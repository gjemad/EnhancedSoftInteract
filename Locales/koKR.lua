local _, ns = ...;

ns.AddLanguage("koKR", "Korean", "hinski", {
  ----  HUD  ----
  HUD_MOVE_CLOSER = "가까이 이동",
  HUD_IN_COMBAT = "전투중",
  HUD_SKILL_TOO_LOW = "숙련도 부족 (%d/%d)", --your skill, the skill the node needs
  HUD_KEY_NUMPAD = "N%s", --a numpad key on the button: the digit or symbol, as in N3 or N+

  ----  HUD styles  ----
  STYLE_LEVEL_UP_LINE = "레벨업 선",
  STYLE_RUNIC_LINE = "북유럽풍 선",
  STYLE_PLAIN_TEXT = "단순 문자",

  ----  Settings: Enabled and Interact Key  ----
  OPTION_ENABLED = "활성화",
  OPTION_ENABLED_DESC = "소프트 타겟 HUD를 표시합니다.",
  OPTION_ALWAYS_INTERACT_KEY = "상호작용 단축키 항상 활성화",
  OPTION_ALWAYS_INTERACT_KEY_DESC = "어떤 요소로 인해 게임의 상호작용 단축키가 꺼지면 다시 켭니다.",
  OPTION_INTERACT_KEY = "상호작용 단축키",
  OPTION_INTERACT_KEY_DESC = "상호작용에 사용할 단축키를 설정합니다.\n\n칸을 클릭한 뒤 단축키를 누르세요. 마우스 오른쪽 클릭으로 해제합니다.",
  OPTION_AUTO_LOOT_CONFLICT = "자동 전리품 획득 충돌",
  OPTION_AUTO_LOOT_CONFLICT_TEXT = '자동 전리품 획득 단축키 충돌: %s은(는) 이미 "%s"에 지정되어 있습니다.', --the key, the action
  OPTION_AUTO_LOOT_CONFLICT_DESC = "자동 전리품 획득 단축키는 %s, 상호작용 단축키는 %s입니다.", --the modifier, the key
  OPTION_AUTO_LOOT_CONFLICT_CLEAR_DESC = '해제하면 "%s" 지정이 %s에서 제거됩니다.', --the action, the key
  OPTION_INTERACT_SOUND_DESC = "대상과 상호작용할 수 있게 되었을 때와 더 이상 할 수 없게 되었을 때 소리를 재생합니다.",
  OPTION_ALWAYS_INTERACT_ICONS = "상호작용 단축키 아이콘 항상 모두 표시",
  OPTION_ALWAYS_INTERACT_ICONS_DESC = "게임의 상호작용 단축키 아이콘 설정을 '모두 표시'로 유지하여, HUD가 모든 대상에 맞는 아이콘을 표시할 수 있게 합니다.",

  ----  Settings: Appearance  ----
  SECTION_APPEARANCE = "외형",
  OPTION_STYLE = "스타일",
  OPTION_STYLE_DESC = "HUD의 모양을 변경합니다.",
  OPTION_SIZE = "크기",
  OPTION_SIZE_DESC = "HUD의 크기를 설정합니다.",
  VALUE_SIZE_SMALL = "작게",
  VALUE_SIZE_NORMAL = "보통",
  VALUE_SIZE_LARGE = "크게",
  OPTION_FONT = "글꼴",
  OPTION_FONT_DESC = "HUD 텍스트의 글꼴을 변경합니다.",
  OPTION_FONT_LANGUAGE_DESC = "선택한 언어는 다른 글꼴로 표시할 수 없어 전용 글꼴을 사용합니다.",
  OPTION_LANGUAGE = "언어",
  OPTION_LANGUAGE_DESC = "이 애드온의 언어를 설정합니다. 변경 사항은 /reload를 입력한 후에 적용됩니다.",
  OPTION_LANGUAGE_RELOAD = "다시 로드 필요",
  OPTION_LANGUAGE_RELOAD_TEXT = "언어를 바꾸려면 /reload를 입력하세요.",
  VALUE_LANGUAGE_AUTO = "게임 언어",
  OPTION_SHOW_ICON = "아이콘 표시",
  OPTION_SHOW_ICON_DESC = "HUD에 상호작용 아이콘을 표시합니다.",
  OPTION_SHOW_BUTTON = "상호작용 단축키 표시",
  OPTION_SHOW_BUTTON_DESC = "HUD에 상호작용 단축키를 표시합니다.",
  OPTION_BUTTON_STYLE = "단축키 버튼 스타일",
  OPTION_BUTTON_STYLE_DESC = "상호작용 단축키 버튼의 그래픽을 변경합니다.",
  VALUE_BUTTON_CLASSIC = "클래식 (검정)",
  VALUE_BUTTON_RED = "클래식 (빨강)",
  VALUE_BUTTON_PLUNDERSTORM = "플런더스톰",
  OPTION_SWAP_SIDES = "아이콘과 상호작용 단축키 위치 교체",
  OPTION_SWAP_SIDES_DESC = "아이콘을 오른쪽으로, 상호작용 키를 왼쪽으로 옮깁니다.",
  OPTION_SKILL_UP = "숙련도 상승 아이콘 표시",
  OPTION_SKILL_UP_DESC = "대상으로 전문 기술 숙련도를 올릴 수 있을 때 이름 옆에 아이콘을 표시합니다.",
  OPTION_CAST_BAR = "시전바 사용",
  OPTION_CAST_BAR_DESC = "채집하거나 무언가를 여는 동안 HUD에 시전바를 표시합니다.",
  OPTION_CAST_TIMER = "시전바 타이머 표시",
  OPTION_CAST_TIMER_DESC = "시전이 끝날 때까지 남은 시간(초)을 표시합니다.",
  OPTION_HIDE_GAME_CAST_BAR = "기본 시전바 자동 숨김",
  OPTION_HIDE_GAME_CAST_BAR_DESC = "HUD가 시전을 표시하는 동안 기본 시전바를 숨깁니다.",
  OPTION_CAST_CLICKED = "클릭한 대상에도 표시",
  OPTION_CAST_CLICKED_DESC = "대상을 직접 클릭했을 때도 시전바를 표시합니다.",

  ----  Settings: Targeting  ----
  SECTION_TARGETING = "대상 지정",
  OPTION_INTERACT_RANGE = "상호작용 범위",
  OPTION_INTERACT_RANGE_DESC = "상호작용 단축키가 대상을 찾는 거리를 설정합니다.\n\n게임 오브젝트는 20야드까지만 가능합니다. 그 이상의 범위는 우호적인 대상에만 적용됩니다.",
  VALUE_YARDS = "%d야드", --the distance
  OPTION_INTERACT_ARC = "상호작용 각도",
  OPTION_INTERACT_ARC_DESC = "상호작용 단축키가 전방에서 대상을 찾는 범위의 너비를 설정합니다.",
  VALUE_ARC_STRAIGHT_AHEAD = "정면",
  VALUE_ARC_NARROW = "좁게",
  VALUE_ARC_WIDE = "넓게",

  ----  Settings: Target Displays  ----
  SECTION_TARGET_DISPLAYS = "대상 표시",
  OPTION_TARGET_TOOLTIP = "대상 툴팁 표시",
  OPTION_TARGET_TOOLTIP_DESC = "상호작용 대상에 대해 게임의 툴팁을 표시합니다.",
  OPTION_TARGET_ICONS = "대상 아이콘 표시",
  OPTION_TARGET_ICONS_DESC = "상호작용 대상 위에 게임의 상호작용 아이콘을 표시합니다.",
  OPTION_TARGET_ICONS_NPC = "NPC",
  OPTION_TARGET_ICONS_NPC_DESC = "NPC 위에 아이콘을 표시합니다.",
  OPTION_TARGET_ICONS_OBJECT = "오브젝트",
  OPTION_TARGET_ICONS_OBJECT_DESC = "오브젝트 위에 아이콘을 표시합니다.",
  OPTION_OBJECT_NAMES = "오브젝트 이름 표시",
  OPTION_OBJECT_NAMES_DESC = "상호작용 대상이 오브젝트일 때 그 위에 이름을 표시합니다.",
  OPTION_QUEST_LOOT_EFFECT = "퀘스트 아이템 전리품 효과 표시",
  OPTION_QUEST_LOOT_EFFECT_DESC = "획득할 수 있는 퀘스트 아이템에 대해 게임의 전리품 효과를 켭니다.",
  OPTION_LOOT_EFFECT = "대상 전리품 효과 표시",
  OPTION_LOOT_EFFECT_DESC = "상호작용 대상이 광맥, 약초 또는 퀘스트 오브젝트일 때 전리품 효과를 표시합니다.",
  OPTION_LOOT_EFFECT_ORE = "광맥",
  OPTION_LOOT_EFFECT_ORE_DESC = "광맥에 전리품 효과를 표시합니다.",
  OPTION_LOOT_EFFECT_HERBS = "약초",
  OPTION_LOOT_EFFECT_HERBS_DESC = "약초에 전리품 효과를 표시합니다.",
  OPTION_LOOT_EFFECT_QUEST = "퀘스트 오브젝트",
  OPTION_LOOT_EFFECT_QUEST_DESC = "퀘스트에 필요한 오브젝트에 전리품 효과를 표시합니다.",
  OPTION_PLUMBER_CAST_BAR = "Plumber 시전바 숨김",
  OPTION_PLUMBER_CAST_BAR_DESC = "Plumber의 상호작용 대상 이름표에 표시되는 원형 시전바를 숨깁니다. Plumber 설정의 '시전바 표시'가 변경되며, /reload를 입력한 후에 적용됩니다.",
  CONFLICT_TITLE = "충돌하는 애드온",
  CONFLICT_INTRO = "다른 애드온이 다음 옵션들을 제어하고 있습니다.",
  CONFLICT_PLUMBER = 'Plumber가 대상 아이콘과 이름을 처리하고 있습니다. 이 옵션을 변경하려면 Plumber에서 "이름표: 자동 조준 대상"을 끄세요.',
  CONFLICT_PLATER = 'Plater가 오브젝트 이름을 처리하고 있습니다. 오브젝트 이름 표시를 사용하려면 Plater에서 "Hide Plater names game objects"를 켜세요.',
  CONFLICT_FOREVER_LOOT_SPARKLES_TARGETING = 'Forever Loot Sparkles가 상호작용 범위, 각도 및 대상 전리품 효과를 처리하고 있습니다. 이 옵션을 변경하려면 Forever Loot Sparkles에서 "Ore veins", "Herbs", "Quest objects", "Corpses with loot"를 끄세요.',
  CONFLICT_FOREVER_LOOT_SPARKLES_QUEST = 'Forever Loot Sparkles가 퀘스트 아이템의 전리품 효과를 처리하고 있습니다. 여기서 변경하려면 Forever Loot Sparkles에서 "Show quest item sparkles"를 끄세요.',

  ----  Settings page  ----
  SETTINGS_SUBTITLE = "여기서 HUD를 설정합니다. 위치 이동은 편집 모드를 사용하세요.",
  SETTINGS_MOVE_HUD = "편집 모드에서 HUD 이동",
  SETTINGS_MOVE_HUD_DESC = "편집 모드에서 HUD를 드래그해 이동시킬 수 있습니다.",
  SETTINGS_OPEN = "설정 열기", --the button on the HUD in Edit Mode
  SETTINGS_PRESS_KEY = "단축키를 눌러 주세요",
  SETTINGS_CLEAR = "해제",
  SETTINGS_RESET = "%s 초기화", --the option's name
  SETTINGS_RESET_DESC = "이 옵션을 기본값(%s)으로 되돌립니다.", --the default value
  SETTINGS_ON = "켜짐",
  SETTINGS_OFF = "꺼짐",

  ----  Settings preview  ----
  PREVIEW_HINT = "클릭으로 다른 대상 표시",
  PREVIEW_ANIMATE = "애니메이션",
  PREVIEW_ANIMATE_DESC = "일정 초마다 상호작용 동작을 재생합니다.",
  PREVIEW_MOVE_CLOSER_DESC = "대상이 멀리 있는 상태로 표시합니다.",
  PREVIEW_REQUIRES = "전문 기술 필요",
  PREVIEW_REQUIRES_DESC = "전문 기술이 없을 때의 메시지를 표시합니다.",
  PREVIEW_CAST = "시전바",
  PREVIEW_CAST_DESC = "채집하거나 여는 대상에 시전바를 표시합니다.",
  PREVIEW_SECRET = "알 수 없는 이름",
  PREVIEW_SECRET_DESC = "게임이 애드온에 이름을 공개하지 않는 대상을 표시합니다.",

  ----  About page  ----
  ABOUT = "정보",
  ABOUT_VERSION = "버전 %s", --the addon's version
  ABOUT_COMMANDS = "명령어",
  ABOUT_COMMAND_SETTINGS = "설정을 엽니다",
  ABOUT_COMMAND_EDIT_MODE = "편집 모드를 엽니다",
  ABOUT_COMMAND_DEBUG = "디버그 창을 엽니다",
  ABOUT_TRANSLATORS = "번역자",
  ABOUT_NO_TRANSLATIONS = "아직 번역이 없습니다",
  ABOUT_HELP_OUT = "도움 주기",
  ABOUT_REPORT_BUG = "버그 신고",
  ABOUT_HELP_TRANSLATE = "번역 참여",
  ABOUT_CURSEFORGE = "CurseForge 페이지",
  ABOUT_COPY_HINT = "링크를 복사하려면 클릭한 뒤 Ctrl+C를 누르세요.",
  ABOUT_DEPENDENCIES = "의존성",
  ABOUT_LIBRARIES = "라이브러리",
  ABOUT_FONTS = "글꼴",

  ----  Chat messages  ----
  CHAT_SETTINGS_IN_COMBAT = "전투 중에는 설정을 열 수 없습니다.",
  CHAT_EDIT_MODE_IN_COMBAT = "전투 중에는 편집 모드를 열 수 없습니다.",
  CHAT_EDIT_MODE_UNAVAILABLE = "편집 모드를 사용할 수 없습니다.",
  CHAT_EDIT_MODE_UNAVAILABLE_NOW = "지금은 편집 모드를 사용할 수 없습니다.",
  CHAT_EDIT_MODE_CLOSE_FIRST = "Enhanced Soft Interact 설정을 열려면 먼저 편집 모드 메인 창을 닫으세요.",
  CHAT_BINDINGS_IN_COMBAT = "전투 중에는 단축키를 변경할 수 없습니다.",
  CHAT_RELOAD = "변경 사항을 적용하려면 /reload를 입력하세요.",
  CHAT_QUEST_LOOT_EFFECT_LOG_OUT = "퀘스트 아이템 전리품 효과는 로그아웃 후 다시 접속하면 사라집니다. /reload만으로는 부족합니다.",
  CHAT_KEY_UNBOUND = '%s은(는) 더 이상 "%s"에 지정되어 있지 않습니다.', --the key, the action
  CHAT_KEPT_INTERACT_KEY = '"%s" 옵션이 다시 켜졌습니다. 끄려면 먼저 /esi에서 "%s" 체크를 해제하세요.', --the game's option, the checkbox
  CHAT_KEPT_INTERACT_ICONS = '"%s" 옵션이 다시 \'모두 표시\'로 설정되었습니다. 변경하려면 먼저 /esi에서 "%s" 체크를 해제하세요.', --the game's option, the checkbox

  ----  The game's option names  ----
  GAME_ENABLE_INTERACT_KEY = "상호작용 단축키 활성화",
  GAME_INTERACT_KEY_ICONS = "상호작용 단축키 아이콘",
  GAME_INTERACT_SOUND = "상호작용 단축키 효과음",

  ----  Gathering nodes  ----
  -- Optional. Nodes are found by ID in every language; names are only a fallback for unknown IDs.
  -- A language file fills its own table, pairing the English name from Data/GatherSkill.lua with the name
  -- the game shows, for example:
  --   NODE_NAMES = {
  --     ["Peacebloom"] = "Friedensblume",
  --     ["Silverleaf"] = "Silberblatt",
  --   },
  NODE_NAMES = {},
});
