local _, ns = ...;
local issecretvalue = ns.issecretvalue;
local TYPE_COLORS, mouseCursorByFileID = ns.typeColors, ns.mouseCursorByFileID;

-- Cursor textures come in several spellings: plain names ("Cursor Innkeeper"), the crosshair version both
-- clients use ("Cursor Crosshair_Innkeeper_64", or the bare atlas name "Crosshair_Innkeeper_64"), sized
-- ones ("Cursor Cursor_CampaignQuest_32") and file paths ("Interface\Cursor\Innkeeper"). CursorName
-- reduces each one to "innkeeper", and returns nil for anything that isn't a cursor.
local function CursorName(key)
  local name = key:match("^[Cc]ursor (.+)$") or key:match("[Cc][Uu][Rr][Ss][Oo][Rr][\\/]([%w_%-]+)[%.%w]*$")
    or key:match("^[Cc]rosshair_.+$");
  if not name then return nil end
  return (name:gsub("^[Cc]rosshair_", ""):gsub("^[Cc]ursor_", ""):gsub("_%d+$", ""):lower());
end

-- The lookup form of a key: "cursor innkeeper". Other keys (file IDs, "default") stay as they are.
local function NormalizeCursorKey(key)
  local name = CursorName(key);
  return name and "cursor " .. name or key:lower();
end

-- Maps each normalized key to its TYPE_COLORS spelling, and to its Unable version ("Cursor UnableSkin").
local COLOR_KEY_BY_LOWER = {};
for key in pairs(TYPE_COLORS) do
  COLOR_KEY_BY_LOWER[NormalizeCursorKey(key)] = key;
  local name = key:match("^Cursor (.+)$");
  if name then COLOR_KEY_BY_LOWER[NormalizeCursorKey("Cursor Unable" .. name)] = "Cursor Unable" .. name; end
end
local function ColorKeyFor(cursorKey)
  return COLOR_KEY_BY_LOWER[NormalizeCursorKey(cursorKey)] or cursorKey;
end

local function IsUnableKey(key)
  return key ~= nil and key:lower():find("unable") ~= nil;
end

local OUT_OF_RANGE_COLOR = {.35, .35, .35};
local UNABLE_COLOR = {.5, .5, .5};

-- The color for an icon key (frame.colorKey) and range.
local function GetTypeColor(key, outOfRange)
  local color;
  if outOfRange then
    color = OUT_OF_RANGE_COLOR;
  elseif IsUnableKey(key) then
    color = UNABLE_COLOR;
  else
    color = TYPE_COLORS[key] or TYPE_COLORS["default"];
  end
  return color[1], color[2], color[3];
end

ns.CursorName, ns.NormalizeCursorKey, ns.ColorKeyFor = CursorName, NormalizeCursorKey, ColorKeyFor;
ns.IsUnableKey, ns.GetTypeColor = IsUnableKey, GetTypeColor;

-- What the addon knows about cursor types: their crosshair art, how far that art sits off-center, retail's
-- cursor file IDs, and which gather cursors need a profession.

-- The crosshair atlas for a cursor name ("Crosshair_Skin_64" for "Skin"), or nil when the client doesn't
-- have one. SetUnitCursorTexture uses these on WoW: Forever and on retail ("Cursor Crosshair_Mail_64" in
-- /esi debug on both). Atlas names ignore case, so the name's spelling doesn't matter.
function ns.CrosshairAtlasFor(cursorName)
  local atlas = ("Crosshair_%s_64"):format(cursorName);
  return C_Texture.GetAtlasInfo(atlas) and atlas or nil;
end

function ns.IconArtOffset(icon, key, fromFileID)
  local atlas = icon:GetAtlas();
  if issecretvalue(atlas) then return nil end
  if atlas and atlas ~= "" then return ns.iconArtOffsets[key:gsub("^cursor unable", "cursor ")] end
  local path = icon:GetTextureFilePath();
  if not issecretvalue(path) and type(path) == "string" then
    if path:lower():find("crosshair_", 1, true) then
      return ns.iconArtOffsets[key:gsub("^cursor unable", "cursor ")];
    end
    local name = CursorName(path);
    if name then return ns.mouseCursorArtOffsets["cursor " .. name] end
  end
  local fileID = icon:GetTextureFileID();
  if not issecretvalue(fileID) and mouseCursorByFileID[fileID] then
    return ns.mouseCursorArtOffsets[mouseCursorByFileID[fileID]];
  end
  if fromFileID then return nil end --resolved retail crosshair files are already centered
end

-- Classic can return a native mouse cursor by file ID instead of by path. Use the same identity table
-- for target decisions and icon centering, alongside the modern cursor files above.
function ns.CursorKeyForFileID(fileID)
  local key = mouseCursorByFileID[fileID];
  if not key then
    local name = ns.cursorFileNames[fileID];
    key = name and "Cursor " .. name;
  end
  return key and ColorKeyFor(key);
end

-- Match modern professions by skill line. Era can return no GetProfessions entries even for a gatherer;
-- its learned tracking spells identify the professions without depending on rank or expanded skill rows.
-- Skinning needs no entry because the game does not show its cursor without the profession.
local PROFESSIONS = {
  GatherHerbs = { skillLine = 182, trackingSpell = 2383, name = HERBALISM or "Herbalism" },
  Mine = { skillLine = 186, trackingSpell = 2580, name = MINING or "Mining" },
};

local function HasProfession(profession)
  if GetProfessions and GetProfessionInfo then
    for _, index in pairs({ GetProfessions() }) do --pairs skips the nil gaps
      if select(7, GetProfessionInfo(index)) == profession.skillLine then return true end
    end
  end
  if C_SpellBook and C_SpellBook.IsSpellKnown then
    local known = C_SpellBook.IsSpellKnown(profession.trackingSpell);
    if not ns.issecretvalue(known) then return known end
  end
  return false;
end

-- "Requires Herbalism" for a cursor that needs a profession, else nil.
function ns.RequirementText(cursorName)
  local profession = PROFESSIONS[cursorName];
  return profession and (ITEM_REQ_SKILL or "Requires %s"):format(profession.name) or nil;
end

-- The requirement line when the cursor needs a profession the character doesn't have, else nil.
function ns.RequirementFor(cursorName)
  local profession = PROFESSIONS[cursorName];
  if profession and not HasProfession(profession) then return ns.RequirementText(cursorName) end
  return nil;
end
