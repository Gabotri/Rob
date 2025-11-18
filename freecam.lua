--[==[
    MÓDULO: Freecam (6DOF) v1.1
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [FIX CRÍTICO] Corrigido erro 'LocalTransparencyModifier' (aplicado no Humanoid).
    - Câmera Scriptable com 6 Graus de Liberdade.
    - Atalho F4.
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
local OriginalCameraType = Camera.CameraType
local OriginalCameraSubject = Camera.CameraSubject

-- 3. CONFIGURAÇÕES & ESTADO
local FreecamSettings = {
    Active = false,
    BaseSpeed = 50,         
    TurboMultiplier = 5,    
    SlowMultiplier = 0.2,   
    Sensitivity = 0.15,     
    TweenDuration = 0.5     
}

local FreecamConnection = nil

-- 4. FUNÇÕES DE CÂMERA E TRANSIÇÃO
--========================================================================

-- [FIX] Aplica o estado de Noclip/Fantasma (AGORA NO HUMANOID)
local function ApplyNoclipState(state)
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid") -- << REFERENCIA AO HUMANOID
        
        if hrp and hum then
            hrp.CanCollide = not state
            
            -- Aplica a transparência no Humanoid (Ghost Mode)
            hum.LocalTransparencyModifier = state and 1 or 0 
            
            -- Oculta nome/vida para completar o Ghost Mode
            hum.DisplayDistanceType = state and Enum.DisplayDistanceType.None or Enum.DisplayDistanceType.Model
            hum.NameDisplayDistance = state and 0 or 100 -- 100 é o default do Roblox
            LogarEvento("INFO", "Ghost Mode aplicado: " .. tostring(state))
        end
    end
end

-- Lógica para entrar ou sair do Freecam
local function ToggleFreecam(state)
    FreecamSettings.Active = state
    LogarEvento("INFO", "Freecam: " .. (state and "ATIVADO" or "DESATIVADO"))

    if state then
        -- Salva estado original e desacopla
        OriginalCameraType = Camera.CameraType
        OriginalCameraSubject = Camera.CameraSubject
        
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local targetCFrame = hrp.CFrame
            local tweenInfo = TweenInfo.new(FreecamSettings.TweenDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            TweenService:Create(Camera, tweenInfo, {CFrame = targetCFrame}):Play()
            wait(FreecamSettings.TweenDuration)
        end
        
        Camera.CameraType = Enum.CameraType.Scriptable
        UserInputService.MouseIconEnabled = false 
        ApplyNoclipState(true)
        
        if FreecamConnection then FreecamConnection:Disconnect() end
        FreecamConnection = RunService.RenderStepped:Connect(UpdateCamera)
        
    else
        -- Reacopla e restaura
        if FreecamConnection then FreecamConnection:Disconnect() FreecamConnection = nil end
        UserInputService.MouseIconEnabled = true
        ApplyNoclipState(false)
        
        -- Transição Suave (Saída)
        local tweenInfo = TweenInfo.new(FreecamSettings.TweenDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        TweenService:Create(Camera, tweenInfo, {CFrame = Camera.CFrame}):Play() -- Dummy tween para usar a duração
        
        Camera.CameraSubject = OriginalCameraSubject
        Camera.CameraType = OriginalCameraType 
    end
end

-- 5. LÓGICA DE MOVIMENTO (6DOF)
--========================================================================

local function UpdateCamera(deltaTime)
    if not FreecamSettings.Active then return end

    -- 1. CÁLCULO DE VELOCIDADE
    local currentSpeed = FreecamSettings.BaseSpeed

    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        currentSpeed = currentSpeed * FreecamSettings.TurboMultiplier
    elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        currentSpeed = currentSpeed * FreecamSettings.SlowMultiplier
    end
    
    local moveVector = Vector3.new(0, 0, 0)
    local cameraCFrame = Camera.CFrame

    -- 2. MOVIMENTO LINEAR
    local forward = cameraCFrame.LookVector * currentSpeed * deltaTime
    local right = cameraCFrame.RightVector * currentSpeed * deltaTime

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - right end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + right end

    -- QE para Subir/Descer (World Up Vector)
    local worldUp = Vector3.new(0, 1, 0) * currentSpeed * deltaTime
    if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveVector = moveVector + worldUp end
    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveVector = moveVector - worldUp end

    -- 3. MOVIMENTO ANGULAR (MOUSE LOOK)
    local mouseDelta = UserInputService:GetMouseDelta()
    
    local pitch = -mouseDelta.Y * FreecamSettings.Sensitivity
    local yaw = -mouseDelta.X * FreecamSettings.Sensitivity
    
    local rotCFrame = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
    
    -- 4. APLICAÇÃO FINAL
    Camera.CFrame = (cameraCFrame * rotCFrame) + moveVector
end

-- 6. HOTKEY (F4) E INTEGRAÇÃO
--========================================================================
local function SyncFreecamToggle()
    if not FreecamSettings.Active and Players.LocalPlayer.Character then
        OriginalCameraSubject = Players.LocalPlayer.Character:FindFirstChild("Humanoid")
    end
end
Players.LocalPlayer.CharacterAdded:Connect(SyncFreecamToggle)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.F4 then
        if gameProcessed then return end
        
        ToggleFreecam(not FreecamSettings.Active)
        
        if Chassi.Abas.Player and Chassi.Abas.Player:FindFirstChild("ToggleFreecam") then
            Chassi.Abas.Player:FindFirstChild("ToggleFreecam"):Set(FreecamSettings.Active)
        end
    end
end)


-- 7. UI NO CHASSI (Aba Player)
--========================================================================
if TabPlayer then
    pCreate("SecFreecam", TabPlayer, "CreateSection", "Freecam (Câmera Livre) v1.1", "Left")
    
    pCreate("ToggleFreecam", TabPlayer, "CreateToggle", {
        Name = "Ativar Freecam [F4]",
        CurrentValue = FreecamSettings.Active,
        Callback = ToggleFreecam
    })
    
    pCreate("SliderSpeed", TabPlayer, "CreateSlider", {
        Name = "Velocidade Base (Studs/s)",
        Range = {10, 500}, Increment = 10, Suffix = " sps",
        CurrentValue = 50,
        Callback = function(Val) FreecamSettings.BaseSpeed = Val end
    })

    pCreate("SliderSens", TabPlayer, "CreateSlider", {
        Name = "Sensibilidade Mouse",
        Range = {0.05, 0.5}, Increment = 0.05, Suffix = "x",
        CurrentValue = 0.15,
        Callback = function(Val) FreecamSettings.Sensitivity = Val end
    })
    
    pCreate("InfoControls", TabPlayer, "CreateLabel", {
        Text = "Controles: WASD (Mover), Q/E (Cima/Baixo), SHIFT (Turbo)"
    })

    LogarEvento("SUCESSO", "Módulo Freecam v1.1 carregado. Pressione F4.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada para Freecam.")
end