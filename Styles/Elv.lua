local _, ns = ...;
local WHITE = [[Interface\Buttons\WHITE8X8]];

local Pixel = ns.styles.Pixel;

local function Round(value, pixel) return math.floor(value / pixel + 0.5) * pixel end

local function Height(db)
  return ns.styles.Size(db).keyHeight;
end

local function PanelHeight(frame, db)
  local _, iconHeight = ns.styles.IconDimensions(frame, db);
  return Round(math.max(Height(db), frame.keyCap:IsShown() and frame.keyCap.capHeight or 0,
    ns.styles.ShowIcon(db) and iconHeight or 0), Pixel(frame));
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
  cx = cx + (frame.boxOffsetX or 0);
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

-- Reuse complete native controller art in monochrome; no controller textures are packaged.
local BUTTON_LABELS = {
  lshoulder = "LB", rshoulder = "RB", ltrigger = "LT", rtrigger = "RT",
  lstickin = "LS", rstickin = "RS", back = "Back", forward = "Start",
  up = "Up", down = "Down", left = "Left", right = "Right", menu = "Menu",
  view = "View", share = "Share", system = "Home",
};
local function FallbackText(text)
  return (text:gsub("|A:Gamepad_(%w+)_(%w+)_%d+:[^|]*|a", function(family, button)
    family, button = family:lower(), button:lower();
    if button:match("^[abxy]$") then return button:upper(); end
    if button:match("^%d+$") then return button; end
    if family == "shp" then
      local labels = { lshoulder = "L1", rshoulder = "R1", ltrigger = "L2", rtrigger = "R2",
        square = "[ ]", circle = "O", triangle = "/\\", cross = "X" };
      if labels[button] then return labels[button]; end
    end
    return BUTTON_LABELS[button] or button;
  end));
end

local function HideInput(frame)
  for _, region in ipairs(frame.elvKeyRegions or {}) do region:Hide(); end
end

