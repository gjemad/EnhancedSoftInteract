local _, ns = ...;

local function Label(parent, text, fontObject)
  local label = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontHighlight");
  label:SetText(text);
  label:SetJustifyH("LEFT");
  return label;
end

----
--  Dropdowns: a button and a list made of the addon's own frames. Blizzard's dropdown menus register
--  with Forever's gamepad UI, and a menu or settings control built from addon data taints its
--  controller bindings, which blocks controller interaction after Settings closes. The art is the client's own dropdown art: Mainline (Forever, Retail), the
--  Classic set, or a plain border where neither exists.
--  Every frame on this page, the list included, is created with the page. Forever's gamepad
--  navigation hooks CreateFrame and rebuilds the open panel's navigation, so a frame created here
--  while Settings is open taints it, even when the player uses the mouse.
----
local DROPDOWN_ART = {
  { holder = "common-dropdown-textholder", holderOffsets = { -8, 7, 8, -9 }, arrow = "common-dropdown-a-button",
    arrowOffset = { 1, -3 }, list = "common-dropdown-bg", listOffsets = { -10, 3, 10, -3 } },
  { holder = "common-dropdown-classic-textholder", holderOffsets = { -9, 8, 8, -9 },
    arrow = "common-dropdown-classic-a-buttonDown", arrowOffset = { -1, 0 },
    list = "common-dropdown-classic-bg", listOffsets = { -3, 3, 3, -4 }, listFill = true },
};
local LIST_ROW_HEIGHT, LIST_MAX_ROWS, LIST_PADDING = 20, 14, 8;
-- An entry may have an icon (a texture path), shown ICON_SIZE units square before its text in the list
-- and on the button.
local ICON_SIZE, ICON_GAP = 18, 4;
local list;

local function DropdownArt()
  for _, art in ipairs(DROPDOWN_ART) do
    if C_Texture.GetAtlasInfo(art.holder) and C_Texture.GetAtlasInfo(art.arrow) then return art end
  end
end

-- The arrow's state atlas, when the client has it.
local function ArrowAtlas(art, state)
  local atlas = state and art.arrow .. "-" .. state;
  if atlas and C_Texture.GetAtlasInfo(atlas) then return atlas end
  return art.arrow;
end

local function FindEntry(data, value)
  for _, entry in ipairs(data.values()) do
    if entry.value == value then return entry end
  end
end

-- Shows the entry's icon, if any, and starts the text after it.
local function ShowIcon(icon, text, entry, left)
  icon:SetShown(entry and entry.icon ~= nil);
  if entry and entry.icon then icon:SetTexture(entry.icon); end
  text:SetPoint("LEFT", left + (icon:IsShown() and ICON_SIZE + ICON_GAP or 0), 0);
end

local function UpdateDropdownArrow(button)
  local art = button.art;
  if not art then return end
  local state;
  if not button:IsEnabled() then state = "disabled";
  elseif button.pressed then state = "pressed";
  elseif button.over then state = "hover";
  elseif list and list:IsShown() and list.owner == button then state = "open"; end
  button.Arrow:SetAtlas(ArrowAtlas(art, state), true);
end

local function CloseList()
  if list then list:Hide(); end
end

-- Fills the visible rows from the scroll offset, with a check on the selected value.
local function LayoutList()
  local owner = list.owner;
  local data, entries = owner.data, list.entries;
  local selected = data.get();
  for i, rowButton in ipairs(list.rows) do
    local entry = entries[list.offset + i];
    rowButton:SetShown(entry ~= nil and i <= list.visible);
    if entry then
      rowButton.entry = entry;
      rowButton.Text:SetText(entry.text);
      ShowIcon(rowButton.Icon, rowButton.Text, entry, 22);
      rowButton.Check:SetShown(entry.value == selected);
    end
  end
end

