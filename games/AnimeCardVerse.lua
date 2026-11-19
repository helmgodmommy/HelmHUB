--[[
    ========================================================================================
    HelmHub | Anime CardVerse - Production Combat & Universal Automation Suite
    Game: Anime CardVerse (PlaceId: 86664636582112 | UniverseId: 10041955829)
    Author: dj & VANTA
    Architecture: Clean Event-Driven, Multi-Thread Safe & High-DPS Combat Engine
    UI Engine: HelmHub Inventory.lua Native Sector / Cyber Theme
    ========================================================================================
]]

repeat task.wait(0.1) until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
repeat task.wait(0.1) until LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")

-- ========================================================================
-- [1] REVERSE-PATH RESOURCE CLEANUP (CHỐNG MEMORY LEAK KHI RE-RUN)
-- ========================================================================
local env = (typeof(getgenv) == "function" and getgenv()) or _G
if env.__HelmAnimeCardVerseCleanup then
    pcall(env.__HelmAnimeCardVerseCleanup)
end

local activeConnections = {}
local isScriptRunning = true
local originalGamepassesOwns = nil
local Gamepasses = nil

local function trackConnection(conn)
    if conn then
        table.insert(activeConnections, conn)
    end
    return conn
end

env.__HelmAnimeCardVerseCleanup = function()
    isScriptRunning = false
    for _, conn in ipairs(activeConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(activeConnections)

    -- Phục hồi hàm Gamepasses.Owns và thuộc tính nếu đã can thiệp
    if Gamepasses and originalGamepassesOwns then
        pcall(function()
            Gamepasses.Owns = originalGamepassesOwns
            Gamepasses.BaseMagnetRadius = 17
        end)
    end
    pcall(function()
        LocalPlayer:SetAttribute("Gamepass_InfiniteMagnet", nil)
    end)

    -- Gỡ bỏ NoClip và BodyVelocity nếu đang bật
    if LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local bv = root and root:FindFirstChild("Helm_AntiGravity")
        if bv then bv:Destroy() end

        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- ========================================================================
-- [2] NẠP THƯ VIỆN GIAO DIỆN (HELMHUB UI INVENTORY)
-- ========================================================================
local library
local function loadLibrary()
    if env.HelmSharedLibraryCache and typeof(env.HelmSharedLibraryCache.fn) == "function" then
        local cached = env.HelmSharedLibraryCache
        env.HelmSharedLibraryCache = nil
        local ok, res = pcall(cached.fn)
        if ok and res then return res end
    end
    -- 1. Ưu tiên nạp UI qua Local Dev Server nếu chạy DevMode
    local isDev = (_G.DevMode == true) or (env and env.DevMode == true)
    if isDev then
        pcall(function()
            local code = game:HttpGet("http://127.0.0.1:8000/Library/inventory.lua?t=" .. tick())
            if code and #code > 100 then
                library = loadstring(code)()
            end
        end)
        if library then return library end
    end
    -- 2. Đọc file local executor disk
    if isfile and readfile then
        pcall(function()
            if isfile("Library/inventory.lua") then
                library = loadstring(readfile("Library/inventory.lua"))()
            elseif isfile("inventory.lua") then
                library = loadstring(readfile("inventory.lua"))()
            end
        end)
        if library then return library end
    end
    -- 3. Mặc định tải từ GitHub Raw
    if not library then
        pcall(function()
            library = loadstring(game:HttpGet("https://raw.githubusercontent.com/helmgodmommy/HelmHUB/main/Library/inventory.lua"))()
        end)
    end
    return library
end

library = loadLibrary()
if not library then
    warn("[HelmHub | Anime CardVerse] Không thể tải thư viện UI Library!")
    return
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "HelmHub | CardVerse"),
            Text = tostring(text or ""),
            Duration = tonumber(duration) or 3
        })
    end)
end

-- ========================================================================
-- [3] KẾT NỐI HỆ THỐNG GIAO THỨC MẠNG (REMOTE BANK & CLIENT MODULES)
-- ========================================================================
local function safeRequire(inst)
    if not inst then return nil end
    local ok, res = pcall(require, inst)
    return (ok and res) and res or nil
end

local RemoteBank = safeRequire(ReplicatedStorage:WaitForChild("RemoteBank", 15))
local Lib = safeRequire(ReplicatedStorage:FindFirstChild("Lib"))
local MapClient = safeRequire(ReplicatedStorage:FindFirstChild("Utilities") and ReplicatedStorage.Utilities:FindFirstChild("MapClient"))
local MapUtil = safeRequire(ReplicatedStorage:FindFirstChild("Utilities") and ReplicatedStorage.Utilities:FindFirstChild("MapUtil"))
local DataClient = safeRequire(ReplicatedStorage:FindFirstChild("Utilities") and ReplicatedStorage.Utilities:FindFirstChild("DataClient"))
local AttackClient = nil
local MovementClient = nil

pcall(function()
    local ps = LocalPlayer:WaitForChild("PlayerScripts", 5)
    local cl = ps and ps:WaitForChild("ClientLoader", 5)
    local modules = cl and cl:WaitForChild("Modules", 5)
    if modules then
        AttackClient = safeRequire(modules:FindFirstChild("AttackClient"))
        MovementClient = safeRequire(modules:FindFirstChild("MovementClient"))
    end
end)

if not AttackClient and Lib and typeof(Lib.Find) == "function" then
    pcall(function()
        AttackClient = Lib.Find("AttackClient")
    end)
end

if not RemoteBank then
    warn("[HelmHub | Anime CardVerse] Không thể liên kết ReplicatedStorage.RemoteBank!")
    return
end

-- Can thiệp Gamepasses để mở khóa cơ chế hút đồ vô hạn gốc của game (Native Infinite Magnet)
Gamepasses = safeRequire(ReplicatedStorage:FindFirstChild("DataModules")
    and ReplicatedStorage.DataModules:FindFirstChild("Economy")
    and ReplicatedStorage.DataModules.Economy:FindFirstChild("Gamepasses"))

if Gamepasses and type(Gamepasses.Owns) == "function" then
    originalGamepassesOwns = Gamepasses.Owns
    Gamepasses.Owns = function(plr, passName)
        if passName == "InfiniteMagnet" then
            if plr == nil or plr == LocalPlayer then
                return true
            end
        end
        return originalGamepassesOwns(plr, passName)
    end
    pcall(function()
        Gamepasses.BaseMagnetRadius = 999999
        Gamepasses.InfiniteMagnetRadius = math.huge
    end)
end

pcall(function()
    LocalPlayer:SetAttribute("Gamepass_InfiniteMagnet", true)
end)

-- ========================================================================
-- [4] CẤU HÌNH TRẠNG THÁI TOÀN CỤC (GLOBAL STATE)
-- ========================================================================
local Config = {
    -- Combat: Melee Punch
    AutoPunch = false,
    PunchDelay = 0.015,

    -- Combat: Powers & Hotbar Skills
    AutoSkills = false,
    SkillSlots = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true },
    SkillDelay = 0.15,

    -- Combat: Ultimate
    AutoUltimate = false,
    UltimateCheckDelay = 1.0,

    -- Targeting & Mob Selection
    TargetMode = "Nearest", -- "Nearest", "LowestHP", "BossFirst"
    SelectedWorld = "Tất Cả Thế Giới (All Worlds)",
    SelectedMob = "All",
    SelectedMobs = {}, -- Danh sách nhiều quái được chọn (Multi-Select)
    ScanRange = 2500,
    TargetCurrent = nil,

    -- Auto Positioning & Safety
    AutoPosition = false,
    PositionMode = "BehindMob", -- "BehindMob", "GroundMelee", "FrontMob", "HoverAbove"
    CombatHeightOffset = 0, -- Độ cao tùy chỉnh so với tâm quái (-5 đến +20 studs, 0 = ngang người quái trúng 100%)
    HoverHeight = 6,
    BehindDistance = 2.5, -- Khoảng cách áp sát quái (2.5 studs nằm trọn trong hitbox đánh thường)
    NoClip = false,

    -- Auto Dodge (Né Chiêu Boss & Vùng Đỏ Telegraph - Độc lập hoàn toàn)
    AutoDodge = false,
    DodgeMode = "SmartHybrid", -- "SmartHybrid" (Né ngang + Nhảy cao >16 studs), "Sidestep" (Né ngang), "SkyEvade" (Bay vọt lên cao)
    DodgeMargin = 6,
    IsCurrentlyDodging = false,

    -- Auto Pickups & Magnet
    AutoMagnet = true,

    -- [ƯU TIÊN 1] Auto Bounty (Tự nhận, tự tele sang đúng World, săn đúng quái & tự trả nhiệm vụ 1/10 -> 10/10)
    AutoBounty = false,
    BountyAutoTeleport = true,
    BountyAutoSkills = true,

    -- [ƯU TIÊN 2] Auto Missions / Dungeons / Challenges / Gauntlet (Tách riêng từng chức năng)
    AutoMission = false, -- Công tắc Khởi Động Auto Missions (Tự vào màn)
    AutoMissionFarm = false, -- Tự động đánh quái khi ở trong Phó Bản
    MissionAutoTeleport = false, -- Tự động Tele áp sát quái khi ở trong Phó Bản
    MissionAutoSkills = true, -- Tự động dùng Skill + Ultimate khi bật Auto Farm Phó Bản
    MissionGamemode = "Mission", -- "Mission", "Challenge", "Gauntlet", "Invasion"
    MissionWorld = "Nemu's Village",
    MissionAct = 1, -- 1, 2, 3, 4 (Act 4 = EX Stage)
    MissionMode = "Normal", -- "Normal", "Hard"
    ChallengeTier = "Regular", -- "Regular", "Daily", "Weekly"
    ChallengeSlot = 1, -- 1, 2, 3
    GauntletChamber = 1, -- 1..10
    AutoReplayMission = false,
    MissionDecisionType = "Retry", -- "Retry" (chơi lại), "Next" (đi tiếp), "Return" (về map)

    -- Auto Gacha / Summon
    AutoSummon = false,
    SummonBanner = "Standard Powers",
    SummonCount = 1,

    -- Misc
    AntiAFK = true,
    AlwaysSprint = false
}

-- ========================================================================
-- [5] TARGET ACQUISITION & MAP DETECTOR (ĐỊNH DANH QUÁI & BẢN ĐỒ CHÍNH XÁC)
-- ========================================================================
local function getCurrentMapName()
    local attrMap = LocalPlayer:GetAttribute("CurrentMap")
    if type(attrMap) == "string" and attrMap ~= "" then
        local mapFolder = Workspace:FindFirstChild("Map")
        if mapFolder and mapFolder:FindFirstChild(attrMap) then
            return attrMap
        end
    end
    if MapClient and typeof(MapClient.GetCurrentMap) == "function" then
        local ok, map = pcall(MapClient.GetCurrentMap)
        if ok and type(map) == "string" and map ~= "" then
            return map
        end
    end
    if MapUtil and typeof(MapUtil.GetMapOfPlayer) == "function" then
        local ok, map = pcall(MapUtil.GetMapOfPlayer, LocalPlayer)
        if ok and type(map) == "string" and map ~= "" then
            return map
        end
    end
    local mapFolder = Workspace:FindFirstChild("Map")
    if mapFolder then
        for _, child in ipairs(mapFolder:GetChildren()) do
            if child.Name ~= "Lobby" and child.Name ~= "MapStorage" and child.Name ~= "Terrain" then
                return child.Name
            end
        end
        if mapFolder:FindFirstChild("Lobby") then
            return "Lobby"
        end
    end
    return "Lobby"
end

local function getActiveMapFolder()
    local mapRoot = Workspace:FindFirstChild("Map")
    if not mapRoot then return nil end
    local currentMap = getCurrentMapName()
    if currentMap and mapRoot:FindFirstChild(currentMap) then
        return mapRoot:FindFirstChild(currentMap)
    end
    return nil
end

-- Kiểm tra chính xác người chơi có đang ở trong Phó Bản / Mission / Challenge / Gauntlet hay không
local function isInMission()
    local gmAttr = LocalPlayer:GetAttribute("Gamemode")
    if type(gmAttr) == "string" and gmAttr ~= "" then
        return true
    end
    local mapName = getCurrentMapName()
    if mapName and string.find(mapName, "-", 1, true) then
        return true
    end
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local inMissionUI = pGui and pGui:FindFirstChild("MainHUD")
        and pGui.MainHUD:FindFirstChild("Missions")
        and pGui.MainHUD.Missions:FindFirstChild("InMissionUI")
    if inMissionUI and inMissionUI.Visible then
        return true
    end
    return false
