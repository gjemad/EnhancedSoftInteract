local _, ns = ...;

-- English text, and the fallback for every language. A translation is a file loaded after this one that
-- replaces entries in ns.L when GetLocale() matches, so an untranslated entry stays in English.
ns.L = {
  -- Chat messages
  SETTINGS_IN_COMBAT = "Settings can't be opened in combat.",
  EDIT_MODE_IN_COMBAT = "Edit Mode can't be opened in combat.",
  EDIT_MODE_UNAVAILABLE = "Edit Mode isn't available.",
  EDIT_MODE_UNAVAILABLE_NOW = "Edit Mode isn't available right now.",
  EDIT_MODE_CLOSE_FIRST = "Close the main Edit Mode window to open Enhanced Soft Interact settings.",
  BINDINGS_IN_COMBAT = "Key bindings can't be changed in combat.",
  KEY_UNBOUND = '%s is no longer bound to "%s".', --the key, the action
  KEPT_INTERACT_KEY = '"%s" was turned back on. To turn it off, first uncheck "%s" in /esi.', --the game's option, the checkbox
  KEPT_INTERACT_ICONS = '"%s" was set back to Show All. To change it, first uncheck "%s" in /esi.', --the game's option, the checkbox
};
