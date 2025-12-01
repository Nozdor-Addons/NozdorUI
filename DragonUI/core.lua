local addon = select(2, ...);

-- Create addon object using AceAddon
addon.core = LibStub("AceAddon-3.0"):NewAddon("DragonUI", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0");

-- Function to recursively copy tables
local function deepCopy(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if not target[key] then
                target[key] = {}
            end
            deepCopy(value, target[key])
        else
            target[key] = value
        end
    end
end

function addon.core:OnInitialize()
    -- Replace the temporary addon.db with the real AceDB
    addon.db = LibStub("AceDB-3.0"):New("DragonUIDB", addon.defaults);

    -- Force defaults to be written to profile (check for specific key that should always exist)
    if not addon.db.profile.mainbars or not addon.db.profile.mainbars.scale_actionbar then
        -- Copy all defaults to profile to ensure they exist in SavedVariables
        deepCopy(addon.defaults.profile, addon.db.profile);
    end

    -- Register callbacks for configuration changes
    addon.db.RegisterCallback(addon, "OnProfileChanged", "RefreshConfig");
    addon.db.RegisterCallback(addon, "OnProfileCopied", "RefreshConfig");
    addon.db.RegisterCallback(addon, "OnProfileReset", "RefreshConfig");

    -- Apply current profile configuration immediately
    -- This ensures the profile is loaded when the addon starts
    addon:RefreshConfig();
end

function addon.core:OnEnable()
    -- Now we can safely create and register options (after all modules are loaded)
    
    addon.options = addon:CreateOptionsTable();
    

    -- Inject AceDBOptions into the profiles section
    local profilesOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db);
    addon.options.args.profiles = profilesOptions;
    addon.options.args.profiles.order = 10;

    LibStub("AceConfig-3.0"):RegisterOptionsTable("DragonUI", addon.options);
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DragonUI", "DragonUI");

    -- Setup custom window size that's resistant to refreshes
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    if AceConfigDialog then
        -- Track if user has manually resized the window
        local userHasResized = false
        local defaultWidth, defaultHeight = 900, 600

        -- Hook into the status table system that manages window state
        local function setupDragonUIWindowSize()
            local configFrame = AceConfigDialog.OpenFrames["DragonUI"]
            if configFrame and configFrame.frame then
                -- Check if user has manually resized (status table contains user's size)
                local statusWidth = configFrame.status.width
                local statusHeight = configFrame.status.height
                local statusTop = configFrame.status.top
                local statusLeft = configFrame.status.left

                -- If status has size and it's different from our default, user has resized
                if statusWidth and statusHeight then
                    if statusWidth ~= defaultWidth or statusHeight ~= defaultHeight then
                        userHasResized = true
                    end
                end

                -- Only apply our custom size if user hasn't manually resized
                if not userHasResized then
                    -- Update AceGUI's internal size tracking first
                    configFrame.status.width = defaultWidth
                    configFrame.status.height = defaultHeight
                    
                    -- Apply size
                    configFrame.frame:SetWidth(defaultWidth)
                    configFrame.frame:SetHeight(defaultHeight)
                    
                    -- Only set position if user hasn't moved the window
                    -- If status.top and status.left exist, user has moved the window, so preserve position
                    if not (statusTop and statusLeft) then
                        configFrame.frame:ClearAllPoints()
                        configFrame.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                    else
                        -- User has moved the window, restore their saved position
                        configFrame.frame:ClearAllPoints()
                        configFrame.frame:SetPoint("TOP", UIParent, "BOTTOM", 0, statusTop)
                        configFrame.frame:SetPoint("LEFT", UIParent, "LEFT", statusLeft, 0)
                    end
                else
                    -- User has resized, preserve their position if they moved it
                    if statusTop and statusLeft then
                        -- User has moved the window, restore their saved position
                        configFrame.frame:ClearAllPoints()
                        configFrame.frame:SetPoint("TOP", UIParent, "BOTTOM", 0, statusTop)
                        configFrame.frame:SetPoint("LEFT", UIParent, "LEFT", statusLeft, 0)
                    elseif not (statusTop and statusLeft) then
                        -- User hasn't moved the window, center it
                        configFrame.frame:ClearAllPoints()
                        configFrame.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                    end
                end
            end
        end

        -- Hook the status table application (runs on every refresh)
        local originalSetStatusTable = AceConfigDialog.SetStatusTable
        AceConfigDialog.SetStatusTable = function(self, appName, statusTable)
            local result = originalSetStatusTable(self, appName, statusTable)

            if appName == "DragonUI" then
                -- Apply our custom size after status is set
                setupDragonUIWindowSize()
            end

            return result
        end

        -- Hook the initial Open to set size immediately
        local originalOpen = AceConfigDialog.Open
        AceConfigDialog.Open = function(self, appName, ...)
            local result = originalOpen(self, appName, ...)

            if appName == "DragonUI" then
                -- Reset user resize flag on new window opening
                userHasResized = false
                -- Apply size IMMEDIATELY without delay
                setupDragonUIWindowSize()
            end

            return result
        end
    end

    -- Register slash commands
    self:RegisterChatCommand("dragonui", "SlashCommand");
    self:RegisterChatCommand("pi", "SlashCommand");

    -- Fire custom event to signal that DragonUI is fully initialized
    -- This ensures modules get the correct config values
    self:SendMessage("DRAGONUI_READY");
end

-- Callback function that refreshes all modules when configuration changes
function addon:RefreshConfig()
    -- Initialize cooldown system if it hasn't been already
    if addon.InitializeCooldowns then
        addon.InitializeCooldowns()
    end

    local failed = {};

    -- Try to apply each configuration and track failures
    if addon.RefreshMainbars then
        local success, err = pcall(addon.RefreshMainbars);
        if not success then
            table.insert(failed, "RefreshMainbars")
        end
    end

    if addon.RefreshButtons then
        local success, err = pcall(addon.RefreshButtons);
        if not success then
            table.insert(failed, "RefreshButtons")
        end
    end

    if addon.RefreshMicromenu then
        local success, err = pcall(addon.RefreshMicromenu);
        if not success then
            table.insert(failed, "RefreshMicromenu")
        end
    end

    if addon.RefreshMinimap then
        local success, err = pcall(addon.RefreshMinimap);
        if not success then
            table.insert(failed, "RefreshMinimap")
        end
    end

    if addon.RefreshTargetFrame then
        local success, err = pcall(addon.RefreshTargetFrame);
        if not success then
            table.insert(failed, "RefreshTargetFrame")
        end
    end

    if addon.RefreshFocusFrame then
        local success, err = pcall(addon.RefreshFocusFrame);
        if not success then
            table.insert(failed, "RefreshFocusFrame")
        end
    end

    if addon.RefreshPartyFrames then
        local success, err = pcall(addon.RefreshPartyFrames);
        if not success then
            table.insert(failed, "RefreshPartyFrames")
        end
    end

    if addon.RefreshStance then
        local success, err = pcall(addon.RefreshStance);
        if not success then
            table.insert(failed, "RefreshStance")
        end
    end

    if addon.RefreshUnitFrames then
        local success, err = pcall(addon.RefreshUnitFrames);
        if not success then
            table.insert(failed, "RefreshUnitFrames")
        end
    end

    if addon.RefreshPetbar then
        local success, err = pcall(addon.RefreshPetbar);
        if not success then
            table.insert(failed, "RefreshPetbar")
        end
    end

    if addon.RefreshVehicle then
        local success, err = pcall(addon.RefreshVehicle);
        if not success then
            table.insert(failed, "RefreshVehicle")
        end
    end

    if addon.RefreshMulticast then
        local success, err = pcall(addon.RefreshMulticast);
        if not success then
            table.insert(failed, "RefreshMulticast")
        end
    end

    if addon.RefreshCooldowns then
        local success, err = pcall(addon.RefreshCooldowns);
        if not success then
            table.insert(failed, "RefreshCooldowns")
        end
    end

    if addon.RefreshXpBarPosition then
        pcall(addon.RefreshXpBarPosition)
    end

    if addon.RefreshRepBarPosition then
        pcall(addon.RefreshRepBarPosition)
    end

    if addon.RefreshMinimapTime then
        local success, err = pcall(addon.RefreshMinimapTime);
        if not success then
            table.insert(failed, "RefreshMinimapTime")
        end
    end

    -- Refresh all unit frames when general scale changes
    if addon.RefreshUnitFrames then
        local success, err = pcall(addon.RefreshUnitFrames);
        if not success then
            table.insert(failed, "RefreshUnitFrames")
        end
    end

    if addon.RefreshBuffFrame then
        local success, err = pcall(addon.RefreshBuffFrame);
        if not success then
            table.insert(failed, "RefreshBuffFrame")
        end
    end

    -- If some configurations failed, retry them after 2 seconds
    if #failed > 0 then
        addon.core:ScheduleTimer(function()
            for _, funcName in ipairs(failed) do
                if addon[funcName] then
                    pcall(addon[funcName]);
                end
            end
        end, 2);
    end
end

function addon.core:SlashCommand(input)
    if not input or input:trim() == "" then
        LibStub("AceConfigDialog-3.0"):Open("DragonUI");
    elseif input:lower() == "config" then
        LibStub("AceConfigDialog-3.0"):Open("DragonUI");
    elseif input:lower() == "edit" or input:lower() == "editor" then
        if addon.EditorMode then
            addon.EditorMode:Toggle();
        else
            self:Print("Режим редактора недоступен. Убедитесь, что модуль editor_mode загружен.");
        end
    else
        self:Print("Команды:");
        self:Print("/dragonui config - Открыть настройки");
        self:Print("/dragonui edit - Переключить режим редактора для перемещения элементов интерфейса");

    end
end

---------------------------------------------------
-- FUNCIONES GLOBALES PARA EL SISTEMA DE MOVILIDAD 
---------------------------------------------------

--  FUNCIÓN AUXILIAR PARA CONTAR ELEMENTOS EN TABLA
function addon:tcount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- Таблица переводов названий фреймов для редактора
local frameNameTranslations = {
    ["BagsBar"] = "Панель сумок",
    ["MicroMenu"] = "Микроменю",
    ["micromenu"] = "Микроменю",
    ["PetFrame"] = "Рамка питомца",
    ["PlayerFrame"] = "Рамка игрока",
    ["player"] = "Рамка игрока",
    ["PartyFrames"] = "Рамки группы",
    ["party"] = "Рамки группы",
    ["TargetFrame"] = "Рамка цели",
    ["target"] = "Рамка цели",
    ["FocusFrame"] = "Рамка фокуса",
    ["focus"] = "Рамка фокуса",
    ["Petbar"] = "Панель питомца",
    ["petbar"] = "Панель питомца",
    ["MinimapFrame"] = "Миникарта",
    ["minimap"] = "Миникарта",
    ["MainBar"] = "Основная панель",
    ["mainbar"] = "Основная панель",
    ["RightBar"] = "Правая панель",
    ["rightbar"] = "Правая панель",
    ["LeftBar"] = "Левая панель",
    ["leftbar"] = "Левая панель",
    ["BottomBarLeft"] = "Нижняя левая панель",
    ["bottombarleft"] = "Нижняя левая панель",
    ["BottomBarRight"] = "Нижняя правая панель",
    ["bottombarright"] = "Нижняя правая панель",
    ["RepExpBar"] = "Полоса опыта/репутации",
    ["repexpbar"] = "Полоса опыта/репутации",
    ["PlayerCastbar"] = "Полоса заклинаний игрока",
    ["playerCastbar"] = "Полоса заклинаний игрока",
    ["TargetCastbar"] = "Полоса заклинаний цели",
    ["targetCastbar"] = "Полоса заклинаний цели",
    ["tot"] = "Цель цели",
    ["ToT"] = "Цель цели",
    ["tof"] = "Цель фокуса",
    ["ToF"] = "Цель фокуса",
    ["Auras"] = "Ауры",
    ["buffs"] = "Ауры",
    ["StanceBar"] = "Панель стойки",
    ["stance"] = "Панель стойки",
    ["ArenaEnemyFrames"] = "Рамки арены",
    ["arena"] = "Рамки арены",
    ["bagsbar"] = "Панель сумок",
    ["vehicleleave"] = "Кнопка выхода из транспорта"
}

function CreateUIFrame(width, height, frameName)
    local frame = CreateFrame("Frame", 'DragonUI_' .. frameName, UIParent)
    frame:SetSize(width, height)

    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)
    frame:SetMovable(false)
    frame:SetScript("OnDragStart", function(self, button)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        
        --  AUTO-SAVE: Buscar este frame en EditableFrames y guardar posición automáticamente
        for frameName, frameData in pairs(addon.EditableFrames) do
            if frameData.frame == self then
                -- Guardar posición automáticamente
                if #frameData.configPath == 2 then
                    SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2])
                else
                    SaveUIFramePosition(frameData.frame, frameData.configPath[1])
                end
                
                -- CRITICAL: Apply position in real-time for frames that need it
                if frameData.module and frameData.module.ApplyWidgetPosition then
                    frameData.module.ApplyWidgetPosition()
                elseif frameData.onHide then
                    -- Call onHide to apply position changes immediately
                    frameData.onHide()
                end
                
                break
            end
        end
    end)

    frame:SetFrameLevel(100)
    frame:SetFrameStrata('FULLSCREEN')

    --  TEXTURA VERDE COMO RETAILUI
    do
        local texture = frame:CreateTexture(nil, 'BACKGROUND')
        texture:SetAllPoints(frame)
        --  CAMBIO: Usar textura sólida en lugar de border_buttons.tga
        texture:SetTexture(0, 1, 0, 0.3) -- Verde semi-transparente
        texture:Hide()
        frame.editorTexture = texture

        
    end

    --  TEXTO COMO RETAILUI
    do
        local fontString = frame:CreateFontString(nil, "BORDER", 'GameFontNormal')
        fontString:SetAllPoints(frame)
        local displayName = frameNameTranslations[frameName] or frameName
        fontString:SetText(displayName)
        fontString:Hide()
        frame.editorText = fontString
    end

    return frame
