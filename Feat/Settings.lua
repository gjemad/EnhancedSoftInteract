local ADDON_NAME, ns = ...;
local MEDIA = [[Interface\AddOns\]] .. ADDON_NAME .. [[\Media\]];
local panel, card;
local rows = {};
ns.settingsRows = rows;
local IMAGES = {
  ["Show Target Icons"] = { "SettingsTargetIcons", 256, 256, 288 },
  ["Show Target Tooltip"] = { "SettingsTargetTooltip", 128, 128 },
};

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
  card.art = card:CreateTexture(nil, "ARTWORK");
  card.fade = card:CreateMaskTexture();
  card.fade:SetTexture(MEDIA .. "SettingsExampleFade");
  card.fade:SetAllPoints(card.art);
  card.art:AddMaskTexture(card.fade);
  card:Hide();
  ns.settingsCard = card;
end

local function ShowCard(owner, data)
  card:SetOwner(owner, "ANCHOR_NONE");
  card:ClearLines();
  card:SetPadding(0, 0, 0, 0);
  card:SetMinimumWidth(0);
  card:SetText(data.name, 1, 0.82, 0, 1, true);
  local description = data.desc or "";
  if type(description) == "function" then description = description(); end
  card:AddLine(description, 1, 1, 1, true);
  local image = IMAGES[data.name];
  card.art:Hide();
  if image then
    local width = image[4] or (image[2] == image[3] and 160 or 288);
    local height = width * image[3] / image[2];
    -- Native tooltip padding order is right, bottom, left, top.
    card:SetMinimumWidth(width + 32);
    card:SetPadding(0, height + 16, 0, 0);
    card.art:ClearAllPoints();
    card.art:SetPoint("BOTTOM", 0, 12);
    card.art:SetSize(width, height);
    card.art:SetTexture(MEDIA .. image[1]);
    card.art:Show();
  end
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

local function CreateRow(content, data, y)
  local row = CreateFrame("Frame", nil, content);
  row:SetPoint("TOPLEFT", 8, -y);
  row:SetPoint("TOPRIGHT", -8, -y);
  row:SetHeight(36);
  row:EnableMouse(true);
  row.data = data;
  row.highlight = row:CreateTexture(nil, "BACKGROUND");
  row.highlight:SetTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]]);
  row.highlight:SetAllPoints();
  row.highlight:SetBlendMode("ADD");
  row.highlight:SetAlpha(0.15);
  row.highlight:Hide();
  Hover(row, data);
  row.label = Label(row, data.name);
  row.label:SetPoint("LEFT", 32, 0);
  row.label:SetWidth(200);
  if data.kind == ns.SettingType.Checkbox then
    row.label:SetWidth(480);
    row.control = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate");
    row.control:SetSize(28, 28);
    row.control:SetPoint("LEFT");
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
    row.control = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate");
    row.control:SetSize(224, 28);
    row.control:SetPoint("RIGHT", 0, 0);
    row.control:SetupMenu(function(_, root)
      if data.height then root:SetScrollMode(data.height); end
      for _, entry in ipairs(data.values()) do
        root:CreateRadio(entry.text, function() return data.get() == entry.value end,
          function() Changed(data, entry.value); end);
      end
    end);
  end
  if row.control then Hover(row.control, data, row); end
  row.reset = CreateFrame("Button", nil, row);
  row.reset:SetSize(22, 22);
  row.reset:SetNormalTexture([[Interface\Buttons\UI-SquareButton-Up]]);
  row.reset:SetPushedTexture([[Interface\Buttons\UI-SquareButton-Down]]);
  row.reset:SetDisabledTexture([[Interface\Buttons\UI-SquareButton-Disabled]]);
  row.reset:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]], "ADD");
  row.reset.icon = row.reset:CreateTexture(nil, "ARTWORK");
  row.reset.icon:SetTexture(MEDIA .. "SettingsUndo");
  row.reset.icon:SetSize(14, 14);
  row.reset.icon:SetPoint("CENTER");
  row.reset.icon:SetVertexColor(1, 0.82, 0, 1);
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
    local disabled = data.disabled and data.disabled();
    row.refreshing = true;
    row.control:SetEnabled(not disabled);
    row.label:SetTextColor(disabled and 0.45 or 1, disabled and 0.45 or 1, disabled and 0.45 or 1);
    local value = data.get();
    row.reset:SetShown(value ~= DefaultValue(data));
    row.reset:SetEnabled(not disabled);
    row.reset.icon:SetDesaturated(not not disabled);
    local textWidth = math.min(row.label:GetStringWidth(), data.kind == ns.SettingType.Checkbox and 480 or 200);
    row.reset:SetPoint("LEFT", row, "LEFT", math.max(238, 32 + textWidth + 8), 0);
    if data.kind == ns.SettingType.Checkbox then
      row.control:SetChecked(value);
    elseif data.kind == ns.SettingType.Slider then
      row.control:SetValue(value);
      row.value:SetText(data.formatter and data.formatter(value) or tostring(value));
    elseif data.kind == ns.SettingType.Dropdown then
      row.control:SetDefaultText(tostring(value));
      row.control:GenerateMenu();
    end
    row.refreshing = false;
  end
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
  Hover(move, { name = "Move HUD in Edit Mode", desc = "Opens Edit Mode so you can drag the HUD.\nEach Edit Mode layout keeps its own position." });
  local preview = CreateFrame("Frame", nil, panel);
  preview:SetPoint("TOPLEFT", 16, -68);
  preview:SetSize(560, 72);
  preview:SetClipsChildren(true);
  preview.inEditMode = true;
  local sample = ns.AddHUD(preview);
  ns.settingsPreview = preview;
  preview:EnableMouse(true);
  local samples = { { "Innkeeper Gryshka", "Innkeeper" }, { "Peacebloom", "GatherHerbs" }, { "Copper Vein", "Mine" } };
  local sampleIndex = 1;
  preview:SetScript("OnMouseUp", function()
    sampleIndex = sampleIndex % #samples + 1;
    local name, cursor = unpack(samples[sampleIndex]);
    local requirement = ns.RequirementFor(cursor);
    sample.ShowSample(name, requirement and "Unable" .. cursor or cursor, requirement);
    sample.PlayInteractPulse();
  end);
  sample.ShowSample("Innkeeper Gryshka", "Innkeeper");
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate");
  scroll:SetPoint("TOPLEFT", 16, -156);
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
      y = y + 36;
    end
  end
  content:SetHeight(y + 20);
  CreateCard();
  panel:SetScript("OnShow", ns.RefreshSettings);
  panel:SetScript("OnHide", function() card:Hide(); end);
  local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name);
  Settings.RegisterAddOnCategory(category);
  ns.settingsCategory = category;
end

function ns.OpenSettings()
  if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()); end
end

ns.slashCommands.move = ns.OpenHUDInEditMode;
table.insert(ns.onLoad, CreatePage);
