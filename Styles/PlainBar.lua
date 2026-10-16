local _, ns = ...;
-- The plate leaves the same preset-scaled gap on both sides of the natural icon column.
ns.styles.Register("plain", {
  name = "Plain Bar", underline = true, shadow = false, layers = { lineLow = true }, flashStrength = 0.4,
  fitKeyToName = true,
  sizes = {
    small = { fontSize = 14, nameTop = 5.25, iconSize = 20, keyHeight = 20, glyphHeight = 20, keyFontSize = 14, inputScale = 0.875, nameMinWidth = 90, nameMaxWidth = 220, hudHeight = 42, gap = 7, edgeInset = 6 },
    normal = { fontSize = 16, nameTop = 6, iconSize = 23, keyHeight = 23, glyphHeight = 23, keyFontSize = 16, inputScale = 1, nameMinWidth = 100, nameMaxWidth = 250, hudHeight = 48, gap = 8, edgeInset = 7 },
    large = { fontSize = 20, nameTop = 7.5, iconSize = 29, keyHeight = 29, glyphHeight = 29, keyFontSize = 20, inputScale = 1.25, nameMinWidth = 125, nameMaxWidth = 310, hudHeight = 60, gap = 10, edgeInset = 9 },
  },
  KeyOffsetY = ns.styles.KeyBaselineY,
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
    local size = ns.styles.Size(db);
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
    -- Keep the established art padding, and also contain the canvas when its fixed bottom moves it.
    keyHeight = math.max(keyHeight + 6 * size.inputScale, keyHeight + 2 * math.abs(ns.styles.KeyBaselineY(frame, db)));
    -- The icon art is centered in its column, so equal gaps on both sides of the column center the icon
    -- between the plate edge and the name, as the key's art margin centers the key face.
    local iconInset = db.showIcon and size.edgeInset - size.gap or 4 * size.inputScale;
    local keyInset = size.edgeInset - 3 * size.inputScale - keyOverhang;
    local plateLeft = db.swapIconAndKey and keyInset or iconInset;
    local plateRight = db.swapIconAndKey and iconInset or keyInset;
    frame.stylePlate:ClearAllPoints();
    frame.stylePlate:SetPoint("LEFT", frame.box, "LEFT", plateLeft, 0);
    frame.stylePlate:SetPoint("RIGHT", frame.box, "RIGHT", -plateRight, 0);
    local _, iconHeight = ns.styles.IconDimensions(frame, db);
    -- The fixed underline can sit below a small button; keep the cast's end markers inside the plate.
    local lineHeight = 2 * (-ns.styles.UnderlineY(frame, db) + (ns.CastBar.END_HEIGHT * 0.5 + 2) * size.inputScale);
    frame.stylePlate:SetHeight(math.max(38 * size.inputScale, size.fontSize + 21 * size.inputScale,
      db.showIcon and iconHeight + 6 * size.inputScale or 0, keyHeight, lineHeight));
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
