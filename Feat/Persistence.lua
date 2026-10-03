local _, ns = ...;
local Notify = ns.Notify;

----
--  Persistence: game settings the HUD needs, which the addon puts back when something changes them.
--  Turning the gamepad off can turn the Interact Key off with it, and the Interact Key Icons setting
--  (Options > Accessibility) decides which targets get a cursor at all; below Show All, corpses and
--  objects show the plain cog. While the addon is enabled and a setting's Keep option is checked, the
--  addon sets its CVars back and says so in chat. It checks on every CVar change and once every
--  CHECK_INTERVAL seconds, in case the game changes a CVar without telling addons. CVars a client
--  doesn't have (GetCVar gives nil) are skipped. While Forever's gamepad UI is on, Blizzard holds these
--  CVars at temporary values that SetCVar can't override, so the addon waits. When the gamepad UI ends,
--  Blizzard removes them, the saved values come back, and the addon corrects those.
----
local CHECK_INTERVAL = 1;

-- option: the EnhancedSoftInteractDB key of its Keep checkbox, which Feat\EditMode.lua builds from this
-- list with checkbox as its name. cvars: the values to keep, the way Blizzard's settings set them (Show
-- All is Blizzard_SettingsDefinitions_Frame\Accessibility.lua).
local KEPT = {
  {
    option = "forceInteractKey", checkbox = "Keep Interact Key On",
    restored = "Turned the Interact Key back on.", failed = "The Interact Key is off and couldn't be turned back on.",
    cvars = { softTargetInteract = Enum.SoftTargetEnableFlags.Any },
  },
  {
    option = "forceInteractIcons", checkbox = "Keep Interact Key Icons on Show All",
    restored = "Set Interact Key Icons back to Show All.", failed = "Interact Key Icons couldn't be set back to Show All.",
    cvars = { SoftTargetIconEnemy = 1, SoftTargetIconInteract = 1, SoftTargetIconGameObject = 1, SoftTargetLowPriorityIcons = 1 },
  },
};
ns.keptSettings = KEPT;
local watched = {}; --lowercase CVar name -> true, for CVAR_UPDATE
for _, kept in ipairs(KEPT) do
  for cvar in pairs(kept.cvars) do watched[cvar:lower()] = true; end
end

-- The CVars of a kept setting that differ from the values it keeps.
local function Changed(kept)
  local changed = {};
  for cvar, value in pairs(kept.cvars) do
    local current = GetCVar(cvar);
    if current ~= nil and tonumber(current) ~= value then changed[cvar] = value; end
  end
  return next(changed) and changed or nil;
end

-- silent: no chat message, for when the player just checked a Keep option or Enabled.
local function KeepSettings(silent)
  local db = EnhancedSoftInteractDB;
  if not (db and db.enabled) or (ns.IsGamepadUI and ns.IsGamepadUI()) then return end
  for _, kept in ipairs(KEPT) do
    local changed = db[kept.option] and Changed(kept);
    if not changed then
      kept.didFail = false;
    else
      for cvar, value in pairs(changed) do SetCVar(cvar, value); end
      local wasFailed = kept.didFail; --don't repeat the failure every check
      kept.didFail = Changed(kept) ~= nil;
      if not (silent or kept.didFail) then
        Notify(("%s To stop this, type /esi and uncheck %s."):format(kept.restored, kept.checkbox));
      elseif not silent and not wasFailed then
        Notify(kept.failed);
      end
    end
  end
end
ns.KeepSettings = KeepSettings;

local watcher = CreateFrame("Frame");
watcher:SetScript("OnEvent", function(_, _, name)
  if type(name) == "string" and watched[name:lower()] then KeepSettings(); end
end);

table.insert(ns.onLoad, function()
  KeepSettings();
  watcher:RegisterEvent("CVAR_UPDATE");
  C_Timer.NewTicker(CHECK_INTERVAL, function() KeepSettings(); end);
end);
