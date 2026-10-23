local _, ns = ...;
local WHITE = [[Interface\Buttons\WHITE8X8]];

-- Snap one origin and explicit dimensions (shared pixel helpers in Helpers\StyleRegistry.lua).
-- Independently rounded opposite anchors can collapse a one-pixel region.
local Pixel, Round, Snap = ns.styles.Pixel, ns.styles.Round, ns.styles.Snap;
local Origin, Rect = ns.styles.Origin, ns.styles.Rect;

-- ElvUI conventions: a 1-pixel border in ElvUI's border color around its backdrop color, OUTLINE text
-- without a drop shadow, and extra black lines outside and inside every border when Pixel Perfect is off.
-- ElvUI's yellow pressed overlay reads as a flash, so a held key gets a white overlay at 15% instead, and
-- an interaction lights the panel border in the object color instead of a fill flash. The key is a
-- full-height square flush with its side, sharing the panel edge, with 6 units of padding around the name.
-- The underline and cast bar run along the bottom edge, docked to the key and icon squares. The tables use ElvUI's 32-unit
-- button; presets draw them 10% larger, button included (scaleButtons).
local PADDING = 6;
local PUSHED = { 1, 1, 1, 0.15 };
local BLACK = { 0, 0, 0, 1 };

-- The panel height, which the key and the optional icon cell fill as squares.
local function Square(db)
  return ns.styles.Size(db).keyHeight;
end

local function Padding(db) return PADDING * ns.styles.Size(db).inputScale end

local function PanelHeight(frame, db)
  return Round(Square(db), Pixel(frame));
end

-- Fill inset inside a border: one pixel, or two with ElvUI's thick borders (its E.Border).
local function FillInset(pixel) return ns.ElvTheme.ThickBorders() and pixel * 2 or pixel end

local function LineTop(frame, top, height, pixel)
  -- Keep the snapped underline/cast rectangles inside the one-pixel panel border at small UI scales.
  -- The ideal text-relative baseline stays fixed; these cached bounds only constrain rasterization.
  local rect = frame.elvLineRect;
  return math.max(rect[2] - rect[4] + pixel + height, math.min(top, rect[2] - pixel));
end

local function Region(frame, layer)
  local texture = frame:CreateTexture(nil, layer);
  texture:SetTexture(WHITE);
  Snap(texture, false);
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

local function PlaceEdges(edges, target, x, y, width, height, pixel)
  for i, edge in ipairs(edges) do
    local horizontal = i <= 2;
    local edgeX = x + (i == 4 and width - pixel or 0);
    local edgeY = y - (i == 2 and height - pixel or 0);
    Rect(edge, target, edgeX, edgeY, horizontal and width or pixel, horizontal and pixel or height);
  end
end

local function Border(edges, target, x, y, width, height, pixel, color)
  PlaceEdges(edges, target, x, y, width, height, pixel);
  for _, edge in ipairs(edges) do edge:SetVertexColor(unpack(color)); end
end

-- A border with ElvUI's optional thick-mode lines: the main edge in the border color, plus black lines
-- one pixel outside and inside it. Sets are { main, outer, inner }, four edges each.
local function BorderSets(parent, regions, layer)
  return { main = Edges(parent, regions, layer), outer = Edges(parent, regions, layer), inner = Edges(parent, regions, layer) };
end

