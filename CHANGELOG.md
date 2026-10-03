# Changelog

## Unreleased

- A gamepad button glyph is smaller, so it fits between the HUD's lines instead of running past them.
- Interacting presses a gamepad button the way Blizzard's gamepad action bar does: it shrinks with its bottom edge in place. Keyboard keys still dip.
- When the target changes, the icon glow fades in with the new icon instead of showing the old color at the new spot first.
- Going in or out of range, the HUD dims or brightens over 0.2 seconds together with its colors. It used to drop to 75% almost at once while the colors still blended.
- Out of range, a gamepad button glyph turns a clear red. It used to go nearly black, because the red tint multiplied the glyph's own color.

## 1.0.3-beta (2026-10-03)

- The debug window's portrait shows the cog centered in its ring, at the size Blizzard's bag frames use. The cog used to sit off-center and reach past the ring.
- The first line of a debug page no longer starts under the portrait.
- Debug pages show the HUD width and name column in whole units.

## 1.0.2-beta (2026-10-03)

- `/esi debug` opens a debug window instead of printing to chat. It works like BugSack: each soft target event is a page, Previous and Next browse them, and shift-click jumps to the first or last page. The addon keeps the last 100 events of the session, also while the window is closed.
- Copy selects the current page and Copy All selects every page, so Ctrl+C copies them. Clear empties the log.

## 1.0.1-beta (2026-10-03)

- New colors for every target type. Each type keeps its familiar hue (herbs green, mail red, innkeeper blue), and the bank now has its own pale gold instead of sharing the vendor's brown.
- Out of interact range, the key label turns red, like an action button's hotkey, and the HUD fades to 75% instead of 50%. In range it shows at full opacity.
- A target without a cursor icon shows the Interact cog, or the Unable cog out of range, the way Blizzard's gamepad action bar does.
- The HUD identifies the cursor icon by its atlas name first, then by its path and file ID.
- New slider ranges: Icon Size 16 to 48, Font Size 10 to 32, Shadow Height 20 to 80.
- Shadow Height and Swap Icon and Key reset to their defaults once, because their saved settings were renamed.
- New addon list description: "Shows your soft interact target's name, action and keybind in a frame you can customize."

## 1.0.0-beta (2026-10-03)

First release.

- An on-screen frame for your soft interact target: its name, the cursor icon for the action (talk, loot, skin, mine, quest, vendor and more), and your interact key on a key cap. A gamepad shows its button glyph.
- The frame's lines and icon glow take the target type's color. Out of range, the frame dims and turns grey.
- Herbs and ore you can't gather show "Requires Herbalism" or "Requires Mining" under the name.
- Talkable NPCs with a generic icon get the speech bubble.
- Animations when you interact and when the target changes, plus fade in and out. Each can be turned off.
- Move and style the frame in Edit Mode: icon and key size, font, name width, color brightness, shadow height and animations. Each Edit Mode layout keeps its own position.
- Options > AddOns > Enhanced Soft Interact has the Enable Interact Key setting and the interact keybind. `/esi` opens Edit Mode and `/esi options` opens the options.
- Hides Blizzard's own soft target tooltip and nameplate while the addon runs.
- Works on retail and WoW: Forever.
