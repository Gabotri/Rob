--[==[
    MÓDULO: Teleport Manager v1.6 (UI V2 & Logic Fix)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - Interface reorganizada com Auto-Layout (Zero sobreposição).
    - Correção de sincronia do Modo (Inicia Safe).
    - Velocidade baseada em Studs/s (Igual WalkSpeed).
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

local FileName = "Gabotri_TP_" .. tostring(game.PlaceId) .. "_v4.json"
local SavedPoints = {} 
local CurrentTween = nil
local NoclipConnection = nil
local GizmoFolder = nil

-- Configurações Padrão (Safe por segurança)
local Settings = {
    Mode = "Safe",      -- Padrão SAFE para evitar kicks
    SafeSpeed = 300,    -- 300 studs/s (Rápido, mas suave)
    ShowGizmos = true
}

-- UI Refs
local ScreenGui, PointListScroll, BtnModeDisplay, InpSpeed, BtnToggleGizmo

-- 3. SISTEMA DE ARQUIVOS
--========================================================================
local function AtualizarGizmos()
    if GizmoFolder then GizmoFolder:Destroy() end
    if not Settings.ShowGizmos then return end
    
    GizmoFolder = Instance.new("Folder", Workspace)
    GizmoFolder.Name = "GabotriGizmos_v1.6"
    
    for _, pt in ipairs(SavedPoints) do
        if pt.x and pt.y and pt.z then
            local part = Instance.new("Part")
            part.Shape = Enum.PartType.Ball; part.Size = Vector3.new(1.5,1.5,1.5); part.Anchored = true; part.CanCollide = false
            part.Position = Vector3.new(pt.x, pt.y, pt.z); part.Material = Enum.Material.Neon; part.Color = Color3.fromRGB(0, 255, 255); part.Transparency = 0.4
            part.Parent = GizmoFolder
            
            local bb = Instance.new("BillboardGui", part); bb.Size = UDim2.new(0,100,0,40); bb.AlwaysOnTop = true; bb.StudsOffset = Vector3.new(0,2,0)
            local txt = Instance.new("TextLabel", bb); txt.Size = UDim2.new(1,0,1,0); txt.BackgroundTransparency = 1; txt.Text = pt.name; txt.TextColor3 = Color3.fromRGB(255,255,255); txt.TextStrokeTransparency = 0; txt.Font = Enum.Font.GothamBold; txt.TextSize = 12
        end
    end
end

local function UpdateConfigUI()
    if not BtnModeDisplay then return end
    
    if Settings.Mode == "Safe" then
        BtnModeDisplay.Text = "MODO: SEGURO (Tween)"
        BtnModeDisplay.BackgroundColor3 = Color3.fromRGB(0, 180, 100) -- Verde
    else
        BtnModeDisplay.Text = "MODO: INSTANTÂNEO"
        BtnModeDisplay.BackgroundColor3 = Color3.fromRGB(200, 60, 60) -- Vermelho
    end
    
    if Settings.ShowGizmos then
        BtnToggleGizmo.Text = "GIZMOS: ON"
        BtnToggleGizmo.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    else
        BtnToggleGizmo.Text = "GIZMOS: OFF"
        BtnToggleGizmo.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
    
    InpSpeed.Text = tostring(Settings.SafeSpeed)
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
    UpdateConfigUI() -- FORÇA ATUALIZAÇÃO VISUAL AO CARREGAR
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
        Root.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
    elseif Settings.Mode == "Safe" then
        -- Cálculo: Tempo = Distancia / Velocidade (Studs per Second)
        local dist = (targetPos - Root.Position).Magnitude
        local speed = tonumber(Settings.SafeSpeed) or 300
        if speed <= 0 then speed = 16 end -- Proteção contra div/0
        
        local time = dist / speed
        
        local ti = TweenInfo.new(time, Enum.EasingStyle.Linear)
        CurrentTween = TweenService:Create(Root, ti, {CFrame = CFrame.new(targetPos)})
        
        EnableNoclip(true)
        CurrentTween:Play()
        
        LogarEvento("INFO", string.format("Viajando %.1fs (Vel: %d sps)", time, speed))
        CurrentTween.Completed:Connect(function() EnableNoclip(false); CurrentTween = nil end)
    end
end

-- 5. UI MANAGER V2 (AUTO LAYOUT)
--========================================================================
ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
ScreenGui.Name = "TPManager_v1.6"
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = true

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.Position = UDim2.new(0.75, 0, 0.3, 0)
MainFrame.Size = UDim2.new(0, 260, 0, 400)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
local MC = Instance.new("UICorner", MainFrame); MC.CornerRadius = UDim.new(0, 6)

-- --- HEADER ---
local Header = Instance.new("Frame", MainFrame)
Header.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
Header.Size = UDim2.new(1, 0, 0, 30)
local HC = Instance.new("UICorner", Header); HC.CornerRadius = UDim.new(0, 6)
local HF = Instance.new("Frame", Header); HF.BorderSizePixel=0; HF.BackgroundColor3=Header.BackgroundColor3; HF.Size=UDim2.new(1,0,0,5); HF.Position=UDim2.new(0,0,1,-5) -- Filler

local Title = Instance.new("TextLabel", Header)
Title.Text = "  TP Manager v1.6 [F2]"; Title.TextColor3 = Color3.fromRGB(240,240,240); Title.Font = Enum.Font.GothamBold; Title.TextSize = 14; Title.Size = UDim2.new(1,-30,1,0); Title.BackgroundTransparency = 1; Title.TextXAlignment = Enum.TextXAlignment.Left
local Close = Instance.new("TextButton", Header); Close.Text="X"; Close.TextColor3=Color3.fromRGB(255,80,80); Close.BackgroundTransparency=1; Close.Size=UDim2.new(0,30,1,0); Close.Position=UDim2.new(1,-30,0,0); Close.Font=Enum.Font.GothamBold
Close.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

-- --- ÁREA DE CONTEÚDO (PADDING & LIST) ---
local Content = Instance.new("Frame", MainFrame)
Content.BackgroundTransparency = 1
Content.Position = UDim2.new(0, 0, 0, 35)
Content.Size = UDim2.new(1, 0, 1, -35)

local UIList = Instance.new("UIListLayout", Content)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 8)
UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center

local UIPad = Instance.new("UIPadding", Content)
UIPad.PaddingTop = UDim.new(0, 5)
UIPad.PaddingLeft = UDim.new(0, 10)
UIPad.PaddingRight = UDim.new(0, 10)

-- SECTION 1: CONFIGS (Row 1 & 2)
local RowMode = Instance.new("Frame", Content)
RowMode.BackgroundTransparency = 1
RowMode.Size = UDim2.new(1, 0, 0, 25)
RowMode.LayoutOrder = 1

BtnModeDisplay = Instance.new("TextButton", RowMode)
BtnModeDisplay.Size = UDim2.new(0.65, 0, 1, 0)
BtnModeDisplay.Font = Enum.Font.GothamBold
BtnModeDisplay.TextSize = 11
BtnModeDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
local C1 = Instance.new("UICorner", BtnModeDisplay); C1.CornerRadius = UDim.new(0, 4)

InpSpeed = Instance.new("TextBox", RowMode)
InpSpeed.Size = UDim2.new(0.30, 0, 1, 0)
InpSpeed.Position = UDim2.new(0.70, 0, 0, 0)
InpSpeed.PlaceholderText = "Speed"
InpSpeed.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
InpSpeed.TextColor3 = Color3.fromRGB(255, 255, 255)
InpSpeed.Font = Enum.Font.Gotham
InpSpeed.TextSize = 12
local C2 = Instance.new("UICorner", InpSpeed); C2.CornerRadius = UDim.new(0, 4)

BtnToggleGizmo = Instance.new("TextButton", Content)
BtnToggleGizmo.LayoutOrder = 2
BtnToggleGizmo.Size = UDim2.new(1, 0, 0, 20)
BtnToggleGizmo.Font = Enum.Font.GothamBold
BtnToggleGizmo.TextSize = 11
BtnToggleGizmo.TextColor3 = Color3.fromRGB(255, 255, 255)
local C3 = Instance.new("UICorner", BtnToggleGizmo); C3.CornerRadius = UDim.new(0, 4)

-- SECTION 2: CRIAÇÃO
local Divider = Instance.new("Frame", Content); Divider.LayoutOrder=3; Divider.Size=UDim2.new(1,0,0,1); Divider.BackgroundColor3=Color3.fromRGB(60,60,60); Divider.BorderSizePixel=0

local RowCoords = Instance.new("Frame", Content); RowCoords.LayoutOrder=4; RowCoords.BackgroundTransparency=1; RowCoords.Size=UDim2.new(1,0,0,25)
local InpX = Instance.new("TextBox", RowCoords); InpX.Size=UDim2.new(0.22,0,1,0); InpX.PlaceholderText="X"; InpX.BackgroundColor3=Color3.fromRGB(45,45,50); InpX.TextColor3=Color3.white; Instance.new("UICorner", InpX).CornerRadius=UDim.new(0,4)
local InpY = Instance.new("TextBox", RowCoords); InpY.Size=UDim2.new(0.22,0,1,0); InpY.Position=UDim2.new(0.26,0,0,0); InpY.PlaceholderText="Y"; InpY.BackgroundColor3=Color3.fromRGB(45,45,50); InpY.TextColor3=Color3.white; Instance.new("UICorner", InpY).CornerRadius=UDim.new(0,4)
local InpZ = Instance.new("TextBox", RowCoords); InpZ.Size=UDim2.new(0.22,0,1,0); InpZ.Position=UDim2.new(0.52,0,0,0); InpZ.PlaceholderText="Z"; InpZ.BackgroundColor3=Color3.fromRGB(45,45,50); InpZ.TextColor3=Color3.white; Instance.new("UICorner", InpZ).CornerRadius=UDim.new(0,4)
local BtnGPS = Instance.new("TextButton", RowCoords); BtnGPS.Size=UDim2.new(0.20,0,1,0); BtnGPS.Position=UDim2.new(0.80,0,0,0); BtnGPS.Text="GPS"; BtnGPS.BackgroundColor3=Color3.fromRGB(255,150,0); BtnGPS.TextColor3=Color3.black; BtnGPS.Font=Enum.Font.GothamBold; Instance.new("UICorner", BtnGPS).CornerRadius=UDim.new(0,4)

local RowSave = Instance.new("Frame", Content); RowSave.LayoutOrder=5; RowSave.BackgroundTransparency=1; RowSave.Size=UDim2.new(1,0,0,25)
local InpName = Instance.new("TextBox", RowSave); InpName.Size=UDim2.new(0.65,0,1,0); InpName.PlaceholderText="Nome do Ponto"; InpName.BackgroundColor3=Color3.fromRGB(45,45,50); InpName.TextColor3=Color3.white; InpName.TextXAlignment=Enum.TextXAlignment.Left; Instance.new("UICorner", InpName).CornerRadius=UDim.new(0,4)
-- Adicionando padding no texto do input
local IPad = Instance.new("UIPadding", InpName); IPad.PaddingLeft=UDim.new(0,5)
local BtnSave = Instance.new("TextButton", RowSave); BtnSave.Size=UDim2.new(0.30,0,1,0); BtnSave.Position=UDim2.new(0.70,0,0,0); BtnSave.Text="SALVAR"; BtnSave.BackgroundColor3=Color3.fromRGB(0,120,200); BtnSave.TextColor3=Color3.white; BtnSave.Font=Enum.Font.GothamBold; Instance.new("UICorner", BtnSave).CornerRadius=UDim.new(0,4)

-- SECTION 3: LISTA
local Divider2 = Instance.new("Frame", Content); Divider2.LayoutOrder=6; Divider2.Size=UDim2.new(1,0,0,1); Divider2.BackgroundColor3=Color3.fromRGB(60,60,60); Divider2.BorderSizePixel=0

PointListScroll = Instance.new("ScrollingFrame", Content)
PointListScroll.LayoutOrder = 7
PointListScroll.BackgroundTransparency = 1
PointListScroll.Size = UDim2.new(1, 0, 1, -160) -- Restante do espaço
PointListScroll.CanvasSize = UDim2.new(0,0,0,0)
PointListScroll.ScrollBarThickness = 4

local ListLayout = Instance.new("UIListLayout", PointListScroll)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 4)

