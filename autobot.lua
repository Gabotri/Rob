--[==[
    MÓDULO: Path Creator Pro v2.0 (Native Gizmo & Pure UI)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - Editor de Rotas Completo com UI Pura.
    - Gizmo 3D (Move/Rotate) para ajustes finos.
    - Timeline, Propriedades e Playback.
    - Atalho F5.
]==]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO PATH: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. SERVIÇOS
local LogarEvento = Chassi.LogarEvento
local pCreate = Chassi.pCreate
local TabMundo = Chassi.Abas.Mundo

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Camera = Workspace.CurrentCamera

-- Arquivo de Save
local FileName = "Gabotri_Path_v2_" .. tostring(game.PlaceId) .. ".json"

-- 3. CONFIGURAÇÕES E ESTADO
local PathState = {
    Enabled = false,       -- Modo Editor Ativo
    IsPlaying = false,     -- Executando Rota
    Loop = false,          -- Loop Infinito
    ShowVisuals = true,    -- Mostrar Linhas/Pontos
    DefaultSpeed = 16,     -- Velocidade padrão ao criar
    DefaultDelay = 0       -- Delay padrão
}

local CurrentRoute = {}    -- Lista de Pontos {cframe, type, speed, delay, action}
local SelectedIndex = nil  -- Índice do ponto selecionado
local VisualsFolder = nil  -- Pasta de peças visuais
local LinesDrawing = {}    -- Linhas (Drawing API)

-- Variáveis Gizmo
local GizmoHandles = {}
local OriginalCFrame = CFrame.new()

-- Variáveis Playback
local CurrentTween = nil
local PlaybackCoroutine = nil

-- UI References
local ScreenGui, TimelineScroll, PropFrame

-- 4. SISTEMA VISUAL 3D
--========================================================================
local function ClearVisuals()
    if VisualsFolder then VisualsFolder:Destroy() end
    VisualsFolder = Instance.new("Folder", Workspace)
    VisualsFolder.Name = "GabotriPathVisuals"
    
    for _, line in pairs(LinesDrawing) do line:Remove() end
    LinesDrawing = {}
end

local function UpdateVisuals()
    if not PathState.ShowVisuals then ClearVisuals(); return end
    
    -- Garante pasta
    if not VisualsFolder or not VisualsFolder.Parent then 
        ClearVisuals() 
    end
    
    -- Limpa linhas antigas para redesenhar
    for _, line in pairs(LinesDrawing) do line:Remove() end
    LinesDrawing = {}

    for i, pt in ipairs(CurrentRoute) do
        -- 1. Cria/Atualiza Ponto Físico (Esfera)
        local partName = "Node_" .. i
        local part = VisualsFolder:FindFirstChild(partName)
        
        if not part then
            part = Instance.new("Part")
            part.Name = partName
            part.Shape = Enum.PartType.Ball
            part.Size = Vector3.new(1.5, 1.5, 1.5)
            part.Anchored = true; part.CanCollide = false
            part.Material = Enum.Material.Neon
            part.Parent = VisualsFolder
        end
        
        part.CFrame = pt.cframe
        
        -- Cor baseada na seleção e tipo
        if i == SelectedIndex then
            part.Color = Color3.fromRGB(0, 255, 255) -- Ciano (Selecionado)
            part.Size = Vector3.new(2, 2, 2)
        else
            if pt.type == "Instant" then
                part.Color = Color3.fromRGB(255, 50, 50) -- Vermelho (Instant)
            else
                part.Color = Color3.fromRGB(50, 255, 50) -- Verde (Smooth)
            end
            part.Size = Vector3.new(1.5, 1.5, 1.5)
        end
        
        -- 2. Desenha Linha para o próximo
        if i < #CurrentRoute then
            local nextPt = CurrentRoute[i+1]
            local vecA, visA = Camera:WorldToViewportPoint(pt.cframe.Position)
            local vecB, visB = Camera:WorldToViewportPoint(nextPt.cframe.Position)
            
            if visA and visB then
                local line = Drawing.new("Line")
                line.Visible = true
                line.From = Vector2.new(vecA.X, vecA.Y)
                line.To = Vector2.new(vecB.X, vecB.Y)
                line.Color = Color3.fromRGB(255, 255, 255)
                line.Thickness = 1.5
                line.Transparency = 0.5
                table.insert(LinesDrawing, line)
            end
        end
    end
end

-- 5. SISTEMA DE GIZMO (HANDLES)
--========================================================================
local function ClearGizmos()
    for _, g in pairs(GizmoHandles) do g:Destroy() end
    GizmoHandles = {}
