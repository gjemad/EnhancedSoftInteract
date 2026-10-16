local _, ns = ...;
ns.styles.Register("floating", { name = "Plain Text", shadow = true,
  sizes = {
    small = { fontSize = 14, iconSize = 24, keyHeight = 22, glyphHeight = 22, keyFontSize = 14, inputScale = 0.875, nameMinWidth = 85, nameMaxWidth = 220, hudHeight = 40, gap = 7, edgeInset = 6 },
    normal = { fontSize = 16, iconSize = 28, keyHeight = 25, glyphHeight = 25, keyFontSize = 16, inputScale = 1, nameMinWidth = 100, nameMaxWidth = 250, hudHeight = 46, gap = 8, edgeInset = 7 },
    large = { fontSize = 20, iconSize = 34, keyHeight = 30, glyphHeight = 30, keyFontSize = 20, inputScale = 1.25, nameMinWidth = 125, nameMaxWidth = 310, hudHeight = 58, gap = 10, edgeInset = 9 },
  },
  castBar = { height = 1.2, offset = 5.5 },
});
