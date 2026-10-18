local _, ns = ...;
ns.styles.Register("floating", { name = "Plain Text", shadow = true,
  sizes = {
    small = { fontSize = 14, iconSize = 24, keyHeight = 22.75, glyphHeight = 22.75, keyFontSize = 14, inputScale = 0.875, nameMinWidth = 85, nameMaxWidth = 220, hudHeight = 40, gap = 7, edgeInset = 6 },
    normal = { fontSize = 16, iconSize = 28, keyHeight = 26, glyphHeight = 26, keyFontSize = 16, inputScale = 1, nameMinWidth = 100, nameMaxWidth = 250, hudHeight = 46, gap = 8, edgeInset = 7 },
    large = { fontSize = 20, iconSize = 34, keyHeight = 32.5, glyphHeight = 32.5, keyFontSize = 20, inputScale = 1.25, nameMinWidth = 125, nameMaxWidth = 310, hudHeight = 58, gap = 10, edgeInset = 9 },
  },
  castBar = { height = 1.2, offset = 5.5, success = "softBloom", interrupt = "sink",
    glow = { tail = 24, tailHeight = 7, tailAlpha = 0.78, haloWidth = 7, haloHeight = 9, haloAlpha = 0.4,
      coreWidth = 2.8, coreHeight = 2.8, coreAlpha = 0.95, needle = true, breathHeight = 7, breathStrength = 0.75 } },
});
