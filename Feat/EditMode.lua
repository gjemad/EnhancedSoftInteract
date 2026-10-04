local _, ns = ...;
local frame, media, DEFAULTS, SLIDER_RANGES = ns.frame, ns.media, ns.DEFAULTS, ns.SLIDER_RANGES;
local HUD_DEFAULT_POSITION, Notify = ns.HUD_DEFAULT_POSITION, ns.Notify;
local SetIconSide, UpdateIcon, UpdateFont = ns.SetIconSide, ns.UpdateIcon, ns.UpdateFont;
local UpdateKeyCap, UpdateLayout, UpdateHeight = ns.UpdateKeyCap, ns.UpdateLayout, ns.UpdateHeight;
local UpdateColors = ns.UpdateColors;

----
--  Samples for the HUD in Edit Mode: Classic Era NPCs and game objects (also in WoW: Forever), in three
--  name lengths, each with its cursor. Clicking the preview (Feat\Preview.lua) shows a random sample of the
--  next length.
----
local PREVIEW_NPCS = {
  { --short
    { "Thrall", "Quest" }, { "Doras", "Taxi" }, { "Devrak", "Taxi" }, { "Karus", "Buy" },
    { "Olvia", "Buy" }, { "Gamon", "Speak" }, { "Sian'tsu", "Trainer" },
    { "Mailbox", "Mail" }, { "Peacebloom", "GatherHerbs" }, { "Silverleaf", "GatherHerbs" },
    { "Earthroot", "GatherHerbs" }, { "Tin Vein", "Mine" }, { "Copper Vein", "Mine" },
    { "Prairie Wolf", "Skin" }, { "Plainstrider", "Skin" }, { "Kobold Vermin", "LootAll" },
  },
  { --medium
    { "Innkeeper Gryshka", "Innkeeper" }, { "Innkeeper Allison", "Innkeeper" }, { "Dungar Longdrink", "Taxi" },
    { "Thurman Mullby", "Pickup" }, { "Marshal Dughan", "Quest" }, { "Cairne Bloodhoof", "Quest" },
    { "Magni Bronzebeard", "Quest" }, { "Ander Germaine", "Trainer" }, { "Deputy Willem", "Quest" },
    { "Wild Steelbloom", "GatherHerbs" }, { "Mithril Deposit", "Mine" }, { "Truesilver Deposit", "Mine" },
    { "Small Thorium Vein", "Mine" }, { "Wanted Poster", "Interact" },
    { "Elder Mottled Boar", "Skin" }, { "Defias Pillager", "LootAll" }, { "Frostmane Headhunter", "LootAll" },
    { "Battered Footlocker", "PickLock" }, { "Waterlogged Footlocker", "PickLock" },
  },
  { --long
    { "Highlord Bolvar Fordragon", "Quest" }, { "High Tinker Mekkatorque", "Quest" },
    { "Lady Sylvanas Windrunner", "Quest" }, { "Arch Druid Fandral Staghelm", "Quest" },
    { "High Priestess Tyrande Whisperwind", "Quest" }, { "Archmage Ansirem Runeweaver", "Quest" },
    { "Ooze Covered Rich Thorium Vein", "Mine" }, { "Ooze Covered Truesilver Deposit", "Mine" },
    { "Ooze Covered Mithril Deposit", "Mine" },
    { "Elder Saltwater Crocolisk", "Skin" }, { "Burning Blade Neophyte", "LootAll" },
  },
};

----
--  Edit Mode (LibEditMode). In Edit Mode the HUD shows a sample target, so you can see it while you drag
--  it and change its settings. Each layout keeps its own position; a layout without one uses
--  HUD_DEFAULT_POSITION.
----
local LibEditMode = LibStub("LibEditMode", true);

local function GetLayoutPosition(layoutName)
  return (layoutName and EnhancedSoftInteractDB.layouts[layoutName]) or HUD_DEFAULT_POSITION;
end

local function ApplyPosition(pos)
  frame:ClearAllPoints();
  frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y);
end

