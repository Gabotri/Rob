--[==[
    MÓDULO: Freecam (6DOF) v1.6 (TP & Coords)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [MUDANÇA] Atalho de Mouse alterado para 'P'.
    - [NOVO] Mostrador de Coordenadas em tempo real na UI.
    - [NOVO] Botão "TP Player Here" (Traz o boneco para a câmera).
    - Câmera Virtual e Ghost Mode mantidos.
]==]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO FREECAM: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. SERVIÇOS
local LogarEvento = Chassi.LogarEvento
local pCreate = Chassi.pCreate
local TabPlayer = Chassi.Abas.Player

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- 3. CONFIGURAÇÕES & ESTADO
local FreecamSettings = {
    Active = false,
    MouseLocked = true,     
    BaseSpeed = 50,         
    TurboMultiplier = 5,    
    SlowMultiplier = 0.2,   
    Sensitivity = 0.25,
    FOV = 70,               
    TweenDuration = 0.5     
}

local VirtualRotation = Vector2.new() 
local VirtualPosition = Vector3.new()
local OriginalWalkSpeed = 16
local OriginalCameraType = Enum.CameraType.Custom

-- UI References
local ScreenGui, CoordsLabel -- Para atualizar no loop

-- 4. FUNÇÕES AUXILIARES
--========================================================================

local function ApplyGhostMode(state)
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        
        if hrp and hum then
            hrp.CanCollide = not state
            hrp.Anchored = state 
            
            if state then
                OriginalWalkSpeed = hum.WalkSpeed
                hum.WalkSpeed = 0
                hum.PlatformStand = true 
            else
                hum.WalkSpeed = OriginalWalkSpeed
                hum.PlatformStand = false
                hrp.Anchored = false
            end
            
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.LocalTransparencyModifier = state and 1 or 0
                elseif part:IsA("Decal") then part.Transparency = state and 1 or 0 end
            end
            
            if state then
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                hum.NameDisplayDistance = 0
            else
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
                hum.NameDisplayDistance = 100
            end
        end
    end
end

local function UpdateMouseState()
    if not FreecamSettings.Active then 
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        return 
    end

    if FreecamSettings.MouseLocked then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false
    else
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end
end

local function TeleportPlayerToCam()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        -- Move o HRP para a posição da câmera
        LocalPlayer.Character.HumanoidRootPart.CFrame = Camera.CFrame
        LogarEvento("INFO", "Player teleportado para a Câmera.")
    end
end

-- Lógica Principal do Freecam
local function ToggleFreecam(state)
    FreecamSettings.Active = state
    FreecamSettings.MouseLocked = state 
    
    if ScreenGui then ScreenGui.Enabled = state end

    if state then
        OriginalCameraType = Camera.CameraType
        local startCFrame = Camera.CFrame
        VirtualPosition = startCFrame.Position
        local rx, ry, _ = startCFrame:ToEulerAnglesYXZ()
        VirtualRotation = Vector2.new(rx, ry)
        FreecamSettings.FOV = Camera.FieldOfView 

        Camera.CameraType = Enum.CameraType.Scriptable
        UpdateMouseState()
        ApplyGhostMode(true)
        
        RunService:BindToRenderStep("GabotriFreecamLoop", Enum.RenderPriority.Camera.Value + 1, UpdateCameraStep)
        LogarEvento("INFO", "Freecam ATIVADO. Pressione [P] para cursor.")
        
    else
        RunService:UnbindFromRenderStep("GabotriFreecamLoop")
        Camera.CameraType = OriginalCameraType
        UpdateMouseState()
        ApplyGhostMode(false)
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
            Camera.CFrame = LocalPlayer.Character.Head.CFrame
        end
        LogarEvento("INFO", "Freecam DESATIVADO.")
    end
end

