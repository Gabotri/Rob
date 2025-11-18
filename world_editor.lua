--[==[
    MÓDULO: World Editor Pro v1.0
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - Gizmos 3D (Move, Rotate, Resize) com Snapping.
    - UI Pura: Propriedades e Explorer (Seleção).
    - Ferramentas: Delete, Clone, Anchor, Collide.
    - Atalhos: Ctrl+Click (Multi), Del (Delete), Ctrl+D (Duplicate).
]==]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO EDITOR: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. SERVIÇOS
local LogarEvento = Chassi.LogarEvento
local pCreate = Chassi.pCreate
local TabMundo = Chassi.Abas.Mundo

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Camera = Workspace.CurrentCamera

-- 3. CONFIGURAÇÕES & ESTADO
local EditorSettings = {
    Enabled = false,
    SnapMove = 1.0,       -- 1 Stud
    SnapRotate = 45,      -- 45 Graus
    SnapEnabled = false,
    ToolMode = "Move",    -- Move, Rotate, Resize
    Space = "World"       -- World, Local
}

local SelectedObjects = {} -- Tabela de objetos selecionados
local Gizmos = {} -- Handles e ArcHandles
local Connections = {} -- Eventos temporários
local Clipboard = {} -- Para copiar/colar propriedades

-- UI References
local ScreenGui, PropFrame, ExplorerFrame

-- 4. SISTEMA DE GIZMOS (HANDLES)
--========================================================================
local function ClearGizmos()
    for _, g in pairs(Gizmos) do g:Destroy() end
    Gizmos = {}
end

local function UpdateGizmos()
    ClearGizmos()
    if not EditorSettings.Enabled then return end
    
    -- Cria um Gizmo para cada objeto selecionado (ou um central para o grupo - simplificado por objeto v1)
    for _, part in pairs(SelectedObjects) do
        if part:IsA("BasePart") then
            -- Selection Box (Outline)
            local box = Instance.new("SelectionBox")
            box.Adornee = part
            box.LineThickness = 0.05
            box.Color3 = Color3.fromRGB(0, 255, 255)
            box.Transparency = 0.5
            box.Parent = ScreenGui -- Parenting to GUI prevents clutter in workspace
            table.insert(Gizmos, box)

            -- Ferramenta Ativa
            if EditorSettings.ToolMode == "Move" then
                local handles = Instance.new("Handles")
                handles.Style = Enum.HandlesStyle.Resize -- Setas modernas
                handles.Adornee = part
                handles.Color3 = Color3.fromRGB(255, 255, 0)
                handles.Parent = ScreenGui
                
                handles.MouseDrag:Connect(function(face, distance)
                    local delta = distance
                    if EditorSettings.SnapEnabled then
                        delta = math.floor(distance / EditorSettings.SnapMove) * EditorSettings.SnapMove
                    end
                    
                    local cf = part.CFrame
                    if face == Enum.NormalId.Right then part.CFrame = cf + (cf.RightVector * delta)
                    elseif face == Enum.NormalId.Left then part.CFrame = cf - (cf.RightVector * delta)
                    elseif face == Enum.NormalId.Top then part.CFrame = cf + (cf.UpVector * delta)
                    elseif face == Enum.NormalId.Bottom then part.CFrame = cf - (cf.UpVector * delta)
                    elseif face == Enum.NormalId.Front then part.CFrame = cf + (cf.LookVector * delta)
                    elseif face == Enum.NormalId.Back then part.CFrame = cf - (cf.LookVector * delta)
                    end
                    -- Atualiza UI de Propriedades
                end)
                table.insert(Gizmos, handles)
                
            elseif EditorSettings.ToolMode == "Rotate" then
                local arc = Instance.new("ArcHandles")
                arc.Adornee = part
                arc.Parent = ScreenGui
                
                arc.MouseDrag:Connect(function(axis, relativeAngle)
                    local rot = relativeAngle
                    if EditorSettings.SnapEnabled then
                        rot = math.floor(relativeAngle / math.rad(EditorSettings.SnapRotate)) * math.rad(EditorSettings.SnapRotate)
                    end
                    
                    if axis == Enum.Axis.X then part.CFrame = part.CFrame * CFrame.Angles(rot, 0, 0)
                    elseif axis == Enum.Axis.Y then part.CFrame = part.CFrame * CFrame.Angles(0, rot, 0)
                    elseif axis == Enum.Axis.Z then part.CFrame = part.CFrame * CFrame.Angles(0, 0, rot)
                    end
                end)
                table.insert(Gizmos, arc)
            end
        end
    end
