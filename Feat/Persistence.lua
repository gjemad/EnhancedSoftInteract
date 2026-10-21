local _, ns = ...;

----
--  Persistence: game settings the HUD needs, which the addon puts back when something changes them.
--  Turning the gamepad off can turn the Interact Key off with it, and the Interact Key Icons setting
--  (Options > Accessibility) decides which targets get a cursor at all; below Show All, corpses and
--  objects show the plain cog. While the addon is enabled and a setting's Always option is checked, the
--  addon sets its CVars back. Native option changes explain which checkbox controls them; automatic
--  gamepad changes stay quiet. It checks on every CVar change and once every CHECK_INTERVAL seconds, in case the
--  game changes a CVar without telling addons. CVars a client doesn't have (GetCVar gives nil) are
--  skipped. While Forever's gamepad UI is on, Blizzard holds these CVars at temporary values (Interact
--  Key on gamepad only), so the addon sets its own temporary values over them. When the gamepad UI
--  ends, Blizzard removes the temporary values, the saved values come back, and the addon corrects those.
----
local CHECK_INTERVAL = 1;

-- option: the EnhancedSoftInteractDB key of its Always checkbox, which Feat\SettingsDefinitions.lua builds from this
-- list with checkbox as its name and desc as its tooltip, under Enabled. cvars: the values to keep, the way Blizzard's settings set them (Show
-- All is Blizzard_SettingsDefinitions_Frame\Accessibility.lua). notice: the chat line after the addon
-- undoes a change in the game's options, with the game's option name and the checkbox.
local KEPT = {
  {
    option = "forceInteractKey", checkbox = "Always Enable Interact Key",
    desc = "Turns the game's interact key back on if something turns it off.",
    notice = '"%s" was turned back on. To turn it off, first uncheck "%s" in /esi.',
    setting = "PROXY_ENABLE_INTERACT", value = true, name = "Enable Interact Key",
    cvars = { softTargetInteract = Enum.SoftTargetEnableFlags.Any },
  },
  {
    option = "forceInteractIcons", checkbox = "Always Show All Interact Key Icons",
    desc = "Keeps the game's Interact Key Icons on Show All, so the HUD can show the right icon for every target.",
    notice = '"%s" was set back to Show All. To change it, first uncheck "%s" in /esi.',
    setting = "PROXY_INTERACT_ICONS", value = 2, name = "Interact Key Icons",
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

ns.SetGameCVar = SetBack; --also used by Feat\Targeting.lua

local restoring = false;
local function KeepSettings()
  local db = EnhancedSoftInteractDB;
  if restoring or not (db and db.enabled) then return end
  restoring = true;
  for _, kept in ipairs(KEPT) do
    if db[kept.option] then
      for cvar, value in pairs(kept.cvars) do
        if not ns.IsBlizzardDisplayCVarHidden(cvar) then
          local current = GetCVar(cvar);
          if current ~= nil and tonumber(current) ~= value then SetBack(cvar, value); end
        end
      end
    end
  end
  restoring = false;
end
ns.KeepSettings = KeepSettings;

-- CVAR_UPDATE has no source: Blizzard's automatic gamepad changes look like player changes there.
-- These native proxies retain the requested choice even when our synchronous restoration wins.
-- Refreshes/no-op choices already agree with GetValue, even when display hiding owns an icon CVar.
local noticesRegistered = false;
local function RegisterNotices()
  if noticesRegistered then return true end
  if not (Settings and Settings.SetOnValueChangedCallback) then return false end
  for _, kept in ipairs(KEPT) do
    Settings.SetOnValueChangedCallback(kept.setting, function(_, setting, value)
      local db = EnhancedSoftInteractDB;
      if restoring or not (db and db.enabled and db[kept.option])
        or ns.issecretvalue(value) or type(value) ~= type(kept.value) or value == kept.value then return end
      local current = setting and setting.GetValue and setting:GetValue();
      if not ns.issecretvalue(current) and current == value then return end
      local applicable = false;
      for cvar in pairs(kept.cvars) do
        if GetCVar(cvar) ~= nil and not ns.IsBlizzardDisplayCVarHidden(cvar) then applicable = true; break end
      end
      if not applicable then return end
      local name = setting and setting.GetName and setting:GetName();
      if ns.issecretvalue(name) or type(name) ~= "string" or name == "" then name = kept.name; end
      ns.Notify(kept.notice:format(name, kept.checkbox));
    end);
  end
  noticesRegistered = true;
  return true;
end

local watcher = CreateFrame("Frame");
watcher:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" then
    if RegisterNotices() then watcher:UnregisterEvent("ADDON_LOADED"); end
  elseif not ns.issecretvalue(name) and type(name) == "string" and watched[name:lower()] then
    KeepSettings();
  end
end);

table.insert(ns.onLoad, function()
  KeepSettings();
  if not RegisterNotices() then watcher:RegisterEvent("ADDON_LOADED"); end
  watcher:RegisterEvent("CVAR_UPDATE");
  C_Timer.NewTicker(CHECK_INTERVAL, KeepSettings);
end);

----
--  The game's own Interact Key Sound Cue checkbox, set the way Blizzard's settings set it
--  (Blizzard_SettingsDefinitions_Frame\Controls.lua). It is nil on a client without the CVar.
----
local SOUND_CVAR = "softTargettingInteractKeySound";
if GetCVar(SOUND_CVAR) ~= nil then
  ns.gameInteractSound = {
    Get = function() return GetCVar(SOUND_CVAR) == "1" end,
    Set = function(on) SetCVar(SOUND_CVAR, on and 1 or 0); end,
    Default = function() return C_CVar.GetCVarDefault ~= nil and C_CVar.GetCVarDefault(SOUND_CVAR) == "1" end,
  };
end