end

--  FRAMES REGISTRY COMO RETAILUI
addon.frames = {}

function ShowUIFrame(frame)
    frame:SetMovable(false)
    frame:EnableMouse(false)
    
    -- Safety check for editor overlay elements
    if frame.editorTexture then
        frame.editorTexture:Hide()
    end
    if frame.editorText then
        frame.editorText:Hide()
    end

    if addon.frames[frame] then
        for _, target in pairs(addon.frames[frame]) do
            target:SetAlpha(1)
        end
        addon.frames[frame] = nil
    end
end

function HideUIFrame(frame, exclude)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    
    -- Safety check for editor overlay elements
    if frame.editorTexture then
        frame.editorTexture:Show()
    end
    if frame.editorText then
        frame.editorText:Show()
    end

    addon.frames[frame] = {}
    exclude = exclude or {}

    for _, target in pairs(exclude) do
        target:SetAlpha(0)
        table.insert(addon.frames[frame], target)
    end
end

function SaveUIFramePosition(frame, configPath1, configPath2)
    if not frame then

        return
    end

    local anchor, _, relativePoint, posX, posY = frame:GetPoint(1) -- Primer punto

    --  MANEJAR RUTAS ANIDADAS (widgets.player)
    if configPath2 then
        -- Caso: SaveUIFramePosition(frame, "widgets", "player")
        if not addon.db.profile[configPath1] then
            addon.db.profile[configPath1] = {}
        end

        if not addon.db.profile[configPath1][configPath2] then
            addon.db.profile[configPath1][configPath2] = {}
        end

        addon.db.profile[configPath1][configPath2].anchor = anchor or "CENTER"
        addon.db.profile[configPath1][configPath2].posX = posX or 0
        addon.db.profile[configPath1][configPath2].posY = posY or 0


    else
        -- Caso: SaveUIFramePosition(frame, "minimap") - compatibilidad hacia atrás
        local widgetName = configPath1
        
        if not addon.db.profile.widgets then
            addon.db.profile.widgets = {}
        end

        if not addon.db.profile.widgets[widgetName] then
            addon.db.profile.widgets[widgetName] = {}
        end

        addon.db.profile.widgets[widgetName].anchor = anchor or "CENTER"
        addon.db.profile.widgets[widgetName].posX = posX or 0
        addon.db.profile.widgets[widgetName].posY = posY or 0


    end
