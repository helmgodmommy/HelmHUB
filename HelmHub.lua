--[[
    ========================================================================
    HelmHUB | Universal Fast Loader (Zero-Poll Parallel Architecture)
    GitHub: https://github.com/helmgodmommy/HelmHUB (branch: main)
    Design & Architecture: dj & VANTA
    Phiên bản: 6.0 (Multi-Tier Failover, O(1) Routing & Fast Dev Mode)
    ========================================================================
    Cách dùng (1 dòng duy nhất cho mọi game hỗ trợ):
      loadstring(game:HttpGet("https://raw.githubusercontent.com/helmgodmommy/HelmHUB/main/HelmHub.lua"))()
    ========================================================================
]]

-- 1. Chờ Game & Player sẵn sàng
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

-- Boot ID ngăn chặn trùng lặp phiên chạy song song
local bootId = (tonumber(env.HelmHubBootId) or 0) + 1
env.HelmHubBootId = bootId

-- Cấu hình CDN & Mirrors
local GITHUB_RAW_BASE = "https://raw.githubusercontent.com/helmgodmommy/HelmHUB/main/"
local CDN_MIRRORS = {
    "https://raw.githubusercontent.com/helmgodmommy/HelmHUB/main/",
    "https://fastly.jsdelivr.net/gh/helmgodmommy/HelmHUB@main/",
    "https://raw.gitmirror.com/helmgodmommy/HelmHUB/main/"
}

-- Thông báo an toàn
local function Notify(title, text, duration)
    local t = tostring(title or "HelmHUB")
    local msg = tostring(text or "")
    local dur = tonumber(duration) or 3
    task.spawn(function()
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = t,
                Text = msg,
                Duration = dur
            })
        end)
    end)
    print(string.format("[HelmHUB] %s: %s", t, msg))
end

-- ========================================================================
-- 1. CẤU HÌNH GAME & ĐỊNH TUYẾN O(1) SIÊU TỐC
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
        Name = "Anime Paradise",
        Path = "games/AnimeParadise.lua",
        LocalPaths = { "games/AnimeParadise.lua", "Anime Paradise/AnimeParadise.lua", "AnimeParadise.lua" },
        PlaceIds = { 96665881849072 },
        UniverseIds = { 10079271418 },
        SignatureCheck = function()
            local rem = ReplicatedStorage:FindFirstChild("Remotes")
            local ps = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerScripts")
            return rem ~= nil and rem:FindFirstChild("Bridge") ~= nil and ps ~= nil and ps:FindFirstChild("Paradise_Client") ~= nil
        end
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
    },
    {
        Name = "Anime Dice",
        Path = "games/AnimeDice.lua",
        LocalPaths = { "games/AnimeDice.lua", "AnimeDice/AnimeDice.lua", "AnimeDice.lua" },
        PlaceIds = { 113290951185459 },
        UniverseIds = { 10708913337 },
        SignatureCheck = function()
            return ReplicatedStorage:FindFirstChild("Framework") ~= nil and ReplicatedStorage:FindFirstChild("Network") ~= nil
        end
    }
}

-- Xây dựng bảng tra cứu O(1) Hash Map
local PlaceIdMap = {}
local UniverseIdMap = {}
for _, cfg in ipairs(Games) do
    if cfg.PlaceIds then
        for _, pid in ipairs(cfg.PlaceIds) do
            PlaceIdMap[pid] = cfg
        end
    end
    if cfg.UniverseIds then
        for _, uid in ipairs(cfg.UniverseIds) do
            UniverseIdMap[uid] = cfg
        end
    end
end

local function detectGame()
    -- 1. Tra cứu O(1) PlaceId
    if PlaceIdMap[placeId] then
        return PlaceIdMap[placeId]
    end

    -- 2. Tra cứu O(1) UniverseId / GameId
    if UniverseIdMap[gameId] then
        return UniverseIdMap[gameId]
    end

    -- 3. Fallback: Kiểm tra chữ ký đặc trưng của game
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
    Notify("HelmHUB", string.format("Game này chưa có trong danh sách!\nPlaceId: %s (Đã sao chép vào bộ nhớ)", tostring(placeId)), 6)
    if typeof(setclipboard) == "function" then
        pcall(setclipboard, tostring(placeId))
    end
    return
end

