--[==[
    MÓDULO: Teleport Manager v1.4 (UI Remaster & Gizmo Fix)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - Interface limpa, organizada e moderna (UI Pura).
    - Lista de pontos com rolagem independente.
    - Gizmos 3D funcionais.
    - Modos Safe/Instant + TP Click (Ctrl+Click).
]==]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO TELEPORT: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. SERVIÇOS
local LogarEvento = Chassi.LogarEvento
local pCreate = Chassi.pCreate
local TabMundo = Chassi.Abas.Mundo

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local FileName = "Gabotri_TP_" .. tostring(game.PlaceId) .. "_v3.json"
local SavedPoints = {} 
local CurrentTween = nil
local NoclipConnection = nil
local GizmoFolder = nil

-- Configurações
local Settings = {
    Mode = "Instant",   -- "Instant" ou "Safe"
    SafeSpeed = 100,
    ShowGizmos = true
}

-- Referências UI
local ScreenGui, PointListScroll
local BtnModeDisplay -- Para atualizar texto

-- 3. SISTEMA DE ARQUIVOS
--========================================================================
local function AtualizarGizmos()
    -- Limpa antigos
    if GizmoFolder then GizmoFolder:Destroy() end
    
    if not Settings.ShowGizmos then return end
    
    GizmoFolder = Instance.new("Folder", Workspace)
    GizmoFolder.Name = "GabotriGizmos_v1.4"
    
    for _, pt in ipairs(SavedPoints) do
        if pt.x and pt.y and pt.z then
            local part = Instance.new("Part")
            part.Name = "GIZMO_" .. pt.name
            part.Shape = Enum.PartType.Ball
            part.Size = Vector3.new(1.5, 1.5, 1.5)
            part.Position = Vector3.new(pt.x, pt.y, pt.z)
            part.Anchored = true
            part.CanCollide = false
            part.Material = Enum.Material.Neon
            part.Color = Color3.fromRGB(0, 255, 255) -- Ciano
            part.Transparency = 0.4
            part.Parent = GizmoFolder
            
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 100, 0, 40)
            bb.Adornee = part
            bb.AlwaysOnTop = true -- Vê através da parede
            bb.StudsOffset = Vector3.new(0, 2, 0)
            bb.Parent = part
            
            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1,0,1,0)
            txt.BackgroundTransparency = 1
            txt.Text = pt.name .. "\n(" .. math.floor(pt.dist or 0) .. "m)" -- Distancia atualiza depois ou fica estática
            txt.TextColor3 = Color3.new(1,1,1)
            txt.TextStrokeTransparency = 0
            txt.Font = Enum.Font.SourceSansBold
            txt.TextSize = 12
            txt.Parent = bb
        end
    end
end

local function SalvarArquivo()
    local data = { Settings = Settings, Points = SavedPoints }
    pcall(function() writefile(FileName, HttpService:JSONEncode(data)) end)
    AtualizarGizmos()
end

local function CarregarArquivo()
    if isfile and isfile(FileName) then
        local s, c = pcall(function() return readfile(FileName) end)
        if s then
            local d = HttpService:JSONDecode(c)
            if d then
                if d.Settings then Settings = d.Settings; SavedPoints = d.Points or {}
                else SavedPoints = d end
            end
        end
    end
    AtualizarGizmos()
end

-- 4. LÓGICA DE TELEPORTE
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
    
    if CurrentTween then CurrentTween:Cancel(); EnableNoclip(false) end
    
    if Settings.Mode == "Instant" then
        Root.CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
    elseif Settings.Mode == "Safe" then
        local dist = (targetPos - Root.Position).Magnitude
        local speed = tonumber(Settings.SafeSpeed) or 50
        local time = dist / speed
        
        local ti = TweenInfo.new(time, Enum.EasingStyle.Linear)
        CurrentTween = TweenService:Create(Root, ti, {CFrame = CFrame.new(targetPos)})
        
        EnableNoclip(true)
        CurrentTween:Play()
        
        LogarEvento("INFO", "Viajando... " .. math.floor(time) .. "s")
        CurrentTween.Completed:Connect(function() EnableNoclip(false); CurrentTween = nil end)
    end
end

