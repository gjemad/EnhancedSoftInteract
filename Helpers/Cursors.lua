local _, ns = ...;

-- Colors per icon type, for targets you can interact with. Unable icons always get UNABLE_COLOR or
-- OUT_OF_RANGE_COLOR, so they have no entries. Each color is an OKLCH hue and chroma picked per family
-- (related types share a hue band; icons with a strong color of their own, such as quest marks, pawprints
-- and transmog, use the icon's measured hue), at the lightest lightness sRGB can show, then scaled so the
-- strongest channel is 1. The lines and glows light at full strength, and colorBrightness dims them.
local TYPE_COLORS = {
  ["default"] = {1, 0.83, 0.33}, --unknown or secret icon: plain gold
  -- Quests: gold for normal quests and quest objects, blue for repeatable ones, amber for the campaign.
  ["Cursor Quest"] = {1, 0.85, 0.09},
  ["Cursor QuestInteract"] = {1, 0.85, 0.09},
  ["Cursor QuestRepeatable"] = {0.05, 0.59, 1},
  ["Cursor CampaignQuest"] = {1, 0.5, 0.05},
  ["Cursor CampaignQuestTurnIn"] = {1, 0.5, 0.05},
  -- Gathering and looting: leaf green, ore copper, hide tan, loot sand, and cool steel for locks and hands.
  ["Cursor GatherHerbs"] = {0.41, 1, 0.46},
  ["Cursor Mine"] = {1, 0.74, 0.44},
  ["Cursor Skin"] = {1, 0.6, 0.49},
  ["Cursor LootAll"] = {1, 0.83, 0.47},
  ["Cursor PickLock"] = {0.78, 0.88, 1}, --locked chests and footlockers
  ["Cursor OpenHand"] = {0.92, 0.95, 1}, --chests, petting animals
  ["Cursor OpenHandGlow"] = {0.73, 0.96, 1},
  -- Merchants and services.
  ["Cursor Pickup"] = {1, 0.73, 0.5}, --vendor: warm brown
  ["Cursor Buy"] = {1, 0.95, 0.68}, --bank: pale gold
  ["Cursor RepairNPC"] = {0.86, 0.94, 1}, --steel
  ["Cursor Reforge"] = {0.35, 0.97, 1}, --reforge and upgrade NPCs: teal
  ["Cursor Mail"] = {1, 0.29, 0.23}, --mailbox red
  ["Cursor Innkeeper"] = {0.4, 0.79, 1}, --hearthstone blue
  ["Cursor Taxi"] = {0.99, 1, 0.62}, --flight masters: pale straw
  ["Cursor Trainer"] = {1, 0.66, 0.47},
  ["Cursor Directions"] = {1, 0.55, 0.64}, --guards: rose
  ["Cursor Missions"] = {1, 0.64, 0.65},
  ["Cursor VoidStorage"] = {1, 0.54, 0.91}, --magenta
  ["Cursor Transmogrify"] = {0.69, 0.48, 1}, --violet
  -- Generic icons stay close to white, with a warm or cool tint.
  ["Cursor Speak"] = {1, 0.96, 0.91},
  ["Cursor Inspect"] = {0.81, 0.94, 1},
  ["Cursor Interact"] = {1, 0.79, 0.41}, --the cog: bronze
  -- Battle pets: green when you can capture the pet, gold otherwise.
  ["Cursor WildPetCapturable"] = {0.33, 1, 0.5},
  ["Cursor WildPet"] = {1, 0.74, 0.19},
};

-- Cursor textures come in several spellings: plain names ("Cursor Innkeeper"), the crosshair version both
-- clients use ("Cursor Crosshair_Innkeeper_64", or the bare atlas name "Crosshair_Innkeeper_64"), sized
-- ones ("Cursor Cursor_CampaignQuest_32") and file paths ("Interface\Cursor\Innkeeper"). CursorName
-- reduces each one to "innkeeper", and returns nil for anything that isn't a cursor.
local function CursorName(key)
  local name = key:match("^[Cc]ursor (.+)$") or key:match("[Cc][Uu][Rr][Ss][Oo][Rr][\\/]([%w_]+)[%.%w]*$")
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

-- The color for an icon key (frame.colorKey) and range, dimmed by colorBrightness (percent).
local function GetTypeColor(key, outOfRange)
  local color;
  if outOfRange then
    color = OUT_OF_RANGE_COLOR;
  elseif IsUnableKey(key) then
    color = UNABLE_COLOR;
  else
    color = TYPE_COLORS[key] or TYPE_COLORS["default"];
  end
  local scale = EnhancedSoftInteractDB.colorBrightness / 100;
  return color[1] * scale, color[2] * scale, color[3] * scale;
end

ns.typeColors = TYPE_COLORS;
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

-- Most cursor art isn't centered in its 64x64 image. It sits low and right, with its dark outline and drop
-- shadow below and to the right. Each value is {right, down}, how far the art's colored body (opaque
-- pixels brighter than the outline and shadow) sits from the image center, in 64px units. The values come
-- from measuring every Crosshair_*_64 atlas of the client on 2026-10-03, and the table leaves out offsets
-- under 1. Unable versions have the same shapes and use their cursor's value. AnchorIcon moves the icon
-- the other way.
ns.iconArtOffsets = {
  ["cursor architect"] = {3, 3}, ["cursor attack"] = {0, -2.5}, ["cursor axe"] = {0, 1},
  ["cursor bastionteleporter"] = {4.5, 1}, ["cursor broom"] = {0.5, -1}, ["cursor buy"] = {5, 1.5},
  ["cursor campaignquest"] = {9, 2.5}, ["cursor campaignquestturnin"] = {9, 2.5}, ["cursor cast"] = {0, -2},
  ["cursor directions"] = {0, 2}, ["cursor disarmtrap"] = {3.5, 5}, ["cursor driver"] = {2.5, 1.5},
  ["cursor enchant"] = {0.5, 2}, ["cursor engineerskin"] = {1.5, 4}, ["cursor gatherherbs"] = {2, 2},
  ["cursor grabbinghand"] = {-3.5, -4.5}, ["cursor important"] = {5, 4.5},
  ["cursor importantturnin"] = {5, 4.5}, ["cursor inspect"] = {1, 0.5}, ["cursor interact"] = {3.5, 3.5},
  ["cursor legendaryquest"] = {2.5, 5}, ["cursor legendaryquestturnin"] = {2.5, 4.5},
  ["cursor lock"] = {7.5, 2.5}, ["cursor lootall"] = {5, 2.5}, ["cursor mail"] = {3.5, 3},
  ["cursor mappincursor"] = {1, 1}, ["cursor mine"] = {1, 0}, ["cursor missions"] = {2.5, 4},
  ["cursor openhand"] = {-2.5, 0.5}, ["cursor openhandglow"] = {-4.5, 0.5}, ["cursor palette"] = {0, 1},
  ["cursor petting"] = {1.5, 2.5}, ["cursor picklock"] = {7.5, 2.5}, ["cursor pickup"] = {5, 1.5},
  ["cursor point"] = {-3.5, -6.5}, ["cursor pvp"] = {6, 4.5}, ["cursor questinteract"] = {1, 0.5},
  ["cursor recurring"] = {1.5, 0.5}, ["cursor recurringturnin"] = {1.5, 1}, ["cursor reforge"] = {2.5, 2.5},
  ["cursor sawblade"] = {3, 2}, ["cursor skin"] = {0, 3.5}, ["cursor skinalliance"] = {1, 6},
  ["cursor skinhorde"] = {2, 8.5}, ["cursor speak"] = {2, 4.5}, ["cursor stablemaster"] = {-1, -0.5},
  ["cursor taxi"] = {2, 1}, ["cursor thumbsup"] = {4.5, 0.5}, ["cursor trainer"] = {1.5, 3.5},
  ["cursor transmogrify"] = {3.5, 1.5}, ["cursor vehichlecursor"] = {1, 0}, ["cursor wildpet"] = {2, 3},
  ["cursor wildpetcapturable"] = {3, 2.5}, ["cursor workorders"] = {5, 1}, ["cursor wrapper"] = {2.5, 3},
  ["cursor wrapperturnin"] = {2.5, 2},
};

