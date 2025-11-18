--[==[
    MÓDULO: Teleport Manager (JSON Persistence) v1.0
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - UI Pura (Independente do Sirius).
    - Salva pontos em JSON baseado no ID do Jogo (PlaceId).
    - Hotkey 'G' para marcar ponto rápido.
    - Lista interativa com Teleport/Delete.
]==]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO TELEPORT: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. SERVIÇOS E VARIÁVEIS
local LogarEvento = Chassi.LogarEvento
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

local FileName = "Gabotri_TP_" .. tostring(game.PlaceId) .. ".json"
local SavedPoints = {} -- Tabela que guardará {name, x, y, z}
local ScrollList -- Referência para atualizar a lista visual

-- 3. SISTEMA DE ARQUIVOS (JSON)
--========================================================================
local function SalvarArquivo()
    local json = HttpService:JSONEncode(SavedPoints)
    local success, err = pcall(function()
        writefile(FileName, json)
    end)
    
    if success then
        LogarEvento("SUCESSO", "Pontos salvos em: " .. FileName)
    else
        LogarEvento("ERRO", "Falha ao salvar JSON: " .. tostring(err))
    end
end

local function CarregarArquivo()
    if isfile and isfile(FileName) then
        local success, content = pcall(function()
            return readfile(FileName)
        end)
        
        if success then
            local decoded = HttpService:JSONDecode(content)
            if decoded then
                SavedPoints = decoded
                LogarEvento("INFO", "Carregados " .. #SavedPoints .. " pontos de teleporte.")
            end
        else
            LogarEvento("ERRO", "Falha ao ler JSON: " .. tostring(content))
        end
    else
        LogarEvento("AVISO", "Nenhum save encontrado para este jogo. Criando novo...")
    end
end

-- 4. FUNÇÃO DE TELEPORTE
--========================================================================
local function TeleportTo(posVector)
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        Player.Character.HumanoidRootPart.CFrame = CFrame.new(posVector)
        LogarEvento("INFO", "Teleportado para: " .. tostring(posVector))
    end
end

-- 5. CRIAÇÃO DA UI (PURA / INSTANCE.NEW)
--========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GabotriTeleportUI"
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 170, 255)
MainFrame.Position = UDim2.new(0.7, 0, 0.3, 0) -- Começa na direita
MainFrame.Size = UDim2.new(0, 250, 0, 350)
MainFrame.Active = true
MainFrame.Draggable = true -- Pode arrastar

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Text = "  TP Manager (JSON) - [G]"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 14

-- Inputs
local InputName = Instance.new("TextBox")
InputName.Parent = MainFrame
InputName.PlaceholderText = "Nome do Ponto (ex: Base)"
InputName.Text = ""
InputName.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
InputName.TextColor3 = Color3.fromRGB(255, 255, 255)
InputName.Position = UDim2.new(0.05, 0, 0.1, 0)
InputName.Size = UDim2.new(0.9, 0, 0, 25)

local InputX = Instance.new("TextBox")
InputX.Parent = MainFrame
InputX.PlaceholderText = "X"
InputX.Position = UDim2.new(0.05, 0, 0.2, 0)
InputX.Size = UDim2.new(0.25, 0, 0, 25)
InputX.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
InputX.TextColor3 = Color3.fromRGB(255, 255, 255)

local InputY = Instance.new("TextBox")
InputY.Parent = MainFrame
InputY.PlaceholderText = "Y"
InputY.Position = UDim2.new(0.375, 0, 0.2, 0)
InputY.Size = UDim2.new(0.25, 0, 0, 25)
InputY.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
InputY.TextColor3 = Color3.fromRGB(255, 255, 255)

local InputZ = Instance.new("TextBox")
InputZ.Parent = MainFrame
InputZ.PlaceholderText = "Z"
InputZ.Position = UDim2.new(0.7, 0, 0.2, 0)
InputZ.Size = UDim2.new(0.25, 0, 0, 25)
InputZ.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
InputZ.TextColor3 = Color3.fromRGB(255, 255, 255)

-- Botões de Ação
local BtnTeleport = Instance.new("TextButton")
BtnTeleport.Parent = MainFrame
BtnTeleport.Text = "IR (Coords)"
BtnTeleport.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
BtnTeleport.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnTeleport.Position = UDim2.new(0.05, 0, 0.3, 0)
BtnTeleport.Size = UDim2.new(0.4, 0, 0, 25)
BtnTeleport.MouseButton1Click:Connect(function()
    local x, y, z = tonumber(InputX.Text), tonumber(InputY.Text), tonumber(InputZ.Text)
    if x and y and z then TeleportTo(Vector3.new(x, y, z)) end
end)

