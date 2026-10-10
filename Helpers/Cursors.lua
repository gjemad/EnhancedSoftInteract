local _, ns = ...;
local issecretvalue = issecretvalue or function() return false end;

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

-- Era only. Native mouse cursors, extracted from the Era 1.15.9.70003 client (all 32x32). Each entry is
-- {right, down}: how far the visible art's center sits from the image center, in 64px units, measured
-- like the crosshair table above (opaque pixels brighter than the outline and shadow). Most files carry
-- the same hotspot triangle at pixels 1-9 of the top-left corner. It is visible, so it counts: AnchorIcon
-- centers the whole art, triangle included, in the icon column. Normal and Unable files are measured
-- separately. Regenerate with era_icon_table.py in the wow-ui-renderer tools.
ns.mouseCursorArtOffsets = {
  ["cursor architect"] = {-2, 0},
  ["cursor argusteleporter"] = {0, -7},
  ["cursor attack"] = {0, 0},
  ["cursor buy"] = {-6, -7},
  ["cursor cast"] = {0, -3},
  ["cursor crosshairs"] = {0, 0},
  ["cursor directions"] = {-1, -1},
  ["cursor driver"] = {-1, -2},
  ["cursor engineerskin"] = {0, -1},
  ["cursor fishing"] = {-1, -1},
  ["cursor fishingcursor"] = {2, 2},
  ["cursor gatherherbs"] = {0, 0},
  ["cursor gunner"] = {1, 0},
  ["cursor innkeeper"] = {-3, -4},
  ["cursor inspect"] = {-1, 0},
  ["cursor interact"] = {-3, -3},
  ["cursor item"] = {-22, -22},
  ["cursor lootall"] = {-3, -2},
  ["cursor mail"] = {-1, -5},
  ["cursor mine"] = {-5, 0},
  ["cursor missions"] = {-3, -3},
  ["cursor openhand"] = {-1, 0},
  ["cursor openhandglow"] = {-1, 1},
  ["cursor picklock"] = {-5, -3},
  ["cursor pickup"] = {-6, -7},
  ["cursor point"] = {-4, -8},
  ["cursor pvp"] = {-1, -1},
  ["cursor quest"] = {-10, -2},
  ["cursor questinteract"] = {-5, -2},
  ["cursor questrepeatable"] = {-9, -3},
  ["cursor questturnin"] = {-8, -3},
  ["cursor reforge"] = {0, 0},
  ["cursor repair"] = {-1, -2},
  ["cursor repairnpc"] = {-4, -4},
  ["cursor sawblade"] = {-1, -1},
  ["cursor skin"] = {-1, -4},
  ["cursor skinalliance"] = {-1, -2},
  ["cursor skinhorde"] = {0, 0},
  ["cursor speak"] = {-3, -6},
  ["cursor stablemaster"] = {-2, -2},
  ["cursor taxi"] = {0, 0},
  ["cursor teleport"] = {-3, -1},
  ["cursor thumbsup"] = {3, -1},
  ["cursor trainer"] = {0, -1},
  ["cursor transmogrify"] = {-4, 0},
  ["cursor ui-cursor-move"] = {-1, 0},
  ["cursor ui-cursor-size"] = {-1, -2},
  ["cursor ui-cursor-sizeleft"] = {1, -1},
  ["cursor ui-cursor-sizeright"] = {-1, -1},
  ["cursor unablearchitect"] = {-2, -1},
  ["cursor unableargusteleporter"] = {0, -7},
  ["cursor unableattack"] = {-1, -1},
  ["cursor unablebuy"] = {-8, -8},
  ["cursor unablecast"] = {0, -3},
  ["cursor unablecrosshairs"] = {0, 0},
  ["cursor unabledirections"] = {-1, -1},
  ["cursor unabledriver"] = {-1, -2},
  ["cursor unableengineerskin"] = {0, -1},
  ["cursor unablefishing"] = {-2, -2},
  ["cursor unablegatherherbs"] = {0, -3},
  ["cursor unablegunner"] = {1, 0},
  ["cursor unableinnkeeper"] = {-4, -5},
  ["cursor unableinspect"] = {-1, 0},
  ["cursor unableinteract"] = {-4, -4},
  ["cursor unableitem"] = {-22, -22},
  ["cursor unablelootall"] = {-12, -4},
  ["cursor unablemail"] = {-1, -5},
  ["cursor unablemine"] = {-5, 0},
  ["cursor unablemissions"] = {-3, -3},
  ["cursor unableopenhand"] = {0, 1},
  ["cursor unableopenhandglow"] = {-1, 1},
  ["cursor unablepicklock"] = {-5, -5},
  ["cursor unablepickup"] = {-13, -9},
  ["cursor unablepoint"] = {-4, -8},
  ["cursor unablepvp"] = {-1, -1},
  ["cursor unablequest"] = {-10, -2},
  ["cursor unablequestinteract"] = {-5, -2},
  ["cursor unablequestrepeatable"] = {-8, -3},
  ["cursor unablequestturnin"] = {-8, -3},
  ["cursor unablereforge"] = {1, -1},
  ["cursor unablerepair"] = {-1, -4},
  ["cursor unablerepairnpc"] = {-4, -4},
  ["cursor unablesawblade"] = {-3, -3},
  ["cursor unableskin"] = {-1, -5},
  ["cursor unableskinalliance"] = {-1, -2},
  ["cursor unableskinhorde"] = {1, -2},
  ["cursor unablespeak"] = {-3, -7},
  ["cursor unablestablemaster"] = {-3, -3},
  ["cursor unabletaxi"] = {0, 0},
  ["cursor unableteleport"] = {-3, -1},
  ["cursor unablethumbdown"] = {-1, 0},
  ["cursor unablethumbsdown"] = {1, -2},
  ["cursor unablethumbsup"] = {3, -1},
  ["cursor unablethumbup"] = {-3, -1},
  ["cursor unabletrainer"] = {0, -1},
  ["cursor unabletransmogrify"] = {-4, -1},
  ["cursor unableui-cursor-move"] = {-1, 0},
  ["cursor unableui-cursor-size"] = {-1, -4},
  ["cursor unableui-cursor-sizeleft"] = {1, -1},
  ["cursor unablevehichlecursor"] = {-1, -2},
  ["cursor unablevoidstorage"] = {-3, -1},
  ["cursor unablewildpet"] = {0, 2},
  ["cursor unablewildpetcapturable"] = {-1, -1},
  ["cursor unableworkorders"] = {-4, -2},
  ["cursor vehichlecursor"] = {-1, -2},
  ["cursor voidstorage"] = {-2, -1},
  ["cursor wildpet"] = {1, 1},
  ["cursor wildpetcapturable"] = {1, 1},
  ["cursor workorders"] = {-3, 0},
};

