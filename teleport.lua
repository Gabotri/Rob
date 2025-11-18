--[==[
    MÓDULO: Teleport Manager v1.2 (Safe Mode & Config Persistence)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - Modos: Instantâneo (CFrame) e Seguro (Tween/Velocidade).
    - Salva Pontos + Configurações (Modo/Speed) por Jogo.
    - Noclip automático durante o voo seguro.
]==]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO TELEPORT: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. SERVIÇOS E VARIÁVEIS
local LogarEvento = Chassi.LogarEvento
local pCreate = Chassi.pCreate
local TabMundo = Chassi.Abas.Mundo

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

local FileName = "Gabotri_TP_" .. tostring(game.PlaceId) .. "_v2.json"
local SavedPoints = {} 
local CurrentTween = nil
local NoclipConnection = nil

-- Configurações Padrão (serão sobrescritas se houver save)
local Settings = {
    Mode = "Instant", -- "Instant" ou "Safe"
    SafeSpeed = 100   -- Velocidade do Tween
}

-- Elementos UI para referência
local ScreenGui, MainFrame, ScrollList, TPToggleUI
local BtnMode, InputSpeed -- Precisamos referenciar para atualizar visualmente ao carregar

-- 3. SISTEMA DE ARQUIVOS (JSON COMPLEXO)
--========================================================================
local function SalvarArquivo()
    -- Estrutura composta: Configurações + Pontos
    local data = {
        Settings = Settings,
        Points = SavedPoints
    }
    local json = HttpService:JSONEncode(data)
    pcall(function() writefile(FileName, json) end)
    LogarEvento("SUCESSO", "Dados e Configurações salvos.")
end

local function AtualizarVisualMode()
    if not BtnMode then return end
    if Settings.Mode == "Safe" then
        BtnMode.Text = "MODO: SEGURO (Tween)"
        BtnMode.BackgroundColor3 = Color3.fromRGB(0, 180, 100) -- Verde
    else
        BtnMode.Text = "MODO: INSTANT (TP)"
        BtnMode.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Vermelho
    end
    if InputSpeed then InputSpeed.Text = tostring(Settings.SafeSpeed) end
end

local function CarregarArquivo()
    -- Tenta carregar o V2
    if isfile and isfile(FileName) then
        local success, content = pcall(function() return readfile(FileName) end)
        if success then
            local decoded = HttpService:JSONDecode(content)
            if decoded then
                -- Verifica se é o formato novo ou antigo
                if decoded.Settings then
                    Settings = decoded.Settings
                    SavedPoints = decoded.Points or {}
                else
                    SavedPoints = decoded -- Legado (apenas array)
                end
                LogarEvento("INFO", "Dados carregados. Modo: " .. Settings.Mode)
                AtualizarVisualMode()
            end
        end
    else
        -- Tenta buscar o arquivo da v1.1 para migrar (Opcional, mas útil)
        local oldFile = "Gabotri_TP_" .. tostring(game.PlaceId) .. ".json"
        if isfile and isfile(oldFile) then
            local success, content = pcall(function() return readfile(oldFile) end)
            if success then
                SavedPoints = HttpService:JSONDecode(content) or {}
                LogarEvento("AVISO", "Arquivo legado migrado para o formato v1.2")
            end
        end
    end
end

-- 4. FUNÇÕES DE TELEPORTE E FÍSICA
--========================================================================
local function EnableNoclip(state)
    if state then
        if NoclipConnection then NoclipConnection:Disconnect() end
        NoclipConnection = RunService.Stepped:Connect(function()
            if Player.Character then
                for _, v in pairs(Player.Character:GetChildren()) do
                    if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
                end
            end
        end)
    else
        if NoclipConnection then NoclipConnection:Disconnect() NoclipConnection = nil end
    end
end

local function TeleportTo(targetPos)
    local Char = Player.Character
    if not Char or not Char:FindFirstChild("HumanoidRootPart") then return end
    
    local Root = Char.HumanoidRootPart
    
    -- Cancela tween anterior se houver
    if CurrentTween then CurrentTween:Cancel() EnableNoclip(false) end
    
    if Settings.Mode == "Instant" then
        -- MODO INSTANTÂNEO
        Root.CFrame = CFrame.new(targetPos)
        LogarEvento("INFO", "Teleporte Instantâneo realizado.")
    
    elseif Settings.Mode == "Safe" then
        -- MODO SEGURO (Tween)
        local distance = (targetPos - Root.Position).Magnitude
        local speed = tonumber(Settings.SafeSpeed) or 50
        local timeInfo = distance / speed
        
        local tweenInfo = TweenInfo.new(timeInfo, Enum.EasingStyle.Linear)
        CurrentTween = TweenService:Create(Root, tweenInfo, {CFrame = CFrame.new(targetPos)})
        
        EnableNoclip(true) -- Ativa noclip para não bater em paredes
        CurrentTween:Play()
        
        LogarEvento("INFO", "Iniciando TP Seguro (" .. math.floor(timeInfo) .. "s)...")
        
        CurrentTween.Completed:Connect(function()
            EnableNoclip(false)
            CurrentTween = nil
            LogarEvento("SUCESSO", "Chegou ao destino.")
        end)
    end
