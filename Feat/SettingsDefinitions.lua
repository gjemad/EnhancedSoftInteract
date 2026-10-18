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
  -- A sub-option is indented under its parent and disabled while the parent is off.
  local function Checkbox(name, key, onChange, disabled, indent)
    Add({ kind = kind.Checkbox, name = name, default = DEFAULTS[key], disabled = disabled, indent = indent,
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
  Checkbox("Enable Cast Bar", "castBarEnabled", function()
    ns.RefreshInteractionCastBar();
    if ns.RefreshSettings then ns.RefreshSettings(); end
  end);
  local function CastBarOff() return not db.castBarEnabled end
  Checkbox("Auto Hide Default Cast Bar", "castBarHideGame", ns.RefreshInteractionCastBar, CastBarOff, true);
  Checkbox("Show for Clicked Objects", "castBarClicked", nil, CastBarOff, true);
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
  Slider("Button Size", "buttonSizePercent", Percent, ns.UpdateStyle, KeyHidden);
  Slider("Interaction Icon Size", "interactionIconSizePercent", Percent, ns.UpdateStyle,
    function() return not ns.styles.ShowIcon(db) end);

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

  -- Tooltip text for each option: one short sentence, then a second paragraph only for details or limits.
  local DESCRIPTIONS = {
    ["Enabled"] = "Shows the HUD with your soft target's name, icon and interact key.",
    ["Style"] = "Changes the look of the HUD.",
    ["Size"] = "Sets the overall size of the HUD.\n\nButton Size and Interaction Icon Size scale from this size.",
    ["Enable Animations"] = "Plays fades and effects when your target changes and when you interact.",
    ["Enable Cast Bar"] = "Shows a cast bar in the HUD while you gather or open something.",
    ["Auto Hide Default Cast Bar"] = "Hides the default cast bar while the HUD shows a cast.\n\nOther casts still use the default cast bar.",
    ["Show for Clicked Objects"] = "Also shows the cast bar when you click an object instead of using the interact key.\n\nClicked objects can't always be told apart, so the cast bar may not always behave as expected.",
    ["Show Icon"] = "Shows the interaction icon in the HUD.",
    ["Swap Icon and Key"] = "Moves the icon to the right side and the key to the left.",
    ["Show Interact Key"] = "Shows your interact keybind or controller button in the HUD.",
    ["Button Style"] = "Changes the artwork of keyboard keys.\n\nController buttons always use the game's own symbols.",
    ["Button Size"] = "Makes the key or controller button bigger or smaller.\n\n100% is the normal size for the chosen HUD size.",
    ["Interaction Icon Size"] = "Makes the interaction icon bigger or smaller.\n\n100% is the normal size for the chosen HUD size.",
    ["Font"] = "Changes the font of the target name and key.\n\nThe Elv style has its own font setting, and uses ElvUI's font while ElvUI is loaded.",
    ["Color Brightness"] = "Sets how bright the colored lines and glows are.",
    ["Shadow Strength"] = "Sets how dark the shadow behind the text is.\n\nNot every style has a shadow.",
    ["Show Target Tooltip"] = "Shows the game's tooltip for your soft target.\n\nWhen unchecked, the tooltip is hidden. Your game setting comes back when Enabled is turned off.",
    ["Show Target Icons"] = "Lets the game show its interaction icon above your soft target, including herbs, ore and chests.\n\nWhen unchecked, the icon is hidden.",
    ["Keep Interact Key On"] = "Turns the game's Interact Key option back on if something turns it off.\n\nThe HUD needs it to find targets.",
    ["Keep Interact Key Icons on Show All"] = "Keeps the game's Interact Key Icons option on Show All.\n\nWith fewer icons, the HUD can't show the right icon for every target, such as corpses you can loot.",
  };
  for _, setting in ipairs(settings) do setting.desc = DESCRIPTIONS[setting.name]; end

  return settings;
end
