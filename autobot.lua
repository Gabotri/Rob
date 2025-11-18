--[==[
    MÓDULO: Path Creator Pro v2.2 (Multi-Select & Beams)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [NOVO] Seleção 3D (Clique no ponto) + Multi-Select (Segure Ctrl).
    - [NOVO] Linhas 3D reais (Beams) em vez de riscos 2D.
    - [NOVO] Configuração Global (Fallback para Speed/Delay).
    - [NOVO] Contador visual de Delay durante playback.
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

-- Arquivo
local FileName = "Gabotri_Path_v2_" .. tostring(game.PlaceId) .. ".json"

-- 3. CONFIGURAÇÕES E ESTADO
local PathState = {
    Enabled = false,
    IsPlaying = false,
    Loop = false,
    ShowVisuals = true,
    
    -- Config Globais
    GlobalSpeed = 16,
    GlobalDelay = 0
}

local CurrentRoute = {}    
local SelectedIndices = {} -- Agora é uma tabela: {[index] = true}
local LastSelectedIndex = nil -- Para saber onde colocar o Gizmo

local VisualsFolder = nil  
local GizmoHandles = {}
local OriginalCFrames = {} -- Backup para mover múltiplos
local CurrentTween = nil

-- UI References
local ScreenGui, TimelineScroll, PropFrame, InpGlobalSpeed, InpGlobalDelay
local InpPointSpeed, InpPointDelay, InpPointType

-- 4. SISTEMA VISUAL 3D (BEAMS & SELEÇÃO)
--========================================================================
local function ClearVisuals()
    if VisualsFolder then VisualsFolder:Destroy() end
    VisualsFolder = Instance.new("Folder", Workspace)
    VisualsFolder.Name = "GabotriPathVisuals_v2.2"
end

local function UpdateVisuals()
    if not PathState.ShowVisuals then ClearVisuals(); return end
    if not VisualsFolder or not VisualsFolder.Parent then ClearVisuals() end
    
    -- Atualiza ou Cria Pontos
    for i, pt in ipairs(CurrentRoute) do
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
            
            -- Attachments para os Beams
            local att = Instance.new("Attachment", part)
            att.Name = "BeamAtt"
            
            -- Label (Nome)
            local bb = Instance.new("BillboardGui", part); bb.Size = UDim2.new(0,150,0,50); bb.StudsOffset = Vector3.new(0,2,0); bb.AlwaysOnTop = true
            local txt = Instance.new("TextLabel", bb); txt.Name="Label"; txt.Size=UDim2.new(1,0,1,0); txt.BackgroundTransparency=1; txt.TextColor3=Color3.new(1,1,1); txt.TextStrokeTransparency=0; txt.TextSize=12; txt.Font=Enum.Font.GothamBold
            
            -- Label (Delay Timer - Invisível por padrão)
            local bbT = Instance.new("BillboardGui", part); bbT.Name="TimerUI"; bbT.Size=UDim2.new(0,100,0,30); bbT.StudsOffset=Vector3.new(0,3.5,0); bbT.AlwaysOnTop=true; bbT.Enabled=false
            local txtT = Instance.new("TextLabel", bbT); txtT.Name="TimerLbl"; txtT.Size=UDim2.new(1,0,1,0); txtT.BackgroundTransparency=0.5; txtT.BackgroundColor3=Color3.new(0,0,0); txtT.TextColor3=Color3.new(1,1,0); txtT.TextSize=14; txtT.Font=Enum.Font.Code
        end
        
        part.CFrame = pt.cframe
        
        -- Cores e Texto
        local lbl = part.BillboardGui.Label
        local isSelected = SelectedIndices[i]
        
        if isSelected then
            part.Color = Color3.fromRGB(0, 255, 255) -- Ciano
            part.Size = Vector3.new(2, 2, 2)
            lbl.TextColor3 = Color3.fromRGB(0, 255, 255)
        else
            part.Color = pt.type == "Instant" and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)
            part.Size = Vector3.new(1.5, 1.5, 1.5)
            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
        
        -- Texto Inteligente (Mostra se usa global ou custom)
        local spdTxt = (pt.speed > 0) and tostring(pt.speed) or ("G("..PathState.GlobalSpeed..")")
        local dlyTxt = (pt.delay > 0) and tostring(pt.delay) or ("G("..PathState.GlobalDelay..")")
        lbl.Text = string.format("#%d [%s]\nSpd: %s | Dly: %s", i, pt.type, spdTxt, dlyTxt)
        
        -- Beams (Linhas 3D)
        if i < #CurrentRoute then
            local nextPartName = "Node_" .. (i+1)
            -- O próximo ponto pode ainda não ter sido criado no loop se for novo,
            -- mas no update seguinte ele aparece.
            -- Beam Logic:
            local beam = part:FindFirstChild("PathBeam")
            if not beam then
                beam = Instance.new("Beam", part)
                beam.Name = "PathBeam"
                beam.FaceCamera = true
                beam.Width0 = 0.5; beam.Width1 = 0.5
                beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
                beam.Transparency = NumberSequence.new(0.5)
                beam.Attachment0 = part.BeamAtt
            end
            
            -- Tenta achar o attachment do proximo (pode falhar se o proximo ainda nao renderizou neste frame)
            local nextPart = VisualsFolder:FindFirstChild(nextPartName)
            if nextPart and nextPart:FindFirstChild("BeamAtt") then
                beam.Attachment1 = nextPart.BeamAtt
                beam.Enabled = true
            else
                beam.Enabled = false
            end
        else
            -- Ultimo ponto nao tem beam saindo
            local b = part:FindFirstChild("PathBeam")
            if b then b:Destroy() end
        end
    end
    
    -- Limpeza de orfãos (se deletou pontos)
    for _, child in pairs(VisualsFolder:GetChildren()) do
        local idx = tonumber(child.Name:match("Node_(%d+)"))
        if idx and idx > #CurrentRoute then
            child:Destroy()
        end
    end
end

-- 5. SISTEMA DE GIZMO (MULTI-EDIT)
--========================================================================
local function ClearGizmos()
    for _, g in pairs(GizmoHandles) do g:Destroy() end
    GizmoHandles = {}
end

local function UpdateGizmo()
    ClearGizmos()
    if not PathState.Enabled or not LastSelectedIndex then return end
    
    local pt = CurrentRoute[LastSelectedIndex]
    local proxyPart = VisualsFolder:FindFirstChild("Node_"..LastSelectedIndex)
    if not proxyPart then return end 
    
    local moveHandles = Instance.new("Handles")
    moveHandles.Adornee = proxyPart
    moveHandles.Style = Enum.HandlesStyle.Resize
    moveHandles.Color3 = Color3.fromRGB(255, 200, 0)
    moveHandles.Parent = ScreenGui 
    
    moveHandles.MouseButton1Down:Connect(function()
        -- Salva posição original de TODOS os selecionados
        OriginalCFrames = {}
        for idx, _ in pairs(SelectedIndices) do
            if CurrentRoute[idx] then
                OriginalCFrames[idx] = CurrentRoute[idx].cframe
            end
        end
    end)
    
    moveHandles.MouseDrag:Connect(function(face, distance)
        local delta = distance 
        
        -- Vetor de movimento baseado na face do PRIMÁRIO (LastSelected)
        local baseCF = OriginalCFrames[LastSelectedIndex]
        if not baseCF then return end
        
        local moveVec = Vector3.new(0,0,0)
        if face == Enum.NormalId.Right then moveVec = baseCF.RightVector * delta
        elseif face == Enum.NormalId.Left then moveVec = baseCF.RightVector * -delta
        elseif face == Enum.NormalId.Top then moveVec = baseCF.UpVector * delta
        elseif face == Enum.NormalId.Bottom then moveVec = baseCF.UpVector * -delta
        elseif face == Enum.NormalId.Front then moveVec = baseCF.LookVector * delta
        elseif face == Enum.NormalId.Back then moveVec = baseCF.LookVector * -delta end
        
        -- Aplica o MESMO vetor para TODOS os selecionados
        for idx, _ in pairs(SelectedIndices) do
            if CurrentRoute[idx] and OriginalCFrames[idx] then
                CurrentRoute[idx].cframe = OriginalCFrames[idx] + moveVec
                -- Atualiza visual da parte correspondente
                local p = VisualsFolder:FindFirstChild("Node_"..idx)
                if p then p.CFrame = CurrentRoute[idx].cframe end
            end
        end
        
        UpdatePropertiesUI() -- Atualiza numeros
        -- UpdateVisuals() -- Pesado chamar full update no drag, o proxy update acima resolve visualmente
    end)
    
    table.insert(GizmoHandles, moveHandles)
end

-- 6. GERENCIAMENTO DE SELEÇÃO
--========================================================================
local function SelectPoint(index, multi)
    if not index then
        if not multi then SelectedIndices = {}; LastSelectedIndex = nil end
        UpdateVisuals(); UpdateGizmo(); UpdatePropertiesUI()
        return
    end
    
    if multi then
        if SelectedIndices[index] then
            SelectedIndices[index] = nil -- Desmarca
            if LastSelectedIndex == index then LastSelectedIndex = nil end -- Perdeu o gizmo
        else
            SelectedIndices[index] = true
            LastSelectedIndex = index -- O último clicado ganha o gizmo
        end
    else
        SelectedIndices = {[index] = true}
        LastSelectedIndex = index
    end
    
    UpdateVisuals()
    UpdateGizmo()
    UpdatePropertiesUI()
    -- Scroll to item na lista
end

-- 7. SISTEMA DE ARQUIVOS
--========================================================================
local function SaveRoute()
    local data = {
        GlobalSpeed = PathState.GlobalSpeed,
        GlobalDelay = PathState.GlobalDelay,
        Points = {}
    }
    for _, pt in ipairs(CurrentRoute) do
        local x, y, z = pt.cframe.X, pt.cframe.Y, pt.cframe.Z
        table.insert(data.Points, { x=x, y=y, z=z, t=pt.type, s=pt.speed, d=pt.delay })
    end
    pcall(function() writefile(FileName, HttpService:JSONEncode(data)) end)
    LogarEvento("SUCESSO", "Rota v2 salva.")
end

local function LoadRoute()
    if isfile(FileName) then
        local s, c = pcall(function() return readfile(FileName) end)
        if s then
            local data = HttpService:JSONDecode(c)
            
            -- Compatibilidade v2
            if data.Points then
                PathState.GlobalSpeed = data.GlobalSpeed or 16
                PathState.GlobalDelay = data.GlobalDelay or 0
                CurrentRoute = {}
                for _, d in ipairs(data.Points) do
                    table.insert(CurrentRoute, {
                        cframe = CFrame.new(d.x, d.y, d.z),
                        type = d.t or "Smooth",
                        speed = d.s or 0, -- 0 significa "Usar Global"
                        delay = d.d or 0
                    })
                end
            else
                -- Tenta carregar formato antigo (Array direta)
                CurrentRoute = {}
                for _, d in ipairs(data) do
                    table.insert(CurrentRoute, { cframe = CFrame.new(d.x, d.y, d.z), type = d.type or "Smooth", speed = d.speed or 0, delay = d.delay or 0 })
                end
            end
            LogarEvento("INFO", "Rota carregada.")
        end
    end
    UpdateVisuals()
    RefreshTimeline()
    UpdatePropertiesUI()
end

-- 8. UI PURA
--========================================================================
ScreenGui = Instance.new("ScreenGui", CoreGui); ScreenGui.Name = "PathCreatorUI_v2.2"; ScreenGui.Enabled = false

-- Main Frame
local MainFrame = Instance.new("Frame", ScreenGui); MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35); MainFrame.Position = UDim2.new(0.65, 0, 0.2, 0); MainFrame.Size = UDim2.new(0, 380, 0, 500); MainFrame.Active = true; MainFrame.Draggable = true; Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
-- Header
local Header = Instance.new("Frame", MainFrame); Header.Size=UDim2.new(1,0,0,30); Header.BackgroundColor3=Color3.fromRGB(40,40,45); Instance.new("UICorner", Header).CornerRadius=UDim.new(0,8)
local Title = Instance.new("TextLabel", Header); Title.Text="  Path Pro v2.2 [F5]"; Title.Size=UDim2.new(1,-30,1,0); Title.BackgroundTransparency=1; Title.TextColor3=Color3.fromRGB(255,255,255); Title.Font=Enum.Font.GothamBold; Title.TextXAlignment=Enum.TextXAlignment.Left
local Close = Instance.new("TextButton", Header); Close.Text="X"; Close.Size=UDim2.new(0,30,1,0); Close.Position=UDim2.new(1,-30,0,0); Close.BackgroundTransparency=1; Close.TextColor3=Color3.fromRGB(255,80,80); Close.Font=Enum.Font.GothamBold
Close.MouseButton1Click:Connect(function() PathState.Enabled = false; ScreenGui.Enabled = false; UpdateGizmo() end)

