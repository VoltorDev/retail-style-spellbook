-- Panel de opciones (Config.lua) con la API Settings: se registra DESPUÉS de cargar las
-- SavedVariables, queda enlazado a esa misma tabla y cada cambio se guarda y se aplica.
local WowEnv = require("wow_env")

local TOC = "RetailSpellbook.toc"

local function countKeys(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

describe("opciones en Settings", function()
    it("no registra nada al cargar los ficheros; sí tras el ADDON_LOADED propio", function()
        local env = WowEnv.new()
        env.RetailSpellbookDB = { schema = 1, scale = 1.25 }
        local ns = env:LoadToc(TOC) or error("el addon no cargó")
        local registry = env:SettingsRegistry()
        assert.are.equal(0, countKeys(registry.settings))

        env:Fire("ADDON_LOADED", env:AddonName(), false)
        assert.are.equal(4, countKeys(registry.settings))
        assert.are.equal(1, #registry.addOnCategories)
        assert.are.equal(ns.settingsCategory, registry.addOnCategories[1])
        assert.are.equal(ns.L.ADDON_TITLE, ns.settingsCategory:GetName())

        local expected = {
            ReplaceKey = { "replaceKey", "boolean" },
            HidePassives = { "hidePassives", "boolean" },
            GroupRanks = { "groupRanks", "boolean" },
            Scale = { "scale", "number" },
        }
        for suffix, info in pairs(expected) do
            local setting = registry.settings[env:AddonName() .. "_" .. suffix]
            assert(setting ~= nil, "falta el ajuste " .. suffix)
            assert.are.equal(env.RetailSpellbookDB, setting.variableTbl) -- la tabla ya cargada, no otra
            assert.are.equal(info[1], setting.variableKey)
            assert.are.equal(info[2], setting:GetVariableType())
        end
        assert.are.equal(1.25, registry.settings[env:AddonName() .. "_Scale"]:GetValue()) -- no pisa lo guardado
    end)

    it("crea tres casillas y un deslizador con dos decimales", function()
        local env = WowEnv.boot(TOC)
        local controls = env:SettingsRegistry().controls
        local kinds = {}
        for _, control in ipairs(controls) do
            kinds[#kinds + 1] = control.kind
        end
        assert.are.same({ "Checkbox", "Checkbox", "Checkbox", "Slider" }, kinds)
        local slider = controls[4].options
        assert.are.equal(0.5, slider.minValue)
        assert.are.equal(1.5, slider.maxValue)
        local label = slider.formatters[env.MinimalSliderWithSteppersMixin.Label.Right]
        assert.are.equal("1.25", label(1.25))
    end)

    it("cambiar la escala la guarda y la aplica al libro", function()
        local env = WowEnv.boot(TOC)
        env:SettingsRegistry().settings[env:AddonName() .. "_Scale"]:SetValue(1.2)
        assert.are.equal(1.2, env.RetailSpellbookDB.scale)
        assert.are.equal(1.2, env.RetailSpellbookFrame:GetScale())
    end)

    it("un valor de otro tipo se rechaza, como en el cliente", function()
        local env = WowEnv.boot(TOC)
        local scale = env:SettingsRegistry().settings[env:AddonName() .. "_Scale"]
        assert.has_error(function()
            scale:SetValue("2")
        end)
        assert.are.equal(0.9, env.RetailSpellbookDB.scale)
    end)
end)