end

function CheckSettingsExists(moduleInstance, widgets)
    for _, widget in pairs(widgets) do
        if not addon.db.profile.widgets[widget] then
            moduleInstance:LoadDefaultSettings()
            break
        end
    end
    moduleInstance:UpdateWidgets()
end

function ApplyUIFramePosition(frame, configPath)
    if not frame or not configPath then
        return
    end

    local section, key = configPath:match("([^%.]+)%.([^%.]+)")
    if not section or not key then
        return
    end

    local config = addon.db.profile[section] and addon.db.profile[section][key]
    if not config or not config.override then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(config.anchor or "CENTER", UIParent, config.anchorParent or "CENTER", config.x or 0, config.y or 0)
end

function CheckSettingsExists(moduleTable, configPaths)
    local needsDefaults = false

    for _, configPath in pairs(configPaths) do
        local section, key = configPath:match("([^%.]+)%.([^%.]+)")
        if section and key then
            if not addon.db.profile[section] or not addon.db.profile[section][key] then
                needsDefaults = true
                break
            end
        end
    end

    if needsDefaults and moduleTable.LoadDefaultSettings then
        moduleTable:LoadDefaultSettings()
    end

    if moduleTable.UpdateWidgets then
        moduleTable:UpdateWidgets()
    end
end

