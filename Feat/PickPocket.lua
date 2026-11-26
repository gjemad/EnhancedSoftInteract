local ADDON_NAME, ns = ...;
local issecretvalue = ns.issecretvalue;

-- Pick Pocket on the interact key. While a stealthed rogue who knows Pick Pocket is out of combat, and there
-- is no soft interact target, the HUD shows the soft enemy when it's a living humanoid that can be picked,
-- and the interact key's keys cast Pick Pocket through an override binding.
--
-- The soft enemy only exists on keyboard while SoftTargetEnemy is 3 (0 off, 1 controller, 2 keyboard and
-- mouse, 3 both; Forever's default is 1). Feat\Targeting.lua holds it at 3 while this is active and gives
-- the player's own value back afterwards. Forever's console refuses that CVar, but an addon can set it.
--
-- No API says a mob's pockets are empty. A pick that worked loots with the NPC as every slot's source, and
-- a second pick on the same NPC still succeeds as a cast, then gives error 696 ("Your target has already
-- had its pockets picked") with no loot. Either one marks the NPC as picked for the session, and the HUD
-- then shows it as Already pickpocketed.
local PICK_POCKET = 921;
-- Pick Pocket's bag (file 133644) with its border cropped and its dark background made clear, written by
-- pick_pocket_icon.py in the renderer tools.
local ICON = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\PickPocket]];
local COLOR_KEY = "Cursor PickPocket"; --Data\CursorData.lua
local UNABLE_KEY = "Cursor UnablePickPocket"; --grey, like any Unable cursor
local HUMANOID = 7; --UnitCreatureType's second value
local ERR_ALREADY_PICKED = 696; --UI_ERROR_MESSAGE's first value
local SOFT_ENEMY_BOTH = 3;
-- Loot or the error arrives in the same frame as the cast; this leaves room for a slow server.
local PICK_WINDOW = 1;
-- At the edge of range the spell's range check flips as often as every 0.1 s. Coming into range shows at
-- once, since the key works then; going out of range has to last OUT_OF_RANGE_SETTLE before "Move closer".
local OUT_OF_RANGE_SETTLE = 0.2;
local POLL_INTERVAL = 0.05;

local picked = {}; --GUID -> true
local pendingGUID, pendingUntil = nil, 0;
local shownGUID, inRange, rangeCandidate, rangeSince;
local lastSignature;
-- Set from PLAYER_REGEN_DISABLED to PLAYER_REGEN_ENABLED, since the combat checks may not say so yet at the
-- first event.
local combatStarted = false;

local function Known(value)
  if issecretvalue(value) then return nil end
  return value;
end

local function KnowsSpell()
  if C_SpellBook and C_SpellBook.IsSpellKnown then return Known(C_SpellBook.IsSpellKnown(PICK_POCKET)) end
  local IsPlayerSpell = _G.IsPlayerSpell;
  return IsPlayerSpell and IsPlayerSpell(PICK_POCKET) or false;
end

local function IsRogue() return UnitClassBase and UnitClassBase("player") == "ROGUE" end
ns.PickPocketAvailable = IsRogue;

-- True while the player could pick a pocket: the option is on, and a stealthed rogue with the spell is out
-- of combat.
local function Active()
  local db = EnhancedSoftInteractDB;
  if not (db and db.enabled and db.pickPocket and ns.loggedIn) then return false end
  if combatStarted or not IsRogue() or InCombatLockdown() then return false end
  if Known(UnitAffectingCombat("player")) ~= false then return false end
  return Known(IsStealthed()) == true and KnowsSpell() == true;
end

-- The value Feat\Targeting.lua holds SoftTargetEnemy at, or nil for the player's own.
function ns.PickPocketSoftEnemy()
  return Active() and SOFT_ENEMY_BOTH or nil;
end

-- The soft enemy's GUID when it can be picked, else nil.
local function Candidate()
  if not Active() then return nil end
  if UnitExists("softinteract") then return nil end --the soft interact target comes first
  local unit = "softenemy";
  if Known(UnitExists(unit)) ~= true then return nil end
  local guid = Known(UnitGUID(unit));
  if not guid then return nil end
  if Known(UnitIsPlayer(unit)) ~= false or Known(UnitIsDead(unit)) ~= false then return nil end
  -- NPCs in combat, even ones another player tagged, can still be picked.
  if Known(UnitCanAttack("player", unit)) ~= true then return nil end
  local _, typeID = UnitCreatureType(unit);
  if Known(typeID) ~= HUMANOID then return nil end
  return guid;
end

local function RangeNow()
  local value = C_Spell.IsSpellInRange and Known(C_Spell.IsSpellInRange(PICK_POCKET, "softenemy"));
  return value ~= false; --unknown counts as in range, like the game's own cursor fallback
end

