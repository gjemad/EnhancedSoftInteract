local ADDON_NAME, ns = ...;
local ATLAS = "LevelUp-Bar-White";
local BAR_TEXTURE = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\LevelUpBar]];
local FLASH_ATLAS = "AftLevelup-GlowLine";
ns.styles.Register("levelup", {
  name = "Level-Up Line", shadow = true,
  sizes = {
    small = { fontSize = 14, iconSize = 26, keyHeight = 22.75, glyphHeight = 22.75, keyFontSize = 14.5, inputScale = 0.875, nameMinWidth = 90, nameMaxWidth = 220, hudHeight = 44 },
    normal = { fontSize = 16, iconSize = 30, keyHeight = 26, glyphHeight = 26, keyFontSize = 17, inputScale = 1, nameMinWidth = 100, nameMaxWidth = 250, hudHeight = 50 },
    large = { fontSize = 20, iconSize = 38, keyHeight = 32.5, glyphHeight = 32.5, keyFontSize = 21, inputScale = 1.25, nameMinWidth = 125, nameMaxWidth = 310, hudHeight = 62 },
  },
  -- The native glow line uncovers along the cast (user choice: current bar with C, Glow reveal), and
  -- the start and end markers are wider, taller and in the full object color so they read clearly.
  -- Both stay in the object color: whiter versions washed out in game.
  castBar = { height = 1.2, offset = 6.5, centerBright = true, success = "afterglow", interrupt = "redGlowLine",
    reveal = { atlas = FLASH_ATLAS, height = 14, strength = 0.7 }, endWidth = 1.6, endHeight = 7, endBright = 0.1,
    glow = { tail = 16, tailHeight = 3.6, tailAlpha = 0.5, haloWidth = 7, haloHeight = 9, haloAlpha = 0.4,
      coreWidth = 3, coreHeight = 5.5, coreAlpha = 0.82, needle = true, lineTexture = BAR_TEXTURE } },
  layers = { iconGlow = true, lineLowGlow = true, lineLow = true, lineHigh = true },
  Create = function(frame)
    frame.levelupBloom = ns.styles.CreateBloom(frame);
    frame.levelupNameGlow = ns.styles.CreatePulseGlow(frame);
    return { frame.levelupBloom[1], frame.levelupBloom[2], frame.levelupNameGlow };
  end,
  Apply = function(frame)
    local hasAtlas = C_Texture.GetAtlasInfo(ATLAS) ~= nil;
    frame.lineStrokeShift = 3 / 7;
    for _, line in ipairs({ frame.lineLow, frame.lineLowGlow, frame.lineHigh }) do
      if hasAtlas then line:SetAtlas(ATLAS);
      else
        -- Era lacks this atlas. The bundled crop preserves its 418x7 artwork and alignment.
        line:SetTexture(BAR_TEXTURE);
        line:SetTexCoord(0, 418 / 512, 0, 7 / 8);
      end
    end
    frame.hasLineFlash = C_Texture.GetAtlasInfo(FLASH_ATLAS) ~= nil;
    if frame.hasLineFlash then
      frame.flash:SetAtlas(FLASH_ATLAS);
      -- Remove the artwork's gold so the flash follows the target's color.
      frame.flash:SetDesaturated(true);
    end
  end,
  Layout = function(frame, db)
    local scale = ns.styles.Size(db).inputScale;
    local y = -ns.styles.LineY(frame, db, 6.5);
    local function Line(tex, inset, offsetY, height)
      offsetY = offsetY + height * frame.lineStrokeShift;
      tex:ClearAllPoints();
      tex:SetPoint("LEFT", frame.box, "LEFT", inset, offsetY);
      tex:SetPoint("RIGHT", frame.box, "RIGHT", -inset, offsetY);
      tex:SetHeight(height);
    end
    Line(frame.lineLow, -5 * scale, -y, 4 * scale);
    Line(frame.lineLowGlow, -5 * scale, -y, 10 * scale);
    Line(frame.lineHigh, 20 * scale, y, 3 * scale);
    ns.styles.BloomSegment(frame, frame.levelupBloom[1], -5 * scale, frame.boxWidth + 10 * scale, -y);
    ns.styles.BloomSegment(frame, frame.levelupBloom[2], 20 * scale, frame.boxWidth - 40 * scale, y);
    ns.styles.NameBloom(frame, frame.levelupNameGlow, db);
    if frame.hasLineFlash then
      frame.flash:ClearAllPoints();
      frame.flash:SetPoint("LEFT", frame.box, "LEFT", -5 * scale, -y);
      frame.flash:SetPoint("RIGHT", frame.box, "RIGHT", 5 * scale, -y);
      frame.flash:SetHeight(8 * scale);
    end
  end,
  Paint = function(frame, r, g, b)
    frame.levelupBloom[1]:SetVertexColor(r * 0.5, g * 0.5, b * 0.5, frame.levelupBloom[1]:GetAlpha());
    frame.levelupBloom[2]:SetVertexColor(r * 0.3, g * 0.3, b * 0.3, frame.levelupBloom[2]:GetAlpha());
    frame.levelupNameGlow:SetVertexColor(r * 0.22, g * 0.22, b * 0.22, frame.levelupNameGlow:GetAlpha());
  end,
});
