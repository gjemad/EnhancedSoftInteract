local _, ns = ...;

-- How far and where the game looks for soft interact targets: SoftTargetInteractRange and
-- SoftTargetInteractArc (0 straight ahead, 1 in a cone ahead, 2 the half circle in front). This file owns
-- both CVars.
--
-- While the addon is enabled, it holds them at Interaction Range and Interaction Arc. The player's own
-- value comes back when the addon is turned off, and at logout, so the client never saves an addon value.
-- The range is a secure CVar, so it can't change in combat; the arc can. A change blocked by combat
-- happens at PLAYER_REGEN_ENABLED. In Forever's gamepad UI the values are temporary CVars (ns.SetGameCVar).
local ARC, RANGE = "SoftTargetInteractArc", "SoftTargetInteractRange";

-- Each CVar with its setting.
local CVARS = {
  { cvar = ARC, setting = "interactArc" },
  { cvar = RANGE, setting = "interactRange" },
};

local original = {}; --CVar -> the player's value from before the addon changed it
local applying = false;

local function Has(cvar) return GetCVar(cvar) ~= nil end

function ns.TargetingAvailable() return Has(ARC) or Has(RANGE) end

-- The value the addon wants, or nil for the player's own.
local function Wanted(item)
  local db = EnhancedSoftInteractDB;
  if db and db.enabled then return db[item.setting] end
end

-- Secure CVars can't be changed in combat.
local function BlockedInCombat(cvar)
  if not InCombatLockdown() then return false end
  if C_CVar and C_CVar.GetCVarInfo then
    local _, _, _, _, _, secure = C_CVar.GetCVarInfo(cvar);
    return secure and true or false;
  end
  return cvar == RANGE;
end

-- Sets every CVar to the value wanted now, or back to the player's own.
local function Apply()
  if applying then return end
  applying = true; --setting a CVar fires CVAR_UPDATE, which calls this again
  for _, item in ipairs(CVARS) do
    local cvar = item.cvar;
    local current = Has(cvar) and tonumber(GetCVar(cvar));
    if current and not BlockedInCombat(cvar) then
      local want = Wanted(item);
      if want then
        if current ~= want then
          original[cvar] = original[cvar] or GetCVar(cvar);
          ns.SetGameCVar(cvar, want);
        end
      elseif original[cvar] then
        ns.SetGameCVar(cvar, original[cvar]);
        original[cvar] = nil;
      end
    end
  end
  applying = false;
end

-- Called when Enabled or a targeting setting changes.
ns.UpdateTargeting = Apply;

local watched = { [ARC:lower()] = true, [RANGE:lower()] = true };
local watcher = CreateFrame("Frame");
watcher:RegisterEvent("PLAYER_REGEN_ENABLED");
watcher:RegisterEvent("CVAR_UPDATE");
watcher:RegisterEvent("PLAYER_LOGOUT");
watcher:SetScript("OnEvent", function(_, event, name)
  if event == "CVAR_UPDATE" then
    -- Something else (the gamepad UI, the player) changed a value the addon holds: set it again.
    if not ns.issecretvalue(name) and type(name) == "string" and watched[name:lower()] then Apply(); end
  elseif event == "PLAYER_REGEN_ENABLED" then
    Apply();
  else
    -- Never leave an addon value in the saved settings.
    applying = true;
    for cvar, value in pairs(original) do ns.SetGameCVar(cvar, value); end
  end
end);

table.insert(ns.onLoad, Apply);
