local addonName, ns = ...

-- Korean. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "koKR" then return end

local L = ns.L

local T = {
    HELP_STATUS = "|cffffff00/gbis status|r: 클라이언트, 기능 및 API 출처",
    STATUS_CLIENT = "클라이언트: %s (인터페이스 %d)",
    STATUS_FEATURES = "기능: %s",
    STATUS_API = "API: %s",
    STATUS_DATA = "BiS 데이터: %s · 목록 %d개 · 전문화 %d개 · 기본 단계 %d",
    STATUS_DB ="데이터베이스: 스키마 %d · 디스크에서 불러옴: %s · 불러온 횟수: %d · 캐릭터: %d",
    HELP_LOG = "|cffffff00/gbis log [clear]|r: 디버그 기록 창 표시",
    LOG_TITLE = "GudaBiS 디버그 기록",
    LOG_CLEARED = "디버그 기록을 지웠습니다.",
    HELP_PROBE = "|cffffff00/gbis probe|r: 이 클라이언트가 제공하는 WoW API 확인 (디버그 기록에 저장)",
    PROBE_DONE = "확인 결과를 디버그 기록에 저장했습니다 (/gbis log).",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: 디버그 모드 켜기/끄기 (채팅에 디버그 줄 표시)",
    UNKNOWN_COMMAND = "알 수 없는 명령어 '%s'. /gbis help 를 입력하세요.",
    DEBUG_ON = "디버그 모드 켜짐.",
    DEBUG_OFF = "디버그 모드 꺼짐.",
}

for key, value in pairs(T) do
    L[key] = value
end