local BtnSave = Instance.new("TextButton")
BtnSave.Parent = MainFrame
BtnSave.Text = "SALVAR NA LISTA"
BtnSave.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
BtnSave.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnSave.Position = UDim2.new(0.55, 0, 0.3, 0)
BtnSave.Size = UDim2.new(0.4, 0, 0, 25)

-- Lista (ScrollingFrame)
ScrollList = Instance.new("ScrollingFrame")
ScrollList.Parent = MainFrame
ScrollList.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ScrollList.Position = UDim2.new(0, 0, 0.4, 0)
ScrollList.Size = UDim2.new(1, 0, 0.6, 0)
ScrollList.CanvasSize = UDim2.new(0, 0, 0, 0) -- Auto-ajuste depois
ScrollList.ScrollBarThickness = 6

-- Função para atualizar visual da lista
local function RefreshList()
    -- Limpa antigos
    for _, child in pairs(ScrollList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    -- Cria novos
    local yOffset = 0
    for i, point in ipairs(SavedPoints) do
        local ItemFrame = Instance.new("Frame")
        ItemFrame.Parent = ScrollList
        ItemFrame.Size = UDim2.new(1, -10, 0, 30)
        ItemFrame.Position = UDim2.new(0, 5, 0, yOffset)
        ItemFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        ItemFrame.BorderSizePixel = 0
        
        local LblName = Instance.new("TextLabel")
        LblName.Parent = ItemFrame
        LblName.Size = UDim2.new(0.5, 0, 1, 0)
        LblName.Position = UDim2.new(0.02, 0, 0, 0)
        LblName.BackgroundTransparency = 1
        LblName.TextColor3 = Color3.fromRGB(255, 255, 255)
        LblName.TextXAlignment = Enum.TextXAlignment.Left
        LblName.Text = point.name
        
        local BtnGo = Instance.new("TextButton")
        BtnGo.Parent = ItemFrame
        BtnGo.Size = UDim2.new(0.2, 0, 0.8, 0)
        BtnGo.Position = UDim2.new(0.55, 0, 0.1, 0)
        BtnGo.Text = "IR"
        BtnGo.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
        BtnGo.TextColor3 = Color3.fromRGB(255, 255, 255)
        BtnGo.MouseButton1Click:Connect(function()
            TeleportTo(Vector3.new(point.x, point.y, point.z))
        end)
        
        local BtnDel = Instance.new("TextButton")
        BtnDel.Parent = ItemFrame
        BtnDel.Size = UDim2.new(0.2, 0, 0.8, 0)
        BtnDel.Position = UDim2.new(0.78, 0, 0.1, 0)
        BtnDel.Text = "X"
        BtnDel.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        BtnDel.TextColor3 = Color3.fromRGB(255, 255, 255)
        BtnDel.MouseButton1Click:Connect(function()
            table.remove(SavedPoints, i)
            SalvarArquivo()
            RefreshList()
            LogarEvento("AVISO", "Ponto '"..point.name.."' removido.")
        end)
        
        yOffset = yOffset + 35
    end
    ScrollList.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

-- Lógica do Botão Salvar
BtnSave.MouseButton1Click:Connect(function()
    local name = InputName.Text
    if name == "" then name = "Ponto " .. (#SavedPoints + 1) end
    
    local x, y, z = tonumber(InputX.Text), tonumber(InputY.Text), tonumber(InputZ.Text)
    
    if x and y and z then
        table.insert(SavedPoints, {name = name, x = x, y = y, z = z})
        SalvarArquivo()
        RefreshList()
        LogarEvento("SUCESSO", "Ponto '"..name.."' salvo na lista.")
    else
        LogarEvento("ERRO", "Coordenadas inválidas para salvar.")
    end
end)

-- 6. HOTKEY 'G' (Marcar Ponto)
--========================================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    
    if input.KeyCode == Enum.KeyCode.G then
        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            local pos = Player.Character.HumanoidRootPart.Position
            
            -- Preenche a UI
            InputX.Text = string.format("%.2f", pos.X)
            InputY.Text = string.format("%.2f", pos.Y)
            InputZ.Text = string.format("%.2f", pos.Z)
            InputName.Text = "Ponto Marcado " .. (#SavedPoints + 1)
            
            LogarEvento("INFO", "Posição marcada com 'G'. Clique em Salvar para confirmar.")
        end
    end
end)

-- 7. INICIALIZAÇÃO
--========================================================================
CarregarArquivo()
RefreshList()
LogarEvento("SUCESSO", "Módulo Teleport Manager (UI Pura) carregado.")