local _, ns = ...;

-- Only WoW: Forever loads this file. A client that recognizes none of the TOC's game types loads it
-- anyway, so check the build too.
local build = select(4, GetBuildInfo());
if build < 16000 or build >= 20000 then return end

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
