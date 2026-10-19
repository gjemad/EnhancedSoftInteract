local _, ns = ...;
local media, DEFAULTS, SLIDER_RANGES = ns.media, ns.DEFAULTS, ns.SLIDER_RANGES;
local SetIconSide, UpdateIcon, UpdateFont = ns.SetIconSide, ns.UpdateIcon, ns.UpdateFont;
local UpdateKeyCap, UpdateLayout = ns.UpdateKeyCap, ns.UpdateLayout;
local UpdateColors = ns.UpdateColors;
ns.SettingType = { Checkbox = 1, Slider = 2, Dropdown = 3, Section = 4 };

-- Shared settings definitions for the Interface AddOns page. Edit Mode only owns HUD positioning.
-- Tooltip text (desc): one short sentence, then a second paragraph only for details or limits.
function ns.BuildSettings()
  local db = EnhancedSoftInteractDB;
  local kind = ns.SettingType;
  local settings = {};
  local function AddonOff() return not db.enabled end

  local function Section(name)
    settings[#settings + 1] = { kind = kind.Section, name = name };
  end
  local function Add(setting)
    local disabled = setting.disabled;
    setting.disabled = function() return AddonOff() or (disabled and disabled()) end;
    settings[#settings + 1] = setting;
  end
  -- Options: desc, onChange(value), disabled(), and indent for a sub-option, which sits under its parent
  -- and is disabled while the parent is off.
  local function Checkbox(name, key, options)
    Add({ kind = kind.Checkbox, name = name, desc = options.desc, default = DEFAULTS[key],
      disabled = options.disabled, indent = options.indent,
      get = function() return db[key] end,
      set = function(_, value) db[key] = value; if options.onChange then options.onChange(value) end end });
  end
  -- Ranges and steps come from SLIDER_RANGES. Options: desc, formatter, onChange, disabled.
  local function Slider(name, key, options)
    local range = SLIDER_RANGES[key];
    Add({ kind = kind.Slider, name = name, desc = options.desc, default = DEFAULTS[key],
      minValue = range[1], maxValue = range[2], valueStep = range[3], formatter = options.formatter,
      disabled = options.disabled,
      get = function() return db[key] end,
      set = function(_, value) db[key] = value; if options.onChange then options.onChange(value) end end });
  end
  local function Percent(value) return ("%d%%"):format(value) end
  local function KeyHidden() return not db.showKey end

  -- Always enabled, because it enables the rest of the settings page, so it skips Add.
  settings[#settings + 1] = {
    kind = kind.Checkbox, name = "Enabled", default = DEFAULTS.enabled,
    desc = "Shows the HUD with your soft target's name, icon and interact key.",
    get = function() return db.enabled end,
    set = function(_, value)
      db.enabled = value;
      ns.UpdateBlizzardDisplays();
      ns.KeepSettings();
      ns.RefreshSettings();
    end,
  };

  Section("Appearance");
  Add({ kind = kind.Dropdown, name = "Style", default = DEFAULTS.hudStyle,
    desc = "Changes the look of the HUD.",
    values = function() return ns.HUD_STYLES end,
    get = function() return db.hudStyle end,
    set = function(_, value)
      db.hudStyle = value;
      ns.UpdateStyle();
      ns.RefreshSettings();
    end });
  Add({ kind = kind.Dropdown, name = "Size", default = DEFAULTS.hudSize,
    desc = "Sets the overall size of the HUD.\n\nButton Size and Interaction Icon Size scale from this size.",
    values = function() return {
      {text = "Small", value = "small"}, {text = "Normal", value = "normal"}, {text = "Large", value = "large"},
    } end,
    get = function() return db.hudSize end,
    set = function(_, value)
      db.hudSize = value;
      ns.UpdateStyle();
      ns.RefreshSettings();
    end });
  Checkbox("Enable Animations", "animationsEnabled", {
    desc = "Plays fades and effects when your target changes and when you interact.",
    onChange = ns.UpdateAnimations });
  Checkbox("Enable Cast Bar", "castBarEnabled", {
    desc = "Shows a cast bar in the HUD while you gather or open something.",
    onChange = function()
      ns.RefreshInteractionCastBar();
      ns.RefreshSettings();
    end });
  local function CastBarOff() return not db.castBarEnabled end
  Checkbox("Auto Hide Default Cast Bar", "castBarHideGame", {
    desc = "Hides the default cast bar while the HUD shows a cast.\n\nOther casts still use the default cast bar.",
    onChange = ns.RefreshInteractionCastBar, disabled = CastBarOff, indent = true });
  Checkbox("Show for Clicked Objects", "castBarClicked", {
    desc = "Also shows the cast bar when you click an object instead of using the interact key.\n\nClicked objects can't always be told apart, so the cast bar may not always behave as expected.",
    disabled = CastBarOff, indent = true });

  Section("HUD Elements");
  Add({ kind = kind.Checkbox, name = "Show Icon", desc = "Shows the interaction icon in the HUD.",
    default = function()
      if db.hudStyle == "elv" then return DEFAULTS.elvShowIcon; end
      return DEFAULTS.showIcon;
    end,
    get = function() return ns.styles.ShowIcon(db) end,
    set = function(_, value)
      if db.hudStyle == "elv" then db.elvShowIcon = value; else db.showIcon = value; end
      UpdateIcon();
      UpdateLayout();
    end });
  Checkbox("Swap Icon and Key", "swapIconAndKey", {
    desc = "Moves the icon to the right side and the key to the left.",
    onChange = function() SetIconSide(); UpdateLayout(); end });
  Checkbox("Show Interact Key", "showKey", {
    desc = "Shows your interact keybind or controller button in the HUD.",
    onChange = function() UpdateKeyCap(); UpdateLayout(); end });
  Add({ kind = kind.Dropdown, name = "Button Style", default = DEFAULTS.keyStyle,
    desc = "Changes the artwork of keyboard keys.\n\nController buttons always use the game's own symbols.",
    hidden = function() return ns.styles.Get().ownKey end,
    disabled = KeyHidden,
    values = function() return {{text = "Plunderstorm", value = "plunderstorm"}, {text = "Classic", value = "classic"}} end,
    get = function() return db.keyStyle end,
    set = function(_, value)
      if ns.styles.Get().ownKey then return end
      db.keyStyle = value;
      ns.UpdateStyle();
    end });
  Slider("Button Size", "buttonSizePercent", {
    desc = "Makes the key or controller button bigger or smaller.\n\n100% is the normal size for the chosen HUD size.",
    formatter = Percent, onChange = ns.UpdateStyle, disabled = KeyHidden });
  Slider("Interaction Icon Size", "interactionIconSizePercent", {
    desc = "Makes the interaction icon bigger or smaller.\n\n100% is the normal size for the chosen HUD size.",
    formatter = Percent, onChange = ns.UpdateStyle, disabled = function() return not ns.styles.ShowIcon(db) end });

  Section("Text");
  Add({ kind = kind.Dropdown, name = "Font",
    desc = "Changes the font of the target name and key.\n\nThe Elv style has its own font setting, and uses ElvUI's font while ElvUI is loaded.",
    default = function() return db.hudStyle == "elv" and DEFAULTS.elvFont or media:GetDefault("font"); end,
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
  Section("Colors & Shadow");
  Slider("Color Brightness", "colorBrightness", {
    desc = "Sets how bright the colored lines and glows are.",
    formatter = Percent, onChange = UpdateColors });
  Slider("Shadow Strength", "shadowStrength", {
    desc = "Sets how dark the shadow behind the text is.\n\nNot every style has a shadow.",
    formatter = Percent, onChange = ns.UpdateShadow, disabled = function() return not ns.styles.Get().shadow end });

  Section("Blizzard Displays");
  Checkbox("Show Target Tooltip", "showBlizzardTooltip", {
    desc = "Shows the game's tooltip for your soft target.\n\nWhen unchecked, the tooltip is hidden. Your game setting comes back when Enabled is turned off.",
    onChange = ns.UpdateBlizzardDisplays });
  Checkbox("Show Target Icons", "showBlizzardIcons", {
    desc = "Lets the game show its interaction icon above your soft target, including herbs, ore and chests.\n\nWhen unchecked, the icon is hidden.",
    onChange = ns.UpdateBlizzardDisplays });

  -- Game settings the HUD needs, kept by Feat\Persistence.lua.
  Section("Persistence");
  for _, kept in ipairs(ns.keptSettings) do
    Checkbox(kept.checkbox, kept.option, { desc = kept.desc, onChange = ns.KeepSettings });
  end

  return settings;
end
