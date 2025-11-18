--[==[
    MÓDULO: Visuals Ultimate (Lighting & Environment) v1.0
    AUTOR: Sr. Gabotri (via Gemini)
    DESCRIÇÃO: 
    - Controle total de Iluminação (Fullbright, Fog, Time).
    - Modificadores de Mapa (X-Ray, Material, Skybox).
    - Otimização Visual (Remove Efeitos).
]==]

-- 1. PUXA O CHASSI
local Chassi = _G.GABOTRI_CHASSI
if not Chassi then
    warn("MÓDULO VISUALS: O Chassi Autoloader não foi encontrado.")
    return
end

-- 2. SERVIÇOS
local LogarEvento = Chassi.LogarEvento
local pCreate = Chassi.pCreate
local TabMundo = Chassi.Abas.Mundo -- Adiciona na aba Mundo

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Camera = Workspace.CurrentCamera

-- 3. CONFIGURAÇÕES & ESTADO
local VisualSettings = {
    Fullbright = false,
    NoFog = false,
    ForceTime = false,
    ClockTime = 14,
    Brightness = 2,
    UseSkybox = false,
    SkyboxID = "Clear", -- Default
    XRay = false,
    XRayTransparency = 0.5,
    MaterialOverride = "None"
}

-- Armazenamento de Originais (Backup simples)
local OriginalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows
}

local VisualLoop = nil
local SkyboxInstance = nil

-- Presets de Skybox
local Skyboxes = {
    ["Clear Sky"] = {
        SkyboxBk = "http://www.roblox.com/asset/?id=159454299",
        SkyboxDn = "http://www.roblox.com/asset/?id=159454296",
        SkyboxFt = "http://www.roblox.com/asset/?id=159454293",
        SkyboxLf = "http://www.roblox.com/asset/?id=159454286",
        SkyboxRt = "http://www.roblox.com/asset/?id=159454300",
        SkyboxUp = "http://www.roblox.com/asset/?id=159454288"
    },
    ["Purple Nebula"] = {
        SkyboxBk = "http://www.roblox.com/asset/?id=159229806",
        SkyboxDn = "http://www.roblox.com/asset/?id=159229832",
        SkyboxFt = "http://www.roblox.com/asset/?id=159229863",
        SkyboxLf = "http://www.roblox.com/asset/?id=159229884",
        SkyboxRt = "http://www.roblox.com/asset/?id=159229939",
        SkyboxUp = "http://www.roblox.com/asset/?id=159229959"
    },
    ["Dark Void"] = {
        SkyboxBk = "rbxassetid://0", SkyboxDn = "rbxassetid://0", SkyboxFt = "rbxassetid://0",
        SkyboxLf = "rbxassetid://0", SkyboxRt = "rbxassetid://0", SkyboxUp = "rbxassetid://0"
    }
}

-- 4. FUNÇÕES LÓGICAS
--========================================================================

-- Função de Loop (RenderStepped) para forçar visuais
local function UpdateVisuals()
    -- 1. Fullbright
    if VisualSettings.Fullbright then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.GlobalShadows = false
    end

    -- 2. Brightness
    if VisualSettings.Fullbright or VisualSettings.Brightness ~= OriginalLighting.Brightness then
        Lighting.Brightness = VisualSettings.Brightness
    end

    -- 3. No Fog
    if VisualSettings.NoFog then
        Lighting.FogEnd = 9e9
        Lighting.FogStart = 0
        -- Remove Atmosfera (Fog Volumétrico)
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("Atmosphere") then v:Destroy() end
        end
    end

    -- 4. Force Time
    if VisualSettings.ForceTime then
        Lighting.ClockTime = VisualSettings.ClockTime
    end
end

-- Gerenciador do Loop
local function ToggleLoop(state)
    if state then
        if VisualLoop then VisualLoop:Disconnect() end
        VisualLoop = RunService.RenderStepped:Connect(UpdateVisuals)
    else
        if VisualLoop then VisualLoop:Disconnect() VisualLoop = nil end
        -- Restaura básicos (não perfeito, mas ajuda)
        Lighting.Ambient = OriginalLighting.Ambient
        Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
        Lighting.GlobalShadows = OriginalLighting.GlobalShadows
        Lighting.FogEnd = OriginalLighting.FogEnd
    end
end

-- Aplicador de Skybox
local function ApplySkybox(name)
    if not VisualSettings.UseSkybox then 
        if SkyboxInstance then SkyboxInstance:Destroy() SkyboxInstance = nil end
        return 
    end
    
    local data = Skyboxes[name]
    if data then
        if not SkyboxInstance then
            SkyboxInstance = Instance.new("Sky")
            SkyboxInstance.Name = "GabotriSky"
            SkyboxInstance.Parent = Lighting
        end
        
        SkyboxInstance.SkyboxBk = data.SkyboxBk
        SkyboxInstance.SkyboxDn = data.SkyboxDn
        SkyboxInstance.SkyboxFt = data.SkyboxFt
        SkyboxInstance.SkyboxLf = data.SkyboxLf
        SkyboxInstance.SkyboxRt = data.SkyboxRt
        SkyboxInstance.SkyboxUp = data.SkyboxUp
    end
end