local mouseCursorByFileID = {
  [131013] = "cursor attack",
  [131014] = "cursor buy",
  [131015] = "cursor cast",
  [131017] = "cursor directions",
  [131018] = "cursor gatherherbs",
  [131019] = "cursor innkeeper",
  [131020] = "cursor inspect",
  [131021] = "cursor interact",
  [131022] = "cursor item",
  [131023] = "cursor lootall",
  [131024] = "cursor mail",
  [131025] = "cursor mine",
  [131026] = "cursor picklock",
  [131027] = "cursor pickup",
  [131028] = "cursor point",
  [131029] = "cursor pvp",
  [131030] = "cursor quest",
  [131031] = "cursor questrepeatable",
  [131032] = "cursor questturnin",
  [131033] = "cursor repair",
  [131034] = "cursor repairnpc",
  [131035] = "cursor skin",
  [131036] = "cursor skinalliance",
  [131037] = "cursor skinhorde",
  [131038] = "cursor speak",
  [131039] = "cursor taxi",
  [131040] = "cursor trainer",
  [131041] = "cursor unableattack",
  [131042] = "cursor unablebuy",
  [131043] = "cursor unablecast",
  [131044] = "cursor unabledirections",
  [131045] = "cursor unablegatherherbs",
  [131046] = "cursor unableinnkeeper",
  [131047] = "cursor unableinspect",
  [131048] = "cursor unableinteract",
  [131049] = "cursor unableitem",
  [131050] = "cursor unablelootall",
  [131051] = "cursor unablemail",
  [131052] = "cursor unablemine",
  [131053] = "cursor unablepicklock",
  [131054] = "cursor unablepickup",
  [131055] = "cursor unablepoint",
  [131056] = "cursor unablepvp",
  [131057] = "cursor unablequest",
  [131058] = "cursor unablequestrepeatable",
  [131059] = "cursor unablequestturnin",
  [131060] = "cursor unablerepair",
  [131061] = "cursor unablerepairnpc",
  [131062] = "cursor unableskin",
  [131063] = "cursor unableskinalliance",
  [131064] = "cursor unableskinhorde",
  [131065] = "cursor unablespeak",
  [131066] = "cursor unabletaxi",
  [131067] = "cursor unabletrainer",
  [131068] = "cursor unablevehichlecursor",
  [131069] = "cursor vehichlecursor",
  [235497] = "cursor driver",
  [235498] = "cursor engineerskin",
  [235499] = "cursor gunner",
  [235500] = "cursor unabledriver",
  [235501] = "cursor unableengineerskin",
  [235502] = "cursor unablegunner",
  [252300] = "cursor fishingcursor",
  [303902] = "cursor fishing",
  [303903] = "cursor unablefishing",
  [462987] = "cursor openhand",
  [463442] = "cursor reforge",
  [463443] = "cursor unablereforge",
  [463850] = "cursor openhandglow",
  [463987] = "cursor thumbsup",
  [464971] = "cursor unableopenhand",
  [464972] = "cursor unableopenhandglow",
  [527420] = "cursor stablemaster",
  [527421] = "cursor unablestablemaster",
  [532327] = "cursor ui-cursor-move",
  [532998] = "cursor transmogrify",
  [532999] = "cursor unabletransmogrify",
  [533000] = "cursor unablevoidstorage",
  [533001] = "cursor voidstorage",
  [590792] = "cursor crosshairs",
  [590793] = "cursor unablecrosshairs",
  [610631] = "cursor unablewildpet",
  [610632] = "cursor wildpet",
  [613072] = "cursor unablewildpetcapturable",
  [613073] = "cursor wildpetcapturable",
  [985085] = "cursor architect",
  [985086] = "cursor missions",
  [985223] = "cursor unablearchitect",
  [985224] = "cursor unablemissions",
  [1006596] = "cursor questinteract",
  [1006597] = "cursor unablequestinteract",
  [1024962] = "cursor sawblade",
  [1024963] = "cursor unablesawblade",
  [1062216] = "cursor unablethumbdown",
  [1062217] = "cursor unablethumbsdown",
  [1062218] = "cursor unablethumbsup",
  [1062219] = "cursor unablethumbup",
  [1094568] = "cursor ui-cursor-size",
  [1094569] = "cursor unableui-cursor-move",
  [1094570] = "cursor unableui-cursor-size",
  [1094573] = "cursor ui-cursor-sizeleft",
  [1094574] = "cursor unableui-cursor-sizeleft",
  [1097680] = "cursor unableworkorders",
  [1097681] = "cursor workorders",
  [1261459] = "cursor ui-cursor-sizeright",
  [1706226] = "cursor teleport",
  [1706227] = "cursor unableteleport",
  [1706448] = "cursor argusteleporter",
  [1706449] = "cursor unableargusteleporter",
};

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

-- "Requires Herbalism" when the cursor needs a profession the character doesn't have, else nil.
function ns.RequirementFor(cursorName)
  local profession = PROFESSIONS[cursorName];
  if profession and not HasProfession(profession) then
    return (ITEM_REQ_SKILL or "Requires %s"):format(profession.name);
  end
  return nil;
end