end

local function UpdateGizmo()
    ClearGizmos()
    if not PathState.Enabled or not SelectedIndex or not CurrentRoute[SelectedIndex] then return end
    
    local pt = CurrentRoute[SelectedIndex]
    -- Usamos uma Part temporária invisível para ancorar os Handles, 
    -- pois Handles precisam de um Adornee físico.
    local proxyPart = VisualsFolder:FindFirstChild("Node_"..SelectedIndex)
    if not proxyPart then return end -- Visuals devem estar ativos
    
    -- MOVE HANDLES
    local moveHandles = Instance.new("Handles")
    moveHandles.Adornee = proxyPart
    moveHandles.Style = Enum.HandlesStyle.Resize
    moveHandles.Color3 = Color3.fromRGB(255, 200, 0)
    moveHandles.Parent = ScreenGui -- Parent na UI para segurança
    
    moveHandles.MouseButton1Down:Connect(function()
        OriginalCFrame = pt.cframe
    end)
    
    moveHandles.MouseDrag:Connect(function(face, distance)
        local cf = OriginalCFrame
        local delta = distance 
        -- (Poderia adicionar snapping aqui se quisesse, mas vamos deixar livre para precisão)
        
        if face == Enum.NormalId.Right then pt.cframe = cf + (cf.RightVector * delta)
        elseif face == Enum.NormalId.Left then pt.cframe = cf - (cf.RightVector * delta)
        elseif face == Enum.NormalId.Top then pt.cframe = cf + (cf.UpVector * delta)
        elseif face == Enum.NormalId.Bottom then pt.cframe = cf - (cf.UpVector * delta)
        elseif face == Enum.NormalId.Front then pt.cframe = cf + (cf.LookVector * delta)
        elseif face == Enum.NormalId.Back then pt.cframe = cf - (cf.LookVector * delta) end
        
        -- Atualiza visual em tempo real
        proxyPart.CFrame = pt.cframe 
        UpdatePropertiesUI() -- Atualiza números na tela
    end)
    
    -- ROTATE HANDLES
    local rotHandles = Instance.new("ArcHandles")
    rotHandles.Adornee = proxyPart
    rotHandles.Parent = ScreenGui
    
    rotHandles.MouseButton1Down:Connect(function()
        OriginalCFrame = pt.cframe
    end)
    
    rotHandles.MouseDrag:Connect(function(axis, angle)
        local cf = OriginalCFrame
        if axis == Enum.Axis.X then pt.cframe = cf * CFrame.Angles(angle, 0, 0)
        elseif axis == Enum.Axis.Y then pt.cframe = cf * CFrame.Angles(0, angle, 0)
        elseif axis == Enum.Axis.Z then pt.cframe = cf * CFrame.Angles(0, 0, angle) end
        
        proxyPart.CFrame = pt.cframe
        UpdatePropertiesUI()
    end)
    
    table.insert(GizmoHandles, moveHandles)
    table.insert(GizmoHandles, rotHandles)
end

-- 6. SISTEMA DE ARQUIVOS
--========================================================================
local function SaveRoute()
    local data = {}
    for _, pt in ipairs(CurrentRoute) do
        -- Serializa CFrame
        local x, y, z = pt.cframe.X, pt.cframe.Y, pt.cframe.Z
        local rx, ry, rz = pt.cframe:ToEulerAnglesYXZ()
        table.insert(data, {
            x=x, y=y, z=z, rx=rx, ry=ry, rz=rz,
            type=pt.type, speed=pt.speed, delay=pt.delay
        })
    end
    pcall(function() writefile(FileName, HttpService:JSONEncode(data)) end)
    LogarEvento("SUCESSO", "Rota salva em JSON.")
end

