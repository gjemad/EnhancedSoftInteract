local _, ns = ...;
local issecretvalue = ns.issecretvalue;

-- Only WoW: Forever loads this file. It holds the Skinning range check and the gamepad UI's interact button.

-- Cursors whose interact range the game misreports, and the spell whose range check is right for them.
-- The check needs the name (spell ID 8613 gave nil for a higher rank), so the ID only localizes it.
-- Characters without the spell skip the check; then, or when it gives nil, UnitIsInInteractRange decides.
-- On skinnable corpses, the cursor stays UnableSkin and UnitIsInInteractRange stays false even where the
-- key skins (measured in game), but the Skinning spell's range check is right.
local RANGE_SPELLS = {
  Skin = {8613, "Skinning"},
};

-- Whether the unit is in range of the cursor's range spell, or nil when there is no answer.
function ns.SpellRangeCheck(cursorName, unit)
  local rangeSpell = RANGE_SPELLS[cursorName];
  local spellName = rangeSpell and (C_Spell.GetSpellName(rangeSpell[1]) or rangeSpell[2]);
  if not (spellName and C_SpellBook.FindSpellBookSlotForSpell(spellName)) then return nil end --learned, any rank
  local inRange = C_Spell.IsSpellInRange(spellName, unit);
  if issecretvalue(inRange) then return nil end
  return inRange;
end

-- Whether Forever's gamepad UI is on. While it is, Blizzard_Gamepad\Core.lua holds the soft target CVars
-- at its own temporary values.
function ns.IsGamepadUI()
  return C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad;
end

-- Forever's gamepad UI has a fixed interact button on its action bar, the left face button
-- (GAMEPAD_FACE_LEFT = PAD3; Blizzard_GamepadActionBars), not a key binding. Its glyph follows the
-- controller's label style, as Blizzard's InputDeviceIconSetManager picks it.
local FACE_LEFT_GLYPHS = { Generic = "Gen_3", Letters = "Ltr_X", Shapes = "Shp_Square", Reverse = "Rev_Y" };
function ns.GamepadInteractGlyph()
  if not ns.IsGamepadUI() then return nil end
  local mapped = C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID());
  local glyph = ("Gamepad_%s_64"):format(FACE_LEFT_GLYPHS[mapped and mapped.labelStyle] or "Gen_3");
  return C_Texture.GetAtlasInfo(glyph) and glyph or nil;
end

-- Switching between the mouse and keyboard UI and the gamepad UI updates the key cap.
local styleWatcher = CreateFrame("Frame");
styleWatcher:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION");
styleWatcher:SetScript("OnEvent", function() ns.RefreshKeyCap(); end);