local function CreateList(parent)
  list = CreateFrame("Frame", nil, parent, DropdownArt() and nil or "BackdropTemplate");
  list:SetFrameStrata("FULLSCREEN_DIALOG");
  list:SetClampedToScreen(true);
  list:EnableMouse(true);
  list:EnableMouseWheel(true);
  list:Hide();
  local art = DropdownArt();
  if art then
    local background = list:CreateTexture(nil, "BACKGROUND");
    background:SetAtlas(art.list);
    background:SetPoint("TOPLEFT", art.listOffsets[1], art.listOffsets[2]);
    background:SetPoint("BOTTOMRIGHT", art.listOffsets[3], art.listOffsets[4]);
    if art.listFill then
      local fill = list:CreateTexture(nil, "BACKGROUND", nil, 1);
      fill:SetColorTexture(0, 0, 0, 0.8);
      fill:SetPoint("TOPLEFT", background, "TOPLEFT", 6, -6);
      fill:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", -6, 6);
    end
  else
    list:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8X8]], edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
      edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
    list:SetBackdropColor(0, 0, 0, 0.9);
    list:SetBackdropBorderColor(0.6, 0.6, 0.6, 1);
  end
  -- A click anywhere outside the list closes it.
  list.catcher = CreateFrame("Button", nil, parent);
  list.catcher:SetFrameStrata("FULLSCREEN");
  list.catcher:SetAllPoints(UIParent);
  list.catcher:SetScript("OnClick", CloseList);
  list.catcher:Hide();
  list.rows = {};
  for i = 1, LIST_MAX_ROWS do
    local rowButton = CreateFrame("Button", nil, list);
    rowButton:SetHeight(LIST_ROW_HEIGHT);
    rowButton:SetPoint("TOPLEFT", LIST_PADDING, -LIST_PADDING - (i - 1) * LIST_ROW_HEIGHT);
    rowButton:SetPoint("TOPRIGHT", -LIST_PADDING, -LIST_PADDING - (i - 1) * LIST_ROW_HEIGHT);
    local highlight = rowButton:CreateTexture(nil, "HIGHLIGHT");
    highlight:SetTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]]);
    highlight:SetBlendMode("ADD");
    highlight:SetAlpha(0.4);
    highlight:SetAllPoints();
    rowButton.Check = rowButton:CreateTexture(nil, "ARTWORK");
    rowButton.Check:SetTexture([[Interface\Buttons\UI-CheckBox-Check]]);
    rowButton.Check:SetSize(16, 16);
    rowButton.Check:SetPoint("LEFT", 2, 0);
    rowButton.Icon = rowButton:CreateTexture(nil, "ARTWORK");
    rowButton.Icon:SetSize(ICON_SIZE, ICON_SIZE);
    rowButton.Icon:SetPoint("LEFT", 22, 0);
    rowButton.Icon:Hide();
    rowButton.Text = Label(rowButton, "", "GameFontHighlight");
    rowButton.Text:SetPoint("LEFT", 22, 0);
    rowButton.Text:SetPoint("RIGHT", -4, 0);
    rowButton.Text:SetWordWrap(false);
    rowButton:SetScript("OnClick", function(self)
      local data = list.owner.data;
      CloseList();
      data.set(nil, self.entry.value);
      ns.RefreshSettings();
    end);
    list.rows[i] = rowButton;
  end
  list:SetScript("OnMouseWheel", function(_, delta)
    list.offset = math.max(0, math.min(#list.entries - list.visible, list.offset - delta));
    LayoutList();
  end);
  list:SetScript("OnHide", function()
    list.catcher:Hide();
    local owner = list.owner;
    if owner then UpdateDropdownArrow(owner); end
  end);
  ns.settingsDropdownList = list; --for the test tools
end

local function OpenList(button)
  CloseList();
  local data = button.data;
  list.owner, list.entries = button, data.values();
  list.visible = math.min(#list.entries, LIST_MAX_ROWS);
  -- Start with the selected value in view.
  local selected = data.get();
  local selectedIndex = 1;
  for i, entry in ipairs(list.entries) do if entry.value == selected then selectedIndex = i; break end end
  list.offset = math.max(0, math.min(#list.entries - list.visible, selectedIndex - math.ceil(list.visible / 2)));
  local width = button:GetWidth();
  for _, entry in ipairs(list.entries) do
    list.rows[1].Text:SetText(entry.text);
    local icon = entry.icon and ICON_SIZE + ICON_GAP or 0;
    width = math.max(width, list.rows[1].Text:GetStringWidth() + icon + 26 + LIST_PADDING * 2);
  end
  list:SetSize(width, list.visible * LIST_ROW_HEIGHT + LIST_PADDING * 2);
  list:ClearAllPoints();
  list:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2);
  LayoutList();
  list.catcher:Show();
  list:Show();
  UpdateDropdownArrow(button);
end

local function CreateDropdown(row, data)
  local button = CreateFrame("Button", nil, row, DropdownArt() and nil or "BackdropTemplate");
  button.data = data;
  local art = DropdownArt();
  button.art = art;
  if art then
    local holder = button:CreateTexture(nil, "BACKGROUND");
    holder:SetAtlas(art.holder);
    holder:SetPoint("TOPLEFT", art.holderOffsets[1], art.holderOffsets[2]);
    holder:SetPoint("BOTTOMRIGHT", art.holderOffsets[3], art.holderOffsets[4]);
    button.Arrow = button:CreateTexture(nil, "OVERLAY");
    button.Arrow:SetPoint("RIGHT", art.arrowOffset[1], art.arrowOffset[2]);
  else
    button:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8X8]], edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
      edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
    button:SetBackdropColor(0, 0, 0, 0.6);
    button:SetBackdropBorderColor(0.6, 0.6, 0.6, 1);
    button.Arrow = Label(button, "v", "GameFontHighlight");
    button.Arrow:SetPoint("RIGHT", -8, 0);
  end
  button.Icon = button:CreateTexture(nil, "ARTWORK");
  button.Icon:SetSize(ICON_SIZE, ICON_SIZE);
  button.Icon:SetPoint("LEFT", 8, 0);
  button.Icon:Hide();
  button.Text = Label(button, "", "GameFontHighlight");
  button.Text:SetPoint("LEFT", 8, 0);
  button.Text:SetPoint("RIGHT", button.Arrow, "LEFT", -4, 0);
  button.Text:SetWordWrap(false);
  button:SetScript("OnClick", function(self)
    if list and list:IsShown() and list.owner == self then CloseList(); else OpenList(self); end
  end);
  button:SetScript("OnMouseDown", function(self) self.pressed = true; UpdateDropdownArrow(self); end);
  button:SetScript("OnMouseUp", function(self) self.pressed = false; UpdateDropdownArrow(self); end);
  -- Hover art; call after the row's tooltip handlers are set, which replace earlier scripts.
  function button.HookHover(self)
    self:HookScript("OnEnter", function() self.over = true; UpdateDropdownArrow(self); end);
    self:HookScript("OnLeave", function() self.over = false; UpdateDropdownArrow(self); end);
  end
  -- Shows the chosen value and the enabled state; an open list follows the new value.
  function button.Refresh(self)
    local value = data.get();
    local entry = FindEntry(data, value);
    self.Text:SetText(entry and entry.text or tostring(value));
    ShowIcon(self.Icon, self.Text, entry, 8);
    local shade = self:IsEnabled() and 1 or 0.5;
    self.Text:SetTextColor(shade, shade, shade);
    self.Icon:SetDesaturated(not self:IsEnabled());
    self.Icon:SetAlpha(shade);
    if not self:IsEnabled() and list and list.owner == self then CloseList(); end
    if list and list:IsShown() and list.owner == self then LayoutList(); end
    UpdateDropdownArrow(self);
  end
  UpdateDropdownArrow(button);
  return button;
end

-- CreateList(parent) builds the one shared list when the page is built, Create(row, data) a dropdown
-- button, and Close() hides the list.
ns.SettingsDropdown = { Create = CreateDropdown, CreateList = CreateList, Close = CloseList };
