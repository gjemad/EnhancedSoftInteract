local _, ns = ...;
local LibEditMode = LibStub("LibEditMode", true);

----
--  The Edit Mode preview: a window docked beside the HUD's Edit Mode settings dialog, with a second HUD
--  (ns.AddHUD) that shows the same sample as the real one. Clicking the HUD in it shows the next sample
--  and plays the interact animation. The minimize button folds the window into a tab on the dialog's
--  edge, and clicking the tab opens it again; EnhancedSoftInteractDB.previewMinimized remembers which.
--  Both dock on the side of the dialog that faces the middle of the screen.
----
local WINDOW_WIDTH, WINDOW_HEIGHT = 380, 170; --the narrowest the window gets; a wide HUD widens it
local CONTENT_INSET = 14; --between the window's edge and the clipped area that holds the HUD
local SHADOW_REACH = ns.HUD_SHADOW_PADDING.x; --how far the HUD's shadow reaches past its box (SHADOW_PAD_X in the core)
local TAB_OVERLAP = 4; --the tab tucks this far under the dialog's border, plus one screen pixel (Dock)

local window, tab;

local function Dialog() return LibEditMode.internal and LibEditMode.internal.dialog end

-- Sets a side tab texture. The art points left, toward a dialog on the tab's left (Blizzard's side tabs
-- sit on a panel's right edge), so a tab on the dialog's left edge gets it mirrored. The coordinates come
-- from the atlas each time: re-setting the same atlas keeps the texture's old coordinates, so swapping
-- those flipped the art on every call.
local function SetTabAtlas(tex, atlas, mirrored)
  local info = C_Texture.GetAtlasInfo(atlas);
  if not (info and info.file) then tex:SetAtlas(atlas, true); return end
  local left, right = info.leftTexCoord, info.rightTexCoord;
  if mirrored then left, right = right, left; end
  tex:SetTexture(info.file);
  tex:SetSize(info.width, info.height);
  tex:SetTexCoord(left, right, info.topTexCoord, info.bottomTexCoord);
end

-- Whether the dialog's center is on the right half of the screen, in screen pixels (the dialog and
-- UIParent can have different scales). nil while the dialog has no position.
local function DialogOnRightHalf(dialog)
  local x = dialog:GetCenter();
  if not x then return nil end
  return x * dialog:GetEffectiveScale() > UIParent:GetWidth() * UIParent:GetEffectiveScale() / 2;
end

-- Shows the window or the tab while the dialog shows the HUD's settings, on the side of the dialog that
-- faces the middle of the screen, where there is room. Only pickSide reads the dialog's position. Right
-- after a drag the dialog still reports its old rect, with its left edge at 0 (seen in game), so the side
-- comes from a second call on the next frame.
local onLeft = true;
local function Dock(pickSide)
  local dialog = Dialog();
  local forHUD = dialog and dialog:IsShown() and dialog.selection and dialog.selection.parent == ns.frame;
  local minimized = EnhancedSoftInteractDB.previewMinimized;
  window:SetShown(forHUD and not minimized);
  tab:SetShown(forHUD and minimized);
  if not forHUD then return end
  if pickSide then
    local onRightHalf = DialogOnRightHalf(dialog);
    if onRightHalf ~= nil then onLeft = onRightHalf; end
  end
  window:ClearAllPoints();
  tab:ClearAllPoints();
  local overlap = TAB_OVERLAP + 1 / tab:GetEffectiveScale(); --at TAB_OVERLAP alone a 1px gap showed in game
  if onLeft then
    window:SetPoint("TOPRIGHT", dialog, "TOPLEFT");
    tab:SetPoint("TOPRIGHT", dialog, "TOPLEFT", overlap, -40);
  else
    window:SetPoint("TOPLEFT", dialog, "TOPRIGHT");
    tab:SetPoint("TOPLEFT", dialog, "TOPRIGHT", -overlap, -40);
  end
  SetTabAtlas(tab.background, "common-sidetab", onLeft);
  SetTabAtlas(tab.highlight, "common-sidetab-hover", onLeft);
  tab.icon:SetPoint("CENTER", onLeft and 3 or -3, 0); --off the art's padding, on its right side unmirrored (Blizzard: -3)
