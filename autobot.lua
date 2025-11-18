--[[ 
    MÓDULO: Path Creator Pro v3.1 (Notifications & Shortcuts)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [NOVO] Atalho 'B' para Play/Stop.
    - [NOVO] Botão de Visibilidade da Rota (Footer).
    - [NOVO] Sistema de Notificações para todas as ações.
    - [UI] Layout ajustado para acomodar novos botões.
]]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO PATH: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. SERVIÇOS E UTILITÁRIOS
local LogarEvento = Chassi.LogarEvento or print
local pCreate = Chassi.pCreate
local TabMundo = Chassi.Abas and Chassi.Abas.Mundo

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

-- Função de Notificação Unificada
local function Notificar(titulo, msg)
    -- Tenta usar o Rayfield do Chassi se acessível
    if Chassi.Rayfield and Chassi.Rayfield.Notify then
        Chassi.Rayfield:Notify({Title = titulo, Content = msg, Duration = 2, Image = 4483362458})
    else
        -- Fallback nativo do Roblox
        StarterGui:SetCore("SendNotification", {Title = titulo, Text = msg, Duration = 2})
    end
end

-- Arquivo
local FileName = "Gabotri_Path_v3_" .. tostring(game.PlaceId) .. ".json"

-- 3. CONFIGURAÇÕES E ESTADO
local PathState = {
    Enabled = false,
    IsPlaying = false,
    Loop = false,
    ShowVisuals = true, -- Controle de visibilidade
    GlobalSpeed = 16,
    GlobalDelay = 0
}

local CurrentRoute = {}    
local SelectedIndices = {} 
local LastSelectedIndex = nil 

local VisualsFolder = nil  
local GizmoHandles = {}
local OriginalCFrames = {} 
local CurrentTween = nil

-- UI References
local ScreenGui
local UI = {
    ScrollList = nil,
    StatusLabel = nil,
    Inputs = {}, 
    Buttons = {}
}

-- 4. SISTEMA VISUAL 3D
local function ClearVisuals()
    if VisualsFolder then VisualsFolder:Destroy() end
    VisualsFolder = Instance.new("Folder", Workspace)
    VisualsFolder.Name = "GabotriPathVisuals_v3"
end