local function DrawBorder(target, sets, x, y, width, height, pixel, color, shown)
  local thick = (shown and ns.ElvTheme.ThickBorders()) and true or false;
  Border(sets.main, target, x, y, width, height, pixel, color);
  Border(sets.outer, target, x - pixel, y + pixel, width + pixel * 2, height + pixel * 2, pixel, BLACK);
  Border(sets.inner, target, x + pixel, y - pixel, width - pixel * 2, height - pixel * 2, pixel, BLACK);
  for _, edge in ipairs(sets.main) do edge:SetShown(shown); end
  for _, edge in ipairs(sets.outer) do edge:SetShown(thick); end
  for _, edge in ipairs(sets.inner) do edge:SetShown(thick); end
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
    -- Shared input already uses Blizzard's localized compact binding labels.
    return text;
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
  -- Controller symbols fit inside the square key, with the same padding the core adds around key text.
  local db = EnhancedSoftInteractDB;
  local available = Square(db) - 4 * 1.3 * ns.styles.Size(db).inputScale;
  frame.elvInputScale = math.min(1, available / math.max(1, width));
  for _, token in ipairs(tokens) do token.width = token.width * frame.elvInputScale; end
  width = width * frame.elvInputScale;
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
  -- ElvUI's pressed overlay follows the key's press depth.
  local pushed, cap = frame.elvKeyPushed, frame.keyCap;
  if pushed then
    local depth = cap.pressDepth or 0;
    pushed:SetAlpha(PUSHED[4] * depth);
    pushed:SetShown(cap:IsShown() and not cap.isGlyph and depth > 0);
  end
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
      -- After SetAtlas, SetTexCoord crops inside the atlas, so the atlas's file coordinates show only
      -- a sliver of the symbol. Draw the file with its coordinates instead,
      -- like the cast bar's reveal; that also clears coordinates kept from an earlier symbol.
      local file = info.file or info.filename;
      if file and info.leftTexCoord then
        region:SetTexture(file);
        region:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord);
      else
        region:SetAtlas(token.atlas);
      end
      region:SetDesaturated(true);
      region:SetSize(token.width, token.width * info.height / info.width);
    end
    region:Show();
    if token.text then region:SetFont(ns.styles.Font(EnhancedSoftInteractDB), ns.styles.Size(EnhancedSoftInteractDB).keyFontSize * frame.elvInputScale, ns.ElvTheme.FontFlags()); end
    left = left + token.width + cap.capHeight * 0.04 * frame.elvInputScale;
  end
  PaintInput(frame);
end

-- The cast timer counts down inside the key, like ElvUI's cooldown text on an action button, in the
-- key label's font, size and position. Its cover hides a keyboard label and dims controller art under the
-- number. With the key hidden there is no timer.
local CONTROLLER_COVER = 0.75;
local function PlaceTimer(frame, timer)
  local cap = frame.keyCap;
  if not cap:IsShown() then return false end
  timer.text:ClearAllPoints();
  timer.text:SetPoint("CENTER", cap, "CENTER", 0, -timer.size * 0.04);
  local data = ns.ElvTheme.Media();
  local bg = data and data.backdropcolor or {0.1, 0.1, 0.1};
  timer.cover:ClearAllPoints();
  timer.cover:SetAllPoints(cap.icon);
  timer.cover:SetColorTexture(bg[1] * 0.6, bg[2] * 0.6, bg[3] * 0.6, frame.elvKeyTokens and CONTROLLER_COVER or 1);
  timer.cover:Show();
  return true;
end

