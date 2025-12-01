local addon = select(2, ...);

local EditorMode = {};
addon.EditorMode = EditorMode;

local gridOverlay = nil;
local exitEditorButton = nil;
local resetAllButton = nil;
local snapToggleButton = nil;
local resetButton = nil;
local savedFramePositions = nil;

StaticPopupDialogs["DragonUI_RELOAD_UI"] = {
    text = "Элементы интерфейса были перемещены. Перезагрузить интерфейс, чтобы\nобеспечить корректное отображение всех графических элементов?",
    button1 = "Перезагрузить сейчас",
    button2 = "Позже",
    OnAccept = function()
        ReloadUI()
    end,
    OnShow = function(self)
        -- CRITICAL: Ensure dialog width is sufficient for text BEFORE setting text width
        if self:GetWidth() < 1000 then
            self:SetWidth(1000)
        end
        
        if self.text then
            -- CRITICAL: Set text width to match dialog width minus padding
            -- Text width should be less than dialog width to account for borders/padding
            -- Use wider width to accommodate longer text
            self.text:SetWidth(900)
            self.text:SetJustifyH("CENTER")
            self.text:SetJustifyV("MIDDLE")
        end
        
        -- CRITICAL: Ensure dialog width is sufficient after text is set
        if self:GetWidth() < 1000 then
            self:SetWidth(1000)
        end
        
        local frame = CreateFrame("Frame")
        frame:SetScript("OnUpdate", function(frame)
            frame:SetScript("OnUpdate", nil)
            -- CRITICAL: Re-check width after text is rendered
            if self:GetWidth() < 1000 then
                self:SetWidth(1000)
            end
            if self.text then
                self.text:SetWidth(900)
            end
            
            if self.button1 and self.button2 and self:IsShown() then
                local button1Width = self.button1:GetWidth() or 140
                local button2Width = self.button2:GetWidth() or 120
                local spacing = 13
                local totalWidth = button1Width + spacing + button2Width
                
                self.button1:ClearAllPoints()
                self.button1:SetPoint("BOTTOM", self, "BOTTOM", -(totalWidth / 2 - button1Width / 2), 16)
                self.button2:ClearAllPoints()
                self.button2:SetPoint("LEFT", self.button1, "RIGHT", spacing, 0)
            end
            frame:Hide()
        end)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    text_width = 900,
    width = 1000,
    preferredIndex = 3,
}

local function createExitButton()
    if exitEditorButton then return; end

    exitEditorButton = CreateFrame("Button", "DragonUIExitEditorButton", UIParent, "UIPanelButtonTemplate");
    exitEditorButton:SetText("Выйти из режима редактора");
    exitEditorButton:SetSize(200, 28);
    exitEditorButton:SetPoint("CENTER", UIParent, "CENTER", 0, 200);
    exitEditorButton:SetFrameStrata("DIALOG");
    exitEditorButton:SetFrameLevel(100);

    local normalTexture = exitEditorButton:GetNormalTexture()
    if normalTexture then
        normalTexture:SetVertexColor(0.8, 0.3, 0.3, 1)
    end
    
    local highlightTexture = exitEditorButton:GetHighlightTexture()
    if highlightTexture then
        highlightTexture:SetVertexColor(1, 0.4, 0.4, 1)
    end
    
    local pushedTexture = exitEditorButton:GetPushedTexture()
    if pushedTexture then
        pushedTexture:SetVertexColor(0.6, 0.2, 0.2, 1)
    end
    
    local fontString = exitEditorButton:GetFontString()
    if fontString then
        fontString:SetTextColor(1, 1, 1, 1)
        fontString:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    end

    exitEditorButton:SetScript("OnClick", function()
        EditorMode:Toggle();
    end);

    exitEditorButton:Hide();
end