-- Removedor de Efeitos
local function RemoveEffects()
    local count = 0
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("PostEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("ColorCorrectionEffect") then
            v.Enabled = false
            count = count + 1
        end
    end
    LogarEvento("SUCESSO", count .. " efeitos visuais desativados.")
end

-- X-Ray (Cuidado: Pesado em mapas gigantes)
local function ApplyXRay(state)
    if state then
        LogarEvento("AVISO", "Aplicando X-Ray (Pode congelar brevemente)...")
        for _, part in pairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") and not part.Parent:FindFirstChild("Humanoid") and part.Transparency < 1 then
                -- Marca original para restaurar depois (opcional, aqui só aplica)
                if part.Transparency == 0 then -- Só altera sólidos
                    part.Transparency = VisualSettings.XRayTransparency
                    part:SetAttribute("GabotriXRay", true)
                end
            end
        end
        LogarEvento("SUCESSO", "X-Ray Aplicado.")
    else
        -- Tenta restaurar
        for _, part in pairs(Workspace:GetDescendants()) do
            if part:GetAttribute("GabotriXRay") then
                part.Transparency = 0
                part:SetAttribute("GabotriXRay", nil)
            end
        end
        LogarEvento("INFO", "X-Ray Removido.")
    end
end

-- Material Override
local function ApplyMaterial(matName)
    if matName == "None" then return end
    local matEnum = Enum.Material[matName] or Enum.Material.Plastic
    
    LogarEvento("AVISO", "Alterando materiais para: " .. matName)
    for _, part in pairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and not part.Parent:FindFirstChild("Humanoid") then
            part.Material = matEnum
        end
    end
end

-- 5. UI NO CHASSI (Aba Mundo)
--========================================================================
if TabMundo then
    pCreate("SecVisuals", TabMundo, "CreateSection", "Visuals Ultimate v1.0", "Left")
    
    -- Fullbright & Fog
    pCreate("ToggleFullbright", TabMundo, "CreateToggle", {
        Name = "Fullbright (Luz Total)",
        CurrentValue = false,
        Callback = function(Val) 
            VisualSettings.Fullbright = Val
            ToggleLoop(true) -- Garante que o loop esteja rodando
        end
    })
    
    pCreate("ToggleFog", TabMundo, "CreateToggle", {
        Name = "Remover Neblina (No Fog)",
        CurrentValue = false,
        Callback = function(Val) VisualSettings.NoFog = Val end
    })
    
    -- Time & Brightness
    pCreate("SliderTime", TabMundo, "CreateSlider", {
        Name = "Hora do Dia (ClockTime)",
        Range = {0, 24}, Increment = 0.5, Suffix = "h",
        CurrentValue = 14,
        Callback = function(Val) 
            VisualSettings.ClockTime = Val
            VisualSettings.ForceTime = true
            ToggleLoop(true)
        end
    })
    
    pCreate("SliderBright", TabMundo, "CreateSlider", {
        Name = "Intensidade Brilho",
        Range = {0, 10}, Increment = 0.5, Suffix = "",
        CurrentValue = 2,
        Callback = function(Val) VisualSettings.Brightness = Val end
    })
    
    -- Skybox
    pCreate("ToggleSky", TabMundo, "CreateToggle", {
        Name = "Usar Skybox Custom",
        CurrentValue = false,
        Callback = function(Val) 
            VisualSettings.UseSkybox = Val
            ApplySkybox(VisualSettings.SkyboxID)
        end
    })
    
    pCreate("DropSky", TabMundo, "CreateDropdown", {
        Name = "Selecionar Céu",
        Options = {"Clear Sky", "Purple Nebula", "Dark Void"},
        CurrentOption = "Clear Sky",
        Callback = function(Val)
            -- Rayfield retorna tabela as vezes
            if type(Val) == "table" then Val = Val[1] end
            VisualSettings.SkyboxID = Val
            ApplySkybox(Val)
        end
    })
    
    -- Otimização & Efeitos
    pCreate("BtnNoEffects", TabMundo, "CreateButton", {
        Name = "Remover Efeitos (Blur/Bloom/Sun)",
        Callback = RemoveEffects
    })
    
    -- World Mods
    pCreate("SliderFOV", TabMundo, "CreateSlider", {
        Name = "Campo de Visão (FOV)",
        Range = {10, 120}, Increment = 1, Suffix = "°",
        CurrentValue = 70,
        Callback = function(Val) Camera.FieldOfView = Val end
    })
    
    pCreate("ToggleXRay", TabMundo, "CreateToggle", {
        Name = "X-Ray (Paredes Transparentes)",
        CurrentValue = false,
        Callback = ApplyXRay
    })
    
    pCreate("DropMat", TabMundo, "CreateDropdown", {
        Name = "Forçar Material (FPS/Visual)",
        Options = {"None", "Plastic", "Neon", "Glass", "ForceField"},
        CurrentOption = "None",
        Callback = function(Val)
            if type(Val) == "table" then Val = Val[1] end
            ApplyMaterial(Val)
        end
    })

    LogarEvento("SUCESSO", "Módulo Visuals Ultimate carregado.")
else
    LogarEvento("ERRO", "TabMundo não encontrada para Visuals.")
end

-- Inicializa loop passivo (se necessário)
ToggleLoop(true)