end

-- 5. CRIAÇÃO DA UI (PURA)
--========================================================================
ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GabotriTeleportUI_v1.2"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = true 

MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 170, 255)
MainFrame.Position = UDim2.new(0.75, 0, 0.3, 0) 
MainFrame.Size = UDim2.new(0, 250, 0, 380) -- Maior para caber opções
MainFrame.Active = true
MainFrame.Draggable = true 

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame; Title.BackgroundColor3 = Color3.fromRGB(35, 35, 35); Title.Size = UDim2.new(1, 0, 0, 25)
Title.Text = "  TP Manager v1.2 [F2]"; Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left; Title.Font = Enum.Font.SourceSansBold; Title.TextSize = 14

local BtnCloseX = Instance.new("TextButton")
BtnCloseX.Parent = Title; BtnCloseX.Text = "X"; BtnCloseX.Size = UDim2.new(0, 25, 1, 0); BtnCloseX.Position = UDim2.new(1, -25, 0, 0)
BtnCloseX.BackgroundTransparency = 1; BtnCloseX.TextColor3 = Color3.fromRGB(255, 100, 100)
BtnCloseX.MouseButton1Click:Connect(function() ScreenGui.Enabled = false; if TPToggleUI then TPToggleUI:Set(false) end end)

-- Inputs
local InputName = Instance.new("TextBox")
InputName.Parent = MainFrame; InputName.PlaceholderText = "Nome do Local"; InputName.BackgroundColor3 = Color3.fromRGB(45, 45, 45); InputName.TextColor3 = Color3.fromRGB(255, 255, 255)
InputName.Position = UDim2.new(0.05, 0, 0.09, 0); InputName.Size = UDim2.new(0.9, 0, 0, 25)

local BtnGetCoords = Instance.new("TextButton")
BtnGetCoords.Parent = MainFrame; BtnGetCoords.Text = "PUXAR COORDENADAS"; BtnGetCoords.BackgroundColor3 = Color3.fromRGB(255, 150, 0); BtnGetCoords.TextColor3 = Color3.fromRGB(0, 0, 0)
BtnGetCoords.Position = UDim2.new(0.05, 0, 0.17, 0); BtnGetCoords.Size = UDim2.new(0.9, 0, 0, 20)

local InputX = Instance.new("TextBox"); InputX.Parent = MainFrame; InputX.PlaceholderText = "X"; InputX.BackgroundColor3 = Color3.fromRGB(40,40,40); InputX.TextColor3 = Color3.fromRGB(255,255,255)
InputX.Position = UDim2.new(0.05, 0, 0.24, 0); InputX.Size = UDim2.new(0.28, 0, 0, 25)
local InputY = Instance.new("TextBox"); InputY.Parent = MainFrame; InputY.PlaceholderText = "Y"; InputY.BackgroundColor3 = Color3.fromRGB(40,40,40); InputY.TextColor3 = Color3.fromRGB(255,255,255)
InputY.Position = UDim2.new(0.36, 0, 0.24, 0); InputY.Size = UDim2.new(0.28, 0, 0, 25)
local InputZ = Instance.new("TextBox"); InputZ.Parent = MainFrame; InputZ.PlaceholderText = "Z"; InputZ.BackgroundColor3 = Color3.fromRGB(40,40,40); InputZ.TextColor3 = Color3.fromRGB(255,255,255)
InputZ.Position = UDim2.new(0.67, 0, 0.24, 0); InputZ.Size = UDim2.new(0.28, 0, 0, 25)

-- === ÁREA DE CONFIGURAÇÃO DE MODO (NOVO) ===
BtnMode = Instance.new("TextButton")
BtnMode.Parent = MainFrame
BtnMode.Position = UDim2.new(0.05, 0, 0.32, 0)
BtnMode.Size = UDim2.new(0.6, 0, 0, 25)
BtnMode.Font = Enum.Font.SourceSansBold
BtnMode.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnMode.Text = "MODO: INSTANT (TP)" -- Padrão visual inicial
BtnMode.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
BtnMode.MouseButton1Click:Connect(function()
    -- Toggle Lógica
    if Settings.Mode == "Instant" then
        Settings.Mode = "Safe"
    else
        Settings.Mode = "Instant"
    end
    AtualizarVisualMode()
    SalvarArquivo() -- Salva a preferência
end)

InputSpeed = Instance.new("TextBox")
InputSpeed.Parent = MainFrame
InputSpeed.PlaceholderText = "Spd"
InputSpeed.Text = "100"
InputSpeed.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
InputSpeed.TextColor3 = Color3.fromRGB(255, 255, 255)
InputSpeed.Position = UDim2.new(0.68, 0, 0.32, 0)
InputSpeed.Size = UDim2.new(0.27, 0, 0, 25)
InputSpeed.FocusLost:Connect(function()
    local s = tonumber(InputSpeed.Text)
    if s then 
        Settings.SafeSpeed = s 
        SalvarArquivo() -- Salva a preferência
    end
end)
-- ==========================================

