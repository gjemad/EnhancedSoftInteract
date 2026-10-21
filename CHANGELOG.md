# Changelog

## 0.4.1 (2026-10-21)

### Bug fixes

- Fixed out of range issues when looting NPCs.
- Fixed out of range issues when using game objects.

## 0.4.0 (2026-10-21)

### Features

- Added Interaction Range and Interaction Arc options, which set how far away and how wide an area your interact key searches for targets.
- Herbs, ore and skinnable corpses can show a skill-up icon next to the name when they can raise your profession skill.

### Improvements

- You can now set your interact key and the game's interact sound cue from the settings page.
- The HUD now fades in and out a little faster.
- Updated the cast bar effects.
- Elv's panel lights up when you interact.
- The settings page is simpler, with shorter tooltips.
- The preview shows skill-up icons.

### Changes

- Removed the size, color, shadow and animation options. Each style now sets its own look.
- Renamed some options to make them clearer.
- Show for Clicked Objects is now on by default.

### Bug fixes

- Fixed the Elv button flashing yellow when pressed.
- Fixed cast bar markers sometimes sitting slightly off the line.

### Package

- Shrunk some custom art to reduce package size.

## 0.3.4-alpha (2026-10-19)

### Improvements

- Cleaned up the addon's code so it is easier to maintain. Nothing should look or work differently.

## 0.3.3 (2026-10-19)

### Improvements

- Elv's sizes are 10% larger, like the other styles.
- Chat messages now start with "Enhanced Soft Interact:", and Persistence messages say what was put back and point to /esi.

### Bug fixes

- Fixed controller interaction stopping after changing a setting while a controller is connected.
- Fixed Elv showing only part of controller buttons.
- Fixed buttons overlapping the lines in Level-Up Line.

## 0.3.2 (2026-10-19)

### Features

- Added Small, Normal and Large HUD sizes, with separate sliders for button and icon size.
- Added a Classic button style, used by default outside Retail.
- Cast bars now have glows and success and interrupt effects that match each style.
- Added an option, on by default, to hide the default cast bar while the HUD shows a cast.
- The settings preview can show a target out of range, a missing profession and a cast bar.
- Modifier keys light up on the button while you hold them.
- Elv shows controller buttons and short modifier labels inside its button.

### Improvements

- Icons, buttons, names and lines now line up the same way in every style.
- The Elv style now follows ElvUI's look more closely.
- Key labels use the game's own short names.
- The preview shows more kinds of targets.
- The settings preview stays in view while you scroll, and option descriptions are clearer.
- If Persistence undoes a change you made in the game's options, a chat message tells you which setting to turn off.

### Changes

- Renamed Floating Text to Plain Text.
- Removed the Plain Bar style.

### Bug fixes

- Fixed font changes not showing on the HUD and preview right away.
- Fixed the Runic Line underline sometimes looking thicker than it is.
- Cast bars no longer stop as the HUD fades out.
- A new target no longer cuts off a cast's success or interrupt effect.

## 0.3.1 (2026-10-11)

### Features

- Added the Elv style with optional ElvUI integration.
- Added PT Sans Narrow for the Elv style.
- Moved settings to Interface > AddOns, with a HUD preview.
- Edit Mode now focuses on moving the HUD, with a button to open addon settings.
- Added buttons to reset individual settings.
- Added clearer setting descriptions with screenshot examples.
- Added separate controls for the game's target icons and tooltips.

### Improvements

- Improved icon sizing and key alignment.
- Added colors for more Retail interaction types.

### Bug fixes

- Fixed animations getting stuck or carrying over when switching styles.
- Fixed font changes not updating the HUD and preview.
- Fixed target icon and tooltip settings not applying correctly.

## 0.3.0 (2026-10-10)

### Features

- Added support for Classic Era, TBC Anniversary and Mists of Pandaria Classic.
- Improved spacing in the Plain Bar and Runic Line styles.
- Made the Plain Bar interaction glow softer.

### Bug fixes

- Fixed skinnable corpses showing as out of range on Classic when the interact key could already skin them.
- Fixed missing or incorrect profession requirement messages on Classic.
- Fixed incorrect icons and range messages for guards on Classic.
- Fixed brief "Move closer" messages when closing gathering loot windows.
- Smoothed transitions when moving into and out of interaction range.

## 0.2.3 (2026-10-05)

### Features

- Added optional cast bars for gathering and opening objects.
- Changed the default font size to 16.

### Bug fixes

- Fixed incorrect text sizing when switching targets.

## 0.2.2 (2026-10-04)

### Features

- Replaced the red keybind indicator with a "Move closer" message when out of range.

## 0.2.1-beta (2026-10-04)

- Updated and included project license.

## 0.2.0-beta (2026-10-04)

### Features

- Added Floating Text, Plain Bar and Runic Line styles.
- Added a Shadow Strength slider.

### Bug fixes

- Fixed HUD and preview animations that sometimes looked inconsistent.

## 0.1.6-beta (2026-10-04)

### Features

- Edit Mode now groups visual settings under Appearance with one animation toggle.
- Updated the default settings. The normal key size is now 100%.

### Bug fixes

- Fixed overflowing controls and tooltips in Edit Mode.

## 0.1.5-beta (2026-10-04)

### Bug fixes

