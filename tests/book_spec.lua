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
