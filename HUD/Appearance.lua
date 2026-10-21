local ADDON_NAME, ns = ...;
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
local Clamp, CreateTween, GetTypeColor = ns.Clamp, ns.CreateTween, ns.GetTypeColor;

-- Common shadow and glow textures; style-specific artwork lives in Styles/.
local SHADOW, GLOW = MEDIA .. "SoftShadow", MEDIA .. "SoftGlow";
local SHADOW_ALPHA = 0.9; --the soft shadow behind the text, in styles that have one

-- How the HUD looks: the transition when the target changes, the type color, the shadow and the
-- textures a style applies. hud.SetTypeColor repaints from frame.colorKey and frame.outOfRange.
function ns.SetupAppearance(hud)
  local frame = hud.frame;

  -- When the frame changes to another target or another action (skinning, then looting the same corpse),
  -- the icon and name drop 5 units at once, then rise into place and fade in over SWITCH_TIME. Translation
  -- steps in one group add up. The icon glow fades in with them: it moves with the icon at once, so without
  -- the fade it would show the old color at the new spot before the icon arrives. The type color and the
  -- HUD's alpha blend over at the same time (SetTypeColor, FadeOver).
  local SWITCH_TIME = 0.2;
  local switchSteps = {};
  for _, region in ipairs({ frame.icon, frame.nameHolder }) do
    table.insert(switchSteps, { "Translation", region, 1, 0, offset = -5 });
    table.insert(switchSteps, { "Translation", region, 2, SWITCH_TIME, smoothing = "OUT", offset = 5 });
  end
  for _, region in ipairs({ frame.icon, frame.nameHolder, frame.iconGlow }) do
    table.insert(switchSteps, { "Alpha", region, 1, 0, alpha = {0, 0} });
    table.insert(switchSteps, { "Alpha", region, 2, SWITCH_TIME, smoothing = "OUT", alpha = {0, 1} });
  end
  frame.switchAnim = ns.CreateAnimationGroup(frame, switchSteps);

  -- Stop before changing status opacity: native animation restoration can otherwise bring back
  -- the previous target's normal/compact text. Start only after the new layout is ready.
  local function StopSwitchAnim()
    frame.switchAnim:Stop();
    frame.icon:SetAlpha(1);
    frame.nameHolder:SetAlpha(1);
    frame.iconGlow:SetAlpha(1);
  end

  local function PlaySwitchAnim()
    frame.switchAnim:Play();
  end

  -- Only a target you can interact with gets its type's color. In range but unable (such as a herb without
  -- Herbalism) is UNABLE_COLOR. Out of range is OUT_OF_RANGE_COLOR, the frame fades to OUT_OF_RANGE_ALPHA,
  -- and a shared status line explains why the interaction is unavailable.
  -- A texture's vertex alpha and its own alpha are one value, so an Alpha animation overwrites the
  -- vertex alpha set here. The switch animation fades the icon glow in to alpha 1, which left it at full
  -- strength instead of 0.6 until the next repaint. The additive layers keep alpha 1
  -- and carry their strength in the color instead;
  -- with ADD blending, color times strength at alpha 1 draws the same as color at that alpha. The flash
  -- uses a separate holder for animation alpha, so repainting cannot change its pulse opacity.
  local ICON_GLOW_STRENGTH, LINE_GLOW_STRENGTH = 0.6, 0.35;
  local function PaintColor(r, g, b)
    r, g, b = Clamp(r, 0, 1), Clamp(g, 0, 1), Clamp(b, 0, 1);
    local s = ICON_GLOW_STRENGTH;
    frame.iconGlow:SetVertexColor(r * s, g * s, b * s, 1);
    frame.lineLow:SetVertexColor(r, g, b, 1);
    s = LINE_GLOW_STRENGTH;
    frame.lineLowGlow:SetVertexColor(r * s, g * s, b * s, 1);
    ns.styles.Paint(frame, r, g, b);
  end

  -- Sets the colors, the key label and the glow size from frame.colorKey and frame.outOfRange. With blend
  -- (the HUD is visible), the glow animates and the color blends over SWITCH_TIME from wherever it is
  -- now, also from the middle of a running blend.
  local colorTween = CreateTween();
  local function SetTypeColor(blend)
    hud.PaintKeyCap();
    hud.SetGlowRange(frame.outOfRange, blend);
    local to = { GetTypeColor(frame.colorKey, frame.outOfRange) };
    if not (blend and frame.rgb) then
      colorTween:Stop();
      frame.rgb = to;
      PaintColor(unpack(to));
      return;
    end
    local from = { unpack(frame.rgb) };
    colorTween:Play(SWITCH_TIME, function(t)
      for i = 1, 3 do frame.rgb[i] = from[i] + (to[i] - from[i]) * t; end
      PaintColor(unpack(frame.rgb));
    end);
  end

  local function UpdateColors() SetTypeColor(false); end

  -- Each style owns its appearance; targeting, columns and animations stay shared. A style with
  -- shadow set gets the soft shadow behind the text.
  local function ApplyTextures()
    frame.shadow:SetTexture(SHADOW);
    frame.shadow:SetVertexColor(0, 0, 0, SHADOW_ALPHA);
    frame.shadow:SetShown(ns.styles.Get().shadow == true);
    frame.iconGlow:SetTexture(GLOW);
    ns.styles.Apply(frame);
  end

  -- Stops the transition and the color blend when the HUD hides.
  function hud.ResetAppearance()
    frame.switchAnim:Stop();
    colorTween:Stop();
    frame.rgb = nil;
  end

  hud.SetTypeColor, hud.UpdateColors, hud.ApplyTextures = SetTypeColor, UpdateColors, ApplyTextures;
  hud.StopSwitchAnim, hud.PlaySwitchAnim = StopSwitchAnim, PlaySwitchAnim;
end