local function UpdateVisuals()
    -- Se visual desligado, limpa e retorna
    if not PathState.ShowVisuals then ClearVisuals(); return end
    
    if not VisualsFolder or not VisualsFolder.Parent then ClearVisuals() end
    
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
            
            local att = Instance.new("Attachment", part); att.Name = "BeamAtt"
            
            local bb = Instance.new("BillboardGui", part); bb.Size = UDim2.new(0,150,0,50); bb.StudsOffset = Vector3.new(0,2,0); bb.AlwaysOnTop = true
            local txt = Instance.new("TextLabel", bb); txt.Name="Label"; txt.Size=UDim2.new(1,0,1,0); txt.BackgroundTransparency=1; txt.TextColor3=Color3.new(1,1,1); txt.TextStrokeTransparency=0; txt.TextSize=12; txt.Font=Enum.Font.GothamBold
            
            local bbT = Instance.new("BillboardGui", part); bbT.Name="TimerUI"; bbT.Size=UDim2.new(0,100,0,30); bbT.StudsOffset=Vector3.new(0,3.5,0); bbT.AlwaysOnTop=true; bbT.Enabled=false
            local txtT = Instance.new("TextLabel", bbT); txtT.Name="TimerLbl"; txtT.Size=UDim2.new(1,0,1,0); txtT.BackgroundTransparency=0.5; txtT.BackgroundColor3=Color3.new(0,0,0); txtT.TextColor3=Color3.new(1,1,0); txtT.TextSize=14; txtT.Font=Enum.Font.Code
        end
        
        part.CFrame = pt.cframe
        
        local lbl = part.BillboardGui.Label
        local isSelected = SelectedIndices[i]
        
        if isSelected then
            part.Color = Color3.fromRGB(0, 255, 255) 
            part.Size = Vector3.new(2, 2, 2)
            lbl.TextColor3 = Color3.fromRGB(0, 255, 255)
        else
            part.Color = pt.type == "Instant" and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)
            part.Size = Vector3.new(1.5, 1.5, 1.5)
            lbl.TextColor3 = Color3.new(1, 1, 1)
        end
        
        local spdTxt = (pt.speed > 0) and tostring(pt.speed) or ("G("..PathState.GlobalSpeed..")")
        local dlyTxt = (pt.delay > 0) and tostring(pt.delay) or ("G("..PathState.GlobalDelay..")")
        lbl.Text = string.format("#%d [%s]\nSpd: %s | Dly: %s", i, pt.type, spdTxt, dlyTxt)
        
        -- Beams
        if i < #CurrentRoute then
            local nextPartName = "Node_" .. (i+1)
            local beam = part:FindFirstChild("PathBeam") or Instance.new("Beam", part)
            beam.Name = "PathBeam"; beam.FaceCamera = true; beam.Width0 = 0.5; beam.Width1 = 0.5
            beam.Color = ColorSequence.new(Color3.new(1,1,1))
            beam.Transparency = NumberSequence.new(0.5)
            beam.Attachment0 = part.BeamAtt
            
            local nextPart = VisualsFolder:FindFirstChild(nextPartName)
            if nextPart and nextPart:FindFirstChild("BeamAtt") then
                beam.Attachment1 = nextPart.BeamAtt; beam.Enabled = true
            else
                beam.Enabled = false
            end
        else
            local b = part:FindFirstChild("PathBeam"); if b then b:Destroy() end
        end
    end
    
    -- Limpeza orfãos
    for _, child in pairs(VisualsFolder:GetChildren()) do
        local idx = tonumber(child.Name:match("Node_(%d+)"))
        if idx and idx > #CurrentRoute then child:Destroy() end
    end
end

-- 5. GIZMO
local function ClearGizmos()
    for _, g in pairs(GizmoHandles) do g:Destroy() end
    GizmoHandles = {}
end

local function UpdateGizmo()
    ClearGizmos()
    if not PathState.Enabled or not LastSelectedIndex or not PathState.ShowVisuals then return end
    
    local proxyPart = VisualsFolder:FindFirstChild("Node_"..LastSelectedIndex)
    if not proxyPart then return end 
    
    local moveHandles = Instance.new("Handles")
    moveHandles.Adornee = proxyPart
    moveHandles.Style = Enum.HandlesStyle.Resize
    moveHandles.Color3 = Color3.fromRGB(255, 200, 0)
    moveHandles.Parent = ScreenGui 
    
    moveHandles.MouseButton1Down:Connect(function()
        OriginalCFrames = {}
        for idx, _ in pairs(SelectedIndices) do
            if CurrentRoute[idx] then OriginalCFrames[idx] = CurrentRoute[idx].cframe end
        end
    end)
    
    moveHandles.MouseDrag:Connect(function(face, distance)
        local baseCF = OriginalCFrames[LastSelectedIndex]
        if not baseCF then return end
        
        local moveVec = Vector3.new(0,0,0)
        if face == Enum.NormalId.Right then moveVec = baseCF.RightVector * distance
        elseif face == Enum.NormalId.Left then moveVec = baseCF.RightVector * -distance
        elseif face == Enum.NormalId.Top then moveVec = baseCF.UpVector * distance
        elseif face == Enum.NormalId.Bottom then moveVec = baseCF.UpVector * -distance
        elseif face == Enum.NormalId.Front then moveVec = baseCF.LookVector * distance
        elseif face == Enum.NormalId.Back then moveVec = baseCF.LookVector * -distance end
        
        for idx, _ in pairs(SelectedIndices) do
            if CurrentRoute[idx] and OriginalCFrames[idx] then
                CurrentRoute[idx].cframe = OriginalCFrames[idx] + moveVec
                local p = VisualsFolder:FindFirstChild("Node_"..idx)
                if p then p.CFrame = CurrentRoute[idx].cframe end
            end
        end
        UpdatePropertiesUI()
    end)
    table.insert(GizmoHandles, moveHandles)
