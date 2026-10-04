local _, ns = ...;

-- The interact key's text ("F", "s-F"), or nil when it's unbound. While a controller is the active input
-- (GAME_PAD_ACTIVE_CHANGED), a gamepad binding ("PAD1", "PADLTRIGGER-PAD1") wins over a keyboard one.
-- WoW: Forever's gamepad UI has a fixed interact button instead of a binding; ns.GamepadInteractGlyph
-- (Feat\Forever.lua) returns its glyph while that UI is on.
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
  local text = GetBindingText(key, 1);
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

ns.GetInteractKeyText, ns.IsChordDown = GetInteractKeyText, IsChordDown;
