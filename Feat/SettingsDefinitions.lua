local ADDON_NAME, ns = ...;
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
local media, DEFAULTS, SLIDER_RANGES = ns.media, ns.DEFAULTS, ns.SLIDER_RANGES;
local SetIconSide, UpdateIcon, UpdateFont = ns.SetIconSide, ns.UpdateIcon, ns.UpdateFont;
local UpdateKeyCap, UpdateLayout = ns.UpdateKeyCap, ns.UpdateLayout;
ns.SettingType = { Checkbox = 1, Slider = 2, Dropdown = 3, Section = 4, Keybind = 5 };

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
  -- Options: desc, onChange(value), disabled(), hidden(), and indent for a sub-option: how many levels
  -- it sits under its parent.
  local function Checkbox(name, key, options)
    Add({ kind = kind.Checkbox, name = name, desc = options.desc, default = DEFAULTS[key],
      disabled = options.disabled, hidden = options.hidden, indent = options.indent,
      get = function() return db[key] end,
      set = function(_, value) db[key] = value; if options.onChange then options.onChange(value) end end });
  end
  -- Ranges and steps come from SLIDER_RANGES. Options: desc, formatter, onChange, disabled, hidden.
  local function Slider(name, key, options)
    local range = SLIDER_RANGES[key];
    Add({ kind = kind.Slider, name = name, desc = options.desc, default = DEFAULTS[key],
      minValue = range[1], maxValue = range[2], valueStep = range[3], formatter = options.formatter,
      disabled = options.disabled, hidden = options.hidden,
      get = function() return db[key] end,
      set = function(_, value) db[key] = value; if options.onChange then options.onChange(value) end end });
  end
  local function KeyHidden() return not db.showKey end

  -- Always enabled, because it enables the rest of the settings page, so it skips Add.
  settings[#settings + 1] = {
    kind = kind.Checkbox, name = "Enabled", default = DEFAULTS.enabled,
    desc = "Shows the HUD for your soft target.",
    get = function() return db.enabled end,
    set = function(_, value)
      db.enabled = value;
      ns.UpdateBlizzardDisplays();
      ns.KeepSettings();
      ns.UpdateTargeting();
      if ns.UpdateObjectName then ns.UpdateObjectName(); end
      ns.RefreshSettings();
    end,
  };

  -- Interact Key options under Enabled: the Always options from Feat\Persistence.lua, which keep the
  -- game's settings at the values the HUD needs, the binding and the game's sound cue.
  local kept = {};
  for _, entry in ipairs(ns.keptSettings) do kept[entry.option] = entry; end
  local function Kept(key)
    Checkbox(kept[key].checkbox, key, { desc = kept[key].desc, onChange = ns.KeepSettings, indent = 1 });
  end
  Kept("forceInteractKey");
  Add({ kind = kind.Keybind, name = "Interact Key", indent = 1, action = "INTERACTTARGET",
    desc = "Sets the keys you interact with.\n\nClick a slot, then press a key. Right-click clears it.",
    get = function() return GetBindingKey("INTERACTTARGET") end,
    set = function(slot, key) ns.SetBindingSlot("INTERACTTARGET", slot, key); end });
  local interactSound = ns.gameInteractSound;
  if interactSound then
    Add({ kind = kind.Checkbox, name = ENABLE_INTERACT_SOUND_OPTION or "Interact Key Sound Cue", default = interactSound.Default, indent = 1,
      desc = "Plays a sound when you can interact with a target, and when you no longer can.",
      get = interactSound.Get,
      set = function(_, value) interactSound.Set(value); end });
  end
  Kept("forceInteractIcons");

  -- The game's soft interact range and arc, which Feat\Targeting.lua owns.
  local function TargetingUnavailable() return not ns.TargetingAvailable() end
  local function Yards(value) return ("%d yards"):format(value) end

  Section("Targeting");
  Slider("Interaction Range", "interactRange", {
    desc = "Sets how far away your interact key finds targets.\n\nGame objects have a 20 yard limit. Above that, the range only affects friendly targets.",
    formatter = Yards, onChange = ns.UpdateTargeting, hidden = TargetingUnavailable });
  Add({ kind = kind.Dropdown, name = "Interaction Arc", default = DEFAULTS.interactArc,
    desc = "Sets how wide an area in front of you your interact key searches for targets.",
    hidden = TargetingUnavailable,
    values = function() return {
      {text = "Straight Ahead", value = 0, icon = MEDIA .. "ArcStraightAhead"},
      {text = "Narrow", value = 1, icon = MEDIA .. "ArcNarrow"},
      {text = "Wide", value = 2, icon = MEDIA .. "ArcWide"},
    } end,
    get = function() return db.interactArc end,
    set = function(_, value) db.interactArc = value; ns.UpdateTargeting(); end });

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
    desc = "Sets the size of the HUD.",
    values = function() return {
      {text = "Small", value = "small"}, {text = "Normal", value = "normal"}, {text = "Large", value = "large"},
    } end,
    get = function() return db.hudSize end,
    set = function(_, value)
      db.hudSize = value;
      ns.UpdateStyle();
      ns.RefreshSettings();
    end });
  Add({ kind = kind.Dropdown, name = "Font",
    desc = "Changes the font of the HUD's text.",
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
  Add({ kind = kind.Checkbox, name = "Show Icon", desc = "Shows the interaction icon in the HUD.",
    default = function() return DEFAULTS[ns.styles.Get().showIconKey] end,
    get = function() return ns.styles.ShowIcon(db) end,
    set = function(_, value)
      db[ns.styles.Get().showIconKey] = value;
      UpdateIcon();
      UpdateLayout();
    end });
  Checkbox("Show Interact Button", "showKey", {
    desc = "Shows the interact button in the HUD.",
    onChange = function() UpdateKeyCap(); UpdateLayout(); end });
  Add({ kind = kind.Dropdown, name = "Button Style", default = DEFAULTS.keyStyle, indent = 1,
    desc = "Changes the artwork of the interact button.",
    hidden = function() return ns.styles.Get().ownKey end,
    disabled = KeyHidden,
    values = function() return {
      {text = "Classic", value = "classic"},
      {text = "Plunderstorm", value = "plunderstorm"},
    } end,
    get = function() return db.keyStyle end,
    set = function(_, value)
      if ns.styles.Get().ownKey then return end
      db.keyStyle = value;
      ns.UpdateStyle();
    end });
  Checkbox("Swap Icon and Interact Button positions", "swapIconAndKey", {
    desc = "Moves the icon to the right side and the interact button to the left.",
    onChange = function() SetIconSide(); UpdateLayout(); end });
  Checkbox("Show Skill-Up Icon", "showSkillUp", {
    desc = "Shows an icon next to the name when the target can raise your profession skill.",
    hidden = function() return not ns.SkillUpSupported end,
    onChange = UpdateLayout });
  Checkbox("Enable Cast Bar", "castBarEnabled", {
    desc = "Shows a cast bar in the HUD while you gather or open something.",
    onChange = function()
      ns.RefreshInteractionCastBar();
      ns.RefreshSettings();
    end });
  local function CastBarOff() return not db.castBarEnabled end
  Checkbox("Show Cast Bar Timer", "castBarTimer", {
    desc = "Shows the seconds left on your cast.",
    hidden = function() return not ns.styles.Get().castBar.timer end,
    onChange = ns.RefreshInteractionCastBar, disabled = CastBarOff, indent = 1 });
  Checkbox("Auto Hide Default Cast Bar", "castBarHideGame", {
    desc = "Hides the default cast bar while the HUD shows a cast.",
    onChange = ns.RefreshInteractionCastBar, disabled = CastBarOff, indent = 1 });
  Checkbox("Show for Clicked Objects", "castBarClicked", {
    desc = "Also shows the cast bar when you click an object.\n\nThis may not always work as expected.",
    disabled = CastBarOff, indent = 1 });

  Section("Blizzard Displays");
  Checkbox("Show Target Tooltip", "showBlizzardTooltip", {
    desc = "Shows the game's tooltip for your soft target.",
    onChange = ns.UpdateBlizzardDisplays });
  Checkbox("Show Target Icons", "showBlizzardIcons", {
    desc = "Shows the game's interaction icon above your soft target.",
    onChange = ns.UpdateBlizzardDisplays });
  Checkbox("Show Object Names", "showObjectNames", {
    desc = "Shows the name above your soft target when it's an object.",
    hidden = function() return not ns.ObjectNamesSupported end,
    onChange = function() ns.UpdateObjectName(); end });

  return settings;
end
