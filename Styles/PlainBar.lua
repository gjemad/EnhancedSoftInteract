local _, ns = ...;
ns.styles.Register("plain", {
  name = "Plain Bar", shadow = false, layers = { lineLow = true }, flashStrength = 0.6,
  Create = function(frame)
    frame.stylePlate = frame:CreateTexture(nil, "BACKGROUND");
    frame.stylePlate:SetColorTexture(14 / 255, 13 / 255, 12 / 255, 0.84);
    local regions = { frame.stylePlate };
    frame.styleBorder = {};
    for i = 1, 4 do
      local edge = frame:CreateTexture(nil, "BACKGROUND", nil, 1);
      edge:SetColorTexture(75 / 255, 65 / 255, 50 / 255, 0.57);
      frame.styleBorder[i] = edge;
      regions[#regions + 1] = edge;
    end
    return regions;
  end,
  Apply = function(frame)
    frame.flash:SetTexture([[Interface\Buttons\WHITE8X8]]);
    -- Black adds no light; alpha stays at 1 so the shared pulse owns opacity.
    frame.flash:SetGradient("VERTICAL", CreateColor(1, 1, 1, 1), CreateColor(0, 0, 0, 1));
    frame.flash:ClearAllPoints();
    frame.flash:SetPoint("TOPLEFT", frame.stylePlate, "TOPLEFT", 1, -1);
    frame.flash:SetPoint("BOTTOMRIGHT", frame.stylePlate, "BOTTOMRIGHT", -1, 1);
  end,
  Layout = function(frame, db)
    ns.styles.NameSegment(frame, frame.lineLow, frame.nameLeft, frame.nameWidth, -(db.fontSize * 0.5 + 6.5));
    -- Three units of padding around the visible columns, including the keyboard art's overhang.
    local cap = frame.keyCap;
    local keyOverhang, keyHeight = 0, cap:IsShown() and cap.capHeight or 0;
    if cap:IsShown() and not cap.isGlyph then
      local m = cap.art.margins;
      local artWidth = cap.capWidth / (1 - m[1] - m[3]);
      keyOverhang = artWidth * (db.swapIconAndKey and m[1] or m[3]);
      keyHeight = cap.capHeight * (1 + 2 * math.max(m[2], m[4]) / (1 - m[2] - m[4]));
    end
    local plateLeft = 4 - (db.swapIconAndKey and keyOverhang or 0);
    local plateRight = 4 - (db.swapIconAndKey and 0 or keyOverhang);
    frame.stylePlate:ClearAllPoints();
    frame.stylePlate:SetPoint("LEFT", frame.box, "LEFT", plateLeft, 0);
    frame.stylePlate:SetPoint("RIGHT", frame.box, "RIGHT", -plateRight, 0);
    frame.stylePlate:SetHeight(math.max(38, db.fontSize + 21, db.showIcon and db.iconSize + 6 or 0, keyHeight + 6));
    frame.plateInsetLeft, frame.plateInsetRight = plateLeft, plateRight;
    for i, edge in ipairs(frame.styleBorder) do
      edge:ClearAllPoints();
      local horizontal = i <= 2;
      local side = horizontal and (i == 1 and "TOP" or "BOTTOM") or (i == 3 and "LEFT" or "RIGHT");
      local first = horizontal and side .. "LEFT" or "TOP" .. side;
      local last = horizontal and side .. "RIGHT" or "BOTTOM" .. side;
      edge:SetPoint(first, frame.stylePlate, first);
      edge:SetPoint(last, frame.stylePlate, last);
      if horizontal then edge:SetHeight(1); else edge:SetWidth(1); end
    end
  end,
});
