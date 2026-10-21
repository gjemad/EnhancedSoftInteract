local ADDON_NAME, ns = ...;
local styles, order = {}, {};
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
local commonLayers = { "iconGlow", "lineLowGlow", "lineLow", "lineHigh" };
ns.HUD_STYLES = {};
ns.styles = {};

-- A style supplies its label, visible common layers and its hooks. Create returns its extra regions; the
-- registry hides them when another style is selected. Layout uses cached numeric columns, never
-- measurements of the target's secret name.
--
-- Hooks a style may leave out. Register copies these into every style that doesn't define them, so
-- callers call the hook without checking. A few hooks are absent on purpose, and their callers check for
-- them: Pixel, IconMax, IconDimensions, KeyText, KeyWidth, PaintKeyCap, KeyOffsetY, RequirementY,
-- PlaceCast and OutcomeLight.
local DEFAULT_HOOKS = {
  showIconKey = "showIcon", --the saved setting that shows the icon
};
function DEFAULT_HOOKS.Create() return {} end
function DEFAULT_HOOKS.Apply() end
function DEFAULT_HOOKS.Remove() end
function DEFAULT_HOOKS.Layout() end
function DEFAULT_HOOKS.Paint() end

function ns.styles.Register(id, style)
  assert(not styles[id], "Duplicate HUD style: " .. id);
  for name, default in pairs(DEFAULT_HOOKS) do
    if style[name] == nil then style[name] = default; end
  end
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
-- Buttons and their labels keep their table size, so a key stays clear of Level-Up's lines (user,
-- 2026-10-19: the scaled key overlapped them). A style with scaleButtons scales them too (Elv, whose
-- panel is one button tall: user, 2026-10-19).
local PRESET_SCALE = 1.1;
local UNSCALED = { keyHeight = true, glyphHeight = true, keyFontSize = true };
local scaled = {};
function ns.styles.Size(db)
  local style = styles[db.hudStyle] or styles.levelup;
  local profile = style.sizes[db.hudSize] or style.sizes.normal;
  local size = scaled[profile];
  if not size then
    size = {};
    for key, value in pairs(profile) do
      local fixed = UNSCALED[key] and not style.scaleButtons;
      size[key] = type(value) == "number" and value * (fixed and 1 or PRESET_SCALE) or value;
    end
    scaled[profile] = size;
  end
  return size;
end

-- Fine tuning is relative to the chosen preset; its immutable profile remains the layout baseline.

-- Invisible side cells reserve space independently of their artwork and input labels. A style can
-- own its cells (Elv: a flush square plus the gap to the name).
function DEFAULT_HOOKS.CellSize(db) return 46 * ns.styles.Size(db).inputScale end
function ns.styles.CellSize(db) return ns.styles.Get().CellSize(db) end

-- Distance from the box edge to the center of a side cell's content.
function DEFAULT_HOOKS.CellCenter(db) return ns.styles.CellSize(db) * 0.5 end
function ns.styles.CellCenter(db) return ns.styles.Get().CellCenter(db) end

function DEFAULT_HOOKS.SidePadding(db) return 18 * ns.styles.Size(db).inputScale end
function ns.styles.SidePadding(db) return ns.styles.Get().SidePadding(db) end

-- Font flags for the name, status and key text ("" draws no outline).
function DEFAULT_HOOKS.FontFlags() return "" end
function ns.styles.FontFlags() return ns.styles.Get().FontFlags() end

function DEFAULT_HOOKS.Font(db) return ns.media:Fetch("font", db.font) end
function ns.styles.Font(db) return ns.styles.Get().Font(db) end

function ns.styles.ShowIcon(db) return db[ns.styles.Get().showIconKey] end

function ns.styles.NameMinWidth(db)
  return ns.styles.Size(db).nameMinWidth;
end

-- Shared names use the HUD origin.
function DEFAULT_HOOKS.NameOffset(frame, db, amount)
  local style, size = ns.styles.Get(), ns.styles.Size(db);
  return (style.nameOffsetY or 0) * size.inputScale + size.fontSize * 0.26 * amount
    + ns.styles.StatusOffset(frame, db) * amount;
end
function ns.styles.NameOffset(frame, db, amount) return ns.styles.Get().NameOffset(frame, db, amount) end

function ns.styles.IconDimensions(frame, db)
  local style = ns.styles.Get();
  local width, height = ns.styles.Size(db).iconSize, ns.styles.Size(db).iconSize;
  if style.IconDimensions then width, height = style.IconDimensions(frame, db); end
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

-- Pixel snapping for a texture. snapped = true lets the client place it on the pixel grid. snapped = false
-- leaves a rect that was already placed on whole pixels alone, so native rounding and texel bias can't
-- shift it. Some clients lack these methods.
function ns.styles.Snap(texture, snapped)
  if texture.SetRoundLayoutToNearestPixel then texture:SetRoundLayoutToNearestPixel(false); end
  if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(snapped); end
  if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(snapped and 0.5 or 0); end
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
  ns.styles.Snap(texture, false);
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

