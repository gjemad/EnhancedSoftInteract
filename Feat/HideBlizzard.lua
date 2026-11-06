local _, ns = ...;

-- The tooltip option enables or hides target tooltips; the icon option allows the player's settings.
-- The player's tooltip settings return when the addon is off; icon settings also return when checked.
-- SoftTargetNameplateSize controls the nameplate icon. On the mainline UI (WoW: Forever and Retail) the
-- floating object icon uses its own CVar.
-- On WoW: Forever the addon sets temp CVars, as Blizzard's gamepad mode does. The client never saves
-- those, and removing them brings the player's value back. Retail has no temp CVars, so the addon sets
-- the CVar and puts the player's value back at logout, before the client saves its settings. Blizzard's
-- nameplates need an explicit refresh after these CVar changes.
-- It skips CVars a client doesn't have (GetCVar gives nil).
-- On the mainline UI an object can have no nameplate with its icons off, and Show Object Names and the target
-- loot effect need one. While one of them is on, SoftTargetIconGameObject stays on and Feat\ObjectNames.lua makes
-- the icon invisible.
-- An NPC's icon can have no plate, and only SoftTargetIconInteract turns that one off. The mainline UI
-- can show NPC and object icons separately; other clients only have the size CVar, so both go together.
local HIDDEN_CVARS = { "SoftTargetTooltipInteract", "SoftTargetTooltipEnemy", "SoftTargetNameplateSize" };
local build = select(4, GetBuildInfo());
if build >= 100000 or (build >= 16000 and build < 20000) then --mainline UI only
  HIDDEN_CVARS[#HIDDEN_CVARS + 1] = "SoftTargetIconGameObject";
  HIDDEN_CVARS[#HIDDEN_CVARS + 1] = "SoftTargetIconInteract";
  ns.SeparateTargetIcons = true;
end
ns.hiddenCVars = HIDDEN_CVARS;
-- Plumber's Nameplate: Soft Target module draws its own icon and name, and needs SoftTargetIconGameObject
-- on. While it's on the icon CVars stay the player's, and the settings page locks the options for them.
-- PlumberDB is nil until Plumber loads, after this addon.
function ns.PlumberOwnsTargetIcons()
  local plumber = _G.PlumberDB;
  return ns.SeparateTargetIcons and plumber and plumber.SoftTargetName == true or false;
end

-- Plater draws an object's name with these two settings off, and needs the object to keep its plate.
function ns.PlaterDrawsObjectNames()
  local plater = _G.Plater;
  local profile = plater and plater.db and plater.db.profile;
  return ns.SeparateTargetIcons and profile and not profile.hide_name_on_game_objects
    and not profile.ignore_softinteract_objects or false;
end

-- The text for the settings page: which addon settings conflict, one paragraph each.
function ns.DisplayConflictText()
  local L = ns.L;
  local text = L.CONFLICT_INTRO;
  if ns.PlumberOwnsTargetIcons() then text = text .. "\n\n" .. L.CONFLICT_PLUMBER; end
  if ns.PlaterDrawsObjectNames() then text = text .. "\n\n" .. L.CONFLICT_PLATER; end
  if ns.ForeverLootSparklesOwnsTargeting() then text = text .. "\n\n" .. L.CONFLICT_FOREVER_LOOT_SPARKLES_TARGETING; end
  if ns.ForeverLootSparklesOwnsQuestEffect() then text = text .. "\n\n" .. L.CONFLICT_FOREVER_LOOT_SPARKLES_QUEST; end
  return text;
end
local function TooltipHidden(db) return not db.showBlizzardTooltip end
local hiddenWhen = {
  softtargettooltipinteract = TooltipHidden,
  softtargettooltipenemy = TooltipHidden,
  softtargetnameplatesize = function(db) return not db.showNpcIcons and not db.showObjectIcons and not ns.PlumberOwnsTargetIcons() end,
  softtargeticongameobject = function(db) return not db.showObjectIcons and not ns.PlumberOwnsTargetIcons() end,
  softtargeticoninteract = function(db) return not db.showNpcIcons and not ns.PlumberOwnsTargetIcons() end,
};
local watched = {};
for _, cvar in ipairs(HIDDEN_CVARS) do watched[cvar:lower()] = true; end
local SetTempCVar, RemoveTempCVar = C_CVar.SetTempCVar, C_CVar.RemoveTempCVar;
local playerValues = {}; --retail: each CVar's value from the player, from before the addon hid it
local hidden = {}; --Forever: the CVars the addon holds at a temp value
local applied = {}; --retail: the value the addon last set, which is never the player's own

local function ShouldHide(cvar)
  local db = EnhancedSoftInteractDB;
  local key = cvar:lower();
  return db and db.enabled and watched[key] and hiddenWhen[key](db);
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
local plumberOwned, platerDraws;
local function HideBlizzardDisplays()
  if hiding then return end
  hiding = true;
  plumberOwned, platerDraws = ns.PlumberOwnsTargetIcons(), ns.PlaterDrawsObjectNames();
  local tooltipChanged = false;
  for _, cvar in ipairs(HIDDEN_CVARS) do
    local value = GetCVar(cvar);
    local tooltip = hiddenWhen[cvar:lower()] == TooltipHidden;
    local desired = ShouldHide(cvar) and "0" or nil;
    local db = EnhancedSoftInteractDB;
    if desired and cvar == "SoftTargetIconGameObject" and (db.showObjectNames or platerDraws
      or (ns.LootEffectNeedsObjectPlates and ns.LootEffectNeedsObjectPlates(db))) then desired = "1"; end
    if tooltip and db and db.enabled then desired = db.showBlizzardTooltip and "1" or "0"; end
    if desired and value ~= nil and value ~= desired then
      if tooltip then tooltipChanged = true; end
      if SetTempCVar then
        SetTempCVar(cvar, desired);
        hidden[cvar] = true;
      else
        local ours = tooltip or value == applied[cvar];
        playerValues[cvar] = ours and (playerValues[cvar] or value) or value;
        applied[cvar] = desired;
        SetCVar(cvar, desired);
      end
    elseif not desired then
      if tooltip and (hidden[cvar] or playerValues[cvar]) then tooltipChanged = true; end
      if hidden[cvar] then RemoveTempCVar(cvar); hidden[cvar] = nil; end
      if playerValues[cvar] then SetCVar(cvar, playerValues[cvar]); playerValues[cvar] = nil; end
      applied[cvar] = nil;
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
  wipe(applied);
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
watcher:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED"); --neither addon has an event for its setting changing
watcher:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_SOFT_INTERACT_CHANGED" and ns.PlumberOwnsTargetIcons() == plumberOwned
    and ns.PlaterDrawsObjectNames() == platerDraws then return end
  if event == "CVAR_UPDATE" and (ns.issecretvalue(name) or type(name) ~= "string" or not watched[name:lower()]) then return end
  if event ~= "PLAYER_LOGOUT" then
    HideBlizzardDisplays();
  elseif not SetTempCVar then
    RestorePlayerValues();
    hiding = true; --the client saves its settings after this, so don't hide them again
  end
end);

table.insert(ns.onLoad, HideBlizzardDisplays);
