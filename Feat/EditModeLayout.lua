local _, ns = ...;
local LibEditMode = LibStub("LibEditMode", true);

-- LibEditMode pools its controls across addons. Fit our rows to a common width and restore the
-- original sizes when another addon's settings open, without changing the embedded library.
local CONTENT_WIDTH, LABEL_WIDTH, VALUE_WIDTH = 440, 140, 60;
local function SetupLayout()
  local dialog = LibEditMode and LibEditMode.internal.dialog;
  if not dialog then return end
  local original = {};
  local function Resize(region, width, fixed)
    if not region then return end
    if not original[region] then original[region] = { width = region:GetWidth(), fixedWidth = region.fixedWidth }; end
    region:SetWidth(width);
    if fixed then region.fixedWidth = width; end
  end
  local function Restore()
    for region, size in pairs(original) do
      region.fixedWidth = size.fixedWidth;
      region:SetWidth(size.width);
    end
    wipe(original);
  end
  local function Fit()
    if not dialog.selection or dialog.selection.parent ~= ns.frame then
      if next(original) then Restore(); dialog:Layout(); end
      return;
    end
    Resize(dialog, CONTENT_WIDTH + 40, true);
    Resize(dialog.Settings, CONTENT_WIDTH, true);
    Resize(dialog.Settings.Divider, CONTENT_WIDTH);
    for _, widget in ipairs(dialog.Settings.widgets or {}) do
      Resize(widget, CONTENT_WIDTH, true);
      if widget.Slider then
        Resize(widget.Label, LABEL_WIDTH);
        Resize(widget.Slider, 200);
        Resize(widget.Slider.RightText, VALUE_WIDTH);
      elseif widget.Dropdown then
        Resize(widget.Label, LABEL_WIDTH);
        Resize(widget.Dropdown, CONTENT_WIDTH - LABEL_WIDTH - 5);
      elseif widget.Button then
        Resize(widget.Label, CONTENT_WIDTH - 40);
      elseif widget.Divider then
        Resize(widget.Divider, CONTENT_WIDTH);
      end
    end
    dialog:Layout();
  end
  hooksecurefunc(dialog, "Update", Fit);
  hooksecurefunc(dialog, "RefreshWidgets", Fit);
end

table.insert(ns.onLoad, SetupLayout);
