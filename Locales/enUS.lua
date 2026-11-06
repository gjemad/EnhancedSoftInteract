local _, ns = ...;

----
--  English text, and the fallback for every language.
--
--  To add a language, copy this file to Locales/<code>.lua and change the first line below to your code,
--  your language's own name and the name to credit, for example:
--    ns.AddLanguage("nbNO", "Norsk", "YourName", {
--  Then translate the right side of each line. A line you delete stays in English. Keep every %s and %d, in
--  the same order. The comment after a line says what they hold.
--
--  Codes for the game's languages: enUS, deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW
--  (https://warcraft.wiki.gg/wiki/API_GetLocale). These load by themselves on a client in that language.
--  Any other language works too: players pick it under Language in the settings. Use a lowercase language
--  code and an uppercase country code, such as nbNO, svSE, daDK, fiFI, nlNL, plPL, trTR or ukUA
--  (https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes,
--  https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes).
--
--  How to send a translation: see the README (https://github.com/gjemad/EnhancedSoftInteract).
--
--  Prefixes: HUD_ the HUD itself. SECTION_ settings headers. OPTION_ settings rows, with _DESC for the
--  tooltip. VALUE_ dropdown choices and slider values. STYLE_ HUD styles. SETTINGS_ the rest of the
--  settings page. PREVIEW_ the preview's checkboxes. CHAT_ chat messages. GAME_ the game's own option
--  names, used only if the game doesn't provide them.
----
ns.AddLanguage("enUS", "English", nil, {
  ----  HUD  ----
  HUD_MOVE_CLOSER = "Move closer",
  HUD_SKILL_TOO_LOW = "Too low skill level (%d/%d)", --your skill, the skill the node needs
  HUD_KEY_NUMPAD = "N%s", --a numpad key on the button: the digit or symbol, as in N3 or N+

  ----  HUD styles  ----
  STYLE_LEVEL_UP_LINE = "Level-Up Line",
  STYLE_RUNIC_LINE = "Runic Line",
  STYLE_PLAIN_TEXT = "Plain Text",

  ----  Settings: Enabled and Interact Key  ----
  OPTION_ENABLED = "Enabled",
  OPTION_ENABLED_DESC = "Shows the HUD for your soft target.",
  OPTION_ALWAYS_INTERACT_KEY = "Always Enable Interact Key",
  OPTION_ALWAYS_INTERACT_KEY_DESC = "Turns the game's interact key back on if something turns it off.",
  OPTION_INTERACT_KEY = "Interact Key",
  OPTION_INTERACT_KEY_DESC = "Sets the keys you interact with.\n\nClick a slot, then press a key. Right-click clears it.",
  OPTION_AUTO_LOOT_CONFLICT = "Auto-Loot Conflict",
  OPTION_AUTO_LOOT_CONFLICT_TEXT = 'Auto Loot Key conflict: %s is already bound to "%s".', --the key, the action
  OPTION_AUTO_LOOT_CONFLICT_DESC = "Your Auto Loot Key is %s and your Interact Key is %s.", --the modifier, the key
  OPTION_AUTO_LOOT_CONFLICT_CLEAR_DESC = 'Clear removes "%s" from %s.', --the action, the key
  OPTION_INTERACT_SOUND_DESC = "Plays a sound when you can interact with a target, and when you no longer can.",
  OPTION_ALWAYS_INTERACT_ICONS = "Always Show All Interact Key Icons",
  OPTION_ALWAYS_INTERACT_ICONS_DESC = "Keeps the game's Interact Key Icons on Show All, so the HUD can show the right icon for every target.",

  ----  Settings: Appearance  ----
  SECTION_APPEARANCE = "Appearance",
  OPTION_STYLE = "Style",
  OPTION_STYLE_DESC = "Changes the look of the HUD.",
  OPTION_SIZE = "Size",
  OPTION_SIZE_DESC = "Sets the size of the HUD.",
  VALUE_SIZE_SMALL = "Small",
  VALUE_SIZE_NORMAL = "Normal",
  VALUE_SIZE_LARGE = "Large",
  OPTION_FONT = "Font",
  OPTION_FONT_DESC = "Changes the font of the HUD's text.",
  OPTION_LANGUAGE = "Language",
  OPTION_LANGUAGE_DESC = "Sets the language of this addon. Changing it reloads the interface.",
  VALUE_LANGUAGE_AUTO = "Game Language",
  OPTION_SHOW_ICON = "Show Icon",
  OPTION_SHOW_ICON_DESC = "Shows the interaction icon in the HUD.",
  OPTION_SHOW_BUTTON = "Show Interact Button",
  OPTION_SHOW_BUTTON_DESC = "Shows the interact button in the HUD.",
  OPTION_BUTTON_STYLE = "Button Style",
  OPTION_BUTTON_STYLE_DESC = "Changes the artwork of the interact button.",
  VALUE_BUTTON_CLASSIC = "Classic",
  VALUE_BUTTON_PLUNDERSTORM = "Plunderstorm",
  OPTION_SWAP_SIDES = "Swap Icon and Interact Button positions",
  OPTION_SWAP_SIDES_DESC = "Moves the icon to the right side and the interact button to the left.",
  OPTION_SKILL_UP = "Show Skill-Up Icon",
  OPTION_SKILL_UP_DESC = "Shows an icon next to the name when the target can raise your profession skill.",
  OPTION_CAST_BAR = "Enable Cast Bar",
  OPTION_CAST_BAR_DESC = "Shows a cast bar in the HUD while you gather or open something.",
  OPTION_CAST_TIMER = "Show Cast Bar Timer",
  OPTION_CAST_TIMER_DESC = "Shows the seconds left on your cast.",
  OPTION_HIDE_GAME_CAST_BAR = "Auto Hide Default Cast Bar",
  OPTION_HIDE_GAME_CAST_BAR_DESC = "Hides the default cast bar while the HUD shows a cast.",
  OPTION_CAST_CLICKED = "Show for Clicked Objects",
  OPTION_CAST_CLICKED_DESC = "Also shows the cast bar when you click an object.",

  ----  Settings: Targeting  ----
  SECTION_TARGETING = "Targeting",
  OPTION_INTERACT_RANGE = "Interaction Range",
  OPTION_INTERACT_RANGE_DESC = "Sets how far away your interact key finds targets.\n\nGame objects have a 20 yard limit. Above that, the range only affects friendly targets.",
  VALUE_YARDS = "%d yards", --the distance
  OPTION_INTERACT_ARC = "Interaction Arc",
  OPTION_INTERACT_ARC_DESC = "Sets how wide an area in front of you your interact key searches for targets.",
  VALUE_ARC_STRAIGHT_AHEAD = "Straight Ahead",
  VALUE_ARC_NARROW = "Narrow",
  VALUE_ARC_WIDE = "Wide",

  ----  Settings: Target Displays  ----
  SECTION_TARGET_DISPLAYS = "Target Displays",
  OPTION_TARGET_TOOLTIP = "Show Target Tooltip",
  OPTION_TARGET_TOOLTIP_DESC = "Shows the game's tooltip for your soft target.",
  OPTION_TARGET_ICONS = "Show Target Icons",
  OPTION_TARGET_ICONS_DESC = "Shows the game's interaction icon above your soft target.",
  OPTION_TARGET_ICONS_NPC = "NPCs",
  OPTION_TARGET_ICONS_NPC_DESC = "Shows the icon above NPCs.",
  OPTION_TARGET_ICONS_OBJECT = "Objects",
  OPTION_TARGET_ICONS_OBJECT_DESC = "Shows the icon above objects.",
  OPTION_OBJECT_NAMES = "Show Object Names",
  OPTION_OBJECT_NAMES_DESC = "Shows the name above your soft target when it's an object.",
  OPTION_QUEST_LOOT_EFFECT = "Show Quest Item Loot Effect",
  OPTION_QUEST_LOOT_EFFECT_DESC = "Turns on the game's loot effect for quest items you can loot. To turn it off again, uncheck this and log out and back in. /reload isn't enough.",
  OPTION_LOOT_EFFECT = "Show Target Loot Effect",
  OPTION_LOOT_EFFECT_DESC = "Shows a loot effect on your soft target when it's an ore vein, a herb or a quest object.",
  OPTION_LOOT_EFFECT_ORE = "Ore Veins",
  OPTION_LOOT_EFFECT_ORE_DESC = "Shows the loot effect on ore veins.",
  OPTION_LOOT_EFFECT_HERBS = "Herbs",
  OPTION_LOOT_EFFECT_HERBS_DESC = "Shows the loot effect on herbs.",
  OPTION_LOOT_EFFECT_QUEST = "Quest Objects",
  OPTION_LOOT_EFFECT_QUEST_DESC = "Shows the loot effect on objects you need for a quest.",
  OPTION_PLUMBER_CAST_BAR = "Hide Plumber Cast Bar",
  OPTION_PLUMBER_CAST_BAR_DESC = "Hides the radial cast bar on Plumber's soft target nameplate. This changes Show Cast Bar in Plumber's settings and reloads the UI.",
  CONFLICT_TITLE = "Conflicting AddOns",
  CONFLICT_INTRO = "Another addon controls these options.",
  CONFLICT_PLUMBER = 'Plumber handles the target icons and names. To change these options, turn off "Nameplate: Soft Target" in Plumber.',
  CONFLICT_PLATER = 'Plater handles object names. To use Show Object Names, turn on "Hide Plater names game objects" in Plater.',
  CONFLICT_FOREVER_LOOT_SPARKLES_TARGETING = 'Forever Loot Sparkles handles the interaction range, arc and target loot effect. To change these options, turn off "Ore veins", "Herbs", "Quest objects" and "Corpses with loot" in Forever Loot Sparkles.',
  CONFLICT_FOREVER_LOOT_SPARKLES_QUEST = 'Forever Loot Sparkles handles the loot effect on quest items. To change it here, turn off "Show quest item sparkles" in Forever Loot Sparkles.',

  ----  Settings page  ----
  SETTINGS_SUBTITLE = "Customize the HUD here. Use Edit Mode to move it.",
  SETTINGS_MOVE_HUD = "Move HUD in Edit Mode",
  SETTINGS_MOVE_HUD_DESC = "Opens Edit Mode so you can drag the HUD.",
  SETTINGS_OPEN = "Open Settings", --the button on the HUD in Edit Mode
  SETTINGS_PRESS_KEY = "Press a key",
  SETTINGS_CLEAR = "Clear",
  SETTINGS_RESET = "Reset %s", --the option's name
  SETTINGS_RESET_DESC = "Restores this option to its default: %s.", --the default value
  SETTINGS_ON = "On",
  SETTINGS_OFF = "Off",

  ----  Settings preview  ----
  PREVIEW_HINT = "Click for another target",
  PREVIEW_ANIMATE = "Animate",
  PREVIEW_ANIMATE_DESC = "Plays the interaction every few seconds.",
  PREVIEW_MOVE_CLOSER_DESC = "Shows the target as out of range.",
  PREVIEW_REQUIRES = "Requires profession",
  PREVIEW_REQUIRES_DESC = "Shows the missing profession message.",
  PREVIEW_CAST = "Cast bar",
  PREVIEW_CAST_DESC = "Shows a cast bar on targets you gather or open.",
  PREVIEW_SECRET = "Secret name",
  PREVIEW_SECRET_DESC = "Shows a target whose name the game keeps secret from addons.",

  ----  About page  ----
  ABOUT = "About",
  ABOUT_VERSION = "Version %s", --the addon's version
  ABOUT_COMMANDS = "Commands",
  ABOUT_COMMAND_SETTINGS = "Opens the settings",
  ABOUT_COMMAND_EDIT_MODE = "Opens Edit Mode",
  ABOUT_COMMAND_DEBUG = "Opens the debug window",
  ABOUT_TRANSLATORS = "Translators",
  ABOUT_NO_TRANSLATIONS = "No translations yet",
  ABOUT_HELP_OUT = "Help Out",
  ABOUT_REPORT_BUG = "Report a Bug",
  ABOUT_HELP_TRANSLATE = "Help Translate",
  ABOUT_CURSEFORGE = "CurseForge Page",
  ABOUT_COPY_HINT = "To copy a link, click it and press Ctrl+C.",
  ABOUT_DEPENDENCIES = "Dependencies",
  ABOUT_LIBRARIES = "Libraries",
  ABOUT_FONTS = "Fonts",

  ----  Chat messages  ----
  CHAT_SETTINGS_IN_COMBAT = "Settings can't be opened in combat.",
  CHAT_EDIT_MODE_IN_COMBAT = "Edit Mode can't be opened in combat.",
  CHAT_EDIT_MODE_UNAVAILABLE = "Edit Mode isn't available.",
  CHAT_EDIT_MODE_UNAVAILABLE_NOW = "Edit Mode isn't available right now.",
  CHAT_EDIT_MODE_CLOSE_FIRST = "Close the main Edit Mode window to open Enhanced Soft Interact settings.",
  CHAT_BINDINGS_IN_COMBAT = "Key bindings can't be changed in combat.",
  CHAT_QUEST_LOOT_EFFECT_LOG_OUT = "The quest item loot effect goes away after you log out and back in. /reload isn't enough.",
  CHAT_KEY_UNBOUND = '%s is no longer bound to "%s".', --the key, the action
  CHAT_KEPT_INTERACT_KEY = '"%s" was turned back on. To turn it off, first uncheck "%s" in /esi.', --the game's option, the checkbox
  CHAT_KEPT_INTERACT_ICONS = '"%s" was set back to Show All. To change it, first uncheck "%s" in /esi.', --the game's option, the checkbox

  ----  The game's option names  ----
  GAME_ENABLE_INTERACT_KEY = "Enable Interact Key",
  GAME_INTERACT_KEY_ICONS = "Interact Key Icons",
  GAME_INTERACT_SOUND = "Interact Key Sound Cue",

  ----  Gathering nodes  ----
  -- Optional. Nodes are found by ID in every language; names are only a fallback for unknown IDs.
  -- A language file fills its own table, pairing the English name from Data/GatherSkill.lua with the name
  -- the game shows, for example:
  --   NODE_NAMES = {
  --     ["Peacebloom"] = "Friedensblume",
  --     ["Silverleaf"] = "Silberblatt",
  --   },
  NODE_NAMES = {},
});
