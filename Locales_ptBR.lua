local addonName, ns = ...

-- Portuguese (Brazil). Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "ptBR" then return end

local L = ns.L

local T = {
    OWNED_EQUIPPED = "Você está usando",
    OWNED_BAGS = "Nas suas bolsas",
    OWNED_BANK = "No seu banco",
    OWNED_ALT = "Com %s",
    OWNED_MANUAL = "Marcado como obtido",
    OWNED_SKIP = "Marcado como desnecessário",
    OWNED_ALTERNATIVE = "Você tem uma alternativa: %s",
    HINT_MARK = "Clique direito: marcar como obtido ou desnecessário",
    HELP_SHOW = "|cffffff00/gbis|r: mostra ou oculta o painel do melhor equipamento",
    PANEL_TITLE = "Melhor equipamento (BiS)",
    PHASE = "Fase %d",
    PHASE_PRERAID = "Pré-raide",
    NO_LIST = "Ainda não há lista de melhor equipamento para sua classe nesta fase.",
    HINT_RANKED = "Clique: mostra a classificação de itens deste espaço",
    TOOLTIP_ITEM_LOADING = "Item %d (carregando...)",
    TOOLTIP_TOGGLE = "GudaBiS: mostra ou oculta o melhor equipamento",
    HELP_STATUS = "|cffffff00/gbis status|r: cliente, recursos e origem da API",
    STATUS_CLIENT = "Cliente: %s (interface %d)",
    STATUS_FEATURES = "Recursos: %s",
    STATUS_API = "API: %s",
    STATUS_DATA = "Dados BiS: %s · %d listas · %d especializações · fase padrão %d",
    STATUS_DB ="Banco de dados: esquema %d · carregado do disco: %s · carregamentos: %d · personagens: %d",
    HELP_LOG = "|cffffff00/gbis log [clear]|r: mostra a janela do registro de depuração",
    LOG_TITLE = "Registro de depuração do GudaBiS",
    LOG_CLEARED = "Registro de depuração limpo.",
    HELP_PROBE = "|cffffff00/gbis probe|r: quais APIs do WoW este cliente oferece (no registro de depuração)",
    PROBE_DONE = "Verificação gravada no registro de depuração (/gbis log).",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: ativa ou desativa o modo de depuração (linhas de depuração no chat)",
    UNKNOWN_COMMAND = "Comando desconhecido '%s'. Digite /gbis help.",
    DEBUG_ON = "Modo de depuração ativado.",
    DEBUG_OFF = "Modo de depuração desativado.",
}

for key, value in pairs(T) do
    L[key] = value
end