-- Retail sometimes gives a cursor as a texture file ID instead of a name, for the files in
-- interface/cursor/crosshair/ at 1x and 2x ("uiquestinteractcrosshair2x"). This maps each file ID to its
-- cursor name, from the client file list on wago.tools. Lookups ignore case.
ns.cursorFileNames = {
  [4675617] = "architect", [4675618] = "argusteleporter", [4675619] = "attack", [4675620] = "bastionteleporter",
  [4675621] = "buy", [4675622] = "cast", [4675623] = "crosshairs", [4675624] = "directions",
  [4675625] = "disarmtrap", [4675626] = "driver", [4675627] = "engineerskin", [4675628] = "ferry",
  [4675629] = "fishing", [4675630] = "fishingcursor", [4675631] = "gatherherbs", [4675632] = "gunner",
  [4675633] = "innkeeper", [4675634] = "inspect", [4675635] = "interact", [4675636] = "item", [4675637] = "lootall",
  [4675638] = "mail", [4675639] = "mappincursor", [4675640] = "mine", [4675641] = "missions", [4675642] = "openhand",
  [4675643] = "openhandglow", [4675644] = "picklock", [4675645] = "pickup", [4675646] = "point",
  [4675647] = "progenitorflightmaster", [4675648] = "pvp", [4675649] = "quest", [4675650] = "questinteract",
  [4675651] = "questrepeatable", [4675652] = "questturnin", [4675653] = "reforge", [4675654] = "repair",
  [4675655] = "repairnpc", [4675656] = "sawblade", [4675657] = "skin", [4675658] = "skinalliance",
  [4675659] = "skinhorde", [4675660] = "speak", [4675661] = "stablemaster", [4675662] = "taxi",
  [4675663] = "thumbsup", [4675664] = "trainer", [4675665] = "transmogrify", [4675670] = "unablearchitect",
  [4675671] = "unableargusteleporter", [4675672] = "unableattack", [4675673] = "unablebastionteleporter",
  [4675674] = "unablebuy", [4675675] = "unablecast", [4675676] = "unablecrosshairs", [4675677] = "unabledirections",
  [4675678] = "unabledisarmtrap", [4675679] = "unabledriver", [4675680] = "unableengineerskin",
  [4675681] = "unableferry", [4675682] = "unablefishing", [4675683] = "unablegatherherbs",
  [4675684] = "unablegunner", [4675685] = "unableinnkeeper", [4675686] = "unableinspect",
  [4675687] = "unableinteract", [4675688] = "unableitem", [4675689] = "unablelootall", [4675690] = "unablemail",
  [4675691] = "unablemappincursor", [4675692] = "unablemine", [4675693] = "unablemissions",
  [4675694] = "unableopenhand", [4675695] = "unableopenhandglow", [4675696] = "unablepicklock",
  [4675697] = "unablepickup", [4675698] = "unablepoint", [4675699] = "unableprogenitorflightmaster",
  [4675700] = "unablepvp", [4675701] = "unablequest", [4675702] = "unablequestinteract",
  [4675703] = "unablequestrepeatable", [4675704] = "unablequestturnin", [4675705] = "unablereforge",
  [4675706] = "unablerepair", [4675707] = "unablerepairnpc", [4675708] = "unablesawblade", [4675709] = "unableskin",
  [4675710] = "unableskinalliance", [4675711] = "unableskinhorde", [4675712] = "unablespeak",
  [4675713] = "unablestablemaster", [4675714] = "unabletaxi", [4675715] = "unablethumbdown",
  [4675716] = "unablethumbsdown", [4675717] = "unablethumbsup", [4675718] = "unablethumbup",
  [4675719] = "unabletrainer", [4675720] = "unabletransmogrify", [4675724] = "unablevehichlecursor",
  [4675725] = "unablevoidstorage", [4675726] = "unablewildpet", [4675727] = "unablewildpetcapturable",
  [4675728] = "unableworkorders", [4675729] = "vehichlecursor", [4675730] = "voidstorage", [4675731] = "wildpet",
  [4675732] = "wildpetcapturable", [4675733] = "workorders", [6074836] = "wrapperquest",
  [6074839] = "recurringquest", [6074842] = "quest", [6074857] = "legendaryquest", [6074860] = "importantquest",
  [6074863] = "campaignquest", [6074866] = "flightmaster", [6075016] = "mail", [6075030] = "taxi",
  [6075035] = "trainer", [6075043] = "buy", [6075055] = "interact", [6075058] = "pickup",
  [6075065] = "questinteract", [6075088] = "attack", [6075270] = "openhand", [6075273] = "openhand",
  [6075276] = "openhandglow", [6075466] = "picklock", [6075469] = "lock", [6116514] = "lootall", [6116529] = "cast",
  [6116631] = "gearenchant", [6119901] = "repairnpc", [6119907] = "repair", [6119963] = "transmogrify",
  [6119971] = "vehicle", [6125834] = "vehichle", [6152862] = "innkeeper", [6161863] = "stablemaster",
  [6727029] = "grabbinghand", [6727202] = "holdinghand", [6838848] = "inspect", [6914207] = "driver",
  [7380706] = "palette", [7382286] = "broom", [7704509] = "axe", [7958206] = "bastionteleporter",
  [7958209] = "disarmtrap", [7958213] = "fishing", [7958221] = "gatherherbs", [7958223] = "gunner", [7958225] = "mappin",
  [7958227] = "mine", [7958571] = "missions", [7958573] = "move", [7958575] = "wildpetcapturable",
  [7958577] = "wildpet", [7958579] = "petting", [7958581] = "pvp", [7958583] = "reforge",
  [7958585] = "sawblade", [7958587] = "sizeleft", [7958589] = "sizeright", [7958594] = "skin",
  [7958603] = "skinalliance", [7958610] = "skinhorde", [7958619] = "thumbsup", [7958632] = "workorders",
  [7959502] = "architect", [7961737] = "axe", [7961738] = "broom", [7961739] = "palette", [7961748] = "unableaxe",
  [7961749] = "unablebroom", [7961750] = "unablepalette",
};

-- Gather cursors the game shows even to characters without the profession (seen on WoW: Forever, and
-- assumed the same on retail, which uses the same client). RequirementFor matches professions by skill
-- line, which is the same on both clients, through GetProfessions() and GetProfessionInfo(index) (7th
-- return), as Blizzard's profession book does. Names are the client's localized strings. Skinning needs no
-- entry, because the game doesn't show the Skin cursor at all without the profession.
local PROFESSIONS = {
  GatherHerbs = { skillLine = 182, name = HERBALISM or "Herbalism" },
  Mine = { skillLine = 186, name = MINING or "Mining" },
};

local function HasSkillLine(skillLine)
  for _, index in pairs({ GetProfessions() }) do --pairs skips the nil gaps
    if select(7, GetProfessionInfo(index)) == skillLine then return true end
  end
  return false;
end

-- "Requires Herbalism" when the cursor needs a profession the character doesn't have, else nil.
function ns.RequirementFor(cursorName)
  local profession = PROFESSIONS[cursorName];
  if profession and not HasSkillLine(profession.skillLine) then
    return (ITEM_REQ_SKILL or "Requires %s"):format(profession.name);
  end
  return nil;
end
