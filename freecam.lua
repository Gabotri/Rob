--[==[
    MÓDULO: Freecam (6DOF) v1.3
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [FIX CRÍTICO] Câmera Virtual: Usa CFrame interno para ignorar travas do jogo.
    - [FIX] Prioridade: Usa BindToRenderStep para sobrescrever scripts do jogo.
    - [FIX] Mouse Lock: Trava o mouse no centro para rotação infinita.
    - Player travado e invisível (Ghost Mode).
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
    Sensitivity = 0.25,  -- Aumentei um pouco para ficar mais responsivo
    TweenDuration = 0.5     
}

-- Variáveis de Estado (Câmera Virtual)
local VirtualRotation = Vector2.new() -- Armazena Pitch/Yaw
local VirtualPosition = Vector3.new() -- Armazena Posição X/Y/Z
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
            hrp.Anchored = state -- Ancorar previne que física do jogo empurre o boneco
            
            -- Movimento
            if state then
                OriginalWalkSpeed = hum.WalkSpeed
                hum.WalkSpeed = 0
                hum.PlatformStand = true -- Garante que não ande
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
            
            -- Oculta UI do boneco
            hum.DisplayDistanceType = state and Enum.DisplayDistanceType.None or Enum.DisplayDistanceType.Model
        end
    end
end

-- Lógica Principal do Freecam
local function ToggleFreecam(state)
    FreecamSettings.Active = state
    
    if state then
        -- ATIVAR
        OriginalCameraType = Camera.CameraType
        
        -- 1. Captura a posição inicial exata da câmera
        local startCFrame = Camera.CFrame
        VirtualPosition = startCFrame.Position
        
        -- Converte a rotação atual para Vector2 (Pitch/Yaw)
        local rx, ry, _ = startCFrame:ToEulerAnglesYXZ()
        VirtualRotation = Vector2.new(rx, ry)
        
        -- 2. Configura a Câmera
        Camera.CameraType = Enum.CameraType.Scriptable
        UserInputService.MouseIconEnabled = false
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter -- Trava mouse no centro
        
        -- 3. Aplica Ghost Mode
        ApplyGhostMode(true)
        
        -- 4. Inicia o Loop com ALTA PRIORIDADE
        -- "Camera + 1" garante que rodamos DEPOIS do sistema de câmera do Roblox
        RunService:BindToRenderStep("GabotriFreecamLoop", Enum.RenderPriority.Camera.Value + 1, UpdateCameraStep)
        
        LogarEvento("INFO", "Freecam ATIVADO (Virtual Mode).")
        
    else
        -- DESATIVAR
        RunService:UnbindFromRenderStep("GabotriFreecamLoop")
        
        Camera.CameraType = OriginalCameraType
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        
        ApplyGhostMode(false)
        
        -- Tween de volta pro boneco (Visual)
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
    
    -- A. ROTAÇÃO (MOUSE)
    local mouseDelta = UserInputService:GetMouseDelta()
    local sens = FreecamSettings.Sensitivity * (math.pi / 180) -- Converte graus para radianos
    
    VirtualRotation = VirtualRotation - Vector2.new(mouseDelta.Y * sens, mouseDelta.X * sens)
    
    -- Limita o Pitch (Olhar pra cima/baixo) para não dar cambalhota (89 graus)
    VirtualRotation = Vector2.new(
        math.clamp(VirtualRotation.X, -math.rad(89), math.rad(89)),
        VirtualRotation.Y
    )
    
    -- Cria o CFrame de Rotação Base
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
    
    -- Calcula o movimento relativo para onde a câmera está olhando
    -- VectorToWorldSpace transforma o vetor de movimento local (WASD) em global baseado na rotação
    local worldMove = rotationCFrame:VectorToWorldSpace(moveDir)
    
    -- Aplica o movimento na Posição Virtual
    if moveDir.Magnitude > 0 then
        -- Normaliza para velocidade constante na diagonal e multiplica pelo speed e delta
        VirtualPosition = VirtualPosition + (worldMove.Unit * speed * deltaTime)
    end
    
    -- C. APLICAÇÃO FINAL (FORCE)
    Camera.CFrame = CFrame.new(VirtualPosition) * rotationCFrame
end

-- 6. ATALHOS E EVENTOS
--========================================================================
-- Sincronia ao renascer
Players.LocalPlayer.CharacterAdded:Connect(function()
    if FreecamSettings.Active then ToggleFreecam(false) end -- Desliga se morrer pra evitar bugs
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.F4 then
        if gp then return end
        ToggleFreecam(not FreecamSettings.Active)
        
        -- Sync UI
        if Chassi.Abas.Player and Chassi.Abas.Player:FindFirstChild("ToggleFreecam") then
            Chassi.Abas.Player:FindFirstChild("ToggleFreecam"):Set(FreecamSettings.Active)
        end
    end
end)

-- 7. UI NO CHASSI
--========================================================================
if TabPlayer then
    pCreate("SecFreecam", TabPlayer, "CreateSection", "Freecam v1.3 (Virtual Mode)", "Left")
    
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

    LogarEvento("SUCESSO", "Módulo Freecam v1.3 (Virtual Lock) carregado.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada.")
end