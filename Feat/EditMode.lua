local _, ns = ...;
local frame, media, DEFAULTS, SLIDER_RANGES = ns.frame, ns.media, ns.DEFAULTS, ns.SLIDER_RANGES;
local HUD_DEFAULT_POSITION, Notify = ns.HUD_DEFAULT_POSITION, ns.Notify;
local SetIconSide, UpdateIcon, UpdateFont = ns.SetIconSide, ns.UpdateIcon, ns.UpdateFont;
local UpdateKeyCap, UpdateLayout, UpdateHeight = ns.UpdateKeyCap, ns.UpdateLayout, ns.UpdateHeight;
local PlayInteractPulse = ns.PlayInteractPulse;

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
  local function Seconds(value) return ("%.2fs"):format(value) end
  local function RoundTime(value) return math.floor(value * 100 + 0.5) / 100 end
  local function KeyHidden() return not db.showKey end

  -- Outside the sections and never disabled, because it enables the rest.
  settings[1] = {
    kind = kind.Checkbox, name = "Enabled", default = DEFAULTS.enabled,
    get = function() return db.enabled end,
    set = function(_, value)
      db.enabled = value;
      ns.UpdateBlizzardDisplays();
      ns.KeepInteractKeyOn();
      LibEditMode:RefreshFrameSettings(frame);
    end,
  };
  Checkbox("Keep Interact Key On", "forceInteractKey", function() ns.KeepInteractKeyOn(true); end);

  Section("icon", "Icon & Key");
  Checkbox("Show Icon", "showIcon", function() UpdateIcon(); UpdateLayout(); end);
  Slider("Icon Size", "iconSize", Px, function() UpdateIcon(); UpdateLayout(); end,
    function() return not db.showIcon end);
  Checkbox("Swap Icon and Key", "swapIconAndKey", function() SetIconSide(); UpdateLayout(); end);
  Checkbox("Show Interact Key", "showKey", function() UpdateKeyCap(); UpdateLayout(); end);
  Slider("Key Size", "keySize", Percent, function() UpdateKeyCap(); UpdateLayout(); end, KeyHidden);

  Section("text", "Text");
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

  Section("background", "Color & Shadow");
  Slider("Color Brightness", "colorBrightness", Percent, ns.UpdateColors);
  Slider("Shadow Height", "hudHeight", Px, UpdateHeight);

  Section("animation", "Animation");
  Checkbox("Interact Animation", "interactAnim", function(on) if on then PlayInteractPulse(); end end);
  Checkbox("Target Switch Animation", "switchAnim");
  Checkbox("Fade Animations", "fadeEnabled");
  local function FadeOff() return not db.fadeEnabled end
  Slider("Fade In Time", "fadeInTime", Seconds, function(v) db.fadeInTime = RoundTime(v) end, FadeOff);
  Slider("Fade Out Time", "fadeOutTime", Seconds, function(v) db.fadeOutTime = RoundTime(v) end, FadeOff);

  -- LibEditMode shows a setting's desc as its tooltip.
  local DESCRIPTIONS = {
    ["Enabled"] = "Shows the HUD for your soft interact target. Turn off to hide it, bring back Blizzard's soft target tooltip and nameplate, and stop keeping the Interact Key on. The Interact Key keeps its current setting.",
    ["Keep Interact Key On"] = "Turns Enable Interact Key in Options > Controls back on if anything turns it off, such as turning off the gamepad, and says so in chat. The HUD needs the key. Uncheck this to leave the key alone.",
    ["Show Icon"] = "Shows the target's interact icon (talk, quest, vendor, herb, ...) on the HUD.",
    ["Icon Size"] = "Size of the interact icon.\nDefault: 30px",
    ["Swap Icon and Key"] = "Puts the icon on the right end of the HUD and the interact key on the left. The name stays centered.",
    ["Show Interact Key"] = "Shows the key bound to Interact With Target at the end of the HUD opposite the icon. While you use a controller it shows the gamepad button instead. It hides while the action is unbound.",
    ["Key Size"] = "Size of the interact key, relative to the font size.\nDefault: 130%",
    ["Font"] = "Font of the target name and the key.",
    ["Name Min Width"] = "Narrowest the name column gets, for short names.\nDefault: 100px",
    ["Name Max Width"] = "Widest the name column gets. Longer names end in \"...\".\nDefault: 200px",
    ["Font Size"] = "Font size of the target name.\nDefault: 17",
    ["Color Brightness"] = "Brightness of the target type's color in the lines and the glow behind the icon.\nDefault: 100%",
    ["Target Switch Animation"] = "When the frame changes to another target or action (skinning, then looting), the icon and name slide in and the color blends over. Click the preview to see it.",
    ["Shadow Height"] = "Height of the HUD. The soft shadow behind it reaches a little past this.\nDefault: 50px",
    ["Interact Animation"] = "Plays a 0.3 second glow in the target type's color on the HUD when you press the interact key. Click the preview to see it.",
    ["Fade Animations"] = "Fades the HUD in and out. Turn off to show and hide it instantly.",
    ["Fade In Time"] = ("Seconds for the HUD to fade in.\nDefault: %.2fs"):format(DEFAULTS.fadeInTime),
    ["Fade Out Time"] = ("Seconds for the HUD to fade out.\nDefault: %.2fs"):format(DEFAULTS.fadeOutTime),
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