---------------------------------------------------
-- SISTEMA CENTRALIZADO DE FRAMES EDITABLES (EXTENDIDO)
---------------------------------------------------

--  REGISTRO GLOBAL DE TODOS LOS FRAMES EDITABLES
addon.EditableFrames = {}

--  FUNCIÓN PARA REGISTRAR FRAMES AUTOMÁTICAMENTE
function addon:RegisterEditableFrame(frameInfo)
    local frameData = {
        name = frameInfo.name,                    -- "player", "minimap", "target"
        frame = frameInfo.frame,                  -- El frame auxiliar
        blizzardFrame = frameInfo.blizzardFrame,  --  NUEVO: Frame real de Blizzard (opcional)
        configPath = frameInfo.configPath,       -- {"widgets", "player"} o {"unitframe", "target"}
        onShow = frameInfo.onShow,               -- Función opcional al mostrar editor
        onHide = frameInfo.onHide,               -- Función opcional al ocultar editor
        --  NUEVO: Funciones para mostrar/ocultar con datos fake
        showTest = frameInfo.showTest,           -- Función para mostrar con datos fake
        hideTest = frameInfo.hideTest,           -- Función para ocultar frame fake
        hasTarget = frameInfo.hasTarget,         -- Función para verificar si debe estar visible
        module = frameInfo.module                -- Referencia al módulo
    }
    
    self.EditableFrames[frameInfo.name] = frameData