local function createResetAllButton()
    if resetAllButton then return; end

    resetAllButton = CreateFrame("Button", "DragonUIResetAllButton", UIParent, "UIPanelButtonTemplate");
    resetAllButton:SetText("Сбросить все позиции");
    resetAllButton:SetSize(200, 28);
    resetAllButton:SetPoint("CENTER", UIParent, "CENTER", 0, 165);
    resetAllButton:SetFrameStrata("DIALOG");
    resetAllButton:SetFrameLevel(100);

    local normalTexture = resetAllButton:GetNormalTexture()
    if normalTexture then
        normalTexture:SetVertexColor(0.8, 0.3, 0.3, 1)
    end
    
    local highlightTexture = resetAllButton:GetHighlightTexture()
    if highlightTexture then
        highlightTexture:SetVertexColor(1, 0.4, 0.4, 1)
    end
    
    local pushedTexture = resetAllButton:GetPushedTexture()
    if pushedTexture then
        pushedTexture:SetVertexColor(0.6, 0.2, 0.2, 1)
    end
    
    local fontString = resetAllButton:GetFontString()
    if fontString then
        fontString:SetTextColor(1, 1, 1, 1)
        fontString:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    end

    resetAllButton:SetScript("OnClick", function()
        EditorMode:ShowResetConfirmation()
    end);

    resetAllButton:Hide()
end

local function createSnapToggleButton()
    if snapToggleButton then return; end
    snapToggleButton = CreateFrame("Button", "DragonUISnapToggleButton", UIParent, "UIPanelButtonTemplate");
    snapToggleButton:SetText("Магнит: ВКЛ");
    snapToggleButton:SetSize(100, 28);
    snapToggleButton:SetPoint("CENTER", UIParent, "CENTER", -52, 130);
    snapToggleButton:SetFrameStrata("DIALOG");
    snapToggleButton:SetFrameLevel(100);

    local normalTexture = snapToggleButton:GetNormalTexture()
    if normalTexture then
        normalTexture:SetVertexColor(0.3, 0.6, 0.8, 1)
    end
    
    local highlightTexture = snapToggleButton:GetHighlightTexture()
    if highlightTexture then
        highlightTexture:SetVertexColor(0.4, 0.7, 1, 1)
    end
    
    local pushedTexture = snapToggleButton:GetPushedTexture()
    if pushedTexture then
        pushedTexture:SetVertexColor(0.2, 0.4, 0.6, 1)
    end
    
    local fontString = snapToggleButton:GetFontString()
    if fontString then
        fontString:SetTextColor(1, 1, 1, 1)
        fontString:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    end
    local function initializeSnapState()
        if addon.db and addon.db.profile then
            if not addon.db.profile.editor then
                addon.db.profile.editor = {}
            end
            if addon.db.profile.editor.snapEnabled == nil then
                addon.db.profile.editor.snapEnabled = true
            end
        end
    end
    
    initializeSnapState()

    local function updateButtonText()
        initializeSnapState()
        if addon.db and addon.db.profile.editor and addon.db.profile.editor.snapEnabled then
            snapToggleButton:SetText("Магнит: ВКЛ")
            if normalTexture then
                normalTexture:SetVertexColor(0.3, 0.8, 0.3, 1)
            end
        else
            snapToggleButton:SetText("Магнит: ВЫКЛ")
            if normalTexture then
                normalTexture:SetVertexColor(0.8, 0.3, 0.3, 1)
            end
        end
    end

    updateButtonText()

    snapToggleButton:SetScript("OnClick", function()
        initializeSnapState()
        if addon.db and addon.db.profile then
            if not addon.db.profile.editor then
                addon.db.profile.editor = {}
            end
            addon.db.profile.editor.snapEnabled = not addon.db.profile.editor.snapEnabled
            updateButtonText()
        end
    end);

    snapToggleButton:Hide()
end

local function createResetButton()
    if resetButton then return; end
    resetButton = CreateFrame("Button", "DragonUIResetButton", UIParent, "UIPanelButtonTemplate");
    resetButton:SetText("Сброс");
    resetButton:SetSize(100, 28);
    resetButton:SetPoint("LEFT", snapToggleButton, "RIGHT", 4, 0);
    resetButton:SetFrameStrata("DIALOG");
    resetButton:SetFrameLevel(100);

    local normalTexture = resetButton:GetNormalTexture()
    if normalTexture then
        normalTexture:SetVertexColor(0.8, 0.4, 0.2, 1)
    end
    
    local highlightTexture = resetButton:GetHighlightTexture()
    if highlightTexture then
        highlightTexture:SetVertexColor(1, 0.5, 0.3, 1)
    end
    
    local pushedTexture = resetButton:GetPushedTexture()
    if pushedTexture then
        pushedTexture:SetVertexColor(0.6, 0.3, 0.1, 1)
    end
    
    local fontString = resetButton:GetFontString()
    if fontString then
        fontString:SetTextColor(1, 1, 1, 1)
        fontString:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    end

    resetButton:SetScript("OnClick", function()
        if not savedFramePositions then
            return
        end
        
        for frameName, frameData in pairs(addon.EditableFrames) do
            if savedFramePositions[frameName] and frameData.frame then
                local saved = savedFramePositions[frameName]
                frameData.frame:ClearAllPoints()
                
                local relativeTo = saved.relativeTo
                if not relativeTo or not relativeTo.GetObjectType then
                    relativeTo = UIParent
                end
                
                frameData.frame:SetPoint(saved.point, relativeTo, saved.relativePoint, saved.xOfs, saved.yOfs)
                
                if #frameData.configPath == 2 then
                    SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2])
                else
                    SaveUIFramePosition(frameData.frame, frameData.configPath[1])
                end
            end
        end
    end);

    resetButton:Hide()
