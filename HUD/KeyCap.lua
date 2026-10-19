local _, ns = ...;
local issecretvalue, GetInteractKeyText, InkOffset = ns.issecretvalue, ns.GetInteractKeyText, ns.InkOffset;

----
--  Interact key cap, on Blizzard's key art: the plunderstorm key, else the tutorial key, else a plain
--  box. margins is the transparent art around the key face (left, top, right, bottom), as shares of the
--  art's width and height. The plunderstorm key's border runs from x 16 to 92 and y 16 to 80 of its
--  108x96 image. Shares hold whatever size GetAtlasInfo reports. The cap frame is the face, so the layout
--  spaces the visible key like the icon, and the art's margins hang outside the frame. bottomBorder is the
--  center of the face's bottom border line as a share of the art's height (rows 79-80 of 96, the same art
--  on Forever and Era); fitted input sizes and their text fields use this reference.
----
local KEYCAP_STYLES = { --in order of preference
  { atlas = "plunderstorm-icon-key", textColor = {1, 1, 1}, shadow = true,
    margins = {16 / 108, 16 / 96, 15 / 108, 15 / 96}, topBorder = 16 / 96, bottomBorder = 80 / 96 },
  { atlas = "newplayertutorial-icon-key", textColor = {0, 0, 0}, shadow = false },
};
local NO_MARGINS = {0, 0, 0, 0};

local keyTextMeasure = ns.CreateMeasure();

