local _, ns = ...
local L = ns.L

-- Qué hay en el libro y cómo se reparte en páginas, sin tocar marcos (se prueba fuera del juego).
--
-- Forever enseña una pestaña por línea de habilidad (General, cada escuela de la clase, mascota).
-- Retail las agrupa: una pestaña con toda la clase, con un encabezado por línea, otra General y otra
-- Mascota. Aquí se lee el libro con C_SpellBook y se arma esa forma.
local Data = {}
ns.Data = Data

local GENERAL_INDEX = 1 -- Enum.SpellBookSkillLineIndex.General

local function Bank(name)
    local banks = Enum.SpellBookSpellBank
    return banks and banks[name] or (name == "Pet" and 1 or 0)
end

local function ItemTypes()
    return Enum.SpellBookItemType or { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 }
end

-- Un hueco del libro, o nil si está vacío.
function Data.ReadItem(slot, bank)
    local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
    if not info or info.itemType == ItemTypes().None then
        return nil
    end
    return {
        slot = slot,
        bank = bank,
        itemType = info.itemType,
        spellID = info.spellID,
        actionID = info.actionID,
        name = info.name or "",
        subName = info.subName or "",
        icon = info.iconID,
        isPassive = info.isPassive or false,
        isOffSpec = info.isOffSpec or false,
    }
end

