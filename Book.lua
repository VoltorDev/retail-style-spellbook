local _, ns = ...
local L = ns.L
local Data = ns.Data
local module = ns:NewModule("Book")

-- Libro de hechizos con la organización de retail: pestañas Clase / General / Mascota, un encabezado
-- por escuela, dos páginas abiertas con tres columnas, buscador y ocultar pasivas.
--
-- Por qué un libro propio y no retocar el de Blizzard: sus hechizos se lanzan con
-- C_SpellBook.CastSpellBookItem desde su propio OnClick. Si un addon cambia cómo se arman sus
-- categorías, los datos de cada botón quedan contaminados (taint) y lanzar desde el libro da
-- «acción bloqueada». Aquí cada hechizo es un SecureActionButton (type "spell"), que lanza sin taint.
-- Coste: en combate los botones no se pueden reasignar, así que la página y la pestaña se quedan
-- fijas hasta salir de él (abrir, cerrar y lanzar sí funcionan).

local ROWS, COLS = 8, 3
local ROW_H, COL_W = 56, 152
local WIDTH, HEIGHT = 1060, 620
local PAGE_X = { 58, 560 }
local TOP_Y = -96

local FALLBACK_TEXT = { 0.18, 0.106, 0.059 }
local SUBTEXT = { 0.36, 0.25, 0.14 }

local book, toggle
local pageWidgets = { {}, {} } -- [1|2] = { buttons = {}, headers = {} }
local state = { tab = "class", spread = 1, query = "", categories = {}, pages = {} }

local function TextColor()
    if SPELLBOOK_FONT_COLOR and SPELLBOOK_FONT_COLOR.GetRGB then
        return SPELLBOOK_FONT_COLOR:GetRGB()
    end
    return unpack(FALLBACK_TEXT)
end

local function ItemTypes()
    return Enum.SpellBookItemType or { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 }
end

--------------------------------------------------------------------------------------------------
-- Botón de un hechizo
--------------------------------------------------------------------------------------------------

local function Button_OnEnter(self)
    if not self.item then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetSpellBookItem(self.item.slot, self.item.bank)
    GameTooltip:Show()
    self.IconHighlight:Show()
end

local function Button_OnLeave(self)
    GameTooltip:Hide()
    self.IconHighlight:Hide()
end

-- Arrastrar a la barra de acción. No es una acción protegida; en combate la barra no la aceptaría.
local function Button_OnDragStart(self)
    if self.item and not InCombatLockdown() then
        C_SpellBook.PickupSpellBookItem(self.item.slot, self.item.bank)
    end
end

-- Mayús+clic: enlazar en el chat. El clic seguro no hace nada con Mayús (shift-type1 = "none").
local function Button_PostClick(self, mouseButton)
    if self.item and mouseButton == "LeftButton" and IsModifiedClick("CHATLINK") then
        local link = self.item.spellID and C_Spell.GetSpellLink(self.item.spellID)
        if link then
            ChatFrameUtil.InsertLink(link)
        end
    end
end

local function CreateSpellButton(parent)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    button:SetSize(COL_W - 6, ROW_H - 6)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")

    local shadow = button:CreateTexture(nil, "BACKGROUND")
    shadow:SetAtlas("spellbook-item-iconframe-shadow")
    shadow:SetSize(52, 52)
    shadow:SetPoint("LEFT", -6, 0)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("LEFT", 0, 0)
    button.Icon = icon

    local highlight = button:CreateTexture(nil, "OVERLAY")
    highlight:SetAtlas("spellbook-item-iconframe-hover")
    highlight:SetAllPoints(icon)
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.4)
    highlight:Hide()
    button.IconHighlight = highlight

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    button.Cooldown = cooldown

    local name = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 7, -1)
    name:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    name:SetJustifyH("LEFT")
    name:SetMaxLines(2)
    name:SetWordWrap(true)
    name:SetTextColor(TextColor())
    name:SetShadowOffset(0, 0)
    button.Name = name

    local sub = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    sub:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    sub:SetJustifyH("LEFT")
    sub:SetTextColor(unpack(SUBTEXT))
    sub:SetShadowOffset(0, 0)
    button.SubName = sub

    button:SetScript("OnEnter", Button_OnEnter)
    button:SetScript("OnLeave", Button_OnLeave)
    button:SetScript("OnDragStart", Button_OnDragStart)
    button:SetScript("PostClick", Button_PostClick)
    button:Hide()
    return button
