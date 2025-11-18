--[==[
    MÓDULO: ESP Master (Visuals) v1.1
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO:
    - [MUDANÇA] Tracers agora saem do Player (HumanoidRootPart) e não da base da tela.
    - [MUDANÇA] Padrões: Box=OFF, HeadDot=OFF, Todo o resto=ON (Ao iniciar).
]==]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO ESP: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. VARIÁVEIS E SERVIÇOS
local LogarEvento = Chassi.LogarEvento
local pCreate = Chassi.pCreate
local TabMundo = Chassi.Abas.Mundo 

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- 3. CONFIGURAÇÕES (PADRÕES ALTERADOS v1.1)
local ESP_Settings = {
    MasterSwitch = true, -- Já começa ligado
    -- Cores
    ColorVisible = Color3.fromRGB(0, 255, 0),
    ColorHidden = Color3.fromRGB(255, 0, 0),
    -- Toggles (Configurados conforme pedido)
    Box = false,        -- Pediu desligado
    HeadDot = false,    -- Pediu desligado
    
    -- "O Resto Ligado"
    Name = true,
    Health = true,
    Weapon = true,
    Distance = true,
    Tracers = true,
    Skeleton = true,
    Charm = true,
    VisCheck = true
}

-- Cache de Objetos de Desenho
local ESP_Cache = {}

-- 4. FUNÇÕES DE DESENHO (DRAWING API)
--========================================================================
local function NewDrawing(type)
    local obj = Drawing.new(type)
    obj.Visible = false
    return obj
end

local function CreateESPObject(player)
    local Objects = {
        Box = NewDrawing("Square"),
        Tracer = NewDrawing("Line"),
        Name = NewDrawing("Text"),
        Distance = NewDrawing("Text"),
        Weapon = NewDrawing("Text"),
        HealthBarOutline = NewDrawing("Square"),
        HealthBar = NewDrawing("Square"),
        HeadDot = NewDrawing("Circle"),
        Skeleton = {},
        Highlight = nil 
    }
    
    -- Configurações Iniciais
    Objects.Name.Center = true; Objects.Name.Outline = true; Objects.Name.Size = 14
    Objects.Distance.Center = true; Objects.Distance.Outline = true; Objects.Distance.Size = 12
    Objects.Weapon.Center = true; Objects.Weapon.Outline = true; Objects.Weapon.Size = 12
    
    Objects.Box.Thickness = 1; Objects.Box.Filled = false
    Objects.HealthBarOutline.Thickness = 1; Objects.HealthBarOutline.Filled = false
    Objects.HealthBar.Filled = true
    
    return Objects
end

local function RemoveESP(player)
    if ESP_Cache[player] then
        for key, obj in pairs(ESP_Cache[player]) do
            if key == "Skeleton" then
                for _, line in pairs(obj) do line:Remove() end
            elseif key == "Highlight" then
                if obj then obj:Destroy() end
            elseif obj and obj.Remove then
                obj:Remove()
            end
        end
        ESP_Cache[player] = nil
    end
end

-- 5. LÓGICA PRINCIPAL (UPDATE LOOP)
--========================================================================
local function GetColor(playerChar, part)
    if not ESP_Settings.VisCheck then return ESP_Settings.ColorVisible end
    
    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character, playerChar, Camera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = Workspace:Raycast(origin, direction, params)
    if result then return ESP_Settings.ColorHidden else return ESP_Settings.ColorVisible end
end

