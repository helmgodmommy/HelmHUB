--[[
    ========================================================================
    HelmHUB | Universal Fast Loader (1 Script Cho All Game)
    GitHub: https://github.com/helmgodmommy/HelmHUB (branch: main)
    Tác giả: dj & VANTA
    Phiên bản: 5.2 (Zero-Poll Parallel GitHub Loader)
    ========================================================================
    Cách dùng (1 dòng duy nhất cho mọi game hỗ trợ):
      loadstring(game:HttpGet("https://raw.githubusercontent.com/helmgodmommy/HelmHUB/main/HelmHub.lua"))()
    ========================================================================
]]

if not game:IsLoaded() then
    pcall(function() game.Loaded:Wait() end)
end

local Players = game:GetService("Players")
if not Players.LocalPlayer then
    pcall(function()
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    end)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local placeId = game.PlaceId
local gameId = game.GameId
local env = (typeof(getgenv) == "function" and getgenv()) or _G

local bootId = (tonumber(env.HelmHubBootId) or 0) + 1
env.HelmHubBootId = bootId

local GITHUB_RAW_BASE = "https://raw.githubusercontent.com/helmgodmommy/HelmHUB/main/"

local function sendCoreNotification(payload)
    StarterGui:SetCore("SendNotification", payload)
end

local function Notify(title, text, duration)
    local t = tostring(title or "HelmHUB")
    local msg = tostring(text or "")
    pcall(sendCoreNotification, {
        Title = t,
        Text = msg,
        Duration = tonumber(duration) or 3
    })
    print(string.format("[HelmHUB] %s: %s", t, msg))
end

-- ========================================================================
-- 1. CẤU HÌNH GAME & NHẬN DIỆN TỰ ĐỘNG (ZERO-ALLOCATION LOOKUP)
-- ========================================================================
local Games = {
    {
        Name = "Anime Eyes",
        Path = "games/AnimeEyes.lua",
        LocalPaths = { "games/AnimeEyes.lua", "Anime Eyes/AnimeEyes.lua", "AnimeEyes.lua" },
        PlaceIds = { 97617452700163 },
        UniverseIds = {},
        SignatureCheck = function()
            local rem = ReplicatedStorage:FindFirstChild("Remotes")
            return rem ~= nil and (rem:FindFirstChild("UnlockEye") ~= nil or rem:FindFirstChild("BossDrop") ~= nil or rem:FindFirstChild("Pad") ~= nil)
        end
    },
    {
        Name = "Anime Dimensions",
        Path = "games/AnimeDimensions.lua",
        LocalPaths = { "games/AnimeDimensions.lua", "Anime dimesion/AnimeDimesion.lua", "ADS.lua" },
        PlaceIds = { 6938803436, 6990129309, 6990133340, 6990131029, 7338881230, 7274690025 },
        UniverseIds = { 2712497672 }
    },
    {
        Name = "Card Origins",
        Path = "games/CardOrigins.lua",
        LocalPaths = { "games/CardOrigins.lua", "Card Origins/CardOrigins.lua", "CardOrigins.lua" },
        PlaceIds = { 78312396550517 },
        UniverseIds = {}
    },
    {
        Name = "Anime Rising",
        Path = "games/AnimeRising.lua",
        LocalPaths = { "games/AnimeRising.lua", "AR Test Place/AnimeRising.lua", "AnimeRising.lua" },
        PlaceIds = { 118712332916577 },
        UniverseIds = {},
        SignatureCheck = function()
            local rem = ReplicatedStorage:FindFirstChild("Remote")
            return rem ~= nil and (rem:FindFirstChild("Enemies") ~= nil or rem:FindFirstChild("Pets") ~= nil or rem:FindFirstChild("Loop") ~= nil)
        end
    }
}

local function detectGame()
    for _, cfg in ipairs(Games) do
        if cfg.PlaceIds and table.find(cfg.PlaceIds, placeId) then
            return cfg
        end
    end
    for _, cfg in ipairs(Games) do
        if cfg.UniverseIds and table.find(cfg.UniverseIds, gameId) then
            return cfg
        end
    end
    for _, cfg in ipairs(Games) do
        if cfg.SignatureCheck then
            local ok, matched = pcall(cfg.SignatureCheck)
            if ok and matched then
                return cfg
            end
        end
    end
    return nil
end

local detectedGame = detectGame()
if not detectedGame then
    Notify("HelmHUB", string.format("Game này chưa có trong danh sách!\nPlaceId: %s", tostring(placeId)), 5)
    if typeof(setclipboard) == "function" then
        pcall(setclipboard, tostring(placeId))
    end
    return
end

-- ========================================================================
-- 2. HÀM TẢI SIÊU TỐC (O(1) VALIDATION + SMART HOST/MIRROR CACHE)
-- ========================================================================
local function safeHttpGet(url)
    return game:HttpGet(url)
end

local function stripBom(content)
    if content:sub(1, 3) == "\239\187\191" then
        return content:sub(4)
    end
    return content
end

local function isValidLua(content)
    if type(content) ~= "string" or #content < 100 then
        return false
    end
    local head = content:sub(1, 512)
    if head:sub(1, 3) == "\239\187\191" then
        head = head:sub(4)
    end
    head = head:match("^%s*(.-)$"):lower()
    if head == "" then
        return false
    end
    local firstChar = head:sub(1, 1)
    if firstChar == "<" or firstChar == "{" then
        return false
    end
    if head:find("404: not found", 1, true)
        or head:find("403: forbidden", 1, true)
        or head:find("error response", 1, true)
        or head:find("couldn't find", 1, true)
        or head:find("package size exceeded", 1, true) then
        return false
    end
    return true
