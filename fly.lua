--[==[
    MÓDULO: Fly (Voo) v2.1
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: Adiciona Toggle, Slider de Velocidade e atalho 'F' na Aba Player.
    ATUALIZAÇÃO v2.1:
    - [FIX] Corrigido o erro de hierarquia. Elementos (Toggle, Slider) agora são
      criados como filhos da 'TabPlayer', não da 'SecMovimento'.
    - [FIX] Removido 'pCallback' do 'CreateSlider' para evitar spam no console.
    - [FIX] Adicionado 'pcall' interno na 'SetFlySpeed' para segurança.
]==]

-- 1. PUXA O CHASSI (A "COLA")
--========================================================================
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO FLY v2.1: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. DESEMPACOTA AS FUNÇÕES DO CHASSI
--========================================================================
local LogarEvento = Chassi.LogarEvento
local pCallback = Chassi.pCallback
local pCreate = Chassi.pCreate
local Sirius = Chassi.Sirius
local TabPlayer = Chassi.Abas.Player

LogarEvento("INFO", "Módulo 'Fly v2.1' iniciando carregamento...")

-- Serviços do Roblox
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- 3. CRIA A LÓGICA DE VOO
--========================================================================
local Player = Players.LocalPlayer
local FlyToggle -- Variável para guardar nosso botão
_G.FlyLoopActive = false -- Flag global para controlar o loop

local DEFAULT_WALKSPEED = 16 -- Padrão do Roblox
local currentFlySpeed = 75   -- Padrão de voo

local function GetHumanoid()
    local Character = Player.Character
    if not Character then return nil end
    return Character:FindFirstChildOfClass("Humanoid")
end

-- Esta função agora controla PlatformStand E WalkSpeed
local function SetFlyState(Value)
    LogarEvento("CALLBACK", "SetFlyState (Fly v2.1) chamado com: " .. tostring(Value))
    
    local Humanoid = GetHumanoid()
    if not Humanoid then
        LogarEvento("ERRO", "Fly v2.1: Humanoid não encontrado.")
        return
    end
    
    _G.FlyLoopActive = Value
    
    if Value == true then
        -- Voo ATIVADO
        DEFAULT_WALKSPEED = Humanoid.WalkSpeed -- Salva a velocidade normal
        Humanoid.WalkSpeed = currentFlySpeed   -- Aplica a velocidade de voo
        
        spawn(function()
            LogarEvento("INFO", "Fly v2.1: Loop de voo iniciado.")
            while _G.FlyLoopActive do
                Humanoid.PlatformStand = true
                RunService.Heartbeat:Wait()
            end
            -- Garante que saia do PlatformStand ao desligar
            Humanoid.PlatformStand = false
            Humanoid.WalkSpeed = DEFAULT_WALKSPEED -- Restaura a velocidade
            LogarEvento("INFO", "Fly v2.1: Loop de voo terminado. Velocidade restaurada para " .. DEFAULT_WALKSPEED)
        end)
    else
        -- Voo DESATIVADO
        -- (A flag _G.FlyLoopActive = false matará o loop acima)
    end
end

-- Esta função é chamada pelo SLIDER
local function SetFlySpeed(Speed)
    -- !! CORREÇÃO v2.1 !!
    -- Adicionado Pcall, já que não está mais protegido pelo pCallback (para evitar spam)
    local status, err = pcall(function()
        local speedNum = tonumber(Speed) or 75
        currentFlySpeed = speedNum
        
        -- Se o voo estiver ativo, aplica a velocidade imediatamente
        if _G.FlyLoopActive then
            local Humanoid = GetHumanoid()
            if Humanoid then
                Humanoid.WalkSpeed = currentFlySpeed
            end
        end
    end)
    
    if not status then
        LogarEvento("ERRO", "Falha no SetFlySpeed (Slider): " .. tostring(err))
    end
end

-- 4. CRIA A INTERFACE (NA ABA PLAYER)
--========================================================================
if TabPlayer then
    -- 1. A SEÇÃO (Apenas um label visual)
    -- O parent é 'TabPlayer'.
    pCreate("SecMovimento_Fly", TabPlayer, "CreateSection", "Movimentação (Fly v2.1)", "Left")
    
    -- 2. O TOGGLE
    -- O parent TAMBÉM é 'TabPlayer'.
    FlyToggle = pCreate("ToggleFly", TabPlayer, "CreateToggle", {
        Name = "Voo (Fly) - [F]",
        Default = false,
        Callback = pCallback("Fly_Toggle", SetFlyState) -- pCallback é bom aqui (one-shot)
    })
    
    -- 3. O SLIDER
    -- O parent TAMBÉM é 'TabPlayer'.
    pCreate("SliderFlySpeed", TabPlayer, "CreateSlider", {
        Name = "Velocidade de Voo",
        Min = 16,
        Max = 500,
        Default = currentFlySpeed,
        Round = 0,
        -- !! CORREÇÃO v2.1 !!
        -- Removemos o 'pCallback' daqui para não spammar o console.
        Callback = SetFlySpeed 
    })
    
    LogarEvento("SUCESSO", "Módulo 'Fly v2.1': Interface (Toggle+Slider) criada na Aba Player.")
else
    LogarEvento("ERRO", "Módulo 'Fly v2.1': Não foi possível encontrar a 'TabPlayer'.")
end

-- 5. CRIA O ATALHO (TECLA F)
--========================================================================
local keybindConnection = RunService.RenderStepped:Connect(function()
    local status, err = pcall(function()
        if UserInputService:GetFocusedTextBox() == nil then
            if UserInputService:IsKeyDown(Enum.KeyCode.F) then
                if FlyToggle then
                    local currentState = FlyToggle:Get()
                    FlyToggle:Set(not currentState) -- Inverte o toggle
                    wait(0.2) -- Debounce (evita spam)
                end
            end
        end
    end)
    
    if not status then
        LogarEvento("ERRO", "Falha CRÍTICA no listener de atalho 'Fly v2.1': " .. tostring(err))
        if keybindConnection then
            keybindConnection:Disconnect()
            LogarEvento("AVISO", "Listener de atalho 'Fly v2.1' foi desconectado devido a erro.")
        end
    end
end)

LogarEvento("SUCESSO", "Módulo 'Fly v2.1' (com Slider) carregado e pronto. Pressione 'F' ou use o toggle.")
