local _, ns = ...;

-- The tooltip option enables or hides target tooltips; the icon option allows the player's settings.
-- The player's tooltip settings return when the addon is off; icon settings also return when checked.
-- SoftTargetNameplateSize controls the nameplate icon. Retail's floating object icon uses its own CVar.
-- On WoW: Forever the addon sets temp CVars, as Blizzard's gamepad mode does. The client never saves
-- those, and removing them brings the player's value back. Retail has no temp CVars, so the addon sets
-- the CVar and puts the player's value back at logout, before the client saves its settings. Blizzard's
-- nameplates need an explicit refresh after these CVar changes.
-- It skips CVars a client doesn't have (GetCVar gives nil).
local HIDDEN_CVARS = { "SoftTargetTooltipInteract", "SoftTargetTooltipEnemy", "SoftTargetNameplateSize" };
if select(4, GetBuildInfo()) >= 100000 then --Retail only
  HIDDEN_CVARS[#HIDDEN_CVARS + 1] = "SoftTargetIconGameObject";
end
ns.hiddenCVars = HIDDEN_CVARS;
local optionByCVar = {
  softtargettooltipinteract = "showBlizzardTooltip",
  softtargettooltipenemy = "showBlizzardTooltip",
  softtargetnameplatesize = "showBlizzardIcons",
  softtargeticongameobject = "showBlizzardIcons",
};
local watched = {};
for _, cvar in ipairs(HIDDEN_CVARS) do watched[cvar:lower()] = true; end
local SetTempCVar, RemoveTempCVar = C_CVar.SetTempCVar, C_CVar.RemoveTempCVar;
local playerValues = {}; --retail: each CVar's value from the player, from before the addon hid it
local hidden = {}; --Forever: the CVars the addon holds at a temp value

local function ShouldHide(cvar)
  local db = EnhancedSoftInteractDB;
  local key = cvar:lower();
  return db and db.enabled and watched[key] and not db[optionByCVar[key]];
end

-- Display hiding takes priority over Always Show All Interact Key Icons.
ns.IsBlizzardDisplayCVarHidden = ShouldHide;

local function RefreshNameplateIcons()
  local driver = NamePlateDriverFrame;
  if not (driver and driver.OnSoftTargetUpdate) then return end
  if CVarCallbackRegistry and CVarCallbackRegistry.ClearCache then
    CVarCallbackRegistry:ClearCache("SoftTargetNameplateSize");
  end
  driver:OnSoftTargetUpdate();
end

-- Blizzard's tooltip checkbox is a proxy for multiple CVars, so CVar changes alone do not refresh it.
local function RefreshTooltipSetting()
  local setting = Settings and Settings.GetSetting and Settings.GetSetting("PROXY_TARGET_TOOLTIP");
  if setting and setting.NotifyUpdate then setting:NotifyUpdate(); end
end

-- Setting a CVar fires CVAR_UPDATE synchronously, which calls this again; the guard stops that recursion.
local hiding = false;
local function HideBlizzardDisplays()
  if hiding then return end
  hiding = true;
  local tooltipChanged = false;
  for _, cvar in ipairs(HIDDEN_CVARS) do
    local value = GetCVar(cvar);
    local tooltip = optionByCVar[cvar:lower()] == "showBlizzardTooltip";
    local desired = ShouldHide(cvar) and "0" or nil;
    local db = EnhancedSoftInteractDB;
    if tooltip and db and db.enabled then desired = db.showBlizzardTooltip and "1" or "0"; end
    if desired and value ~= nil and value ~= desired then
      if tooltip then tooltipChanged = true; end
      if SetTempCVar then
        SetTempCVar(cvar, desired);
        hidden[cvar] = true;
      else
        playerValues[cvar] = tooltip and (playerValues[cvar] or value) or value;
        SetCVar(cvar, desired);
      end
    elseif not desired then
      if tooltip and (hidden[cvar] or playerValues[cvar]) then tooltipChanged = true; end
      if hidden[cvar] then RemoveTempCVar(cvar); hidden[cvar] = nil; end
      if playerValues[cvar] then SetCVar(cvar, playerValues[cvar]); playerValues[cvar] = nil; end
    end
  end
  RefreshNameplateIcons();
  if tooltipChanged then RefreshTooltipSetting(); end
  hiding = false;
end

local function RestorePlayerValues()
  hiding = true; --setting them fires CVAR_UPDATE, which would hide them again
  local tooltipChanged = hidden.SoftTargetTooltipInteract or playerValues.SoftTargetTooltipInteract
    or hidden.SoftTargetTooltipEnemy or playerValues.SoftTargetTooltipEnemy;
  for cvar in pairs(hidden) do RemoveTempCVar(cvar); end
  for cvar, value in pairs(playerValues) do SetCVar(cvar, value); end
  wipe(hidden);
  wipe(playerValues);
  RefreshNameplateIcons();
  if tooltipChanged then RefreshTooltipSetting(); end
  hiding = false;
end

-- Called when Enabled or either Show option changes.
ns.UpdateBlizzardDisplays = HideBlizzardDisplays;

-- Settings panels and Blizzard's gamepad mode can change these again; reapply the selected display mode.
local watcher = CreateFrame("Frame");
watcher:RegisterEvent("PLAYER_ENTERING_WORLD");
watcher:RegisterEvent("CVAR_UPDATE");
watcher:RegisterEvent("PLAYER_LOGOUT");
watcher:SetScript("OnEvent", function(_, event, name)
  if event == "CVAR_UPDATE" and (ns.issecretvalue(name) or type(name) ~= "string" or not watched[name:lower()]) then return end
  if event ~= "PLAYER_LOGOUT" then
    HideBlizzardDisplays();
  elseif not SetTempCVar then
    RestorePlayerValues();
    hiding = true; --the client saves its settings after this, so don't hide them again
  end
end);

table.insert(ns.onLoad, HideBlizzardDisplays);