-- ========================================================================
-- 2. PIPELINE NẠP TÀI NGUYÊN ĐA TẦNG (MULTI-TIER SMART LOADER)
-- ========================================================================
local function stripBom(content)
    if content and content:sub(1, 3) == "\239\187\191" then
        return content:sub(4)
    end
    return content
end

local function isValidLua(content)
    if type(content) ~= "string" or #content < 80 then
        return false
    end
    local head = content:sub(1, 256)
    if head:sub(1, 3) == "\239\187\191" then
        head = head:sub(4)
    end
    local trimmed = head:gsub("^%s+", ""):lower()
    if trimmed == "" then
        return false
    end
    local b1 = trimmed:sub(1, 1)
    if b1 == "<" or b1 == "{" then -- Lỗi HTML (404/Cloudflare) hoặc JSON Error
        return false
    end
    if trimmed:find("404: not found", 1, true)
        or trimmed:find("403: forbidden", 1, true)
        or trimmed:find("error response", 1, true)
        or trimmed:find("couldn't find", 1, true)
        or trimmed:find("package size exceeded", 1, true) then
        return false
    end
    return true
end

-- Lưu đệm thông minh (tránh ghi đè nếu nội dung không đổi)
local function smartSaveFile(relPath, content)
    if typeof(writefile) ~= "function" or typeof(content) ~= "string" or #content < 100 then
        return
    end
    pcall(function()
        local saveTargets = { relPath, "!HelmHub/" .. relPath }
        for _, path in ipairs(saveTargets) do
            local dir = path:match("^(.+)/[^/]+$")
            if dir and typeof(isfolder) == "function" and typeof(makefolder) == "function" then
                local acc = ""
                for part in dir:gmatch("[^/]+") do
                    acc = (acc == "" and part) or (acc .. "/" .. part)
                    if not isfolder(acc) then
                        pcall(makefolder, acc)
                    end
                end
            end
            local needWrite = true
            if typeof(isfile) == "function" and isfile(path) and typeof(readfile) == "function" then
                local okRead, existing = pcall(readfile, path)
                if okRead and existing and #existing == #content then
                    needWrite = false
                end
            end
            if needWrite then
                pcall(writefile, path, content)
            end
        end
    end)
end

-- Tầng 0: Nạp từ Local HTTP Server khi bật DevMode
local function fetchFromLocalServer(relPath)
    local hosts = {}
    if _G.LocalHost then table.insert(hosts, _G.LocalHost) end
    table.insert(hosts, "127.0.0.1:8000")
    table.insert(hosts, "localhost:8000")
    table.insert(hosts, "192.168.2.203:8000")

    local clean = relPath:gsub(" ", "%%20")
    for _, host in ipairs(hosts) do
        local url = string.format("http://%s/%s?t=%s", host, clean, tostring(tick()))
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and isValidLua(res) then
            return stripBom(res), string.format("DevServer (%s)", host)
        end
    end
    return nil, nil
end

-- Tầng 1: Nạp từ Disk cục bộ (Executor Workspace)
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
    -- Kiểm tra thư mục cache "!HelmHub/"
    local cachePath = "!HelmHub/" .. relPath
    local okCache, cExists = pcall(isfile, cachePath)
    if okCache and cExists then
        local okRead, res = pcall(readfile, cachePath)
        if okRead and isValidLua(res) then
            return stripBom(res), "Cache (" .. cachePath .. ")"
        end
    end
    return nil, nil
end

-- Tầng 2 & 3: Nạp từ GitHub Raw và các CDN Mirrors
local function fetchFromNetwork(relPath)
    local clean = relPath:gsub(" ", "%%20")
    local tStamp = tostring(math.floor(tick() / 15)) -- Cache buster mỗi 15s

    for _, base in ipairs(CDN_MIRRORS) do
        local url = base .. clean .. "?t=" .. tStamp
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and isValidLua(res) then
            local mirrorName = (base:find("jsdelivr") and "CDN jsDelivr")
                or (base:find("gitmirror") and "GitMirror")
                or "GitHub Raw"
            return stripBom(res), mirrorName
        end
    end
    return nil, nil
end