end

-- Qué hace cada clic. Solo fuera de combate (atributos de un botón seguro).
local function SetActions(button, item)
    local types = ItemTypes()
    for _, key in ipairs({ "type", "spell", "type2", "macrotext2", "shift-type1" }) do
        button:SetAttribute(key, nil)
    end
    if not item or item.isPassive then
        return
    end
    if item.itemType == types.Spell and item.spellID then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", item.spellID)
    elseif item.itemType == types.PetAction and item.spellID then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", item.spellID)
        -- Clic derecho: activar o quitar el lanzamiento automático, como en el libro de Blizzard.
        button:SetAttribute("type2", "macro")
        button:SetAttribute("macrotext2", "/petautocasttoggle " .. item.name)
    elseif item.itemType == types.Flyout then
        button:SetAttribute("type", "flyout")
        button:SetAttribute("spell", item.actionID)
    end
    button:SetAttribute("shift-type1", "none")
end

local function UpdateCooldown(button)
    local item = button.item
    local duration = item and item.spellID and not item.isPassive and C_Spell.GetSpellCooldownDuration(item.spellID)
    if duration and button.Cooldown.SetCooldownFromDurationObject then
        button.Cooldown:SetCooldownFromDurationObject(duration, true)
    else
        button.Cooldown:Clear()
    end
end

local function ShowItem(button, entry)
    local item = entry.item
    local types = ItemTypes()
    button.item = item
    SetActions(button, item)
    button.Icon:SetTexture(item.icon)
    local unusable = item.itemType == types.FutureSpell or entry.offSpec
    button.Icon:SetDesaturated(unusable)
    button.Icon:SetAlpha(unusable and 0.6 or 1)
    button.Name:SetText(item.name)
    local sub = item.subName
    if item.isPassive then
        sub = (sub ~= "" and sub ~= SPELL_PASSIVE) and (sub .. " - " .. L.PASSIVE) or L.PASSIVE
    elseif item.itemType == types.FutureSpell then
        sub = L.NOT_LEARNED
    end
    button.SubName:SetText(sub)
    UpdateCooldown(button)
    button:Show()
end

--------------------------------------------------------------------------------------------------
-- Páginas
--------------------------------------------------------------------------------------------------

local function CreateHeader(parent)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetJustifyH("LEFT")
    header:SetTextColor(TextColor())
    header:SetShadowOffset(0, 0)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("spellbook-divider")
    divider:SetHeight(11)
    header.Divider = divider
    return header
end

local function CreatePageWidgets()
    for side = 1, 2 do
        local widgets = pageWidgets[side]
        widgets.buttons, widgets.headers = {}, {}
        for i = 1, ROWS * COLS do
            widgets.buttons[i] = CreateSpellButton(book)
        end
        for i = 1, ROWS do
            widgets.headers[i] = CreateHeader(book)
        end
    end
end

