local _, ns = ...;
-- The icon column starts 7 units in from the box edge. A plate edge at -1 is 8 units outside it, the same
-- gap as between the icon column and the name.
local ICON_PLATE_INSET = -1;
ns.styles.Register("plain", {
  name = "Plain Bar", underline = true, shadow = false, layers = { lineLow = true }, flashStrength = 0.4,
  castBar = { height = 1.7, offset = 6.5 },
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
    ns.styles.NameSegment(frame, frame.lineLow, frame.nameLeft, frame.nameWidth, ns.styles.UnderlineY(frame, db));
    -- Key side: three units of padding past the keyboard art's overhang.
    local cap = frame.keyCap;
    local keyOverhang, keyHeight = 0, cap:IsShown() and cap.capHeight or 0;
    if cap:IsShown() and not cap.isGlyph then
      local m = cap.art.margins;
      local artWidth = cap.capWidth / (1 - m[1] - m[3]);
      keyOverhang = artWidth * (db.swapIconAndKey and m[1] or m[3]);
      keyHeight = cap.capHeight * (1 + 2 * math.max(m[2], m[4]) / (1 - m[2] - m[4]));
    end
    -- The icon art is centered in its column, so equal gaps on both sides of the column center the icon
    -- between the plate edge and the name, as the key's art margin centers the key face.
    local iconInset = db.showIcon and ICON_PLATE_INSET or 4;
    local plateLeft = db.swapIconAndKey and 4 - keyOverhang or iconInset;
    local plateRight = db.swapIconAndKey and iconInset or 4 - keyOverhang;
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