-- Follows the range check, settled against flicker. A new target takes the current answer at once.
local function UpdateRange(guid)
  local now = RangeNow();
  if guid ~= shownGUID then
    shownGUID, inRange, rangeCandidate = guid, now, nil;
    return;
  end
  if now == inRange then rangeCandidate = nil; return end
  if now then inRange, rangeCandidate = true, nil; return end
  if rangeCandidate ~= now then
    rangeCandidate, rangeSince = now, GetTime();
  elseif GetTime() - rangeSince >= OUT_OF_RANGE_SETTLE then
    inRange, rangeCandidate = now, nil;
  end
end

-- What the HUD shows for the current Pick Pocket target, in the shape ns.ResolveTarget returns, or nil.
-- A picked NPC stays, greyed out with a status line, like a node that needs a profession: the line replaces
-- "Move closer", and range still dims and darkens the HUD.
function ns.PickPocketTarget()
  local guid = Candidate();
  if not guid then return nil end
  if guid ~= shownGUID then UpdateRange(guid); end
  local done = picked[guid] or false;
  local key = done and UNABLE_KEY or COLOR_KEY;
  local outOfRange = not inRange;
  return { name = UnitName("softenemy"), knownTarget = guid, hasCursor = true, iconSource = "pick_pocket",
    iconFromFileID = false, icon = ICON, iconDesaturated = done, resolvedKey = key, iconKey = key,
    outOfRange = outOfRange, requirementText = done and ns.L.HUD_ALREADY_PICKED or nil,
    signature = key .. "|" .. tostring(outOfRange), action = COLOR_KEY:lower() };
end

----
--  The interact key. Override bindings can't change in combat, so they go at PLAYER_REGEN_DISABLED, which
--  comes before the lockdown starts. The button casts by name with no unit, the way an action button does:
--  with SoftTargetEnemy at 3 that reaches the soft enemy, or the target, which the soft enemy then follows.
----
local button = CreateFrame("Button", "EnhancedSoftInteractPickPocket", UIParent, "SecureActionButtonTemplate");
button:SetAttribute("type", "spell");
-- Key down only: registered for up as well, Forever cast on both, so one press picked twice and the second
-- cast, on an NPC just picked, put the player in combat (captures 2026-11-26).
button:RegisterForClicks("AnyDown");
local bindingOwner = CreateFrame("Frame");
local boundKeys;

local function KeysSignature()
  local keys = { GetBindingKey("INTERACTTARGET") };
  for i, key in ipairs(keys) do keys[i] = Known(key) or ""; end
  return table.concat(keys, "\n"), keys;
end

local function SetBinding(on)
  if InCombatLockdown() then return end
  local signature, keys = KeysSignature();
  if on and boundKeys == signature then return end
  if not on and not boundKeys then return end
  ClearOverrideBindings(bindingOwner);
  boundKeys = nil;
  if not on then return end
  local name = Known(C_Spell.GetSpellName(PICK_POCKET));
  if not name then return end
  button:SetAttribute("spell", name);
  for _, key in ipairs(keys) do
    if key ~= "" then SetOverrideBindingClick(bindingOwner, true, key, button:GetName(), "LeftButton"); end
  end
  boundKeys = signature;
end

-- True while the interact key should cast Pick Pocket: active, with a soft enemy and no soft interact
-- target. That covers enemies the HUD doesn't show, such as a picked NPC or a beast, because the game's
-- interact key attacks an enemy, and SoftTargetEnemy 3 gives the keyboard a soft enemy it wouldn't have.
-- Pick Pocket on those only brings the game's error.
local function KeyCastsPickPocket()
  if not Active() or ns.frame.inEditMode or UnitExists("softinteract") then return false end
  return Known(UnitExists("softenemy")) == true;
end

-- Plays the style's cast success or interruption effect on the HUD, with no start or end markers or timer,
-- since Pick Pocket has no cast bar. The core waits for it to finish before it shows the next state.
local function PlayOutcome(kind, guid)
  if not guid or guid ~= shownGUID or ns.frame.lastTarget ~= guid then return end
  ns.CastBar.Outcome(ns.frame, guid, kind, 1, nil,
    { color = { ns.GetTypeColor(COLOR_KEY, false) }, instant = true, noTimer = true });
end

-- A pick that went out (UNIT_SPELLCAST_SUCCEEDED) and brought neither loot nor error 696 missed, and the NPC
-- notices: it plays the interruption effect. No capture shows a miss yet, so it is recognized by what's
-- missing, by whichever comes first: MISS_WAIT passing, combat starting, or the NPC no longer pickable.
local MISS_WAIT = 0.4;
local pendingSucceeded = false;
local function ClearPending()
  pendingGUID, pendingSucceeded = nil, false;
