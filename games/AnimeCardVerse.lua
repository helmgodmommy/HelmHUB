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

local function safeRequire(inst)
    if not inst then return nil end
    local ok, res = pcall(require, inst)
    return (ok and res) and res or nil
end
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
repeat task.wait(0.1) until LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")

-- ========================================================================
-- [ANTI-AFK VĨNH VIỄN 3 LỚP (PREVENT 20-MIN IDLE KICK & AUTO-REJOIN)]
-- ========================================================================
pcall(function()
    -- Lớp 1: Vô hiệu hóa trực tiếp các Connection kiểm tra Idled của Roblox CoreGui
    if typeof(getconnections) == "function" then
        for _, conn in ipairs(getconnections(LocalPlayer.Idled)) do
            if typeof(conn.Disable) == "function" then
                conn:Disable()
            end
        end
    end
end)

-- Lớp 2: Luồng ngầm định kỳ giả lập hoạt động mỗi 2 phút (chạy kể cả khi Alt-Tab / Thu nhỏ cửa sổ)
task.spawn(function()
    local vu = game:GetService("VirtualUser")
    local vim = nil
    pcall(function()
        vim = game:GetService("VirtualInputManager")
    end)
    while isScriptRunning do
        task.wait(120) -- 2 phút một lần
        pcall(function()
            if vu then
                vu:CaptureController()
                vu:ClickButton2(Vector2.new(50, 50))
            end
        end)
        pcall(function()
            if vim then
                vim:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
                task.wait(0.05)
                vim:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
            end
        end)
    end
end)

-- Lớp 3: Fallback Listener khi sự kiện Idled phát sinh từ Engine
pcall(function()
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            local vu = game:GetService("VirtualUser")
            if vu then
                vu:CaptureController()
                vu:ClickButton2(Vector2.new(50, 50))
            end
        end)
    end)
end)


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

    -- Gỡ bỏ NoClip, LinearVelocity và BodyVelocity nếu đang bật
    if LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local lv = root:FindFirstChild("Helm_TransitLV")
            if lv then lv:Destroy() end
            local att = root:FindFirstChild("Helm_TransitAttachment")
            if att then att:Destroy() end
            local bv = root:FindFirstChild("Helm_AntiGravity")
            if bv then bv:Destroy() end
        end

        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- ========================================================================
-- [1.5] VÔ HIỆU HÓA HOÀN TOÀN CƠ CHẾ AUTO-POSITION & KÉO VỀ CHỖ CŨ NỘI BỘ CỦA GAME
-- ========================================================================
pcall(function()
    local apConfig = safeRequire(ReplicatedStorage:FindFirstChild("DataModules")
        and ReplicatedStorage.DataModules:FindFirstChild("World")
        and ReplicatedStorage.DataModules.World:FindFirstChild("AutoPositionConfig"))
    if apConfig then
        apConfig.AnchorAttr = "__DisabledAnchorAttr__"
        apConfig.MapAttr = "__DisabledMapAttr__"
        apConfig.ReturnDistance = 1e9
        apConfig.IdleBeforeReturn = 1e9
        apConfig.WaypointTimeout = 0
    end
    LocalPlayer:SetAttribute("AutoPositionAnchor", nil)
    LocalPlayer:SetAttribute("AutoPositionMap", nil)
    trackConnection(LocalPlayer:GetAttributeChangedSignal("AutoPositionAnchor"):Connect(function()
        if LocalPlayer:GetAttribute("AutoPositionAnchor") ~= nil then
            LocalPlayer:SetAttribute("AutoPositionAnchor", nil)
        end
    end))
    trackConnection(LocalPlayer:GetAttributeChangedSignal("AutoPositionMap"):Connect(function()
        if LocalPlayer:GetAttribute("AutoPositionMap") ~= nil then
            LocalPlayer:SetAttribute("AutoPositionMap", nil)
        end
    end))
end)
pcall(function()
    local sc = safeRequire(ReplicatedStorage:FindFirstChild("Utilities") and ReplicatedStorage.Utilities:FindFirstChild("SummonCutscene"))
    if sc then
        sc.IsPlaying = function() return false end
    end
end)

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
-- safeRequire defined at top of script

local RemoteBank = safeRequire(ReplicatedStorage:WaitForChild("RemoteBank", 15))
local Lib = safeRequire(ReplicatedStorage:FindFirstChild("Lib"))
local MapClient = safeRequire(ReplicatedStorage:FindFirstChild("Utilities") and ReplicatedStorage.Utilities:FindFirstChild("MapClient"))
local MapUtil = safeRequire(ReplicatedStorage:FindFirstChild("Utilities") and ReplicatedStorage.Utilities:FindFirstChild("MapUtil"))
local DataClient = safeRequire(ReplicatedStorage:FindFirstChild("Utilities") and ReplicatedStorage.Utilities:FindFirstChild("DataClient"))
local InvasionAPI = safeRequire(ReplicatedStorage:FindFirstChild("Utilities") and ReplicatedStorage.Utilities:FindFirstChild("InvasionAPI"))
local InvasionData = safeRequire(ReplicatedStorage:FindFirstChild("DataModules")
    and ReplicatedStorage.DataModules:FindFirstChild("World")
    and ReplicatedStorage.DataModules.World:FindFirstChild("InvasionData"))
local Format = safeRequire(ReplicatedStorage:FindFirstChild("Utilities") and ReplicatedStorage.Utilities:FindFirstChild("Format"))
local AttackClient = nil
local _MovementClient = nil

pcall(function()
    local ps = LocalPlayer:WaitForChild("PlayerScripts", 5)
    local cl = ps and ps:WaitForChild("ClientLoader", 5)
    local modules = cl and cl:WaitForChild("Modules", 5)
    if modules then
        AttackClient = safeRequire(modules:FindFirstChild("AttackClient"))
        ____MovementClient = safeRequire(modules:FindFirstChild("MovementClient"))
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
    -- Combat: Melee Punch (Đồng bộ nhịp chuẩn Server 350ms tránh drop đòn)
    AutoPunch = false,
    PunchDelay = 0.35,

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
    MovementStyle = "Glide", -- "Glide" (Lướt mượt chuẩn Server), "Walk" (Chạy bộ tự nhiên), "Instant" (Dịch chuyển tức thời)
    GlideSpeed = 25, -- Tốc độ tiếp cận quái (studs/s) - mặc định 25 studs/s chuẩn native sprint (an toàn không rollback)
    AutoMount = false, -- Tự động cưỡi Mount khi di chuyển xa (>12 studs) và tự xuống khi áp sát quái
    StayMountedCombat = false, -- Thử nghiệm giữ nguyên Mount khi cận chiến (bắn thẳng PunchRemote)
    CombatHeightOffset = 0, -- Độ cao tùy chỉnh so với tâm quái (-5 đến +20 studs, 0 = ngang người quái trúng 100%)
    HoverHeight = 6,
    BehindDistance = 1, -- Khoảng cách áp sát quái (1 stud cận chiến chạm hitbox 100%)
    NoClip = false,

    -- Auto Dodge (Né Chiêu Boss & Vùng Đỏ Telegraph - Độc lập hoàn toàn)
    AutoDodge = false,
    DodgeMode = "SmartHybrid", -- "SmartHybrid" (Né ngang + Nhảy cao >16 studs), "Sidestep" (Né ngang), "SkyEvade" (Bay vọt lên cao)
    DodgeMargin = 6,
    IsCurrentlyDodging = false,

    -- Auto Pickups & Magnet
    AutoMagnet = true,

    -- [ƯU TIÊN 0: SỰ KIỆN GIỚI HẠN GIỜ] Auto Invasion (Xâm Lược Thế Giới & Săn Boss Egris)
    AutoInvasion = false, -- Tự động tham gia khi có Invasion mở
    InvasionAutoFarm = true, -- Tự động đánh quái trại & phá Totem & đánh Boss Egris
    InvasionAutoTeleport = true, -- Tự động tele tới Totem & Boss Egris
    InvasionAutoSkills = true, -- Tự động dùng kỹ năng & Ulti khi đánh Invasion
    InvasionPreferredWorld = "Tự Động (Theo Server)",
    InvasionFarmUntilCap = false, -- Dừng khi đủ giới hạn ngày (Gems 10k, Rerolls 100)
    InvasionDecisionType = "WaitNext", -- "WaitNext" (về làm Bounty/Missions chờ đợt sau), "LobbyWait" (đứng chờ)

    -- [ƯU TIÊN QUESTLINES] Auto Quests (Nhiệm Vụ NPC Cốt Truyện & Mở Khóa World)
    AutoQuest = false,
    QuestPriorityOverBounty = true, -- Ưu tiên hoàn thành nhiệm vụ mở World trước khi làm Bounty
    QuestAutoTeleport = true, -- Tự động Tele áp sát quái của nhiệm vụ NPC
    QuestAutoTeleportWorld = true, -- Tự động chuyển World sang map có quái nhiệm vụ
    QuestAutoSkills = true, -- Tự xả skill khi đánh quái nhiệm vụ
    QuestAutoAccept = true, -- Tự động gửi lệnh nhận nhiệm vụ từ NPC
    QuestAutoClaim = true, -- Tự động gửi lệnh nhận thưởng và mở khóa world
    QuestlineSelected = "Tự Động (Theo Tiến Độ Cốt Truyện)",

    -- [ƯU TIÊN 1] Auto Bounty (Tự nhận, tự tele sang đúng World, săn đúng quái & tự trả nhiệm vụ 1/10 -> 10/10)
    AutoBounty = false,
    BountyAutoPunch = true,
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

    -- Auto Challenges
    AutoChallenge = false,
    ChallengeSelectedTier = "Tất Cả (Daily -> Weekly -> Regular)",

    -- Auto Gacha / Summon
    AutoSummon = false,
    SummonBanner = "Standard Powers",
    SummonCount = 1,

    -- Merchant Auto Buy (Bob E.O)
    AutoBuyMerchant = false,
    SelectedShopItems = { "Trait Rerolls", "Stat Cubes", "Stat Prisms" },

    -- Misc & UI
    AntiAFK = true,
    AlwaysSprint = false,
    CustomPlayerSpeedEnabled = false,
    PlayerWalkSpeed = 26, -- Tốc độ chạy tùy chỉnh của Player (Mặc định 26 studs/s an toàn tuyệt đối)
    FloatingMenuButton = true
}

-- ========================================================================
-- [5] TARGET ACQUISITION & MAP DETECTOR (ĐỊNH DANH QUÁI & BẢN ĐỒ CHÍNH XÁC)
-- ========================================================================
local function getCurrentMapName()
    local attrMap = LocalPlayer:GetAttribute("CurrentMap")
    if type(attrMap) == "string" and attrMap ~= "" then
        return attrMap
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
    if currentMap and currentMap ~= "" and currentMap ~= "Lobby" then
        local direct = mapRoot:FindFirstChild(currentMap)
        if direct then return direct end

        -- Khớp mờ theo tiền tố hoặc tên thế giới (ví dụ "Demon Citadel - Act 2" <-> "Demon Citadel")
        local curLower = currentMap:lower()
        for _, child in ipairs(mapRoot:GetChildren()) do
            if child.Name ~= "Lobby" and child.Name ~= "MapStorage" and child.Name ~= "Terrain" then
                local cLower = child.Name:lower()
                if curLower:find(cLower, 1, true) or cLower:find(curLower, 1, true) then
                    return child
                end
            end
        end
    end

    -- Tìm bất kỳ folder map nào chứa Enemies hoặc SpawnPart
    for _, child in ipairs(mapRoot:GetChildren()) do
        if child.Name ~= "Lobby" and child.Name ~= "MapStorage" and child.Name ~= "Terrain" then
            if child:FindFirstChild("Enemies") or child:FindFirstChild("SpawnPart", true) then
                return child
            end
        end
    end

    -- Fallback: Folder bất kỳ không phải Lobby / MapStorage
    for _, child in ipairs(mapRoot:GetChildren()) do
        if child.Name ~= "Lobby" and child.Name ~= "MapStorage" and child.Name ~= "Terrain" then
            return child
        end
    end

    return mapRoot:FindFirstChild("Lobby")
end

local currentWaveInfo = {
    wave = 0,
    totalWaves = 0,
    enemiesAlive = 0,
    enemiesTotal = 0,
    title = ""
}

-- Kiểm tra xem người chơi có đang ở trong màn chơi Sự Kiện Xâm Lược (Invasion) hay không
local function isInInvasion()
    local gmAttr = LocalPlayer:GetAttribute("Gamemode")
    if gmAttr == "Invasion" then
        return true
    end
    local title = (currentWaveInfo and currentWaveInfo.title) or ""
    if title:lower():find("invasion") or title:lower():find("egris") then
        return true
    end
    return false
end

