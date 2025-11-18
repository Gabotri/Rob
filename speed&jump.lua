--[==[
    MÓDULO: Status Player (Speed & Jump) v1.2 - No Slide
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [NOVO] Sistema "No Slide": Corta a inércia ao soltar as teclas.
    - Speed padrão: 64 | Jump padrão: 128
]==]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO STATUS: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. VARIÁVEIS E SERVIÇOS
local LogarEvento = Chassi.LogarEvento
local pCreate = Chassi.pCreate
local TabPlayer = Chassi.Abas.Player

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

-- Variáveis de Controle
local SpeedValue = 64
local JumpValue = 128
local ForceSpeed = false
local ForceJump = false
local NoSlide = true -- Ativado por padrão para parar na hora

-- 3. LÓGICA TÉCNICA
--========================================================================
local function GetHumanoid()
    if Player.Character then return Player.Character:FindFirstChild("Humanoid") end
    return nil
end

local function GetRoot()
    if Player.Character then return Player.Character:FindFirstChild("HumanoidRootPart") end
    return nil
end

-- Aplicações Únicas
local function ApplySpeed()
    local hum = GetHumanoid()
    if hum then hum.WalkSpeed = SpeedValue end
end

local function ApplyJump()
    local hum = GetHumanoid()
    if hum then
        if hum.UseJumpPower then hum.JumpPower = JumpValue
        else hum.JumpHeight = JumpValue / 5 end
    end
end

-- Loop Principal (Heartbeat)
RunService.Heartbeat:Connect(function()
    local hum = GetHumanoid()
    local root = GetRoot()
    
    if hum and root then
        -- 1. Forçar Velocidade
        if ForceSpeed then
            if hum.WalkSpeed ~= SpeedValue then hum.WalkSpeed = SpeedValue end
        end
        
        -- 2. Forçar Pulo
        if ForceJump then
            if hum.UseJumpPower then
                if hum.JumpPower ~= JumpValue then hum.JumpPower = JumpValue end
            else
                local targetHeight = JumpValue / 5
                if hum.JumpHeight ~= targetHeight then hum.JumpHeight = targetHeight end
            end
        end

        -- 3. Lógica "No Slide" (Parada Instantânea)
        -- Se a opção estiver ativa e o jogador NÃO estiver apertando teclas de andar (MoveDirection ~ 0)
        if NoSlide and hum.MoveDirection.Magnitude < 0.1 then
            -- Mantém a velocidade Y (queda/pulo) mas ZERA a velocidade X e Z (horizontal)
            -- Usa AssemblyLinearVelocity (padrão novo) ou Velocity (antigo)
            local vel = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
        end
    end
end)

-- 4. INTERFACE GRÁFICA
--========================================================================
if TabPlayer then
    pCreate("SecStatus", TabPlayer, "CreateSection", "Super Human (v1.2)", "Right")

    -- === VELOCIDADE ===
    pCreate("SliderSpeed", TabPlayer, "CreateSlider", {
        Name = "Velocidade",
        Range = {16, 300},
        Increment = 1,
        Suffix = " WS",
        CurrentValue = 64,
        Callback = function(Val) SpeedValue = Val; if not ForceSpeed then ApplySpeed() end end
    })
    
    pCreate("ToggleForceSpeed", TabPlayer, "CreateToggle", {
        Name = "Forçar Velocidade (Loop)",
        CurrentValue = false,
        Callback = function(Val) ForceSpeed = Val end
    })

    -- Toggle NOVO para o deslize
    pCreate("ToggleNoSlide", TabPlayer, "CreateToggle", {
        Name = "Parada Instantânea (Sem Deslize)",
        CurrentValue = true, -- Já vem ligado
        Callback = function(Val) 
            NoSlide = Val 
            LogarEvento("CALLBACK", "No Slide alterado para: " .. tostring(Val))
        end
    })

    -- === PULO ===
    pCreate("SliderJump", TabPlayer, "CreateSlider", {
        Name = "Força do Pulo",
        Range = {50, 500},
        Increment = 1,
        Suffix = " JP",
        CurrentValue = 128,
        Callback = function(Val) JumpValue = Val; if not ForceJump then ApplyJump() end end
    })

    pCreate("ToggleForceJump", TabPlayer, "CreateToggle", {
        Name = "Forçar Pulo (Loop)",
        CurrentValue = false,
        Callback = function(Val) ForceJump = Val end
    })
    
    LogarEvento("SUCESSO", "Status Player v1.2 (No Slide) carregado.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada.")
end