end

local function createGridOverlay()
    if gridOverlay then return; end

    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    local cellSize = 32
    local halfCellsHorizontal = math.floor((screenWidth / 2) / cellSize)
    local halfCellsVertical = math.floor((screenHeight / 2) / cellSize)
    
    local totalHorizontalCells = halfCellsHorizontal * 2
    local totalVerticalCells = halfCellsVertical * 2
    
    local actualCellWidth = screenWidth / totalHorizontalCells
    local actualCellHeight = screenHeight / totalVerticalCells
    
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    
    gridOverlay = CreateFrame('Frame', "DragonUIGridOverlay", UIParent)
    gridOverlay:SetAllPoints(UIParent)
    gridOverlay:SetFrameStrata("BACKGROUND")
    gridOverlay:SetFrameLevel(0)

    local background = gridOverlay:CreateTexture("DragonUIGridBackground", 'BACKGROUND')
    background:SetAllPoints(gridOverlay)
    background:SetTexture(0, 0, 0, 0.3)
    background:SetDrawLayer('BACKGROUND', -1)

    local lineThickness = 1

    for i = 0, totalHorizontalCells do
        local line = gridOverlay:CreateTexture("DragonUIGridV"..i, 'BACKGROUND')
        
        if i == halfCellsHorizontal then
            line:SetTexture(1, 0, 0, 0.8)
        else
            line:SetTexture(1, 1, 1, 0.3)
        end
        
        local x = i * actualCellWidth
        line:SetPoint("TOPLEFT", gridOverlay, "TOPLEFT", x - (lineThickness / 2), 0)
        line:SetPoint('BOTTOMRIGHT', gridOverlay, 'BOTTOMLEFT', x + (lineThickness / 2), 0)
    end

    for i = 0, totalVerticalCells do
        local line = gridOverlay:CreateTexture("DragonUIGridH"..i, 'BACKGROUND')
        
        if i == halfCellsVertical then
            line:SetTexture(1, 0, 0, 0.8)
        else
            line:SetTexture(1, 1, 1, 0.3)
        end
        
        local y = i * actualCellHeight
        line:SetPoint("TOPLEFT", gridOverlay, "TOPLEFT", 0, -y + (lineThickness / 2))
        line:SetPoint('BOTTOMRIGHT', gridOverlay, 'TOPRIGHT', 0, -y - (lineThickness / 2))
    end
    
    gridOverlay:Hide()
end

function EditorMode:Show()
    if InCombatLockdown() then
        
        return
    end

    createGridOverlay()
    createExitButton()
    createResetAllButton()
    createSnapToggleButton()
    createResetButton()
    
    savedFramePositions = {}
    for frameName, frameData in pairs(addon.EditableFrames) do
        if frameData.frame then
            local point, relativeTo, relativePoint, xOfs, yOfs = frameData.frame:GetPoint()
            savedFramePositions[frameName] = {
                point = point or "CENTER",
                relativeTo = relativeTo,
                relativePoint = relativePoint or point or "CENTER",
                xOfs = xOfs or 0,
                yOfs = yOfs or 0
            }
        end
    end
    
    gridOverlay:Show()
    exitEditorButton:Show()
    resetAllButton:Show()
    snapToggleButton:Show()
    resetButton:Show()

    addon:ShowAllEditableFrames()
    
    if addon.EnableActionBarOverlays then
        addon.EnableActionBarOverlays()
    end
    
    EditorMode:InstallScaleHooks()
    
    if addon.UpdateOverlaySizes then
        addon.UpdateOverlaySizes()
    end
    
    self:RefreshOptionsUI()
