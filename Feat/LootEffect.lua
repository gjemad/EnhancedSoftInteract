local ADDON_NAME, ns = ...;

-- WoW: Forever only. Forever and Retail load this file, and a client that recognizes none of the TOC's game
-- types loads it anyway, so the build decides. Retail has its own loot effect on these objects, and Era and MoP
-- Classic give a soft target no nameplate to anchor to.
local build = select(4, GetBuildInfo());
if build < 16000 or build >= 20000 then return end

-- Gold dust on the soft target when it's an ore vein, a herb or a quest object, one option each. The dust
-- hangs under the target's nameplate, which is the only thing that knows where the target is.
-- The HUD decides the dust's mood while it shows the same target: usable, distant (out of range) or
-- unusable. Each mood in MOODS sets how strong the dust is, how fast it twinkles and how grey it is, and a
-- new mood blends the dust from its current look to that one over MOOD_FADE. A mood takes over only once
-- the HUD has reported it for the mood's settle time, so the edge of the range doesn't flicker. Becoming
-- usable starts every dot's twinkle over at once.
-- Each dot runs through one twinkle (progress 0 to 1, after a dark gap below 0) at its own length and size,
-- drifting up as it goes, then reappears somewhere else in the disc.
-- An object has a plate while SoftTargetIconGameObject is on (Feat\HideBlizzard.lua holds it on for these
-- options). Corpses get none: the game already shows its loot effect on a corpse with loot, and a corpse only has a plate
-- with SoftTargetNameplateInteract, which shows its name and an empty health bar.
-- Nothing attached to a nameplate may be measured: GetCenter and the like fail on it and taint the addon.
ns.LootEffectSupported = true;
local UNIT = "softinteract";
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];

local DROP = 40; --from the plate's center down to the target
local RADIUS_X, RADIUS_Y = 26, 15; --the flattened disc the dust appears in
local DOT_COUNT = 10;
local CORE_SIZE, CORE_SWELL = 2.4, 1.9; --a dot's core, plus this much at its brightest
local HALO_SIZE, HALO_STRENGTH = 3.1, 0.55; --a soft halo around each core, in core sizes and its color
local CORE_COLOR = { 1, 1, 0.9 };
local DUST_COLOR = { 1, 0.85, 0.5 };
local GREY_COLOR = { 0.6, 0.6, 0.6 };
local TWINKLE_MIN, TWINKLE_SPREAD, DARK_GAP = 0.7, 0.8, 0.5; --seconds a dot shines, and the dark gap before the next
local SIZE_MIN, SIZE_SPREAD = 0.6, 0.8; --each dot's own size, around 1
local DRIFT = 8; --units per second of twinkle time
local APPEAR_TIME, MOOD_FADE = 0.3, 0.25;
local MOODS = {
  usable = { strength = 1, pace = 1.15, grey = 0, settle = 0.12 },
  distant = { strength = 0.6, pace = 0.75, grey = 0, settle = 0.12 },
  unusable = { strength = 0.3, pace = 0.41, grey = 1, settle = 0.5 },
};

-- The option for each cursor, after its Unable prefix is removed.
local OPTION_BY_CURSOR = {
  mine = "lootEffectOre", gatherherbs = "lootEffectHerbs",
  quest = "lootEffectQuest", questinteract = "lootEffectQuest", questrepeatable = "lootEffectQuest",
  campaignquest = "lootEffectQuest",
};
-- Forever Loot Sparkles' option for each of ours. While it's on there, that addon draws its own effect.
local OTHER_ADDON = { lootEffectOre = "sparkleOre", lootEffectHerbs = "sparkleHerbs", lootEffectQuest = "sparkleQuest" };

function ns.LootEffectOwnedElsewhere(key)
  return ns.ForeverLootSparklesOption(OTHER_ADDON[key]);
end

-- Whether an option is on, so objects need their plate.
function ns.LootEffectNeedsObjectPlates(db)
  return db.lootEffectOre or db.lootEffectHerbs or db.lootEffectQuest;
end

