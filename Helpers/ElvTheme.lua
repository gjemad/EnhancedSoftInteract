local _, ns = ...;
local theme = {};
ns.ElvTheme = theme;

-- ElvUI's engine table, or nil when ElvUI isn't loaded.
local function Engine()
  local suite = _G.ElvUI;
  local engine = type(suite) == "table" and suite[1];
  return type(engine) == "table" and engine or nil;
end

-- Read resolved media: ElvUI applies profile and class-color choices before publishing these values.
function theme.Media()
  local engine = Engine();
  return engine and type(engine.media) == "table" and engine.media or nil;
end

function theme.Font(db)
  local data = theme.Media();
  return data and data.normFont or ns.media:Fetch("font", db.elvFont);
end

-- The font name ElvUI's general options choose, else the Elv style's own font setting.
function theme.FontName(db)
  local engine = Engine();
  local general = engine and engine.db and engine.db.general;
  return general and general.font or db.elvFont;
end

-- ElvUI's general font style (default "OUTLINE"); "NONE" means no outline. Without ElvUI, ElvUI's default.
function theme.FontFlags()
  local engine = Engine();
  local general = engine and engine.db and engine.db.general;
  local style = general and general.fontStyle;
  if type(style) ~= "string" then return "OUTLINE" end
  return style == "NONE" and "" or style;
end

-- ElvUI draws extra black lines outside and inside each border when its Pixel Perfect option is off.
function theme.ThickBorders()
  local engine = Engine();
  return engine ~= nil and engine.PixelMode == false;
end

-- When ElvUI changes its media, profile or the screen scale, the Elv style redraws. One deferred refresh
-- covers several changes in a row, and nothing polls while the HUD runs.
local hooked, pending;
local function Refresh()
  if pending then return end
  pending = true;
  C_Timer.After(0, function()
    pending = nil;
    if EnhancedSoftInteractDB and EnhancedSoftInteractDB.hudStyle == "elv" then
      ns.UpdateStyle();
      ns.RefreshSettings();
    end
  end);
end

local function Connect()
  local engine = Engine();
  if not engine or engine == hooked or type(engine.UpdateMedia) ~= "function" then return end
  hooked = engine;
  hooksecurefunc(engine, "UpdateMedia", Refresh);
  Refresh();
end

local watcher = CreateFrame("Frame");
watcher:RegisterEvent("PLAYER_LOGIN");
watcher:RegisterEvent("ADDON_LOADED");
watcher:RegisterEvent("UI_SCALE_CHANGED");
watcher:RegisterEvent("DISPLAY_SIZE_CHANGED");
watcher:SetScript("OnEvent", function(_, event, addon)
  if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and addon == "ElvUI") then Connect(); end
  if event ~= "ADDON_LOADED" then Refresh(); end
end);
Connect(); --ElvUI is an optional dependency, so it has loaded before this file