local function DrawPage(side, page)
    local widgets = pageWidgets[side]
    local usedButtons, usedHeaders = 0, 0
    for _, entry in ipairs(page or {}) do
        local x = PAGE_X[side]
        local y = TOP_Y - entry.row * ROW_H
        if entry.kind == "header" then
            usedHeaders = usedHeaders + 1
            local header = widgets.headers[usedHeaders]
            header:ClearAllPoints()
            header:SetPoint("BOTTOMLEFT", book, "TOPLEFT", x, y - ROW_H + 18)
            header:SetText(entry.text)
            header:Show()
            header.Divider:ClearAllPoints()
            header.Divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -10, -2)
            header.Divider:SetWidth(COLS * COL_W - 20)
            header.Divider:Show()
        else
            usedButtons = usedButtons + 1
            local button = widgets.buttons[usedButtons]
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", book, "TOPLEFT", x + entry.col * COL_W, y - 4)
            ShowItem(button, entry)
        end
    end
    for i = usedButtons + 1, #widgets.buttons do
        local button = widgets.buttons[i]
        button.item = nil
        SetActions(button, nil)
        button:Hide()
    end
    for i = usedHeaders + 1, #widgets.headers do
        widgets.headers[i]:Hide()
        widgets.headers[i].Divider:Hide()
    end
end

