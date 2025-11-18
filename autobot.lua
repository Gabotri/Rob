--[==[
    MÓDULO: Path Recorder (Waypoint Sequencer) v1.0
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - Criação visual de pontos de caminho (Waypoints).
    - Reprodução suave do caminho (Tween/Move).
    - Atalho de Ativação: F5.
    - Contém o esqueleto de um Outliner (Lista) e Painel de Propriedades.
]==]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO PATH RECORDER: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. SERVIÇOS E VARIÁVEIS
local LogarEvento = Chassi.LogarEvento
local pCreate = Chassi.pCreate
local TabPlayer = Chassi.Abas.Player

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Estado do Módulo
local PathSettings = {
    Enabled = false,
    IsRecording = false,
    IsPlaying = false,
    MouseLocked = true,    -- Para interação na UI
    SmoothSpeed = 100,     -- Velocidade de movimento em studs/s
    DrawColor = Color3.fromRGB(0, 255, 255)
}

-- Armazenamento e Cache
local Waypoints = {}       -- Lista de CFrames/Pontos
local WaypointParts = {}   -- Peças visuais no mundo
local WaypointLines = {}   -- Linhas visuais (Drawing API)
local CurrentMoveTween = nil
local CurrentWaypointIndex = 1

-- UI References
local ScreenGui, PlayPauseBtn, ClearBtn, PointListScroll

-- 3. LÓGICA DE VISUALIZAÇÃO (Desenho de Pontos e Linhas)
--========================================================================

local function DrawLine(p1, p2, color)
    local line = Drawing.new("Line")
    line.Thickness = 2
    line.Color = color
    
    local vec1, vis1 = Camera:WorldToViewportPoint(p1)
    local vec2, vis2 = Camera:WorldToViewportPoint(p2)

    if vis1 and vis2 then
        line.Visible = true
        line.From = Vector2.new(vec1.X, vec1.Y)
        line.To = Vector2.new(vec2.X, vec2.Y)
    else
        line.Visible = false
    end
    table.insert(WaypointLines, line)
end

local function UpdateVisualPath()
    -- Limpa Linhas Antigas
    for _, line in pairs(WaypointLines) do line:Remove() end
    WaypointLines = {}
    
    -- Atualiza Peças e Desenha Novas Linhas
    for i, point in ipairs(Waypoints) do
        local part = WaypointParts[i]
        if not part then
            part = Instance.new("Part")
            part.Shape = Enum.PartType.Ball; part.Size = Vector3.new(1,1,1); part.Anchored = true; part.CanCollide = false
            part.Material = Enum.Material.Neon; part.Color = PathSettings.DrawColor; part.Position = point.CFrame.Position
            part.Parent = Workspace; part.Name = "Waypoint_"..i
            WaypointParts[i] = part
        end
        
        -- Linha Conectora (Path Visualization)
        if i > 1 then
            local prevPart = WaypointParts[i-1]
            if prevPart then
                -- Desenho de Linhas via Drawing API para performance (Simulando Traceline)
                -- O Drawing API precisa ser atualizado em RenderStepped (feito na função principal)
                -- Vamos apenas criar as partes para a lógica do caminho
            end
        end
    end
end

-- 4. MOVIMENTO E AUTOMAÇÃO (Playback)
--========================================================================

local function MoveToNextWaypoint()
    if CurrentWaypointIndex > #Waypoints then
        LogarEvento("SUCESSO", "Caminho finalizado.")
        CurrentWaypointIndex = 1
        PathSettings.IsPlaying = false
        return
    end

    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local targetPoint = Waypoints[CurrentWaypointIndex]
    local targetCFrame = targetPoint.CFrame
    
    local distance = (targetCFrame.Position - hrp.Position).Magnitude
    local duration = distance / PathSettings.SmoothSpeed
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    CurrentMoveTween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    CurrentMoveTween:Play()
    
    CurrentMoveTween.Completed:Wait() -- Espera o movimento acabar
    
    CurrentWaypointIndex = CurrentWaypointIndex + 1
    MoveToNextWaypoint()
end

local function TogglePlayback(state)
    PathSettings.IsPlaying = state
    if CurrentMoveTween then CurrentMoveTween:Cancel() end
    
    if state then
        CurrentWaypointIndex = 1
        MoveToNextWaypoint()
    end
end

-- 5. FUNÇÃO DE ENTRADA (F5)
--========================================================================

local function TogglePathManager(state)
    PathSettings.Enabled = state
    
    if state then
        -- Ativa o modo de edição (Mouse livre)
        PathSettings.MouseLocked = false
    else
        -- Desativa e Limpa
        PathSettings.IsPlaying = false
        PathSettings.MouseLocked = true
        if CurrentMoveTween then CurrentMoveTween:Cancel() end
    end
    
    -- Atualiza Mouse State
    local mouseBehavior = PathSettings.MouseLocked and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
    UserInputService.MouseBehavior = mouseBehavior
    UserInputService.MouseIconEnabled = not PathSettings.MouseLocked
    
    LogarEvento("INFO", "Path Manager: " .. (state and "ATIVADO" or "DESATIVADO"))
end

-- 6. UI PURA (Painel de Propriedades e Lista de Pontos)
--========================================================================