local function KeyText(frame, text)
  frame.elvKeyTokens = nil;
  HideInput(frame);
  local tokens, from = {}, 1;
  while true do
    local first, last, atlas = text:find("|A:(Gamepad_[^:|]+):[^|]*|a", from);
    if not first then break end
    if first > from then tokens[#tokens + 1] = { text = text:sub(from, first - 1) }; end
    local large = atlas:gsub("_32$", "_64");
    local info = C_Texture.GetAtlasInfo(large);
    if info then atlas = large; else info = C_Texture.GetAtlasInfo(atlas); end
    if not info then return FallbackText(text) end
    tokens[#tokens + 1] = { atlas = atlas, info = info };
    from = last + 1;
  end
  if #tokens == 0 then
    local chord = frame.keyCap.key;
    if not chord then return text end
    local key = chord:match("%-(%-)$") or chord:match("([^%-]+)$") or chord;
    local labels = { SHIFT = "s", CTRL = "c", ALT = "a", META = "m" };
    local prefix = "";
    for modifier in chord:sub(1, #chord - #key):gmatch("([^%-]+)%-") do
      if not labels[modifier] then return text end
      prefix = prefix .. labels[modifier] .. "-";
    end
    if prefix == "" then return text end
    local label = GetBindingText(key, 1);
    return prefix .. (label and label ~= "" and label or key);
  end
  if from <= #text then tokens[#tokens + 1] = { text = text:sub(from) }; end
  frame.elvKeyTokens = tokens;
  return "";
end

local function KeyWidth(frame, height)
  local tokens = frame.elvKeyTokens;
  if not tokens then return 0 end
  frame.elvKeyRegions = frame.elvKeyRegions or {};
  local path, size, flags = frame.keyCap.text:GetFont();
  local width, gap = 0, height * 0.04;
  for i, token in ipairs(tokens) do
    local slot = frame.elvKeySlots and frame.elvKeySlots[i];
    if not slot then
      frame.elvKeySlots = frame.elvKeySlots or {};
      slot = { icon = frame.keyCap:CreateTexture(nil, "OVERLAY"), label = frame.keyCap:CreateFontString(nil, "OVERLAY") };
      frame.elvKeySlots[i] = slot;
      for _, region in pairs(slot) do
        frame.elvKeyRegions[#frame.elvKeyRegions + 1] = region;
        frame.styleRegions.elv[#frame.styleRegions.elv + 1] = region;
      end
    end
    if token.atlas then
      token.width = height * 0.62;
    else
      slot.label:SetFont(path, size, flags or "");
      slot.label:SetText(token.text);
      token.width = slot.label:GetStringWidth();
      if ns.issecretvalue(token.width) then token.width = size * #token.text * 0.6; end
    end
    width = width + token.width + (i > 1 and gap or 0);
  end
  frame.elvKeyWidth = width;
  if #tokens == 1 and tokens[1].atlas then return 0 end
  return width;
end

local function PaintInput(frame)
  local shade = (frame.outOfRange or frame.requirementText) and 0.75 or 1;
  for _, slot in ipairs(frame.elvKeySlots or {}) do
    slot.icon:SetVertexColor(shade, shade, shade, 1);
    slot.label:SetTextColor(shade, shade, shade);
  end
  if not frame.keyCap:IsShown() then HideInput(frame); end
end

local function InputArt(frame)
  HideInput(frame);
  if not frame.elvKeyTokens or not frame.keyCap:IsShown() then return end
  local cap, left = frame.keyCap, -frame.elvKeyWidth * 0.5;
  for i, token in ipairs(frame.elvKeyTokens) do
    local slot = frame.elvKeySlots[i];
    local cx = left + token.width * 0.5;
    local region = token.atlas and slot.icon or slot.label;
    region:ClearAllPoints();
    region:SetPoint("CENTER", cap, "CENTER", cx, 0);
    if token.atlas then
      local info = token.info;
      region:SetAtlas(token.atlas);
      region:SetDesaturated(true);
      if info.leftTexCoord then
        region:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord);
      end
      region:SetSize(token.width, token.width * info.height / info.width);
    end
    region:Show();
    left = left + token.width + cap.capHeight * 0.04;
  end
  PaintInput(frame);
end

ns.styles.Register("elv", {
  name = "Elv", underline = true, shadow = false, flatKey = true, ownKey = true,
  sizes = {
    small = { fontSize = 14, iconSize = 28, keyHeight = 28, glyphHeight = 28, keyFontSize = 14.5, inputScale = 0.875, nameMinWidth = 125, nameMaxWidth = 220, hudHeight = 40, gap = 5, edgeInset = 5, padding = 5 },
    normal = { fontSize = 16, iconSize = 32, keyHeight = 32, glyphHeight = 32, keyFontSize = 17, inputScale = 1, nameMinWidth = 140, nameMaxWidth = 250, hudHeight = 48, gap = 6, edgeInset = 6, padding = 6 },
    large = { fontSize = 20, iconSize = 40, keyHeight = 40, glyphHeight = 40, keyFontSize = 21, inputScale = 1.25, nameMinWidth = 175, nameMaxWidth = 310, hudHeight = 60, gap = 7, edgeInset = 7, padding = 7 },
  },
  KeyText = KeyText,
  KeyWidth = KeyWidth, keyTextPadding = 4,
  PaintKeyCap = PaintInput,
  Remove = function(frame)
    frame.elvKeyTokens = nil;
    HideInput(frame);
  end,
  layers = { lineLow = true }, flashStrength = 0.25,
  Font = ns.ElvTheme.Font, Pixel = Pixel,
  IconDimensions = function(frame, db)
    local cap = frame.keyCap;
    if cap:IsShown() and cap.capHeight then return cap.capHeight, cap.capHeight end
    local size = Round(Height(db), Pixel(frame));
    return size, size;
  end,
  Insets = function(frame, db)
    local padding = ns.styles.Size(db).padding;
    if frame.keyCap:IsShown() and not frame.keyCap.isGlyph then
      if db.swapIconAndKey then return 0, padding end
      return padding, 0;
    end
    return padding, padding;
  end,
  UnderlineY = function(_, db) return -Height(db) * 0.5 + ns.styles.Size(db).padding end,
  NameOffset = function(_, db, amount)
    local size = ns.styles.Size(db);
    return 2 * size.inputScale + size.fontSize * 0.1875 * amount;
  end,
  RequirementY = function(_, db) return -ns.styles.Size(db).fontSize * 0.25 end,
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
      InputArt(frame);
    end
    if not cap:IsShown() or cap.isGlyph then
      HideInput(frame);
    end
    for _, edge in ipairs(frame.elvKeyBorder) do edge:SetShown(cap:IsShown() and not cap.isGlyph); end
    local line = frame.lineLow;
    -- Snap the name column itself. Snapping the growing panel origin and then adding its inset
    -- can move the line by one pixel even though the name column has not moved.
    local lineX, lineY = Origin(frame, -frame.nameWidth * 0.5 - frame.boxOffsetX,
      ns.styles.UnderlineY(frame, db) + pixel * 0.5, pixel);
    Rect(line, frame.box, lineX, lineY, Round(frame.nameWidth, pixel), pixel);
    line:Show();
  end,
});