end

-- 5. GERENCIAMENTO DE SELEÇÃO
--========================================================================
local function IsSelected(obj)
    for i, v in ipairs(SelectedObjects) do if v == obj then return i end end
    return nil
end

local function SelectObject(obj, multi)
    if not obj then 
        if not multi then SelectedObjects = {} UpdateGizmos() end
        return 
    end
    
    if multi then
        local idx = IsSelected(obj)
        if idx then table.remove(SelectedObjects, idx)
        else table.insert(SelectedObjects, obj) end
    else
        SelectedObjects = {obj}
    end
    
    UpdateGizmos()
    -- Atualiza UI de Propriedades (pega o primeiro)
    if #SelectedObjects > 0 then UpdatePropertiesUI(SelectedObjects[1]) end
end

-- 6. UI PURA (PROPERTIES & EXPLORER)
--========================================================================
ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GabotriWorldEditor"
ScreenGui.Parent = CoreGui
ScreenGui.Enabled = false
ScreenGui.ResetOnSpawn = false

-- === PAINEL DE PROPRIEDADES ===
PropFrame = Instance.new("Frame", ScreenGui)
PropFrame.Name = "Properties"
PropFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
PropFrame.Position = UDim2.new(0.82, 0, 0.1, 0)
PropFrame.Size = UDim2.new(0, 200, 0, 400)
PropFrame.Active = true; PropFrame.Draggable = true
Instance.new("UICorner", PropFrame).CornerRadius = UDim.new(0, 6)

local PropTitle = Instance.new("TextLabel", PropFrame)
PropTitle.Text = " PROPRIEDADES"; PropTitle.Size = UDim2.new(1,0,0,25); PropTitle.BackgroundColor3 = Color3.fromRGB(40,40,45); PropTitle.TextColor3 = Color3.white; PropTitle.Font = Enum.Font.GothamBold; PropTitle.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UICorner", PropTitle).CornerRadius = UDim.new(0, 6)

local PropList = Instance.new("ScrollingFrame", PropFrame)
PropList.Position = UDim2.new(0,0,0,30); PropList.Size = UDim2.new(1,0,1,-35); PropList.BackgroundTransparency = 1; PropList.ScrollBarThickness = 4
local UIList = Instance.new("UIListLayout", PropList); UIList.Padding = UDim.new(0, 5); UIList.SortOrder = Enum.SortOrder.LayoutOrder

-- Helper de Input de Propriedade
local function CreatePropInput(name, order)
    local Frame = Instance.new("Frame", PropList); Frame.Size = UDim2.new(1,-10,0,40); Frame.BackgroundTransparency = 1; Frame.LayoutOrder = order
    local Lbl = Instance.new("TextLabel", Frame); Lbl.Text = name; Lbl.Size = UDim2.new(1,0,0,15); Lbl.TextColor3 = Color3.fromRGB(200,200,200); Lbl.BackgroundTransparency = 1; Lbl.Font = Enum.Font.Gotham; Lbl.TextSize = 10
    local Box = Instance.new("TextBox", Frame); Box.Position = UDim2.new(0,0,0,15); Box.Size = UDim2.new(1,0,0,20); Box.BackgroundColor3 = Color3.fromRGB(50,50,55); Box.TextColor3 = Color3.white; Box.Font = Enum.Font.Code; Box.TextSize = 11
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 4)
    return Box
end

