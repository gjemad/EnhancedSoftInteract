local _, ns = ...;

-- The interact key's text ("F", "s-F"), or nil when it's unbound. While a controller is the active input
-- (GAME_PAD_ACTIVE_CHANGED), a gamepad binding ("PAD1", "PADLTRIGGER-PAD1") wins over a keyboard one.
-- WoW: Forever's gamepad UI has a fixed interact button instead of a binding; ns.GamepadInteractGlyph
-- (Feat\Gamepad_Camelot.lua) returns its glyph while that UI is on.
ns.gamepadActive = false;
local function IsPadKey(key) return key:find("^PAD") ~= nil or key:find("%-PAD") ~= nil end
-- Also returns the key itself ("F", "SHIFT-F", "PAD3"), which KeyWatcher checks. The gamepad UI's
-- interact button is the left face button, GAMEPAD_FACE_LEFT.
local function GetInteractKeyText()
  local glyph = ns.GamepadInteractGlyph and ns.GamepadInteractGlyph();
  if glyph then return "|A:" .. glyph .. ":14:14|a", GAMEPAD_FACE_LEFT or "PAD3" end
  local keys = { GetBindingKey("INTERACTTARGET") };
  local key = keys[1];
  for _, k in ipairs(keys) do
    if IsPadKey(k) == ns.gamepadActive then key = k; break end
  end
  if not key then return nil end
  local text = GetBindingText(key, 1); --same compact, localized labels as Blizzard action buttons
  if not text or text == "" then return nil end
  return text, key;
end

-- Whether a key chord is held: its key and every modifier in it ("SHIFT-F", "PADLTRIGGER-PAD1"). A chord
-- whose key is the minus key ends in "-" ("SHIFT--").
local MODIFIER_DOWN = { ALT = IsAltKeyDown, CTRL = IsControlKeyDown, SHIFT = IsShiftKeyDown, META = IsMetaKeyDown };
local function IsChordDown(chord)
  local key = chord:match("%-(%-)$") or chord:match("([^%-]+)$") or chord;
  for modifier in chord:sub(1, #chord - #key):gmatch("([^%-]+)%-") do
    local isDown = MODIFIER_DOWN[modifier];
    if isDown then
      if not isDown() then return false end
    elseif not IsKeyDown(modifier) then
      return false;
    end
  end
  return IsKeyDown(key) and true or false;
end

-- Puts key in the action's slot (1 or 2), or clears the slot when key is nil. The other slot keeps its
-- key. A key taken from another action is named in chat, since the game unbinds it there.
local function SetBindingSlot(action, slot, key)
  if InCombatLockdown() then ns.Notify("Key bindings can't change during combat."); return end
  local keys = { GetBindingKey(action) };
  local wanted = { keys[1], keys[2] };
  for i = 1, 2 do if wanted[i] == key then wanted[i] = nil; end end
  wanted[slot] = key;
  for _, old in ipairs(keys) do SetBinding(old, nil); end
  if key then
    local previous = GetBindingAction(key);
    if previous ~= "" and previous ~= action then
      SetBinding(key, nil);
      ns.Notify(('%s no longer does "%s".'):format(GetBindingText(key), _G["BINDING_NAME_" .. previous] or previous));
    end
  end
  for i = 1, 2 do if wanted[i] then SetBinding(wanted[i], action); end end
  SaveBindings(GetCurrentBindingSet());
end

ns.GetInteractKeyText, ns.IsChordDown, ns.SetBindingSlot = GetInteractKeyText, IsChordDown, SetBindingSlot;
