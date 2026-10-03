local _, ns = ...;

----
--  Persistence: game settings the HUD needs, which the addon puts back when something changes them.
--  Turning the gamepad off can turn the Interact Key off with it, and the Interact Key Icons setting
--  (Options > Accessibility) decides which targets get a cursor at all; below Show All, corpses and
--  objects show the plain cog. While the addon is enabled and a setting's Keep option is checked, the
--  addon sets its CVars back. It says nothing in chat, because the gamepad UI turns the Interact Key off
--  on every NPC conversation. It checks on every CVar change and once every CHECK_INTERVAL seconds, in case the
--  game changes a CVar without telling addons. CVars a client doesn't have (GetCVar gives nil) are
--  skipped. While Forever's gamepad UI is on, Blizzard holds these CVars at temporary values (Interact
--  Key on gamepad only), so the addon sets its own temporary values over them. When the gamepad UI
--  ends, Blizzard removes the temporary values, the saved values come back, and the addon corrects those.
----
local CHECK_INTERVAL = 1;

-- option: the EnhancedSoftInteractDB key of its Keep checkbox, which Feat\EditMode.lua builds from this
-- list with checkbox as its name. cvars: the values to keep, the way Blizzard's settings set them (Show
-- All is Blizzard_SettingsDefinitions_Frame\Accessibility.lua).
local KEPT = {
  {
    option = "forceInteractKey", checkbox = "Keep Interact Key On",
    cvars = { softTargetInteract = Enum.SoftTargetEnableFlags.Any },
  },
  {
    option = "forceInteractIcons", checkbox = "Keep Interact Key Icons on Show All",
    cvars = { SoftTargetIconEnemy = 1, SoftTargetIconInteract = 1, SoftTargetIconGameObject = 1, SoftTargetLowPriorityIcons = 1 },
  },
};
ns.keptSettings = KEPT;
local watched = {}; --lowercase CVar name -> true, for CVAR_UPDATE
for _, kept in ipairs(KEPT) do
  for cvar in pairs(kept.cvars) do watched[cvar:lower()] = true; end
end

-- Sets a CVar back. During the gamepad UI a temporary value replaces Blizzard's temporary one.
local SetTempCVar = C_CVar.SetTempCVar;
local function SetBack(cvar, value)
  if SetTempCVar and ns.IsGamepadUI and ns.IsGamepadUI() then
    SetTempCVar(cvar, value);
  else
    SetCVar(cvar, value);
  end
end

local function KeepSettings()
  local db = EnhancedSoftInteractDB;
  if not (db and db.enabled) then return end
  for _, kept in ipairs(KEPT) do
    if db[kept.option] then
      for cvar, value in pairs(kept.cvars) do
        local current = GetCVar(cvar);
        if current ~= nil and tonumber(current) ~= value then SetBack(cvar, value); end
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
  C_Timer.NewTicker(CHECK_INTERVAL, KeepSettings);
end);
