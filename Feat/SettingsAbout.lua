local _, ns = ...;
local L = ns.L;

----
--  The About page, a submenu under the settings page: commands, translators, links and dependencies.
--  Translators come from the language files, so a new translation needs no change here. Like the settings
--  page, it is plain frames built when the addon loads (see Feat\SettingsDropdown.lua). The link boxes
--  only take focus when the player clicks them: moving focus from addon code taints Forever's gamepad UI.
----
local REPO = "github.com/gjemad/EnhancedSoftInteract";
local LABEL_X, COMMAND_TEXT_X, VALUE_X, RIGHT_INSET = 30, 134, 210, 26;
local COMMAND_ROW, LINK_ROW, VALUE_ROW, HEADING_ROW = 26, 30, 26, 30;
local TRANSLATOR_X, TRANSLATOR_NAME_X = 14, 104;

local function Text(parent, text, fontObject)
  local label = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontHighlight");
  label:SetText(text);
  label:SetJustifyH("LEFT");
  return label;
end

-- A box to copy a link from. Typing puts the link back.
local function LinkBox(parent, link, y)
  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate");
  box:SetAutoFocus(false);
  box:SetHeight(22);
  box:SetPoint("TOPLEFT", VALUE_X + 5, -y);
  box:SetPoint("RIGHT", -RIGHT_INSET, 0);
  box:SetText(link);
  box:SetCursorPosition(0);
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then self:SetText(link); self:HighlightText(); end
  end);
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText(); end);
  box:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); end);
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); end);
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus(); end);
  return box;
end

local function AddonVersion()
  local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata;
  local version = GetMetadata and GetMetadata("EnhancedSoftInteract", "Version");
  -- Only a packaged build has a real version; a copy from the repo still has the packager's placeholder.
  if version and not version:find("^@") then return version end
end

-- The Translators column, right of the panel's center. Returns the y below its last row.
local function CreateTranslators(page, y)
  local count = 0;
  for _, code in ipairs(ns.languageOrder) do
    local language = ns.languages[code];
    if code ~= "enUS" then
      count = count + 1;
      local name = Text(page, language.name, "GameFontNormal");
      name:SetPoint("TOPLEFT", page, "TOP", TRANSLATOR_X, -y);
      local who = Text(page, language.translators or "", "GameFontHighlightSmall");
      who:SetPoint("TOPLEFT", page, "TOP", TRANSLATOR_NAME_X, -y);
      who:SetPoint("RIGHT", -RIGHT_INSET, 0);
      y = y + math.max(COMMAND_ROW, who:GetStringHeight() + 8);
    end
  end
  if count == 0 then
    local none = Text(page, L.ABOUT_NO_TRANSLATIONS, "GameFontHighlightSmall");
    none:SetPoint("TOPLEFT", page, "TOP", TRANSLATOR_X, -y);
    y = y + COMMAND_ROW;
  end
  return y;
end

local function CreateAboutPage()
  if not (ns.settingsCategory and Settings.RegisterCanvasLayoutSubcategory) then return end
  local page = CreateFrame("Frame", "EnhancedSoftInteractAbout", UIParent);
  page:Hide();
  ns.aboutPage = page; --for the test tools
  local title = Text(page, ns.settingsPanel.name, "GameFontNormalLarge");
  title:SetPoint("TOPLEFT", 16, -16);
  title:SetTextColor(1, 0.82, 0.25);
  local version = AddonVersion();
  if version then
    Text(page, L.ABOUT_VERSION:format(version), "GameFontDisable"):SetPoint("TOPRIGHT", -20, -18);
  end

  local y = 56;
  local commandsHeading = ns.CreateSettingsSection(page, L.ABOUT_COMMANDS);
  commandsHeading:SetPoint("TOPLEFT", 0, -y);
  commandsHeading:SetPoint("RIGHT", page, "CENTER", -16, 0);
  local translatorsHeading = ns.CreateSettingsSection(page, L.ABOUT_TRANSLATORS);
  translatorsHeading:SetPoint("TOPLEFT", page, "TOP", 16, -y);
  translatorsHeading:SetPoint("RIGHT", 0, 0);
  y = y + HEADING_ROW;
  local translatorsEnd = CreateTranslators(page, y);
  for _, command in ipairs({
    { "/esi", L.ABOUT_COMMAND_SETTINGS },
    { "/esi move", L.ABOUT_COMMAND_EDIT_MODE },
    { "/esi debug", L.ABOUT_COMMAND_DEBUG },
  }) do
    Text(page, command[1], "GameFontNormal"):SetPoint("TOPLEFT", LABEL_X, -y);
    Text(page, command[2], "GameFontHighlightSmall"):SetPoint("TOPLEFT", COMMAND_TEXT_X, -y - 1);
    y = y + COMMAND_ROW;
  end

  y = math.max(y, translatorsEnd) + 10;
  local helpHeading = ns.CreateSettingsSection(page, L.ABOUT_HELP_OUT);
  helpHeading:SetPoint("TOPLEFT", 0, -y);
  helpHeading:SetPoint("RIGHT", 0, 0);
  y = y + HEADING_ROW;
  page.linkBoxes = {};
  for _, link in ipairs({
    { L.ABOUT_REPORT_BUG, REPO .. "/issues" },
    { L.ABOUT_HELP_TRANSLATE, REPO .. "#translating" },
    { L.ABOUT_CURSEFORGE, "curseforge.com/projects/1726408" },
  }) do
    Text(page, link[1]):SetPoint("TOPLEFT", LABEL_X, -y - 4);
    page.linkBoxes[#page.linkBoxes + 1] = LinkBox(page, link[2], y);
    y = y + LINK_ROW;
  end
  Text(page, L.ABOUT_COPY_HINT, "GameFontDisableSmall"):SetPoint("TOPLEFT", VALUE_X, -y);
  y = y + 26;

  local dependenciesHeading = ns.CreateSettingsSection(page, L.ABOUT_DEPENDENCIES);
  dependenciesHeading:SetPoint("TOPLEFT", 0, -y);
  dependenciesHeading:SetPoint("RIGHT", 0, 0);
  y = y + HEADING_ROW;
  for _, dependency in ipairs({
    { L.ABOUT_LIBRARIES, "LibEditMode, LibSharedMedia, CallbackHandler, LibStub" },
    { L.ABOUT_FONTS, "PT Sans Narrow" },
  }) do
    Text(page, dependency[1], "GameFontNormal"):SetPoint("TOPLEFT", LABEL_X, -y);
    Text(page, dependency[2], "GameFontHighlightSmall"):SetPoint("TOPLEFT", VALUE_X, -y - 1);
    y = y + VALUE_ROW;
  end

  page:SetScript("OnHide", function()
    for _, box in ipairs(page.linkBoxes) do box:ClearFocus(); end
  end);
  page.name = L.ABOUT;
  page.parent = ns.settingsPanel.name;
  Settings.RegisterCanvasLayoutSubcategory(ns.settingsCategory, page, L.ABOUT);
end

table.insert(ns.onLoad, CreateAboutPage);
