local _, ns = ...;
local issecretvalue = ns.issecretvalue;

-- The skill-up icon before a herb, ore or skinnable corpse's name: Blizzard's recipe list arrows, orange
-- (High), yellow (Medium) or green (Low). A target that gives no skill (grey) or needs more skill than the
-- character has shows none. Retail shows none either: its gathering skill-ups don't follow these
-- thresholds.
local RETAIL = select(4, GetBuildInfo()) >= 100000;
ns.SkillUpSupported = not RETAIL; --for the settings page
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
-- gathering code. Blizzard's own thresholds aren't documented; check them in game. Forever's starter
-- nodes have their own (Data/GatherSkill.lua colors).
local YELLOW_AT, GREEN_AT, GREY_AT = 25, 50, 100;

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
  if entry and nodes.entries[entry] then return nodes.entries[entry], "entry", entry, nodes.colors[entry] end
  -- English names only; a node in another language without a known ID gets no icon.
  name = Accessible(name);
  if name and nodes.names[name] then return nodes.names[name], "name", entry, nodes.colors[name] end
  return nil, nil, entry;
end

-- The skill-up level for the soft target ("High", "Medium", "Low") and the details for /esi debug, or nil
-- when the target gives no skill or isn't known.
function ns.SkillUpFor(cursorName, guid, name)
  local skill = not RETAIL and SKILLS[cursorName];
  if not skill then return nil end
  local required, source, entry, colors = Required(skill, guid, name);
  local rank = SkillRank(skill);
  local info = { required = required, source = source, entry = entry, rank = rank };
  if not (required and rank) or rank < required then return nil, info end
  local yellow, green, grey = required + YELLOW_AT, required + GREEN_AT, required + GREY_AT;
  if colors then yellow, green, grey = colors[1], colors[2], colors[3]; end
  info.level = rank < yellow and "High" or rank < green and "Medium" or rank < grey and "Low" or nil;
  return info.level, info;
end

-- A skill-up level for a preview sample of a herb, ore or skinnable corpse, or nil. Each call takes the
-- next of the three levels, so the preview shows every icon as it cycles through targets.
local SAMPLE_LEVELS = { "High", "Medium", "Low" };
local sampleCount = 0;
function ns.SampleSkillUp(cursorName)
  cursorName = cursorName and cursorName:gsub("^Unable", ""); --out of range keeps the icon, as on a real target
  if RETAIL or not SKILLS[cursorName] then return nil end
  sampleCount = sampleCount % #SAMPLE_LEVELS + 1;
  return SAMPLE_LEVELS[sampleCount];
end

-- The art for a skill-up level, or nil on a client without it.
function ns.SkillUpAtlas(level)
  local atlas = level and "Professions-Icon-Skill-" .. level;
  return atlas and C_Texture.GetAtlasInfo(atlas) and atlas or nil;
end
