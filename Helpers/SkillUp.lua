local _, ns = ...;
local issecretvalue = ns.issecretvalue;

-- The skill-up icon before a herb, ore or skinnable corpse's name: Blizzard's recipe list arrows, orange
-- (High), yellow (Medium) or green (Low). A target that gives no skill (grey) or needs more skill than the
-- character has shows none. Retail shows none either: its gathering skill-ups don't follow these
-- thresholds.
local INTERFACE = select(4, GetBuildInfo());
-- This client's field in Data/GatherSkill.lua, or nil on Retail and on Classic versions with no data.
local CLIENT = INTERFACE >= 16000 and INTERFACE < 20000 and "forever"
  or INTERFACE < 20000 and "era"
  or INTERFACE < 30000 and "tbc"
  or INTERFACE >= 50000 and INTERFACE < 60000 and "mop"
  or nil;
ns.SkillUpSupported = CLIENT ~= nil; --for the settings page
-- Forever has C_SkillInfo, the Classic clients the older Skills panel functions.
local C_SkillInfo, GetNumSkillLines, GetSkillLineInfo = _G.C_SkillInfo, _G.GetNumSkillLines, _G.GetSkillLineInfo;

-- Each gathering cursor's skill line, the data table with its nodes (Data/GatherSkill.lua) and the name
-- the Skills panel uses, for clients whose skill rows have no ID.
local SKILLS = {
  GatherHerbs = { skillLine = 182, nodes = "herbs", name = HERBALISM or "Herbalism" },
  Mine = { skillLine = 186, nodes = "mining", name = MINING or "Mining" },
  Skin = { skillLine = 393, name = SKINNING or "Skinning" },
};

-- The orange, yellow and green ranges end this far above the requirement, as in the open-source servers'
-- gathering code. Blizzard's own thresholds aren't documented; check them in game. Some nodes have their
-- own on a client, measured in game (Data/GatherSkill.lua colors).
local YELLOW_AT, GREEN_AT, GREY_AT = 25, 50, 100;

-- This client's own yellow, green and grey skills from a colors entry, or nil.
local function ClientColors(entry)
  return entry and entry[CLIENT];
end

local function Accessible(value)
  if issecretvalue(value) then return nil end
  return value;
end

-- The character's rank in a skill line, or nil. Forever has C_SkillInfo; the Classic clients have
-- GetProfessions, or only the Skills panel rows (Era can return no GetProfessions entries).
local function SkillRank(skill)
  if C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
    local info = C_SkillInfo.GetSkillLineInfoByID(skill.skillLine);
    local rank = info and Accessible(info.rank);
    if rank then return rank end
  end
  if GetProfessions and GetProfessionInfo then
    for _, index in pairs({ GetProfessions() }) do --pairs skips the nil gaps
      local _, _, rank, _, _, _, skillLine = GetProfessionInfo(index);
      if skillLine == skill.skillLine then return rank end
    end
  end
  if GetNumSkillLines and GetSkillLineInfo then
    for index = 1, GetNumSkillLines() do
      local name, isHeader, _, rank = GetSkillLineInfo(index);
      if not isHeader and name == skill.name then return rank end
    end
  end
  return nil;
end

-- The entry ID in a game object's GUID ("GameObject-0-1-0-12-1731-0000C2F4A1"), or nil.
local function EntryID(guid)
  if not guid or issecretvalue(guid) then return nil end
  local unitType, _, _, _, _, id = strsplit("-", guid);
  return unitType == "GameObject" and tonumber(id) or nil;
end

-- The data's name for a node, from the name this language's game shows. A node in another language with
-- neither a known ID nor an entry in NODE_NAMES gets no icon. This runs only for a node with an unknown ID.
local function EnglishNodeName(name)
  for english, translated in pairs(ns.L.NODE_NAMES) do
    if translated == name then return english end
  end
  return name;
end

-- What a node or corpse needs: the skill, where that came from ("entry", "name" or "level"), the entry ID,
-- and the node's own yellow, green and grey skills when it has them. Unknown nodes give nil. A corpse
-- needs nothing below level 10, then 10 per level to level 20, then 5 per level.
local function Required(skill, guid, name)
  if not skill.nodes then
    local level = Accessible(UnitLevel("softinteract"));
    if not level or level <= 0 then return nil end
    return level < 10 and 0 or level < 20 and (level - 10) * 10 or level * 5, "level";
  end
  local nodes = ns.gatherSkill[skill.nodes];
  local entry = EntryID(guid);
  local node = entry and nodes.entries[entry];
  if node and node[CLIENT] then return node[CLIENT], "entry", entry, ClientColors(nodes.colors[entry]) end
  name = Accessible(name);
  name = name and EnglishNodeName(name);
  node = name and nodes.names[name];
  if node and node[CLIENT] then return node[CLIENT], "name", entry, ClientColors(nodes.colors[name]) end
  return nil, nil, entry;