end

-- 6. SELEÇÃO
local function SelectPoint(index, multi)
    if not index then
        if not multi then SelectedIndices = {}; LastSelectedIndex = nil end
        UpdateVisuals(); UpdateGizmo(); UpdatePropertiesUI()
        return
    end
    if multi then
        if SelectedIndices[index] then
            SelectedIndices[index] = nil
            if LastSelectedIndex == index then LastSelectedIndex = nil end
        else
            SelectedIndices[index] = true; LastSelectedIndex = index
        end
    else
        SelectedIndices = {[index] = true}; LastSelectedIndex = index
    end
    UpdateVisuals(); UpdateGizmo(); UpdatePropertiesUI()
end

-- 7. SAVE/LOAD
local function SaveRoute()
    local data = { GlobalSpeed = PathState.GlobalSpeed, GlobalDelay = PathState.GlobalDelay, Points = {} }
    for _, pt in ipairs(CurrentRoute) do
        local x, y, z = pt.cframe.X, pt.cframe.Y, pt.cframe.Z
        table.insert(data.Points, { x=x, y=y, z=z, t=pt.type, s=pt.speed, d=pt.delay })
    end
    pcall(function() writefile(FileName, HttpService:JSONEncode(data)) end)
    Notificar("Sistema", "Rota salva com sucesso!")
    LogarEvento("SUCESSO", "Rota salva em "..FileName)
end

local function LoadRoute()
    if isfile(FileName) then
        local s, c = pcall(function() return readfile(FileName) end)
        if s then
            local data = HttpService:JSONDecode(c)
            if data.Points then
                PathState.GlobalSpeed = data.GlobalSpeed or 16
                PathState.GlobalDelay = data.GlobalDelay or 0
                CurrentRoute = {}
                for _, d in ipairs(data.Points) do
                    table.insert(CurrentRoute, { cframe = CFrame.new(d.x, d.y, d.z), type = d.t or "Smooth", speed = d.s or 0, delay = d.d or 0 })
                end
            end
            Notificar("Sistema", "Rota carregada.")
        end
    end
    UpdateVisuals(); RefreshTimeline(); UpdatePropertiesUI()
end

-- 8. UI (Layout Ajustado)
--========================================================================
ScreenGui = Instance.new("ScreenGui", CoreGui); ScreenGui.Name = "PathCreatorUI_v3"; ScreenGui.Enabled = false
ScreenGui.IgnoreGuiInset = true

-- Estilos
local Colors = { BgDark = Color3.fromRGB(30, 30, 35), BgLight = Color3.fromRGB(40, 40, 45), Accent = Color3.fromRGB(0, 120, 215), Text = Color3.new(1,1,1), Red = Color3.fromRGB(200, 60, 60), Green = Color3.fromRGB(60, 200, 100) }

local function CreateFrame(parent, size, pos, color, corner)
    local f = Instance.new("Frame", parent); f.Size = size; f.Position = pos; f.BackgroundColor3 = color or Colors.BgDark
    if corner then Instance.new("UICorner", f).CornerRadius = UDim.new(0, corner) end
    return f
end

local function CreateBtn(parent, text, size, pos, color, func)
    local b = Instance.new("TextButton", parent); b.Text = text; b.Size = size; b.Position = pos; b.BackgroundColor3 = color or Colors.BgLight
    b.TextColor3 = Colors.Text; b.Font = Enum.Font.GothamBold; b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4); b.MouseButton1Click:Connect(func)
    return b
end

