--[==[
    MÓDULO: ESP Master v2.0 (Ultimate)
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: Pacote visual completo com Radar, Loot, Predição e Filtros.
    
    NOVAS FUNCIONALIDADES v2.0:
    - [NOVO] Team Check (Filtro de Aliados).
    - [NOVO] Item ESP (Mostra ferramentas/armas no chão).
    - [NOVO] Movement Prediction (Ponto branco de previsão de tiro).
    - [NOVO] Radar HUD (Pontos ao redor da mira indicando inimigos).
    - [NOVO] Armor/Shield Check (Tenta ler atributos de armadura).
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

-- 3. CONFIGURAÇÕES GLOBAIS
local ESP_Settings = {
    MasterSwitch = true,
    
    -- Cores
    ColorVisible = Color3.fromRGB(0, 255, 0),
    ColorHidden = Color3.fromRGB(255, 0, 0),
    ColorTeam = Color3.fromRGB(0, 170, 255),
    ColorItem = Color3.fromRGB(255, 255, 0),
    
    -- Jogadores (Players)
    Box = false,
    Name = true,
    Health = true,
    Armor = true,      -- [NOVO]
    Weapon = true,
    Distance = true,
    Tracers = true,    -- (Do Player)
    Skeleton = true,
    HeadDot = false,
    Charm = true,
    Prediction = true, -- [NOVO] Ponto de Predição
    
    -- Filtros e Radar
    VisCheck = true,
    TeamCheck = false, -- [NOVO] Se true, esconde aliados
    RadarHUD = true,   -- [NOVO] Indicadores ao redor da mira
    RadarRadius = 100, -- Distancia do centro da tela
    
    -- Loot (Itens)
    ShowItems = true,  -- [NOVO]
    ItemDist = 150     -- Distancia max para itens
}

-- Cache
local ESP_Cache = {}
local Item_Cache = {}

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
        Armor = NewDrawing("Text"), -- [NOVO]
        HealthBarOutline = NewDrawing("Square"),
        HealthBar = NewDrawing("Square"),
        HeadDot = NewDrawing("Circle"),
        PredictionDot = NewDrawing("Circle"), -- [NOVO]
        RadarDot = NewDrawing("Square"),      -- [NOVO] Para o Radar HUD
        Skeleton = {},
        Highlight = nil 
    }
    
    -- Configurações de Texto
    Objects.Name.Center = true; Objects.Name.Outline = true; Objects.Name.Size = 14
    Objects.Distance.Center = true; Objects.Distance.Outline = true; Objects.Distance.Size = 12
    Objects.Weapon.Center = true; Objects.Weapon.Outline = true; Objects.Weapon.Size = 12
    Objects.Armor.Center = true; Objects.Armor.Outline = true; Objects.Armor.Size = 12; Objects.Armor.Color = Color3.fromRGB(0, 200, 255)
    
    -- Configurações de Formas
    Objects.Box.Thickness = 1; Objects.Box.Filled = false
    Objects.HealthBarOutline.Thickness = 1; Objects.HealthBarOutline.Filled = false
    Objects.HealthBar.Filled = true
    Objects.PredictionDot.Radius = 3; Objects.PredictionDot.Filled = true; Objects.PredictionDot.Color = Color3.fromRGB(255, 255, 255)
    Objects.RadarDot.Size = Vector2.new(4, 4); Objects.RadarDot.Filled = true; Objects.RadarDot.Color = Color3.fromRGB(255, 0, 0)
    
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

-- 5. LÓGICA DE ITENS (LOOT)
--========================================================================
-- Atualiza a lista de itens a cada 1 segundo para não lagar
task.spawn(function()
    while true do
        if ESP_Settings.ShowItems and ESP_Settings.MasterSwitch then
            for _, obj in pairs(Item_Cache) do obj:Remove() end
            Item_Cache = {}
            
            -- Procura apenas no Workspace direto para evitar crash em jogos grandes
            for _, item in pairs(Workspace:GetChildren()) do
                if item:IsA("Tool") and item:FindFirstChild("Handle") then
                    local dist = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) 
                                 and (LocalPlayer.Character.HumanoidRootPart.Position - item.Handle.Position).Magnitude or 9999
                    
                    if dist < ESP_Settings.ItemDist then
                        local draw = NewDrawing("Text")
                        draw.Text = item.Name .. " [" .. math.floor(dist) .. "]"
                        draw.Center = true; draw.Outline = true; draw.Size = 13
                        draw.Color = ESP_Settings.ColorItem
                        draw.Visible = false
                        table.insert(Item_Cache, {Draw = draw, Item = item})
                    end
                end
            end
        else
             for _, obj in pairs(Item_Cache) do obj.Draw.Visible = false end
        end
        wait(1)
    end
end)

