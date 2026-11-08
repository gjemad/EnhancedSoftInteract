local ADDON_NAME, ns = ...;
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
local media, DEFAULTS, SLIDER_RANGES = ns.media, ns.DEFAULTS, ns.SLIDER_RANGES;
local SetIconSide, UpdateIcon, UpdateFont = ns.SetIconSide, ns.UpdateIcon, ns.UpdateFont;
local UpdateKeyCap, UpdateLayout = ns.UpdateKeyCap, ns.UpdateLayout;
local L = ns.L;
ns.SettingType = { Checkbox = 1, Slider = 2, Dropdown = 3, Section = 4, Keybind = 5, Note = 6 };

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
    local disabled, locked = setting.disabled, setting.locked;
    setting.disabled = function() return AddonOff() or (disabled and disabled()) or (locked and locked()) end;
    if locked then
      setting.locked = function() return not AddonOff() and locked() end;
    end
    settings[#settings + 1] = setting;
  end
  -- Options: desc, onChange(value), disabled(), hidden(), locked() while another addon's setting
  -- conflicts, and indent for a sub-option: how many levels it sits under its parent.
  local function Checkbox(name, key, options)
    Add({ kind = kind.Checkbox, name = name, desc = options.desc, default = DEFAULTS[key],
      disabled = options.disabled, locked = options.locked, hidden = options.hidden, indent = options.indent,
      get = function() return db[key] end,
      set = function(_, value) db[key] = value; if options.onChange then options.onChange(value) end end });
  end
  -- Ranges and steps come from SLIDER_RANGES. Options: desc, formatter, onChange, disabled, locked, hidden.
  local function Slider(name, key, options)
    local range = SLIDER_RANGES[key];
    Add({ kind = kind.Slider, name = name, desc = options.desc, default = DEFAULTS[key],
      minValue = range[1], maxValue = range[2], valueStep = range[3], formatter = options.formatter,
      disabled = options.disabled, locked = options.locked, hidden = options.hidden,
      get = function() return db[key] end,
      set = function(_, value) db[key] = value; if options.onChange then options.onChange(value) end end });
  end
  local function KeyHidden() return not db.showKey end

  -- Always enabled, because it enables the rest of the settings page, so it skips Add.
  settings[#settings + 1] = {
    kind = kind.Checkbox, name = L.OPTION_ENABLED, default = DEFAULTS.enabled,
    desc = L.OPTION_ENABLED_DESC,
    get = function() return db.enabled end,
    set = function(_, value)
      db.enabled = value;
      ns.UpdateBlizzardDisplays();
      ns.KeepSettings();
      ns.UpdateTargeting();
      if ns.UpdateObjectName then ns.UpdateObjectName(); end
      if ns.UpdateLootEffect then ns.UpdateLootEffect(); end
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
  Add({ kind = kind.Keybind, name = L.OPTION_INTERACT_KEY, indent = 1, action = "INTERACTTARGET",
    desc = L.OPTION_INTERACT_KEY_DESC,
    get = function() return GetBindingKey("INTERACTTARGET") end,
    set = function(slot, key) ns.SetBindingSlot("INTERACTTARGET", slot, key); end });
  Add({ kind = kind.Note, name = L.OPTION_AUTO_LOOT_CONFLICT, indent = 1,
    desc = function() return select(3, ns.AutoLootConflictText()) or "" end,
    hidden = function() return not ns.AutoLootConflictText() end,
    get = ns.AutoLootConflictText, clear = ns.ClearAutoLootConflict });
  local interactSound = ns.gameInteractSound;
  if interactSound then
    Add({ kind = kind.Checkbox, name = ENABLE_INTERACT_SOUND_OPTION or L.GAME_INTERACT_SOUND, default = interactSound.Default, indent = 1,
      desc = L.OPTION_INTERACT_SOUND_DESC,
      get = interactSound.Get,
      set = function(_, value) interactSound.Set(value); end });
  end
  Kept("forceInteractIcons");

  Section(L.SECTION_APPEARANCE);
  Add({ kind = kind.Dropdown, name = L.OPTION_STYLE, default = DEFAULTS.hudStyle,
    desc = L.OPTION_STYLE_DESC,
    values = function() return ns.HUD_STYLES end,
    get = function() return db.hudStyle end,
    set = function(_, value)
      db.hudStyle = value;
      ns.UpdateStyle();
      ns.RefreshSettings();
    end });
  Add({ kind = kind.Dropdown, name = L.OPTION_SIZE, default = DEFAULTS.hudSize,
    desc = L.OPTION_SIZE_DESC,
    values = function() return {
      {text = L.VALUE_SIZE_SMALL, value = "small"}, {text = L.VALUE_SIZE_NORMAL, value = "normal"}, {text = L.VALUE_SIZE_LARGE, value = "large"},
    } end,
    get = function() return db.hudSize end,
    set = function(_, value)
      db.hudSize = value;
      ns.UpdateStyle();
      ns.RefreshSettings();
    end });
  -- Text is read when the page and HUD are built, so a new language needs a reload. The player types /reload:
  -- ReloadUI needs a key or mouse press, and the game blocked it from this dropdown's click.
  Add({ kind = kind.Dropdown, name = L.OPTION_LANGUAGE, default = DEFAULTS.language,
    desc = L.OPTION_LANGUAGE_DESC,
    hidden = function() return #ns.languageOrder < 2 end,
    values = function()
      local values = { { text = L.VALUE_LANGUAGE_AUTO, value = "auto" } };
      for _, code in ipairs(ns.languageOrder) do
        values[#values + 1] = { text = ns.languages[code].name, value = code };
      end
      return values;
    end,
    get = function() return db.language end,
    set = function(_, value)
      if value == db.language then return end
      db.language = value;
      ns.Notify(L.CHAT_RELOAD);
    end });
  -- Shown while the saved choice differs from the language this session loaded.
  local function LanguagePending() return #ns.languageOrder >= 2 and db.language ~= ns.loadedLanguage end
  Add({ kind = kind.Note, name = L.OPTION_LANGUAGE_RELOAD, indent = 1, desc = L.OPTION_LANGUAGE_RELOAD_TEXT,
    hidden = function() return not LanguagePending() end,
    get = function() return L.OPTION_LANGUAGE_RELOAD_TEXT end });
  Add({ kind = kind.Dropdown, name = L.OPTION_FONT,
    desc = function()
      return ns.languageFont and L.OPTION_FONT_DESC .. "\n\n" .. L.OPTION_FONT_LANGUAGE_DESC or L.OPTION_FONT_DESC;
    end,
    default = function() return db.hudStyle == "elv" and DEFAULTS.elvFont or media:GetDefault("font"); end,
    values = function()
      local values = {};
      for _, name in ipairs(media:List("font")) do values[#values + 1] = { text = name, value = name }; end
      return values;
    end,
    get = function() return db.hudStyle == "elv" and ns.ElvTheme.FontName(db) or db.font end,
    disabled = function()
      if ns.languageFont then return true end
      local data = db.hudStyle == "elv" and ns.ElvTheme.Media();
      return data and data.normFont ~= nil;
    end,
    set = function(_, value)
      if db.hudStyle == "elv" then db.elvFont = value; else db.font = value; end
      UpdateFont();
    end });
  Add({ kind = kind.Checkbox, name = L.OPTION_SHOW_ICON, desc = L.OPTION_SHOW_ICON_DESC,
    default = function() return DEFAULTS[ns.styles.Get().showIconKey] end,
    get = function() return ns.styles.ShowIcon(db) end,
    set = function(_, value)
      db[ns.styles.Get().showIconKey] = value;
      UpdateIcon();
      UpdateLayout();
    end });
  Checkbox(L.OPTION_SHOW_BUTTON, "showKey", {
    desc = L.OPTION_SHOW_BUTTON_DESC,
    onChange = function() UpdateKeyCap(); UpdateLayout(); end });
  Add({ kind = kind.Dropdown, name = L.OPTION_BUTTON_STYLE, default = DEFAULTS.keyStyle, indent = 1,
    desc = L.OPTION_BUTTON_STYLE_DESC,
    hidden = function() return ns.styles.Get().ownKey end,
    disabled = KeyHidden,
    -- Classic (Red) needs the game's red button art; a saved choice without it shows Classic (Black).
    values = function()
      local values = { {text = L.VALUE_BUTTON_CLASSIC, value = "classic"} };
      if ns.RedButtonSupported() then values[#values + 1] = {text = L.VALUE_BUTTON_RED, value = "red"}; end
      values[#values + 1] = {text = L.VALUE_BUTTON_PLUNDERSTORM, value = "plunderstorm"};
      return values;
    end,
    get = function() return db.keyStyle end,
    set = function(_, value)
      if ns.styles.Get().ownKey then return end
      db.keyStyle = value;
      ns.UpdateStyle();
    end });
  Checkbox(L.OPTION_SWAP_SIDES, "swapIconAndKey", {
    desc = L.OPTION_SWAP_SIDES_DESC,
    onChange = function() SetIconSide(); UpdateLayout(); end });
  Checkbox(L.OPTION_SKILL_UP, "showSkillUp", {
    desc = L.OPTION_SKILL_UP_DESC,
    hidden = function() return not ns.SkillUpSupported end,
    onChange = UpdateLayout });
  Checkbox(L.OPTION_CAST_BAR, "castBarEnabled", {
    desc = L.OPTION_CAST_BAR_DESC,
    onChange = function()
      ns.RefreshInteractionCastBar();
      ns.RefreshSettings();
    end });
  local function CastBarOff() return not db.castBarEnabled end
  Checkbox(L.OPTION_CAST_TIMER, "castBarTimer", {
    desc = L.OPTION_CAST_TIMER_DESC,
    hidden = function() return not ns.styles.Get().castBar.timer end,
    onChange = ns.RefreshInteractionCastBar, disabled = CastBarOff, indent = 1 });
  Checkbox(L.OPTION_HIDE_GAME_CAST_BAR, "castBarHideGame", {
    desc = L.OPTION_HIDE_GAME_CAST_BAR_DESC,
    onChange = ns.RefreshInteractionCastBar, disabled = CastBarOff, indent = 1 });
  Checkbox(L.OPTION_CAST_CLICKED, "castBarClicked", {
    desc = L.OPTION_CAST_CLICKED_DESC,
    disabled = CastBarOff, indent = 1 });

  -- The game's soft interact range and arc, which Feat\Targeting.lua owns.
  local function TargetingUnavailable() return not ns.TargetingAvailable() end
  local function Yards(value) return L.VALUE_YARDS:format(value) end

  Section(L.SECTION_TARGETING);
  Slider(L.OPTION_INTERACT_RANGE, "interactRange", {
    desc = L.OPTION_INTERACT_RANGE_DESC,
    formatter = Yards, onChange = ns.UpdateTargeting, hidden = TargetingUnavailable,
    locked = ns.ForeverLootSparklesOwnsTargeting });
  Add({ kind = kind.Dropdown, name = L.OPTION_INTERACT_ARC, default = DEFAULTS.interactArc,
    desc = L.OPTION_INTERACT_ARC_DESC,
    hidden = TargetingUnavailable, locked = ns.ForeverLootSparklesOwnsTargeting,
    values = function() return {
      {text = L.VALUE_ARC_STRAIGHT_AHEAD, value = 0, icon = MEDIA .. "ArcStraightAhead"},
      {text = L.VALUE_ARC_NARROW, value = 1, icon = MEDIA .. "ArcNarrow"},
      {text = L.VALUE_ARC_WIDE, value = 2, icon = MEDIA .. "ArcWide"},
    } end,
    get = function() return db.interactArc end,
    set = function(_, value) db.interactArc = value; ns.UpdateTargeting(); end });

  Section(L.SECTION_TARGET_DISPLAYS);
  Checkbox(L.OPTION_TARGET_TOOLTIP, "showBlizzardTooltip", {
    desc = L.OPTION_TARGET_TOOLTIP_DESC,
    onChange = ns.UpdateBlizzardDisplays });
  local PlumberOwns = ns.PlumberOwnsTargetIcons;
  local function TargetIconsChanged()
    ns.UpdateBlizzardDisplays();
    if ns.UpdateObjectName then ns.UpdateObjectName(); end
  end
  -- Checked while either sub-option is on, and grey while only one is, like the AddOn List. Clicking
  -- the grey check turns both on (Feat\Settings.lua).
  Add({ kind = kind.Checkbox, name = L.OPTION_TARGET_ICONS, desc = L.OPTION_TARGET_ICONS_DESC,
    locked = PlumberOwns,
    default = DEFAULTS.showNpcIcons or DEFAULTS.showObjectIcons,
    get = function() return db.showNpcIcons or db.showObjectIcons end,
    partial = function() return db.showNpcIcons ~= db.showObjectIcons end,
    set = function(_, value)
      db.showNpcIcons, db.showObjectIcons = value, value;
      TargetIconsChanged();
    end });
  local function NoSeparateIcons() return not ns.SeparateTargetIcons end
  Checkbox(L.OPTION_TARGET_ICONS_NPC, "showNpcIcons", {
    desc = L.OPTION_TARGET_ICONS_NPC_DESC, indent = 1, locked = PlumberOwns,
    hidden = NoSeparateIcons, onChange = TargetIconsChanged });
  Checkbox(L.OPTION_TARGET_ICONS_OBJECT, "showObjectIcons", {
    desc = L.OPTION_TARGET_ICONS_OBJECT_DESC, indent = 1, locked = PlumberOwns,
    hidden = NoSeparateIcons, onChange = TargetIconsChanged });
  Checkbox(L.OPTION_OBJECT_NAMES, "showObjectNames", {
    desc = L.OPTION_OBJECT_NAMES_DESC,
    locked = function() return PlumberOwns() or ns.PlaterDrawsObjectNames() end,
    hidden = function() return not ns.ObjectNamesSupported end,
    onChange = function()
      ns.UpdateBlizzardDisplays();
      ns.UpdateObjectName();
    end });
  Checkbox(L.OPTION_QUEST_LOOT_EFFECT, "showQuestLootEffect", {
    desc = L.OPTION_QUEST_LOOT_EFFECT_DESC, locked = ns.ForeverLootSparklesOwnsQuestEffect,
    hidden = function() return not ns.QuestLootEffectAvailable() end,
    onChange = ns.UpdateQuestLootEffect });
  -- Objects need their plate for the dust, which Feat\HideBlizzard.lua and Feat\ObjectNames.lua provide.
  -- The rows exist on every client but are hidden where Feat\LootEffect.lua doesn't load.
  local function LootEffectChanged()
    ns.UpdateBlizzardDisplays();
    if ns.UpdateObjectName then ns.UpdateObjectName(); end
    if ns.UpdateLootEffect then ns.UpdateLootEffect(); end
  end
  local LOOT_EFFECT_KEYS = { "lootEffectOre", "lootEffectHerbs", "lootEffectQuest" };
  local function LootEffectOwnedElsewhere(key) return ns.LootEffectOwnedElsewhere ~= nil and ns.LootEffectOwnedElsewhere(key) end
  local function NoLootEffect() return not ns.LootEffectSupported end
  -- Checked while any sub-option is on and grey while they differ, like Show Target Icons. Clicking it sets
  -- all three. It locks while Forever Loot Sparkles owns any of them, so the locked rows stay together under
  -- one conflict box; a free sub-option still works on its own.
  Add({ kind = kind.Checkbox, name = L.OPTION_LOOT_EFFECT, desc = L.OPTION_LOOT_EFFECT_DESC,
    default = DEFAULTS.lootEffectOre or DEFAULTS.lootEffectHerbs or DEFAULTS.lootEffectQuest,
    hidden = NoLootEffect,
    locked = function()
      for _, key in ipairs(LOOT_EFFECT_KEYS) do if LootEffectOwnedElsewhere(key) then return true end end
      return false;
    end,
    get = function() return db.lootEffectOre or db.lootEffectHerbs or db.lootEffectQuest end,
    partial = function() return not (db.lootEffectOre == db.lootEffectHerbs and db.lootEffectHerbs == db.lootEffectQuest) end,
    set = function(_, value)
      for _, key in ipairs(LOOT_EFFECT_KEYS) do db[key] = value; end
      LootEffectChanged();
    end });
  for _, option in ipairs({
    { L.OPTION_LOOT_EFFECT_ORE, "lootEffectOre", L.OPTION_LOOT_EFFECT_ORE_DESC },
    { L.OPTION_LOOT_EFFECT_HERBS, "lootEffectHerbs", L.OPTION_LOOT_EFFECT_HERBS_DESC },
    { L.OPTION_LOOT_EFFECT_QUEST, "lootEffectQuest", L.OPTION_LOOT_EFFECT_QUEST_DESC },
  }) do
    local key = option[2];
    Checkbox(option[1], key, {
      desc = option[3], indent = 1, locked = function() return LootEffectOwnedElsewhere(key) end,
      hidden = NoLootEffect, onChange = LootEffectChanged });
  end
  -- Reads and writes Plumber's own Show Cast Bar setting, so the two pages always agree. Plumber reads it
  -- when it loads and has no public way to read it again, so a change needs a reload, which the player types
  -- for the same reason as the Language option.
  Add({ kind = kind.Checkbox, name = L.OPTION_PLUMBER_CAST_BAR, desc = L.OPTION_PLUMBER_CAST_BAR_DESC, default = false,
    hidden = function() return not PlumberOwns() end,
    get = function() return _G.PlumberDB ~= nil and _G.PlumberDB.SoftTarget_CastBar == false end,
    set = function(_, value)
      local plumber = _G.PlumberDB;
      if not plumber or plumber.SoftTarget_CastBar == not value then return end
      plumber.SoftTarget_CastBar = not value;
      ns.Notify(L.CHAT_RELOAD);
    end });

  return settings;
end
