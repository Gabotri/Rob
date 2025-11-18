--[==[
    MÓDULO: Freecam (6DOF) v1.4
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [FIX CRÍTICO] Corrigido erro de Enum (HumanoidDisplayDistanceType).
    - Câmera Virtual (Ignora travas do jogo).
    - Mouse Lock + Ghost Mode (Player invisível e imóvel).
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
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- 3. CONFIGURAÇÕES & ESTADO
local FreecamSettings = {
    Active = false,
    BaseSpeed = 50,         
    TurboMultiplier = 5,    
    SlowMultiplier = 0.2,   
    Sensitivity = 0.25,
    TweenDuration = 0.5     
}

local VirtualRotation = Vector2.new() 
local VirtualPosition = Vector3.new()
local OriginalWalkSpeed = 16
local OriginalCameraType = Enum.CameraType.Custom

-- 4. FUNÇÕES AUXILIARES
--========================================================================

local function ApplyGhostMode(state)
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        
        if hrp and hum then
            -- Física
            hrp.CanCollide = not state
            hrp.Anchored = state 
            
            -- Movimento
            if state then
                OriginalWalkSpeed = hum.WalkSpeed
                hum.WalkSpeed = 0
                hum.PlatformStand = true 
            else
                hum.WalkSpeed = OriginalWalkSpeed
                hum.PlatformStand = false
                hrp.Anchored = false
            end
            
            -- Visual (Invisibilidade Local)
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.LocalTransparencyModifier = state and 1 or 0
                elseif part:IsA("Decal") then
                    part.Transparency = state and 1 or 0
                end
            end
            
            -- [FIX] Oculta UI do boneco usando o Enum CORRETO
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

-- Lógica Principal do Freecam
local function ToggleFreecam(state)
    FreecamSettings.Active = state
    
    if state then
        -- ATIVAR
        OriginalCameraType = Camera.CameraType
        
        local startCFrame = Camera.CFrame
        VirtualPosition = startCFrame.Position
        
        local rx, ry, _ = startCFrame:ToEulerAnglesYXZ()
        VirtualRotation = Vector2.new(rx, ry)
        
        Camera.CameraType = Enum.CameraType.Scriptable
        UserInputService.MouseIconEnabled = false
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter 
        
        ApplyGhostMode(true)
        
        RunService:BindToRenderStep("GabotriFreecamLoop", Enum.RenderPriority.Camera.Value + 1, UpdateCameraStep)
        
        LogarEvento("INFO", "Freecam ATIVADO (Virtual Mode).")
        
    else
        -- DESATIVAR
        RunService:UnbindFromRenderStep("GabotriFreecamLoop")
        
        Camera.CameraType = OriginalCameraType
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        
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
    
    -- A. ROTAÇÃO
    local mouseDelta = UserInputService:GetMouseDelta()
    local sens = FreecamSettings.Sensitivity * (math.pi / 180)
    
    VirtualRotation = VirtualRotation - Vector2.new(mouseDelta.Y * sens, mouseDelta.X * sens)
    VirtualRotation = Vector2.new(math.clamp(VirtualRotation.X, -math.rad(89), math.rad(89)), VirtualRotation.Y)
    
    local rotationCFrame = CFrame.fromEulerAnglesYXZ(VirtualRotation.X, VirtualRotation.Y, 0)
    
    -- B. MOVIMENTO
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
end

-- 6. ATALHOS E EVENTOS
--========================================================================
Players.LocalPlayer.CharacterAdded:Connect(function()
    if FreecamSettings.Active then ToggleFreecam(false) end 
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.F4 then
        if gp then return end
        ToggleFreecam(not FreecamSettings.Active)
        
        if Chassi.Abas.Player and Chassi.Abas.Player:FindFirstChild("ToggleFreecam") then
            Chassi.Abas.Player:FindFirstChild("ToggleFreecam"):Set(FreecamSettings.Active)
        end
    end
end)

-- 7. UI NO CHASSI
--========================================================================
if TabPlayer then
    pCreate("SecFreecam", TabPlayer, "CreateSection", "Freecam v1.4 (Fix Enum)", "Left")
    
    pCreate("ToggleFreecam", TabPlayer, "CreateToggle", {
        Name = "Ativar Freecam [F4]",
        CurrentValue = FreecamSettings.Active,
        Callback = ToggleFreecam
    })
    
    pCreate("SliderSpeed", TabPlayer, "CreateSlider", {
        Name = "Velocidade (Studs/s)",
        Range = {10, 500}, Increment = 10, Suffix = " sps",
        CurrentValue = 50,
        Callback = function(Val) FreecamSettings.BaseSpeed = Val end
    })

    pCreate("SliderSens", TabPlayer, "CreateSlider", {
        Name = "Sensibilidade Mouse",
        Range = {0.1, 2.0}, Increment = 0.1, Suffix = "x",
        CurrentValue = 0.25,
        Callback = function(Val) FreecamSettings.Sensitivity = Val end
    })
    
    pCreate("InfoControls", TabPlayer, "CreateLabel", "Controles: WASD, Q/E, SHIFT, Mouse")

    LogarEvento("SUCESSO", "Módulo Freecam v1.4 (Enum Fix) carregado.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada.")
end