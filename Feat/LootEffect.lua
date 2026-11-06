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
-- new mood eases the dust from its current look to that one over MOOD_FADE. A mood takes over only once the
-- HUD has reported it for the mood's settle time, so the edge of the range doesn't flicker. Becoming usable
-- lets every dot finish its twinkle and starts the next ones without a dark gap.
-- Each dot runs through one twinkle (progress 0 to 1, after a dark gap below 0) with its own length, size,
-- brightness and shade of gold, drifting up as it goes, then reappears somewhere else in the disc. About one
-- dot in STAR_ODDS is a slowly turning star glint instead of a round one.
-- Two clouds take turns, so a lost target's dust fades out while the next target's fades in. A cloud whose
-- plate is removed hides at once, because a hidden plate gives its anchors no reliable place.
-- An object has a plate while SoftTargetIconGameObject is on (Feat\HideBlizzard.lua holds it on for these
-- options). Corpses get none: the game already shows its loot effect on a corpse with loot, and a corpse only has a plate
-- with SoftTargetNameplateInteract, which shows its name and an empty health bar.
-- Nothing attached to a nameplate may be measured: GetCenter and the like fail on it and taint the addon.
ns.LootEffectSupported = true;
local UNIT = "softinteract";
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
local GLOW = MEDIA .. "SoftGlow";
local STAR = "azsharawards-starglow"; --client art

local DROP = 40; --from the plate's center down to the target
local RADIUS_X, RADIUS_Y = 26, 15; --the flattened disc the dust appears in
local DOT_COUNT = 10;
local CORE_SIZE, CORE_SWELL = 2.4, 1.9; --a dot's core, plus this much at its brightest
local HALO_SIZE, HALO_STRENGTH = 3.1, 0.55; --a soft halo around each core, in core sizes and its color
local STAR_ODDS, STAR_SIZE, STAR_STRENGTH, STAR_TURN = 7, 5.5, 0.9, 0.6; --star glints; turn in radians per second
local CORE_COLOR = { 1, 1, 0.9 };
local DUST_COLOR = { 1, 0.85, 0.5 };
local PALE_COLOR = { 1, 0.95, 0.78 }; --the palest shade a dot can lean toward
local GREY_COLOR = { 0.6, 0.6, 0.6 };
local TWINKLE_MIN, TWINKLE_SPREAD, DARK_GAP = 0.7, 0.8, 0.5; --seconds a dot shines, and the dark gap before the next
local SIZE_MIN, SIZE_SPREAD = 0.6, 0.8; --each dot's own size, around 1
local SIZE_JITTER = 0.5; --and a further 0.75 to 1.25 of that
local DIM_MIN, PALE_MAX = 0.65, 0.5; --each dot's own brightness from DIM_MIN to 1, and lean toward PALE_COLOR
local DRIFT = 8; --units per second of twinkle time
local APPEAR_TIME, VANISH_TIME, MOOD_FADE = 0.3, 0.3, 0.25;
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

local function Mix(from, to, amount) return from + (to - from) * amount end
local function Ease(amount) return amount * amount * (3 - 2 * amount) end
local hasStar = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(STAR) ~= nil;

-- Both clouds and their dots are made here, at load.
local function NewCloud()
  local cloud = { dots = {}, look = { strength = 1, pace = 1, grey = 0 }, from = {}, blend = 1, mood = "usable", presence = 0 };
  cloud.frame = CreateFrame("Frame", nil, _G.WorldFrame); --nameplates live under WorldFrame too
  cloud.frame:SetSize(1, 1);
  cloud.frame:SetFrameStrata("BACKGROUND");
  cloud.frame:Hide();
  for index = 1, DOT_COUNT do
    local halo = cloud.frame:CreateTexture(nil, "ARTWORK");
    local core = cloud.frame:CreateTexture(nil, "OVERLAY");
    for _, texture in ipairs({ halo, core }) do
      texture:SetTexture(GLOW);
      texture:SetBlendMode("ADD");
      texture:SetAlpha(0);
    end
    cloud.dots[index] = { halo = halo, core = core };
  end
  return cloud;