local function CreateLabeledInput(parent, labelText, ph, order)
    local c = Instance.new("Frame", parent); c.Size = UDim2.new(1, 0, 0, 40); c.LayoutOrder = order; c.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", c); lbl.Text = labelText; lbl.Size = UDim2.new(1, 0, 0, 15); lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.fromRGB(180,180,180); lbl.Font = Enum.Font.Gotham; lbl.TextSize = 10; lbl.TextXAlignment = Enum.TextXAlignment.Left
    local box = Instance.new("TextBox", c); box.PlaceholderText = ph; box.Text = ""; box.Size = UDim2.new(1, 0, 0, 20); box.Position = UDim2.new(0, 0, 0, 18); box.BackgroundColor3 = Colors.BgDark; box.TextColor3 = Colors.Text; box.Font = Enum.Font.GothamBold; box.TextSize = 12; Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    return box
end

local MainContainer = CreateFrame(ScreenGui, UDim2.new(0, 550, 0, 400), UDim2.new(0.5, -275, 0.5, -200), Colors.BgDark, 8)
MainContainer.Active = true; MainContainer.Draggable = true

-- Top Bar
local Header = CreateFrame(MainContainer, UDim2.new(1, 0, 0, 30), UDim2.new(0,0,0,0), Colors.BgLight, 8)
local HeaderCover = CreateFrame(Header, UDim2.new(1,0,0,5), UDim2.new(0,0,1,-5), Colors.BgLight, 0); HeaderCover.BorderSizePixel = 0
local Title = Instance.new("TextLabel", Header); Title.Text = "  PATH CREATOR PRO v3.1"; Title.Size = UDim2.new(1, -30, 1, 0); Title.BackgroundTransparency = 1; Title.TextColor3 = Colors.Text; Title.Font = Enum.Font.GothamBold; Title.TextXAlignment = Enum.TextXAlignment.Left
local CloseBtn = CreateBtn(Header, "X", UDim2.new(0, 30, 1, 0), UDim2.new(1, -30, 0, 0), Color3.new(0,0,0), function() PathState.Enabled = false; ScreenGui.Enabled = false; UpdateGizmo() end); CloseBtn.BackgroundTransparency = 1; CloseBtn.TextColor3 = Colors.Red

-- Sidebar
local Sidebar = CreateFrame(MainContainer, UDim2.new(0.35, -5, 1, -75), UDim2.new(0, 5, 0, 35), Colors.BgLight, 4)
UI.ScrollList = Instance.new("ScrollingFrame", Sidebar); UI.ScrollList.Size = UDim2.new(1, -4, 1, -4); UI.ScrollList.Position = UDim2.new(0, 2, 0, 2); UI.ScrollList.BackgroundTransparency = 1; UI.ScrollList.ScrollBarThickness = 4; UI.ScrollList.CanvasSize = UDim2.new(0,0,0,0)
local ListLayout = Instance.new("UIListLayout", UI.ScrollList); ListLayout.Padding = UDim.new(0, 2)

-- Inspector
local Inspector = CreateFrame(MainContainer, UDim2.new(0.65, -10, 1, -75), UDim2.new(0.35, 5, 0, 35), Colors.BgLight, 4)
local InspLayout = Instance.new("UIListLayout", Inspector); InspLayout.Padding = UDim.new(0, 5); InspLayout.SortOrder = Enum.SortOrder.LayoutOrder
local InspPad = Instance.new("UIPadding", Inspector); InspPad.PaddingTop = UDim.new(0, 10); InspPad.PaddingLeft = UDim.new(0, 10); InspPad.PaddingRight = UDim.new(0, 10)
UI.StatusLabel = Instance.new("TextLabel", Inspector); UI.StatusLabel.LayoutOrder = 0; UI.StatusLabel.Size = UDim2.new(1,0,0,20); UI.StatusLabel.BackgroundTransparency = 1; UI.StatusLabel.TextColor3 = Colors.Accent; UI.StatusLabel.Font = Enum.Font.GothamBlack; UI.StatusLabel.Text = "SELECIONE UM PONTO"

