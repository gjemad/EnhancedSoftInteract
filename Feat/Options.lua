local _, ns = ...;
local frame, Notify, IsInteractKeyEnabled = ns.frame, ns.Notify, ns.IsInteractKeyEnabled;
local LibEditMode = LibStub("LibEditMode", true);

-- Options > AddOns > Enhanced Soft Interact holds the Interact Key setting and its keybind. You set
-- everything else about the HUD in Edit Mode (Feat\EditMode.lua).
local optionsFrame = CreateFrame("Frame", "EnhancedSoftInteractOptions", UIParent);
local category = Settings.RegisterCanvasLayoutCategory(optionsFrame, "Enhanced Soft Interact");
Settings.RegisterAddOnCategory(category);

function ns.ToggleOptions()
  if not SettingsPanel:IsShown() then
    Settings.OpenToCategory(category.ID);
  else
    SettingsPanel:Close(true);
  end
end

-- Rows are ROW_WIDTH wide, with labels at LABEL_X and controls at CONTROL_X, where Blizzard's settings
-- templates put their control (center - 80). Outside a settings list nothing anchors a template's label,
-- so AlignLabel does.
local ROW_WIDTH = 500;
local LABEL_X = 10;
local CONTROL_X = ROW_WIDTH / 2 - 80;
local INTERACT_ACTION = "INTERACTTARGET";
local function AlignLabel(text, row)
  text:ClearAllPoints();
  text:SetPoint("LEFT", row, "LEFT", LABEL_X, 0);
  text:SetPoint("RIGHT", row, "LEFT", CONTROL_X - 5, 0);
  text:SetJustifyH("LEFT");
  text:SetWordWrap(false);
end