end


function EditorMode:Hide(showReloadPopup)
    if gridOverlay then gridOverlay:Hide() end
    if exitEditorButton then exitEditorButton:Hide() end
    if resetAllButton then resetAllButton:Hide() end
    if snapToggleButton then snapToggleButton:Hide() end
    if resetButton then resetButton:Hide() end
    
    -- CRITICAL: Check if any frames were actually moved before showing reload dialog
    local hasChanges = false
    if savedFramePositions then
        for frameName, frameData in pairs(addon.EditableFrames) do
            if frameData.frame and savedFramePositions[frameName] then
                local saved = savedFramePositions[frameName]
                local point, relativeTo, relativePoint, xOfs, yOfs = frameData.frame:GetPoint()
                
                -- Normalize relativeTo for comparison
                local savedRelativeTo = saved.relativeTo
                local currentRelativeTo = relativeTo
                
                -- Compare positions (with small tolerance for floating point errors)
                local tolerance = 0.1
                local xDiff = math.abs((xOfs or 0) - (saved.xOfs or 0))
                local yDiff = math.abs((yOfs or 0) - (saved.yOfs or 0))
                
                -- Check if point changed
                local pointChanged = (point or "CENTER") ~= (saved.point or "CENTER")
                local relativePointChanged = (relativePoint or point or "CENTER") ~= (saved.relativePoint or saved.point or "CENTER")
                
                -- Check if position changed significantly
                if pointChanged or relativePointChanged or xDiff > tolerance or yDiff > tolerance then
                    hasChanges = true
                    break
                end
            end
        end
    end
    
    savedFramePositions = nil

    addon:HideAllEditableFrames(true)
    
    if addon.DisableActionBarOverlays then
        addon.DisableActionBarOverlays()
    end
    
    EditorMode:RemoveScaleHooks()
    
    self:RefreshOptionsUI()
    
    -- CRITICAL: Only show reload dialog if frames were actually moved
    if showReloadPopup ~= false and hasChanges then
        StaticPopup_Show("DragonUI_RELOAD_UI")
    end
end

function EditorMode:RefreshOptionsUI()
    addon.core:ScheduleTimer(function()
        local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
        if AceConfigRegistry then
            AceConfigRegistry:NotifyChange("DragonUI")
        end
    end, 0.1)
end

function EditorMode:Toggle()
    if self:IsActive() then 
        self:Hide(true)
    else 
        self:Show() 
    end
end

function EditorMode:IsActive()
    return gridOverlay and gridOverlay:IsShown()
end

SLASH_NozdorUI_EDITOR1 = "/duiedit"
SLASH_NozdorUI_EDITOR2 = "/dragonedit"
SlashCmdList["NozdorUI_EDITOR"] = function()
    EditorMode:Toggle()
end

local scaleHooks = {}

function EditorMode:InstallScaleHooks()
end

function EditorMode:RemoveScaleHooks()
    scaleHooks.xpbar = nil
    scaleHooks.repbar = nil
end

function EditorMode:ShowResetConfirmation()
    StaticPopup_Show("DragonUI_RESET_ALL_POSITIONS")
end

function EditorMode:ResetAllPositions()
    if not addon.db or not addon.db.profile then
        return
    end
    
    if self:IsActive() then
        self:Hide(false)
    end
    
    if addon.defaults and addon.defaults.profile and addon.defaults.profile.widgets then
        addon.db.profile.widgets = addon:CopyTable(addon.defaults.profile.widgets)
    else
        return
    end
    
    ReloadUI()
end

if not addon.CopyTable then
    function addon:CopyTable(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                copy[addon:CopyTable(orig_key)] = addon:CopyTable(orig_value)
            end
            setmetatable(copy, addon:CopyTable(getmetatable(orig)))
        else
            copy = orig
        end
        return copy
    end
end

StaticPopupDialogs["DragonUI_RESET_ALL_POSITIONS"] = {
    text = "Вы уверены, что хотите сбросить все элементы интерфейса к их позициям по умолчанию?",
    button1 = "Да",
    button2 = "Нет",
    OnAccept = function()
        EditorMode:ResetAllPositions()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
