--[==[
    MÓDULO: AimLock (Prediction Edition) v1.2
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: Sistema de mira com Predição e Controles Híbridos.
    
    MUDANÇAS v1.2:
    - [CONTROLE] F1: Liga/Desliga o Módulo (Master Switch).
    - [CONTROLE] Botão Direito: Segura para mirar (Gatilho).
    - [NOVO] Predição de Movimento (Velocity Check) para alvos em movimento.
]==]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO AIMLOCK: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. VARIÁVEIS E SERVIÇOS
local LogarEvento = Chassi.LogarEvento
local pCreate = Chassi.pCreate
local TabPlayer = Chassi.Abas.Player

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- 3. CONFIGURAÇÕES (Settings)
local AimSettings = {
    SystemEnabled = false,        -- Controlado pelo F1 (Master Switch)
    IsAiming = false,             -- Controlado pelo Botão Direito (Gatilho)
    
    -- Teclas
    ToggleKey = Enum.KeyCode.F1,               -- Liga/Desliga o sistema
    TriggerKey = Enum.UserInputType.MouseButton2, -- Gatilho da mira
    
    -- Seleção
    TeamCheck = true,    
    WallCheck = true,    
    TargetPart = "Head",
    
    -- FOV
    ShowFOV = true,
    FOVRadius = 150,
    FOVColor = Color3.fromRGB(255, 255, 255),
    
    -- Movimento e Predição
    Smoothing = 0.1,
    Sensitivity = 1,
    Prediction = false,       -- [NOVO] Vem desligado por padrão
    PredictionAmount = 0.165  -- [NOVO] Fator de predição (Ping/Velocidade)
}

local Target = nil
local FOVCircle = Drawing.new("Circle")

-- Configuração Inicial do Círculo FOV
FOVCircle.Thickness = 1
FOVCircle.NumSides = 60
FOVCircle.Filled = false
FOVCircle.Transparency = 1

-- 4. FUNÇÕES AUXILIARES
--========================================================================

-- Verifica se o alvo está visível (Raycast)
local function IsVisible(targetPart)
    if not AimSettings.WallCheck then return true end
    
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent, Camera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    
    local result = Workspace:Raycast(origin, direction, params)
    return result == nil
end

-- Pega nome da parte (Safe)
local function GetTargetPartName()
    local val = AimSettings.TargetPart
    if type(val) == "table" then return val[1] or "Head" end
    return tostring(val)
end

