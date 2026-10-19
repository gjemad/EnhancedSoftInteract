local ADDON_NAME, ns = ...;
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
local panel, card;
local rows = {};
local ROW_HEIGHT = 36;
local SUB_OPTION_INDENT = 24;
local pageItems, pageContent, pageHeight = {};
local RefreshPreview;
ns.settingsRows = rows;

local function Label(parent, text, fontObject)
  local label = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontHighlight");
  label:SetText(text);
  label:SetJustifyH("LEFT");
  return label;
end

local function CreateCard()
  card = CreateFrame("GameTooltip", "EnhancedSoftInteractSettingsTooltip", UIParent, "GameTooltipTemplate");
  card:SetFrameStrata("TOOLTIP");
  card:SetClampedToScreen(true);
  card.NineSlice:DisableDrawLayer("BACKGROUND");
  card.background = card:CreateTexture(nil, "BACKGROUND", nil, -1);
  card.background:SetPoint("TOPLEFT", 3, -3);
  card.background:SetPoint("BOTTOMRIGHT", -3, 3);
  card.background:SetColorTexture(0, 0, 0, 1);
  card.background:SetAlpha(0.8);
  card:HookScript("OnShow", function(self)
    -- Native style setup can replace the center's atlas and vertex tint.
    -- Hide that texture and draw our own black fill under the native border.
    self.NineSlice.Center:Hide();
    self.NineSlice.Center:SetAlpha(0);
  end);
  card:Hide();
  ns.settingsCard = card;
end

local function ShowCard(owner, data)
  card:SetOwner(owner, "ANCHOR_NONE");
  card:ClearLines();
  card:SetText(data.name, 1, 0.82, 0, 1, true);
  local description = data.desc or "";
  if type(description) == "function" then description = description(); end
  card:AddLine(description, 1, 1, 1, true);
  card:ClearAllPoints();
  card:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", 0, 8);
  card:Show();
  card.NineSlice.Center:Hide();
  card.NineSlice.Center:SetAlpha(0);
end

local function Hover(frame, data, owner)
  local anchor = owner or frame;
  frame:SetScript("OnEnter", function()
    if anchor.highlight then anchor.highlight:Show(); end
    ShowCard(anchor, data);
  end);
  frame:SetScript("OnLeave", function()
    if anchor.highlight then anchor.highlight:Hide(); end
    card:Hide();
  end);
end

local function Changed(data, value)
  data.set(nil, value);
  ns.RefreshSettings();
end

local function DefaultValue(data)
  if type(data.default) == "function" then return data.default(); end
  return data.default;
end

----
--  Dropdowns: a button and a list made of the addon's own frames. Blizzard's dropdown menus register
--  with Forever's gamepad UI, and a menu or settings control built from addon data taints its
--  controller bindings, which blocked controller interaction after Settings closed (taint log and
--  scans, 2026-10-19). The art is the client's own dropdown art: Mainline (Forever, Retail), the
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

local function EntryText(data, value)
  for _, entry in ipairs(data.values()) do
    if entry.value == value then return entry.text end
  end
  return tostring(value);
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
      rowButton.Check:SetShown(entry.value == selected);
    end
  end
end

