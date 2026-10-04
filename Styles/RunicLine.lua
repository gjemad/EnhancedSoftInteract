local ADDON_NAME, ns = ...;
local DIAMOND = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\RunicDiamond]];
ns.styles.Register("runic", {
  name = "Runic Line", shadow = true,
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
    local left, width, y = frame.nameLeft, frame.nameWidth, -(db.fontSize * 0.5 + 6.5);
    ns.styles.NameSegment(frame, frame.lineLow, left, width * 0.5 - 5, y);
    ns.styles.NameSegment(frame, frame.lineHigh, left + width * 0.5 + 5, width * 0.5 - 5, y);
    ns.styles.BloomSegment(frame, frame.runicBloom[1], left, width * 0.5 - 5, y);
    ns.styles.BloomSegment(frame, frame.runicBloom[2], left + width * 0.5 + 5, width * 0.5 - 5, y);
    ns.styles.NameBloom(frame, frame.runicNameGlow, db);
    frame.rune:ClearAllPoints();
    frame.rune:SetPoint("CENTER", frame.box, "LEFT", left + width * 0.5, y);
    frame.flash:ClearAllPoints();
    frame.flash:SetPoint("CENTER", frame.box, "LEFT", left + width * 0.5, y);
    for i, tick in ipairs(frame.runeTicks) do
      tick:ClearAllPoints();
      tick:SetPoint("CENTER", frame.box, "LEFT", left + (i - 1) * width, y);
    end
  end,
  Paint = function(frame, r, g, b)
    frame.rune:SetVertexColor(r, g, b, 1);
    for _, tick in ipairs(frame.runeTicks) do tick:SetVertexColor(r, g, b, 1); end
    for _, glow in ipairs(frame.runicBloom) do glow:SetVertexColor(r * 0.5, g * 0.5, b * 0.5, glow:GetAlpha()); end
    frame.runicNameGlow:SetVertexColor(r * 0.22, g * 0.22, b * 0.22, frame.runicNameGlow:GetAlpha());
  end,
});
