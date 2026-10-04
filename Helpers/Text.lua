local _, ns = ...;

-- UpdateKeyCap and UpdateLayout measure text on hidden font strings that aren't anchored to the HUD.
-- GetStringWidth is SecretWhenAnchoringSecret, so a region anchored to the NPC name, which is secret in
-- instances and combat, returns secret sizes.
local function CreateMeasure()
  local fs = UIParent:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
  fs:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT"); --off-screen
  fs:Hide();
  return fs;
end

-- A font string centers text by the letters' advance widths, but in Friz Quadrata (the default font) the
-- ink of some letters sits off-center in that width; an "R" leans 0.05 font sizes right because of its
-- leg. FRIZ_BEARINGS has each character's left and right side bearing in 1/1000 font sizes, read from
-- Fonts\FRIZQT__.TTF. InkOffset returns how far right of center a label's ink sits, in font sizes, and 0
-- for other fonts and unknown characters.
local FRIZ_BEARINGS = {
  ["A"]={9,2}, ["B"]={52,44}, ["C"]={40,13}, ["D"]={52,40}, ["E"]={52,9}, ["F"]={52,26}, ["G"]={40,69},
  ["H"]={52,53}, ["I"]={52,52}, ["J"]={-37,45}, ["K"]={52,-19}, ["L"]={52,13}, ["M"]={26,27}, ["N"]={44,40},
  ["O"]={40,41}, ["P"]={52,27}, ["Q"]={40,-118}, ["R"]={52,-43}, ["S"]={37,39}, ["T"]={-7,-7}, ["U"]={49,52},
  ["V"]={-5,7}, ["W"]={-6,12}, ["X"]={5,6}, ["Y"]={-7,4}, ["Z"]={25,16}, ["a"]={35,6}, ["b"]={35,41},
  ["c"]={40,-4}, ["d"]={40,36}, ["e"]={40,40}, ["f"]={34,-53}, ["g"]={15,3}, ["h"]={38,39}, ["i"]={42,39},
  ["j"]={-26,64}, ["k"]={38,-12}, ["l"]={38,39}, ["m"]={42,37}, ["n"]={42,38}, ["o"]={40,40}, ["p"]={35,40},
  ["q"]={41,39}, ["r"]={42,9}, ["s"]={30,26}, ["t"]={27,9}, ["u"]={38,39}, ["v"]={-12,2}, ["w"]={-8,2},
  ["x"]={-5,-5}, ["y"]={-21,5}, ["z"]={11,-1}, ["0"]={39,40}, ["1"]={157,201}, ["2"]={53,43}, ["3"]={61,78},
  ["4"]={13,24}, ["5"]={71,70}, ["6"]={45,48}, ["7"]={80,57}, ["8"]={39,36}, ["9"]={47,44}, ["-"]={35,34},
};
local function InkOffset(text, fontPath)
  if not fontPath:lower():find("frizqt__") then return 0 end
  local first, last = FRIZ_BEARINGS[text:sub(1, 1)], FRIZ_BEARINGS[text:sub(-1)];
  if not (first and last) then return 0 end
  return (first[1] - last[2]) / 2000;
end

ns.CreateMeasure, ns.InkOffset = CreateMeasure, InkOffset;
