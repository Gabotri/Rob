--[==[
    MÓDULO: Teleport Manager v1.8 (Safety Platform & Stop)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [NOVO] Botão "CANCELAR ROTA" (Para o TP no meio do caminho).
    - [NOVO] Plataforma de Segurança: Cria chão ao cancelar, some ao andar.
    - [NOVO] Toggle Noclip: Escolha se quer atravessar paredes ou não.
    - UI V2 com Color3.fromRGB corrigido.
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

local FileName = "Gabotri_TP_" .. tostring(game.PlaceId) .. "_v5.json"
local SavedPoints = {} 
local CurrentTween = nil
local NoclipConnection = nil
local PlatformConnection = nil -- Monitora movimento para deletar plataforma
local GizmoFolder = nil
local SafetyPart = nil

-- Configurações
local Settings = {
    Mode = "Safe",
    SafeSpeed = 300,
    ShowGizmos = true,
    AutoNoclip = true -- [NOVO] Controle do Noclip
}

-- UI Refs
local ScreenGui, PointListScroll, BtnModeDisplay, InpSpeed, BtnToggleGizmo, BtnToggleNoclip

-- 3. SISTEMA DE ARQUIVOS
--========================================================================
local function AtualizarGizmos()
    if GizmoFolder then GizmoFolder:Destroy() end
    if not Settings.ShowGizmos then return end
    
    GizmoFolder = Instance.new("Folder", Workspace)
    GizmoFolder.Name = "GabotriGizmos_v1.8"
    
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
    
    -- Atualiza Botão Modo
    if Settings.Mode == "Safe" then
        BtnModeDisplay.Text = "MODO: SEGURO"
        BtnModeDisplay.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    else
        BtnModeDisplay.Text = "MODO: INSTANT"
        BtnModeDisplay.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    end
    
    -- Atualiza Botão Gizmo
    BtnToggleGizmo.Text = Settings.ShowGizmos and "GIZMO: ON" or "GIZMO: OFF"
    BtnToggleGizmo.BackgroundColor3 = Settings.ShowGizmos and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(60, 60, 60)
    
    -- Atualiza Botão Noclip [NOVO]
    BtnToggleNoclip.Text = Settings.AutoNoclip and "NOCLIP: ON" or "NOCLIP: OFF"
    BtnToggleNoclip.BackgroundColor3 = Settings.AutoNoclip and Color3.fromRGB(180, 100, 0) or Color3.fromRGB(60, 60, 60)
    
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
    UpdateConfigUI()
    AtualizarGizmos()
end

-- 4. LÓGICA DE FÍSICA E PLATAFORMA
--========================================================================
local function EnableNoclip(state)
    -- Só ativa se o estado for true E a configuração permitir
    if state and Settings.AutoNoclip then
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

local function CriarPlataformaSeguranca()
    local Char = Player.Character
    if not Char or not Char:FindFirstChild("HumanoidRootPart") then return end
    
    -- Remove anterior se existir
    if SafetyPart then SafetyPart:Destroy() end
    if PlatformConnection then PlatformConnection:Disconnect() end
    
    -- Cria chão
    SafetyPart = Instance.new("Part")
    SafetyPart.Name = "GabotriSafetyPlatform"
    SafetyPart.Size = Vector3.new(15, 1, 15)
    SafetyPart.Anchored = true
    SafetyPart.CanCollide = true
    SafetyPart.Transparency = 0.3
    SafetyPart.Material = Enum.Material.Glass
    SafetyPart.Color = Color3.fromRGB(0, 255, 0) -- Verde Neon
    SafetyPart.Position = Char.HumanoidRootPart.Position - Vector3.new(0, 3.5, 0)
    SafetyPart.Parent = Workspace
    
    LogarEvento("AVISO", "Rota cancelada! Plataforma criada. Mova-se para remover.")
    
    -- Monitora movimento para deletar
    PlatformConnection = RunService.Heartbeat:Connect(function()
        local Hum = Char:FindFirstChild("Humanoid")
        if Hum and Hum.MoveDirection.Magnitude > 0.1 then
            -- Jogador tentou andar
            if SafetyPart then SafetyPart:Destroy() SafetyPart = nil end
            PlatformConnection:Disconnect()
            PlatformConnection = nil
        end
    end)
end

local function CancelarRota()
    if CurrentTween then
        CurrentTween:Cancel()
        CurrentTween = nil
        EnableNoclip(false)
        CriarPlataformaSeguranca() -- Cria o chão
    end
end

local function TeleportTo(targetPos)
    local Char = Player.Character
    if not Char or not Char:FindFirstChild("HumanoidRootPart") then return end
    local Root = Char.HumanoidRootPart
    
    -- Limpezas prévias
    if CurrentTween then CurrentTween:Cancel() end
    EnableNoclip(false)
    if SafetyPart then SafetyPart:Destroy() end -- Remove plataforma se já estiver em outra
    
    if Settings.Mode == "Instant" then
        Root.CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
    elseif Settings.Mode == "Safe" then
        local dist = (targetPos - Root.Position).Magnitude
        local speed = tonumber(Settings.SafeSpeed) or 300
        if speed <= 0 then speed = 16 end
        
        local time = dist / speed
        local ti = TweenInfo.new(time, Enum.EasingStyle.Linear)
        CurrentTween = TweenService:Create(Root, ti, {CFrame = CFrame.new(targetPos)})
        
        EnableNoclip(true) -- Tenta ativar noclip (respeita config interna)
        CurrentTween:Play()
        
        LogarEvento("INFO", string.format("Iniciando voo (%.1fs)...", time))
        CurrentTween.Completed:Connect(function() EnableNoclip(false); CurrentTween = nil end)
    end
end

-- 5. UI MANAGER V2 (ATUALIZADA)
--========================================================================
ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
ScreenGui.Name = "TPManager_v1.8"
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = true

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.Position = UDim2.new(0.75, 0, 0.3, 0)
MainFrame.Size = UDim2.new(0, 260, 0, 460) -- Aumentei altura para o botão STOP
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
local MC = Instance.new("UICorner", MainFrame); MC.CornerRadius = UDim.new(0, 6)

-- HEADER
local Header = Instance.new("Frame", MainFrame)
Header.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
Header.Size = UDim2.new(1, 0, 0, 30)
local HC = Instance.new("UICorner", Header); HC.CornerRadius = UDim.new(0, 6)
local HF = Instance.new("Frame", Header); HF.BorderSizePixel=0; HF.BackgroundColor3=Header.BackgroundColor3; HF.Size=UDim2.new(1,0,0,5); HF.Position=UDim2.new(0,0,1,-5)

local Title = Instance.new("TextLabel", Header)
Title.Text = "  TP Manager v1.8 [F2]"; Title.TextColor3 = Color3.fromRGB(240,240,240); Title.Font = Enum.Font.GothamBold; Title.TextSize = 14; Title.Size = UDim2.new(1,-30,1,0); Title.BackgroundTransparency = 1; Title.TextXAlignment = Enum.TextXAlignment.Left
local Close = Instance.new("TextButton", Header); Close.Text="X"; Close.TextColor3=Color3.fromRGB(255,80,80); Close.BackgroundTransparency=1; Close.Size=UDim2.new(0,30,1,0); Close.Position=UDim2.new(1,-30,0,0); Close.Font=Enum.Font.GothamBold
Close.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

-- CONTEÚDO
local Content = Instance.new("Frame", MainFrame)
Content.BackgroundTransparency = 1
Content.Position = UDim2.new(0, 0, 0, 35)
Content.Size = UDim2.new(1, 0, 1, -35)

local UIList = Instance.new("UIListLayout", Content)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 6)
UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center

local UIPad = Instance.new("UIPadding", Content)
UIPad.PaddingTop = UDim.new(0, 5)
UIPad.PaddingLeft = UDim.new(0, 10)
UIPad.PaddingRight = UDim.new(0, 10)

-- 1. CONFIGS (Row 1)
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

-- 2. CONFIGS (Row 2 - Gizmo & Noclip)
local RowToggles = Instance.new("Frame", Content)
RowToggles.BackgroundTransparency = 1
RowToggles.Size = UDim2.new(1, 0, 0, 25)
RowToggles.LayoutOrder = 2

BtnToggleGizmo = Instance.new("TextButton", RowToggles)
BtnToggleGizmo.Size = UDim2.new(0.48, 0, 1, 0)
BtnToggleGizmo.Font = Enum.Font.GothamBold
BtnToggleGizmo.TextSize = 10
BtnToggleGizmo.TextColor3 = Color3.fromRGB(255, 255, 255)
local C3 = Instance.new("UICorner", BtnToggleGizmo); C3.CornerRadius = UDim.new(0, 4)

BtnToggleNoclip = Instance.new("TextButton", RowToggles)
BtnToggleNoclip.Size = UDim2.new(0.48, 0, 1, 0)
BtnToggleNoclip.Position = UDim2.new(0.52, 0, 0, 0)
BtnToggleNoclip.Font = Enum.Font.GothamBold
BtnToggleNoclip.TextSize = 10
BtnToggleNoclip.TextColor3 = Color3.fromRGB(255, 255, 255)
local C4 = Instance.new("UICorner", BtnToggleNoclip); C4.CornerRadius = UDim.new(0, 4)

-- 3. BOTÃO CANCELAR ROTA [NOVO]
local BtnStop = Instance.new("TextButton", Content)
BtnStop.LayoutOrder = 3
BtnStop.Size = UDim2.new(1, 0, 0, 30)
BtnStop.BackgroundColor3 = Color3.fromRGB(180, 40, 40) -- Vermelho Alerta
BtnStop.Text = "CANCELAR ROTA / PARAR"
BtnStop.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnStop.Font = Enum.Font.GothamBlack
BtnStop.TextSize = 12
local CStop = Instance.new("UICorner", BtnStop); CStop.CornerRadius = UDim.new(0, 4)
BtnStop.MouseButton1Click:Connect(CancelarRota)

-- 4. CRIAÇÃO
local Divider = Instance.new("Frame", Content); Divider.LayoutOrder=4; Divider.Size=UDim2.new(1,0,0,1); Divider.BackgroundColor3=Color3.fromRGB(60,60,60); Divider.BorderSizePixel=0

local RowCoords = Instance.new("Frame", Content); RowCoords.LayoutOrder=5; RowCoords.BackgroundTransparency=1; RowCoords.Size=UDim2.new(1,0,0,25)
local InpX = Instance.new("TextBox", RowCoords); InpX.Size=UDim2.new(0.22,0,1,0); InpX.PlaceholderText="X"; InpX.BackgroundColor3=Color3.fromRGB(45,45,50); InpX.TextColor3=Color3.fromRGB(255,255,255); Instance.new("UICorner", InpX).CornerRadius=UDim.new(0,4)
local InpY = Instance.new("TextBox", RowCoords); InpY.Size=UDim2.new(0.22,0,1,0); InpY.Position=UDim2.new(0.26,0,0,0); InpY.PlaceholderText="Y"; InpY.BackgroundColor3=Color3.fromRGB(45,45,50); InpY.TextColor3=Color3.fromRGB(255,255,255); Instance.new("UICorner", InpY).CornerRadius=UDim.new(0,4)
local InpZ = Instance.new("TextBox", RowCoords); InpZ.Size=UDim2.new(0.22,0,1,0); InpZ.Position=UDim2.new(0.52,0,0,0); InpZ.PlaceholderText="Z"; InpZ.BackgroundColor3=Color3.fromRGB(45,45,50); InpZ.TextColor3=Color3.fromRGB(255,255,255); Instance.new("UICorner", InpZ).CornerRadius=UDim.new(0,4)
local BtnGPS = Instance.new("TextButton", RowCoords); BtnGPS.Size=UDim2.new(0.20,0,1,0); BtnGPS.Position=UDim2.new(0.80,0,0,0); BtnGPS.Text="GPS"; BtnGPS.BackgroundColor3=Color3.fromRGB(255,150,0); BtnGPS.TextColor3=Color3.fromRGB(0,0,0); BtnGPS.Font=Enum.Font.GothamBold; Instance.new("UICorner", BtnGPS).CornerRadius=UDim.new(0,4)

local RowSave = Instance.new("Frame", Content); RowSave.LayoutOrder=6; RowSave.BackgroundTransparency=1; RowSave.Size=UDim2.new(1,0,0,25)
local InpName = Instance.new("TextBox", RowSave); InpName.Size=UDim2.new(0.65,0,1,0); InpName.PlaceholderText="Nome do Ponto"; InpName.BackgroundColor3=Color3.fromRGB(45,45,50); InpName.TextColor3=Color3.fromRGB(255,255,255); InpName.TextXAlignment=Enum.TextXAlignment.Left; Instance.new("UICorner", InpName).CornerRadius=UDim.new(0,4)
local IPad = Instance.new("UIPadding", InpName); IPad.PaddingLeft=UDim.new(0,5)
local BtnSave = Instance.new("TextButton", RowSave); BtnSave.Size=UDim2.new(0.30,0,1,0); BtnSave.Position=UDim2.new(0.70,0,0,0); BtnSave.Text="SALVAR"; BtnSave.BackgroundColor3=Color3.fromRGB(0,120,200); BtnSave.TextColor3=Color3.fromRGB(255,255,255); BtnSave.Font=Enum.Font.GothamBold; Instance.new("UICorner", BtnSave).CornerRadius=UDim.new(0,4)

-- 5. LISTA
local Divider2 = Instance.new("Frame", Content); Divider2.LayoutOrder=7; Divider2.Size=UDim2.new(1,0,0,1); Divider2.BackgroundColor3=Color3.fromRGB(60,60,60); Divider2.BorderSizePixel=0

PointListScroll = Instance.new("ScrollingFrame", Content)
PointListScroll.LayoutOrder = 8
PointListScroll.BackgroundTransparency = 1
PointListScroll.Size = UDim2.new(1, 0, 1, -190) -- Espaço ajustado
PointListScroll.CanvasSize = UDim2.new(0,0,0,0)
PointListScroll.ScrollBarThickness = 4

local ListLayout = Instance.new("UIListLayout", PointListScroll)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 4)