end

-- Kiểm tra nghiêm ngặt một Model quái có hợp lệ, còn sống và nằm trên mặt đất của Map hiện tại hay không
local function isValidCombatTarget(mob, activeMapFolder)
    if not mob or not mob.Parent then return false end
    local mapFolder = activeMapFolder or getActiveMapFolder()
    if not mapFolder or mapFolder.Name == "Lobby" then return false end
    -- Bắt buộc quái phải thuộc Map đang load trong Workspace.Map (chống tele sang map của người khác hoặc MapStorage)
    if not mob:IsDescendantOf(mapFolder) then return false end
    if Players:GetPlayerFromCharacter(mob) or mob == LocalPlayer.Character then return false end

    local pName = mob.Parent and mob.Parent.Name:lower() or ""
    if pName:find("asset") or pName:find("lobby") or pName:find("npc") then return false end

    local hum = mob:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then
        return false
    end

    local mRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso")
    if not mRoot then return false end

    local pos = mRoot.Position
    -- Loại bỏ quái bị rơi xuống hư không hoặc tọa độ lỗi
    if pos.Y < -45 or pos.Y > 1500 then
        return false
    end

    local spawnPart = mapFolder:FindFirstChild("SpawnPart", true)
    if spawnPart and spawnPart:IsA("BasePart") then
        -- Không bao giờ tele tới quái nằm thấp hơn mặt sàn Spawn quá 22 studs hoặc xa ngoài biên map
        if pos.Y < (spawnPart.Position.Y - 22) then
            return false
        end
        if (pos - spawnPart.Position).Magnitude > 10000 then
            return false
        end
    end

    return true
end

local function getAllEnemies()
    local enemiesList = {}
    local currentMapFolder = getActiveMapFolder()
    if not currentMapFolder or currentMapFolder.Name == "Lobby" then
        return enemiesList
    end

    -- Chỉ quét quái bên trong đúng Map hiện tại của người chơi (Tuyệt đối không fallback sang map chưa load)
    for _, desc in ipairs(currentMapFolder:GetDescendants()) do
        if desc:IsA("Model") and isValidCombatTarget(desc, currentMapFolder) then
            table.insert(enemiesList, desc)
        end
    end

    return enemiesList
end

-- Bảng ánh xạ Quái -> Thế Giới (Dùng cho Auto Bounty tự động tìm đúng Map của quái)
local MobToWorldMap = {
    ["Alien Scout"] = "Nemu's Village",
    ["Alien Soldier"] = "Nemu's Village",
    ["Alien Officer"] = "Nemu's Village",
    ["Captain Shinyu"] = "Nemu's Village",
    ["Freezer"] = "Nemu's Village",
    ["Grants"] = "Hollow World",
    ["Yummy"] = "Hollow World",
    ["Grimmjay"] = "Hollow World",
    ["Arruru"] = "Hollow World",
    ["Aizo"] = "Hollow World",
    ["Goblin"] = "Demon Citadel",
    ["Goblin Shaman"] = "Demon Citadel",
    ["High Grunt"] = "Demon Citadel",
    ["Ferrite"] = "Demon Citadel",
    ["Belu"] = "Demon Citadel"
}

-- Tự động quét ReplicatedStorage.Assets.Enemies để cập nhật thêm mọi quái mới từ game
pcall(function()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local enemiesFolder = assets and assets:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, worldFolder in ipairs(enemiesFolder:GetChildren()) do
            for _, mobModel in ipairs(worldFolder:GetChildren()) do
                if mobModel:IsA("Model") then
                    MobToWorldMap[mobModel.Name] = worldFolder.Name
                end
            end
        end
    end
end)