-- 5. UI MANAGER (REMASTERIZADA)
--========================================================================
ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
ScreenGui.Name = "TPManager_v1.4"
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = true

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Position = UDim2.new(0.75, 0, 0.3, 0)
MainFrame.Size = UDim2.new(0, 280, 0, 450)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true

-- Cantos Arredondados
local UICorner = Instance.new("UICorner", MainFrame); UICorner.CornerRadius = UDim.new(0, 8)

-- Header
local Header = Instance.new("Frame", MainFrame)
Header.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Header.Size = UDim2.new(1, 0, 0, 30)
local HeaderCorner = Instance.new("UICorner", Header); HeaderCorner.CornerRadius = UDim.new(0, 8)
-- Tapa a parte de baixo do arredondamento do header para conectar com o frame
local HeaderFill = Instance.new("Frame", Header); HeaderFill.BorderSizePixel=0; HeaderFill.BackgroundColor3=Header.BackgroundColor3; HeaderFill.Size=UDim2.new(1,0,0,5); HeaderFill.Position=UDim2.new(0,0,1,-5)

local TitleLbl = Instance.new("TextLabel", Header)
TitleLbl.Text = "  TP Manager v1.4 [F2]"
TitleLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 14
TitleLbl.Size = UDim2.new(1, -30, 1, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Size = UDim2.new(0, 30, 1, 0)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

-- Container Superior (Controles Fixos)
local TopContainer = Instance.new("Frame", MainFrame)
TopContainer.BackgroundTransparency = 1
TopContainer.Position = UDim2.new(0, 10, 0, 35)
TopContainer.Size = UDim2.new(1, -20, 0, 190)

local UIL_Top = Instance.new("UIListLayout", TopContainer)
UIL_Top.SortOrder = Enum.SortOrder.LayoutOrder
UIL_Top.Padding = UDim.new(0, 5)

-- 1. Configurações (Mode / Speed / Gizmo)
local ConfigFrame = Instance.new("Frame", TopContainer)
ConfigFrame.LayoutOrder = 1
ConfigFrame.BackgroundTransparency = 1
ConfigFrame.Size = UDim2.new(1, 0, 0, 60)

BtnModeDisplay = Instance.new("TextButton", ConfigFrame)
BtnModeDisplay.Size = UDim2.new(0.58, 0, 0.45, 0)
BtnModeDisplay.Font = Enum.Font.GothamBold
BtnModeDisplay.TextSize = 12
BtnModeDisplay.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
BtnModeDisplay.TextColor3 = Color3.white
local Corner1 = Instance.new("UICorner", BtnModeDisplay); Corner1.CornerRadius = UDim.new(0, 4)

local InputSpeed = Instance.new("TextBox", ConfigFrame)
InputSpeed.Size = UDim2.new(0.38, 0, 0.45, 0)
InputSpeed.Position = UDim2.new(0.62, 0, 0, 0)
InputSpeed.PlaceholderText = "Speed"
InputSpeed.Text = tostring(Settings.SafeSpeed)
InputSpeed.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
InputSpeed.TextColor3 = Color3.white
local Corner2 = Instance.new("UICorner", InputSpeed); Corner2.CornerRadius = UDim.new(0, 4)

local BtnToggleGizmo = Instance.new("TextButton", ConfigFrame)
BtnToggleGizmo.Size = UDim2.new(1, 0, 0.45, 0)
BtnToggleGizmo.Position = UDim2.new(0, 0, 0.55, 0)
BtnToggleGizmo.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
BtnToggleGizmo.TextColor3 = Color3.white
BtnToggleGizmo.Font = Enum.Font.Gotham
BtnToggleGizmo.TextSize = 12
local Corner3 = Instance.new("UICorner", BtnToggleGizmo); Corner3.CornerRadius = UDim.new(0, 4)

local function UpdateConfigUI()
    if Settings.Mode == "Safe" then
        BtnModeDisplay.Text = "Safe (Tween)"
        BtnModeDisplay.BackgroundColor3 = Color3.fromRGB(0, 160, 100)
    else
        BtnModeDisplay.Text = "Instant (TP)"
        BtnModeDisplay.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    end
    BtnToggleGizmo.Text = "Gizmos 3D: " .. (Settings.ShowGizmos and "LIGADO" or "DESLIGADO")
end

BtnModeDisplay.MouseButton1Click:Connect(function()
    Settings.Mode = (Settings.Mode == "Instant") and "Safe" or "Instant"
    UpdateConfigUI(); SalvarArquivo()
end)
BtnToggleGizmo.MouseButton1Click:Connect(function()
    Settings.ShowGizmos = not Settings.ShowGizmos
    UpdateConfigUI(); SalvarArquivo()
end)
InputSpeed.FocusLost:Connect(function()
    Settings.SafeSpeed = tonumber(InputSpeed.Text) or 100
    SalvarArquivo()
end)
UpdateConfigUI()

-- 2. Criação de Ponto
local CreateFrame = Instance.new("Frame", TopContainer)
CreateFrame.LayoutOrder = 2
CreateFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
CreateFrame.Size = UDim2.new(1, 0, 0, 95)
local CornerC = Instance.new("UICorner", CreateFrame); CornerC.CornerRadius = UDim.new(0, 6)

local TitleCreate = Instance.new("TextLabel", CreateFrame)
TitleCreate.Text = "NOVO PONTO"
TitleCreate.Size = UDim2.new(1, 0, 0, 20)
TitleCreate.BackgroundTransparency = 1
TitleCreate.TextColor3 = Color3.fromRGB(150, 150, 150)
TitleCreate.Font = Enum.Font.GothamBold
TitleCreate.TextSize = 10

local InpName = Instance.new("TextBox", CreateFrame)
InpName.Size = UDim2.new(0.9, 0, 0, 22); InpName.Position = UDim2.new(0.05, 0, 0.25, 0)
InpName.PlaceholderText = "Nome do Local"; InpName.BackgroundColor3 = Color3.fromRGB(25, 25, 25); InpName.TextColor3 = Color3.white
local CornerN = Instance.new("UICorner", InpName); CornerN.CornerRadius = UDim.new(0, 4)

local InpX = Instance.new("TextBox", CreateFrame); InpX.Size = UDim2.new(0.28, 0, 0, 22); InpX.Position = UDim2.new(0.05, 0, 0.55, 0); InpX.PlaceholderText="X"; InpX.BackgroundColor3=Color3.fromRGB(25,25,25); InpX.TextColor3=Color3.white
local InpY = Instance.new("TextBox", CreateFrame); InpY.Size = UDim2.new(0.28, 0, 0, 22); InpY.Position = UDim2.new(0.36, 0, 0.55, 0); InpY.PlaceholderText="Y"; InpY.BackgroundColor3=Color3.fromRGB(25,25,25); InpY.TextColor3=Color3.white
local InpZ = Instance.new("TextBox", CreateFrame); InpZ.Size = UDim2.new(0.28, 0, 0, 22); InpZ.Position = UDim2.new(0.67, 0, 0.55, 0); InpZ.PlaceholderText="Z"; InpZ.BackgroundColor3=Color3.fromRGB(25,25,25); InpZ.TextColor3=Color3.white

local BtnGet = Instance.new("TextButton", CreateFrame); BtnGet.Text="GPS"; BtnGet.BackgroundColor3=Color3.fromRGB(255, 150, 0); BtnGet.TextColor3=Color3.black; BtnGet.Size=UDim2.new(0.15,0,0.52,0); BtnGet.Position=UDim2.new(0.83,0,0.25,0); Instance.new("UICorner", BtnGet).CornerRadius=UDim.new(0,4)

local BtnSave = Instance.new("TextButton", TopContainer)
BtnSave.LayoutOrder = 3
BtnSave.Text = "SALVAR PONTO NA LISTA"
BtnSave.Size = UDim2.new(1, 0, 0, 25)
BtnSave.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
BtnSave.TextColor3 = Color3.white
BtnSave.Font = Enum.Font.GothamBold
local CornerS = Instance.new("UICorner", BtnSave); CornerS.CornerRadius = UDim.new(0, 4)

-- Lógica Botões Criação
BtnGet.MouseButton1Click:Connect(function()
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local p = Player.Character.HumanoidRootPart.Position
        InpX.Text=math.floor(p.X); InpY.Text=math.floor(p.Y); InpZ.Text=math.floor(p.Z)
    end
end)

-- Lista (Scroll Inferior)
local ListHeader = Instance.new("TextLabel", MainFrame)
ListHeader.Text = "PONTOS SALVOS"
ListHeader.Size = UDim2.new(1, 0, 0, 20)
ListHeader.Position = UDim2.new(0, 0, 0, 230)
ListHeader.BackgroundTransparency = 1
ListHeader.TextColor3 = Color3.fromRGB(150, 150, 150)
ListHeader.Font = Enum.Font.GothamBold
ListHeader.TextSize = 10

PointListScroll = Instance.new("ScrollingFrame", MainFrame)
PointListScroll.BackgroundTransparency = 1
PointListScroll.Position = UDim2.new(0, 10, 0, 250)
PointListScroll.Size = UDim2.new(1, -20, 1, -260)
PointListScroll.ScrollBarThickness = 4
PointListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local UIL_List = Instance.new("UIListLayout", PointListScroll)
UIL_List.SortOrder = Enum.SortOrder.LayoutOrder
UIL_List.Padding = UDim.new(0, 5)

local function RefreshList()
    -- Limpa lista visual
    for _, c in pairs(PointListScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    for i, pt in ipairs(SavedPoints) do
        local Item = Instance.new("Frame", PointListScroll)
        Item.Size = UDim2.new(1, 0, 0, 30)
        Item.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        local CornerI = Instance.new("UICorner", Item); CornerI.CornerRadius = UDim.new(0, 4)
        
        local NameL = Instance.new("TextLabel", Item)
        NameL.Text = pt.name
        NameL.Size = UDim2.new(0.6, 0, 1, 0)
        NameL.Position = UDim2.new(0.05, 0, 0, 0)
        NameL.BackgroundTransparency = 1
        NameL.TextColor3 = Color3.white
        NameL.TextXAlignment = Enum.TextXAlignment.Left
        NameL.Font = Enum.Font.Gotham
        NameL.TextSize = 12
        
        local GoBtn = Instance.new("TextButton", Item)
        GoBtn.Text = "IR"
        GoBtn.Size = UDim2.new(0.15, 0, 0.8, 0)
        GoBtn.Position = UDim2.new(0.65, 0, 0.1, 0)
        GoBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
        GoBtn.TextColor3 = Color3.white
        GoBtn.Font = Enum.Font.GothamBold
        Instance.new("UICorner", GoBtn).CornerRadius = UDim.new(0, 4)
        
        local DelBtn = Instance.new("TextButton", Item)
        DelBtn.Text = "X"
        DelBtn.Size = UDim2.new(0.15, 0, 0.8, 0)
        DelBtn.Position = UDim2.new(0.82, 0, 0.1, 0)
        DelBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
        DelBtn.TextColor3 = Color3.white
        DelBtn.Font = Enum.Font.GothamBold
        Instance.new("UICorner", DelBtn).CornerRadius = UDim.new(0, 4)
        
        GoBtn.MouseButton1Click:Connect(function() TeleportTo(Vector3.new(pt.x, pt.y, pt.z)) end)
        DelBtn.MouseButton1Click:Connect(function() table.remove(SavedPoints, i); SalvarArquivo(); RefreshList() end)
    end
    
    PointListScroll.CanvasSize = UDim2.new(0, 0, 0, #SavedPoints * 35)
end

BtnSave.MouseButton1Click:Connect(function()
    local x,y,z = tonumber(InpX.Text), tonumber(InpY.Text), tonumber(InpZ.Text)
    if x then
        local n = InpName.Text; if n=="" then n="Local "..(#SavedPoints+1) end
        table.insert(SavedPoints, {name=n, x=x, y=y, z=z})
        SalvarArquivo(); RefreshList()
    end
end)

-- 6. ATALHOS (F2 e CTRL+Click)
--========================================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.F2 then ScreenGui.Enabled = not ScreenGui.Enabled end
    
    if not gp and input.UserInputType == Enum.UserInputType.MouseButton1 then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            if Mouse.Target then
                TeleportTo(Mouse.Hit.Position + Vector3.new(0, 3, 0))
            end
        end
    end
end)

if TabMundo then
    pCreate("ToggleTPMenu", TabMundo, "CreateToggle", {
        Name = "Menu TP [F2]", CurrentValue = true, Callback = function(v) ScreenGui.Enabled = v end
    })
end

-- 7. INICIALIZAÇÃO
CarregarArquivo()
RefreshList()
LogarEvento("SUCESSO", "Módulo Teleport v1.4 (Remastered UI) carregado.")