-- Lấy toàn bộ thông tin trạng thái, đồng hồ đếm ngược và thanh tiến độ của Sự Kiện Xâm Lược (Invasion)
local function getInvasionStatus()
    local now = workspace:GetServerTimeNow()
    local activeWorld = nil
    local isActive = false
    local timeLeft = 0
    local timeRatio = 0
    local timeUntilNext = 0
    local nextRatio = 0

    if InvasionAPI and typeof(InvasionAPI.IsActive) == "function" then
        isActive = InvasionAPI.IsActive()
        activeWorld = InvasionAPI.GetActiveWorld()
        if isActive then
            timeLeft, timeRatio = InvasionAPI.GetTimeLeft()
        else
            timeUntilNext, nextRatio = InvasionAPI.GetTimeUntilNext()
        end
    else
        local w = ReplicatedStorage:GetAttribute("InvasionWorld")
        local startsAt = ReplicatedStorage:GetAttribute("InvasionStartsAt") or 0
        local endsAt = ReplicatedStorage:GetAttribute("InvasionEndsAt") or 0
        local nextAt = ReplicatedStorage:GetAttribute("InvasionNextAt") or 0

        if type(w) == "string" and w ~= "" and type(endsAt) == "number" and endsAt > now then
            isActive = true
            activeWorld = w
            local span = math.max(endsAt - startsAt, 1)
            timeLeft = math.max(endsAt - now, 0)
            timeRatio = math.clamp(timeLeft / span, 0, 1)
        elseif type(nextAt) == "number" and nextAt > now then
            isActive = false
            local span = 1800
            timeUntilNext = math.max(nextAt - now, 0)
            nextRatio = math.clamp(1 - (timeUntilNext / span), 0, 1)
        end
    end

    local gemsReceived, gemsMax = 0, 10000
    local rerollsReceived, rerollsMax = 0, 100
    if DataClient and typeof(DataClient.Get) == "function" and InvasionData and InvasionData.DailyLimits then
        pcall(function()
            local dailyData = DataClient.Get(InvasionData.DailyLimits.DataKey or "InvasionDaily")
            gemsReceived = InvasionData.DailyLimits.GetReceived(dailyData, "Gems", now)
            rerollsReceived = InvasionData.DailyLimits.GetReceived(dailyData, "Trait Rerolls", now)
            gemsMax = InvasionData.DailyLimits.GetMax("Gems") or 10000
            rerollsMax = InvasionData.DailyLimits.GetMax("Trait Rerolls") or 100
        end)
    end

    return {
        isActive = isActive,
        activeWorld = activeWorld,
        timeLeft = timeLeft,
        timeRatio = timeRatio,
        timeUntilNext = timeUntilNext,
        nextRatio = nextRatio,
        gems = { received = gemsReceived, max = gemsMax },
        rerolls = { received = rerollsReceived, max = rerollsMax }
    }
end

-- Kiểm tra chính xác người chơi có đang ở trong Phó Bản / Mission / Challenge / Gauntlet / Invasion hay không
local function isInMission()
    local gmAttr = LocalPlayer:GetAttribute("Gamemode")
    if type(gmAttr) == "string" and gmAttr ~= "" then
        return true
    end
    local mapName = getCurrentMapName()
    if mapName and (string.find(mapName, "-", 1, true) or string.find(mapName, "Act", 1, true)) then
        return true
    end
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local inMissionUI = pGui and pGui:FindFirstChild("MainHUD")
        and pGui.MainHUD:FindFirstChild("Missions")
        and pGui.MainHUD.Missions:FindFirstChild("InMissionUI")
    if inMissionUI and inMissionUI.Visible then
        return true
    end
    local details = pGui and pGui:FindFirstChild("MainHUD")
        and pGui.MainHUD:FindFirstChild("Missions")
        and pGui.MainHUD.Missions:FindFirstChild("Details")
    if details and details.Visible then
        return true
    end
    return false
end

-- Kiểm tra nghiêm ngặt một Model quái (hoặc Totem trong Invasion) có hợp lệ, còn sống và nằm trên mặt đất của Map hiện tại hay không
local function isValidCombatTarget(mob, activeMapFolder)
    if not mob or not mob.Parent then return false end
    if Players:GetPlayerFromCharacter(mob) or mob == LocalPlayer.Character then return false end

    -- Bỏ qua NPC đối thoại có ProximityPrompt (Bob E.O, Bounty, Quests NPC)
    if mob:FindFirstChildWhichIsA("ProximityPrompt", true) then return false end

    local pName = mob.Parent and mob.Parent.Name:lower() or ""
    if pName == "npcs" or pName == "npc" then return false end

    local hum = mob:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then
        return false
    end

    -- Hỗ trợ cả quái thông thường (HumanoidRootPart/Torso) và Invasion Totem (PrimaryPart/Hitbox)
    local mRoot = mob:FindFirstChild("HumanoidRootPart")
        or mob:FindFirstChild("Torso")
        or mob.PrimaryPart
        or mob:FindFirstChild("Hitbox")
        or mob:FindFirstChildWhichIsA("BasePart")
    if not mRoot then return false end

    local pos = mRoot.Position
    -- Loại bỏ quái bị rơi xuống hư không hoặc tọa độ lỗi
    if pos.Y < -45 or pos.Y > 1500 then
        return false
    end

    local inMission = isInMission()
    local inInvasion = isInInvasion()

    -- Trong màn Phó Bản (Missions, Challenges, Gauntlet) & Sự Kiện Xâm Lược (Invasion):
    -- MỌI quái sống có Humanoid trên sàn đấu đều hợp lệ 100% (không bị chặn bởi thư mục Lobby hay Assets)
    if inMission or inInvasion then
        return true
    end

    -- Ngoài thế giới thông thường: Không nhắm dummy hoặc quái chưa kích hoạt trong Lobby / MapStorage
    local mapRoot = Workspace:FindFirstChild("Map")
    local lobbyFolder = mapRoot and mapRoot:FindFirstChild("Lobby")
    if lobbyFolder and mob:IsDescendantOf(lobbyFolder) then
        return false
    end

    local playerStorage = LocalPlayer:FindFirstChild("MapStorage")
    if playerStorage and mob:IsDescendantOf(playerStorage) then
        return false
    end

    local mapFolder = activeMapFolder or getActiveMapFolder()
    if mapFolder and mapFolder.Name ~= "Lobby" then
        if mob:IsDescendantOf(mapFolder) then
            return true
        end
    end

    if mapRoot and mob:IsDescendantOf(mapRoot) then
        return true
    end

    return false
end

local function getAllEnemies()
    local enemiesList = {}
    local inMission = isInMission()
    local inInvasion = isInInvasion()
    local currentMapFolder = getActiveMapFolder()

    -- Nếu đang ở ngoài Sảnh Lobby thông thường (không trong Mission / không trong Invasion): không có quái chiến đấu
    if not inMission and not inInvasion and currentMapFolder and currentMapFolder.Name == "Lobby" then
        return enemiesList
    end

    local scanned = {}

    -- [BƯỚC 1: Quét bản đồ hiện tại]
    if currentMapFolder then
        for _, desc in ipairs(currentMapFolder:GetDescendants()) do
            if desc:IsA("Model") and not scanned[desc] and isValidCombatTarget(desc, currentMapFolder) then
                scanned[desc] = true
                table.insert(enemiesList, desc)
            end
        end
    end

    -- [BƯỚC 2: Quét toàn bộ các nhánh trong Workspace.Map]
    local mapRoot = Workspace:FindFirstChild("Map")
    if mapRoot then
        for _, child in ipairs(mapRoot:GetChildren()) do
            -- Khi ở trong Mission, quét TẤT CẢ các thư mục map (kể cả Lobby nếu màn đấu nằm trong Lobby Assets)
            if inMission or inInvasion or (child.Name ~= "Lobby" and child.Name ~= "MapStorage" and child.Name ~= "Terrain") then
                for _, desc in ipairs(child:GetDescendants()) do
                    if desc:IsA("Model") and not scanned[desc] and isValidCombatTarget(desc, child) then
                        scanned[desc] = true
                        table.insert(enemiesList, desc)
                    end
                end
            end
        end
    end

    -- [BƯỚC 3: QUÉT DỰ PHÒNG TOÀN DIỆN WORKSPACE KHI ĐANG TRONG MISSION / INVASION]
    -- Đảm bảo 100% tìm thấy quái dù quái spawn ở Workspace.Enemies, Workspace.Live, Workspace.Mobs hay bất kỳ đâu
    if (inMission or inInvasion) and #enemiesList == 0 then
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and not scanned[obj] and isValidCombatTarget(obj, nil) then
                scanned[obj] = true
                table.insert(enemiesList, obj)
            elseif (obj:IsA("Folder") or obj:IsA("Model")) and obj.Name ~= "Terrain" and obj.Name ~= "Camera" then
                for _, desc in ipairs(obj:GetDescendants()) do
                    if desc:IsA("Model") and not scanned[desc] and isValidCombatTarget(desc, nil) then
                        scanned[desc] = true
                        table.insert(enemiesList, desc)
                    end
                end
            end
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

-- ========================================================================
-- [DỮ LIỆU CỐT TRUYỆN NPC & MỞ KHÓA WORLD (QUESTLINES)]
-- ========================================================================
local QuestlinesFallback = {
    ["Nemu's Questline"] = {
        world = "Nemu's Village",
        unlocksWorld = "Hollow World",
        npcName = "Nemu",
        steps = {
            { title = "Nemu Quest #1", kills = { ["Alien Scout"] = 5 } },
            { title = "Nemu Quest #2", kills = { ["Alien Scout"] = 5, ["Alien Soldier"] = 5 } },
            { title = "Nemu Quest #3", kills = { ["Alien Soldier"] = 5, ["Alien Officer"] = 5 } },
            { title = "Nemu Quest #4", kills = { ["Alien Officer"] = 10 } },
            { title = "Nemu Quest #5", kills = { ["Captain Shinyu"] = 5 } },
            { title = "Nemu Quest #6", kills = { ["Freezer"] = 5 } },
        }
    },
    ["Kisky's Questline"] = {
        world = "Hollow World",
        unlocksWorld = "Demon Citadel",
        npcName = "Kisky",
        steps = {
            { title = "Kisky Quest #1", kills = { ["Grants"] = 7 } },
            { title = "Kisky Quest #2", kills = { ["Grants"] = 7, ["Yummy"] = 7 } },
            { title = "Kisky Quest #3", kills = { ["Yummy"] = 7, ["Arruru"] = 5 } },
            { title = "Kisky Quest #4", kills = { ["Arruru"] = 12 } },
            { title = "Kisky Quest #5", kills = { ["Grimmjay"] = 5 } },
            { title = "Kisky Quest #6", kills = { ["Aizo"] = 5 } },
        }
    },
    ["Sang Woo's Questline"] = {
        world = "Demon Citadel",
        unlocksWorld = nil,
        npcName = "Sang Woo",
        steps = {
            { title = "Sang Woo Quest #1", kills = { ["Goblin"] = 15 } },
            { title = "Sang Woo Quest #2", kills = { ["Goblin"] = 5, ["Goblin Shaman"] = 15 } },
            { title = "Sang Woo Quest #3", kills = { ["Goblin Shaman"] = 10, ["High Grunt"] = 10 } },
            { title = "Sang Woo Quest #4", kills = { ["High Grunt"] = 20 } },
            { title = "Sang Woo Quest #5", kills = { ["Ferrite"] = 10 } },
            { title = "Sang Woo Quest #6", kills = { ["Belu"] = 10 } },
        }
    }
}

local function getQuestlineStatus()
    local result = {
        state = "None",
        questlineId = "Nemu's Questline",
        questlineName = "Nemu's Questline",
        world = "Nemu's Village",
        unlocksWorld = "Hollow World",
        npcName = "Nemu",
        stepIndex = 1,
        totalSteps = 6,
        stepTitle = "Nemu Quest #1",
        targetEnemy = "Alien Scout",
        progress = 0,
        target = 5,
        allCompleted = false,
        completedQuestlines = {},
        activeStepsSummary = ""
    }

    local completedMap = {}
    local questlinesProgress = {}
    if DataClient and typeof(DataClient.Get) == "function" then
        local ok1, comp = pcall(DataClient.Get, "CompletedQuestlines")
        if ok1 and type(comp) == "table" then
            completedMap = comp
        end
        local ok2, qp = pcall(DataClient.Get, "QuestProgress")
        if ok2 and type(qp) == "table" and type(qp.questlines) == "table" then
            questlinesProgress = qp.questlines
        end
    end
    result.completedQuestlines = completedMap

    local targetQuestlineId = nil
    if Config.QuestlineSelected and Config.QuestlineSelected ~= "Tự Động (Theo Tiến Độ Cốt Truyện)" then
        if Config.QuestlineSelected:find("Nemu") then
            targetQuestlineId = "Nemu's Questline"
        elseif Config.QuestlineSelected:find("Kisky") then
            targetQuestlineId = "Kisky's Questline"
        elseif Config.QuestlineSelected:find("Sang Woo") then
            targetQuestlineId = "Sang Woo's Questline"
        end
    end

    if not targetQuestlineId then
        if not completedMap["Nemu's Questline"] then
            targetQuestlineId = "Nemu's Questline"
        elseif not completedMap["Kisky's Questline"] then
            targetQuestlineId = "Kisky's Questline"
        elseif not completedMap["Sang Woo's Questline"] then
            targetQuestlineId = "Sang Woo's Questline"
        else
            result.allCompleted = true
            result.state = "AllCompleted"
            return result
        end
    else
        if completedMap[targetQuestlineId] then
            result.allCompleted = true
            result.state = "AllCompleted"
            result.questlineId = targetQuestlineId
            return result
        end
    end

    local qConfig = QuestlinesFallback[targetQuestlineId]
    if not qConfig then
        return result
    end

    result.questlineId = targetQuestlineId
    result.questlineName = targetQuestlineId
    result.world = qConfig.world
    result.unlocksWorld = qConfig.unlocksWorld
    result.npcName = qConfig.npcName
    result.totalSteps = #qConfig.steps

    local pData = questlinesProgress[targetQuestlineId]
    if not pData then
        result.state = "NeedAccept"
        result.stepIndex = 1
        local step1 = qConfig.steps[1]
        if step1 then
            result.stepTitle = step1.title
            for en, count in pairs(step1.kills) do
                result.targetEnemy = en
                result.target = count
                result.progress = 0
                break
            end
        end
        return result
    end

    local stepIdx = tonumber(pData.questIndex) or 1
    result.stepIndex = stepIdx

    if stepIdx > #qConfig.steps then
        result.state = "ReadyToClaim"
        return result
    end

    local currentStepDef = qConfig.steps[stepIdx]
    if not currentStepDef then
        result.state = "AllCompleted"
        return result
    end

    result.stepTitle = currentStepDef.title
    local stepComplete = true
    local firstUnfinishedEnemy = nil
    local firstUnfinishedProg = 0
    local firstUnfinishedReq = 1
    local summaryList = {}
    local playerKills = (type(pData.kills) == "table") and pData.kills or {}

    for en, reqCount in pairs(currentStepDef.kills) do
        local cur = tonumber(playerKills[en]) or 0
        table.insert(summaryList, string.format("%s (%d/%d)", en, cur, reqCount))
        if cur < reqCount then
            stepComplete = false
            if not firstUnfinishedEnemy then
                firstUnfinishedEnemy = en
                firstUnfinishedProg = cur
                firstUnfinishedReq = reqCount
            end
        end
    end

    result.activeStepsSummary = table.concat(summaryList, ", ")

    if stepComplete then
        result.state = "ReadyToClaim"
        result.progress = firstUnfinishedReq
        result.target = firstUnfinishedReq
    else
        result.state = "InProgress"
        result.targetEnemy = firstUnfinishedEnemy
        result.progress = firstUnfinishedProg
        result.target = firstUnfinishedReq
    end

    return result
