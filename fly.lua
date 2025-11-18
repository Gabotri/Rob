--[==[
    MÓDULO: Fly (Voo Físico) v3.0 (BodyVelocity Edition)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: Sistema de voo real usando Física (BV/BG).
    CONTROLES:
      - W, A, S, D: Movimento
      - Space: Subir
      - LeftControl: Descer
      - F: Ativar/Desativar
    
    MUDANÇAS v3.0:
    - [CHANGE] Removido PlatformStand puro. Adicionado BodyVelocity/BodyGyro.
    - [FIX] Voo agora ignora gravidade.
    - [FIX] Logs integrados em cada etapa da física.
]==]

-- 1. PUXA O CHASSI (A "COLA")
--========================================================================
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO FLY v3.0: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. DESEMPACOTA AS FUNÇÕES DO CHASSI
--========================================================================
local LogarEvento = Chassi.LogarEvento
local pCallback = Chassi.pCallback
local pCreate = Chassi.pCreate
local Sirius = Chassi.Sirius
local TabPlayer = Chassi.Abas.Player

LogarEvento("INFO", "Módulo 'Fly v3.0 (Physics)' iniciando carregamento...")

-- Serviços Essenciais
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- 3. LÓGICA DE VOO (FÍSICA)
--========================================================================
local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local FlyToggleUI -- Referência ao botão na UI

-- Variáveis de Estado
local isFlying = false
local flySpeed = 50 -- Velocidade padrão inicial
local bv, bg -- Variáveis para armazenar os objetos físicos (BodyVelocity, BodyGyro)

-- Função para limpar a física antiga (caso tenha sobrado algo)
local function LimparFisica(rootPart)
    if rootPart then
        for _, obj in pairs(rootPart:GetChildren()) do
            if obj.Name == "GabotriFlightForce" or obj.Name == "GabotriFlightGyro" then
                obj:Destroy()
            end
        end
    end
end

local function StartFly()
    local Character = Player.Character
    if not Character then LogarEvento("ERRO", "StartFly: Personagem não encontrado.") return end
    
    local RootPart = Character:FindFirstChild("HumanoidRootPart")
    local Humanoid = Character:FindFirstChild("Humanoid")
    
    if not RootPart or not Humanoid then 
        LogarEvento("ERRO", "StartFly: RootPart ou Humanoid faltando.") 
        return 
    end

    -- 1. Prepara o ambiente
    isFlying = true
    LimparFisica(RootPart) -- Garante que não duplique
    Humanoid.PlatformStand = true -- Desativa animação de andar/cair
    
    -- 2. Cria o Giroscópio (Estabilidade)
    bg = Instance.new("BodyGyro")
    bg.Name = "GabotriFlightGyro"
    bg.P = 9e4
    bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.CFrame = RootPart.CFrame
    bg.Parent = RootPart
    
    -- 3. Cria a Velocidade (Movimento + Anti-Gravidade)
    bv = Instance.new("BodyVelocity")
    bv.Name = "GabotriFlightForce"
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.maxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Parent = RootPart
    
    LogarEvento("INFO", "Voo INICIADO. Física aplicada ao personagem.")

    -- 4. Loop de Atualização (Roda a cada frame)
    spawn(function()
        while isFlying and Character and Humanoid and RootPart do
            -- Pega a direção da câmera
            local delta = 0
            local moveDir = Vector3.new(0,0,0)
            
            -- Controles de Movimento (CFrame da Câmera)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir = moveDir + Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir = moveDir - Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir = moveDir - Camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir = moveDir + Camera.CFrame.RightVector
            end
            
            -- Controles de Altura (Espaço/Ctrl)
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                moveDir = moveDir - Vector3.new(0, 1, 0)
            end
            
            -- Aplica ao BodyGyro (Olhar para onde a câmera olha)
            bg.CFrame = Camera.CFrame
            
            -- Aplica ao BodyVelocity (Mover na direção calculada * Velocidade)
            bv.Velocity = moveDir * flySpeed
            
            RunService.RenderStepped:Wait()
        end
    end)
end

local function StopFly()
    isFlying = false
    local Character = Player.Character
    if Character then
        local Humanoid = Character:FindFirstChild("Humanoid")
        local RootPart = Character:FindFirstChild("HumanoidRootPart")
        
        if Humanoid then 
            Humanoid.PlatformStand = false -- Devolve controle ao boneco
        end
        
        LimparFisica(RootPart) -- Remove BV e BG
        
        -- Zera a velocidade residual para não ser jogado longe
        if RootPart then RootPart.Velocity = Vector3.new(0,0,0) end
    end
    LogarEvento("INFO", "Voo ENCERRADO. Física removida.")
end

-- Função Toggle Principal
local function ToggleFlyState(Value)
    LogarEvento("CALLBACK", "ToggleFlyState chamado. Novo estado: " .. tostring(Value))
    if Value then
        StartFly()
    else
        StopFly()
    end
end

-- Função Slider
local function UpdateFlySpeed(Value)
    flySpeed = tonumber(Value) or 50
    -- Não logamos aqui para não floodar o console ao arrastar o slider
end

-- 4. CRIA A INTERFACE (NA ABA PLAYER)
--========================================================================
if TabPlayer then
    pCreate("SecMovimento_Fly", TabPlayer, "CreateSection", "Voo Avançado (v3.0)", "Left")
    
    FlyToggleUI = pCreate("ToggleFly", TabPlayer, "CreateToggle", {
        Name = "Ativar Voo [F]",
        CurrentValue = false, -- Sintaxe Sirius
        Flag = "ToggleFlyFlag",
        Callback = pCallback("Fly_Toggle", ToggleFlyState)
    })
    
    pCreate("SliderFlySpeed", TabPlayer, "CreateSlider", {
        Name = "Velocidade de Voo",
        Range = {10, 300}, -- Sintaxe Sirius (Min, Max)
        Increment = 1,
        Suffix = " Studs",
        CurrentValue = 50,
        Flag = "SliderFlySpeedFlag",
        Callback = UpdateFlySpeed
    })
    
    LogarEvento("SUCESSO", "Módulo 'Fly v3.0': UI criada na Aba Player.")
else
    LogarEvento("ERRO", "Módulo 'Fly v3.0': TabPlayer não encontrada.")
end

-- 5. ATALHO DE TECLADO (F)
--========================================================================
-- Listener seguro que verifica se o jogador não está digitando no chat
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end -- Ignora se estiver digitando no chat
    
    if input.KeyCode == Enum.KeyCode.F then
        if FlyToggleUI then
            local novoEstado = not isFlying
            LogarEvento("INFO", "Atalho 'F' pressionado. Alternando voo para: " .. tostring(novoEstado))
            
            -- Atualiza a UI do Rayfield (que chama o Callback automaticamente)
            FlyToggleUI:Set(novoEstado)
        end
    end
end)

LogarEvento("SUCESSO", "Módulo 'Fly v3.0' carregado. Pressione F para voar.")