end

local function SetMinimized(minimized)
  EnhancedSoftInteractDB.previewMinimized = minimized;
  PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
  Dock();
end

local function CreateWindow(dialog)
  window = CreateFrame("Frame", nil, UIParent);
  window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT);
  window:SetFrameStrata(dialog:GetFrameStrata());
  window:SetFrameLevel(dialog:GetFrameLevel());
  window:EnableMouse(true); --clicks on the window don't reach the world behind it
  window:Hide();
  CreateFrame("Frame", nil, window, "DialogBorderTranslucentTemplate"); --the dialog's own border

  local title = window:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge");
  title:SetPoint("TOP", 0, -15);
  title:SetText("Preview");

  local minimize = CreateFrame("Button", nil, window);
  minimize:SetSize(24, 24);
  minimize:SetPoint("TOPRIGHT", -6, -6);
  minimize:SetNormalAtlas("RedButton-Condense");
  minimize:SetPushedAtlas("RedButton-Condense-Pressed");
  minimize:SetHighlightAtlas("RedButton-Highlight", "ADD");
  minimize:SetScript("OnClick", function() SetMinimized(true); end);

  local hint = window:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall");
  hint:SetPoint("BOTTOM", 0, 14);
  hint:SetText("Click the preview for the next sample.");

  -- The HUD sits in a clipped area, which keeps its shadow inside the window.
  local content = CreateFrame("Frame", nil, window);
  content:SetPoint("TOPLEFT", CONTENT_INSET, -40);
  content:SetPoint("BOTTOMRIGHT", -CONTENT_INSET, 32);
  content:SetClipsChildren(true);
  content:EnableMouse(true);
  content:SetScript("OnMouseUp", function(_, button)
    if button ~= "LeftButton" then return end
    ns.ShowNextEditModeSample();
    if EnhancedSoftInteractDB.animationsEnabled then ns.PlayInteractPulse(); end
  end);

  -- The window widens to fit the HUD at its widest, with the name column at Name Max Width, so the
  -- sample's own name length doesn't resize it on every click.
  local hudFrame = CreateFrame("Frame", nil, content);
  hudFrame:SetSize(200, 40);
  hudFrame:SetPoint("CENTER");
  hudFrame:Hide();
  hudFrame.onLayout = function(width)
    local db = EnhancedSoftInteractDB;
    local widest = width - hudFrame.nameWidth + math.max(db.nameMinWidth, db.nameMaxWidth);
    window:SetWidth(math.max(WINDOW_WIDTH, widest + 2 * (SHADOW_REACH + CONTENT_INSET)));
  end
  ns.AddHUD(hudFrame);
end

-- The tab's icon is the Group Finder eye, from the same flipbooks as the queue eye
-- (Blizzard_LFGUtil\LFGEye.xml): OPENING opens it, then SEARCHING loops while it looks around. Each
-- flipbook is a grid of frames read left to right, top to bottom. The eye opens whenever the tab appears,
-- looks around while the mouse is over the tab, and otherwise rests on the opening's last frame.
local OPENING = { atlas = "groupfinder-eye-flipbook-initial", rows = 5, columns = 11, frames = 52, time = 1.5 };
local SEARCHING = { atlas = "groupfinder-eye-flipbook-searching", rows = 8, columns = 11, frames = 80, time = 2 };
local EYE_SIZE = 36;

