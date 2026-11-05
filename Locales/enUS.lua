local _, ns = ...

-- Tabla de textos: si falta una clave, devuelve la propia clave en vez de nil
-- (un texto sin traducir se ve, pero no rompe el addon).
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
ns.L = L

L.ADDON_TITLE = "Retail-Style Spellbook"
L.LOADED = "loaded. Your spellbook key opens it; /libro toggles it, /retailspellbook config for options."
L.SLASH_HELP = "Commands: /retailspellbook [config | debug | reset]; nothing opens the book"
L.ERR_COMBAT = "Not available in combat; try again when combat ends."
L.RESET_CONFIRM = "Type /retailspellbook reset confirm to restore the defaults."
L.RESET_DONE = "Settings restored to defaults."
L.COMPARTMENT_TOOLTIP = "Click to open the options."

L.DEBUG_HEADER = "Diagnostics (paste this when reporting a problem):"

L.TITLE = "Spellbook"
L.TAB_CLASS = "Class"
L.TAB_GENERAL = "General"
L.TAB_PET = "Pet"
L.PASSIVE = "Passive"
L.NOT_LEARNED = "Not learned yet"
L.HIDE_PASSIVES = "Hide passives"
L.NO_RESULTS = "No spells match."
L.PAGE_FORMAT = "Page %d / %d"
L.ERR_COMBAT_PAGE = "Pages, tabs and search are locked in combat; you can still cast from the open page."
L.ERR_COMBAT_TOGGLE = "In combat, open the book with its key (the slash command cannot)."
L.OPT_REPLACE_KEY = "Open with the spellbook key"
L.OPT_REPLACE_KEY_TT =
    "The key bound to the Blizzard spellbook opens this one instead. Without it, use /libro or /retailspellbook."
L.OPT_HIDE_PASSIVES_TT = "Hides passive spells, as the option of the retail spellbook."
L.OPT_SCALE = "Scale"
L.OPT_SCALE_TT = "Size of the spellbook."