-- LÓGICA BOTÕES CONFIG
BtnModeDisplay.MouseButton1Click:Connect(function()
    Settings.Mode = (Settings.Mode == "Instant") and "Safe" or "Instant"
    UpdateConfigUI(); SalvarArquivo()
end)
BtnToggleGizmo.MouseButton1Click:Connect(function()
    Settings.ShowGizmos = not Settings.ShowGizmos
    UpdateConfigUI(); SalvarArquivo(); AtualizarGizmos()
end)
BtnToggleNoclip.MouseButton1Click:Connect(function()
    Settings.AutoNoclip = not Settings.AutoNoclip
    UpdateConfigUI(); SalvarArquivo()
end)
InpSpeed.FocusLost:Connect(function() Settings.SafeSpeed = tonumber(InpSpeed.Text) or 300; SalvarArquivo() end)

-- LÓGICA LISTA
local function RefreshList()
    for _, c in pairs(PointListScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for i, pt in ipairs(SavedPoints) do
        local Row = Instance.new("Frame", PointListScroll)
        Row.Size = UDim2.new(1, 0, 0, 28)
        Row.BackgroundColor3 = (i%2==0) and Color3.fromRGB(40,40,45) or Color3.fromRGB(35,35,40)
        local CR = Instance.new("UICorner", Row); CR.CornerRadius = UDim.new(0, 4)
        
        local Lbl = Instance.new("TextLabel", Row); Lbl.Size=UDim2.new(0.6,0,1,0); Lbl.Position=UDim2.new(0.03,0,0,0); Lbl.BackgroundTransparency=1; Lbl.Text=pt.name; Lbl.TextColor3=Color3.fromRGB(255,255,255); Lbl.TextXAlignment=Enum.TextXAlignment.Left; Lbl.Font=Enum.Font.Gotham; Lbl.TextSize=12
        local BtnGo = Instance.new("TextButton", Row); BtnGo.Text="IR"; BtnGo.Size=UDim2.new(0.18,0,0.8,0); BtnGo.Position=UDim2.new(0.60,0,0.1,0); BtnGo.BackgroundColor3=Color3.fromRGB(0,160,100); BtnGo.TextColor3=Color3.fromRGB(255,255,255); BtnGo.Font=Enum.Font.GothamBold; BtnGo.TextSize=10; Instance.new("UICorner", BtnGo).CornerRadius=UDim.new(0,3)
        local BtnDel = Instance.new("TextButton", Row); BtnDel.Text="X"; BtnDel.Size=UDim2.new(0.15,0,0.8,0); BtnDel.Position=UDim2.new(0.82,0,0.1,0); BtnDel.BackgroundColor3=Color3.fromRGB(180,60,60); BtnDel.TextColor3=Color3.fromRGB(255,255,255); BtnDel.Font=Enum.Font.GothamBold; BtnDel.TextSize=10; Instance.new("UICorner", BtnDel).CornerRadius=UDim.new(0,3)
        
        BtnGo.MouseButton1Click:Connect(function() TeleportTo(Vector3.new(pt.x, pt.y, pt.z)) end)
        BtnDel.MouseButton1Click:Connect(function() table.remove(SavedPoints, i); SalvarArquivo(); RefreshList() end)
    end
    PointListScroll.CanvasSize = UDim2.new(0, 0, 0, #SavedPoints * 32)
end

-- LÓGICA GPS E SAVE
BtnGPS.MouseButton1Click:Connect(function()
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local p = Player.Character.HumanoidRootPart.Position
        InpX.Text=math.floor(p.X); InpY.Text=math.floor(p.Y); InpZ.Text=math.floor(p.Z)
    end
end)
BtnSave.MouseButton1Click:Connect(function()
    local x,y,z = tonumber(InpX.Text), tonumber(InpY.Text), tonumber(InpZ.Text)
    if x then
        local n = InpName.Text; if n=="" then n="Ponto "..(#SavedPoints+1) end
        table.insert(SavedPoints, {name=n, x=x, y=y, z=z})
        SalvarArquivo(); RefreshList()
    end
end)

-- ATALHOS E TOGGLE
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

-- STARTUP
CarregarArquivo()
RefreshList()
LogarEvento("SUCESSO", "Módulo TP v1.8 (Safety Platform) carregado.")