local function UpdateItems()
    for _, entry in pairs(Item_Cache) do
        if entry.Item and entry.Item:FindFirstChild("Handle") then
            local vec, vis = Camera:WorldToViewportPoint(entry.Item.Handle.Position)
            if vis and ESP_Settings.ShowItems and ESP_Settings.MasterSwitch then
                entry.Draw.Visible = true
                entry.Draw.Position = Vector2.new(vec.X, vec.Y)
            else
                entry.Draw.Visible = false
            end
        else
            entry.Draw.Visible = false
        end
    end
end

-- 6. LÓGICA PRINCIPAL (UPDATE PLAYER LOOP)
--========================================================================
local function IsEnemy(player)
    if not ESP_Settings.TeamCheck then return true end -- Se filtro desligado, todos são "inimigos"
    if player.Team == nil then return true end -- Sem time = inimigo
    return player.Team ~= LocalPlayer.Team
end

local function GetColor(playerChar, part, isEnemy)
    if not isEnemy then return ESP_Settings.ColorTeam end
    
    if ESP_Settings.VisCheck then
        local origin = Camera.CFrame.Position
        local direction = (part.Position - origin)
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {LocalPlayer.Character, playerChar, Camera}
        params.FilterType = Enum.RaycastFilterType.Exclude
        local result = Workspace:Raycast(origin, direction, params)
        if result then return ESP_Settings.ColorHidden else return ESP_Settings.ColorVisible end
    else
        return ESP_Settings.ColorVisible
    end
end