local function SetupOptions()
  -- Each Add places a widget below the previous one.
  local y = 0;
  local function Add(widget, x, gapBefore, height)
    y = y + (gapBefore or 0);
    widget:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", x, -y);
    y = y + (height or widget:GetHeight());
  end
  local function AddHeader(title)
    local header = CreateFrame("Frame", nil, optionsFrame, "SettingsListSectionHeaderTemplate");
    header:SetWidth(optionsFrame:GetWidth() - 10);
    header.Title:SetText(title);
    Add(header, 0, 10);
  end

  AddHeader("Interact Key");

  -- Enable Interact Key is the same setting as Options > Controls > Enable Interact Key.
  local label = ENABLE_INTERACT_TEXT or "Enable Interact Key";
  local tooltip = (OPTION_TOOLTIP_ENABLE_INTERACT or "Enables the Interact Key for keyboard and mouse.") ..
    "\n\nEnhanced Soft Interact needs it. It is the same setting as Enable Interact Key in Options > Controls." ..
    "\nFor the most accurate icons, set Interact Key Icons to Show All under Accessibility.";
  local checkbox = CreateFrame("CheckButton", nil, optionsFrame, "SettingsCheckboxControlTemplate");
  checkbox:SetWidth(ROW_WIDTH);
  checkbox.Text:SetText(label);
  AlignLabel(checkbox.Text, checkbox);
  checkbox.Checkbox:SetScript("OnClick", function()
    SetCVar("softTargetInteract", IsInteractKeyEnabled() and Enum.SoftTargetEnableFlags.Gamepad or Enum.SoftTargetEnableFlags.Any);
    ns.RefreshOptionsState();
  end);
  local function Tooltip()
    GameTooltip_AddDisabledLine(SettingsTooltip, HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(label));
    GameTooltip_AddDisabledLine(SettingsTooltip, NORMAL_FONT_COLOR:WrapTextInColorCode(tooltip));
  end
  checkbox.Checkbox:SetTooltipFunc(Tooltip);
  checkbox:SetTooltipFunc(Tooltip);
  Add(checkbox, 10, 0);

  -- The interact keybind, with a primary and a secondary key like Blizzard's keybinding rows.
  local bindRow = CreateFrame("Frame", nil, optionsFrame);
  bindRow:SetSize(ROW_WIDTH, 32);
  bindRow.label = bindRow:CreateFontString(nil, "OVERLAY", "GameFontNormal");
  AlignLabel(bindRow.label, bindRow);
  bindRow.label:SetText(BINDING_NAME_INTERACTTARGET or "Interact With Target");
  local bindButtons = {};
  local listeningButton;

  local function RefreshBindingButtons()
    local keys = { GetBindingKey(INTERACT_ACTION) };
    for slot, b in ipairs(bindButtons) do
      if b == listeningButton then
        b:SetText("Press a key...");
      elseif keys[slot] then
        b:SetText(GetBindingText(keys[slot]));
      else
        b:SetText(GRAY_FONT_COLOR:WrapTextInColorCode(NOT_BOUND or "Not Bound"));
      end
    end
  end

  -- The row only gets the key handler while a button waits for a key. An OnKeyDown script turns on
  -- keyboard input for the frame, so leaving it attached would catch every key press.
  local function StopListening()
    listeningButton = nil;
    bindRow:SetScript("OnKeyDown", nil);
    bindRow:EnableKeyboard(false);
    RefreshBindingButtons();
  end

  -- Handles a key the same way as Blizzard's KeybindListener (BindingUtil), for this one action.
  local function BindInput(input)
    if not listeningButton then return end
    if input == "ESCAPE" then StopListening(); return end
    local key = GetConvertedKeyOrButton(input);
    if IsKeyPressIgnoredForBinding(key) then return end --a modifier alone: keep waiting
    local newKey = CreateKeyChordStringUsingMetaKeyState(key);
    if newKey == "BUTTON1" or newKey == "BUTTON2" then return end --plain left and right click stay unbound
    local slot = listeningButton.slot;
    StopListening();
    if InCombatLockdown() then Notify("Keybinds can't be changed in combat."); return end

    local oldAction = GetBindingAction(newKey);
    if oldAction ~= "" and oldAction ~= INTERACT_ACTION then
      Notify(("%s no longer triggers %s."):format(GetBindingText(newKey), GetBindingName(oldAction)));
    end
    local slotKey = select(slot, GetBindingKey(INTERACT_ACTION));
    if slotKey then SetBinding(slotKey); end
    SetBinding(newKey, INTERACT_ACTION);
    SaveBindings(GetCurrentBindingSet());
    RefreshBindingButtons();
  end
  local function OnListenKeyDown(_, input) BindInput(input) end
  bindRow:SetScript("OnHide", StopListening);

  for slot = 1, 2 do
    local b = CreateFrame("Button", nil, bindRow, "UIPanelButtonTemplate");
    b:SetSize(140, 24);
    b.slot = slot;
    if slot == 1 then
      b:SetPoint("LEFT", bindRow, "LEFT", CONTROL_X, 0);
    else
      b:SetPoint("LEFT", bindButtons[1], "RIGHT", 6, 0);
    end
    b:RegisterForClicks("AnyUp");
    b:SetScript("OnClick", function(self, button)
      if listeningButton == self then
        if button == "LeftButton" or button == "RightButton" then StopListening(); else BindInput(button); end
        return;
      end
      if InCombatLockdown() then Notify("Keybinds can't be changed in combat."); return end
      if button == "RightButton" then --unbind this slot
        local slotKey = select(self.slot, GetBindingKey(INTERACT_ACTION));
        if slotKey then
          SetBinding(slotKey);
          SaveBindings(GetCurrentBindingSet());
        end
        RefreshBindingButtons();
      elseif button == "LeftButton" then
        listeningButton = self;
        bindRow:SetScript("OnKeyDown", OnListenKeyDown);
        bindRow:EnableKeyboard(true);
        bindRow:SetPropagateKeyboardInput(false);
        RefreshBindingButtons();
      end
    end);
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP");
      GameTooltip_SetTitle(GameTooltip, BINDING_NAME_INTERACTTARGET or "Interact With Target");
      GameTooltip_AddNormalLine(GameTooltip, "Sets the " .. (self.slot == 1 and "primary" or "secondary") ..
        " key. Left-click, then press the key. Esc cancels.\nRight-click to unbind.");
      GameTooltip:Show();
    end);
    b:SetScript("OnLeave", function() GameTooltip:Hide(); end);
    bindButtons[slot] = b;
  end
  Add(bindRow, 10, 5);

  AddHeader("HUD");

  -- A pointer to Edit Mode, where the HUD itself is the preview.
  local hint = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
  hint:SetWidth(optionsFrame:GetWidth() - 30);
  hint:SetJustifyH("LEFT");
  hint:SetText("Set the HUD's look and position in Edit Mode. It shows a sample target there, and its settings change it as you go. Each Edit Mode layout keeps its own position. You can also type /esi.");
  Add(hint, 10 + LABEL_X, 5, hint:GetStringHeight() + 4);
  local editModeButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate");
  editModeButton:SetSize(200, 24);
  editModeButton:SetText("Open HUD in Edit Mode");
  editModeButton:SetScript("OnClick", function() ns.OpenHUDInEditMode(); end);
  Add(editModeButton, 10 + LABEL_X, 10);

  ns.RefreshOptionsState = function()
    checkbox.Checkbox:SetChecked(IsInteractKeyEnabled());
    if not listeningButton then RefreshBindingButtons(); end
    if LibEditMode and LibEditMode:IsInEditMode() then LibEditMode:RefreshFrameSettings(frame); end
  end
end

-- SetupOptions runs the first time the panel opens, once the panel has its size.
optionsFrame:SetScript("OnShow", function()
  if not ns.RefreshOptionsState then SetupOptions(); end
  ns.RefreshOptionsState();
end);

-- Keeps the panel in sync when the Interact Key changes elsewhere, such as Blizzard's settings.
optionsFrame:RegisterEvent("CVAR_UPDATE");
optionsFrame:SetScript("OnEvent", function()
  if ns.RefreshOptionsState then ns.RefreshOptionsState(); end
end);

ns.slashCommands.options = ns.ToggleOptions;

table.insert(ns.onLoad, function()
  if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    local info = UIDropDownMenu_CreateInfo();
    info.text = "Enhanced Soft Interact options";
    info.notCheckable = true;
    info.func = ns.ToggleOptions;
    AddonCompartmentFrame:RegisterAddon(info);
  end
end);