end

local function isQuestOverrideActive()
    if not Config.AutoQuest then
        return false, nil
    end
    if isInMission() or isInInvasion() then
        return false, nil
    end
    local status = getQuestlineStatus()
    if not status or status.allCompleted or status.state == "AllCompleted" or status.state == "None" then
        return false, status
    end
    return true, status
end

local function _getQuestNPCModel(npcName, questlineId)
    local activeMap = getActiveMapFolder()
    local npcs = activeMap and activeMap:FindFirstChild("NPCs")
    if npcs then
        for _, n in ipairs(npcs:GetChildren()) do
            if n:IsA("Model") then
                if (npcName and n.Name:lower() == npcName:lower()) or (questlineId and n:GetAttribute("Questline") == questlineId) then
                    return n
                end
            end
        end
    end
    local mapRoot = Workspace:FindFirstChild("Map")
    if mapRoot then
        for _, child in ipairs(mapRoot:GetChildren()) do
            local subNPCs = child:FindFirstChild("NPCs")
            if subNPCs then
                for _, n in ipairs(subNPCs:GetChildren()) do
                    if n:IsA("Model") then
                        if (npcName and n.Name:lower() == npcName:lower()) or (questlineId and n:GetAttribute("Questline") == questlineId) then
                            return n
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function claimAllQuests()
    pcall(function()
        if not DataClient or typeof(DataClient.Get) ~= "function" then return end
        local qp = DataClient.Get("QuestProgress")
        if not qp then return end
        if qp.daily and type(qp.daily.progress) == "table" and type(qp.daily.claimed) == "table" then
            for idxStr, _ in pairs(qp.daily.progress) do
                if not qp.daily.claimed[idxStr] then
                    RemoteBank.QuestClaimReward:Fire({ category = "Daily", questIndex = tonumber(idxStr) or idxStr })
                end
            end
        end
        if qp.weekly and type(qp.weekly.progress) == "table" and type(qp.weekly.claimed) == "table" then
            for idxStr, _ in pairs(qp.weekly.progress) do
                if not qp.weekly.claimed[idxStr] then
                    RemoteBank.QuestClaimReward:Fire({ category = "Weekly", questIndex = tonumber(idxStr) or idxStr })
                end
            end
        end
        local qStatus = getQuestlineStatus()
        if qStatus and qStatus.state == "ReadyToClaim" and qStatus.questlineId then
            RemoteBank.QuestClaimReward:Fire(qStatus.questlineId)
        end
    end)
end

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

-- Kiểm tra xem [ƯU TIÊN: AUTO BOUNTY] có đang kích hoạt và còn nhiệm vụ chưa xong trong ngày không
local function isBountyOverrideActive()
    if not Config.AutoBounty then
        return false, nil
    end
    -- Khi người chơi đang trong Phó Bản (Mission), ưu tiên hoàn thành màn chơi trước, Bounty không ngắt quãng trận đấu
    if isInMission() then
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

-- ========================================================================
-- [6B] CHALLENGES & MILESTONES ENGINE
-- ========================================================================
local ChallengeDataModule
pcall(function()
    ChallengeDataModule = require(ReplicatedStorage.DataModules.Progression.ChallengeData)
end)

local function isChallengeClaimed(tier, slot)
    local claimed = false
    pcall(function()
        if DataClient and typeof(DataClient.Get) == "function" then
            local prog = DataClient.Get("ChallengeProgress")
            if type(prog) == "table" and type(prog[tier]) == "table" then
                local tProg = prog[tier]
                local period = ChallengeDataModule and ChallengeDataModule.GetPeriod(tier, os.time()) or 0
                if tProg.period == period and type(tProg.claimed) == "table" then
                    claimed = (tProg.claimed[tostring(slot)] == true)
                end
            end
        end
    end)
    return claimed
end

local function getChallengeInfo()
    if not ChallengeDataModule then
        pcall(function()
            ChallengeDataModule = require(ReplicatedStorage.DataModules.Progression.ChallengeData)
        end)
    end
    local now = os.time()
    local dailyRem = 0
    local weeklyRem = 0
    local regularRem = 0
    if ChallengeDataModule and typeof(ChallengeDataModule.GetTimeRemaining) == "function" then
        pcall(function()
            dailyRem = ChallengeDataModule.GetTimeRemaining("Daily", now) or 0
            weeklyRem = ChallengeDataModule.GetTimeRemaining("Weekly", now) or 0
            regularRem = ChallengeDataModule.GetTimeRemaining("Regular", now) or 0
        end)
    end
    return {
        dailyTime = dailyRem,
        weeklyTime = weeklyRem,
        regularTime = regularRem,
        dailyClaimed = isChallengeClaimed("Daily", 1),
        weeklyClaimed = isChallengeClaimed("Weekly", 1)
    }
end

local function launchConfiguredChallenge()
    local targetTier = "Daily"
    local targetSlot = 1
    local sel = tostring(Config.ChallengeSelectedTier or "Tất Cả (Daily -> Weekly -> Regular)")
    if sel:find("Weekly") then
        targetTier = "Weekly"
        targetSlot = 1
    elseif sel:find("Regular") then
        targetTier = "Regular"
        targetSlot = tonumber(sel:match("%d+")) or 1
    elseif sel:find("Tất Cả") or sel:find("All") then
        local dClaimed = isChallengeClaimed("Daily", 1)
        local wClaimed = isChallengeClaimed("Weekly", 1)
        if not dClaimed then
            targetTier = "Daily"
            targetSlot = 1
        elseif not wClaimed then
            targetTier = "Weekly"
            targetSlot = 1
        else
            targetTier = "Regular"
            targetSlot = 1
        end
    else
        targetTier = "Daily"
        targetSlot = 1
    end

    pcall(function()
        if RemoteBank and RemoteBank.MissionLaunch then
            RemoteBank.MissionLaunch:Fire({
                gamemode = "Challenge",
                tier = targetTier,
                index = targetSlot
            })
            notify("Auto Challenge", string.format("Đang khởi động %s Challenge (Slot %d)!", targetTier, targetSlot), 3)
        end
    end)
end

local function claimAllLevelMilestones()
    pcall(function()
        if RemoteBank and RemoteBank.ClaimLevelMilestone then
            for lvl = 5, 50, 5 do
                RemoteBank.ClaimLevelMilestone:Fire(lvl)
            end
        end
    end)
end

local function claimAllAchievements()
    pcall(function()
        local cats = { "General", "Combat", "Progression", "Collection", "Social" }
        for _, cat in ipairs(cats) do
            if RemoteBank and RemoteBank.AchievementClaimMilestone then
                RemoteBank.AchievementClaimMilestone:Fire(cat)
            end
            if RemoteBank and RemoteBank.AchievementClaimTask then
                for taskId = 1, 30 do
                    RemoteBank.AchievementClaimTask:Fire(cat, taskId)
                end
            end
        end
    end)
end

local function getActivePriorityMode()
    if isInInvasion() then
        return "InvasionCombat", nil
    end
    local invStatus = getInvasionStatus()
    if Config.AutoInvasion and invStatus.isActive then
        return "Invasion", invStatus
    end
    if isInMission() and Config.AutoMissionFarm then
        return "Mission", nil
    end
    if Config.AutoChallenge and not isInMission() and not isInInvasion() then
        return "Challenge", nil
    end
    local questActive, questStatus = isQuestOverrideActive()
    local bountyActive, bountyStatus = isBountyOverrideActive()
    if Config.QuestPriorityOverBounty and questActive then
        return "Quest", questStatus
    end
    if bountyActive then
        return "Bounty", bountyStatus
    end
    if questActive then
        return "Quest", questStatus
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

