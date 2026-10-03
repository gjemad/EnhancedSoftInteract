local _, ns = ...;
local issecretvalue = issecretvalue or function() return false end;
local frame = ns.frame;

-- /esi debug: prints a block per soft target event, with what the game sent and what the HUD did with it.
-- Secret values (names and GUIDs in combat or instances) print as <secret>. Only tostring, concatenation
-- and string.format touch them, which secrets allow.
local debugCount, debugLastGUID = 0, nil;
local function Safe(v)
  if issecretvalue(v) then return "<secret>" end
  return tostring(v);
end

function ns.DebugSoftTarget(oldGUID, newGUID, hasCursor, rawPath, resolvedKey, iconKey, talkBadge, outOfRange)
  debugCount = debugCount + 1;
  local same = "unknown";
  if not issecretvalue(newGUID) then
    same = (newGUID == debugLastGUID) and "yes (repeat event)" or "no";
    debugLastGUID = newGUID;
  end
  local unit = "softInteract";
  local r, g, b = ns.GetTypeColor(iconKey, outOfRange);
  local hasColor = outOfRange or ns.IsUnableKey(iconKey) or ns.typeColors[iconKey];
  local p = "|cffffd100ESI debug #" .. debugCount .. "|r ";
  print(p .. ("event: old=%s new=%s sameTarget=%s source=%s"):format(Safe(oldGUID), Safe(newGUID), same,
    frame.fromRangeCheck and "range check" or "game event"));
  print(p .. ("unit: name=%s player=%s object=%s interactable=%s inRange=%s attackable=%s"):format(
    Safe(UnitName(unit)), Safe(UnitIsPlayer(unit)), Safe(UnitIsGameObject and UnitIsGameObject(unit)),
    Safe(UnitIsInteractable and UnitIsInteractable(unit)), Safe(UnitIsInInteractRange and UnitIsInInteractRange(unit)),
    Safe(UnitCanAttack("player", unit))));
  print(p .. ("icon: hasCursor=%s path=%s resolved=%s key=%s color=%.2f,%.2f,%.2f%s talkBadge=%s nudge=%d,%d outOfRange=%s"):format(
    tostring(hasCursor), Safe(rawPath), resolvedKey, iconKey, r, g, b, hasColor and "" or " (default, no entry)",
    tostring(talkBadge and true or false), frame.iconNudgeX or 0, frame.iconNudgeY or 0, tostring(outOfRange)));
  local keys = { GetBindingKey("INTERACTTARGET") };
  print(p .. ("key: bindings=%s gamepadActive=%s gamepadUI=%s glyph=%s"):format(
    #keys > 0 and table.concat(keys, ",") or "none", tostring(ns.gamepadActive),
    tostring(C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad or false),
    tostring(ns.GamepadInteractGlyph and ns.GamepadInteractGlyph())));
  local cap = frame.keyCap;
  print(p .. ("layout: width=%s nameColumn=%s height=%s key=%s keyCap=%s"):format(
    tostring(frame.boxWidth), tostring(frame.nameWidth), tostring(EnhancedSoftInteractDB.bgHeight),
    cap:IsShown() and Safe(cap.text:GetText()) or "hidden",
    cap:IsShown() and ("%.0fx%.0f"):format(cap.capWidth or 0, cap.capHeight or 0) or "-"));
end

ns.slashCommands.debug = function()
  frame.debugIcons = not frame.debugIcons;
  ns.Notify("debug output " .. (frame.debugIcons and "on" or "off") .. ".");
end