-- The interact key's cap: its art, its text and its colors. Other parts of the HUD reach it through
-- frame.keyCap and the hud.StyleKeyCap, hud.PaintKeyCap and hud.UpdateKeyCap functions.
function ns.SetupKeyCap(hud)
  local frame = hud.frame;
  local cap = CreateFrame("Frame", nil, frame);
  cap.icon = cap:CreateTexture(nil, "ARTWORK");
  cap.text = cap:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
  cap:Hide();
  frame.keyCap = cap;
  ns.ModifierKey.Create(cap);

  local function KeyboardArt()
    for _, style in ipairs(KEYCAP_STYLES) do
      local info = C_Texture.GetAtlasInfo(style.atlas);
      if info and info.width > 0 and info.height > 0 then
        return { aspect = info.width / info.height, margins = style.margins or NO_MARGINS,
          topBorder = style.topBorder, bottomBorder = style.bottomBorder }, style;
      end
    end
    return { aspect = 1, margins = NO_MARGINS };
  end

  -- Styles the cap with the first key art this client has, else a plain dark box. cap.art keeps the art's
  -- proportions and face margins for SetKeyCapText.
  local function StyleKeyCap()
    cap.isGlyph = false;
    cap.styleArt = ns.styles.Get();
    cap.keyStyle = EnhancedSoftInteractDB.keyStyle;
    cap.classic = not cap.styleArt.ownKey and cap.keyStyle == "classic";
    cap.classicCanvasWidth, cap.classicCanvasHeight, cap.classicCanvasOffsetY = nil, nil, nil;
    for _, slices in ipairs(cap.classicButton or {}) do
      for _, texture in ipairs(slices) do texture:Hide(); end
    end
    if cap.classic then
      -- Both keyboard choices share the selected native reference's logical face and border anchors.
      -- Classic's transparent source padding belongs to its drawing canvas, not to that layout face.
      local reference = KeyboardArt();
      local m = reference.margins;
      local faceShareX, faceShareY = 1 - m[1] - m[3], 1 - m[2] - m[4];
      cap.art = { aspect = reference.aspect * faceShareX / faceShareY, margins = NO_MARGINS };
      if reference.bottomBorder then
        cap.art.topBorder = ((reference.topBorder or m[2]) - m[2]) / faceShareY;
        cap.art.bottomBorder = (reference.bottomBorder - m[2]) / faceShareY;
      end
      cap.icon:SetColorTexture(0, 0, 0, 0);
      cap.icon:SetTexCoord(0, 1, 0, 1);
      cap.textColor = {1, 1, 1};
      cap.text:SetShadowOffset(1, -1);
      if not cap.classicButton then
        cap.classicButton = {};
        for state, file in ipairs({[[Interface\Buttons\UI-Panel-Button-Up]], [[Interface\Buttons\UI-Panel-Button-Down]]}) do
          local slices = {};
          cap.classicButton[state] = slices;
          for i, coords in ipairs({{0, 0.09375}, {0.09375, 0.53125}, {0.53125, 0.625}}) do
            -- Down draws above Up; textures sharing a sublevel have no guaranteed order.
            local texture = cap:CreateTexture(nil, "ARTWORK", nil, state);
            texture:SetTexture(file);
            texture:SetTexCoord(coords[1], coords[2], 0, 0.6875);
            texture:SetDesaturated(true);
            slices[i] = texture;
          end
        end
      end
      return;
    end
    if ns.styles.Get().flatKey then
      cap.art = { aspect = 1, margins = NO_MARGINS };
      local data = ns.ElvTheme.Media();
      local background = data and data.backdropcolor or {0.1, 0.1, 0.1};
      cap.icon:SetColorTexture(background[1] * 0.6, background[2] * 0.6, background[3] * 0.6, 1);
      cap.icon:SetTexCoord(0, 1, 0, 1);
      cap.textColor = {1, 1, 1};
      cap.text:SetShadowOffset(0, 0);
      ns.styles.Snap(cap.icon, false);
      return;
    end
    ns.styles.Snap(cap.icon, true);
    local art, style = KeyboardArt();
    cap.art = art;
    if style then
      cap.icon:SetAtlas(style.atlas);
      cap.textColor = style.textColor;
      cap.text:SetShadowOffset(style.shadow and 1 or 0, style.shadow and -1 or 0);
      return;
    end
    cap.icon:SetColorTexture(0, 0, 0, 0.6);
    cap.textColor = {1, 1, 1};
    cap.text:SetShadowOffset(1, -1);
  end

  -- A blocked interaction dims the input; the status line explains why. Press shading still applies.
  local WHITE = {1, 1, 1};
  local function PaintKeyCap()
    for state, slices in ipairs(cap.classicButton or {}) do
      for _, texture in ipairs(slices) do
        local tint = (cap.pressShade or 1) * ((frame.outOfRange or frame.requirementText ~= nil) and 0.7 or 1);
        texture:SetVertexColor(tint, tint * 0.98, tint * 0.93, 1);
        texture:SetAlpha(state == 1 and 1 or (cap.pressDepth or 0));
        texture:SetShown(cap.classic and cap:IsShown() and not cap.isGlyph and (texture.classicWidth or 0) > 0);
      end
    end
    if cap.classic and not cap.isGlyph and cap.textX then
      cap.text:SetPoint("CENTER", cap.textX, cap.textY - (cap.pressDepth or 0));
    end
    if ns.styles.Get().flatKey and not cap.isGlyph then
      local data = ns.ElvTheme.Media();
      local bg = data and data.backdropcolor or {0.1, 0.1, 0.1};
      cap.icon:SetColorTexture(bg[1] * 0.6, bg[2] * 0.6, bg[3] * 0.6, 1);
      cap.icon:SetVertexColor(1, 1, 1, 1);
      local shade = (frame.outOfRange or frame.requirementText) and 0.75 or 1;
      cap.text:SetTextColor(shade, shade, shade);
      local style = ns.styles.Get();
      if style.PaintKeyCap then style.PaintKeyCap(frame, cap); end
      ns.ModifierKey.Paint(frame);
      return;
    end
    local shade = cap.pressShade or 1;
    local function Shaded(c) return c[1] * shade, c[2] * shade, c[3] * shade end
    local blocked = frame.outOfRange or frame.requirementText ~= nil;
    local neutral = blocked and {0.75, 0.75, 0.75};
    cap.icon:SetDesaturated(cap.isGlyph and blocked and true or false);
    if cap.isGlyph then
      cap.icon:SetVertexColor(Shaded(neutral or WHITE));
    else
      cap.icon:SetVertexColor(Shaded(blocked and {0.7, 0.7, 0.7} or WHITE));
      cap.text:SetTextColor(Shaded(neutral or cap.textColor));
    end
    local style = ns.styles.Get();
    if style.PaintKeyCap then style.PaintKeyCap(frame, cap, shade, blocked); end
    ns.ModifierKey.Paint(frame);
  end

  -- SetKeyCapText moves the key text off the cap's center. A font string centers its whole line, including
  -- the room for descenders, so capitals sit high. The text moves down 0.04 font sizes
  -- and right by KEY_TEXT_NUDGE_X font sizes to center the visible letters. WoW snaps text to whole pixels,
  -- so a letter can still land half a pixel off.
  local KEY_TEXT_NUDGE_X = 0.06;

  -- Each style's size profile owns the key face, glyph and lettering heights. Keyboard labels fit
  -- their natural F face; controller chords retain room to widen without moving vertical anchors.
  local KEY_TEXT_PAD = 10;
  -- Composite glyphs stay inside the shared keycap. Their explicit atlas sizes do not follow SetFont.
  local function ScaleGamepadText(text, scale, limit)
    local tallest = 0;
    for height in text:gmatch("|A:Gamepad_[^:|]+:([^:|]*)") do
      tallest = math.max(tallest, (tonumber(height) or 0) * scale);
    end
    if tallest > limit then scale = scale * limit / tallest; end
    text = text:gsub("(|A:Gamepad_[^:|]+:)([^:|]*):([^:|]*)([^|]*|a)", function(prefix, height, width, suffix)
      local h, w = tonumber(height), tonumber(width);
      -- Zero or omitted dimensions let the font choose the size. Preserve atlas offsets and artwork.
      if h and h > 0 then height = h * scale; end
      if w and w > 0 then width = w * scale; end
      return prefix .. height .. ":" .. width .. suffix;
    end);
    return text;
  end
  local function SetKeyCapText(text)
    local db = EnhancedSoftInteractDB;
    local style = ns.styles.Get();
    local size = ns.styles.Size(db);
    local buttonScale = ns.styles.ButtonScale(db);
    if style.KeyText then text = style.KeyText(frame, text); end
    if cap.isGlyph or cap.styleArt ~= style or cap.keyStyle ~= db.keyStyle then StyleKeyCap(); end
    local managed = ns.ModifierKey.Prepare(frame, cap.key, text);
    local glyph = text:match("^|A:([^:|]+):[^|]*|a$");
    glyph = glyph and glyph:gsub("_32$", "_64");
    if glyph and C_Texture.GetAtlasInfo(glyph) then
      cap.icon:SetAtlas(glyph);
      cap.icon:ClearAllPoints();
      cap.icon:SetAllPoints();
      cap.text:SetText("");
      cap.isGlyph = true;
      local height = ns.styles.KeyFaceHeight(frame, db, true);
      cap.capWidth, cap.capHeight = height, height;
      cap:SetSize(height, height);
      cap.cellScale = math.min(1, ns.styles.CellSize(db) / height);
      cap:SetScale(cap.cellScale);
      PaintKeyCap();
      return;
    end
    local m = cap.art.margins;
    local faceShareX, faceShareY = 1 - m[1] - m[3], 1 - m[2] - m[4];
    local faceHeight = ns.styles.KeyFaceHeight(frame, db, false);
    local height = faceHeight / faceShareY;
    local gamepadText = text:find("|A:Gamepad_", 1, true);
    if gamepadText then text = ScaleGamepadText(text, size.inputScale * buttonScale, faceHeight - 2 * size.inputScale * buttonScale); end
    local fontPath = ns.styles.Font(db);
    local fontSize = size.keyFontSize * buttonScale;
    cap.text:SetFont(fontPath, fontSize, ns.styles.FontFlags());
    local textNudge = style.flatKey and 0 or KEY_TEXT_NUDGE_X;
    cap.textX = gamepadText and 0 or fontSize * (textNudge - InkOffset(text, fontPath));
    cap.textY = gamepadText and 0 or -fontSize * 0.04;
    cap.text:SetPoint("CENTER", cap.textX, cap.textY);
    cap.text:SetText(text);
    keyTextMeasure:SetFont(fontPath, fontSize, ns.styles.FontFlags());
    keyTextMeasure:SetText(managed and "F" or text);
    local textWidth = keyTextMeasure:GetStringWidth();
    if issecretvalue(textWidth) then textWidth = fontSize * #(managed and "F" or text) * 0.6; end --rough estimate; not seen yet
    if style.KeyWidth and not managed then textWidth = math.max(textWidth, style.KeyWidth(frame, height)); end
    local naturalWidth = height * cap.art.aspect * faceShareX;
    cap.capWidth = managed and naturalWidth or math.max(naturalWidth,
      textWidth + (style.keyTextPadding or KEY_TEXT_PAD) * 1.3 * size.inputScale * buttonScale);
    cap.capHeight = faceHeight;
    if style.Pixel then
      local pixel = style.Pixel(frame);
      cap.capWidth = math.floor(cap.capWidth / pixel + 0.5) * pixel;
      cap.capHeight = math.floor(cap.capHeight / pixel + 0.5) * pixel;
      height = cap.capHeight / faceShareY;
    end
    cap:SetSize(cap.capWidth, cap.capHeight);
    -- Fit the visible input face uniformly inside its fixed cell. Native shadow margins do not alter
    -- the matched keyboard face size. Press effects animate children and retain this base scale.
    local cell = ns.styles.CellSize(db);
    cap.cellScale = math.min(1, cell / cap.capWidth, cell / cap.capHeight);
    if style.flatKey then cap.cellScale = 1; end --Elv fits its owned input before physical-pixel snapping
    cap:SetScale(cap.cellScale);
    local artWidth = cap.capWidth / faceShareX;
    cap.icon:ClearAllPoints();
    cap.icon:SetPoint("TOPLEFT", -m[1] * artWidth, m[2] * height);
    cap.icon:SetPoint("BOTTOMRIGHT", m[3] * artWidth, -m[4] * height);
    if cap.classic then
      local canvasWidth, canvasHeight = cap.capWidth + 4 * cap.capHeight / 19, cap.capHeight * 22 / 19;
      -- Very narrow plain fallbacks meet at their center; keep the two native end pieces proportional.
      if cap.capWidth < 20 * cap.capHeight / 19 then canvasWidth = cap.capWidth * 6 / 5; end
      local offsetY, edge = cap.capHeight / 38, math.min(canvasWidth * 0.5, cap.capHeight * 12 / 19);
      cap.classicCanvasWidth, cap.classicCanvasHeight, cap.classicCanvasOffsetY = canvasWidth, canvasHeight, offsetY;
      local widths = {edge, math.max(0, canvasWidth - edge * 2), edge};
      local lefts = {0, edge, canvasWidth - edge};
      for _, slices in ipairs(cap.classicButton) do
        for i, texture in ipairs(slices) do
          texture:ClearAllPoints();
          texture:SetPoint("LEFT", cap, "CENTER", -canvasWidth * 0.5 + lefts[i], offsetY);
          texture:SetSize(math.max(0.01, widths[i]), canvasHeight);
          texture.classicWidth = widths[i];
        end
      end
    end
    ns.ModifierKey.Layout(frame, db);
    PaintKeyCap();
  end

  local function UpdateKeyCap()
    local text, key;
    if EnhancedSoftInteractDB.showKey then
      text, key = GetInteractKeyText();
      if not text and frame.sampleName then text = "F"; end --the Edit Mode sample shows "F" when the key is unbound
    end
    cap.key = key;
    cap:SetShown(text and true or false);
    if text then SetKeyCapText(text);
    else
      ns.ModifierKey.Prepare(frame, nil, nil);
      PaintKeyCap();
    end
  end

  hud.StyleKeyCap, hud.PaintKeyCap, hud.UpdateKeyCap = StyleKeyCap, PaintKeyCap, UpdateKeyCap;
end
