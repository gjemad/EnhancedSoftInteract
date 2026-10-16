local ADDON_NAME, ns = ...;
local DIAMOND = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\RunicDiamond]];
-- The diamond extends three units above the line, leaving one more unit below status text.
ns.styles.Register("runic", {
  name = "Runic Line", underline = true, shadow = true, lineClearance = 4,
  fitKeyToName = true,
  sizes = {
    small = { fontSize = 14, nameTop = 5.25, iconSize = 24, keyHeight = 22, glyphHeight = 22, keyFontSize = 14, inputScale = 0.875, nameMinWidth = 90, nameMaxWidth = 220, hudHeight = 42, gap = 7, edgeInset = 6 },
    normal = { fontSize = 16, nameTop = 6, iconSize = 28, keyHeight = 24, glyphHeight = 24, keyFontSize = 16, inputScale = 1, nameMinWidth = 100, nameMaxWidth = 250, hudHeight = 48, gap = 8, edgeInset = 7 },
    large = { fontSize = 20, nameTop = 7.5, iconSize = 34, keyHeight = 30, glyphHeight = 30, keyFontSize = 20, inputScale = 1.25, nameMinWidth = 125, nameMaxWidth = 310, hudHeight = 60, gap = 10, edgeInset = 9 },
  },
  KeyOffsetY = ns.styles.KeyBaselineY,
  castBar = { height = 1.2, offset = 6.5, split = true },
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
  Layout = function(frame, db)
    local scale = ns.styles.Size(db).inputScale;
    local gap = 5 * scale;
    local left, width, y = frame.nameLeft, frame.nameWidth, ns.styles.UnderlineY(frame, db);
    ns.styles.NameSegment(frame, frame.lineLow, left, width * 0.5 - gap, y);
    ns.styles.NameSegment(frame, frame.lineHigh, left + width * 0.5 + gap, width * 0.5 - gap, y);
    ns.styles.BloomSegment(frame, frame.runicBloom[1], left, width * 0.5 - gap, y);
    ns.styles.BloomSegment(frame, frame.runicBloom[2], left + width * 0.5 + gap, width * 0.5 - gap, y);
    ns.styles.NameBloom(frame, frame.runicNameGlow, db);
    frame.rune:ClearAllPoints();
    frame.rune:SetPoint("CENTER", frame.box, "LEFT", left + width * 0.5, y);
    frame.rune:SetSize(6 * scale, 6 * scale);
    frame.flash:ClearAllPoints();
    frame.flash:SetPoint("CENTER", frame.box, "LEFT", left + width * 0.5, y);
    frame.flash:SetSize(10 * scale, 10 * scale);
    for i, tick in ipairs(frame.runeTicks) do
      tick:ClearAllPoints();
      tick:SetPoint("CENTER", frame.box, "LEFT", left + (i - 1) * width, y);
      tick:SetSize(1, 4 * scale);
    end
  end,
  Paint = function(frame, r, g, b)
    frame.rune:SetVertexColor(r, g, b, 1);
    for _, tick in ipairs(frame.runeTicks) do tick:SetVertexColor(r, g, b, 1); end
    for _, glow in ipairs(frame.runicBloom) do glow:SetVertexColor(r * 0.5, g * 0.5, b * 0.5, glow:GetAlpha()); end
    frame.runicNameGlow:SetVertexColor(r * 0.22, g * 0.22, b * 0.22, frame.runicNameGlow:GetAlpha());
  end,
});
