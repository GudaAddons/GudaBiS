local addonName, ns = ...

-- Portuguese (Brazil). Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "ptBR" then return end

local L = ns.L

local T = {
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: ativa ou desativa o modo de depuração (linhas de depuração no chat)",
    UNKNOWN_COMMAND = "Comando desconhecido '%s'. Digite /gbis help.",
    DEBUG_ON = "Modo de depuração ativado.",
    DEBUG_OFF = "Modo de depuração desativado.",
}

for key, value in pairs(T) do
    L[key] = value
end
