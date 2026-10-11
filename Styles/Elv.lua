local _, ns = ...;
local WHITE = [[Interface\Buttons\WHITE8X8]];

local Pixel = ns.styles.Pixel;

local function Round(value, pixel) return math.floor(value / pixel + 0.5) * pixel end

local PADDING = 6;
local function Height(db)
  return math.max(32, db.fontSize + 16, db.fontSize * 1.47 + 8);
end

local function PanelHeight(frame, db)
  return Round(math.max(Height(db), frame.keyCap:IsShown() and frame.keyCap.capHeight or 0), Pixel(frame));
end

-- Snap one origin and explicit dimensions. Independently rounded opposite anchors can collapse a
-- one-pixel region. Disable texture sampling bias so it cannot shift the last column off that rect.
local function Sampling(texture)
  if texture.SetRoundLayoutToNearestPixel then texture:SetRoundLayoutToNearestPixel(false); end
  if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false); end
  if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0); end
end

local function Origin(frame, x, y, pixel)
  local cx, cy = frame:GetCenter();
  if ns.issecretvalue(cx) or ns.issecretvalue(cy) or not cx or not cy then cx, cy = 0, 0; end
  return Round(cx + x, pixel) - cx, Round(cy + y, pixel) - cy;
end

local function Rect(texture, target, x, y, width, height)
  Sampling(texture);
  texture:ClearAllPoints();
  texture:SetPoint("TOPLEFT", target, "CENTER", x, y);
  texture:SetSize(width, height);
end

local function Region(frame, layer)
  local texture = frame:CreateTexture(nil, layer);
  texture:SetTexture(WHITE);
  Sampling(texture);
  return texture;
end

local function Edges(frame, regions, layer)
  local edges = {};
  for i = 1, 4 do
    edges[i] = Region(frame, layer or "BORDER");
    regions[#regions + 1] = edges[i];
  end
  return edges;
end

local function Border(edges, target, x, y, width, height, pixel, color)
  for i, edge in ipairs(edges) do
    local horizontal = i <= 2;
    local edgeX = x + (i == 4 and width - pixel or 0);
    local edgeY = y - (i == 2 and height - pixel or 0);
    Rect(edge, target, edgeX, edgeY, horizontal and width or pixel, horizontal and pixel or height);
    edge:SetVertexColor(unpack(color));
  end
end

ns.styles.Register("elv", {
  name = "Elv", underline = true, shadow = false, flatKey = true,
  layers = { lineLow = true }, flashStrength = 0.25, columnGap = PADDING,
  Font = ns.ElvTheme.Font, Pixel = Pixel,
  KeyHeight = function(db) return Height(db) * math.max(1, db.keyScale / 100) end,
  IconDimensions = function(frame, db)
    local cap = frame.keyCap;
    if cap:IsShown() and cap.capWidth then return cap.capWidth, cap.capHeight end
    local size = Round(Height(db) * math.max(1, db.keyScale / 100), Pixel(frame));
    return size, size;
  end,
  Insets = function(frame, db)
    if frame.keyCap:IsShown() and not frame.keyCap.isGlyph then
      if db.swapIconAndKey then return 0, PADDING end
      return PADDING, 0;
    end
    return PADDING, PADDING;
  end,
  UnderlineY = function(frame, db) return -PanelHeight(frame, db) * 0.5 + PADDING end,
  NameOffset = function(_, db, amount) return 2 + db.fontSize * 0.1875 * amount end,
  RequirementY = function(_, db) return -db.fontSize * 0.25 end,
  PlaceCast = function(frame, texture, left, width, height, y)
    local pixel = Pixel(frame);
    local x, top = Origin(frame, -frame.boxWidth * 0.5 + left, y + height * 0.5, pixel);
    Rect(texture, frame.box, x, top, math.max(pixel, Round(width, pixel)), height);
  end,
  castBar = { height = 1.7, offset = 6.5, pixel = true,
    Texture = function() local data = ns.ElvTheme.Media(); return data and data.normTex or WHITE end },
  Create = function(frame)
    frame.elvPlate = Region(frame, "BACKGROUND");
    local regions = { frame.elvPlate };
    frame.elvBorder = Edges(frame, regions);
    return regions;
  end,
  Apply = function(frame)
    -- The keyboard fill is ARTWORK on a child frame; its edges must be above it on that same frame.
    frame.elvKeyBorder = frame.elvKeyBorder or Edges(frame.keyCap, frame.styleRegions.elv, "OVERLAY");
    local data = ns.ElvTheme.Media();
    local backdrop = data and data.backdropcolor or {0.1, 0.1, 0.1, 1};
    frame.elvPlate:SetVertexColor(unpack(backdrop));
    frame.flash:SetTexture(WHITE);
    frame.flash:SetGradient("VERTICAL", CreateColor(1, 1, 1, 1), CreateColor(0, 0, 0, 1));
    frame.flash:ClearAllPoints();
    frame.flash:SetPoint("TOPLEFT", frame.elvPlate, "TOPLEFT");
    frame.flash:SetPoint("BOTTOMRIGHT", frame.elvPlate, "BOTTOMRIGHT");
  end,
  Layout = function(frame, db)
    local pixel = Pixel(frame);
    local data = ns.ElvTheme.Media();
    local border = data and data.bordercolor or {0, 0, 0, 1};
    local cap = frame.keyCap;
    local height = PanelHeight(frame, db);
    local width = Round(frame.boxWidth, pixel);
    local x, y = Origin(frame, -frame.boxWidth * 0.5, height * 0.5, pixel);
    Rect(frame.elvPlate, frame.box, x, y, width, height);
    frame.plateInsetLeft, frame.plateInsetRight = 0, 0;
    frame.elvRect = { x, y, width, height, pixel };
    Border(frame.elvBorder, frame.box, x, y, width, height, pixel, border);
    if cap:IsShown() and not cap.isGlyph then
      local keyX = db.swapIconAndKey and x or x + width - cap.capWidth;
      local keyY = y;
      cap:ClearAllPoints();
      cap:SetPoint("TOPLEFT", frame.box, "CENTER", keyX, keyY);
      cap.icon:ClearAllPoints();
      -- Inset the fill one physical pixel; the outer border and divider share the panel edges.
      Rect(cap.icon, frame.box, keyX + pixel, keyY - pixel, cap.capWidth - pixel * 2, height - pixel * 2);
      Sampling(cap.icon);
      Border(frame.elvKeyBorder, frame.box, keyX, keyY, cap.capWidth, height, pixel, border);
    end
    for _, edge in ipairs(frame.elvKeyBorder) do edge:SetShown(cap:IsShown() and not cap.isGlyph); end
    local line = frame.lineLow;
    local lineX = x + Round(frame.nameLeft, pixel);
    local lineY = y - height + Round(PADDING, pixel) + pixel;
    Rect(line, frame.box, lineX, lineY, Round(frame.nameWidth, pixel), pixel);
    line:Show();
  end,
});
