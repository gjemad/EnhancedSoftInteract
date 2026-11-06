# EnhancedSoftInteract

All rights reserved. See [LICENSE.txt](LICENSE.txt). Bundled third-party libraries
retain their own licenses.

## Translating

You can translate the addon into any language, including one the game itself doesn't have, such as Norwegian.

1. Copy [Locales/enUS.lua](Locales/enUS.lua) to `Locales/<code>.lua`. Use the game's code if it has your language: enUS, deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN or zhTW ([list](https://warcraft.wiki.gg/wiki/API_GetLocale)). Otherwise use a lowercase [language code](https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes) and an uppercase [country code](https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes), such as nbNO.
2. Change the file's first line to your code, your language's own name and the name you want credited: `ns.AddLanguage("nbNO", "Norsk", "YourName", {`
3. Translate the text on the right side of each line. A line you delete stays in English. Keep every `%s` and `%d`, in the same order; the comment after a line says what they hold. Save the file as UTF-8.
4. Send it as a pull request, or attach it to an [issue](https://github.com/gjemad/EnhancedSoftInteract/issues).

You may copy `Locales/enUS.lua` to make a translation. By sending a translation, you agree that it can ship with the addon under the terms in LICENSE.txt, and your name goes in the credits.
