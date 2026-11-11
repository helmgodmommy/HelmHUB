--[[
    ========================================================================
    HelmHub | Master UI Library (HelmXGenimi Theme)
    Design & Architecture: dj & VANTA
    Theme: HelmXGenimi (Midnight Indigo, Glacial Cyan & Void Glass)
    Aesthetic:
      - Luminous Crystal Wave (#7dd3fc) & Glacial Ice-Foam (#8cc2dd)
      - Abyssal Butterfly Sapphire (#3b82f6) & Ocean Blue (#507aa1)
      - Deep Void & Midnight Ultramarine Glass (#04050b / #0c122f)
      - High-Contrast Frosted Glassmorphism Scrim for crisp legibility
      - Smart Auto-Background Loader (Local Server + getcustomasset + Roblox Asset)
      - Responsive Viewport Scaler & Floating Capsule HUD
    ========================================================================
]]

local env = (typeof(getgenv) == "function" and getgenv()) or _G

if env.HelmLibrary and typeof(env.HelmLibrary.Destroy) == "function" then
    pcall(function() env.HelmLibrary:Destroy() end)
end

local library = {
    flags = {},
    items = {},
    connections = {}
}
env.HelmLibrary = library

-- Safe connection tracker
local function trackConn(conn)
    if conn then
        table.insert(library.connections, conn)
    end
    return conn
end

-- Core Services
local players = game:GetService("Players")
local uis = game:GetService("UserInputService")
local runservice = game:GetService("RunService")
local tweenservice = game:GetService("TweenService")
local marketplaceservice = game:GetService("MarketplaceService")
local textservice = game:GetService("TextService")
local httpservice = game:GetService("HttpService")
local stats = game:GetService("Stats")

local player = players.LocalPlayer
local mouse = player and player:GetMouse()
local camera = workspace.CurrentCamera

-- Resolve Root GUI Container
local coregui = (function()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local okCore, cg = pcall(function() return game:GetService("CoreGui") end)
    if okCore and cg then
        local canParent = pcall(function()
            local test = Instance.new("Folder")
            test.Parent = cg
            test:Destroy()
        end)
        if canParent then return cg end
    end
    local lp = players.LocalPlayer
    if lp then
        local pg = lp:FindFirstChild("PlayerGui")
        if pg then return pg end
    end
    return game:GetService("CoreGui")
end)()

-- Safe Protect GUI Helper
local function protectGui(gui)
    if syn and syn.protect_gui then
        pcall(syn.protect_gui, gui)
    elseif gethui and gui.Parent == coregui then
        pcall(function() gui.Parent = gethui() end)
    end
end

-- Comprehensive Teardown
library.Destroy = function(self)
    if library.connections then
        for _, conn in ipairs(library.connections) do
            pcall(function()
                if conn and typeof(conn) == "RBXScriptConnection" and conn.Connected then
                    conn:Disconnect()
                end
            end)
        end
        table.clear(library.connections)
    end

    if library.cursor and typeof(library.cursor.Remove) == "function" then
        pcall(function() library.cursor:Remove() end)
        library.cursor = nil
    end

    if env.watermark then
        pcall(function() env.watermark:Destroy() end)
        env.watermark = nil
    end

    if env.uilib then
        pcall(function() env.uilib:Destroy() end)
        env.uilib = nil
    end

    local oldStat = coregui:FindFirstChild("StatBySmell")
    if oldStat then
        pcall(function() oldStat:Destroy() end)
    end
    local lp = players.LocalPlayer
    if lp and lp:FindFirstChild("PlayerGui") then
        local pStat = lp.PlayerGui:FindFirstChild("StatBySmell")
        if pStat then
            pcall(function() pStat:Destroy() end)
        end
    end

    if library.items then
        for _, item in pairs(library.items) do
            if typeof(item) == "table" and item.Main and typeof(item.Main) == "Instance" then
                pcall(function() item.Main:Destroy() end)
            end
        end
        table.clear(library.items)
    end
    table.clear(library.flags)
end

-- ============================================================================
-- THEME: HELMXGENIMI (MIDNIGHT INDIGO, CRYSTAL CYAN & ICE FOAM)
-- Synced directly to assets/helm_bg.png (4K UHD) palette
-- ============================================================================
library.theme = {
    fontsize = 14,
    titlesize = 16,
    font = Enum.Font.GothamMedium,
    fontbold = Enum.Font.GothamBold,
    fontcode = Enum.Font.RobotoMono or Enum.Font.Code,

    -- Official Helm Artwork Background (Local 4K PNG assets/helm_bg.png + Roblox Asset Fallback)
    background = "assets/helm_bg.png",
    background_fallback = "130973309862145",
    bgtransparency = 0.04, -- Ultra-crisp 4K artwork clarity tempered by dark abyssal glass scrim
    tilesize = 50,
    cursor = false,
    cursorimg = "https://t0.rbxcdn.com/42f66da98c40252ee151326a82aab51f",

    -- Deep Abyssal Void & Midnight Ultramarine Surfaces (#04050B / #0C122F / #162350)
    backgroundcolor = Color3.fromRGB(4, 5, 11),        -- Abyssal Void Black (#04050b)
    backgroundcolor2 = Color3.fromRGB(12, 18, 47),     -- Abyssal Indigo (#0c122f)
    sectorcolor = Color3.fromRGB(8, 12, 32),           -- Frosted Midnight Card Base (#080c20)
    sectorcolor2 = Color3.fromRGB(4, 6, 18),           -- Deep Obsidian Ultramarine (#040612)
    topcolor = Color3.fromRGB(6, 10, 28),              -- Header Midnight Abyss (#060a1c)
    topcolor2 = Color3.fromRGB(3, 5, 18),

    -- Crystal Wave Cyan & Abyssal Butterfly Sapphire Palette
    accentcolor = Color3.fromRGB(125, 211, 252),       -- Luminous Crystal Cyan (#7dd3fc)
    accentcolor2 = Color3.fromRGB(59, 130, 246),       -- Abyssal Butterfly Sapphire (#3b82f6)
    azurecolor = Color3.fromRGB(140, 194, 221),        -- Glacial Ice-Foam Highlight (#8cc2dd)
    azurecolor2 = Color3.fromRGB(80, 122, 161),        -- Luminous Ocean Blue (#507aa1)
    ribbonred = Color3.fromRGB(244, 63, 94),           -- Rose Crimson Alert (#f43f5e)
    emeraldaccent = Color3.fromRGB(52, 211, 153),      -- Glacio Emerald Status (#34d399)

    -- Steel Sapphire & Cerulean Borders (#27395E / #39567E)
    bordercolor = Color3.fromRGB(39, 57, 94),          -- Steel Sapphire Border (#27395e)
    bordercolor_glow = Color3.fromRGB(125, 211, 252),  -- Crystal Wave Glow Border
    outlinecolor = Color3.fromRGB(103, 154, 189),      -- Backwards compatibility (#679abd)
    outlinecolor2 = Color3.fromRGB(4, 5, 11),

    -- Interactive Elements (#162350 -> #27395E)
    buttoncolor = Color3.fromRGB(16, 26, 60),          -- Deep Cobalt Silk Button
    buttoncolor2 = Color3.fromRGB(10, 16, 40),
    buttonhover = Color3.fromRGB(34, 54, 104),         -- Sapphire Wave Hover Glow
    togglegroove = Color3.fromRGB(14, 22, 52),        -- Midnight Switch Groove
    togglegroove_active = Color3.fromRGB(59, 130, 246),-- Butterfly Sapphire Active
    slidergroove = Color3.fromRGB(12, 20, 46),

    -- Crisp Ice-White Typography (High Legibility over Luminous Waves)
    toptextcolor = Color3.fromRGB(232, 246, 255),      -- Glacial Frost White (#e8f6ff)
    tabstextcolor = Color3.fromRGB(142, 174, 208),     -- Muted Cerulean Mist (#8eaed0)
    tabstextselected = Color3.fromRGB(186, 230, 253),  -- Crystal Ice Highlight (#bae6fd)
    itemscolor = Color3.fromRGB(218, 234, 250),        -- Crisp Ice Slate White (#daeafA)
    itemscolor2 = Color3.fromRGB(248, 252, 255),       -- Pure Glacial White
    mutedtextcolor = Color3.fromRGB(122, 152, 188),    -- Secondary Steel Mist

    topheight = 50,
    dpScrollBarThickness = 4
}

_G.Color = Color3.fromRGB(125, 211, 252)
_G.Color2 = Color3.fromRGB(59, 130, 246)

-- Micro-Animation & Tween Helpers
local function smoothTween(inst, props, duration, easingStyle, easingDir)
    if not inst or not inst.Parent then return nil end
    local tween = tweenservice:Create(
        inst,
        TweenInfo.new(
            duration or 0.18,
            easingStyle or Enum.EasingStyle.Quart,
            easingDir or Enum.EasingDirection.Out
        ),
        props
    )
    tween:Play()
    return tween
end

local function RainbowText(text)
    if text and typeof(text) == "Instance" and text:IsA("TextLabel") then
        text.TextColor3 = Color3.fromRGB(56, 189, 248)
    end
end

-- ============================================================================
-- HYBRID LOCAL & ROBLOX ASSET RESOLVER (HelmXGenimi 4K PNG Artwork)
-- Priority: 1. Local cache / workspace PNG -> 2. Local HTTP Server sync (4K PNG)
--           3. Roblox Asset ID Fallback (130973309862145) when no local asset
-- ============================================================================
local function resolveImageAsync(imgSource, callback, fallbackId)
    if not callback then callback = function() end end
    local sourceStr = tostring(imgSource or library.theme.background or "assets/helm_bg.png")
    if sourceStr == "" then sourceStr = library.theme.background or "assets/helm_bg.png" end

    local function toRobloxUri(idOrUri)
        local s = tostring(idOrUri or "")
        if s == "" then return nil end
        if s:find("rbxthumb://") or s:find("rbxassetid://") then
            local rawId = s:match("%d+")
            if rawId and #rawId >= 8 then
                return "rbxthumb://type=Asset&id=" .. rawId .. "&w=768&h=432"
            end
            return s
        elseif s:match("^%d+$") and #s >= 8 then
            return "rbxthumb://type=Asset&id=" .. s .. "&w=768&h=432"
        end
        return nil
    end

    -- 1. Direct Roblox Asset ID / rbxassetid / rbxthumb
    local directUri = toRobloxUri(sourceStr)
    if directUri then
        callback(directUri)
        return directUri
    end

    local fallbackUri = toRobloxUri(fallbackId or library.theme.background_fallback or "130973309862145")

    -- 2. Local File / Local HTTP Server via getcustomasset (or getsynasset)
    local getAsset = (typeof(getcustomasset) == "function" and getcustomasset)
        or (typeof(getsynasset) == "function" and getsynasset)
        or nil

    local diskFound = false
    local cachedSize = 0

    if getAsset then
        local relPath = sourceStr:gsub("^/", "")
        local function detectImageExt(bytes)
            if not bytes or typeof(bytes) ~= "string" or #bytes < 512 then return nil end
            local b1, b2, b3, b4 = bytes:byte(1, 4)
            if b1 == 0x89 and b2 == 0x50 and b3 == 0x4E and b4 == 0x47 then
                return "png"
            elseif b1 == 0xFF and b2 == 0xD8 then
                return "jpg"
            end
            return nil
        end

        -- Fast local disk lookup first (avoid blank flash if already cached)
        if isfile then
            local quickPaths = { "!HelmHub/" .. relPath, relPath }
            for _, qp in ipairs(quickPaths) do
                local okExists, exists = pcall(isfile, qp)
                if okExists and exists then
                    local okUri, uri = pcall(getAsset, qp)
                    if okUri and uri and uri ~= "" then
                        diskFound = true
                        if readfile then
                            local okRead, raw = pcall(readfile, qp)
                            if okRead and typeof(raw) == "string" then
                                cachedSize = #raw
                            end
                        end
                        callback(uri)
                        break
                    end
                end
            end
        end

        -- Show Roblox fallback immediately while local server syncs (or if machine lacks local image)
        if not diskFound and fallbackUri then
            callback(fallbackUri)
        end

        -- Sync fresh 4K artwork from Local Server in background without blocking UI init
        task.spawn(function()
            local localHosts = {}
            if _G.LocalHost then table.insert(localHosts, _G.LocalHost) end
            table.insert(localHosts, "127.0.0.1:8000")
            table.insert(localHosts, "localhost:8000")
            table.insert(localHosts, "192.168.2.203:8000")
            table.insert(localHosts, "10.0.2.2:8000")

            local cleanRel = relPath:gsub(" ", "%%20")
            for _, host in ipairs(localHosts) do
                local url = string.format("http://%s/%s?t=%s", host, cleanRel, tostring(tick()))
                local okGet, bytes = pcall(function() return game:HttpGet(url) end)
                local detectedExt = okGet and detectImageExt(bytes) or nil
                if detectedExt then
                    if diskFound and cachedSize > 0 and #bytes == cachedSize then
                        return
                    end
                    if writefile then
                        pcall(function()
                            if isfolder and makefolder then
                                if not isfolder("!HelmHub") then makefolder("!HelmHub") end
                                if not isfolder("!HelmHub/assets") then makefolder("!HelmHub/assets") end
                            end
                        end)
                        -- Size-tagged cache filename avoids Roblox ContentProvider holding stale pixels across hot-reloads
                        local ext = detectedExt or relPath:match("%.([%w]+)$") or "png"
                        local stem = relPath:match("([^/\\]+)%.[%w]+$") or "helm_bg"
                        local cachePath = string.format("!HelmHub/assets/%s_%d.%s", stem, #bytes, ext)
                        local needWrite = true
                        if isfile then
                            local okEx, ex = pcall(isfile, cachePath)
                            if okEx and ex then needWrite = false end
                        end
                        if needWrite then
                            pcall(writefile, cachePath, bytes)
                        end
                        pcall(writefile, "!HelmHub/" .. relPath, bytes)

                        local okUri, uri = pcall(getAsset, cachePath)
                        if okUri and uri and uri ~= "" then
                            callback(uri)
                            return
                        end
                        local okUri2, uri2 = pcall(getAsset, "!HelmHub/" .. relPath)
                        if okUri2 and uri2 and uri2 ~= "" then
                            callback(uri2)
                            return
                        end
                    end
                    return
                end
            end
        end)
    elseif fallbackUri then
        callback(fallbackUri)
        return fallbackUri
    end

    return fallbackUri or ""
end

-- Draggable Utility (PC Mouse & Mobile Touch Supported)
local function MakeDraggable(topbarobject, object)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPosition = nil

    local function update(input)
        if not dragging or not dragStart or not startPosition then return end
        local delta = input.Position - dragStart
        local newPos = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
        object.Position = newPos
    end

    topbarobject.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true
            dragStart = input.Position
            startPosition = object.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    topbarobject.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement) or (input.UserInputType == Enum.UserInputType.Touch) then
            dragInput = input
        end
    end)

    uis.InputChanged:Connect(function(input)
        if (input == dragInput) and dragging then
            update(input)
        end
    end)
end

-- ============================================================================
-- CONFIGURATION SYSTEM (Auto-Save / Load)
-- ============================================================================
library.ConfigSystem = function(self, name, customGame)
    if isfolder and makefolder then
        if not isfolder("!HelmHub") then
            pcall(makefolder, "!HelmHub")
        end
    end

    local detectedGame = customGame or _G.HelmGameName
    if not detectedGame then
        pcall(function()
            local pid = game.PlaceId
            if pid == 97617452700163 then
                detectedGame = "Anime Eyes"
            elseif pid == 78312396550517 then
                detectedGame = "Card Origins"
            elseif pid == 118712332916577 then
                detectedGame = "Anime Rising"
            elseif pid == 6938803436 or pid == 6990129309 or pid == 6990133340 or pid == 6990131029 or pid == 7338881230 or pid == 7274690025 then
                detectedGame = "Anime Dimensions"
            else
                local info = marketplaceservice:GetProductInfo(pid)
                detectedGame = (info and info.Name) or tostring(pid)
            end
        end)
    end
    detectedGame = tostring(detectedGame or "General"):gsub('[\\/:%*%?"<>|]', "")

    local gameFolder = "!HelmHub/" .. detectedGame
    if isfolder and makefolder then
        if not isfolder(gameFolder) then
            pcall(makefolder, gameFolder)
        end
    end

    local configSystem = {
        gameFolder = gameFolder,
        configFolder = gameFolder
    }
    local configName = tostring(name or "config")
    local filePath = gameFolder .. "/" .. configName .. ".txt"

    if isfile and writefile then
        if not isfile(filePath) then
            pcall(writefile, filePath, "{}")
        end
    end

    configSystem.Load = function(self)
        if not isfile or not readfile then return end
        local success, content = pcall(readfile, filePath)
        if success and content and #content > 1 then
            pcall(function()
                local readConfig = httpservice:JSONDecode(content)
                local newConfig = {}
                for i, v in pairs(readConfig) do
                    if typeof(v) == "table" then
                        if (typeof(v[1]) == "number") and #v == 3 then
                            newConfig[i] = Color3.new(v[1], v[2], v[3])
                        elseif typeof(v[1]) == "table" then
                            newConfig[i] = v[1]
                        else
                            newConfig[i] = v
                        end
                    elseif tostring(v):find("Enum.KeyCode.") then
                        newConfig[i] = Enum.KeyCode[tostring(v):gsub("Enum.KeyCode.", "")]
                    else
                        newConfig[i] = v
                    end
                end
                library.flags = newConfig
                for i, v in pairs(library.flags) do
                    for _, v2 in pairs(library.items) do
                        if v2.flag and v2.flag == i then
                            pcall(function() v2:Set(v) end)
                        end
                    end
                end
            end)
        end
    end

    configSystem.Save = function(self)
        if not writefile then return end
        local config = {}
        for i, v in pairs(library.flags) do
            if v ~= nil and v ~= "" then
                if typeof(v) == "Color3" then
                    config[i] = {v.R, v.G, v.B}
                elseif (typeof(v) == "EnumItem") and tostring(v):find("Enum.KeyCode") then
                    config[i] = "Enum.KeyCode." .. v.Name
                elseif typeof(v) == "table" then
                    config[i] = v
                else
                    config[i] = v
                end
            end
        end
        pcall(writefile, filePath, httpservice:JSONEncode(config))
    end

    return configSystem
end

-- ============================================================================
-- WATERMARK COMPONENT (HelmXGenimi Badge)
-- ============================================================================
library.CreateWatermark = function(self, name)
    local gamename = "Game"
    pcall(function()
        gamename = marketplaceservice:GetProductInfo(game.PlaceId).Name
    end)

    local watermark = {
        Visible = true,
        text = " ◈ HELMHUB // " .. name:gsub("{game}", gamename):gsub("{fps}", "0 FPS") .. " "
    }

    watermark.main = Instance.new("ScreenGui")
    watermark.main.Name = "HelmWatermark"
    watermark.main.ResetOnSpawn = false
    watermark.main.DisplayOrder = 20

    local wmParented = false
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then pcall(function() watermark.main.Parent = h; wmParented = true end) end
    end
    if not wmParented and coregui then
        pcall(function() watermark.main.Parent = coregui; wmParented = true end)
    end
    if not wmParented then
        pcall(function()
            local lp = players.LocalPlayer
            local pg = lp and (lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 5))
            if pg then watermark.main.Parent = pg; wmParented = true end
        end)
    end
    protectGui(watermark.main)

    if env.watermark then
        pcall(function() env.watermark:Destroy() end)
    end
    env.watermark = watermark.main

    watermark.mainbar = Instance.new("Frame", watermark.main)
    watermark.mainbar.Name = "Main"
    watermark.mainbar.BorderSizePixel = 0
    watermark.mainbar.BackgroundColor3 = Color3.fromRGB(4, 7, 22)
    watermark.mainbar.BackgroundTransparency = 0.14
    watermark.mainbar.Position = UDim2.new(0, 14, 0, 14)
    watermark.mainbar.Size = UDim2.new(0, 220, 0, 28)
    watermark.mainbar.ZIndex = 5

    local corner = Instance.new("UICorner", watermark.mainbar)
    corner.CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke", watermark.mainbar)
    stroke.Thickness = 1
    stroke.Color = library.theme.bordercolor
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    watermark.Outline = stroke
    watermark.BlackOutline = stroke

    watermark.topbar = Instance.new("Frame", watermark.mainbar)
    watermark.topbar.Name = "AccentLine"
    watermark.topbar.BorderSizePixel = 0
    watermark.topbar.BackgroundColor3 = library.theme.accentcolor
    watermark.topbar.Size = UDim2.new(1, 0, 0, 2)
    watermark.topbar.Position = UDim2.new(0, 0, 0, 0)
    watermark.topbar.ZIndex = 6

    local wmGrad = Instance.new("UIGradient", watermark.topbar)
    wmGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, library.theme.accentcolor2),
        ColorSequenceKeypoint.new(0.5, library.theme.accentcolor),
        ColorSequenceKeypoint.new(1, library.theme.azurecolor)
    })

    local topCorner = Instance.new("UICorner", watermark.topbar)
    topCorner.CornerRadius = UDim.new(0, 6)

    watermark.label = Instance.new("TextLabel", watermark.mainbar)
    watermark.label.Name = "FPSLabel"
    watermark.label.BackgroundTransparency = 1
    watermark.label.Size = UDim2.new(1, -16, 1, 0)
    watermark.label.Position = UDim2.new(0, 10, 0, 0)
    watermark.label.Font = library.theme.fontbold
    watermark.label.TextSize = 13
    watermark.label.TextColor3 = library.theme.toptextcolor
    watermark.label.TextXAlignment = Enum.TextXAlignment.Left
    watermark.label.Text = watermark.text
    watermark.label.ZIndex = 7

    local startTime, counter, oldfps = os.clock(), 0, nil
    local c_wm_hb = runservice.Heartbeat:Connect(function()
        if not watermark.main or not watermark.main.Parent then return end
        watermark.mainbar.Visible = watermark.Visible

        if name:find("{fps}") then
            local currentTime = os.clock()
            counter = counter + 1
            if (currentTime - startTime) >= 1 then
                local fps = math.floor(counter / (currentTime - startTime))
                counter = 0
                startTime = currentTime
                if fps ~= oldfps then
                    local formatted = " ◈ HELMHUB // " .. name:gsub("{game}", gamename):gsub("{fps}", fps .. " FPS") .. " "
                    watermark.label.Text = formatted
                    local tSize = textservice:GetTextSize(formatted, 13, library.theme.fontbold, Vector2.new(1000, 50))
                    watermark.mainbar.Size = UDim2.new(0, tSize.X + 24, 0, 28)
                end
                oldfps = fps
            end
        end
    end)
    trackConn(c_wm_hb)

    watermark.mainbar.MouseEnter:Connect(function()
        smoothTween(watermark.mainbar, {BackgroundTransparency = 0.05}, 0.2)
        smoothTween(stroke, {Color = library.theme.accentcolor}, 0.2)
    end)
    watermark.mainbar.MouseLeave:Connect(function()
        smoothTween(watermark.mainbar, {BackgroundTransparency = 0.15}, 0.2)
        smoothTween(stroke, {Color = library.theme.bordercolor}, 0.2)
    end)

    watermark.UpdateTheme = function(self, theme)
        theme = theme or library.theme
        stroke.Color = theme.bordercolor
        watermark.topbar.BackgroundColor3 = theme.accentcolor
        watermark.label.Font = theme.fontbold
    end

    return watermark
end

-- ============================================================================
-- MAIN WINDOW COMPONENT (HelmXGenimi Terminal)
-- ============================================================================
library.CreateWindow = function(self, name, hidebutton)
    local window = {}
    window.name = name or "HelmHub // HelmXGenimi"
    window.size = UDim2.fromOffset(680, 440)
    window.hidebutton = hidebutton or Enum.KeyCode.Insert
    window.theme = library.theme
    window.Tabs = {}
    window.OpenedColorPickers = {}
    window.CurrentOpenDropdown = nil
    window.IsMinimized = false

    local updateevent = Instance.new("BindableEvent")
    window.UpdateTheme = function(self, theme)
        updateevent:Fire(theme or library.theme)
        window.theme = theme or library.theme
    end

    window.Destroy = function(self)
        library:Destroy()
    end

    -- ScreenGui
    window.Main = Instance.new("ScreenGui")
    window.Main.Name = "HelmMasterUI"
    window.Main.DisplayOrder = 15
    window.Main.ResetOnSpawn = false

    local uiParented = false
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then pcall(function() window.Main.Parent = h; uiParented = true end) end
    end
    if not uiParented and coregui then
        pcall(function() window.Main.Parent = coregui; uiParented = true end)
    end
    if not uiParented then
        pcall(function()
            local lp = players.LocalPlayer
            local pg = lp and (lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 5))
            if pg then window.Main.Parent = pg; uiParented = true end
        end)
    end
    protectGui(window.Main)

    if env.uilib then
        pcall(function() env.uilib:Destroy() end)
    end
    env.uilib = window.Main

    -- Root Window Frame
    window.Frame = Instance.new("TextButton", window.Main)
    window.Frame.Name = "main"
    window.Frame.Position = UDim2.fromScale(0.5, 0.5)
    window.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Frame.Size = window.size
    window.Frame.BorderSizePixel = 0
    window.Frame.AutoButtonColor = false
    window.Frame.Text = ""
    window.Frame.BackgroundColor3 = window.theme.backgroundcolor
    window.Frame.BackgroundTransparency = 0.25
    window.Frame.ClipsDescendants = false

    -- Sleek Chamfered Corners & Crystal Sapphire Stroke
    local mainCorner = Instance.new("UICorner", window.Frame)
    mainCorner.CornerRadius = UDim.new(0, 10)

    local mainStroke = Instance.new("UIStroke", window.Frame)
    mainStroke.Color = Color3.fromRGB(125, 211, 252)
    mainStroke.Thickness = 1.3
    mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local mainStrokeGrad = Instance.new("UIGradient", mainStroke)
    mainStrokeGrad.Rotation = 35
    mainStrokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(125, 211, 252)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(59, 130, 246)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(39, 57, 94))
    })

    -- Backward compatibility stubs
    window.Outline = mainStroke
    window.BlackOutline = mainStroke
    window.BlackOutline2 = mainStroke

    -- Responsive Viewport Scaler
    window.UIScale = Instance.new("UIScale", window.Frame)
    local function updateWindowScale()
        pcall(function()
            local cam = workspace.CurrentCamera
            if not cam then return end
            local vp = cam.ViewportSize
            if vp.X > 0 and vp.Y > 0 then
                local scaleX = (vp.X - 24) / 680
                local scaleY = (vp.Y - 48) / 440
                window.UIScale.Scale = math.clamp(math.min(scaleX, scaleY, 1), 0.62, 1)
            end
        end)
    end
    updateWindowScale()
    if workspace.CurrentCamera then
        trackConn(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateWindowScale))
    end

    -- Smooth Window Entrance
    window.UIScale.Scale = window.UIScale.Scale * 0.95
    window.Frame.BackgroundTransparency = 0.50
    task.spawn(function()
        task.wait(0.02)
        smoothTween(window.Frame, {BackgroundTransparency = 0.28}, 0.25, Enum.EasingStyle.Quart)
        updateWindowScale()
    end)

    -- Toggle Window Visibility on Keybind
    local c_whide = uis.InputBegan:Connect(function(key)
        if key.KeyCode == window.hidebutton then
            if window.Frame then
                window.Frame.Visible = not window.Frame.Visible
            end
        end
    end)
    trackConn(c_whide)

    -- Window Background Image (Acrylic Glassmorphism with Abyssal Butterfly Artwork)
    window.BackgroundImage = Instance.new("ImageLabel", window.Frame)
    window.BackgroundImage.Name = "background"
    window.BackgroundImage.BorderSizePixel = 0
    window.BackgroundImage.BackgroundTransparency = 1
    window.BackgroundImage.Position = UDim2.new(0, 0, 0, 0)
    window.BackgroundImage.Size = UDim2.fromScale(1, 1)
    window.BackgroundImage.ScaleType = Enum.ScaleType.Crop
    window.BackgroundImage.ZIndex = 1
    window.BackgroundImage.Image = ""
    window.BackgroundImage.ImageTransparency = window.theme.bgtransparency or 0.04
    pcall(function() window.BackgroundImage.ResampleMode = Enum.ResamplerMode.Default end)

    local bgCorner = Instance.new("UICorner", window.BackgroundImage)
    bgCorner.CornerRadius = UDim.new(0, 10)

    -- Frosted Abyssal Scrim over Wallpaper (keeps bright cyan wave crests legible behind cards)
    local bgScrim = Instance.new("Frame", window.BackgroundImage)
    bgScrim.Name = "AbyssalScrim"
    bgScrim.BorderSizePixel = 0
    bgScrim.BackgroundColor3 = Color3.fromRGB(4, 6, 18)
    bgScrim.BackgroundTransparency = 0.50
    bgScrim.Size = UDim2.fromScale(1, 1)
    bgScrim.ZIndex = 2

    local scrimCorner = Instance.new("UICorner", bgScrim)
    scrimCorner.CornerRadius = UDim.new(0, 10)

    local scrimGrad = Instance.new("UIGradient", bgScrim)
    scrimGrad.Rotation = 90
    scrimGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(3, 5, 28)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(8, 13, 36)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 5, 11))
    })
    scrimGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.30),
        NumberSequenceKeypoint.new(0.5, 0.45),
        NumberSequenceKeypoint.new(1, 0.28)
    })

    -- Auto-Resolve Background Image (Local 4K PNG -> Roblox Asset Fallback)
    resolveImageAsync(window.theme.background, function(resolved)
        if resolved and resolved ~= "" and window.BackgroundImage then
            window.BackgroundImage.Image = resolved
            window.BackgroundImage.ImageTransparency = window.theme.bgtransparency or 0.04
        end
    end, window.theme.background_fallback)

    -- Window TopBar (Draggable Abyssal Terminal Header)
    window.TopBar = Instance.new("Frame", window.Frame)
    window.TopBar.Name = "top"
    window.TopBar.Size = UDim2.new(1, 0, 0, window.theme.topheight)
    window.TopBar.BorderSizePixel = 0
    window.TopBar.BackgroundColor3 = window.theme.topcolor
    window.TopBar.BackgroundTransparency = 0.16
    window.TopBar.ZIndex = 8

    local topCorner = Instance.new("UICorner", window.TopBar)
    topCorner.CornerRadius = UDim.new(0, 10)

    local topBottomFix = Instance.new("Frame", window.TopBar)
    topBottomFix.Name = "CornerFix"
    topBottomFix.BorderSizePixel = 0
    topBottomFix.BackgroundColor3 = window.theme.topcolor
    topBottomFix.BackgroundTransparency = 0.16
    topBottomFix.Position = UDim2.new(0, 0, 1, -8)
    topBottomFix.Size = UDim2.new(1, 0, 0, 8)
    topBottomFix.ZIndex = 8

    MakeDraggable(window.TopBar, window.Frame)

    -- Branding: [ ◈ HELMHUB // HelmXGenimi ]
    local titleContainer = Instance.new("Frame", window.TopBar)
    titleContainer.Name = "TitleContainer"
    titleContainer.BackgroundTransparency = 1
    titleContainer.Position = UDim2.new(0, 14, 0, 0)
    titleContainer.Size = UDim2.new(1, -120, 0, 26)
    titleContainer.ZIndex = 9

    local brandIcon = Instance.new("TextLabel", titleContainer)
    brandIcon.Name = "BrandIcon"
    brandIcon.BackgroundTransparency = 1
    brandIcon.Position = UDim2.new(0, 0, 0, 0)
    brandIcon.Size = UDim2.new(0, 22, 1, 0)
    brandIcon.Font = window.theme.fontbold
    brandIcon.Text = "◈"
    brandIcon.TextColor3 = window.theme.accentcolor
    brandIcon.TextSize = 16
    brandIcon.ZIndex = 10

    window.NameLabel = Instance.new("TextLabel", titleContainer)
    window.NameLabel.Name = "title"
    window.NameLabel.BackgroundTransparency = 1
    window.NameLabel.Position = UDim2.new(0, 24, 0, 0)
    window.NameLabel.Size = UDim2.new(1, -30, 1, 0)
    window.NameLabel.Font = window.theme.fontbold
    window.NameLabel.Text = window.name .. "  [ HelmXGenimi ]"
    window.NameLabel.TextColor3 = window.theme.toptextcolor
    window.NameLabel.TextSize = 14
    window.NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    window.NameLabel.ZIndex = 10

    -- Window Controls: Minimize [-] and Close [×]
    local controlContainer = Instance.new("Frame", window.TopBar)
    controlContainer.Name = "Controls"
    controlContainer.BackgroundTransparency = 1
    controlContainer.Position = UDim2.new(1, -74, 0, 4)
    controlContainer.Size = UDim2.new(0, 64, 0, 20)
    controlContainer.ZIndex = 10

    local btnMinimize = Instance.new("TextButton", controlContainer)
    btnMinimize.Name = "BtnMinimize"
    btnMinimize.Size = UDim2.new(0, 26, 0, 20)
    btnMinimize.Position = UDim2.new(0, 0, 0, 0)
    btnMinimize.BorderSizePixel = 0
    btnMinimize.BackgroundColor3 = Color3.fromRGB(16, 26, 60)
    btnMinimize.Text = "−"
    btnMinimize.Font = window.theme.fontbold
    btnMinimize.TextColor3 = window.theme.tabstextselected
    btnMinimize.TextSize = 15
    btnMinimize.AutoButtonColor = false
    btnMinimize.ZIndex = 11

    local minCorner = Instance.new("UICorner", btnMinimize)
    minCorner.CornerRadius = UDim.new(0, 4)

    local minStroke = Instance.new("UIStroke", btnMinimize)
    minStroke.Color = Color3.fromRGB(39, 57, 94)
    minStroke.Thickness = 1
    minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local btnClose = Instance.new("TextButton", controlContainer)
    btnClose.Name = "BtnClose"
    btnClose.Size = UDim2.new(0, 26, 0, 20)
    btnClose.Position = UDim2.new(0, 32, 0, 0)
    btnClose.BorderSizePixel = 0
    btnClose.BackgroundColor3 = Color3.fromRGB(48, 18, 36)
    btnClose.Text = "×"
    btnClose.Font = window.theme.fontbold
    btnClose.TextColor3 = Color3.fromRGB(253, 164, 175)
    btnClose.TextSize = 16
    btnClose.AutoButtonColor = false
    btnClose.ZIndex = 11

    local closeCorner = Instance.new("UICorner", btnClose)
    closeCorner.CornerRadius = UDim.new(0, 4)

    local closeStroke = Instance.new("UIStroke", btnClose)
    closeStroke.Color = Color3.fromRGB(136, 19, 55)
    closeStroke.Thickness = 1
    closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    btnMinimize.MouseEnter:Connect(function()
        smoothTween(btnMinimize, {BackgroundColor3 = Color3.fromRGB(34, 54, 104)}, 0.12)
        smoothTween(minStroke, {Color = window.theme.accentcolor}, 0.12)
    end)
    btnMinimize.MouseLeave:Connect(function()
        smoothTween(btnMinimize, {BackgroundColor3 = Color3.fromRGB(16, 26, 60)}, 0.12)
        smoothTween(minStroke, {Color = Color3.fromRGB(39, 57, 94)}, 0.12)
    end)

    btnClose.MouseEnter:Connect(function()
        smoothTween(btnClose, {BackgroundColor3 = Color3.fromRGB(127, 29, 48)}, 0.12)
        smoothTween(closeStroke, {Color = Color3.fromRGB(244, 63, 94)}, 0.12)
    end)
    btnClose.MouseLeave:Connect(function()
        smoothTween(btnClose, {BackgroundColor3 = Color3.fromRGB(48, 18, 36)}, 0.12)
        smoothTween(closeStroke, {Color = Color3.fromRGB(136, 19, 55)}, 0.12)
    end)

    btnMinimize.MouseButton1Click:Connect(function()
        window.IsMinimized = not window.IsMinimized
        if window.IsMinimized then
            smoothTween(window.Frame, {Size = UDim2.fromOffset(window.size.X.Offset, window.theme.topheight)}, 0.2)
            btnMinimize.Text = "+"
            if window.BackgroundImage then window.BackgroundImage.Visible = false end
            for _, t in pairs(window.Tabs) do
                t.Left.Visible = false
                t.Right.Visible = false
            end
        else
            smoothTween(window.Frame, {Size = window.size}, 0.2)
            btnMinimize.Text = "−"
            if window.BackgroundImage then window.BackgroundImage.Visible = true end
            if window.SelectedTab then
                window.SelectedTab.Left.Visible = true
                window.SelectedTab.Right.Visible = true
            end
        end
    end)

    btnClose.MouseButton1Click:Connect(function()
        smoothTween(window.Frame, {BackgroundTransparency = 1}, 0.15)
        task.wait(0.15)
        window.Frame.Visible = false
        window.Frame.BackgroundTransparency = 0.28
    end)

    -- Waveform Accent Line: Abyssal Indigo -> Crystal Cyan -> Ice Foam -> Butterfly Sapphire
    window.Line2 = Instance.new("Frame", window.TopBar)
    window.Line2.Name = "line"
    window.Line2.Position = UDim2.new(0, 0, 0, 26)
    window.Line2.Size = UDim2.new(1, 0, 0, 1)
    window.Line2.BorderSizePixel = 0
    window.Line2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    window.Line2.ZIndex = 9

    local lineGrad = Instance.new("UIGradient", window.Line2)
    lineGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(6, 12, 36)),
        ColorSequenceKeypoint.new(0.25, window.theme.accentcolor2),
        ColorSequenceKeypoint.new(0.5, window.theme.accentcolor),
        ColorSequenceKeypoint.new(0.75, window.theme.azurecolor),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 12, 36))
    })

    -- Tab Bar (Horizontal Scroll List)
    window.TabList = Instance.new("ScrollingFrame", window.TopBar)
    window.TabList.Name = "tablist"
    window.TabList.BackgroundTransparency = 1
    window.TabList.Position = UDim2.new(0, 12, 0, 27)
    window.TabList.Size = UDim2.new(1, -24, 0, 22)
    window.TabList.BorderSizePixel = 0
    window.TabList.ScrollBarThickness = 0
    window.TabList.ScrollingDirection = Enum.ScrollingDirection.X
    window.TabList.AutomaticCanvasSize = Enum.AutomaticSize.X
    window.TabList.CanvasSize = UDim2.new(0, 0, 0, 0)
    window.TabList.ClipsDescendants = true
    window.TabList.ZIndex = 10

    window.ListLayout = Instance.new("UIListLayout", window.TabList)
    window.ListLayout.FillDirection = Enum.FillDirection.Horizontal
    window.ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    window.ListLayout.Padding = UDim.new(0, 6)

    -- Active Tab Animated Crystal Cyan Indicator Line
    window.Line = Instance.new("Frame", window.Frame)
    window.Line.Name = "ActiveTabIndicator"
    window.Line.Position = UDim2.new(0, 12, 0, window.theme.topheight - 2)
    window.Line.Size = UDim2.fromOffset(60, 2)
    window.Line.BorderSizePixel = 0
    window.Line.BackgroundColor3 = window.theme.accentcolor
    window.Line.ZIndex = 12

    local indCorner = Instance.new("UICorner", window.Line)
    indCorner.CornerRadius = UDim.new(0, 2)

    local indGrad = Instance.new("UIGradient", window.Line)
    indGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, window.theme.accentcolor2),
        ColorSequenceKeypoint.new(0.5, window.theme.accentcolor),
        ColorSequenceKeypoint.new(1, window.theme.azurecolor)
    })

    -- Fullscreen Overlay for Dropdowns
    window.DropdownOverlay = Instance.new("TextButton", window.Frame)
    window.DropdownOverlay.Name = "DropdownOverlay"
    window.DropdownOverlay.BackgroundTransparency = 1
    window.DropdownOverlay.Size = UDim2.fromScale(1, 1)
    window.DropdownOverlay.Position = UDim2.fromOffset(0, 0)
    window.DropdownOverlay.ZIndex = 150
    window.DropdownOverlay.Visible = false
    window.DropdownOverlay.Text = ""
    window.DropdownOverlay.AutoButtonColor = false

    local function closeActiveDropdown()
        if window.CurrentOpenDropdown then
            pcall(function() window.CurrentOpenDropdown:Close() end)
            window.CurrentOpenDropdown = nil
        end
        if window.DropdownOverlay then
            window.DropdownOverlay.Visible = false
        end
    end
    window.CloseDropdown = closeActiveDropdown
    window.DropdownOverlay.Activated:Connect(closeActiveDropdown)
    window.DropdownOverlay.MouseButton1Click:Connect(closeActiveDropdown)

    -- ========================================================================
    -- TAB BUILDER
    -- ========================================================================
    window.CreateTab = function(self, name)
        local tab = {
            name = name or "Tab",
            SectorsLeft = {},
            SectorsRight = {}
        }

        local tSize = textservice:GetTextSize(tab.name, window.theme.fontsize, window.theme.fontbold, Vector2.new(1000, 100))

        tab.TabButton = Instance.new("TextButton", window.TabList)
        tab.TabButton.Name = tab.name
        tab.TabButton.AutoButtonColor = false
        tab.TabButton.BackgroundColor3 = Color3.fromRGB(16, 26, 62)
        tab.TabButton.BackgroundTransparency = 0.55
        tab.TabButton.BorderSizePixel = 0
        tab.TabButton.Size = UDim2.fromOffset(tSize.X + 20, 20)
        tab.TabButton.Font = window.theme.fontbold
        tab.TabButton.Text = tab.name
        tab.TabButton.TextColor3 = window.theme.tabstextcolor
        tab.TabButton.TextSize = 12
        tab.TabButton.ZIndex = 11

        local tabCorner = Instance.new("UICorner", tab.TabButton)
        tabCorner.CornerRadius = UDim.new(0, 5)

        local tabStroke = Instance.new("UIStroke", tab.TabButton)
        tabStroke.Color = Color3.fromRGB(39, 57, 94)
        tabStroke.Thickness = 1
        tabStroke.Transparency = 0.45
        tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        tab.TabStroke = tabStroke

        -- Scrolling Columns (Left & Right)
        local contentHeight = window.size.Y.Offset - window.theme.topheight - 12
        local columnWidth = (window.size.X.Offset / 2) - 16

        tab.Left = Instance.new("ScrollingFrame", window.Frame)
        tab.Left.Name = "leftside"
        tab.Left.BorderSizePixel = 0
        tab.Left.BackgroundTransparency = 1
        tab.Left.Position = UDim2.new(0, 12, 0, window.theme.topheight + 6)
        tab.Left.Size = UDim2.fromOffset(columnWidth, contentHeight)
        tab.Left.ScrollBarThickness = 4
        tab.Left.ScrollBarImageColor3 = window.theme.accentcolor
        tab.Left.ScrollingDirection = Enum.ScrollingDirection.Y
        tab.Left.CanvasSize = UDim2.new(0, 0, 0, 0)
        pcall(function() tab.Left.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
        tab.Left.ScrollingEnabled = true
        tab.Left.ClipsDescendants = true
        tab.Left.Visible = false
        tab.Left.ZIndex = 5

        local leftLayout = Instance.new("UIListLayout", tab.Left)
        leftLayout.FillDirection = Enum.FillDirection.Vertical
        leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
        leftLayout.Padding = UDim.new(0, 12)

        local leftPadding = Instance.new("UIPadding", tab.Left)
        leftPadding.PaddingTop = UDim.new(0, 4)
        leftPadding.PaddingBottom = UDim.new(0, 20)
        leftPadding.PaddingRight = UDim.new(0, 6)

        tab.Right = Instance.new("ScrollingFrame", window.Frame)
        tab.Right.Name = "rightside"
        tab.Right.BorderSizePixel = 0
        tab.Right.BackgroundTransparency = 1
        tab.Right.Position = UDim2.new(0.5, 4, 0, window.theme.topheight + 6)
        tab.Right.Size = UDim2.fromOffset(columnWidth, contentHeight)
        tab.Right.ScrollBarThickness = 4
        tab.Right.ScrollBarImageColor3 = window.theme.accentcolor
        tab.Right.ScrollingDirection = Enum.ScrollingDirection.Y
        tab.Right.CanvasSize = UDim2.new(0, 0, 0, 0)
        pcall(function() tab.Right.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
        tab.Right.ScrollingEnabled = true
        tab.Right.ClipsDescendants = true
        tab.Right.Visible = false
        tab.Right.ZIndex = 5

        local rightLayout = Instance.new("UIListLayout", tab.Right)
        rightLayout.FillDirection = Enum.FillDirection.Vertical
        rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rightLayout.Padding = UDim.new(0, 12)

        local rightPadding = Instance.new("UIPadding", tab.Right)
        rightPadding.PaddingTop = UDim.new(0, 4)
        rightPadding.PaddingBottom = UDim.new(0, 20)
        rightPadding.PaddingRight = UDim.new(0, 6)

        tab.UpdateCanvas = function(self)
            local sizeleft = 0
            for _, s in ipairs(tab.SectorsLeft) do
                local h = (s.Main and s.Main.Size.Y.Offset > 0 and s.Main.Size.Y.Offset) or 44
                if s.itemCount and s.itemCount > 0 then
                    h = math.max(h, s.itemCount * 34 + 52)
                end
                sizeleft = sizeleft + h + 14
            end
            tab.Left.CanvasSize = UDim2.fromOffset(0, sizeleft + 40)

            local sizeright = 0
            for _, s in ipairs(tab.SectorsRight) do
                local h = (s.Main and s.Main.Size.Y.Offset > 0 and s.Main.Size.Y.Offset) or 44
                if s.itemCount and s.itemCount > 0 then
                    h = math.max(h, s.itemCount * 34 + 52)
                end
                sizeright = sizeright + h + 14
            end
            tab.Right.CanvasSize = UDim2.fromOffset(0, sizeright + 40)
        end

        -- Tab Selection
        local isSwitching = false
        tab.SelectTab = function(self)
            if window.CloseDropdown then window:CloseDropdown() end
            if isSwitching then return end
            isSwitching = true

            window.SelectedTab = tab
            for _, v in pairs(window.Tabs) do
                if v ~= tab then
                    v.TabButton.TextColor3 = window.theme.tabstextcolor
                    smoothTween(v.TabButton, {BackgroundColor3 = Color3.fromRGB(16, 26, 62), BackgroundTransparency = 0.55}, 0.15)
                    if v.TabStroke then
                        smoothTween(v.TabStroke, {Color = Color3.fromRGB(39, 57, 94), Transparency = 0.45}, 0.15)
                    end
                    v.Left.Visible = false
                    v.Right.Visible = false
                end
            end

            tab.TabButton.TextColor3 = window.theme.tabstextselected
            smoothTween(tab.TabButton, {BackgroundColor3 = Color3.fromRGB(22, 40, 88), BackgroundTransparency = 0.14}, 0.15)
            if tab.TabStroke then
                smoothTween(tab.TabStroke, {Color = window.theme.accentcolor, Transparency = 0.15}, 0.15)
            end

            tab.Left.Visible = true
            tab.Right.Visible = true

            pcall(function()
                local relX = tab.TabButton.AbsolutePosition.X - window.Frame.AbsolutePosition.X
                smoothTween(window.Line, {
                    Position = UDim2.new(0, relX, 0, window.theme.topheight - 2),
                    Size = UDim2.fromOffset(tab.TabButton.AbsoluteSize.X, 2)
                }, 0.2, Enum.EasingStyle.Quart)
            end)

            task.spawn(function()
                task.wait(0.04)
                for _, s in pairs(tab.SectorsLeft) do pcall(function() s:FixSize() end) end
                for _, s in pairs(tab.SectorsRight) do pcall(function() s:FixSize() end) end
                tab:UpdateCanvas()
                task.wait(0.08)
                for _, s in pairs(tab.SectorsLeft) do pcall(function() s:FixSize() end) end
                for _, s in pairs(tab.SectorsRight) do pcall(function() s:FixSize() end) end
                tab:UpdateCanvas()
                isSwitching = false
            end)
        end

        tab.TabButton.MouseButton1Click:Connect(function()
            tab:SelectTab()
        end)
        tab.TabButton.MouseEnter:Connect(function()
            if window.SelectedTab ~= tab then
                smoothTween(tab.TabButton, {BackgroundColor3 = Color3.fromRGB(24, 38, 80), BackgroundTransparency = 0.28}, 0.15)
                if tab.TabStroke then
                    smoothTween(tab.TabStroke, {Color = Color3.fromRGB(80, 122, 161), Transparency = 0.25}, 0.15)
                end
            end
        end)
        tab.TabButton.MouseLeave:Connect(function()
            if window.SelectedTab ~= tab then
                smoothTween(tab.TabButton, {BackgroundColor3 = Color3.fromRGB(16, 26, 62), BackgroundTransparency = 0.55}, 0.15)
                if tab.TabStroke then
                    smoothTween(tab.TabStroke, {Color = Color3.fromRGB(39, 57, 94), Transparency = 0.45}, 0.15)
                end
            end
        end)

        if #window.Tabs == 0 then
            task.spawn(function()
                task.wait(0.05)
                tab:SelectTab()
            end)
            pcall(function() tab:UpdateCanvas() end)
        end

        -- ====================================================================
        -- SECTOR BUILDER (Frosted Glass Card)
        -- ====================================================================
        tab.CreateSector = function(self, name, side)
            local sector = {
                name = name or "Sector",
                side = (side and side:lower()) or "left",
                itemCount = 0
            }

            local parentColumn = (sector.side == "left" and tab.Left) or tab.Right
            local secWidth = columnWidth - 10
            local itemWidth = secWidth - 16

            sector.Main = Instance.new("Frame", parentColumn)
            sector.Main.Name = sector.name:gsub(" ", "") .. "Sector"
            sector.Main.BorderSizePixel = 0
            sector.Main.BackgroundColor3 = window.theme.sectorcolor
            sector.Main.BackgroundTransparency = 0.22
            sector.Main.Size = UDim2.fromOffset(secWidth, 44)
            sector.Main.ClipsDescendants = false
            sector.Main.ZIndex = 6

            local secCorner = Instance.new("UICorner", sector.Main)
            secCorner.CornerRadius = UDim.new(0, 8)

            local secGrad = Instance.new("UIGradient", sector.Main)
            secGrad.Rotation = 90
            secGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 18, 47)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 6, 18))
            })

            local secStroke = Instance.new("UIStroke", sector.Main)
            secStroke.Color = Color3.fromRGB(80, 122, 161)
            secStroke.Thickness = 1.1
            secStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

            local strokeGrad = Instance.new("UIGradient", secStroke)
            strokeGrad.Rotation = 25
            strokeGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, window.theme.accentcolor),
                ColorSequenceKeypoint.new(0.45, window.theme.accentcolor2),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 35, 80))
            })

            -- Header Bar with Helm Badge
            local headerBar = Instance.new("Frame", sector.Main)
            headerBar.Name = "Header"
            headerBar.BackgroundTransparency = 1
            headerBar.Size = UDim2.new(1, 0, 0, 24)
            headerBar.Position = UDim2.new(0, 0, 0, 2)
            headerBar.ZIndex = 7

            local badge = Instance.new("TextLabel", headerBar)
            badge.Name = "Badge"
            badge.BackgroundTransparency = 1
            badge.Position = UDim2.new(0, 10, 0, 0)
            badge.Size = UDim2.new(0, 16, 1, 0)
            badge.Font = window.theme.fontbold
            badge.Text = "◈"
            badge.TextColor3 = window.theme.accentcolor
            badge.TextSize = 13
            badge.ZIndex = 8

            sector.Label = Instance.new("TextLabel", headerBar)
            sector.Label.Name = "Title"
            sector.Label.BackgroundTransparency = 1
            sector.Label.Position = UDim2.new(0, 26, 0, 0)
            sector.Label.Size = UDim2.new(1, -34, 1, 0)
            sector.Label.Font = window.theme.fontbold
            sector.Label.Text = sector.name
            sector.Label.TextColor3 = window.theme.toptextcolor
            sector.Label.TextSize = 13
            sector.Label.TextXAlignment = Enum.TextXAlignment.Left
            sector.Label.TextTruncate = Enum.TextTruncate.AtEnd
            sector.Label.ZIndex = 8

            local headerLine = Instance.new("Frame", sector.Main)
            headerLine.Name = "Line"
            headerLine.BorderSizePixel = 0
            headerLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            headerLine.Position = UDim2.new(0, 8, 0, 26)
            headerLine.Size = UDim2.new(1, -16, 0, 1)
            headerLine.ZIndex = 7

            local lineGrad2 = Instance.new("UIGradient", headerLine)
            lineGrad2.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, window.theme.accentcolor),
                ColorSequenceKeypoint.new(0.5, window.theme.azurecolor),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 18, 47))
            })

            -- Sector Items Container
            sector.Items = Instance.new("Frame", sector.Main)
            sector.Items.Name = "items"
            sector.Items.BackgroundTransparency = 1
            sector.Items.Position = UDim2.fromOffset(0, 30)
            sector.Items.Size = UDim2.fromOffset(secWidth, 0)
            sector.Items.ClipsDescendants = false
            sector.Items.ZIndex = 7

            sector.ListLayout = Instance.new("UIListLayout", sector.Items)
            sector.ListLayout.FillDirection = Enum.FillDirection.Vertical
            sector.ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            sector.ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
            sector.ListLayout.Padding = UDim.new(0, 8)

            local itemsPad = Instance.new("UIPadding", sector.Items)
            itemsPad.PaddingTop = UDim.new(0, 4)
            itemsPad.PaddingBottom = UDim.new(0, 10)
            itemsPad.PaddingLeft = UDim.new(0, 4)
            itemsPad.PaddingRight = UDim.new(0, 4)

            if sector.side == "left" then
                table.insert(tab.SectorsLeft, sector)
            else
                table.insert(tab.SectorsRight, sector)
            end

            sector.FixSize = function(self)
                local count = math.max(0, (sector.itemCount or 0))
                local minExpectedH = count * 36 + 6
                local contentH = sector.ListLayout.AbsoluteContentSize.Y
                if contentH < minExpectedH then
                    contentH = minExpectedH
                end
                local targetH = math.max(contentH + 48, 54)
                sector.Main.Size = UDim2.fromOffset(secWidth, targetH)
                sector.Items.Size = UDim2.fromOffset(secWidth, contentH + 18)
                pcall(function() tab:UpdateCanvas() end)

                task.defer(function()
                    if sector.ListLayout and sector.Main then
                        local realH = sector.ListLayout.AbsoluteContentSize.Y
                        local effH = math.max(realH, minExpectedH)
                        if effH > 0 and math.abs(sector.Items.Size.Y.Offset - (effH + 18)) > 2 then
                            sector.Main.Size = UDim2.fromOffset(secWidth, effH + 48)
                            sector.Items.Size = UDim2.fromOffset(secWidth, effH + 18)
                            pcall(function() tab:UpdateCanvas() end)
                        end
                    end
                end)
            end

            sector.ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                sector:FixSize()
            end)

            -- ================================================================
            -- 1. BUTTON ELEMENT
            -- ================================================================
            sector.AddButton = function(self, text, callback)
                sector.itemCount = (sector.itemCount or 0) + 1
                local button = {
                    text = text or "Button",
                    callback = callback or function() end
                }

                button.Main = Instance.new("TextButton", sector.Items)
                button.Main.Name = "Button_" .. tostring(sector.itemCount)
                button.Main.LayoutOrder = sector.itemCount
                button.Main.Size = UDim2.fromOffset(itemWidth, 32)
                button.Main.BorderSizePixel = 0
                button.Main.BackgroundColor3 = window.theme.buttoncolor
                button.Main.AutoButtonColor = false
                button.Main.Text = ""
                button.Main.ClipsDescendants = true
                button.Main.ZIndex = 8

                local btnCorner = Instance.new("UICorner", button.Main)
                btnCorner.CornerRadius = UDim.new(0, 6)

                local btnStroke = Instance.new("UIStroke", button.Main)
                btnStroke.Color = Color3.fromRGB(57, 86, 126)
                btnStroke.Thickness = 1.2
                btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                button.Label = Instance.new("TextLabel", button.Main)
                button.Label.Name = "Label"
                button.Label.BackgroundTransparency = 1
                button.Label.Position = UDim2.new(0, 8, 0, 0)
                button.Label.Size = UDim2.new(1, -16, 1, 0)
                button.Label.Font = window.theme.fontbold
                button.Label.Text = button.text
                button.Label.TextColor3 = window.theme.toptextcolor
                button.Label.TextSize = 12
                button.Label.TextXAlignment = Enum.TextXAlignment.Center
                button.Label.TextYAlignment = Enum.TextYAlignment.Center
                button.Label.TextWrapped = false
                button.Label.TextTruncate = Enum.TextTruncate.AtEnd
                button.Label.ZIndex = 9

                button.Main.MouseEnter:Connect(function()
                    smoothTween(button.Main, {BackgroundColor3 = window.theme.buttonhover}, 0.15)
                    smoothTween(btnStroke, {Color = window.theme.accentcolor}, 0.15)
                    button.Label.TextColor3 = Color3.fromRGB(255, 255, 255)
                end)
                button.Main.MouseLeave:Connect(function()
                    smoothTween(button.Main, {BackgroundColor3 = window.theme.buttoncolor}, 0.15)
                    smoothTween(btnStroke, {Color = Color3.fromRGB(57, 86, 126)}, 0.15)
                    button.Label.TextColor3 = window.theme.toptextcolor
                end)

                button.Main.MouseButton1Click:Connect(function()
                    smoothTween(button.Main, {BackgroundColor3 = window.theme.accentcolor}, 0.08)
                    button.Label.TextColor3 = Color3.fromRGB(4, 5, 11)
                    task.wait(0.08)
                    smoothTween(button.Main, {BackgroundColor3 = window.theme.buttonhover}, 0.15)
                    button.Label.TextColor3 = Color3.fromRGB(255, 255, 255)
                    pcall(button.callback)
                end)

                sector:FixSize()
                return button
            end

            -- ================================================================
            -- 2. LABEL ELEMENT
            -- ================================================================
            sector.AddLabel = function(self, text, ranbow)
                sector.itemCount = (sector.itemCount or 0) + 1
                local label = {}
                label.Main = Instance.new("TextLabel", sector.Items)
                label.Main.Name = "Label_" .. tostring(sector.itemCount)
                label.Main.LayoutOrder = sector.itemCount
                label.Main.BackgroundTransparency = 1
                label.Main.Size = UDim2.fromOffset(itemWidth, 18)
                label.Main.TextTruncate = Enum.TextTruncate.AtEnd
                label.Main.Font = window.theme.font
                label.Main.Text = text or ""
                label.Main.TextColor3 = (ranbow and window.theme.accentcolor) or window.theme.itemscolor
                label.Main.TextSize = 13
                label.Main.TextXAlignment = Enum.TextXAlignment.Left
                label.Main.ZIndex = 8

                label.Set = function(self, value)
                    label.Main.Text = tostring(value)
                end

                sector:FixSize()
                return label
            end

            -- ================================================================
            -- 3. TOGGLE ELEMENT (Cyber Switch with Sliding Knob)
            -- ================================================================
            sector.AddToggle = function(self, text, default, callback, flag)
                sector.itemCount = (sector.itemCount or 0) + 1
                local toggle = {
                    text = text or "Toggle",
                    default = default or false,
                    callback = callback or function() end,
                    flag = flag or text or "",
                    value = default or false
                }

                toggle.Container = Instance.new("Frame", sector.Items)
                toggle.Container.Name = "Toggle_" .. tostring(sector.itemCount)
                toggle.Container.LayoutOrder = sector.itemCount
                toggle.Container.BackgroundTransparency = 1
                toggle.Container.Size = UDim2.fromOffset(itemWidth, 24)
                toggle.Container.ZIndex = 8

                toggle.Main = Instance.new("TextButton", toggle.Container)
                toggle.Main.Name = "toggle"
                toggle.Main.Size = UDim2.new(0, 38, 0, 18)
                toggle.Main.Position = UDim2.new(0, 0, 0.5, -9)
                toggle.Main.BorderSizePixel = 0
                toggle.Main.BackgroundColor3 = window.theme.togglegroove
                toggle.Main.AutoButtonColor = false
                toggle.Main.Text = ""
                toggle.Main.ZIndex = 9

                local switchCorner = Instance.new("UICorner", toggle.Main)
                switchCorner.CornerRadius = UDim.new(0, 9)

                local switchStroke = Instance.new("UIStroke", toggle.Main)
                switchStroke.Color = Color3.fromRGB(39, 57, 94)
                switchStroke.Thickness = 1
                switchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                local switchGrad = Instance.new("UIGradient", toggle.Main)
                switchGrad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, window.theme.accentcolor),
                    ColorSequenceKeypoint.new(1, window.theme.accentcolor2)
                })
                switchGrad.Enabled = false

                toggle.CheckedFrame = Instance.new("Frame", toggle.Main)
                toggle.CheckedFrame.Name = "Knob"
                toggle.CheckedFrame.Size = UDim2.fromOffset(14, 14)
                toggle.CheckedFrame.Position = UDim2.new(0, 2, 0.5, -7)
                toggle.CheckedFrame.BorderSizePixel = 0
                toggle.CheckedFrame.BackgroundColor3 = Color3.fromRGB(142, 174, 208)
                toggle.CheckedFrame.ZIndex = 10

                local knobCorner = Instance.new("UICorner", toggle.CheckedFrame)
                knobCorner.CornerRadius = UDim.new(0, 7)

                toggle.Label = Instance.new("TextButton", toggle.Container)
                toggle.Label.Name = "Label"
                toggle.Label.BackgroundTransparency = 1
                toggle.Label.Position = UDim2.new(0, 46, 0, 0)
                toggle.Label.Size = UDim2.new(1, -50, 1, 0)
                toggle.Label.TextTruncate = Enum.TextTruncate.AtEnd
                toggle.Label.Font = window.theme.font
                toggle.Label.Text = toggle.text
                toggle.Label.TextColor3 = window.theme.itemscolor
                toggle.Label.TextSize = 12
                toggle.Label.TextXAlignment = Enum.TextXAlignment.Left
                toggle.Label.AutoButtonColor = false
                toggle.Label.ZIndex = 9

                toggle.Label.MouseEnter:Connect(function()
                    smoothTween(toggle.Label, {TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.12)
                end)
                toggle.Label.MouseLeave:Connect(function()
                    if not toggle.value then
                        smoothTween(toggle.Label, {TextColor3 = window.theme.itemscolor}, 0.12)
                    end
                end)

                toggle.Items = Instance.new("Frame", toggle.Container)
                toggle.Items.Name = "SubItems"
                toggle.Items.BackgroundTransparency = 1
                toggle.Items.Position = UDim2.new(1, -64, 0, 0)
                toggle.Items.Size = UDim2.new(0, 64, 1, 0)
                toggle.Items.ZIndex = 9

                local subLayout = Instance.new("UIListLayout", toggle.Items)
                subLayout.FillDirection = Enum.FillDirection.Horizontal
                subLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
                subLayout.SortOrder = Enum.SortOrder.LayoutOrder
                subLayout.Padding = UDim.new(0, 4)

                if toggle.flag and toggle.flag ~= "" then
                    library.flags[toggle.flag] = toggle.default or false
                end

                toggle.Set = function(self, value)
                    toggle.value = value and true or false
                    if toggle.flag and toggle.flag ~= "" then
                        library.flags[toggle.flag] = toggle.value
                    end

                    if toggle.value then
                        switchGrad.Enabled = true
                        smoothTween(toggle.Main, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}, 0.18)
                        smoothTween(switchStroke, {Color = window.theme.accentcolor}, 0.18)
                        smoothTween(toggle.CheckedFrame, {
                            Position = UDim2.new(1, -16, 0.5, -7),
                            BackgroundColor3 = Color3.fromRGB(4, 6, 18)
                        }, 0.18, Enum.EasingStyle.Quart)
                        toggle.Label.TextColor3 = Color3.fromRGB(255, 255, 255)
                    else
                        switchGrad.Enabled = false
                        smoothTween(toggle.Main, {BackgroundColor3 = window.theme.togglegroove}, 0.18)
                        smoothTween(switchStroke, {Color = Color3.fromRGB(39, 57, 94)}, 0.18)
                        smoothTween(toggle.CheckedFrame, {
                            Position = UDim2.new(0, 2, 0.5, -7),
                            BackgroundColor3 = Color3.fromRGB(142, 174, 208)
                        }, 0.18, Enum.EasingStyle.Quart)
                        toggle.Label.TextColor3 = window.theme.itemscolor
                    end

                    pcall(toggle.callback, toggle.value)
                end

                toggle.Get = function(self)
                    return toggle.value
                end

                local function onToggleClick()
                    toggle:Set(not toggle.value)
                end
                toggle.Main.MouseButton1Click:Connect(onToggleClick)
                toggle.Label.MouseButton1Click:Connect(onToggleClick)

                toggle:Set(toggle.default)

                -- Attached Sub-items
                toggle.AddKeybind = function(self, default, flag)
                    local keybind = {
                        default = default or "None",
                        value = default or "None",
                        flag = flag or (toggle.text .. "_key")
                    }

                    local keyBtn = Instance.new("TextButton", toggle.Items)
                    keyBtn.Name = "keybind"
                    keyBtn.BackgroundColor3 = Color3.fromRGB(24, 32, 50)
                    keyBtn.BorderSizePixel = 0
                    keyBtn.Size = UDim2.fromOffset(48, 18)
                    keyBtn.Font = window.theme.fontcode
                    keyBtn.Text = "[" .. (typeof(keybind.default) == "EnumItem" and keybind.default.Name or tostring(keybind.default)) .. "]"
                    keyBtn.TextColor3 = window.theme.tabstextcolor
                    keyBtn.TextSize = 11
                    keyBtn.AutoButtonColor = false
                    keyBtn.ZIndex = 10

                    local kbCorner = Instance.new("UICorner", keyBtn)
                    kbCorner.CornerRadius = UDim.new(0, 4)

                    local kbStroke = Instance.new("UIStroke", keyBtn)
                    kbStroke.Color = Color3.fromRGB(36, 54, 86)
                    kbStroke.Thickness = 1
                    kbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                    keybind.Set = function(self, key)
                        keybind.value = key
                        local nameStr = (typeof(key) == "EnumItem" and key.Name) or tostring(key)
                        keyBtn.Text = "[" .. nameStr .. "]"
                        if keybind.flag and keybind.flag ~= "" then
                            library.flags[keybind.flag] = keybind.value
                        end
                    end

                    keybind.Get = function(self)
                        return keybind.value
                    end

                    local listening = false
                    keyBtn.MouseButton1Click:Connect(function()
                        listening = true
                        keyBtn.Text = "[...]"
                        keyBtn.TextColor3 = window.theme.accentcolor
                        kbStroke.Color = window.theme.accentcolor
                    end)

                    uis.InputBegan:Connect(function(input, gpe)
                        if listening and not gpe then
                            if input.UserInputType == Enum.UserInputType.Keyboard then
                                listening = false
                                kbStroke.Color = Color3.fromRGB(36, 54, 86)
                                keyBtn.TextColor3 = window.theme.tabstextcolor
                                if input.KeyCode == Enum.KeyCode.Escape then
                                    keybind:Set("None")
                                else
                                    keybind:Set(input.KeyCode)
                                end
                            end
                        end
                    end)

                    table.insert(library.items, keybind)
                    return keybind
                end

                toggle.AddDropdown = function(self, items, default, multichoice, callback, flag)
                    return sector:AddDropdown(toggle.text, items, default, multichoice, callback, flag)
                end

                toggle.AddTextbox = function(self, default, callback, flag)
                    return sector:AddTextbox(toggle.text, default, callback, flag)
                end

                toggle.AddColorpicker = function(self, default, callback, flag)
                    return sector:AddColorpicker(toggle.text, default, callback, flag)
                end

                toggle.AddSlider = function(self, min, default, max, decimals, callback, flag)
                    return sector:AddSlider(toggle.text, min, default, max, decimals, callback, flag)
                end

                sector:FixSize()
                table.insert(library.items, toggle)
                return toggle
            end

            -- ================================================================
            -- 4. TEXTBOX ELEMENT (Stacked 2-Row Layout to Eliminate Any Overlap)
            -- ================================================================
            sector.AddTextbox = function(self, text, default, callback, flag)
                sector.itemCount = (sector.itemCount or 0) + 1
                local textbox = {
                    text = text or "Textbox",
                    default = default or "",
                    callback = callback or function() end,
                    flag = flag or text or "",
                    value = default or ""
                }

                local container = Instance.new("Frame", sector.Items)
                container.Name = "Textbox_" .. tostring(sector.itemCount)
                container.LayoutOrder = sector.itemCount
                container.BackgroundTransparency = 1
                container.Size = UDim2.fromOffset(itemWidth, 54)
                container.ClipsDescendants = false
                container.ZIndex = 8

                local label = Instance.new("TextLabel", container)
                label.Name = "Label"
                label.BackgroundTransparency = 1
                label.Position = UDim2.new(0, 0, 0, 0)
                label.Size = UDim2.new(1, 0, 0, 18)
                label.Font = window.theme.fontbold
                label.Text = textbox.text
                label.TextColor3 = window.theme.accentcolor
                label.TextSize = 12
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.TextTruncate = Enum.TextTruncate.AtEnd
                label.ZIndex = 9

                textbox.Main = Instance.new("TextBox", container)
                textbox.Main.Name = "Input"
                textbox.Main.Position = UDim2.new(0, 0, 0, 22)
                textbox.Main.Size = UDim2.new(1, 0, 0, 28)
                textbox.Main.BorderSizePixel = 0
                textbox.Main.BackgroundColor3 = Color3.fromRGB(10, 16, 40)
                textbox.Main.Font = window.theme.fontcode
                textbox.Main.Text = tostring(textbox.default)
                textbox.Main.PlaceholderText = "Nhập hoặc dán tại đây..."
                textbox.Main.PlaceholderColor3 = Color3.fromRGB(104, 134, 170)
                textbox.Main.TextColor3 = window.theme.itemscolor2
                textbox.Main.TextSize = 11
                textbox.Main.TextXAlignment = Enum.TextXAlignment.Left
                textbox.Main.ClearTextOnFocus = false
                textbox.Main.ClipsDescendants = true
                textbox.Main.ZIndex = 9

                local tbPad = Instance.new("UIPadding", textbox.Main)
                tbPad.PaddingLeft = UDim.new(0, 8)
                tbPad.PaddingRight = UDim.new(0, 8)

                local tbCorner = Instance.new("UICorner", textbox.Main)
                tbCorner.CornerRadius = UDim.new(0, 6)

                local tbStroke = Instance.new("UIStroke", textbox.Main)
                tbStroke.Color = Color3.fromRGB(39, 57, 94)
                tbStroke.Thickness = 1
                tbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                textbox.Main.Focused:Connect(function()
                    smoothTween(tbStroke, {Color = window.theme.accentcolor}, 0.15)
                end)
                textbox.Main.FocusLost:Connect(function(enterPressed)
                    smoothTween(tbStroke, {Color = Color3.fromRGB(39, 57, 94)}, 0.15)
                    textbox.value = textbox.Main.Text
                    if textbox.flag and textbox.flag ~= "" then
                        library.flags[textbox.flag] = textbox.value
                    end
                    pcall(textbox.callback, textbox.value)
                end)

                textbox.Set = function(self, val)
                    textbox.value = tostring(val)
                    textbox.Main.Text = textbox.value
                    if textbox.flag and textbox.flag ~= "" then
                        library.flags[textbox.flag] = textbox.value
                    end
                end

                textbox.Get = function(self)
                    return textbox.value
                end

                if textbox.flag and textbox.flag ~= "" then
                    library.flags[textbox.flag] = textbox.default
                end

                sector:FixSize()
                table.insert(library.items, textbox)
                return textbox
            end

            -- ================================================================
            -- 5. SLIDER ELEMENT (Fluid Track + Precision Number Input)
            -- ================================================================
            sector.AddSlider = function(self, text, min, default, max, decimals, callback, flag)
                sector.itemCount = (sector.itemCount or 0) + 1
                local slider = {
                    text = text or "Slider",
                    min = min or 0,
                    max = max or 100,
                    decimals = (decimals ~= nil) and decimals or 0,
                    default = default or min or 0,
                    callback = callback or function() end,
                    flag = flag or text or "",
                    value = default or min or 0
                }

                local container = Instance.new("Frame", sector.Items)
                container.Name = "Slider_" .. tostring(sector.itemCount)
                container.LayoutOrder = sector.itemCount
                container.BackgroundTransparency = 1
                container.Size = UDim2.fromOffset(itemWidth, 38)
                container.ZIndex = 8

                slider.Label = Instance.new("TextLabel", container)
                slider.Label.Name = "Title"
                slider.Label.BackgroundTransparency = 1
                slider.Label.Position = UDim2.new(0, 0, 0, 0)
                slider.Label.Size = UDim2.new(1, -60, 0, 16)
                slider.Label.TextTruncate = Enum.TextTruncate.AtEnd
                slider.Label.Font = window.theme.font
                slider.Label.Text = slider.text
                slider.Label.TextColor3 = window.theme.itemscolor
                slider.Label.TextSize = 13
                slider.Label.TextXAlignment = Enum.TextXAlignment.Left
                slider.Label.ZIndex = 9

                slider.InputLabel = Instance.new("TextBox", container)
                slider.InputLabel.Name = "ValueBadge"
                slider.InputLabel.Size = UDim2.new(0, 54, 0, 18)
                slider.InputLabel.Position = UDim2.new(1, -54, 0, 0)
                slider.InputLabel.BorderSizePixel = 0
                slider.InputLabel.BackgroundColor3 = Color3.fromRGB(10, 16, 40)
                slider.InputLabel.Font = window.theme.fontcode
                slider.InputLabel.Text = tostring(slider.default)
                slider.InputLabel.TextColor3 = window.theme.accentcolor
                slider.InputLabel.TextSize = 11
                slider.InputLabel.ClearTextOnFocus = false
                slider.InputLabel.ZIndex = 9

                local badgeCorner = Instance.new("UICorner", slider.InputLabel)
                badgeCorner.CornerRadius = UDim.new(0, 4)

                local badgeStroke = Instance.new("UIStroke", slider.InputLabel)
                badgeStroke.Color = Color3.fromRGB(39, 57, 94)
                badgeStroke.Thickness = 1
                badgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                -- Slider Track
                slider.Main = Instance.new("TextButton", container)
                slider.Main.Name = "Track"
                slider.Main.Size = UDim2.new(1, 0, 0, 8)
                slider.Main.Position = UDim2.new(0, 0, 0, 24)
                slider.Main.BorderSizePixel = 0
                slider.Main.BackgroundColor3 = window.theme.slidergroove
                slider.Main.AutoButtonColor = false
                slider.Main.Text = ""
                slider.Main.ZIndex = 9

                local trackCorner = Instance.new("UICorner", slider.Main)
                trackCorner.CornerRadius = UDim.new(0, 4)

                local trackStroke = Instance.new("UIStroke", slider.Main)
                trackStroke.Color = Color3.fromRGB(39, 57, 94)
                trackStroke.Thickness = 1
                trackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                -- Active Fill Bar (Gradient Butterfly Sapphire to Luminous Crystal Cyan)
                local fillBar = Instance.new("Frame", slider.Main)
                fillBar.Name = "Fill"
                fillBar.Size = UDim2.new(0, 0, 1, 0)
                fillBar.BorderSizePixel = 0
                fillBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                fillBar.ZIndex = 10

                local fillCorner = Instance.new("UICorner", fillBar)
                fillCorner.CornerRadius = UDim.new(0, 4)

                local fillGrad = Instance.new("UIGradient", fillBar)
                fillGrad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, window.theme.accentcolor2),
                    ColorSequenceKeypoint.new(1, window.theme.accentcolor)
                })

                -- Draggable Thumb Knob
                local thumb = Instance.new("Frame", slider.Main)
                thumb.Name = "Thumb"
                thumb.Size = UDim2.fromOffset(14, 14)
                thumb.AnchorPoint = Vector2.new(0.5, 0.5)
                thumb.Position = UDim2.new(0, 0, 0.5, 0)
                thumb.BorderSizePixel = 0
                thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                thumb.ZIndex = 11

                local thumbCorner = Instance.new("UICorner", thumb)
                thumbCorner.CornerRadius = UDim.new(0, 7)

                local thumbStroke = Instance.new("UIStroke", thumb)
                thumbStroke.Color = window.theme.accentcolor
                thumbStroke.Thickness = 1.8

                local function roundVal(val)
                    if slider.decimals <= 0 then
                        return math.floor(val + 0.5)
                    else
                        local dec = slider.decimals
                        if dec < 1 and dec > 0 then
                            local rounded = math.floor(val / dec + 0.5) * dec
                            return tonumber(string.format("%.3f", rounded))
                        else
                            local mult = 10 ^ math.floor(dec)
                            local rounded = math.floor(val * mult + 0.5) / mult
                            return tonumber(string.format("%." .. tostring(math.floor(dec)) .. "f", rounded))
                        end
                    end
                end

                slider.Set = function(self, value)
                    local clamped = math.clamp(tonumber(value) or slider.min, slider.min, slider.max)
                    slider.value = roundVal(clamped)

                    local percent = (slider.value - slider.min) / math.max(slider.max - slider.min, 0.0001)
                    percent = math.clamp(percent, 0, 1)

                    fillBar.Size = UDim2.new(percent, 0, 1, 0)
                    thumb.Position = UDim2.new(percent, 0, 0.5, 0)

                    if slider.decimals <= 0 then
                        slider.InputLabel.Text = tostring(math.floor(slider.value + 0.5))
                    elseif slider.decimals < 1 then
                        slider.InputLabel.Text = string.format("%.1f", slider.value)
                    else
                        slider.InputLabel.Text = string.format("%." .. tostring(math.floor(slider.decimals)) .. "f", slider.value)
                    end

                    if slider.flag and slider.flag ~= "" then
                        library.flags[slider.flag] = slider.value
                    end
                    pcall(slider.callback, slider.value)
                end

                slider.Get = function(self)
                    return slider.value
                end

                slider.Refresh = function(self, inputX)
                    if not inputX then return end
                    local trackAbs = slider.Main.AbsolutePosition.X
                    local trackW = slider.Main.AbsoluteSize.X
                    local percent = math.clamp((inputX - trackAbs) / trackW, 0, 1)
                    local rawVal = slider.min + (percent * (slider.max - slider.min))
                    slider:Set(rawVal)
                end

                local isDragging = false
                slider.Main.InputBegan:Connect(function(input)
                    if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
                        isDragging = true
                        slider:Refresh(input.Position.X)
                    end
                end)

                uis.InputEnded:Connect(function(input)
                    if (input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch) then
                        isDragging = false
                    end
                end)

                uis.InputChanged:Connect(function(input)
                    if isDragging and ((input.UserInputType == Enum.UserInputType.MouseMovement) or (input.UserInputType == Enum.UserInputType.Touch)) then
                        slider:Refresh(input.Position.X)
                    end
                end)

                slider.InputLabel.FocusLost:Connect(function()
                    local typedNum = tonumber(slider.InputLabel.Text)
                    if typedNum then
                        slider:Set(typedNum)
                    else
                        slider.InputLabel.Text = tostring(slider.value)
                    end
                end)

                slider:Set(slider.default)

                sector:FixSize()
                table.insert(library.items, slider)
                return slider
            end

            -- ================================================================
            -- 6. DROPDOWN ELEMENT (Chevron Arrow + Floating Modal + Filter)
            -- ================================================================
            sector.AddDropdown = function(self, text, items, default, multichoice, callback, flag)
                sector.itemCount = (sector.itemCount or 0) + 1
                local dropdown = {
                    text = text or "Dropdown",
                    defaultitems = items or {},
                    default = default,
                    multichoice = multichoice or false,
                    callback = callback or function() end,
                    flag = flag or text or "",
                    values = {},
                    value = default,
                    isOpen = false
                }

                local container = Instance.new("Frame", sector.Items)
                container.Name = "Dropdown_" .. tostring(sector.itemCount)
                container.LayoutOrder = sector.itemCount
                container.BackgroundTransparency = 1
                container.Size = UDim2.fromOffset(itemWidth, 48)
                container.ZIndex = 8

                dropdown.Label = Instance.new("TextLabel", container)
                dropdown.Label.Name = "Title"
                dropdown.Label.BackgroundTransparency = 1
                dropdown.Label.Position = UDim2.new(0, 0, 0, 0)
                dropdown.Label.Size = UDim2.new(1, 0, 0, 16)
                dropdown.Label.Font = window.theme.font
                dropdown.Label.Text = dropdown.text
                dropdown.Label.TextColor3 = window.theme.itemscolor
                dropdown.Label.TextSize = 13
                dropdown.Label.TextXAlignment = Enum.TextXAlignment.Left
                dropdown.Label.ZIndex = 9

                dropdown.Main = Instance.new("TextButton", container)
                dropdown.Main.Name = "dropdown"
                dropdown.Main.Size = UDim2.new(1, 0, 0, 26)
                dropdown.Main.Position = UDim2.new(0, 0, 0, 18)
                dropdown.Main.BorderSizePixel = 0
                dropdown.Main.BackgroundColor3 = Color3.fromRGB(12, 18, 46)
                dropdown.Main.AutoButtonColor = false
                dropdown.Main.Text = ""
                dropdown.Main.ZIndex = 9

                local ddCorner = Instance.new("UICorner", dropdown.Main)
                ddCorner.CornerRadius = UDim.new(0, 6)

                local ddStroke = Instance.new("UIStroke", dropdown.Main)
                ddStroke.Color = Color3.fromRGB(39, 57, 94)
                ddStroke.Thickness = 1
                ddStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                dropdown.Main.MouseEnter:Connect(function()
                    smoothTween(dropdown.Main, {BackgroundColor3 = Color3.fromRGB(20, 32, 72)}, 0.12)
                    smoothTween(ddStroke, {Color = Color3.fromRGB(103, 154, 189)}, 0.12)
                end)
                dropdown.Main.MouseLeave:Connect(function()
                    if not dropdown.isOpen then
                        smoothTween(dropdown.Main, {BackgroundColor3 = Color3.fromRGB(12, 18, 46)}, 0.12)
                        smoothTween(ddStroke, {Color = Color3.fromRGB(39, 57, 94)}, 0.12)
                    end
                end)

                dropdown.SelectedLabel = Instance.new("TextLabel", dropdown.Main)
                dropdown.SelectedLabel.Name = "SelectedText"
                dropdown.SelectedLabel.BackgroundTransparency = 1
                dropdown.SelectedLabel.Position = UDim2.new(0, 10, 0, 0)
                dropdown.SelectedLabel.Size = UDim2.new(1, -34, 1, 0)
                dropdown.SelectedLabel.Font = window.theme.fontbold
                dropdown.SelectedLabel.Text = "None"
                dropdown.SelectedLabel.TextColor3 = window.theme.itemscolor2
                dropdown.SelectedLabel.TextSize = 12
                dropdown.SelectedLabel.TextXAlignment = Enum.TextXAlignment.Left
                dropdown.SelectedLabel.TextTruncate = Enum.TextTruncate.AtEnd
                dropdown.SelectedLabel.ZIndex = 10

                local chevron = Instance.new("TextLabel", dropdown.Main)
                chevron.Name = "Chevron"
                chevron.BackgroundTransparency = 1
                chevron.Position = UDim2.new(1, -22, 0, 0)
                chevron.Size = UDim2.new(0, 18, 1, 0)
                chevron.Font = window.theme.fontbold
                chevron.Text = "▼"
                chevron.TextColor3 = window.theme.accentcolor
                chevron.TextSize = 10
                chevron.ZIndex = 10

                -- Floating Popup Frame
                dropdown.ItemsFrame = Instance.new("Frame", window.Frame)
                dropdown.ItemsFrame.Name = "DropdownPopup"
                dropdown.ItemsFrame.BorderSizePixel = 0
                dropdown.ItemsFrame.BackgroundColor3 = Color3.fromRGB(8, 13, 34)
                dropdown.ItemsFrame.BackgroundTransparency = 0.04
                dropdown.ItemsFrame.Size = UDim2.fromOffset(200, 0)
                dropdown.ItemsFrame.Visible = false
                dropdown.ItemsFrame.ClipsDescendants = true
                dropdown.ItemsFrame.ZIndex = 160

                local popCorner = Instance.new("UICorner", dropdown.ItemsFrame)
                popCorner.CornerRadius = UDim.new(0, 6)

                local popStroke = Instance.new("UIStroke", dropdown.ItemsFrame)
                popStroke.Color = window.theme.accentcolor
                popStroke.Thickness = 1.1
                popStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                local searchBox = Instance.new("TextBox", dropdown.ItemsFrame)
                searchBox.Name = "SearchFilter"
                searchBox.Size = UDim2.new(1, -12, 0, 22)
                searchBox.Position = UDim2.new(0, 6, 0, 6)
                searchBox.BorderSizePixel = 0
                searchBox.BackgroundColor3 = Color3.fromRGB(16, 25, 58)
                searchBox.Font = window.theme.font
                searchBox.PlaceholderText = "🔍 Tìm kiếm..."
                searchBox.PlaceholderColor3 = Color3.fromRGB(104, 134, 170)
                searchBox.Text = ""
                searchBox.TextColor3 = window.theme.itemscolor2
                searchBox.TextSize = 12
                searchBox.ClearTextOnFocus = false
                searchBox.ZIndex = 161

                local sCorner = Instance.new("UICorner", searchBox)
                sCorner.CornerRadius = UDim.new(0, 4)

                local scrollList = Instance.new("ScrollingFrame", dropdown.ItemsFrame)
                scrollList.Name = "ScrollList"
                scrollList.BackgroundTransparency = 1
                scrollList.BorderSizePixel = 0
                scrollList.Position = UDim2.new(0, 6, 0, 32)
                scrollList.Size = UDim2.new(1, -12, 1, -38)
                scrollList.ScrollBarThickness = 4
                scrollList.ScrollBarImageColor3 = window.theme.accentcolor
                scrollList.ScrollingDirection = Enum.ScrollingDirection.Y
                scrollList.AutomaticCanvasSize = Enum.AutomaticSize.Y
                scrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
                scrollList.ZIndex = 161

                local scrollLayout = Instance.new("UIListLayout", scrollList)
                scrollLayout.FillDirection = Enum.FillDirection.Vertical
                scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
                scrollLayout.Padding = UDim.new(0, 4)

                dropdown.isSelected = function(self, item)
                    if dropdown.multichoice then
                        return table.find(dropdown.values, item) ~= nil
                    else
                        return dropdown.value == item
                    end
                end

                dropdown.updateText = function(self)
                    if dropdown.multichoice then
                        if #dropdown.values == 0 then
                            dropdown.SelectedLabel.Text = "None"
                        else
                            dropdown.SelectedLabel.Text = table.concat(dropdown.values, ", ")
                        end
                    else
                        dropdown.SelectedLabel.Text = tostring(dropdown.value or "None")
                    end
                end

                dropdown.Set = function(self, val)
                    if dropdown.multichoice then
                        if typeof(val) == "table" then
                            dropdown.values = val
                        else
                            dropdown.values = {val}
                        end
                        dropdown:updateText()
                        if dropdown.flag and dropdown.flag ~= "" then
                            library.flags[dropdown.flag] = dropdown.values
                        end
                        pcall(dropdown.callback, dropdown.values)
                    else
                        dropdown.value = val
                        dropdown:updateText()
                        if dropdown.flag and dropdown.flag ~= "" then
                            library.flags[dropdown.flag] = dropdown.value
                        end
                        pcall(dropdown.callback, dropdown.value)
                    end
                    dropdown:updateItemVisuals()
                end

                dropdown.Get = function(self)
                    return dropdown.multichoice and dropdown.values or dropdown.value
                end

                dropdown.updateItemVisuals = function(self)
                    for _, child in ipairs(scrollList:GetChildren()) do
                        if child:IsA("TextButton") then
                            local itemName = child.Name
                            local selected = dropdown:isSelected(itemName)
                            if selected then
                                child.BackgroundColor3 = Color3.fromRGB(30, 64, 138)
                                child.TextColor3 = Color3.fromRGB(232, 246, 255)
                            else
                                child.BackgroundColor3 = Color3.fromRGB(14, 22, 50)
                                child.TextColor3 = window.theme.itemscolor
                            end
                        end
                    end
                end

                dropdown.Close = function(self)
                    dropdown.isOpen = false
                    chevron.Text = "▼"
                    smoothTween(ddStroke, {Color = Color3.fromRGB(39, 57, 94)}, 0.15)
                    smoothTween(dropdown.ItemsFrame, {Size = UDim2.fromOffset(dropdown.ItemsFrame.Size.X.Offset, 0)}, 0.15)
                    task.wait(0.15)
                    dropdown.ItemsFrame.Visible = false
                    if window.CurrentOpenDropdown == dropdown then
                        window.CurrentOpenDropdown = nil
                    end
                    if window.DropdownOverlay then
                        window.DropdownOverlay.Visible = false
                    end
                end

                dropdown.Open = function(self)
                    if window.CloseDropdown then window:CloseDropdown() end
                    dropdown.isOpen = true
                    window.CurrentOpenDropdown = dropdown
                    if window.DropdownOverlay then window.DropdownOverlay.Visible = true end

                    chevron.Text = "▲"
                    smoothTween(ddStroke, {Color = window.theme.accentcolor}, 0.15)
                    local absPos = dropdown.Main.AbsolutePosition - window.Frame.AbsolutePosition
                    local absSize = dropdown.Main.AbsoluteSize

                    dropdown.ItemsFrame.Position = UDim2.fromOffset(absPos.X, absPos.Y + absSize.Y + 4)
                    dropdown.ItemsFrame.Size = UDim2.fromOffset(absSize.X, 0)
                    dropdown.ItemsFrame.Visible = true

                    local targetH = math.clamp((#dropdown.defaultitems * 26) + 42, 60, 180)
                    smoothTween(dropdown.ItemsFrame, {Size = UDim2.fromOffset(absSize.X, targetH)}, 0.18)
                end

                dropdown.Toggle = function(self)
                    if dropdown.isOpen then
                        dropdown:Close()
                    else
                        dropdown:Open()
                    end
                end

                dropdown.Add = function(self, itemStr)
                    local itemName = tostring(itemStr)
                    local itemBtn = Instance.new("TextButton", scrollList)
                    itemBtn.Name = itemName
                    itemBtn.Size = UDim2.new(1, 0, 0, 22)
                    itemBtn.BorderSizePixel = 0
                    itemBtn.BackgroundColor3 = Color3.fromRGB(14, 22, 50)
                    itemBtn.AutoButtonColor = false
                    itemBtn.Font = window.theme.font
                    itemBtn.Text = "  " .. itemName
                    itemBtn.TextColor3 = window.theme.itemscolor
                    itemBtn.TextSize = 12
                    itemBtn.TextXAlignment = Enum.TextXAlignment.Left
                    itemBtn.ZIndex = 162

                    local iCorner = Instance.new("UICorner", itemBtn)
                    iCorner.CornerRadius = UDim.new(0, 4)

                    itemBtn.MouseButton1Click:Connect(function()
                        if dropdown.multichoice then
                            local idx = table.find(dropdown.values, itemName)
                            if idx then
                                table.remove(dropdown.values, idx)
                            else
                                table.insert(dropdown.values, itemName)
                            end
                            dropdown:Set(dropdown.values)
                        else
                            dropdown:Set(itemName)
                            dropdown:Close()
                        end
                    end)

                    itemBtn.MouseEnter:Connect(function()
                        if not dropdown:isSelected(itemName) then
                            smoothTween(itemBtn, {BackgroundColor3 = Color3.fromRGB(28, 44, 88)}, 0.1)
                        end
                    end)
                    itemBtn.MouseLeave:Connect(function()
                        if not dropdown:isSelected(itemName) then
                            smoothTween(itemBtn, {BackgroundColor3 = Color3.fromRGB(14, 22, 50)}, 0.1)
                        end
                    end)
                end

                dropdown.Clear = function(self)
                    for _, child in ipairs(scrollList:GetChildren()) do
                        if child:IsA("TextButton") then
                            child:Destroy()
                        end
                    end
                end

                dropdown.Refresh = function(self, newItems)
                    dropdown.defaultitems = newItems or {}
                    dropdown:Clear()
                    for _, v in ipairs(dropdown.defaultitems) do
                        dropdown:Add(v)
                    end
                    dropdown:updateItemVisuals()
                end

                dropdown.GetOptions = function(self)
                    return dropdown.defaultitems
                end

                searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                    local query = searchBox.Text:lower()
                    for _, child in ipairs(scrollList:GetChildren()) do
                        if child:IsA("TextButton") then
                            if query == "" or child.Name:lower():find(query, 1, true) then
                                child.Visible = true
                            else
                                child.Visible = false
                            end
                        end
                    end
                end)

                dropdown.Main.MouseButton1Click:Connect(function()
                    dropdown:Toggle()
                end)

                for _, v in ipairs(dropdown.defaultitems) do
                    dropdown:Add(v)
                end

                if dropdown.default ~= nil then
                    dropdown:Set(dropdown.default)
                else
                    dropdown:updateText()
                end

                sector:FixSize()
                table.insert(library.items, dropdown)
                return dropdown
            end

            -- ================================================================
            -- 7. KEYBIND ELEMENT
            -- ================================================================
            sector.AddKeybind = function(self, text, default, newkeycallback, callback, flag)
                local keybind = {
                    text = text or "Keybind",
                    default = default or "None",
                    value = default or "None",
                    newkeycallback = newkeycallback or function() end,
                    callback = callback or function() end,
                    flag = flag or text or ""
                }

                local container = Instance.new("Frame", sector.Items)
                container.Name = "KeybindContainer"
                container.BackgroundTransparency = 1
                container.Size = UDim2.new(1, 0, 0, 26)
                container.ZIndex = 8

                local label = Instance.new("TextLabel", container)
                label.Name = "Label"
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(1, -70, 1, 0)
                label.Font = window.theme.font
                label.Text = keybind.text
                label.TextColor3 = window.theme.itemscolor
                label.TextSize = 13
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.ZIndex = 9

                local keyBtn = Instance.new("TextButton", container)
                keyBtn.Name = "KeyBtn"
                keyBtn.Size = UDim2.new(0, 64, 0, 20)
                keyBtn.Position = UDim2.new(1, -64, 0.5, -10)
                keyBtn.BorderSizePixel = 0
                keyBtn.BackgroundColor3 = Color3.fromRGB(14, 22, 50)
                keyBtn.Font = window.theme.fontcode
                keyBtn.Text = "[" .. (typeof(keybind.default) == "EnumItem" and keybind.default.Name or tostring(keybind.default)) .. "]"
                keyBtn.TextColor3 = window.theme.accentcolor
                keyBtn.TextSize = 11
                keyBtn.AutoButtonColor = false
                keyBtn.ZIndex = 9

                local kCorner = Instance.new("UICorner", keyBtn)
                kCorner.CornerRadius = UDim.new(0, 4)

                local kStroke = Instance.new("UIStroke", keyBtn)
                kStroke.Color = Color3.fromRGB(39, 57, 94)
                kStroke.Thickness = 1
                kStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                keybind.Set = function(self, key)
                    keybind.value = key
                    local nameStr = (typeof(key) == "EnumItem" and key.Name) or tostring(key)
                    keyBtn.Text = "[" .. nameStr .. "]"
                    if keybind.flag and keybind.flag ~= "" then
                        library.flags[keybind.flag] = keybind.value
                    end
                    pcall(keybind.newkeycallback, key)
                end

                keybind.Get = function(self)
                    return keybind.value
                end

                local listening = false
                keyBtn.MouseButton1Click:Connect(function()
                    listening = true
                    keyBtn.Text = "[...]"
                    keyBtn.TextColor3 = window.theme.accentcolor
                    kStroke.Color = window.theme.accentcolor
                end)

                uis.InputBegan:Connect(function(input, gpe)
                    if listening and not gpe then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            listening = false
                            kStroke.Color = Color3.fromRGB(39, 57, 94)
                            keyBtn.TextColor3 = window.theme.accentcolor
                            if input.KeyCode == Enum.KeyCode.Escape then
                                keybind:Set("None")
                            else
                                keybind:Set(input.KeyCode)
                            end
                        end
                    elseif not gpe and input.UserInputType == Enum.UserInputType.Keyboard then
                        if typeof(keybind.value) == "EnumItem" and input.KeyCode == keybind.value then
                            pcall(keybind.callback)
                        end
                    end
                end)

                sector:FixSize()
                table.insert(library.items, keybind)
                return keybind
            end

            -- ================================================================
            -- 8. COLORPICKER ELEMENT
            -- ================================================================
            sector.AddColorpicker = function(self, text, default, callback, flag)
                sector.itemCount = (sector.itemCount or 0) + 1
                local colorpicker = {
                    text = text or "Colorpicker",
                    default = default or Color3.fromRGB(125, 211, 252),
                    callback = callback or function() end,
                    flag = flag or text or "",
                    value = default or Color3.fromRGB(125, 211, 252)
                }

                local container = Instance.new("Frame", sector.Items)
                container.Name = "Colorpicker_" .. tostring(sector.itemCount)
                container.LayoutOrder = sector.itemCount
                container.BackgroundTransparency = 1
                container.Size = UDim2.fromOffset(itemWidth, 24)
                container.ZIndex = 8

                local label = Instance.new("TextLabel", container)
                label.Name = "Label"
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(1, -36, 1, 0)
                label.Font = window.theme.font
                label.Text = colorpicker.text
                label.TextColor3 = window.theme.itemscolor
                label.TextSize = 13
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.ZIndex = 9

                local swatch = Instance.new("TextButton", container)
                swatch.Name = "Swatch"
                swatch.Size = UDim2.new(0, 24, 0, 16)
                swatch.Position = UDim2.new(1, -26, 0.5, -8)
                swatch.BorderSizePixel = 0
                swatch.BackgroundColor3 = colorpicker.value
                swatch.AutoButtonColor = false
                swatch.Text = ""
                swatch.ZIndex = 9

                local sCorner = Instance.new("UICorner", swatch)
                sCorner.CornerRadius = UDim.new(0, 4)

                local sStroke = Instance.new("UIStroke", swatch)
                sStroke.Color = Color3.fromRGB(255, 255, 255)
                sStroke.Thickness = 1
                sStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                colorpicker.Set = function(self, val)
                    colorpicker.value = val
                    swatch.BackgroundColor3 = val
                    if colorpicker.flag and colorpicker.flag ~= "" then
                        library.flags[colorpicker.flag] = val
                    end
                    pcall(colorpicker.callback, val)
                end

                colorpicker.Get = function(self)
                    return colorpicker.value
                end

                sector:FixSize()
                table.insert(library.items, colorpicker)
                return colorpicker
            end

            -- ================================================================
            -- 9. SEPERATOR ELEMENT (Gradient Crystal Cyan & Ice-Foam Divider)
            -- ================================================================
            sector.AddSeperator = function(self, text, ranbow)
                local seperator = {
                    text = text or ""
                }

                seperator.main = Instance.new("Frame", sector.Items)
                seperator.main.Name = "Seperator"
                seperator.main.BackgroundTransparency = 1
                seperator.main.Size = UDim2.fromOffset(itemWidth, 18)
                seperator.main.ZIndex = 8

                local divLine = Instance.new("Frame", seperator.main)
                divLine.Name = "Line"
                divLine.BorderSizePixel = 0
                divLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                divLine.Size = UDim2.new(1, 0, 0, 1)
                divLine.Position = UDim2.new(0, 0, 0.5, 0)
                divLine.ZIndex = 8

                local dGrad = Instance.new("UIGradient", divLine)
                dGrad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(6, 12, 36)),
                    ColorSequenceKeypoint.new(0.3, window.theme.accentcolor2),
                    ColorSequenceKeypoint.new(0.5, window.theme.accentcolor),
                    ColorSequenceKeypoint.new(0.7, window.theme.azurecolor),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 12, 36))
                })

                if seperator.text ~= "" then
                    local badgeFrame = Instance.new("Frame", seperator.main)
                    badgeFrame.Name = "Badge"
                    badgeFrame.BorderSizePixel = 0
                    badgeFrame.BackgroundColor3 = window.theme.sectorcolor
                    badgeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
                    badgeFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
                    badgeFrame.ZIndex = 9

                    local tSize = textservice:GetTextSize(seperator.text, 11, window.theme.fontbold, Vector2.new(1000, 50))
                    badgeFrame.Size = UDim2.fromOffset(tSize.X + 16, 16)

                    local bCorner = Instance.new("UICorner", badgeFrame)
                    bCorner.CornerRadius = UDim.new(0, 4)

                    seperator.label = Instance.new("TextLabel", badgeFrame)
                    seperator.label.Name = "Label"
                    seperator.label.BackgroundTransparency = 1
                    seperator.label.Size = UDim2.fromScale(1, 1)
                    seperator.label.Font = window.theme.fontbold
                    seperator.label.Text = seperator.text
                    seperator.label.TextColor3 = (ranbow and window.theme.accentcolor) or window.theme.toptextcolor
                    seperator.label.TextSize = 11
                    seperator.label.ZIndex = 10
                end

                seperator.Set = function(self, value)
                    if seperator.label then
                        seperator.label.Text = tostring(value)
                    end
                end

                sector:FixSize()
                return seperator
            end

            return sector
        end

        table.insert(window.Tabs, tab)
        return tab
    end

    return window