-- Configs Globais (Topo)
local Globals = Instance.new("Frame", MainFrame); Globals.Position=UDim2.new(0,5,0,35); Globals.Size=UDim2.new(1,-10,0,35); Globals.BackgroundTransparency=1
local function MakeInput(parent, ph, x, w, callback)
    local b = Instance.new("TextBox", parent); b.PlaceholderText=ph; b.Text=""; b.Size=UDim2.new(w,0,1,0); b.Position=UDim2.new(x,0,0,0); b.BackgroundColor3=Color3.fromRGB(50,50,55); b.TextColor3=Color3.white; Instance.new("UICorner", b).CornerRadius=UDim.new(0,4)
    b.FocusLost:Connect(function() callback(b.Text) end)
    return b
end
InpGlobalSpeed = MakeInput(Globals, "Global Spd", 0, 0.3, function(t) PathState.GlobalSpeed = tonumber(t) or 16; UpdateVisuals() end)
InpGlobalDelay = MakeInput(Globals, "Global Dly", 0.32, 0.3, function(t) PathState.GlobalDelay = tonumber(t) or 0; UpdateVisuals() end)
local BtnLoop = Instance.new("TextButton", Globals); BtnLoop.Text="Loop: OFF"; BtnLoop.Size=UDim2.new(0.35,0,1,0); BtnLoop.Position=UDim2.new(0.65,0,0,0); BtnLoop.BackgroundColor3=Color3.fromRGB(60,60,60); BtnLoop.TextColor3=Color3.white; Instance.new("UICorner", BtnLoop).CornerRadius=UDim.new(0,4)
BtnLoop.MouseButton1Click:Connect(function() PathState.Loop=not PathState.Loop; BtnLoop.Text=PathState.Loop and "Loop: ON" or "Loop: OFF"; BtnLoop.BackgroundColor3=PathState.Loop and Color3.fromRGB(0,120,200) or Color3.fromRGB(60,60,60) end)