-- Atualizador de Esqueleto (Mantido da v1.1)
local function UpdateSkeleton(player, Character, color, objects)
    local RigType = (Character:FindFirstChild("UpperTorso")) and "R15" or "R6"
    local Connections = {}
    if RigType == "R15" then
        Connections = {{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"}}
    else
        Connections = {{"Head","Torso"},{"Torso","Left Leg"},{"Torso","Right Leg"},{"Torso","Left Arm"},{"Torso","Right Arm"}}
    end

    local cache = objects.Skeleton
    for i = 1, #Connections do
        if not cache[i] then cache[i] = NewDrawing("Line") end
        local line = cache[i]
        local partA = Character:FindFirstChild(Connections[i][1])
        local partB = Character:FindFirstChild(Connections[i][2])
        
        if partA and partB and ESP_Settings.Skeleton and ESP_Settings.MasterSwitch then
            local vecA, visA = Camera:WorldToViewportPoint(partA.Position)
            local vecB, visB = Camera:WorldToViewportPoint(partB.Position)
            if visA and visB then
                line.Visible = true; line.From = Vector2.new(vecA.X, vecA.Y); line.To = Vector2.new(vecB.X, vecB.Y)
                line.Color = color; line.Thickness = 1
            else line.Visible = false end
        else line.Visible = false end
    end
end

RunService.RenderStepped:Connect(function()
    UpdateItems() -- Atualiza loot
    
    -- Origem Tracer (Seu Personagem)
    local myTracerOrigin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local myRoot = nil
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        myRoot = LocalPlayer.Character.HumanoidRootPart
        local myPos, myVis = Camera:WorldToViewportPoint(myRoot.Position)
        myTracerOrigin = Vector2.new(myPos.X, myPos.Y)
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not ESP_Cache[player] then ESP_Cache[player] = CreateESPObject(player) end
            
            local objs = ESP_Cache[player]
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            local isEnemy = IsEnemy(player)
            
            -- Lógica "Anti-Overload" (Se não for inimigo e TeamCheck ligado, oculta tudo)
            local shouldDraw = ESP_Settings.MasterSwitch and char and hrp and hum and hum.Health > 0
            if ESP_Settings.TeamCheck and not isEnemy then shouldDraw = false end

            if shouldDraw then
                local vector, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                local mainColor = GetColor(char, hrp, isEnemy)
                
                -- --- RADAR HUD (Funciona mesmo fora da tela) ---
                if ESP_Settings.RadarHUD and myRoot then
                    local lookVec = Camera.CFrame.LookVector
                    local targetDir = (hrp.Position - myRoot.Position).Unit
                    -- Matemágica de ângulo relativa à câmera
                    local angle = math.atan2(targetDir.X, targetDir.Z) - math.atan2(lookVec.X, lookVec.Z)
                    
                    -- Projeta no círculo ao redor da tela (Radius)
                    local radarX = (Camera.ViewportSize.X / 2) + math.sin(angle) * ESP_Settings.RadarRadius
                    local radarY = (Camera.ViewportSize.Y / 2) + math.cos(angle) * ESP_Settings.RadarRadius
                    
                    objs.RadarDot.Visible = true
                    objs.RadarDot.Position = Vector2.new(radarX, radarY)
                    objs.RadarDot.Color = isEnemy and Color3.new(1,0,0) or Color3.new(0,1,1)
                else
                    objs.RadarDot.Visible = false
                end
                -- -------------------------------------------

                if onScreen then
                    local scale = 1000 / dist
                    local width, height = 3 * scale, 5 * scale
                    local x, y = vector.X - width / 2, vector.Y - height / 2
                    
                    -- BOX
                    if ESP_Settings.Box then
                        objs.Box.Visible = true; objs.Box.Size = Vector2.new(width, height)
                        objs.Box.Position = Vector2.new(x, y); objs.Box.Color = mainColor
                    else objs.Box.Visible = false end
                    
                    -- TRACER
                    if ESP_Settings.Tracers then
                        objs.Tracer.Visible = true; objs.Tracer.From = myTracerOrigin
                        objs.Tracer.To = Vector2.new(vector.X, vector.Y); objs.Tracer.Color = mainColor
                    else objs.Tracer.Visible = false end

                    -- NAME
                    if ESP_Settings.Name then
                        objs.Name.Visible = true; objs.Name.Text = player.Name
                        objs.Name.Position = Vector2.new(vector.X, y - 16); objs.Name.Color = mainColor
                    else objs.Name.Visible = false end
                    
                    -- PREDICTION DOT (Cálculo de Movimento Futuro)
                    if ESP_Settings.Prediction then
                        -- Predição Simples: Posição + (Velocidade * Ping/Latencia aproximada)
                        local predPos = hrp.Position + (hrp.Velocity * 0.165) 
                        local predVec, predVis = Camera:WorldToViewportPoint(predPos)
                        if predVis then
                            objs.PredictionDot.Visible = true
                            objs.PredictionDot.Position = Vector2.new(predVec.X, predVec.Y)
                        else objs.PredictionDot.Visible = false end
                    else objs.PredictionDot.Visible = false end

                    -- ARMOR / SHIELD (Texto extra)
                    if ESP_Settings.Armor then
                        local armorVal = char:GetAttribute("Armor") or char:GetAttribute("Shield") or 0
                        if armorVal > 0 then
                            objs.Armor.Visible = true
                            objs.Armor.Text = "Shield: " .. tostring(armorVal)
                            objs.Armor.Position = Vector2.new(vector.X, y - 28) -- Acima do nome
                        else objs.Armor.Visible = false end
                    else objs.Armor.Visible = false end

                    -- HEALTH
                    if ESP_Settings.Health then
                        local hpPct = hum.Health / hum.MaxHealth
                        local barH = height * hpPct
                        objs.HealthBarOutline.Visible = true; objs.HealthBarOutline.Size = Vector2.new(4, height); objs.HealthBarOutline.Position = Vector2.new(x - 6, y)
                        objs.HealthBar.Visible = true; objs.HealthBar.Size = Vector2.new(2, barH); objs.HealthBar.Position = Vector2.new(x - 5, y + (height - barH))
                        objs.HealthBar.Color = Color3.fromHSV(hpPct * 0.3, 1, 1)
                    else objs.HealthBarOutline.Visible = false; objs.HealthBar.Visible = false end
                    
                    -- SKELETON
                    if ESP_Settings.Skeleton then UpdateSkeleton(player, char, mainColor, objs)
                    else for _, l in pairs(objs.Skeleton) do l.Visible = false end end
                    
                    -- CHARM (HIGHLIGHT)
                    if ESP_Settings.Charm then
                        if not objs.Highlight or objs.Highlight.Parent ~= char then
                            if objs.Highlight then objs.Highlight:Destroy() end
                            local hl = Instance.new("Highlight")
                            hl.Name = "GabotriCharm"; hl.FillColor = mainColor
                            hl.OutlineColor = Color3.new(1,1,1); hl.FillTransparency = 0.5
                            hl.OutlineTransparency = 0; hl.Adornee = char; hl.Parent = char
                            objs.Highlight = hl
                        else objs.Highlight.FillColor = mainColor; objs.Highlight.Enabled = true end
                    else if objs.Highlight then objs.Highlight.Enabled = false end end
                    
                    -- DISTANCE & WEAPON (Posicionamento)
                    if ESP_Settings.Distance then
                        objs.Distance.Visible = true; objs.Distance.Text = string.format("[%d]", math.floor(dist))
                        objs.Distance.Position = Vector2.new(vector.X, y + height + 2)
                    else objs.Distance.Visible = false end
                    
                    if ESP_Settings.Weapon then
                        local tool = char:FindFirstChildWhichIsA("Tool")
                        if tool then
                            objs.Weapon.Visible = true; objs.Weapon.Text = tool.Name
                            objs.Weapon.Position = Vector2.new(vector.X, y + height + 15)
                        else objs.Weapon.Visible = false end
                    else objs.Weapon.Visible = false end
                    
                    -- HEAD DOT
                    if ESP_Settings.HeadDot then
                        local head = char:FindFirstChild("Head")
                        if head then
                            local hv, hvis = Camera:WorldToViewportPoint(head.Position)
                            if hvis then objs.HeadDot.Visible = true; objs.HeadDot.Position = Vector2.new(hv.X, hv.Y); objs.HeadDot.Color = mainColor
                            else objs.HeadDot.Visible = false end
                        end
                    else objs.HeadDot.Visible = false end

                else
                    -- Offscreen: Esconde tudo (menos Radar)
                    for k, obj in pairs(objs) do
                        if k == "Skeleton" then for _, l in pairs(obj) do l.Visible = false end
                        elseif k == "Highlight" and obj then obj.Enabled = false
                        elseif k ~= "RadarDot" and k ~= "Skeleton" and k ~= "Highlight" then obj.Visible = false end
                    end
                end
            else
                -- Hide All
                if objs then
                    for k, obj in pairs(objs) do
                        if k == "Skeleton" then for _, l in pairs(obj) do l.Visible = false end
                        elseif k == "Highlight" and obj then obj.Enabled = false
                        elseif k ~= "Skeleton" and k ~= "Highlight" then obj.Visible = false end
                    end
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) RemoveESP(p) end)

-- 7. INTERFACE GRÁFICA (Tab Mundo)
--========================================================================
if TabMundo then
    pCreate("SecESP", TabMundo, "CreateSection", "ESP Ultimate v2.0", "Right")
    
    pCreate("ToggleESPMaster", TabMundo, "CreateToggle", {
        Name = "Master Switch", CurrentValue = ESP_Settings.MasterSwitch,
        Callback = function(Val) ESP_Settings.MasterSwitch = Val end
    })
    
    -- FILTROS
    pCreate("ToggleTeam", TabMundo, "CreateToggle", { Name = "Team Check (Ignorar Aliados)", CurrentValue = ESP_Settings.TeamCheck, Callback = function(v) ESP_Settings.TeamCheck = v end })
    pCreate("ToggleVis", TabMundo, "CreateToggle", { Name = "Vis Check (Parede Vermelha)", CurrentValue = ESP_Settings.VisCheck, Callback = function(v) ESP_Settings.VisCheck = v end })
    
    -- ITENS E RADAR
    pCreate("ToggleItems", TabMundo, "CreateToggle", { Name = "Item ESP (Ferramentas)", CurrentValue = ESP_Settings.ShowItems, Callback = function(v) ESP_Settings.ShowItems = v end })
    pCreate("ToggleRadar", TabMundo, "CreateToggle", { Name = "Radar HUD (Mira)", CurrentValue = ESP_Settings.RadarHUD, Callback = function(v) ESP_Settings.RadarHUD = v end })
    pCreate("TogglePred", TabMundo, "CreateToggle", { Name = "Movement Prediction (Dot)", CurrentValue = ESP_Settings.Prediction, Callback = function(v) ESP_Settings.Prediction = v end })

    -- VISUAIS PADRÃO
    pCreate("ToggleBox", TabMundo, "CreateToggle", { Name = "Box 2D", CurrentValue = ESP_Settings.Box, Callback = function(v) ESP_Settings.Box = v end })
    pCreate("ToggleName", TabMundo, "CreateToggle", { Name = "Name & Armor", CurrentValue = ESP_Settings.Name, Callback = function(v) ESP_Settings.Name = v; ESP_Settings.Armor = v end })
    pCreate("ToggleTracer", TabMundo, "CreateToggle", { Name = "Tracers (Player)", CurrentValue = ESP_Settings.Tracers, Callback = function(v) ESP_Settings.Tracers = v end })
    pCreate("ToggleSkel", TabMundo, "CreateToggle", { Name = "Skeleton", CurrentValue = ESP_Settings.Skeleton, Callback = function(v) ESP_Settings.Skeleton = v end })
    pCreate("ToggleCharm", TabMundo, "CreateToggle", { Name = "Chams (Glow)", CurrentValue = ESP_Settings.Charm, Callback = function(v) ESP_Settings.Charm = v end })

    LogarEvento("SUCESSO", "Módulo ESP Ultimate v2.0 carregado.")
else
    LogarEvento("ERRO", "TabMundo não encontrada.")
end