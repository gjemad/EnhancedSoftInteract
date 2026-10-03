local _, ns = ...;

-- The HUD replaces Blizzard's soft target tooltip and nameplate, so the addon turns both off while it
-- runs, and the player's own settings return once it's disabled. On WoW: Forever it sets temp CVars, as
-- Blizzard's gamepad mode does, and the client never saves those. Retail has no temp CVars, so the addon
-- sets the CVar, remembers the player's value and puts it back at logout, before the client saves its
-- settings. It skips CVars a client doesn't have (GetCVar gives nil).
local HIDDEN_CVARS = { "SoftTargetTooltipInteract", "SoftTargetNameplateInteract" };
local SetTempCVar = C_CVar.SetTempCVar;
local playerValues = {}; --retail: each CVar's value from the player, restored at logout

-- Setting a CVar fires CVAR_UPDATE synchronously, which calls this again; the guard stops that recursion.
local hiding = false;
local function HideBlizzardDisplays()
  if hiding then return end
  hiding = true;
  for _, cvar in ipairs(HIDDEN_CVARS) do
    local value = GetCVar(cvar);
    if value ~= nil and value ~= "0" then
      if SetTempCVar then
        SetTempCVar(cvar, "0");
      else
        playerValues[cvar] = value; --also catches a change the player made in the settings meanwhile
        SetCVar(cvar, "0");
      end
    end
  end
  hiding = false;
end

local function RestorePlayerValues()
  hiding = true; --don't hide them again
  for cvar, value in pairs(playerValues) do SetCVar(cvar, value); end
end

-- Settings panels and Blizzard's gamepad mode can set these again; turn them back off.
local watcher = CreateFrame("Frame");
watcher:RegisterEvent("PLAYER_ENTERING_WORLD");
watcher:RegisterEvent("CVAR_UPDATE");
watcher:RegisterEvent("PLAYER_LOGOUT");
watcher:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGOUT" then RestorePlayerValues(); else HideBlizzardDisplays(); end
end);

table.insert(ns.onLoad, HideBlizzardDisplays);