local function NumSpreads()
    return math.max(1, math.ceil(#state.pages / 2))
end

local function UpdateControls()
    local spreads = NumSpreads()
    book.PageText:SetFormattedText(L.PAGE_FORMAT, state.spread, spreads)
    book.PrevPage:SetEnabled(state.spread > 1)
    book.NextPage:SetEnabled(state.spread < spreads)
    local searching = state.query ~= ""
    for index, tab in ipairs(book.Tabs) do
        local category = state.categories[index]
        PanelTemplates_SetTabShown(book, index, category ~= nil)
        if category then
            tab:SetText(category.name)
        end
    end
    if searching then
        PanelTemplates_SetTab(book, 0)
    else
        for index, category in ipairs(state.categories) do
            if category.key == state.tab then
                PanelTemplates_SetTab(book, index)
            end
        end
    end
    book.EmptyText:SetShown(#state.pages == 0)
end

-- Recalcula y dibuja. En combate se aplaza: los botones seguros no se pueden reasignar.
function module:Refresh(keepSpread)
    if not book then
        return
    end
    if InCombatLockdown() then
        self.pending = true
        return
    end
    self.pending = false
    state.categories = Data.Collect()
    local found = false
    for _, category in ipairs(state.categories) do
        found = found or category.key == state.tab
    end
    if not found then
        state.tab = "class"
    end
    local groups = Data.Visible(state.categories, state.tab, {
        hidePassives = ns.db.hidePassives,
        query = state.query,
    })
    state.pages = Data.Paginate(groups, ROWS, COLS)
    if not keepSpread then
        state.spread = 1
    end
    state.spread = math.min(state.spread, NumSpreads())
    DrawPage(1, state.pages[state.spread * 2 - 1])
    DrawPage(2, state.pages[state.spread * 2])
    UpdateControls()
end

local function ChangeSpread(delta)
    if InCombatLockdown() then
        ns:Print(L.ERR_COMBAT_PAGE)
        return
    end
    state.spread = math.max(1, math.min(NumSpreads(), state.spread + delta))
    module:Refresh(true)
end

local function SelectTab(index)
    if InCombatLockdown() then
        ns:Print(L.ERR_COMBAT_PAGE)
        return
    end
    local category = state.categories[index]
    if not category then
        return
    end
    state.tab = category.key
    state.query = ""
    book.SearchBox:SetText("")
    module:Refresh(false)
end

--------------------------------------------------------------------------------------------------
-- Marco
--------------------------------------------------------------------------------------------------

local function SavePosition()
    local point, _, relativePoint, x, y = book:GetPoint(1)
    ns.db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function ApplyPosition()
    local position = ns.db.position
    book:ClearAllPoints()
    book:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    book:SetScale(ns.db.scale)
end

local function CreateNavButton(direction)
    local button = CreateFrame("Button", nil, book)
    button:SetSize(32, 32)
    local base = "Interface\\Buttons\\UI-SpellbookIcon-" .. direction .. "Page-"
    button:SetNormalTexture(base .. "Up")
    button:SetPushedTexture(base .. "Down")
    button:SetDisabledTexture(base .. "Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    return button
end

local function CreateBook()
    book = CreateFrame("Frame", "RetailSpellbookFrame", UIParent, "PortraitFrameTemplate, SecureHandlerBaseTemplate")
    book:SetSize(WIDTH, HEIGHT)
    book:SetToplevel(true)
    book:SetFrameStrata("HIGH")
    book:EnableMouse(true)
    book:SetMovable(true)
    book:SetClampedToScreen(true)
    book:RegisterForDrag("LeftButton")
    book:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    book:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    book:Hide()
    if book.SetTitle then
        book:SetTitle(L.TITLE)
    end
    if book.SetPortraitToAsset then
        book:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_09")
    end

    -- El botón de cerrar de la plantilla oculta el marco desde código inseguro (bloqueado en combate):
    -- se cambia por uno seguro.
    if type(book.CloseButton) == "table" then
        book.CloseButton:Hide()
    end
    local close = CreateFrame("Button", nil, book, "UIPanelCloseButtonNoScripts, SecureHandlerClickTemplate")
    close:SetPoint("TOPRIGHT", 1, 0)
    close:SetAttribute("_onclick", [[ self:GetParent():Hide() ]])

    local left = book:CreateTexture(nil, "BACKGROUND", nil, 2)
    left:SetAtlas("spellbook-Page-Left-C60")
    left:SetPoint("TOPLEFT", 2, -21)
    left:SetPoint("BOTTOMRIGHT", book, "BOTTOM", 0, 2)
    local right = book:CreateTexture(nil, "BACKGROUND", nil, 2)
    right:SetAtlas("spellbook-Page-Right-C60")
    right:SetPoint("TOPLEFT", book, "TOP", 0, -21)
    right:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Pestañas arriba, como en retail.
    book.Tabs = {}
    for index = 1, 3 do
        local tab = CreateFrame("Button", nil, book, "PanelTopTabButtonTemplate")
        tab:SetID(index)
        tab.index = index
        if index == 1 then
            tab:SetPoint("TOPLEFT", book, "TOPLEFT", 64, -30)
        else
            tab:SetPoint("LEFT", book.Tabs[index - 1], "RIGHT", 4, 0)
        end
        tab:SetScript("OnClick", function(self)
            SelectTab(self.index)
        end)
        book.Tabs[index] = tab
    end
    PanelTemplates_SetNumTabs(book, 3)

    local search = CreateFrame("EditBox", nil, book, "SearchBoxTemplate")
    search:SetSize(200, 20)
    search:SetPoint("TOPRIGHT", book, "TOPRIGHT", -170, -38)
    search:HookScript("OnTextChanged", function(self, userInput)
        if not userInput then
            return
        end
        state.query = self:GetText() or ""
        module:Refresh(false)
    end)
    book.SearchBox = search

    local passives = CreateFrame("CheckButton", nil, book, "UICheckButtonTemplate")
    passives:SetSize(24, 24)
    passives:SetPoint("TOPRIGHT", book, "TOPRIGHT", -130, -36)
    local label = passives.Text or passives.text
    if type(label) == "table" then
        label:SetText(L.HIDE_PASSIVES)
        label:ClearAllPoints()
        label:SetPoint("LEFT", passives, "RIGHT", 2, 0)
    end
    passives:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            self:SetChecked(ns.db.hidePassives)
            ns:Print(L.ERR_COMBAT_PAGE)
            return
        end
        ns.db.hidePassives = self:GetChecked() and true or false
        module:Refresh(true)
    end)
    book.HidePassives = passives

    local prev = CreateNavButton("Prev")
    prev:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -80, 16)
    prev:SetScript("OnClick", function()
        ChangeSpread(-1)
    end)
    local nextButton = CreateNavButton("Next")
    nextButton:SetPoint("LEFT", prev, "RIGHT", 6, 0)
    nextButton:SetScript("OnClick", function()
        ChangeSpread(1)
    end)
    local pageText = book:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pageText:SetPoint("RIGHT", prev, "LEFT", -8, 0)
    pageText:SetTextColor(TextColor())
    pageText:SetShadowOffset(0, 0)
    book.PrevPage, book.NextPage, book.PageText = prev, nextButton, pageText

    local empty = book:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    empty:SetPoint("CENTER", book, "LEFT", WIDTH / 4, 0)
    empty:SetTextColor(TextColor())
    empty:SetText(L.NO_RESULTS)
    book.EmptyText = empty

    -- Rueda del ratón: pasar página.
    book:EnableMouseWheel(true)
    book:SetScript("OnMouseWheel", function(_, delta)
        ChangeSpread(delta > 0 and -1 or 1)
    end)

    book:HookScript("OnShow", function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_OPEN or 829)
        passives:SetChecked(ns.db.hidePassives)
        module:Refresh(true)
    end)
    book:HookScript("OnHide", function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_CLOSE or 830)
    end)

    tinsert(UISpecialFrames, book:GetName())
    CreatePageWidgets()
    ApplyPosition()