local function GetTargetPart(character)
    local partName = GetTargetPartName()
    if partName == "Random" then
        local parts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}
        local randomPart = parts[math.random(1, #parts)]
        return character:FindFirstChild(randomPart) or character:FindFirstChild("Head")
    else
        return character:FindFirstChild(partName)
    end
end

-- Busca o alvo mais próximo do cursor (dentro do FOV)
local function GetClosestPlayer()
    local closest = nil
    local maxDist = AimSettings.FOVRadius
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local isAlly = (AimSettings.TeamCheck and player.Team == LocalPlayer.Team and player.Team ~= nil)
            
            if not isAlly and player.Character then
                local hum = player.Character:FindFirstChild("Humanoid")
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                local head = player.Character:FindFirstChild("Head")
                
                if hum and hum.Health > 0 and hrp and head then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    
                    if onScreen then
                        local mousePos = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
                        local dist = (mousePos - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                        
                        if dist < maxDist then
                            if IsVisible(head) then
                                closest = player
                                maxDist = dist
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- 5. LÓGICA PRINCIPAL (LOOP & PREDIÇÃO)
--========================================================================
RunService.RenderStepped:Connect(function()
    -- O FOV só aparece se o sistema estiver ATIVADO (F1)
    FOVCircle.Visible = AimSettings.ShowFOV and AimSettings.SystemEnabled
    FOVCircle.Radius = AimSettings.FOVRadius
    FOVCircle.Position = UserInputService:GetMouseLocation()
    
    -- Muda cor: Vermelho se segurando botão direito, Branco se em espera
    FOVCircle.Color = (AimSettings.IsAiming and AimSettings.SystemEnabled) and Color3.fromRGB(255, 0, 0) or AimSettings.FOVColor

    -- Lógica de Mira
    if AimSettings.SystemEnabled and AimSettings.IsAiming then
        -- Validação do Alvo
        if Target and Target.Character and Target.Character:FindFirstChild("Humanoid") and Target.Character.Humanoid.Health > 0 then
             local part = GetTargetPart(Target.Character)
             local root = Target.Character:FindFirstChild("HumanoidRootPart")
             
             if part and root then
                 -- === LÓGICA DE PREDIÇÃO ===
                 local targetPosition = part.Position
                 
                 if AimSettings.Prediction then
                     -- Adiciona: Velocidade do Alvo * Fator de Predição
                     targetPosition = targetPosition + (root.Velocity * AimSettings.PredictionAmount)
                 end
                 -- ==========================

                 -- Matemágica da Câmera (Lerp)
                 local currentCFrame = Camera.CFrame
                 local targetCFrame = CFrame.new(currentCFrame.Position, targetPosition)
                 
                 Camera.CFrame = currentCFrame:Lerp(targetCFrame, AimSettings.Smoothing * AimSettings.Sensitivity)
             else
                 Target = nil
             end
        else
            -- Busca novo alvo
            Target = GetClosestPlayer()
        end
    else
        Target = nil
    end
end)

-- 6. INPUTS (F1 e Botão Direito)
--========================================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end 
    
    -- F1: Master Switch (Ativa/Desativa o sistema)
    if input.KeyCode == AimSettings.ToggleKey then
        AimSettings.SystemEnabled = not AimSettings.SystemEnabled
        AimSettings.IsAiming = false -- Reseta mira ao desligar
        
        if AimSettings.SystemEnabled then
            LogarEvento("INFO", "AimLock HABILITADO (Pronto para uso).")
        else
            LogarEvento("INFO", "AimLock DESABILITADO.")
        end
    end

    -- Botão Direito: Gatilho (Segurar)
    if input.UserInputType == AimSettings.TriggerKey then
        if AimSettings.SystemEnabled then
            AimSettings.IsAiming = true
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    
    -- Soltou Botão Direito: Para de mirar
    if input.UserInputType == AimSettings.TriggerKey then
        AimSettings.IsAiming = false
        Target = nil
    end
end)

-- 7. INTERFACE GRÁFICA (Tab Player)
--========================================================================
if TabPlayer then
    pCreate("SecAim", TabPlayer, "CreateSection", "AimLock v1.2 (Híbrido)", "Left")
    
    -- Toggle Principal (Sincronizado com F1)
    pCreate("ToggleAim", TabPlayer, "CreateToggle", {
        Name = "Sistema AimLock [F1]",
        CurrentValue = false,
        Callback = function(Val) 
            AimSettings.SystemEnabled = Val 
            if not Val then AimSettings.IsAiming = false end
        end
    })
    
    pCreate("ToggleFOV", TabPlayer, "CreateToggle", {
        Name = "Mostrar FOV",
        CurrentValue = AimSettings.ShowFOV,
        Callback = function(Val) AimSettings.ShowFOV = Val end
    })
    
    pCreate("SliderFOV", TabPlayer, "CreateSlider", {
        Name = "Raio do FOV",
        Range = {10, 800}, Increment = 10, Suffix = " px",
        CurrentValue = 150,
        Callback = function(Val) AimSettings.FOVRadius = Val end
    })
    
    -- Configuração de Predição
    pCreate("TogglePred", TabPlayer, "CreateToggle", {
        Name = "Usar Predição de Movimento",
        CurrentValue = false, -- Pedido: Padrão Desligado
        Callback = function(Val) AimSettings.Prediction = Val end
    })
    
    pCreate("SliderPred", TabPlayer, "CreateSlider", {
        Name = "Fator de Predição (Ping)",
        Range = {1, 50}, -- Divide por 100 no script (0.01 a 0.5)
        Increment = 1,
        Suffix = " ms",
        CurrentValue = 16, -- ~0.16 (Padrão razoável)
        Callback = function(Val) AimSettings.PredictionAmount = Val / 100 end
    })
    
    pCreate("SliderSmooth", TabPlayer, "CreateSlider", {
        Name = "Suavização",
        Range = {1, 100}, Increment = 1, Suffix = "%",
        CurrentValue = 10,
        Callback = function(Val) AimSettings.Smoothing = Val / 100 end
    })
    
    pCreate("ToggleWall", TabPlayer, "CreateToggle", {
        Name = "Wall Check", CurrentValue = AimSettings.WallCheck,
        Callback = function(Val) AimSettings.WallCheck = Val end
    })
    
    pCreate("DropdownPart", TabPlayer, "CreateDropdown", {
        Name = "Parte do Corpo",
        Options = {"Head", "HumanoidRootPart", "UpperTorso", "Random"},
        CurrentOption = "Head",
        Callback = function(Val) AimSettings.TargetPart = Val end
    })

    LogarEvento("SUCESSO", "Módulo AimLock v1.2 carregado.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada para o AimLock.")
end