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
function ns.styles.Size(db)
  local style = styles[db.hudStyle] or styles.levelup;
  return style.sizes[db.hudSize] or style.sizes.normal;
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

function ns.styles.IconDimensions(frame, db)
  local style = ns.styles.Get();
  if style.IconDimensions then return style.IconDimensions(frame, db) end
  local size = ns.styles.Size(db).iconSize;
  return size, size;
end

function ns.styles.Pixel(frame)
  local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor();
  if not factor then
    local _, height = GetPhysicalScreenSize();
    factor = 768 / height;
  end
  return factor / frame:GetEffectiveScale();
end

local function TextClearance(db, offset)
  -- The status is centered 0.41 font sizes down and uses a 0.65-size font. Reserve half that font
  -- below its center, plus the style's decoration clearance; retain a larger normal line offset.
  local size = ns.styles.Size(db);
  return math.max(size.fontSize * 0.5 + offset * size.inputScale,
    size.fontSize * 0.735 + (ns.styles.Get().lineClearance or 2) * size.inputScale);
end

-- Text and lines use stable font-relative baselines. Outer icon/key sizes do not move them.
function ns.styles.UnderlineY(frame, db)
  local style = ns.styles.Get();
  if style.UnderlineY then return style.UnderlineY(frame, db) end
  return -TextClearance(db, 6.5);
end

-- Runic and Plain Bar fit both measured keyboard borders between the ready capital reference and line.
-- Controller canvases use the same bounds; their native symbols retain their own transparent margins.
function ns.styles.KeyFaceHeight(frame, db, glyph)
  local size, style = ns.styles.Size(db), ns.styles.Get();
  if not style.fitKeyToName then return glyph and size.glyphHeight or size.keyHeight end
  local span = size.nameTop - ns.styles.UnderlineY(frame, db);
  if glyph then return span end
  local art = frame.keyCap.art;
  if not glyph and art and art.bottomBorder then
    local m = art.margins;
    return span * (1 - m[2] - m[4]) / (art.bottomBorder - (art.topBorder or m[2]));
  end
  return span + 1; --plain and Classic borders are centered half a unit inside each frame edge
end

-- Underlined styles align the button's visible bottom border to the fixed text baseline.
-- Resizing or changing artwork moves the button, rather than the text or underline.
function ns.styles.KeyBaselineY(frame, db)
  local cap = frame.keyCap;
  if not cap:IsShown() or not cap.capHeight then return 0 end
  local bottom = -cap.capHeight * 0.5 + (cap.isGlyph and 0 or 0.5);
  local art = cap.art;
  if art and art.bottomBorder and not cap.isGlyph then
    local m = art.margins;
    bottom = ((1 + m[2] - m[4]) * 0.5 - art.bottomBorder) / (1 - m[2] - m[4]) * cap.capHeight;
  end
  return ns.styles.UnderlineY(frame, db) - bottom;
end

-- Fitted buttons and cursor artwork share the center of the visible name/line area.
function ns.styles.ContentCenterY(frame, db)
  local style = ns.styles.Get();
  if not style.fitKeyToName then return 0 end
  return (ns.styles.Size(db).nameTop + ns.styles.UnderlineY(frame, db)) * 0.5;
end

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
