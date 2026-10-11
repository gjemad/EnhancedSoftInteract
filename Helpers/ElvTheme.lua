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

function theme.FontName(db)
  local suite = _G.ElvUI;
  local engine = type(suite) == "table" and suite[1];
  local general = type(engine) == "table" and engine.db and engine.db.general;
  return general and general.font or db.elvFont;
end