end

-- Seen colors: the game's own tooltip colors the profession line of a gathering node by skill-up level.
-- Whenever the player hovers a known node, the color at the current rank is saved per client, profession
-- and node name (EnhancedSoftInteractDB.skillColors), account-wide and without a message. The level depends
-- only on the node type and the rank, so a same-named node under the pointer gives the same answer as the
-- soft target. A seen color corrects the thresholds above; /esi skills lists where they disagree.
local LEVELS = { High = 1, Medium = 2, Low = 3, Trivial = 4 };
-- The game's difficulty colors. Red means the skill is too low; it is saved but moves no threshold.
local TOOLTIP_COLORS = {
  { "High", 1, 0.5, 0.25 }, { "Medium", 1, 1, 0 }, { "Low", 0.25, 0.75, 0.25 },
  { "Trivial", 0.5, 0.5, 0.5 }, { "Red", 1, 0.1, 0.1 },
};

-- The saved colors of one profession on this client, created on first use.
local function SeenNodes(skill, create)
  local db = EnhancedSoftInteractDB;
  if not (db and CLIENT and skill.nodes) then return nil end
  if create then
    db.skillColors = db.skillColors or {};
    db.skillColors[CLIENT] = db.skillColors[CLIENT] or {};
    db.skillColors[CLIENT][skill.nodes] = db.skillColors[CLIENT][skill.nodes] or {};
  end
  local client = db.skillColors and db.skillColors[CLIENT];
  return client and client[skill.nodes];
end

-- The level name for a tooltip line color, or "#rrggbb" for a color that is none of them.
local function LevelForColor(r, g, b)
  for _, c in ipairs(TOOLTIP_COLORS) do
    if math.abs(r - c[2]) < 0.1 and math.abs(g - c[3]) < 0.1 and math.abs(b - c[4]) < 0.1 then return c[1] end
  end
  return ("#%02x%02x%02x"):format(r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5);
end

-- The yellow, green and grey skills moved as little as the seen colors need: a color seen at a rank puts
-- every lower threshold at or below it and every higher one above it.
local function Corrected(seen, yellow, green, grey)
  if not seen then return yellow, green, grey end
  local at = { yellow, green, grey };
  for k = 1, 3 do
    local low, high = -math.huge, math.huge;
    for rank, level in pairs(seen) do
      local order = LEVELS[level];
      if order and order > k then high = math.min(high, rank); elseif order then low = math.max(low, rank + 1); end
    end
    at[k] = math.min(math.max(at[k], low), high);
    if k > 1 then at[k] = math.max(at[k], at[k - 1]); end
  end
  return at[1], at[2], at[3];
end

-- The node's thresholds before any seen color: the usual rule or the node's own from the data.
local function DataThresholds(required, colors)
  if colors then return colors[1], colors[2], colors[3] end
  return required + YELLOW_AT, required + GREEN_AT, required + GREY_AT;
end

local function LevelAt(rank, yellow, green, grey)
  return rank < yellow and "High" or rank < green and "Medium" or rank < grey and "Low" or nil;
end

-- The skill-up level for the soft target ("High", "Medium", "Low") and the details for /esi debug, or nil
-- when the target gives no skill or isn't known.
function ns.SkillUpFor(cursorName, guid, name)
  local skill = CLIENT and SKILLS[cursorName];
  if not skill then return nil end
  local required, source, entry, colors = Required(skill, guid, name);
  local rank = SkillRank(skill);
  local info = { required = required, source = source, entry = entry, rank = rank };
  if not (required and rank) or rank < required then return nil, info end
  local nodes = skill.nodes and SeenNodes(skill);
  name = Accessible(name);
  local seen = nodes and name and nodes[EnglishNodeName(name)];
  info.level = LevelAt(rank, Corrected(seen, DataThresholds(required, colors)));
  return info.level, info;
end

-- Saves the profession line's color when GameTooltip shows a known herb or ore node. Only reads: the
-- tooltip is never changed, shown or hidden here.
local function ReadTooltip(tooltip)
  if not CLIENT or tooltip ~= GameTooltip or not tooltip.NumLines or tooltip:IsForbidden() then return end
  local lines = tooltip:NumLines();
  if issecretvalue(lines) or lines < 2 then return end
  local title = _G.GameTooltipTextLeft1 and Accessible(_G.GameTooltipTextLeft1:GetText());
  if not title then return end
  title = EnglishNodeName(title);
  for _, skill in pairs(SKILLS) do
    local node = skill.nodes and ns.gatherSkill[skill.nodes].names[title];
    if node and node[CLIENT] then
      for i = 2, lines do
        local line = _G["GameTooltipTextLeft" .. i];
        local text = line and Accessible(line:GetText());
        if text and text:find(skill.name, 1, true) then
          local r, g, b = line:GetTextColor();
          if issecretvalue(r) or issecretvalue(g) or issecretvalue(b) then return end
          local rank = SkillRank(skill);
          if not rank then return end
          local nodes = SeenNodes(skill, true);
          nodes[title] = nodes[title] or {};
          nodes[title][rank] = LevelForColor(r, g, b);
          return;
        end
      end
    end
  end