UI.Inputs.PtType = CreateLabeledInput(Inspector, "Tipo (Smooth/Instant)", "Ex: Smooth", 1); UI.Inputs.PtType.FocusLost:Connect(function() for k,_ in pairs(SelectedIndices) do if CurrentRoute[k] then CurrentRoute[k].type=UI.Inputs.PtType.Text; Notificar("Editar", "Tipo alterado.") end end UpdateVisuals() end)
UI.Inputs.PtSpeed = CreateLabeledInput(Inspector, "Velocidade Custom (0 = Global)", "0", 2); UI.Inputs.PtSpeed.FocusLost:Connect(function() local v=tonumber(UI.Inputs.PtSpeed.Text); if v then for k,_ in pairs(SelectedIndices) do CurrentRoute[k].speed=v end Notificar("Editar", "Velocidade alterada.") UpdateVisuals() end end)
UI.Inputs.PtDelay = CreateLabeledInput(Inspector, "Delay Custom (0 = Global)", "0", 3); UI.Inputs.PtDelay.FocusLost:Connect(function() local v=tonumber(UI.Inputs.PtDelay.Text); if v then for k,_ in pairs(SelectedIndices) do CurrentRoute[k].delay=v end Notificar("Editar", "Delay alterado.") UpdateVisuals() end end)

local ActionsFrame = CreateFrame(Inspector, UDim2.new(1,0,0,30), UDim2.new(0,0,0,0), nil, 0); ActionsFrame.BackgroundTransparency = 1; ActionsFrame.LayoutOrder = 4
CreateBtn(ActionsFrame, "Mover p/ Mim", UDim2.new(0.48, 0, 1, 0), UDim2.new(0,0,0,0), Colors.Accent, function()
    local h = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if h and LastSelectedIndex then CurrentRoute[LastSelectedIndex].cframe = h.CFrame; UpdateVisuals(); UpdateGizmo(); Notificar("Editar", "Ponto movido.") end
end)
CreateBtn(ActionsFrame, "Deletar", UDim2.new(0.48, 0, 1, 0), UDim2.new(0.52,0,0,0), Colors.Red, function()
    local toDel = {}
    for k,_ in pairs(SelectedIndices) do table.insert(toDel, k) end
    table.sort(toDel, function(a,b) return a > b end)
    for _, idx in ipairs(toDel) do table.remove(CurrentRoute, idx) end
    SelectedIndices = {}; LastSelectedIndex = nil
    RefreshTimeline(); UpdateVisuals(); UpdateGizmo(); UpdatePropertiesUI()
    Notificar("Sistema", "Ponto(s) deletado(s).")
end)

-- Footer
local Footer = CreateFrame(MainContainer, UDim2.new(1, -10, 0, 30), UDim2.new(0, 5, 1, -35), Colors.BgLight, 4)
local GlobalBox = CreateFrame(Footer, UDim2.new(0.55, 0, 1, 0), UDim2.new(0,0,0,0), nil, 0); GlobalBox.BackgroundTransparency = 1
local l1 = Instance.new("UIListLayout", GlobalBox); l1.FillDirection = Enum.FillDirection.Horizontal; l1.Padding = UDim.new(0, 5); l1.VerticalAlignment = Enum.VerticalAlignment.Center

UI.Inputs.GlobalSpeed = Instance.new("TextBox", GlobalBox); UI.Inputs.GlobalSpeed.PlaceholderText = "G. Spd"; UI.Inputs.GlobalSpeed.Size = UDim2.new(0, 45, 0, 20); UI.Inputs.GlobalSpeed.BackgroundColor3 = Colors.BgDark; UI.Inputs.GlobalSpeed.TextColor3 = Colors.Text; Instance.new("UICorner", UI.Inputs.GlobalSpeed).CornerRadius = UDim.new(0,4)
UI.Inputs.GlobalSpeed.FocusLost:Connect(function() PathState.GlobalSpeed = tonumber(UI.Inputs.GlobalSpeed.Text) or 16; UpdateVisuals(); Notificar("Config", "Velocidade Global atualizada") end)