end

-- Botón invisible que abre y cierra el libro también en combate (fragmento seguro). La tecla del
-- libro de Blizzard se redirige a él con un atajo de sustitución.
local function CreateToggle()
    toggle = CreateFrame("Button", "RetailSpellbookToggle", UIParent, "SecureHandlerClickTemplate")
    toggle:RegisterForClicks("AnyDown")
    toggle:SetFrameRef("book", book)
    toggle:SetAttribute(
        "_onclick",
        [[
        local book = self:GetFrameRef("book")
        if book:IsShown() then
            book:Hide()
        else
            book:Show()
        end
    ]]
    )
end

--------------------------------------------------------------------------------------------------
-- Tecla del libro
--------------------------------------------------------------------------------------------------

local boundKeys = ""

local function SpellbookKeys()
    local keys = { GetBindingKey("TOGGLESPELLBOOK") }
    return keys, table.concat(keys, ",")
end

function module:UpdateBindings()
    if not toggle then
        return
    end
    if InCombatLockdown() then
        self.pendingBindings = true
        return
    end
    self.pendingBindings = false
    local keys, signature = SpellbookKeys()
    if not ns.db.replaceKey then
        signature = ""
    end
    if signature == boundKeys then
        return
    end
    ClearOverrideBindings(toggle)
    if ns.db.replaceKey then
        for _, key in ipairs(keys) do
            SetOverrideBindingClick(toggle, true, key, "RetailSpellbookToggle", "LeftButton")
        end
    end
    boundKeys = signature
end

function module:Toggle()
    if not book then
        return
    end
    if InCombatLockdown() then
        ns:Print(L.ERR_COMBAT_TOGGLE)
        return
    end
    book:SetShown(not book:IsShown())
end

--------------------------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------------------------

local REFRESH_EVENTS = { "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "PET_BAR_UPDATE", "UNIT_PET" }

function module:OnEnable()
    CreateBook()
    CreateToggle()
    self:UpdateBindings()

    local function RefreshIfShown()
        if book:IsShown() then
            module:Refresh(true)
        else
            module.pending = true
        end
    end
    for _, event in ipairs(REFRESH_EVENTS) do
        ns:RegisterEvent(event, RefreshIfShown)
    end
    ns:RegisterEvent("UPDATE_BINDINGS", function()
        module:UpdateBindings()
    end)
    ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if module.pendingBindings then
            module:UpdateBindings()
        end
        if module.pending and book:IsShown() then
            module:Refresh(true)
        end
    end)
    ns:RegisterEvent("SPELL_UPDATE_COOLDOWN", function()
        if not book:IsShown() then
            return
        end
        for side = 1, 2 do
            for _, button in ipairs(pageWidgets[side].buttons) do
                if button.item then
                    UpdateCooldown(button)
                end
            end
        end
    end)
end

function module:ApplySettings()
    if not book or InCombatLockdown() then
        return
    end
    ApplyPosition()
    self:UpdateBindings()
    if book:IsShown() then
        self:Refresh(true)
    end
end

ns.Book = module