end

-- ============================================================================
-- FLOATING TOPBAR HUD ("StatBySmell" - Resonator Capsule HUD)
-- FPS, Ping, and Mobile-Friendly Draggable Hub Menu Toggle
-- ============================================================================
repeat task.wait() until game:IsLoaded()

if not coregui:FindFirstChild("StatBySmell") then
    local GuiStat = Instance.new("ScreenGui")
    GuiStat.Name = "StatBySmell"
    GuiStat.Parent = coregui
    GuiStat.ResetOnSpawn = false
    GuiStat.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    GuiStat.IgnoreGuiInset = true
    GuiStat.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    protectGui(GuiStat)

    -- Floating Capsule Container
    local TopbarContainer = Instance.new("Frame", GuiStat)
    TopbarContainer.Name = "Frame"
    TopbarContainer.BorderSizePixel = 0
    TopbarContainer.BackgroundColor3 = Color3.fromRGB(4, 7, 22)
    TopbarContainer.BackgroundTransparency = 0.14
    TopbarContainer.Position = UDim2.new(0.5, -160, 0, 6)
    TopbarContainer.Size = UDim2.new(0, 320, 0, 32)
    TopbarContainer.ZIndex = 50

    local topbarCorner = Instance.new("UICorner", TopbarContainer)
    topbarCorner.CornerRadius = UDim.new(0, 16)

    local topbarStroke = Instance.new("UIStroke", TopbarContainer)
    topbarStroke.Color = Color3.fromRGB(103, 154, 189)
    topbarStroke.Thickness = 1.2
    topbarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local topbarStrokeGrad = Instance.new("UIGradient", topbarStroke)
    topbarStrokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(59, 130, 246)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(125, 211, 252)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 194, 221))
    })

    MakeDraggable(TopbarContainer, TopbarContainer)

    local UIListLayout = Instance.new("UIListLayout", TopbarContainer)
    UIListLayout.FillDirection = Enum.FillDirection.Horizontal
    UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    UIListLayout.Padding = UDim.new(0, 8)

    -- 1. FPS Pill
    local _1FPSCount = Instance.new("Frame", TopbarContainer)
    _1FPSCount.Name = "1FPSCount"
    _1FPSCount.BackgroundTransparency = 1
    _1FPSCount.LayoutOrder = 1
    _1FPSCount.Size = UDim2.new(0, 80, 0, 24)
    _1FPSCount.ZIndex = 51

    local IconButton = Instance.new("TextButton", _1FPSCount)
    IconButton.Name = "IconButton"
    IconButton.BorderSizePixel = 0
    IconButton.BackgroundColor3 = Color3.fromRGB(12, 18, 47)
    IconButton.BackgroundTransparency = 0.25
    IconButton.Size = UDim2.fromScale(1, 1)
    IconButton.AutoButtonColor = false
    IconButton.Text = ""
    IconButton.ZIndex = 52

    local fCorner = Instance.new("UICorner", IconButton)
    fCorner.CornerRadius = UDim.new(0, 12)

    local IconLabel = Instance.new("TextLabel", IconButton)
    IconLabel.Name = "IconLabel"
    IconLabel.BackgroundTransparency = 1
    IconLabel.Size = UDim2.fromScale(1, 1)
    IconLabel.Font = Enum.Font.GothamBold
    IconLabel.Text = "FPS: 60"
    IconLabel.TextColor3 = Color3.fromRGB(52, 211, 153)
    IconLabel.TextSize = 12
    IconLabel.ZIndex = 53

    -- 2. Ping Pill
    local _3PingCount = Instance.new("Frame", TopbarContainer)
    _3PingCount.Name = "3PingCount"
    _3PingCount.BackgroundTransparency = 1
    _3PingCount.LayoutOrder = 2
    _3PingCount.Size = UDim2.new(0, 88, 0, 24)
    _3PingCount.ZIndex = 51

    local IconButton_2 = Instance.new("TextButton", _3PingCount)
    IconButton_2.Name = "IconButton"
    IconButton_2.BorderSizePixel = 0
    IconButton_2.BackgroundColor3 = Color3.fromRGB(12, 18, 47)
    IconButton_2.BackgroundTransparency = 0.25
    IconButton_2.Size = UDim2.fromScale(1, 1)
    IconButton_2.AutoButtonColor = false
    IconButton_2.Text = ""
    IconButton_2.ZIndex = 52

    local pCorner = Instance.new("UICorner", IconButton_2)
    pCorner.CornerRadius = UDim.new(0, 12)

    local IconLabel_2 = Instance.new("TextLabel", IconButton_2)
    IconLabel_2.Name = "IconLabel"
    IconLabel_2.BackgroundTransparency = 1
    IconLabel_2.Size = UDim2.fromScale(1, 1)
    IconLabel_2.Font = Enum.Font.GothamBold
    IconLabel_2.Text = "Ping: 0 ms"
    IconLabel_2.TextColor3 = Color3.fromRGB(52, 211, 153)
    IconLabel_2.TextSize = 12
    IconLabel_2.ZIndex = 53

    -- 3. Menu Toggle Button (HelmXGenimi Menu)
    local _2ToggleMenu = Instance.new("Frame", TopbarContainer)
    _2ToggleMenu.Name = "2ToggleMenu"
    _2ToggleMenu.BackgroundTransparency = 1
    _2ToggleMenu.LayoutOrder = 3
    _2ToggleMenu.Size = UDim2.new(0, 108, 0, 24)
    _2ToggleMenu.ZIndex = 51

    local IconButton_3 = Instance.new("TextButton", _2ToggleMenu)
    IconButton_3.Name = "IconButton"
    IconButton_3.BorderSizePixel = 0
    IconButton_3.BackgroundColor3 = Color3.fromRGB(22, 48, 106)
    IconButton_3.BackgroundTransparency = 0.10
    IconButton_3.Size = UDim2.fromScale(1, 1)
    IconButton_3.AutoButtonColor = false
    IconButton_3.Text = ""
    IconButton_3.ZIndex = 52

    local mCorner = Instance.new("UICorner", IconButton_3)
    mCorner.CornerRadius = UDim.new(0, 12)

    local mGrad = Instance.new("UIGradient", IconButton_3)
    mGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(37, 99, 235)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 116, 184))
    })

    local mStroke = Instance.new("UIStroke", IconButton_3)
    mStroke.Color = Color3.fromRGB(125, 211, 252)
    mStroke.Thickness = 1.2
    mStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local IconImage = Instance.new("TextLabel", IconButton_3)
    IconImage.Name = "IconImage"
    IconImage.BackgroundTransparency = 1
    IconImage.Position = UDim2.new(0, 8, 0, 0)
    IconImage.Size = UDim2.new(0, 16, 1, 0)
    IconImage.Font = Enum.Font.GothamBold
    IconImage.Text = "◈"
    IconImage.TextColor3 = Color3.fromRGB(186, 230, 253)
    IconImage.TextSize = 13
    IconImage.ZIndex = 53

    local IconLabel_3 = Instance.new("TextLabel", IconButton_3)
    IconLabel_3.Name = "IconLabel"
    IconLabel_3.BackgroundTransparency = 1
    IconLabel_3.Position = UDim2.new(0, 26, 0, 0)
    IconLabel_3.Size = UDim2.new(1, -30, 1, 0)
    IconLabel_3.Font = Enum.Font.GothamBold
    IconLabel_3.Text = "Helm MENU"
    IconLabel_3.TextColor3 = Color3.fromRGB(248, 252, 255)
    IconLabel_3.TextSize = 11
    IconLabel_3.TextXAlignment = Enum.TextXAlignment.Left
    IconLabel_3.ZIndex = 53

    IconButton_3.MouseEnter:Connect(function()
        smoothTween(IconButton_3, {BackgroundColor3 = Color3.fromRGB(59, 130, 246)}, 0.12)
        smoothTween(mStroke, {Color = Color3.fromRGB(186, 230, 253)}, 0.12)
    end)
    IconButton_3.MouseLeave:Connect(function()
        smoothTween(IconButton_3, {BackgroundColor3 = Color3.fromRGB(22, 48, 106)}, 0.12)
        smoothTween(mStroke, {Color = Color3.fromRGB(125, 211, 252)}, 0.12)
    end)

    -- Menu Click Handler
    local lastMenuToggle = 0
    local function toggleHubMenu()
        local now = tick()
        if (now - lastMenuToggle) < 0.2 then return end
        lastMenuToggle = now

        smoothTween(IconButton_3, {BackgroundColor3 = Color3.fromRGB(125, 211, 252)}, 0.08)
        task.wait(0.08)
        smoothTween(IconButton_3, {BackgroundColor3 = Color3.fromRGB(22, 48, 106)}, 0.15)

        local found = false
        if env.uilib then
            pcall(function()
                local m = env.uilib:FindFirstChild("main")
                if m then
                    m.Visible = not m.Visible
                    found = true
                end
            end)
        end
        if not found then
            local containers = {}
            if gethui then pcall(function() table.insert(containers, gethui()) end) end
            pcall(function() table.insert(containers, coregui) end)
            local lp = players.LocalPlayer
            if lp and lp:FindFirstChild("PlayerGui") then
                table.insert(containers, lp.PlayerGui)
            end
            for _, c in ipairs(containers) do
                pcall(function()
                    for _, v in pairs(c:GetChildren()) do
                        local m = v:FindFirstChild("main")
                        if m then
                            m.Visible = not m.Visible
                            found = true
                            break
                        end
                    end
                end)
                if found then break end
            end
        end
    end

    IconButton_3.Activated:Connect(toggleHubMenu)
    IconButton_3.MouseButton1Click:Connect(toggleHubMenu)

    -- Live Heartbeat Loops (FPS & Ping Monitoring)
    local frames = 0
    local fpsConn = runservice.RenderStepped:Connect(function()
        frames = frames + 1
    end)
    trackConn(fpsConn)

    task.spawn(function()
        while GuiStat and GuiStat.Parent do
            task.wait(1)
            if not (GuiStat and GuiStat.Parent) then break end
            pcall(function()
                local currFPS = frames
                frames = 0
                IconLabel.Text = "FPS " .. tostring(currFPS)
                if currFPS < 20 then
                    IconLabel.TextColor3 = Color3.fromRGB(239, 68, 68)   -- Crimson (Lag)
                elseif currFPS < 40 then
                    IconLabel.TextColor3 = Color3.fromRGB(245, 158, 11)  -- Amber (Medium)
                elseif currFPS < 55 then
                    IconLabel.TextColor3 = Color3.fromRGB(56, 189, 248)  -- Azure Sky (Good)
                else
                    IconLabel.TextColor3 = Color3.fromRGB(52, 211, 153)  -- Glacio Emerald (Smooth)
                end

                local netStats = stats:FindFirstChild("Network")
                local sItem = netStats and netStats:FindFirstChild("ServerStatsItem")
                local dataPing = sItem and sItem:FindFirstChild("Data Ping")
                if dataPing then
                    local pingStr = dataPing:GetValueString()
                    local ping = math.round(tonumber(string.split(pingStr, "(")[1]) or 0)
                    IconLabel_2.Text = "Ping: " .. tostring(ping) .. " ms"
                    if ping < 80 then
                        IconLabel_2.TextColor3 = Color3.fromRGB(52, 211, 153)
                    elseif ping < 150 then
                        IconLabel_2.TextColor3 = Color3.fromRGB(56, 189, 248)
                    elseif ping < 250 then
                        IconLabel_2.TextColor3 = Color3.fromRGB(245, 158, 11)
                    else
                        IconLabel_2.TextColor3 = Color3.fromRGB(239, 68, 68)
                    end
                end
            end)
        end
    end)
end

return library
