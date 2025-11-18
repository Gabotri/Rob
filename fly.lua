--[==[
    MÓDULO: Fly (Réplica da Referência) v1.0
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: Implementação exata da lógica de vetores enviada pelo usuário.
    - Usa BodyGyro para rotação (Trava na Câmera).
    - Usa BodyVelocity para movimento (WASD + Espaço/Ctrl).
    - Loop via RenderStepped.
]==]

-- 1. PUXA O CHASSI (A "COLA")
--========================================================================
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO FLY: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. VARIÁVEIS LOCAIS E SERVIÇOS
--========================================================================
local LogarEvento = Chassi.LogarEvento
local pCallback = Chassi.pCallback
local pCreate = Chassi.pCreate
local TabPlayer = Chassi.Abas.Player

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local Player = Players.LocalPlayer

-- Variáveis de Controle do Voo (Baseado na sua referência)
local flyEnabled = false
local flySpeed = 50
local flyBodyGyro = nil
local flyBodyVel = nil
local flyLoopConnection = nil -- Equivalente ao activeConnections["FlyLoop"]

-- Referência UI
local FlyToggleUI

-- 3. LÓGICA DE VOO (ADAPTAÇÃO DA REFERÊNCIA)
--========================================================================

-- Função auxiliar para pegar o HRP
local function getHRP()
    if Player.Character then
        return Player.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- Função Principal (Lógica Exata do seu snippet)
local function toggleFly(state)
    flyEnabled = state
    LogarEvento("CALLBACK", "toggleFly alterado para: " .. tostring(state))
    
    local hrp = getHRP()
    
    if flyEnabled and hrp then
        -- 1. Criação da Física
        -- Deletar antigos se existirem para evitar duplicidade
        if hrp:FindFirstChild("BodyGyro") then hrp.BodyGyro:Destroy() end
        if hrp:FindFirstChild("BodyVelocity") then hrp.BodyVelocity:Destroy() end

        flyBodyGyro = Instance.new("BodyGyro", hrp)
        flyBodyGyro.P = 9e4
        flyBodyGyro.maxTorque = Vector3.new(9e9, 9e9, 9e9)
        flyBodyGyro.CFrame = hrp.CFrame
        
        flyBodyVel = Instance.new("BodyVelocity", hrp)
        flyBodyVel.Velocity = Vector3.new(0,0,0)
        flyBodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        
        -- 2. O Loop (RenderStepped)
        if flyLoopConnection then flyLoopConnection:Disconnect() end
        
        flyLoopConnection = RunService.RenderStepped:Connect(function()
            -- Verificação de segurança
            if not hrp.Parent or not flyBodyGyro or not flyBodyVel then 
                toggleFly(false) 
                return 
            end
            
            -- Atualiza a rotação para olhar para onde a câmera olha
            flyBodyGyro.CFrame = Camera.CFrame
            
            -- Cálculo do vetor de movimento
            local vel = Vector3.new(0,0,0)
            local cf = Camera.CFrame
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then 
                vel = vel + cf.LookVector * flySpeed 
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then 
                vel = vel - cf.LookVector * flySpeed 
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then 
                vel = vel - cf.RightVector * flySpeed 
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then 
                vel = vel + cf.RightVector * flySpeed 
            end
            -- Sobe com Espaço, Desce com Ctrl (Velocidade ajustada conforme referência / 1.5)
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then 
                vel = vel + Vector3.new(0, flySpeed/1.5, 0) 
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then 
                vel = vel - Vector3.new(0, flySpeed/1.5, 0) 
            end
            
            -- Aplica a velocidade calculada
            flyBodyVel.Velocity = vel
        end)
        
        LogarEvento("INFO", "Voo Ativado (Physics Loop iniciado).")
        
    else
        -- 3. Limpeza (Desativar)
        if flyBodyGyro then 
            flyBodyGyro:Destroy() 
            flyBodyGyro = nil 
        end
        if flyBodyVel then 
            flyBodyVel:Destroy() 
            flyBodyVel = nil 
        end
        if flyLoopConnection then 
            flyLoopConnection:Disconnect() 
            flyLoopConnection = nil
        end
        
        -- Zera a inércia para o personagem cair "parado" e não ser jogado
        if hrp then hrp.Velocity = Vector3.zero end
        
        LogarEvento("INFO", "Voo Desativado (Limpeza concluída).")
    end
end

-- 4. INTERFACE (TAB PLAYER)
--========================================================================
if TabPlayer then
    pCreate("SecFlyRef", TabPlayer, "CreateSection", "Fly (Vector Logic)", "Right")

    -- Toggle
    FlyToggleUI = pCreate("ToggleFlyRef", TabPlayer, "CreateToggle", {
        Name = "Ativar Voo [F]",
        CurrentValue = false,
        Flag = "ToggleFlyRef",
        Callback = pCallback("FlyToggle_Callback", function(Value)
            toggleFly(Value)
        end)
    })

    -- Slider de Velocidade
    pCreate("SliderFlySpeedRef", TabPlayer, "CreateSlider", {
        Name = "Velocidade de Voo",
        Range = {10, 300},
        Increment = 5,
        Suffix = " Speed",
        CurrentValue = 50,
        Flag = "SliderFlySpeedRef",
        Callback = function(Value)
            flySpeed = tonumber(Value) or 50
        end
    })
else
    LogarEvento("ERRO", "TabPlayer não encontrada para criar o Fly.")
end

-- 5. ATALHO DE TECLADO (F)
--========================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F then
        if FlyToggleUI then
            local novoEstado = not flyEnabled
            FlyToggleUI:Set(novoEstado) -- Atualiza UI e dispara o Callback
        end
    end
end)

LogarEvento("SUCESSO", "Módulo Fly (Referência) carregado.")