end
local function Missed()
  local guid = pendingGUID;
  ClearPending();
  PlayOutcome("interrupt", guid);
end

-- Checks the target again and tells the core when what the HUD should show has changed.
local function Refresh()
  local guid = Candidate();
  if pendingSucceeded and guid ~= pendingGUID then Missed(); end
  if guid then UpdateRange(guid); else shownGUID = nil; end
  local done = guid and picked[guid] or false;
  local signature = guid and (guid .. "|" .. tostring(inRange) .. "|" .. tostring(done)) or nil;
  SetBinding(KeyCastsPickPocket());
  if signature == lastSignature then return end
  lastSignature = signature;
  local soft = UnitGUID("softinteract");
  if ns.OnSoftInteractChanged then ns.OnSoftInteractChanged(soft, soft, true); end
end

local function MarkPicked(guid)
  if not guid then return end
  picked[guid] = true;
  ClearPending();
  Refresh();
end

local function LootSourceMatches(guid)
  for slot = 1, (Known(GetNumLootItems()) or 0) do
    local sources = { GetLootSourceInfo(slot) };
    for i = 1, #sources, 2 do
      if Known(sources[i]) == guid then return true end
    end
  end
  return false;
end

local watcher = CreateFrame("Frame");
local sincePoll = 0;
watcher:SetScript("OnUpdate", function(_, elapsed)
  sincePoll = sincePoll + elapsed;
  if sincePoll < POLL_INTERVAL then return end
  sincePoll = 0;
  if Active() or lastSignature or boundKeys then Refresh(); end
end);
for _, event in ipairs({ "PLAYER_SOFT_ENEMY_CHANGED", "PLAYER_SOFT_INTERACT_CHANGED", "UPDATE_STEALTH", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "UPDATE_BINDINGS", "UI_ERROR_MESSAGE", "LOOT_READY", "SPELLS_CHANGED" }) do
  watcher:RegisterEvent(event);
end
-- The player's cast events and where each one's spell ID is.
local CAST_EVENTS = { UNIT_SPELLCAST_SENT = 4, UNIT_SPELLCAST_SUCCEEDED = 3, UNIT_SPELLCAST_FAILED = 3,
  UNIT_SPELLCAST_INTERRUPTED = 3 };
for event in pairs(CAST_EVENTS) do watcher:RegisterUnitEvent(event, "player"); end
local castToken = 0; --voids the miss timer of an earlier cast
watcher:SetScript("OnEvent", function(_, event, ...)
  local spellArg = CAST_EVENTS[event];
  if spellArg then
    if Known(select(spellArg, ...)) ~= PICK_POCKET then return end
    if event == "UNIT_SPELLCAST_SENT" then
      castToken = castToken + 1;
      pendingGUID, pendingUntil, pendingSucceeded = Known(UnitGUID("softenemy")), GetTime() + PICK_WINDOW, false;
      if pendingGUID and pendingGUID == shownGUID and ns.PlayTargetPulse then ns.PlayTargetPulse(); end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
      if not pendingGUID then return end
      pendingSucceeded = true;
      local token = castToken;
      C_Timer.After(MISS_WAIT, function()
        if token == castToken and pendingSucceeded then Missed(); Refresh(); end
      end);
    else
      ClearPending(); --a cast that never went out (moving, out of range) is not a miss
    end
    return;
  elseif event == "UI_ERROR_MESSAGE" then
    if Known((...)) == ERR_ALREADY_PICKED and pendingGUID and GetTime() <= pendingUntil then MarkPicked(pendingGUID); end
    return;
  elseif event == "LOOT_READY" then
    if pendingGUID and GetTime() <= pendingUntil and LootSourceMatches(pendingGUID) then
      PlayOutcome("success", pendingGUID);
      MarkPicked(pendingGUID);
    end
    return;
  elseif event == "PLAYER_REGEN_DISABLED" then
    if pendingSucceeded then Missed(); end --the NPC noticed before anything else said so
    combatStarted = true;
    SetBinding(false);
  elseif event == "PLAYER_REGEN_ENABLED" then
    combatStarted = false;
  end
  -- Stealth and combat change what Feat\Targeting.lua holds SoftTargetEnemy at.
  -- A new interact key changes KeysSignature, so Refresh binds it; the override itself leaves it unchanged.
  if event ~= "UPDATE_BINDINGS" and event ~= "PLAYER_SOFT_INTERACT_CHANGED" and ns.UpdateTargeting then ns.UpdateTargeting(); end
  Refresh();
end);

-- Called when Pick Pocket with Interact Key or Enabled changes.
function ns.UpdatePickPocket()
  if ns.UpdateTargeting then ns.UpdateTargeting(); end
  Refresh();
end

-- For the test tools.
ns.pickPocketState = { picked = picked, button = button, owner = bindingOwner };
