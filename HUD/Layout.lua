local _, ns = ...;
local Clamp, CreateTween = ns.Clamp, ns.CreateTween;
local NormalizeCursorKey, issecretvalue = ns.NormalizeCursorKey, ns.issecretvalue;
local nameMeasure = ns.CreateMeasure();

-- Where everything sits in the HUD: the icon, the name and status text, and the box that holds the icon,
-- name and key columns. hud.UpdateLayout lays the columns out again, and the Update functions follow a
-- change to the icon, font or height. hud.ResetLayout stops their animations.
function ns.SetupLayout(hud)
  local frame = hud.frame;
  local cap = frame.keyCap;

  -- Shows the target's name in both the normal and the compact label.
  local function SetName(text)
    frame.name:SetText(text);
    frame.compactName:SetText(text);
  end

  -- Invisible fixed-size side cells center the icon and key independently of their artwork.
  -- Swap Icon and Key swaps the complete cells. A hidden cell becomes the shared edge padding.
  local function Inset(side)
    local half = ns.styles.CellCenter(EnhancedSoftInteractDB);
    return side == "LEFT" and half or -half;
  end

  -- Most cursor art isn't centered in its image. IconArtOffset picks the measurements for the actual
  -- mouse or crosshair artwork, in 64px units; the icon moves the other way. AnchorIcon
  -- rounds the nudge to whole units, because the renderer may snap a fractional nudge away. Every client
  -- keeps a full iconSize column and centers the visible art in it: Forever's crosshair art and Era's
  -- native mouse cursors (Cursors.lua, triangle included).
  local function AnchorIcon()
    local side = EnhancedSoftInteractDB.swapIconAndKey and "RIGHT" or "LEFT";
    local key = frame.colorKey and NormalizeCursorKey(frame.colorKey);
    local offset = key and ns.IconArtOffset(frame.icon, key, frame.iconFromFileID);
    local nudgeX, nudgeY = 0, 0;
    local width, height = ns.styles.IconDimensions(frame, EnhancedSoftInteractDB);
    if offset then
      local function Round(v) return v >= 0 and math.floor(v + 0.5) or -math.floor(-v + 0.5) end
      nudgeX, nudgeY = Round(-offset[1] * width / 64), Round(offset[2] * height / 64);
    end
    frame.iconNudgeX, frame.iconNudgeY = nudgeX, nudgeY; --for /esi debug
    frame.icon:SetSize(width, height);
    frame.iconCenterY, frame.iconColumnWidth = 0, width; --for the test tools
    frame.icon:ClearAllPoints();
    frame.icon:SetPoint("CENTER", frame.box, side, Inset(side) + nudgeX, nudgeY);
  end

  local function SetIconSide()
    local keySide = EnhancedSoftInteractDB.swapIconAndKey and "LEFT" or "RIGHT";
    AnchorIcon();
    cap:ClearAllPoints();
    cap:SetPoint("CENTER", frame.box, keySide, Inset(keySide), 0);
  end

  -- The glow behind the icon is GLOW_W x GLOW_H icon sizes in range and shrinks to GLOW_OUT_OF_RANGE_SCALE
  -- of that out of range. While the HUD is visible it gets there over GLOW_TIME, easing out from its
  -- current size, so a range change halfway reverses smoothly. It resizes the texture instead of using a
  -- Scale animation, so repeated changes can't add up.
  local GLOW_W, GLOW_H = 2.2, 1.9;
  local GLOW_OUT_OF_RANGE_SCALE = 0.55;
  local GLOW_TIME = 0.25;
  local function SizeGlow()
    local width, height = ns.styles.IconDimensions(frame, EnhancedSoftInteractDB);
    local scale = Clamp(frame.glowScale or 1, GLOW_OUT_OF_RANGE_SCALE, 1);
    frame.iconGlow:SetSize(width * scale * GLOW_W, height * scale * GLOW_H);
  end

  local glowTween, glowTarget = CreateTween(), nil;
  local function SetGlowScale(target, animate)
    if not (animate and frame.glowScale) then
      glowTween:Stop();
      glowTarget, frame.glowScale = target, target;
      SizeGlow();
      return;
    end
    if target == glowTarget then return end --already there or on the way
    glowTarget = target;
    local from = frame.glowScale;
    glowTween:Play(GLOW_TIME, function(t)
      frame.glowScale = from + (target - from) * (1 - (1 - t) ^ 2);
      SizeGlow();
    end);
  end

  local function UpdateIcon()
    local db = EnhancedSoftInteractDB;
    frame.icon:SetShown(ns.styles.ShowIcon(db));
    local style = ns.styles.Get();
    frame.iconGlow:SetShown(ns.styles.ShowIcon(db) and style.layers and style.layers.iconGlow or false);
    SizeGlow();
    AnchorIcon(); --the nudge scales with the icon size
  end

  ----
  --  Name, requirement line and columns
  ----

  -- Range and profession messages share the compact name layout. Availability fades the message and
  -- blends fixed-size labels on one moving anchor without changing the HUD's height or measuring
  -- a secret region. Keep font sizes fixed so glyph rasterization cannot step during the transition.
  local REQ_NAME_SCALE, REQ_TEXT_SCALE = 0.82, 0.65;
  local REQ_TEXT_Y = -0.41;
  local REQ_NAME_GREY = 0.8;
  -- The skill-up icon (Blizzard's 13 x 15 recipe list arrows) is anchored to the name and centered between
  -- the interaction icon and the name's text, at least SKILL_GAP from the text. With no
  -- interaction icon on its left, it centers between the name column's edge and the text. It follows the
  -- name through the status transition, and with a status line it moves STATUS_PULL of the way toward
  -- SKILL_GAP from the smaller name. It is drawn at SKILL_SCALE at Normal (font size 17.6) and
  -- follows the font size.
  local SKILL_W, SKILL_H, SKILL_GAP, SKILL_SCALE, SKILL_FONT, STATUS_PULL = 13, 15, 3, 1, 17.6, 0.5;
  -- The visible art reaches this far from the interaction icon's center, in icon widths: Forever's
  -- mining pick fills about 74% of its crosshair texture.
  local ICON_ART_REACH = 0.37;
  local statusTween = CreateTween();
  local function PaintStatus(amount)
    local db = EnhancedSoftInteractDB;
    frame.statusAmount = amount;
    local c = frame.nameColor;
    frame.name:SetTextColor(c[1], c[2], c[3]);
    frame.compactName:SetTextColor(REQ_NAME_GREY, REQ_NAME_GREY, REQ_NAME_GREY);
    frame.nameOffsetY = ns.styles.NameOffset(frame, db, amount);
    frame.name:SetPoint("CENTER", frame.box, "LEFT",
      frame.nameLeft + frame.nameWidth * 0.5, frame.nameOffsetY);
    frame.compactName:SetPoint("CENTER", frame.name, "CENTER");
    if frame.skillTextWidth then
      local half = frame.skillTextWidth * (1 - amount + REQ_NAME_SCALE * amount) * 0.5;
      local closest = half + frame.skillGap + frame.skillIconWidth * 0.5;
      local centered = math.max(closest, (half + frame.skillEdge) * 0.5);
      local x = centered + (closest - centered) * STATUS_PULL * amount;
      frame.skillIcon:SetPoint("CENTER", frame.name, "CENTER", -x, 0);
    end
    frame.name:SetAlpha(1 - amount);
    frame.compactName:SetAlpha(amount);
    frame.requirement:SetAlpha(amount);
    frame.requirement:SetShown(amount > 0);
    frame.statusShadow:SetAlpha(0.35 * amount);
    frame.statusShadow:SetShown(amount > 0);
  end

  local function StyleName(animate)
    local text = frame.requirementText or (frame.outOfRange and "Move closer");
    local to = text and 1 or 0;
    if not (animate and frame.statusAmount ~= nil) then
      statusTween:Stop();
      frame.statusTarget = to;
      PaintStatus(to);
    elseif frame.statusTarget ~= to then
      statusTween:Stop();
      frame.statusTarget = to;
      local from = frame.statusAmount;
      statusTween:Play(0.25, function(t)
        t = t * t * (3 - 2 * t);
        PaintStatus(from + (to - from) * t);
      end);
      PaintStatus(from);
    else
      PaintStatus(frame.statusAmount);
    end
  end

  -- The box is a table of three columns: icon | name | key cap (swapIconAndKey swaps the outer two). The icon
  -- and key columns are fixed cells (CellSize); a hidden one shrinks to the edge padding (SidePadding). The
  -- name column fits the name (and the requirement line) between nameMinWidth and nameMaxWidth, and cuts a longer
  -- name short with "...", after its font steps down through NAME_FONT_STEPS to fit. A secret name has a
  -- secret width, so its column takes SECRET_NAME_SCALE of nameMaxWidth and its font always takes
  -- SECRET_FONT_SCALE. A faint crossed-out eye at the column's right end marks it. The name can't be
  -- measured, so the eye stays there, and the name gives up the same room on both sides to stay centered.
  local NAME_FONT_STEPS = { 0.95, 0.9, 0.85 };
  local SECRET_NAME_SCALE, SECRET_FONT_SCALE = 0.67, 0.9;
  local SECRET_ICON_W, SECRET_ICON_H, SECRET_ICON_INSET, SECRET_NAME_ROOM = 16, 13.25, 9.5, 18; --at font size 17.6
  local function UpdateLayout(animate)
    local db = EnhancedSoftInteractDB;
    local minName = ns.styles.NameMinWidth(db);
    local maxName = math.max(minName, ns.styles.Size(db).nameMaxWidth);
    AnchorIcon();
    local cell = ns.styles.CellSize(db);
    local padding = ns.styles.SidePadding(db);
    local left = ns.styles.ShowIcon(db) and cell or padding;
    local right = cap:IsShown() and cell or padding;
    if db.swapIconAndKey then left, right = right, left; end
    local style = ns.styles.Get();
    local edgeLeft, edgeRight = 0, 0;
    frame.cellSize, frame.sidePadding = cell, padding; --for the test tools
    -- Returns the column width, and the text's own width when it isn't secret.
    local secretRoom = SECRET_NAME_ROOM * ns.styles.Size(db).fontSize / SKILL_FONT;
    local secretWidth = math.max(minName, math.floor(maxName * SECRET_NAME_SCALE));
    -- A secret string never reaches nameMeasure: its secret aspect would stay on the font string, and
    -- every later measurement, of readable names too, would come back secret.
    local function FitWidth(text, size, width)
      if issecretvalue(text) then return secretWidth end
      nameMeasure:SetFont(ns.styles.Font(db), size, ns.styles.FontFlags());
      nameMeasure:SetText(text);
      local textWidth = nameMeasure:GetStringWidth();
      if issecretvalue(textWidth) then return secretWidth end
      return math.min(maxName, math.max(width, math.ceil(textWidth) + 1)), textWidth; --+1: no "..." on an exact fit
    end
    local textScale = REQ_TEXT_SCALE;
    local nameWidth, nameTextWidth = secretWidth, nil; --the settings preview's Secret name checkbox
    if not (frame.sampleName and frame.sampleSecret) then
      nameWidth, nameTextWidth = FitWidth(frame.sampleName or UnitName("softInteract") or "",
        ns.styles.Size(db).fontSize, minName);
    end
    local nameFontScale = nameTextWidth and 1 or SECRET_FONT_SCALE;
    if nameTextWidth and math.ceil(nameTextWidth) + 1 > maxName then
      local fullWidth = nameTextWidth;
      for _, scale in ipairs(NAME_FONT_STEPS) do
        nameFontScale, nameTextWidth = scale, fullWidth * scale;
        if math.ceil(nameTextWidth) + 1 <= maxName then break end
      end
    end
    frame.nameFontScale = nameFontScale; --for the test tools
    local text = frame.requirementText or (frame.outOfRange and "Move closer");
    local statusWidth = minName;
    if text then
      statusWidth = FitWidth(text, ns.styles.Size(db).fontSize * textScale, 0);
      nameWidth = math.max(nameWidth, statusWidth);
    end
    -- The skill-up icon needs room before the name's text. What the column doesn't leave is added
    -- outside it, so the name column and the cast bar keep the text's width. The same
    -- room goes on both sides, so full-width lines stay centered on the name and the cast bar.
    -- A secret name has no width to place the icon by, so it shows none.
    local skillAtlas = nameTextWidth and db.showSkillUp and ns.SkillUpAtlas(frame.skillUp);
    local skillUnit = ns.styles.Size(db).fontSize / SKILL_FONT;
    if skillAtlas then
      local room = (nameWidth - math.min(nameTextWidth, nameWidth)) * 0.5;
      edgeLeft = math.max(0, (SKILL_W * SKILL_SCALE + SKILL_GAP) * skillUnit - room);
      edgeRight = edgeLeft;
    end
    -- Prepare the text and a full line before showing it, including the first target after /reload.
    if text then
      frame.requirement:SetText(text);
      if frame.outOfRange and not frame.requirementText then
        frame.requirement:SetTextColor(1, 0.82, 0.35);
      else
        frame.requirement:SetTextColor(RED_FONT_COLOR:GetRGB());
      end
    end
    frame.requirement:SetFont(ns.styles.Font(db), ns.styles.Size(db).fontSize * textScale, ns.styles.FontFlags());
    frame.requirement:ClearAllPoints();
    local requirementY = style.RequirementY and style.RequirementY(frame, db)
      or (style.nameOffsetY or 0) * ns.styles.Size(db).inputScale
      + ns.styles.Size(db).fontSize * REQ_TEXT_Y + ns.styles.StatusOffset(frame, db);
    frame.requirement:SetPoint("LEFT", frame.box, "LEFT", edgeLeft + left, requirementY);
    frame.requirement:SetWidth(nameWidth);
    frame.requirement:SetHeight(math.ceil(ns.styles.Size(db).fontSize * textScale * 1.5));
    frame.statusShadow:ClearAllPoints();
    frame.statusShadow:SetPoint("CENTER", frame.box, "LEFT", edgeLeft + left + nameWidth * 0.5, requirementY);
    frame.statusShadow:SetSize(statusWidth + 32, ns.styles.Size(db).fontSize * textScale + 11);
    frame.name:ClearAllPoints();
    frame.name:SetFont(ns.styles.Font(db), ns.styles.Size(db).fontSize * nameFontScale, ns.styles.FontFlags());
    local secretName = nameTextWidth == nil;
    local labelWidth = secretName and nameWidth - 2 * secretRoom or nameWidth;
    frame.name:SetWidth(labelWidth);
    frame.secretIcon:SetShown(secretName);
    if secretName then
      frame.secretIcon:SetAtlas("transmog-icon-hidden");
      frame.secretIcon:SetSize(SECRET_ICON_W * skillUnit, SECRET_ICON_H * skillUnit);
      frame.secretIcon:ClearAllPoints();
      frame.secretIcon:SetPoint("CENTER", frame.box, "LEFT",
        edgeLeft + left + nameWidth - SECRET_ICON_INSET * skillUnit, ns.styles.NameOffset(frame, db, 0));
    end
    frame.skillTextWidth = skillAtlas and math.min(nameTextWidth, nameWidth) or nil;
    frame.skillGap, frame.skillIconWidth = SKILL_GAP * skillUnit, SKILL_W * SKILL_SCALE * skillUnit;
    frame.skillIcon:SetShown(frame.skillTextWidth ~= nil);
    if frame.skillTextWidth then
      frame.skillIcon:SetAtlas(skillAtlas);
      frame.skillIcon:SetSize(frame.skillIconWidth, SKILL_H * SKILL_SCALE * skillUnit);
    end
    frame.compactName:SetFont(ns.styles.Font(db), ns.styles.Size(db).fontSize * REQ_NAME_SCALE * nameFontScale, ns.styles.FontFlags());
    -- An outlined style draws no drop shadow (ElvUI's convention); others keep the font's own shadow.
    for _, label in ipairs({ frame.name, frame.compactName, frame.requirement }) do
      if style.noTextShadow then label:SetShadowOffset(0, 0); else label:SetShadowOffset(unpack(label.baseShadow)); end
    end
    frame.compactName:SetWidth(labelWidth);
    frame.name:SetJustifyH("CENTER");
    frame.compactName:SetJustifyH("CENTER");
    frame.requirement:SetJustifyH("CENTER");
    local width = edgeLeft + left + nameWidth + right + edgeRight;
    frame.box:SetWidth(width);
    frame.boxWidth, frame.nameWidth = width, nameWidth; --for /esi debug; reading them back could be secret
    frame.nameLeft = edgeLeft + left;
    -- How far left of the name's center the skill-up icon's space starts: the interaction icon's visible
    -- right edge, or the left cell's edge.
    local iconRight = ns.styles.ShowIcon(db) and not db.swapIconAndKey
      and ns.styles.CellCenter(db) + ns.styles.IconDimensions(frame, db) * ICON_ART_REACH;
    frame.skillEdge = frame.nameLeft + nameWidth * 0.5 - (iconRight or left);
    -- Center the name column, rather than the combined icon/name/key width. Resizing an outer column
    -- must not slide the name and status sideways. The cached offset also informs pixel snapping.
    frame.boxOffsetX = width * 0.5 - frame.nameLeft - nameWidth * 0.5;
    frame.box:SetPoint("CENTER", frame, "CENTER", frame.boxOffsetX, 0);
    StyleName(animate);
    SetIconSide(); --center the artwork in its reserved side cells
    ns.styles.Layout(frame);
    ns.CastBar.Layout(frame);
    if frame.onLayout then frame.onLayout(width); end --the preview widens its window to fit the HUD
  end

  -- After a font or font size change, the name, key cap, columns and lines follow.
  local function UpdateFont()
    SetName(frame.sampleName or UnitName("softInteract"));
    hud.UpdateKeyCap();
    UpdateLayout();
    -- Invalidate native glyph caches after applying the new face, including an unchanged target.
    -- Forward text as-is: a target name may be secret, so never inspect or transform it here.
    for _, label in ipairs({ frame.name, frame.compactName, frame.requirement, cap.text }) do
      local text = label:GetText();
      label:SetText(nil);
      label:SetText(text);
    end
  end

  local function UpdateHeight()
    frame.box:SetHeight(ns.styles.Size(EnhancedSoftInteractDB).hudHeight);
  end

  -- Stops the glow and status animations, so nothing half-finished carries over to the next target.
  function hud.ResetLayout()
    glowTween:Stop();
    statusTween:Stop();
    frame.glowScale, glowTarget = nil, nil;
    frame.statusAmount, frame.statusTarget = nil, nil;
  end

  -- The glow behind the icon shrinks while the target is out of range.
  function hud.SetGlowRange(outOfRange, animate)
    SetGlowScale(outOfRange and GLOW_OUT_OF_RANGE_SCALE or 1, animate);
  end

  hud.SetName, hud.PaintStatus, hud.statusTween = SetName, PaintStatus, statusTween;
  hud.AnchorIcon, hud.SetIconSide, hud.UpdateIcon = AnchorIcon, SetIconSide, UpdateIcon;
  hud.UpdateLayout, hud.UpdateFont, hud.UpdateHeight = UpdateLayout, UpdateFont, UpdateHeight;
end