ns.styles.Register("elv", {
  name = "Elv", underline = true, shadow = false, flatKey = true, ownKey = true,
  scaleButtons = true, noTextShadow = true, showIconKey = "elvShowIcon",
  sizes = {
    small = { fontSize = 14, iconSize = 28, keyHeight = 28, glyphHeight = 28, keyFontSize = 14.5, inputScale = 0.875, nameMinWidth = 125, nameMaxWidth = 220, hudHeight = 40 },
    normal = { fontSize = 16, iconSize = 32, keyHeight = 32, glyphHeight = 32, keyFontSize = 17, inputScale = 1, nameMinWidth = 140, nameMaxWidth = 250, hudHeight = 48 },
    large = { fontSize = 20, iconSize = 40, keyHeight = 40, glyphHeight = 40, keyFontSize = 21, inputScale = 1.25, nameMinWidth = 175, nameMaxWidth = 310, hudHeight = 60 },
  },
  KeyText = KeyText,
  KeyWidth = KeyWidth, keyTextPadding = 4,
  PaintKeyCap = PaintInput,
  Remove = function(frame)
    frame.elvKeyTokens = nil;
    HideInput(frame);
  end,
  layers = { lineLow = true }, flashStrength = 0, --the border light replaces the fill flash
  Font = ns.ElvTheme.Font, FontFlags = ns.ElvTheme.FontFlags, Pixel = Pixel,
  -- Side cells: a flush square (key or icon) plus the padding before the name. Without one, padding only.
  CellSize = function(db) return Square(db) + Padding(db) end,
  CellCenter = function(db) return Square(db) * 0.5 end,
  SidePadding = Padding,
  KeyFaceHeight = Square,
  -- The two-pixel cast bar sits on the panel's bottom border, inside it; this is its center, and the
  -- one-pixel underline is its lower row. Measured from the snapped panel, so both stay on whole pixels.
  UnderlineY = function(frame, db)
    local pixel, height = Pixel(frame), PanelHeight(frame, db);
    local _, top = Origin(frame, 0, height * 0.5, pixel);
    return top - height + FillInset(pixel) + pixel;
  end,
  CastSpan = function(frame) return frame.elvCastLeft, frame.elvCastWidth end, --set by Layout
  -- The ready name sits 2 units above center. A status line lifts the name and sits between it and the line.
  NameOffset = function(_, db, amount)
    local size = ns.styles.Size(db);
    -- 0.3 font sizes keeps the smaller name's descenders clear of the status line.
    return 2 * size.inputScale + size.fontSize * 0.3 * amount;
  end,
  RequirementY = function(_, db) return -ns.styles.Size(db).fontSize * 0.25 end,
  -- The interaction icon sits inside its square, clear of the border.
  IconDimensions = function(_, db) local size = Square(db) - Padding(db); return size, size end,
  IconMax = function(frame, db) return Square(db) - FillInset(Pixel(frame)) * 2 end,
  PlaceCast = function(frame, texture, left, width, height, y)
    local pixel = Pixel(frame);
    local x, top = Origin(frame, -frame.boxWidth * 0.5 + left, y + height * 0.5, pixel);
    Rect(texture, frame.box, x, LineTop(frame, top, height, pixel), math.max(pixel, Round(width, pixel)), height);
  end,
  castBar = { height = 1.7, offset = 6.5, pixel = true, endPixels = 2, backingPixels = 0,
    glow = { spark = true }, success = "flashFill", interrupt = "redBar",
    timer = { flat = true, Place = PlaceTimer, FontSize = function(size) return size.keyFontSize end },
    Texture = function() local data = ns.ElvTheme.Media(); return data and data.normTex or WHITE end },
  Create = function(frame)
    frame.elvPlate = Region(frame, "BACKGROUND");
    local regions = { frame.elvPlate };
    frame.elvBorder = BorderSets(frame, regions);
    frame.elvIconBorder = BorderSets(frame, regions);
    -- The panel border lights, above the key and its labels: once with the interaction pulse (its holder
    -- joins the shared pulse at full strength), and during a cast outcome (OutcomeLight). The outcome's
    -- holder moves under the outcome overlay in Apply, so it hides with it.
    for _, name in ipairs({ "elvPulseLight", "elvOutcomeLight" }) do
      local holder = CreateFrame("Frame", nil, frame);
      holder:SetAllPoints(frame);
      holder:SetFrameLevel(frame:GetFrameLevel() + 4);
      holder.edges = Edges(holder, {}, "OVERLAY");
      regions[#regions + 1] = holder;
      frame[name] = holder;
    end
    frame.elvPulseLight:SetAlpha(0);
    frame.elvPulseLight.pulsePeak = 1;
    frame.stylePulseLayers[#frame.stylePulseLayers + 1] = frame.elvPulseLight;
    return regions;
  end,
  Paint = function(frame, r, g, b)
    for _, edge in ipairs(frame.elvPulseLight.edges) do edge:SetVertexColor(r, g, b, 1); end
  end,
  OutcomeLight = function(frame, r, g, b, alpha)
    for _, edge in ipairs(frame.elvOutcomeLight.edges) do edge:SetVertexColor(r, g, b, alpha); end
  end,
  Apply = function(frame)
    -- The keyboard fill is ARTWORK on a child frame; its edges and pressed overlay sit above it there.
    local regions = frame.styleRegions.elv;
    frame.elvKeyBorder = frame.elvKeyBorder or BorderSets(frame.keyCap, regions, "OVERLAY");
    if not frame.elvKeyPushed then
      frame.elvKeyPushed = frame.keyCap:CreateTexture(nil, "OVERLAY", nil, -1);
      frame.elvKeyPushed:SetColorTexture(PUSHED[1], PUSHED[2], PUSHED[3], 1);
      frame.elvKeyPushed:SetAlpha(0);
      regions[#regions + 1] = frame.elvKeyPushed;
    end
    local data = ns.ElvTheme.Media();
    local backdrop = data and data.backdropcolor or {0.1, 0.1, 0.1, 1};
    frame.elvPlate:SetVertexColor(unpack(backdrop));
    local light = frame.elvOutcomeLight;
    if light:GetParent() ~= frame.castFinish then
      light:SetParent(frame.castFinish);
      light:SetFrameLevel(frame:GetFrameLevel() + 4);
    end
    for _, edge in ipairs(light.edges) do edge:SetVertexColor(0, 0, 0, 0); end
  end,
  Layout = function(frame, db)
    local pixel = Pixel(frame);
    local data = ns.ElvTheme.Media();
    local border = data and data.bordercolor or BLACK;
    local inset = FillInset(pixel);
    local cap = frame.keyCap;
    local height = PanelHeight(frame, db);
    local width = Round(frame.boxWidth, pixel);
    local x, y = Origin(frame, -frame.boxWidth * 0.5, height * 0.5, pixel);
    Rect(frame.elvPlate, frame.box, x, y, width, height);
    frame.plateInsetLeft, frame.plateInsetRight = 0, 0; --for the test tools, like elvRect
    frame.elvRect = { x, y, width, height, pixel };
    local _, lineTop = Origin(frame, 0, height * 0.5, pixel);
    frame.elvLineRect = { 0, lineTop, 0, height, pixel };
    DrawBorder(frame.box, frame.elvBorder, x, y, width, height, pixel, border, true);
    -- The lights trace the panel's own border; their colors come from Paint and the outcomes.
    PlaceEdges(frame.elvPulseLight.edges, frame.box, x, y, width, height, pixel);
    PlaceEdges(frame.elvOutcomeLight.edges, frame.box, x, y, width, height, pixel);
    -- Key and icon squares share the panel's outer edges; their inner edge is the divider.
    local keyLeft = db.swapIconAndKey;
    local keyShown = cap:IsShown() and not cap.isGlyph;
    if keyShown then
      local keyX = keyLeft and x or x + width - cap.capWidth;
      cap:ClearAllPoints();
      cap:SetPoint("TOPLEFT", frame.box, "CENTER", keyX, y);
      Rect(cap.icon, frame.box, keyX + inset, y - inset, cap.capWidth - inset * 2, height - inset * 2);
      Rect(frame.elvKeyPushed, frame.box, keyX + inset, y - inset, cap.capWidth - inset * 2, height - inset * 2);
      InputArt(frame);
    else
      HideInput(frame);
    end
    DrawBorder(frame.box, frame.elvKeyBorder, keyLeft and x or x + width - (cap.capWidth or height), y,
      cap.capWidth or height, height, pixel, border, keyShown);
    local iconShown = ns.styles.ShowIcon(db) and true or false;
    DrawBorder(frame.box, frame.elvIconBorder, keyLeft and x + width - height or x, y, height, height, pixel, border, iconShown);
    PaintInput(frame);
    -- The underline and cast bar dock to the squares: they span the panel's inside between the key's and
    -- the icon's dividers, or reach the inner border where a square is hidden. Thick borders add a black
    -- line outside each divider, which the span leaves clear.
    local thick = inset - pixel;
    local spanLeft, spanRight = x + inset, x + width - inset;
    if keyShown then
      if keyLeft then spanLeft = x + cap.capWidth + thick; else spanRight = x + width - cap.capWidth - thick; end
    end
    if iconShown then
      if keyLeft then spanRight = x + width - height - thick; else spanLeft = x + height + thick; end
    end
    frame.elvCastLeft, frame.elvCastWidth = spanLeft + frame.boxWidth * 0.5, spanRight - spanLeft;
    local line = frame.lineLow;
    local lineX, lineY = Origin(frame, spanLeft, ns.styles.UnderlineY(frame, db), pixel);
    Rect(line, frame.box, lineX, LineTop(frame, lineY, pixel, pixel), Round(spanRight - spanLeft, pixel), pixel);
    line:Show();
  end,
});