local function isMobNameMatch(candidateName, targetName)
    if not candidateName or not targetName then return false end
    local c = tostring(candidateName):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local t = tostring(targetName):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if c == t then return true end

    -- Loại bỏ các đuôi clone, số ID, ngoặc đơn/ngoặc vuông (ví dụ Goblin_1, Goblin#2, Goblin (3), Goblin [Lvl 50])
    -- Chống nhầm lẫn giữa Goblin và Goblin Shaman
    local cClean = c:gsub("%b()", ""):gsub("%b[]", ""):gsub("%b{}", "")
    cClean = cClean:gsub("[#_%-]%d+$", ""):gsub("%s+%d+$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cClean == t then return true end

    return false
end

local function isMobSelectedByFilter(mobName)
    if not mobName then return false end
    local specific = getSpecificSelectedMobs()
    if #specific == 0 then
        return true
    end
    for _, sel in ipairs(specific) do
        if isMobNameMatch(mobName, sel) then
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

    local inInvasion = isInInvasion()
    local inMission = isInMission()
    local currentMapFolder = getActiveMapFolder()
    if not inMission and not inInvasion and (not currentMapFolder or currentMapFolder.Name == "Lobby") then
        return nil
    end

    local enemies = getAllEnemies()
    if #enemies == 0 then return nil end

    local questActive, questStatus = isQuestOverrideActive()
    local bountyActive, bountyStatus = isBountyOverrideActive()
    local effectiveRange = (inInvasion or inMission or bountyActive or questActive)
        and math.max(Config.ScanRange or 2500, 6000)
        or (Config.ScanRange or 2500)

    local bestTarget = nil
    local bestScore = math.huge

    for _, mob in ipairs(enemies) do
        if isValidCombatTarget(mob, currentMapFolder) then
            local mRoot = mob:FindFirstChild("HumanoidRootPart")
                or mob:FindFirstChild("Torso")
                or mob.PrimaryPart
                or mob:FindFirstChild("Hitbox")
                or mob:FindFirstChildWhichIsA("BasePart")
            local mHum = mob:FindFirstChildOfClass("Humanoid")
            if mRoot and mHum then
                local shouldSkip = false

                -- HỆ THỐNG ƯU TIÊN 5 TẦNG (PHÂN BIỆT CHÍNH XÁC QUÁI - KHÔNG NHẦM GOBLIN VÀ GOBLIN SHAMAN):
                -- [TẦNG 0 - SỰ KIỆN INVASION]: Khóa Totem, Boss Egris và quái trại
                if inInvasion and Config.InvasionAutoFarm then
                    -- Quét mọi mục tiêu trong Invasion (Totem / Boss Egris / Camp Mobs)
                -- [TẦNG 1 - PHÓ BẢN MISSIONS]: Đang ở trong Phó Bản
                elseif inMission and (Config.AutoMission or Config.AutoMissionFarm) then
                    -- Nhắm toàn bộ quái sống trong Wave của màn chơi để vượt ải
                -- [TẦNG 2A - NGOÀI WORLD: AUTO QUESTS (Ưu Tiên Mở World)]:
                elseif (not inMission) and (not inInvasion) and questActive and questStatus and questStatus.targetEnemy and (Config.QuestPriorityOverBounty or not bountyActive) then
                    if not isMobNameMatch(mob.Name, questStatus.targetEnemy) then
                        shouldSkip = true
                    end
                -- [TẦNG 2B - NGOÀI WORLD: AUTO BOUNTY]:
                elseif (not inMission) and (not inInvasion) and bountyActive and bountyStatus and bountyStatus.enemy and bountyStatus.enemy ~= "" then
                    if not isMobNameMatch(mob.Name, bountyStatus.enemy) then
                        shouldSkip = true
                    end
                -- [TẦNG 2C - NGOÀI WORLD: AUTO QUESTS (Khi xếp sau Bounty)]:
                elseif (not inMission) and (not inInvasion) and questActive and questStatus and questStatus.targetEnemy then
                    if not isMobNameMatch(mob.Name, questStatus.targetEnemy) then
                        shouldSkip = true
                    end
                -- [TẦNG 3 - NGOÀI WORLD]: Chiến Đấu Thường
                else
                    if not isMobSelectedByFilter(mob.Name) then
                        shouldSkip = true
                    end
                end

                if not shouldSkip then
                    local dist = (mRoot.Position - root.Position).Magnitude
                    if dist <= effectiveRange then
                        local score = dist
                        if inInvasion then
                            local mobNameLower = mob.Name:lower()
                            local isBossEgris = mobNameLower:find("egris") or (mHum.MaxHealth > 50000)
                            local isTotem = mobNameLower:find("totem") or (mob:GetAttribute("EnemyType") == "Totem")
                            if isBossEgris then
                                score = dist - 200000 -- Tuyệt đối ưu tiên Boss Egris
                            elseif isTotem then
                                score = dist - 100000 -- Ưu tiên phá Totem trước quái trại
                            end
                        elseif Config.TargetMode == "LowestHP" then
                            -- Ưu tiên dứt điểm quái máu thấp trong cụm nhưng không bao giờ chạy xa bỏ quái trước mặt
                            score = dist + (mHum.Health / math.max(1, mHum.MaxHealth)) * 40
                        elseif Config.TargetMode == "BossFirst" then
                            local isBoss = mHum.MaxHealth > 5000 or mob.Name:lower():find("boss")
                            score = isBoss and (dist - 100000) or dist
                        else
                            -- "Nearest" (Mặc định): Luôn luôn nhắm quái gần vị trí nhân vật nhất
                            score = dist
                        end

                        if score < bestScore then
                            bestScore = score
                            bestTarget = mob
                        end
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
local currentLockedTarget = nil
local currentApproachDir = nil

local function isPlayerMounted()
    return LocalPlayer:GetAttribute("Mount") ~= nil or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Mount") ~= nil)
end

local lastMountToggleTime = 0
local function setPlayerMounted(shouldMount)
    local now = tick()
    if now - lastMountToggleTime < 0.6 then return end

    local currentlyMounted = isPlayerMounted()
    if shouldMount and not currentlyMounted then
        lastMountToggleTime = now
        pcall(function()
            if RemoteBank and RemoteBank.MountToggle then
                RemoteBank.MountToggle:Fire()
            end
        end)
    elseif not shouldMount and currentlyMounted then
        lastMountToggleTime = now
        pcall(function()
            if RemoteBank and RemoteBank.MountToggle then
                RemoteBank.MountToggle:Fire()
            end
        end)
    end
end

local function restoreCharacterCollision()
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                local name = part.Name
                if name:find("Leg") or name:find("Foot") or name:find("Torso") or name == "HumanoidRootPart" or name == "Head" then
                    part.CanCollide = true
                end
            end
        end
    end
end

local function releaseCombatLock()
    isActivelyLockingTarget = false
    currentLockedTarget = nil
    currentApproachDir = nil
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local lv = root:FindFirstChild("Helm_TransitLV")
        if lv then lv:Destroy() end
        local att = root:FindFirstChild("Helm_TransitAttachment")
        if att then att:Destroy() end
        local bv = root:FindFirstChild("Helm_AntiGravity")
        if bv then bv:Destroy() end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:MoveTo(root and root.Position or Vector3.zero)
    end
    if not Config.NoClip then
        restoreCharacterCollision()
    end
end

trackConnection(RunService.Heartbeat:Connect(function(dt)
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

    local inInvasion = isInInvasion()
    local inMission = isInMission()
    local questActive, questStatus = isQuestOverrideActive()
    local bountyActive, bountyStatus = isBountyOverrideActive()
    local shouldPosition = false

    -- [ƯU TIÊN TUYỆT ĐỐI]: Nếu người chơi bật AutoPosition ở Tab Chiến Đấu -> Luôn áp sát quái không bị chặn!
    if Config.AutoPosition then
        shouldPosition = true
    elseif inInvasion and Config.InvasionAutoFarm and Config.InvasionAutoTeleport then
        shouldPosition = true
    elseif inMission and (Config.AutoMission or Config.AutoMissionFarm) and Config.MissionAutoTeleport then
        shouldPosition = true
    elseif Config.QuestPriorityOverBounty and questActive and Config.QuestAutoTeleport then
        local onQuestWorld = (not questStatus.world or getCurrentMapName() == questStatus.world)
        shouldPosition = onQuestWorld
    elseif bountyActive and Config.BountyAutoTeleport then
        local onBountyWorld = (not bountyStatus.world or getCurrentMapName() == bountyStatus.world)
        shouldPosition = onBountyWorld
    elseif questActive and Config.QuestAutoTeleport then
        local onQuestWorld = (not questStatus.world or getCurrentMapName() == questStatus.world)
        shouldPosition = onQuestWorld
    end

    -- 2. Khi không bật giữ vị trí: giải phóng khóa mục tiêu và để người chơi di chuyển hoàn toàn tự nhiên
    if not shouldPosition then
        if isActivelyLockingTarget then
            releaseCombatLock()
        end
        local dodgePos = computeDodgeEscape(root.Position, root.Position.Y)
        if dodgePos then
            local safeDodgeY = math.max(dodgePos.Y, getSafeStandingY(dodgePos, root.Position.Y, activeMap, 0))
            local finalDodge = Vector3.new(dodgePos.X, safeDodgeY, dodgePos.Z)
            root.CFrame = CFrame.new(finalDodge, finalDodge + root.CFrame.LookVector)
            root.AssemblyLinearVelocity = Vector3.zero
        end
        return
    end

    -- 3. Kiểm tra mục tiêu trên TỪNG FRAME: nếu quái vừa chết hoặc không khớp ưu tiên hiện tại thì quét lại ngay
    local target = Config.TargetCurrent
    local needRescan = not isValidCombatTarget(target, activeMap)
    if not needRescan and not (inInvasion and Config.InvasionAutoFarm) and not (inMission and Config.AutoMissionFarm) then
        if questActive and questStatus and questStatus.targetEnemy and (Config.QuestPriorityOverBounty or not bountyActive) then
            if not isMobNameMatch(target.Name, questStatus.targetEnemy) then
                needRescan = true
            end
        elseif bountyActive and bountyStatus and bountyStatus.enemy and bountyStatus.enemy ~= "" then
            if not isMobNameMatch(target.Name, bountyStatus.enemy) then
                needRescan = true
            end
        elseif questActive and questStatus and questStatus.targetEnemy then
            if not isMobNameMatch(target.Name, questStatus.targetEnemy) then
                needRescan = true
            end
        else
            if not isMobSelectedByFilter(target.Name) then
                needRescan = true
            end
        end
    end
    if needRescan then
        target = getBestTarget()
        Config.TargetCurrent = target
    end

    if not target or not isValidCombatTarget(target, activeMap) then
        if isActivelyLockingTarget then
            releaseCombatLock()
        end
        local dodgePos = computeDodgeEscape(root.Position, root.Position.Y)
        if dodgePos then
            local safeDodgeY = math.max(dodgePos.Y, getSafeStandingY(dodgePos, root.Position.Y, activeMap, 0))
            local finalDodge = Vector3.new(dodgePos.X, safeDodgeY, dodgePos.Z)
            root.CFrame = CFrame.new(finalDodge, finalDodge + root.CFrame.LookVector)
            root.AssemblyLinearVelocity = Vector3.zero
        end
        return
    end

    local tRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")
    if not tRoot then
        isActivelyLockingTarget = false
        currentLockedTarget = nil
        currentApproachDir = nil
        return
    end

    isActivelyLockingTarget = true

    local mobPos = tRoot.Position

    -- Khóa góc tiếp cận cố định theo quái hiện tại (Chống triệt để lỗi quái xoay mặt làm lật 180 độ gây quay vòng đánh vào không khí)
    if currentLockedTarget ~= target or not currentApproachDir then
        currentLockedTarget = target
        local mobLook = Vector3.new(tRoot.CFrame.LookVector.X, 0, tRoot.CFrame.LookVector.Z)
        if mobLook.Magnitude < 0.05 then
            mobLook = Vector3.new(0, 0, -1)
        else
            mobLook = mobLook.Unit
        end

        if Config.PositionMode == "BehindMob" then
            currentApproachDir = -mobLook
        elseif Config.PositionMode == "FrontMob" then
            currentApproachDir = mobLook
        elseif Config.PositionMode == "HoverAbove" then
            currentApproachDir = -mobLook
        else
            -- GroundMelee: Tính hướng từ quái tới vị trí hiện tại của nhân vật
            local diff = Vector3.new(root.Position.X - mobPos.X, 0, root.Position.Z - mobPos.Z)
            currentApproachDir = (diff.Magnitude > 0.1) and diff.Unit or (-mobLook)
        end
    end

    local distOffset = math.max(1, math.floor(tonumber(Config.BehindDistance) or 1))
    local targetCFrame = nil

    -- Độ cao đứng đánh chuẩn: Dựa trực tiếp vào độ cao sàn của quái mobPos.Y
    -- Không bắn raycast từ trên cao xuống để loại bỏ 100% tình trạng bắn trúng tán lá cây dừa hoặc nóc nhà gây bay lên trời
    local targetY = mobPos.Y + (Config.CombatHeightOffset or 0)
    if Config.PositionMode == "HoverAbove" then
        local hoverH = Config.CombatHeightOffset
        if hoverH == 0 then hoverH = Config.HoverHeight or 6 end
        targetY = mobPos.Y + math.max(3, hoverH)
        local hoverPos = Vector3.new(mobPos.X, targetY, mobPos.Z) + currentApproachDir * math.max(distOffset, 2.0)
        local lookAt = Vector3.new(mobPos.X, targetY, mobPos.Z)
        if (lookAt - hoverPos).Magnitude < 0.1 then
            lookAt = hoverPos - currentApproachDir
        end
        targetCFrame = CFrame.new(hoverPos, lookAt)
    else
        -- GroundMelee, BehindMob, FrontMob
        local standXZ = Vector3.new(mobPos.X, 0, mobPos.Z) + currentApproachDir * distOffset
        local standPos = Vector3.new(standXZ.X, targetY, standXZ.Z)
        local lookAt = Vector3.new(mobPos.X, targetY, mobPos.Z)
        if (lookAt - standPos).Magnitude < 0.1 then
            lookAt = standPos - currentApproachDir
        end
        targetCFrame = CFrame.new(standPos, lookAt)
    end

    if targetCFrame then
        -- Kiểm tra xem vị trí chuẩn bị đứng có nằm trong vùng đỏ Telegraph của Boss/Quái không
        local dodgePos = computeDodgeEscape(targetCFrame.Position, mobPos.Y)
        if dodgePos then
            local safeDodgeY = math.max(dodgePos.Y, getSafeStandingY(dodgePos, mobPos.Y, activeMap, 0))
            local finalDodge = Vector3.new(dodgePos.X, safeDodgeY, dodgePos.Z)
            local lookAt = Vector3.new(mobPos.X, safeDodgeY, mobPos.Z)
            if (lookAt - finalDodge).Magnitude < 0.1 then
                lookAt = finalDodge + Vector3.new(0, 0, -1)
            end
            targetCFrame = CFrame.new(finalDodge, lookAt)
        end

        local destPos = targetCFrame.Position
        local currentPos = root.Position
        local delta = destPos - currentPos
        local dist = delta.Magnitude

        local transitSpeed = math.clamp(tonumber(Config.GlideSpeed) or 25, 10, 80)
        local hum = char:FindFirstChildOfClass("Humanoid")

        if dist > 1.8 then
            -- Tự động cưỡi Mount khi di chuyển cự ly xa (>12 studs) để tăng tốc độ di chuyển
            if Config.AutoMount and dist > 12 then
                setPlayerMounted(true)
            end

            -- [GIAI ĐOẠN 1: TIẾP CẬN MỤC TIÊU - VƯỢT VẬT CẢN (CÂY, ĐÁ, HÀNG RÀO) 100%]
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end

            if Config.MovementStyle == "Instant" then
                -- Kiểu 1: Dịch chuyển tức thời
                root.CFrame = targetCFrame
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            elseif Config.MovementStyle == "Walk" then
                -- Kiểu 2: Chạy bộ tự nhiên (Humanoid Walk chuẩn physics, không CFrame snap)
                if hum and hum.Health > 0 then
                    hum.WalkSpeed = transitSpeed
                    hum:MoveTo(destPos)
                end
                local lookTarget = Vector3.new(mobPos.X, root.Position.Y, mobPos.Z)
                if (lookTarget - root.Position).Magnitude > 0.1 then
                    root.CFrame = CFrame.new(root.Position, lookTarget)
                end
            else
                -- Kiểu 3: Lướt mượt chuẩn Server (Glide - Mặc định: mượt mà, không giật lag, không bay bổng)
                local dtClamped = math.clamp(dt, 0.001, 0.05)
                local moveStep = math.min(dist, transitSpeed * dtClamped)
                local moveDir = (dist > 0.001) and (delta / dist) or Vector3.new(0, 0, -1)
                local nextPos = currentPos + moveDir * moveStep

                local lookTarget = Vector3.new(mobPos.X, nextPos.Y, mobPos.Z)
                if (lookTarget - nextPos).Magnitude > 0.1 then
                    root.CFrame = CFrame.new(nextPos, lookTarget)
                else
                    root.CFrame = CFrame.new(nextPos)
                end
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero

                if hum and hum.Health > 0 then
                    hum:MoveTo(destPos)
                end
            end
        else
            -- Khi đã áp sát quái: Tự động xuống Mount để sẵn sàng tung đòn đánh cận chiến
            if Config.AutoMount and not Config.StayMountedCombat and isPlayerMounted() then
                setPlayerMounted(false)
            end

            -- [GIAI ĐOẠN 2: KHÓA CHẶT CỰ LY ĐÁNH CẬN CHIẾN (<= 1.8 STUDS)]
            root.CFrame = targetCFrame
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            if hum and hum.Health > 0 then
                hum:MoveTo(root.Position)
            end
        end
    end
end))

-- NoClip Thread: Giữ va chạm chân để nhân vật không rơi xuyên sàn làm server kích hoạt anti-void
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
-- [8.0] ĐO LƯỜNG SỐ ĐÒN TRÚNG THỰC TẾ TỪ SERVER (HIT METRICS VIA HITFXREMOTE)
local combatMetrics = {
    hitsRecorded = 0,
    hitsLastSecond = 0,
    hitTimestamps = {}
}

if RemoteBank and RemoteBank.HitFXRemote then
    pcall(function()
        RemoteBank.HitFXRemote.OnClientEvent:Connect(function(attacker, fxType, hitList)
            local myUserId = LocalPlayer and LocalPlayer.UserId
            local isMe = (attacker == LocalPlayer)
            if not isMe and typeof(attacker) == "Instance" then
                isMe = (attacker:GetAttribute("OwnerUserId") == myUserId)
            end
            if isMe and type(hitList) == "table" and #hitList > 0 then
                local now = tick()
                table.insert(combatMetrics.hitTimestamps, now)
                combatMetrics.hitsRecorded = combatMetrics.hitsRecorded + #hitList
            end
        end)
    end)
end

-- Tính toán đòn trúng/giây theo cửa sổ trượt 1 giây
task.spawn(function()
    while isScriptRunning do
        local now = tick()
        local cutoff = now - 1.0
        local valid = {}
        for _, t in ipairs(combatMetrics.hitTimestamps) do
            if t >= cutoff then
                table.insert(valid, t)
            end
        end
        combatMetrics.hitTimestamps = valid
        combatMetrics.hitsLastSecond = #valid
        task.wait(0.25)
    end
end)

-- Tải module AttackClient gốc của game để kích hoạt animation vũ khí/vung kiếm chân thực
local AttackClientModule = nil
pcall(function()
    local ps = LocalPlayer:FindFirstChildOfClass("PlayerScripts") or LocalPlayer:FindFirstChild("PlayerScripts")
    local cl = ps and ps:FindFirstChild("ClientLoader")
    local mods = cl and cl:FindFirstChild("Modules")
    if mods and mods:FindFirstChild("AttackClient") then
        AttackClientModule = require(mods.AttackClient)
    end
end)

-- 1. Auto Melee Punch Loop (Đồng bộ nhịp chuẩn game và server, không xung đột packet)
task.spawn(function()
    local lastTargetScan = 0
    local isMeleeActiveInClient = false
    while isScriptRunning do
        local delaySec = Config.PunchDelay or 0.35
        local inInvasion = isInInvasion()
        local inMission = isInMission()
        local bountyActive = isBountyOverrideActive()
        local inInvasionAttack = inInvasion and Config.InvasionAutoFarm
        local inMissionAttack = inMission and (Config.AutoMission or Config.AutoMissionFarm)
        local canPunch = Config.AutoPunch or inInvasionAttack or inMissionAttack or (bountyActive and Config.BountyAutoPunch)

        if canPunch then
            local now = tick()
            if not isValidCombatTarget(Config.TargetCurrent) or (now - lastTargetScan >= 0.15) then
                Config.TargetCurrent = getBestTarget()
                lastTargetScan = now
            end

            local target = Config.TargetCurrent
            if isValidCombatTarget(target) then
                if isPlayerMounted() then
                    -- Khi đang trên thú cưỡi: Bắn thẳng PunchRemote để bypass bộ lọc chặn của AttackClient
                    pcall(function()
                        RemoteBank.PunchRemote:Fire()
                    end)
                elseif AttackClientModule and typeof(AttackClientModule.StartMelee) == "function" then
                    if not isMeleeActiveInClient then
                        isMeleeActiveInClient = true
                        pcall(function() AttackClientModule.StartMelee() end)
                    end
                else
                    pcall(function()
                        RemoteBank.PunchRemote:Fire()
                    end)
                end
            else
                if AttackClientModule and typeof(AttackClientModule.StopMelee) == "function" and isMeleeActiveInClient then
                    isMeleeActiveInClient = false
                    pcall(function() AttackClientModule.StopMelee() end)
                end
            end
        else
            if AttackClientModule and typeof(AttackClientModule.StopMelee) == "function" and isMeleeActiveInClient then
                isMeleeActiveInClient = false
                pcall(function() AttackClientModule.StopMelee() end)
            end
        end
        task.wait(math.max(delaySec, 0.05))
    end
end)

-- 2. Auto Hotbar Powers / Skills Loop
task.spawn(function()
    while isScriptRunning do
        local inInvasion = isInInvasion()
        local inMission = isInMission()
        local questActive = isQuestOverrideActive()
        local questSkills = questActive and Config.QuestAutoSkills
        local bountyActive = isBountyOverrideActive()
        local bountySkills = bountyActive and Config.BountyAutoSkills
        local inInvasionSkills = inInvasion and Config.InvasionAutoFarm and Config.InvasionAutoSkills
        local inMissionSkills = inMission and (Config.AutoMission or Config.AutoMissionFarm) and Config.MissionAutoSkills
        local canSkills = Config.AutoSkills or inInvasionSkills or inMissionSkills or bountySkills or questSkills
        if canSkills then
            local target = Config.TargetCurrent
            if not isValidCombatTarget(target) then
                target = getBestTarget()
                Config.TargetCurrent = target
            end
            if target then
                local tRoot = target:FindFirstChild("HumanoidRootPart")
                    or target:FindFirstChild("Torso")
                    or target.PrimaryPart
                    or target:FindFirstChild("Hitbox")
                    or target:FindFirstChildWhichIsA("BasePart")
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
        local inInvasion = isInInvasion()
        local inMission = isInMission()
        local questActive = isQuestOverrideActive()
        local questUlt = questActive and Config.QuestAutoSkills
        local bountyActive = isBountyOverrideActive()
        local bountyUlt = bountyActive and Config.BountyAutoSkills
        local inInvasionUlt = inInvasion and Config.InvasionAutoFarm and Config.InvasionAutoSkills
        local inMissionUlt = inMission and (Config.AutoMission or Config.AutoMissionFarm) and Config.MissionAutoSkills
        local canUlt = (Config.AutoUltimate or inInvasionUlt or inMissionUlt or bountyUlt or questUlt) and canCastUltimate()
        if canUlt then
            local target = Config.TargetCurrent
            if not isValidCombatTarget(target) then
                target = getBestTarget()
                Config.TargetCurrent = target
            end
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
-- [10] AUTO QUESTS (MỞ WORLD), AUTO BOUNTY & AUTO MISSIONS
-- ========================================================================
-- 0. Luồng điều phối Auto Quests (Nhiệm Vụ Cốt Truyện NPC & Mở Khóa World)
local lastQuestWorldTele = 0
local lastQuestAcceptAttempt = 0
local lastQuestClaimAttempt = 0

task.spawn(function()
    while isScriptRunning do
        if Config.AutoQuest then
            if not isInMission() and not isInInvasion() then
                local status = getQuestlineStatus()
                if status and not status.allCompleted and status.state ~= "AllCompleted" then
                    -- Bước 1: Nếu chưa nhận Questline -> Gửi Remote nhận nhiệm vụ từ NPC
                    if status.state == "NeedAccept" and Config.QuestAutoAccept then
                        if os.clock() - lastQuestAcceptAttempt > 2.5 then
                            lastQuestAcceptAttempt = os.clock()
                            pcall(function()
                                if RemoteBank and RemoteBank.QuestAccept then
                                    RemoteBank.QuestAccept:Fire(status.questlineId)
                                end
                                if RemoteBank and RemoteBank.QuestSetTracked then
                                    RemoteBank.QuestSetTracked:Fire("Questline", status.questlineId)
                                end
                            end)
                            notify("Auto Quests", string.format("Đã gửi yêu cầu nhận cốt truyện %s!", tostring(status.questlineId)), 2.5)
                        end
                        task.wait(1.0)

                    -- Bước 2: Khi đã tiêu diệt đủ số quái yêu cầu -> Tự động Claim nhận thưởng & mở khóa World
                    elseif status.state == "ReadyToClaim" and Config.QuestAutoClaim then
                        if os.clock() - lastQuestClaimAttempt > 2.5 then
                            lastQuestClaimAttempt = os.clock()
                            pcall(function()
                                if RemoteBank and RemoteBank.QuestClaimReward then
                                    RemoteBank.QuestClaimReward:Fire(status.questlineId)
                                end
                            end)
                            notify("Auto Quests", string.format("Đã hoàn thành bước! Đang nhận thưởng & mở khóa %s...", tostring(status.questlineId)), 3)
                            task.wait(1.5)
                            -- Nhận tiếp bước tiếp theo
                            pcall(function()
                                if RemoteBank and RemoteBank.QuestAccept then
                                    RemoteBank.QuestAccept:Fire(status.questlineId)
                                end
                            end)
                        end
                        task.wait(1.0)

                    -- Bước 3: Đang trong tiến trình săn quái: kiểm tra xem có đang ở đúng World của quái không
                    elseif status.state == "InProgress" then
                        if Config.QuestAutoTeleportWorld and status.world and status.world ~= "" then
                            local curMap = getCurrentMapName()
                            if curMap ~= status.world and (os.clock() - lastQuestWorldTele > 4.0) then
                                lastQuestWorldTele = os.clock()
                                releaseCombatLock()
                                Config.TargetCurrent = nil
                                pcall(function()
                                    if RemoteBank and RemoteBank.Teleport then
                                        RemoteBank.Teleport:Fire(status.world)
                                    elseif MapClient and typeof(MapClient.RequestTeleport) == "function" then
                                        MapClient.RequestTeleport(status.world)
                                    end
                                end)
                                notify("Auto Quests", string.format("Đang dịch chuyển sang %s để làm %s (Săn %s)!", tostring(status.world), tostring(status.questlineId), tostring(status.targetEnemy or "Quái")), 3)
                                task.wait(3.5)
                            end
                        end
                    end
                end
            end
        end
        task.wait(1.0)
    end
end)

-- 1. Luồng điều phối Auto Bounty (Ưu Tiên Số 1 Ngoài World: Tự nhận -> Tele Map Quái -> Săn Đủ -> Tự Claim 1/10..10/10)
local lastBountyWorldTele = 0

task.spawn(function()
    while isScriptRunning do
        if Config.AutoBounty then
            -- Khi người chơi đang trong màn Phó Bản (Mission), tạm hoãn Auto Bounty để bot tập trung đánh xong màn phó bản
            if not isInMission() then
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
                    -- Bước 3: Đang trong tiến trình săn quái Bounty ngoài World (ví dụ Belu 3/12 ở Demon Citadel)
                    elseif status.state == "InProgress" then
                        if Config.BountyAutoTeleport and status.world and status.world ~= "" then
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
        end
        task.wait(1.0)
    end
end)

-- 2. Luồng điều phối Auto Missions (Ưu Tiên Số 2: Tự động chạy khi Auto Bounty đã xong 10/10 hoặc đang tắt)
currentWaveInfo = {
    wave = 0,
    totalWaves = 0,
    enemiesAlive = 0,
    enemiesTotal = 0,
    title = ""
}

local function syncWaveInfoFromHUD()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local inMissionUI = pGui and pGui:FindFirstChild("MainHUD")
        and pGui.MainHUD:FindFirstChild("Missions")
        and pGui.MainHUD.Missions:FindFirstChild("InMissionUI")
    if inMissionUI and inMissionUI.Visible and inMissionUI:FindFirstChild("StatsFrame") then
        local stats = inMissionUI.StatsFrame
        if stats:FindFirstChild("Waves") and stats.Waves:FindFirstChild("NumberDisplay") then
            local wText = tostring(stats.Waves.NumberDisplay.Text or "")
            local curW, totW = wText:match("(%d+)/(%d+)")
            if curW and totW then
                currentWaveInfo.wave = tonumber(curW) or currentWaveInfo.wave
                currentWaveInfo.totalWaves = tonumber(totW) or currentWaveInfo.totalWaves
            elseif tonumber(wText) then
                currentWaveInfo.wave = tonumber(wText) or currentWaveInfo.wave
            end
        end
        if stats:FindFirstChild("Enemies") and stats.Enemies:FindFirstChild("NumberDisplay") then
            local eText = tostring(stats.Enemies.NumberDisplay.Text or "")
            local curE, totE = eText:match("(%d+)/(%d+)")
            if curE and totE then
                currentWaveInfo.enemiesAlive = tonumber(curE) or currentWaveInfo.enemiesAlive
                currentWaveInfo.enemiesTotal = tonumber(totE) or currentWaveInfo.enemiesTotal
            elseif tonumber(eText) then
                currentWaveInfo.enemiesAlive = tonumber(eText) or currentWaveInfo.enemiesAlive
            end
        end
        local details = inMissionUI:FindFirstChild("Details")
        if details and details:FindFirstChild("Act") and details.Act:FindFirstChild("Title") then
            local tText = tostring(details.Act.Title.Text or "")
            if tText ~= "" then
                currentWaveInfo.title = tText
            end
        end
    end
end

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

    -- Nếu đang ở trong màn Invasion, tự động Return để ra ngoài nhận thưởng và chờ đợt sau
    if isInInvasion() then
        pcall(function()
            RemoteBank.MissionDecision:Fire("Return")
        end)
        return
    end

    -- Nếu Auto Bounty (Ưu Tiên 1) đang bật và còn nhiệm vụ Bounty chưa làm xong -> Tự chọn Return thoát ra ngoài làm Bounty
    local bStatus = getBountyTaskStatus()
    if Config.AutoBounty and bStatus and not bStatus.completed and bStatus.state ~= "Completed" then
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

-- Luồng điều phối Auto Invasion (Ưu Tiên Số 0: Tự động tham gia khi đợt Xâm Lược mở)
task.spawn(function()
    local lastInvLaunch = 0
    while isScriptRunning do
        if Config.AutoInvasion then
            local invSt = getInvasionStatus()
            if invSt.isActive and not isInInvasion() and not isInMission() then
                local capped = Config.InvasionFarmUntilCap and (invSt.gems.received >= invSt.gems.max and invSt.rerolls.received >= invSt.rerolls.max)
                if not capped and (os.clock() - lastInvLaunch > 5.0) then
                    lastInvLaunch = os.clock()
                    local chosenWorld = (Config.InvasionPreferredWorld and Config.InvasionPreferredWorld ~= "Tự Động (Theo Server)")
                        and Config.InvasionPreferredWorld
                        or (invSt.activeWorld or "Nemu's Village")
                    pcall(function()
                        if RemoteBank.MissionLaunch then
                            RemoteBank.MissionLaunch:Fire({
                                gamemode = "Invasion",
                                world = chosenWorld
                            })
                        end
                    end)
                    notify("Auto Invasion", string.format("Phát hiện Xâm Lược tại %s! Đang tham gia...", tostring(chosenWorld)), 3)
                    task.wait(4.0)
                end
            end
        end
        task.wait(2.0)
    end
end)

task.spawn(function()
    while isScriptRunning do
        -- 1. Nếu bảng tổng kết thưởng đang hiện mà sự kiện bị trễ -> Tự bấm quyết định
        local bStatus = getBountyTaskStatus()
        local bountyPending = Config.AutoBounty and bStatus and not bStatus.completed and bStatus.state ~= "Completed"
        if (Config.AutoReplayMission or Config.AutoMission or bountyPending or isInInvasion()) and isMissionRewardUIVisible() then
            task.wait(1.6)
            if isMissionRewardUIVisible() then
                handleMissionEndDecision(nil)
                task.wait(2.5)
            end
        end

        -- 2. Khởi chạy Auto Challenge hoặc Phó Bản khi không bận Xâm Lược
        local bountyBusy = isBountyOverrideActive()
        local invSt = getInvasionStatus()
        local invBusy = Config.AutoInvasion and invSt.isActive
        if Config.AutoChallenge and not invBusy and not isInMission() and not isInInvasion() then
            launchConfiguredChallenge()
            task.wait(4.5)
        elseif Config.AutoMission and not bountyBusy and not invBusy and not isInMission() and not isInInvasion() then
            launchConfiguredMission()
            task.wait(4.5)
        end

        task.wait(1.5)
    end
end)

-- Tự động tiếp tục ngay khi nhận gói tin kết thúc màn chơi (MissionComplete)
if RemoteBank.MissionComplete and RemoteBank.MissionComplete.OnClientEvent then
    trackConnection(RemoteBank.MissionComplete.OnClientEvent:Connect(function(resultData)
        if Config.AutoReplayMission or Config.AutoMission or isBountyOverrideActive() or isInInvasion() then
            task.spawn(function()
                task.wait(1.6)
                handleMissionEndDecision(resultData)
            end)
        end
    end))
end

-- ========================================================================
-- [11] AUTO SUMMON / GACHA & FLOATING TOGGLE
-- ========================================================================
local function doPullBanner(bannerName, count)
    local targetBanner = "Standard Powers"
    local bStr = tostring(bannerName or ""):lower()
    if bStr:find("weapon") or bStr:find("kiếm") or bStr:find("vũ khí") then
        targetBanner = "Standard Weapons"
    else
        targetBanner = "Standard Powers"
    end

    local num = tonumber(count) or 1
    if num > 50 then num = 50 end
    if num < 1 then num = 1 end

    pcall(function()
        if RemoteBank and RemoteBank.PullBanner then
            RemoteBank.PullBanner:Fire(targetBanner, num)
        end
    end)
end

task.spawn(function()
    while isScriptRunning do
        if Config.AutoSummon then
            pcall(function()
                doPullBanner(Config.SummonBanner, Config.SummonCount)
            end)
            task.wait(0.6)
        else
            task.wait(1)
        end
    end
end)

-- ========================================================================
-- [11B] MERCHANT AUTO BUY (BOB E.O - TRAVELLING MERCHANT)
-- ========================================================================
local MerchantsModule
pcall(function()
    MerchantsModule = require(ReplicatedStorage.DataModules.Economy.Merchants)
end)

local function getMerchantStock()
    if not MerchantsModule then
        pcall(function()
            MerchantsModule = require(ReplicatedStorage.DataModules.Economy.Merchants)
        end)
    end
    if not MerchantsModule then return nil, 0, 0 end
    local now = os.time()
    local period = MerchantsModule.GetPeriod(now)
    local timeLeft = MerchantsModule.GetTimeRemaining(now)
    local ok, stock = pcall(MerchantsModule.RollStock, "Travelling Merchant", period)
    if ok and type(stock) == "table" then
        return stock, timeLeft, period
    end
    return nil, timeLeft, period
end

local function getRemainingSlotStock(slotData, slotIndex, period)
    if not slotData then return 0 end
    if slotData.Infinite then return 999999 end
    local sold = 0
    pcall(function()
        if DataClient and typeof(DataClient.Get) == "function" then
            local purchases = DataClient.Get("MerchantPurchases")
            if type(purchases) == "table" and type(purchases["Travelling Merchant"]) == "table" then
                local tm = purchases["Travelling Merchant"]
                if slotData.Permanent then
                    if type(tm.permanent) == "table" then
                        sold = tonumber(tm.permanent[slotData.Item]) or 0
                    end
                elseif tm.period == period and type(tm.bought) == "table" then
                    sold = tonumber(tm.bought[tostring(slotIndex)]) or 0
                end
            end
        end
    end)
    return math.max(0, (slotData.Quantity or 0) - sold)
end

local function isItemSelectedForPurchase(itemName)
    if not Config.SelectedShopItems or #Config.SelectedShopItems == 0 then
        return false
    end
    local itemLower = tostring(itemName or ""):lower()
    for _, sel in ipairs(Config.SelectedShopItems) do
        local selStr = tostring(sel):lower()
        if selStr:find("tất cả vật phẩm") or selStr:find("all items") then
            return true
        end
        if selStr:find("tất cả quả sao") and itemLower:find("star fruit") then
            return true
        end
        if itemLower == selStr or itemLower:find(selStr, 1, true) or selStr:find(itemLower, 1, true) then
            return true
        end
    end
    return false
end

local function purchaseSelectedMerchantItems()
    local stock, _timeLeft, period = getMerchantStock()
    if not stock or #stock == 0 then return 0 end

    local currentCoins = 0
    pcall(function()
        if DataClient and typeof(DataClient.Get) == "function" then
            currentCoins = tonumber(DataClient.Get("Coins")) or 0
        end
        if currentCoins <= 0 and LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Coins") then
            currentCoins = tonumber(LocalPlayer.leaderstats.Coins.Value) or 0
        end
    end)

    local totalPurchased = 0
    for slotIndex, slotData in ipairs(stock) do
        local itemName = tostring(slotData.Item or "")
        if isItemSelectedForPurchase(itemName) then
            local remaining = getRemainingSlotStock(slotData, slotIndex, period)
            if remaining > 0 then
                local unitPrice = tonumber(slotData.UnitPrice) or 0
                local maxCanAfford = (unitPrice > 0) and math.floor(currentCoins / unitPrice) or remaining
                local qtyToBuy = math.min(remaining, maxCanAfford)
                if qtyToBuy > 0 then
                    pcall(function()
                        if RemoteBank and RemoteBank.MerchantPurchase then
                            RemoteBank.MerchantPurchase:Fire("Travelling Merchant", slotIndex, qtyToBuy)
                            totalPurchased = totalPurchased + qtyToBuy
                            currentCoins = math.max(0, currentCoins - (qtyToBuy * unitPrice))
                        end
                    end)
                    task.wait(0.2)
                end
            end
        end
    end
    return totalPurchased
end

local function findBobEOModel()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name:find("Bob") or obj.Name:find("Merchant")) then
            return obj
        end
    end
    return nil
end

task.spawn(function()
    while isScriptRunning do
        if Config.AutoBuyMerchant then
            pcall(function()
                purchaseSelectedMerchantItems()
            end)
            task.wait(3.0)
        else
            task.wait(1.5)
        end
    end
end)

-- UI Toggle Button Floating on Screen
local floatingScreenGui
local function setFloatingButtonVisible(visible)
    if floatingScreenGui then
        floatingScreenGui.Enabled = (visible ~= false)
    end
end

local function createFloatingToggle(targetWindow)
    pcall(function()
        local parentGui
        if typeof(gethui) == "function" then
            parentGui = gethui()
        else
            local okCore, cg = pcall(function() return game:GetService("CoreGui") end)
            if okCore and cg then
                parentGui = cg
            else
                parentGui = LocalPlayer:WaitForChild("PlayerGui")
            end
        end

        local existing = parentGui:FindFirstChild("HelmHubFloatingMenu")
        if existing then existing:Destroy() end

        floatingScreenGui = Instance.new("ScreenGui")
        floatingScreenGui.Name = "HelmHubFloatingMenu"
        floatingScreenGui.ResetOnSpawn = false
        floatingScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Name = "ToggleButton"
        toggleBtn.Size = UDim2.new(0, 115, 0, 30)
        toggleBtn.Position = UDim2.new(0.5, -57, 0, 8)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
        toggleBtn.BackgroundTransparency = 0.15
        toggleBtn.Text = "✦ Helm MENU"
        toggleBtn.TextColor3 = Color3.fromRGB(130, 225, 255)
        toggleBtn.TextSize = 13
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.BorderSizePixel = 0
        toggleBtn.Active = true
        toggleBtn.AutoButtonColor = true
        toggleBtn.Parent = floatingScreenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 15)
        corner.Parent = toggleBtn

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1.2
        stroke.Color = Color3.fromRGB(0, 170, 255)
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = toggleBtn

        -- Smooth Dragging Support
        local dragging = false
        local dragInput, dragStart, startPos
        toggleBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = toggleBtn.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        toggleBtn.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                toggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        -- Click toggle
        toggleBtn.MouseButton1Click:Connect(function()
            if targetWindow and targetWindow.Frame then
                targetWindow.Frame.Visible = not targetWindow.Frame.Visible
                if targetWindow.Frame.Visible then
                    toggleBtn.TextColor3 = Color3.fromRGB(130, 225, 255)
                    stroke.Color = Color3.fromRGB(0, 170, 255)
                else
                    toggleBtn.TextColor3 = Color3.fromRGB(180, 190, 205)
                    stroke.Color = Color3.fromRGB(60, 75, 95)
                end
            end
        end)

        floatingScreenGui.Enabled = (Config.FloatingMenuButton ~= false)
        floatingScreenGui.Parent = parentGui
    end)
end

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

-- Khởi tạo nút On/Off Menu nổi trên màn hình
createFloatingToggle(Window)

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
local StatusHitsLabel = SecAttack:AddLabel("Đòn Trúng Server: 0 đòn/s (Tổng: 0)", false)

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

            local hps = (combatMetrics and combatMetrics.hitsLastSecond) or 0
            local totalHits = (combatMetrics and combatMetrics.hitsRecorded) or 0
            if Config.AutoPunch or (isInMission() and Config.AutoMissionFarm) or (isInInvasion() and Config.InvasionAutoFarm) then
                StatusHitsLabel:Set(string.format("Đòn Trúng Server: %d đòn/s (Tổng trúng: %d)", hps, totalHits))
            else
                StatusHitsLabel:Set(string.format("Đòn Trúng Server: Đang tắt (Tổng: %d)", totalHits))
            end
        end)
        task.wait(0.5)
    end
