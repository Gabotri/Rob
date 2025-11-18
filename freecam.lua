--[==[
    MÓDULO: Freecam (6DOF) v1.5 (UI Config & Mouse Unlock)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [NOVO] Painel de Configurações (Speed, Sens, FOV).
    - [NOVO] Tecla 'Left Alt' para destravar mouse e usar a UI sem sair do Freecam.
    - [FIX] Zoom/FOV integrado.
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
    MouseLocked = true,     -- Controla se estamos girando ou clicando
    BaseSpeed = 50,         
    TurboMultiplier = 5,    
    SlowMultiplier = 0.2,   
    Sensitivity = 0.25,
    FOV = 70,               -- [NOVO] Campo de visão
    TweenDuration = 0.5     
}

local VirtualRotation = Vector2.new() 
local VirtualPosition = Vector3.new()
local OriginalWalkSpeed = 16
local OriginalCameraType = Enum.CameraType.Custom

-- UI References
local ScreenGui, SpeedInput, SensInput, FOVInput

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

-- Lógica Principal do Freecam
local function ToggleFreecam(state)
    FreecamSettings.Active = state
    FreecamSettings.MouseLocked = state -- Reseta para travado ao ativar
    
    -- UI Visibilidade
    if ScreenGui then ScreenGui.Enabled = state end

    if state then
        -- ATIVAR
        OriginalCameraType = Camera.CameraType
        local startCFrame = Camera.CFrame
        VirtualPosition = startCFrame.Position
        local rx, ry, _ = startCFrame:ToEulerAnglesYXZ()
        VirtualRotation = Vector2.new(rx, ry)
        FreecamSettings.FOV = Camera.FieldOfView -- Pega FOV atual

        Camera.CameraType = Enum.CameraType.Scriptable
        UpdateMouseState()
        ApplyGhostMode(true)
        
        RunService:BindToRenderStep("GabotriFreecamLoop", Enum.RenderPriority.Camera.Value + 1, UpdateCameraStep)
        LogarEvento("INFO", "Freecam ATIVADO. Pressione [Left Alt] para liberar o mouse.")
        
    else
        -- DESATIVAR
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
    
    -- A. ROTAÇÃO (Só se o mouse estiver travado)
    if FreecamSettings.MouseLocked then
        local mouseDelta = UserInputService:GetMouseDelta()
        local sens = FreecamSettings.Sensitivity * (math.pi / 180)
        
        VirtualRotation = VirtualRotation - Vector2.new(mouseDelta.Y * sens, mouseDelta.X * sens)
        VirtualRotation = Vector2.new(math.clamp(VirtualRotation.X, -math.rad(89), math.rad(89)), VirtualRotation.Y)
    end
    
    local rotationCFrame = CFrame.fromEulerAnglesYXZ(VirtualRotation.X, VirtualRotation.Y, 0)
    
    -- B. MOVIMENTO (TECLADO)
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
    
    -- C. APLICAÇÃO FINAL
    Camera.CFrame = CFrame.new(VirtualPosition) * rotationCFrame
    Camera.FieldOfView = FreecamSettings.FOV -- Aplica Zoom
end

-- 6. UI DE CONFIGURAÇÃO (PURA)
--========================================================================
ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FreecamConfigUI"
ScreenGui.Parent = CoreGui
ScreenGui.Enabled = false
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.Position = UDim2.new(0.8, 0, 0.7, 0) -- Canto inferior direito
MainFrame.Size = UDim2.new(0, 220, 0, 160)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", MainFrame)
Title.Text = "  Freecam Config [Alt]"; Title.Size = UDim2.new(1,0,0,25); Title.BackgroundColor3 = Color3.fromRGB(35,35,40); Title.TextColor3 = Color3.fromRGB(255,255,255); Title.Font = Enum.Font.GothamBold; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.TextSize = 12
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)
-- Filler do título
local HF = Instance.new("Frame", Title); HF.BorderSizePixel=0; HF.BackgroundColor3=Title.BackgroundColor3; HF.Size=UDim2.new(1,0,0,5); HF.Position=UDim2.new(0,0,1,-5); HF.ZIndex=0

local Container = Instance.new("Frame", MainFrame)
Container.BackgroundTransparency = 1; Container.Position = UDim2.new(0, 10, 0, 30); Container.Size = UDim2.new(1, -20, 1, -30)
local UIList = Instance.new("UIListLayout", Container); UIList.Padding = UDim.new(0, 8); UIList.SortOrder = Enum.SortOrder.LayoutOrder

-- Helper de Slider Simples (TextBox)
local function CreateInput(text, default, callback)
    local Frame = Instance.new("Frame", Container); Frame.Size = UDim2.new(1,0,0,30); Frame.BackgroundTransparency = 1
    local Lbl = Instance.new("TextLabel", Frame); Lbl.Text = text; Lbl.Size = UDim2.new(0.6,0,1,0); Lbl.TextColor3 = Color3.fromRGB(200,200,200); Lbl.BackgroundTransparency = 1; Lbl.Font = Enum.Font.Gotham; Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.TextSize = 11
    local Box = Instance.new("TextBox", Frame); Box.Text = tostring(default); Box.Size = UDim2.new(0.35,0,0.8,0); Box.Position = UDim2.new(0.65,0,0.1,0); Box.BackgroundColor3 = Color3.fromRGB(50,50,55); Box.TextColor3 = Color3.fromRGB(255,255,255); Box.Font = Enum.Font.GothamBold; Box.TextSize = 11
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 4)
    
    Box.FocusLost:Connect(function()
        local num = tonumber(Box.Text)
        if num then callback(num) end
    end)
    return Box
end

SpeedInput = CreateInput("Speed (Studs)", FreecamSettings.BaseSpeed, function(v) FreecamSettings.BaseSpeed = v end)
SensInput = CreateInput("Sensibilidade", FreecamSettings.Sensitivity, function(v) FreecamSettings.Sensitivity = v end)
FOVInput = CreateInput("FOV (Zoom)", FreecamSettings.FOV, function(v) FreecamSettings.FOV = math.clamp(v, 1, 120) end)

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

    -- Left Alt: Toggle Mouse Lock (Só se freecam ativo)
    if input.KeyCode == Enum.KeyCode.LeftAlt then
        if FreecamSettings.Active then
            FreecamSettings.MouseLocked = not FreecamSettings.MouseLocked
            UpdateMouseState()
        end
    end
end)

-- 8. UI NO CHASSI (Aba Player - Sync)
--========================================================================
if TabPlayer then
    pCreate("SecFreecam", TabPlayer, "CreateSection", "Freecam v1.5 (UI Config)", "Left")
    
    pCreate("ToggleFreecam", TabPlayer, "CreateToggle", {
        Name = "Ativar Freecam [F4]",
        CurrentValue = FreecamSettings.Active,
        Callback = ToggleFreecam
    })
    
    pCreate("InfoControls", TabPlayer, "CreateLabel", "Use 'Left Alt' para liberar o mouse e configurar.")
    
    LogarEvento("SUCESSO", "Módulo Freecam v1.5 (Mouse Control) carregado.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada.")
end