local dust = CreateFrame("Frame", nil, _G.WorldFrame); --nameplates live under WorldFrame too
dust:SetSize(1, 1);
dust:SetFrameStrata("BACKGROUND");
dust:Hide();
ns.lootEffectFrame = dust; --for the test tools
local dots = {};
for index = 1, DOT_COUNT do
  local halo = dust:CreateTexture(nil, "ARTWORK");
  local core = dust:CreateTexture(nil, "OVERLAY");
  for _, texture in ipairs({ halo, core }) do
    texture:SetTexture(MEDIA .. "SoftGlow");
    texture:SetBlendMode("ADD");
    texture:SetAlpha(0);
  end
  dots[index] = { halo = halo, core = core };
end

local function Mix(from, to, amount) return from + (to - from) * amount end

-- The dust's look now, the look it blends from and how far that blend has come.
local look = { strength = 1, pace = 1, grey = 0 };
local blendFrom = { strength = 1, pace = 1, grey = 0 };
local blend = 1;
local mood = "usable";
local presence = 0; --the fade-in of a new target, 0 to 1
local hungOn, hungFor; --the plate and the target's GUID

-- A dot's next twinkle, somewhere new in the disc. immediate: no dark gap.
local function Scatter(dot, immediate)
  local angle, distance = math.random() * 2 * math.pi, math.sqrt(math.random());
  dot.left, dot.up = math.cos(angle) * distance * RADIUS_X, math.sin(angle) * distance * RADIUS_Y;
  dot.length = TWINKLE_MIN + TWINKLE_SPREAD * math.random();
  dot.size = SIZE_MIN + SIZE_SPREAD * math.random();
  dot.progress = immediate and 0 or -DARK_GAP * math.random() / dot.length;
end

local function EnterMood(newMood, at)
  mood = newMood;
  for field, value in pairs(look) do blendFrom[field] = value; end
  blend = at and 1 or 0;
  if at then
    for field, value in pairs(MOODS[newMood]) do if look[field] then look[field] = value; end end
  end
  if newMood == "usable" and not at then
    for _, dot in ipairs(dots) do Scatter(dot, true); end
  end
end

local function PaintDot(dot, color)
  local brightness = dot.progress > 0 and math.sin(math.pi * dot.progress) or 0;
  local size = (CORE_SIZE + CORE_SWELL * brightness) * dot.size;
  local alpha = presence * look.strength * brightness;
  local up = dot.up + DRIFT * math.max(dot.progress, 0) * dot.length;
  dot.core:SetPoint("CENTER", dust, "CENTER", dot.left, up);
  dot.core:SetSize(size, size);
  dot.core:SetVertexColor(Mix(CORE_COLOR[1], color[1], look.grey), Mix(CORE_COLOR[2], color[2], look.grey),
    Mix(CORE_COLOR[3], color[3], look.grey));
  dot.core:SetAlpha(alpha);
  dot.halo:SetPoint("CENTER", dust, "CENTER", dot.left, up);
  dot.halo:SetSize(size * HALO_SIZE, size * HALO_SIZE);
  dot.halo:SetVertexColor(color[1], color[2], color[3]);
  dot.halo:SetAlpha(alpha * HALO_STRENGTH);
end

local haloColor = {};
dust:SetScript("OnUpdate", function(_, elapsed)
  elapsed = math.min(elapsed, 0.1); --no jump after a stall
  presence = math.min(1, presence + elapsed / APPEAR_TIME);
  if blend < 1 then
    blend = math.min(1, blend + elapsed / MOOD_FADE);
    local target = MOODS[mood];
    for field in pairs(look) do look[field] = Mix(blendFrom[field], target[field], blend); end
  end
  for index = 1, 3 do haloColor[index] = Mix(DUST_COLOR[index], GREY_COLOR[index], look.grey); end
  for _, dot in ipairs(dots) do
    dot.progress = dot.progress + elapsed * look.pace / dot.length;
    if dot.progress >= 1 then Scatter(dot); end
    PaintDot(dot, haloColor);
  end
end);

