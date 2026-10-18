local _, ns = ...;
local theme = {};
ns.ElvTheme = theme;

-- Read resolved media: ElvUI applies profile and class-color choices before publishing these values.
function theme.Media()
  local suite = _G.ElvUI;
  local engine = type(suite) == "table" and suite[1];
  return type(engine) == "table" and type(engine.media) == "table" and engine.media or nil;
end

function theme.Font(db)
  local data = theme.Media();
  return data and data.normFont or ns.media:Fetch("font", db.elvFont);
end

local function Engine()
  local suite = _G.ElvUI;
  local engine = type(suite) == "table" and suite[1];
  return type(engine) == "table" and engine or nil;
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

function theme.FontName(db)
  local suite = _G.ElvUI;
  local engine = type(suite) == "table" and suite[1];
  local general = type(engine) == "table" and engine.db and engine.db.general;
  return general and general.font or db.elvFont;
end
