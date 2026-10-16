local _, ns = ...;
local media, DEFAULTS, SLIDER_RANGES = ns.media, ns.DEFAULTS, ns.SLIDER_RANGES;
local SetIconSide, UpdateIcon, UpdateFont = ns.SetIconSide, ns.UpdateIcon, ns.UpdateFont;
local UpdateKeyCap, UpdateLayout = ns.UpdateKeyCap, ns.UpdateLayout;
local UpdateColors = ns.UpdateColors;
ns.SettingType = { Checkbox = 1, Slider = 2, Dropdown = 3, Section = 4, Divider = "divider" };

-- Shared settings definitions for the Interface AddOns page. Edit Mode only owns HUD positioning.
function ns.BuildSettings()
  local db = EnhancedSoftInteractDB;
  local kind = ns.SettingType;
  local settings = {};
  local function AddonOff() return not db.enabled end

  local function Section(_, name)
    settings[#settings + 1] = { kind = kind.Section, name = name };
  end
  local function Add(setting)
    local disabled = setting.disabled;
    setting.disabled = function() return AddonOff() or (disabled and disabled()) end;
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
  local function Percent(value) return ("%d%%"):format(value) end
  local function KeyHidden() return not db.showKey end

  -- Always enabled, because it enables the rest of the settings page.
  settings[1] = {
    kind = kind.Checkbox, name = "Enabled", default = DEFAULTS.enabled,
    get = function() return db.enabled end,
    set = function(_, value)
      db.enabled = value;
      ns.UpdateBlizzardDisplays();
      ns.KeepSettings();
      if ns.RefreshSettings then ns.RefreshSettings(); end
    end,
  };

  Section("appearance", "Appearance");
  Add({ kind = kind.Dropdown, name = "Style", default = DEFAULTS.hudStyle,
    values = function() return ns.HUD_STYLES end,
    get = function() return db.hudStyle end,
    set = function(_, value)
      db.hudStyle = value;
      ns.UpdateStyle();
      if ns.RefreshSettings then ns.RefreshSettings(); end
    end });
  Add({ kind = kind.Dropdown, name = "Size", default = DEFAULTS.hudSize,
    values = function() return {
      {text = "Small", value = "small"}, {text = "Normal", value = "normal"}, {text = "Large", value = "large"},
    } end,
    get = function() return db.hudSize end,
    set = function(_, value)
      db.hudSize = value;
      ns.UpdateStyle();
      if ns.RefreshSettings then ns.RefreshSettings(); end
    end });
  Checkbox("Enable Animations", "animationsEnabled", ns.UpdateAnimations);
  Checkbox("Enable Cast Bar", "castBarEnabled", ns.RefreshInteractionCastBar);
  Section("hud", "HUD Elements");
  local function IconChanged()
    UpdateIcon();
    UpdateLayout();
  end
  Add({ kind = kind.Checkbox, name = "Show Icon", default = function()
    if db.hudStyle == "elv" then return DEFAULTS.elvShowIcon; end
    return DEFAULTS.showIcon;
  end,
    get = function() return ns.styles.ShowIcon(db) end,
    set = function(_, value)
      if db.hudStyle == "elv" then db.elvShowIcon = value; else db.showIcon = value; end
      IconChanged();
    end });
  Checkbox("Swap Icon and Key", "swapIconAndKey", function() SetIconSide(); UpdateLayout(); end);
  Checkbox("Show Interact Key", "showKey", function() UpdateKeyCap(); UpdateLayout(); end);
  Add({ kind = kind.Dropdown, name = "Button Style", default = DEFAULTS.keyStyle,
    hidden = function() return ns.styles.Get().ownKey end,
    disabled = KeyHidden,
    values = function() return {{text = "Plunderstorm", value = "plunderstorm"}, {text = "Classic", value = "classic"}} end,
    get = function() return db.keyStyle end,
    set = function(_, value)
      if ns.styles.Get().ownKey then return end
      db.keyStyle = value;
      ns.UpdateStyle();
    end });

  Section("text", "Text");
  Add({ kind = kind.Dropdown, name = "Font",
    default = function() return db.hudStyle == "elv" and DEFAULTS.elvFont or media:GetDefault("font"); end, height = 300,
    values = function()
      local values = {};
      for _, name in ipairs(media:List("font")) do values[#values + 1] = { text = name, value = name }; end
      return values;
    end,
    get = function() return db.hudStyle == "elv" and ns.ElvTheme.FontName(db) or db.font end,
    disabled = function()
      local data = db.hudStyle == "elv" and ns.ElvTheme.Media();
      return data and data.normFont ~= nil;
    end,
    set = function(_, value)
      if db.hudStyle == "elv" then db.elvFont = value; else db.font = value; end
      UpdateFont();
    end });
  Section("color", "Colors & Shadow");
  Slider("Color Brightness", "colorBrightness", Percent, UpdateColors);
  local function NoShadow() return not ns.styles.Get().shadow end
  Slider("Shadow Strength", "shadowStrength", Percent, ns.UpdateShadow, NoShadow);

  Section("blizzardDisplays", "Blizzard Displays");
  Checkbox("Show Target Tooltip", "showBlizzardTooltip", ns.UpdateBlizzardDisplays);
  Checkbox("Show Target Icons", "showBlizzardIcons", ns.UpdateBlizzardDisplays);

  -- Game settings the HUD needs, kept by Feat\Persistence.lua.
  Section("persistence", "Persistence");
  for _, kept in ipairs(ns.keptSettings) do Checkbox(kept.checkbox, kept.option, ns.KeepSettings); end

  -- Cards share these descriptions, with optional visual examples on the settings page.
  local DESCRIPTIONS = {
    ["Style"] = "Chooses the look of the target display.",
    ["Size"] = "Sizes the whole HUD together. Small, Normal and Large each keep the chosen style's text, button and icon in proportion.",
    ["Enabled"] = "Shows the target's name, icon and interact key.",
    ["Show Target Tooltip"] = "Shows the game's tooltip for the selected soft target.\nUnchecked: hides it. Does not change the addon's HUD.\nYour game settings return when the addon is disabled.",
    ["Show Target Icons"] = "Allows the game's interaction icon above the soft target's nameplate, including herbs, mining nodes and chests.",
    ["Keep Interact Key On"] = "Keeps the Interact Key enabled\nso you can use it to interact with nearby targets.",
    ["Keep Interact Key Icons on Show All"] = "Keeps all interact icons enabled\nso the addon can show the right icon for each target.",
    ["Show Icon"] = "Shows the interaction icon inside the addon's HUD.",
    ["Swap Icon and Key"] = "Switches the sides of the icon and interact key.",
    ["Show Interact Key"] = "Shows your interact key or controller button.",
    ["Button Style"] = "Choose Plunderstorm or Classic artwork for keyboard keys.\nController buttons keep their native symbols. Elv uses its own key display.",
    ["Font"] = "Chooses the lettering for the name and key.\nElv keeps a separate font choice and uses ElvUI's font while the suite is loaded.",
    ["Color Brightness"] = "Adjusts how bright the colored lines and glow appear.",
    ["Shadow Strength"] = "Adjusts how dark the shadow behind the name appears.",
    ["Enable Animations"] = "Adds movement and fades to the target display.",
    ["Enable Cast Bar"] = "Shows progress while gathering or opening objects.",
  };
  for _, setting in ipairs(settings) do setting.desc = DESCRIPTIONS[setting.name]; end

  return settings;
end