-- Playback
local PlayFrame = Instance.new("Frame", MainFrame); PlayFrame.Position=UDim2.new(0,5,0,75); PlayFrame.Size=UDim2.new(1,-10,0,30); PlayFrame.BackgroundTransparency=1
local function MakeBtn(parent, text, col, x, w, func)
    local b = Instance.new("TextButton", parent); b.Text=text; b.BackgroundColor3=col; b.TextColor3=Color3.white; b.Size=UDim2.new(w,0,1,0); b.Position=UDim2.new(x,0,0,0); b.Font=Enum.Font.GothamBold; Instance.new("UICorner", b).CornerRadius=UDim.new(0,4); b.MouseButton1Click:Connect(func); return b
end
MakeBtn(PlayFrame, "PLAY", Color3.fromRGB(0,180,100), 0, 0.3, function() TogglePlayback(true) end)
MakeBtn(PlayFrame, "STOP", Color3.fromRGB(200,60,60), 0.32, 0.3, function() TogglePlayback(false) end)
MakeBtn(PlayFrame, "SALVAR", Color3.fromRGB(255,150,0), 0.65, 0.35, SaveRoute)

-- Split View
local Split = Instance.new("Frame", MainFrame); Split.Position=UDim2.new(0,5,0,110); Split.Size=UDim2.new(1,-10,1,-115); Split.BackgroundTransparency=1
-- Lista (Timeline)
local Left = Instance.new("ScrollingFrame", Split); Left.Size=UDim2.new(0.4,0,1,0); Left.BackgroundColor3=Color3.fromRGB(25,25,30); Left.ScrollBarThickness=3; Instance.new("UICorner", Left).CornerRadius=UDim.new(0,4)
local LeftLayout = Instance.new("UIListLayout", Left); LeftLayout.Padding=UDim.new(0,2)