local function UpdateSkeleton(player, Character, color)
    local RigType = (Character:FindFirstChild("UpperTorso")) and "R15" or "R6"
    local Connections = {}
    
    if RigType == "R15" then
        Connections = {
            {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"}, {"LowerTorso", "LeftUpperLeg"},
            {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
            {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}, {"UpperTorso", "LeftUpperArm"},
            {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
            {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"}
        }
    else
        Connections = {
            {"Head", "Torso"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
            {"Torso", "Left Arm"}, {"Torso", "Right Arm"}
        }
    end

    local cache = ESP_Cache[player].Skeleton
    for i = 1, #Connections do
        if not cache[i] then cache[i] = NewDrawing("Line") end
        local line = cache[i]
        local partA = Character:FindFirstChild(Connections[i][1])
        local partB = Character:FindFirstChild(Connections[i][2])
        
        if partA and partB and ESP_Settings.Skeleton and ESP_Settings.MasterSwitch then
            local vecA, visA = Camera:WorldToViewportPoint(partA.Position)
            local vecB, visB = Camera:WorldToViewportPoint(partB.Position)
            
            if visA and visB then
                line.Visible = true
                line.From = Vector2.new(vecA.X, vecA.Y)
                line.To = Vector2.new(vecB.X, vecB.Y)
                line.Color = color
                line.Thickness = 1
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
end

RunService.RenderStepped:Connect(function()
    -- Pre-calcula a posição do LocalPlayer para os Tracers
    local myTracerOrigin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) -- Padrão Centro
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local myPos, myVis = Camera:WorldToViewportPoint(LocalPlayer.Character.HumanoidRootPart.Position)
        myTracerOrigin = Vector2.new(myPos.X, myPos.Y)
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not ESP_Cache[player] then ESP_Cache[player] = CreateESPObject(player) end
            
            local objs = ESP_Cache[player]
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            
            if ESP_Settings.MasterSwitch and char and hrp and hum and hum.Health > 0 then
                local vector, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                local mainColor = GetColor(char, hrp)
                
                if onScreen then
                    local scaleFactor = 1000 / dist
                    local width = 3 * scaleFactor
                    local height = 5 * scaleFactor
                    local x = vector.X - width / 2
                    local y = vector.Y - height / 2
                    
                    -- 1. BOX
                    if ESP_Settings.Box then
                        objs.Box.Visible = true
                        objs.Box.Size = Vector2.new(width, height)
                        objs.Box.Position = Vector2.new(x, y)
                        objs.Box.Color = mainColor
                    else objs.Box.Visible = false end
                    
                    -- 2. TRACERS (Do Player até o Inimigo)
                    if ESP_Settings.Tracers then
                        objs.Tracer.Visible = true
                        objs.Tracer.From = myTracerOrigin -- Origem calculada acima (No LocalPlayer)
                        objs.Tracer.To = Vector2.new(vector.X, vector.Y) -- Centro do inimigo
                        objs.Tracer.Color = mainColor
                    else objs.Tracer.Visible = false end

                    -- 3. NAME
                    if ESP_Settings.Name then
                        objs.Name.Visible = true
                        objs.Name.Text = player.Name
                        objs.Name.Position = Vector2.new(vector.X, y - 16)
                        objs.Name.Color = mainColor
                    else objs.Name.Visible = false end
                    
                    -- 4. DISTANCE
                    if ESP_Settings.Distance then
                        objs.Distance.Visible = true
                        objs.Distance.Text = string.format("[%d]", math.floor(dist))
                        objs.Distance.Position = Vector2.new(vector.X, y + height + 2)
                        objs.Distance.Color = Color3.new(1, 1, 1)
                    else objs.Distance.Visible = false end
                    
                    -- 5. WEAPON
                    if ESP_Settings.Weapon then
                        local tool = char:FindFirstChildWhichIsA("Tool")
                        if tool then
                            objs.Weapon.Visible = true
                            objs.Weapon.Text = tool.Name
                            objs.Weapon.Position = Vector2.new(vector.X, y + height + 15)
                            objs.Weapon.Color = Color3.new(0.8, 0.8, 1)
                        else objs.Weapon.Visible = false end
                    else objs.Weapon.Visible = false end

                    -- 6. HEALTH BAR
                    if ESP_Settings.Health then
                        local healthPercent = hum.Health / hum.MaxHealth
                        local barHeight = height * healthPercent
                        objs.HealthBarOutline.Visible = true
                        objs.HealthBarOutline.Size = Vector2.new(4, height)
                        objs.HealthBarOutline.Position = Vector2.new(x - 6, y)
                        objs.HealthBar.Visible = true
                        objs.HealthBar.Size = Vector2.new(2, barHeight)
                        objs.HealthBar.Position = Vector2.new(x - 5, y + (height - barHeight))
                        objs.HealthBar.Color = Color3.fromHSV(healthPercent * 0.3, 1, 1)
                    else
                        objs.HealthBarOutline.Visible = false; objs.HealthBar.Visible = false
                    end
                    
                    -- 7. HEAD DOT
                    if ESP_Settings.HeadDot then
                        local head = char:FindFirstChild("Head")
                        if head then
                            local headVec, headVis = Camera:WorldToViewportPoint(head.Position)
                            if headVis then
                                objs.HeadDot.Visible = true
                                objs.HeadDot.Position = Vector2.new(headVec.X, headVec.Y)
                                objs.HeadDot.Radius = 4
                                objs.HeadDot.Filled = true
                                objs.HeadDot.Color = mainColor
                            end
                        end
                    else objs.HeadDot.Visible = false end
                    
                    -- 8. SKELETON
                    if ESP_Settings.Skeleton then
                        UpdateSkeleton(player, char, mainColor)
                    else
                        for _, line in pairs(objs.Skeleton) do line.Visible = false end
                    end
                    
                    -- 9. CHARM (Highlight)
                    if ESP_Settings.Charm then
                        if not objs.Highlight or objs.Highlight.Parent ~= char then
                            if objs.Highlight then objs.Highlight:Destroy() end
                            local hl = Instance.new("Highlight")
                            hl.Name = "GabotriCharm"
                            hl.FillColor = mainColor
                            hl.OutlineColor = Color3.new(1,1,1)
                            hl.FillTransparency = 0.5
                            hl.OutlineTransparency = 0
                            hl.Adornee = char
                            hl.Parent = char
                            objs.Highlight = hl
                        else
                            objs.Highlight.FillColor = mainColor
                            objs.Highlight.Enabled = true
                        end
                    else
                        if objs.Highlight then objs.Highlight.Enabled = false end
                    end
                else
                    -- Esconde tudo se fora da tela
                    for k, obj in pairs(objs) do
                        if k == "Skeleton" then for _, line in pairs(obj) do line.Visible = false end
                        elseif k == "Highlight" and obj then obj.Enabled = false
                        elseif k ~= "Skeleton" and k ~= "Highlight" then obj.Visible = false end
                    end
                end
            else
                -- Player Morto/Invalido
                if objs then
                    for k, obj in pairs(objs) do
                        if k == "Skeleton" then for _, line in pairs(obj) do line.Visible = false end
                        elseif k == "Highlight" and obj then obj.Enabled = false
                        elseif k ~= "Skeleton" and k ~= "Highlight" then obj.Visible = false end
                    end
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) RemoveESP(p) end)

-- 6. INTERFACE GRÁFICA (Tab Mundo)
--========================================================================
if TabMundo then
    pCreate("SecESP", TabMundo, "CreateSection", "Visuals / ESP v1.1", "Right")
    
    pCreate("ToggleESPMaster", TabMundo, "CreateToggle", {
        Name = "Ativar ESP (Master Switch)",
        CurrentValue = ESP_Settings.MasterSwitch,
        Callback = function(Val) ESP_Settings.MasterSwitch = Val end
    })
    
    -- Opções Visuais
    pCreate("ToggleBox", TabMundo, "CreateToggle", { Name = "Box (Caixa 2D)", CurrentValue = ESP_Settings.Box, Callback = function(v) ESP_Settings.Box = v end })
    pCreate("ToggleName", TabMundo, "CreateToggle", { Name = "Names (Nomes)", CurrentValue = ESP_Settings.Name, Callback = function(v) ESP_Settings.Name = v end })
    pCreate("ToggleHealth", TabMundo, "CreateToggle", { Name = "Health Bar (Vida)", CurrentValue = ESP_Settings.Health, Callback = function(v) ESP_Settings.Health = v end })
    pCreate("ToggleWeapon", TabMundo, "CreateToggle", { Name = "Weapon (Ferramenta)", CurrentValue = ESP_Settings.Weapon, Callback = function(v) ESP_Settings.Weapon = v end })
    pCreate("ToggleDist", TabMundo, "CreateToggle", { Name = "Distance (Distância)", CurrentValue = ESP_Settings.Distance, Callback = function(v) ESP_Settings.Distance = v end })
    pCreate("ToggleTracer", TabMundo, "CreateToggle", { Name = "Tracers (Linhas - Do Player)", CurrentValue = ESP_Settings.Tracers, Callback = function(v) ESP_Settings.Tracers = v end })
    pCreate("ToggleSkel", TabMundo, "CreateToggle", { Name = "Skeleton (Esqueleto)", CurrentValue = ESP_Settings.Skeleton, Callback = function(v) ESP_Settings.Skeleton = v end })
    pCreate("ToggleHead", TabMundo, "CreateToggle", { Name = "Head Dot (Ponto Cabeça)", CurrentValue = ESP_Settings.HeadDot, Callback = function(v) ESP_Settings.HeadDot = v end })
    pCreate("ToggleCharm", TabMundo, "CreateToggle", { Name = "Charm (Chams Highlight)", CurrentValue = ESP_Settings.Charm, Callback = function(v) ESP_Settings.Charm = v end })
    pCreate("ToggleVis", TabMundo, "CreateToggle", { Name = "Visibility Check (Cor)", CurrentValue = ESP_Settings.VisCheck, Callback = function(v) ESP_Settings.VisCheck = v end })

    LogarEvento("SUCESSO", "Módulo ESP Master v1.1 carregado.")
else
    LogarEvento("ERRO", "TabMundo não encontrada para o ESP.")
end