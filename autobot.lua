--[==[
    MÓDULO: Path Recorder (Waypoint Sequencer) v1.1
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [FIX] Substituído Color3.white por Color3.fromRGB para corrigir erro 'got nil'.
    - Criação visual de pontos (Clique Direito).
    - Reprodução suave (Tween) com velocidade ajustável.
    - Atalho F5 (Ativar/Desativar) e P (Liberar Mouse).
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
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Estado do Módulo
local PathSettings = {
    Enabled = false,
    IsPlaying = false,
    MouseLocked = true,    
    SmoothSpeed = 50,      -- Velocidade Padrão
    DrawColor = Color3.fromRGB(0, 255, 255)
}

-- Armazenamento
local Waypoints = {}       
local WaypointParts = {}   
local WaypointLines = {}   
local CurrentMoveTween = nil
local CurrentWaypointIndex = 1

-- UI References
local ScreenGui, PointListScroll

-- 3. LÓGICA DE VISUALIZAÇÃO (Drawing API + Parts)
--========================================================================
local function ClearVisuals()
    for _, line in pairs(WaypointLines) do line:Remove() end
    WaypointLines = {}
    for _, part in pairs(WaypointParts) do part:Destroy() end
    WaypointParts = {}
end

local function UpdateVisualPath()
    -- Limpa linhas antigas (Drawing)
    for _, line in pairs(WaypointLines) do line:Remove() end
    WaypointLines = {}
    
    -- Garante que as partes existam
    for i, point in ipairs(Waypoints) do
        if not WaypointParts[i] then
            local part = Instance.new("Part")
            part.Shape = Enum.PartType.Ball
            part.Size = Vector3.new(1.5, 1.5, 1.5)
            part.Anchored = true
            part.CanCollide = false
            part.Material = Enum.Material.Neon
            part.Color = PathSettings.DrawColor
            part.Position = point.CFrame.Position
            part.Parent = Workspace
            part.Name = "Waypoint_"..i
            WaypointParts[i] = part
        end
        
        -- Desenha linha conectando ao anterior
        if i > 1 then
            local currPos = WaypointParts[i].Position
            local prevPos = WaypointParts[i-1].Position
            
            local vec1, vis1 = Camera:WorldToViewportPoint(currPos)
            local vec2, vis2 = Camera:WorldToViewportPoint(prevPos)
            
            if vis1 and vis2 then
                local line = Drawing.new("Line")
                line.Thickness = 2
                line.Color = PathSettings.DrawColor
                line.From = Vector2.new(vec1.X, vec1.Y)
                line.To = Vector2.new(vec2.X, vec2.Y)
                line.Visible = true
                table.insert(WaypointLines, line)
            end
        end
    end
end

-- 4. MOVIMENTO E AUTOMAÇÃO (Playback)
--========================================================================
local function MoveToNextWaypoint()
    if not PathSettings.IsPlaying then return end

    if CurrentWaypointIndex > #Waypoints then
        LogarEvento("SUCESSO", "Caminho finalizado.")
        PathSettings.IsPlaying = false
        CurrentWaypointIndex = 1
        return
    end

    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local targetPoint = Waypoints[CurrentWaypointIndex]
    
    -- Cálculo de Tempo baseado na Velocidade (Slider)
    local distance = (targetPoint.CFrame.Position - hrp.Position).Magnitude
    local speed = math.max(1, PathSettings.SmoothSpeed) -- Evita div/0
    local duration = distance / speed
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    CurrentMoveTween = TweenService:Create(hrp, tweenInfo, {CFrame = targetPoint.CFrame})
    CurrentMoveTween:Play()
    
    LogarEvento("INFO", "Indo para Ponto #"..CurrentWaypointIndex.." ("..math.floor(duration).."s)")
    
    CurrentMoveTween.Completed:Wait() -- Espera chegar
    
    -- Se ainda estiver tocando, vai pro próximo
    if PathSettings.IsPlaying then
        CurrentWaypointIndex = CurrentWaypointIndex + 1
        MoveToNextWaypoint()
    end
end

local function TogglePlayback(state)
    PathSettings.IsPlaying = state
    if not state and CurrentMoveTween then CurrentMoveTween:Cancel() end
    
    if state then
        CurrentWaypointIndex = 1
        -- Solta o mouse para não atrapalhar se estiver travado
        if PathSettings.Enabled then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
        MoveToNextWaypoint()
    end
end

-- 5. GERENCIAMENTO DE UI PURA (COMPATIBLE COLORS)
--========================================================================
local function RefreshList()
    if not PointListScroll then return end
    for _, child in pairs(PointListScroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    
    local yOffset = 0
    for i, point in ipairs(Waypoints) do
        local Item = Instance.new("Frame", PointListScroll)
        Item.Size = UDim2.new(1, 0, 0, 25)
        Item.BackgroundTransparency = 1
        Item.Position = UDim2.new(0, 0, 0, yOffset)
        
        local Lbl = Instance.new("TextLabel", Item)
        Lbl.Text = "Ponto #" .. i
        Lbl.Size = UDim2.new(1, -10, 1, 0)
        Lbl.Position = UDim2.new(0, 5, 0, 0)
        Lbl.BackgroundTransparency = 1
        Lbl.TextColor3 = Color3.fromRGB(255, 255, 255) -- [FIX]
        Lbl.TextXAlignment = Enum.TextXAlignment.Left
        Lbl.Font = Enum.Font.Code
        Lbl.TextSize = 12
        
        yOffset = yOffset + 25
    end
    PointListScroll.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

local function SetupPureUI()
    ScreenGui = Instance.new("ScreenGui", CoreGui)
    ScreenGui.Name = "PathEditorUI_v1.1"
    ScreenGui.Enabled = false -- Começa escondido até ativar F5
    
    local Frame = Instance.new("Frame", ScreenGui)
    Frame.Size = UDim2.new(0, 250, 0, 350)
    Frame.Position = UDim2.new(0.05, 0, 0.2, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    Frame.Active = true; Frame.Draggable = true
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 6)
    
    -- Header
    local Title = Instance.new("TextLabel", Frame)
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Text = "  Path Recorder v1.1 [F5]"
    Title.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    Title.TextColor3 = Color3.fromRGB(255, 255, 255) -- [FIX]
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Font = Enum.Font.GothamBold
    Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 6)
    
    -- Botões
    local function CreateBtn(text, col, pos_y, func)
        local btn = Instance.new("TextButton", Frame)
        btn.Text = text
        btn.BackgroundColor3 = col
        btn.TextColor3 = Color3.fromRGB(255, 255, 255) -- [FIX]
        btn.Size = UDim2.new(0.9, 0, 0, 30)
        btn.Position = UDim2.new(0.05, 0, 0, pos_y)
        btn.Font = Enum.Font.GothamBold
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(func)
        return btn
    end
    
    CreateBtn("PLAY (Iniciar Rota)", Color3.fromRGB(0, 180, 100), 40, function() TogglePlayback(true) end)
    CreateBtn("PAUSE (Parar)", Color3.fromRGB(200, 100, 0), 75, function() TogglePlayback(false) end)
    CreateBtn("LIMPAR PONTOS", Color3.fromRGB(180, 60, 60), 110, function() 
        Waypoints = {}; ClearVisuals(); RefreshList()
        LogarEvento("AVISO", "Todos os pontos removidos.")
    end)
    
    -- Lista
    local ListBg = Instance.new("Frame", Frame)
    ListBg.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    ListBg.Position = UDim2.new(0.05, 0, 0, 150)
    ListBg.Size = UDim2.new(0.9, 0, 0, 180)
    Instance.new("UICorner", ListBg).CornerRadius = UDim.new(0, 4)
    
    PointListScroll = Instance.new("ScrollingFrame", ListBg)
    PointListScroll.Size = UDim2.new(1, -5, 1, -5)
    PointListScroll.Position = UDim2.new(0, 5, 0, 5)
    PointListScroll.BackgroundTransparency = 1
    PointListScroll.ScrollBarThickness = 4
end

-- 6. FUNÇÃO DE ENTRADA (F5)
--========================================================================
local function TogglePathManager(state)
    PathSettings.Enabled = state
    if ScreenGui then ScreenGui.Enabled = state end
    
    if state then
        PathSettings.MouseLocked = false -- Inicia com mouse solto para editar
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    else
        PathSettings.IsPlaying = false
        if CurrentMoveTween then CurrentMoveTween:Cancel() end
        UserInputService.MouseIconEnabled = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        ClearVisuals() -- Limpa visuais ao fechar
    end
    
    LogarEvento("INFO", "Path Manager: " .. (state and "ATIVADO" or "DESATIVADO"))
end

-- 7. INPUTS E ATALHOS
--========================================================================

-- Loop para atualizar linhas 3D (Drawing API precisa ser redesenhado)
RunService.RenderStepped:Connect(function()
    if PathSettings.Enabled and #Waypoints > 0 then
        UpdateVisualPath()
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    -- F5: Toggle
    if input.KeyCode == Enum.KeyCode.F5 then
        TogglePathManager(not PathSettings.Enabled)
        if Chassi.Abas.Player and Chassi.Abas.Player:FindFirstChild("TogglePath") then
            Chassi.Abas.Player:FindFirstChild("TogglePath"):Set(PathSettings.Enabled)
        end
    end
    
    if not PathSettings.Enabled then return end
    if gp then return end
    
    -- Clique Direito: Adicionar Ponto
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        local mousePos = LocalPlayer:GetMouse().Hit.Position
        -- Raycast simples para chão (Snap)
        local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = {LocalPlayer.Character}
        local ray = Workspace:Raycast(mousePos + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), params)
        local pos = ray and ray.Position or mousePos
        
        table.insert(Waypoints, {CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))}) -- +3 altura
        RefreshList()
        LogarEvento("INFO", "Ponto adicionado.")
    end
    
    -- P: Alternar Mouse Lock
    if input.KeyCode == Enum.KeyCode.P then
        PathSettings.MouseLocked = not PathSettings.MouseLocked
        UserInputService.MouseBehavior = PathSettings.MouseLocked and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = not PathSettings.MouseLocked
    end
end)

-- 8. INICIALIZAÇÃO
--========================================================================
SetupPureUI()

if TabPlayer then
    pCreate("SecPath", TabPlayer, "CreateSection", "Path Recorder v1.1 (Colors Fix)", "Right")
    pCreate("TogglePath", TabPlayer, "CreateToggle", {
        Name = "Ativar Path Manager [F5]",
        CurrentValue = PathSettings.Enabled,
        Callback = TogglePathManager
    })
    
    pCreate("SliderSpeed", TabPlayer, "CreateSlider", {
        Name = "Velocidade Suave",
        Range = {10, 500}, Increment = 10, Suffix = " sps",
        CurrentValue = 50,
        Callback = function(Val) PathSettings.SmoothSpeed = Val end
    })
    
    pCreate("InfoPath", TabPlayer, "CreateLabel", "Botão Direito: Add Ponto | P: Mouse")

    LogarEvento("SUCESSO", "Módulo Path Recorder v1.1 carregado.")
else
    LogarEvento("ERRO", "TabPlayer não encontrada.")
end