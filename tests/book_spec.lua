-- Data.lua y Book.lua: organización como en retail, páginas, búsqueda, botones seguros y tecla del libro.
local WowEnv = require("wow_env")

local TOC = "RetailSpellbook.toc"
local SPELL, FUTURE, PETACTION = 1, 2, 3

local function spell(id, name, extra)
    local info = { itemType = SPELL, spellID = id, actionID = id, name = name, subName = "", iconID = id }
    for k, v in pairs(extra or {}) do
        info[k] = v
    end
    return info
end

-- Un mago de Forever: General y tres escuelas (así lo da C_SpellBook, una línea por pestaña de icono).
local MAGE = {
    lines = {
        { "General", 1, 0, 2 },
        { "Arcano", 2, 2, 3 },
        { "Fuego", 3, 5, 2 },
        { "Escarcha", 4, 7, 2 },
    },
    items = {
        [1] = spell(6603, "Ataque"),
        [2] = spell(20599, "Diplomacia", { isPassive = true, subName = "Racial" }),
        [3] = spell(1459, "Intelecto Arcano", { subName = "Rango 1" }),
        [4] = spell(5143, "Misiles Arcanos", { subName = "Rango 1" }),
        [5] = spell(12345, "Concentración Arcana", { isPassive = true }),
        [6] = spell(133, "Bola de Fuego", { subName = "Rango 2" }),
        [7] = spell(2136, "Explosión de Fuego", { itemType = FUTURE }),
        [8] = spell(116, "Descarga de Escarcha", { subName = "Rango 3" }),
        [9] = spell(122, "Nova de Escarcha"),
    },
    pet = {},
}

local function boot(opts)
    opts = opts or {}
    opts.spellbook = opts.spellbook or MAGE
    opts.locale = opts.locale or "esES"
    opts.bindings = opts.bindings or { TOGGLESPELLBOOK = { "P" } }
    return WowEnv.boot(TOC, opts)
end

