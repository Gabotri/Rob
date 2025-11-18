--[==[
    MÓDULO: World Editor Pro v1.3 (Stable Physics & Hotkeys)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [FIX] Sensibilidade: Agora usa CFrame Relativo (1:1 com o mouse).
    - [FIX] Multi-Select: Agora requer Ctrl + Shift + Click.
    - [FIX] Ferramenta Resize já estava corrigida na v1.2, mantida aqui.
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
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

-- 3. CONFIGURAÇÕES
local EditorSettings = {
    Enabled = false,
    SnapMove = 1.0,
    SnapRotate = 45,
    SnapEnabled = false,
    ToolMode = "Move",
    Space = "World"
}

local SelectedObjects = {}
local Gizmos = {}

-- Variáveis de Controle de Física (Estabilidade)
local OriginalCFrame = CFrame.new()
local OriginalSize = Vector3.new()

-- UI References
local ScreenGui, PropFrame

-- 4. SISTEMA DE GIZMOS (ESTABILIZADO)
--========================================================================
local function ClearGizmos()
    for _, g in pairs(Gizmos) do g:Destroy() end
    Gizmos = {}
end

local function UpdateGizmos()
    ClearGizmos()
    if not EditorSettings.Enabled then return end
    
    for _, part in pairs(SelectedObjects) do
        if part:IsA("BasePart") then
            -- Selection Box
            local box = Instance.new("SelectionBox")
            box.Adornee = part; box.LineThickness = 0.05; box.Color3 = Color3.fromRGB(0, 255, 255); box.Transparency = 0.5; box.Parent = ScreenGui
            table.insert(Gizmos, box)

            -- === FERRAMENTA MOVE (ESTÁVEL) ===
            if EditorSettings.ToolMode == "Move" then
                local handles = Instance.new("Handles")
                handles.Style = Enum.HandlesStyle.Resize
                handles.Adornee = part; handles.Color3 = Color3.fromRGB(255, 255, 0); handles.Parent = ScreenGui
                
                -- Salva posição inicial ao clicar
                handles.MouseButton1Down:Connect(function()
                    OriginalCFrame = part.CFrame
                end)

                handles.MouseDrag:Connect(function(face, distance)
                    local d = distance
                    if EditorSettings.SnapEnabled then d = math.floor(d / EditorSettings.SnapMove) * EditorSettings.SnapMove end
                    
                    -- Calcula baseado no Original, não no atual (Evita aceleração infinita)
                    local cf = OriginalCFrame
                    
                    if face == Enum.NormalId.Right then part.CFrame = cf + (cf.RightVector * d)
                    elseif face == Enum.NormalId.Left then part.CFrame = cf - (cf.RightVector * d)
                    elseif face == Enum.NormalId.Top then part.CFrame = cf + (cf.UpVector * d)
                    elseif face == Enum.NormalId.Bottom then part.CFrame = cf - (cf.UpVector * d)
                    elseif face == Enum.NormalId.Front then part.CFrame = cf + (cf.LookVector * d)
                    elseif face == Enum.NormalId.Back then part.CFrame = cf - (cf.LookVector * d) end
                    
                    UpdatePropertiesUI(part)
                end)
                table.insert(Gizmos, handles)
                
            -- === FERRAMENTA ROTATE (ESTÁVEL) ===
            elseif EditorSettings.ToolMode == "Rotate" then
                local arc = Instance.new("ArcHandles")
                arc.Adornee = part; arc.Parent = ScreenGui
                
                arc.MouseButton1Down:Connect(function()
                    OriginalCFrame = part.CFrame
                end)
                
                arc.MouseDrag:Connect(function(axis, relativeAngle)
                    local rot = relativeAngle
                    if EditorSettings.SnapEnabled then rot = math.floor(relativeAngle / math.rad(EditorSettings.SnapRotate)) * math.rad(EditorSettings.SnapRotate) end
                    
                    -- Aplica a rotação sobre o CFrame Original
                    if axis == Enum.Axis.X then part.CFrame = OriginalCFrame * CFrame.Angles(rot, 0, 0)
                    elseif axis == Enum.Axis.Y then part.CFrame = OriginalCFrame * CFrame.Angles(0, rot, 0)
                    elseif axis == Enum.Axis.Z then part.CFrame = OriginalCFrame * CFrame.Angles(0, 0, rot) end
                    
                    UpdatePropertiesUI(part)
                end)
                table.insert(Gizmos, arc)
            
            -- === FERRAMENTA RESIZE (ESTÁVEL) ===
            elseif EditorSettings.ToolMode == "Resize" then
                local handles = Instance.new("Handles")
                handles.Style = Enum.HandlesStyle.Resize
                handles.Adornee = part; handles.Color3 = Color3.fromRGB(0, 100, 255); handles.Parent = ScreenGui
                
                handles.MouseButton1Down:Connect(function()
                    OriginalSize = part.Size
                    OriginalCFrame = part.CFrame
                end)

                handles.MouseDrag:Connect(function(face, distance)
                    local d = distance
                    if EditorSettings.SnapEnabled then d = math.floor(d / EditorSettings.SnapMove) * EditorSettings.SnapMove end
                    
                    local sizeChange = Vector3.new(0,0,0)
                    local posChange = Vector3.new(0,0,0)
                    
                    -- Lógica: Aumenta tamanho e compensa posição (Centro)
                    if face == Enum.NormalId.Right then sizeChange = Vector3.new(d, 0, 0); posChange = OriginalCFrame.RightVector * (d / 2)
                    elseif face == Enum.NormalId.Left then sizeChange = Vector3.new(d, 0, 0); posChange = OriginalCFrame.RightVector * (-d / 2)
                    elseif face == Enum.NormalId.Top then sizeChange = Vector3.new(0, d, 0); posChange = OriginalCFrame.UpVector * (d / 2)
                    elseif face == Enum.NormalId.Bottom then sizeChange = Vector3.new(0, d, 0); posChange = OriginalCFrame.UpVector * (-d / 2)
                    elseif face == Enum.NormalId.Front then sizeChange = Vector3.new(0, 0, d); posChange = OriginalCFrame.LookVector * (d / 2)
                    elseif face == Enum.NormalId.Back then sizeChange = Vector3.new(0, 0, d); posChange = OriginalCFrame.LookVector * (-d / 2) end

                    part.Size = OriginalSize + sizeChange
                    part.CFrame = OriginalCFrame + posChange
                    
                    UpdatePropertiesUI(part)
                end)
                table.insert(Gizmos, handles)
            end
        end
    end
end

-- 5. GERENCIAMENTO DE SELEÇÃO
--========================================================================
local function SelectObject(obj, multi)
    if not obj then 
        if not multi then SelectedObjects = {} UpdateGizmos() end
        return 
    end
    
    local found = false
    for i, v in ipairs(SelectedObjects) do 
        if v == obj then 
            if multi then table.remove(SelectedObjects, i) end
            found = true 
            break 
        end 
    end
    
    if not found then
        if not multi then SelectedObjects = {obj}
        else table.insert(SelectedObjects, obj) end
    end
    
    UpdateGizmos()
    if #SelectedObjects > 0 then UpdatePropertiesUI(SelectedObjects[1]) end
end

-- 6. UI PURA
--========================================================================
ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GabotriWorldEditor_v1.3"
ScreenGui.Parent = CoreGui
ScreenGui.Enabled = false
ScreenGui.ResetOnSpawn = false

-- PROPRIEDADES
PropFrame = Instance.new("Frame", ScreenGui)
PropFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
PropFrame.Position = UDim2.new(0.82, 0, 0.1, 0)
PropFrame.Size = UDim2.new(0, 200, 0, 400)
PropFrame.Active = true; PropFrame.Draggable = true
Instance.new("UICorner", PropFrame).CornerRadius = UDim.new(0, 6)

local PropTitle = Instance.new("TextLabel", PropFrame)
PropTitle.Text = " PROPRIEDADES"; PropTitle.Size = UDim2.new(1,0,0,25); PropTitle.BackgroundColor3 = Color3.fromRGB(40,40,45)
PropTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PropTitle.Font = Enum.Font.GothamBold; PropTitle.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UICorner", PropTitle).CornerRadius = UDim.new(0, 6)

local PropList = Instance.new("ScrollingFrame", PropFrame)
PropList.Position = UDim2.new(0,0,0,30); PropList.Size = UDim2.new(1,0,1,-35); PropList.BackgroundTransparency = 1; PropList.ScrollBarThickness = 4
local UIList = Instance.new("UIListLayout", PropList); UIList.Padding = UDim.new(0, 5); UIList.SortOrder = Enum.SortOrder.LayoutOrder

-- Helpers UI
local function CreatePropInput(name, order)
    local Frame = Instance.new("Frame", PropList); Frame.Size = UDim2.new(1,-10,0,40); Frame.BackgroundTransparency = 1; Frame.LayoutOrder = order
    local Lbl = Instance.new("TextLabel", Frame); Lbl.Text = name; Lbl.Size = UDim2.new(1,0,0,15); Lbl.TextColor3 = Color3.fromRGB(200,200,200); Lbl.BackgroundTransparency = 1; Lbl.Font = Enum.Font.Gotham; Lbl.TextSize = 10
    local Box = Instance.new("TextBox", Frame); Box.Position = UDim2.new(0,0,0,15); Box.Size = UDim2.new(1,0,0,20); Box.BackgroundColor3 = Color3.fromRGB(50,50,55)
    Box.TextColor3 = Color3.fromRGB(255, 255, 255); Box.Font = Enum.Font.Code; Box.TextSize = 11; Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 4)
    return Box
end

local InpName = CreatePropInput("Name", 1)
local InpPos = CreatePropInput("Position", 2)
local InpSize = CreatePropInput("Size", 3)
local InpTransp = CreatePropInput("Transparency", 4)

-- Update UI
function UpdatePropertiesUI(obj)
    if not obj then return end
    InpName.Text = obj.Name
    if obj:IsA("BasePart") then
        InpPos.Text = string.format("%.1f, %.1f, %.1f", obj.Position.X, obj.Position.Y, obj.Position.Z)
        InpSize.Text = string.format("%.1f, %.1f, %.1f", obj.Size.X, obj.Size.Y, obj.Size.Z)
        InpTransp.Text = string.format("%.1f", obj.Transparency)
    end
end

-- TOOLBAR
local ToolFrame = Instance.new("Frame", ScreenGui)
ToolFrame.Name = "Tools"; ToolFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35); ToolFrame.Position = UDim2.new(0.4, 0, 0.02, 0); ToolFrame.Size = UDim2.new(0, 300, 0, 40)
Instance.new("UICorner", ToolFrame).CornerRadius = UDim.new(0, 6)
local TL = Instance.new("UIListLayout", ToolFrame); TL.FillDirection = Enum.FillDirection.Horizontal; TL.Padding = UDim.new(0, 5); TL.HorizontalAlignment = Enum.HorizontalAlignment.Center; TL.VerticalAlignment = Enum.VerticalAlignment.Center