-- Propriedades
local Right = Instance.new("Frame", Split); Right.Size=UDim2.new(0.58,0,1,0); Right.Position=UDim2.new(0.42,0,0,0); Right.BackgroundColor3=Color3.fromRGB(25,25,30); Instance.new("UICorner", Right).CornerRadius=UDim.new(0,4)
local LblSel = Instance.new("TextLabel", Right); LblSel.Text="Seleção: Nenhuma"; LblSel.Size=UDim2.new(1,0,0,20); LblSel.TextColor3=Color3.fromRGB(200,200,200); LblSel.BackgroundTransparency=1
InpPointType = MakeInput(Right, "Type (Smooth/Instant)", 0, 1, function(t) for k,_ in pairs(SelectedIndices) do if CurrentRoute[k] then CurrentRoute[k].type=t end end UpdateVisuals() end); InpPointType.Position=UDim2.new(0,0,0,25)
InpPointSpeed = MakeInput(Right, "Custom Speed (0=Global)", 0, 1, function(t) local v=tonumber(t); if v then for k,_ in pairs(SelectedIndices) do CurrentRoute[k].speed=v end UpdateVisuals() end end); InpPointSpeed.Position=UDim2.new(0,0,0,60)
InpPointDelay = MakeInput(Right, "Custom Delay (0=Global)", 0, 1, function(t) local v=tonumber(t); if v then for k,_ in pairs(SelectedIndices) do CurrentRoute[k].delay=v end UpdateVisuals() end end); InpPointDelay.Position=UDim2.new(0,0,0,95)
MakeBtn(Right, "Mover para Mim (T)", Color3.fromRGB(0,100,180), 0, 1, function() 
    local h = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if h and LastSelectedIndex then CurrentRoute[LastSelectedIndex].cframe = h.CFrame; UpdateVisuals(); UpdateGizmo() end
end).Position = UDim2.new(0,0,0,140)
MakeBtn(Right, "DELETAR PONTOS", Color3.fromRGB(180,40,40), 0, 1, function()
    -- Deletar requer reordenação, complexo com índices. Vamos fazer reverso.
    local toDel = {}
    for k,_ in pairs(SelectedIndices) do table.insert(toDel, k) end
    table.sort(toDel, function(a,b) return a > b end) -- Maior pro menor
    for _, idx in ipairs(toDel) do table.remove(CurrentRoute, idx) end
    SelectedIndices = {}; LastSelectedIndex = nil
    RefreshTimeline(); UpdateVisuals(); UpdateGizmo(); UpdatePropertiesUI()
end).Position = UDim2.new(0,0,0,180)