UI.Inputs.GlobalDelay = Instance.new("TextBox", GlobalBox); UI.Inputs.GlobalDelay.PlaceholderText = "G. Dly"; UI.Inputs.GlobalDelay.Size = UDim2.new(0, 45, 0, 20); UI.Inputs.GlobalDelay.BackgroundColor3 = Colors.BgDark; UI.Inputs.GlobalDelay.TextColor3 = Colors.Text; Instance.new("UICorner", UI.Inputs.GlobalDelay).CornerRadius = UDim.new(0,4)
UI.Inputs.GlobalDelay.FocusLost:Connect(function() PathState.GlobalDelay = tonumber(UI.Inputs.GlobalDelay.Text) or 0; UpdateVisuals(); Notificar("Config", "Delay Global atualizado") end)

UI.Buttons.Loop = CreateBtn(GlobalBox, "Loop: OFF", UDim2.new(0, 60, 0, 20), UDim2.new(0,0,0,0), Colors.BgDark, function()
    PathState.Loop = not PathState.Loop
    UI.Buttons.Loop.Text = PathState.Loop and "Loop: ON" or "Loop: OFF"
    UI.Buttons.Loop.BackgroundColor3 = PathState.Loop and Colors.Accent or Colors.BgDark
    Notificar("Loop", PathState.Loop and "Ativado" or "Desativado")
end)

-- NOVO: Botão de Visibilidade (Olho)
UI.Buttons.Vis = CreateBtn(GlobalBox, "Vis: ON", UDim2.new(0, 55, 0, 20), UDim2.new(0,0,0,0), Colors.Accent, function()
    PathState.ShowVisuals = not PathState.ShowVisuals
    UI.Buttons.Vis.Text = PathState.ShowVisuals and "Vis: ON" or "Vis: OFF"
    UI.Buttons.Vis.BackgroundColor3 = PathState.ShowVisuals and Colors.Accent or Colors.BgDark
    UpdateVisuals()
    UpdateGizmo()
    Notificar("Visual", PathState.ShowVisuals and "Rota Visível" or "Rota Oculta")
end)

local PlayBox = CreateFrame(Footer, UDim2.new(0.4, 0, 1, 0), UDim2.new(0.6, 0, 0, 0), nil, 0); PlayBox.BackgroundTransparency = 1
local l2 = Instance.new("UIListLayout", PlayBox); l2.FillDirection = Enum.FillDirection.Horizontal; l2.Padding = UDim.new(0, 5); l2.HorizontalAlignment = Enum.HorizontalAlignment.Right; l2.VerticalAlignment = Enum.VerticalAlignment.Center
CreateBtn(PlayBox, "SALVAR", UDim2.new(0, 60, 0, 24), UDim2.new(0,0,0,0), Color3.fromRGB(255, 140, 0), SaveRoute)
CreateBtn(PlayBox, "STOP", UDim2.new(0, 50, 0, 24), UDim2.new(0,0,0,0), Colors.Red, function() TogglePlayback(false) end)
CreateBtn(PlayBox, "PLAY", UDim2.new(0, 50, 0, 24), UDim2.new(0,0,0,0), Colors.Green, function() TogglePlayback(true) end)