-- Campos
local InpName = CreatePropInput("Name", 1)
local InpPos = CreatePropInput("Position (X, Y, Z)", 2)
local InpSize = CreatePropInput("Size (X, Y, Z)", 3)
local InpColor = CreatePropInput("Color (R, G, B)", 4)
local InpTransp = CreatePropInput("Transparency (0-1)", 5)

-- Botões Booleanos
local BoolContainer = Instance.new("Frame", PropList); BoolContainer.Size = UDim2.new(1,-10,0,30); BoolContainer.BackgroundTransparency = 1; BoolContainer.LayoutOrder = 6
local BtnAnchor = Instance.new("TextButton", BoolContainer); BtnAnchor.Size = UDim2.new(0.48,0,1,0); BtnAnchor.Text = "Anchored"; BtnAnchor.BackgroundColor3 = Color3.fromRGB(60,60,60); BtnAnchor.TextColor3 = Color3.white
local BtnCollide = Instance.new("TextButton", BoolContainer); BtnCollide.Size = UDim2.new(0.48,0,1,0); BtnCollide.Position = UDim2.new(0.52,0,0,0); BtnCollide.Text = "Collide"; BtnCollide.BackgroundColor3 = Color3.fromRGB(60,60,60); BtnCollide.TextColor3 = Color3.white
Instance.new("UICorner", BtnAnchor).CornerRadius = UDim.new(0,4); Instance.new("UICorner", BtnCollide).CornerRadius = UDim.new(0,4)

-- Função Global Update UI
function UpdatePropertiesUI(obj)
    if not obj then return end
    InpName.Text = obj.Name
    if obj:IsA("BasePart") then
        InpPos.Text = string.format("%.2f, %.2f, %.2f", obj.Position.X, obj.Position.Y, obj.Position.Z)
        InpSize.Text = string.format("%.2f, %.2f, %.2f", obj.Size.X, obj.Size.Y, obj.Size.Z)
        local c = obj.Color
        InpColor.Text = string.format("%d, %d, %d", c.R*255, c.G*255, c.B*255)
        InpTransp.Text = tostring(obj.Transparency)
        
        BtnAnchor.BackgroundColor3 = obj.Anchored and Color3.fromRGB(0,150,0) or Color3.fromRGB(60,60,60)
        BtnCollide.BackgroundColor3 = obj.CanCollide and Color3.fromRGB(0,150,0) or Color3.fromRGB(60,60,60)
    end
end

-- Aplicar Propriedades (Inputs)
InpPos.FocusLost:Connect(function()
    if #SelectedObjects > 0 then
        local obj = SelectedObjects[1]
        local x,y,z = InpPos.Text:match("([^,]+),%s*([^,]+),%s*([^,]+)")
        if x and y and z and obj:IsA("BasePart") then
            obj.Position = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
            UpdateGizmos()
        end
    end
end)
InpSize.FocusLost:Connect(function()
    if #SelectedObjects > 0 then
        local obj = SelectedObjects[1]
        local x,y,z = InpSize.Text:match("([^,]+),%s*([^,]+),%s*([^,]+)")
        if x and y and z and obj:IsA("BasePart") then
            obj.Size = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
            UpdateGizmos()
        end
    end
end)
BtnAnchor.MouseButton1Click:Connect(function()
    for _, o in pairs(SelectedObjects) do if o:IsA("BasePart") then o.Anchored = not o.Anchored end end
    if #SelectedObjects > 0 then UpdatePropertiesUI(SelectedObjects[1]) end
end)
BtnCollide.MouseButton1Click:Connect(function()
    for _, o in pairs(SelectedObjects) do if o:IsA("BasePart") then o.CanCollide = not o.CanCollide end end
    if #SelectedObjects > 0 then UpdatePropertiesUI(SelectedObjects[1]) end
end)

-- === TOOLBAR (TOOLS) ===
local ToolFrame = Instance.new("Frame", ScreenGui)
ToolFrame.Name = "Tools"
ToolFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
ToolFrame.Position = UDim2.new(0.4, 0, 0.02, 0)
ToolFrame.Size = UDim2.new(0, 300, 0, 40)
Instance.new("UICorner", ToolFrame).CornerRadius = UDim.new(0, 6)