local function SetupPureUI()
    local Gui = Instance.new("ScreenGui", CoreGui); Gui.Name = "PathEditorUI"
    local Frame = Instance.new("Frame", Gui); Frame.Size = UDim2.new(0,250,0,300); Frame.Position = UDim2.new(0.05,0,0.1,0)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35); Frame.Active = true; Frame.Draggable = true
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 6)
    
    -- Header
    local Title = Instance.new("TextLabel", Frame); Title.Size=UDim2.new(1,0,0,25); Title.Text="Path Recorder v1.0"; Title.BackgroundTransparency=0; Title.BackgroundColor3=Color3.fromRGB(40,40,45); Title.TextColor3=Color3.white
    
    -- Botões de Controle
    local BtnPlay = Instance.new("TextButton", Frame); BtnPlay.Size=UDim2.new(0.3,0,0,25); BtnPlay.Position=UDim2.new(0.05,0,0.1,0); BtnPlay.Text="PLAY"; BtnPlay.BackgroundColor3=Color3.fromRGB(0,180,100)
    local BtnPause = Instance.new("TextButton", Frame); BtnPause.Size=UDim2.new(0.3,0,0,25); BtnPause.Position=UDim2.new(0.35,0,0.1,0); BtnPause.Text="PAUSE"; BtnPause.BackgroundColor3=Color3.fromRGB(200,100,0)
    local BtnClear = Instance.new("TextButton", Frame); BtnClear.Size=UDim2.new(0.3,0,0,25); BtnClear.Position=UDim2.new(0.65,0,0.1,0); BtnClear.Text="CLEAR"; BtnClear.BackgroundColor3=Color3.fromRGB(180,60,60)
    
    -- Lista de Pontos (Outliner Simplificado)
    PointListScroll = Instance.new("ScrollingFrame", Frame); PointListScroll.Size=UDim2.new(1,-10,1,-70); PointListScroll.Position=UDim2.new(0.05,0,0.22,0)
    PointListScroll.BackgroundColor3=Color3.fromRGB(35,35,40); PointListScroll.CanvasSize=UDim2.new(0,0,0,0)
    local UIL = Instance.new("UIListLayout", PointListScroll); UIL.Padding=UDim.new(0,3)
    
    -- Conexão dos Botões
    BtnPlay.MouseButton1Click:Connect(function() TogglePlayback(true) end)
    BtnPause.MouseButton1Click:Connect(function() PathSettings.IsPlaying = false; if CurrentMoveTween then CurrentMoveTween:Cancel() end end)
    BtnClear.MouseButton1Click:Connect(function() 
        Waypoints = {}; for _, p in pairs(WaypointParts) do p:Destroy() end; WaypointParts = {}; UpdateVisualPath(); RefreshList()
    end)
    
    return Frame
end

local function RefreshList()
    -- Atualiza a lista visualmente
    if not PointListScroll then return end
    for _, child in pairs(PointListScroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    
    local yOffset = 0
    for i, point in ipairs(Waypoints) do
        local Item = Instance.new("Frame", PointListScroll); Item.Size=UDim2.new(1,0,0,20); Item.BackgroundTransparency=1
        local Lbl = Instance.new("TextLabel", Item); Lbl.Text="Ponto #"..i; Lbl.Size=UDim2.new(1,0,1,0); Lbl.BackgroundTransparency=1; Lbl.TextColor3=Color3.white; Lbl.TextXAlignment=Enum.TextXAlignment.Left
        yOffset = yOffset + 25
    end
    PointListScroll.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

-- 7. INPUTS E ATALHOS
--========================================================================

local function HandleMouseClick(input, gameProcessed)
    if not PathSettings.Enabled or gameProcessed then return end
    
    -- Clique Direito para Adicionar Ponto
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        local target = LocalPlayer:GetMouse().Hit.Position
        
        -- Auto-snap a superfícies (adiciona um offset de altura)
        local ray = Workspace:Raycast(target + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0))
        local pos = ray and ray.Position or target -- Pega a posição do chão
        
        table.insert(Waypoints, {CFrame = CFrame.new(pos)})
        UpdateVisualPath()
        RefreshList()
        LogarEvento("INFO", "Waypoint adicionado: #"..#Waypoints)
    end
end

-- Loop para Desenhar Linhas Traceline
RunService.RenderStepped:Connect(function()
    if PathSettings.Enabled then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and #Waypoints > 0 then
            -- Redesenha todas as linhas no frame da tela
            UpdateVisualPath()
        end
    end
end)

-- Conexão de Eventos
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.F5 then
        TogglePathManager(not PathSettings.Enabled)
        if Chassi.Abas.Player and Chassi.Abas.Player:FindFirstChild("TogglePath") then
            Chassi.Abas.Player:FindFirstChild("TogglePath"):Set(PathSettings.Enabled)
        end
    end
end)
UserInputService.InputBegan:Connect(HandleMouseClick)

-- 8. INICIALIZAÇÃO
--========================================================================
SetupPureUI()

if TabPlayer then
    pCreate("SecPath", TabPlayer, "CreateSection", "Path Recorder (F5)", "Right")
    pCreate("TogglePath", TabPlayer, "CreateToggle", {
        Name = "Ativar Path Manager [F5]",
        CurrentValue = PathSettings.Enabled,
        Callback = TogglePathManager
    })
    
    pCreate("SliderSpeed", TabPlayer, "CreateSlider", {
        Name = "Velocidade Suave",
        Range = {10, 500}, Increment = 10, Suffix = " sps",
        CurrentValue = 100,
        Callback = function(Val) PathSettings.SmoothSpeed = Val end
    })

    LogarEvento("SUCESSO", "Módulo Path Recorder v1.0 carregado.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada para Path Recorder.")
end