-- Shows one frame of a flipbook (1 is the first) on a texture.
local function SetEyeFrame(tex, book, index)
  local info = C_Texture.GetAtlasInfo(book.atlas);
  if not (info and info.file) then tex:SetAtlas(book.atlas); return end
  local w = (info.rightTexCoord - info.leftTexCoord) / book.columns;
  local h = (info.bottomTexCoord - info.topTexCoord) / book.rows;
  local column, row = (index - 1) % book.columns, math.floor((index - 1) / book.columns);
  local left, top = info.leftTexCoord + column * w, info.topTexCoord + row * h;
  tex:SetTexture(info.file);
  tex:SetTexCoord(left, left + w, top, top + h);
end

-- A texture on button, over the resting eye, that plays a flipbook and hides again when it ends or stops.
local function CreateEyeAnimation(button, rest, book, looping)
  local tex = button:CreateTexture(nil, "ARTWORK", nil, 1);
  tex:SetAtlas(book.atlas);
  tex:SetAllPoints(rest);
  tex:Hide();
  local group = button:CreateAnimationGroup();
  group:SetLooping(looping and "REPEAT" or "NONE");
  local flipBook = group:CreateAnimation("FlipBook");
  flipBook:SetTarget(tex);
  flipBook:SetFlipBookRows(book.rows);
  flipBook:SetFlipBookColumns(book.columns);
  flipBook:SetFlipBookFrames(book.frames);
  flipBook:SetDuration(book.time);
  local function Done() tex:Hide(); rest:Show(); end
  group:SetScript("OnPlay", function() rest:Hide(); tex:Show(); end);
  group:SetScript("OnFinished", Done);
  group:SetScript("OnStop", Done);
  return group;
end

-- The tab is Blizzard's side tab art (as on the collections and social frames) with the eye.
local function CreateTab(dialog)
  tab = CreateFrame("Button", nil, UIParent);
  local info = C_Texture.GetAtlasInfo("common-sidetab");
  tab:SetSize(info and info.width or 45, info and info.height or 60);
  tab:SetFrameStrata(dialog:GetFrameStrata());
  tab:SetFrameLevel(math.max(0, dialog:GetFrameLevel() - 1)); --under the dialog's border
  tab:Hide();
  tab.background = tab:CreateTexture(nil, "BACKGROUND");
  tab.background:SetPoint("CENTER");
  tab.icon = tab:CreateTexture(nil, "ARTWORK");
  tab.icon:SetSize(EYE_SIZE, EYE_SIZE);
  SetEyeFrame(tab.icon, OPENING, OPENING.frames);
  tab.highlight = tab:CreateTexture(nil, "HIGHLIGHT");
  tab.highlight:SetPoint("CENTER");
  local opening = CreateEyeAnimation(tab, tab.icon, OPENING, false);
  local searching = CreateEyeAnimation(tab, tab.icon, SEARCHING, true);

  tab:SetScript("OnShow", function()
    searching:Stop();
    opening:Play();
  end);
  tab:SetScript("OnClick", function() SetMinimized(false); end);
  tab:SetScript("OnEnter", function(self)
    opening:Stop();
    searching:Play();
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    GameTooltip_SetTitle(GameTooltip, "Show Preview");
    GameTooltip:Show();
  end);
  tab:SetScript("OnLeave", function()
    searching:Stop();
    GameTooltip:Hide();
  end);
end

-- Runs after Feat\EditMode.lua registered the HUD, which creates LibEditMode's dialog.
table.insert(ns.onLoad, function()
  local dialog = LibEditMode and Dialog();
  if not dialog then return end
  CreateWindow(dialog);
  CreateTab(dialog);
  -- The side comes from the next frame, once the dialog's new size and position are settled.
  local function PickSideNextFrame() C_Timer.After(0, function() Dock(true); end); end
  hooksecurefunc(dialog, "Update", function() Dock(); PickSideNextFrame(); end); --a frame's settings opened in the dialog
  dialog:HookScript("OnHide", function() Dock(); end);
  dialog:HookScript("OnDragStop", PickSideNextFrame); --the dialog moved, maybe to the other half of the screen
end);
