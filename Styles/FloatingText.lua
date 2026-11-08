local _, ns = ...;
ns.styles.Register("floating", { name = function() return ns.L.STYLE_PLAIN_TEXT end, shadow = true,
  sizes = {
    small = { fontSize = 14, iconSize = 24, keyHeight = 22.75, glyphHeight = 22.75, keyFontSize = 12.5, inputScale = 0.875, nameMinWidth = 85, nameMaxWidth = 220, hudHeight = 40 },
    normal = { fontSize = 16, iconSize = 28, keyHeight = 26, glyphHeight = 26, keyFontSize = 14.5, inputScale = 1, nameMinWidth = 100, nameMaxWidth = 250, hudHeight = 46 },
    large = { fontSize = 20, iconSize = 34, keyHeight = 32.5, glyphHeight = 32.5, keyFontSize = 18, inputScale = 1.25, nameMinWidth = 125, nameMaxWidth = 310, hudHeight = 58 },
  },
  castBar = { height = 1.2, offset = 5.5, timer = true, success = "softBloom", interrupt = "sink",
    glow = { tail = 24, tailHeight = 7, tailAlpha = 0.78, haloWidth = 7, haloHeight = 9, haloAlpha = 0.4,
      coreWidth = 2.8, coreHeight = 2.8, coreAlpha = 0.95, needle = true, breathHeight = 7, breathStrength = 0.75 } },
  -- The cast bar sits on the button's lower border, level with Runic Line's line.
  CastY = ns.styles.ButtonBottom,
  -- A status line lifts the name and itself as far as needed to stay above the cast bar. 0.795 font sizes is
  -- the status line's bottom: HUD\Layout.lua's REQ_TEXT_Y plus half its 0.65 font size.
  StatusOffset = function(frame, db)
    return math.max(0, ns.styles.Size(db).fontSize * 0.795 + ns.styles.ButtonBottom(frame, db));
  end,
});