end
local clouds = { NewCloud(), NewCloud() };
local active; --the cloud on the current target; the other one may still be fading out
ns.lootEffectFrame = clouds[1].frame; --for the test tools

-- A dot's next twinkle, somewhere new in the disc, with its own look. It starts at once when the target has
-- just become usable, or after a short dark gap.
local function Scatter(dot)
  local angle, distance = math.random() * 2 * math.pi, math.sqrt(math.random());
  dot.left, dot.up = math.cos(angle) * distance * RADIUS_X, math.sin(angle) * distance * RADIUS_Y;
  dot.length = TWINKLE_MIN + TWINKLE_SPREAD * math.random();
  dot.size = (SIZE_MIN + SIZE_SPREAD * math.random()) * (1 - SIZE_JITTER / 2 + SIZE_JITTER * math.random());
  dot.dim = Mix(DIM_MIN, 1, math.random());
  dot.pale = PALE_MAX * math.random();
  dot.progress = dot.eager and 0 or -DARK_GAP * math.random() / dot.length;
  dot.eager = nil;
  local star = hasStar and math.random(STAR_ODDS) == 1;
  if star ~= dot.star then
    dot.star = star;
    if star then dot.halo:SetAtlas(STAR); else dot.halo:SetTexture(GLOW); end
  end
  dot.angle, dot.turn = math.random() * math.pi, (math.random() - 0.5) * 2 * STAR_TURN;
end

local function EnterMood(cloud, newMood, immediate)
  cloud.mood = newMood;
  for field, value in pairs(cloud.look) do cloud.from[field] = value; end
  if immediate then
    for field in pairs(cloud.look) do cloud.look[field] = MOODS[newMood][field]; end
    cloud.blend = 1;
    return;
  end
  cloud.blend = 0;
  if newMood == "usable" then
    for _, dot in ipairs(cloud.dots) do dot.eager = true; end
  end
end

local function PaintDot(cloud, dot, presence)
  local look = cloud.look;
  local brightness = dot.progress > 0 and math.sin(math.pi * dot.progress) or 0;
  local alpha = presence * look.strength * brightness * dot.dim;
  local size = (CORE_SIZE + CORE_SWELL * brightness) * dot.size;
  local up = dot.up + DRIFT * math.max(dot.progress, 0) * dot.length;
  local red = Mix(Mix(DUST_COLOR[1], PALE_COLOR[1], dot.pale), GREY_COLOR[1], look.grey);
  local green = Mix(Mix(DUST_COLOR[2], PALE_COLOR[2], dot.pale), GREY_COLOR[2], look.grey);
  local blue = Mix(Mix(DUST_COLOR[3], PALE_COLOR[3], dot.pale), GREY_COLOR[3], look.grey);
  dot.core:SetPoint("CENTER", cloud.frame, "CENTER", dot.left, up);
  dot.core:SetSize(size, size);
  dot.core:SetVertexColor(Mix(CORE_COLOR[1], red, look.grey), Mix(CORE_COLOR[2], green, look.grey),
    Mix(CORE_COLOR[3], blue, look.grey));
  dot.core:SetAlpha(alpha);
  local haloSize = size * (dot.star and STAR_SIZE or HALO_SIZE);
  dot.halo:SetPoint("CENTER", cloud.frame, "CENTER", dot.left, up);
  dot.halo:SetSize(haloSize, haloSize);
  dot.halo:SetVertexColor(red, green, blue);
  dot.halo:SetRotation(dot.star and dot.angle or 0);
  dot.halo:SetAlpha(alpha * (dot.star and STAR_STRENGTH or HALO_STRENGTH));
end

local function Hide(cloud)
  cloud.frame:Hide();
  cloud.frame:ClearAllPoints();
  cloud.plate, cloud.guid, cloud.leaving = nil, nil, nil;
end