end

local function fetchFromDisk(relPath, localPaths)
    if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
        return nil, nil
    end
    local candidates = localPaths or { relPath }
    for _, path in ipairs(candidates) do
        local okExists, exists = pcall(isfile, path)
        if okExists and exists then
            local okRead, res = pcall(readfile, path)
            if okRead and isValidLua(res) then
                return stripBom(res), "Disk (" .. path .. ")"
            end
        end
    end
    return nil, nil
end

local function fetchFromGitHub(relPath)
    local clean = relPath:gsub(" ", "%%20")
    local ok, res = pcall(safeHttpGet, GITHUB_RAW_BASE .. clean)
    if ok and isValidLua(res) then
        return stripBom(res), "GitHub Raw"
    end
    return nil, nil
end

local function fetchFast(relPath, localPaths)
    local s, src = fetchFromGitHub(relPath)
    if s then return s, src end
    return fetchFromDisk(relPath, localPaths)
end

-- ========================================================================
-- 3. SONG SONG NẠP UI + GAME SCRIPT (EVENT-DRIVEN BARRIER + OBFUSCATED BRIDGE)
-- ========================================================================
local function loadModule(relPath, localPaths)
    local code, src = fetchFast(relPath, localPaths)
    if not code then
        return nil, nil, nil, nil
    end
    local fn, err = loadstring(code)
    if fn then
        return fn, src, nil, code
    end
    return nil, src, err, code
end

local function attachLibraryBridge(gameFn, libCode)
    if not libCode then
        return gameFn
    end

    if typeof(writefile) == "function" then
        pcall(function()
            if typeof(isfolder) == "function" and typeof(makefolder) == "function" then
                if not isfolder("Library") then pcall(makefolder, "Library") end
                if not isfolder("!HelmHub") then pcall(makefolder, "!HelmHub") end
                if not isfolder("!HelmHub/Library") then pcall(makefolder, "!HelmHub/Library") end
            end
            pcall(writefile, "Library/inventory.lua", libCode)
            pcall(writefile, "!HelmHub/Library/inventory.lua", libCode)
        end)
    end

    if typeof(setfenv) ~= "function" then
        return gameFn
    end

    local realGame = game
    local realGetfenv = getfenv
    local baseEnv = (typeof(realGetfenv) == "function" and realGetfenv()) or _G

    local proxyEnv = {}
    local methodCache = {}
    local gameProxy = {}

    local function interceptHttpGet(_, url, ...)
        if type(url) == "string" and url:find("inventory.lua", 1, true) then
            rawset(proxyEnv, "game", nil)
            rawset(proxyEnv, "Game", nil)
            return libCode
        end
        return realGame:HttpGet(url, ...)
    end

    setmetatable(gameProxy, {
        __index = function(_, k)
            if k == "HttpGet" or k == "HttpGetAsync" then
                return interceptHttpGet
            end
            local v = realGame[k]
            if type(v) == "function" then
                local fn = methodCache[k]
                if not fn then
                    fn = function(_, ...)
                        return v(realGame, ...)
                    end
                    methodCache[k] = fn
                end
                return fn
            end
            return v
        end,
        __newindex = function(_, k, val)
            realGame[k] = val
        end
    })

    proxyEnv.game = gameProxy
    proxyEnv.Game = gameProxy

    setmetatable(proxyEnv, {
        __index = baseEnv,
        __newindex = baseEnv
    })

    pcall(setfenv, gameFn, proxyEnv)
    return gameFn
end

local libResult = {}
local gameResult = {}
local remaining = 2
local doneSignal = nil

local function spawnLoad(target, relPath, localPaths)
    task.spawn(function()
        local ok, fn, src, err, code = pcall(loadModule, relPath, localPaths)
        if ok then
            target.fn = fn
            target.source = src
            target.err = err
            target.code = code
        else
            target.err = fn
        end
        remaining = remaining - 1
        if remaining == 0 and doneSignal then
            doneSignal:Fire()
        end
    end)
end

spawnLoad(libResult, "Library/inventory.lua", { "Library/inventory.lua", "!HelmHub/Library/inventory.lua" })
spawnLoad(gameResult, detectedGame.Path, detectedGame.LocalPaths)

if remaining > 0 then
    doneSignal = Instance.new("BindableEvent")
    doneSignal.Event:Wait()
    doneSignal:Destroy()
    doneSignal = nil
end

if env.HelmHubBootId ~= bootId then
    return
end

if gameResult.fn then
    _G.HelmGameName = detectedGame.Name
    if libResult.fn then
        env.HelmSharedLibraryCache = {
            fn = libResult.fn,
            source = libResult.source
        }
        attachLibraryBridge(gameResult.fn, libResult.code)
    else
        env.HelmSharedLibraryCache = nil
        if libResult.err then
            warn("[HelmHUB] Library compile error:", libResult.err)
        end
    end
    Notify("HelmHUB", string.format("Đang mở [%s] (%s)...", detectedGame.Name, tostring(gameResult.source)), 3)
    task.spawn(gameResult.fn)
else
    env.HelmSharedLibraryCache = nil
    if libResult.err then
        warn("[HelmHUB] Library compile error:", libResult.err)
    end
    if gameResult.err then
        Notify("Lỗi Biên Dịch", tostring(gameResult.err), 6)
        warn("[HelmHUB Loader] Parse error:", gameResult.err)
    else
        Notify("Lỗi Tải Script", string.format("Không tải được [%s] từ GitHub!", detectedGame.Name), 6)
    end
end
