local _, ns = ...;
local issecretvalue = ns.issecretvalue;
local frame = ns.frame;

----
--  Debug log: every soft target event becomes a page with what the game sent and what the HUD did with
--  it. /esi debug opens a window that pages through them like BugSack, and Copy highlights the text so
--  Ctrl+C copies it. The log keeps the last MAX_PAGES events of this session.
----
local MAX_PAGES = 100;
local pages = {};
local eventCount, lastGUID = 0, nil;

-- Secret values (names and GUIDs in combat or instances) become "<secret>". Only tostring, concatenation
-- and string.format touch them, which secrets allow, so no page holds a secret.
local function Safe(v)
  if issecretvalue(v) then return "<secret>" end
  return tostring(v);
end

local window;
local ShowPage;

function ns.DebugSoftTarget(oldGUID, newGUID, hasCursor, resolvedKey, iconKey, talkBadge, outOfRange)
  eventCount = eventCount + 1;
  local same = "unknown";
  if not issecretvalue(newGUID) then
    same = (newGUID == lastGUID) and "yes (repeat event)" or "no";
    lastGUID = newGUID;
  end
  local unit = "softinteract";
  local r, g, b = ns.GetTypeColor(iconKey, outOfRange);
  local hasColor = outOfRange or ns.IsUnableKey(iconKey) or ns.typeColors[iconKey];
  local keys = { GetBindingKey("INTERACTTARGET") };
  local cap = frame.keyCap;
  local name = Safe(UnitName(unit));
  local lines = {
    ("#%d  %s  %s"):format(eventCount, date("%H:%M:%S"), name),
    ("event: old=%s new=%s sameTarget=%s source=%s"):format(Safe(oldGUID), Safe(newGUID), same,
      frame.fromRangeCheck and "range check" or "game event"),
    ("unit: name=%s player=%s object=%s interactable=%s inRange=%s attackable=%s"):format(
      name, Safe(UnitIsPlayer(unit)), Safe(UnitIsGameObject and UnitIsGameObject(unit)),
      Safe(UnitIsInteractable and UnitIsInteractable(unit)), Safe(UnitIsInInteractRange and UnitIsInInteractRange(unit)),
      Safe(UnitCanAttack("player", unit))),
    ("icon: hasCursor=%s source=%s resolved=%s key=%s color=%.2f,%.2f,%.2f%s talkBadge=%s nudge=%d,%d outOfRange=%s"):format(
      tostring(hasCursor), Safe(frame.iconSource), resolvedKey, iconKey, r, g, b, hasColor and "" or " (default, no entry)",
      tostring(talkBadge and true or false), frame.iconNudgeX or 0, frame.iconNudgeY or 0, tostring(outOfRange)),
    ("key: bindings=%s gamepadActive=%s gamepadUI=%s glyph=%s"):format(
      #keys > 0 and table.concat(keys, ",") or "none", tostring(ns.gamepadActive),
      tostring(ns.IsGamepadUI and ns.IsGamepadUI() or false),
      tostring(ns.GamepadInteractGlyph and ns.GamepadInteractGlyph())),
    ("layout: width=%s nameColumn=%s height=%s key=%s keyCap=%s"):format(
      ("%.0f"):format(frame.boxWidth or 0), ("%.0f"):format(frame.nameWidth or 0), tostring(EnhancedSoftInteractDB.hudHeight),
      cap:IsShown() and Safe(cap.text:GetText()) or "hidden",
      cap:IsShown() and ("%.0fx%.0f"):format(cap.capWidth or 0, cap.capHeight or 0) or "-"),
  };
  local onNewest = window and window.page == #pages;
  table.insert(pages, table.concat(lines, "\n"));
  local dropped = #pages > MAX_PAGES;
  if dropped then table.remove(pages, 1); end
  -- An open window on the newest page follows new events; on an older page it stays on that event. While
  -- text is selected for copying, the window waits until the next page change.
  if window and window:IsShown() and not window.text:HasFocus() then
    ShowPage(onNewest and #pages or window.page - (dropped and 1 or 0));
  end
end

----
--  The window, built the first time /esi debug opens it.
----
local function CreateWindow()
  local w = CreateFrame("Frame", "EnhancedSoftInteractDebug", UIParent, "PortraitFrameTemplate");
  w:Hide();
  w:SetSize(720, 300);
  w:SetPoint("CENTER");
  w:SetFrameStrata("DIALOG");
  w:SetToplevel(true);
  w:SetMovable(true);
  w:EnableMouse(true);
  w:RegisterForDrag("LeftButton");
  w:SetClampedToScreen(true);
  w:SetScript("OnDragStart", w.StartMoving);
  w:SetScript("OnDragStop", w.StopMovingOrSizing);
  w:SetBorder("HeldBagLayout");
  -- The bag border's portrait ring is smaller than the template's default, so the icon gets the size and
  -- place Blizzard's bag frames use (36 at -4, 1), moved against the cog art's off-center body.
  local PORTRAIT_SIZE = 36;
  local offset = ns.iconArtOffsets["cursor interact"] or {0, 0};
  local function Round(v) return math.floor(v + 0.5) end
  w:SetPortraitAtlasRaw("Crosshair_interact_64");
  w:SetPortraitTextureSizeAndOffset(PORTRAIT_SIZE, -4 - Round(offset[1] * PORTRAIT_SIZE / 64),
    1 + Round(offset[2] * PORTRAIT_SIZE / 64));
  w:SetTitle("Enhanced Soft Interact Debug");
  w:SetScript("OnShow", function() PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN); end);
  w:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE); end);
  table.insert(UISpecialFrames, w:GetName()); --Esc closes it

  w.count = w.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal");
  w.count:SetPoint("RIGHT", w.CloseButton, "LEFT", -5, 0);
  w.count:SetJustifyH("RIGHT");
  w.count:SetTextColor(1, 1, 1);

  local function Button(text, width)
    local b = CreateFrame("Button", nil, w, "SharedButtonTemplate");
    b:SetSize(width, 26);
    b:SetText(text);
    return b;
  end
  w.prev = Button("< Previous", 140);
  w.prev:SetPoint("BOTTOMLEFT", 8, 8);
  w.next = Button("Next >", 140);
  w.next:SetPoint("BOTTOMRIGHT", -8, 8);
  w.copy = Button("Copy", 110);
  w.copyAll = Button("Copy All", 110);
  w.clear = Button("Clear", 110);
  w.copyAll:SetPoint("BOTTOM", 0, 8);
  w.copy:SetPoint("RIGHT", w.copyAll, "LEFT", -6, 0);
  w.clear:SetPoint("LEFT", w.copyAll, "RIGHT", 6, 0);

  -- A read-only edit box, so the text can be selected and copied. Typing puts the shown text back.
  local scroll = CreateFrame("ScrollFrame", nil, w, "ScrollFrameTemplate");
  scroll:SetPoint("TOPLEFT", 12, -44); --below the portrait ring
  scroll:SetPoint("BOTTOMRIGHT", -30, 40);
  local text = CreateFrame("EditBox", nil, scroll);
  text:SetMultiLine(true);
  text:SetAutoFocus(false);
  text:SetMaxLetters(0);
  text:SetFontObject("GameFontHighlightSmall");
  text:SetWidth(scroll:GetWidth());
  text:SetScript("OnEscapePressed", text.ClearFocus);
  text:SetScript("OnTextChanged", function(self, userInput)
    if userInput then self:SetText(w.shownText or ""); self:HighlightText(); end
  end);
  scroll:SetScrollChild(text);
  scroll:SetScript("OnSizeChanged", function(self, width) text:SetWidth(width); end);
  w.text = text;

  local function Show(textToShow, countText)
    w.shownText = textToShow;
    text:SetText(textToShow);
    text:SetCursorPosition(0);
    text:ClearFocus();
    w.count:SetText(countText);
  end

  function ShowPage(index)
    if #pages == 0 then
      w.page = 0;
      Show("No soft target events yet. Look at something you can interact with.", "0 / 0");
    else
      w.page = math.max(1, math.min(index, #pages));
      Show(pages[w.page], ("%d / %d"):format(w.page, #pages));
    end
    w.prev:SetEnabled(w.page > 1);
    w.next:SetEnabled(w.page < #pages);
    w.copy:SetEnabled(#pages > 0);
    w.copyAll:SetEnabled(#pages > 0);
    w.clear:SetEnabled(#pages > 0);
  end

  -- Addons can't write to the clipboard, so Copy selects the text and Ctrl+C does the rest.
  local function SelectForCopy(countText)
    w.count:SetText(countText .. "  |cff20ff20Ctrl+C to copy|r");
    text:SetFocus();
    text:HighlightText();
  end

  -- Shift-click jumps to the first or last page.
  w.prev:SetScript("OnClick", function() ShowPage(IsShiftKeyDown() and 1 or w.page - 1); end);
  w.next:SetScript("OnClick", function() ShowPage(IsShiftKeyDown() and #pages or w.page + 1); end);
  w.copy:SetScript("OnClick", function()
    ShowPage(w.page);
    SelectForCopy(w.count:GetText());
  end);
  w.copyAll:SetScript("OnClick", function()
    Show(table.concat(pages, "\n\n"), ("all %d"):format(#pages));
    SelectForCopy(w.count:GetText());
  end);
  w.clear:SetScript("OnClick", function()
    wipe(pages);
    ShowPage(0);
  end);
  return w;
end

ns.slashCommands.debug = function()
  window = window or CreateWindow();
  if window:IsShown() then
    window:Hide();
  else
    window:Show();
    ShowPage(#pages);
  end
end