local function ReadRange(first, count, bank)
    local items = {}
    for slot = first, first + count - 1 do
        local item = Data.ReadItem(slot, bank)
        if item then
            items[#items + 1] = item
        end
    end
    return items
end

-- Pestañas al estilo retail: { key, name, groups = { { name, items } } }. La de mascota solo si hay.
function Data.Collect()
    -- El nombre de "player" no debería ser secreto; si lo fuera, se usa el texto propio.
    local className = UnitClass("player")
    local classTitle = (className and not issecretvalue(className)) and className or L.TAB_CLASS
    local class = { key = "class", name = classTitle, groups = {} }
    local general = { key = "general", name = GENERAL_SPELLS or L.TAB_GENERAL, groups = {} }
    local player = Bank("Player")

    for index = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(index)
        if line and not line.shouldHide and not line.isGuild then
            local group = {
                name = line.name,
                offSpec = line.offSpecID ~= nil,
                items = ReadRange(line.itemIndexOffset + 1, line.numSpellBookItems, player),
            }
            if index == GENERAL_INDEX then
                group.name = nil -- como en retail: la pestaña General no lleva encabezado
                general.groups[#general.groups + 1] = group
            else
                class.groups[#class.groups + 1] = group
            end
        end
    end

    local categories = { class, general }
    local numPet = C_SpellBook.HasPetSpells()
    if numPet and numPet > 0 then
        categories[#categories + 1] = {
            key = "pet",
            name = PET or L.TAB_PET,
            groups = { { items = ReadRange(1, numPet, Bank("Pet")) } },
        }
    end
    return categories
end

-- Minúsculas y sin tildes, para buscar "escarcha" y encontrar "Escarcha" o "nova" en "Nova de Escarcha".
local ACCENTS = {
    ["á"] = "a",
    ["é"] = "e",
    ["í"] = "i",
    ["ó"] = "o",
    ["ú"] = "u",
    ["ü"] = "u",
    ["Á"] = "a",
    ["É"] = "e",
    ["Í"] = "i",
    ["Ó"] = "o",
    ["Ú"] = "u",
    ["Ü"] = "u",
    ["ñ"] = "n",
    ["Ñ"] = "n",
}
function Data.Normalize(text)
    -- Primero las tildes: string.lower trabaja por bytes y podría tocar los de una letra UTF-8.
    text = text or ""
    for accented, plain in pairs(ACCENTS) do
        text = text:gsub(accented, plain)
    end
    return text:lower()
end

local function Keep(item, options)
    if options.hidePassives and item.isPassive then
        return false
    end
    if options.query and options.query ~= "" then
        local haystack = Data.Normalize(item.name .. " " .. item.subName)
        return haystack:find(Data.Normalize(options.query), 1, true) ~= nil
    end
    return true
end

-- Número de rango sacado del subtexto ("Rango 3", "Rank 3"); nil si no lo lleva.
function Data.RankOf(item)
    local number = item.subName and item.subName:match("(%d+)")
    return number and tonumber(number) or nil
end

-- Copia del rango elegido (por spellID) con la lista completa en `ranks`. Si no hay elección o ya no
-- está aprendido, el rango aprendido más alto; si no hay ninguno aprendido, el más bajo por aprender.
function Data.PickRank(ranks, chosenSpellID)
    local types = ItemTypes()
    local pick
    for _, rank in ipairs(ranks) do
        if chosenSpellID and rank.spellID == chosenSpellID and rank.itemType == types.Spell then
            pick = rank
            break
        end
    end
    if not pick then
        for index = #ranks, 1, -1 do
            if ranks[index].itemType == types.Spell then
                pick = ranks[index]
                break
            end
        end
    end
    pick = pick or ranks[1]
    local copy = {}
    for key, value in pairs(pick) do
        copy[key] = value
    end
    copy.ranks = ranks
    return copy
end

-- Forever pone cada rango como una entrada aparte del libro. Esto deja una sola por hechizo (en el
-- sitio del primer rango) con `ranks` = todos sus rangos, de menor a mayor. Solo junta hechizos del
-- jugador (aprendidos o por aprender) con el mismo nombre: acciones de mascota y flyouts no tienen rangos.
function Data.MergeRanks(items, chosen)
    local types = ItemTypes()
    local merged, byName = {}, {}
    for _, item in ipairs(items) do
        local rankable = (item.itemType == types.Spell or item.itemType == types.FutureSpell) and item.name ~= ""
        local entry = rankable and byName[item.name] or nil
        if entry then
            entry[#entry + 1] = item
        else
            entry = { item }
            merged[#merged + 1] = entry
            if rankable then
                byName[item.name] = entry
            end
        end
    end
    local result = {}
    for _, ranks in ipairs(merged) do
        if #ranks == 1 then
            result[#result + 1] = ranks[1]
        else
            local order = {}
            for index, rank in ipairs(ranks) do
                order[rank] = index
            end
            table.sort(ranks, function(a, b)
                local ra, rb = Data.RankOf(a), Data.RankOf(b)
                if ra and rb and ra ~= rb then
                    return ra < rb
                end
                return order[a] < order[b]
            end)
            result[#result + 1] = Data.PickRank(ranks, chosen and chosen[ranks[1].name])
        end
    end
    return result
end

-- Grupos que se ven: los de la pestaña elegida o, si hay búsqueda, lo que coincide en todas, con un
-- encabezado por pestaña (como los resultados de búsqueda de retail). Con `groupRanks`, un hechizo
-- por nombre con todos sus rangos (ver MergeRanks); `chosenRanks[nombre]` = spellID elegido.
function Data.Visible(categories, selected, options)
    options = options or {}
    local searching = options.query and options.query ~= ""
    local groups = {}
    for _, category in ipairs(categories) do
        if searching or category.key == selected then
            for _, group in ipairs(category.groups) do
                local items = {}
                local source = group.items
                if options.groupRanks then
                    source = Data.MergeRanks(source, options.chosenRanks)
                end
                for _, item in ipairs(source) do
                    if Keep(item, options) then
                        items[#items + 1] = item
                    end
                end
                if #items > 0 then
                    local name = group.name
                    if searching then
                        name = group.name and (category.name .. " - " .. group.name) or category.name
                    end
                    groups[#groups + 1] = { name = name, offSpec = group.offSpec, items = items }
                end
            end
        end
    end
    return groups
end

-- Reparte los grupos en páginas de `rows` filas y `cols` columnas. Cada encabezado ocupa una fila y
-- nunca queda solo al pie de una página. Devuelve una lista de páginas; cada una, una lista de
-- { kind = "header", text, row } y { kind = "item", item, row, col, offSpec }.
function Data.Paginate(groups, rows, cols)
    local pages, page, row = {}, {}, 0
    local function NewPage()
        pages[#pages + 1] = page
        page, row = {}, 0
    end
    for _, group in ipairs(groups) do
        if group.name then
            if row > 0 and row + 2 > rows then
                NewPage()
            end
            page[#page + 1] = { kind = "header", text = group.name, row = row }
            row = row + 1
        end
        local current
        for index, item in ipairs(group.items) do
            local col = (index - 1) % cols
            if col == 0 then
                if row >= rows then
                    NewPage()
                end
                current = row
                row = row + 1
            end
            page[#page + 1] = { kind = "item", item = item, row = current, col = col, offSpec = group.offSpec }
        end
    end
    if #page > 0 then
        pages[#pages + 1] = page
    end
    return pages
end
