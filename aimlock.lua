--[==[
    MÓDULO: AimLock v1.3 (Feedback & Auto-Switch)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: Sistema de mira com Feedback Visual e Troca Inteligente.
    
    MUDANÇAS v1.3:
    - [NOVO] Feedback de Texto: Mostra o nome do alvo travado na tela.
    - [LÓGICA] Auto-Switch: Troca de alvo se ele morrer, sair do FOV ou entrar em parede.
    - [FIX] Validação contínua de Wall Check durante a mira.
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
    SystemEnabled = false,        
    IsAiming = false,             
    
    -- Teclas
    ToggleKey = Enum.KeyCode.F1,               
    TriggerKey = Enum.UserInputType.MouseButton2, 
    
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
    Prediction = false,       
    PredictionAmount = 0.165  
}

local Target = nil

-- Objetos de Desenho
local FOVCircle = Drawing.new("Circle")
local TargetLabel = Drawing.new("Text") -- [NOVO] Feedback

-- Configuração Inicial
FOVCircle.Thickness = 1; FOVCircle.NumSides = 60; FOVCircle.Filled = false; FOVCircle.Transparency = 1
TargetLabel.Size = 18; TargetLabel.Center = true; TargetLabel.Outline = true; TargetLabel.Color = Color3.fromRGB(255, 50, 50)

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

-- Checa se o alvo atual ainda é válido (Dentro do FOV, Vivo e Visível)
local function IsTargetValid(targ)
    if not targ or not targ.Character then return false end
    
    local hum = targ.Character:FindFirstChild("Humanoid")
    local head = targ.Character:FindFirstChild("Head")
    
    if not hum or hum.Health <= 0 or not head then return false end
    
    -- Checagem de Distância do Mouse (FOV)
    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
    if not onScreen then return false end
    
    local mousePos = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
    local dist = (mousePos - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
    if dist > AimSettings.FOVRadius then return false end -- Saiu do FOV
    
    -- Checagem de Parede (Se ativada)
    if AimSettings.WallCheck and not IsVisible(head) then return false end
    
    return true
end

-- Busca o alvo mais próximo
local function GetClosestPlayer()
    local closest = nil
    local maxDist = AimSettings.FOVRadius
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local isAlly = (AimSettings.TeamCheck and player.Team == LocalPlayer.Team and player.Team ~= nil)
            
            if not isAlly and player.Character then
                local hum = player.Character:FindFirstChild("Humanoid")
                local head = player.Character:FindFirstChild("Head")
                
                if hum and hum.Health > 0 and head then
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

-- 5. LÓGICA PRINCIPAL (LOOP)
--========================================================================
RunService.RenderStepped:Connect(function()
    local mouseLoc = UserInputService:GetMouseLocation()

    -- Atualiza Desenhos
    FOVCircle.Visible = AimSettings.ShowFOV and AimSettings.SystemEnabled
    FOVCircle.Radius = AimSettings.FOVRadius
    FOVCircle.Position = mouseLoc
    FOVCircle.Color = (AimSettings.IsAiming and Target) and Color3.fromRGB(255, 0, 0) or AimSettings.FOVColor

    -- Feedback de Texto
    if AimSettings.SystemEnabled and AimSettings.IsAiming and Target then
        TargetLabel.Visible = true
        TargetLabel.Text = "[ TRAVADO: " .. Target.Name .. " ]"
        TargetLabel.Position = Vector2.new(mouseLoc.X, mouseLoc.Y + AimSettings.FOVRadius + 20)
    else
        TargetLabel.Visible = false
    end

    -- Lógica de Mira
    if AimSettings.SystemEnabled and AimSettings.IsAiming then
        -- 1. Validação Contínua (Auto-Switch Logic)
        if Target and not IsTargetValid(Target) then
            Target = nil -- Invalida para buscar outro imediatamente
        end

        -- 2. Se temos um alvo válido, mira nele
        if Target then
             local part = GetTargetPart(Target.Character)
             local root = Target.Character:FindFirstChild("HumanoidRootPart")
             
             if part and root then
                 -- Predição
                 local targetPosition = part.Position
                 if AimSettings.Prediction then
                     targetPosition = targetPosition + (root.Velocity * AimSettings.PredictionAmount)
                 end

                 -- Aplica Mira
                 local currentCFrame = Camera.CFrame
                 local targetCFrame = CFrame.new(currentCFrame.Position, targetPosition)
                 Camera.CFrame = currentCFrame:Lerp(targetCFrame, AimSettings.Smoothing * AimSettings.Sensitivity)
             end
        else
            -- 3. Se não temos alvo (ou ele foi invalidado acima), busca o próximo
            Target = GetClosestPlayer()
        end
    else
        Target = nil
    end
end)

-- 6. INPUTS
--========================================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end 
    
    if input.KeyCode == AimSettings.ToggleKey then
        AimSettings.SystemEnabled = not AimSettings.SystemEnabled
        AimSettings.IsAiming = false 
        if AimSettings.SystemEnabled then LogarEvento("INFO", "AimLock HABILITADO.")
        else LogarEvento("INFO", "AimLock DESABILITADO.") end
    end

    if input.UserInputType == AimSettings.TriggerKey then
        if AimSettings.SystemEnabled then AimSettings.IsAiming = true end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == AimSettings.TriggerKey then
        AimSettings.IsAiming = false
        Target = nil
    end
end)

-- 7. INTERFACE GRÁFICA
--========================================================================
if TabPlayer then
    pCreate("SecAim", TabPlayer, "CreateSection", "AimLock v1.3 (Feedback)", "Left")
    
    pCreate("ToggleAim", TabPlayer, "CreateToggle", {
        Name = "Sistema AimLock [F1]",
        CurrentValue = false,
        Callback = function(Val) AimSettings.SystemEnabled = Val; if not Val then AimSettings.IsAiming = false end end
    })
    
    pCreate("ToggleFOV", TabPlayer, "CreateToggle", {
        Name = "Mostrar FOV", CurrentValue = AimSettings.ShowFOV,
        Callback = function(Val) AimSettings.ShowFOV = Val end
    })
    
    pCreate("SliderFOV", TabPlayer, "CreateSlider", {
        Name = "Raio do FOV", Range = {10, 800}, Increment = 10, Suffix = " px", CurrentValue = 150,
        Callback = function(Val) AimSettings.FOVRadius = Val end
    })
    
    pCreate("TogglePred", TabPlayer, "CreateToggle", {
        Name = "Usar Predição", CurrentValue = false,
        Callback = function(Val) AimSettings.Prediction = Val end
    })
    
    pCreate("SliderPred", TabPlayer, "CreateSlider", {
        Name = "Fator de Predição", Range = {1, 50}, Increment = 1, Suffix = " ms", CurrentValue = 16,
        Callback = function(Val) AimSettings.PredictionAmount = Val / 100 end
    })
    
    pCreate("SliderSmooth", TabPlayer, "CreateSlider", {
        Name = "Suavização", Range = {1, 100}, Increment = 1, Suffix = "%", CurrentValue = 10,
        Callback = function(Val) AimSettings.Smoothing = Val / 100 end
    })
    
    pCreate("ToggleWall", TabPlayer, "CreateToggle", {
        Name = "Wall Check (Auto-Switch)", CurrentValue = AimSettings.WallCheck,
        Callback = function(Val) AimSettings.WallCheck = Val end
    })
    
    pCreate("DropdownPart", TabPlayer, "CreateDropdown", {
        Name = "Parte do Corpo", Options = {"Head", "HumanoidRootPart", "UpperTorso", "Random"}, CurrentOption = "Head",
        Callback = function(Val) AimSettings.TargetPart = Val end
    })

    LogarEvento("SUCESSO", "Módulo AimLock v1.3 carregado.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada para o AimLock.")
end