-- 5. LOOP DE CÂMERA (VIRTUAL CFRAME)
--========================================================================
function UpdateCameraStep(deltaTime)
    if not FreecamSettings.Active then return end
    
    -- Atualiza UI de Coordenadas
    if CoordsLabel then
        CoordsLabel.Text = string.format("X: %.0f  Y: %.0f  Z: %.0f", VirtualPosition.X, VirtualPosition.Y, VirtualPosition.Z)
    end
    
    -- Rotação
    if FreecamSettings.MouseLocked then
        local mouseDelta = UserInputService:GetMouseDelta()
        local sens = FreecamSettings.Sensitivity * (math.pi / 180)
        VirtualRotation = VirtualRotation - Vector2.new(mouseDelta.Y * sens, mouseDelta.X * sens)
        VirtualRotation = Vector2.new(math.clamp(VirtualRotation.X, -math.rad(89), math.rad(89)), VirtualRotation.Y)
    end
    
    local rotationCFrame = CFrame.fromEulerAnglesYXZ(VirtualRotation.X, VirtualRotation.Y, 0)
    
    -- Movimento
    local speed = FreecamSettings.BaseSpeed
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then speed = speed * FreecamSettings.TurboMultiplier end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then speed = speed * FreecamSettings.SlowMultiplier end
    
    local moveDir = Vector3.new()
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Vector3.new(0, 0, -1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir + Vector3.new(0, 0, 1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir + Vector3.new(-1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Vector3.new(1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveDir = moveDir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveDir = moveDir + Vector3.new(0, -1, 0) end
    
    local worldMove = rotationCFrame:VectorToWorldSpace(moveDir)
    
    if moveDir.Magnitude > 0 then
        VirtualPosition = VirtualPosition + (worldMove.Unit * speed * deltaTime)
    end
    
    Camera.CFrame = CFrame.new(VirtualPosition) * rotationCFrame
    Camera.FieldOfView = FreecamSettings.FOV 
end

-- 6. UI DE CONFIGURAÇÃO (PURA ATUALIZADA)
--========================================================================
ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FreecamConfigUI_v1.6"
ScreenGui.Parent = CoreGui
ScreenGui.Enabled = false
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.Position = UDim2.new(0.8, 0, 0.65, 0) 
MainFrame.Size = UDim2.new(0, 220, 0, 230) -- Aumentado para caber novos itens
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", MainFrame)
Title.Text = "  Freecam [P]"; Title.Size = UDim2.new(1,0,0,25); Title.BackgroundColor3 = Color3.fromRGB(35,35,40); Title.TextColor3 = Color3.fromRGB(255,255,255); Title.Font = Enum.Font.GothamBold; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.TextSize = 12
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)
local HF = Instance.new("Frame", Title); HF.BorderSizePixel=0; HF.BackgroundColor3=Title.BackgroundColor3; HF.Size=UDim2.new(1,0,0,5); HF.Position=UDim2.new(0,0,1,-5); HF.ZIndex=0

local Container = Instance.new("Frame", MainFrame)
Container.BackgroundTransparency = 1; Container.Position = UDim2.new(0, 10, 0, 30); Container.Size = UDim2.new(1, -20, 1, -30)
local UIList = Instance.new("UIListLayout", Container); UIList.Padding = UDim.new(0, 8); UIList.SortOrder = Enum.SortOrder.LayoutOrder

-- [NOVO] Label de Coordenadas
CoordsLabel = Instance.new("TextLabel", Container)
CoordsLabel.Size = UDim2.new(1, 0, 0, 20)
CoordsLabel.BackgroundTransparency = 1
CoordsLabel.Text = "X: 0  Y: 0  Z: 0"
CoordsLabel.TextColor3 = Color3.fromRGB(0, 255, 255) -- Ciano
CoordsLabel.Font = Enum.Font.Code
CoordsLabel.TextSize = 11

-- [NOVO] Botão TP Player
local BtnTP = Instance.new("TextButton", Container)
BtnTP.Size = UDim2.new(1, 0, 0, 25)
BtnTP.Text = "TP PLAYER TO CAM"
BtnTP.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
BtnTP.TextColor3 = Color3.fromRGB(255, 255, 255)
BtnTP.Font = Enum.Font.GothamBold
BtnTP.TextSize = 10
Instance.new("UICorner", BtnTP).CornerRadius = UDim.new(0, 4)
BtnTP.MouseButton1Click:Connect(TeleportPlayerToCam)

local Divider = Instance.new("Frame", Container); Divider.Size=UDim2.new(1,0,0,1); Divider.BackgroundColor3=Color3.fromRGB(60,60,60); Divider.BorderSizePixel=0

-- Sliders
local function CreateInput(text, default, callback)
    local Frame = Instance.new("Frame", Container); Frame.Size = UDim2.new(1,0,0,30); Frame.BackgroundTransparency = 1
    local Lbl = Instance.new("TextLabel", Frame); Lbl.Text = text; Lbl.Size = UDim2.new(0.6,0,1,0); Lbl.TextColor3 = Color3.fromRGB(200,200,200); Lbl.BackgroundTransparency = 1; Lbl.Font = Enum.Font.Gotham; Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.TextSize = 11
    local Box = Instance.new("TextBox", Frame); Box.Text = tostring(default); Box.Size = UDim2.new(0.35,0,0.8,0); Box.Position = UDim2.new(0.65,0,0.1,0); Box.BackgroundColor3 = Color3.fromRGB(50,50,55); Box.TextColor3 = Color3.fromRGB(255,255,255); Box.Font = Enum.Font.GothamBold; Box.TextSize = 11
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 4)
    Box.FocusLost:Connect(function() local num = tonumber(Box.Text); if num then callback(num) end end)
    return Box
end

CreateInput("Speed (Studs)", FreecamSettings.BaseSpeed, function(v) FreecamSettings.BaseSpeed = v end)
CreateInput("Sensibilidade", FreecamSettings.Sensitivity, function(v) FreecamSettings.Sensitivity = v end)
CreateInput("FOV (Zoom)", FreecamSettings.FOV, function(v) FreecamSettings.FOV = math.clamp(v, 1, 120) end)

-- 7. ATALHOS E EVENTOS
--========================================================================
Players.LocalPlayer.CharacterAdded:Connect(function()
    if FreecamSettings.Active then ToggleFreecam(false) end 
end)

UserInputService.InputBegan:Connect(function(input, gp)
    -- F4: Toggle Geral
    if input.KeyCode == Enum.KeyCode.F4 then
        if gp then return end
        ToggleFreecam(not FreecamSettings.Active)
        if Chassi.Abas.Player and Chassi.Abas.Player:FindFirstChild("ToggleFreecam") then
            Chassi.Abas.Player:FindFirstChild("ToggleFreecam"):Set(FreecamSettings.Active)
        end
    end

    -- [MUDANÇA] P: Toggle Mouse Lock
    if input.KeyCode == Enum.KeyCode.P then
        if FreecamSettings.Active then
            FreecamSettings.MouseLocked = not FreecamSettings.MouseLocked
            UpdateMouseState()
        end
    end
end)

-- 8. UI NO CHASSI
--========================================================================
if TabPlayer then
    pCreate("SecFreecam", TabPlayer, "CreateSection", "Freecam v1.6 (TP & P)", "Left")
    
    pCreate("ToggleFreecam", TabPlayer, "CreateToggle", {
        Name = "Ativar Freecam [F4]",
        CurrentValue = FreecamSettings.Active,
        Callback = ToggleFreecam
    })
    
    pCreate("InfoControls", TabPlayer, "CreateLabel", "Use 'P' para cursor. Menu UI disponível.")
    
    LogarEvento("SUCESSO", "Módulo Freecam v1.6 (TP & Coords) carregado.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada.")
end