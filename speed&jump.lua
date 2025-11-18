--[==[
    MÓDULO: Status Player (Speed & Jump Force) v1.1
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - Sliders para definir valores.
    - Botões para aplicar uma vez.
    - Toggles para FORÇAR (Loop) contra anti-cheats básicos.
    - [MUDANÇA v1.1] Padrões alterados: Speed 64, Jump 128.
]==]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO STATUS: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. VARIÁVEIS E SERVIÇOS
local LogarEvento = Chassi.LogarEvento
local pCallback = Chassi.pCallback
local pCreate = Chassi.pCreate
local TabPlayer = Chassi.Abas.Player

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

-- Variáveis de Controle (Valores Iniciais Alterados)
local SpeedValue = 64   -- Padrão v1.1
local JumpValue = 128   -- Padrão v1.1
local ForceSpeed = false
local ForceJump = false
local LoopConnection

-- 3. LÓGICA DE APLICAÇÃO E LOOP
--========================================================================

-- Função auxiliar para pegar Humanoide seguro
local function GetHumanoid()
    if Player.Character then
        return Player.Character:FindFirstChild("Humanoid")
    end
    return nil
end

-- Aplica a velocidade uma vez
local function ApplySpeed()
    local hum = GetHumanoid()
    if hum then
        hum.WalkSpeed = SpeedValue
    end
end

-- Aplica o pulo uma vez (Detecta se é Power ou Height)
local function ApplyJump()
    local hum = GetHumanoid()
    if hum then
        if hum.UseJumpPower then
            hum.JumpPower = JumpValue
        else
            -- Conversão: JumpHeight geralmente é menor (ex: 7.2 vs 50)
            -- Se o usuário colocar 128 no slider, JumpHeight será ~25.6
            hum.JumpHeight = JumpValue / 5 
        end
    end
end

-- O Loop Principal (Heartbeat roda todo frame de física)
LoopConnection = RunService.Heartbeat:Connect(function()
    local hum = GetHumanoid()
    if hum then
        -- Forçar Velocidade
        if ForceSpeed then
            if hum.WalkSpeed ~= SpeedValue then
                hum.WalkSpeed = SpeedValue
            end
        end
        
        -- Forçar Pulo
        if ForceJump then
            if hum.UseJumpPower then
                if hum.JumpPower ~= JumpValue then hum.JumpPower = JumpValue end
            else
                local targetHeight = JumpValue / 5
                if hum.JumpHeight ~= targetHeight then hum.JumpHeight = targetHeight end
            end
        end
    end
end)

-- 4. INTERFACE GRÁFICA (Tab Player)
--========================================================================
if TabPlayer then
    pCreate("SecStatus", TabPlayer, "CreateSection", "Alterar Status (Force Mode)", "Right")

    -- === VELOCIDADE ===
    pCreate("SliderSpeed", TabPlayer, "CreateSlider", {
        Name = "Velocidade (WalkSpeed)",
        Range = {16, 500},
        Increment = 1,
        Suffix = " Speed",
        CurrentValue = 64, -- Padrão atualizado
        Flag = "SliderSpeed",
        Callback = function(Value)
            SpeedValue = Value
            -- Se o toggle não estiver ligado, aplicamos uma vez ao arrastar
            if not ForceSpeed then ApplySpeed() end
        end
    })

    pCreate("ToggleForceSpeed", TabPlayer, "CreateToggle", {
        Name = "Forçar Velocidade (Loop)",
        CurrentValue = false,
        Flag = "ToggleForceSpeed",
        Callback = function(Value)
            ForceSpeed = Value
            LogarEvento("CALLBACK", "Force Speed alterado para: " .. tostring(Value))
        end
    })

    pCreate("BtnApplySpeed", TabPlayer, "CreateButton", {
        Name = "Aplicar Velocidade (Manual)",
        Callback = function()
            ApplySpeed()
            LogarEvento("INFO", "Velocidade aplicada manualmente: " .. SpeedValue)
        end
    })

    -- === PULO ===
    pCreate("SliderJump", TabPlayer, "CreateSlider", {
        Name = "Força do Pulo (Jump)",
        Range = {50, 500},
        Increment = 1,
        Suffix = " Power",
        CurrentValue = 128, -- Padrão atualizado
        Flag = "SliderJump",
        Callback = function(Value)
            JumpValue = Value
            if not ForceJump then ApplyJump() end
        end
    })

    pCreate("ToggleForceJump", TabPlayer, "CreateToggle", {
        Name = "Forçar Pulo (Loop)",
        CurrentValue = false,
        Flag = "ToggleForceJump",
        Callback = function(Value)
            ForceJump = Value
            LogarEvento("CALLBACK", "Force Jump alterado para: " .. tostring(Value))
        end
    })

    pCreate("BtnApplyJump", TabPlayer, "CreateButton", {
        Name = "Aplicar Pulo (Manual)",
        Callback = function()
            ApplyJump()
            LogarEvento("INFO", "Pulo aplicado manualmente: " .. JumpValue)
        end
    })
    
    LogarEvento("SUCESSO", "Módulo Status Player v1.1 carregado na UI.")
else
    LogarEvento("ERRO", "Módulo Status: TabPlayer não encontrada.")
end