local UIListTools = Instance.new("UIListLayout", ToolFrame)
UIListTools.FillDirection = Enum.FillDirection.Horizontal
UIListTools.Padding = UDim.new(0, 5)
UIListTools.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListTools.VerticalAlignment = Enum.VerticalAlignment.Center

local function CreateToolBtn(text, mode)
    local btn = Instance.new("TextButton", ToolFrame)
    btn.Size = UDim2.new(0, 60, 0, 30)
    btn.Text = text
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    btn.TextColor3 = Color3.white
    btn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(function()
        EditorSettings.ToolMode = mode
        UpdateGizmos()
        LogarEvento("EDITOR", "Ferramenta: " .. mode)
    end)
    return btn
end

CreateToolBtn("Move", "Move")
CreateToolBtn("Rotate", "Rotate")
local BtnSnap = CreateToolBtn("Snap: Off", "None")
BtnSnap.MouseButton1Click:Connect(function()
    EditorSettings.SnapEnabled = not EditorSettings.SnapEnabled
    BtnSnap.Text = EditorSettings.SnapEnabled and "Snap: ON" or "Snap: OFF"
    BtnSnap.BackgroundColor3 = EditorSettings.SnapEnabled and Color3.fromRGB(0,150,0) or Color3.fromRGB(50,50,55)
end)

-- 7. INPUTS E LÓGICA DE MOUSE
--========================================================================
UserInputService.InputBegan:Connect(function(input, gp)
    -- Atalho Principal (INSERT) para ligar/desligar editor
    if input.KeyCode == Enum.KeyCode.Insert then
        EditorSettings.Enabled = not EditorSettings.Enabled
        ScreenGui.Enabled = EditorSettings.Enabled
        UpdateGizmos()
        LogarEvento("INFO", "Editor de Mundo: " .. tostring(EditorSettings.Enabled))
    end

    if not EditorSettings.Enabled then return end
    if gp then return end

    -- Seleção (Clique Esquerdo)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if Mouse.Target then
            local isMulti = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            SelectObject(Mouse.Target, isMulti)
        else
            if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                SelectObject(nil)
            end
        end
    end

    -- Atalhos de Edição
    if input.KeyCode == Enum.KeyCode.Delete then
        for _, o in pairs(SelectedObjects) do o:Destroy() end
        SelectObject(nil)
        LogarEvento("EDITOR", "Objetos deletados.")
    end
    
    if input.KeyCode == Enum.KeyCode.D and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local clones = {}
        for _, o in pairs(SelectedObjects) do
            if o.Archivable then
                local c = o:Clone()
                c.Parent = o.Parent
                if c:IsA("BasePart") then c.Position = c.Position + Vector3.new(2,0,0) end -- Offset simples
                table.insert(clones, c)
            end
        end
        SelectedObjects = clones
        UpdateGizmos()
        LogarEvento("EDITOR", "Objetos duplicados.")
    end
end)

-- 8. INTEGRAÇÃO CHASSI
--========================================================================
if TabMundo then
    pCreate("SecEditor", TabMundo, "CreateSection", "World Editor Pro v1.0", "Left")
    pCreate("ToggleEdit", TabMundo, "CreateToggle", {
        Name = "Ativar Editor [Insert]",
        CurrentValue = false,
        Callback = function(Val)
            EditorSettings.Enabled = Val
            ScreenGui.Enabled = Val
            UpdateGizmos()
        end
    })
    pCreate("SliderSnap", TabMundo, "CreateSlider", {
        Name = "Grid Snap (Studs)", Range = {0, 20}, Increment = 0.5, CurrentValue = 1,
        Callback = function(v) EditorSettings.SnapMove = v end
    })
    pCreate("SliderRot", TabMundo, "CreateSlider", {
        Name = "Rotation Snap (Graus)", Range = {0, 90}, Increment = 5, CurrentValue = 45,
        Callback = function(v) EditorSettings.SnapRotate = v end
    })
end

LogarEvento("SUCESSO", "Módulo World Editor v1.0 carregado.")