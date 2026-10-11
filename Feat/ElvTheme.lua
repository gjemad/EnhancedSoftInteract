local _, ns = ...;
local watcher = CreateFrame("Frame");
local hooked, pending;

-- A single deferred refresh coalesces media/profile/scale changes; no theme polling runs in the HUD.
local function Refresh()
  if pending then return end
  pending = true;
  C_Timer.After(0, function()
    pending = nil;
    if EnhancedSoftInteractDB and EnhancedSoftInteractDB.hudStyle == "elv" then
      ns.UpdateStyle();
      if ns.RefreshSettings then ns.RefreshSettings(); end
    end
  end);
end

local function Connect()
  local suite = _G.ElvUI;
  local engine = type(suite) == "table" and suite[1];
  if type(engine) ~= "table" or engine == hooked or type(engine.UpdateMedia) ~= "function" then return end
  hooked = engine;
  hooksecurefunc(engine, "UpdateMedia", Refresh);
  Refresh();
end

watcher:RegisterEvent("PLAYER_LOGIN");
watcher:RegisterEvent("ADDON_LOADED");
watcher:RegisterEvent("UI_SCALE_CHANGED");
watcher:RegisterEvent("DISPLAY_SIZE_CHANGED");
watcher:SetScript("OnEvent", function(_, event, addon)
  if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and addon == "ElvUI") then Connect(); end
  if event ~= "ADDON_LOADED" then Refresh(); end
end);
ns.onLoad[#ns.onLoad + 1] = Connect;