-- Lógica UI
function RefreshTimeline()
    for _, c in pairs(Left:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for i, pt in ipairs(CurrentRoute) do
        local Row = Instance.new("Frame", Left); Row.Size=UDim2.new(1,0,0,25); Row.BackgroundColor3 = SelectedIndices[i] and Color3.fromRGB(0,100,150) or Color3.fromRGB(40,40,45)
        local Btn = Instance.new("TextButton", Row); Btn.Size=UDim2.new(1,0,1,0); Btn.BackgroundTransparency=1; Btn.Text=" Pt "..i.." ("..pt.type..")"; Btn.TextColor3=Color3.white; Btn.TextXAlignment=Enum.TextXAlignment.Left
        Btn.MouseButton1Click:Connect(function()
            local multi = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            SelectPoint(i, multi)
        end)
    end
    Left.CanvasSize = UDim2.new(0,0,0, #CurrentRoute * 27)
end

function UpdatePropertiesUI()
    -- Atualiza inputs globais
    InpGlobalSpeed.Text = tostring(PathState.GlobalSpeed)
    InpGlobalDelay.Text = tostring(PathState.GlobalDelay)
    
    -- Atualiza inputs de seleção
    local count = 0; for _ in pairs(SelectedIndices) do count=count+1 end
    if count == 0 then
        LblSel.Text = "Nenhum selecionado"; InpPointType.Text=""; InpPointSpeed.Text=""; InpPointDelay.Text=""
    elseif count == 1 and LastSelectedIndex and CurrentRoute[LastSelectedIndex] then
        local pt = CurrentRoute[LastSelectedIndex]
        LblSel.Text = "Editando Ponto #"..LastSelectedIndex
        InpPointType.Text = pt.type
        InpPointSpeed.Text = tostring(pt.speed)
        InpPointDelay.Text = tostring(pt.delay)
    else
        LblSel.Text = "Editando "..count.." pontos (Multi)"
        InpPointType.Text = "(Vários)"; InpPointSpeed.Text = "(Vários)"; InpPointDelay.Text = "(Vários)"
    end
    RefreshTimeline() -- Atualiza cores da lista
end

-- 9. PLAYBACK
function TogglePlayback(state)
    PathState.IsPlaying = state
    if not state then if CurrentTween then CurrentTween:Cancel() end return end
    
    task.spawn(function()
        while PathState.IsPlaying do
            for i, pt in ipairs(CurrentRoute) do
                if not PathState.IsPlaying then break end
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then break end
                
                -- Resolve Speed/Delay (Global fallback)
                local speed = (pt.speed > 0) and pt.speed or PathState.GlobalSpeed
                local delay = (pt.delay > 0) and pt.delay or PathState.GlobalDelay
                
                if pt.type == "Instant" then
                    hrp.CFrame = pt.cframe
                else
                    local dist = (pt.cframe.Position - hrp.Position).Magnitude
                    local time = dist / math.max(1, speed)
                    local ti = TweenInfo.new(time, Enum.EasingStyle.Linear)
                    CurrentTween = TweenService:Create(hrp, ti, {CFrame = pt.cframe})
                    CurrentTween:Play()
                    CurrentTween.Completed:Wait()
                end
                
                -- Delay com Visualizador
                if delay > 0 then
                    local part = VisualsFolder:FindFirstChild("Node_"..i)
                    local timerUI = part and part:FindFirstChild("TimerUI")
                    local timerLbl = timerUI and timerUI.TimerLbl
                    
                    if timerUI then timerUI.Enabled = true end
                    
                    local start = tick()
                    while tick() - start < delay do
                        if not PathState.IsPlaying then break end
                        local remaining = delay - (tick() - start)
                        if timerLbl then timerLbl.Text = string.format("Wait: %.1fs", remaining) end
                        RunService.Heartbeat:Wait()
                    end
                    
                    if timerUI then timerUI.Enabled = false end
                end
            end
            if not PathState.Loop then PathState.IsPlaying = false end
        end
    end)
end

-- 10. INPUTS E SELEÇÃO 3D
UserInputService.InputBegan:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.F5 then
        PathState.Enabled = not PathState.Enabled
        ScreenGui.Enabled = PathState.Enabled
        UpdateVisuals(); UpdateGizmo()
        if Chassi.Abas.Mundo and Chassi.Abas.Mundo:FindFirstChild("TogglePathCreator") then Chassi.Abas.Mundo:FindFirstChild("TogglePathCreator"):Set(PathState.Enabled) end
    end
    
    if not PathState.Enabled then return end
    
    -- T: Add Ponto
    if input.KeyCode == Enum.KeyCode.T and not gp then
        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(CurrentRoute, {
                cframe = Player.Character.HumanoidRootPart.CFrame,
                type = "Smooth", speed = 0, delay = 0
            })
            SelectPoint(#CurrentRoute, false)
        end
    end
    
    -- Clique 3D (Raycast)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not gp then
        local mouseRay = Mouse.UnitRay
        local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Include
        if VisualsFolder then params.FilterDescendantsInstances = {VisualsFolder} end
        
        local res = Workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, params)
        if res and res.Instance then
            local idx = tonumber(res.Instance.Name:match("Node_(%d+)"))
            if idx then
                local multi = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                SelectPoint(idx, multi)
            end
        else
            -- Se clicou no vazio e não tem Ctrl, desmarca
            if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then SelectPoint(nil) end
        end
    end
end)

-- 11. START
if TabMundo then
    pCreate("SecPathPro", TabMundo, "CreateSection", "Path Creator v2.2", "Right")
    pCreate("TogglePathCreator", TabMundo, "CreateToggle", {
        Name = "Abrir Editor [F5]", CurrentValue = false,
        Callback = function(v) PathState.Enabled = v; ScreenGui.Enabled = v; UpdateVisuals(); UpdateGizmo() end
    })
end

LoadRoute()
LogarEvento("SUCESSO", "Módulo Path Creator v2.2 (Multi-Select) carregado.")