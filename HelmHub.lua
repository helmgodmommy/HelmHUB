--[[
    ========================================================================
    HelmHUB | Universal Fast Loader (1 Script Cho All Game)
    GitHub: https://github.com/helmgodmommy/HelmHUB (branch: main)
    Tác giả: dj & VANTA
    Phiên bản: 5.0 (Parallel Edge Prefetch + O(1) Auto-Detect)
    ========================================================================
    Cách dùng (1 dòng duy nhất cho mọi game hỗ trợ):
      loadstring(game:HttpGet("https://raw.githubusercontent.com/helmgodmommy/HelmHUB/main/HelmHub.lua"))()

    Chế độ Dev Local (dùng kèm start_local_test.bat):
      _G.DevMode = true; loadstring(game:HttpGet("http://127.0.0.1:8000/HelmHub.lua?t=" .. tick()))()
    ========================================================================
]]

if not game:IsLoaded() then
    pcall(function() game.Loaded:Wait() end)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local placeId = game.PlaceId
local gameId = game.GameId
local env = (typeof(getgenv) == "function" and getgenv()) or _G

local GITHUB_RAW = "https://raw.githubusercontent.com/helmgodmommy/HelmHUB/main/"
local JSDELIVR_CDN = "https://cdn.jsdelivr.net/gh/helmgodmommy/HelmHUB@main/"
local isDevMode = (_G.DevMode == true) or (_G.LocalHost ~= nil)

local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "HelmHUB"),
            Text = tostring(text or ""),
            Duration = tonumber(duration or 3)
        })
    end)
    print(string.format("[HelmHUB] %s: %s", tostring(title or ""), tostring(text or "")))
end

