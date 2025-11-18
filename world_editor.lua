--[==[
    MÓDULO: World Editor Pro v1.2 (Resize Fix & Backspace)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - [FIX] Resize corrigido: Matemática de vetores reescrita (escala suave e na direção certa).
    - [FIX] Atalho de Deletar alterado para 'Backspace' para não fechar o Chassi.
    - [FIX] Sensibilidade ajustada para 1:1.
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

-- 3. CONFIGURAÇÕES & ESTADO
local EditorSettings = {
    Enabled = false,
    SnapMove = 1.0,
    SnapRotate = 45,
    SnapEnabled = false,
    ToolMode = "Move",    -- Move, Rotate, Resize
    Space = "World"
}

local SelectedObjects = {}
local Gizmos = {}
-- Variáveis para controle de Resize "Smooth"
local OriginalSize = Vector3.new()
local OriginalCFrame = CFrame.new()
local DragStartPoint = nil

-- UI References
local ScreenGui, PropFrame

-- 4. SISTEMA DE GIZMOS (CORRIGIDO)
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

            -- === FERRAMENTA MOVE ===
            if EditorSettings.ToolMode == "Move" then
                local handles = Instance.new("Handles")
                handles.Style = Enum.HandlesStyle.Resize -- Usamos visual de setas
                handles.Adornee = part; handles.Color3 = Color3.fromRGB(255, 255, 0); handles.Parent = ScreenGui
                
                handles.MouseDrag:Connect(function(face, distance)
                    local delta = distance
                    if EditorSettings.SnapEnabled then delta = math.floor(distance / EditorSettings.SnapMove) * EditorSettings.SnapMove end
                    
                    local cf = part.CFrame
                    -- Move na direção da face relativa
                    if face == Enum.NormalId.Right then part.CFrame = cf + (cf.RightVector * delta)
                    elseif face == Enum.NormalId.Left then part.CFrame = cf - (cf.RightVector * delta)
                    elseif face == Enum.NormalId.Top then part.CFrame = cf + (cf.UpVector * delta)
                    elseif face == Enum.NormalId.Bottom then part.CFrame = cf - (cf.UpVector * delta)
                    elseif face == Enum.NormalId.Front then part.CFrame = cf + (cf.LookVector * delta)
                    elseif face == Enum.NormalId.Back then part.CFrame = cf - (cf.LookVector * delta) end
                    
                    UpdatePropertiesUI(part)
                end)
                table.insert(Gizmos, handles)
                
            -- === FERRAMENTA ROTATE ===
            elseif EditorSettings.ToolMode == "Rotate" then
                local arc = Instance.new("ArcHandles")
                arc.Adornee = part; arc.Parent = ScreenGui
                
                arc.MouseDrag:Connect(function(axis, relativeAngle)
                    local rot = relativeAngle
                    if EditorSettings.SnapEnabled then rot = math.floor(relativeAngle / math.rad(EditorSettings.SnapRotate)) * math.rad(EditorSettings.SnapRotate) end
                    
                    if axis == Enum.Axis.X then part.CFrame = part.CFrame * CFrame.Angles(rot, 0, 0)
                    elseif axis == Enum.Axis.Y then part.CFrame = part.CFrame * CFrame.Angles(0, rot, 0)
                    elseif axis == Enum.Axis.Z then part.CFrame = part.CFrame * CFrame.Angles(0, 0, rot) end
                    UpdatePropertiesUI(part)
                end)
                table.insert(Gizmos, arc)
            
            -- === FERRAMENTA RESIZE (CORRIGIDA) ===
            elseif EditorSettings.ToolMode == "Resize" then
                local handles = Instance.new("Handles")
                handles.Style = Enum.HandlesStyle.Resize
                handles.Adornee = part; handles.Color3 = Color3.fromRGB(0, 100, 255); handles.Parent = ScreenGui
                
                -- Armazena estado inicial ao clicar
                handles.MouseButton1Down:Connect(function()
                    OriginalSize = part.Size
                    OriginalCFrame = part.CFrame
                end)

                handles.MouseDrag:Connect(function(face, distance)
                    -- Aplica snap se necessário
                    local d = distance
                    if EditorSettings.SnapEnabled then d = math.floor(d / EditorSettings.SnapMove) * EditorSettings.SnapMove end
                    
                    -- Vetores de Direção Baseados na Face
                    local sizeChange = Vector3.new(0,0,0)
                    local posChange = Vector3.new(0,0,0)
                    
                    -- Lógica: Aumenta o tamanho E move o centro metade da distância para manter o outro lado fixo
                    if face == Enum.NormalId.Right then -- X+
                        sizeChange = Vector3.new(d, 0, 0)
                        posChange = OriginalCFrame.RightVector * (d / 2)
                    elseif face == Enum.NormalId.Left then -- X-
                        sizeChange = Vector3.new(d, 0, 0)
                        posChange = OriginalCFrame.RightVector * (-d / 2)
                    elseif face == Enum.NormalId.Top then -- Y+
                        sizeChange = Vector3.new(0, d, 0)
                        posChange = OriginalCFrame.UpVector * (d / 2)
                    elseif face == Enum.NormalId.Bottom then -- Y-
                        sizeChange = Vector3.new(0, d, 0)
                        posChange = OriginalCFrame.UpVector * (-d / 2)
                    elseif face == Enum.NormalId.Front then -- Z- (Roblox Front é -Z)
                         -- No resize handle, front usually expands Z axis. 
                         -- Vamos simplificar: Front aumenta Z
                         sizeChange = Vector3.new(0, 0, d)
                         posChange = OriginalCFrame.LookVector * (d / 2)
                    elseif face == Enum.NormalId.Back then -- Z+
                         sizeChange = Vector3.new(0, 0, d)
                         posChange = OriginalCFrame.LookVector * (-d / 2)
                    end

                    -- Aplica Mudanças (Resetando ao original + delta para evitar erro de acumulação)
                    -- Nota: Handles acumulam 'distance' desde o clique inicial, então usamos OriginalSize
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
    
    -- Verifica se já está selecionado
    local found = false
    for i, v in ipairs(SelectedObjects) do 
        if v == obj then 
            if multi then table.remove(SelectedObjects, i) end -- Deseleciona se multi
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
ScreenGui.Name = "GabotriWorldEditor_v1.2"
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

-- Função Update UI
function UpdatePropertiesUI(obj)
    if not obj then return end
    InpName.Text = obj.Name
    if obj:IsA("BasePart") then
        InpPos.Text = string.format("%.1f, %.1f, %.1f", obj.Position.X, obj.Position.Y, obj.Position.Z)
        InpSize.Text = string.format("%.1f, %.1f, %.1f", obj.Size.X, obj.Size.Y, obj.Size.Z)
        InpTransp.Text = string.format("%.1f", obj.Transparency)
    end
end

-- Inputs Logic
InpPos.FocusLost:Connect(function()
    if #SelectedObjects > 0 then local x,y,z = InpPos.Text:match("([^,]+),%s*([^,]+),%s*([^,]+)")
        if x and SelectedObjects[1]:IsA("BasePart") then SelectedObjects[1].Position = Vector3.new(x,y,z); UpdateGizmos() end end
end)
InpSize.FocusLost:Connect(function()
    if #SelectedObjects > 0 then local x,y,z = InpSize.Text:match("([^,]+),%s*([^,]+),%s*([^,]+)")
        if x and SelectedObjects[1]:IsA("BasePart") then SelectedObjects[1].Size = Vector3.new(x,y,z); UpdateGizmos() end end
end)

-- TOOLBAR
local ToolFrame = Instance.new("Frame", ScreenGui)
ToolFrame.Name = "Tools"; ToolFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35); ToolFrame.Position = UDim2.new(0.4, 0, 0.02, 0); ToolFrame.Size = UDim2.new(0, 320, 0, 40)
Instance.new("UICorner", ToolFrame).CornerRadius = UDim.new(0, 6)
local TL = Instance.new("UIListLayout", ToolFrame); TL.FillDirection = Enum.FillDirection.Horizontal; TL.Padding = UDim.new(0, 5); TL.HorizontalAlignment = Enum.HorizontalAlignment.Center; TL.VerticalAlignment = Enum.VerticalAlignment.Center

local function CreateToolBtn(text, mode)
    local btn = Instance.new("TextButton", ToolFrame); btn.Size = UDim2.new(0, 70, 0, 30); btn.Text = text; btn.BackgroundColor3 = Color3.fromRGB(50, 50, 55); btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Font = Enum.Font.GothamBold; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(function() EditorSettings.ToolMode = mode; UpdateGizmos() end)
    return btn
end

CreateToolBtn("Move", "Move")
CreateToolBtn("Rotate", "Rotate")
CreateToolBtn("Resize", "Resize")

-- 7. INPUTS E LOGICA
--========================================================================
UserInputService.InputBegan:Connect(function(input, gp)
    -- Insert: Toggle
    if input.KeyCode == Enum.KeyCode.Insert then
        EditorSettings.Enabled = not EditorSettings.Enabled
        ScreenGui.Enabled = EditorSettings.Enabled
        UpdateGizmos()
    end

    if not EditorSettings.Enabled then return end
    if gp then return end

    -- Click: Select
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if Mouse.Target then
            SelectObject(Mouse.Target, UserInputService:IsKeyDown(Enum.KeyCode.LeftControl))
        else
            if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then SelectObject(nil) end
        end
    end

    -- [FIX] Backspace: Delete (Para não conflitar com o Chassi)
    if input.KeyCode == Enum.KeyCode.Backspace then
        for _, o in pairs(SelectedObjects) do o:Destroy() end
        SelectObject(nil)
        LogarEvento("EDITOR", "Objetos deletados com Backspace.")
    end
    
    -- Ctrl+D: Duplicate
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
    pCreate("SecEditor", TabMundo, "CreateSection", "World Editor v1.2 (Fix)", "Left")
    pCreate("ToggleEdit", TabMundo, "CreateToggle", {
        Name = "Ativar Editor [Insert]", CurrentValue = false,
        Callback = function(v) EditorSettings.Enabled = v; ScreenGui.Enabled = v; UpdateGizmos() end
    })
    pCreate("SliderSnap", TabMundo, "CreateSlider", {
        Name = "Snap", Range = {0, 10}, Increment = 1, CurrentValue = 1,
        Callback = function(v) EditorSettings.SnapMove = v; EditorSettings.SnapEnabled = (v > 0) end
    })
end

LogarEvento("SUCESSO", "Módulo World Editor v1.2 (Resize Fix) carregado.")