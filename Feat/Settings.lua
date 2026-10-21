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
--  Sliders: a plain Slider with the art of Blizzard's settings slider (MinimalSliderWithSteppersTemplate in
--  Blizzard_SharedXML: the Minimal_SliderBar track and thumb, with a stepper arrow at each end), built
--  from the addon's own frames like the dropdowns. A client without that art gets OptionsSliderTemplate.
----
local STEPPER_DISABLED_ALPHA = 0.5; --Blizzard's value
local THUMB_DISABLED_ALPHA = 0.7;

local function CreateSlider(row, data)
  local native = C_Texture.GetAtlasInfo("Minimal_SliderBar_Button") ~= nil;
  local slider = CreateFrame("Slider", nil, row, not native and "OptionsSliderTemplate" or nil);
  slider:SetMinMaxValues(data.minValue, data.maxValue);
  slider:SetValueStep(data.valueStep);
  slider:SetObeyStepOnDrag(true);
  if not native then
    slider:SetSize(160, 16);
    if slider.Low then slider.Low:Hide(); end
    if slider.High then slider.High:Hide(); end
    if slider.Text then slider.Text:Hide(); end
    return slider;
  end
  slider:SetOrientation("HORIZONTAL");
  slider:SetSize(136, 19);
  slider:EnableMouse(true);
  local function Art(atlas, layer)
    local texture = slider:CreateTexture(nil, layer or "ARTWORK");
    texture:SetAtlas(atlas, true);
    return texture;
  end
  local left, right = Art("Minimal_SliderBar_Left"), Art("Minimal_SliderBar_Right");
  left:SetPoint("LEFT");
  right:SetPoint("RIGHT");
  local middle = Art("_Minimal_SliderBar_Middle");
  middle:SetPoint("TOPLEFT", left, "TOPRIGHT");
  middle:SetPoint("TOPRIGHT", right, "TOPLEFT");
  slider:SetThumbTexture(Art("Minimal_SliderBar_Button", "OVERLAY"));

  -- The arrows step by one value; each turns grey at its end of the range, as Blizzard's do.
  slider.steppers = {};
  for i, step in ipairs({ -1, 1 }) do
    local button = CreateFrame("Button", nil, row);
    button.art = button:CreateTexture(nil, "BACKGROUND");
    button.art:SetAtlas(step < 0 and "Minimal_SliderBar_Button_Left" or "Minimal_SliderBar_Button_Right", true);
    button.art:SetPoint("CENTER");
    button:SetSize(step < 0 and 11 or 9, 19);
    if step < 0 then
      button:SetPoint("RIGHT", slider, "LEFT", -4, 0);
    else
      button:SetPoint("LEFT", slider, "RIGHT", 4, 0);
    end
    button:SetScript("OnClick", function()
      slider:SetValue(slider:GetValue() + step * data.valueStep);
      if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON); end
    end);
    Hover(button, data, row);
    slider.steppers[i] = button;
  end
  function slider.UpdateSteppers(self)
    local enabled = self:IsEnabled();
    local low, high = self:GetMinMaxValues();
    local value = self:GetValue() or low;
    local half = data.valueStep * 0.5;
    for i, button in ipairs(self.steppers) do
      local on = enabled and (i == 1 and value > low + half or i == 2 and value < high - half);
      button:SetEnabled(on and true or false);
      button:SetAlpha(on and 1 or STEPPER_DISABLED_ALPHA);
      button.art:SetDesaturated(not on);
    end
    self:GetThumbTexture():SetAlpha(enabled and 1 or THUMB_DISABLED_ALPHA);
  end
  slider:HookScript("OnValueChanged", slider.UpdateSteppers);
  return slider;
end
ns.CreateSettingsSlider = CreateSlider; --for the test tools

----
--  Binding slots: two buttons for a game binding, like the game's Keybindings page. Click a slot, then
--  press a key or click it with a middle or side mouse button; Escape or another click cancels, and
--  right-click clears the slot. Controller buttons stay in the game's controller settings. The slot
--  takes keyboard input only while it waits for a key.
----
local MOUSE_BUTTONS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" };
local MODIFIER_KEYS = { LALT = true, RALT = true, LCTRL = true, RCTRL = true, LSHIFT = true, RSHIFT = true,
  LMETA = true, RMETA = true, UNKNOWN = true };
local listening; --the slot waiting for a key

-- The binding string for a key with the held modifiers, in the game's ALT-CTRL-SHIFT order.
local function Chord(key)
  local chord = "";
  if IsAltKeyDown() then chord = chord .. "ALT-"; end
  if IsControlKeyDown() then chord = chord .. "CTRL-"; end
  if IsShiftKeyDown() then chord = chord .. "SHIFT-"; end
  if IsMetaKeyDown and IsMetaKeyDown() then chord = chord .. "META-"; end
  return chord .. key;
end

local function StopListening()
  local slot = listening;
  if not slot then return end
  listening = nil;
  slot:EnableKeyboard(false);
  slot:SetScript("OnKeyDown", nil);
  slot:UnlockHighlight();
  ns.RefreshSettings();
end

