--[==[
    MÓDULO: Status Player (Speed & Jump) v1.3 - Auto Start
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [NOVO v1.3] Aplica Speed (64) e Jump (128) IMEDIATAMENTE ao carregar.
    - Inclui "No Slide" (Parada Instantânea).
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

-- Variáveis de Controle (Padrões)
local SpeedValue = 64
local JumpValue = 128
local ForceSpeed = false
local ForceJump = false
local NoSlide = true

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

local function ApplySpeed()
    local hum = GetHumanoid()
    if hum then 
        hum.WalkSpeed = SpeedValue 
        LogarEvento("INFO", "Speed inicial aplicado: " .. SpeedValue)
    end
end

local function ApplyJump()
    local hum = GetHumanoid()
    if hum then
        if hum.UseJumpPower then hum.JumpPower = JumpValue
        else hum.JumpHeight = JumpValue / 5 end
        LogarEvento("INFO", "Jump inicial aplicado: " .. JumpValue)
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
        if NoSlide and hum.MoveDirection.Magnitude < 0.1 then
            local vel = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
        end
    end
end)

-- 4. APLICAÇÃO AUTOMÁTICA (AUTO START)
--========================================================================
-- Chama as funções agora mesmo para setar os valores ao carregar o script
task.spawn(function()
    -- Pequeno delay para garantir que o personagem carregou se o script rodar muito rápido no Join
    if not Player.Character then Player.CharacterAdded:Wait() end
    wait(0.5) 
    ApplySpeed()
    ApplyJump()
end)

-- 5. INTERFACE GRÁFICA
--========================================================================
if TabPlayer then
    pCreate("SecStatus", TabPlayer, "CreateSection", "Super Human (Auto-Start)", "Right")

    -- === VELOCIDADE ===
    pCreate("SliderSpeed", TabPlayer, "CreateSlider", {
        Name = "Velocidade",
        Range = {16, 300},
        Increment = 1,
        Suffix = " WS",
        CurrentValue = 64, -- Mostra 64 na UI
        Callback = function(Val) SpeedValue = Val; if not ForceSpeed then ApplySpeed() end end
    })
    
    pCreate("ToggleForceSpeed", TabPlayer, "CreateToggle", {
        Name = "Forçar Velocidade (Loop)",
        CurrentValue = false,
        Callback = function(Val) ForceSpeed = Val end
    })

    pCreate("ToggleNoSlide", TabPlayer, "CreateToggle", {
        Name = "Parada Instantânea (Sem Deslize)",
        CurrentValue = true, 
        Callback = function(Val) NoSlide = Val end
    })

    -- === PULO ===
    pCreate("SliderJump", TabPlayer, "CreateSlider", {
        Name = "Força do Pulo",
        Range = {50, 500},
        Increment = 1,
        Suffix = " JP",
        CurrentValue = 128, -- Mostra 128 na UI
        Callback = function(Val) JumpValue = Val; if not ForceJump then ApplyJump() end end
    })

    pCreate("ToggleForceJump", TabPlayer, "CreateToggle", {
        Name = "Forçar Pulo (Loop)",
        CurrentValue = false,
        Callback = function(Val) ForceJump = Val end
    })
    
    LogarEvento("SUCESSO", "Status Player v1.3 carregado e aplicado.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada.")
end