local function CreateList()
  list = CreateFrame("Frame", nil, panel, DropdownArt() and nil or "BackdropTemplate");
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
  list.catcher = CreateFrame("Button", nil, panel);
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
    rowButton.Text = Label(rowButton, "", "GameFontHighlight");
    rowButton.Text:SetPoint("LEFT", 22, 0);
    rowButton.Text:SetPoint("RIGHT", -4, 0);
    rowButton.Text:SetWordWrap(false);
    rowButton:SetScript("OnClick", function(self)
      local data = list.owner.data;
      CloseList();
      Changed(data, self.entry.value);
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
  ns.settingsDropdownList = list;
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
    width = math.max(width, list.rows[1].Text:GetStringWidth() + 26 + LIST_PADDING * 2);
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
    self.Text:SetText(EntryText(data, data.get()));
    local shade = self:IsEnabled() and 1 or 0.5;
    self.Text:SetTextColor(shade, shade, shade);
    if not self:IsEnabled() and list and list.owner == self then CloseList(); end
    if list and list:IsShown() and list.owner == self then LayoutList(); end
    UpdateDropdownArrow(self);
  end
  UpdateDropdownArrow(button);
  return button;
end

local function CreateRow(content, data, y)
  local row = CreateFrame("Frame", nil, content);
  row:SetPoint("TOPLEFT", 8, -y);
  row:SetPoint("TOPRIGHT", -8, -y);
  row:SetHeight(ROW_HEIGHT);
  row:EnableMouse(true);
  row.data = data;
  row.highlight = row:CreateTexture(nil, "BACKGROUND");
  row.highlight:SetTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]]);
  row.highlight:SetAllPoints();
  row.highlight:SetBlendMode("ADD");
  row.highlight:SetAlpha(0.15);
  row.highlight:Hide();
  Hover(row, data);
  -- Sub-options sit one checkbox width further in, under their parent option.
  row.indent = data.indent and SUB_OPTION_INDENT or 0;
  row.label = Label(row, data.name);
  row.label:SetPoint("LEFT", 32 + row.indent, 0);
  row.label:SetWidth(200);
  if data.kind == ns.SettingType.Checkbox then
    row.label:SetWidth(480 - row.indent);
    row.control = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate");
    row.control:SetSize(28, 28);
    row.control:SetPoint("LEFT", row.indent, 0);
    row.control:SetScript("OnClick", function(self) Changed(data, not not self:GetChecked()); end);
  elseif data.kind == ns.SettingType.Slider then
    row.control = CreateFrame("Slider", nil, row, "OptionsSliderTemplate");
    row.control:SetSize(160, 16);
    row.control:SetPoint("RIGHT", -64, 0);
    row.control:SetMinMaxValues(data.minValue, data.maxValue);
    row.control:SetValueStep(data.valueStep);
    row.control:SetObeyStepOnDrag(true);
    if row.control.Low then row.control.Low:Hide(); end
    if row.control.High then row.control.High:Hide(); end
    if row.control.Text then row.control.Text:Hide(); end
    row.value = Label(row, "", "GameFontHighlightSmall");
    row.value:SetPoint("RIGHT", -2, 0);
    row.control:SetScript("OnValueChanged", function(_, value)
      if row.refreshing then return end
      local stepped = math.floor(value / data.valueStep + 0.5) * data.valueStep;
      Changed(data, stepped);
    end);
  elseif data.kind == ns.SettingType.Dropdown then
    row.control = CreateDropdown(row, data);
    row.control:SetSize(224, 25);
    row.control:SetPoint("RIGHT", -8, 0);
  end
  if row.control then Hover(row.control, data, row); end
  if row.control and row.control.HookHover then row.control:HookHover(); end
  -- Blizzard's shop camera undo button (user choice), bundled so every client shows it. SettingsReset
  -- holds its default, hover, pressed and disabled art in 64-pixel cells, each 62 pixels inside a margin.
  row.reset = CreateFrame("Button", nil, row);
  row.reset:SetSize(22, 22);
  local function ResetState(column, line)
    local state = row.reset:CreateTexture();
    state:SetTexture(MEDIA .. "SettingsReset");
    state:SetTexCoord((column * 64 + 1) / 128, (column * 64 + 63) / 128, (line * 64 + 1) / 128, (line * 64 + 63) / 128);
    state:SetAllPoints();
    return state;
  end
  row.reset:SetNormalTexture(ResetState(0, 0));
  row.reset:SetHighlightTexture(ResetState(1, 0));
  row.reset:GetHighlightTexture():SetBlendMode("BLEND");
  row.reset:SetPushedTexture(ResetState(0, 1));
  row.reset:SetDisabledTexture(ResetState(1, 1));
  row.reset:SetScript("OnClick", function()
    card:Hide();
    Changed(data, DefaultValue(data));
  end);
  Hover(row.reset, { name = "Reset " .. data.name, desc = function()
    local value = DefaultValue(data);
    local text = data.formatter and data.formatter(value) or tostring(value);
    if type(value) == "boolean" then text = value and "On" or "Off"; end
    if data.values then
      for _, entry in ipairs(data.values()) do if entry.value == value then text = entry.text; break end end
    end
    return "Restores this option to its default: " .. text .. ".";
  end }, row);
  rows[#rows + 1] = row;
end

function ns.RefreshSettings()
  for _, row in ipairs(rows) do
    local data = row.data;
    row.settingsHidden = data.hidden and data.hidden() or false;
    row:SetShown(not row.settingsHidden);
    local disabled = data.disabled and data.disabled();
    row.refreshing = true;
    row.control:SetEnabled(not disabled);
    row.label:SetTextColor(disabled and 0.45 or 1, disabled and 0.45 or 1, disabled and 0.45 or 1);
    local value = data.get();
    row.reset:SetShown(value ~= DefaultValue(data));
    row.reset:SetEnabled(not disabled); --the button shows Blizzard's own disabled art
    local textWidth = math.min(row.label:GetStringWidth(), data.kind == ns.SettingType.Checkbox and 480 - row.indent or 200);
    row.reset:SetPoint("LEFT", row, "LEFT", math.max(238, 32 + row.indent + textWidth + 8), 0);
    if data.kind == ns.SettingType.Checkbox then
      row.control:SetChecked(value);
    elseif data.kind == ns.SettingType.Slider then
      row.control:SetValue(value);
      row.value:SetText(data.formatter and data.formatter(value) or tostring(value));
    elseif data.kind == ns.SettingType.Dropdown then
      row.control:Refresh();
    end
    row.refreshing = false;
  end
  local removed = 0;
  for _, item in ipairs(pageItems) do
    item.frame:SetPoint("TOPLEFT", item.inset, -item.y + removed);
    item.frame:SetPoint("TOPRIGHT", -item.inset, -item.y + removed);
    if item.frame.settingsHidden then removed = removed + ROW_HEIGHT; end
  end
  if pageContent then pageContent:SetHeight(pageHeight - removed); end
  if RefreshPreview then RefreshPreview(); end
end

-- Checkboxes under the preview show states a sample can't reach on its own. They change only the
-- preview and are not saved. Animate plays the interaction every few seconds, or loops the cast.
local PREVIEW_TOGGLES = {
  { key = "animate", name = "Animate", desc = "Plays the interaction every few seconds.\n\nWith Cast bar checked, plays a finished cast and an interrupted one." },
  { key = "range", name = "Move closer", desc = "Shows the target as out of range." },
  { key = "requires", name = "Requires profession", desc = "Shows the missing profession message.\n\nOnly for herbs and ore." },
  { key = "cast", name = "Cast bar", desc = "Shows a cast bar on targets you gather or open.\n\nNot available out of range, with a missing profession, or when Enable Cast Bar is off." },
};
local PREVIEW_PULSE_EVERY = 3;

local function CreatePreviewControls(sample, nextSample, frame)
  local preview = sample.frame;
  local state = { animate = true, range = false, requires = false, cast = false };
  local current = {};
  local toggles = {};
  ns.previewToggles = toggles;
  local function Requirement()
    return state.requires and ns.RequirementText(current.cursor) or nil;
  end
  local function Blocked() return state.range or Requirement() ~= nil end
  local function Applicable(key)
    if key == "requires" then return ns.RequirementText(current.cursor) ~= nil end
    if key == "cast" then
      return EnhancedSoftInteractDB.castBarEnabled and ns.styles.Get().castBar ~= nil
        and ns.SampleCastable(current.name, current.cursor) and not Blocked();
    end
    return true;
  end
  local function Casting() return state.cast and Applicable("cast") end
  RefreshPreview = function()
    if not current.name then return end
    local requirement = Requirement();
    sample.SetSampleState(Blocked() and "Unable" .. current.cursor or current.cursor, state.range, requirement);
    ns.CastBar.Preview(preview, Casting() and (state.animate and "loop" or "hold") or nil, sample.PlayInteractPulse);
    for key, box in pairs(toggles) do
      local enabled = Applicable(key);
      box:SetEnabled(enabled);
      box:SetChecked(state[key]);
      local shade = enabled and 0.75 or 0.4;
      box.label:SetTextColor(shade, shade, shade);
    end
  end
  local function Next()
    local name, _, _, cursor = nextSample();
    current.name, current.cursor = name, cursor;
    sample.ShowSample(name, cursor);
    RefreshPreview();
    if state.animate and not Blocked() and not Casting() then sample.PlayInteractPulse(); end
  end
  preview:EnableMouse(true);
  preview:SetScript("OnMouseUp", Next);
  -- Small, muted checkboxes along the bottom of the preview frame.
  local row = CreateFrame("Frame", nil, frame);
  row:SetPoint("BOTTOM", 0, 8);
  row:SetHeight(20);
  local x = 0;
  for _, data in ipairs(PREVIEW_TOGGLES) do
    local box = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate");
    box:SetSize(20, 20);
    box:SetPoint("LEFT", x, 0);
    box.label = Label(row, data.name, "GameFontHighlightSmall");
    box.label:SetPoint("LEFT", box, "RIGHT", 1, 0);
    box:SetScript("OnClick", function(self)
      state[data.key] = not not self:GetChecked();
      RefreshPreview();
    end);
    Hover(box, data);
    toggles[data.key] = box;
    x = x + 20 + 1 + math.ceil(box.label:GetStringWidth()) + 14;
  end
  row:SetWidth(x - 14);
  -- Pulses run only while the page shows, and only when no looping cast already plays them.
  local elapsedSince = 0;
  row:SetScript("OnUpdate", function(_, elapsed)
    if not state.animate or Blocked() or Casting() then elapsedSince = 0; return end
    elapsedSince = elapsedSince + elapsed;
    if elapsedSince >= PREVIEW_PULSE_EVERY then
      elapsedSince = 0;
      sample.PlayInteractPulse();
    end
  end);
  Next();
end

local function CreatePage()
  panel = CreateFrame("Frame", "EnhancedSoftInteractSettings", UIParent);
  panel.name = "Enhanced Soft Interact";
  panel:Hide();
  ns.settingsPanel = panel;
  local title = Label(panel, panel.name, "GameFontNormalLarge");
  title:SetPoint("TOPLEFT", 16, -16);
  title:SetTextColor(1, 0.82, 0.25);
  local subtitle = Label(panel, "Customize the HUD here. Use Edit Mode to move it.", "GameFontHighlightSmall");
  subtitle:SetPoint("TOPLEFT", 16, -48);
  local move = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate");
  move:SetSize(210, 26);
  move:SetPoint("TOPRIGHT", -20, -14);
  move:SetText("Move HUD in Edit Mode");
  move:SetScript("OnClick", ns.OpenHUDInEditMode);
  Hover(move, { name = "Move HUD in Edit Mode", desc = "Opens Edit Mode so you can drag the HUD.\n\nEach Edit Mode layout keeps its own position." });
  -- The preview sits in a fixed frame above the scrolling options, like Blizzard's nameplate preview,
  -- so it stays in view while options change. Clients without that frame art get a plain border.
  local previewFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate");
  previewFrame:SetPoint("TOPLEFT", 16, -66);
  previewFrame:SetPoint("TOPRIGHT", -20, -66);
  previewFrame:SetHeight(126);
  if C_Texture.GetAtlasInfo("options_frame_child") then
    local border = previewFrame:CreateTexture(nil, "BACKGROUND");
    border:SetAtlas("options_frame_child");
    border:SetAllPoints();
  else
    previewFrame:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8X8]], edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
      edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } });
    previewFrame:SetBackdropColor(0, 0, 0, 0.4);
    previewFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1);
  end
  local caption = Label(previewFrame, PREVIEW or "Preview", "GameFontHighlightSmall");
  caption:SetPoint("TOPLEFT", 10, -10);
  local hint = Label(previewFrame, "Click for another target", "GameFontDisableSmall");
  hint:SetPoint("TOPRIGHT", -10, -10);
  local preview = CreateFrame("Frame", nil, previewFrame);
  preview:SetPoint("TOP", 0, -22);
  preview:SetSize(560, 72);
  preview:SetClipsChildren(true);
  preview.inEditMode = true;
  local sample = ns.AddHUD(preview);
  ns.settingsPreview = preview;
  CreatePreviewControls(sample, ns.CreatePreviewPicker(), previewFrame);
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate");
  scroll:SetPoint("TOPLEFT", 16, -200);
  scroll:SetPoint("BOTTOMRIGHT", -36, 16);
  local content = CreateFrame("Frame", nil, scroll);
  content:SetWidth(580);
  scroll:SetScrollChild(content);
  scroll:HookScript("OnVerticalScroll", function() if card then card:Hide(); end end);
  scroll:SetScript("OnSizeChanged", function(_, width) if width > 0 then content:SetWidth(width); end end);
  local y = 0;
  local definitions = ns.BuildSettings();
  for _, data in ipairs(definitions) do
    if data.kind == ns.SettingType.Section then
      y = y + 18;
      local heading = CreateFrame("Frame", nil, content);
      heading:SetPoint("TOPLEFT", 0, -y);
      heading:SetPoint("TOPRIGHT", 0, -y);
      heading:SetHeight(18);
      pageItems[#pageItems + 1] = {frame = heading, inset = 0, y = y};
      local text = heading:CreateFontString(nil, "ARTWORK", "GameFontNormal");
      text:SetText(data.name);
      text:SetPoint("CENTER");
      for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local line = heading:CreateTexture(nil, "BACKGROUND");
        line:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]]);
        line:SetTexCoord(0.81, 0.94, 0.5, 1);
        line:SetHeight(8);
        line:SetPoint(side, heading, side, side == "LEFT" and 3 or -3, 0);
        line:SetPoint(side == "LEFT" and "RIGHT" or "LEFT", text, side, side == "LEFT" and -5 or 5, 0);
      end
      y = y + 26;
    elseif data.kind ~= ns.SettingType.Divider then
      CreateRow(content, data, y);
      pageItems[#pageItems + 1] = {frame = rows[#rows], inset = 8, y = y};
      y = y + ROW_HEIGHT;
    end
  end
  content:SetHeight(y + 20);
  pageContent, pageHeight = content, y + 20;
  CreateCard();
  CreateList();
  panel:SetScript("OnShow", ns.RefreshSettings);
  panel:SetScript("OnHide", function() card:Hide(); CloseList(); end);
  local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name);
  Settings.RegisterAddOnCategory(category);
  ns.settingsCategory = category;
end

function ns.OpenSettings()
  if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()); end
end

ns.slashCommands.move = ns.OpenHUDInEditMode;
table.insert(ns.onLoad, CreatePage);