end

if CLIENT and GameTooltip then
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and TooltipDataProcessor.AllTypes then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, ReadTooltip);
  end
  GameTooltip:HookScript("OnShow", ReadTooltip); --Classic clients fill world tooltips without the processor
end

-- The seen ranks as runs of one color: { from = 128, to = 131, color = "Medium" }, in rank order.
local function Runs(seen)
  local ranks = {};
  for rank in pairs(seen) do ranks[#ranks + 1] = rank; end
  table.sort(ranks);
  local runs, first = {}, 1;
  for i = 1, #ranks do
    if i == #ranks or seen[ranks[i + 1]] ~= seen[ranks[i]] or ranks[i + 1] ~= ranks[i] + 1 then
      runs[#runs + 1] = { from = ranks[first], to = ranks[i], color = seen[ranks[i]] };
      first = i + 1;
    end
  end
  return runs;
end

local function Thresholds(yellow, green, grey) return { yellow = yellow, green = green, grey = grey } end

-- /esi skills (Feat/Debug.lua): every node on this client whose seen colors disagree with the data, sorted by
-- profession and name, and how many nodes have a seen color at all. Each node has the data's thresholds, the
-- thresholds the seen colors give, the ranks where the data's color differs from the seen one, and the seen
-- ranks as runs. Colors are the saved names: High (orange), Medium
-- (yellow), Low (green), Trivial (grey), Red, or "#rrggbb". A developer report like /esi debug, so it stays
-- in English.
function ns.SkillColorReport()
  local list, seenNodes = {}, 0;
  for _, skill in pairs(SKILLS) do
    local nodes = skill.nodes and SeenNodes(skill);
    for title, seen in pairs(nodes or {}) do
      local node = ns.gatherSkill[skill.nodes].names[title];
      local required = node and node[CLIENT];
      if required then
        seenNodes = seenNodes + 1;
        local colors = ClientColors(ns.gatherSkill[skill.nodes].colors[title]);
        local yellow, green, grey = DataThresholds(required, colors);
        local wrong = {};
        for rank, level in pairs(seen) do
          local expected = rank < required and "Red" or LevelAt(rank, yellow, green, grey) or "Trivial";
          if level ~= expected then wrong[#wrong + 1] = { rank = rank, seen = level, expected = expected }; end
        end
        if #wrong > 0 then
          table.sort(wrong, function(a, b) return a.rank < b.rank end);
          list[#list + 1] = {
            profession = skill.nodes, node = title, required = required,
            data = Thresholds(yellow, green, grey), data_source = colors and "node" or "rule",
            seen_thresholds = Thresholds(Corrected(seen, yellow, green, grey)), wrong = wrong, seen = Runs(seen),
          };
        end
      end
    end
  end
  table.sort(list, function(a, b)
    if a.profession ~= b.profession then return a.profession < b.profession end
    return a.node < b.node;
  end);
  local ranks = {};
  for _, skill in pairs(SKILLS) do
    if skill.nodes then ranks[skill.nodes] = SkillRank(skill) or false; end
  end
  return { client = CLIENT, ranks = ranks, rule = Thresholds(YELLOW_AT, GREEN_AT, GREY_AT), seen_nodes = seenNodes,
    nodes = list };
end

-- "Too low skill level (100/150)" for a node that needs more skill than the character has, else nil. The game
-- gives such a node the same Unable cursor as one out of range. Corpses are left out: their requirement
-- comes from a formula, not the game's data.
function ns.SkillRequirementText(cursorName, info)
  local skill = SKILLS[cursorName];
  if not (skill and skill.nodes and info and info.required and info.rank) then return nil end
  if info.rank >= info.required then return nil end
  return ns.L.HUD_SKILL_TOO_LOW:format(info.rank, info.required);
end

-- A skill-up level for a preview sample of a herb, ore or skinnable corpse, or nil. Each call takes the
-- next of the three levels, so the preview shows every icon as it cycles through targets.
local SAMPLE_LEVELS = { "High", "Medium", "Low" };
local sampleCount = 0;
function ns.SampleSkillUp(cursorName)
  cursorName = cursorName and cursorName:gsub("^Unable", ""); --out of range keeps the icon, as on a real target
  if not CLIENT or not SKILLS[cursorName] then return nil end
  sampleCount = sampleCount % #SAMPLE_LEVELS + 1;
  return SAMPLE_LEVELS[sampleCount];
end

-- The art for a skill-up level, or nil on a client without it.
function ns.SkillUpAtlas(level)
  local atlas = level and "Professions-Icon-Skill-" .. level;
  return atlas and C_Texture.GetAtlasInfo(atlas) and atlas or nil;
end