local function CreateToolBtn(text, mode)
    local btn = Instance.new("TextButton", ToolFrame); btn.Size = UDim2.new(0, 60, 0, 30); btn.Text = text; btn.BackgroundColor3 = Color3.fromRGB(50, 50, 55); btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Font = Enum.Font.GothamBold; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(function() EditorSettings.ToolMode = mode; UpdateGizmos() end)
    return btn
end

CreateToolBtn("Move", "Move")
CreateToolBtn("Rotate", "Rotate")
CreateToolBtn("Resize", "Resize")

-- 7. INPUTS
--========================================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.Insert then
        EditorSettings.Enabled = not EditorSettings.Enabled
        ScreenGui.Enabled = EditorSettings.Enabled
        UpdateGizmos()
    end

    if not EditorSettings.Enabled then return end
    if gp then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if Mouse.Target then
            -- [FIX] Multi-select: Ctrl + Shift + Click
            local isMulti = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            SelectObject(Mouse.Target, isMulti)
        else
            if not (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)) then SelectObject(nil) end
        end
    end

    if input.KeyCode == Enum.KeyCode.Backspace then -- [FIX] Backspace delete
        for _, o in pairs(SelectedObjects) do o:Destroy() end
        SelectObject(nil)
    end
    
    if input.KeyCode == Enum.KeyCode.D and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local clones = {}
        for _, o in pairs(SelectedObjects) do
            if o.Archivable then
                local c = o:Clone(); c.Parent = o.Parent
                if c:IsA("BasePart") then c.Position = c.Position + Vector3.new(2,0,0) end
                table.insert(clones, c)
            end
        end
        SelectedObjects = clones
        UpdateGizmos()
    end
end)

-- 8. CHASSI
if TabMundo then
    pCreate("SecEditor", TabMundo, "CreateSection", "World Editor v1.3 (Physics Fix)", "Left")
    pCreate("ToggleEdit", TabMundo, "CreateToggle", {
        Name = "Ativar Editor [Insert]", CurrentValue = false,
        Callback = function(v) EditorSettings.Enabled = v; ScreenGui.Enabled = v; UpdateGizmos() end
    })
    pCreate("SliderSnap", TabMundo, "CreateSlider", {
        Name = "Snap", Range = {0, 10}, Increment = 1, CurrentValue = 1,
        Callback = function(v) EditorSettings.SnapMove = v; EditorSettings.SnapEnabled = (v > 0) end
    })
end

LogarEvento("SUCESSO", "Módulo World Editor v1.3 (Physics Stable) carregado.")