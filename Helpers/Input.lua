local _, ns = ...;

-- The interact key's text ("F", "s-F"), or nil when it's unbound. While a controller is the active input
-- (GAME_PAD_ACTIVE_CHANGED), a gamepad binding ("PAD1", "PADLTRIGGER-PAD1") wins over a keyboard one.
-- WoW: Forever's gamepad UI has a fixed interact button instead of a binding; ns.GamepadInteractGlyph
-- (Feat\Gamepad_Camelot.lua) returns its glyph while that UI is on.
ns.gamepadActive = false;
local function IsPadKey(key) return key:find("^PAD") ~= nil or key:find("%-PAD") ~= nil end
-- The game has no short label for numpad keys: GetBindingText gives "Num Pad 3" even when abbreviating,
-- too wide for the button, so the base key's label becomes "N3". The modifier part stays the game's.
local NUMPAD_SYMBOLS = { DECIMAL = ".", DIVIDE = "/", MINUS = "-", MULTIPLY = "*", PLUS = "+" };
local function ShortKeyText(key, text)
  local base = key:match("%-(%-)$") or key:match("([^%-]+)$") or key;
  local which = base:match("^NUMPAD(.+)$");
  local symbol = which and (which:match("^%d$") or NUMPAD_SYMBOLS[which]);
  if not symbol then return text end
  local long = GetBindingText(base, 1);
  if not long or long == "" or text:sub(-#long) ~= long then return text end
  return text:sub(1, #text - #long) .. ns.L.HUD_KEY_NUMPAD:format(symbol);
end

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
  return ShortKeyText(key, text), key;
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

local function NotifyUnbound(key, action)
  ns.Notify(ns.L.CHAT_KEY_UNBOUND:format(GetBindingText(key), _G["BINDING_NAME_" .. action] or action));
end

-- Puts key in the action's slot (1 or 2), or clears the slot when key is nil. The other slot keeps its
-- key. A key taken from another action is named in chat, since the game unbinds it there.
local function SetBindingSlot(action, slot, key)
  if InCombatLockdown() then ns.Notify(ns.L.CHAT_BINDINGS_IN_COMBAT); return end
  local keys = { GetBindingKey(action) };
  local wanted = { keys[1], keys[2] };
  for i = 1, 2 do if wanted[i] == key then wanted[i] = nil; end end
  wanted[slot] = key;
  for _, old in ipairs(keys) do SetBinding(old, nil); end
  if key then
    local previous = GetBindingAction(key);
    if previous ~= "" and previous ~= action then
      SetBinding(key, nil);
      NotifyUnbound(key, previous);
    end
  end
  for i = 1, 2 do if wanted[i] then SetBinding(wanted[i], action); end end
  SaveBindings(GetCurrentBindingSet());
end

-- The warning for an interact key whose Auto Loot Key chord is bound to another action. Only
-- checks keys without a modifier of their own. Also returns the chord when SetBinding can clear it (an
-- override binding from an addon can't be cleared that way) and the tooltip text.
function ns.AutoLootConflictText()
  local modifier = GetModifiedClick("AUTOLOOTTOGGLE");
  if not modifier or modifier == "NONE" then return end
  for _, key in ipairs({ GetBindingKey("INTERACTTARGET") }) do
    if not key:find(".%-") then
      local chord = modifier .. "-" .. key;
      local action = GetBindingAction(chord, true);
      if action ~= "" and action ~= "INTERACTTARGET" then
        local name = _G["BINDING_NAME_" .. action] or action;
        local chordText = GetBindingText(chord);
        local clearable = GetBindingAction(chord) == action;
        return ns.L.OPTION_AUTO_LOOT_CONFLICT_TEXT:format(chordText, name),
          clearable and chord or nil,
          ns.L.OPTION_AUTO_LOOT_CONFLICT_DESC:format(modifier, GetBindingText(key))
            .. (clearable and " " .. ns.L.OPTION_AUTO_LOOT_CONFLICT_CLEAR_DESC:format(name, chordText) or "");
      end
    end
  end
end

function ns.ClearAutoLootConflict()
  if InCombatLockdown() then ns.Notify(ns.L.CHAT_BINDINGS_IN_COMBAT); return end
  local _, chord = ns.AutoLootConflictText();
  if not chord then return end
  local action = GetBindingAction(chord);
  SetBinding(chord, nil);
  SaveBindings(GetCurrentBindingSet());
  NotifyUnbound(chord, action);
end

ns.GetInteractKeyText, ns.IsChordDown, ns.SetBindingSlot = GetInteractKeyText, IsChordDown, SetBindingSlot;