- The debug window keeps your scroll position and logs when a target clears.
- Turning off Fade Animations now stops HUD fading immediately.

## 0.1.4-beta (2026-10-04)

### Features

- The debug window now has timestamped logs, filters and a selectable time range for troubleshooting.
- The debug log now keeps up to 2,000 events.

## 0.1.3-beta (2026-10-04)

### Bug fixes

- Fixed HUD animations that sometimes looked inconsistent.

## 0.1.2-beta (2026-10-04)

### Features

- A new option in Edit Mode lets you keep Blizzard's soft target tooltip and nameplate next to the HUD.

### Bug fixes

- The Interact Key now stays on while you use the gamepad UI.
- The addon no longer prints a chat message each time it turns the Interact Key back on.
- Turning the addon off now brings Blizzard's soft target tooltip and nameplate back on WoW: Forever.

## 0.1.1-beta (2026-10-03)

### Bug fixes

- Corpses and objects no longer show a cog on the HUD when Interact Key Icons isn't set to Show All. The addon now keeps that setting on Show All, and you can turn this off in Edit Mode.

## 0.1.0-beta (2026-10-03)

### Features

- All settings are now in Edit Mode, and the addon's options page is gone.
- You can turn the addon off with the new Enabled option in Edit Mode.
- Edit Mode shows a preview of the HUD next to its settings.

### Bug fixes

- Turning off your gamepad no longer leaves the Interact Key turned off.

## 0.0.5-beta (2026-10-03)

### Features

- The key cap follows your interact key. It stays pressed in and dark while you hold the key. This works for keyboard keys, key combinations such as Shift-F, and gamepad buttons.
- The ripple plays when the interaction happens. If holding the key interacts before you let go, the key cap springs back right then. Each further interaction during the same hold plays a quick tap.

### Bug fixes

- Typing in chat doesn't press the key cap.

## 0.0.4-beta (2026-10-03)

### Features

- When you interact, the key cap or gamepad button shrinks toward its center and darkens for a moment, and a ring ripples out from its edge. Keys used to dip down instead.

### Bug fixes

- A gamepad button glyph is smaller, so it fits between the HUD's lines instead of running past them.
- When the target changes, the icon glow fades in with the new icon. Before, the glow showed the old color at the new spot first.
- When the target goes in or out of range, the HUD dims or brightens over 0.2 seconds, together with its colors. Before, it dropped to 75% almost at once while the colors were still blending.
- Out of range, a gamepad button glyph turns a clear red. It used to go nearly black, because the red tint multiplied the glyph's own color.

## 0.0.3-beta (2026-10-03)

### Features

- Debug pages show the HUD width and name column in whole units.

### Bug fixes

- The debug window's portrait shows the cog centered in its ring, at the size Blizzard's bag frames use. The cog used to sit off-center and reach past the ring.
- The first line of a debug page no longer starts under the portrait.

## 0.0.2-beta (2026-10-03)

### Features

- `/esi debug` opens a debug window instead of printing to chat. Each soft target event is a page, like an error in BugSack. Previous and Next browse the pages, and shift-click jumps to the first or last one. The addon keeps the last 100 events of the session, also while the window is closed.
- Copy selects the current page and Copy All selects every page, so Ctrl+C copies them. Clear empties the log.

## 0.0.1-beta (2026-10-03)

### Features

- Every target type has a new color. Each type keeps its familiar hue (herbs green, mail red, innkeeper blue), and the bank now has its own pale gold instead of sharing the vendor's brown.
- Out of interact range, the key label turns red, like an action button's hotkey, and the HUD fades to 75% instead of 50%. In range it shows at full opacity.
- A target without a cursor icon shows the Interact cog, or the Unable cog out of range, the way Blizzard's gamepad action bar does.
- The HUD identifies the cursor icon by its atlas name first, then by its path and file ID.
- The sliders have new ranges:
  - Icon Size 16 to 48
  - Font Size 10 to 32
  - Shadow Height 20 to 80
- Shadow Height and Swap Icon and Key reset to their defaults once, because the addon renamed their saved settings.
- The addon list shows a new description, "Shows your soft interact target's name, action and keybind in a frame you can customize."

## 0.0.0-beta (2026-10-03)

This is the first release.

### Features

- The addon shows your soft interact target in a frame on screen. The frame has the target's name, the cursor icon for the action (talk, loot, skin, mine, quest, vendor and more) and your interact key on a key cap. With a gamepad, the key cap shows the button's glyph.
- The frame's lines and icon glow take the target type's color. Out of range, the frame dims and turns grey.
- Herbs and ore you can't gather show "Requires Herbalism" or "Requires Mining" under the name.
- Talkable NPCs with a generic icon get the speech bubble.
- The frame plays an animation when you interact and when the target changes, and it fades in and out. You can turn each of these off.
- You can move and style the frame in Edit Mode. The settings cover icon and key size, font, name width, color brightness, shadow height and animations. Each Edit Mode layout keeps its own position.
- Options > AddOns > Enhanced Soft Interact has the Enable Interact Key setting and the interact keybind. `/esi` opens Edit Mode and `/esi options` opens the options.
- The addon hides Blizzard's own soft target tooltip and nameplate while it runs.
- The addon works on retail and WoW: Forever.