-- Tổng hợp thứ tự ưu tiên thông minh
local function fetchFast(relPath, localPaths)
    -- Nếu đang ở chế độ DevMode hoặc yêu cầu Local
    if _G.DevMode == true or _G.LocalHost ~= nil then
        local code, src = fetchFromLocalServer(relPath)
        if code then return code, src end

        local codeD, srcD = fetchFromDisk(relPath, localPaths)
        if codeD then return codeD, srcD end
    end

    -- Môi trường chạy chuẩn: GitHub/CDN -> Disk Fallback
    local codeNet, srcNet = fetchFromNetwork(relPath)
    if codeNet then
        smartSaveFile(relPath, codeNet) -- Lưu cache ngầm
        return codeNet, srcNet
    end

    -- Fallback khi mạng lỗi hoặc offline
    local codeDisk, srcDisk = fetchFromDisk(relPath, localPaths)
    if codeDisk then
        return codeDisk, srcDisk
    end

    return nil, nil
end

-- Biên dịch module an toàn
local function loadModule(relPath, localPaths)
    local code, src = fetchFast(relPath, localPaths)
    if not code then
        return nil, nil, "Không thể tải tài nguyên từ bất kỳ nguồn nào!", nil
    end
    local fn, err = loadstring(code)
    if fn then
        return fn, src, nil, code
    end
    return nil, src, err, code
end

-- ========================================================================
-- 3. CẦU NỐI THƯ VIỆN & NẠP SONG SONG KHÔNG ĐỢI (ZERO-RACE BARRIER)
-- ========================================================================
local function attachLibraryBridge(gameFn, libCode)
    if not libCode then return gameFn end

    -- Lưu sẵn vào bộ đệm tệp tin để game script đọc tức thì
    smartSaveFile("Library/inventory.lua", libCode)

    if typeof(setfenv) ~= "function" then
        return gameFn
    end

    local realGame = game
    local baseEnv = (typeof(getfenv) == "function" and getfenv()) or _G

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

-- Điểm rào cản nạp song song an toàn (Khởi tạo Barrier trước khi Spawn)
local doneSignal = Instance.new("BindableEvent")
local remaining = 2
local libResult = {}
local gameResult = {}

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
        if remaining <= 0 then
            doneSignal:Fire()
        end
    end)
end

-- Kích hoạt song song nạp Thư viện UI và Game Script
spawnLoad(libResult, "Library/inventory.lua", { "Library/inventory.lua", "!HelmHub/Library/inventory.lua" })
spawnLoad(gameResult, detectedGame.Path, detectedGame.LocalPaths)

if remaining > 0 then
    doneSignal.Event:Wait()
end
pcall(function() doneSignal:Destroy() end)

-- Kiểm tra phiên chạy hợp lệ
if env.HelmHubBootId ~= bootId then
    return
end

-- ========================================================================
-- 4. KHỞI CHẠY AN TOÀN VÀ BÁO CÁO LỖI (RUNTIME SUPERVISOR)
-- ========================================================================
if gameResult.fn then
    _G.HelmGameName = detectedGame.Name

    -- Chia sẻ đối tượng Thư viện đã biên dịch cho Game Script
    if libResult.fn then
        env.HelmSharedLibraryCache = {
            fn = libResult.fn,
            source = libResult.source,
            code = libResult.code
        }
        attachLibraryBridge(gameResult.fn, libResult.code)
    else
        env.HelmSharedLibraryCache = nil
        if libResult.err then
            warn("[HelmHUB] Cảnh báo biên dịch Library:", libResult.err)
        end
    end

    Notify("HelmHUB", string.format("Khởi chạy [%s] từ %s...", detectedGame.Name, tostring(gameResult.source)), 3)

    -- Khởi chạy trong luồng giám sát ngoại lệ (xpcall)
    task.spawn(function()
        local okExec, errExec = xpcall(gameResult.fn, function(e)
            return tostring(e) .. "\n" .. debug.traceback()
        end)
        if not okExec then
            warn("[HelmHUB Runtime Crash]:", errExec)
            Notify("Lỗi Thực Thi Game", tostring(errExec):sub(1, 120), 8)
        end
    end)
else
    env.HelmSharedLibraryCache = nil
    if libResult.err then
        warn("[HelmHUB] Lỗi biên dịch Thư viện:", libResult.err)
    end
    if gameResult.err then
        Notify("Lỗi Biên Dịch", tostring(gameResult.err), 7)
        warn("[HelmHUB Loader] Compile Error:", gameResult.err)
    else
        Notify("Lỗi Tải Script", string.format("Không thể tải [%s] từ bất kỳ máy chủ nào!", detectedGame.Name), 7)
    end
end