end)

pcall(function()
    SecAttack:AddToggle("Tự Động Đánh Thường (Auto Punch)", Config.AutoPunch, function(val)
        Config.AutoPunch = val
        if val and not Config.AutoPosition then
            Config.AutoPosition = true
            notify("Tự Động Áp Sát", "Đã tự động kích hoạt Áp Sát Quái để đảm bảo đòn đánh trúng 100%!", 3)
        end
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

    local _DropWorld = SecTarget:AddDropdown("Lọc Danh Sách Quái Theo World", {
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

    SecTarget:AddDropdown("Chế Độ Nhắm Quái", {
        "Gần Nhất (Ưu Tiên Đánh Quái Ngay Cạnh - Chuẩn)",
        "Máu Thấp Nhất (Lowest HP)",
        "Ưu Tiên Boss (Boss First)"
    }, "Gần Nhất (Ưu Tiên Đánh Quái Ngay Cạnh - Chuẩn)", false, function(val)
        local s = tostring(val or "")
        if s:find("Máu Thấp") or s:find("Lowest") then
            Config.TargetMode = "LowestHP"
        elseif s:find("Boss") then
            Config.TargetMode = "BossFirst"
        else
            Config.TargetMode = "Nearest"
        end
    end)

    SecTarget:AddSlider("Phạm Vi Quét Quái Toàn Map (Studs)", 100, 2500, 5000, 0, function(val)
        Config.ScanRange = math.floor(tonumber(val) or 2500)
    end)

    SecTarget:AddToggle("Tự Động Giữ Vị Trí / Áp Sát (Auto Position)", Config.AutoPosition, function(val)
        Config.AutoPosition = val
        if not val then
            releaseCombatLock()
        end
    end)

    SecTarget:AddSlider("⚡ Tốc Độ Di Chuyển / Tiếp Cận (Studs/s)", 10, 25, 80, 0, function(val)
        Config.GlideSpeed = math.floor(tonumber(val) or 25)
    end)

    SecTarget:AddDropdown("🕹️ Kiểu Di Chuyển (Movement Style)", {
        "Lướt Mượt Chuẩn Server (Glide - Mặc Định)",
        "Chạy Bộ Tự Nhiên (Humanoid Walk)",
        "Dịch Chuyển Tức Thời (Instant Teleport)"
    }, "Lướt Mượt Chuẩn Server (Glide - Mặc Định)", false, function(val)
        local s = tostring(val or "")
        if s:find("Instant") or s:find("Tức Thời") then
            Config.MovementStyle = "Instant"
        elseif s:find("Walk") or s:find("Chạy Bộ") then
            Config.MovementStyle = "Walk"
        else
            Config.MovementStyle = "Glide"
        end
    end)

    SecTarget:AddToggle("🐎 Tự Động Cưỡi Mount Khi Di Chuyển Xa (Auto Mount)", Config.AutoMount, function(val)
        Config.AutoMount = val
        if not val and isPlayerMounted() and not Config.StayMountedCombat then
            setPlayerMounted(false)
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

    SecTarget:AddSlider("Độ Cao Đứng Đánh Quái (Studs)", -5, 0, 20, 0, function(val)
        Config.CombatHeightOffset = math.floor(tonumber(val) or 0)
    end)

    SecTarget:AddSlider("Khoảng Cách Áp Sát Quái (Studs)", 1, 1, 10, 0, function(val)
        Config.BehindDistance = math.max(1, math.floor(tonumber(val) or 1))
    end)

    SecTarget:AddToggle("Đi Xuyên Vật Thể (NoClip)", Config.NoClip, function(val)
        Config.NoClip = val
        if not val and not isActivelyLockingTarget then
            restoreCharacterCollision()
        end
    end)
end)

-- ------------------------------------------------------------------------
-- TAB 2: (A) GAMEMODE (HỢP NHẤT TOÀN DIỆN: CHALLENGES + QUESTS + BOUNTY + INVASION + MISSIONS)
-- ------------------------------------------------------------------------
pcall(function()
    local TabActivities = Window:CreateTab("(A) Gamemode")
    local SecActivities = TabActivities:CreateSector("Tiến Độ & Kích Hoạt (Status & Automation)", "left")
    local SecConfig = TabActivities:CreateSector("Cấu Hình Gamemode Chạy Ngầm (Config)", "right")

    -- [CỘT TRÁI] TRẠNG THÁI TIẾN ĐỘ THỜI GIAN THỰC
    local PrioStatusLabel = SecActivities:AddLabel("Ưu Tiên: Đang kiểm tra...", false)
    local ChallengeStatusLabel = SecActivities:AddLabel("Thử Thách: Đang kiểm tra...", false)
    local QuestlineLabel = SecActivities:AddLabel("Cốt Truyện: Đang kiểm tra...", false)
    local BountyLabel = SecActivities:AddLabel("Bounty: Đang kiểm tra...", false)
    local InvasionLabel = SecActivities:AddLabel("Invasion: Đang kiểm tra...", false)
    local MissionStateLabel = SecActivities:AddLabel("Phó Bản: Đang ở sảnh / map", false)
    local MissionWaveLabel = SecActivities:AddLabel("Wave: 0/0 | Quái: 0 con", false)

    task.spawn(function()
        while isScriptRunning do
            pcall(function()
                -- 1. Ưu tiên hoạt động
                local prioMode = getActivePriorityMode()
                if prioMode == "Invasion" or prioMode == "InvasionCombat" then
                    PrioStatusLabel:Set("⚡ Ưu Tiên: [0] AUTO INVASION (SỰ KIỆN XÂM LƯỢC)")
                elseif prioMode == "Challenge" then
                    PrioStatusLabel:Set("🎯 Ưu Tiên: [1] AUTO CHALLENGES (DAILY / WEEKLY)")
                elseif prioMode == "Mission" or prioMode == "MissionQueue" then
                    PrioStatusLabel:Set("⚔️ Ưu Tiên: [2] AUTO MISSIONS (PHÓ BẢN)")
                elseif prioMode == "Quest" then
                    PrioStatusLabel:Set("🔥 Ưu Tiên: [3] AUTO QUESTS (CỐT TRUYỆN MỞ WORLD)")
                elseif prioMode == "Bounty" then
                    PrioStatusLabel:Set("📜 Ưu Tiên: [4] AUTO BOUNTY (TIỀN THƯỞNG)")
                else
                    PrioStatusLabel:Set("🌍 Ưu Tiên: [5] CHIẾN ĐẤU THƯỜNG TRONG MAP")
                end

                -- 2. Tiến độ Challenges (Daily & Weekly)
                local cInfo = getChallengeInfo()
                local dHours = math.floor(cInfo.dailyTime / 3600)
                local dMins = math.floor((cInfo.dailyTime % 3600) / 60)
                local dSecs = math.floor(cInfo.dailyTime % 60)

                local wDays = math.floor(cInfo.weeklyTime / 86400)
                local wHours = math.floor((cInfo.weeklyTime % 86400) / 3600)
                local wMins = math.floor((cInfo.weeklyTime % 3600) / 60)

                local dStatus = cInfo.dailyClaimed and "✅ Xong" or string.format("⏳ Còn %02d:%02d:%02d", dHours, dMins, dSecs)
                local wStatus = cInfo.weeklyClaimed and "✅ Xong" or string.format("⏳ Còn %dd %02d:%02d", wDays, wHours, wMins)

                ChallengeStatusLabel:Set(string.format("Thử Thách: Daily [%s] | Weekly [%s]", dStatus, wStatus))

                -- 3. Tiến độ Quests cốt truyện
                local qStatus = getQuestlineStatus()
                if not qStatus then
                    QuestlineLabel:Set("Cốt Truyện: Chưa tải dữ liệu")
                elseif qStatus.allCompleted or qStatus.state == "AllCompleted" then
                    QuestlineLabel:Set("Cốt Truyện: 🎉 ĐÃ XONG TẤT CẢ! ĐÃ MỞ TOÀN BỘ WORLD")
                elseif qStatus.state == "NeedAccept" then
                    QuestlineLabel:Set(string.format("Cốt Truyện: %s (Bước %d/%d) -> Tự nhận NPC %s",
                        tostring(qStatus.questlineName or "?"), qStatus.stepIndex or 1, qStatus.totalSteps or 6, tostring(qStatus.npcName or "?")))
                elseif qStatus.state == "ReadyToClaim" then
                    QuestlineLabel:Set(string.format("Cốt Truyện: %s (Bước %d/%d) -> ✅ Đủ quái, tự trả thưởng",
                        tostring(qStatus.questlineName or "?"), qStatus.stepIndex or 1, qStatus.totalSteps or 6))
                else
                    QuestlineLabel:Set(string.format("Cốt Truyện: %s (B%d/%d) | Săn %s (%d/%d) @ %s",
                        tostring(qStatus.questlineName or "?"), qStatus.stepIndex or 1, qStatus.totalSteps or 6,
                        tostring(qStatus.targetEnemy or "?"), qStatus.progress or 0, qStatus.target or 1, tostring(qStatus.world or "?")))
                end

                -- 4. Tiến độ Bounty
                local bStatus = getBountyTaskStatus()
                if not bStatus then
                    BountyLabel:Set("Bounty: Chưa tải dữ liệu")
                elseif bStatus.completed or bStatus.state == "Completed" then
                    BountyLabel:Set("Bounty: ✅ ĐÃ HOÀN TẤT 10/10 MỐC HÔM NAY")
                elseif bStatus.state == "NeedAccept" then
                    BountyLabel:Set(string.format("Bounty: Mốc %d/10 -> Chuẩn bị tự nhận", bStatus.position or 1))
                else
                    BountyLabel:Set(string.format("Bounty: Mốc %d/10 | Săn %s (%d/%d) @ %s",
                        bStatus.position or 1, tostring(bStatus.enemy or "?"), bStatus.progress or 0, bStatus.target or 1, tostring(bStatus.world or "?")))
                end

                -- 5. Tiến độ Invasion
                local invData = getInvasionData()
                if invData.inInvasion then
                    InvasionLabel:Set(string.format("Invasion: ĐANG DIỄN RA (%s) | Boss: %s HP: %d%%",
                        tostring(invData.currentMap), tostring(invData.bossName or "Egris"), math.floor(invData.bossHpPct * 100)))
                elseif invData.activeWorld and invData.activeWorld ~= "" then
                    InvasionLabel:Set(string.format("Invasion: Cổng đang mở tại %s (Chuẩn bị vào)", tostring(invData.activeWorld)))
                else
                    InvasionLabel:Set("Invasion: Đang chờ sự kiện mở...")
                end

                -- 6. Tiến độ Phó Bản (Missions)
                if isInMission() then
                    pcall(syncWaveInfoFromHUD)
                    local gm = LocalPlayer:GetAttribute("Gamemode") or Config.MissionGamemode or "Mission"
                    local title = (currentWaveInfo.title ~= "" and currentWaveInfo.title) or getCurrentMapName()
                    local waveCount = (currentWaveInfo.wave and currentWaveInfo.wave > 0) and currentWaveInfo.wave or 1
                    local totalW = (currentWaveInfo.totalWaves and currentWaveInfo.totalWaves > 0) and currentWaveInfo.totalWaves or 10
                    local livingMobs = #getAllEnemies()
                    if livingMobs == 0 and currentWaveInfo.enemiesAlive and currentWaveInfo.enemiesAlive > 0 then
                        livingMobs = currentWaveInfo.enemiesAlive
                    end
                    MissionStateLabel:Set(string.format("Phó Bản: [%s - %s]", tostring(gm), tostring(title)))
                    MissionWaveLabel:Set(string.format("Wave: %d/%d | Quái Sống: %d con", waveCount, totalW, livingMobs))
                else
                    MissionStateLabel:Set("Phó Bản: Ngoài Thế Giới / Sảnh")
                    MissionWaveLabel:Set(string.format("Quái Quanh Đây: %d con", #getAllEnemies()))
                end
            end)
            task.wait(0.6)
        end
    end)

    -- CÁC CÔNG TẮC KÍCH HOẠT CHÍNH (CỘT TRÁI)
    SecActivities:AddToggle("🎯 Bật Auto Challenges (Daily, Weekly, Regular)", Config.AutoChallenge, function(val)
        Config.AutoChallenge = val
    end)

    SecActivities:AddToggle("🔥 Bật Auto Quests (Làm Cốt Truyện Mở World)", Config.AutoQuest, function(val)
        Config.AutoQuest = val
        if not val and not Config.AutoPosition then
            releaseCombatLock()
        end
    end)

    SecActivities:AddToggle("👑 Ưu Tiên Quests Hơn Bounty (Mở World Trước)", Config.QuestPriorityOverBounty, function(val)
        Config.QuestPriorityOverBounty = val
    end)

    SecActivities:AddToggle("📜 Bật Auto Bounty (Săn Tiền Thưởng 10 Mốc/Ngày)", Config.AutoBounty, function(val)
        Config.AutoBounty = val
        if not val and not Config.AutoPosition then
            releaseCombatLock()
        end
    end)

    SecActivities:AddToggle("⚡ Bật Auto Invasion (Tự Động Đi Khi Mở Sự Kiện)", Config.AutoInvasion, function(val)
        Config.AutoInvasion = val
    end)

    SecActivities:AddToggle("⚔️ Bật Auto Missions (Tự Vào Phó Bản / Dungeons)", Config.AutoMission, function(val)
        Config.AutoMission = val
        if val then
            Config.AutoMissionFarm = true
            Config.MissionAutoTeleport = true
        else
            if not Config.AutoPosition then
                releaseCombatLock()
            end
        end
    end)

    SecActivities:AddToggle("💥 Tự Động Đánh Quái Trong Phó Bản (Mission Farm)", Config.AutoMissionFarm, function(val)
        Config.AutoMissionFarm = val
        if not val and not Config.AutoPosition then
            releaseCombatLock()
        end
    end)

    SecActivities:AddToggle("🔄 Tự Động Chơi Lại / Đi Tiếp Khi Xong (Auto Replay)", Config.AutoReplayMission, function(val)
        Config.AutoReplayMission = val
    end)

    SecActivities:AddToggle("🛡️ Tự Động Né Chiêu Boss / Vùng Đỏ (Auto Dodge)", Config.AutoDodge, function(val)
        Config.AutoDodge = val
        if not val then
            Config.IsCurrentlyDodging = false
        end
    end)

    SecActivities:AddButton("💎 Nhận Toàn Bộ Thưởng 1-Chạm (Quests, Bounty, Pass, Milestones)", function()
        pcall(function()
            claimAllQuests()
            claimAllLevelMilestones()
            claimAllAchievements()
            if RemoteBank and RemoteBank.BountyClaim then
                RemoteBank.BountyClaim:Fire(nil)
            end
            if RemoteBank and RemoteBank.ClaimDailyReward then
                RemoteBank.ClaimDailyReward:Fire()
            end
            if RemoteBank and RemoteBank.ClaimGroupReward then
                RemoteBank.ClaimGroupReward:Fire()
            end
            if RemoteBank and RemoteBank.BattlepassClaimAll then
                RemoteBank.BattlepassClaimAll:Fire()
            end
            notify("Nhận Thưởng", "Đã gửi toàn bộ yêu cầu nhận thưởng Quests, Milestones, Achievements & Pass!", 4)
        end)
    end)

    -- [CỘT PHẢI] CẤU HÌNH TỰ ĐỘNG HÓA CHẠY NGẦM 100%
    SecConfig:AddDropdown("Chế Độ Phó Bản (Gamemode)", {
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

    SecConfig:AddDropdown("Chọn Loại Challenge Muốn Đi", {
        "Tất Cả (Daily -> Weekly -> Regular)",
        "Daily Challenge (2500 Gems + 10 Rerolls)",
        "Weekly Challenge (5000 Gems + 50 Rerolls)",
        "Regular Challenge (Slot 1)",
        "Regular Challenge (Slot 2)",
        "Regular Challenge (Slot 3)"
    }, Config.ChallengeSelectedTier, false, function(val)
        Config.ChallengeSelectedTier = val
    end)

    SecConfig:AddDropdown("Chọn Cốt Truyện Muốn Làm", {
        "Tự Động (Theo Tiến Độ Cốt Truyện)",
        "Nemu's Questline (World 1 -> Mở Hollow World)",
        "Kisky's Questline (World 2 -> Mở Demon Citadel)",
        "Sang Woo's Questline (World 3 - Demon Citadel)"
    }, Config.QuestlineSelected, false, function(val)
        Config.QuestlineSelected = val
    end)

    SecConfig:AddDropdown("Chọn Thế Giới Phó Bản (World)", { "Nemu's Village", "Hollow World", "Demon Citadel" }, "Nemu's Village", false, function(val)
        Config.MissionWorld = tostring(val or "Nemu's Village")
    end)

    SecConfig:AddDropdown("Chọn Màn (Act 1-3 & Act 4 EX)", {
        "Act 1",
        "Act 2",
        "Act 3",
        "Act 4 (EX Stage - 10 Waves)"
    }, "Act 1", false, function(val)
        Config.MissionAct = tonumber(tostring(val):match("%d+")) or 1
    end)

    SecConfig:AddDropdown("Độ Khó (Mode)", { "Normal", "Hard" }, "Normal", false, function(val)
        Config.MissionMode = tostring(val or "Normal")
    end)

    SecConfig:AddSlider("Tầng Gauntlet (Chamber 1 - 10)", 1, 1, 10, 0, function(val)
        Config.GauntletChamber = math.clamp(math.floor(tonumber(val) or 1), 1, 10)
    end)

    SecConfig:AddDropdown("Hành Động Khi Xong Màn", {
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

    SecConfig:AddButton("🚀 Vào Ngay Hoạt Động Đã Chọn (Launch Now)", function()
        pcall(function()
            if Config.MissionGamemode == "Challenge" then
                launchConfiguredChallenge()
            else
                launchConfiguredMission()
            end
            notify("Gamemode", "Đã gửi lệnh vào Hoạt Động / Phó Bản!", 3)
        end)
    end)

    SecConfig:AddButton("🚪 Thoát Hoạt Động Về Map Ngay (Leave Mission)", function()
        pcall(function()
            if RemoteBank.MissionDecision then
                RemoteBank.MissionDecision:Fire("Return")
            end
            if RemoteBank.MissionReturn then
                RemoteBank.MissionReturn:Fire()
            end
            notify("Gamemode", "Đã gửi lệnh rời khỏi Hoạt Động!", 3)
        end)
    end)

    SecConfig:AddToggle("📍 Tự Động Tele Sang Đúng World Của Quái", Config.QuestAutoTeleportWorld, function(val)
        Config.QuestAutoTeleportWorld = val
    end)

    SecConfig:AddToggle("🎯 Tự Động Tele Áp Sát Quái Nhiệm Vụ & Phó Bản", Config.QuestAutoTeleport, function(val)
        Config.QuestAutoTeleport = val
        Config.BountyAutoTeleport = val
        Config.InvasionAutoTeleport = val
        Config.MissionAutoTeleport = val
        if not val and not Config.AutoPosition then
            releaseCombatLock()
        end
    end)

    SecConfig:AddToggle("🎁 Tự Động Nhận & Trả Thưởng Nhiệm Vụ (Auto Claim)", Config.QuestAutoClaim, function(val)
        Config.QuestAutoClaim = val
        Config.QuestAutoAccept = val
    end)

    SecConfig:AddToggle("✨ Tự Động Xả Kỹ Năng & Chiêu Cuối (Auto Skills)", Config.QuestAutoSkills, function(val)
        Config.QuestAutoSkills = val
        Config.BountyAutoSkills = val
        Config.InvasionAutoSkills = val
        Config.MissionAutoSkills = val
    end)

    SecConfig:AddToggle("🛑 Dừng Invasion Khi Đạt Giới Hạn Ngày (Cap 10k Gems)", Config.InvasionFarmUntilCap, function(val)
        Config.InvasionFarmUntilCap = val
    end)
end)

-- TAB 4: GACHA & BUY (QUAY THẺ GACHA & CỬA HÀNG MERCHANT BOB E.O)
-- ------------------------------------------------------------------------
pcall(function()
    local TabGachaBuy = Window:CreateTab("Gacha & Buy")
    local SecGacha = TabGachaBuy:CreateSector("Gacha & Banner (Summon)", "left")
    local SecMerchant = TabGachaBuy:CreateSector("Cửa Hàng Merchant (Bob E.O)", "right")

    -- [CỘT TRÁI] GACHA & BANNER
    local GemsLabel = SecGacha:AddLabel("Tài Nguyên: Đang kiểm tra...", false)

    task.spawn(function()
        while isScriptRunning do
            pcall(function()
                local gems = 0
                if DataClient and typeof(DataClient.Get) == "function" then
                    gems = tonumber(DataClient.Get("Gems")) or 0
                end
                if gems <= 0 and LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Gems") then
                    gems = tonumber(LocalPlayer.leaderstats.Gems.Value) or 0
                end
                GemsLabel:Set(string.format("💎 Gems Hiện Có: %s", Format and Format.formatWithCommas and Format.formatWithCommas(gems) or tostring(gems)))
            end)
            task.wait(1.5)
        end
    end)

    SecGacha:AddToggle("Tự Động Quay Thẻ (Auto Summon)", Config.AutoSummon, function(val)
        Config.AutoSummon = val
    end)

    SecGacha:AddDropdown("Chọn Banner Quay", {
        "Standard Powers (Kỹ Năng)",
        "Standard Weapons (Vũ Khí/Kiếm)"
    }, "Standard Powers (Kỹ Năng)", false, function(val)
        local s = tostring(val or ""):lower()
        if s:find("weapon") or s:find("vũ khí") or s:find("kiếm") then
            Config.SummonBanner = "Standard Weapons"
        else
            Config.SummonBanner = "Standard Powers"
        end
    end)

    SecGacha:AddDropdown("Số Lượng Quay", {
        "1x Lần (50 Gems)",
        "10x Lần (500 Gems)",
        "50x Lần (Max Summon - 2500 Gems)"
    }, "1x Lần (50 Gems)", false, function(val)
        local s = tostring(val or "")
        if s:find("50x") then
            Config.SummonCount = 50
        elseif s:find("10x") then
            Config.SummonCount = 10
        else
            Config.SummonCount = 1
        end
    end)

    SecGacha:AddButton("✨ Quay Thẻ Ngay (Summon Now)", function()
        pcall(function()
            doPullBanner(Config.SummonBanner, Config.SummonCount)
            notify("Gacha Summon", string.format("Đã gửi lệnh quay %s (x%d lượt)!", tostring(Config.SummonBanner), tonumber(Config.SummonCount) or 1), 3)
        end)
    end)

    -- [CỘT PHẢI] CỬA HÀNG MERCHANT (BOB E.O) & AUTO BUY
    local RestockLabel = SecMerchant:AddLabel("Đổi Hàng: Đang tính...", false)
    local CoinsLabel = SecMerchant:AddLabel("Tiền Yen: Đang kiểm tra...", false)
    local StockSummaryLabel = SecMerchant:AddLabel("Hàng Trong Shop: Đang tải...", false)

    task.spawn(function()
        while isScriptRunning do
            pcall(function()
                local stock, timeLeft, period = getMerchantStock()
                if timeLeft and timeLeft > 0 then
                    local hh = math.floor(timeLeft / 3600)
                    local mm = math.floor((timeLeft % 3600) / 60)
                    local ss = math.floor(timeLeft % 60)
                    RestockLabel:Set(string.format("⏳ Shop Restock Sau: %02d:%02d:%02d", hh, mm, ss))
                else
                    RestockLabel:Set("⏳ Shop Restock: Vừa làm mới hàng!")
                end

                local coins = 0
                if DataClient and typeof(DataClient.Get) == "function" then
                    coins = tonumber(DataClient.Get("Coins")) or 0
                end
                if coins <= 0 and LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Coins") then
                    coins = tonumber(LocalPlayer.leaderstats.Coins.Value) or 0
                end
                CoinsLabel:Set(string.format("🪙 Tiền (Yen): %s", Format and Format.formatWithCommas and Format.formatWithCommas(coins) or tostring(coins)))

                if stock and #stock > 0 then
                    local summary = {}
                    for i, sl in ipairs(stock) do
                        local rem = getRemainingSlotStock(sl, i, period)
                        if rem > 0 then
                            table.insert(summary, string.format("%s (%d)", sl.Item, rem))
                        end
                    end
                    if #summary > 0 then
                        StockSummaryLabel:Set("Hàng Còn: " .. table.concat(summary, ", "))
                    else
                        StockSummaryLabel:Set("Hàng Còn: Đã bán hết toàn bộ!")
                    end
                else
                    StockSummaryLabel:Set("Hàng Trong Shop: Chưa mở kho hàng")
                end
            end)
            task.wait(1.5)
        end
    end)

    SecMerchant:AddToggle("🛒 Tự Động Mua Hàng Merchant (Auto Buy)", Config.AutoBuyMerchant, function(val)
        Config.AutoBuyMerchant = val
    end)

    SecMerchant:AddDropdown("Chọn Vật Phẩm Cần Mua (Multi-Select)", {
        "[Tất Cả Vật Phẩm (All Items)]",
        "Trait Rerolls",
        "Stat Cubes",
        "Stat Prisms",
        "Weapon Rerolls",
        "Souls",
        "Pure Cloud",
        "Chief Toad",
        "Star Fruit (Tất Cả Quả Sao)",
        "Star Fruit [Rainbow]",
        "Star Fruit [Yellow]",
        "Star Fruit [Green]",
        "Star Fruit [Red]",
        "Star Fruit [Blue]",
        "Star Fruit [Pink]",
        "Star Fruit [Dead]"
    }, Config.SelectedShopItems, true, function(val)
        if typeof(val) == "table" then
            Config.SelectedShopItems = val
        elseif typeof(val) == "string" then
            Config.SelectedShopItems = { val }
        end
    end)

    SecMerchant:AddButton("🛍️ Mua Ngay Các Vật Phẩm Đã Chọn (Buy Selected Now)", function()
        pcall(function()
            local bought = purchaseSelectedMerchantItems()
            notify("Merchant Shop", string.format("Đã gửi lệnh mua %d vật phẩm đã chọn!", bought), 3)
        end)
    end)

    SecMerchant:AddButton("🚶 Dịch Chuyển Tới Bob E.O (Teleport to Bob E.O)", function()
        pcall(function()
            local bob = findBobEOModel()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if bob and root then
                local bRoot = bob:FindFirstChild("HumanoidRootPart") or bob.PrimaryPart or bob:FindFirstChildWhichIsA("BasePart")
                if bRoot then
                    releaseCombatLock()
                    root.CFrame = bRoot.CFrame + (bRoot.CFrame.LookVector * 3.5) + Vector3.new(0, 1, 0)
                    root.AssemblyLinearVelocity = Vector3.zero
                    notify("Merchant", "Đã dịch chuyển tới trước mặt Bob E.O!", 3)
                    return
                end
            end
            notify("Merchant", "Không tìm thấy NPC Bob E.O trong map này (Bob E.O ở Lobby)!", 3)
        end)
    end)
end)

-- ------------------------------------------------------------------------
-- TAB 5: TIỆN ÍCH & NHẬN THƯỞNG (MISC & SYSTEM)
-- ------------------------------------------------------------------------
pcall(function()
    local TabMisc = Window:CreateTab("Tiện Ích")
    local SecCodes = TabMisc:CreateSector("Nhận Thưởng & Menu", "left")
    local SecSystem = TabMisc:CreateSector("Hệ Thống, Tối Ưu & Kết Nối", "right")

    SecCodes:AddButton("💎 Nhận Toàn Bộ Thưởng 1-Chạm (Daily / Group / Pass / Quests / Milestones)", function()
        pcall(function()
            claimAllQuests()
            claimAllLevelMilestones()
            claimAllAchievements()
            if RemoteBank and RemoteBank.ClaimDailyReward then RemoteBank.ClaimDailyReward:Fire() end
            if RemoteBank and RemoteBank.ClaimGroupReward then RemoteBank.ClaimGroupReward:Fire() end
            if RemoteBank and RemoteBank.BattlepassClaimAll then RemoteBank.BattlepassClaimAll:Fire() end
            if RemoteBank and RemoteBank.BountyClaim then RemoteBank.BountyClaim:Fire(nil) end
        end)
        notify("Nhận Thưởng", "Đã gửi toàn bộ yêu cầu nhận thưởng Quests, Milestones, Achievements & Pass!", 3)
    end)

    SecCodes:AddToggle("Nút Bật/Tắt Menu Nổi (Floating Button)", Config.FloatingMenuButton ~= false, function(val)
        Config.FloatingMenuButton = val
        setFloatingButtonVisible(val)
    end)

    SecCodes:AddButton("Ẩn / Hiện Giao Diện Menu (Toggle GUI)", function()
        if Window and Window.Frame then
            Window.Frame.Visible = not Window.Frame.Visible
        end
    end)

    SecCodes:AddButton("🐎 Bật / Tắt Thú Cưỡi Ngay (Toggle Mount)", function()
        pcall(function()
            if RemoteBank and RemoteBank.MountToggle then
                RemoteBank.MountToggle:Fire()
            end
        end)
    end)

    SecSystem:AddToggle("⚡ Tùy Chỉnh Tốc Độ Player (Custom WalkSpeed)", Config.CustomPlayerSpeedEnabled, function(val)
        Config.CustomPlayerSpeedEnabled = val
        pcall(function()
            local speed = val and (Config.PlayerWalkSpeed or 26) or 16
            LocalPlayer:SetAttribute("WalkSpeed", speed)
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = speed
            end
        end)
    end)

    SecSystem:AddSlider("🏃 Tốc Độ Chạy Player (WalkSpeed)", 12, 26, 80, 0, function(val)
        Config.PlayerWalkSpeed = math.floor(tonumber(val) or 26)
        if Config.CustomPlayerSpeedEnabled then
            pcall(function()
                LocalPlayer:SetAttribute("WalkSpeed", Config.PlayerWalkSpeed)
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                    LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = Config.PlayerWalkSpeed
                end
            end)
        end
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

    -- Duy trì tốc độ di chuyển nếu bật CustomPlayerSpeedEnabled hoặc AlwaysSprint
    trackConnection(RunService.Heartbeat:Connect(function()
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                if Config.CustomPlayerSpeedEnabled then
                    local targetSpd = math.clamp(tonumber(Config.PlayerWalkSpeed) or 26, 12, 100)
                    if hum.WalkSpeed ~= targetSpd and not isActivelyLockingTarget then
                        hum.WalkSpeed = targetSpd
                        LocalPlayer:SetAttribute("WalkSpeed", targetSpd)
                    end
                elseif Config.AlwaysSprint then
                    if hum.WalkSpeed < 26 and not isActivelyLockingTarget then
                        hum.WalkSpeed = 28
                        LocalPlayer:SetAttribute("WalkSpeed", 28)
                    end
                end
            end
        end
    end))

    SecSystem:AddToggle("Chống Văng Game Khi Treo Máy (Anti-AFK)", Config.AntiAFK, function(val)
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

    SecSystem:AddButton("🚀 Tối Ưu Hóa FPS Tối Đa (Super FPS Boost)", function()
        pcall(function()
            local lighting = game:GetService("Lighting")
            lighting.GlobalShadows = false
            lighting.FogEnd = 9e9
            for _, v in ipairs(lighting:GetChildren()) do
                if v:IsA("PostProcessEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
                    v.Enabled = false
                end
            end
            for _, v in ipairs(game:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                    v.Enabled = false
                elseif v:IsA("Explosion") then
                    v.Visible = false
                end
            end
        end)
        notify("Tối Ưu FPS", "Đã tắt bóng râm, hậu kỳ và toàn bộ hiệu ứng hạt đồ họa!", 3)
    end)

    SecSystem:AddButton("🔄 Vào Lại Server Hiện Tại (Rejoin Server)", function()
        pcall(function()
            local ts = game:GetService("TeleportService")
            ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end)

    SecSystem:AddButton("🌐 Đổi Sang Server Khác (Server Hop)", function()
        pcall(function()
            local http = game:GetService("HttpService")
            local ts = game:GetService("TeleportService")
            local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", game.PlaceId)
            local raw = game:HttpGet(url)
            local data = http:JSONDecode(raw)
            if data and data.data then
                for _, srv in ipairs(data.data) do
                    if srv.id ~= game.JobId and srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers - 1 then
                        ts:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
                        return
                    end
                end
            end
            ts:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)
end)

notify("HelmHub Sẵn Sàng", "Anime CardVerse Combat Suite đã khởi động đầy đủ!", 4)
