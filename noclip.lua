--[==[
    MÓDULO: Noclip (Atravessar Paredes) v1.0
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: Permite atravessar paredes forçando CanCollide = false.
    ATALHO: Tecla 'N'.
    NOTA: Recomenda-se usar junto com o Fly para não cair no void.
]==]

-- 1. PUXA O CHASSI (A "COLA")
--========================================================================
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO NOCLIP: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. VARIÁVEIS E SERVIÇOS
--========================================================================
local LogarEvento = Chassi.LogarEvento
local pCallback = Chassi.pCallback
local pCreate = Chassi.pCreate
local TabPlayer = Chassi.Abas.Player

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Player = Players.LocalPlayer

local NoclipEnabled = false
local NoclipConnection = nil
local NoclipToggleUI -- Referência para o botão na UI

-- 3. LÓGICA DO NOCLIP
--========================================================================
local function ToggleNoclip(State)
    NoclipEnabled = State
    LogarEvento("CALLBACK", "ToggleNoclip alterado para: " .. tostring(State))

    if NoclipEnabled then
        -- ATIVAR NOCLIP
        if NoclipConnection then NoclipConnection:Disconnect() end
        
        -- O evento 'Stepped' roda antes da física, garantindo que a colisão seja desligada a tempo
        NoclipConnection = RunService.Stepped:Connect(function()
            local Character = Player.Character
            if Character then
                for _, part in pairs(Character:GetChildren()) do
                    if part:IsA("BasePart") and part.CanCollide == true then
                        part.CanCollide = false
                    end
                end
            end
        end)
        
        LogarEvento("INFO", "Noclip ATIVADO. Loop Stepped iniciado.")
    else
        -- DESATIVAR NOCLIP
        if NoclipConnection then 
            NoclipConnection:Disconnect() 
            NoclipConnection = nil
        end
        
        -- Tenta restaurar colisão (opcional, o jogo costuma fazer isso sozinho ao andar)
        local Character = Player.Character
        if Character then
            local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
            if HumanoidRootPart then HumanoidRootPart.CanCollide = true end
        end
        
        LogarEvento("INFO", "Noclip DESATIVADO. Loop encerrado.")
    end
end

-- 4. INTERFACE (TAB PLAYER)
--========================================================================
if TabPlayer then
    -- Cria uma seção específica se ainda não existir visualmente organizada
    -- (O Rayfield agrupa seções com mesmo nome, ou cria nova abaixo)
    pCreate("SecNoclip", TabPlayer, "CreateSection", "Utilitários de Física", "Left")

    NoclipToggleUI = pCreate("ToggleNoclip", TabPlayer, "CreateToggle", {
        Name = "Noclip (Paredes) [N]",
        CurrentValue = false,
        Flag = "ToggleNoclipFlag",
        Callback = pCallback("Noclip_Callback", ToggleNoclip)
    })
    
    LogarEvento("SUCESSO", "Módulo Noclip: UI criada na Aba Player.")
else
    LogarEvento("ERRO", "Módulo Noclip: TabPlayer não encontrada.")
end

-- 5. ATALHO DE TECLADO (N)
--========================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end -- Ignora se estiver digitando no chat
    
    if input.KeyCode == Enum.KeyCode.N then
        if NoclipToggleUI then
            local novoEstado = not NoclipEnabled
            LogarEvento("INFO", "Atalho 'N' pressionado. Noclip: " .. tostring(novoEstado))
            
            -- Atualiza a UI (que chama o Callback automaticamente)
            NoclipToggleUI:Set(novoEstado)
        end
    end
end)

LogarEvento("SUCESSO", "Módulo Noclip carregado. Pressione 'N' para alternar.")