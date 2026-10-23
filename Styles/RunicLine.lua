local ADDON_NAME, ns = ...;
local DIAMOND = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\RunicDiamond]];
ns.styles.Register("runic", {
  name = "Runic Line", underline = true, shadow = true,
  sizes = {
    small = { fontSize = 14, iconSize = 24, keyHeight = 22.75, glyphHeight = 22.75, keyFontSize = 14, inputScale = 0.875, nameMinWidth = 90, nameMaxWidth = 220, hudHeight = 42 },
    normal = { fontSize = 16, iconSize = 28, keyHeight = 26, glyphHeight = 26, keyFontSize = 16, inputScale = 1, nameMinWidth = 100, nameMaxWidth = 250, hudHeight = 48 },
    large = { fontSize = 20, iconSize = 34, keyHeight = 32.5, glyphHeight = 32.5, keyFontSize = 20, inputScale = 1.25, nameMinWidth = 125, nameMaxWidth = 310, hudHeight = 60 },
  },
  -- The cast fills the line itself (lineFill): additive in the object color, the unfilled part darkened,
  -- no backing, like Level-Up Line. The fill rises in brightness toward the tip.
  castBar = { height = 1.2, offset = 6.5, split = true, lineFill = true, rising = true, timer = true, success = "runeIgnition", interrupt = "tipSparks",
    glow = { tail = 17, tailHeight = 5, tailAlpha = 0.48, haloWidth = 10, haloHeight = 9, haloAlpha = 0.52,
      coreWidth = 4.2, coreHeight = 5.2, coreAlpha = 1, diamond = true, breathHeight = 7 } },
  layers = { lineLow = true, lineHigh = true }, highLineAlpha = 1,
  flashStrength = 0.8,
  Create = function(frame, media)
    frame.rune = frame:CreateTexture(nil, "BORDER");
    frame.rune:SetTexture(media .. "RunicDiamond");
    frame.rune:SetSize(6, 6);
    local regions = { frame.rune };
    frame.runeTicks = {};
    for i = 1, 2 do
      local tick = frame:CreateTexture(nil, "BORDER");
      tick:SetTexture([[Interface\Buttons\WHITE8X8]]);
      tick:SetSize(1, 4);
      frame.runeTicks[i] = tick;
      regions[#regions + 1] = tick;
    end
    frame.runicBloom = ns.styles.CreateBloom(frame);
    for _, glow in ipairs(frame.runicBloom) do regions[#regions + 1] = glow; end
    frame.runicNameGlow = ns.styles.CreatePulseGlow(frame);
    regions[#regions + 1] = frame.runicNameGlow;
    return regions;
  end,
  Apply = function(frame)
    frame.flash:SetTexture(DIAMOND);
    frame.flash:SetSize(10, 10);
  end,
  -- The underline sits on the lower border of the visible button.
  UnderlineY = ns.styles.ButtonBottom,
  -- Status text stays clear of the ornament.
  StatusOffset = function(frame, db)
    local size = ns.styles.Size(db);
    return math.max(0, size.fontSize * 0.735 + 3 * size.inputScale + ns.styles.UnderlineY(frame, db));
  end,
  -- The cast track snaps like the line, so both keep the same whole-pixel thickness everywhere.
  PlaceCast = function(frame, texture, left, width, height, y)
    ns.styles.PixelStrip(frame, texture, left, width, y, height);
  end,
  -- The cast's start and end markers center on the one-unit line's pixel row.
  PlaceMarker = function(frame, texture, left, width, height, y)
    ns.styles.PixelMark(frame, texture, left, width, y, height, 1);
  end,
  Layout = function(frame, db)
    local scale = ns.styles.Size(db).inputScale;
    local gap = 5 * scale;
    local left, width, y = frame.nameLeft, frame.nameWidth, ns.styles.UnderlineY(frame, db);
    -- The line is one UI unit tall. Drawn at an arbitrary position it rounds to one or two pixels, so
    -- it looked thicker in the settings preview than on the HUD; whole pixels keep both the same.
    ns.styles.PixelStrip(frame, frame.lineLow, left, width * 0.5 - gap, y, 1);
    ns.styles.PixelStrip(frame, frame.lineHigh, left + width * 0.5 + gap, width * 0.5 - gap, y, 1);
    ns.styles.BloomSegment(frame, frame.runicBloom[1], left, width * 0.5 - gap, y);
    ns.styles.BloomSegment(frame, frame.runicBloom[2], left + width * 0.5 + gap, width * 0.5 - gap, y);
    ns.styles.NameBloom(frame, frame.runicNameGlow, db);
    frame.rune:ClearAllPoints();
    frame.rune:SetPoint("CENTER", frame.box, "LEFT", left + width * 0.5, y);
    frame.rune:SetSize(6 * scale, 6 * scale);
    frame.flash:ClearAllPoints();
    frame.flash:SetPoint("CENTER", frame.box, "LEFT", left + width * 0.5, y);
    frame.flash:SetSize(10 * scale, 10 * scale);
    local pixel = ns.styles.Pixel(frame);
    local tickWidth = math.max(pixel, ns.styles.Round(1, pixel));
    local tickHeight = math.max(pixel, ns.styles.Round(4 * scale, pixel));
    for i, tick in ipairs(frame.runeTicks) do
      ns.styles.PixelMark(frame, tick, left + (i - 1) * width - tickWidth * 0.5, tickWidth, y, tickHeight, 1);
    end
  end,
  Paint = function(frame, r, g, b)
    frame.rune:SetVertexColor(r, g, b, 1);
    for _, tick in ipairs(frame.runeTicks) do tick:SetVertexColor(r, g, b, 1); end
    for _, glow in ipairs(frame.runicBloom) do glow:SetVertexColor(r * 0.5, g * 0.5, b * 0.5, glow:GetAlpha()); end
    frame.runicNameGlow:SetVertexColor(r * 0.22, g * 0.22, b * 0.22, frame.runicNameGlow:GetAlpha());
  end,
});
