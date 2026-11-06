local _, ns = ...;

-- The addon's text. English goes into ns.L as its file loads, so any line a language leaves out stays in
-- English. Other languages wait in ns.languages until the settings load, because the saved choice isn't
-- readable while files load. Every language file always loads: the game only ever reports its own eleven
-- client languages, so a language like Norwegian can only come from the player's choice in the settings.
ns.L = {};
ns.languages = {}; --code -> { name, translators, entries }
ns.languageOrder = {}; --codes, in TOC order

local ENGLISH = "enUS";

-- name: the language's name in that language. translators: the names to credit, as one string.
function ns.AddLanguage(code, name, translators, entries)
  ns.languages[code] = { name = name, translators = translators, entries = entries };
  ns.languageOrder[#ns.languageOrder + 1] = code;
  if code == ENGLISH then
    for key, text in pairs(entries) do ns.L[key] = text; end
  end
end

-- choice: a language code, or "auto" for the game's language. English is already in place, and a code with
-- no file stays in English.
function ns.ApplyLanguage(choice)
  local language = ns.languages[choice == "auto" and GetLocale() or choice];
  if not language then return end
  for key, text in pairs(language.entries) do ns.L[key] = text; end
end
