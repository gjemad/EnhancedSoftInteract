local _, ns = ...;
local IsInteractKeyEnabled = ns.IsInteractKeyEnabled;

----
--  Turning the gamepad off can turn the Interact Key off with it, and the HUD needs the key. While the
--  addon is enabled and Keep Interact Key On (EnhancedSoftInteractDB.forceInteractKey) is checked, the
--  addon turns the key back on whenever it finds it off, and says so in chat. It checks on every change
--  to softTargetInteract and once every CHECK_INTERVAL seconds, in case the game changes the CVar
--  without telling addons.
----
local CHECK_INTERVAL = 1;
local failed = false; --the last try didn't stick; don't repeat the message every check

local function Say(msg) print("|cffffd100ESI:|r " .. msg) end

-- silent: no chat message, for when the player just asked for the key to be kept on.
local function KeepInteractKeyOn(silent)
  local db = EnhancedSoftInteractDB;
  if not (db and db.enabled and db.forceInteractKey) or IsInteractKeyEnabled() then
    failed = false;
    return;
  end
  SetCVar("softTargetInteract", Enum.SoftTargetEnableFlags.Any);
  local wasFailed = failed;
  failed = not IsInteractKeyEnabled();
  if silent then return end
  if not failed then
    Say("Turned the Interact Key back on. To stop this, type /esi and uncheck Keep Interact Key On.");
  elseif not wasFailed then
    Say("The Interact Key is off and couldn't be turned back on.");
  end
end
ns.KeepInteractKeyOn = KeepInteractKeyOn;

local watcher = CreateFrame("Frame");
watcher:SetScript("OnEvent", function(_, _, name)
  if type(name) == "string" and name:lower() == "softtargetinteract" then KeepInteractKeyOn(); end
end);

table.insert(ns.onLoad, function()
  KeepInteractKeyOn();
  watcher:RegisterEvent("CVAR_UPDATE");
  C_Timer.NewTicker(CHECK_INTERVAL, function() KeepInteractKeyOn(); end);
end);
