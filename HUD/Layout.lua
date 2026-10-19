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
    frame.iconCenterY = 0;
    frame.icon:SetSize(width, height);
    frame.iconColumnWidth = width;
    frame.icon:ClearAllPoints();
    frame.icon:SetPoint("CENTER", frame.box, side, Inset(side) + nudgeX, nudgeY);
  end

  local function SetIconSide()
    local keySide = EnhancedSoftInteractDB.swapIconAndKey and "LEFT" or "RIGHT";
    AnchorIcon();
    cap:ClearAllPoints();
    local style = ns.styles.Get();
    cap:SetPoint("CENTER", frame.box, keySide, Inset(keySide), style.KeyOffsetY and style.KeyOffsetY(frame, EnhancedSoftInteractDB) or 0);
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
    frame.name:SetAlpha(1 - amount);
    frame.compactName:SetAlpha(amount);
    frame.requirement:SetAlpha(amount);
    frame.requirement:SetShown(amount > 0);
    frame.statusShadow:SetAlpha(0.35 * amount);
    frame.statusShadow:SetShown(amount > 0);
  end

  local function StyleName(animate)
    local text = frame.requirementText or (frame.outOfRange and "Move closer");
    frame.showRequirement = text ~= nil;
    local to = text and 1 or 0;
    if not (animate and EnhancedSoftInteractDB.animationsEnabled and frame.statusAmount ~= nil) then
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
  -- and key columns are as wide as their contents plus COLUMN_GAP; an empty column takes no room. The name
  -- column fits the name (and the requirement line) between nameMinWidth and nameMaxWidth, and cuts a longer
  -- name short with "...". A secret name has a secret width; its column then takes nameMaxWidth.
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
    frame.cellSize, frame.sidePadding = cell, padding;
    frame.leftCellWidth, frame.rightCellWidth = left, right;
    local function FitWidth(text, size, width)
      nameMeasure:SetFont(ns.styles.Font(db), size, ns.styles.FontFlags());
      nameMeasure:SetText(text);
      local textWidth = nameMeasure:GetStringWidth();
      if issecretvalue(textWidth) then return maxName end
      return math.min(maxName, math.max(width, math.ceil(textWidth) + 1)); --+1: no "..." on an exact fit
    end
    local textScale = REQ_TEXT_SCALE;
    local nameWidth = FitWidth(frame.sampleName or UnitName("softInteract") or "", ns.styles.Size(db).fontSize, minName);
    local text = frame.requirementText or (frame.outOfRange and "Move closer");
    local statusWidth = minName;
    if text then
      statusWidth = FitWidth(text, ns.styles.Size(db).fontSize * textScale, 0);
      nameWidth = math.max(nameWidth, statusWidth);
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
    frame.name:SetFont(ns.styles.Font(db), ns.styles.Size(db).fontSize, ns.styles.FontFlags());
    frame.name:SetWidth(nameWidth);
    frame.compactName:SetFont(ns.styles.Font(db), ns.styles.Size(db).fontSize * REQ_NAME_SCALE, ns.styles.FontFlags());
    -- An outlined style draws no drop shadow (ElvUI's convention); others keep the font's own shadow.
    for _, label in ipairs({ frame.name, frame.compactName, frame.requirement }) do
      if style.noTextShadow then label:SetShadowOffset(0, 0); else label:SetShadowOffset(unpack(label.baseShadow)); end
    end
    frame.compactName:SetWidth(nameWidth);
    frame.name:SetJustifyH("CENTER");
    frame.compactName:SetJustifyH("CENTER");
    frame.requirement:SetJustifyH("CENTER");
    local width = edgeLeft + left + nameWidth + right + edgeRight;
    frame.box:SetWidth(width);
    frame.boxWidth, frame.nameWidth = width, nameWidth; --for /esi debug; reading them back could be secret
    frame.nameLeft = edgeLeft + left;
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
