--[==[
    MÓDULO: Teleport Manager v1.1 (F2 & Toggle Sync)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - UI Pura integrada com o Chassi via Toggle e Atalho F2.
    - Botão "Puxar Coordenadas".
    - Inicia Aberto por padrão.
    - Salva pontos em JSON por jogo.
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
local TabMundo = Chassi.Abas.Mundo -- Colocado na aba Mundo

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

local FileName = "Gabotri_TP_" .. tostring(game.PlaceId) .. ".json"
local SavedPoints = {} 
local ScrollList 
local TPToggleUI -- Referência para atualizar o toggle visualmente

-- 3. SISTEMA DE ARQUIVOS (JSON)
--========================================================================
local function SalvarArquivo()
    local json = HttpService:JSONEncode(SavedPoints)
    pcall(function() writefile(FileName, json) end)
    LogarEvento("SUCESSO", "Pontos salvos no JSON local.")
end

local function CarregarArquivo()
    if isfile and isfile(FileName) then
        local success, content = pcall(function() return readfile(FileName) end)
        if success then
            local decoded = HttpService:JSONDecode(content)
            if decoded then SavedPoints = decoded end
        end
    end
end

-- 4. FUNÇÃO DE TELEPORTE
--========================================================================
local function TeleportTo(posVector)
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        Player.Character.HumanoidRootPart.CFrame = CFrame.new(posVector)
    end
end

-- 5. CRIAÇÃO DA UI (PURA)
--========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GabotriTeleportUI_v1.1"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = true -- [MUDANÇA] Já vem ligado

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 170, 255)
MainFrame.Position = UDim2.new(0.75, 0, 0.3, 0) 
MainFrame.Size = UDim2.new(0, 240, 0, 320)
MainFrame.Active = true
MainFrame.Draggable = true 

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Text = "  TP Manager [F2]"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 14

local BtnCloseX = Instance.new("TextButton")
BtnCloseX.Parent = Title
BtnCloseX.Text = "X"
BtnCloseX.Size = UDim2.new(0, 25, 1, 0)
BtnCloseX.Position = UDim2.new(1, -25, 0, 0)
BtnCloseX.BackgroundTransparency = 1
BtnCloseX.TextColor3 = Color3.fromRGB(255, 100, 100)
BtnCloseX.MouseButton1Click:Connect(function()
    ScreenGui.Enabled = false
    if TPToggleUI then TPToggleUI:Set(false) end -- Atualiza o toggle do Chassi
end)

-- Inputs e Botão Puxar
local InputName = Instance.new("TextBox")
InputName.Parent = MainFrame
InputName.PlaceholderText = "Nome do Local"
InputName.Text = ""
InputName.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
InputName.TextColor3 = Color3.fromRGB(255, 255, 255)
InputName.Position = UDim2.new(0.05, 0, 0.11, 0)
InputName.Size = UDim2.new(0.9, 0, 0, 25)

local BtnGetCoords = Instance.new("TextButton")
BtnGetCoords.Parent = MainFrame
BtnGetCoords.Text = "PUXAR COORDENADAS ATUAIS"
BtnGetCoords.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
BtnGetCoords.TextColor3 = Color3.fromRGB(0, 0, 0)
BtnGetCoords.Font = Enum.Font.SourceSansBold
BtnGetCoords.Position = UDim2.new(0.05, 0, 0.20, 0)
BtnGetCoords.Size = UDim2.new(0.9, 0, 0, 20)

local InputX = Instance.new("TextBox")
InputX.Parent = MainFrame; InputX.PlaceholderText = "X"; InputX.BackgroundColor3 = Color3.fromRGB(40,40,40); InputX.TextColor3 = Color3.fromRGB(255,255,255)
InputX.Position = UDim2.new(0.05, 0, 0.28, 0); InputX.Size = UDim2.new(0.28, 0, 0, 25)

local InputY = Instance.new("TextBox")
InputY.Parent = MainFrame; InputY.PlaceholderText = "Y"; InputY.BackgroundColor3 = Color3.fromRGB(40,40,40); InputY.TextColor3 = Color3.fromRGB(255,255,255)
InputY.Position = UDim2.new(0.36, 0, 0.28, 0); InputY.Size = UDim2.new(0.28, 0, 0, 25)

local InputZ = Instance.new("TextBox")
InputZ.Parent = MainFrame; InputZ.PlaceholderText = "Z"; InputZ.BackgroundColor3 = Color3.fromRGB(40,40,40); InputZ.TextColor3 = Color3.fromRGB(255,255,255)
InputZ.Position = UDim2.new(0.67, 0, 0.28, 0); InputZ.Size = UDim2.new(0.28, 0, 0, 25)

-- Lógica do Botão "Puxar Coordenadas"
BtnGetCoords.MouseButton1Click:Connect(function()
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local pos = Player.Character.HumanoidRootPart.Position
        InputX.Text = string.format("%.1f", pos.X)
        InputY.Text = string.format("%.1f", pos.Y)
        InputZ.Text = string.format("%.1f", pos.Z)
        if InputName.Text == "" then InputName.Text = "Ponto " .. (#SavedPoints + 1) end
        LogarEvento("INFO", "Coordenadas preenchidas automaticamente.")
    end
end)

-- Botão Salvar
local BtnSave = Instance.new("TextButton")
BtnSave.Parent = MainFrame
BtnSave.Text = "ADICIONAR À LISTA"
BtnSave.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
BtnSave.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnSave.Position = UDim2.new(0.05, 0, 0.38, 0)
BtnSave.Size = UDim2.new(0.9, 0, 0, 25)

-- Lista
ScrollList = Instance.new("ScrollingFrame")
ScrollList.Parent = MainFrame
ScrollList.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ScrollList.Position = UDim2.new(0, 0, 0.48, 0)
ScrollList.Size = UDim2.new(1, 0, 0.52, 0)
ScrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollList.ScrollBarThickness = 6

-- Atualizador de Lista
local function RefreshList()
    for _, child in pairs(ScrollList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local yOffset = 0
    for i, point in ipairs(SavedPoints) do
        local ItemFrame = Instance.new("Frame")
        ItemFrame.Parent = ScrollList
        ItemFrame.Size = UDim2.new(1, -10, 0, 25)
        ItemFrame.Position = UDim2.new(0, 5, 0, yOffset)
        ItemFrame.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(40, 40, 40)
        ItemFrame.BorderSizePixel = 0
        
        local LblName = Instance.new("TextLabel")
        LblName.Parent = ItemFrame
        LblName.Size = UDim2.new(0.55, 0, 1, 0)
        LblName.Position = UDim2.new(0.02, 0, 0, 0)
        LblName.BackgroundTransparency = 1
        LblName.TextColor3 = Color3.fromRGB(255, 255, 255)
        LblName.TextXAlignment = Enum.TextXAlignment.Left
        LblName.Text = point.name
        
        local BtnGo = Instance.new("TextButton")
        BtnGo.Parent = ItemFrame; BtnGo.Size = UDim2.new(0.15, 0, 0.8, 0); BtnGo.Position = UDim2.new(0.6, 0, 0.1, 0)
        BtnGo.Text = "IR"; BtnGo.BackgroundColor3 = Color3.fromRGB(0, 120, 200); BtnGo.TextColor3 = Color3.fromRGB(255, 255, 255)
        BtnGo.MouseButton1Click:Connect(function() TeleportTo(Vector3.new(point.x, point.y, point.z)) end)
        
        local BtnDel = Instance.new("TextButton")
        BtnDel.Parent = ItemFrame; BtnDel.Size = UDim2.new(0.15, 0, 0.8, 0); BtnDel.Position = UDim2.new(0.8, 0, 0.1, 0)
        BtnDel.Text = "X"; BtnDel.BackgroundColor3 = Color3.fromRGB(200, 50, 50); BtnDel.TextColor3 = Color3.fromRGB(255, 255, 255)
        BtnDel.MouseButton1Click:Connect(function()
            table.remove(SavedPoints, i)
            SalvarArquivo()
            RefreshList()
        end)
        
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

-- 6. INTEGRAÇÃO COM CHASSI (TabMundo + Atalho F2)
--========================================================================
if TabMundo then
    -- Toggle no Chassi
    TPToggleUI = pCreate("ToggleTPMenu", TabMundo, "CreateToggle", {
        Name = "Menu Teleporte (UI) [F2]",
        CurrentValue = true, -- Padrão ON
        Callback = function(Val)
            ScreenGui.Enabled = Val
        end
    })
end

-- Listener do F2
UserInputService.InputBegan:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.F2 then
        -- Inverte o estado
        local newState = not ScreenGui.Enabled
        ScreenGui.Enabled = newState
        LogarEvento("INFO", "Menu TP alternado via F2: " .. tostring(newState))
        
        -- Sincroniza com o Toggle do Sirius para não ficar visualmente errado
        if TPToggleUI then
            TPToggleUI:Set(newState)
        end
    end
end)

-- 7. INICIALIZAÇÃO
--========================================================================
CarregarArquivo()
RefreshList()
LogarEvento("SUCESSO", "Módulo Teleport Manager v1.1 carregado.")