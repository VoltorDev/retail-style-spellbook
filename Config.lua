local addonName, ns = ...
local L = ns.L
local module = ns:NewModule("Config")

-- Panel en Opciones > AddOns con la API nativa Settings (Blizzard_Settings_Shared).
-- Se registra en OnInitialize porque Settings.RegisterAddOnSetting escribe el valor por defecto
-- en la tabla si la clave es nil: hay que hacerlo DESPUÉS de cargar las SavedVariables.
function module:OnInitialize()
    local db = ns.db
    local category = Settings.RegisterVerticalLayoutCategory(L.ADDON_TITLE)

    local function OnSettingChanged()
        ns:ApplySettings()
    end

    local replaceKey = Settings.RegisterAddOnSetting(
        category,
        addonName .. "_ReplaceKey",
        "replaceKey",
        db,
        Settings.VarType.Boolean,
        L.OPT_REPLACE_KEY,
        ns.DEFAULTS.replaceKey
    )
    replaceKey:SetValueChangedCallback(OnSettingChanged)
    Settings.CreateCheckbox(category, replaceKey, L.OPT_REPLACE_KEY_TT)

    local hidePassives = Settings.RegisterAddOnSetting(
        category,
        addonName .. "_HidePassives",
        "hidePassives",
        db,
        Settings.VarType.Boolean,
        L.HIDE_PASSIVES,
        ns.DEFAULTS.hidePassives
    )
    hidePassives:SetValueChangedCallback(OnSettingChanged)
    Settings.CreateCheckbox(category, hidePassives, L.OPT_HIDE_PASSIVES_TT)

    local groupRanks = Settings.RegisterAddOnSetting(
        category,
        addonName .. "_GroupRanks",
        "groupRanks",
        db,
        Settings.VarType.Boolean,
        L.OPT_GROUP_RANKS,
        ns.DEFAULTS.groupRanks
    )
    groupRanks:SetValueChangedCallback(OnSettingChanged)
    Settings.CreateCheckbox(category, groupRanks, L.OPT_GROUP_RANKS_TT)

    local scale = Settings.RegisterAddOnSetting(
        category,
        addonName .. "_Scale",
        "scale",
        db,
        Settings.VarType.Number,
        L.OPT_SCALE,
        ns.DEFAULTS.scale
    )
    scale:SetValueChangedCallback(OnSettingChanged)
    local sliderOptions = Settings.CreateSliderOptions(0.5, 1.5, 0.05)
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return ("%.2f"):format(value)
    end)
    Settings.CreateSlider(category, scale, sliderOptions, L.OPT_SCALE_TT)

    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end

-- Abrir el panel está restringido en combate (C_SettingsUtil.OpenSettingsPanel lleva HasRestrictions).
function ns:OpenSettings()
    if InCombatLockdown() then
        self:Print(L.ERR_COMBAT)
        return
    end
    Settings.OpenToCategory(self.settingsCategory:GetID())
end

-- Compartimento de addons (botón del minimapa). Los nombres coinciden con el TOC.
-- El cliente llama a la función de clic con (addonName, buttonName) y a las de ratón
-- con (addonName, menuButtonFrame).
function RetailSpellbook_OnAddonCompartmentClick()
    ns:OpenSettings()
end

function RetailSpellbook_OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:SetText(L.ADDON_TITLE)
    GameTooltip:AddLine(L.COMPARTMENT_TOOLTIP, 1, 1, 1)
    GameTooltip:Show()
end

function RetailSpellbook_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