local function Detach()
  dust:Hide();
  dust:ClearAllPoints();
  hungOn, hungFor = nil, nil;
end

local function Hang(plate, guid, newMood)
  dust:ClearAllPoints();
  dust:SetPoint("CENTER", plate, "CENTER", 0, -DROP);
  hungOn, hungFor = plate, guid;
  presence = 0;
  EnterMood(newMood, true);
  for _, dot in ipairs(dots) do Scatter(dot); end
  dust:Show();
end

-- The mood the HUD reports takes over once it has been reported for its settle time. Each report of a
-- different mood gets a ticket; a later report, or the old mood coming back, voids the earlier ticket.
local reported, ticket = nil, 0;
local function Report(newMood)
  if newMood == reported then return end
  reported = newMood;
  ticket = ticket + 1;
  if newMood == mood then return end
  local mine = ticket;
  C_Timer.After(MOODS[newMood].settle, function()
    if mine == ticket and hungOn then EnterMood(newMood); end
  end);
end

local function Readable(value)
  if ns.issecretvalue(value) then return nil end
  return value;
end

-- The HUD's view of the target, while it shows the one at hand: its cursor without the Unable prefix, and
-- its mood. Unusable covers a requirement such as a missing profession or too little skill (which leaves
-- outOfRange set as well) and any other Unable cursor in range.
local function HudTarget(guid)
  local hud = ns.frame;
  if not (hud and hud.colorKey and guid and hud.lastTarget == guid) then return end
  local cursor = hud.colorKey:match("^Cursor (.+)$");
  cursor = cursor and cursor:lower():gsub("^unable", "");
  local newMood = hud.requirementText and "unusable" or hud.outOfRange and "distant"
    or ns.IsUnableKey(hud.colorKey) and "unusable" or "usable";
  return cursor, newMood;
end

-- Whether the game ties the object to an active quest: directly, or by a quest objective line in its tooltip.
local function QuestObject()
  if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest and Readable(C_QuestLog.UnitIsRelatedToActiveQuest(UNIT)) then
    return true;
  end
  local objectiveType = Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective;
  local tooltip = objectiveType and C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(UNIT);
  local rows = tooltip and Readable(tooltip.lines);
  if type(rows) ~= "table" then return false end
  for _, row in ipairs(rows) do
    if Readable(row.type) == objectiveType then return true end
  end
  return false;
end

-- The option that covers the soft target, or nil.
local function OptionFor(cursor)
  if not Readable(UnitIsGameObject(UNIT)) then return nil end
  return OPTION_BY_CURSOR[cursor] or (QuestObject() and "lootEffectQuest") or nil;
end

local function Update()
  local db = EnhancedSoftInteractDB;
  local guid = Readable(UnitGUID(UNIT));
  local cursor, newMood = HudTarget(guid);
  local key = db and db.enabled and cursor and OptionFor(cursor);
  if not (key and db[key] and not ns.LootEffectOwnedElsewhere(key)) then return Detach() end
  local plate = C_NamePlate.GetNamePlateForUnit(UNIT);
  if not plate or plate:IsForbidden() then return Detach() end
  if plate ~= hungOn or guid ~= hungFor then
    reported, ticket = newMood, ticket + 1;
    Hang(plate, guid, newMood);
  else
    Report(newMood);
  end
end

-- Called when Enabled or a loot effect option changes, and after the HUD takes a target or a change in range
-- or state.
ns.UpdateLootEffect = Update;
ns.LootEffectMood = function() return dust:IsShown() and mood or nil end; --for the test tools

local watcher = CreateFrame("Frame");
watcher:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED");
watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED");
watcher:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
watcher:SetScript("OnEvent", function(_, event, token)
  if event == "NAME_PLATE_UNIT_REMOVED" then
    local plate = C_NamePlate.GetNamePlateForUnit(token);
    if plate and plate ~= hungOn then return end
    Detach();
    C_Timer.After(0, Update);
  else
    Update();
  end
end);

table.insert(ns.onLoad, Update);
