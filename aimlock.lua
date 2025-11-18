--[==[
    MÓDULO: AimLock (Camera Tracking) v1.0
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: Sistema de rastreamento de mira com suavização e FOV.
    FUNCIONALIDADES:
    - AimLock: Trava a câmera no alvo mais próximo da mira.
    - FOV Circle: Desenha o raio de atuação.
    - Smoothing: Movimento humanizado (Lerp).
    - Visibility Check: Raycast para não mirar através de paredes.
    - Target Part: Configurável (Head, Torso, Random).
    - Keybind: Botão direito do mouse (MB2) por padrão.
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
local Mouse = LocalPlayer:GetMouse()

-- 3. CONFIGURAÇÕES (Settings)
local AimSettings = {
    Enabled = false,
    Keybind = Enum.UserInputType.MouseButton2, -- Botão Direito
    IsAiming = false,
    
    -- Seleção
    TeamCheck = true,    -- Ignorar aliados
    WallCheck = true,    -- Verificar paredes
    TargetPart = "Head", -- "Head", "HumanoidRootPart" ou "Random"
    
    -- FOV (Campo de Visão)
    ShowFOV = true,
    FOVRadius = 150,
    FOVColor = Color3.fromRGB(255, 255, 255),
    
    -- Suavização (Quanto maior, mais lento/suave)
    Smoothing = 0.1,     -- 1 = Instantâneo, 0.1 = Lento
    Sensitivity = 1      -- Multiplicador extra
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
    return result == nil -- Se não bateu em nada, está visível
end

-- Pega a parte do corpo desejada
local function GetTargetPart(character)
    if AimSettings.TargetPart == "Random" then
        local parts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}
        local randomPart = parts[math.random(1, #parts)]
        return character:FindFirstChild(randomPart) or character:FindFirstChild("Head")
    else
        return character:FindFirstChild(AimSettings.TargetPart)
    end
end

-- Busca o alvo mais próximo do cursor (dentro do FOV)
local function GetClosestPlayer()
    local closest = nil
    local maxDist = AimSettings.FOVRadius
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            -- Checagem de Time
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
                            -- Checagem de Visibilidade
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

-- 5. LÓGICA PRINCIPAL (LOOP)
--========================================================================
RunService.RenderStepped:Connect(function()
    -- Atualiza Desenho do FOV
    FOVCircle.Visible = AimSettings.ShowFOV and AimSettings.Enabled
    FOVCircle.Radius = AimSettings.FOVRadius
    FOVCircle.Position = UserInputService:GetMouseLocation()
    FOVCircle.Color = AimSettings.FOVColor

    -- Lógica de Mira
    if AimSettings.Enabled and AimSettings.IsAiming then
        -- Se já temos um alvo, verifica se ele ainda é válido
        if Target and Target.Character and Target.Character:FindFirstChild("Humanoid") and Target.Character.Humanoid.Health > 0 then
             -- Verifica visibilidade contínua
             local part = GetTargetPart(Target.Character)
             if part then
                 -- Matemágica da Câmera (CFrame LookAt com Interpolação/Lerp)
                 local currentCFrame = Camera.CFrame
                 local targetCFrame = CFrame.new(currentCFrame.Position, part.Position)
                 
                 -- Aplica a suavização (Lerp)
                 Camera.CFrame = currentCFrame:Lerp(targetCFrame, AimSettings.Smoothing * AimSettings.Sensitivity)
             else
                 Target = nil -- Perdeu a parte
             end
        else
            -- Se não temos alvo ou ele morreu, busca um novo
            Target = GetClosestPlayer()
        end
    else
        Target = nil -- Reseta se soltar o botão
    end
end)

-- 6. INPUT (Keybind)
--========================================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == AimSettings.Keybind or input.KeyCode == AimSettings.Keybind then
        AimSettings.IsAiming = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == AimSettings.Keybind or input.KeyCode == AimSettings.Keybind then
        AimSettings.IsAiming = false
        Target = nil
    end
end)

-- 7. INTERFACE GRÁFICA (Tab Player)
--========================================================================
if TabPlayer then
    pCreate("SecAim", TabPlayer, "CreateSection", "AimLock v1.0", "Left")
    
    pCreate("ToggleAim", TabPlayer, "CreateToggle", {
        Name = "Ativar AimLock",
        CurrentValue = false,
        Callback = function(Val) AimSettings.Enabled = Val end
    })
    
    pCreate("ToggleFOV", TabPlayer, "CreateToggle", {
        Name = "Mostrar FOV (Círculo)",
        CurrentValue = AimSettings.ShowFOV,
        Callback = function(Val) AimSettings.ShowFOV = Val end
    })
    
    pCreate("SliderFOV", TabPlayer, "CreateSlider", {
        Name = "Raio do FOV",
        Range = {10, 800},
        Increment = 10,
        Suffix = " px",
        CurrentValue = 150,
        Callback = function(Val) AimSettings.FOVRadius = Val end
    })
    
    pCreate("SliderSmooth", TabPlayer, "CreateSlider", {
        Name = "Suavização (Humanização)",
        Range = {1, 100}, -- Na UI será 1-100, no script divide por 100
        Increment = 1,
        Suffix = "%",
        CurrentValue = 10, -- 0.1
        Callback = function(Val) AimSettings.Smoothing = Val / 100 end
    })
    
    pCreate("ToggleWall", TabPlayer, "CreateToggle", {
        Name = "Wall Check (Visibilidade)",
        CurrentValue = AimSettings.WallCheck,
        Callback = function(Val) AimSettings.WallCheck = Val end
    })
    
    pCreate("DropdownPart", TabPlayer, "CreateDropdown", {
        Name = "Parte do Corpo",
        Options = {"Head", "HumanoidRootPart", "UpperTorso", "Random"},
        CurrentOption = "Head",
        Callback = function(Val) AimSettings.TargetPart = Val end
    })

    LogarEvento("SUCESSO", "Módulo AimLock v1.0 carregado.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada para o AimLock.")
end