end

--  FUNCIÓN PARA MOSTRAR TODOS LOS FRAMES EN EDITOR MODE
function addon:ShowAllEditableFrames()
    for name, frameData in pairs(self.EditableFrames) do
        if frameData.frame then
            HideUIFrame(frameData.frame) -- Mostrar overlay verde
            
            --  NUEVO: Mostrar frame con datos fake si es necesario
            if frameData.showTest then
                frameData.showTest()
            end
            
            if frameData.onShow then
                frameData.onShow()
            end
        end
    end
end

--  FUNCIÓN PARA OCULTAR TODOS LOS FRAMES Y GUARDAR POSICIONES
function addon:HideAllEditableFrames(refresh)
    for name, frameData in pairs(self.EditableFrames) do
        if frameData.frame then
            ShowUIFrame(frameData.frame) -- Ocultar overlay verde
            
            --  NUEVO: Ocultar frame fake si no debe estar visible
            if frameData.hideTest then
                frameData.hideTest()
            end
            
            if refresh then
                -- Guardar posición automáticamente
                if #frameData.configPath == 2 then
                    SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2])
                else
                    SaveUIFramePosition(frameData.frame, frameData.configPath[1])
                end
                
                if frameData.onHide then
                    frameData.onHide()
                end
            end
        end
    end
end

--  FUNCIÓN PARA VERIFICAR SI UN FRAME DEBE ESTAR VISIBLE
function addon:ShouldFrameBeVisible(frameName)
    local frameData = self.EditableFrames[frameName]
    if not frameData then return false end
    
    if frameData.hasTarget then
        return frameData.hasTarget()
    end
    
    -- Por defecto, los frames siempre están visibles (player, minimap)
    return true
end

--  FUNCIÓN PARA OBTENER INFORMACIÓN DE UN FRAME REGISTRADO
function addon:GetEditableFrameInfo(frameName)
    return self.EditableFrames[frameName]
end

--  EXPORTAR CreateUIFrame AL NAMESPACE ADDON PARA COMPATIBILIDAD
addon.CreateUIFrame = CreateUIFrame

-- ============================================================================
-- UNIT FRAMES REFRESH FUNCTION
-- ============================================================================

-- Function to refresh all unit frames when general scale changes
function addon.RefreshUnitFrames()
    -- Refresh all unit frames
    if addon.RefreshPlayerFrame then
        addon.RefreshPlayerFrame()
    end
    
    if addon.RefreshTargetFrame then
        addon.RefreshTargetFrame()
    end
    
    if addon.RefreshFocusFrame then
        addon.RefreshFocusFrame()
    end
    
    if addon.RefreshPartyFrames then
        addon.RefreshPartyFrames()
    end
    
    if addon.PetFrame and addon.PetFrame.Refresh then
        addon.PetFrame.Refresh()
    end
    
    if addon.TargetOfTarget and addon.TargetOfTarget.Refresh then
        addon.TargetOfTarget.Refresh()
    end
    
    if addon.TargetOfFocus and addon.TargetOfFocus.Refresh then
        addon.TargetOfFocus.Refresh()
    end
end

---------------------------------------------------
---------------------------------------------------
