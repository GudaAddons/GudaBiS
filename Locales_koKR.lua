local addonName, ns = ...

-- Korean. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "koKR" then return end

local L = ns.L

local T = {
    HELP_STATUS = "|cffffff00/gbis status|r: 클라이언트, 기능 및 API 출처",
    STATUS_CLIENT = "클라이언트: %s (인터페이스 %d)",
    STATUS_FEATURES = "기능: %s",
    STATUS_API = "API: %s",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: 디버그 모드 켜기/끄기 (채팅에 디버그 줄 표시)",
    UNKNOWN_COMMAND = "알 수 없는 명령어 '%s'. /gbis help 를 입력하세요.",
    DEBUG_ON = "디버그 모드 켜짐.",
    DEBUG_OFF = "디버그 모드 꺼짐.",
}

for key, value in pairs(T) do
    L[key] = value
end
