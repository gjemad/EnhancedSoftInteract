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
  local name = fileID and ns.cursorFileNames[fileID];
  return name and ns.ColorKeyFor("Cursor " .. name) or tostring(fileID), "file " .. tostring(fileID), name ~= nil;
end

-- Raw range evidence is sampled once per decision and also retained for diagnostic snapshots.
function ns.ReadTargetRange(cursor, lastInRangeTarget)
  local unit, guid = "softinteract", UnitGUID("softinteract");
  local spellRange = cursor and ns.SpellRangeCheck and ns.SpellRangeCheck(cursor, unit);
  return { name = UnitName(unit), guid = guid, cursor = cursor, interactRange = InInteractRange(),
    spellRange = spellRange, casting = UnitCastingInfo("player"), channeling = UnitChannelInfo("player"),
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
  local canInteract = interactRange;
  if spellRange ~= nil then canInteract = spellRange; end
  local busy = range.casting or range.channeling;
  if unable and (canInteract or (busy and knownTarget and knownTarget == lastInRangeTarget)) then Replace(unable); end
  local inRange = not ns.IsUnableKey(key);
  if inRange then lastInRangeTarget = knownTarget; end
  local cursor = key:match("^Cursor (.+)$");
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
    signature = key .. "|" .. tostring(talkBadge) .. "|" .. tostring(outOfRange),
    action = key:lower():gsub("unable", "") };
end