local function LoadRoute()
    if isfile(FileName) then
        local s, c = pcall(function() return readfile(FileName) end)
        if s then
            local data = HttpService:JSONDecode(c)
            CurrentRoute = {}
            for _, d in ipairs(data) do
                local cf = CFrame.new(d.x, d.y, d.z) * CFrame.fromEulerAnglesYXZ(d.rx, d.ry, d.rz)
                table.insert(CurrentRoute, {
                    cframe = cf,
                    type = d.type or "Smooth",
                    speed = d.speed or 16,
                    delay = d.delay or 0
                })
            end
            LogarEvento("INFO", "Rota carregada: " .. #CurrentRoute .. " pontos.")
        end
    end
    UpdateVisuals()
    RefreshTimeline()
end

-- 7. UI PURA (EDITOR & PROPERTIES)
--========================================================================
ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PathCreatorUI_v2"
ScreenGui.Parent = CoreGui
ScreenGui.Enabled = false

-- --- CONTAINER PRINCIPAL ---
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.Position = UDim2.new(0.65, 0, 0.2, 0)
MainFrame.Size = UDim2.new(0, 350, 0, 450)
MainFrame.Active = true; MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

-- Header
local Header = Instance.new("Frame", MainFrame); Header.Size=UDim2.new(1,0,0,30); Header.BackgroundColor3=Color3.fromRGB(40,40,45); Instance.new("UICorner", Header).CornerRadius=UDim.new(0,8)
local Title = Instance.new("TextLabel", Header); Title.Text="  Path Creator v2.0 [F5]"; Title.Size=UDim2.new(1,-30,1,0); Title.BackgroundTransparency=1; Title.TextColor3=Color3.fromRGB(255,255,255); Title.Font=Enum.Font.GothamBold; Title.TextXAlignment=Enum.TextXAlignment.Left
local Close = Instance.new("TextButton", Header); Close.Text="X"; Close.Size=UDim2.new(0,30,1,0); Close.Position=UDim2.new(1,-30,0,0); Close.BackgroundTransparency=1; Close.TextColor3=Color3.fromRGB(255,80,80); Close.Font=Enum.Font.GothamBold
Close.MouseButton1Click:Connect(function() PathState.Enabled = false; ScreenGui.Enabled = false; UpdateGizmo() end)

-- --- ÁREA DE PLAYBACK (TOPO) ---
local PlayFrame = Instance.new("Frame", MainFrame); PlayFrame.Position=UDim2.new(0,5,0,35); PlayFrame.Size=UDim2.new(1,-10,0,40); PlayFrame.BackgroundTransparency=1
local LayoutPlay = Instance.new("UIListLayout", PlayFrame); LayoutPlay.FillDirection=Enum.FillDirection.Horizontal; LayoutPlay.Padding=UDim.new(0,5)

local function MakeBtn(parent, text, col, func)
    local b = Instance.new("TextButton", parent); b.Text=text; b.BackgroundColor3=col; b.TextColor3=Color3.fromRGB(255,255,255); b.Size=UDim2.new(0,70,1,0); b.Font=Enum.Font.GothamBold; Instance.new("UICorner", b).CornerRadius=UDim.new(0,4)
    b.MouseButton1Click:Connect(func); return b
end

MakeBtn(PlayFrame, "PLAY", Color3.fromRGB(0,180,100), function() TogglePlayback(true) end)
MakeBtn(PlayFrame, "STOP", Color3.fromRGB(200,60,60), function() TogglePlayback(false) end)
local BtnLoop = MakeBtn(PlayFrame, "Loop: OFF", Color3.fromRGB(60,60,60), function() 
    PathState.Loop = not PathState.Loop
    -- Atualiza texto do botão (precisa de referencia, mas faremos inline pra simplificar)
end)
-- Helper pra atualizar loop button
RunService.Heartbeat:Connect(function() BtnLoop.Text = PathState.Loop and "Loop: ON" or "Loop: OFF"; BtnLoop.BackgroundColor3 = PathState.Loop and Color3.fromRGB(0,120,200) or Color3.fromRGB(60,60,60) end)

local BtnSave = MakeBtn(PlayFrame, "SALVAR", Color3.fromRGB(255,150,0), SaveRoute)
BtnSave.Size = UDim2.new(0, 80, 1, 0) -- Maior

-- --- DIVISOR (TIMELINE | PROPERTIES) ---
local SplitContainer = Instance.new("Frame", MainFrame); SplitContainer.Position=UDim2.new(0,5,0,80); SplitContainer.Size=UDim2.new(1,-10,1,-85); SplitContainer.BackgroundTransparency=1

-- ESQUERDA: TIMELINE LIST
local LeftPanel = Instance.new("Frame", SplitContainer); LeftPanel.Size=UDim2.new(0.4,0,1,0); LeftPanel.BackgroundColor3=Color3.fromRGB(25,25,30); Instance.new("UICorner", LeftPanel).CornerRadius=UDim.new(0,4)
TimelineScroll = Instance.new("ScrollingFrame", LeftPanel); TimelineScroll.Size=UDim2.new(1,-4,1,-4); TimelineScroll.Position=UDim2.new(0,2,0,2); TimelineScroll.BackgroundTransparency=1; TimelineScroll.ScrollBarThickness=3
local ListLayout = Instance.new("UIListLayout", TimelineScroll); ListLayout.Padding=UDim.new(0,2)

-- DIREITA: PROPRIEDADES
PropFrame = Instance.new("Frame", SplitContainer); PropFrame.Size=UDim2.new(0.58,0,1,0); PropFrame.Position=UDim2.new(0.42,0,0,0); PropFrame.BackgroundColor3=Color3.fromRGB(25,25,30); Instance.new("UICorner", PropFrame).CornerRadius=UDim.new(0,4)

-- Inputs de Propriedades
local PropLayout = Instance.new("UIListLayout", PropFrame); PropLayout.Padding=UDim.new(0,5); PropLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
local PropPad = Instance.new("UIPadding", PropFrame); PropPad.PaddingTop=UDim.new(0,5)

local LblInfo = Instance.new("TextLabel", PropFrame); LblInfo.Size=UDim2.new(1,0,0,20); LblInfo.BackgroundTransparency=1; LblInfo.TextColor3=Color3.fromRGB(200,200,200); LblInfo.Text="Nenhum ponto selecionado"

local function MakePropInput(ph)
    local b = Instance.new("TextBox", PropFrame); b.Size=UDim2.new(0.9,0,0,25); b.PlaceholderText=ph; b.BackgroundColor3=Color3.fromRGB(45,45,50); b.TextColor3=Color3.fromRGB(255,255,255); Instance.new("UICorner", b).CornerRadius=UDim.new(0,4)
    return b
end

local InpType = MakePropInput("Type (Smooth/Instant)") -- Simplificado para texto por enquanto
local InpSpeed = MakePropInput("Speed")
local InpDelay = MakePropInput("Delay (s)")
local BtnMoveHere = Instance.new("TextButton", PropFrame); BtnMoveHere.Text="Mover para Mim"; BtnMoveHere.Size=UDim2.new(0.9,0,0,25); BtnMoveHere.BackgroundColor3=Color3.fromRGB(0,100,180); BtnMoveHere.TextColor3=Color3.fromRGB(255,255,255); Instance.new("UICorner", BtnMoveHere).CornerRadius=UDim.new(0,4)
local BtnDelete = Instance.new("TextButton", PropFrame); BtnDelete.Text="DELETAR PONTO"; BtnDelete.Size=UDim2.new(0.9,0,0,25); BtnDelete.BackgroundColor3=Color3.fromRGB(180,40,40); BtnDelete.TextColor3=Color3.fromRGB(255,255,255); Instance.new("UICorner", BtnDelete).CornerRadius=UDim.new(0,4)

-- Lógica de Atualização da Timeline
function RefreshTimeline()
    for _, c in pairs(TimelineScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    
    for i, pt in ipairs(CurrentRoute) do
        local Row = Instance.new("Frame", TimelineScroll); Row.Size=UDim2.new(1,0,0,25); Row.BackgroundColor3 = (i==SelectedIndex) and Color3.fromRGB(0,100,150) or Color3.fromRGB(40,40,45)
        local Btn = Instance.new("TextButton", Row); Btn.Size=UDim2.new(1,0,1,0); Btn.BackgroundTransparency=1; Btn.Text=" Ponto "..i; Btn.TextColor3=Color3.fromRGB(255,255,255); Btn.TextXAlignment=Enum.TextXAlignment.Left
        
        Btn.MouseButton1Click:Connect(function()
            SelectedIndex = i
            UpdateGizmo()
            UpdateVisuals()
            RefreshTimeline() -- Atualiza highlight
            UpdatePropertiesUI()
        end)
    end
    TimelineScroll.CanvasSize = UDim2.new(0,0,0, #CurrentRoute * 27)
end

-- Lógica de Atualização de Propriedades UI -> Dados
function UpdatePropertiesUI()
    if not SelectedIndex or not CurrentRoute[SelectedIndex] then
        LblInfo.Text = "Nenhum ponto selecionado"
        InpType.Text=""; InpSpeed.Text=""; InpDelay.Text=""
        return 
    end
    
    local pt = CurrentRoute[SelectedIndex]
    LblInfo.Text = "Editando Ponto #" .. SelectedIndex
    InpType.Text = pt.type
    InpSpeed.Text = tostring(pt.speed)
    InpDelay.Text = tostring(pt.delay)
end

-- Inputs Logic
InpType.FocusLost:Connect(function() if SelectedIndex then CurrentRoute[SelectedIndex].type = InpType.Text; UpdateVisuals() end end)
InpSpeed.FocusLost:Connect(function() if SelectedIndex then CurrentRoute[SelectedIndex].speed = tonumber(InpSpeed.Text) or 16 end end)
InpDelay.FocusLost:Connect(function() if SelectedIndex then CurrentRoute[SelectedIndex].delay = tonumber(InpDelay.Text) or 0 end end)

BtnMoveHere.MouseButton1Click:Connect(function()
    if SelectedIndex and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        CurrentRoute[SelectedIndex].cframe = Player.Character.HumanoidRootPart.CFrame
        UpdateVisuals()
        UpdateGizmo()
    end
end)

BtnDelete.MouseButton1Click:Connect(function()
    if SelectedIndex then
        table.remove(CurrentRoute, SelectedIndex)
        SelectedIndex = nil
        ClearGizmos()
        RefreshTimeline()
        UpdateVisuals()
        UpdatePropertiesUI()
    end
end)

-- 8. PLAYBACK SYSTEM
--========================================================================
function TogglePlayback(state)
    PathState.IsPlaying = state
    
    if not state then
        if CurrentTween then CurrentTween:Cancel() end
        return
    end
    
    -- Loop de Playback
    task.spawn(function()
        while PathState.IsPlaying do
            for i, pt in ipairs(CurrentRoute) do
                if not PathState.IsPlaying then break end
                
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then break end
                
                -- Lógica do Tipo de Ponto
                if pt.type == "Instant" then
                    hrp.CFrame = pt.cframe
                    task.wait(pt.delay)
                else
                    -- Smooth
                    local dist = (pt.cframe.Position - hrp.Position).Magnitude
                    local speed = math.max(1, pt.speed)
                    local time = dist / speed
                    
                    local ti = TweenInfo.new(time, Enum.EasingStyle.Linear)
                    CurrentTween = TweenService:Create(hrp, ti, {CFrame = pt.cframe})
                    CurrentTween:Play()
                    CurrentTween.Completed:Wait()
                    task.wait(pt.delay)
                end
            end
            
            if not PathState.Loop then PathState.IsPlaying = false end
        end
    end)
end

-- 9. INPUTS E ATALHOS
--========================================================================
UserInputService.InputBegan:Connect(function(input, gp)
    -- F5: Toggle
    if input.KeyCode == Enum.KeyCode.F5 then
        PathState.Enabled = not PathState.Enabled
        ScreenGui.Enabled = PathState.Enabled
        UpdateVisuals()
        UpdateGizmo()
        
        if Chassi.Abas.Mundo and Chassi.Abas.Mundo:FindFirstChild("TogglePathCreator") then
            Chassi.Abas.Mundo:FindFirstChild("TogglePathCreator"):Set(PathState.Enabled)
        end
    end
    
    if not PathState.Enabled then return end
    if gp then return end
    
    -- Right Click: Add Point
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        local hit = Mouse.Hit
        -- Cria ponto
        table.insert(CurrentRoute, {
            cframe = hit + Vector3.new(0, 3, 0),
            type = "Smooth",
            speed = PathState.DefaultSpeed,
            delay = PathState.DefaultDelay
        })
        
        SelectedIndex = #CurrentRoute -- Seleciona o novo
        UpdateVisuals()
        RefreshTimeline()
        UpdateGizmo()
        UpdatePropertiesUI()
        LogarEvento("INFO", "Ponto adicionado.")
    end
end)

-- Render Loop para desenhar linhas dinamicamente
RunService.RenderStepped:Connect(function()
    if PathState.Enabled or PathState.IsPlaying then
        -- Atualiza linhas se os pontos moverem (pelo gizmo)
        -- Para otimizar, poderíamos checar "IsDragging", mas update constante é mais seguro visualmente
        UpdateVisuals()
    end
end)

-- 10. INTEGRAÇÃO
--========================================================================
if TabMundo then
    pCreate("SecPathPro", TabMundo, "CreateSection", "Path Creator Pro v2.0", "Right")
    pCreate("TogglePathCreator", TabMundo, "CreateToggle", {
        Name = "Abrir Editor [F5]", CurrentValue = false,
        Callback = function(v) PathState.Enabled = v; ScreenGui.Enabled = v; UpdateVisuals(); UpdateGizmo() end
    })
    pCreate("BtnClearPath", TabMundo, "CreateButton", {
        Name = "Limpar Toda Rota",
        Callback = function() CurrentRoute={}; SelectedIndex=nil; ClearVisuals(); ClearGizmos(); RefreshTimeline(); UpdatePropertiesUI() end
    })
end

LoadRoute()
LogarEvento("SUCESSO", "Módulo Path Creator v2.0 (Pure UI & Gizmo) carregado.")