-- A vertical mark on whole pixels (cast markers, end ticks), centered on a line that PixelStrip draws at y
-- with lineHeight. The mark gets the line's pixel parity, so it reaches as far above the line as below.
-- Rounded on its own, an even-height mark around a one-pixel line stood a pixel higher or lower
-- depending on the line's position (user report 2026-10-20: Runic's markers sat higher with keycaps).
function ns.styles.PixelMark(frame, texture, left, width, y, height, lineHeight)
  local pixel = ns.styles.Pixel(frame);
  lineHeight = math.max(pixel, ns.styles.Round(lineHeight, pixel));
  height = math.max(pixel, ns.styles.Round(height, pixel));
  if math.floor((height - lineHeight) / pixel + 0.5) % 2 == 1 then height = height + pixel; end
  local x, lineTop = ns.styles.Origin(frame, -frame.boxWidth * 0.5 + left, y + lineHeight * 0.5, pixel);
  ns.styles.Rect(texture, frame.box, x, lineTop + (height - lineHeight) * 0.5,
    math.max(pixel, ns.styles.Round(width, pixel)), height);
end

local function TextClearance(db, offset, clearance)
  -- The status is centered 0.41 font sizes down and uses a 0.65-size font. Reserve half that font
  -- below its center, plus the style's decoration clearance; retain a larger normal line offset.
  local size = ns.styles.Size(db);
  return math.max(size.fontSize * 0.5 + offset * size.inputScale,
    size.fontSize * 0.735 + (clearance or 2) * size.inputScale);
end

-- Text and lines use stable font-relative baselines. Outer icon/key sizes do not move them.
-- Underlines sit five preset-scaled units above the side cells' bottom edge, including status text.
function DEFAULT_HOOKS.UnderlineY(_, db)
  return -ns.styles.CellSize(db) * 0.5 + 5 * ns.styles.Size(db).inputScale;
end
function ns.styles.UnderlineY(frame, db) return ns.styles.Get().UnderlineY(frame, db) end

-- Status text moves clear of a style's ornament. Ready names keep the common content center.
function DEFAULT_HOOKS.StatusOffset() return 0 end
function ns.styles.StatusOffset(frame, db) return ns.styles.Get().StatusOffset(frame, db) end

-- Shared buttons use Level-Up's Normal height, scaled with the preset.
-- Elv retains its compact style-owned face; native artwork keeps its proportions in either path.
function DEFAULT_HOOKS.KeyFaceHeight(db, glyph)
  local size = ns.styles.Size(db);
  return (glyph and size.glyphHeight or size.keyHeight);
end
function ns.styles.KeyFaceHeight(_, db, glyph) return ns.styles.Get().KeyFaceHeight(db, glyph) end

function ns.styles.LineY(frame, db, offset)
  if ns.styles.Get().underline then return ns.styles.UnderlineY(frame, db); end
  return -TextClearance(db, offset);
end

function ns.styles.Create(frame)
  frame.styleRegions = {};
  frame.stylePulseLayers = {};
  for _, id in ipairs(order) do
    local style = styles[id];
    local regions = style.Create(frame, MEDIA);
    frame.styleRegions[id] = regions;
    for _, region in ipairs(regions) do region:Hide(); end
  end
end

function ns.styles.Apply(frame)
  local style = ns.styles.Get();
  -- A style that changes shared regions (masks, icon tint) undoes that when another style takes over.
  if frame.appliedStyle and frame.appliedStyle ~= style then
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
    ns.styles.Snap(frame[name], true);
  end
  frame.flash:SetTexture(MEDIA .. "SoftGlow");
  frame.flash:SetDesaturated(false);
  frame.flash:SetGradient("VERTICAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1));
  frame.flash:ClearAllPoints();
  frame.flash:SetPoint("TOPLEFT", frame.box, "TOPLEFT", -20, 0);
  frame.flash:SetPoint("BOTTOMRIGHT", frame.box, "BOTTOMRIGHT", 20, 0);
  style.Apply(frame);
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
  ns.styles.Get().Layout(frame, EnhancedSoftInteractDB);
end

function ns.styles.Paint(frame, r, g, b)
  local style = ns.styles.Get();
  frame.lineHigh:SetVertexColor(r, g, b, style.highLineAlpha or 0.5);
  local strength = style.flashStrength or 1;
  -- The holder owns animation opacity; texture alpha stays opaque while its RGB changes.
  frame.flash:SetVertexColor(r * strength, g * strength, b * strength, 1);
  style.Paint(frame, r, g, b);
end