local BtnSave = Instance.new("TextButton")
BtnSave.Parent = MainFrame; BtnSave.Text = "ADICIONAR À LISTA"; BtnSave.BackgroundColor3 = Color3.fromRGB(0, 100, 180); BtnSave.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnSave.Position = UDim2.new(0.05, 0, 0.41, 0); BtnSave.Size = UDim2.new(0.9, 0, 0, 25)

ScrollList = Instance.new("ScrollingFrame")
ScrollList.Parent = MainFrame; ScrollList.BackgroundColor3 = Color3.fromRGB(30, 30, 30); ScrollList.Position = UDim2.new(0, 0, 0.50, 0)
ScrollList.Size = UDim2.new(1, 0, 0.50, 0); ScrollList.CanvasSize = UDim2.new(0, 0, 0, 0); ScrollList.ScrollBarThickness = 6

-- Funções Lógicas UI
BtnGetCoords.MouseButton1Click:Connect(function()
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local pos = Player.Character.HumanoidRootPart.Position
        InputX.Text = string.format("%.1f", pos.X)
        InputY.Text = string.format("%.1f", pos.Y)
        InputZ.Text = string.format("%.1f", pos.Z)
        if InputName.Text == "" then InputName.Text = "Ponto " .. (#SavedPoints + 1) end
    end
end)

local function RefreshList()
    for _, child in pairs(ScrollList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    local yOffset = 0
    for i, point in ipairs(SavedPoints) do
        local ItemFrame = Instance.new("Frame"); ItemFrame.Parent = ScrollList; ItemFrame.Size = UDim2.new(1, -10, 0, 25); ItemFrame.Position = UDim2.new(0, 5, 0, yOffset)
        ItemFrame.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(40, 40, 40); ItemFrame.BorderSizePixel = 0
        
        local LblName = Instance.new("TextLabel"); LblName.Parent = ItemFrame; LblName.Size = UDim2.new(0.55, 0, 1, 0); LblName.Position = UDim2.new(0.02, 0, 0, 0)
        LblName.BackgroundTransparency = 1; LblName.TextColor3 = Color3.fromRGB(255, 255, 255); LblName.TextXAlignment = Enum.TextXAlignment.Left; LblName.Text = point.name
        
        local BtnGo = Instance.new("TextButton"); BtnGo.Parent = ItemFrame; BtnGo.Size = UDim2.new(0.15, 0, 0.8, 0); BtnGo.Position = UDim2.new(0.6, 0, 0.1, 0)
        BtnGo.Text = "IR"; BtnGo.BackgroundColor3 = Color3.fromRGB(0, 120, 200); BtnGo.TextColor3 = Color3.fromRGB(255, 255, 255)
        BtnGo.MouseButton1Click:Connect(function() TeleportTo(Vector3.new(point.x, point.y, point.z)) end)
        
        local BtnDel = Instance.new("TextButton"); BtnDel.Parent = ItemFrame; BtnDel.Size = UDim2.new(0.15, 0, 0.8, 0); BtnDel.Position = UDim2.new(0.8, 0, 0.1, 0)
        BtnDel.Text = "X"; BtnDel.BackgroundColor3 = Color3.fromRGB(200, 50, 50); BtnDel.TextColor3 = Color3.fromRGB(255, 255, 255)
        BtnDel.MouseButton1Click:Connect(function() table.remove(SavedPoints, i); SalvarArquivo(); RefreshList() end)
        yOffset = yOffset + 30
    end
    ScrollList.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

BtnSave.MouseButton1Click:Connect(function()
    local x, y, z = tonumber(InputX.Text), tonumber(InputY.Text), tonumber(InputZ.Text)
    if x and y and z then
        local name = InputName.Text
        if name == "" then name = "Coords" end
        table.insert(SavedPoints, {name = name, x = x, y = y, z = z})
        SalvarArquivo()
        RefreshList()
    end
end)

-- 6. INTEGRAÇÃO
--========================================================================
if TabMundo then
    TPToggleUI = pCreate("ToggleTPMenu", TabMundo, "CreateToggle", {
        Name = "Menu Teleporte (UI) [F2]",
        CurrentValue = true,
        Callback = function(Val) ScreenGui.Enabled = Val end
    })
end

UserInputService.InputBegan:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.F2 then
        local newState = not ScreenGui.Enabled
        ScreenGui.Enabled = newState
        if TPToggleUI then TPToggleUI:Set(newState) end
    end
end)

-- 7. START
CarregarArquivo()
RefreshList()
LogarEvento("SUCESSO", "Módulo Teleport Manager v1.2 (Híbrido) carregado.")