-- Đọc trạng thái nhiệm vụ Bounty hiện tại từ DataClient.Get("BountyProgress") + Fallback HUD UI
local function getBountyTaskStatus()
    if DataClient and typeof(DataClient.Get) == "function" then
        local ok, bp = pcall(DataClient.Get, "BountyProgress")
        if ok and type(bp) == "table" then
            local claimedCount = tonumber(bp.claimed) or 0
            if bp.completed == true or claimedCount >= 10 then
                return {
                    state = "Completed",
                    accepted = true,
                    completed = true,
                    position = 10,
                    total = 10,
                    claimed = claimedCount
                }
            end

            local qLine = type(bp.questline) == "table" and bp.questline or nil
            local bountiesList = qLine and type(qLine.bounties) == "table" and qLine.bounties or nil
            local idx = tonumber(bp.index) or 1
            local currentEntry = bountiesList and bountiesList[idx] or nil

            if bp.accepted ~= true then
                return {
                    state = "NeedAccept",
                    accepted = false,
                    completed = false,
                    position = idx,
                    total = 10,
                    claimed = claimedCount,
                    enemy = currentEntry and currentEntry.enemy or nil,
                    world = currentEntry and (currentEntry.world or MobToWorldMap[currentEntry.enemy]) or nil,
                    progress = tonumber(bp.progress) or 0,
                    target = currentEntry and tonumber(currentEntry.target) or 1
                }
            end

            if currentEntry then
                local prog = tonumber(bp.progress) or 0
                local req = tonumber(currentEntry.target) or 1
                local enemyName = tostring(currentEntry.enemy or "")
                local worldName = currentEntry.world or MobToWorldMap[enemyName]
                return {
                    state = (prog >= req) and "ReadyToClaim" or "InProgress",
                    accepted = true,
                    completed = false,
                    position = tonumber(currentEntry.position) or idx,
                    total = 10,
                    claimed = claimedCount,
                    enemy = enemyName,
                    world = worldName,
                    progress = math.min(prog, req),
                    target = req
                }
            end
        end
    end

    -- Fallback: Đọc trực tiếp từ bảng ghim nhiệm vụ trên màn hình (ví dụ: "Bounty 2/10" - "Belu (3/12)" hoặc "Bounty 4" - "Defeat 0/33 Captain Shinyu")
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local mainHud = pGui and pGui:FindFirstChild("MainHUD")
    if mainHud then
        for _, desc in ipairs(mainHud:GetDescendants()) do
            if desc:IsA("TextLabel") then
                if desc.Name == "QuestName" and desc.Text:find("^Bounty%s+%d+/%d+") then
                    local posStr, totStr = desc.Text:match("^Bounty%s+(%d+)/(%d+)")
                    local parentFrame = desc.Parent
                    local descLabel = parentFrame and parentFrame:FindFirstChild("Description")
                    if descLabel and descLabel:IsA("TextLabel") then
                        local rawText = descLabel.Text
                        local enemyName, progStr, reqStr = rawText:match("^(.-)%s*%(([%d,]+)/([%d,]+)%)$")
                        if enemyName and progStr and reqStr then
                            local prog = tonumber((progStr:gsub(",", ""))) or 0
                            local req = tonumber((reqStr:gsub(",", ""))) or 1
                            return {
                                state = (prog >= req) and "ReadyToClaim" or "InProgress",
                                accepted = true,
                                completed = false,
                                position = tonumber(posStr) or 1,
                                total = tonumber(totStr) or 10,
                                claimed = (tonumber(posStr) or 1) - 1,
                                enemy = enemyName,
                                world = MobToWorldMap[enemyName],
                                progress = prog,
                                target = req
                            }
                        end
                    end
                elseif desc.Text:find("^Bounty%s+%d+$") then
                    local posStr = desc.Text:match("^Bounty%s+(%d+)$")
                    local container = desc.Parent and desc.Parent.Parent
                    if container then
                        for _, sub in ipairs(container:GetDescendants()) do
                            if sub:IsA("TextLabel") and sub.Text:find("^Defeat%s+[%d,]+/[%d,]+%s+.+") then
                                local progStr, reqStr, enemyName = sub.Text:match("^Defeat%s+([%d,]+)/([%d,]+)%s+(.+)$")
                                if progStr and reqStr and enemyName then
                                    local prog = tonumber((progStr:gsub(",", ""))) or 0
                                    local req = tonumber((reqStr:gsub(",", ""))) or 1
                                    return {
                                        state = (prog >= req) and "ReadyToClaim" or "InProgress",
                                        accepted = true,
                                        completed = false,
                                        position = tonumber(posStr) or 1,
                                        total = 10,
                                        claimed = (tonumber(posStr) or 1) - 1,
                                        enemy = enemyName,
                                        world = MobToWorldMap[enemyName],
                                        progress = prog,
                                        target = req
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- Kiểm tra xem [ƯU TIÊN 1: AUTO BOUNTY] có đang kích hoạt và còn nhiệm vụ chưa xong trong ngày không
local function isBountyOverrideActive()
    if not Config.AutoBounty then
        return false, nil
    end
    local status = getBountyTaskStatus()
    if not status then
        return false, nil
    end
    if status.completed or status.state == "Completed" then
        return false, status
    end
    return true, status
end

local function getActivePriorityMode()
    local bountyActive, bountyStatus = isBountyOverrideActive()
    if bountyActive then
        return "Bounty", bountyStatus
    end
    if isInMission() and Config.AutoMissionFarm then
        return "Mission", nil
    end
    if Config.AutoMission then
        return "MissionQueue", nil
    end
    return "NormalCombat", nil
end

local function getSpecificSelectedMobs()
    local specific = {}
    if type(Config.SelectedMobs) == "table" then
        for _, name in ipairs(Config.SelectedMobs) do
            local s = tostring(name)
            if s ~= "" and s ~= "All" and s ~= "Tất Cả Quái (All Mobs)" then
                table.insert(specific, s)
            end
        end
    end
    if #specific == 0 and type(Config.SelectedMob) == "string" and Config.SelectedMob ~= "" and Config.SelectedMob ~= "All" and Config.SelectedMob ~= "Tất Cả Quái (All Mobs)" then
        table.insert(specific, Config.SelectedMob)
    end
    return specific
end

local function isMobSelectedByFilter(mobName)
    if not mobName then return false end
    local specific = getSpecificSelectedMobs()
    if #specific == 0 then
        return true
    end
    local mobLower = tostring(mobName):lower()
    for _, sel in ipairs(specific) do
        local selLower = sel:lower()
        if mobLower == selLower or mobLower:find(selLower, 1, true) then
            return true
        end
    end
    return false
end

local function getSelectedMobsDisplay()
    local specific = getSpecificSelectedMobs()
    if #specific == 0 then
        return nil
    end
    return table.concat(specific, ", ")
end

local function getBestTarget()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local currentMapFolder = getActiveMapFolder()
    if not currentMapFolder or currentMapFolder.Name == "Lobby" then
        return nil
    end

    local enemies = getAllEnemies()
    if #enemies == 0 then return nil end

    local bountyActive, bountyStatus = isBountyOverrideActive()
    local inMission = isInMission()
    local effectiveRange = (bountyActive or (inMission and Config.AutoMissionFarm))
        and math.max(Config.ScanRange or 2500, 5000)
        or (Config.ScanRange or 2500)

    local bestTarget = nil
    local bestScore = math.huge

    for _, mob in ipairs(enemies) do
        if isValidCombatTarget(mob, currentMapFolder) then
            local mRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso")
            local mHum = mob:FindFirstChildOfClass("Humanoid")

            -- HỆ THỐNG ƯU TIÊN 3 TẦNG: [1] Auto Bounty -> [2] Auto Missions -> [3] Chiến Đấu Thường
            if bountyActive and bountyStatus and bountyStatus.enemy and bountyStatus.enemy ~= "" then
                -- Tầng 1: Đang chạy Auto Bounty -> Chỉ nhắm đúng con quái nhiệm vụ Bounty yêu cầu
                local targetEnemyLower = tostring(bountyStatus.enemy):lower()
                local mobNameLower = mob.Name:lower()
                if mobNameLower ~= targetEnemyLower and not mobNameLower:find(targetEnemyLower, 1, true) then
                    continue
                end
            elseif inMission and Config.AutoMissionFarm then
                -- Tầng 2: Đang trong Phó Bản (Mission) -> Đánh toàn bộ quái trong Wave để qua màn
            else
                -- Tầng 3: Chiến đấu thường ngoài World -> Lọc theo danh sách Multi-Quái người chơi chọn ở Tab 1
                if not isMobSelectedByFilter(mob.Name) then
                    continue
                end
            end

            local dist = (mRoot.Position - root.Position).Magnitude
            if dist <= effectiveRange then
                if Config.TargetMode == "Nearest" or bountyActive then
                    if dist < bestScore then
                        bestScore = dist
                        bestTarget = mob
                    end
                elseif Config.TargetMode == "LowestHP" then
                    if mHum.Health < bestScore then
                        bestScore = mHum.Health
                        bestTarget = mob
                    end
                elseif Config.TargetMode == "BossFirst" then
                    local isBoss = mHum.MaxHealth > 5000 or mob.Name:lower():find("boss")
                    local score = isBoss and (dist - 100000) or dist
                    if score < bestScore then
                        bestScore = score
                        bestTarget = mob
                    end
                end
            end
        end
    end

    return bestTarget
end

-- ========================================================================
-- [6] NETWORK-LEVEL COOLDOWN ENGINE & COMBAT HELPERS
-- ========================================================================
local localSkillCooldowns = {}

if RemoteBank.CastResponse and RemoteBank.CastResponse.OnClientEvent then
    trackConnection(RemoteBank.CastResponse.OnClientEvent:Connect(function(res)
        if type(res) == "table" and res.hotbar and res.cooldown then
            localSkillCooldowns[res.hotbar] = os.clock() + (tonumber(res.cooldown) or 3)
        end
    end))
end

if RemoteBank.CooldownUpdate and RemoteBank.CooldownUpdate.OnClientEvent then
    trackConnection(RemoteBank.CooldownUpdate.OnClientEvent:Connect(function(res)
        if type(res) == "table" and res.hotbar then
            local remaining = tonumber(res.remaining) or 0
            if remaining > 0 then
                localSkillCooldowns[res.hotbar] = os.clock() + remaining
            else
                localSkillCooldowns[res.hotbar] = nil
            end
        end
    end))
end

local function isSkillOnCooldown(slot)
    -- 1. Ưu tiên kiểm tra Network Packet Cooldown
    if localSkillCooldowns[slot] and os.clock() < localSkillCooldowns[slot] then
        return true
    end

    -- 2. Kiểm tra UI hiển thị Hotbar
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local mainHud = pg and pg:FindFirstChild("MainHUD")
    local bottomFrame = mainHud and mainHud:FindFirstChild("Bottom") and mainHud.Bottom:FindFirstChild("Frame")
    if bottomFrame then
        local slotFrame = bottomFrame:FindFirstChild(tostring(slot))
        local cd = slotFrame and slotFrame:FindFirstChild("Frame") and slotFrame.Frame:FindFirstChild("Cooldown")
        if cd and cd.Visible then
            return true
        end
    end
    return false
end

local function canCastUltimate()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local mainHud = pg and pg:FindFirstChild("MainHUD")
    local leaderBuff = mainHud and mainHud:FindFirstChild("Bottom") and mainHud.Bottom:FindFirstChild("LeaderBuff")
    if leaderBuff then
        local cd = leaderBuff:FindFirstChild("Frame") and leaderBuff.Frame:FindFirstChild("Cooldown")
        if cd and cd.Visible then
            return false
        end
    end
    return true
end

-- Tự động phản hồi HitboxClassRemote để xác thực mọi va chạm đòn đánh
local HitboxClassRemote = ReplicatedStorage:FindFirstChild("HitboxClassRemote")
if HitboxClassRemote and HitboxClassRemote:IsA("RemoteEvent") then
    trackConnection(HitboxClassRemote.OnClientEvent:Connect(function(action, payload)
        if action == "New" and type(payload) == "table" and payload._Tick then
            pcall(function()
                HitboxClassRemote:FireServer(payload._Tick)
            end)
        end
    end))
end

-- ========================================================================
-- [7] AUTO DODGE ENGINE (HỆ THỐNG TỰ ĐỘNG NÉ CHIÊU BOSS & VÙNG ĐỎ TELEGRAPH)
-- ========================================================================
local activeTelegraphs = {}

if RemoteBank.BossTelegraph and RemoteBank.BossTelegraph.OnClientEvent then
    trackConnection(RemoteBank.BossTelegraph.OnClientEvent:Connect(function(msg)
        if type(msg) ~= "table" then return end
        local now = os.clock()

        if msg.op == "pulse" then
            if typeof(msg.cf) == "CFrame" then
                local pid = "pulse_" .. tostring(now) .. "_" .. tostring(math.random(1000, 9999))
                activeTelegraphs[pid] = {
                    id = pid,
                    shape = { Type = "Circle", Radius = tonumber(msg.radius) or 10 },
                    follow = false,
                    cf = msg.cf,
                    born = now,
                    maxDuration = (tonumber(msg.duration) or 0.6) + 0.35
                }
            end
            return
        end

        local id = msg.id
        if id == nil then return end

        if msg.op == "new" then
            if type(msg.shape) == "table" then
                activeTelegraphs[id] = {
                    id = id,
                    shape = msg.shape,
                    boss = (typeof(msg.boss) == "Instance") and msg.boss or nil,
                    foot = tonumber(msg.foot) or 0,
                    follow = (typeof(msg.boss) == "Instance"),
                    cf = (typeof(msg.cf) == "CFrame") and msg.cf or nil,
                    born = now,
                    maxDuration = 3.5
                }
            end
        elseif msg.op == "place" then
            local entry = activeTelegraphs[id]
            if entry and typeof(msg.cf) == "CFrame" then
                entry.follow = false
                entry.cf = msg.cf
                entry.born = now
                entry.maxDuration = 1.8
            end
        elseif msg.op == "flash" or msg.op == "remove" then
            activeTelegraphs[id] = nil
        end
    end))
end

local function resolveTelegraphOrigin(entry)
    if entry.follow and entry.boss and entry.boss.Parent then
        local bRoot = entry.boss:FindFirstChild("HumanoidRootPart")
        if bRoot then
            local pos = bRoot.Position - Vector3.new(0, entry.foot or 0, 0)
            local look = bRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
            if look.Magnitude < 0.01 then
                look = Vector3.new(0, 0, -1)
            else
                look = look.Unit
            end
            entry.cf = CFrame.lookAt(pos, pos + look)
            return entry.cf
        end
    end
    return entry.cf
end

-- Giải toán tọa độ né an toàn khỏi mọi vùng đỏ (Circle, Box, Sector & Workspace BossTelegraphs)
local function computeDodgeEscape(testPos, fallbackOriginY)
    if not Config.AutoDodge then
        Config.IsCurrentlyDodging = false
        return nil
    end

    local now = os.clock()
    local margin = Config.DodgeMargin or 6
    local isThreatened = false
    local escapePos = testPos
    local threatOriginY = fallbackOriginY or testPos.Y

    -- 1. Kiểm tra dữ liệu gói tin Telegraph thời gian thực
    for id, entry in pairs(activeTelegraphs) do
        if (now - entry.born) > (entry.maxDuration or 3.5) then
            activeTelegraphs[id] = nil
        else
            local originCF = resolveTelegraphOrigin(entry)
            local shape = entry.shape
            if typeof(originCF) == "CFrame" and type(shape) == "table" then
                local localPos = originCF:PointToObjectSpace(escapePos)
                if math.abs(localPos.Y) <= 22 then
                    local sType = shape.Type
                    if sType == "Circle" then
                        local safeR = (tonumber(shape.Radius) or 9) + margin
                        local planarDist = math.sqrt(localPos.X * localPos.X + localPos.Z * localPos.Z)
                        if planarDist < safeR then
                            isThreatened = true
                            threatOriginY = math.max(threatOriginY, originCF.Position.Y)
                            local dx, dz = 0, 1
                            if planarDist > 0.1 then
                                dx = localPos.X / planarDist
                                dz = localPos.Z / planarDist
                            end
                            local safeLocal = Vector3.new(dx * (safeR + 3), 0, dz * (safeR + 3))
                            local worldSafe = originCF:PointToWorldSpace(safeLocal)
                            escapePos = Vector3.new(worldSafe.X, escapePos.Y, worldSafe.Z)
                        end
                    elseif sType == "Box" then
                        local halfW = ((tonumber(shape.Width) or 6) * 0.5) + margin
                        local len = tonumber(shape.Length) or 28
                        local fwd = tonumber(shape.Forward) or 0
                        local minZ = -(fwd + len + margin)
                        local maxZ = -fwd + margin
                        if math.abs(localPos.X) < halfW and localPos.Z >= minZ and localPos.Z <= maxZ then
                            isThreatened = true
                            threatOriginY = math.max(threatOriginY, originCF.Position.Y)
                            -- Né ngang vuông góc khỏi đường húc (Charge) hoặc lùi ra sau lưng Boss
                            local sideSign = (localPos.X >= 0) and 1 or -1
                            local safeLocal = Vector3.new(sideSign * (halfW + 3.5), 0, math.min(localPos.Z, 4))
                            local worldSafe = originCF:PointToWorldSpace(safeLocal)
                            escapePos = Vector3.new(worldSafe.X, escapePos.Y, worldSafe.Z)
                        end
                    elseif sType == "Sector" then
                        local safeR = (tonumber(shape.Radius) or 10) + margin
                        local planarDist = math.sqrt(localPos.X * localPos.X + localPos.Z * localPos.Z)
                        if planarDist < safeR and localPos.Z < (margin + 2) then
                            isThreatened = true
                            threatOriginY = math.max(threatOriginY, originCF.Position.Y)
                            -- Đòn quét hình quạt luôn hướng về phía trước (-Z), lách ngay ra sau lưng Boss (+Z)
                            local safeLocal = Vector3.new(0, 0, math.max(margin + 4, 8))
                            local worldSafe = originCF:PointToWorldSpace(safeLocal)
                            escapePos = Vector3.new(worldSafe.X, escapePos.Y, worldSafe.Z)
                        end
                    end
                end
            end
        end
    end

    -- 2. Lớp bảo vệ vật lý: Quét trực tiếp các Part vùng đỏ trong workspace.BossTelegraphs
    local teleFolder = Workspace:FindFirstChild("BossTelegraphs")
    if teleFolder then
        for _, desc in ipairs(teleFolder:GetDescendants()) do
            if desc:IsA("BasePart") then
                local lp = desc.CFrame:PointToObjectSpace(escapePos)
                local hx = (desc.Size.X * 0.5) + margin
                local hz = (desc.Size.Z * 0.5) + margin
                if math.abs(lp.X) < hx and math.abs(lp.Z) < hz and math.abs(lp.Y) <= 22 then
                    isThreatened = true
                    threatOriginY = math.max(threatOriginY, desc.Position.Y)
                    local pushX = (lp.X >= 0 and 1 or -1) * (hx + 3)
                    local worldSafe = desc.CFrame:PointToWorldSpace(Vector3.new(pushX, 0, lp.Z))
                    escapePos = Vector3.new(worldSafe.X, escapePos.Y, worldSafe.Z)
                end
            end
        end
    end

    Config.IsCurrentlyDodging = isThreatened
    if not isThreatened then
        return nil
    end

    -- EnemyAttacks.HitAbove = 14 -> Nâng độ cao lên >16.5 studs sẽ miễn nhiễm 100% sát thương mặt đất
    if Config.DodgeMode == "SkyEvade" then
        return Vector3.new(testPos.X, threatOriginY + 17.5, testPos.Z)
    elseif Config.DodgeMode == "Sidestep" then
        return Vector3.new(escapePos.X, testPos.Y, escapePos.Z)
    else
        -- SmartHybrid: Vừa dịch ngang khỏi vùng đỏ vừa nâng cao 16.5 studs
        return Vector3.new(escapePos.X, threatOriginY + 16.5, escapePos.Z)
    end
end

-- ========================================================================
-- [7.5] AUTO POSITIONING & SMOOTH COMBAT ENGINE (ANTI-VOID & FLOOR-LOCK)
-- ========================================================================
-- Tính độ cao đứng đánh quái dựa trực tiếp trên tâm quái + Độ Cao Tùy Chỉnh (Không raycast lên vách đá/cây làm trượt đòn đánh thường)
local function getSafeStandingY(xzPos, mobRootY, activeMap, customOffset)
    local minFloorY = -25
    local spawnPart = activeMap and activeMap:FindFirstChild("SpawnPart", true)
    if spawnPart and spawnPart:IsA("BasePart") then
        minFloorY = spawnPart.Position.Y - 12
    end

    local offset = (customOffset ~= nil) and customOffset or (Config.CombatHeightOffset or 0)
    local desiredY = (mobRootY or 5) + offset
    return math.max(desiredY, minFloorY)
end

local isActivelyLockingTarget = false
local wasNoClipActive = false

local function restoreCharacterCollision()
    if LocalPlayer.Character then
        for _, partName in ipairs({ "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso" }) do
            local p = LocalPlayer.Character:FindFirstChild(partName)
            if p and p:IsA("BasePart") then
                p.CanCollide = true
            end
        end
    end
end

local function releaseCombatLock()
    isActivelyLockingTarget = false
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local bv = root:FindFirstChild("Helm_AntiGravity")
        if bv then bv:Destroy() end
    end
    if not Config.NoClip then
        restoreCharacterCollision()
    end
end

trackConnection(RunService.Heartbeat:Connect(function()
    if not isScriptRunning then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        isActivelyLockingTarget = false
        return
    end

    local activeMap = getActiveMapFolder()
    local spawnPart = activeMap and activeMap:FindFirstChild("SpawnPart", true)
    local voidLimitY = (spawnPart and spawnPart:IsA("BasePart")) and (spawnPart.Position.Y - 25) or -45

    -- 1. CỨU HỘ CHỐNG RƠI HƯ KHÔNG (ANTI-VOID RESCUE): Kéo ngay về mặt sàn Spawn nếu nhân vật tụt xuống dưới đáy map
    if root.Position.Y < voidLimitY then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if spawnPart and spawnPart:IsA("BasePart") then
            root.CFrame = spawnPart.CFrame + Vector3.new(0, 5, 0)
        else
            root.CFrame = CFrame.new(root.Position.X, 30, root.Position.Z)
        end
        return
    end

    local bountyActive, bountyStatus = isBountyOverrideActive()
    local inMission = isInMission()
    local shouldPosition = false
    if bountyActive then
        -- [ƯU TIÊN 1: AUTO BOUNTY] Chỉ tele áp sát quái Bounty khi đang ở đúng Map của quái đó
        local onBountyWorld = (not inMission) and (not bountyStatus.world or getCurrentMapName() == bountyStatus.world)
        shouldPosition = Config.BountyAutoTeleport and onBountyWorld
    elseif inMission then
        -- [ƯU TIÊN 2: AUTO MISSIONS]
        shouldPosition = (Config.AutoMissionFarm and Config.MissionAutoTeleport) or Config.AutoPosition
    else
        -- [ƯU TIÊN 3: CHIẾN ĐẤU THƯỜNG]
        shouldPosition = Config.AutoPosition
    end

    -- 2. Khi không bật giữ vị trí / Tele: tắt ngay BodyVelocity để nhân vật đứng tự do, chỉ né khi AutoDodge bật
    if not shouldPosition then
        isActivelyLockingTarget = false
        local dodgePos = computeDodgeEscape(root.Position, root.Position.Y)
        if dodgePos then
            local safeDodgeY = math.max(dodgePos.Y, getSafeStandingY(dodgePos, root.Position.Y, activeMap, 0))
            local finalDodge = Vector3.new(dodgePos.X, safeDodgeY, dodgePos.Z)
            root.CFrame = CFrame.new(finalDodge, finalDodge + root.CFrame.LookVector)
            root.AssemblyLinearVelocity = Vector3.zero
        else
            local bv = root:FindFirstChild("Helm_AntiGravity")
            if bv then bv:Destroy() end
            if not Config.NoClip then
                restoreCharacterCollision()
            end
        end
        return
    end

    -- 3. Kiểm tra mục tiêu trên TỪNG FRAME: nếu quái vừa chết hoặc không khớp ưu tiên hiện tại thì quét lại ngay
    local target = Config.TargetCurrent
    local needRescan = not isValidCombatTarget(target, activeMap)
    if not needRescan and bountyActive and bountyStatus and bountyStatus.enemy and bountyStatus.enemy ~= "" then
        local tEnemyLower = tostring(bountyStatus.enemy):lower()
        local curNameLower = target.Name:lower()
        if curNameLower ~= tEnemyLower and not curNameLower:find(tEnemyLower, 1, true) then
            needRescan = true
        end
    elseif not needRescan and not bountyActive and not (inMission and Config.AutoMissionFarm) then
        if not isMobSelectedByFilter(target.Name) then
            needRescan = true
        end
    end
    if needRescan then
        target = getBestTarget()
        Config.TargetCurrent = target
    end

    if not target or not isValidCombatTarget(target, activeMap) then
        isActivelyLockingTarget = false
        local dodgePos = computeDodgeEscape(root.Position, root.Position.Y)
        if dodgePos then
            local safeDodgeY = math.max(dodgePos.Y, getSafeStandingY(dodgePos, root.Position.Y, activeMap, 0))
            local finalDodge = Vector3.new(dodgePos.X, safeDodgeY, dodgePos.Z)
            root.CFrame = CFrame.new(finalDodge, finalDodge + root.CFrame.LookVector)
            root.AssemblyLinearVelocity = Vector3.zero
        else
            -- Khi hết quái (chờ Wave mới hoặc ở Lobby), gỡ bỏ AntiGravity & bật lại va chạm sàn để không trôi xuống đất
            local bv = root:FindFirstChild("Helm_AntiGravity")
            if bv then bv:Destroy() end
            if not Config.NoClip then
                restoreCharacterCollision()
            end
        end
        return
    end

    local tRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")
    if not tRoot then
        isActivelyLockingTarget = false
        return
    end

    isActivelyLockingTarget = true

    -- Bật Anti-Gravity BodyVelocity khi đang khóa mục tiêu sống
    local bv = root:FindFirstChild("Helm_AntiGravity")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "Helm_AntiGravity"
        bv.MaxForce = Vector3.new(1e7, 1e7, 1e7)
        bv.Velocity = Vector3.zero
        bv.Parent = root
    end
    bv.Velocity = Vector3.zero

    -- Phẳng hóa vector hướng nhìn của quái trên mặt phẳng XZ (chống lỗi quái chúi đầu làm nhân vật bị cắm xuống dưới sàn)
    local mobPos = tRoot.Position
    local mobFlatLook = Vector3.new(tRoot.CFrame.LookVector.X, 0, tRoot.CFrame.LookVector.Z)
    if mobFlatLook.Magnitude < 0.05 then
        mobFlatLook = Vector3.new(0, 0, -1)
    else
        mobFlatLook = mobFlatLook.Unit
    end

    local distOffset = Config.BehindDistance or 2.5
    local targetCFrame = nil

    if Config.PositionMode == "GroundMelee" then
        local diff = Vector3.new(root.Position.X - mobPos.X, 0, root.Position.Z - mobPos.Z)
        local dir = (diff.Magnitude > 0.1) and diff.Unit or (-mobFlatLook)
        local standXZ = Vector3.new(mobPos.X, 0, mobPos.Z) + dir * distOffset
        local safeY = getSafeStandingY(standXZ, mobPos.Y, activeMap)
        local standPos = Vector3.new(standXZ.X, safeY, standXZ.Z)
        local lookAt = Vector3.new(mobPos.X, mobPos.Y, mobPos.Z)
        if (lookAt - standPos).Magnitude < 0.1 then lookAt = standPos + mobFlatLook end
        targetCFrame = CFrame.new(standPos, lookAt)
    elseif Config.PositionMode == "HoverAbove" then
        local hoverH = Config.CombatHeightOffset
        if hoverH == 0 then hoverH = Config.HoverHeight or 6 end
        local safeY = getSafeStandingY(mobPos, mobPos.Y, activeMap, hoverH)
        local hoverPos = Vector3.new(mobPos.X, safeY, mobPos.Z) - mobFlatLook * math.max(distOffset, 2.0)
        local lookAt = Vector3.new(mobPos.X, mobPos.Y, mobPos.Z)
        if (lookAt - hoverPos).Magnitude < 0.1 then lookAt = hoverPos + mobFlatLook end
        targetCFrame = CFrame.new(hoverPos, lookAt)
    elseif Config.PositionMode == "FrontMob" then
        local standXZ = Vector3.new(mobPos.X, 0, mobPos.Z) + mobFlatLook * distOffset
        local safeY = getSafeStandingY(standXZ, mobPos.Y, activeMap)
        local standPos = Vector3.new(standXZ.X, safeY, standXZ.Z)
        local lookAt = Vector3.new(mobPos.X, mobPos.Y, mobPos.Z)
        if (lookAt - standPos).Magnitude < 0.1 then lookAt = standPos - mobFlatLook end
        targetCFrame = CFrame.new(standPos, lookAt)
    else
        -- BehindMob (Mặc định chuẩn nhất: khóa sát sau lưng quái 2.5 studs, cùng cao độ Y + Độ Cao Tùy Chỉnh)
        local standXZ = Vector3.new(mobPos.X, 0, mobPos.Z) - mobFlatLook * distOffset
        local safeY = getSafeStandingY(standXZ, mobPos.Y, activeMap)
        local standPos = Vector3.new(standXZ.X, safeY, standXZ.Z)
        local lookAt = Vector3.new(mobPos.X, mobPos.Y, mobPos.Z)
        if (lookAt - standPos).Magnitude < 0.1 then lookAt = standPos + mobFlatLook end
        targetCFrame = CFrame.new(standPos, lookAt)
    end

    if targetCFrame then
        -- Kiểm tra xem vị trí chuẩn bị đứng có nằm trong vùng đỏ Telegraph của Boss/Quái không
        local dodgePos = computeDodgeEscape(targetCFrame.Position, mobPos.Y)
        if dodgePos then
            local safeDodgeY = math.max(dodgePos.Y, getSafeStandingY(dodgePos, mobPos.Y, activeMap, 0))
            local finalDodge = Vector3.new(dodgePos.X, safeDodgeY, dodgePos.Z)
            local lookAt = Vector3.new(mobPos.X, mobPos.Y, mobPos.Z)
            if (lookAt - finalDodge).Magnitude < 0.1 then
                lookAt = finalDodge + Vector3.new(0, 0, -1)
            end
            targetCFrame = CFrame.new(finalDodge, lookAt)
        end

        root.CFrame = targetCFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end))

-- NoClip Thread: Chỉ tắt va chạm khi ĐANG KHÓA MỤC TIÊU SỐNG hoặc người chơi bật NoClip chủ động (chống rơi xuyên sàn khi chờ Wave)
trackConnection(RunService.Stepped:Connect(function()
    local shouldNoClip = Config.NoClip or isActivelyLockingTarget
    if shouldNoClip and LocalPlayer.Character then
        wasNoClipActive = true
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    elseif wasNoClipActive then
        wasNoClipActive = false
        restoreCharacterCollision()
    end
end))

-- ========================================================================
-- [8] COMBAT LOOPS: MELEE, SKILLS & ULTIMATE
-- ========================================================================
-- 1. Auto Melee Punch Loop (Hỗ trợ Sub-Frame Multi-Packet Batching xuống tới 1ms)
task.spawn(function()
    local lastTargetScan = 0
    while isScriptRunning do
        local delaySec = Config.PunchDelay or 0.015
        local bountyActive = isBountyOverrideActive()
        local inMissionAttack = Config.AutoMissionFarm and isInMission()
        if bountyActive or Config.AutoPunch or inMissionAttack then
            local now = tick()
            if not isValidCombatTarget(Config.TargetCurrent) or (now - lastTargetScan >= 0.15) then
                Config.TargetCurrent = getBestTarget()
                lastTargetScan = now
            end

            -- Khi cài đặt < 16ms (vượt ngưỡng 1 frame 60FPS), tự động đóng gói nhiều đòn (Packet Batching)
            local burstCount = 1
            if delaySec < 0.016 then
                burstCount = math.clamp(math.floor(0.016 / math.max(delaySec, 0.001)), 1, 16)
            end

            pcall(function()
                for _ = 1, burstCount do
                    RemoteBank.PunchRemote:Fire()
                end
            end)
        end
        task.wait(math.max(delaySec, 0.001))
    end
end)

-- 2. Auto Hotbar Powers / Skills Loop
task.spawn(function()
    while isScriptRunning do
        local bountyActive = isBountyOverrideActive()
        local bountySkills = bountyActive and Config.BountyAutoSkills
        local inMissionSkills = (not bountyActive) and Config.AutoMissionFarm and Config.MissionAutoSkills and isInMission()
        if bountySkills or Config.AutoSkills or inMissionSkills then
            local target = getBestTarget()
            Config.TargetCurrent = target
            if target then
                local tRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")
                local targetPos = tRoot and tRoot.Position or Vector3.new(0, 0, 0)

                for slotIdx = 1, 5 do
                    if Config.SkillSlots[slotIdx] and not isSkillOnCooldown(slotIdx) then
                        pcall(function()
                            RemoteBank.CastPower:Fire({
                                hotbar = slotIdx,
                                targetPosition = targetPos
                            })
                        end)
                        task.wait(0.06)
                    end
                end
            end
        end
        task.wait(Config.SkillDelay or 0.15)
    end
end)

-- 3. Auto Ultimate Loop
task.spawn(function()
    while isScriptRunning do
        local bountyActive = isBountyOverrideActive()
        local bountyUlt = bountyActive and Config.BountyAutoSkills
        local inMissionUlt = (not bountyActive) and Config.AutoMissionFarm and Config.MissionAutoSkills and isInMission()
        if (bountyUlt or Config.AutoUltimate or inMissionUlt) and canCastUltimate() then
            local target = getBestTarget()
            if target then
                pcall(function()
                    RemoteBank.CastUltimate:Fire()
                end)
            end
        end
        task.wait(Config.UltimateCheckDelay or 1.0)
    end
end)

-- ========================================================================
-- [9] AUTO PICKUP & DROP MAGNET (HÚT VẬT PHẨM & TIỀN TỆ VÔ HẠN TOÀN MAP)
-- ========================================================================
local pendingDrops = {}
local knownDrops = {}
local lastDropCleanTime = os.clock()

local function queueDrop(uuid)
    if not uuid or typeof(uuid) ~= "string" or uuid == "" then return end
    if knownDrops[uuid] then return end
    knownDrops[uuid] = os.clock()
    table.insert(pendingDrops, uuid)
end

-- Hàm sweep gom sạch toàn bộ CurrencyDrop trên Workspace về chân người chơi
local function forceSweepDrops()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local playerCFrame = root and root.CFrame

    for _, child in ipairs(Workspace:GetChildren()) do
        if child.Name == "CurrencyDrop" then
            pcall(function()
                child:SetAttribute("Pickable", true)
                if playerCFrame and child:IsA("BasePart") then
                    child.CFrame = playerCFrame
                    child.CanCollide = false
                end
            end)

            local idObj = child:FindFirstChild("ID")
            local uuid = idObj and idObj.Value
            if uuid and typeof(uuid) == "string" and uuid ~= "" then
                queueDrop(uuid)
            end
        end
    end
end

-- 1. Đón đầu sự kiện rơi vật phẩm từ server (DropSpawnRemote)
if RemoteBank.DropSpawnRemote and RemoteBank.DropSpawnRemote.OnClientEvent then
    trackConnection(RemoteBank.DropSpawnRemote.OnClientEvent:Connect(function(dropBatch)
        if not Config.AutoMagnet then return end
        if type(dropBatch) == "table" then
            for _, item in ipairs(dropBatch) do
                local dropUuid = nil
                if type(item) == "table" then
                    dropUuid = item.uuid or item.UUID or item.id or item.Id
                elseif type(item) == "string" then
                    dropUuid = item
                end
                if dropUuid then
                    queueDrop(dropUuid)
                end
            end
        end
    end))
end

-- 2. Quét liên tục Workspace: dịch chuyển CurrencyDrop về người chơi & gỡ bỏ mọi rào cản khoảng cách
task.spawn(function()
    while isScriptRunning do
        if Config.AutoMagnet then
            local now = os.clock()
            if now - lastDropCleanTime > 60 then
                lastDropCleanTime = now
                for u, t in pairs(knownDrops) do
                    if now - t > 120 then
                        knownDrops[u] = nil
                    end
                end
            end

            forceSweepDrops()
        end
        task.wait(0.2)
    end
end)

-- 3. Gửi gói tin nhặt đồ RemoteBank.PickupRemote theo đợt (Batch Pickup)
trackConnection(RunService.Heartbeat:Connect(function()
    if Config.AutoMagnet and #pendingDrops > 0 then
        local batch = {}
        local count = math.min(#pendingDrops, 50)
        for i = 1, count do
            table.insert(batch, pendingDrops[i])
        end
        for _ = 1, count do
            table.remove(pendingDrops, 1)
        end
        pcall(function()
            RemoteBank.PickupRemote:Fire(batch)
        end)
    end
end))

-- ========================================================================
-- [10] AUTO BOUNTY (ƯU TIÊN 1) & AUTO MISSIONS (ƯU TIÊN 2)
-- ========================================================================
-- 1. Luồng điều phối Auto Bounty (Ưu Tiên Số 1: Tự nhận -> Tự rời Phó Bản -> Tự Tele sang Map của Quái -> Săn đủ -> Tự Claim 1/10..10/10)
local lastBountyWorldTele = 0

task.spawn(function()
    while isScriptRunning do
        if Config.AutoBounty then
            local status = getBountyTaskStatus()
            if status and not status.completed and status.state ~= "Completed" then
                -- Bước 1: Tự động nhận chuỗi nhiệm vụ Bounty trong ngày nếu chưa nhận
                if status.state == "NeedAccept" then
                    pcall(function()
                        if RemoteBank.BountyAccept then
                            RemoteBank.BountyAccept:Fire(nil)
                        end
                        if RemoteBank.QuestSetTracked then
                            RemoteBank.QuestSetTracked:Fire("Bounty", status.position or 1)
                        end
                    end)
                    task.wait(1.2)
                -- Bước 2: Khi đã đánh đủ số lượng quái yêu cầu (ví dụ 12/12) -> Tự động Claim nhận thưởng để nhảy sang mốc tiếp theo
                elseif status.state == "ReadyToClaim" then
                    pcall(function()
                        if RemoteBank.BountyClaim then
                            RemoteBank.BountyClaim:Fire(nil)
                        end
                    end)
                    task.wait(1.0)
                -- Bước 3: Đang trong tiến trình săn quái Bounty (ví dụ Belu 3/12 ở Demon Citadel)
                elseif status.state == "InProgress" then
                    -- Nếu đang ở trong Phó Bản (Mission), tự thoát ra ngoài World để ưu tiên làm Bounty trước
                    if isInMission() then
                        releaseCombatLock()
                        Config.TargetCurrent = nil
                        pcall(function()
                            if RemoteBank.MissionDecision then
                                RemoteBank.MissionDecision:Fire("Return")
                            end
                            if RemoteBank.MissionReturn then
                                RemoteBank.MissionReturn:Fire()
                            end
                        end)
                        task.wait(3.5)
                    elseif Config.BountyAutoTeleport and status.world and status.world ~= "" then
                        local curMap = getCurrentMapName()
                        if curMap ~= status.world and (os.clock() - lastBountyWorldTele > 4.0) then
                            lastBountyWorldTele = os.clock()
                            releaseCombatLock()
                            Config.TargetCurrent = nil
                            pcall(function()
                                if RemoteBank and RemoteBank.Teleport then
                                    RemoteBank.Teleport:Fire(status.world)
                                elseif MapClient and typeof(MapClient.RequestTeleport) == "function" then
                                    MapClient.RequestTeleport(status.world)
                                end
                            end)
                            notify("Auto Bounty [Ưu Tiên 1]", string.format("Đang dịch chuyển sang %s để săn %s (%d/%d)!", tostring(status.world), tostring(status.enemy), status.progress or 0, status.target or 1), 3)
                            task.wait(3.5)
                        end
                    end
                end
            end
        end
        task.wait(1.0)
    end
end)

-- 2. Luồng điều phối Auto Missions (Ưu Tiên Số 2: Tự động chạy khi Auto Bounty đã xong 10/10 hoặc đang tắt)
local currentWaveInfo = {
    wave = 0,
    totalWaves = 0,
    enemiesAlive = 0,
    enemiesTotal = 0,
    title = ""
}

if RemoteBank.MissionWaveUpdate and RemoteBank.MissionWaveUpdate.OnClientEvent then
    trackConnection(RemoteBank.MissionWaveUpdate.OnClientEvent:Connect(function(data)
        if type(data) == "table" then
            currentWaveInfo.wave = tonumber(data.wave) or currentWaveInfo.wave
            currentWaveInfo.totalWaves = tonumber(data.totalWaves) or currentWaveInfo.totalWaves
            currentWaveInfo.enemiesAlive = tonumber(data.enemiesAlive) or currentWaveInfo.enemiesAlive
            currentWaveInfo.enemiesTotal = tonumber(data.enemiesTotal) or currentWaveInfo.enemiesTotal
            if data.title then
                currentWaveInfo.title = tostring(data.title)
            end
        end
    end))
end

local function isMissionRewardUIVisible()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local rewardUI = pGui and pGui:FindFirstChild("MainHUD")
        and pGui.MainHUD:FindFirstChild("Missions")
        and pGui.MainHUD.Missions:FindFirstChild("MissionRewardUI")
    return (rewardUI and rewardUI.Visible == true) or false
end

local function launchConfiguredMission()
    pcall(function()
        if not RemoteBank.MissionLaunch then return end
        local gm = Config.MissionGamemode or "Mission"
        if gm == "Challenge" then
            local tier = Config.ChallengeTier or "Regular"
            local idx = (tier == "Regular") and (tonumber(Config.ChallengeSlot) or 1) or 1
            RemoteBank.MissionLaunch:Fire({
                gamemode = "Challenge",
                tier = tier,
                index = idx
            })
        elseif gm == "Gauntlet" then
            RemoteBank.MissionLaunch:Fire({
                gamemode = "Gauntlet",
                chamber = tonumber(Config.GauntletChamber) or 1
            })
        elseif gm == "Invasion" then
            RemoteBank.MissionLaunch:Fire({
                gamemode = "Invasion",
                world = Config.MissionWorld or "Nemu's Village"
            })
        else
            local actNum = tonumber(Config.MissionAct) or 1
            -- Act 4 là EX Stage (10 Waves) chỉ có chế độ Hard trong MissionData
            local modeStr = (actNum == 4) and "Hard" or (Config.MissionMode or "Normal")
            RemoteBank.MissionLaunch:Fire({
                gamemode = "Mission",
                world = Config.MissionWorld or "Nemu's Village",
                act = actNum,
                mode = modeStr
            })
        end
    end)
end

local function handleMissionEndDecision(resultData)
    pcall(forceSweepDrops)
    if not RemoteBank.MissionDecision then return end

    -- Nếu Auto Bounty (Ưu Tiên 1) đang bật và có nhiệm vụ mới -> Tự chọn Return thoát ra ngoài làm Bounty
    if isBountyOverrideActive() then
        pcall(function()
            RemoteBank.MissionDecision:Fire("Return")
        end)
        return
    end

    local preferred = Config.MissionDecisionType or "Retry"
    local canNext = (type(resultData) ~= "table") or (resultData.canNext ~= false)
    local canRetry = (type(resultData) ~= "table") or (resultData.canRetry ~= false)

    local firstChoice = preferred
    if firstChoice == "Next" and not canNext then
        firstChoice = canRetry and "Retry" or "Return"
    elseif firstChoice == "Retry" and not canRetry then
        firstChoice = "Return"
    end

    pcall(function()
        RemoteBank.MissionDecision:Fire(firstChoice)
    end)

    -- Fallback nếu màn tiếp theo bị khóa hoặc hết lượt Challenge trong ngày
    task.delay(2.2, function()
        if isScriptRunning and isMissionRewardUIVisible() and (Config.AutoReplayMission or Config.AutoMission) then
            pcall(function()
                if firstChoice == "Next" and canRetry then
                    RemoteBank.MissionDecision:Fire("Retry")
                else
                    RemoteBank.MissionDecision:Fire("Return")
                end
            end)
        end
    end)
end

task.spawn(function()
    while isScriptRunning do
        -- 1. Nếu bảng tổng kết thưởng đang hiện mà sự kiện bị trễ -> Tự bấm quyết định
        if (Config.AutoReplayMission or Config.AutoMission or isBountyOverrideActive()) and isMissionRewardUIVisible() then
            task.wait(1.6)
            if isMissionRewardUIVisible() then
                handleMissionEndDecision(nil)
                task.wait(2.5)
            end
        end

        -- 2. Chỉ khởi chạy vào Phó Bản (Ưu Tiên 2) khi Auto Bounty (Ưu Tiên 1) không bận săn quái
        local bountyBusy = isBountyOverrideActive()
        if Config.AutoMission and not bountyBusy and not isInMission() then
            launchConfiguredMission()
            task.wait(4.5)
        end

        task.wait(1.5)
    end
end)

-- Tự động tiếp tục ngay khi nhận gói tin kết thúc màn chơi (MissionComplete)
if RemoteBank.MissionComplete and RemoteBank.MissionComplete.OnClientEvent then
    trackConnection(RemoteBank.MissionComplete.OnClientEvent:Connect(function(resultData)
        if Config.AutoReplayMission or Config.AutoMission or isBountyOverrideActive() then
            task.spawn(function()
                task.wait(1.6)
                handleMissionEndDecision(resultData)
            end)
        end
    end))
end

-- ========================================================================
-- [11] AUTO SUMMON / GACHA
-- ========================================================================
task.spawn(function()
    while isScriptRunning do
        if Config.AutoSummon then
            pcall(function()
                if Config.SummonBanner == "Weapon Summon" then
                    RemoteBank.SummonWeapon:Fire(Config.SummonCount)
                else
                    RemoteBank.PullBanner:Fire(Config.SummonBanner, Config.SummonCount)
                end
            end)
            task.wait(0.6)
        else
            task.wait(1)
        end
    end
end)

-- ========================================================================
-- [12] GIAO DIỆN NGƯỜI DÙNG (NATIVE INVENTORY.LUA SECTORS)
-- ========================================================================
local Window
local okWin, resWin = pcall(function()
    return library:CreateWindow("HelmHub | Anime CardVerse")
end)

if okWin and resWin and typeof(resWin.CreateTab) == "function" then
    Window = resWin
else
    local okWin2, resWin2 = pcall(function()
        return library.CreateWindow(library, "HelmHub | Anime CardVerse")
    end)
    if okWin2 and resWin2 and typeof(resWin2.CreateTab) == "function" then
        Window = resWin2
    end
end

if not Window then
    warn("[HelmHub | Anime CardVerse] Không thể tạo cửa sổ giao diện chính!")
    return
end

-- ------------------------------------------------------------------------
-- TAB 1: CHIẾN ĐẤU (COMBAT)
-- ------------------------------------------------------------------------
local TabCombat = Window:CreateTab("Chiến Đấu")
local SecAttack = TabCombat:CreateSector("Tấn Công & Kỹ Năng", "left")
local SecTarget = TabCombat:CreateSector("Mục Tiêu & Vị Trí", "right")

-- Live Status Labels
local StatusMapLabel = SecAttack:AddLabel("Bản Đồ: Đang kiểm tra...", false)
local StatusMobLabel = SecAttack:AddLabel("Quái Vật: 0 con", false)
local StatusTargetLabel = SecAttack:AddLabel("Mục Tiêu: Chưa có", false)

-- Cập nhật trạng thái thời gian thực
task.spawn(function()
    while isScriptRunning do
        pcall(function()
            local mapName = getCurrentMapName()
            if mapName == "Lobby" then
                StatusMapLabel:Set("Bản Đồ: LOBBY (Khu An Toàn - Không có quái)")
            else
                StatusMapLabel:Set(string.format("Bản Đồ: %s", tostring(mapName)))
            end

            local enemies = getAllEnemies()
            local filteredCount = 0
            for _, mob in ipairs(enemies) do
                if mob.Name and isMobSelectedByFilter(mob.Name) then
                    filteredCount = filteredCount + 1
                end
            end

            local selectedDisplay = getSelectedMobsDisplay()
            if selectedDisplay then
                StatusMobLabel:Set(string.format("Quái [%s]: %d/%d con", selectedDisplay, filteredCount, #enemies))
            else
                StatusMobLabel:Set(string.format("Quái Vật Quét Được: %d con", #enemies))
            end

            if Config.TargetCurrent and Config.TargetCurrent.Parent then
                local hum = Config.TargetCurrent:FindFirstChildOfClass("Humanoid")
                local hp = hum and math.floor(hum.Health) or 0
                local maxHp = hum and math.floor(hum.MaxHealth) or 1
                StatusTargetLabel:Set(string.format("Mục Tiêu: %s (%d/%d HP)", Config.TargetCurrent.Name, hp, maxHp))
            else
                StatusTargetLabel:Set("Mục Tiêu: Chưa nhắm được mục tiêu")
            end
        end)
        task.wait(0.5)
    end
end)

pcall(function()
    SecAttack:AddToggle("Tự Động Đánh Thường (Auto Punch)", Config.AutoPunch, function(val)
        Config.AutoPunch = val
    end)

    SecAttack:AddSlider("Tốc Độ Đánh (ms)", 1, 15, 400, 1, function(val)
        Config.PunchDelay = (tonumber(val) or 15) / 1000
    end)

    SecAttack:AddToggle("Tự Động Xả Kỹ Năng (Auto Skills)", Config.AutoSkills, function(val)
        Config.AutoSkills = val
    end)

    SecAttack:AddToggle("Tự Động Chiêu Cuối (Auto Ultimate)", Config.AutoUltimate, function(val)
        Config.AutoUltimate = val
    end)

    SecAttack:AddToggle("Hút Vật Phẩm Vô Hạn (Infinite Magnet)", Config.AutoMagnet, function(val)
        Config.AutoMagnet = val
    end)

    -- Nút vào nhanh màn chơi ngay tại Tab Chiến Đấu
    SecAttack:AddButton("▶ VÀO NGAY MÀN 1 (Nemu's Village - Act 1)", function()
        pcall(function()
            RemoteBank.MissionLaunch:Fire({
                gamemode = "Mission",
                world = "Nemu's Village",
                act = 1,
                mode = "Normal"
            })
            notify("Khởi Chạy Màn Chơi", "Đang chuyển vào Nemu's Village - Act 1...", 4)
        end)
    end)

    SecAttack:AddButton("🚀 Dịch Chuyển Tới Bệ Teleport Pad (Lobby)", function()
        pcall(function()
            local CollectionService = game:GetService("CollectionService")
            local targetPad = nil
            local pads = CollectionService:GetTagged("TeleportPad")
            if pads and #pads > 0 then
                targetPad = pads[1]
            else
                local gPads = CollectionService:GetTagged("GamemodePad")
                if gPads and #gPads > 0 then
                    targetPad = gPads[1]
                end
            end

            if not targetPad then
                local pad = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Lobby")
                targetPad = pad and pad:FindFirstChild("Assets") and pad.Assets:FindFirstChild("TeleportPad")
            end

            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetPad and root then
                root.CFrame = targetPad:GetPivot() + Vector3.new(0, 4, 0)
                notify("Dịch Chuyển", "Đã bay tới bệ chọn màn chơi!", 3)
            else
                notify("Dịch Chuyển", "Không tìm thấy bệ TeleportPad (Chỉ có ở Lobby)!", 3)
            end
        end)
    end)

    -- Bộ lọc ô kỹ năng Hotbar
    for slot = 1, 5 do
        SecAttack:AddToggle(string.format("Xả Kỹ Năng Ô %d (Skill %d)", slot, slot), true, function(val)
            Config.SkillSlots[slot] = (val == true)
        end)
    end
end)

-- Sector Mục Tiêu & Vị Trí (Bên Phải)
pcall(function()
    local WorldMobCatalog = {
        ["Tất Cả Thế Giới (All Worlds)"] = {
            "Tất Cả Quái (All Mobs)",
            "Alien Scout", "Alien Soldier", "Alien Officer", "Captain Shinyu", "Freezer",
            "Grants", "Yummy", "Grimmjay", "Arruru", "Aizo",
            "Goblin", "Goblin Shaman", "High Grunt", "Ferrite", "Belu"
        },
        ["Nemu's Village (Map 1)"] = {
            "Tất Cả Quái (All Mobs)",
            "Alien Scout", "Alien Soldier", "Alien Officer", "Captain Shinyu", "Freezer"
        },
        ["Hollow World (Map 2)"] = {
            "Tất Cả Quái (All Mobs)",
            "Grants", "Yummy", "Grimmjay", "Arruru", "Aizo"
        },
        ["Demon Citadel (Map 3)"] = {
            "Tất Cả Quái (All Mobs)",
            "Goblin", "Goblin Shaman", "High Grunt", "Ferrite", "Belu"
        }
    }

    local WorldTeleportNameMap = {
        ["Nemu's Village (Map 1)"] = "Nemu's Village",
        ["Hollow World (Map 2)"] = "Hollow World",
        ["Demon Citadel (Map 3)"] = "Demon Citadel"
    }

    local DropMob = nil
    local isWorldDropdownReady = false
    local hadAllMobsSelected = true

    local DropWorld = SecTarget:AddDropdown("Lọc Danh Sách Quái Theo World", {
        "Tất Cả Thế Giới (All Worlds)",
        "Nemu's Village (Map 1)",
        "Hollow World (Map 2)",
        "Demon Citadel (Map 3)"
    }, "Tất Cả Thế Giới (All Worlds)", false, function(val)
        Config.SelectedWorld = val
        local mobs = WorldMobCatalog[val] or WorldMobCatalog["Tất Cả Thế Giới (All Worlds)"]
        if DropMob and typeof(DropMob.Refresh) == "function" then
            hadAllMobsSelected = true
            DropMob:Refresh(mobs)
            DropMob:Set({ "Tất Cả Quái (All Mobs)" })
            Config.SelectedMobs = {}
            Config.SelectedMob = "All"
        end

        -- Khi người chơi chọn World 1 / World 2 / World 3 -> Tự động dịch chuyển nhân vật sang World đó luôn
        if isWorldDropdownReady and val then
            local targetWorldName = WorldTeleportNameMap[val]
            if targetWorldName and getCurrentMapName() ~= targetWorldName then
                releaseCombatLock()
                Config.TargetCurrent = nil
                pcall(function()
                    if RemoteBank and RemoteBank.Teleport then
                        RemoteBank.Teleport:Fire(targetWorldName)
                    elseif MapClient and typeof(MapClient.RequestTeleport) == "function" then
                        MapClient.RequestTeleport(targetWorldName)
                    end
                end)
                notify("Dịch Chuyển Thế Giới", string.format("Đang dịch chuyển bạn tới %s...", targetWorldName), 3)
            end
        end
    end)
    isWorldDropdownReady = true

    DropMob = SecTarget:AddDropdown("Chọn Quái Cần Đánh (Chọn Nhiều Quái)", WorldMobCatalog["Tất Cả Thế Giới (All Worlds)"], { "Tất Cả Quái (All Mobs)" }, true, function(vals)
        local list = (type(vals) == "table") and vals or (vals and { tostring(vals) } or {})
        local hasAllNow = (table.find(list, "Tất Cả Quái (All Mobs)") ~= nil) or (table.find(list, "All") ~= nil)

        local specific = {}
        for _, v in ipairs(list) do
            local s = tostring(v)
            if s ~= "" and s ~= "Tất Cả Quái (All Mobs)" and s ~= "All" then
                table.insert(specific, s)
            end
        end

        -- Nếu người chơi vừa bấm lại "Tất Cả Quái (All Mobs)" hoặc bỏ tích hết -> Reset về đánh tất cả quái
        if (hasAllNow and not hadAllMobsSelected) or (#specific == 0) then
            hadAllMobsSelected = true
            Config.SelectedMobs = {}
            Config.SelectedMob = "All"
            if DropMob and type(DropMob.values) == "table" then
                DropMob.values = { "Tất Cả Quái (All Mobs)" }
                pcall(function()
                    DropMob:updateText()
                    DropMob:updateItemVisuals()
                end)
            end
        else
            -- Người chơi đang tích chọn 1 hoặc nhiều quái cụ thể -> Tự bỏ dấu tích "Tất Cả Quái" để danh sách hiển thị gọn
            hadAllMobsSelected = false
            Config.SelectedMobs = specific
            Config.SelectedMob = specific[1] or "All"
            if hasAllNow and DropMob and type(DropMob.values) == "table" then
                DropMob.values = specific
                pcall(function()
                    DropMob:updateText()
                    DropMob:updateItemVisuals()
                end)
            end
        end
        Config.TargetCurrent = nil
    end)

    SecTarget:AddButton("🔄 Quét Quái Đang Sống Trên Map Hiện Tại", function()
        local liveEnemies = getAllEnemies()
        local nameSet = {}
        local options = { "Tất Cả Quái (All Mobs)" }
        for _, mob in ipairs(liveEnemies) do
            if mob.Name and not nameSet[mob.Name] then
                nameSet[mob.Name] = true
                table.insert(options, mob.Name)
            end
        end
        if #options > 1 then
            if DropMob and typeof(DropMob.Refresh) == "function" then
                hadAllMobsSelected = true
                DropMob:Refresh(options)
                DropMob:Set({ "Tất Cả Quái (All Mobs)" })
                Config.SelectedMobs = {}
                Config.SelectedMob = "All"
            end
            notify("Quét Quái", string.format("Đã nạp %d loại quái thực tế đang sống trên map!", #options - 1), 3)
        else
            notify("Quét Quái", "Không tìm thấy quái nào đang sống (hoặc bạn đang ở Lobby)!", 3)
        end
    end)

    SecTarget:AddDropdown("Chế Độ Nhắm Quái", { "Gần Nhất", "Máu Thấp Nhất", "Ưu Tiên Boss" }, "Gần Nhất", false, function(val)
        if val and tostring(val):find("Máu Thấp") then
            Config.TargetMode = "LowestHP"
        elseif val and tostring(val):find("Boss") then
            Config.TargetMode = "BossFirst"
        else
            Config.TargetMode = "Nearest"
        end
    end)

    SecTarget:AddSlider("Phạm Vi Quét Quái Toàn Map (Studs)", 100, 2500, 5000, 10, function(val)
        Config.ScanRange = tonumber(val) or 2500
    end)

    SecTarget:AddToggle("Tự Động Giữ Vị Trí / Áp Sát (Auto Position)", Config.AutoPosition, function(val)
        Config.AutoPosition = val
        if not val then
            releaseCombatLock()
        end
    end)

    SecTarget:AddDropdown("Kiểu Áp Sát Quái", {
        "Khóa Sau Lưng Quái (Chuẩn Nhất)",
        "Đứng Dưới Đất Đánh (Ground Melee)",
        "Khóa Trước Mặt Quái",
        "Treo Trên Đầu Quái (Hover)"
    }, "Khóa Sau Lưng Quái (Chuẩn Nhất)", false, function(val)
        local s = tostring(val or "")
        if s:find("Đất") or s:find("Ground") then
            Config.PositionMode = "GroundMelee"
        elseif s:find("Trước Mặt") then
            Config.PositionMode = "FrontMob"
        elseif s:find("Trên Đầu") or s:find("Hover") then
            Config.PositionMode = "HoverAbove"
        else
            Config.PositionMode = "BehindMob"
        end
    end)

    SecTarget:AddSlider("Độ Cao Đứng Đánh Quái (Studs)", -5, 0, 20, 0.5, function(val)
        Config.CombatHeightOffset = tonumber(val) or 0
    end)

    SecTarget:AddSlider("Khoảng Cách Áp Sát Quái (Studs)", 0.5, 2.5, 10, 0.5, function(val)
        Config.BehindDistance = tonumber(val) or 2.5
    end)

    SecTarget:AddToggle("Đi Xuyên Vật Thể (NoClip)", Config.NoClip, function(val)
        Config.NoClip = val
        if not val and not isActivelyLockingTarget then
            restoreCharacterCollision()
        end
    end)
end)

-- ------------------------------------------------------------------------
-- TAB 2: AUTO BOUNTY (ƯU TIÊN SỐ 1: TỰ NHẬN -> TELE ĐÚNG MAP -> SĂN ĐÚNG QUÁI -> TỰ TRẢ)
-- ------------------------------------------------------------------------
pcall(function()
    local TabBounty = Window:CreateTab("Auto Bounty")
    local SecBountyMain = TabBounty:CreateSector("Khởi Động & Tiến Độ Auto Bounty", "left")
    local SecBountyActions = TabBounty:CreateSector("Điều Khiển & Thao Tác Nhanh", "right")

    local PriorityStatusLabel = SecBountyMain:AddLabel("Ưu Tiên Đang Chạy: Đang kiểm tra...", false)
    local BountyStepLabel = SecBountyMain:AddLabel("Tiến Độ Bounty: 0/10", false)
    local BountyTargetLabel = SecBountyMain:AddLabel("Mục Tiêu Bounty: Chưa có", false)
    local BountyWorldLabel = SecBountyMain:AddLabel("Bản Đồ Săn: Chưa xác định", false)

    task.spawn(function()
        while isScriptRunning do
            pcall(function()
                local prioMode = getActivePriorityMode()
                if prioMode == "Bounty" then
                    PriorityStatusLabel:Set("🔥 Ưu Tiên Đang Chạy: [1] AUTO BOUNTY")
                elseif prioMode == "Mission" or prioMode == "MissionQueue" then
                    PriorityStatusLabel:Set("⚔️ Ưu Tiên Đang Chạy: [2] AUTO MISSIONS")
                else
                    PriorityStatusLabel:Set("🌍 Ưu Tiên Đang Chạy: [3] CHIẾN ĐẤU THƯỜNG")
                end

                local bStatus = getBountyTaskStatus()
                if not bStatus then
                    BountyStepLabel:Set("Tiến Độ Bounty: Chưa tải dữ liệu / Chưa nhận")
                    BountyTargetLabel:Set("Mục Tiêu Bounty: Chưa có")
                    BountyWorldLabel:Set("Bản Đồ Săn: ---")
                elseif bStatus.completed or bStatus.state == "Completed" then
                    BountyStepLabel:Set("Tiến Độ Bounty: ✅ ĐÃ HOÀN TẤT 10/10 HÔM NAY")
                    BountyTargetLabel:Set("Mục Tiêu Bounty: Đã xong toàn bộ (Nhường cho Missions/World)")
                    BountyWorldLabel:Set("Bản Đồ Săn: Hoàn thành")
                elseif bStatus.state == "NeedAccept" then
                    BountyStepLabel:Set(string.format("Tiến Độ Bounty: %d/10 (Chưa Nhận - Sẵn sàng nhận)", bStatus.position or 1))
                    BountyTargetLabel:Set(string.format("Mục Tiêu Sắp Tới: %s (0/%d)", tostring(bStatus.enemy or "?"), bStatus.target or 1))
                    BountyWorldLabel:Set(string.format("Bản Đồ Săn: %s", tostring(bStatus.world or "?")))
                else
                    BountyStepLabel:Set(string.format("Tiến Độ Bounty: Mốc %d/%d (Đã nhận)", bStatus.position or 1, bStatus.total or 10))
                    BountyTargetLabel:Set(string.format("Mục Tiêu Săn: %s (%d/%d)", tostring(bStatus.enemy or "?"), bStatus.progress or 0, bStatus.target or 1))
                    BountyWorldLabel:Set(string.format("Bản Đồ Săn: %s", tostring(bStatus.world or "?")))
                end
            end)
            task.wait(0.5)
        end
    end)

    SecBountyMain:AddToggle("🔥 Khởi Động Auto Bounty (Ưu Tiên Số 1)", Config.AutoBounty, function(val)
        Config.AutoBounty = val
        if not val and not Config.AutoPosition and not (isInMission() and Config.AutoMissionFarm and Config.MissionAutoTeleport) then
            releaseCombatLock()
        end
    end)

    SecBountyMain:AddToggle("📍 Tự Động Tele Sang Map & Áp Sát Quái Bounty", Config.BountyAutoTeleport, function(val)
        Config.BountyAutoTeleport = val
        if not val and not Config.AutoPosition then
            releaseCombatLock()
        end
    end)

    SecBountyMain:AddToggle("✨ Tự Động Xả Kỹ Năng & Ulti Khi Săn Bounty", Config.BountyAutoSkills, function(val)
        Config.BountyAutoSkills = val
    end)

    SecBountyActions:AddButton("📜 Nhận Nhiệm Vụ Bounty Ngay (Accept Bounty)", function()
        pcall(function()
            if RemoteBank.BountyAccept then
                RemoteBank.BountyAccept:Fire(nil)
            end
        end)
        notify("Auto Bounty", "Đã gửi lệnh nhận nhiệm vụ Bounty!", 3)
    end)

    SecBountyActions:AddButton("🎁 Nhận Thưởng Mốc Bounty Hiện Tại (Claim Bounty)", function()
        pcall(function()
            if RemoteBank.BountyClaim then
                RemoteBank.BountyClaim:Fire(nil)
            end
        end)
        notify("Auto Bounty", "Đã gửi lệnh nhận thưởng mốc Bounty!", 3)
    end)

    SecBountyActions:AddButton("🚀 Dịch Chuyển Ngay Tới Map Của Quái Bounty", function()
        local bStatus = getBountyTaskStatus()
        if bStatus and bStatus.world and bStatus.world ~= "" then
            releaseCombatLock()
            Config.TargetCurrent = nil
            pcall(function()
                if RemoteBank and RemoteBank.Teleport then
                    RemoteBank.Teleport:Fire(bStatus.world)
                elseif MapClient and typeof(MapClient.RequestTeleport) == "function" then
                    MapClient.RequestTeleport(bStatus.world)
                end
            end)
            notify("Auto Bounty", string.format("Đang dịch chuyển tới %s để săn %s!", tostring(bStatus.world), tostring(bStatus.enemy or "Bounty")), 3)
        else
            notify("Auto Bounty", "Chưa tìm thấy thông tin Map của nhiệm vụ Bounty hiện tại!", 3)
        end
    end)

    SecBountyActions:AddButton("📌 Ghim Hiển Thị Bounty Lên Màn Hình (Track)", function()
        pcall(function()
            local bStatus = getBountyTaskStatus()
            local pos = (bStatus and bStatus.position) or 1
            if RemoteBank.QuestSetTracked then
                RemoteBank.QuestSetTracked:Fire("Bounty", pos)
            end
        end)
        notify("Auto Bounty", "Đã ghim nhiệm vụ Bounty lên màn hình!", 3)
    end)
end)

-- ------------------------------------------------------------------------
-- TAB 3: AUTO MISSIONS (ƯU TIÊN SỐ 2: MISSIONS + AUTO FARM PHÓ BẢN + AUTO DODGE)
-- ------------------------------------------------------------------------
pcall(function()
    local TabMissions = Window:CreateTab("Auto Missions")
    local SecMissionSetup = TabMissions:CreateSector("Khởi Động & Cấu Hình Missions", "left")
    local SecMissionCombat = TabMissions:CreateSector("Auto Farm Phó Bản & Auto Dodge Riêng", "right")

    -- [CỘT TRÁI] KHỞI ĐỘNG & CẤU HÌNH PHÓ BẢN
    SecMissionSetup:AddToggle("🔥 Khởi Động Auto Missions (Start Auto Missions)", Config.AutoMission, function(val)
        Config.AutoMission = val
    end)

    SecMissionSetup:AddToggle("🔄 Tự Động Chơi Lại / Đi Tiếp Khi Xong (Auto Replay)", Config.AutoReplayMission, function(val)
        Config.AutoReplayMission = val
    end)

    SecMissionSetup:AddButton("🚀 Vào Ngay Phó Bản Đã Chọn (Launch Now)", function()
        launchConfiguredMission()
        notify("Auto Missions", "Đã gửi lệnh vào Phó Bản!", 3)
    end)

    SecMissionSetup:AddButton("🚪 Thoát Phó Bản Về Map Ngay (Leave Mission)", function()
        pcall(function()
            if RemoteBank.MissionDecision then
                RemoteBank.MissionDecision:Fire("Return")
            end
            if RemoteBank.MissionReturn then
                RemoteBank.MissionReturn:Fire()
            end
        end)
        notify("Auto Missions", "Đã gửi lệnh rời khỏi Phó Bản!", 3)
    end)

    SecMissionSetup:AddDropdown("Chế Độ Phó Bản (Gamemode)", {
        "Mission (Cốt Truyện & EX Stage)",
        "Challenge (Regular / Daily / Weekly)",
        "Gauntlet (Tháp Thử Thách Chamber 1-10)",
        "Invasion (Xâm Lược Thế Giới)"
    }, "Mission (Cốt Truyện & EX Stage)", false, function(val)
        local s = tostring(val or "")
        if s:find("Challenge") then
            Config.MissionGamemode = "Challenge"
        elseif s:find("Gauntlet") then
            Config.MissionGamemode = "Gauntlet"
        elseif s:find("Invasion") then
            Config.MissionGamemode = "Invasion"
        else
            Config.MissionGamemode = "Mission"
        end
    end)

    SecMissionSetup:AddDropdown("Chọn Thế Giới (World)", { "Nemu's Village", "Hollow World", "Demon Citadel" }, "Nemu's Village", false, function(val)
        Config.MissionWorld = tostring(val or "Nemu's Village")
    end)

    SecMissionSetup:AddDropdown("Chọn Màn (Act 1-3 & Act 4 EX)", {
        "Act 1",
        "Act 2",
        "Act 3",
        "Act 4 (EX Stage - 10 Waves)"
    }, "Act 1", false, function(val)
        Config.MissionAct = tonumber(tostring(val):match("%d+")) or 1
    end)

    SecMissionSetup:AddDropdown("Độ Khó (Mode)", { "Normal", "Hard" }, "Normal", false, function(val)
        Config.MissionMode = tostring(val or "Normal")
    end)

    SecMissionSetup:AddDropdown("Loại Challenge (Khi chọn Challenge)", {
        "Regular Challenge (Slot 1)",
        "Regular Challenge (Slot 2)",
        "Regular Challenge (Slot 3)",
        "Daily Challenge",
        "Weekly Challenge"
    }, "Regular Challenge (Slot 1)", false, function(val)
        local s = tostring(val or "")
        if s:find("Daily") then
            Config.ChallengeTier = "Daily"
            Config.ChallengeSlot = 1
        elseif s:find("Weekly") then
            Config.ChallengeTier = "Weekly"
            Config.ChallengeSlot = 1
        else
            Config.ChallengeTier = "Regular"
            Config.ChallengeSlot = tonumber(s:match("%d+")) or 1
        end
    end)

    SecMissionSetup:AddSlider("Tầng Gauntlet (Chamber 1 - 10)", 1, 1, 10, 0, function(val)
        Config.GauntletChamber = math.clamp(math.floor(tonumber(val) or 1), 1, 10)
    end)

    SecMissionSetup:AddDropdown("Hành Động Khi Xong Màn", {
        "Chơi Lại Màn Cũ (Retry)",
        "Đi Tiếp Màn Mới (Next)",
        "Thoát Ra Ngoài Map (Return)"
    }, "Chơi Lại Màn Cũ (Retry)", false, function(val)
        local s = tostring(val or "")
        if s:find("Next") or s:find("Tiếp") then
            Config.MissionDecisionType = "Next"
        elseif s:find("Return") or s:find("Thoát") then
            Config.MissionDecisionType = "Return"
        else
            Config.MissionDecisionType = "Retry"
        end
    end)

    -- [CỘT PHẢI] AUTO FARM QUÁI PHÓ BẢN & AUTO DODGE ĐỘC LẬP
    local MissionStateLabel = SecMissionCombat:AddLabel("Trạng Thái: Đang kiểm tra...", false)
    local MissionWaveLabel = SecMissionCombat:AddLabel("Wave: 0/0 | Quái Sống: 0", false)
    local MissionDodgeLabel = SecMissionCombat:AddLabel("Né Chiêu (Auto Dodge): Đang tắt", false)

    task.spawn(function()
        while isScriptRunning do
            pcall(function()
                if isInMission() then
                    local gm = LocalPlayer:GetAttribute("Gamemode") or Config.MissionGamemode or "Mission"
                    local title = (currentWaveInfo.title ~= "" and currentWaveInfo.title) or getCurrentMapName()
                    MissionStateLabel:Set(string.format("Trạng Thái: ĐANG TRONG MÀN [%s - %s]", tostring(gm), tostring(title)))
                    MissionWaveLabel:Set(string.format("Wave: %d/%d | Quái Còn Sống: %d/%d",
                        currentWaveInfo.wave or 0,
                        currentWaveInfo.totalWaves or 0,
                        currentWaveInfo.enemiesAlive or #getAllEnemies(),
                        currentWaveInfo.enemiesTotal or #getAllEnemies()
                    ))
                else
                    MissionStateLabel:Set("Trạng Thái: Đang ở ngoài Thế Giới / Lobby")
                    MissionWaveLabel:Set(string.format("Quái Quanh Đây: %d con", #getAllEnemies()))
                end

                if Config.IsCurrentlyDodging then
                    MissionDodgeLabel:Set("⚡ CẢNH BÁO: ĐANG NÉ VÙNG ĐỎ BOSS!")
                else
                    MissionDodgeLabel:Set(Config.AutoDodge and "Né Chiêu: Đang bật bảo vệ (An toàn)" or "Né Chiêu: Đang tắt")
                end
            end)
            task.wait(0.4)
        end
    end)

    -- Nhóm 1: Auto Farm Quái Phó Bản (Tách riêng Đánh, Tele & Tùy Chỉnh Độ Cao / Khoảng Cách)
    SecMissionCombat:AddToggle("⚔️ Tự Động Đánh Quái Phó Bản (Auto Farm Mission)", Config.AutoMissionFarm, function(val)
        Config.AutoMissionFarm = val
        if not val and not Config.AutoPosition then
            releaseCombatLock()
        end
    end)

    SecMissionCombat:AddToggle("📍 Tự Động Tele Tới Quái Phó Bản (Mission Teleport)", Config.MissionAutoTeleport, function(val)
        Config.MissionAutoTeleport = val
        if not val and not Config.AutoPosition then
            releaseCombatLock()
        end
    end)

    SecMissionCombat:AddToggle("✨ Tự Xả Kỹ Năng & Ulti Trong Phó Bản (Mission Skills)", Config.MissionAutoSkills, function(val)
        Config.MissionAutoSkills = val
    end)

    SecMissionCombat:AddDropdown("Kiểu Áp Sát Quái Phó Bản", {
        "Khóa Sau Lưng Quái (Chuẩn Nhất)",
        "Đứng Dưới Đất Đánh (Ground Melee)",
        "Khóa Trước Mặt Quái",
        "Treo Trên Đầu Quái (Hover)"
    }, "Khóa Sau Lưng Quái (Chuẩn Nhất)", false, function(val)
        local s = tostring(val or "")
        if s:find("Đất") or s:find("Ground") then
            Config.PositionMode = "GroundMelee"
        elseif s:find("Trước Mặt") then
            Config.PositionMode = "FrontMob"
        elseif s:find("Trên Đầu") or s:find("Hover") then
            Config.PositionMode = "HoverAbove"
        else
            Config.PositionMode = "BehindMob"
        end
    end)

    SecMissionCombat:AddSlider("Độ Cao Đánh Quái Phó Bản (Studs)", -5, 0, 20, 0.5, function(val)
        Config.CombatHeightOffset = tonumber(val) or 0
    end)

    SecMissionCombat:AddSlider("Khoảng Cách Đứng Đánh Phó Bản (Studs)", 0.5, 2.5, 10, 0.5, function(val)
        Config.BehindDistance = tonumber(val) or 2.5
    end)

    -- Nhóm 2: Auto Dodge (Né Chiêu Vùng Đỏ - Độc lập hoàn toàn)
    SecMissionCombat:AddToggle("🛡️ Tự Động Né Chiêu Boss / Vùng Đỏ (Auto Dodge)", Config.AutoDodge, function(val)
        Config.AutoDodge = val
        if not val then
            Config.IsCurrentlyDodging = false
        end
    end)

    SecMissionCombat:AddDropdown("Kiểu Né Chiêu (Dodge Mode)", {
        "Kết Hợp Né Ngang + Nhảy Cao (Smart Hybrid)",
        "Né Ngang Ra Ngoài Vùng Đỏ (Sidestep)",
        "Nhảy Vọt Lên Cao >16 Studs (Sky Evade)"
    }, "Kết Hợp Né Ngang + Nhảy Cao (Smart Hybrid)", false, function(val)
        local s = tostring(val or "")
        if s:find("Sidestep") or s:find("Né Ngang Ra") then
            Config.DodgeMode = "Sidestep"
        elseif s:find("Sky") or s:find("Nhảy Vọt") then
            Config.DodgeMode = "SkyEvade"
        else
            Config.DodgeMode = "SmartHybrid"
        end
    end)

    SecMissionCombat:AddSlider("Khoảng Cách Né An Toàn (Studs)", 3, 6, 15, 1, function(val)
        Config.DodgeMargin = tonumber(val) or 6
    end)
end)

-- ------------------------------------------------------------------------
-- TAB 3: NHẶT ĐỒ & QUAY THẺ (LOOT MAGNET & GACHA SUMMON)
-- ------------------------------------------------------------------------
pcall(function()
    local TabSummon = Window:CreateTab("Nhặt Đồ & Quay Thẻ")
    local SecMagnet = TabSummon:CreateSector("Hút Vật Phẩm & Tiền Tệ", "left")
    local SecSummon = TabSummon:CreateSector("Gacha & Banner", "right")

    SecMagnet:AddToggle("Hút Vật Phẩm & Tiền Tệ Vô Hạn (Infinite Magnet)", Config.AutoMagnet, function(val)
        Config.AutoMagnet = val
    end)

    SecMagnet:AddButton("⚡ Hút Ngay Lập Tức Toàn Bộ Đồ Trên Bản Đồ", function()
        pcall(forceSweepDrops)
        notify("Hút Vật Phẩm", "Đang quét và gom sạch mọi vật phẩm rơi trên bản đồ!", 3)
    end)

    SecSummon:AddToggle("Tự Động Quay Thẻ (Auto Summon)", Config.AutoSummon, function(val)
        Config.AutoSummon = val
    end)

    SecSummon:AddDropdown("Chọn Banner Quay", { "Standard Powers", "Special Powers", "Weapon Summon" }, "Standard Powers", false, function(val)
        Config.SummonBanner = tostring(val or "Standard Powers")
    end)

    SecSummon:AddDropdown("Số Lượng Quay", { "1x Lần", "10x Lần" }, "1x Lần", false, function(val)
        Config.SummonCount = (val and tostring(val):find("10x")) and 10 or 1
    end)
end)

-- ------------------------------------------------------------------------
-- TAB 4: TIỆN ÍCH & MÃ QUÀ TẶNG (MISC & CODES)
-- ------------------------------------------------------------------------
pcall(function()
    local TabMisc = Window:CreateTab("Tiện Ích")
    local SecCodes = TabMisc:CreateSector("Mã Quà Tặng & Nhận Thưởng", "left")
    local SecSystem = TabMisc:CreateSector("Hệ Thống & Tối Ưu", "right")

    SecCodes:AddButton("Nhập Tất Cả Code (Redeem All Codes)", function()
        local codes = { "EARLYACCESS", "EARLYACCESS+", "CONTENTCREATOR" }
        local redeemed = 0
        for _, c in ipairs(codes) do
            pcall(function()
                RemoteBank.RedeemCode:Fire(c)
                redeemed = redeemed + 1
            end)
            task.wait(0.3)
        end
        notify("Redeem Codes", string.format("Đã gửi %d mã quà tặng!", redeemed), 4)
    end)

    SecCodes:AddButton("Nhận Toàn Bộ Thưởng (Daily / Group / Pass / Quests)", function()
        pcall(function()
            if RemoteBank.ClaimDailyReward then RemoteBank.ClaimDailyReward:Fire() end
            if RemoteBank.ClaimGroupReward then RemoteBank.ClaimGroupReward:Fire() end
            if RemoteBank.BattlepassClaimAll then RemoteBank.BattlepassClaimAll:Fire() end
            if RemoteBank.QuestClaimReward then
                for qId = 1, 30 do
                    RemoteBank.QuestClaimReward:Fire(qId)
                end
            end
        end)
        notify("Nhận Thưởng", "Đã gửi toàn bộ yêu cầu nhận thưởng!", 3)
    end)

    SecSystem:AddToggle("Chạy Nhanh Liên Tục (Always Sprint)", Config.AlwaysSprint, function(val)
        Config.AlwaysSprint = val
        pcall(function()
            local speed = val and 28 or 16
            LocalPlayer:SetAttribute("WalkSpeed", speed)
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = speed
            end
        end)
    end)

    -- Duy trì tốc độ di chuyển nếu bật AlwaysSprint
    trackConnection(RunService.Heartbeat:Connect(function()
        if Config.AlwaysSprint and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.WalkSpeed < 26 then
                hum.WalkSpeed = 28
            end
        end
    end))

    SecSystem:AddToggle("Chống Văng Game (Anti-AFK)", Config.AntiAFK, function(val)
        Config.AntiAFK = val
    end)

    -- Anti-AFK Listener
    trackConnection(LocalPlayer.Idled:Connect(function()
        if Config.AntiAFK then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
            end)
        end
    end))

    SecSystem:AddButton("Tối Ưu Hóa FPS (Boost FPS)", function()
        pcall(function()
            for _, v in ipairs(game:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                    v.Enabled = false
                elseif v:IsA("Lighting") then
                    v.GlobalShadows = false
                end
            end
        end)
        notify("Tối Ưu FPS", "Đã giảm tải hiệu ứng hạt và bóng mờ!", 3)
    end)
end)

notify("HelmHub Sẵn Sàng", "Anime CardVerse Combat Suite đã khởi động đầy đủ!", 4)