-- Puts key in the action's slot (1 or 2), or clears the slot when key is nil. The other slot keeps its
-- key. A key taken from another action is named in chat, since the game unbinds it there.
function ns.SetBindingSlot(action, slot, key)
  if InCombatLockdown() then ns.Notify("Key bindings can't change during combat."); return end
  local keys = { GetBindingKey(action) };
  local wanted = { keys[1], keys[2] };
  for i = 1, 2 do if wanted[i] == key then wanted[i] = nil; end end
  wanted[slot] = key;
  for _, old in ipairs(keys) do SetBinding(old, nil); end
  if key then
    local previous = GetBindingAction(key);
    if previous ~= "" and previous ~= action then
      SetBinding(key, nil);
      ns.Notify(('%s no longer does "%s".'):format(GetBindingText(key), _G["BINDING_NAME_" .. previous] or previous));
    end
  end
  for i = 1, 2 do if wanted[i] then SetBinding(wanted[i], action); end end
  SaveBindings(GetCurrentBindingSet());
end

local function CreateBindingSlots(row, data)
  local holder = CreateFrame("Frame", nil, row);
  holder:SetSize(224, 22);
  holder.slots = {};
  local function Bind(i, key)
    data.set(i, key);
    ns.RefreshSettings();
  end
  for i = 1, 2 do
    local slot = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate");
    slot:SetSize(108, 22);
    slot:SetPoint(i == 1 and "LEFT" or "RIGHT");
    slot:RegisterForClicks("AnyUp");
    slot:SetScript("OnClick", function(self, button)
      if listening == self then
        StopListening();
        if MOUSE_BUTTONS[button] then Bind(i, Chord(MOUSE_BUTTONS[button])); end
        return;
      end
      StopListening();
      if button == "RightButton" then Bind(i, nil); return end
      if button ~= "LeftButton" then return end
      listening = self;
      self:LockHighlight();
      self:SetText("Press a key");
      self:EnableKeyboard(true);
      self:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then StopListening(); return end
        if MODIFIER_KEYS[key] then return end
        StopListening();
        Bind(i, Chord(key));
      end);
    end);
    Hover(slot, data, row);
    holder.slots[i] = slot;
  end
  function holder.SetEnabled(self, enabled)
    for _, slot in ipairs(self.slots) do slot:SetEnabled(enabled); end
  end
  function holder.Refresh(self)
    local keys = { data.get() };
    for i, slot in ipairs(self.slots) do
      if listening ~= slot then slot:SetText(keys[i] and GetBindingText(keys[i]) or NOT_BOUND or "Not Bound"); end
    end
  end
  return holder;
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
  -- Sub-options sit one checkbox width further in per level, under their parent option.
  row.indent = (data.indent or 0) * SUB_OPTION_INDENT;
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
    row.control = CreateSlider(row, data);
    row.control:SetPoint("RIGHT", -64, 0);
    row.value = Label(row, "", "GameFontHighlightSmall");
    row.value:SetPoint("RIGHT", -2, 0);
    row.control:SetScript("OnValueChanged", function(_, value)
      if row.refreshing then return end
      local stepped = math.floor(value / data.valueStep + 0.5) * data.valueStep;
      Changed(data, stepped);
    end);
  elseif data.kind == ns.SettingType.Dropdown then
    row.control = ns.SettingsDropdown.Create(row, data);
    row.control:SetSize(224, 25);
    row.control:SetPoint("RIGHT", -8, 0);
  elseif data.kind == ns.SettingType.Keybind then
    row.control = CreateBindingSlots(row, data);
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
    row.reset:SetShown(data.kind ~= ns.SettingType.Keybind and value ~= DefaultValue(data)); --a binding has no default
    row.reset:SetEnabled(not disabled); --the button shows Blizzard's own disabled art
    local textWidth = math.min(row.label:GetStringWidth(), data.kind == ns.SettingType.Checkbox and 480 - row.indent or 200);
    row.reset:SetPoint("LEFT", row, "LEFT", math.max(238, 32 + row.indent + textWidth + 8), 0);
    if data.kind == ns.SettingType.Checkbox then
      row.control:SetChecked(value);
    elseif data.kind == ns.SettingType.Slider then
      row.control:SetValue(value);
      if row.control.UpdateSteppers then row.control:UpdateSteppers(); end --also when the value didn't change
      row.value:SetText(data.formatter and data.formatter(value) or tostring(value));
    elseif data.kind == ns.SettingType.Dropdown or data.kind == ns.SettingType.Keybind then
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
  { key = "animate", name = "Animate", desc = "Plays the interaction every few seconds." },
  { key = "range", name = "Move closer", desc = "Shows the target as out of range." },
  { key = "requires", name = "Requires profession", desc = "Shows the missing profession message." },
  { key = "cast", name = "Cast bar", desc = "Shows a cast bar on targets you gather or open." },
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
  Hover(move, { name = "Move HUD in Edit Mode", desc = "Opens Edit Mode so you can drag the HUD." });
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
    else
      CreateRow(content, data, y);
      pageItems[#pageItems + 1] = {frame = rows[#rows], inset = 8, y = y};
      y = y + ROW_HEIGHT;
    end
  end
  content:SetHeight(y + 20);
  pageContent, pageHeight = content, y + 20;
  CreateCard();
  ns.SettingsDropdown.CreateList(panel);
  panel:SetScript("OnShow", ns.RefreshSettings);
  panel:SetScript("OnHide", function() card:Hide(); ns.SettingsDropdown.Close(); StopListening(); end);
  panel:RegisterEvent("UPDATE_BINDINGS"); --bindings changed outside the page
  panel:SetScript("OnEvent", function() if panel:IsShown() then ns.RefreshSettings(); end end);
  local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name);
  Settings.RegisterAddOnCategory(category);
  ns.settingsCategory = category;
end

function ns.OpenSettings()
  if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()); end
end

ns.slashCommands.move = ns.OpenHUDInEditMode;
table.insert(ns.onLoad, CreatePage);