local function Animate(cloud, elapsed)
  elapsed = math.min(elapsed, 0.1); --no jump after a stall
  if cloud.leaving then
    cloud.presence = math.max(0, cloud.presence - elapsed / VANISH_TIME);
    if cloud.presence == 0 then return Hide(cloud) end
  else
    cloud.presence = math.min(1, cloud.presence + elapsed / APPEAR_TIME);
  end
  if cloud.blend < 1 then
    cloud.blend = math.min(1, cloud.blend + elapsed / MOOD_FADE);
    local target, amount = MOODS[cloud.mood], Ease(cloud.blend);
    for field in pairs(cloud.look) do cloud.look[field] = Mix(cloud.from[field], target[field], amount); end
  end
  local presence = Ease(cloud.presence);
  for _, dot in ipairs(cloud.dots) do
    dot.progress = dot.progress + elapsed * cloud.look.pace / dot.length;
    dot.angle = dot.angle + elapsed * dot.turn;
    if dot.progress >= 1 then Scatter(dot); end
    PaintDot(cloud, dot, presence);
  end
end
for _, cloud in ipairs(clouds) do
  cloud.frame:SetScript("OnUpdate", function(_, elapsed) Animate(cloud, elapsed) end);
end

-- The current target's dust fades out.
local function Release()
  if active then active.leaving = true; end
  active = nil;
end

local function Hang(plate, guid, newMood)
  Release();
  active = clouds[1].frame:IsShown() and not clouds[2].frame:IsShown() and clouds[2] or clouds[1];
  local cloud = active;
  cloud.frame:ClearAllPoints();
  cloud.frame:SetPoint("CENTER", plate, "CENTER", 0, -DROP);
  cloud.plate, cloud.guid, cloud.leaving, cloud.presence = plate, guid, nil, 0;
  EnterMood(cloud, newMood, true);
  for _, dot in ipairs(cloud.dots) do Scatter(dot); end
  cloud.frame:Show();
end

-- The mood the HUD reports takes over once it has been reported for its settle time. Each report of a
-- different mood gets a ticket; a later report, or the old mood coming back, voids the earlier ticket.
local reported, ticket = nil, 0;
local function Report(newMood)
  if newMood == reported then return end
  reported = newMood;
  ticket = ticket + 1;
  if newMood == active.mood then return end
  local mine, cloud = ticket, active;
  C_Timer.After(MOODS[newMood].settle, function()
    if mine == ticket and cloud == active then EnterMood(cloud, newMood); end
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
  if not (key and db[key] and not ns.LootEffectOwnedElsewhere(key)) then return Release() end
  local plate = C_NamePlate.GetNamePlateForUnit(UNIT);
  if not plate or plate:IsForbidden() then return Release() end
  if not active or plate ~= active.plate or guid ~= active.guid then
    reported, ticket = newMood, ticket + 1;
    Hang(plate, guid, newMood);
  else
    Report(newMood);
  end
end

-- Called when Enabled or a loot effect option changes, and after the HUD takes a target or a change in range
-- or state.
ns.UpdateLootEffect = Update;
-- For the test tools: the current target's mood, and whether any dust shows.
ns.LootEffectMood = function() return active and active.mood or nil end;
ns.LootEffectShown = function() return clouds[1].frame:IsShown() or clouds[2].frame:IsShown() end;
ns.LootEffectClouds = clouds;

local watcher = CreateFrame("Frame");
watcher:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED");
watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED");
watcher:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
watcher:SetScript("OnEvent", function(_, event, token)
  if event == "NAME_PLATE_UNIT_REMOVED" then
    local plate = C_NamePlate.GetNamePlateForUnit(token);
    local hit = false;
    for _, cloud in ipairs(clouds) do
      if cloud.plate and (not plate or plate == cloud.plate) then
        if cloud == active then active = nil; end
        Hide(cloud);
        hit = true;
      end
    end
    if hit then C_Timer.After(0, Update); end
  else
    Update();
  end
end);

table.insert(ns.onLoad, Update);