-- LOGICA
BtnModeDisplay.MouseButton1Click:Connect(function()
    Settings.Mode = (Settings.Mode == "Instant") and "Safe" or "Instant"
    UpdateConfigUI(); SalvarArquivo()
end)
BtnToggleGizmo.MouseButton1Click:Connect(function()
    Settings.ShowGizmos = not Settings.ShowGizmos
    UpdateConfigUI(); SalvarArquivo(); AtualizarGizmos()
end)
InpSpeed.FocusLost:Connect(function() Settings.SafeSpeed = tonumber(InpSpeed.Text) or 300; SalvarArquivo() end)

BtnGPS.MouseButton1Click:Connect(function()
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local p = Player.Character.HumanoidRootPart.Position
        InpX.Text=math.floor(p.X); InpY.Text=math.floor(p.Y); InpZ.Text=math.floor(p.Z)
    end
end)

local function RefreshList()
    for _, c in pairs(PointListScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    
    for i, pt in ipairs(SavedPoints) do
        local Row = Instance.new("Frame", PointListScroll)
        Row.Size = UDim2.new(1, 0, 0, 28)
        Row.BackgroundColor3 = (i%2==0) and Color3.fromRGB(40,40,45) or Color3.fromRGB(35,35,40)
        local CR = Instance.new("UICorner", Row); CR.CornerRadius = UDim.new(0, 4)
        
        local Lbl = Instance.new("TextLabel", Row); Lbl.Size=UDim2.new(0.6,0,1,0); Lbl.Position=UDim2.new(0.03,0,0,0); Lbl.BackgroundTransparency=1; Lbl.Text=pt.name; Lbl.TextColor3=Color3.white; Lbl.TextXAlignment=Enum.TextXAlignment.Left; Lbl.Font=Enum.Font.Gotham; Lbl.TextSize=12
        
        local BtnGo = Instance.new("TextButton", Row); BtnGo.Text="IR"; BtnGo.Size=UDim2.new(0.18,0,0.8,0); BtnGo.Position=UDim2.new(0.60,0,0.1,0); BtnGo.BackgroundColor3=Color3.fromRGB(0,160,100); BtnGo.TextColor3=Color3.white; BtnGo.Font=Enum.Font.GothamBold; BtnGo.TextSize=10; Instance.new("UICorner", BtnGo).CornerRadius=UDim.new(0,3)
        
        local BtnDel = Instance.new("TextButton", Row); BtnDel.Text="X"; BtnDel.Size=UDim2.new(0.15,0,0.8,0); BtnDel.Position=UDim2.new(0.82,0,0.1,0); BtnDel.BackgroundColor3=Color3.fromRGB(180,60,60); BtnDel.TextColor3=Color3.white; BtnDel.Font=Enum.Font.GothamBold; BtnDel.TextSize=10; Instance.new("UICorner", BtnDel).CornerRadius=UDim.new(0,3)
        
        BtnGo.MouseButton1Click:Connect(function() TeleportTo(Vector3.new(pt.x, pt.y, pt.z)) end)
        BtnDel.MouseButton1Click:Connect(function() table.remove(SavedPoints, i); SalvarArquivo(); RefreshList() end)
    end
    PointListScroll.CanvasSize = UDim2.new(0, 0, 0, #SavedPoints * 32)
end

BtnSave.MouseButton1Click:Connect(function()
    local x,y,z = tonumber(InpX.Text), tonumber(InpY.Text), tonumber(InpZ.Text)
    if x then
        local n = InpName.Text; if n=="" then n="Ponto "..(#SavedPoints+1) end
        table.insert(SavedPoints, {name=n, x=x, y=y, z=z})
        SalvarArquivo(); RefreshList()
    end
end)

-- 6. ATALHOS E TOGGLE
UserInputService.InputBegan:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.F2 then ScreenGui.Enabled = not ScreenGui.Enabled end
    if not gp and input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        if Mouse.Target then TeleportTo(Mouse.Hit.Position + Vector3.new(0,3,0)) end
    end
end)

if TabMundo then
    pCreate("ToggleTPMenu", TabMundo, "CreateToggle", {
        Name = "Menu TP [F2]", CurrentValue = true, Callback = function(v) ScreenGui.Enabled = v end
    })
end

-- 7. STARTUP
CarregarArquivo()
RefreshList()
LogarEvento("SUCESSO", "Módulo TP v1.6 (Clean UI) carregado.")