local function names(group)
    local list = {}
    for _, item in ipairs(group.items) do
        list[#list + 1] = item.name
    end
    return list
end

-- Último valor puesto en cada atributo de un botón seguro.
local function attributes(button)
    local attrs = {}
    for _, call in ipairs(button:Calls("SetAttribute")) do
        attrs[call[1]] = call[2]
    end
    return attrs
end

local function shownButtons(env)
    local list = {}
    for _, button in ipairs(env:Widgets("Button")) do
        if button.item and button:IsShown() then
            list[#list + 1] = button
        end
    end
    return list
end

-- El cliente simulado no lanza OnShow al mostrar: se hace a mano, como haría el juego.
local function open(env)
    env:RunSlash("/libro")
    local book = env.RetailSpellbookFrame
    book:GetScript("OnShow")(book)
end

local function buttonFor(env, name)
    for _, button in ipairs(shownButtons(env)) do
        if button.item.name == name then
            return button
        end
    end
end

describe("organización como en retail", function()
    it("pestaña de clase con un encabezado por escuela; General sin encabezado", function()
        local _, ns = boot()
        local categories = ns.Data.Collect()
        assert.are.equal(2, #categories) -- sin mascota no hay pestaña de mascota
        local class, general = categories[1], categories[2]
        assert.are.equal("class", class.key)
        assert.are.equal("Mage", class.name)
        assert.are.same(
            { "Arcano", "Fuego", "Escarcha" },
            { class.groups[1].name, class.groups[2].name, class.groups[3].name }
        )
        assert.are.same({ "Intelecto Arcano", "Misiles Arcanos", "Concentración Arcana" }, names(class.groups[1]))
        assert.are.equal("general", general.key)
        assert.is_nil(general.groups[1].name)
        assert.are.same({ "Ataque", "Diplomacia" }, names(general.groups[1]))
    end)

    it("con mascota aparece su pestaña, con los hechizos del banco de mascota", function()
        local book = {}
        for k, v in pairs(MAGE) do
            book[k] = v
        end
        book.pet = {
            [1] = spell(17253, "Morder", { itemType = PETACTION }),
            [2] = spell(2649, "Gruñido", { itemType = PETACTION }),
        }
        local _, ns = boot({ spellbook = book })
        local categories = ns.Data.Collect()
        assert.are.equal(3, #categories)
        assert.are.equal("pet", categories[3].key)
        assert.are.same({ "Morder", "Gruñido" }, names(categories[3].groups[1]))
        assert.are.equal(1, categories[3].groups[1].items[1].bank)
    end)

    it("una línea oculta no sale", function()
        local book = { lines = { { "General", 1, 0, 2 }, { "Oculta", 2, 2, 3, true } }, items = MAGE.items, pet = {} }
        local _, ns = boot({ spellbook = book })
        assert.are.equal(0, #ns.Data.Collect()[1].groups)
    end)
end)

describe("filtros", function()
    it("ocultar pasivas", function()
        local _, ns = boot()
        local groups = ns.Data.Visible(ns.Data.Collect(), "class", { hidePassives = true })
        assert.are.same({ "Intelecto Arcano", "Misiles Arcanos" }, names(groups[1]))
    end)

    it("la búsqueda mira en todas las pestañas, sin distinguir mayúsculas ni tildes", function()
        local _, ns = boot()
        local groups = ns.Data.Visible(ns.Data.Collect(), "class", { query = "ARCANO" })
        assert.are.equal(1, #groups)
        assert.are.equal("Mage - Arcano", groups[1].name)
        groups = ns.Data.Visible(ns.Data.Collect(), "class", { query = "diplomacia" })
        assert.are.equal("General", groups[1].name)
        groups = ns.Data.Visible(ns.Data.Collect(), "class", { query = "explosion" })
        assert.are.same({ "Explosión de Fuego" }, names(groups[1]))
        assert.are.equal(0, #ns.Data.Visible(ns.Data.Collect(), "class", { query = "zzz" }))
    end)
end)

describe("páginas", function()
    local function items(n)
        local list = {}
        for i = 1, n do
            list[i] = { name = "h" .. i }
        end
        return list
    end

    it("tres columnas por fila y el encabezado ocupa su propia fila", function()
        local _, ns = boot()
        local pages = ns.Data.Paginate({ { name = "A", items = items(4) } }, 8, 3)
        assert.are.equal(1, #pages)
        local page = pages[1]
        assert.are.same({ "header", 0 }, { page[1].kind, page[1].row })
        assert.are.same({ 1, 0 }, { page[2].row, page[2].col })
        assert.are.same({ 1, 2 }, { page[4].row, page[4].col })
        assert.are.same({ 2, 0 }, { page[5].row, page[5].col })
    end)

    it("un encabezado nunca queda solo al pie de la página", function()
        local _, ns = boot()
        -- 7 filas de A (encabezado + 6 filas) dejan una libre: B pasa entero a la página siguiente.
        local pages = ns.Data.Paginate({ { name = "A", items = items(18) }, { name = "B", items = items(2) } }, 8, 3)
        assert.are.equal(2, #pages)
        assert.are.same({ "header", "B", 0 }, { pages[2][1].kind, pages[2][1].text, pages[2][1].row })
    end)

    it("un grupo largo sigue en la página siguiente sin repetir encabezado", function()
        local _, ns = boot()
        local pages = ns.Data.Paginate({ { name = "A", items = items(30) } }, 8, 3)
        assert.are.equal(2, #pages)
        assert.are.equal("item", pages[2][1].kind)
        assert.are.equal(0, pages[2][1].row)
    end)
end)

describe("libro en pantalla", function()
    it("al abrirlo pinta la pestaña de clase con botones seguros que lanzan el hechizo", function()
        local env = boot()
        open(env)
        local bola = buttonFor(env, "Bola de Fuego")
        assert(bola, "falta el botón de Bola de Fuego")
        local attrs = attributes(bola)
        assert.are.equal("spell", attrs.type)
        assert.are.equal(133, attrs.spell)
        assert.are.equal("Rango 2", bola.SubName:GetText())
        assert.is_nil(buttonFor(env, "Ataque")) -- es de la pestaña General
        assert.are.equal(1, env.RetailSpellbookFrame._selectedTab)
        assert.is_false(env.RetailSpellbookFrame._tabShown[3]) -- sin mascota
    end)

    it("botón de cerrar seguro, visible y por encima del marco", function()
        local env = boot()
        open(env)
        local close = env.RetailSpellbookFrame.SecureCloseButton
        assert(close, "falta el botón de cerrar")
        assert.is_true(close:IsShown())
        assert.are.equal("UIPanelCloseButtonNoScripts, SecureHandlerClickTemplate", close._template)
        local level = close:LastCall("SetFrameLevel")
        assert(level and level >= 520, "el botón de cerrar queda por debajo del marco")
        assert.are.equal(" self:GetParent():Hide() ", attributes(close)._onclick)
        assert(close:GetNumPoints() > 0 or close:LastCall("SetAllPoints"), "el botón de cerrar no tiene posición")
    end)

    it("pasivas y no aprendidos se ven pero no lanzan nada", function()
        local env = boot()
        open(env)
        local passive = buttonFor(env, "Concentración Arcana")
        assert.is_nil(attributes(passive).type)
        assert.are.equal(env.RetailSpellbookFrame and "Pasiva", passive.SubName:GetText())
        local future = buttonFor(env, "Explosión de Fuego")
        assert.is_nil(attributes(future).type)
        assert.are.equal("Aún no aprendido", future.SubName:GetText())
    end)

    it("la pestaña General y la casilla de ocultar pasivas", function()
        local env, ns = boot()
        open(env)
        env.RetailSpellbookFrame.Tabs[2]:GetScript("OnClick")(env.RetailSpellbookFrame.Tabs[2])
        assert(buttonFor(env, "Ataque"))
        assert.is_nil(buttonFor(env, "Bola de Fuego"))
        local check = env.RetailSpellbookFrame.HidePassives
        check:SetChecked(true)
        check.GetChecked = function()
            return true
        end
        check:GetScript("OnClick")(check)
        assert.is_true(ns.db.hidePassives)
        assert.is_nil(buttonFor(env, "Diplomacia"))
    end)

    it("la X del buscador (texto borrado por código) quita el filtro", function()
        local env = boot()
        open(env)
        local search = env.RetailSpellbookFrame.SearchBox
        local changed = search:GetScript("OnTextChanged")
        search:SetText("escarcha")
        changed(search, true)
        assert.is_nil(buttonFor(env, "Bola de Fuego"))
        search:SetText("")
        changed(search, false) -- la X de SearchBoxTemplate lo hace sin userInput
        assert(buttonFor(env, "Bola de Fuego"), "el filtro sigue tras borrar con la X")
    end)

    it("arrastrar recoge el hueco del libro", function()
        local env = boot()
        open(env)
        local bola = buttonFor(env, "Bola de Fuego")
        bola:GetScript("OnDragStart")(bola)
        assert.is_not_nil(bola.item)
    end)

    it("en combate no cambia de pestaña y lo explica; al salir aplica lo pendiente", function()
        local env, ns = boot()
        open(env)
        env:ClearPrinted()
        env:SetCombat(true)
        env.RetailSpellbookFrame.Tabs[2]:GetScript("OnClick")(env.RetailSpellbookFrame.Tabs[2])
        assert(buttonFor(env, "Bola de Fuego")) -- sigue la de clase
        local printed = env:Printed()
        assert(printed:find(ns.L.ERR_COMBAT_PAGE, 1, true))
        env:Fire("SPELLS_CHANGED")
        assert.is_true(ns.Book.pending)
        env:SetCombat(false)
        env:Fire("PLAYER_REGEN_ENABLED")
        assert.is_false(ns.Book.pending)
    end)
end)

describe("tecla del libro", function()
    it("la tecla del libro de Blizzard abre este", function()
        local env = boot({ bindings = { TOGGLESPELLBOOK = { "P", "SHIFT-P" } } })
        local overrides = env:Overrides()
        assert.are.equal("RetailSpellbookToggle", overrides.P.button)
        assert.are.equal("RetailSpellbookToggle", overrides["SHIFT-P"].button)
    end)

    it("sin la opción la tecla vuelve al libro de Blizzard", function()
        local env = boot()
        env:SettingsRegistry().settings[env:AddonName() .. "_ReplaceKey"]:SetValue(false)
        assert.is_nil(env:Overrides().P)
    end)

    it("si cambias la tecla en combate se aplica al salir", function()
        local env = boot()
        env:SetCombat(true)
        env:SetBindings({ TOGGLESPELLBOOK = { "L" } })
        env:Fire("UPDATE_BINDINGS")
        assert.is_not_nil(env:Overrides().P)
        env:SetCombat(false)
        env:Fire("PLAYER_REGEN_ENABLED")
        assert.is_nil(env:Overrides().P)
        assert.are.equal("RetailSpellbookToggle", env:Overrides().L.button)
    end)

    it("el botón de la tecla abre y cierra con un fragmento seguro (vale en combate)", function()
        local env = boot()
        local toggle = env.RetailSpellbookToggle
        local snippet = attributes(toggle)._onclick
        assert(snippet:find("book:Show()", 1, true))
        assert(snippet:find("book:Hide()", 1, true))
    end)
end)

-- What's Training? dibuja su lista encima del libro de Blizzard; con este libro abierto en su lugar
-- no se veía. El libro ofrece un botón que abre su ventana, con el recuento de su API pública.
describe("What's Training?", function()
    -- WT_API simulada con la forma de su Api.lua (version 1): Status, Event, IsReady, GetSpells,
    -- RegisterCallback(owner, event, fn).
    local function fakeApi(spells)
        local api = { callbacks = {}, ready = true }
        api.Status = { AVAILABLE = "available", NEXTLEVEL = "nextLevel", KNOWN = "known" }
        api.Event = { READY = "Ready", SPELLS_CHANGED = "SpellsChanged", LEVEL_CHANGED = "LevelChanged" }
        api.IsReady = function()
            return api.ready
        end
        api.GetSpells = function()
            return spells
        end
        api.RegisterCallback = function(_, event, fn)
            api.callbacks[event] = fn
        end
        return api
    end

    local function bootWith(api)
        local env, ns = boot({
            globals = {
                WT_API = api,
                GetMoneyString = function(copper)
                    return copper .. "c"
                end,
            },
        })
        local opened = 0
        env.SlashCmdList.WHATSTRAINING = function()
            opened = opened + 1
        end
        return env, ns, function()
            return opened
        end
    end

    local SPELLS = {
        { id = 1, status = "available", cost = 100 },
        { id = 2, status = "available", cost = 250 },
        { id = 3, status = "nextLevel", cost = 900 },
        { id = 4, status = "known", cost = 50 },
    }

    it("sin What's Training no hay botón", function()
        local env = boot()
        open(env)
        assert.is_false(env.RetailSpellbookFrame.TrainingButton:IsShown())
    end)

    it("con What's Training el botón cuenta lo disponible y abre su ventana", function()
        local env, ns, opened = bootWith(fakeApi(SPELLS))
        open(env)
        local button = env.RetailSpellbookFrame.TrainingButton
        assert.is_true(button:IsShown())
        assert.are.equal("Por aprender (2)", button:GetText())
        local count, cost = ns.Training.Summary()
        assert.are.same({ 2, 350 }, { count, cost })
        button:GetScript("OnClick")(button)
        assert.are.equal(1, opened())
        button:GetScript("OnEnter")(button)
        local first = env.GameTooltip:Calls("AddLine")[1]
        assert.are.equal("2 disponibles ya en tu instructor: 350c", first[1])
    end)

    it("su ventana se abre al lado del libro y por encima, no tapada", function()
        local env = bootWith(fakeApi(SPELLS))
        local frame = env.CreateFrame("Frame", "WhatsTrainingFloatingFrame", env.UIParent)
        frame:Hide()
        local raised = 0
        frame.Raise = function()
            raised = raised + 1
        end
        env.SlashCmdList.WHATSTRAINING = function()
            frame:SetShown(not frame:IsShown())
        end
        open(env)
        local button = env.RetailSpellbookFrame.TrainingButton
        button:GetScript("OnClick")(button)
        assert.is_true(frame:IsShown())
        assert.are.equal(1, raised)
        local point, relativeTo, relativePoint = frame:GetPoint(1)
        assert.are.same({ "TOPLEFT", env.RetailSpellbookFrame, "TOPRIGHT" }, { point, relativeTo, relativePoint })
    end)

    it("si el usuario ya movió su ventana, no se recoloca", function()
        local env = bootWith(fakeApi(SPELLS))
        env.WT_FloatingFramePoint = { "CENTER", "CENTER", 0, 0 }
        local frame = env.CreateFrame("Frame", "WhatsTrainingFloatingFrame", env.UIParent)
        frame:SetPoint("CENTER")
        frame:Hide()
        frame.Raise = function() end
        env.SlashCmdList.WHATSTRAINING = function()
            frame:Show()
        end
        open(env)
        local button = env.RetailSpellbookFrame.TrainingButton
        button:GetScript("OnClick")(button)
        assert.are.equal("CENTER", (frame:GetPoint(1)))
    end)

    it("se actualiza cuando What's Training avisa de un cambio", function()
        local spells = { { id = 1, status = "available", cost = 100 } }
        local api = fakeApi(spells)
        local env = bootWith(api)
        open(env)
        local button = env.RetailSpellbookFrame.TrainingButton
        assert.are.equal("Por aprender (1)", button:GetText())
        spells[1].status = "known"
        api.callbacks.SpellsChanged("SpellsChanged", { 1 })
        assert.are.equal("Por aprender (0)", button:GetText())
    end)

    it("si su API no está lista o falla, el botón sigue y abre la ventana", function()
        local api = fakeApi(SPELLS)
        api.ready = false
        local env, ns, opened = bootWith(api)
        open(env)
        local button = env.RetailSpellbookFrame.TrainingButton
        assert.are.equal("Por aprender", button:GetText())
        api.ready = true
        api.GetSpells = function()
            error("API cambiada")
        end
        assert.is_nil(ns.Training.Summary())
        button:GetScript("OnClick")(button)
        assert.are.equal(1, opened())
    end)
end)

-- Forever da cada rango como una entrada aparte; el libro deja una por hechizo con desplegable.
describe("un hechizo por rango", function()
    local RANKED = {
        lines = { { "General", 1, 0, 1 }, { "Fuego", 3, 1, 5 } },
        items = {
            [1] = spell(6603, "Ataque"),
            [2] = spell(143, "Bola de Fuego", { subName = "Rango 2" }),
            [3] = spell(133, "Bola de Fuego", { subName = "Rango 1" }),
            [4] = spell(145, "Bola de Fuego", { subName = "Rango 3" }),
            [5] = spell(3140, "Bola de Fuego", { subName = "Rango 4", itemType = FUTURE }),
            [6] = spell(2136, "Explosión de Fuego", { subName = "Rango 1" }),
        },
        pet = {},
    }

    -- MenuUtil falso: guarda el generador y lo ejecuta con un menú que anota lo que se crea.
    local function bootRanked()
        local menu = {}
        local env, ns = boot({
            spellbook = RANKED,
            globals = {
                MenuUtil = {
                    CreateContextMenu = function(owner, generator)
                        menu.owner, menu.title, menu.radios = owner, nil, {}
                        local root = {}
                        function root.CreateTitle(_, text)
                            menu.title = text
                        end
                        function root.CreateRadio(_, text, isSelected, setSelected, data)
                            local radio = { text = text, enabled = true, selected = isSelected(data) }
                            radio.pick = function()
                                setSelected(data)
                            end
                            function radio.SetEnabled(self, value)
                                self.enabled = value
                            end
                            menu.radios[#menu.radios + 1] = radio
                            return radio
                        end
                        generator(owner, root)
                    end,
                },
            },
        })
        return env, ns, menu
    end

    local function ranksOf(item)
        local list = {}
        for _, rank in ipairs(item.ranks) do
            list[#list + 1] = rank.subName
        end
        return list
    end

    it("junta los rangos en una entrada, ordenados, y elige el aprendido más alto", function()
        local _, ns = bootRanked()
        local groups = ns.Data.Visible(ns.Data.Collect(), "class", { groupRanks = true })
        assert.are.same({ "Bola de Fuego", "Explosión de Fuego" }, names(groups[1]))
        local bola = groups[1].items[1]
        assert.are.same({ "Rango 1", "Rango 2", "Rango 3", "Rango 4" }, ranksOf(bola))
        assert.are.equal(145, bola.spellID) -- rango 3: el 4 aún no está aprendido
        assert.is_nil(groups[1].items[2].ranks) -- un solo rango: sin desplegable
    end)

    it("respeta el rango elegido y, si no está aprendido, vuelve al más alto", function()
        local _, ns = bootRanked()
        local categories = ns.Data.Collect()
        local function pick(id)
            local options = { groupRanks = true, chosenRanks = { ["Bola de Fuego"] = id } }
            return ns.Data.Visible(categories, "class", options)[1].items[1].spellID
        end
        assert.are.equal(133, pick(133))
        assert.are.equal(145, pick(3140)) -- el 4 no se puede lanzar
        assert.are.equal(145, pick(999)) -- uno que ya no existe
    end)

    it("sin la opción sale cada rango por separado", function()
        local _, ns = bootRanked()
        local groups = ns.Data.Visible(ns.Data.Collect(), "class", { groupRanks = false })
        assert.are.equal(5, #groups[1].items)
    end)

    it("si ningún rango está aprendido, se ve el más bajo", function()
        local _, ns = bootRanked()
        local merged = ns.Data.MergeRanks({
            { itemType = FUTURE, spellID = 2, name = "Nova", subName = "Rango 2" },
            { itemType = FUTURE, spellID = 1, name = "Nova", subName = "Rango 1" },
        })
        assert.are.equal(1, #merged)
        assert.are.equal(1, merged[1].spellID)
    end)

    it("en pantalla: un solo botón, con flecha, que lanza el rango elegido", function()
        local env = bootRanked()
        open(env)
        local count = 0
        for _, button in ipairs(shownButtons(env)) do
            if button.item.name == "Bola de Fuego" then
                count = count + 1
            end
        end
        assert.are.equal(1, count)
        local bola = buttonFor(env, "Bola de Fuego")
        local attrs = attributes(bola)
        assert.are.equal("spell", attrs.type)
        assert.are.equal(145, attrs.spell)
        assert.are.equal("none", attrs.type2) -- clic derecho = desplegable, no lanza
        assert.are.equal("Rango 3", bola.SubName:GetText())
        assert.is_true(bola.RankButton:IsShown())
        assert.is_false(buttonFor(env, "Explosión de Fuego").RankButton:IsShown())
    end)

    it("clic derecho abre el desplegable; elegir un rango lo guarda y lo lanza", function()
        local env, ns, menu = bootRanked()
        open(env)
        local bola = buttonFor(env, "Bola de Fuego")
        bola:GetScript("PostClick")(bola, "RightButton")
        assert.are.equal("Bola de Fuego", menu.title)
        assert.are.equal(4, #menu.radios)
        assert.are.equal("Rango 4 (Aún no aprendido)", menu.radios[1].text) -- del más alto al más bajo
        assert.is_false(menu.radios[1].enabled)
        assert.is_true(menu.radios[2].selected)
        menu.radios[4].pick() -- rango 1
        assert.are.equal(133, ns.charDB.ranks["Bola de Fuego"])
        bola = buttonFor(env, "Bola de Fuego")
        assert.are.equal(133, attributes(bola).spell)
        assert.are.equal("Rango 1", bola.SubName:GetText())
    end)

    it("la flecha abre el mismo desplegable", function()
        local env, _, menu = bootRanked()
        open(env)
        local bola = buttonFor(env, "Bola de Fuego")
        bola.RankButton:GetScript("OnClick")(bola.RankButton)
        assert.are.equal("Bola de Fuego", menu.title)
    end)

    it("en combate no cambia el rango y lo explica", function()
        local env, ns, menu = bootRanked()
        open(env)
        local bola = buttonFor(env, "Bola de Fuego")
        bola:GetScript("PostClick")(bola, "RightButton")
        env:ClearPrinted()
        env:SetCombat(true)
        menu.radios[4].pick()
        assert(env:Printed():find(ns.L.ERR_COMBAT_RANK, 1, true))
        assert.is_nil(ns.charDB.ranks and ns.charDB.ranks["Bola de Fuego"])
        assert.are.equal(145, attributes(bola).spell)
    end)
end)