-- Lógica de UI
function RefreshTimeline()
    for _, c in pairs(UI.ScrollList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for i, pt in ipairs(CurrentRoute) do
        local Row = Instance.new("Frame", UI.ScrollList); Row.Size = UDim2.new(1, 0, 0, 25); Row.BackgroundColor3 = SelectedIndices[i] and Colors.Accent or Colors.BgDark
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 4)
        local Btn = Instance.new("TextButton", Row); Btn.Size = UDim2.new(1, -10, 1, 0); Btn.Position = UDim2.new(0, 10, 0, 0)
        Btn.BackgroundTransparency = 1; Btn.Text = i .. ". " .. pt.type; Btn.TextColor3 = Colors.Text; Btn.TextXAlignment = Enum.TextXAlignment.Left; Btn.Font = Enum.Font.GothamSemibold
        Btn.MouseButton1Click:Connect(function()
            local multi = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            SelectPoint(i, multi)
        end)
    end
    UI.ScrollList.CanvasSize = UDim2.new(0, 0, 0, #CurrentRoute * 27)
end

function UpdatePropertiesUI()
    UI.Inputs.GlobalSpeed.Text = tostring(PathState.GlobalSpeed)
    UI.Inputs.GlobalDelay.Text = tostring(PathState.GlobalDelay)
    local count = 0; for _ in pairs(SelectedIndices) do count=count+1 end
    if count == 0 then
        UI.StatusLabel.Text = "NENHUM SELECIONADO"
        UI.Inputs.PtType.Text = ""; UI.Inputs.PtSpeed.Text = ""; UI.Inputs.PtDelay.Text = ""
    elseif count == 1 and LastSelectedIndex and CurrentRoute[LastSelectedIndex] then
        local pt = CurrentRoute[LastSelectedIndex]
        UI.StatusLabel.Text = "EDITANDO PONTO #"..LastSelectedIndex
        UI.Inputs.PtType.Text = pt.type
        UI.Inputs.PtSpeed.Text = tostring(pt.speed)
        UI.Inputs.PtDelay.Text = tostring(pt.delay)
    else
        UI.StatusLabel.Text = "MULTI-SELEÇÃO ("..count..")"
        UI.Inputs.PtType.Text = "---"; UI.Inputs.PtSpeed.Text = "---"; UI.Inputs.PtDelay.Text = "---"
    end
    RefreshTimeline()
end

-- 9. LÓGICA DE PLAYBACK
function TogglePlayback(state)
    PathState.IsPlaying = state
    Notificar("Playback", state and "Iniciando rota..." or "Rota Parada.")
    
    if not state then if CurrentTween then CurrentTween:Cancel() end return end
    
    task.spawn(function()
        while PathState.IsPlaying do
            for i, pt in ipairs(CurrentRoute) do
                if not PathState.IsPlaying then break end
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then break end
                
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
            if not PathState.Loop then PathState.IsPlaying = false; Notificar("Playback", "Rota finalizada.") end
        end
    end)
end

-- 10. INPUTS E ATALHOS
UserInputService.InputBegan:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.F5 then
        PathState.Enabled = not PathState.Enabled
        ScreenGui.Enabled = PathState.Enabled
        UpdateVisuals(); UpdateGizmo()
        if TabMundo and TabMundo:FindFirstChild("TogglePathCreator") then TabMundo:FindFirstChild("TogglePathCreator"):Set(PathState.Enabled) end
    end
    
    -- [NOVO] Atalho B para Play/Stop
    if input.KeyCode == Enum.KeyCode.B and not gp then
        TogglePlayback(not PathState.IsPlaying)
    end
    
    if not PathState.Enabled then return end
    
    if input.KeyCode == Enum.KeyCode.T and not gp then
        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(CurrentRoute, {
                cframe = Player.Character.HumanoidRootPart.CFrame,
                type = "Smooth", speed = 0, delay = 0
            })
            SelectPoint(#CurrentRoute, false)
            Notificar("Editar", "Ponto adicionado (T)")
        end
    end
    
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
            if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then SelectPoint(nil) end
        end
    end
end)

-- 11. START
if TabMundo then
    pCreate("SecPathPro", TabMundo, "CreateSection", "Path Creator v3.1", "Right")
    pCreate("TogglePathCreator", TabMundo, "CreateToggle", {
        Name = "Abrir Editor [F5]", CurrentValue = false,
        Callback = function(v) PathState.Enabled = v; ScreenGui.Enabled = v; UpdateVisuals(); UpdateGizmo() end
    })
end

LoadRoute()
LogarEvento("SUCESSO", "Módulo Path Creator v3.1 (UI+Notifs) carregado.")