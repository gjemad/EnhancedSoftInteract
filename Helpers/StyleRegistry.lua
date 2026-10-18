local ADDON_NAME, ns = ...;
local styles, order = {}, {};
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
local commonLayers = { "iconGlow", "lineLowGlow", "lineLow", "lineHigh" };
ns.HUD_STYLES = {};
ns.styles = {};

-- A style supplies its label, visible common layers and optional Create/Apply/Layout/Paint hooks.
-- Create returns its extra regions; the registry hides them when another style is selected.
-- Layout uses cached numeric columns, never measurements of the target's secret name.
function ns.styles.Register(id, style)
  assert(not styles[id], "Duplicate HUD style: " .. id);
  styles[id] = style;
  order[#order + 1] = id;
  ns.HUD_STYLES[#ns.HUD_STYLES + 1] = { text = style.name, value = id };
end

function ns.styles.Get()
  return styles[EnhancedSoftInteractDB.hudStyle] or styles.levelup;
end

-- Size profiles are style-owned geometry, never copied into or derived from saved dimension values.
-- Every preset draws 10% larger than its table (user, 2026-10-18). All profile fields are dimensions,
-- including inputScale, so the whole HUD grows together. Scaled copies are made once per profile.
-- A style with fixedPresets keeps its table sizes (Elv: ElvUI's 32-unit default button). Buttons and
-- their labels keep their table size in every style, so a key stays clear of Level-Up's lines
-- (user, 2026-10-19: the scaled key overlapped them).
local PRESET_SCALE = 1.1;
local UNSCALED = { keyHeight = true, glyphHeight = true, keyFontSize = true };
local scaled = {};
function ns.styles.Size(db)
  local style = styles[db.hudStyle] or styles.levelup;
  local profile = style.sizes[db.hudSize] or style.sizes.normal;
  local size = scaled[profile];
  if not size then
    local factor = style.fixedPresets and 1 or PRESET_SCALE;
    size = {};
    for key, value in pairs(profile) do
      size[key] = type(value) == "number" and value * (UNSCALED[key] and 1 or factor) or value;
    end
    scaled[profile] = size;
  end
  return size;
end

-- Fine tuning is relative to the chosen preset; its immutable profile remains the layout baseline.
function ns.styles.ButtonScale(db) return (db.buttonSizePercent or 100) / 100 end
function ns.styles.IconScale(db) return (db.interactionIconSizePercent or 100) / 100 end

-- Invisible side cells reserve space independently of their artwork and input labels. A style can
-- own its cells (Elv: a flush square plus the gap to the name).
function ns.styles.CellSize(db)
  local style = ns.styles.Get();
  if style.CellSize then return style.CellSize(db) end
  return (style.cellSize or 46) * ns.styles.Size(db).inputScale;
end

-- Distance from the box edge to the center of a side cell's content.
function ns.styles.CellCenter(db)
  local style = ns.styles.Get();
  if style.CellCenter then return style.CellCenter(db) end
  return ns.styles.CellSize(db) * 0.5;
end

function ns.styles.SidePadding(db)
  local style = ns.styles.Get();
  if style.SidePadding then return style.SidePadding(db) end
  return 18 * ns.styles.Size(db).inputScale;
end

-- Font flags for the name, status and key text ("" draws no outline).
function ns.styles.FontFlags()
  local style = ns.styles.Get();
  return style.FontFlags and style.FontFlags() or "";
end

function ns.styles.Font(db)
  local style = ns.styles.Get();
  return style.Font and style.Font(db) or ns.media:Fetch("font", db.font);
end

function ns.styles.ShowIcon(db)
  if db.hudStyle == "elv" then return db.elvShowIcon end
  return db.showIcon;
end

function ns.styles.NameMinWidth(db)
  return ns.styles.Size(db).nameMinWidth;
end

function ns.styles.NameOffset(frame, db, amount)
  local style, size = ns.styles.Get(), ns.styles.Size(db);
  if style.NameOffset then return style.NameOffset(frame, db, amount) end
  -- Shared names use the HUD origin.
  return (style.nameOffsetY or 0) * size.inputScale + size.fontSize * 0.26 * amount
    + ns.styles.StatusOffset(frame, db) * amount;
end

function ns.styles.IconDimensions(frame, db)
  local style = ns.styles.Get();
  local width, height = ns.styles.Size(db).iconSize, ns.styles.Size(db).iconSize;
  if style.IconDimensions then width, height = style.IconDimensions(frame, db); end
  local scale = ns.styles.IconScale(db);
  width, height = width * scale, height * scale;
  if style.IconMax then
    local limit = style.IconMax(frame, db);
    width, height = math.min(width, limit), math.min(height, limit);
  end
  if style.Pixel then
    local pixel = style.Pixel(frame);
    width, height = math.floor(width / pixel + 0.5) * pixel, math.floor(height / pixel + 0.5) * pixel;
  end
  return width, height;
end

function ns.styles.Pixel(frame)
  local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor();
  if not factor then
    local _, height = GetPhysicalScreenSize();
    factor = 768 / height;
  end
  return factor / frame:GetEffectiveScale();
end

-- Physical-pixel placement for thin flat regions (Elv's panel, Runic's line). A thin line anchored at
-- an arbitrary position rounds to one or two pixels depending on where it lands, so these snap one
-- origin in screen space and give explicit whole-pixel sizes.
function ns.styles.Round(value, pixel) return math.floor(value / pixel + 0.5) * pixel end

-- Disable native rounding and texture sampling bias, so they cannot shift a snapped rect.
function ns.styles.Sampling(texture)
  if texture.SetRoundLayoutToNearestPixel then texture:SetRoundLayoutToNearestPixel(false); end
  if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false); end
  if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0); end
end

-- Offsets from the box center, (x, y), moved so they land on the screen's pixel grid.
function ns.styles.Origin(frame, x, y, pixel)
  local cx, cy = frame:GetCenter();
  if ns.issecretvalue(cx) or ns.issecretvalue(cy) or not cx or not cy then cx, cy = 0, 0; end
  cx = cx + (frame.boxOffsetX or 0);
  return ns.styles.Round(cx + x, pixel) - cx, ns.styles.Round(cy + y, pixel) - cy;
end

-- Places a texture by its top-left corner, relative to the box center, with explicit dimensions.
function ns.styles.Rect(texture, target, x, y, width, height)
  ns.styles.Sampling(texture);
  texture:ClearAllPoints();
  texture:SetPoint("TOPLEFT", target, "CENTER", x, y);
  texture:SetSize(width, height);
end

-- A horizontal strip on whole pixels: left edge and width in box-left units, centered on y, at least
-- one pixel tall.
function ns.styles.PixelStrip(frame, texture, left, width, y, height)
  local pixel = ns.styles.Pixel(frame);
  height = math.max(pixel, ns.styles.Round(height, pixel));
  local x, top = ns.styles.Origin(frame, -frame.boxWidth * 0.5 + left, y + height * 0.5, pixel);
  ns.styles.Rect(texture, frame.box, x, top, math.max(pixel, ns.styles.Round(width, pixel)), height);
end

local function TextClearance(db, offset, clearance)
  -- The status is centered 0.41 font sizes down and uses a 0.65-size font. Reserve half that font
  -- below its center, plus the style's decoration clearance; retain a larger normal line offset.
  local size = ns.styles.Size(db);
  return math.max(size.fontSize * 0.5 + offset * size.inputScale,
    size.fontSize * 0.735 + (clearance or 2) * size.inputScale);
end

-- Text and lines use stable font-relative baselines. Outer icon/key sizes do not move them.
function ns.styles.UnderlineY(frame, db)
  local style = ns.styles.Get();
  if style.UnderlineY then return style.UnderlineY(frame, db) end
  if db.hudStyle == "runic" then
    local cap = frame.keyCap;
    if cap:IsShown() and cap.capHeight then
      local height = cap.capHeight;
      local bottom = -height * 0.5 + (cap.isGlyph and 0 or 0.5);
      local art = cap.art;
      if art and art.bottomBorder and not cap.isGlyph then
        local m = art.margins;
        bottom = ((1 + m[2] - m[4]) * 0.5 - art.bottomBorder) / (1 - m[2] - m[4]) * height;
      end
      return bottom * (cap.cellScale or 1);
    end
    -- Without a visible input, retain the normalized keyboard's measured lower-border reference.
    return -ns.styles.Size(db).keyHeight * ns.styles.ButtonScale(db) * 31.5 / 65;
  end
  -- Underlines sit five preset-scaled units above the side cells' bottom edge, including status text.
  return -ns.styles.CellSize(db) * 0.5 + 5 * ns.styles.Size(db).inputScale;
end

-- Keep status text clear of Runic's ornament.
-- Only the status presentation moves; ready names retain the common content center.
function ns.styles.StatusOffset(frame, db)
  if db.hudStyle ~= "runic" then return 0 end
  local size = ns.styles.Size(db);
  return math.max(0, size.fontSize * 0.735 + 3 * size.inputScale + ns.styles.UnderlineY(frame, db));
end

-- Shared buttons use Level-Up's Normal height, uniformly scaled with the preset and slider.
-- Elv retains its compact style-owned face; native artwork keeps its proportions in either path.
function ns.styles.KeyFaceHeight(frame, db, glyph)
  local style = ns.styles.Get();
  if style.KeyFaceHeight then return style.KeyFaceHeight(db) end
  local size = ns.styles.Size(db);
  local scale = ns.styles.ButtonScale(db);
  return (glyph and size.glyphHeight or size.keyHeight) * scale;
end

-- Input centers follow the common HUD origin; cursor-specific art offsets are applied separately.
function ns.styles.ContentCenterY() return 0 end

function ns.styles.LineY(frame, db, offset)
  if ns.styles.Get().underline then return ns.styles.UnderlineY(frame, db); end
  return -TextClearance(db, offset);
end

function ns.styles.Create(frame)
  frame.styleRegions = {};
  frame.stylePulseLayers = {};
  for _, id in ipairs(order) do
    local style = styles[id];
    local regions = style.Create and style.Create(frame, MEDIA) or {};
    frame.styleRegions[id] = regions;
    for _, region in ipairs(regions) do region:Hide(); end
  end
end

function ns.styles.Apply(frame)
  local style = ns.styles.Get();
  -- A style that changes shared regions (masks, icon tint) undoes that when another style takes over.
  if frame.appliedStyle and frame.appliedStyle ~= style and frame.appliedStyle.Remove then
    frame.appliedStyle.Remove(frame);
  end
  frame.appliedStyle = style;
  for _, region in ipairs(frame.stylePulseLayers) do region:SetAlpha(0); end
  for _, name in ipairs(commonLayers) do
    frame[name]:SetShown(style.layers and style.layers[name] and (name ~= "iconGlow" or EnhancedSoftInteractDB.showIcon) or false);
  end
  for id, regions in pairs(frame.styleRegions) do
    for _, region in ipairs(regions) do region:SetShown(styles[id] == style); end
  end
  -- Reset shared textures and anchors so switching styles cannot carry over another look.
  for _, name in ipairs({ "lineLow", "lineLowGlow", "lineHigh" }) do
    frame[name]:SetTexture([[Interface\Buttons\WHITE8X8]]);
    frame[name]:SetTexCoord(0, 1, 0, 1);
    if frame[name].SetRoundLayoutToNearestPixel then frame[name]:SetRoundLayoutToNearestPixel(false); end
    if frame[name].SetSnapToPixelGrid then frame[name]:SetSnapToPixelGrid(true); end
    if frame[name].SetTexelSnappingBias then frame[name]:SetTexelSnappingBias(0.5); end
  end
  frame.flash:SetTexture(MEDIA .. "SoftGlow");
  frame.flash:SetDesaturated(false);
  frame.flash:SetGradient("VERTICAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1));
  frame.flash:ClearAllPoints();
  frame.flash:SetPoint("TOPLEFT", frame.box, "TOPLEFT", -20, 0);
  frame.flash:SetPoint("BOTTOMRIGHT", frame.box, "BOTTOMRIGHT", 20, 0);
  if style.Apply then style.Apply(frame); end
  frame.flashHolder:SetAlpha(0);
end

-- Bloom layers join the core pulse so timing, repeat presses and cancellation stay shared.
function ns.styles.CreatePulseGlow(frame)
  local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 0);
  glow:SetTexture(MEDIA .. "SoftGlow");
  glow:SetBlendMode("ADD");
  glow:SetAlpha(0);
  frame.stylePulseLayers[#frame.stylePulseLayers + 1] = glow;
  return glow;
end

function ns.styles.CreateBloom(frame)
  local regions = { ns.styles.CreatePulseGlow(frame), ns.styles.CreatePulseGlow(frame) };
  return regions;
end

function ns.styles.NameBloom(frame, texture, db)
  texture:ClearAllPoints();
  texture:SetPoint("CENTER", frame.name, "CENTER");
  local size = ns.styles.Size(db);
  texture:SetSize(frame.nameWidth + 24 * size.inputScale, size.fontSize + 16 * size.inputScale);
end

function ns.styles.BloomSegment(frame, texture, left, width, y)
  texture:ClearAllPoints();
  texture:SetPoint("CENTER", frame.box, "LEFT", left + width * 0.5, y);
  local scale = ns.styles.Size(EnhancedSoftInteractDB).inputScale;
  texture:SetSize(width + 24 * scale, 26 * scale);
end

function ns.styles.Layout(frame)
  local style = ns.styles.Get();
  if style.Layout then style.Layout(frame, EnhancedSoftInteractDB); end
end

function ns.styles.Paint(frame, r, g, b)
  local style = ns.styles.Get();
  frame.lineHigh:SetVertexColor(r, g, b, style.highLineAlpha or 0.5);
  local strength = style.flashStrength or 1;
  -- The holder owns animation opacity; texture alpha stays opaque while its RGB changes.
  frame.flash:SetVertexColor(r * strength, g * strength, b * strength, 1);
  if style.Paint then style.Paint(frame, r, g, b); end
end

-- Shared geometry for styles that decorate only the name column.
function ns.styles.NameSegment(frame, texture, x, width, y)
  texture:ClearAllPoints();
  texture:SetPoint("LEFT", frame.box, "LEFT", x, y);
  texture:SetSize(width, 1);
end
