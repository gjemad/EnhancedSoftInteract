local _, ns = ...;
local issecretvalue = ns.issecretvalue;
local SetUnitCursorTexture = SetUnitCursorTexture or function() return false end;

-- Target decisions have no dependency on HUD layout or animations. Reading the game's cursor requires
-- a texture; the caller supplies its icon. The result describes any replacement the renderer must draw.
local GENERIC_ICONS = { ["Cursor Interact"] = true, ["Cursor UnableInteract"] = true, default = true };
local CROSSHAIR_STYLE = Enum.CursorStyle and Enum.CursorStyle.Crosshair;

local function InInteractRange()
  if not UnitIsInInteractRange then return nil end
  return UnitIsInInteractRange("softinteract");
end

local function Accessible(value)
  if issecretvalue(value) then return nil end
  return value;
end

-- A looted object can report Unable while its loot window is open. Match actual loot sources so an
-- unrelated soft target never inherits that object's availability.
local lootOpen, lootSources = false, {};
-- Era kept UnableGatherHerbs for 152ms after LOOT_CLOSED in the captured trace. Allow one normal
-- range-check interval for that cursor to settle, only for the just-closed loot sources.
local LOOT_CLOSE_SETTLE = 0.2;
local closingSources, closingUntil, lootToken = {}, 0, 0;
local lootWatcher = CreateFrame("Frame");
function ns.LootSnapshot()
  local sources = {};
  for guid in pairs(lootSources) do sources[#sources + 1] = guid; end
  table.sort(sources);
  return { active = lootOpen, source_guids = sources };
end
local function AddLootSources(...)
  for i = 1, select("#", ...), 2 do
    local guid = Accessible(select(i, ...));
    if type(guid) == "string" then lootSources[guid] = true; end
  end
end
local function RefreshLootTarget()
  local guid = Accessible(UnitGUID("softinteract"));
  if guid and ns.OnSoftInteractChanged then ns.OnSoftInteractChanged(guid, guid); end
end
lootWatcher:RegisterEvent("LOOT_READY");
lootWatcher:RegisterEvent("LOOT_OPENED");
lootWatcher:RegisterEvent("LOOT_CLOSED");
lootWatcher:RegisterEvent("PLAYER_ENTERING_WORLD");
lootWatcher:SetScript("OnEvent", function(_, event)
  local before = ns.DebugLoot and ns.LootSnapshot();
  lootToken = lootToken + 1;
  local token = lootToken;
  if event == "LOOT_CLOSED" then
    closingSources, closingUntil = lootSources, GetTime() + LOOT_CLOSE_SETTLE;
    C_Timer.After(LOOT_CLOSE_SETTLE, function()
      if token ~= lootToken then return end
      closingSources, closingUntil = {}, 0;
      RefreshLootTarget();
    end);
  else
    closingSources, closingUntil = {}, 0;
  end
  lootSources = {};
  if event == "LOOT_CLOSED" or event == "PLAYER_ENTERING_WORLD" then
    lootOpen = false;
  else
    -- Sources are already available at LOOT_READY, before the window's opening event.
    lootOpen = true;
    local count = GetNumLootItems and Accessible(GetNumLootItems());
    if type(count) == "number" and GetLootSourceInfo then
      for slot = 1, count do AddLootSources(GetLootSourceInfo(slot)); end
    end
  end
  RefreshLootTarget();
  if ns.DebugLoot then ns.DebugLoot(event, before, ns.LootSnapshot()); end
end);

local function IsTalkableNPC()
  local unit = "softinteract";
  local player, attackable = UnitIsPlayer(unit), UnitCanAttack("player", unit);
  if issecretvalue(player) or issecretvalue(attackable) then return false end
  if not UnitExists(unit) or player or attackable then return false end
  if UnitIsGameObject then
    local object = UnitIsGameObject(unit);
    if issecretvalue(object) or object then return false end
  end
  if UnitIsInteractable then
    local interactable = UnitIsInteractable(unit);
    if issecretvalue(interactable) or not interactable then return false end
  end
  return true;
end

local function IdentifyCursor(icon)
  local atlas = icon:GetAtlas();
  if issecretvalue(atlas) then return "default", "secret", false end
  if atlas and atlas ~= "" then return ns.ColorKeyFor(atlas), "atlas " .. atlas, false end
  local path = icon:GetTextureFilePath();
  if issecretvalue(path) then return "default", "secret", false end
  if type(path) == "string" and ns.CursorName(path) then return ns.ColorKeyFor(path), "path " .. path, false end
  local fileID = icon:GetTextureFileID();
  if issecretvalue(fileID) then return "default", "secret", false end
  local key = fileID and ns.CursorKeyForFileID(fileID);
  return key or tostring(fileID), "file " .. tostring(fileID), key ~= nil;
end

-- Raw range evidence is sampled once per decision and also retained for diagnostic snapshots.
function ns.ReadTargetRange(cursor, lastInRangeTarget)
  local unit, guid = "softinteract", UnitGUID("softinteract");
  local spellRange = cursor and ns.SpellRangeCheck and ns.SpellRangeCheck(cursor, unit);
  return { name = UnitName(unit), guid = guid, cursor = cursor, interactRange = InInteractRange(),
    spellRange = spellRange, casting = UnitCastingInfo("player"), channeling = UnitChannelInfo("player"),
    looting = lootOpen and not issecretvalue(guid) and lootSources[guid] or false,
    loot_closing = GetTime() < closingUntil and not issecretvalue(guid) and closingSources[guid] or false,
    lastInRangeTarget = lastInRangeTarget };
end

function ns.ResolveTarget(icon, guid, lastInRangeTarget)
  local hasCursor = SetUnitCursorTexture(icon, "softinteract", CROSSHAIR_STYLE);
  local key, source, fromFileID;
  if hasCursor then key, source, fromFileID = IdentifyCursor(icon); else source, fromFileID = "none", false; end
  local knownTarget = not issecretvalue(guid) and guid or nil;
  local rawCursor = key and (key:match("^Cursor Unable(.+)$") or key:match("^Cursor (.+)$"));
  local range = ns.ReadTargetRange(rawCursor, lastInRangeTarget);
  local override;
  local function Replace(cursor)
    override, fromFileID = cursor, false;
    key = ns.ColorKeyFor("Cursor " .. cursor);
  end
  local interactRange, spellRange = Accessible(range.interactRange), Accessible(range.spellRange);
  if not hasCursor then Replace(interactRange == false and "UnableInteract" or "Interact"); end
  local resolvedKey = key;
  local unable = key:match("^Cursor Unable(.+)$");
  -- Release immediately when the native cursor recovers, so later movement is checked normally.
  if not unable and knownTarget then closingSources[knownTarget] = nil; end
  local canInteract = interactRange;
  if spellRange ~= nil then canInteract = spellRange; end
  local busy = range.casting or range.channeling;
  local settling = range.loot_closing and interactRange ~= false and spellRange ~= false;
  if unable and (canInteract or range.looting or settling
      or (busy and knownTarget and knownTarget == lastInRangeTarget)) then Replace(unable); end
  local inRange = not ns.IsUnableKey(key);
  if inRange then lastInRangeTarget = knownTarget; end
  local cursor = key:match("^Cursor Unable(.+)$") or key:match("^Cursor (.+)$");
  local requirement = cursor and ns.RequirementFor(cursor);
  if requirement then Replace("Unable" .. cursor); end
  local talkBadge = (not hasCursor or GENERIC_ICONS[key]) and IsTalkableNPC() or false;
  if talkBadge then
    if interactRange ~= nil then inRange = interactRange; end
    Replace(inRange and "Speak" or "UnableSpeak");
  end
  local outOfRange = not inRange;
  return { name = range.name, knownTarget = knownTarget, hasCursor = hasCursor, iconSource = source,
    iconFromFileID = fromFileID, resolvedKey = resolvedKey, iconKey = key, overrideCursor = override,
    talkBadge = talkBadge, outOfRange = outOfRange, range = range, inRangeTarget = lastInRangeTarget,
    requirementText = ns.IsUnableKey(key) and requirement or nil,
    signature = key .. "|" .. tostring(talkBadge) .. "|" .. tostring(outOfRange) .. "|" .. tostring(requirement),
    action = key:lower():gsub("unable", "") };
end
