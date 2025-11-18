--[==[
    MÓDULO: Freecam (6DOF) v1.2
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [FIX CRÍTICO] Trava de movimento do player (WalkSpeed = 0).
    - [FIX CRÍTICO] Corrigido erro de sintaxe ao criar o Label de Controles na UI.
    - Câmera Scriptable com 6 Graus de Liberdade e Atalho F4.
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
    Sensitivity = 0.15,     
    TweenDuration = 0.5     
}

local FreecamConnection = nil
local OriginalCameraType = Camera.CameraType
local OriginalCameraSubject = Camera.CameraSubject
local OriginalWalkSpeed = 16 -- Valor padrão para restaurar se o player ainda não tiver sido carregado

-- 4. FUNÇÕES DE CÂMERA E TRANSIÇÃO
--========================================================================

-- Aplica o estado de Noclip/Fantasma E Trava o Player
local function ApplyNoclipState(state)
    local char = LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        
        if hrp and hum then
            hrp.CanCollide = not state
            
            -- 1. CONTROLE DE MOVIMENTO DO PLAYER
            if state then
                -- Salva a velocidade original antes de travar
                OriginalWalkSpeed = hum.WalkSpeed 
                hum.WalkSpeed = 0                 
            else
                -- Restaura a velocidade
                hum.WalkSpeed = OriginalWalkSpeed 
            end
            
            -- 2. Transparência (Ghost Mode)
            hum.LocalTransparencyModifier = state and 1 or 0 
            hum.DisplayDistanceType = state and Enum.DisplayDistanceType.None or Enum.DisplayDistanceType.Model
            hum.NameDisplayDistance = state and 0 or 100 
            LogarEvento("INFO", "Ghost Mode aplicado: " .. tostring(state) .. " | WalkSpeed: " .. tostring(hum.WalkSpeed))
        end
    end
end

-- Lógica para entrar ou sair do Freecam
local function ToggleFreecam(state)
    FreecamSettings.Active = state

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
        ApplyNoclipState(true) -- << Trava o player e aplica ghost mode
        
        if FreecamConnection then FreecamConnection:Disconnect() end
        FreecamConnection = RunService.RenderStepped:Connect(UpdateCamera)
        
    else
        -- Reacopla e restaura
        if FreecamConnection then FreecamConnection:Disconnect() FreecamConnection = nil end
        UserInputService.MouseIconEnabled = true
        ApplyNoclipState(false) -- << Restaura o player
        
        local tweenInfo = TweenInfo.new(FreecamSettings.TweenDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        TweenService:Create(Camera, tweenInfo, {CFrame = Camera.CFrame}):Play() 
        
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
    local speedDelta = currentSpeed * deltaTime
    local forward = cameraCFrame.LookVector * speedDelta
    local right = cameraCFrame.RightVector * speedDelta

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - right end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + right end

    -- QE para Subir/Descer (World Up Vector)
    local worldUp = Vector3.new(0, 1, 0) * speedDelta
    if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveVector = moveVector + worldUp end
    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveVector = moveVector - worldUp end

    -- 3. MOVIMENTO ANGULAR (MOUSE LOOK)
    local mouseDelta = UserInputService:GetMouseDelta()
    
    -- Ajusta a rotação para não virar de ponta cabeça se estiver olhando muito para cima/baixo
    local pitch = -mouseDelta.Y * FreecamSettings.Sensitivity
    local yaw = -mouseDelta.X * FreecamSettings.Sensitivity
    
    local rotCFrame = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
    
    -- 4. APLICAÇÃO FINAL
    -- Aplica a rotação no eixo Y (World) e a rotação no eixo X (Local)
    Camera.CFrame = (Camera.CFrame * CFrame.Angles(0, yaw, 0)) * CFrame.Angles(pitch, 0, 0) + moveVector
end

-- 6. HOTKEY (F4) E INTEGRAÇÃO
--========================================================================
local function SyncFreecamToggle()
    if not FreecamSettings.Active and LocalPlayer.Character then
        OriginalCameraSubject = LocalPlayer.Character:FindFirstChild("Humanoid")
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then OriginalWalkSpeed = hum.WalkSpeed end -- Salva WalkSpeed na criação do personagem
    end
end
Players.LocalPlayer.CharacterAdded:Connect(SyncFreecamToggle)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.F4 then
        if gameProcessed then return end
        
        ToggleFreecam(not FreecamSettings.Active)
        
        if Chassi.Abas.Player and Chassi.Abas.Player:FindFirstChild("ToggleFreecam") then
            -- Note: O erro de UI é na criação do Label, não aqui, mas é bom manter a sincronia.
            Chassi.Abas.Player:FindFirstChild("ToggleFreecam"):Set(FreecamSettings.Active)
        end
    end
end)


-- 7. UI NO CHASSI (Aba Player)
--========================================================================
if TabPlayer then
    pCreate("SecFreecam", TabPlayer, "CreateSection", "Freecam (Câmera Livre) v1.2", "Left")
    
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
    
    -- [FIX CRÍTICO UI] Passando a string de texto diretamente para CreateLabel
    pCreate("InfoControls", TabPlayer, "CreateLabel", "Controles: WASD (Mover), Q/E (Cima/Baixo), SHIFT (Turbo)")

    LogarEvento("SUCESSO", "Módulo Freecam v1.2 (Player Lock e UI Fix) carregado.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada para Freecam.")
end