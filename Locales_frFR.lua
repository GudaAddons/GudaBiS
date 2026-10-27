local addonName, ns = ...

-- French. Only the keys below are replaced; any other key keeps the English text.
if ns.locale ~= "frFR" then return end

local L = ns.L

local T = {
    OWNED_EQUIPPED = "Vous le portez",
    OWNED_BAGS = "Dans vos sacs",
    OWNED_BANK = "Dans votre banque",
    OWNED_ALT = "Chez %s",
    OWNED_MANUAL = "Marqué comme possédé",
    OWNED_SKIP = "Marqué comme inutile",
    OWNED_ALTERNATIVE = "Vous avez une alternative : %s",
    HINT_MARK = "Clic droit : marquer comme possédé ou inutile",
    HELP_SHOW = "|cffffff00/gbis|r : affiche ou masque le panneau du meilleur équipement",
    PANEL_TITLE = "Meilleur équipement (BiS)",
    PHASE = "Phase %d",
    PHASE_PRERAID = "Avant les raids",
    NO_LIST = "Pas encore de liste de meilleur équipement pour votre classe dans cette phase.",
    HINT_RANKED = "Clic : afficher le classement des objets de cet emplacement",
    TOOLTIP_ITEM_LOADING = "Objet %d (chargement...)",
    TOOLTIP_TOGGLE = "GudaBiS : affiche ou masque le meilleur équipement",
    HELP_STATUS = "|cffffff00/gbis status|r : client, fonctionnalités et sources de l'API",
    STATUS_CLIENT = "Client : %s (interface %d)",
    STATUS_FEATURES = "Fonctionnalités : %s",
    STATUS_API = "API : %s",
    STATUS_DATA = "Données BiS : %s · %d listes · %d spécialisations · phase par défaut %d",
    STATUS_DB ="Base de données : schéma %d · chargée depuis le disque : %s · chargements : %d · personnages : %d",
    HELP_LOG = "|cffffff00/gbis log [clear]|r : affiche la fenêtre du journal de débogage",
    LOG_TITLE = "Journal de débogage GudaBiS",
    LOG_CLEARED = "Journal de débogage effacé.",
    HELP_PROBE = "|cffffff00/gbis probe|r : quelles API WoW ce client propose (dans le journal de débogage)",
    PROBE_DONE = "Vérification écrite dans le journal de débogage (/gbis log).",
    HELP_DEBUG = "|cffffff00/gbis debug [on|off]|r : active ou désactive le mode débogage (lignes de débogage dans le chat)",
    UNKNOWN_COMMAND = "Commande inconnue « %s ». Tapez /gbis help.",
    DEBUG_ON = "Mode débogage activé.",
    DEBUG_OFF = "Mode débogage désactivé.",
}

for key, value in pairs(T) do
    L[key] = value
end
