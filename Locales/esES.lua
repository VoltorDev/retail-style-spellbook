local _, ns = ...

local locale = GetLocale()
if locale ~= "esES" and locale ~= "esMX" then
    return
end

local L = ns.L

L.LOADED = "cargado. Tu tecla del libro lo abre; /libro también, y /retailspellbook config para opciones."
L.SLASH_HELP = "Comandos: /retailspellbook [config | debug | reset]; sin nada abre el libro"
L.ERR_COMBAT = "No disponible en combate; inténtalo al salir de él."
L.RESET_CONFIRM = "Escribe /retailspellbook reset confirmar para volver a los valores por defecto."
L.RESET_DONE = "Opciones restauradas a los valores por defecto."
L.COMPARTMENT_TOOLTIP = "Clic para abrir las opciones."

L.DEBUG_HEADER = "Diagnóstico (pégalo al informar de un problema):"

L.TITLE = "Libro de hechizos"
L.TAB_CLASS = "Clase"
L.TAB_GENERAL = "General"
L.TAB_PET = "Mascota"
L.PASSIVE = "Pasiva"
L.NOT_LEARNED = "Aún no aprendido"
L.HIDE_PASSIVES = "Ocultar pasivas"
L.NO_RESULTS = "Ningún hechizo coincide."
L.PAGE_FORMAT = "Página %d / %d"
L.ERR_COMBAT_PAGE =
    "En combate no se cambia de página, pestaña ni búsqueda; sí puedes lanzar desde la página abierta."
L.ERR_COMBAT_TOGGLE = "En combate abre el libro con su tecla (el comando no puede)."
L.OPT_REPLACE_KEY = "Abrir con la tecla del libro"
L.OPT_REPLACE_KEY_TT = "La tecla del libro de Blizzard abre este en su lugar. Sin ella, usa /libro."
L.OPT_HIDE_PASSIVES_TT = "Oculta los hechizos pasivos, como la opción del libro de retail."
L.OPT_GROUP_RANKS = "Un hechizo por rango"
L.OPT_GROUP_RANKS_TT = "Junta los rangos de cada hechizo en una sola entrada y deja elegir cuál lanza con un "
    .. "desplegable (por defecto, el más alto)."
L.RANK_PICK = "Elegir rango"
L.RANK_PICK_TT =
    "Clic aquí o clic derecho en el hechizo: elige qué rango lanza este botón. Se recuerda por personaje."
L.ERR_COMBAT_RANK = "En combate no se puede cambiar el rango; sal de combate y vuelve a elegirlo."
L.OPT_SCALE = "Escala"
L.OPT_SCALE_TT = "Tamaño del libro."

L.TRAINING = "Por aprender"
L.TRAINING_COUNT = "Por aprender (%d)"
L.TRAINING_SUMMARY = "%d disponibles ya en tu instructor: %s"
L.TRAINING_HINT = "Clic: abre What's Training con lo que puedes aprender, su coste y dónde."
