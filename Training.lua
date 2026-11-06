local _, ns = ...

-- Puente con What's Training? (addon de terceros, MIT). En Forever, ese addon dibuja su lista de
-- «qué puedes aprender y cuánto cuesta» encima del libro de Blizzard (PlayerSpellsFrame.SpellBookFrame).
-- Como la tecla del libro abre este en su lugar, esa lista no llega a verse. Aquí no se copia nada de
-- él: se usa su API pública (WT_API, de solo lectura) para el recuento y su comando /wt para abrir su
-- propia ventana, la que su autor usa en Forever porque abrir el libro de Blizzard deja taint.

local Training = {}

local function Api()
    local api = rawget(_G, "WT_API")
    if type(api) ~= "table" then
        return nil
    end
    return api
end

-- ¿Está cargado What's Training? Basta su comando: es lo que se usa para abrir su ventana.
function Training.IsAvailable()
    local slash = SlashCmdList and SlashCmdList.WHATSTRAINING
    return type(slash) == "function"
end

-- Hechizos disponibles ahora en el instructor y su coste total en cobre, o nil si su API no está
-- lista. Protegido con pcall: un cambio en el addon ajeno no debe romper este libro.
function Training.Summary()
    local api = Api()
    if not api then
        return nil
    end
    local ok, count, cost = pcall(function()
        if not api.IsReady() then
            return nil
        end
        local available = api.Status.AVAILABLE
        local n, copper = 0, 0
        for _, spell in ipairs(api.GetSpells()) do
            if spell.status == available then
                n = n + 1
                copper = copper + (tonumber(spell.cost) or 0)
            end
        end
        return n, copper
    end)
    if not ok then
        return nil
    end
    return count, cost
end

-- Abre o cierra la ventana de What's Training. Devuelve false si no está cargado.
function Training.Open()
    if not Training.IsAvailable() then
        return false
    end
    SlashCmdList.WHATSTRAINING("")
    return true
end

-- Avisa (una sola vez) cuando cambian sus datos: subir de nivel, aprender o ignorar un hechizo.
local subscribed = false
function Training.Subscribe(callback)
    local api = Api()
    if subscribed or not api or type(api.RegisterCallback) ~= "function" then
        return subscribed
    end
    local events = api.Event or {}
    for _, event in ipairs({ events.READY, events.SPELLS_CHANGED, events.LEVEL_CHANGED, events.IGNORED_CHANGED }) do
        if event then
            pcall(api.RegisterCallback, Training, event, callback)
        end
    end
    subscribed = true
    return true
end

ns.Training = Training