-- ========================================================================
-- 1. CẤU HÌNH GAME & TRA CỨU O(1)
-- ========================================================================
local Games = {
    AnimeEyes = {
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
    AnimeDimensions = {
        Name = "Anime Dimensions",
        Path = "games/AnimeDimensions.lua",
        LocalPaths = { "games/AnimeDimensions.lua", "Anime dimesion/AnimeDimesion.lua", "ADS.lua" },
        PlaceIds = { 6938803436, 6990129309, 6990133340, 6990131029, 7338881230, 7274690025 },
        UniverseIds = { 2712497672 }
    },
    CardOrigins = {
        Name = "Card Origins",
        Path = "games/CardOrigins.lua",
        LocalPaths = { "games/CardOrigins.lua", "Card Origins/CardOrigins.lua", "CardOrigins.lua" },
        PlaceIds = { 78312396550517 },
        UniverseIds = {}
    },
    AnimeRising = {
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

local PlaceIdMap = {}
local UniverseIdMap = {}
for _, cfg in pairs(Games) do
    for _, pid in ipairs(cfg.PlaceIds or {}) do
        PlaceIdMap[pid] = cfg
    end
    for _, uid in ipairs(cfg.UniverseIds or {}) do
        UniverseIdMap[uid] = cfg
    end
end

local detectedGame = PlaceIdMap[placeId] or UniverseIdMap[gameId]
if not detectedGame then
    for _, cfg in pairs(Games) do
        if cfg.SignatureCheck then
            local ok, matched = pcall(cfg.SignatureCheck)
            if ok and matched then
                detectedGame = cfg
                break
            end
        end
    end
end

if not detectedGame then
    Notify("HelmHUB", string.format("Game này chưa có trong danh sách!\nPlaceId: %s", tostring(placeId)), 5)
    pcall(function()
        if setclipboard then
            setclipboard(tostring(placeId))
        end
    end)
    return
end

-- ========================================================================
-- 2. HÀM TẢI SIÊU TỐC (KHÔNG BLOCK LOCALHOST KHI CHẠY GITHUB)
-- ========================================================================
local function isValidLua(content)
    if not content or typeof(content) ~= "string" or #content < 100 then
        return false
    end
    if content:find("404: Not Found") or content:find("403: Forbidden") or content:find("<!DOCTYPE") or content:find("<html") or content:find("Error response") then
        return false
    end
    return true
end

local function fetchFromLocalServer(relPath, localPaths)
    local hosts = {}
    if _G.LocalHost then table.insert(hosts, _G.LocalHost) end
    table.insert(hosts, "127.0.0.1:8000")
    table.insert(hosts, "localhost:8000")
    table.insert(hosts, "192.168.2.203:8000")
    table.insert(hosts, "10.0.2.2:8000")

    local candidates = localPaths or { relPath }
    local bust = "?t=" .. tostring(tick())
    for _, path in ipairs(candidates) do
        local clean = path:gsub(" ", "%%20")
        for _, host in ipairs(hosts) do
            local ok, res = pcall(function()
                return game:HttpGet("http://" .. host .. "/" .. clean .. bust)
            end)
            if ok and isValidLua(res) then
                return res, "Local (" .. host .. ")"
            end
        end
    end
    return nil, nil
end

local function fetchFromDisk(relPath, localPaths)
    if not (isfile and readfile) then return nil, nil end
    local candidates = localPaths or { relPath }
    for _, path in ipairs(candidates) do
        local ok, res = pcall(function()
            if isfile(path) then
                return readfile(path)
            end
            return nil
        end)
        if ok and isValidLua(res) then
            return res, "Disk (" .. path .. ")"
        end
    end
    return nil, nil
end

local function fetchFromGitHub(relPath)
    local clean = relPath:gsub(" ", "%%20")
    local mirrors = {
        { url = GITHUB_RAW .. clean, label = "GitHub Raw" },
        { url = JSDELIVR_CDN .. clean, label = "jsDelivr CDN" }
    }
    for _, m in ipairs(mirrors) do
        local ok, res = pcall(function()
            return game:HttpGet(m.url)
        end)
        if ok and isValidLua(res) then
            return res, m.label
        end
    end
    return nil, nil
end

local function fetchFast(relPath, localPaths)
    if isDevMode then
        local s, src = fetchFromLocalServer(relPath, localPaths)
        if s then return s, src end
        s, src = fetchFromDisk(relPath, localPaths)
        if s then return s, src end
        return fetchFromGitHub(relPath)
    else
        local s, src = fetchFromGitHub(relPath)
        if s then return s, src end
        return fetchFromDisk(relPath, localPaths)
    end
end

-- ========================================================================
-- 3. SONG SONG NẠP UI + GAME SCRIPT (TỐI ĐA TỐC ĐỘ KHỞI CHẠY)
-- ========================================================================
local libDone, gameDone = false, false
local libFn, libSource, libErr = nil, nil, nil
local gameFn, gameSource, gameErr = nil, nil, nil

task.spawn(function()
    local code, src = fetchFast("Library/inventory.lua", { "Library/inventory.lua", "!HelmHub/Library/inventory.lua" })
    if code then
        local fn, err = loadstring(code)
        if fn then
            libFn = fn
            libSource = src
        else
            libErr = err
        end
    end
    libDone = true
end)

task.spawn(function()
    local code, src = fetchFast(detectedGame.Path, detectedGame.LocalPaths)
    if code then
        local fn, err = loadstring(code)
        if fn then
            gameFn = fn
            gameSource = src
        else
            gameErr = err
        end
    end
    gameDone = true
end)

while not (libDone and gameDone) do
    RunService.Heartbeat:Wait()
end

if libFn then
    env.HelmSharedLibraryCache = {
        fn = libFn,
        source = libSource
    }
else
    env.HelmSharedLibraryCache = nil
    if libErr then
        warn("[HelmHUB] Library compile error:", libErr)
    end
end

if gameFn then
    Notify("HelmHUB", string.format("Đang mở [%s] (%s)...", detectedGame.Name, tostring(gameSource)), 3)
    task.spawn(gameFn)
elseif gameErr then
    Notify("Lỗi Biên Dịch", tostring(gameErr), 6)
    warn("[HelmHUB Loader] Parse error:", gameErr)
else
    Notify("Lỗi Tải Script", string.format("Không tải được [%s] từ %s!", detectedGame.Name, isDevMode and "Local Server" or "GitHub"), 6)
end