-- Shows a sample target of the next name length on every HUD (the real one and the preview). Herbs and
-- ore look the way this character would see them, so without the profession they are unable and show the
-- requirement line.
local sampleLength, sampleName = 0, nil;
local function ShowNextEditModeSample()
  sampleLength = sampleLength % #PREVIEW_NPCS + 1;
  local npcs = PREVIEW_NPCS[sampleLength];
  local npc;
  repeat npc = npcs[math.random(#npcs)] until #npcs == 1 or npc[1] ~= sampleName;
  local name, cursor = npc[1], npc[2];
  sampleName = name;
  local requirement = ns.RequirementFor(cursor);
  if requirement then cursor = "Unable" .. cursor; end
  ns.ShowSample(name, cursor, requirement);
end
ns.ShowNextEditModeSample = ShowNextEditModeSample;

local function ShowEditModeSample()
  frame.inEditMode = true;
  sampleLength = 0;
  ShowNextEditModeSample();
end

-- Back to the real soft target, or fade out when there is none.
local function EndEditModeSample()
  frame.inEditMode = false;
  frame.sampleName = nil;
  frame.lastTarget, frame.lastSignature = nil, nil;
  ns.OnSoftInteractChanged(nil, UnitGUID("softinteract"));
end

-- The Edit Mode panel's settings. They are account-wide, not per layout, so get and set ignore the
-- layout name. Sections are LibEditMode expanders, and editModeSections keeps which ones are open.
local function BuildEditModeSettings()
  local db = EnhancedSoftInteractDB;
  local kind = LibEditMode.SettingType;
  local sections = db.editModeSections;
  local settings = {};
  local currentSection;
  local function AddonOff() return not db.enabled end

  local function Section(key, name)
    currentSection = key;
    settings[#settings + 1] = {
      kind = kind.Expander, name = name, default = true,
      get = function() return sections[key] ~= false end,
      set = function(_, expanded) sections[key] = expanded; end,
    };
  end
  local function Add(setting)
    local section, disabled = currentSection, setting.disabled;
    if section then setting.hidden = function() return sections[section] == false end end
    setting.disabled = function(layoutName) return AddonOff() or (disabled and disabled(layoutName)) end
    settings[#settings + 1] = setting;
  end
  local function Checkbox(name, key, onChange)
    Add({ kind = kind.Checkbox, name = name, default = DEFAULTS[key],
      get = function() return db[key] end,
      set = function(_, value) db[key] = value; if onChange then onChange(value) end end });
  end
  -- Ranges and steps come from SLIDER_RANGES.
  local function Slider(name, key, formatter, onChange, disabled)
    local range = SLIDER_RANGES[key];
    Add({ kind = kind.Slider, name = name, default = DEFAULTS[key], minValue = range[1], maxValue = range[2],
      valueStep = range[3], formatter = formatter, disabled = disabled,
      get = function() return db[key] end,
      set = function(_, value) db[key] = value; if onChange then onChange(value) end end });
  end
  local function Px(value) return ("%dpx"):format(value) end
  local function Percent(value) return ("%d%%"):format(value) end
  local function KeyHidden() return not db.showKey end

  -- Outside the sections and never disabled, because it enables the rest.
  settings[1] = {
    kind = kind.Checkbox, name = "Enabled", default = DEFAULTS.enabled,
    get = function() return db.enabled end,
    set = function(_, value)
      db.enabled = value;
      ns.UpdateBlizzardDisplays();
      ns.KeepSettings();
      LibEditMode:RefreshFrameSettings(frame);
    end,
  };

  Section("appearance", "Appearance");
  Checkbox("Hide Blizzard's Soft Target Displays", "hideBlizzard", ns.UpdateBlizzardDisplays);
  Checkbox("Enable Animations", "animationsEnabled", ns.UpdateAnimations);
  Add({ kind = kind.Divider, hideLabel = true });
  Checkbox("Show Icon", "showIcon", function() UpdateIcon(); UpdateLayout(); end);
  Slider("Icon Size", "iconSize", Px, function() UpdateIcon(); UpdateLayout(); end,
    function() return not db.showIcon end);
  Checkbox("Swap Icon and Key", "swapIconAndKey", function() SetIconSide(); UpdateLayout(); end);
  Checkbox("Show Interact Key", "showKey", function() UpdateKeyCap(); UpdateLayout(); end);
  Slider("Key Size", "keyScale", Percent, function() UpdateKeyCap(); UpdateLayout(); end, KeyHidden);

  Add({ kind = kind.Divider, hideLabel = true });
  Add({ kind = kind.Dropdown, name = "Font", default = media:GetDefault("font"), height = 300,
    values = function()
      local values = {};
      for _, name in ipairs(media:List("font")) do values[#values + 1] = { text = name, value = name }; end
      return values;
    end,
    get = function() return db.font end,
    set = function(_, value) db.font = value; UpdateFont(); end });
  Slider("Font Size", "fontSize", nil, UpdateFont);
  Slider("Name Min Width", "nameMinWidth", Px, UpdateLayout);
  Slider("Name Max Width", "nameMaxWidth", Px, UpdateLayout);


  Slider("Color Brightness", "colorBrightness", Percent, UpdateColors);
  Slider("Shadow Height", "hudHeight", Px, UpdateHeight);

  -- Game settings the HUD needs, kept by Feat\Persistence.lua.
  Section("persistence", "Persistence");
  for _, kept in ipairs(ns.keptSettings) do Checkbox(kept.checkbox, kept.option, ns.KeepSettings); end

  -- LibEditMode adds desc without word wrapping, so keep tooltip lines short with explicit breaks.
  local DESCRIPTIONS = {
    ["Enabled"] = "Shows the target's name, icon and interact key.",
    ["Hide Blizzard's Soft Target Displays"] = "Hides the game's own labels for your interact target.\nTurn off to show them alongside this addon.",
    ["Keep Interact Key On"] = "Keeps the Interact Key enabled\nso you can use it to interact with nearby targets.",
    ["Keep Interact Key Icons on Show All"] = "Keeps all interact icons enabled\nso the addon can show the right icon for each target.",
    ["Show Icon"] = "Shows an icon for what you can do with the target.",
    ["Icon Size"] = "Adjusts the size of the target icon.",
    ["Swap Icon and Key"] = "Switches the sides of the icon and interact key.",
    ["Show Interact Key"] = "Shows your interact key or controller button.",
    ["Key Size"] = "Adjusts the size of the key or controller button.\n100% is the normal size.",
    ["Font"] = "Chooses the lettering for the name and key.",
    ["Name Min Width"] = "Sets the space reserved for short names.",
    ["Name Max Width"] = "Limits the space used by long names.\nNames that don't fit end in \"...\".",
    ["Font Size"] = "Adjusts the size of the target's name.",
    ["Color Brightness"] = "Adjusts how bright the colored lines and glow appear.",
    ["Shadow Height"] = "Adjusts the height of the shadow behind the name.",
    ["Enable Animations"] = "Adds movement and fades to the target display.",
  };
  for _, setting in ipairs(settings) do setting.desc = DESCRIPTIONS[setting.name]; end

  return settings;
end

local function SetupEditMode()
  if not LibEditMode then return end
  LibEditMode:AddFrame(frame, function(_, layoutName, point, x, y)
    EnhancedSoftInteractDB.layouts[layoutName] = { point = point, x = x, y = y };
  end, HUD_DEFAULT_POSITION, "Enhanced Soft Interact");
  LibEditMode:AddFrameSettings(frame, BuildEditModeSettings());
  LibEditMode:RegisterCallback("layout", function(layoutName) ApplyPosition(GetLayoutPosition(layoutName)); end);
  LibEditMode:RegisterCallback("rename", function(oldName, newName)
    local layouts = EnhancedSoftInteractDB.layouts;
    layouts[newName], layouts[oldName] = layouts[oldName], nil;
  end);
  LibEditMode:RegisterCallback("delete", function(layoutName) EnhancedSoftInteractDB.layouts[layoutName] = nil; end);
  LibEditMode:RegisterCallback("enter", ShowEditModeSample);
  LibEditMode:RegisterCallback("exit", EndEditModeSample);
end

-- Opens Edit Mode (as Blizzard's /editmode does) and selects the HUD, which opens its settings panel.
function ns.OpenHUDInEditMode()
  if InCombatLockdown() then Notify("Edit Mode can't be opened in combat."); return end
  if not LibEditMode then Notify("Edit Mode isn't available."); return end
  if SettingsPanel:IsShown() then SettingsPanel:Close(true); end
  if not EditModeManagerFrame:IsShown() then
    if not EditModeManagerFrame:CanEnterEditMode() then Notify("Edit Mode isn't available right now."); return end
    ShowUIPanel(EditModeManagerFrame);
  end
  C_Timer.After(0, function()
    local selection = LibEditMode.frameSelections and LibEditMode.frameSelections[frame];
    if selection and selection:IsShown() then selection:GetScript("OnMouseDown")(selection); end
  end);
end

table.insert(ns.onLoad, function()
  ApplyPosition(GetLayoutPosition(LibEditMode and LibEditMode:GetActiveLayoutName()));
  SetupEditMode();
  if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    local info = UIDropDownMenu_CreateInfo();
    info.text = "Enhanced Soft Interact";
    info.notCheckable = true;
    info.func = ns.OpenHUDInEditMode;
    AddonCompartmentFrame:RegisterAddon(info);
  end
end);
