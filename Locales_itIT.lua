local addonName, ns = ...

-- Italian. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "itIT" then return end

local L = ns.L

local T = {
    OWNED_EQUIPPED = "Lo indossi",
    OWNED_BAGS = "Nelle tue borse",
    OWNED_BANK = "Nella tua banca",
    OWNED_ALT = "Ce l'ha %s",
    OWNED_MANUAL = "Segnato come posseduto",
    OWNED_SKIP = "Segnato come non necessario",
    OWNED_ALTERNATIVE = "Hai un'alternativa: %s",
    OWNED_USING = "Indossi un'alternativa: %s",
    HINT_MARK = "Clic destro: segna come posseduto o non necessario",
    HELP_SHOW = "|cffffff00/gbis|r: mostra o nasconde il pannello dell'equipaggiamento migliore",
    PANEL_TITLE = "Equipaggiamento migliore (BiS)",
    PHASE = "Fase %d",
    PHASE_PRERAID = "Prima delle incursioni",
    NO_LIST = "Non c'è ancora una lista dell'equipaggiamento migliore per la tua classe in questa fase.",
    HINT_RANKED = "Clic: mostra la classifica degli oggetti per questo spazio",
    NEW_LIST = "Nuova lista",
    DEFAULT_LIST_NAME = "La mia lista %d",
    RENAME_LIST = "Rinomina lista",
    DELETE_CONFIRM = "Eliminare la lista \"%s\"?",
    COPY_CURRENT = "Copia la lista mostrata",
    TOOLTIP_NEW_LIST = "Nuova lista",
    TOOLTIP_RENAME = "Rinomina questa lista",
    TOOLTIP_DELETE = "Elimina questa lista",
    ROLE_MS = "SP",
    ROLE_OS = "SS",
    TOOLTIP_MS = "Specializzazione principale: avvisi di bottino e tiri usano questa lista. Clicca di nuovo per toglierla.",
    TOOLTIP_OS = "Specializzazione secondaria: avvisi di bottino e tiri usano questa lista per gli oggetti secondari. Clicca di nuovo per toglierla.",
    HINT_CHOOSE = "Clic: scegli un oggetto per questo spazio",
    HINT_PICK = "Clic: metti questo oggetto nello spazio",
    PICK_CLEAR = "Svuota questo spazio",
    PICK_ID = "ID oggetto o link Wowhead",
    PICK_HINT = "Oppure Maiusc-clic o trascina qui un oggetto.",
    PICK_WRONG_SLOT = "L'oggetto %d non va in questo spazio.",
    TOOLTIP_ITEM_LOADING = "Oggetto %d (caricamento...)",
    TOOLTIP_TOGGLE = "GudaBiS: mostra o nasconde l'equipaggiamento migliore",
    HELP_STATUS = "|cffffff00/gbis status|r: client, funzionalità e origine delle API",
    STATUS_CLIENT = "Client: %s (interfaccia %d)",
    STATUS_FEATURES = "Funzionalità: %s",
    STATUS_API = "API: %s",
    STATUS_DATA = "Dati BiS: %s · %d liste · %d specializzazioni · fase predefinita %d",
    STATUS_DB ="Database: schema %d · caricato dal disco: %s · caricamenti: %d · personaggi: %d",
    HELP_LOG = "|cffffff00/gbis log [clear]|r: mostra la finestra del registro di debug",
    LOG_TITLE = "Registro di debug di GudaBiS",
    LOG_CLEARED = "Registro di debug svuotato.",
    HELP_PROBE = "|cffffff00/gbis probe|r: quali API di WoW offre questo client (nel registro di debug)",
    PROBE_DONE = "Verifica scritta nel registro di debug (/gbis log).",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r: attiva o disattiva la modalità debug (righe di debug in chat)",
    UNKNOWN_COMMAND = "Comando sconosciuto '%s'. Digita /gbis help.",
    DEBUG_ON = "Modalità debug attivata.",
    DEBUG_OFF = "Modalità debug disattivata.",
}

for key, value in pairs(T) do
    L[key] = value
end
