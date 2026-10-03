local _, ns = ...;

-- The HUD replaces Blizzard's soft target tooltip and nameplate, and the icon Blizzard's nameplates draw
-- above the target, so the addon turns them off while it runs, and the player's own settings return once
-- it's disabled. The nameplate icon only shows while SoftTargetNameplateSize is above 0
-- (Blizzard_NamePlates.lua); the icon CVars that give the HUD its cursor stay as they are.
-- On WoW: Forever the addon sets temp CVars, as Blizzard's gamepad mode does. The client never saves
-- those, and removing them brings the player's value back. Retail has no temp CVars, so the addon sets
-- the CVar and puts the player's value back at logout, before the client saves its settings. Both put
-- the player's value back when you uncheck Enabled in Edit Mode. It skips CVars a client doesn't have
-- (GetCVar gives nil).
local HIDDEN_CVARS = { "SoftTargetTooltipInteract", "SoftTargetNameplateInteract", "SoftTargetNameplateSize" };
local SetTempCVar, RemoveTempCVar = C_CVar.SetTempCVar, C_CVar.RemoveTempCVar;
local playerValues = {}; --retail: each CVar's value from the player, from before the addon hid it
local hidden = {}; --Forever: the CVars the addon holds at a temp value

-- Setting a CVar fires CVAR_UPDATE synchronously, which calls this again; the guard stops that recursion.
local hiding = false;
local function HideBlizzardDisplays()
  local db = EnhancedSoftInteractDB;
  if hiding or not (db and db.enabled) then return end
  hiding = true;
  for _, cvar in ipairs(HIDDEN_CVARS) do
    local value = GetCVar(cvar);
    if value ~= nil and value ~= "0" then
      if SetTempCVar then
        SetTempCVar(cvar, "0");
        hidden[cvar] = true;
      else
        playerValues[cvar] = value; --also catches a change the player made in the settings meanwhile
        SetCVar(cvar, "0");
      end
    end
  end
  hiding = false;
end

local function RestorePlayerValues()
  hiding = true; --setting them fires CVAR_UPDATE, which would hide them again
  for cvar in pairs(hidden) do RemoveTempCVar(cvar); end
  for cvar, value in pairs(playerValues) do SetCVar(cvar, value); end
  wipe(hidden);
  wipe(playerValues);
  hiding = false;
end

-- Called when Enabled changes.
function ns.UpdateBlizzardDisplays()
  if EnhancedSoftInteractDB.enabled then HideBlizzardDisplays(); else RestorePlayerValues(); end
end

-- Settings panels and Blizzard's gamepad mode can set these again; turn them back off.
local watcher = CreateFrame("Frame");
watcher:RegisterEvent("PLAYER_ENTERING_WORLD");
watcher:RegisterEvent("CVAR_UPDATE");
watcher:RegisterEvent("PLAYER_LOGOUT");
watcher:SetScript("OnEvent", function(_, event)
  if event ~= "PLAYER_LOGOUT" then
    HideBlizzardDisplays();
  elseif not SetTempCVar then
    RestorePlayerValues();
    hiding = true; --the client saves its settings after this, so don't hide them again
  end
end);

table.insert(ns.onLoad, HideBlizzardDisplays);
