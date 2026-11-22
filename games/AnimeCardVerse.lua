--[[
    HelmHub | Anime CardVerse - Production Combat & Universal Automation Suite; Game: Anime CardVerse (PlaceId: 86664636582112 | UniverseId: 10041955829); Author: dj & VANTA
]]

repeat task.wait(0.1) until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local function safeRequire(inst)
    if not inst then return nil end
    local ok, res = pcall(require, inst)
    return (ok and res) and res or nil
end

local LocalPlayer = Players.LocalPlayer
repeat task.wait(0.1) until LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")

-- [1] REVERSE-PATH RESOURCE CLEANUP & ANTI-AFK 3 LỚP
local env = (typeof(getgenv) == "function" and getgenv()) or _G
if env.__HelmAnimeCardVerseCleanup then pcall(env.__HelmAnimeCardVerseCleanup) end

local activeConnections = {}
local isScriptRunning = true
local HookOrig = {
    originalGamepassesOwns = false,
    originalVFXUtilPlayAt = false,
    originalVFXUtilEnemyDeath = false,
    originalParticlesAbsoluteEmit = false,
    originalParticlesEmit = false,
    originalParticlesEnableEmit = false,
    originalPartIclesAbsoluteEmit = false,
    originalPartIclesEmit = false,
    originalPartIclesEnableEmit = false,
    originalSoundUtilPlayAt = false
}
local RT = {
    cachedEnemiesList = {}, lastEnemiesScanClock = 0, lastEnemiesMapRef = nil,
    cachedQuestStatus = nil, lastQuestStatusClock = 0,
    cachedBountyStatus = nil, lastBountyStatusClock = 0, lastBountyHudScanClock = 0,
    lastChallengeLockNotify = 0,
    cachedTopMode = "NormalCombat", cachedTopData = nil, cachedTopRank = 6, lastTopModeClock = 0,
    localSkillCooldowns = {}, pendingSlotRetryUntil = {}, pendingGlobalCastUntil = 0, lastFiredSlotTime = {},
    cachedSlotPowers = {}, lastPowersCacheUpdate = 0,
    activeTelegraphs = {},
    cachedSpawnPartMap = nil, cachedSpawnPart = nil,
    isActivelyLockingTarget = false, wasNoClipActive = false, currentLockedTarget = nil, currentApproachDir = nil,
    cachedCharRef = nil, cachedCharBaseParts = {}, lastMountToggleTime = 0,
    charDescendantConn = nil, stuckLastCheck = 0, stuckLastPos = nil, stuckCount = 0, craftNextColorIndex = 1,
    dropWebhookBuffer = { pending = {}, highestRank = 0, bestColor = 5814783, shouldPing = false, batchTimer = nil },
    suppressDropWebhookUntil = 0, lastMissionCompleteWebhookClock = 0,
    combatMetrics = { hitsRecorded = 0, hitsLastSecond = 0, hitTimestamps = {} }, isMeleeActiveInClient = false,
    pendingDrops = {}, knownDrops = {}, lastDropCleanTime = os.clock(), lastPickupRun = 0, uiLabelCache = {},
    lastQuestWorldTele = 0, lastQuestAcceptAttempt = 0, lastQuestClaimAttempt = 0, lastBountyWorldTele = 0,
    floatingScreenGui = nil, Gamepasses = nil, VFXUtil = nil, PartIclesMod = nil, SoundUtilMod = nil, potatoConn = nil
}

local function trackConnection(conn)
    if conn then table.insert(activeConnections, conn) end
    return conn
end

pcall(function() if typeof(getconnections) == "function" then for _, conn in ipairs(getconnections(LocalPlayer.Idled)) do if typeof(conn.Disable) == "function" then conn:Disable() end end end end)

task.spawn(function()
    local vim = nil; pcall(function() vim = game:GetService("VirtualInputManager") end)
    while isScriptRunning do
        task.wait(120); pcall(function() if VirtualUser then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(50, 50)) end end)
        pcall(function() if vim then vim:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game); task.wait(0.05); vim:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game) end end)
    end
end)

env.__HelmAnimeCardVerseCleanup = function()
    isScriptRunning = false
    for _, conn in ipairs(activeConnections) do pcall(function() conn:Disconnect() end) end
    table.clear(activeConnections)
    if RT.Gamepasses and HookOrig.originalGamepassesOwns then pcall(function() RT.Gamepasses.Owns = HookOrig.originalGamepassesOwns; RT.Gamepasses.BaseMagnetRadius = 17 end) end
    pcall(function() LocalPlayer:SetAttribute("Gamepass_InfiniteMagnet", nil) end); pcall(function() RunService:Set3dRenderingEnabled(true) end)
    if RT.VFXUtil then
        if HookOrig.originalVFXUtilPlayAt then pcall(function() RT.VFXUtil.PlayAt = HookOrig.originalVFXUtilPlayAt end) end
        if HookOrig.originalVFXUtilEnemyDeath then pcall(function() RT.VFXUtil.EnemyDeath = HookOrig.originalVFXUtilEnemyDeath end) end
    end
    if RT.PartIclesMod then
        if HookOrig.originalPartIclesAbsoluteEmit then pcall(function() RT.PartIclesMod.AbsoluteEmit = HookOrig.originalPartIclesAbsoluteEmit end) end
        if HookOrig.originalPartIclesEmit then pcall(function() RT.PartIclesMod.Emit = HookOrig.originalPartIclesEmit end) end
        if HookOrig.originalPartIclesEnableEmit then pcall(function() RT.PartIclesMod.EnableEmit = HookOrig.originalPartIclesEnableEmit end) end
    end
    if RT.SoundUtilMod and HookOrig.originalSoundUtilPlayAt then pcall(function() RT.SoundUtilMod.PlayAt = HookOrig.originalSoundUtilPlayAt end) end
    if RT.potatoConn then pcall(function() RT.potatoConn:Disconnect() end); RT.potatoConn = nil end
    if typeof(setfpscap) == "function" then pcall(function() setfpscap(60) end) end
    pcall(function() local lighting = game:GetService("Lighting"); lighting.GlobalShadows = true; lighting.FogEnd = 1000 end)
    if LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            for _, n in ipairs({ "Helm_TransitLV", "Helm_TransitAttachment", "Helm_AntiGravity" }) do
                local obj = root:FindFirstChild(n)
                if obj then obj:Destroy() end
            end
        end
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end
    end
end

-- [1.5] VÔ HIỆU HÓA AUTO-POSITION KÉO VỀ CHỖ CŨ & CUTSCENE
pcall(function()
    local apConfig = safeRequire(ReplicatedStorage:FindFirstChild("DataModules") and ReplicatedStorage.DataModules:FindFirstChild("World") and ReplicatedStorage.DataModules.World:FindFirstChild("AutoPositionConfig"))
    if apConfig then apConfig.AnchorAttr = "__DisabledAnchorAttr__"; apConfig.MapAttr = "__DisabledMapAttr__"; apConfig.ReturnDistance = 1e9; apConfig.IdleBeforeReturn = 1e9; apConfig.WaypointTimeout = 0 end
    for _, attr in ipairs({ "AutoPositionAnchor", "AutoPositionMap" }) do
        LocalPlayer:SetAttribute(attr, nil)
        trackConnection(LocalPlayer:GetAttributeChangedSignal(attr):Connect(function() if LocalPlayer:GetAttribute(attr) ~= nil then LocalPlayer:SetAttribute(attr, nil) end end))
    end
end)
pcall(function()
    local sc = safeRequire(ReplicatedStorage:FindFirstChild("Utilities") and ReplicatedStorage.Utilities:FindFirstChild("SummonCutscene"))
    if sc then sc.IsPlaying = function() return false end end
end)

-- [2] NẠP THƯ VIỆN GIAO DIỆN (HELMHUB UI INVENTORY)
local library
local function loadLibrary()
    if env.HelmSharedLibraryCache and typeof(env.HelmSharedLibraryCache.fn) == "function" then
        local cached = env.HelmSharedLibraryCache
        env.HelmSharedLibraryCache = nil; local ok, res = pcall(cached.fn)
        if ok and res then return res end
    end
    local isDev = (_G.DevMode == true) or (env and env.DevMode == true)
    if isDev then
        pcall(function() local code = game:HttpGet("http://127.0.0.1:8000/Library/inventory.lua?t=" .. tick()); if code and #code > 100 then library = loadstring(code)() end end)
        if library then return library end
    end
    if isfile and readfile then
        pcall(function()
            if isfile("Library/inventory.lua") then library = loadstring(readfile("Library/inventory.lua"))()
            elseif isfile("inventory.lua") then library = loadstring(readfile("inventory.lua"))() end
        end)
        if library then return library end
    end
    if not library then pcall(function() library = loadstring(game:HttpGet("https://raw.githubusercontent.com/helmgodmommy/HelmHUB/main/Library/inventory.lua"))() end) end
    return library
end

library = loadLibrary()
if not library then warn("[HelmHub | Anime CardVerse] Không thể tải thư viện UI Library!"); return end

local function notify(title, text, duration) pcall(function() StarterGui:SetCore("SendNotification", { Title = tostring(title or "HelmHub | CardVerse"), Text = tostring(text or ""), Duration = tonumber(duration) or 3 }) end) end

-- [3] KẾT NỐI HỆ THỐNG GIAO THỨC MẠNG (REMOTE BANK & CLIENT MODULES)
local Utilities = ReplicatedStorage:FindFirstChild("Utilities")
local DataModules = ReplicatedStorage:FindFirstChild("DataModules")
local RemoteBank = safeRequire(ReplicatedStorage:WaitForChild("RemoteBank", 15))
if not RemoteBank then warn("[HelmHub | Anime CardVerse] Không thể liên kết ReplicatedStorage.RemoteBank!"); return end

local Lib = safeRequire(ReplicatedStorage:FindFirstChild("Lib"))
local MapClient = safeRequire(Utilities and Utilities:FindFirstChild("MapClient"))
local MapUtil = safeRequire(Utilities and Utilities:FindFirstChild("MapUtil"))
local DataClient = safeRequire(Utilities and Utilities:FindFirstChild("DataClient"))
pcall(function()
    if DataClient and typeof(DataClient.Get) == "function" and typeof(DataClient.Initialize) == "function" then
        local cur = DataClient.Get()
        if type(cur) ~= "table" or next(cur) == nil then DataClient.Initialize() end
    end
end)

local InvasionAPI = safeRequire(Utilities and Utilities:FindFirstChild("InvasionAPI"))
local InvasionData = safeRequire(DataModules and DataModules:FindFirstChild("World") and DataModules.World:FindFirstChild("InvasionData"))
local Format = safeRequire(Utilities and Utilities:FindFirstChild("Format"))
local PowersData = safeRequire(DataModules and DataModules:FindFirstChild("Inventory") and DataModules.Inventory:FindFirstChild("Powers"))
local WeaponsData = safeRequire(DataModules and DataModules:FindFirstChild("Inventory") and DataModules.Inventory:FindFirstChild("Weapons"))
local GearsData = safeRequire(DataModules and DataModules:FindFirstChild("Inventory") and DataModules.Inventory:FindFirstChild("Gears"))
local MountsData = safeRequire(DataModules and DataModules:FindFirstChild("Inventory") and DataModules.Inventory:FindFirstChild("Mounts"))
local ItemsData = safeRequire(DataModules and DataModules:FindFirstChild("Economy") and DataModules.Economy:FindFirstChild("Items"))
    or safeRequire(DataModules and DataModules:FindFirstChild("Inventory") and DataModules.Inventory:FindFirstChild("Items"))
local Affinities = safeRequire(DataModules and DataModules:FindFirstChild("Combat") and DataModules.Combat:FindFirstChild("Affinities"))
local EnemyTypes = safeRequire(DataModules and DataModules:FindFirstChild("Combat") and DataModules.Combat:FindFirstChild("EnemyTypes"))
local BuffData = safeRequire(DataModules and DataModules:FindFirstChild("Combat") and DataModules.Combat:FindFirstChild("BuffData"))
local _CastLock = safeRequire(Utilities and Utilities:FindFirstChild("CastLock"))
local StunUtil = safeRequire(Utilities and Utilities:FindFirstChild("StunUtil"))
local ChallengeDataModule = safeRequire(DataModules and DataModules:FindFirstChild("Progression") and DataModules.Progression:FindFirstChild("ChallengeData"))
local MerchantsModule = safeRequire(DataModules and DataModules:FindFirstChild("Economy") and DataModules.Economy:FindFirstChild("Merchants"))

local AttackClientModule = nil
pcall(function()
    local ps = LocalPlayer:WaitForChild("PlayerScripts", 5); local cl = ps and ps:WaitForChild("ClientLoader", 5); local modules = cl and cl:WaitForChild("Modules", 5)
    if modules then AttackClientModule = safeRequire(modules:FindFirstChild("AttackClient")) end
end)
if not AttackClientModule and Lib and typeof(Lib.Find) == "function" then pcall(function() AttackClientModule = Lib.Find("AttackClient") end) end

RT.Gamepasses = safeRequire(DataModules and DataModules:FindFirstChild("Economy") and DataModules.Economy:FindFirstChild("RT.Gamepasses"))
if RT.Gamepasses and type(RT.Gamepasses.Owns) == "function" then
    HookOrig.originalGamepassesOwns = RT.Gamepasses.Owns
    RT.Gamepasses.Owns = function(plr, passName)
        if passName == "InfiniteMagnet" and (plr == nil or plr == LocalPlayer) then return true end
        return HookOrig.originalGamepassesOwns(plr, passName)
    end
    pcall(function() RT.Gamepasses.BaseMagnetRadius = 999999; RT.Gamepasses.InfiniteMagnetRadius = math.huge end)
end
pcall(function() LocalPlayer:SetAttribute("Gamepass_InfiniteMagnet", true) end)

-- [4] CẤU HÌNH TRẠNG THÁI TOÀN CỤC (GLOBAL STATE)
local Config = {
    AutoPunch = false, PunchDelay = 0.35,
    AutoSkills = false, SmartSkills = true, PredictiveAim = true, OverkillProtection = true, ClusterAOE = true,
    SkillSlots = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true }, SkillDelay = 0.15,
    AutoUltimate = false, SmartUltimate = true, SmartUltimateMode = "BossOnly", SmartUltimateClusterCount = 3, UltimateCheckDelay = 1.0,
    TargetMode = "Nearest", SelectedWorld = "Tất Cả World (All Worlds)", SelectedMob = "All", SelectedMobs = {}, ScanRange = 2500, TargetCurrent = nil,
    AutoPosition = false, PositionMode = "BehindMob", MovementStyle = "Glide", GlideSpeed = 25, AutoMount = false, StayMountedCombat = false,
    CombatHeightOffset = 0, HoverHeight = 6, BehindDistance = 1, NoClip = false,
    AutoDodge = false, DodgeMode = "SmartHybrid", DodgeMargin = 6, IsCurrentlyDodging = false,
    AutoMagnet = true,
    AutoInvasion = false, InvasionAutoFarm = true, InvasionAutoTeleport = true, InvasionAutoSkills = true,
    InvasionPreferredWorld = "Tự Động (Theo Server)", InvasionFarmUntilCap = false, InvasionDecisionType = "WaitNext",
    AutoQuest = false, QuestPriorityOverBounty = true, QuestAutoTeleport = true, QuestAutoTeleportWorld = true,
    QuestAutoSkills = true, QuestAutoAccept = true, QuestAutoClaim = true, QuestlineSelected = "Tự Động (Theo Tiến Độ)",
    PriorityPreset = "Mặc Định: Quest > Invasion > Bounty > Challenge > Mission",
    PriorityOrder = { "Quest", "Invasion", "Bounty", "Challenge", "Mission" },
    CustomPrioritySlots = { "Quest", "Invasion", "Bounty", "Challenge", "Mission" },
    AutoBounty = false, BountyAutoPunch = true, BountyAutoTeleport = true, BountyAutoSkills = true,
    AutoMission = false, AutoMissionFarm = false, MissionAutoTeleport = false, MissionAutoSkills = true,
    MissionGamemode = "Mission", MissionWorld = "Nemu's Village", MissionAct = 1, MissionMode = "Normal",
    ChallengeTier = "Regular", ChallengeSlot = 1, GauntletChamber = 1, AutoReplayMission = false, MissionDecisionType = "Retry",
    AutoChallenge = false, ChallengeSelectedTier = "Tất Cả (Daily > Weekly > Regular)",
    PartyRole = "Tắt (Solo)", PartyTargetPlayers = { "[Tất Cả Người Chơi]" }, PartyWaitMembers = true,
    AutoSummon = false, SummonBanner = "Standard Powers", SummonCount = 1,
    AutoSellGears = false, SelectedSellGears = { "[Tất Cả Gear]" },
    KeepBestGearPerName = true, ProtectHighRollGears = true,
    AutoBuyMerchant = false, SelectedShopItems = { "Trait Rerolls", "Stat Cubes", "Stat Prisms" },
    AutoCraftColorFruits = false, AutoCraftRainbowFruit = false,
    CraftColorStrategy = "Cân Bằng 5 Hệ (Ưu Tiên Màu Ít Nhất)", CraftNextColorIndex = 1,
    CraftManualRecipe = "Star Fruit [Rainbow]", CraftManualAmount = 1,
    AntiAFK = true, AlwaysSprint = false, CustomPlayerSpeedEnabled = false, PlayerWalkSpeed = 26, FloatingMenuButton = true,
    HeadlessMode = false, SuppressHitFX = false, PotatoGraphics = false, DisableLightingEffects = false, SuperBoostFPS = false, TargetFPSCap = 60,
    CustomCodeInput = "",
    WebhookURL = "", WebhookEnabled = false, WebhookDiscordUserId = "", WebhookPingRare = false,
    WebhookOnSummon = true, WebhookMinRarity = "Mythic Trở Lên", WebhookOnMission = true,
    WebhookOnDrops = true, WebhookPeriodic = false, WebhookInterval = 15
}

trackConnection(LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(50, 50))
            if Workspace.CurrentCamera then VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame); task.wait(1); VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame) end
        end)
    end
end))

-- [5] TARGET ACQUISITION & MAP DETECTOR
local function getMobRoot(mob)
    if not mob then return nil end
    return mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso") or mob.PrimaryPart or mob:FindFirstChild("Hitbox") or mob:FindFirstChildWhichIsA("BasePart")
end

local function getPlayerCurrency(key)
    local val = 0
    pcall(function()
        if DataClient and typeof(DataClient.Get) == "function" then val = tonumber(DataClient.Get(key)) or 0 end
        if val <= 0 and LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild(key) then val = tonumber(LocalPlayer.leaderstats[key].Value) or 0 end
    end)
    return val
end

local function getCurrentMapName()
    local attrMap = LocalPlayer:GetAttribute("CurrentMap")
    if type(attrMap) == "string" and attrMap ~= "" then return attrMap end
    if MapClient and typeof(MapClient.GetCurrentMap) == "function" then
        local ok, map = pcall(MapClient.GetCurrentMap)
        if ok and type(map) == "string" and map ~= "" then return map end
    end
    if MapUtil and typeof(MapUtil.GetMapOfPlayer) == "function" then
        local ok, map = pcall(MapUtil.GetMapOfPlayer, LocalPlayer)
        if ok and type(map) == "string" and map ~= "" then return map end
    end
    local mapFolder = Workspace:FindFirstChild("Map")
    if mapFolder then
        if mapFolder:FindFirstChild("Lobby") then return "Lobby" end
        for _, child in ipairs(mapFolder:GetChildren()) do if child.Name ~= "MapStorage" and child.Name ~= "Terrain" then return child.Name end end
    end
    return "Lobby"
end

local function isCurrentMapLobby()
    local m = getCurrentMapName()
    if m == "Lobby" then return true end
    local attrMap = LocalPlayer:GetAttribute("CurrentMap")
    if attrMap == "Lobby" then return true end
    if MapClient and typeof(MapClient.GetCurrentMap) == "function" then
        local ok, res = pcall(MapClient.GetCurrentMap)
        if ok and res == "Lobby" then return true end
    end
    local mapFolder = Workspace:FindFirstChild("Map")
    if mapFolder and mapFolder:FindFirstChild("Lobby") then return true end
    return false
end

local function getActiveMapFolder()
    local mapRoot = Workspace:FindFirstChild("Map")
    if not mapRoot then return nil end
    local currentMap = getCurrentMapName()
    if currentMap and currentMap ~= "" and currentMap ~= "Lobby" then
        local direct = mapRoot:FindFirstChild(currentMap)
        if direct then return direct end
        local curLower = currentMap:lower()
        for _, child in ipairs(mapRoot:GetChildren()) do
            if child.Name ~= "Lobby" and child.Name ~= "MapStorage" and child.Name ~= "Terrain" then
                local cLower = child.Name:lower()
                if curLower:find(cLower, 1, true) or cLower:find(curLower, 1, true) then return child end
            end
        end
    end
    for _, child in ipairs(mapRoot:GetChildren()) do
        if child.Name ~= "Lobby" and child.Name ~= "MapStorage" and child.Name ~= "Terrain" then
            if child:FindFirstChild("Enemies") or child:FindFirstChild("SpawnPart", true) then return child end
        end
    end
    for _, child in ipairs(mapRoot:GetChildren()) do if child.Name ~= "Lobby" and child.Name ~= "MapStorage" and child.Name ~= "Terrain" then return child end end
    return mapRoot:FindFirstChild("Lobby")
end

local currentWaveInfo = { wave = 0, totalWaves = 0, enemiesAlive = 0, enemiesTotal = 0, title = "" }

local function isInInvasion()
    if isCurrentMapLobby() then return false end
    local gm = LocalPlayer:GetAttribute("Gamemode")
    if gm == "Invasion" then return true end
    if type(gm) == "string" and gm ~= "" then return false end
    -- Fallback theo title CHỈ khi HUD phó bản còn hiện (tránh title cũ kẹt lại sau khi đã về Lobby)
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local inM = pGui and pGui:FindFirstChild("MainHUD") and pGui.MainHUD:FindFirstChild("Missions") and pGui.MainHUD.Missions:FindFirstChild("InMissionUI")
    if not (inM and inM.Visible) then return false end
    local title = ((currentWaveInfo and currentWaveInfo.title) or ""):lower()
    return title:find("invasion") ~= nil or title:find("egris") ~= nil
end

-- Rời phó bản (Gamemode bị xoá) -> reset wave/title để không bị nhận nhầm là vẫn đang trong Invasion
trackConnection(LocalPlayer:GetAttributeChangedSignal("Gamemode"):Connect(function()
    local gm = LocalPlayer:GetAttribute("Gamemode")
    if gm == nil or gm == "" then currentWaveInfo.wave, currentWaveInfo.totalWaves, currentWaveInfo.enemiesAlive, currentWaveInfo.enemiesTotal, currentWaveInfo.title = 0, 0, 0, 0, "" end
end))

local function getInvasionStatus()
    local now = workspace:GetServerTimeNow(); local activeWorld, isActive, timeLeft, timeRatio, timeUntilNext, nextRatio = nil, false, 0, 0, 0, 0
    if InvasionAPI and typeof(InvasionAPI.IsActive) == "function" then
        isActive = InvasionAPI.IsActive(); activeWorld = InvasionAPI.GetActiveWorld()
        if isActive then timeLeft, timeRatio = InvasionAPI.GetTimeLeft()
        else timeUntilNext, nextRatio = InvasionAPI.GetTimeUntilNext() end
    else
        local w = ReplicatedStorage:GetAttribute("InvasionWorld"); local startsAt = ReplicatedStorage:GetAttribute("InvasionStartsAt") or 0
        local endsAt = ReplicatedStorage:GetAttribute("InvasionEndsAt") or 0; local nextAt = ReplicatedStorage:GetAttribute("InvasionNextAt") or 0
        if type(w) == "string" and w ~= "" and type(endsAt) == "number" and endsAt > now then
            isActive, activeWorld = true, w; timeLeft = math.max(endsAt - now, 0); timeRatio = math.clamp(timeLeft / math.max(endsAt - startsAt, 1), 0, 1)
        elseif type(nextAt) == "number" and nextAt > now then
            timeUntilNext = math.max(nextAt - now, 0)
            nextRatio = math.clamp(1 - (timeUntilNext / 1800), 0, 1)
        end
    end
    local gemsReceived, gemsMax, rerollsReceived, rerollsMax = 0, 10000, 0, 100
    if DataClient and typeof(DataClient.Get) == "function" and InvasionData and InvasionData.DailyLimits then
        pcall(function()
            local dailyData = DataClient.Get(InvasionData.DailyLimits.DataKey or "InvasionDaily"); gemsReceived = InvasionData.DailyLimits.GetReceived(dailyData, "Gems", now)
            rerollsReceived = InvasionData.DailyLimits.GetReceived(dailyData, "Trait Rerolls", now); gemsMax = InvasionData.DailyLimits.GetMax("Gems") or 10000
            rerollsMax = InvasionData.DailyLimits.GetMax("Trait Rerolls") or 100
        end)
    end
    return {
        isActive = isActive, activeWorld = activeWorld, timeLeft = timeLeft, timeRatio = timeRatio,
        timeUntilNext = timeUntilNext, nextRatio = nextRatio, inInvasion = isInInvasion(), currentMap = getCurrentMapName(),
        bossName = "Egris", bossHpPct = 1,
        gems = { received = gemsReceived, max = gemsMax }, rerolls = { received = rerollsReceived, max = rerollsMax }
    }
end

local function isInMission()
    if isCurrentMapLobby() then return false end
    local mapName = getCurrentMapName()
    if mapName == "Lobby" then return false end
    local gmAttr = LocalPlayer:GetAttribute("Gamemode")
    if type(gmAttr) == "string" and gmAttr ~= "" then return true end
    if mapName and (string.find(mapName, "-", 1, true) or string.find(mapName, "Act", 1, true)) then return true end
    local pGui = LocalPlayer:FindFirstChild("PlayerGui"); local missionsUI = pGui and pGui:FindFirstChild("MainHUD") and pGui.MainHUD:FindFirstChild("Missions")
    if missionsUI then
        local inM = missionsUI:FindFirstChild("InMissionUI")
        if inM and inM.Visible then return true end
    end
    return false
end

local function isAlliedSummonOrFriendly(mob, mRoot)
    if not mob then return true end
    if mob:GetAttribute("IsAlly") == true or mob:GetAttribute("Invulnerable") == true or mob:GetAttribute("Summon") == true or mob:GetAttribute("IsSummon") == true then return true end
    if mob:GetAttribute("OwnerUserId") ~= nil or mob:GetAttribute("Owner") ~= nil or mob:GetAttribute("Summoner") ~= nil then return true end
    local root = mRoot or getMobRoot(mob)
    local hb = root and root:FindFirstChild("Healthbar")
    if hb then
        local allyGrad = hb:FindFirstChild("AllyGradient", true)
        if allyGrad and allyGrad:IsA("UIGradient") and allyGrad.Enabled then return true end
    end
    return false
end

local function isValidCombatTarget(mob, activeMapFolder)
    if not mob or not mob.Parent then return false end
    if Players:GetPlayerFromCharacter(mob) or mob == LocalPlayer.Character then return false end
    local mobNameLower = mob.Name:lower()
    local isTotem = (mobNameLower:find("totem") ~= nil) or (mob:GetAttribute("EnemyType") == "Totem") or (mob:FindFirstChild("Totem Active") ~= nil)
    if not isTotem and mob:FindFirstChildWhichIsA("ProximityPrompt", true) then return false end
    local pName = mob.Parent and mob.Parent.Name:lower() or ""
    if pName == "npcs" or pName == "npc" or pName == "summons" or pName == "allies" or pName == "shadows" then return false end
    local hum = mob:FindFirstChildOfClass("Humanoid")
    if not isTotem then
        if not hum or hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then return false end
    else
        if hum and (hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead) then return false end
        local attrHp = mob:GetAttribute("Health")
        if type(attrHp) == "number" and attrHp <= 0 then return false end
    end
    local mRoot = getMobRoot(mob)
    if not mRoot or mRoot.Position.Y < -45 or mRoot.Position.Y > 1500 then return false end
    if not isTotem and isAlliedSummonOrFriendly(mob, mRoot) then return false end
    if isInMission() or isInInvasion() then return true end
    local mapRoot = Workspace:FindFirstChild("Map")
    local lobbyFolder = mapRoot and mapRoot:FindFirstChild("Lobby")
    if lobbyFolder and mob:IsDescendantOf(lobbyFolder) then return false end
    local playerStorage = LocalPlayer:FindFirstChild("MapStorage")
    if playerStorage and mob:IsDescendantOf(playerStorage) then return false end
    local mapFolder = activeMapFolder or getActiveMapFolder()
    if mapFolder and mapFolder.Name ~= "Lobby" and mob:IsDescendantOf(mapFolder) then return true end
    return (mapRoot and mob:IsDescendantOf(mapRoot)) or false
end

local function getAllEnemies()
    local now = os.clock(); local inMission, inInvasion = isInMission(), isInInvasion(); local currentMapFolder = getActiveMapFolder()
    if not inMission and not inInvasion and currentMapFolder and currentMapFolder.Name == "Lobby" then table.clear(RT.cachedEnemiesList); return RT.cachedEnemiesList end
    if (now - RT.lastEnemiesScanClock < 0.14) and (currentMapFolder == RT.lastEnemiesMapRef) and #RT.cachedEnemiesList > 0 then
        local validCached = {}
        for _, mob in ipairs(RT.cachedEnemiesList) do if isValidCombatTarget(mob, currentMapFolder) then table.insert(validCached, mob) end end
        if #validCached > 0 then RT.cachedEnemiesList = validCached; return RT.cachedEnemiesList end
    end
    RT.lastEnemiesScanClock = now; RT.lastEnemiesMapRef = currentMapFolder; local enemiesList, scanned = {}, {}
    local function tryAddModel(obj, mapCtx) if obj and obj:IsA("Model") and not scanned[obj] and isValidCombatTarget(obj, mapCtx) then scanned[obj] = true; table.insert(enemiesList, obj) end end
    local function scanContainerFast(container, mapCtx)
        if not container then return end
        local enemiesSub = container:FindFirstChild("Enemies") or container:FindFirstChild("Mobs") or container:FindFirstChild("Alive")
        if enemiesSub then for _, child in ipairs(enemiesSub:GetChildren()) do tryAddModel(child, mapCtx) end end
        local camps = container:FindFirstChild("Campsites") or container:FindFirstChild("Camps")
        if camps then
            for _, desc in ipairs(camps:GetDescendants()) do
                if desc:IsA("Model") then tryAddModel(desc, mapCtx) end
            end
        end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") then
                tryAddModel(child, mapCtx)
            elseif child:IsA("Folder") and child.Name ~= "Map" and child.Name ~= "Details" and child.Name ~= "Props" and child.Name ~= "Decorations" and child.Name ~= "Buildings" and child.Name ~= "Lighting" and child.Name ~= "Spawns" then
                for _, sub in ipairs(child:GetChildren()) do
                    if sub:IsA("Model") then
                        tryAddModel(sub, mapCtx)
                    elseif sub:IsA("Folder") then
                        for _, nested in ipairs(sub:GetChildren()) do
                            if nested:IsA("Model") then tryAddModel(nested, mapCtx) end
                        end
                    end
                end
            end
        end
        if #enemiesList == 0 then for _, desc in ipairs(container:GetDescendants()) do if desc:IsA("Model") then tryAddModel(desc, mapCtx) end end end
    end
    if currentMapFolder then scanContainerFast(currentMapFolder, currentMapFolder) end
    if inInvasion then
        local wsCamps = Workspace:FindFirstChild("Campsites") or Workspace:FindFirstChild("Camps")
        if wsCamps then
            for _, desc in ipairs(wsCamps:GetDescendants()) do
                if desc:IsA("Model") then tryAddModel(desc, nil) end
            end
        end
    end
    if #enemiesList == 0 then
        local mapRoot = Workspace:FindFirstChild("Map")
        if mapRoot then
            for _, child in ipairs(mapRoot:GetChildren()) do
                if child ~= currentMapFolder and (inMission or inInvasion or (child.Name ~= "Lobby" and child.Name ~= "MapStorage" and child.Name ~= "Terrain")) then scanContainerFast(child, child) end
            end
        end
    end
    if (inMission or inInvasion) and #enemiesList == 0 then
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") then
                tryAddModel(obj, nil)
            elseif obj:IsA("Folder") and obj.Name ~= "Terrain" and obj.Name ~= "Camera" and obj.Name ~= "VFX" then
                for _, sub in ipairs(obj:GetChildren()) do tryAddModel(sub, nil) end
            end
        end
    end
    RT.cachedEnemiesList = enemiesList
    return enemiesList
end

local MobToWorldMap = {
    ["Alien Scout"] = "Nemu's Village", ["Alien Soldier"] = "Nemu's Village", ["Alien Officer"] = "Nemu's Village",
    ["Captain Shinyu"] = "Nemu's Village", ["Freezer"] = "Nemu's Village",
    ["Grants"] = "Hollow World", ["Yummy"] = "Hollow World", ["Grimmjay"] = "Hollow World",
    ["Arruru"] = "Hollow World", ["Aizo"] = "Hollow World",
    ["Goblin"] = "Demon Citadel", ["Goblin Shaman"] = "Demon Citadel", ["High Grunt"] = "Demon Citadel",
    ["Ferrite"] = "Demon Citadel", ["Belu"] = "Demon Citadel"
}

pcall(function()
    local enemiesFolder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Enemies")
    if enemiesFolder then for _, worldFolder in ipairs(enemiesFolder:GetChildren()) do for _, mobModel in ipairs(worldFolder:GetChildren()) do if mobModel:IsA("Model") then MobToWorldMap[mobModel.Name] = worldFolder.Name end end end end
end)

-- [5B] QUESTLINES, BOUNTY, CHALLENGES & MILESTONES
local QuestlinesFallback = {
    ["Nemu's Questline"] = {
        world = "Nemu's Village", unlocksWorld = "Hollow World", npcName = "Nemu",
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
        world = "Hollow World", unlocksWorld = "Demon Citadel", npcName = "Kisky",
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
        world = "Demon Citadel", unlocksWorld = nil, npcName = "Sang Woo",
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
        state = "None", questlineId = "Nemu's Questline", questlineName = "Nemu's Questline",
        world = "Nemu's Village", unlocksWorld = "Hollow World", npcName = "Nemu",
        stepIndex = 1, totalSteps = 6, stepTitle = "Nemu Quest #1", targetEnemy = "Alien Scout",
    progress = 0, target = 5, allCompleted = false, completedQuestlines = {}, activeStepsSummary = "" }; local completedMap, questlinesProgress = {}, {}
    if DataClient and typeof(DataClient.Get) == "function" then
        local ok1, comp = pcall(DataClient.Get, "CompletedQuestlines")
        if ok1 and type(comp) == "table" then completedMap = comp end
        local ok2, qp = pcall(DataClient.Get, "QuestProgress")
        if ok2 and type(qp) == "table" and type(qp.questlines) == "table" then questlinesProgress = qp.questlines end
    end
    result.completedQuestlines = completedMap; local targetQuestlineId = nil
    if Config.QuestlineSelected and not Config.QuestlineSelected:find("Tự Động") then
        if Config.QuestlineSelected:find("Nemu") then targetQuestlineId = "Nemu's Questline"
        elseif Config.QuestlineSelected:find("Kisky") then targetQuestlineId = "Kisky's Questline"
        elseif Config.QuestlineSelected:find("Sang Woo") then targetQuestlineId = "Sang Woo's Questline" end
    end
    if not targetQuestlineId then
        if not completedMap["Nemu's Questline"] then targetQuestlineId = "Nemu's Questline"
        elseif not completedMap["Kisky's Questline"] then targetQuestlineId = "Kisky's Questline"
        elseif not completedMap["Sang Woo's Questline"] then targetQuestlineId = "Sang Woo's Questline"
        else result.allCompleted, result.state = true, "AllCompleted"; return result end
    elseif completedMap[targetQuestlineId] then
        result.allCompleted, result.state, result.questlineId = true, "AllCompleted", targetQuestlineId
        return result
    end
    local qConfig = QuestlinesFallback[targetQuestlineId]
    if not qConfig then return result end
    result.questlineId, result.questlineName = targetQuestlineId, targetQuestlineId
    result.world, result.unlocksWorld, result.npcName, result.totalSteps = qConfig.world, qConfig.unlocksWorld, qConfig.npcName, #qConfig.steps
    local pData = questlinesProgress[targetQuestlineId]
    if not pData then
        result.state, result.stepIndex = "NeedAccept", 1; local step1 = qConfig.steps[1]
        if step1 then
            result.stepTitle = step1.title
            for en, count in pairs(step1.kills) do result.targetEnemy, result.target, result.progress = en, count, 0; break end
        end
        return result
    end
    local stepIdx = tonumber(pData.questIndex) or 1; result.stepIndex = stepIdx
    if stepIdx > #qConfig.steps then result.state = "ReadyToClaim"; return result end
    local currentStepDef = qConfig.steps[stepIdx]
    if not currentStepDef then result.state = "AllCompleted"; return result end
    result.stepTitle = currentStepDef.title; local stepComplete, firstEnemy, firstProg, firstReq, summaryList = true, nil, 0, 1, {}
    local playerKills = (type(pData.kills) == "table") and pData.kills or {}
    for en, reqCount in pairs(currentStepDef.kills) do
        local cur = tonumber(playerKills[en]) or 0; table.insert(summaryList, string.format("%s (%d/%d)", en, cur, reqCount))
        if cur < reqCount then
            stepComplete = false
            if not firstEnemy then firstEnemy, firstProg, firstReq = en, cur, reqCount end
        end
    end
    result.activeStepsSummary = table.concat(summaryList, ", ")
    if stepComplete then result.state, result.progress, result.target = "ReadyToClaim", firstReq, firstReq else result.state, result.targetEnemy, result.progress, result.target = "InProgress", firstEnemy, firstProg, firstReq end
    return result
end

local function isQuestOverrideActive()
    if not Config.AutoQuest or isInMission() or isInInvasion() then return false, nil end
    local now = os.clock()
    if not RT.cachedQuestStatus or (now - RT.lastQuestStatusClock > 0.45) then RT.lastQuestStatusClock = now; RT.cachedQuestStatus = getQuestlineStatus() end
    local status = RT.cachedQuestStatus
    if not status or status.allCompleted or status.state == "AllCompleted" or status.state == "None" then return false, status end
    return true, status
end

local function claimAllQuests()
    pcall(function()
        if not DataClient or typeof(DataClient.Get) ~= "function" then return end
        local qp = DataClient.Get("QuestProgress")
        if not qp then return end
        for _, cat in ipairs({ { key = "daily", name = "Daily" }, { key = "weekly", name = "Weekly" } }) do
            local sub = qp[cat.key]
            if sub and type(sub.progress) == "table" and type(sub.claimed) == "table" then
                for idxStr, _ in pairs(sub.progress) do if not sub.claimed[idxStr] then RemoteBank.QuestClaimReward:Fire({ category = cat.name, questIndex = tonumber(idxStr) or idxStr }) end end
            end
        end
        local qStatus = getQuestlineStatus()
        if qStatus and qStatus.state == "ReadyToClaim" and qStatus.questlineId then RemoteBank.QuestClaimReward:Fire(qStatus.questlineId) end
    end)
end

local function getBountyTaskStatus()
    local now = os.clock()
    if RT.cachedBountyStatus and (now - RT.lastBountyStatusClock < 0.75) then return RT.cachedBountyStatus end
    RT.lastBountyStatusClock = now
    if DataClient and typeof(DataClient.Get) == "function" then
        local ok, bp = pcall(DataClient.Get, "BountyProgress")
        if ok and type(bp) == "table" then
            local claimedCount = tonumber(bp.claimed) or 0
            if bp.completed == true or claimedCount >= 10 then RT.cachedBountyStatus = { state = "Completed", accepted = true, completed = true, position = 10, total = 10, claimed = claimedCount }; return RT.cachedBountyStatus end
            local bountiesList = type(bp.questline) == "table" and type(bp.questline.bounties) == "table" and bp.questline.bounties or nil
            local idx = tonumber(bp.index) or 1; local currentEntry = bountiesList and bountiesList[idx] or nil
            if bp.accepted ~= true then
                RT.cachedBountyStatus = {
                    state = "NeedAccept", accepted = false, completed = false, position = idx, total = 10, claimed = claimedCount,
                    enemy = currentEntry and currentEntry.enemy or nil,
                    world = currentEntry and (currentEntry.world or MobToWorldMap[currentEntry.enemy]) or nil,
                    progress = tonumber(bp.progress) or 0, target = currentEntry and tonumber(currentEntry.target) or 1
                }
                return RT.cachedBountyStatus
            end
            if currentEntry then
                local prog, req = tonumber(bp.progress) or 0, tonumber(currentEntry.target) or 1; local enemyName = tostring(currentEntry.enemy or "")
                RT.cachedBountyStatus = {
                    state = (prog >= req) and "ReadyToClaim" or "InProgress", accepted = true, completed = false,
                    position = tonumber(currentEntry.position) or idx, total = 10, claimed = claimedCount,
                    enemy = enemyName, world = currentEntry.world or MobToWorldMap[enemyName],
                progress = math.min(prog, req), target = req }
                return RT.cachedBountyStatus
            end
        end
    end
    if now - RT.lastBountyHudScanClock < 2.5 then return RT.cachedBountyStatus end
    RT.lastBountyHudScanClock = now
    local mainHud = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("MainHUD")
    if mainHud then
        for _, desc in ipairs(mainHud:GetDescendants()) do
            if desc:IsA("TextLabel") then
                if desc.Name == "QuestName" and desc.Text:find("^Bounty%s+%d+/%d+") then
                    local posStr, totStr = desc.Text:match("^Bounty%s+(%d+)/(%d+)")
                    local descLabel = desc.Parent and desc.Parent:FindFirstChild("Description")
                    if descLabel and descLabel:IsA("TextLabel") then
                        local enemyName, progStr, reqStr = descLabel.Text:match("^(.-)%s*%(([%d,]+)/([%d,]+)%)$")
                        if enemyName and progStr and reqStr then
                            local prog, req = tonumber((progStr:gsub(",", ""))) or 0, tonumber((reqStr:gsub(",", ""))) or 1
                            RT.cachedBountyStatus = {
                                state = (prog >= req) and "ReadyToClaim" or "InProgress", accepted = true, completed = false,
                                position = tonumber(posStr) or 1, total = tonumber(totStr) or 10, claimed = (tonumber(posStr) or 1) - 1,
                            enemy = enemyName, world = MobToWorldMap[enemyName], progress = prog, target = req }
                            return RT.cachedBountyStatus
                        end
                    end
                elseif desc.Text:find("^Bounty%s+%d+$") then
                    local posStr = desc.Text:match("^Bounty%s+(%d+)$"); local container = desc.Parent and desc.Parent.Parent
                    if container then
                        for _, sub in ipairs(container:GetDescendants()) do
                            if sub:IsA("TextLabel") and sub.Text:find("^Defeat%s+[%d,]+/[%d,]+%s+.+") then
                                local progStr, reqStr, enemyName = sub.Text:match("^Defeat%s+([%d,]+)/([%d,]+)%s+(.+)$")
                                if progStr and reqStr and enemyName then
                                    local prog, req = tonumber((progStr:gsub(",", ""))) or 0, tonumber((reqStr:gsub(",", ""))) or 1
                                    RT.cachedBountyStatus = {
                                        state = (prog >= req) and "ReadyToClaim" or "InProgress", accepted = true, completed = false,
                                        position = tonumber(posStr) or 1, total = 10, claimed = (tonumber(posStr) or 1) - 1,
                                        enemy = enemyName, world = MobToWorldMap[enemyName], progress = prog, target = req
                                    }
                                    return RT.cachedBountyStatus
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return RT.cachedBountyStatus
end

local function isBountyOverrideActive()
    if not Config.AutoBounty or isInMission() then return false, nil end
    local status = getBountyTaskStatus()
    if not status or status.completed or status.state == "Completed" then return false, status end
    return true, status
end

local function getServerUnixTime() local ok, t = pcall(function() return math.floor(workspace:GetServerTimeNow()) end); return (ok and type(t) == "number" and t > 0) and t or os.time() end

local function getChallengeSlotStatus(tier, slot)
    local now = getServerUnixTime(); local claimed, exhausted, lockReason, pickWorld, pickAct, clearsUsed, dailyLimit = false, false, nil, nil, nil, 0, nil
    pcall(function()
        local period = ChallengeDataModule and typeof(ChallengeDataModule.GetPeriod) == "function" and ChallengeDataModule.GetPeriod(tier, now) or 0
        if ChallengeDataModule and typeof(ChallengeDataModule.GetDailyLimit) == "function" then dailyLimit = ChallengeDataModule.GetDailyLimit(tier) end
        if DataClient and typeof(DataClient.Get) == "function" then
            local prog = DataClient.Get("ChallengeProgress")
            if type(prog) == "table" and type(prog[tier]) == "table" then
                local tProg = prog[tier]
                if tProg.period == period and type(tProg.claimed) == "table" then claimed = (tProg.claimed[tostring(slot)] == true) end
                local day = ChallengeDataModule and typeof(ChallengeDataModule.GetDay) == "function" and ChallengeDataModule.GetDay(now) or 0
                if tProg.day == day and type(tProg.counts) == "table" then clearsUsed = tonumber(tProg.counts[tostring(slot)]) or 0 end
            end
            if ChallengeDataModule and typeof(ChallengeDataModule.GetPick) == "function" then pickWorld, pickAct = ChallengeDataModule.GetPick(tier, period, slot) end
            if ChallengeDataModule and typeof(ChallengeDataModule.GetLockReason) == "function" and pickWorld then lockReason = ChallengeDataModule.GetLockReason(tier, pickWorld, pickAct, DataClient.Get("CompletedActs")) end
        end
        exhausted = claimed or (dailyLimit ~= nil and clearsUsed >= dailyLimit)
    end)
    return { tier = tier, slot = slot, claimed = claimed, exhausted = exhausted, lockReason = lockReason, world = pickWorld, act = pickAct, clearsUsed = clearsUsed, dailyLimit = dailyLimit, playable = (not exhausted) and (lockReason == nil) }
end

local function getPlayableChallengeTarget()
    local sel = tostring(Config.ChallengeSelectedTier or "Tất Cả (Daily -> Weekly -> Regular)"); local candidates = {}
    if sel:find("Daily") and not sel:find("Tất Cả") then
        candidates = { { "Daily", 1 } }
    elseif sel:find("Weekly") and not sel:find("Tất Cả") then
        candidates = { { "Weekly", 1 } }
    elseif sel:find("Regular") and not sel:find("Tất Cả") then
        local chosenSlot = tonumber(sel:match("Slot%s*(%d+)")) or tonumber(sel:match("(%d+)")) or 1; candidates = { { "Regular", chosenSlot } }
        for s = 1, 3 do if s ~= chosenSlot then table.insert(candidates, { "Regular", s }) end end
    else
        candidates = { { "Daily", 1 }, { "Weekly", 1 }, { "Regular", 1 }, { "Regular", 2 }, { "Regular", 3 } }
    end
    local firstLocked = nil
    for _, c in ipairs(candidates) do
        local st = getChallengeSlotStatus(c[1], c[2])
        if st.playable then return st, nil end
        if not st.exhausted and st.lockReason and not firstLocked then firstLocked = st end
    end
    return nil, firstLocked
end

local function getChallengeInfo()
    local now, dailyRem, weeklyRem, regularRem = getServerUnixTime(), 0, 0, 0
    if ChallengeDataModule and typeof(ChallengeDataModule.GetTimeRemaining) == "function" then
        pcall(function() dailyRem = ChallengeDataModule.GetTimeRemaining("Daily", now) or 0; weeklyRem = ChallengeDataModule.GetTimeRemaining("Weekly", now) or 0; regularRem = ChallengeDataModule.GetTimeRemaining("Regular", now) or 0 end)
    end
    local dSt = getChallengeSlotStatus("Daily", 1); local wSt = getChallengeSlotStatus("Weekly", 1); local regPlayable = 0
    for s = 1, 3 do if getChallengeSlotStatus("Regular", s).playable then regPlayable = regPlayable + 1 end end
    return { dailyTime = dailyRem, weeklyTime = weeklyRem, regularTime = regularRem, dailyClaimed = dSt.exhausted, dailyLocked = dSt.lockReason, weeklyClaimed = wSt.exhausted, weeklyLocked = wSt.lockReason, regularPlayable = regPlayable }
end

local currentPartyState = { active = false, leaderId = nil, members = {}, mission = nil }

local function isPartyHostMode() local r = tostring(Config.PartyRole or ""); return r:find("Chủ Phòng") ~= nil or r:find("Host") ~= nil end

local function isPartyGuestMode() local r = tostring(Config.PartyRole or ""); return r:find("Thành Viên") ~= nil or r:find("Guest") ~= nil end

local function getPartyMemberCount()
    if not currentPartyState.active or type(currentPartyState.members) ~= "table" then return 1 end
    return math.max(1, #currentPartyState.members)
end

local function isUserInMyParty(userId)
    if userId == LocalPlayer.UserId then return true end
    if not currentPartyState.active or type(currentPartyState.members) ~= "table" then return false end
    for _, m in ipairs(currentPartyState.members) do if type(m) == "table" and tonumber(m.userId) == tonumber(userId) then return true end end
    return false
end

local function amIPartyGuest()
    if isPartyHostMode() then return false end
    if isPartyGuestMode() then return true end
    return currentPartyState.active and currentPartyState.leaderId ~= nil and currentPartyState.leaderId ~= LocalPlayer.UserId
end

local function isPlayerSelectedForParty(plrName, plrUserId)
    if type(Config.PartyTargetPlayers) ~= "table" or #Config.PartyTargetPlayers == 0 then return true end
    local nLower = tostring(plrName or ""):lower()
    local idStr = tostring(plrUserId or "")
    for _, sel in ipairs(Config.PartyTargetPlayers) do
        local sLower = tostring(sel or ""):lower()
        if sLower:find("tất cả người chơi") or sLower:find("all players") then return true end
        if (nLower ~= "" and (sLower == nLower or sLower:find(nLower, 1, true) or nLower:find(sLower, 1, true))) or (idStr ~= "" and sLower:find(idStr, 1, true)) then return true end
    end
    return false
end

local function getMatchingServerTeammates()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LocalPlayer and isPlayerSelectedForParty(plr.Name, plr.UserId) then table.insert(list, plr) end end
    return list
end

local function inviteSelectedPlayersToParty(partyMissionPayload)
    local invited = 0
    pcall(function()
        if partyMissionPayload and RemoteBank and RemoteBank.PartySetMission then RemoteBank.PartySetMission:Fire(partyMissionPayload) end
        if not RemoteBank or not RemoteBank.PartyInvite then return end
        for _, plr in ipairs(getMatchingServerTeammates()) do if not isUserInMyParty(plr.UserId) then RemoteBank.PartyInvite:Fire({ userId = plr.UserId }); invited = invited + 1 end end
    end)
    return invited
end

local function preparePartyBeforeLaunch(partyMissionPayload)
    if not isPartyHostMode() then return end
    local teammates = getMatchingServerTeammates()
    -- Nếu cấu hình người chơi cụ thể nhưng họ chưa kịp xuất hiện trong Players (đang load từ map cũ về sảnh)
    if #teammates == 0 and type(Config.PartyTargetPlayers) == "table" and #Config.PartyTargetPlayers > 0 then
        local hasSpecific = false
        for _, t in ipairs(Config.PartyTargetPlayers) do
            local s = tostring(t):lower()
            if s ~= "" and not s:find("tất cả người chơi") and not s:find("all players") then hasSpecific = true; break end
        end
        if hasSpecific and Config.PartyWaitMembers then
            local waitDeadline = os.clock() + 3.0
            while isScriptRunning and os.clock() < waitDeadline do
                task.wait(0.4)
                teammates = getMatchingServerTeammates()
                if #teammates > 0 then break end
            end
        end
    end
    if #teammates == 0 then return end
    local missingCount = 0
    for _, plr in ipairs(teammates) do if not isUserInMyParty(plr.UserId) then missingCount = missingCount + 1 end end
    if partyMissionPayload and RemoteBank and RemoteBank.PartySetMission then
        pcall(function() RemoteBank.PartySetMission:Fire(partyMissionPayload) end)
        task.wait(0.5)
    end
    if missingCount > 0 then
        local invited = inviteSelectedPlayersToParty(partyMissionPayload)
        if invited > 0 then notify("Co-op Party (Chủ Phòng)", string.format("Đã gửi lời mời tổ đội tới %d người chơi! Đang đợi đồng đội vào...", invited), 3) end
        if Config.PartyWaitMembers then
            local deadline = os.clock() + 6.0
            local lastReinvite = os.clock()
            while isScriptRunning and isPartyHostMode() and os.clock() < deadline do
                local allJoined = true
                for _, plr in ipairs(getMatchingServerTeammates()) do if not isUserInMyParty(plr.UserId) then allJoined = false; break end end
                if allJoined or getPartyMemberCount() >= 2 then break end
                if os.clock() - lastReinvite >= 2.5 then
                    lastReinvite = os.clock()
                    inviteSelectedPlayersToParty(partyMissionPayload)
                end
                task.wait(0.25)
            end
        end
        task.wait(0.3)
    end
end

if RemoteBank.PartyUpdate and RemoteBank.PartyUpdate.OnClientEvent then
    trackConnection(RemoteBank.PartyUpdate.OnClientEvent:Connect(function(partyData)
        if type(partyData) == "table" and type(partyData.members) == "table" then
            currentPartyState.active = (#partyData.members > 1) or (partyData.leaderId ~= nil); currentPartyState.leaderId = tonumber(partyData.leaderId)
            currentPartyState.members = partyData.members; currentPartyState.mission = partyData.mission
        else
            currentPartyState.active = false
            currentPartyState.leaderId = nil; currentPartyState.members = {}; currentPartyState.mission = nil
        end
    end))
end

if RemoteBank.PartyInviteResult and RemoteBank.PartyInviteResult.OnClientEvent then
    trackConnection(RemoteBank.PartyInviteResult.OnClientEvent:Connect(function(inviteData)
        if not isPartyGuestMode() or type(inviteData) ~= "table" or type(inviteData.fromUserId) ~= "number" then return end
        local fromName = tostring(inviteData.fromName or ""); local fromId = inviteData.fromUserId
        if not isPlayerSelectedForParty(fromName, fromId) then return end
        task.spawn(function()
            pcall(function()
                local dlg = safeRequire(Utilities and Utilities:FindFirstChild("Dialogue"))
                if dlg and typeof(dlg.Close) == "function" then pcall(dlg.Close) end
                local fm = safeRequire(Utilities and Utilities:FindFirstChild("FrameManager"))
                if fm and typeof(fm.Close) == "function" then pcall(fm.Close, "Dialogue") end
                local pGui = LocalPlayer:FindFirstChild("PlayerGui"); local pInvUI = pGui and pGui:FindFirstChild("PartyInviteUI")
                if pInvUI and pInvUI:FindFirstChild("Prompt") then pInvUI.Prompt.Visible = false end
                if RemoteBank.PartyRespond then RemoteBank.PartyRespond:Fire({ fromUserId = fromId, accept = true }) end
                Config.AutoMissionFarm = true; Config.MissionAutoTeleport = true
                notify("Co-op Party (Thành Viên)", string.format("Đã tự động chấp nhận lời mời tổ đội từ @%s!", fromName ~= "" and fromName or tostring(fromId)), 3)
            end)
        end)
    end))
end

local function launchConfiguredChallenge()
    if amIPartyGuest() then return false end
    local playable, lockedSt = getPlayableChallengeTarget()
    if not playable then
        if os.clock() - RT.lastChallengeLockNotify > 25 then
            RT.lastChallengeLockNotify = os.clock()
            if lockedSt then
                notify("Auto Challenge (Đang Khóa)", string.format("%s (Slot %d - %s) chưa mở khóa: %s", tostring(lockedSt.tier), tonumber(lockedSt.slot) or 1, tostring(lockedSt.world or "?"), tostring(lockedSt.lockReason)), 5)
            else
                notify("Auto Challenge", "Đã hoàn thành hết toàn bộ Challenge khả dụng trong chu kỳ này!", 4)
            end
        end
        return false
    end
    pcall(function()
        if RemoteBank and RemoteBank.MatchmakeCancel then pcall(function() RemoteBank.MatchmakeCancel:Fire(nil) end) end
        preparePartyBeforeLaunch({ world = playable.world or "Nemu's Village", act = tonumber(playable.act) or 1, tier = playable.tier, index = playable.slot })
        if RemoteBank and RemoteBank.MissionLaunch then
            RemoteBank.MissionLaunch:Fire({ gamemode = "Challenge", tier = playable.tier, index = playable.slot })
            notify("Auto Challenge", string.format("Đang vào %s Challenge (Slot %d - %s Act %s)!", tostring(playable.tier), tonumber(playable.slot) or 1, tostring(playable.world or "Map"), tostring(playable.act or "?")), 3)
        end
    end)
    return true
end

local function claimAllLevelMilestones() pcall(function() if RemoteBank and RemoteBank.ClaimLevelMilestone then for lvl = 5, 50, 5 do RemoteBank.ClaimLevelMilestone:Fire(lvl) end end end) end

local function claimAllAchievements()
    pcall(function()
        for _, cat in ipairs({ "General", "Combat", "Progression", "Collection", "Social" }) do
            if RemoteBank and RemoteBank.AchievementClaimMilestone then RemoteBank.AchievementClaimMilestone:Fire(cat) end
            if RemoteBank and RemoteBank.AchievementClaimTask then for taskId = 1, 30 do RemoteBank.AchievementClaimTask:Fire(cat, taskId) end end
        end
    end)
end

local ALL_PRIORITY_KEYS = { "Quest", "Invasion", "Bounty", "Challenge", "Mission" }

local function parsePriorityKey(label)
    local s = tostring(label or ""):lower()
    if s:find("quest") or s:find("cốt truyện") then return "Quest"
    elseif s:find("invasion") or s:find("xâm lược") then return "Invasion"
    elseif s:find("bounty") or s:find("tiền thưởng") then return "Bounty"
    elseif s:find("challenge") or s:find("thử thách") then return "Challenge"
    elseif s:find("mission") or s:find("phó bản") then return "Mission" end
    return nil
end

local function getResolvedPriorityOrder()
    local preset = tostring(Config.PriorityPreset or ""); local rawList
    if preset:find("Tùy Chỉnh") or preset:find("Custom") then
        rawList = Config.CustomPrioritySlots or Config.PriorityOrder or ALL_PRIORITY_KEYS
    elseif preset:find("Săn Sự Kiện") then
        rawList = { "Invasion", "Challenge", "Quest", "Bounty", "Mission" }
    elseif preset:find("Cày Thử Thách") then
        rawList = { "Challenge", "Invasion", "Bounty", "Quest", "Mission" }
    elseif preset:find("Cày Phó Bản") then
        rawList = { "Mission", "Invasion", "Challenge", "Quest", "Bounty" }
    else
        rawList = { "Quest", "Invasion", "Bounty", "Challenge", "Mission" }
    end
    local order, seen = {}, {}
    for _, item in ipairs(rawList) do
        local k = parsePriorityKey(item) or item
        if k and not seen[k] then seen[k] = true; table.insert(order, k) end
    end
    for _, k in ipairs(ALL_PRIORITY_KEYS) do if not seen[k] then seen[k] = true; table.insert(order, k) end end
    Config.PriorityOrder = order
    return order
end

local function isInvasionReadyToEnter()
    if not Config.AutoInvasion then return false, nil end
    local invSt = getInvasionStatus()
    if not invSt or not invSt.isActive then return false, invSt end
    -- Cổng sắp đóng (< 90s) thì không vào: qua giờ đóng server khoá quái bất tử & kẹt người chơi
    if (tonumber(invSt.timeLeft) or 0) < 90 then return false, invSt end
    local capped = Config.InvasionFarmUntilCap and (invSt.gems.received >= invSt.gems.max and invSt.rerolls.received >= invSt.rerolls.max)
    if capped then return false, invSt end
    return true, invSt
end

local function getTopRequestedPriorityMode()
    local now = os.clock()
    if now - RT.lastTopModeClock < 0.35 then return RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank end
    RT.lastTopModeClock = now; local order = getResolvedPriorityOrder()
    local invReady, invSt = isInvasionReadyToEnter()
    if invReady and invSt and invSt.isActive then
        RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank = "Invasion", invSt, 1
        return RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank
    end
    for rank, key in ipairs(order) do
        if key == "Quest" then
            local ok, st = isQuestOverrideActive()
            if ok then RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank = "Quest", st, rank; return RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank end
        elseif key == "Invasion" then
            if invReady then RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank = "Invasion", invSt, rank; return RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank end
        elseif key == "Bounty" then
            local ok, st = isBountyOverrideActive()
            if ok then RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank = "Bounty", st, rank; return RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank end
        elseif key == "Challenge" then
            if Config.AutoChallenge then
                local playable = getPlayableChallengeTarget()
                if playable then RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank = "Challenge", playable, rank; return RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank end
            end
        elseif key == "Mission" then
            if Config.AutoMission then RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank = "MissionQueue", nil, rank; return RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank end
        end
    end
    RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank = "NormalCombat", nil, 6
    return RT.cachedTopMode, RT.cachedTopData, RT.cachedTopRank
end

local function getActivePriorityMode()
    if isInInvasion() then return "InvasionCombat", nil, 0 end
    if isInMission() and (Config.AutoMissionFarm or Config.AutoMission or Config.AutoChallenge) then local gm = tostring(LocalPlayer:GetAttribute("Gamemode") or ""); return (gm == "Challenge") and "Challenge" or "Mission", nil, 0 end
    return getTopRequestedPriorityMode()
end

local function getSpecificSelectedMobs()
    local specific = {}
    if type(Config.SelectedMobs) == "table" then
        for _, name in ipairs(Config.SelectedMobs) do
            local s = tostring(name)
            if s ~= "" and s ~= "All" and s ~= "Tất Cả Quái (All Mobs)" then table.insert(specific, s) end
        end
    end
    if #specific == 0 and type(Config.SelectedMob) == "string" and Config.SelectedMob ~= "" and Config.SelectedMob ~= "All" and Config.SelectedMob ~= "Tất Cả Quái (All Mobs)" then table.insert(specific, Config.SelectedMob) end
    return specific
end

local function isMobNameMatch(candidateName, targetName)
    if not candidateName or not targetName then return false end
    local c = tostring(candidateName):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local t = tostring(targetName):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if c == t then return true end
    local cClean = c:gsub("%b()", ""):gsub("%b[]", ""):gsub("%b{}", ""):gsub("[#_%-]%d+$", ""):gsub("%s+%d+$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return cClean == t
end

local function isMobSelectedByFilter(mobName)
    if not mobName then return false end
    local specific = getSpecificSelectedMobs()
    if #specific == 0 then return true end
    for _, sel in ipairs(specific) do if isMobNameMatch(mobName, sel) then return true end end
    return false
end

local function getSelectedMobsDisplay() local specific = getSpecificSelectedMobs(); return (#specific > 0) and table.concat(specific, ", ") or nil end

local function getBestTarget()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local inInvasion, inMission = isInInvasion(), isInMission(); local currentMapFolder = getActiveMapFolder()
    if not inMission and not inInvasion and (not currentMapFolder or currentMapFolder.Name == "Lobby") then return nil end
    local enemies = getAllEnemies()
    if #enemies == 0 then return nil end
    local questActive, questStatus = isQuestOverrideActive(); local bountyActive, bountyStatus = isBountyOverrideActive(); local topMode = getTopRequestedPriorityMode()
    local effectiveRange = (inInvasion or inMission or bountyActive or questActive) and math.max(Config.ScanRange or 2500, 6000) or (Config.ScanRange or 2500)
    local bestTarget, bestScore = nil, math.huge
    for _, mob in ipairs(enemies) do
        if isValidCombatTarget(mob, currentMapFolder) then
            local mRoot = getMobRoot(mob); local mHum = mob:FindFirstChildOfClass("Humanoid")
            local mobNameLower = mob.Name:lower()
            local isTotem = mobNameLower:find("totem") ~= nil or mob:GetAttribute("EnemyType") == "Totem" or (mob:FindFirstChild("Totem Active") ~= nil)
            if mRoot and (mHum or isTotem) then
                local shouldSkip = false
                if not (inInvasion and Config.InvasionAutoFarm) and not (inMission and (Config.AutoMission or Config.AutoMissionFarm or Config.AutoChallenge)) then
                    local qEnemy = not inMission and not inInvasion and questActive and questStatus and questStatus.targetEnemy
                    local bEnemy = not inMission and not inInvasion and bountyActive and bountyStatus and bountyStatus.enemy ~= "" and bountyStatus.enemy
                    if (topMode == "Quest" and qEnemy) or (topMode ~= "Bounty" and qEnemy) then shouldSkip = not isMobNameMatch(mob.Name, qEnemy)
                    elseif bEnemy then shouldSkip = not isMobNameMatch(mob.Name, bEnemy)
                    else shouldSkip = not isMobSelectedByFilter(mob.Name) end
                end
                if not shouldSkip then
                    local dist = (mRoot.Position - root.Position).Magnitude
                    if dist <= effectiveRange then
                        local score = dist
                        if inInvasion then
                            local isBoss = mobNameLower:find("egris") or (mHum and mHum.MaxHealth > 50000)
                            if isBoss then
                                score = dist - 500000
                            elseif isTotem then
                                -- Ưu tiên tuyệt đối phá Totem tại Camp hiện tại (trong bán kính 160 studs)
                                if dist <= 160 then
                                    score = dist - 400000
                                else
                                    score = dist - 80000
                                end
                            else
                                score = dist
                            end
                        elseif Config.TargetMode == "LowestHP" then
                            local hpRatio = mHum and (mHum.Health / math.max(1, mHum.MaxHealth)) or 1
                            score = dist + hpRatio * 40
                        elseif Config.TargetMode == "BossFirst" then
                            local isBoss = (mHum and mHum.MaxHealth > 5000) or mobNameLower:find("boss"); score = isBoss and (dist - 100000) or dist
                        end
                        if score < bestScore then bestScore, bestTarget = score, mob end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- [6] NETWORK-LEVEL COOLDOWN ENGINE & SMART SKILL / ULTIMATE ENGINE

local function flushPowerShotRemotes(powerName)
    pcall(function()
        local powersFolder = ReplicatedStorage:FindFirstChild("Powers")
        if not powersFolder then return end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart"); local hum = char and char:FindFirstChildOfClass("Humanoid")
        local cf = (root and root.CFrame) or CFrame.new(); local look = cf.LookVector
        if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Running, true) end) end
        if root and root.Anchored then root.Anchored = false end
        local targets = {}
        if type(powerName) == "string" and #powerName > 0 then
            local pInst = powersFolder:FindFirstChild(powerName, true)
            if pInst then table.insert(targets, pInst) end
        else
            for _, desc in ipairs(powersFolder:GetDescendants()) do if desc.Name == "Handler" and desc:IsA("ModuleScript") and desc.Parent then table.insert(targets, desc.Parent) end end
        end
        for _, pInst in ipairs(targets) do
            local handler = pInst:FindFirstChild("Handler"); local shotRemote = handler and handler:FindFirstChild("ShotRemote")
            if shotRemote and shotRemote:IsA("RemoteEvent") then
                local pInstName = pInst.Name
                local arg = ((pInstName:find("Dragon Fear") ~= nil) or (pInstName == "Beast Fang")) and cf or look; pcall(function() shotRemote:FireServer(arg) end)
                task.delay(0.05, function() pcall(function() shotRemote:FireServer(arg) end) end)
            end
        end
    end)
end

task.defer(function() flushPowerShotRemotes(nil) end)

if RemoteBank.CastResponse and RemoteBank.CastResponse.OnClientEvent then
    trackConnection(RemoteBank.CastResponse.OnClientEvent:Connect(function(res)
        if type(res) == "table" and res.hotbar then
            if res.host and res.host ~= LocalPlayer then return end
            local slot = tonumber(res.hotbar) or res.hotbar
            RT.pendingSlotRetryUntil[slot], RT.lastFiredSlotTime[slot] = nil, nil; local cdVal = tonumber(res.cooldown)
            if cdVal and cdVal > 0 then RT.localSkillCooldowns[slot] = os.clock() + cdVal end
        end
    end))
end

if RemoteBank.CooldownUpdate and RemoteBank.CooldownUpdate.OnClientEvent then
    trackConnection(RemoteBank.CooldownUpdate.OnClientEvent:Connect(function(res)
        if type(res) == "table" and res.hotbar then
            local slot = tonumber(res.hotbar) or res.hotbar; local remaining = tonumber(res.remaining) or 0; RT.pendingSlotRetryUntil[slot] = nil
            if remaining > 0 then RT.localSkillCooldowns[slot] = os.clock() + remaining; RT.lastFiredSlotTime[slot] = nil else RT.localSkillCooldowns[slot] = nil end
        end
    end))
end

local function getHotbarSlotFrame(slot)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local bottomFrame = pg and pg:FindFirstChild("MainHUD") and pg.MainHUD:FindFirstChild("Bottom") and pg.MainHUD.Bottom:FindFirstChild("Frame")
    if not bottomFrame then return nil end
    return bottomFrame:FindFirstChild("Hotbar" .. tostring(slot)) or bottomFrame:FindFirstChild(tostring(slot))
end

local function isSkillOnCooldown(slot)
    local now = os.clock()
    if RT.pendingSlotRetryUntil[slot] and now < RT.pendingSlotRetryUntil[slot] then return true end
    local slotFrame = getHotbarSlotFrame(slot); local innerFrame = slotFrame and slotFrame:FindFirstChild("Frame")
    if innerFrame then
        local locked = innerFrame:FindFirstChild("Locked")
        if locked and locked.Visible then return true end
        local cardInfo = innerFrame:FindFirstChild("CardInformation")
        local titleLbl = cardInfo and cardInfo:FindFirstChild("TitleFrame") and cardInfo.TitleFrame:FindFirstChild("Title")
        if titleLbl and (titleLbl.Text == "EMPTY" or titleLbl.Text == "") then return true end
        local cd = innerFrame:FindFirstChild("Cooldown")
        if cd then
            if cd.Visible then return true end
            RT.localSkillCooldowns[slot] = nil
            return false
        end
    end
    return (RT.localSkillCooldowns[slot] and now < RT.localSkillCooldowns[slot]) or false
end

local function canCastUltimate()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local leaderBuff = pg and pg:FindFirstChild("MainHUD") and pg.MainHUD:FindFirstChild("Bottom") and pg.MainHUD.Bottom:FindFirstChild("LeaderBuff")
    local cd = leaderBuff and leaderBuff:FindFirstChild("Frame") and leaderBuff.Frame:FindFirstChild("Cooldown")
    return not (cd and cd.Visible)
end

local function isPlayerCastLocked()
    if StunUtil and typeof(StunUtil.IsStunned) == "function" then
        local ok, stunned = pcall(StunUtil.IsStunned, LocalPlayer)
        if ok and stunned then return true end
    end
    if LocalPlayer:GetAttribute("Stunned") == true or LocalPlayer:GetAttribute("Frozen") == true then return true end
    return false
end

local function refreshEquippedPowersCache()
    local now = os.clock()
    if (now - RT.lastPowersCacheUpdate) < 0.5 then return RT.cachedSlotPowers end
    RT.lastPowersCacheUpdate = now; local equipped, allPowers = nil, {}
    if DataClient and typeof(DataClient.Get) == "function" then
        local okEquip, eq = pcall(DataClient.Get, "Equipped_Powers"); local okPowers, ap = pcall(DataClient.Get, "Powers")
        if okEquip and type(eq) == "table" then equipped = eq end
        if okPowers and type(ap) == "table" then allPowers = ap end
    end
    for slot = 1, 5 do
        local uuid = equipped and (equipped[slot] or equipped[tostring(slot)]) or nil
        if typeof(uuid) == "table" and uuid.UUID then uuid = uuid.UUID end
        local card = (uuid and uuid ~= "") and allPowers[uuid] or nil
        local pName = card and (card.Power or card.Name) or (type(uuid) == "string" and PowersData and PowersData[uuid] and uuid or nil)
        if not pName then
            local slotFrame = getHotbarSlotFrame(slot); local cardInfo = slotFrame and slotFrame:FindFirstChild("Frame") and slotFrame.Frame:FindFirstChild("CardInformation")
            local titleLbl = cardInfo and cardInfo:FindFirstChild("TitleFrame") and cardInfo.TitleFrame:FindFirstChild("Title")
            if titleLbl and type(titleLbl.Text) == "string" and titleLbl.Text ~= "" and titleLbl.Text ~= "EMPTY" then pName = titleLbl.Text end
        end
        if pName and pName ~= "" and pName ~= "EMPTY" then
            local staticData = PowersData and PowersData[pName] or nil; local lowerName = string.lower(pName)
            local isBuff = lowerName:find("buff") ~= nil or lowerName:find("logia") ~= nil or lowerName:find("compass") ~= nil or lowerName:find("aura") ~= nil or lowerName:find("awakening") ~= nil
            if not isBuff and BuffData and typeof(BuffData.Get) == "function" and BuffData.Get(pName) then isBuff = true end
            RT.cachedSlotPowers[slot] = {
                Slot = slot, UUID = uuid or pName, Name = pName, Static = staticData,
                Stats = staticData and staticData.Stats or {}, Element = staticData and staticData.Element or nil,
                Type = staticData and staticData.Type or nil, CastDuration = (staticData and tonumber(staticData.CastDuration)) or 1.0,
            IsBuff = isBuff }
        else
            RT.cachedSlotPowers[slot] = nil
        end
    end
    return RT.cachedSlotPowers
end

local function computeSmartTargetPosition(target, pData)
    local tRoot = getMobRoot(target)
    if not tRoot then return Vector3.zero end
    local basePos = tRoot.Position
    if Config.PredictiveAim then
        local vel = Vector3.zero; pcall(function() vel = tRoot.AssemblyLinearVelocity end)
        if vel.Magnitude > 2 and vel.Magnitude < 150 then basePos = basePos + (vel * math.clamp((pData and pData.CastDuration or 0.8) * 0.35, 0.1, 0.5)) end
    end
    if Config.ClusterAOE and target and target.Parent then
        local clusterCentroid, clusterCount = basePos, 1
        for _, enemy in ipairs(getAllEnemies()) do
            if enemy ~= target and isValidCombatTarget(enemy) then
                local eRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
                if eRoot and (eRoot.Position - basePos).Magnitude <= 28 then clusterCentroid = clusterCentroid + eRoot.Position; clusterCount = clusterCount + 1 end
            end
        end
        if clusterCount >= 2 then basePos = clusterCentroid / clusterCount end
    end
    return basePos
end

local function evaluateSmartSkillScore(slotIdx, target, currentHP, maxHP)
    if isSkillOnCooldown(slotIdx) then return -1 end
    local pData = refreshEquippedPowersCache()[slotIdx]
    if not pData then return 50 - slotIdx end
    local stats = pData.Stats or {}
    local dmg, cd, multiHit = tonumber(stats.Damage) or 30, tonumber(stats.Cooldown) or 8, tonumber(stats.MultiHit) or 1
    if pData.IsBuff then
        local isActive = false
        if BuffData and typeof(BuffData.IsActive) == "function" then pcall(function() isActive = BuffData.IsActive(LocalPlayer, pData.Name) end) end
        return isActive and 10 or 100000
    end
    local score = ((dmg * multiHit) / math.max(cd, 1)) * 10
    if target and pData.Element then
        local affinityMult, elemNames = 1, {}; local elems = (type(pData.Element) == "table") and pData.Element or { pData.Element }
        for _, el in ipairs(elems) do
            local elName = (type(el) == "table" and el.name) or (type(el) == "string" and el) or nil
            if elName then table.insert(elemNames, elName) end
        end
        local typeName = (type(pData.Type) == "table" and pData.Type.name) or (type(pData.Type) == "string" and pData.Type) or nil
        if Affinities and typeof(Affinities.GetMultiplier) == "function" and #elemNames > 0 then
            local ok, m = pcall(Affinities.GetMultiplier, target, elemNames, typeName)
            if ok and type(m) == "number" then affinityMult = m end
        else
            for _, elName in ipairs(elemNames) do
                local val = target:GetAttribute("Affinity_" .. elName)
                if type(val) == "number" then affinityMult = affinityMult * val end
            end
        end
        score = score * affinityMult
    end
    score = math.max(score, 15)
    if Config.OverkillProtection and currentHP and maxHP and maxHP > 0 and (currentHP / maxHP) <= 0.08 and cd >= 7 then score = score * 0.05 end
    if Config.AutoDodge and Config.IsCurrentlyDodging and (pData.CastDuration or 1) > 1.2 then score = score * 0.1 end
    return math.max(score, 1)
end

local function shouldSmartCastUltimate(target)
    if not canCastUltimate() or not isValidCombatTarget(target) then return false end
    if not Config.SmartUltimate then return true end
    local mode = Config.SmartUltimateMode or "BossOnly"
    if mode == "Any" then return true end
    local isBoss = false
    if EnemyTypes and typeof(EnemyTypes.IsBoss) == "function" then
        local ok, res = pcall(EnemyTypes.IsBoss, target)
        if ok and res then isBoss = true end
    end
    if not isBoss then
        local eType = target:GetAttribute("EnemyType")
        isBoss = (eType == "Boss" or eType == "Mini Boss" or target.Name:find("Boss") ~= nil or target.Name:find("Egris") ~= nil or target.Name:find("Freezer") ~= nil or target.Name:find("Aizo") ~= nil or target.Name:find("Belu") ~= nil)
    end
    if mode == "BossOnly" then return isBoss end
    if mode == "Cluster" then
        if isBoss then return true end
        local tRoot = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
        if not tRoot then return false end
        local count = 0
        for _, enemy in ipairs(getAllEnemies()) do
            if isValidCombatTarget(enemy) then
                local eRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
                if eRoot and (eRoot.Position - tRoot.Position).Magnitude <= 32 then count = count + 1 end
            end
        end
        return count >= (Config.SmartUltimateClusterCount or 3)
    end
    return true
end

-- [7] AUTO DODGE ENGINE (NÉ VÙNG ĐỎ TELEGRAPH)
local function cleanExpiredTelegraphs(now)
    now = now or os.clock()
    for id, entry in pairs(RT.activeTelegraphs) do
        if (now - entry.born) > (entry.maxDuration or 3.5) then
            RT.activeTelegraphs[id] = nil
        end
    end
end

if RemoteBank.BossTelegraph and RemoteBank.BossTelegraph.OnClientEvent then
    trackConnection(RemoteBank.BossTelegraph.OnClientEvent:Connect(function(msg)
        if type(msg) ~= "table" then return end
        local now = os.clock()
        cleanExpiredTelegraphs(now)
        if msg.op == "pulse" then
            if typeof(msg.cf) == "CFrame" then
                local pid = "pulse_" .. tostring(now) .. "_" .. tostring(math.random(1000, 9999))
                RT.activeTelegraphs[pid] = { id = pid, shape = { Type = "Circle", Radius = tonumber(msg.radius) or 10 }, follow = false, cf = msg.cf, born = now, maxDuration = (tonumber(msg.duration) or 0.6) + 0.35 }
            end
            return
        end
        local id = msg.id
        if id == nil then return end
        if msg.op == "new" and type(msg.shape) == "table" then
            RT.activeTelegraphs[id] = {
                id = id, shape = msg.shape, boss = (typeof(msg.boss) == "Instance") and msg.boss or nil,
                foot = tonumber(msg.foot) or 0, follow = (typeof(msg.boss) == "Instance"),
            cf = (typeof(msg.cf) == "CFrame") and msg.cf or nil, born = now, maxDuration = 3.5 }
        elseif msg.op == "place" then
            local entry = RT.activeTelegraphs[id]
            if entry and typeof(msg.cf) == "CFrame" then entry.follow, entry.cf, entry.born, entry.maxDuration = false, msg.cf, now, 1.8 end
        elseif msg.op == "flash" or msg.op == "remove" then
            RT.activeTelegraphs[id] = nil
        end
    end))
end

local function resolveTelegraphOrigin(entry)
    if entry.follow and entry.boss and entry.boss.Parent then
        local bRoot = entry.boss:FindFirstChild("HumanoidRootPart")
        if bRoot then
            local pos = bRoot.Position - Vector3.new(0, entry.foot or 0, 0)
            local look = bRoot.CFrame.LookVector * Vector3.new(1, 0, 1); look = (look.Magnitude < 0.01) and Vector3.new(0, 0, -1) or look.Unit; entry.cf = CFrame.lookAt(pos, pos + look)
            return entry.cf
        end
    end
    return entry.cf
end

local function computeDodgeEscape(testPos, fallbackOriginY)
    local now = os.clock()
    cleanExpiredTelegraphs(now)
    if not Config.AutoDodge then Config.IsCurrentlyDodging = false; return nil end
    local margin = Config.DodgeMargin or 6
    local isThreatened, escapePos, threatOriginY = false, testPos, fallbackOriginY or testPos.Y
    for id, entry in pairs(RT.activeTelegraphs) do
        local originCF, shape = resolveTelegraphOrigin(entry), entry.shape
            if typeof(originCF) == "CFrame" and type(shape) == "table" then
                local localPos = originCF:PointToObjectSpace(escapePos)
                if math.abs(localPos.Y) <= 22 then
                    local sType = shape.Type
                    if sType == "Circle" then
                        local safeR = (tonumber(shape.Radius) or 9) + margin
                        local planarDist = math.sqrt(localPos.X * localPos.X + localPos.Z * localPos.Z)
                        if planarDist < safeR then
                            isThreatened, threatOriginY = true, math.max(threatOriginY, originCF.Position.Y); local dx = (planarDist > 0.1) and (localPos.X / planarDist) or 0
                            local dz = (planarDist > 0.1) and (localPos.Z / planarDist) or 1
                            local worldSafe = originCF:PointToWorldSpace(Vector3.new(dx * (safeR + 3), 0, dz * (safeR + 3)))
                            escapePos = Vector3.new(worldSafe.X, escapePos.Y, worldSafe.Z)
                        end
                    elseif sType == "Box" then
                        local halfW = ((tonumber(shape.Width) or 6) * 0.5) + margin; local len, fwd = tonumber(shape.Length) or 28, tonumber(shape.Forward) or 0
                        if math.abs(localPos.X) < halfW and localPos.Z >= -(fwd + len + margin) and localPos.Z <= (-fwd + margin) then
                            isThreatened, threatOriginY = true, math.max(threatOriginY, originCF.Position.Y); local sideSign = (localPos.X >= 0) and 1 or -1
                            local worldSafe = originCF:PointToWorldSpace(Vector3.new(sideSign * (halfW + 3.5), 0, math.min(localPos.Z, 4)))
                            escapePos = Vector3.new(worldSafe.X, escapePos.Y, worldSafe.Z)
                        end
                    elseif sType == "Sector" then
                        local safeR = (tonumber(shape.Radius) or 10) + margin; local planarDist = math.sqrt(localPos.X * localPos.X + localPos.Z * localPos.Z)
                        if planarDist < safeR and localPos.Z < (margin + 2) then
                            isThreatened, threatOriginY = true, math.max(threatOriginY, originCF.Position.Y)
                            local worldSafe = originCF:PointToWorldSpace(Vector3.new(0, 0, math.max(margin + 4, 8))); escapePos = Vector3.new(worldSafe.X, escapePos.Y, worldSafe.Z)
                        end
                    end
                end
            end
        end
    local teleFolder = Workspace:FindFirstChild("BossTelegraphs")
    if teleFolder then
        for _, desc in ipairs(teleFolder:GetDescendants()) do
            if desc:IsA("BasePart") then
                local lp = desc.CFrame:PointToObjectSpace(escapePos); local hx, hz = (desc.Size.X * 0.5) + margin, (desc.Size.Z * 0.5) + margin
                if math.abs(lp.X) < hx and math.abs(lp.Z) < hz and math.abs(lp.Y) <= 22 then
                    isThreatened, threatOriginY = true, math.max(threatOriginY, desc.Position.Y)
                    local pushX = (lp.X >= 0 and 1 or -1) * (hx + 3); local worldSafe = desc.CFrame:PointToWorldSpace(Vector3.new(pushX, 0, lp.Z))
                    escapePos = Vector3.new(worldSafe.X, escapePos.Y, worldSafe.Z)
                end
            end
        end
    end
    Config.IsCurrentlyDodging = isThreatened
    if not isThreatened then return nil end
    if Config.DodgeMode == "SkyEvade" then return Vector3.new(testPos.X, threatOriginY + 17.5, testPos.Z)
    elseif Config.DodgeMode == "Sidestep" then return Vector3.new(escapePos.X, testPos.Y, escapePos.Z)
    else return Vector3.new(escapePos.X, threatOriginY + 16.5, escapePos.Z) end
end

-- [7.5] AUTO POSITIONING & SMOOTH COMBAT ENGINE
local function getMapSpawnPart(activeMap)
    if not activeMap then return nil end
    if activeMap ~= RT.cachedSpawnPartMap or (RT.cachedSpawnPart and not RT.cachedSpawnPart.Parent) then RT.cachedSpawnPartMap = activeMap; RT.cachedSpawnPart = activeMap:FindFirstChild("SpawnPart", true) end
    return RT.cachedSpawnPart
end

local function getSafeStandingY(_xzPos, mobRootY, activeMap, customOffset)
    local minFloorY = -25; local spawnPart = getMapSpawnPart(activeMap)
    if spawnPart and spawnPart:IsA("BasePart") then minFloorY = spawnPart.Position.Y - 12 end
    local offset = (customOffset ~= nil) and customOffset or (Config.CombatHeightOffset or 0)
    return math.max((mobRootY or 5) + offset, minFloorY)
end

local function getCharacterBaseParts(char)
    if not char then return {} end
    if char ~= RT.cachedCharRef or #RT.cachedCharBaseParts == 0 then
        RT.cachedCharRef = char
        table.clear(RT.cachedCharBaseParts)
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("BasePart") then
                table.insert(RT.cachedCharBaseParts, child)
            elseif child:IsA("Accessory") then
                local h = child:FindFirstChild("Handle")
                if h and h:IsA("BasePart") then table.insert(RT.cachedCharBaseParts, h) end
            end
        end
        local mount = char:FindFirstChild("Mount")
        if mount then
            for _, part in ipairs(mount:GetDescendants()) do
                if part:IsA("BasePart") then table.insert(RT.cachedCharBaseParts, part) end
            end
        end
    end
    return RT.cachedCharBaseParts
end

local function isPlayerMounted() return LocalPlayer:GetAttribute("Mount") ~= nil or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Mount") ~= nil) end

local function setPlayerMounted(shouldMount)
    local now = tick()
    if now - RT.lastMountToggleTime < 0.6 then return end
    local currentlyMounted = isPlayerMounted()
    if (shouldMount and not currentlyMounted) or (not shouldMount and currentlyMounted) then RT.lastMountToggleTime = now; pcall(function() if RemoteBank and RemoteBank.MountToggle then RemoteBank.MountToggle:Fire() end end) end
end

local function restoreCharacterCollision()
    if Config.NoClip or isInInvasion() or isInMission() or RT.isActivelyLockingTarget then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(getCharacterBaseParts(char)) do
        if part.Parent then
            local name = part.Name
            if name:find("Leg") or name:find("Foot") or name:find("Torso") or name == "HumanoidRootPart" or name == "Head" then
                if not part.CanCollide then part.CanCollide = true end
            end
        end
    end
end

local function releaseCombatLock()
    RT.isActivelyLockingTarget, RT.currentLockedTarget, RT.currentApproachDir = false, nil, nil; local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        for _, n in ipairs({ "Helm_TransitLV", "Helm_TransitAttachment", "Helm_AntiGravity" }) do
            local obj = root:FindFirstChild(n)
            if obj then obj:Destroy() end
        end
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum:MoveTo(root and root.Position or Vector3.zero) end
    if not Config.NoClip then restoreCharacterCollision() end
end

local function teleportToWorld(worldName)
    if not worldName or worldName == "" then return end
    releaseCombatLock()
    Config.TargetCurrent = nil
    table.clear(RT.activeTelegraphs)
    pcall(function()
        if RemoteBank and RemoteBank.Teleport then RemoteBank.Teleport:Fire(worldName)
        elseif MapClient and typeof(MapClient.RequestTeleport) == "function" then MapClient.RequestTeleport(worldName) end
    end)
end

trackConnection(RunService.Heartbeat:Connect(function(dt)
    if not isScriptRunning then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then RT.isActivelyLockingTarget = false; return end
    local activeMap = getActiveMapFolder(); local spawnPart = getMapSpawnPart(activeMap)
    local voidLimitY = (spawnPart and spawnPart:IsA("BasePart")) and (spawnPart.Position.Y - 25) or -45
    if root.Position.Y < voidLimitY then
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        root.CFrame = (spawnPart and spawnPart:IsA("BasePart")) and (spawnPart.CFrame + Vector3.new(0, 5, 0)) or CFrame.new(root.Position.X, 30, root.Position.Z)
        return
    end
    local inInvasion, inMission = isInInvasion(), isInMission(); local questActive, questStatus = isQuestOverrideActive()
    local bountyActive, bountyStatus = isBountyOverrideActive(); local topMode = getTopRequestedPriorityMode(); local shouldPosition = false
    if Config.AutoPosition or (inInvasion and Config.InvasionAutoFarm and Config.InvasionAutoTeleport)
        or (inMission and (Config.AutoMission or Config.AutoMissionFarm or Config.AutoChallenge) and (Config.MissionAutoTeleport or Config.AutoChallenge)) then
        shouldPosition = true
    elseif (topMode == "Quest" or not (topMode == "Bounty" and bountyActive and Config.BountyAutoTeleport)) and questActive and Config.QuestAutoTeleport then
        shouldPosition = (not questStatus.world or getCurrentMapName() == questStatus.world)
    elseif bountyActive and Config.BountyAutoTeleport then
        shouldPosition = (not bountyStatus.world or getCurrentMapName() == bountyStatus.world)
    end
    local function applyIdleDodge()
        if RT.isActivelyLockingTarget then releaseCombatLock() end
        local dodgePos = computeDodgeEscape(root.Position, root.Position.Y)
        if dodgePos then
            local safeDodgeY = math.max(dodgePos.Y, getSafeStandingY(dodgePos, root.Position.Y, activeMap, 0))
            local finalDodge = Vector3.new(dodgePos.X, safeDodgeY, dodgePos.Z); root.CFrame = CFrame.new(finalDodge, finalDodge + root.CFrame.LookVector)
            root.AssemblyLinearVelocity = Vector3.zero
        elseif (inInvasion or inMission) and root.AssemblyLinearVelocity.Y < 0 then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
        end
    end
    if not shouldPosition then applyIdleDodge(); return end
    local target = Config.TargetCurrent; local needRescan = not isValidCombatTarget(target, activeMap)
    if not needRescan and not (inInvasion and Config.InvasionAutoFarm) and not (inMission and (Config.AutoMissionFarm or Config.AutoMission or Config.AutoChallenge)) then
        local qEnemy = questActive and questStatus and questStatus.targetEnemy; local bEnemy = bountyActive and bountyStatus and bountyStatus.enemy ~= "" and bountyStatus.enemy
        if (topMode == "Quest" and qEnemy) or (topMode ~= "Bounty" and qEnemy) then needRescan = not isMobNameMatch(target.Name, qEnemy)
        elseif bEnemy then needRescan = not isMobNameMatch(target.Name, bEnemy)
        else needRescan = not isMobSelectedByFilter(target.Name) end
    end
    if needRescan then target = getBestTarget(); Config.TargetCurrent = target end
    if not target or not isValidCombatTarget(target, activeMap) then applyIdleDodge(); return end
    local tRoot = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("Torso")
    if not tRoot then RT.isActivelyLockingTarget, RT.currentLockedTarget, RT.currentApproachDir = false, nil, nil; return end
    RT.isActivelyLockingTarget = true; local mobPos = tRoot.Position
    if root.Position.Y < (mobPos.Y - 8) then
        root.CFrame = CFrame.new(root.Position.X, mobPos.Y + 3.5, root.Position.Z)
        root.AssemblyLinearVelocity = Vector3.zero
    end
    if RT.currentLockedTarget ~= target or not RT.currentApproachDir then
        RT.currentLockedTarget = target; local mobLook = Vector3.new(tRoot.CFrame.LookVector.X, 0, tRoot.CFrame.LookVector.Z)
        mobLook = (mobLook.Magnitude < 0.05) and Vector3.new(0, 0, -1) or mobLook.Unit
        if Config.PositionMode == "BehindMob" or Config.PositionMode == "HoverAbove" then RT.currentApproachDir = -mobLook
        elseif Config.PositionMode == "FrontMob" then RT.currentApproachDir = mobLook
        else
            local diff = Vector3.new(root.Position.X - mobPos.X, 0, root.Position.Z - mobPos.Z); RT.currentApproachDir = (diff.Magnitude > 0.1) and diff.Unit or (-mobLook)
        end
    end
    local distOffset = math.max(1, math.floor(tonumber(Config.BehindDistance) or 1)); local targetY = mobPos.Y + (Config.CombatHeightOffset or 0); local targetCFrame
    if Config.PositionMode == "HoverAbove" then
        local hoverH = (Config.CombatHeightOffset ~= 0) and Config.CombatHeightOffset or (Config.HoverHeight or 6); targetY = mobPos.Y + math.max(3, hoverH)
        local hoverPos = Vector3.new(mobPos.X, targetY, mobPos.Z) + RT.currentApproachDir * math.max(distOffset, 2.0); local lookAt = Vector3.new(mobPos.X, targetY, mobPos.Z)
        if (lookAt - hoverPos).Magnitude < 0.1 then lookAt = hoverPos - RT.currentApproachDir end
        targetCFrame = CFrame.new(hoverPos, lookAt)
    else
        local standXZ = Vector3.new(mobPos.X, 0, mobPos.Z) + RT.currentApproachDir * distOffset
        local standPos = Vector3.new(standXZ.X, targetY, standXZ.Z); local lookAt = Vector3.new(mobPos.X, targetY, mobPos.Z)
        if (lookAt - standPos).Magnitude < 0.1 then lookAt = standPos - RT.currentApproachDir end
        targetCFrame = CFrame.new(standPos, lookAt)
    end
    local dodgePos = computeDodgeEscape(targetCFrame.Position, mobPos.Y)
    if dodgePos then
        local safeDodgeY = math.max(dodgePos.Y, getSafeStandingY(dodgePos, mobPos.Y, activeMap, 0))
        local finalDodge = Vector3.new(dodgePos.X, safeDodgeY, dodgePos.Z); local lookAt = Vector3.new(mobPos.X, safeDodgeY, mobPos.Z)
        if (lookAt - finalDodge).Magnitude < 0.1 then lookAt = finalDodge + Vector3.new(0, 0, -1) end
        targetCFrame = CFrame.new(finalDodge, lookAt)
    end
    local destPos, currentPos = targetCFrame.Position, root.Position; local delta = destPos - currentPos; local dist = delta.Magnitude
    local transitSpeed = math.clamp(tonumber(Config.GlideSpeed) or 25, 10, 80); local hum = char:FindFirstChildOfClass("Humanoid")
    local shouldNoClip = Config.NoClip or RT.isActivelyLockingTarget or inInvasion or inMission

    -- SMART UNSTUCK ENGINE (PHÁ KẸT TƯỜNG & VẬT CẢN THÔNG MINH)
    local nowClock = os.clock()
    if nowClock - (RT.stuckLastCheck or 0) >= 0.5 then
        local movedSinceLast = (root.Position - (RT.stuckLastPos or root.Position)).Magnitude
        RT.stuckLastPos = root.Position
        RT.stuckLastCheck = nowClock
        if dist > 3.0 and movedSinceLast < 1.0 then
            RT.stuckCount = (RT.stuckCount or 0) + 1
            if RT.stuckCount >= 2 then
                if isPlayerMounted() then setPlayerMounted(false) end
                for _, p in ipairs(getCharacterBaseParts(char)) do if p.Parent then p.CanCollide = false end end
                root.CFrame = targetCFrame + Vector3.new(0, 3, 0)
                root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
                RT.stuckCount = 0
                return
            end
        else
            RT.stuckCount = 0
        end
    end

    if dist > 1.8 then
        if inInvasion then
            if isPlayerMounted() then setPlayerMounted(false) end
        elseif Config.AutoMount and dist > 12 then
            setPlayerMounted(true)
        end
        if Config.MovementStyle == "Instant" then
            root.CFrame = targetCFrame; root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        elseif Config.MovementStyle == "Walk" then
            if hum and hum.Health > 0 then hum.WalkSpeed = transitSpeed; hum:MoveTo(destPos) end
            local lookTarget = Vector3.new(mobPos.X, root.Position.Y, mobPos.Z)
            if (lookTarget - root.Position).Magnitude > 0.1 then root.CFrame = CFrame.new(root.Position, lookTarget) end
        else
            local moveStep = math.min(dist, transitSpeed * math.clamp(dt, 0.001, 0.05)); local moveDir = (dist > 0.001) and (delta / dist) or Vector3.new(0, 0, -1)
            local nextPos = currentPos + moveDir * moveStep; local lookTarget = Vector3.new(mobPos.X, nextPos.Y, mobPos.Z)
            root.CFrame = ((lookTarget - nextPos).Magnitude > 0.1) and CFrame.new(nextPos, lookTarget) or CFrame.new(nextPos)
            root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
            if hum and hum.Health > 0 and not shouldNoClip then hum:MoveTo(destPos) end
        end
    else
        if (Config.AutoMount or inInvasion) and not Config.StayMountedCombat and isPlayerMounted() then setPlayerMounted(false) end
        root.CFrame = targetCFrame; root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        if hum and hum.Health > 0 and not shouldNoClip then hum:MoveTo(root.Position) end
    end
end))

trackConnection(RunService.Stepped:Connect(function()
    local shouldNoClip = Config.NoClip or RT.isActivelyLockingTarget
    local char = LocalPlayer.Character
    if shouldNoClip and char then
        RT.wasNoClipActive = true
        for _, part in ipairs(getCharacterBaseParts(char)) do
            if part.Parent and part.CanCollide then
                part.CanCollide = false
            end
        end
    elseif RT.wasNoClipActive then
        RT.wasNoClipActive = false
        restoreCharacterCollision()
    end
end))

-- [8] COMBAT LOOPS: MELEE, SKILLS & ULTIMATE
if RemoteBank and RemoteBank.HitFXRemote then
    pcall(function()
        RemoteBank.HitFXRemote.OnClientEvent:Connect(function(attacker, _fxType, hitList)
            local myUserId = LocalPlayer and LocalPlayer.UserId
            local isMe = (attacker == LocalPlayer) or (typeof(attacker) == "Instance" and attacker:GetAttribute("OwnerUserId") == myUserId)
            if isMe and type(hitList) == "table" and #hitList > 0 then table.insert(RT.combatMetrics.hitTimestamps, tick()); RT.combatMetrics.hitsRecorded = RT.combatMetrics.hitsRecorded + #hitList end
        end)
    end)
end

task.spawn(function()
    while isScriptRunning do
        local cutoff = tick() - 1.0
        local ts = RT.combatMetrics.hitTimestamps
        local n, writeIdx = #ts, 1
        for readIdx = 1, n do
            if ts[readIdx] >= cutoff then
                if writeIdx ~= readIdx then ts[writeIdx] = ts[readIdx] end
                writeIdx = writeIdx + 1
            end
        end
        for i = writeIdx, n do ts[i] = nil end
        RT.combatMetrics.hitsLastSecond = writeIdx - 1
        task.wait(0.25)
    end
end)

task.spawn(function()
    local lastTargetScan = 0
    while isScriptRunning do
        local canPunch = Config.AutoPunch or (isInInvasion() and Config.InvasionAutoFarm) or (isInMission() and (Config.AutoMission or Config.AutoMissionFarm or Config.AutoChallenge)) or (isBountyOverrideActive() and Config.BountyAutoPunch)
        local isCastingSkill = os.clock() < (RT.pendingGlobalCastUntil or 0)
        if canPunch and not isCastingSkill then
            local now = tick()
            if not isValidCombatTarget(Config.TargetCurrent) or (now - lastTargetScan >= 0.15) then Config.TargetCurrent, lastTargetScan = getBestTarget(), now end
            if isValidCombatTarget(Config.TargetCurrent) then
                if isPlayerMounted() or not (AttackClientModule and typeof(AttackClientModule.StartMelee) == "function") then
                    pcall(function() RemoteBank.PunchRemote:Fire() end)
                elseif not RT.isMeleeActiveInClient then
                    RT.isMeleeActiveInClient = true; pcall(function() AttackClientModule.StartMelee() end)
                end
            elseif AttackClientModule and typeof(AttackClientModule.StopMelee) == "function" and RT.isMeleeActiveInClient then
                RT.isMeleeActiveInClient = false; pcall(function() AttackClientModule.StopMelee() end)
            end
        elseif AttackClientModule and typeof(AttackClientModule.StopMelee) == "function" and RT.isMeleeActiveInClient then
            RT.isMeleeActiveInClient = false; pcall(function() AttackClientModule.StopMelee() end)
        end
        task.wait(math.max(Config.PunchDelay or 0.35, 0.05))
    end
end)

task.spawn(function()
    while isScriptRunning do
        local inInv, inMis = isInInvasion(), isInMission()
        local canSkills = Config.AutoSkills
            or (inInv and (Config.InvasionAutoSkills or Config.InvasionAutoFarm or Config.AutoSkills))
            or (inMis and (Config.AutoMission or Config.AutoMissionFarm or Config.AutoChallenge) and Config.MissionAutoSkills)
            or (isBountyOverrideActive() and Config.BountyAutoSkills) or (isQuestOverrideActive() and Config.QuestAutoSkills)
        if canSkills then
            local target = Config.TargetCurrent
            if not isValidCombatTarget(target) then target = getBestTarget(); Config.TargetCurrent = target end
            if isValidCombatTarget(target) then
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); local tRoot = getMobRoot(target)
                local distToTarget = (root and tRoot) and (tRoot.Position - root.Position).Magnitude or 0
                if distToTarget <= 55 then
                    if isPlayerMounted() and not Config.StayMountedCombat then setPlayerMounted(false); task.wait(0.15) end
                    local now = os.clock()
                    if not isPlayerCastLocked() and now >= RT.pendingGlobalCastUntil then
                        local slotMap = refreshEquippedPowersCache(); local chosenSlot = nil
                        if Config.SmartSkills then
                            local hum = target:FindFirstChildOfClass("Humanoid"); local curHP, maxHP = hum and hum.Health or nil, hum and hum.MaxHealth or nil; local highestScore = -1
                            for slotIdx = 1, 5 do
                                if Config.SkillSlots[slotIdx] then
                                    local score = evaluateSmartSkillScore(slotIdx, target, curHP, maxHP)
                                    if score > highestScore then highestScore, chosenSlot = score, slotIdx end
                                end
                            end
                            if highestScore <= 0 then chosenSlot = nil end
                        else
                            for slotIdx = 1, 5 do if Config.SkillSlots[slotIdx] and not isSkillOnCooldown(slotIdx) then chosenSlot = slotIdx; break end end
                        end
                        if chosenSlot then
                            local pData = slotMap[chosenSlot]
                            local targetPos = Config.SmartSkills and computeSmartTargetPosition(target, pData) or (tRoot and tRoot.Position or Vector3.zero)
                            if RT.lastFiredSlotTime[chosenSlot] and (now - RT.lastFiredSlotTime[chosenSlot]) >= 0.45 then flushPowerShotRemotes(pData and pData.Name or nil); task.wait(0.06) end
                            if RT.isMeleeActiveInClient and AttackClientModule and typeof(AttackClientModule.StopMelee) == "function" then pcall(function() AttackClientModule.StopMelee() end); RT.isMeleeActiveInClient = false end
                            pcall(function() RemoteBank.CastPower:Fire({ hotbar = chosenSlot, targetPosition = targetPos }) end); RT.lastFiredSlotTime[chosenSlot] = os.clock()
                            RT.pendingSlotRetryUntil[chosenSlot] = os.clock() + 0.50; RT.pendingGlobalCastUntil = os.clock() + 0.25; task.wait(0.08)
                        end
                    end
                end
            end
        end
        task.wait(Config.SkillDelay or 0.15)
    end
end)

task.spawn(function()
    while isScriptRunning do
        local canUlt = (Config.AutoUltimate or (isInInvasion() and Config.InvasionAutoFarm and Config.InvasionAutoSkills)
            or (isInMission() and (Config.AutoMission or Config.AutoMissionFarm or Config.AutoChallenge) and Config.MissionAutoSkills)
            or (isBountyOverrideActive() and Config.BountyAutoSkills) or (isQuestOverrideActive() and Config.QuestAutoSkills)) and canCastUltimate()
        if canUlt then
            local target = Config.TargetCurrent
            if not isValidCombatTarget(target) then target = getBestTarget(); Config.TargetCurrent = target end
            if isValidCombatTarget(target) and shouldSmartCastUltimate(target) then pcall(function() RemoteBank.CastUltimate:Fire() end) end
        end
        task.wait(Config.UltimateCheckDelay or 1.0)
    end
end)

-- [9] AUTO PICKUP & DROP MAGNET
local function queueDrop(uuid)
    if not uuid or typeof(uuid) ~= "string" or uuid == "" or RT.knownDrops[uuid] then return end
    RT.knownDrops[uuid] = os.clock()
    table.insert(RT.pendingDrops, uuid)
end

local function forceSweepDrops()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); local playerCFrame = root and root.CFrame
    for _, child in ipairs(Workspace:GetChildren()) do
        if child.Name == "CurrencyDrop" then
            pcall(function() child:SetAttribute("Pickable", true); if playerCFrame and child:IsA("BasePart") then child.CFrame, child.CanCollide = playerCFrame, false end end)
            local idObj = child:FindFirstChild("ID")
            if idObj and typeof(idObj.Value) == "string" and idObj.Value ~= "" then queueDrop(idObj.Value) end
        end
    end
end

trackConnection(Workspace.ChildAdded:Connect(function(child)
    if not Config.AutoMagnet or not child or child.Name ~= "CurrencyDrop" then return end
    pcall(function()
        child:SetAttribute("Pickable", true)
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root and child:IsA("BasePart") then child.CFrame, child.CanCollide = root.CFrame, false end
    end)
    local idObj = child:FindFirstChild("ID")
    if idObj and typeof(idObj.Value) == "string" and idObj.Value ~= "" then queueDrop(idObj.Value) end
end))

if RemoteBank.DropSpawnRemote and RemoteBank.DropSpawnRemote.OnClientEvent then
    trackConnection(RemoteBank.DropSpawnRemote.OnClientEvent:Connect(function(dropBatch)
        if not Config.AutoMagnet or type(dropBatch) ~= "table" then return end
        for _, item in ipairs(dropBatch) do
            local dropUuid = (type(item) == "table" and (item.uuid or item.UUID or item.id or item.Id)) or (type(item) == "string" and item) or nil
            if dropUuid then queueDrop(dropUuid) end
        end
    end))
end

task.spawn(function()
    while isScriptRunning do
        if Config.AutoMagnet then
            local now = os.clock()
            if now - RT.lastDropCleanTime > 60 then
                RT.lastDropCleanTime = now
                local newKnown = {}
                for u, t in pairs(RT.knownDrops) do if now - t <= 120 then newKnown[u] = t end end
                RT.knownDrops = newKnown
            end
            if isCurrentMapLobby and isCurrentMapLobby() then
                table.clear(RT.pendingDrops)
                table.clear(RT.knownDrops)
            else
                forceSweepDrops()
            end
        end
        task.wait(2.5)
    end
end)

trackConnection(RunService.Heartbeat:Connect(function()
    if not Config.AutoMagnet or #RT.pendingDrops == 0 then return end
    local now = os.clock()
    if now - (RT.lastPickupRun or 0) < 0.15 then return end
    RT.lastPickupRun = now
    local total = #RT.pendingDrops
    local count = math.min(total, 50)
    local batch = {}
    for i = 1, count do batch[i] = RT.pendingDrops[i] end
    local remCount = total - count
    for i = 1, remCount do RT.pendingDrops[i] = RT.pendingDrops[count + i] end
    for i = remCount + 1, total do RT.pendingDrops[i] = nil end
    pcall(function() RemoteBank.PickupRemote:Fire(batch) end)
end))

-- [10] AUTO QUESTS, AUTO BOUNTY & AUTO MISSIONS
task.spawn(function()
    while isScriptRunning do
        if Config.AutoQuest and not isInMission() and not isInInvasion() then
            local status = getQuestlineStatus()
            if status and not status.allCompleted and status.state ~= "AllCompleted" then
                if status.state == "NeedAccept" and Config.QuestAutoAccept then
                    if os.clock() - RT.lastQuestAcceptAttempt > 2.5 then
                        RT.lastQuestAcceptAttempt = os.clock()
                        pcall(function()
                            if RemoteBank.QuestAccept then RemoteBank.QuestAccept:Fire(status.questlineId) end
                            if RemoteBank.QuestSetTracked then RemoteBank.QuestSetTracked:Fire("Questline", status.questlineId) end
                        end)
                        notify("Auto Quests", string.format("Đã gửi yêu cầu nhận cốt truyện %s!", tostring(status.questlineId)), 2.5)
                    end
                elseif status.state == "ReadyToClaim" and Config.QuestAutoClaim then
                    if os.clock() - RT.lastQuestClaimAttempt > 2.5 then
                        RT.lastQuestClaimAttempt = os.clock()
                        pcall(function() if RemoteBank.QuestClaimReward then RemoteBank.QuestClaimReward:Fire(status.questlineId) end end)
                        notify("Auto Quests", string.format("Đã hoàn thành bước! Đang nhận thưởng & mở khóa %s...", tostring(status.questlineId)), 3)
                        task.wait(1.5); pcall(function() if RemoteBank.QuestAccept then RemoteBank.QuestAccept:Fire(status.questlineId) end end)
                    end
                elseif status.state == "InProgress" and Config.QuestAutoTeleportWorld and status.world and status.world ~= "" then
                    local topMode = getTopRequestedPriorityMode()
                    if topMode == "Quest" and getCurrentMapName() ~= status.world and (os.clock() - RT.lastQuestWorldTele > 4.0) then
                        RT.lastQuestWorldTele = os.clock(); teleportToWorld(status.world)
                        notify("Auto Quests", string.format("Đang dịch chuyển sang %s để làm %s (Săn %s)!", tostring(status.world), tostring(status.questlineId), tostring(status.targetEnemy or "Quái")), 3)
                        task.wait(3.5)
                    end
                end
            end
        end
        task.wait(1.0)
    end
end)

task.spawn(function()
    while isScriptRunning do
        if Config.AutoBounty and not isInMission() and not isInInvasion() then
            local status = getBountyTaskStatus()
            if status and not status.completed and status.state ~= "Completed" then
                if status.state == "NeedAccept" then
                    pcall(function()
                        if RemoteBank.BountyAccept then RemoteBank.BountyAccept:Fire(nil) end
                        if RemoteBank.QuestSetTracked then RemoteBank.QuestSetTracked:Fire("Bounty", status.position or 1) end
                    end)
                elseif status.state == "ReadyToClaim" then
                    pcall(function() if RemoteBank.BountyClaim then RemoteBank.BountyClaim:Fire(nil) end end)
                elseif status.state == "InProgress" and Config.BountyAutoTeleport and status.world and status.world ~= "" then
                    local topMode = getTopRequestedPriorityMode()
                    if topMode == "Bounty" and getCurrentMapName() ~= status.world and (os.clock() - RT.lastBountyWorldTele > 4.0) then
                        RT.lastBountyWorldTele = os.clock(); teleportToWorld(status.world)
                        notify("Auto Bounty", string.format("Đang dịch chuyển sang %s để săn %s (%d/%d)!", tostring(status.world), tostring(status.enemy), status.progress or 0, status.target or 1), 3)
                        task.wait(3.5)
                    end
                end
            end
        end
        task.wait(1.0)
    end
end)

local function syncWaveInfoFromHUD()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local inMissionUI = pGui and pGui:FindFirstChild("MainHUD") and pGui.MainHUD:FindFirstChild("Missions") and pGui.MainHUD.Missions:FindFirstChild("InMissionUI")
    if inMissionUI and inMissionUI.Visible and inMissionUI:FindFirstChild("StatsFrame") then
        local stats = inMissionUI.StatsFrame
        if stats:FindFirstChild("Waves") and stats.Waves:FindFirstChild("NumberDisplay") then
            local wText = tostring(stats.Waves.NumberDisplay.Text or "")
            local curW, totW = wText:match("(%d+)/(%d+)")
            if curW and totW then currentWaveInfo.wave, currentWaveInfo.totalWaves = tonumber(curW) or currentWaveInfo.wave, tonumber(totW) or currentWaveInfo.totalWaves
            elseif tonumber(wText) then currentWaveInfo.wave = tonumber(wText) or currentWaveInfo.wave end
        end
        if stats:FindFirstChild("Enemies") and stats.Enemies:FindFirstChild("NumberDisplay") then
            local eText = tostring(stats.Enemies.NumberDisplay.Text or "")
            local curE, totE = eText:match("(%d+)/(%d+)")
            if curE and totE then currentWaveInfo.enemiesAlive, currentWaveInfo.enemiesTotal = tonumber(curE) or currentWaveInfo.enemiesAlive, tonumber(totE) or currentWaveInfo.enemiesTotal
            elseif tonumber(eText) then currentWaveInfo.enemiesAlive = tonumber(eText) or currentWaveInfo.enemiesAlive end
        end
        local details = inMissionUI:FindFirstChild("Details")
        if details and details:FindFirstChild("Act") and details.Act:FindFirstChild("Title") then
            local tText = tostring(details.Act.Title.Text or "")
            if tText ~= "" then currentWaveInfo.title = tText end
        end
    end
end

if RemoteBank.MissionWaveUpdate and RemoteBank.MissionWaveUpdate.OnClientEvent then
    trackConnection(RemoteBank.MissionWaveUpdate.OnClientEvent:Connect(function(data)
        if type(data) == "table" then
            currentWaveInfo.wave = tonumber(data.wave) or currentWaveInfo.wave; currentWaveInfo.totalWaves = tonumber(data.totalWaves) or currentWaveInfo.totalWaves
            currentWaveInfo.enemiesAlive = tonumber(data.enemiesAlive) or currentWaveInfo.enemiesAlive
            currentWaveInfo.enemiesTotal = tonumber(data.enemiesTotal) or currentWaveInfo.enemiesTotal
            if data.title then currentWaveInfo.title = tostring(data.title) end
        end
    end))
end

local function isMissionRewardUIVisible()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local rewardUI = pGui and pGui:FindFirstChild("MainHUD") and pGui.MainHUD:FindFirstChild("Missions") and pGui.MainHUD.Missions:FindFirstChild("MissionRewardUI")
    return (rewardUI and rewardUI.Visible == true) or false
end

local function launchConfiguredMission()
    if amIPartyGuest() then return end
    pcall(function()
        if not RemoteBank.MissionLaunch then return end
        local gm = Config.MissionGamemode or "Mission"
        if gm == "Challenge" then
            local tier = Config.ChallengeTier or "Regular"
            local slotIdx = (tier == "Regular") and (tonumber(Config.ChallengeSlot) or 1) or 1; local st = getChallengeSlotStatus(tier, slotIdx)
            preparePartyBeforeLaunch({ world = st.world or (Config.MissionWorld or "Nemu's Village"), act = tonumber(st.act) or 1, tier = tier, index = slotIdx })
            RemoteBank.MissionLaunch:Fire({ gamemode = "Challenge", tier = tier, index = slotIdx })
        elseif gm == "Gauntlet" then
            local ch = tonumber(Config.GauntletChamber) or 1
            preparePartyBeforeLaunch({ gamemode = "Gauntlet", chamber = ch, world = "Gauntlet" }); RemoteBank.MissionLaunch:Fire({ gamemode = "Gauntlet", chamber = ch })
        elseif gm == "Invasion" then
            local invSt = getInvasionStatus()
            if not invSt.isActive or (tonumber(invSt.timeLeft) or 0) < 90 then return end
            local w = Config.MissionWorld or "Nemu's Village"
            preparePartyBeforeLaunch({ gamemode = "Invasion", world = w }); RemoteBank.MissionLaunch:Fire({ gamemode = "Invasion", world = w })
        else
            local actNum = tonumber(Config.MissionAct) or 1; local w = Config.MissionWorld or "Nemu's Village"; local m = (actNum == 4) and "Hard" or (Config.MissionMode or "Normal")
            preparePartyBeforeLaunch({ world = w, act = actNum, mode = m }); RemoteBank.MissionLaunch:Fire({ gamemode = "Mission", world = w, act = actNum, mode = m })
        end
    end)
end

local function handleMissionEndDecision(resultData)
    pcall(forceSweepDrops)
    if not RemoteBank.MissionDecision then return end
    if type(resultData) == "table" and type(resultData.hostId) == "number" and resultData.hostId ~= LocalPlayer.UserId and amIPartyGuest() then
        task.delay(4.5, function()
            if isScriptRunning and isMissionRewardUIVisible() then pcall(function() RemoteBank.MissionDecision:Fire("Return") end) end
        end)
        return
    end
    if isInInvasion() then pcall(function() RemoteBank.MissionDecision:Fire("Return") end); return end
    local gmAttr = tostring(LocalPlayer:GetAttribute("Gamemode") or (type(resultData) == "table" and type(resultData.missionData) == "table" and resultData.missionData.gamemode) or "")
    local topMode = getTopRequestedPriorityMode()
    if gmAttr == "Challenge" then
        local isVictory = (type(resultData) ~= "table") or (resultData.victory ~= false)
        local canRetryChallenge = (not isVictory) and (type(resultData) == "table" and resultData.canRetry == true) and (topMode == "Challenge")
        pcall(function() RemoteBank.MissionDecision:Fire(canRetryChallenge and "Retry" or "Return") end)
        return
    end
    if topMode ~= "MissionQueue" and topMode ~= "NormalCombat" then pcall(function() RemoteBank.MissionDecision:Fire("Return") end); return end
    local firstChoice = Config.MissionDecisionType or "Retry"; local canNext = (type(resultData) ~= "table") or (resultData.canNext ~= false)
    local canRetry = (type(resultData) ~= "table") or (resultData.canRetry ~= false)
    if firstChoice == "Next" and not canNext then firstChoice = canRetry and "Retry" or "Return"
    elseif firstChoice == "Retry" and not canRetry then firstChoice = "Return" end
    pcall(function() RemoteBank.MissionDecision:Fire(firstChoice) end)
    task.delay(2.2, function()
        if isScriptRunning and isMissionRewardUIVisible() and (Config.AutoReplayMission or Config.AutoMission or Config.AutoChallenge) then
            pcall(function() RemoteBank.MissionDecision:Fire((firstChoice == "Next" and canRetry) and "Retry" or "Return") end)
        end
    end)
end

task.spawn(function()
    local lastInvLaunch = 0
    while isScriptRunning do
        if Config.AutoInvasion and not isInInvasion() and not isInMission() and not amIPartyGuest() then
            local invReady, invSt = isInvasionReadyToEnter()
            if invReady and invSt and invSt.isActive and (os.clock() - lastInvLaunch > 5.0) then
                lastInvLaunch = os.clock()
                local chosenWorld = (Config.InvasionPreferredWorld and Config.InvasionPreferredWorld ~= "Tự Động (Theo Server)") and Config.InvasionPreferredWorld or (invSt.activeWorld or "Nemu's Village")
                notify("Auto Invasion", string.format("Phát hiện Xâm Lược tại %s! Đang tạo phòng...", tostring(chosenWorld)), 3)
                if isPartyHostMode() then
                    preparePartyBeforeLaunch({ gamemode = "Invasion", world = chosenWorld })
                end
                if RemoteBank and RemoteBank.MissionLaunch then
                    pcall(function()
                        RemoteBank.MissionLaunch:Fire({ gamemode = "Invasion", world = chosenWorld })
                    end)
                end
                task.wait(4.0)
            end
        end
        task.wait(1.5)
    end
end)

-- Invasion watchdog: cổng đóng (InvasionEndsAt) mà vẫn còn trong Invasion -> server khoá quái bất tử
-- và giữ người chơi lại. Chủ động thoát bằng MissionReturn (nút Return của game) / MissionDecision.
task.spawn(function()
    local expiredSince, lastReturnFire, notified = nil, 0, false
    while isScriptRunning do
        local inInv = LocalPlayer:GetAttribute("Gamemode") == "Invasion"; local gateOpen = true
        if inInv then
            local ok, res = pcall(function()
                if InvasionAPI and typeof(InvasionAPI.IsActive) == "function" then return InvasionAPI.IsActive() == true end
                return getInvasionStatus().isActive == true
            end)
            gateOpen = (not ok) or res
        end
        if inInv and not gateOpen and (Config.AutoInvasion or Config.InvasionAutoFarm) then
            expiredSince = expiredSince or os.clock()
            if os.clock() - expiredSince >= 2 and os.clock() - lastReturnFire >= 4 then
                lastReturnFire = os.clock(); pcall(releaseCombatLock)
                if isMissionRewardUIVisible() and RemoteBank.MissionDecision then
                    pcall(function() RemoteBank.MissionDecision:Fire("Return") end)
                elseif RemoteBank.MissionReturn then
                    pcall(function() RemoteBank.MissionReturn:Fire(true) end)
                end
                if not notified then notified = true; notify("Auto Invasion", "Cổng Xâm Lược đã đóng! Đang tự thoát về Lobby để tránh kẹt quái bất tử...", 4) end
            end
        else
            expiredSince, notified = nil, false
        end
        task.wait(1.0)
    end
end)

task.spawn(function()
    while isScriptRunning do
        local topMode = getTopRequestedPriorityMode()
        if (Config.AutoReplayMission or Config.AutoMission or Config.AutoChallenge or topMode ~= "NormalCombat" or isInInvasion()) and isMissionRewardUIVisible() then
            task.wait(1.6)
            if isMissionRewardUIVisible() then handleMissionEndDecision(nil); task.wait(2.5) end
        end
        if not isInMission() and not isInInvasion() and not amIPartyGuest() then
            if topMode == "Challenge" then
                if launchConfiguredChallenge() then task.wait(4.5) else task.wait(3.0) end
            elseif topMode == "MissionQueue" then
                launchConfiguredMission(); task.wait(4.5)
            elseif Config.AutoChallenge and not Config.AutoQuest and not Config.AutoBounty and not Config.AutoInvasion and not Config.AutoMission then
                launchConfiguredChallenge(); task.wait(3.5)
            end
        end
        task.wait(1.5)
    end
end)

if RemoteBank.MissionComplete and RemoteBank.MissionComplete.OnClientEvent then
    trackConnection(RemoteBank.MissionComplete.OnClientEvent:Connect(function(resultData)
        if Config.AutoReplayMission or Config.AutoMission or Config.AutoChallenge or isBountyOverrideActive() or isInInvasion() then task.spawn(function() task.wait(1.6); handleMissionEndDecision(resultData) end) end
    end))
end

-- [11] AUTO SUMMON, MERCHANT AUTO BUY & FLOATING TOGGLE
local function doPullBanner(bannerName, count)
    local bStr = tostring(bannerName or ""):lower(); local targetBanner = (bStr:find("weapon") or bStr:find("kiếm") or bStr:find("vũ khí")) and "Standard Weapons" or "Standard Powers"
    local num = math.clamp(tonumber(count) or 1, 1, 50); pcall(function() if RemoteBank and RemoteBank.PullBanner then RemoteBank.PullBanner:Fire(targetBanner, num) end end)
end

task.spawn(function()
    while isScriptRunning do
        if Config.AutoSummon then
            pcall(function() doPullBanner(Config.SummonBanner, Config.SummonCount) end); task.wait(0.6)
        else
            task.wait(1)
        end
    end
end)

local function getGearCatalogTable()
    if type(GearsData) == "table" then
        if type(GearsData.Gears) == "table" then return GearsData.Gears end
        return GearsData
    end
    return {}
end

local function computeGearRollScore(gearName, rolledStats)
    if type(rolledStats) ~= "table" then return 0, 0 end
    local catalog = getGearCatalogTable()
    local meta = catalog[tostring(gearName or "")]; local rawSum, ratioSum, count = 0, 0, 0
    for statKey, val in pairs(rolledStats) do
        local num = tonumber(val) or 0; rawSum = rawSum + num; local matchedDef = nil
        if type(meta) == "table" and type(meta.MainStats) == "table" then for _, def in ipairs(meta.MainStats) do if type(def) == "table" and def.stat == statKey then matchedDef = def; break end end end
        if matchedDef and tonumber(matchedDef.max) and tonumber(matchedDef.min) then
            local minV, maxV = tonumber(matchedDef.min) or 0, tonumber(matchedDef.max) or 1; local ratio = (maxV > minV) and math.clamp((num - minV) / (maxV - minV), 0, 1) or 1
            ratioSum = ratioSum + ratio; count = count + 1
        end
    end
    local avgRatio = (count > 0) and (ratioSum / count) or 0
    return rawSum, avgRatio
end

local function isGearMatchedBySellFilter(gearName)
    if type(Config.SelectedSellGears) ~= "table" or #Config.SelectedSellGears == 0 then return false end
    local gName = tostring(gearName or "")
    local gLower = gName:lower(); local catalog = getGearCatalogTable(); local meta = catalog[gName]; local gSet = (type(meta) == "table" and tostring(meta.Set or ""):lower()) or ""
    for _, sel in ipairs(Config.SelectedSellGears) do
        local sLower = tostring(sel or ""):lower()
        if sLower:find("tất cả gear") or sLower:find("all gears") then return true end
        if sLower:find("set:%s*battle armor") and gSet == "battle armor" then return true end
        if sLower:find("set:%s*ex captain") and gSet == "ex captain" then return true end
        if sLower:find("set:%s*shadow commander") and gSet == "shadow commander" then return true end
        if sLower:find("set:%s*knight") and gSet == "knight" then return true end
        if gLower == sLower or sLower:find(gLower, 1, true) then return true end
    end
    return false
end

local function getGearInventorySummary()
    local total, equippedCount, lockedCount = 0, 0, 0
    pcall(function()
        if not DataClient or typeof(DataClient.Get) ~= "function" then return end
        local gears = DataClient.Get("Gears")
        local eqMap = {}; local eqGears = DataClient.Get("Equipped_Gears")
        if type(eqGears) == "table" then for _, u in pairs(eqGears) do if type(u) == "string" and u ~= "None" then eqMap[u] = true end end end
        if type(gears) == "table" then
            for uuid, entry in pairs(gears) do
                if type(entry) == "table" then
                    total = total + 1
                    if entry.Equipped == true or eqMap[uuid] then equippedCount = equippedCount + 1 end
                    if entry.Locked == true or entry.Favorited == true then lockedCount = lockedCount + 1 end
                end
            end
        end
    end)
    return total, equippedCount, lockedCount
end

local function sellSelectedGears()
    if not DataClient or typeof(DataClient.Get) ~= "function" or not RemoteBank or not RemoteBank.DeleteGear then return 0 end
    local gears = DataClient.Get("Gears")
    if type(gears) ~= "table" then return 0 end
    local eqMap = {}
    local eqGears = DataClient.Get("Equipped_Gears")
    if type(eqGears) == "table" then for _, u in pairs(eqGears) do if type(u) == "string" and u ~= "None" then eqMap[u] = true end end end
    local bestUuidPerName, bestScorePerName = {}, {}
    if Config.KeepBestGearPerName then
        for uuid, entry in pairs(gears) do
            if type(entry) == "table" and type(entry.Gear) == "string" then
                local rawSum, avgRatio = computeGearRollScore(entry.Gear, entry.MainStats)
                local composite = rawSum + (avgRatio * 100) + ((entry.Equipped or eqMap[uuid] or entry.Locked) and 10000 or 0)
                local curBest = bestScorePerName[entry.Gear]
                if not curBest or composite > curBest then bestScorePerName[entry.Gear] = composite; bestUuidPerName[entry.Gear] = uuid end
            end
        end
    end
    local toDelete = {}
    for uuid, entry in pairs(gears) do
        if type(entry) == "table" and type(entry.Gear) == "string" then
            local isProtected = (entry.Locked == true) or (entry.Equipped == true) or (entry.Favorited == true) or (eqMap[uuid] == true) or (Config.KeepBestGearPerName and bestUuidPerName[entry.Gear] == uuid)
            if not isProtected and Config.ProtectHighRollGears then
                local _, avgRatio = computeGearRollScore(entry.Gear, entry.MainStats)
                if avgRatio >= 0.90 then isProtected = true end
            end
            if not isProtected and isGearMatchedBySellFilter(entry.Gear) then table.insert(toDelete, uuid) end
        end
    end
    if #toDelete == 0 then return 0 end
    for i = 1, #toDelete, 50 do
        local batch = {}
        for j = i, math.min(i + 49, #toDelete) do batch[toDelete[j]] = true end
        pcall(function() RemoteBank.DeleteGear:Fire(batch) end)
        if i + 50 <= #toDelete then task.wait(0.12) end
    end
    return #toDelete
end

task.spawn(function()
    while isScriptRunning do
        if Config.AutoSellGears then
            pcall(function() local sold = sellSelectedGears(); if sold > 0 then notify("Auto Sell Gears", string.format("Đã tự động dọn bán %d món Gear rác khỏi túi đồ!", sold), 2.5) end end)
            task.wait(3.5)
        else
            task.wait(1.5)
        end
    end
end)

local function getMerchantStock()
    if not MerchantsModule then return nil, 0, 0 end
    local now = os.time()
    local period = MerchantsModule.GetPeriod(now); local timeLeft = MerchantsModule.GetTimeRemaining(now)
    local ok, stock = pcall(MerchantsModule.RollStock, "Travelling Merchant", period)
    return (ok and type(stock) == "table") and stock or nil, timeLeft, period
end

local function getRemainingSlotStock(slotData, slotIndex, period)
    if not slotData then return 0 end
    if slotData.Infinite then return 999999 end
    local sold = 0
    pcall(function()
        if DataClient and typeof(DataClient.Get) == "function" then
            local purchases = DataClient.Get("MerchantPurchases")
            local tm = type(purchases) == "table" and purchases["Travelling Merchant"] or nil
            if type(tm) == "table" then
                if slotData.Permanent and type(tm.permanent) == "table" then sold = tonumber(tm.permanent[slotData.Item]) or 0
                elseif tm.period == period and type(tm.bought) == "table" then sold = tonumber(tm.bought[tostring(slotIndex)]) or 0 end
            end
        end
    end)
    return math.max(0, (slotData.Quantity or 0) - sold)
end

local function isItemSelectedForPurchase(itemName)
    if not Config.SelectedShopItems or #Config.SelectedShopItems == 0 then return false end
    local itemLower = tostring(itemName or ""):lower()
    for _, sel in ipairs(Config.SelectedShopItems) do
        local selStr = tostring(sel):lower()
        if selStr:find("tất cả vật phẩm") or selStr:find("all items") then return true end
        if (selStr:find("tất cả quả") or selStr:find("tất cả star fruit")) and itemLower:find("star fruit") then return true end
        if itemLower == selStr or itemLower:find(selStr, 1, true) or selStr:find(itemLower, 1, true) then return true end
    end
    return false
end

local function purchaseSelectedMerchantItems()
    local stock, _timeLeft, period = getMerchantStock()
    if not stock or #stock == 0 then return 0 end
    local currentCoins, totalPurchased = getPlayerCurrency("Coins"), 0
    for slotIndex, slotData in ipairs(stock) do
        if isItemSelectedForPurchase(tostring(slotData.Item or "")) then
            local remaining = getRemainingSlotStock(slotData, slotIndex, period)
            if remaining > 0 then
                local unitPrice = tonumber(slotData.UnitPrice) or 0
                local maxCanAfford = (unitPrice > 0) and math.floor(currentCoins / unitPrice) or remaining; local qtyToBuy = math.min(remaining, maxCanAfford)
                if qtyToBuy > 0 then
                    pcall(function()
                        if RemoteBank and RemoteBank.MerchantPurchase then
                            RemoteBank.MerchantPurchase:Fire("Travelling Merchant", slotIndex, qtyToBuy)
                            totalPurchased = totalPurchased + qtyToBuy; currentCoins = math.max(0, currentCoins - (qtyToBuy * unitPrice))
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
    for _, obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("Model") and (obj.Name:find("Bob") or obj.Name:find("Merchant")) then return obj end end
    return nil
end

task.spawn(function()
    while isScriptRunning do
        if Config.AutoBuyMerchant then pcall(purchaseSelectedMerchantItems); task.wait(3.0) else task.wait(1.5) end
    end
end)

local function setFloatingButtonVisible(visible)
    pcall(function()
        local en = (visible ~= false)
        if RT.floatingScreenGui then RT.floatingScreenGui.Enabled = en end
        for _, rootGui in ipairs({ (typeof(gethui) == "function" and gethui()) or nil, (pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui")) or nil, LocalPlayer:FindFirstChild("PlayerGui") }) do
            if rootGui then
                local dup = rootGui:FindFirstChild("HelmHubFloatingMenu")
                if dup then dup:Destroy() end
                local statGui = rootGui:FindFirstChild("StatBySmell")
                if statGui then RT.floatingScreenGui = statGui; statGui.Enabled = en end
            end
        end
    end)
end
local function createFloatingToggle(_targetWindow) setFloatingButtonVisible(Config.FloatingMenuButton ~= false) end

-- [11C] HỆ THỐNG NHẬN THƯỞNG SỰ KIỆN, QUÉT CODE & SIÊU TỐI ƯU HIỆU NĂNG
local function claimAllUpdateEvents()
    local claimed = 0
    pcall(function()
        local ue = safeRequire(DataModules and DataModules:FindFirstChild("Progression") and DataModules.Progression:FindFirstChild("UpdateEvent"))
        if ue and type(ue.Powers) == "table" and RemoteBank and RemoteBank.ClaimUpdateEvent then
            for _, pData in ipairs(ue.Powers) do
                local pName = type(pData) == "table" and pData.Power or pData
                if pName then RemoteBank.ClaimUpdateEvent:Fire(pName); claimed = claimed + 1; task.wait(0.08) end
            end
        end
    end)
    return claimed
end

local function claimAllRewardsOneClick()
    pcall(function()
        claimAllQuests()
        claimAllLevelMilestones(); claimAllAchievements(); claimAllUpdateEvents()
        if RemoteBank and RemoteBank.BountyClaim then RemoteBank.BountyClaim:Fire(nil) end
        if RemoteBank and RemoteBank.ClaimDailyReward then RemoteBank.ClaimDailyReward:Fire() end
        if RemoteBank and RemoteBank.ClaimGroupReward then RemoteBank.ClaimGroupReward:Fire() end
        if RemoteBank and RemoteBank.BattlepassClaimAll then RemoteBank.BattlepassClaimAll:Fire() end
    end)
    notify("Nhận Thưởng", "Đã gửi toàn bộ yêu cầu nhận thưởng Quests, Milestones, Achievements, Pass & Update Event!", 4)
end

local function redeemAllCodes()
    task.spawn(function()
        local codesList, seen = {}, {}
        local function addCode(c)
            if type(c) == "string" and #c > 0 then
                local cleaned = c:gsub("%s+", ""); local up = string.upper(cleaned)
                if not seen[up] then seen[up] = true; table.insert(codesList, up) end
            end
        end
        pcall(function()
            local codeMod = safeRequire(DataModules and DataModules:FindFirstChild("Economy") and DataModules.Economy:FindFirstChild("Codes"))
            if type(codeMod) == "table" then for cKey, _ in pairs(codeMod) do addCode(tostring(cKey)) end end
        end)
        for _, c in ipairs({ "EARLYACCESS", "EARLYACCESS+", "CONTENTCREATOR", "RELEASE", "UPDATE1", "SHADOWS", "EGRISE", "100KVISITS", "500KVISITS", "1MVISITS", "10KLIKES", "25KLIKES", "SORRYFORDELAY", "SUB2PROTOPOLY", "WELCOME", "FREEGEMS" }) do addCode(c) end
        if #codesList == 0 then notify("Nhập Code", "Không tìm thấy danh sách mã code khả dụng!", 3); return end
        notify("Nhập Code", string.format("Bắt đầu tự động nhập %d mã code...", #codesList), 3); local successCount, resultConn = 0, nil
        if RemoteBank and RemoteBank.RedeemCodeResult then resultConn = RemoteBank.RedeemCodeResult.OnClientEvent:Connect(function(res) if res and res.success then successCount = successCount + 1 end end) end
        for _, code in ipairs(codesList) do
            if not isScriptRunning then break end
            pcall(function() if RemoteBank and RemoteBank.RedeemCode then RemoteBank.RedeemCode:Fire(code) end end); task.wait(0.3)
        end
        task.wait(0.6)
        if resultConn then pcall(function() resultConn:Disconnect() end) end
        notify("Nhập Code Hoàn Tất", string.format("Đã gửi %d mã code! Nhận thành công: %d.", #codesList, successCount), 4)
    end)
end

RT.VFXUtil = safeRequire(Utilities and Utilities:FindFirstChild("RT.VFXUtil"))
if RT.VFXUtil then
    if RT.VFXUtil.PlayAt then
        HookOrig.originalVFXUtilPlayAt = RT.VFXUtil.PlayAt
        RT.VFXUtil.PlayAt = function(...)
            if Config.SuppressHitFX then return end
            return HookOrig.originalVFXUtilPlayAt(...)
        end
    end
    if RT.VFXUtil.EnemyDeath then
        HookOrig.originalVFXUtilEnemyDeath = RT.VFXUtil.EnemyDeath
        RT.VFXUtil.EnemyDeath = function(mob, ...)
            if Config.SuppressHitFX then pcall(function() if typeof(mob) == "Instance" and mob.Parent then mob:Destroy() end end); return end
            return HookOrig.originalVFXUtilEnemyDeath(mob, ...)
        end
    end
end

RT.PartIclesMod = safeRequire(Utilities and Utilities:FindFirstChild("Part_Icles"))
if RT.PartIclesMod then
    if RT.PartIclesMod.AbsoluteEmit then
        HookOrig.originalPartIclesAbsoluteEmit = RT.PartIclesMod.AbsoluteEmit
        RT.PartIclesMod.AbsoluteEmit = function(...)
            if Config.SuppressHitFX then return end
            return HookOrig.originalPartIclesAbsoluteEmit(...)
        end
    end
    if RT.PartIclesMod.Emit then
        HookOrig.originalPartIclesEmit = RT.PartIclesMod.Emit
        RT.PartIclesMod.Emit = function(...)
            if Config.SuppressHitFX then return end
            return HookOrig.originalPartIclesEmit(...)
        end
    end
    if RT.PartIclesMod.EnableEmit then
        HookOrig.originalPartIclesEnableEmit = RT.PartIclesMod.EnableEmit
        RT.PartIclesMod.EnableEmit = function(...)
            if Config.SuppressHitFX then return end
            return HookOrig.originalPartIclesEnableEmit(...)
        end
    end
end

RT.SoundUtilMod = safeRequire(Utilities and Utilities:FindFirstChild("SoundUtil"))
if RT.SoundUtilMod and RT.SoundUtilMod.PlayAt then
    HookOrig.originalSoundUtilPlayAt = RT.SoundUtilMod.PlayAt
    RT.SoundUtilMod.PlayAt = function(posOrPart, soundName, ...)
        if Config.SuppressHitFX then
            local s = tostring(soundName or "")
            if s == "PunchImpact" or s == "PunchSwing" or s == "DeathSound" or typeof(soundName) == "Instance" then return end
        end
        return HookOrig.originalSoundUtilPlayAt(posOrPart, soundName, ...)
    end
end

local function setGameDamageIndicatorsEnabled(enabled)
    pcall(function()
        if DataClient and typeof(DataClient.Get) == "function" then
            local st = DataClient.Get("Settings")
            if type(st) == "table" then st["Damage Indicators"] = enabled; st["Global Shadows"] = enabled end
        end
        if RemoteBank and RemoteBank.AdjustSetting then RemoteBank.AdjustSetting:Fire({ "Damage Indicators", Value = enabled }) end
    end)
end

local function purgeActiveVFXAndIndicators()
    pcall(function()
        local vfxFolder = Workspace:FindFirstChild("VFX")
        if vfxFolder then vfxFolder:ClearAllChildren() end
        for _, child in ipairs(Workspace:GetChildren()) do if child.Name == "Indicator" or child.Name == "MissIndicator" then child:Destroy() end end
    end)
end

pcall(function()
    local vfxFolder = Workspace:FindFirstChild("VFX")
    if vfxFolder then
        trackConnection(vfxFolder.ChildAdded:Connect(function(child)
            if Config.SuppressHitFX or Config.PotatoGraphics then task.defer(function() pcall(function() if child and child.Parent then child:Destroy() end end) end) end
        end))
    end
    trackConnection(Workspace.ChildAdded:Connect(function(child)
        if Config.SuppressHitFX and (child.Name == "Indicator" or child.Name == "MissIndicator") then task.defer(function() pcall(function() if child and child.Parent then child:Destroy() end end) end) end
    end))
end)

local function setVFXSuppression(enabled)
    Config.SuppressHitFX = enabled
    if enabled then
        setGameDamageIndicatorsEnabled(false); purgeActiveVFXAndIndicators()
        notify("VFX Suppressor", "Đã chặn 100% hạt chiêu thức (Part_Icles), Hit VFX, âm thanh đòn đánh & số sát thương bay lên!", 3)
    else
        setGameDamageIndicatorsEnabled(true); notify("VFX Suppressor", "Đã bật lại hiệu ứng kỹ năng & số sát thương.", 2)
    end
end

local function applyPotatoToInstance(inst)
    if not inst then return end
    pcall(function()
        if inst:IsA("BasePart") then
            inst.Material = Enum.Material.SmoothPlastic
            inst.CastShadow = false; inst.Reflectance = 0
        elseif inst:IsA("Decal") or inst:IsA("Texture") or inst:IsA("SurfaceAppearance") then
            if inst:IsA("SurfaceAppearance") then inst:Destroy() else inst.Transparency = 1 end
        elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles") or inst:IsA("Beam") or inst:IsA("Highlight") then
            inst.Enabled = false
        elseif inst:IsA("Explosion") then
            inst.Visible = false
        elseif inst:IsA("MeshPart") then
            inst.TextureID = ""; inst.Material = Enum.Material.SmoothPlastic; inst.CastShadow = false
        end
    end)
end

local function setPotatoGraphics(enabled)
    Config.PotatoGraphics = enabled
    if enabled then
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        task.spawn(function()
            local descendants = Workspace:GetDescendants()
            for i, inst in ipairs(descendants) do
                if not Config.PotatoGraphics or not isScriptRunning then break end
                applyPotatoToInstance(inst)
                if i % 350 == 0 then task.wait() end
            end
        end)
        if not RT.potatoConn then
            RT.potatoConn = Workspace.DescendantAdded:Connect(function(child) if Config.PotatoGraphics then applyPotatoToInstance(child) end end); trackConnection(RT.potatoConn)
        end
        notify("Đồ Họa Khoai Tây", "Đã hạ QualityLevel=1, xóa Texture/Mesh/Shadow & chuyển toàn bộ sang SmoothPlastic!", 3)
    else
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
        if RT.potatoConn then pcall(function() RT.potatoConn:Disconnect() end); RT.potatoConn = nil end
        notify("Đồ Họa", "Đã tắt chế độ Potato Graphics!", 2)
    end
end

local function setLightingOptimization(enabled)
    Config.DisableLightingEffects = enabled
    pcall(function()
        local lighting = game:GetService("Lighting"); lighting.GlobalShadows = not enabled; lighting.FogEnd = enabled and 9e9 or 1000
        if enabled then lighting.Brightness = 1 end
        for _, v in ipairs(lighting:GetChildren()) do
            if v:IsA("PostProcessEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("Atmosphere") then v.Enabled = not enabled end
        end
    end)
end

local function setSuperBoostFPS(enabled)
    Config.SuperBoostFPS = enabled
    pcall(function()
        setLightingOptimization(enabled); setVFXSuppression(enabled); setPotatoGraphics(enabled)
        if enabled then
            local cg = env and env.collectgarbage
            if typeof(cg) == "function" then pcall(cg, "collect") end
        end
    end)
    if enabled then
        notify("Siêu Tối Ưu FPS [ON]", "ĐÃ BẬT: Chặn Part_Icles VFX, tắt Damage Indicators, Potato Graphics & dọn RAM!", 3)
    else
        notify("Siêu Tối Ưu FPS [OFF]", "ĐÃ TẮT: Đã khôi phục lại hiệu ứng kỹ năng, số sát thương và ánh sáng mặc định!", 3)
    end
end

local function setHeadlessMode(enabled)
    Config.HeadlessMode = enabled; pcall(function() RunService:Set3dRenderingEnabled(not enabled) end)
    if enabled then notify("Multi-Account Headless", "ĐÃ TẮT RENDER 3D! GPU giảm về ~0%, CPU tiết kiệm tối đa để treo nhiều tài khoản.", 4)
    else notify("Multi-Account Headless", "Đã bật lại hiển thị 3D thông thường.", 3) end
end

local function applyFPSCap(fps)
    local target = tonumber(fps) or 60; Config.TargetFPSCap = target
    if typeof(setfpscap) == "function" then pcall(function() setfpscap(target <= 0 and 999 or target) end) end
end

-- [12] GIAO DIỆN NGƯỜI DÙNG (NATIVE INVENTORY.LUA SECTORS)
local Window
do
local okWin, resWin = pcall(function() return library:CreateWindow("HelmHub | Anime CardVerse") end)
if okWin and resWin and typeof(resWin.CreateTab) == "function" then
    Window = resWin
else
    local okWin2, resWin2 = pcall(function() return library.CreateWindow(library, "HelmHub | Anime CardVerse") end)
    if okWin2 and resWin2 and typeof(resWin2.CreateTab) == "function" then Window = resWin2 end
end
end
if not Window then warn("[HelmHub | Anime CardVerse] Không thể tạo cửa sổ giao diện chính!"); return end
createFloatingToggle(Window)

local function isUIVisible()
    return (Window and Window.Frame and Window.Frame.Visible == true)
end

local function sanitizeUIGlyphs()
    pcall(function()
        local rootGui = Window and (Window.Main or (Window.Frame and Window.Frame.Parent))
        if not rootGui then return end
        for _, desc in ipairs(rootGui:GetDescendants()) do
            if desc:IsA("TextLabel") then
                local txt = tostring(desc.Text or "")
                if txt:find("◈") or desc.Name == "Badge" then
                    desc.Text = txt:gsub("◈", "")
                    if desc.Name == "Badge" then
                        desc.Visible = false
                        local p = desc.Parent
                        local titleLbl = p and (p:FindFirstChild("Title") or p:FindFirstChild("title"))
                        if titleLbl and titleLbl:IsA("TextLabel") then
                            titleLbl.Position = UDim2.new(0, 10, 0, 0)
                        end
                    end
                elseif desc.Name == "brandIcon" or desc.Name == "BrandIcon" then
                    desc.Visible = false
                end
            end
        end
    end)
end

-- TAB 1: CHIẾN ĐẤU (COMBAT)
do
local TabCombat = Window:CreateTab("Chiến Đấu")
local SecAttack = TabCombat:CreateSector("Tấn Công & Kỹ Năng", "left")
local SecTarget = TabCombat:CreateSector("Mục Tiêu & Vị Trí", "right")

local StatusMapLabel = SecAttack:AddLabel("Bản đồ: Đang kiểm tra...", false)
local StatusMobLabel = SecAttack:AddLabel("Số quái: 0", false)
local StatusTargetLabel = SecAttack:AddLabel("Mục tiêu: Chưa có", false)
local StatusHitsLabel = SecAttack:AddLabel("Đòn đánh: 0/s (Tổng: 0)", false)

task.spawn(function()
    local function setLabelIfChanged(lbl, key, text)
        if RT.uiLabelCache[key] ~= text then
            RT.uiLabelCache[key] = text
            lbl:Set(text)
        end
    end
    while isScriptRunning do
        if not isUIVisible() then
            task.wait(2.0)
        else
            pcall(function()
                local mapName = getCurrentMapName()
                local mapText = (mapName == "Lobby" and "Bản đồ: Lobby" or string.format("Bản đồ: %s", tostring(mapName)))
                setLabelIfChanged(StatusMapLabel, "map", mapText)

                local enemies = RT.cachedEnemiesList or {}
                local filteredCount = 0
                for _, mob in ipairs(enemies) do if mob.Name and isMobSelectedByFilter(mob.Name) then filteredCount = filteredCount + 1 end end
                local selectedDisplay = getSelectedMobsDisplay()
                local mobText = (selectedDisplay and string.format("Quái [%s]: %d/%d", selectedDisplay, filteredCount, #enemies) or string.format("Quái quét được: %d", #enemies))
                setLabelIfChanged(StatusMobLabel, "mob", mobText)

                local targetText = "Mục tiêu: Chưa có"
                if Config.TargetCurrent and Config.TargetCurrent.Parent then
                    local hum = Config.TargetCurrent:FindFirstChildOfClass("Humanoid")
                    targetText = string.format("Mục tiêu: %s (%d/%d HP)", Config.TargetCurrent.Name, hum and math.floor(hum.Health) or 0, hum and math.floor(hum.MaxHealth) or 1)
                end
                setLabelIfChanged(StatusTargetLabel, "target", targetText)

                local hps, totalHits = (RT.combatMetrics and RT.combatMetrics.hitsLastSecond) or 0, (RT.combatMetrics and RT.combatMetrics.hitsRecorded) or 0
                local hitsText = string.format("Đòn đánh: Đang tắt (Tổng: %d)", totalHits)
                if Config.AutoPunch or (isInMission() and Config.AutoMissionFarm) or (isInInvasion() and Config.InvasionAutoFarm) then
                    hitsText = string.format("Đòn đánh: %d/s (Tổng: %d)", hps, totalHits)
                end
                setLabelIfChanged(StatusHitsLabel, "hits", hitsText)
            end)
            task.wait(1.0)
        end
    end
end)

pcall(function()
    SecAttack:AddToggle("Tự Đánh Thường (Auto Punch)", Config.AutoPunch, function(val)
        Config.AutoPunch = val
        if val and not Config.AutoPosition then Config.AutoPosition = true; notify("Tự Động Áp Sát", "Đã tự động kích hoạt Áp Sát Quái để đảm bảo đòn đánh trúng 100%!", 3) end
    end)
    SecAttack:AddToggle("Tự Dùng Kỹ Năng (Auto Skills)", Config.AutoSkills, function(val) Config.AutoSkills = val end)
    SecAttack:AddToggle("⚡ Kỹ Năng Thông Minh (Smart Skills)", Config.SmartSkills, function(val) Config.SmartSkills = val end)
    SecAttack:AddToggle("🎯 Đón Đầu Quái (Predictive Aim)", Config.PredictiveAim, function(val) Config.PredictiveAim = val end)
    SecAttack:AddToggle("🛡️ Tránh Lãng Phí Chiêu (Overkill)", Config.OverkillProtection, function(val) Config.OverkillProtection = val end)
    SecAttack:AddToggle("🌌 Gom Quái AOE (Centroid)", Config.ClusterAOE, function(val) Config.ClusterAOE = val end)
    SecAttack:AddToggle("Tự Chiêu Cuối (Auto Ultimate)", Config.AutoUltimate, function(val) Config.AutoUltimate = val end)
    SecAttack:AddDropdown("👑 Khi Nào Dùng Chiêu Cuối", { "Chỉ Boss & Mini-Boss (Boss Only)", "Quái Đông (Cluster >= 3)", "Mọi Quái (Any Target)" }, "Chỉ Boss & Mini-Boss (Boss Only)", function(selected) local s = tostring(selected); Config.SmartUltimateMode = s:find("Boss Only") and "BossOnly" or (s:find("Cluster") and "Cluster" or "Any") end)
    SecAttack:AddToggle("Hút Vật Phẩm (Auto Magnet)", Config.AutoMagnet, function(val) Config.AutoMagnet = val end)
    SecAttack:AddButton("▶ Vào Màn 1 (Nemu's Village Act 1)", function()
        pcall(function() RemoteBank.MissionLaunch:Fire({ gamemode = "Mission", world = "Nemu's Village", act = 1, mode = "Normal" }); notify("Khởi Chạy Màn Chơi", "Đang chuyển vào Nemu's Village - Act 1...", 4) end)
    end)
    SecAttack:AddButton("🚀 Teleport Tới Bệ Phó Bản (Lobby)", function()
        pcall(function()
            local CollectionService = game:GetService("CollectionService"); local pads = CollectionService:GetTagged("TeleportPad")
            local gPads = CollectionService:GetTagged("GamemodePad"); local targetPad = (pads and pads[1]) or (gPads and gPads[1])
            if not targetPad then local lobby = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Lobby"); targetPad = lobby and lobby:FindFirstChild("Assets") and lobby.Assets:FindFirstChild("TeleportPad") end
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if targetPad and root then root.CFrame = targetPad:GetPivot() + Vector3.new(0, 4, 0); notify("Dịch Chuyển", "Đã bay tới bệ chọn màn chơi!", 3) else notify("Dịch Chuyển", "Không tìm thấy bệ TeleportPad (Chỉ có ở Lobby)!", 3) end
        end)
    end)
    for slot = 1, 5 do SecAttack:AddToggle(string.format("Dùng Kỹ Năng Ô %d", slot), true, function(val) Config.SkillSlots[slot] = (val == true) end) end
end)

pcall(function()
    local WorldMobCatalog = {
        ["Tất Cả World (All Worlds)"] = { "Tất Cả Quái (All Mobs)", "Alien Scout", "Alien Soldier", "Alien Officer", "Captain Shinyu", "Freezer", "Grants", "Yummy", "Grimmjay", "Arruru", "Aizo", "Goblin", "Goblin Shaman", "High Grunt", "Ferrite", "Belu" },
        ["Nemu's Village (World 1)"] = { "Tất Cả Quái (All Mobs)", "Alien Scout", "Alien Soldier", "Alien Officer", "Captain Shinyu", "Freezer" },
        ["Hollow World (World 2)"] = { "Tất Cả Quái (All Mobs)", "Grants", "Yummy", "Grimmjay", "Arruru", "Aizo" },
    ["Demon Citadel (World 3)"] = { "Tất Cả Quái (All Mobs)", "Goblin", "Goblin Shaman", "High Grunt", "Ferrite", "Belu" } }
    local WorldTeleportNameMap = { ["Nemu's Village (Map 1)"] = "Nemu's Village", ["Hollow World (Map 2)"] = "Hollow World", ["Demon Citadel (Map 3)"] = "Demon Citadel" }
    local DropMob, isWorldDropdownReady, hadAllMobsSelected = nil, false, true
    SecTarget:AddDropdown("Lọc Quái Theo World", { "Tất Cả World (All Worlds)", "Nemu's Village (World 1)", "Hollow World (World 2)", "Demon Citadel (World 3)" }, "Tất Cả World (All Worlds)", false, function(val)
        Config.SelectedWorld = val; local mobs = WorldMobCatalog[val] or WorldMobCatalog["Tất Cả Thế Giới (All Worlds)"]
        if DropMob and typeof(DropMob.Refresh) == "function" then hadAllMobsSelected = true; DropMob:Refresh(mobs); DropMob:Set({ "Tất Cả Quái (All Mobs)" }); Config.SelectedMobs, Config.SelectedMob = {}, "All" end
        if isWorldDropdownReady and val then
            local targetWorldName = WorldTeleportNameMap[val]
            if targetWorldName and getCurrentMapName() ~= targetWorldName then teleportToWorld(targetWorldName); notify("Dịch Chuyển Thế Giới", string.format("Đang dịch chuyển bạn tới %s...", targetWorldName), 3) end
        end
    end)
    isWorldDropdownReady = true
    DropMob = SecTarget:AddDropdown("Chọn Quái Cần Đánh", WorldMobCatalog["Tất Cả World (All Worlds)"], { "Tất Cả Quái (All Mobs)" }, true, function(vals)
        local list = (type(vals) == "table") and vals or (vals and { tostring(vals) } or {})
        local hasAllNow = (table.find(list, "Tất Cả Quái (All Mobs)") ~= nil) or (table.find(list, "All") ~= nil); local specific = {}
        for _, v in ipairs(list) do
            local s = tostring(v)
            if s ~= "" and s ~= "Tất Cả Quái (All Mobs)" and s ~= "All" then table.insert(specific, s) end
        end
        if (hasAllNow and not hadAllMobsSelected) or (#specific == 0) then
            hadAllMobsSelected, Config.SelectedMobs, Config.SelectedMob = true, {}, "All"
            if DropMob and type(DropMob.values) == "table" then DropMob.values = { "Tất Cả Quái (All Mobs)" }; pcall(function() DropMob:updateText(); DropMob:updateItemVisuals() end) end
        else
            hadAllMobsSelected, Config.SelectedMobs, Config.SelectedMob = false, specific, specific[1] or "All"
            if hasAllNow and DropMob and type(DropMob.values) == "table" then DropMob.values = specific; pcall(function() DropMob:updateText(); DropMob:updateItemVisuals() end) end
        end
        Config.TargetCurrent = nil
    end)
    SecTarget:AddButton("🔄 Quét Quái Đang Sống Trên Map", function()
        local nameSet, options = {}, { "Tất Cả Quái (All Mobs)" }
        for _, mob in ipairs(getAllEnemies()) do if mob.Name and not nameSet[mob.Name] then nameSet[mob.Name] = true; table.insert(options, mob.Name) end end
        if #options > 1 then
            if DropMob and typeof(DropMob.Refresh) == "function" then hadAllMobsSelected = true; DropMob:Refresh(options); DropMob:Set({ "Tất Cả Quái (All Mobs)" }); Config.SelectedMobs, Config.SelectedMob = {}, "All" end
            notify("Quét Quái", string.format("Đã nạp %d loại quái thực tế đang sống trên map!", #options - 1), 3)
        else
            notify("Quét Quái", "Không tìm thấy quái nào đang sống (hoặc bạn đang ở Lobby)!", 3)
        end
    end)
    SecTarget:AddDropdown("Ưu Tiên Nhắm Quái", { "Gần Nhất (Nearest)", "Máu Thấp Nhất (Lowest HP)", "Ưu Tiên Boss (Boss First)" }, "Gần Nhất (Nearest)", false, function(val) local s = tostring(val or ""); Config.TargetMode = (s:find("Máu Thấp") or s:find("Lowest")) and "LowestHP" or (s:find("Boss") and "BossFirst" or "Nearest") end)
    SecTarget:AddSlider("Phạm Vi Quét Quái (Studs)", 100, 2500, 5000, 0, function(val) Config.ScanRange = math.floor(tonumber(val) or 2500) end)
    SecTarget:AddToggle("Tự Áp Sát Quái (Auto Position)", Config.AutoPosition, function(val) Config.AutoPosition = val; if not val then releaseCombatLock() end end)
    SecTarget:AddSlider("⚡ Tốc Độ Lướt (Studs/s)", 10, 25, 80, 0, function(val) Config.GlideSpeed = math.floor(tonumber(val) or 25) end)
    SecTarget:AddDropdown("🕹️ Kiểu Di Chuyển", { "Lướt Mượt (Glide)", "Chạy Bộ (Walk)", "Dịch Chuyển (Instant)" }, "Lướt Mượt (Glide)", false, function(val) local s = tostring(val or ""); Config.MovementStyle = (s:find("Instant") or s:find("Tức Thời")) and "Instant" or ((s:find("Walk") or s:find("Chạy Bộ")) and "Walk" or "Glide") end)
    SecTarget:AddToggle("🐎 Tự Cưỡi Mount Khi Đi Xa", Config.AutoMount, function(val) Config.AutoMount = val; if not val and isPlayerMounted() and not Config.StayMountedCombat then setPlayerMounted(false) end end)
    SecTarget:AddDropdown("Vị Trí Đứng Đánh", { "Sau Lưng Quái (Behind)", "Dưới Đất (Ground)", "Trước Mặt Quái (Front)", "Trên Đầu Quái (Hover)" }, "Sau Lưng Quái (Behind)", false, function(val)
        local s = tostring(val or "")
        Config.PositionMode = (s:find("Đất") or s:find("Ground")) and "GroundMelee" or (s:find("Trước Mặt") and "FrontMob" or ((s:find("Trên Đầu") or s:find("Hover")) and "HoverAbove" or "BehindMob"))
    end)
    SecTarget:AddSlider("Độ Cao Đứng Đánh (Studs)", -5, 0, 20, 0, function(val) Config.CombatHeightOffset = math.floor(tonumber(val) or 0) end)
    SecTarget:AddSlider("Khoảng Cách Đứng Đánh (Studs)", 1, 1, 10, 0, function(val) Config.BehindDistance = math.max(1, math.floor(tonumber(val) or 1)) end)
    SecTarget:AddToggle("Đi Xuyên Tường (NoClip)", Config.NoClip, function(val) Config.NoClip = val; if not val and not RT.isActivelyLockingTarget then restoreCharacterCollision() end end)
end)
end

-- TAB 2: (A) GAMEMODE (CHALLENGES + QUESTS + BOUNTY + INVASION + MISSIONS)
pcall(function()
    local TabActivities = Window:CreateTab("(A) Gamemode"); local SecActivities = TabActivities:CreateSector("Hoạt Động & Ưu Tiên", "left")
    local SecConfig = TabActivities:CreateSector("Cấu Hình Gamemode", "right")
    local PrioStatusLabel = SecActivities:AddLabel("Ưu tiên: Đang tải...", false)
    local ChallengeStatusLabel = SecActivities:AddLabel("Challenge: Đang tải...", false)
    local QuestlineLabel = SecActivities:AddLabel("Quest: Đang tải...", false)
    local BountyLabel = SecActivities:AddLabel("Bounty: Đang tải...", false)
    local InvasionLabel = SecActivities:AddLabel("Invasion: Đang tải...", false)
    local MissionStateLabel = SecActivities:AddLabel("Màn chơi: Ngoài map / Sảnh", false)
    local MissionWaveLabel = SecActivities:AddLabel("Wave: 0/0 | Quái: 0", false)
    task.spawn(function()
        while isScriptRunning do
            if not isUIVisible() then
                task.wait(2.5)
            else
                pcall(function()
                    local prioMode, _, prioRank = getActivePriorityMode()
                    if prioMode == "Quest" then PrioStatusLabel:Set(string.format("🔥 Ưu Tiên #%d: Auto Quests", prioRank or 1))
                    elseif prioMode == "Invasion" or prioMode == "InvasionCombat" then PrioStatusLabel:Set(string.format("⚡ Ưu Tiên #%d: Auto Invasion", prioRank or 2))
                    elseif prioMode == "Bounty" then PrioStatusLabel:Set(string.format("📜 Ưu Tiên #%d: Auto Bounty", prioRank or 3))
                    elseif prioMode == "Challenge" then PrioStatusLabel:Set(string.format("🎯 Ưu Tiên #%d: Auto Challenges", prioRank or 4))
                    elseif prioMode == "Mission" or prioMode == "MissionQueue" then PrioStatusLabel:Set(string.format("⚔️ Ưu Tiên #%d: Auto Missions", prioRank or 5))
                    else PrioStatusLabel:Set("🌍 Quái Ngoài Map") end
                    local cInfo = getChallengeInfo(); local dStatus = cInfo.dailyClaimed and "✅ Xong" or (cInfo.dailyLocked and "🔒 Khóa" or "🟢 Mở")
                    local wStatus = cInfo.weeklyClaimed and "✅ Xong" or (cInfo.weeklyLocked and "🔒 Khóa" or "🟢 Mở")
                    ChallengeStatusLabel:Set(string.format("Challenge: Daily [%s] | Weekly [%s] | Regular [%d/3]", dStatus, wStatus, cInfo.regularPlayable or 0))
                    local qStatus = getQuestlineStatus()
                    if not qStatus then QuestlineLabel:Set("Quest: Đang tải...")
                    elseif qStatus.allCompleted or qStatus.state == "AllCompleted" then QuestlineLabel:Set("Quest: 🎉 Đã xong tất cả!")
                    elseif qStatus.state == "NeedAccept" then QuestlineLabel:Set(string.format("Quest: %s (%d/%d) | Nhận NPC %s", tostring(qStatus.questlineName or "?"), qStatus.stepIndex or 1, qStatus.totalSteps or 6, tostring(qStatus.npcName or "?")))
                    elseif qStatus.state == "ReadyToClaim" then QuestlineLabel:Set(string.format("Quest: %s (%d/%d) | ✅ Đủ quái, tự trả", tostring(qStatus.questlineName or "?"), qStatus.stepIndex or 1, qStatus.totalSteps or 6))
                    else QuestlineLabel:Set(string.format("Quest: %s (%d/%d) | %s (%d/%d)", tostring(qStatus.questlineName or "?"), qStatus.stepIndex or 1, qStatus.totalSteps or 6, tostring(qStatus.targetEnemy or "?"), qStatus.progress or 0, qStatus.target or 1)) end
                    local bStatus = getBountyTaskStatus()
                    if not bStatus then BountyLabel:Set("Bounty: Đang tải...")
                    elseif bStatus.completed or bStatus.state == "Completed" then BountyLabel:Set("Bounty: ✅ Đã xong 10/10 mốc")
                    elseif bStatus.state == "NeedAccept" then BountyLabel:Set(string.format("Bounty: Mốc %d/10 | Chờ nhận", bStatus.position or 1))
                    else BountyLabel:Set(string.format("Bounty: Mốc %d/10 | %s (%d/%d)", bStatus.position or 1, tostring(bStatus.enemy or "?"), bStatus.progress or 0, bStatus.target or 1)) end
                    local invData = getInvasionStatus()
                    if invData.inInvasion then
                        InvasionLabel:Set(string.format("Invasion: Đang mở (%s) | Boss %d%% HP", tostring(invData.currentMap), math.floor((invData.bossHpPct or 1) * 100)))
                    elseif invData.activeWorld and invData.activeWorld ~= "" then
                        InvasionLabel:Set(string.format("Invasion: Cổng mở tại %s", tostring(invData.activeWorld)))
                    else
                        InvasionLabel:Set("Invasion: Đang chờ mở...")
                    end
                    if isInMission() then
                        pcall(syncWaveInfoFromHUD); local gm = LocalPlayer:GetAttribute("Gamemode") or Config.MissionGamemode or "Mission"
                        local title = (currentWaveInfo.title ~= "" and currentWaveInfo.title) or getCurrentMapName()
                        local waveCount = (currentWaveInfo.wave and currentWaveInfo.wave > 0) and currentWaveInfo.wave or 1
                        local totalW = (currentWaveInfo.totalWaves and currentWaveInfo.totalWaves > 0) and currentWaveInfo.totalWaves or 10; local livingMobs = #getAllEnemies()
                        if livingMobs == 0 and currentWaveInfo.enemiesAlive and currentWaveInfo.enemiesAlive > 0 then livingMobs = currentWaveInfo.enemiesAlive end
                        MissionStateLabel:Set(string.format("Màn chơi: %s - %s", tostring(gm), tostring(title)))
                        MissionWaveLabel:Set(string.format("Wave: %d/%d | Còn %d quái", waveCount, totalW, livingMobs))
                    else
                        MissionStateLabel:Set("Màn chơi: Ngoài map / Sảnh"); MissionWaveLabel:Set(string.format("Quái gần đây: %d", #getAllEnemies()))
                    end
                end)
                task.wait(1.2)
            end
        end
    end)
    SecActivities:AddToggle("🔥 Auto Quests (Cốt Truyện)", Config.AutoQuest, function(val) Config.AutoQuest = val; if not val and not Config.AutoPosition then releaseCombatLock() end end)
    SecActivities:AddToggle("⚡ Auto Invasion (Xâm Lược)", Config.AutoInvasion, function(val) Config.AutoInvasion = val end)
    SecActivities:AddToggle("📜 Auto Bounty (10 Mốc/Ngày)", Config.AutoBounty, function(val) Config.AutoBounty = val; if not val and not Config.AutoPosition then releaseCombatLock() end end)
    SecActivities:AddToggle("🎯 Auto Challenges (Thử Thách)", Config.AutoChallenge, function(val)
        Config.AutoChallenge = val
        if val then
            Config.AutoMissionFarm, Config.MissionAutoTeleport = true, true
        elseif not Config.AutoMission and not Config.AutoPosition then
            releaseCombatLock()
        end
    end)
    SecActivities:AddToggle("⚔️ Auto Missions (Phó Bản)", Config.AutoMission, function(val)
        Config.AutoMission = val
        if val then Config.AutoMissionFarm, Config.MissionAutoTeleport = true, true
        elseif not Config.AutoChallenge and not Config.AutoPosition then releaseCombatLock() end
    end)
    SecActivities:AddToggle("💥 Tự Đánh Trong Phó Bản", Config.AutoMissionFarm, function(val) Config.AutoMissionFarm = val; if not val and not Config.AutoPosition then releaseCombatLock() end end)
    SecActivities:AddToggle("🔄 Tự Đi Tiếp / Chơi Lại (Auto Replay)", Config.AutoReplayMission, function(val) Config.AutoReplayMission = val end)
    SecActivities:AddToggle("🛡️ Tự Né Vùng Đỏ Boss (Auto Dodge)", Config.AutoDodge, function(val) Config.AutoDodge = val; if not val then Config.IsCurrentlyDodging = false end end)
    SecActivities:AddButton("💎 Nhận Hết Thưởng 1-Chạm (All Rewards)", claimAllRewardsOneClick)
    local PRIORITY_CHOICE_ITEMS = { "Quest (Cốt Truyện)", "Invasion (Xâm Lược)", "Bounty (Tiền Thưởng)", "Challenge (Thử Thách)", "Mission (Phó Bản)" }
    SecActivities:AddDropdown("👑 Thứ Tự Ưu Tiên", {
        "Mặc Định: Quest > Invasion > Bounty > Challenge > Mission",
        "Săn Sự Kiện: Invasion > Challenge > Quest > Bounty > Mission",
        "Cày Thử Thách: Challenge > Invasion > Bounty > Quest > Mission",
        "Cày Phó Bản: Mission > Invasion > Challenge > Quest > Bounty",
        "Tùy Chỉnh: Theo 5 Ô Bên Dưới"
    }, Config.PriorityPreset, false, function(val) Config.PriorityPreset = tostring(val or "Mặc Định (Quest -> Invasion -> Bounty -> Challenge -> Mission)"); getResolvedPriorityOrder() end)
    for slotIdx = 1, 5 do
        local defaultLabel = PRIORITY_CHOICE_ITEMS[slotIdx]
        SecActivities:AddDropdown(string.format("🔢 Ưu Tiên %d", slotIdx), PRIORITY_CHOICE_ITEMS, defaultLabel, false, function(val)
            Config.CustomPrioritySlots[slotIdx] = parsePriorityKey(val) or ALL_PRIORITY_KEYS[slotIdx]
            if not tostring(Config.PriorityPreset or ""):find("Tùy Chỉnh") then Config.PriorityPreset = "Tùy Chỉnh: Theo 5 Ô Bên Dưới" end
            getResolvedPriorityOrder()
        end)
    end
    SecConfig:AddDropdown("Chế Độ Gamemode", { "Mission (Phó Bản & EX)", "Challenge (Thử Thách)", "Gauntlet (Tháp 1-10)", "Invasion (Xâm Lược)" }, "Mission (Phó Bản & EX)", false, function(val) local s = tostring(val or ""); Config.MissionGamemode = s:find("Challenge") and "Challenge" or (s:find("Gauntlet") and "Gauntlet" or (s:find("Invasion") and "Invasion" or "Mission")) end)
    SecConfig:AddDropdown("Loại Challenge", { "Tất Cả (Daily > Weekly > Regular)", "Daily (2.5k Gems + 10 Rerolls)", "Weekly (5k Gems + 50 Rerolls)", "Regular (Slot 1)", "Regular (Slot 2)", "Regular (Slot 3)" }, Config.ChallengeSelectedTier, false, function(val) Config.ChallengeSelectedTier = val end)
    SecConfig:AddDropdown("Chọn Cốt Truyện (Questline)", { "Tự Động (Theo Tiến Độ)", "Nemu's Questline (World 1)", "Kisky's Questline (World 2)", "Sang Woo's Questline (World 3)" }, Config.QuestlineSelected, false, function(val) Config.QuestlineSelected = val end)
    SecConfig:AddDropdown("Chọn World (Phó Bản)", { "Nemu's Village", "Hollow World", "Demon Citadel" }, "Nemu's Village", false, function(val) Config.MissionWorld = tostring(val or "Nemu's Village") end)
    SecConfig:AddDropdown("Chọn Màn (Act)", { "Act 1", "Act 2", "Act 3", "Act 4 (EX 10 Waves)" }, "Act 1", false, function(val) local a = tostring(val or ""):match("%d+"); Config.MissionAct = a and tonumber(a) or 1 end)
    SecConfig:AddDropdown("Độ Khó", { "Normal", "Hard" }, "Normal", false, function(val) Config.MissionMode = tostring(val or "Normal") end)
    SecConfig:AddSlider("Tầng Gauntlet (Chamber)", 1, 1, 10, 0, function(val) Config.GauntletChamber = math.clamp(math.floor(tonumber(val) or 1), 1, 10) end)
    SecConfig:AddDropdown("Khi Xong Màn", { "Chơi Lại (Retry)", "Đi Tiếp (Next)", "Thoát Ra Map (Return)" }, "Chơi Lại (Retry)", false, function(val) local s = tostring(val or ""); Config.MissionDecisionType = (s:find("Next") or s:find("Tiếp")) and "Next" or ((s:find("Return") or s:find("Thoát")) and "Return" or "Retry") end)
    SecConfig:AddButton("🚀 Vào Màn Đã Chọn (Launch)", function()
        pcall(function()
            if Config.MissionGamemode == "Challenge" then launchConfiguredChallenge() else launchConfiguredMission() end
            notify("Gamemode", "Đã gửi lệnh vào Hoạt Động / Phó Bản!", 3)
        end)
    end)
    SecConfig:AddButton("🚪 Thoát Ra Map (Leave)", function()
        pcall(function()
            if RemoteBank.MissionDecision then RemoteBank.MissionDecision:Fire("Return") end
            if RemoteBank.MissionReturn then RemoteBank.MissionReturn:Fire() end
            notify("Gamemode", "Đã gửi lệnh rời khỏi Hoạt Động!", 3)
        end)
    end)
    local PartyStatusLabel = SecConfig:AddLabel("👥 Tổ Đội (Party): Đang đi Solo (1/4)", false)
    task.spawn(function()
        while isScriptRunning do
            pcall(function()
                if currentPartyState.active and type(currentPartyState.members) == "table" and #currentPartyState.members > 0 then
                    local names = {}
                    for _, m in ipairs(currentPartyState.members) do if type(m) == "table" then table.insert(names, (m.isLeader and "★" or "") .. tostring(m.name or m.userId)) end end
                    PartyStatusLabel:Set(string.format("👥 Tổ Đội (%d/4): %s", #currentPartyState.members, table.concat(names, ", ")))
                else
                    PartyStatusLabel:Set(string.format("👥 Tổ Đội: Solo (Vai trò: %s)", isPartyHostMode() and "👑 Chủ Phòng" or (isPartyGuestMode() and "🤝 Thành Viên" or "Tắt")))
                end
            end)
            task.wait(1.0)
        end
    end)
    local function getServerPlayerDropdownList()
        local items = { "[Tất Cả Người Chơi]" }
        for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LocalPlayer then table.insert(items, plr.Name) end end
        return items
    end
    SecConfig:AddDropdown("👥 Chế Độ Tổ Đội (Party)", { "Tắt (Solo)", "👑 Chủ Phòng (Tự Mời & Kéo Team)", "🤝 Thành Viên (Tự Theo Chủ Phòng)" }, Config.PartyRole, false, function(val)
        Config.PartyRole = tostring(val or "Tắt (Đi Solo)")
        if isPartyGuestMode() then
            Config.AutoMissionFarm, Config.MissionAutoTeleport = true, true; notify("Co-op Party (Thành Viên)", "Đã bật tự động nhận lời mời & tự đánh theo Chủ Phòng!", 3)
        elseif isPartyHostMode() then
            notify("Co-op Party (Chủ Phòng)", "Đã bật chế độ Chủ Phòng: Tự mời đồng đội trước khi vào Gamemode!", 3)
        end
    end)
    local PartyPlayerDrop = SecConfig:AddDropdown("🎯 Chọn Người Chơi Để Mời", getServerPlayerDropdownList(), Config.PartyTargetPlayers, true, function(val)
        if type(val) == "table" then Config.PartyTargetPlayers = val
        elseif type(val) == "string" then Config.PartyTargetPlayers = { val } end
    end)
    SecConfig:AddButton("🔄 Làm Mới DS Người Chơi", function()
        pcall(function()
            local list = getServerPlayerDropdownList()
            if PartyPlayerDrop and typeof(PartyPlayerDrop.Refresh) == "function" then
                PartyPlayerDrop:Refresh(list); PartyPlayerDrop:Set({ "[Tất Cả Người Chơi]" }); Config.PartyTargetPlayers = { "[Tất Cả Người Chơi]" }
            end
            notify("Co-op Party", string.format("Đã cập nhật %d người chơi khác trong server!", math.max(0, #list - 1)), 3)
        end)
    end)
    SecConfig:AddToggle("⏳ Đợi Đủ Đội Mới Bắt Đầu", Config.PartyWaitMembers, function(val) Config.PartyWaitMembers = val end)
    SecConfig:AddButton("📨 Gửi Lời Mời Tổ Đội (Invite)", function()
        pcall(function()
            local actNum = tonumber(Config.MissionAct) or 1; local w = Config.MissionWorld or "Nemu's Village"
            local m = (actNum == 4) and "Hard" or (Config.MissionMode or "Normal"); local invited = inviteSelectedPlayersToParty({ world = w, act = actNum, mode = m })
            notify("Co-op Party", string.format("Đã gửi lời mời tổ đội tới %d người chơi đã chọn!", invited), 3)
        end)
    end)
    SecConfig:AddButton("🚪 Rời / Giải Tán Đội (Leave Party)", function()
        pcall(function()
            if RemoteBank and RemoteBank.PartyLeave then RemoteBank.PartyLeave:Fire(nil) end
            currentPartyState.active = false; currentPartyState.leaderId = nil
            currentPartyState.members = {}; notify("Co-op Party", "Đã gửi lệnh rời khỏi / giải tán Tổ Đội!", 3)
        end)
    end)
    SecConfig:AddToggle("📍 Tự Chuyển World Khi Làm Quest", Config.QuestAutoTeleportWorld, function(val) Config.QuestAutoTeleportWorld = val end)
    SecConfig:AddToggle("🎯 Tự Tele Áp Sát Quái (Quest & Màn)", Config.QuestAutoTeleport, function(val)
        Config.QuestAutoTeleport, Config.BountyAutoTeleport, Config.InvasionAutoTeleport, Config.MissionAutoTeleport = val, val, val, val
        if not val and not Config.AutoPosition then releaseCombatLock() end
    end)
    SecConfig:AddToggle("🎁 Tự Nhận & Trả Thưởng Quest", Config.QuestAutoClaim, function(val) Config.QuestAutoClaim, Config.QuestAutoAccept = val, val end)
    SecConfig:AddToggle("✨ Tự Dùng Skill Khi Làm Quest", Config.QuestAutoSkills, function(val) Config.QuestAutoSkills, Config.BountyAutoSkills, Config.InvasionAutoSkills, Config.MissionAutoSkills = val, val, val, val end)
    SecConfig:AddToggle("🛑 Dừng Khi Đạt Cap Invasion (10k Gems)", Config.InvasionFarmUntilCap, function(val) Config.InvasionFarmUntilCap = val end)
end)

-- TAB 3: CRAFT (TỰ ĐỘNG GHÉP ĐỒ / STAR FRUITS & ACCESSORIES)
do
    local CraftingMod = safeRequire(DataModules and DataModules:FindFirstChild("Economy") and DataModules.Economy:FindFirstChild("Crafting"))
    local CurrenciesMod = safeRequire(DataModules and DataModules:FindFirstChild("Economy") and DataModules.Economy:FindFirstChild("Currencies"))
    local COLOR_FRUITS = { "Star Fruit [Yellow]", "Star Fruit [Red]", "Star Fruit [Pink]", "Star Fruit [Green]", "Star Fruit [Blue]" }
    local FALLBACK_RECIPES = {
        ["Star Fruit [Yellow]"] = { Recipe = { { name = "Star Fruit [Dead]", quantity = 3 } } },
        ["Star Fruit [Red]"] = { Recipe = { { name = "Star Fruit [Dead]", quantity = 3 } } },
        ["Star Fruit [Pink]"] = { Recipe = { { name = "Star Fruit [Dead]", quantity = 3 } } },
        ["Star Fruit [Green]"] = { Recipe = { { name = "Star Fruit [Dead]", quantity = 3 } } },
        ["Star Fruit [Blue]"] = { Recipe = { { name = "Star Fruit [Dead]", quantity = 3 } } },
        ["Star Fruit [Rainbow]"] = { Recipe = {
            { name = "Star Fruit [Yellow]", quantity = 1 }, { name = "Star Fruit [Red]", quantity = 1 },
            { name = "Star Fruit [Green]", quantity = 1 }, { name = "Star Fruit [Blue]", quantity = 1 },
            { name = "Star Fruit [Pink]", quantity = 1 }
        } },
        ["Jewelled Headband"] = { Recipe = {
            { name = "Star Fruit [Yellow]", quantity = 5 }, { name = "Star Fruit [Red]", quantity = 5 },
            { name = "Star Fruit [Pink]", quantity = 5 }, { name = "Star Fruit [Blue]", quantity = 5 },
            { name = "Star Fruit [Green]", quantity = 5 }, { name = "Star Fruit [Rainbow]", quantity = 2 }
        } },
        ["Demon Anklet"] = { Recipe = {
            { name = "Star Fruit [Pink]", quantity = 6 }, { name = "Star Fruit [Blue]", quantity = 13 },
            { name = "Star Fruit [Green]", quantity = 6 }, { name = "Star Fruit [Rainbow]", quantity = 2 }
        } }
    }

    local function getRecipesTable()
        local merged = {}
        for k, v in pairs(FALLBACK_RECIPES) do merged[k] = v end
        if type(CraftingMod) == "table" and type(CraftingMod.Recipes) == "table" then
            for k, v in pairs(CraftingMod.Recipes) do if type(v) == "table" and type(v.Recipe) == "table" then merged[k] = v end end
        end
        return merged
    end

    local function getMaterialOwned(itemName)
        if not itemName then return 0 end
        local val = 0
        pcall(function()
            if DataClient and typeof(DataClient.Get) == "function" then
                local rootData = DataClient.Get()
                if CurrenciesMod and typeof(CurrenciesMod.GetOwned) == "function" and type(rootData) == "table" then
                    val = tonumber(CurrenciesMod.GetOwned(rootData, itemName)) or 0
                end
                if val <= 0 and type(rootData) == "table" and type(rootData.Materials) == "table" then
                    val = tonumber(rootData.Materials[itemName]) or 0
                end
                if val <= 0 then
                    local mats = DataClient.Get("Materials")
                    if type(mats) == "table" then val = tonumber(mats[itemName]) or 0 end
                end
            end
        end)
        return math.max(0, math.floor(val))
    end

    local function _getGearOwnedCount(gearName)
        local count = getMaterialOwned(gearName)
        pcall(function()
            if DataClient and typeof(DataClient.Get) == "function" then
                local gears = DataClient.Get("Gears")
                if type(gears) == "table" then
                    for _, entry in pairs(gears) do
                        if type(entry) == "table" and (entry.Gear == gearName or entry.Name == gearName) then count = count + 1 end
                    end
                end
            end
        end)
        return count
    end

    local function getAffordableCount(recipeName, virtualMatMap)
        local def = getRecipesTable()[recipeName]
        if not def or type(def.Recipe) ~= "table" or #def.Recipe == 0 then return 0 end
        local maxCraft = math.huge
        for _, req in ipairs(def.Recipe) do
            local q = tonumber(req.quantity) or 1
            if q > 0 then
                local owned = (type(virtualMatMap) == "table" and virtualMatMap[req.name] ~= nil) and virtualMatMap[req.name] or getMaterialOwned(req.name)
                maxCraft = math.min(maxCraft, math.floor(math.max(0, owned) / q))
            end
        end
        return (maxCraft == math.huge) and 0 or math.max(0, maxCraft)
    end

    local function fireCraftRemote(recipeName, amount)
        local qty = math.floor(tonumber(amount) or 0)
        if qty < 1 or not RemoteBank or not RemoteBank.Craft then return 0 end
        pcall(function() RemoteBank.Craft:Fire(recipeName, qty) end)
        return qty
    end

    local function craftColorFruitsFromDead()
        local deadOwned = getMaterialOwned("Star Fruit [Dead]")
        local totalCrafts = math.floor(deadOwned / 3)
        if totalCrafts < 1 then return 0, {} end
        local strat = tostring(Config.CraftColorStrategy or "")

        -- Strategy 1: Chỉ Ghép 1 màu chỉ định
        for _, cName in ipairs(COLOR_FRUITS) do
            local shortColor = cName:match("%[(.-)%]")
            if shortColor and strat:find("Chỉ Ghép") and strat:find(shortColor, 1, true) then
                local done = fireCraftRemote(cName, totalCrafts)
                return done, { [cName] = done }
            end
        end

        local plan = {}

        -- Strategy 2: Cân Bằng 5 Hệ (Ưu Tiên Màu Đang Ít Nhất)
        if strat:find("Cân Bằng") then
            local simCounts = {}
            for _, cName in ipairs(COLOR_FRUITS) do
                simCounts[cName] = getMaterialOwned(cName)
            end
            for _ = 1, totalCrafts do
                local minCount, chosenColor = math.huge, COLOR_FRUITS[1]
                for _, cName in ipairs(COLOR_FRUITS) do
                    local count = simCounts[cName] or 0
                    if count < minCount then
                        minCount = count
                        chosenColor = cName
                    end
                end
                simCounts[chosenColor] = (simCounts[chosenColor] or 0) + 1
                plan[chosenColor] = (plan[chosenColor] or 0) + 1
            end

        -- Strategy 3 (Mặc Định): Xoay Vòng 5 Hệ (1 Cái 1 Lần, Lưu Vết Hết Màu)
        else
            local curIdx = tonumber(RT.craftNextColorIndex or Config.CraftNextColorIndex) or 1
            if curIdx < 1 or curIdx > #COLOR_FRUITS then curIdx = 1 end
            for _ = 1, totalCrafts do
                local cName = COLOR_FRUITS[curIdx]
                plan[cName] = (plan[cName] or 0) + 1
                curIdx = (curIdx % #COLOR_FRUITS) + 1
            end
            RT.craftNextColorIndex = curIdx
            Config.CraftNextColorIndex = curIdx
        end

        local craftedTotal = 0
        local planList = {}
        for _, cName in ipairs(COLOR_FRUITS) do
            local amt = plan[cName] or 0
            if amt > 0 then
                local done = fireCraftRemote(cName, amt)
                if done > 0 then
                    craftedTotal = craftedTotal + done
                    local short = cName:match("%[(.-)%]") or cName
                    table.insert(planList, string.format("%s:+%d", short, done))
                end
                task.wait(0.35)
            end
        end

        if craftedTotal > 0 and #planList > 0 then
            notify("Auto Craft Ngũ Sắc", string.format("Đã ghép +%d Quả (%s)", craftedTotal, table.concat(planList, ", ")), 3)
        end

        return craftedTotal, plan
    end

    local function craftRainbowFruits()
        local maxPossible = getAffordableCount("Star Fruit [Rainbow]")
        if maxPossible < 1 then return 0 end
        local done = fireCraftRemote("Star Fruit [Rainbow]", maxPossible)
        if done > 0 then
            notify("Auto Craft Rainbow", string.format("Đã tự ghép +%d Star Fruit [Rainbow]!", done), 3)
        end
        return done
    end

    local function runCraftPipeline()
        local totalColor, totalRb = 0, 0
        if Config.AutoCraftColorFruits then
            local count = craftColorFruitsFromDead()
            totalColor = count or 0
            if totalColor > 0 then task.wait(0.35) end
        end
        if Config.AutoCraftRainbowFruit then
            local count = craftRainbowFruits()
            totalRb = count or 0
        end
        return totalColor, totalRb
    end

    task.spawn(function()
        while isScriptRunning do
            if Config.AutoCraftColorFruits or Config.AutoCraftRainbowFruit then
                pcall(runCraftPipeline)
                task.wait(2.0)
            else
                task.wait(1.2)
            end
        end
    end)

    pcall(function()
        local TabCraft = Window:CreateTab("Craft")
        local SecAutoCraft = TabCraft:CreateSector("⚡ Tự Động Ghép Quả", "left")
        local SecManualCraft = TabCraft:CreateSector("🔨 Ghép Thủ Công & Tiện Ích", "right")
        local CraftDeadLabel = SecAutoCraft:AddLabel("🍎 Star Fruit [Dead]: Đang tải...", false)
        local CraftColorLabel = SecAutoCraft:AddLabel("🎨 Ngũ Sắc: Đang tải...", false)

        task.spawn(function()
            while isScriptRunning do
                if not isUIVisible() then
                    task.wait(3.0)
                else
                    pcall(function()
                        local dead = getMaterialOwned("Star Fruit [Dead]")
                        local rb = getMaterialOwned("Star Fruit [Rainbow]")
                        local y, r, p, g, b = getMaterialOwned("Star Fruit [Yellow]"), getMaterialOwned("Star Fruit [Red]"), getMaterialOwned("Star Fruit [Pink]"), getMaterialOwned("Star Fruit [Green]"), getMaterialOwned("Star Fruit [Blue]")
                        local rbCan = getAffordableCount("Star Fruit [Rainbow]")
                        local colorIcons = { [1] = "🟡Y", [2] = "🔴R", [3] = "🌸P", [4] = "🟢G", [5] = "🔵B" }
                        local nextColorStr = colorIcons[RT.craftNextColorIndex or 1] or "🟡Y"
                        local strat = tostring(Config.CraftColorStrategy or "")
                        local stratTag = strat:find("Cân Bằng") and "Cân Bằng" or (strat:find("Xoay Vòng") and ("Kế: " .. nextColorStr) or "Chỉ Ghép")
                        CraftDeadLabel:Set(string.format("🍎 Dead: %d (Ghép +%d | %s)", dead, math.floor(dead / 3), stratTag))
                        CraftColorLabel:Set(string.format("🎨 Ngũ Sắc: 🟡Y:%d | 🔴R:%d | 🌸P:%d | 🟢G:%d | 🔵B:%d | 🌈Rb:%d (+%d)", y, r, p, g, b, rb, rbCan))
                    end)
                    task.wait(1.5)
                end
            end
        end)

        SecAutoCraft:AddToggle("🍎 Tự Ghép Dead -> 5 Hệ Màu", Config.AutoCraftColorFruits, function(val)
            Config.AutoCraftColorFruits = val
        end)
        SecAutoCraft:AddDropdown("🧠 Chiến Lược Ghép Màu", {
            "Cân Bằng 5 Hệ (Ưu Tiên Màu Ít Nhất)",
            "Xoay Vòng 5 Hệ (1 Cái/Lần, Lưu Vết)",
            "Chỉ Ghép Star Fruit [Yellow]",
            "Chỉ Ghép Star Fruit [Red]",
            "Chỉ Ghép Star Fruit [Pink]",
            "Chỉ Ghép Star Fruit [Green]",
            "Chỉ Ghép Star Fruit [Blue]"
        }, Config.CraftColorStrategy, false, function(val)
            Config.CraftColorStrategy = tostring(val or "")
        end)
        SecAutoCraft:AddToggle("🌈 Tự Ghép 5 Hệ Màu -> Rainbow", Config.AutoCraftRainbowFruit, function(val)
            Config.AutoCraftRainbowFruit = val
        end)

        local ALL_RECIPE_NAMES = {
            "Star Fruit [Rainbow]",
            "Jewelled Headband",
            "Demon Anklet",
            "Star Fruit [Yellow]",
            "Star Fruit [Red]",
            "Star Fruit [Pink]",
            "Star Fruit [Green]",
            "Star Fruit [Blue]"
        }
        SecManualCraft:AddDropdown("📜 Chọn Công Thức Ghép", ALL_RECIPE_NAMES, Config.CraftManualRecipe, false, function(val)
            Config.CraftManualRecipe = tostring(val or "Star Fruit [Rainbow]")
        end)
        SecManualCraft:AddSlider("🔢 Số Lượng Ghép", 1, 1, 100, 0, function(val)
            Config.CraftManualAmount = math.clamp(math.floor(tonumber(val) or 1), 1, 100)
        end)
        SecManualCraft:AddButton("🔨 Ghép Theo Số Lượng Đã Chọn", function()
            pcall(function()
                local rName = Config.CraftManualRecipe or "Star Fruit [Rainbow]"
                local amt = math.max(1, tonumber(Config.CraftManualAmount) or 1)
                fireCraftRemote(rName, amt)
                notify("Manual Craft", string.format("Đã gửi lệnh ghép %s (x%d)!", tostring(rName), amt), 3)
            end)
        end)
        SecManualCraft:AddButton("🔥 Ghép Tối Đa Có Thể (Craft Max)", function()
            pcall(function()
                local rName = Config.CraftManualRecipe or "Star Fruit [Rainbow]"
                local maxAmt = getAffordableCount(rName)
                if maxAmt > 0 then
                    fireCraftRemote(rName, maxAmt)
                    notify("Craft Max", string.format("Đã gửi lệnh ghép tối đa %s (x%d)!", tostring(rName), maxAmt), 3)
                else
                    notify("Craft Max", string.format("Không đủ nguyên liệu để ghép %s!", tostring(rName)), 3)
                end
            end)
        end)
        SecManualCraft:AddButton("🚶 Teleport Tới Thợ Rèn Bamee (Lobby)", function()
            pcall(function()
                local lobby = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Lobby")
                local npc = lobby and lobby:FindFirstChild("NPCs") and lobby.NPCs:FindFirstChild("Crafting")
                if not npc then
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if obj:IsA("Model") and (obj.Name == "Crafting" or obj.Name:find("Bamee")) then npc = obj; break end
                    end
                end
                local nRoot = npc and getMobRoot(npc)
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if nRoot and root then
                    releaseCombatLock()
                    root.CFrame = nRoot.CFrame + (nRoot.CFrame.LookVector * 3.5) + Vector3.new(0, 1, 0)
                    root.AssemblyLinearVelocity = Vector3.zero
                    notify("Crafting NPC", "Đã dịch chuyển tới trước mặt Thợ Rèn Bamee!", 3)
                else
                    notify("Crafting NPC", "Không tìm thấy NPC Bamee (Thợ Rèn chỉ có ở Lobby)!", 3)
                end
            end)
        end)
    end)
end

-- TAB 4: GACHA & BUY (QUAY THẺ GACHA, AUTO SELL GEARS & CỬA HÀNG MERCHANT BOB E.O)
pcall(function()
    local TabGachaBuy = Window:CreateTab("Gacha & Buy"); local SecGacha = TabGachaBuy:CreateSector("Quay Thẻ & Bán Gear", "left")
    local SecMerchant = TabGachaBuy:CreateSector("Cửa Hàng Bob E.O", "right")
    local GemsLabel = SecGacha:AddLabel("Tài Nguyên: Đang kiểm tra...", false)
    local GearStorageLabel = SecGacha:AddLabel("Kho Gear: Đang kiểm tra...", false)
    task.spawn(function()
        while isScriptRunning do
            if not isUIVisible() then
                task.wait(3.0)
            else
                pcall(function()
                    local gems = getPlayerCurrency("Gems")
                    GemsLabel:Set(string.format("💎 Gems: %s", Format and Format.formatWithCommas and Format.formatWithCommas(gems) or tostring(gems)))
                    local totalG, eqG, lockG = getGearInventorySummary(); GearStorageLabel:Set(string.format("🛡️ Kho Gear: %d (Mặc: %d | Khóa: %d)", totalG, eqG, lockG))
                end)
                task.wait(2.0)
            end
        end
    end)
    SecGacha:AddToggle("Tự Quay Thẻ (Auto Summon)", Config.AutoSummon, function(val) Config.AutoSummon = val end)
    SecGacha:AddDropdown("Chọn Banner", { "Standard Powers (Kỹ Năng)", "Standard Weapons (Vũ Khí)" }, "Standard Powers (Kỹ Năng)", false, function(val) local s = tostring(val or ""):lower(); Config.SummonBanner = (s:find("weapon") or s:find("vũ khí") or s:find("kiếm")) and "Standard Weapons" or "Standard Powers" end)
    SecGacha:AddDropdown("Số Lượt Quay", { "1 Lượt (50 Gems)", "10 Lượt (500 Gems)", "50 Lượt (2.5k Gems)" }, "1 Lượt (50 Gems)", false, function(val) local s = tostring(val or ""); Config.SummonCount = s:find("50") and 50 or (s:find("10") and 10 or 1) end)
    SecGacha:AddButton("✨ Quay Ngay (Summon Now)", function()
        pcall(function() doPullBanner(Config.SummonBanner, Config.SummonCount); notify("Gacha Summon", string.format("Đã gửi lệnh quay %s (x%d lượt)!", tostring(Config.SummonBanner), tonumber(Config.SummonCount) or 1), 3) end)
    end)
    SecGacha:AddToggle("♻️ Tự Bán Gear (Auto Sell)", Config.AutoSellGears, function(val) Config.AutoSellGears = val end)
    SecGacha:AddDropdown("Chọn Loại Gear Cần Bán", {
        "[Tất Cả Gear]",
        "Set: Battle Armor (World 1)",
        "Set: Ex Captain (World 2)",
        "Set: Shadow Commander (World 3)",
        "Set: Knight",
        "Alien Scouter", "Battle-Armor Chestplate", "Battle-Armor Legs",
        "Ex Captain's Hat", "Ex Captain's Cloak", "Ex Captain's Pants",
        "Commander's Helmet", "Commander's Chestplate", "Commander's Greaves",
        "Ruby Pendant", "Knight's Chestplate", "Knight's Greaves"
    }, Config.SelectedSellGears, true, function(val)
        if typeof(val) == "table" then Config.SelectedSellGears = val
        elseif typeof(val) == "string" then Config.SelectedSellGears = { val } end
    end)
    SecGacha:AddToggle("🏆 Giữ 1 Món Chỉ Số Cao Nhất (Keep Best)", Config.KeepBestGearPerName, function(val) Config.KeepBestGearPerName = val end)
    SecGacha:AddToggle("🌟 Giữ Lại Gear Tốt (Roll >= 90%)", Config.ProtectHighRollGears, function(val) Config.ProtectHighRollGears = val end)
    SecGacha:AddButton("💰 Bán Gear Đã Chọn (Sell Now)", function()
        pcall(function()
            local sold = sellSelectedGears()
            if sold > 0 then notify("Sell Gears", string.format("Đã bán thành công %d món Gear theo bộ lọc!", sold), 3) else notify("Sell Gears", "Không có món Gear nào cần bán (đã trừ đồ đang mặc, đã khóa & món tốt nhất)!", 3) end
        end)
    end)
    local RestockLabel = SecMerchant:AddLabel("Đổi Hàng: Đang tính...", false)
    local CoinsLabel = SecMerchant:AddLabel("Tiền Yen: Đang kiểm tra...", false)
    local StockSummaryLabel = SecMerchant:AddLabel("Hàng Trong Shop: Đang tải...", false)
    task.spawn(function()
        while isScriptRunning do
            if not isUIVisible() then
                task.wait(3.0)
            else
                pcall(function()
                    local stock, timeLeft, period = getMerchantStock()
                    if timeLeft and timeLeft > 0 then
                        RestockLabel:Set(string.format("⏳ Shop Đổi Hàng Sau: %02d:%02d:%02d", math.floor(timeLeft / 3600), math.floor((timeLeft % 3600) / 60), math.floor(timeLeft % 60)))
                    else
                        RestockLabel:Set("⏳ Shop Vừa Đổi Hàng!")
                    end
                    local coins = getPlayerCurrency("Coins")
                    CoinsLabel:Set(string.format("🪙 Tiền Yen: %s", Format and Format.formatWithCommas and Format.formatWithCommas(coins) or tostring(coins)))
                    if stock and #stock > 0 then
                        local summary = {}
                        for i, sl in ipairs(stock) do
                            local rem = getRemainingSlotStock(sl, i, period)
                            if rem > 0 then table.insert(summary, string.format("%s (%d)", sl.Item, rem)) end
                        end
                        StockSummaryLabel:Set(#summary > 0 and ("Hàng Còn: " .. table.concat(summary, ", ")) or "Hàng Còn: Đã bán hết toàn bộ!")
                    else
                        StockSummaryLabel:Set("Hàng Trong Shop: Chưa mở kho hàng")
                    end
                end)
                task.wait(2.0)
            end
        end
    end)
    SecMerchant:AddToggle("🛒 Tự Mua Hàng Merchant (Auto Buy)", Config.AutoBuyMerchant, function(val) Config.AutoBuyMerchant = val end)
    SecMerchant:AddDropdown("Chọn Vật Phẩm Cần Mua", {
        "[Tất Cả Vật Phẩm]", "Trait Rerolls", "Stat Cubes", "Stat Prisms", "Weapon Rerolls", "Souls", "Pure Cloud", "Chief Toad",
        "Star Fruit (Tất Cả)", "Star Fruit [Rainbow]", "Star Fruit [Yellow]", "Star Fruit [Green]", "Star Fruit [Red]", "Star Fruit [Blue]", "Star Fruit [Pink]", "Star Fruit [Dead]"
    }, Config.SelectedShopItems, true, function(val)
        if typeof(val) == "table" then Config.SelectedShopItems = val
        elseif typeof(val) == "string" then Config.SelectedShopItems = { val } end
    end)
    SecMerchant:AddButton("🛍️ Mua Ngay Vật Phẩm Đã Chọn", function() pcall(function() local bought = purchaseSelectedMerchantItems(); notify("Merchant Shop", string.format("Đã gửi lệnh mua %d vật phẩm đã chọn!", bought), 3) end) end)
    SecMerchant:AddButton("🚶 Teleport Tới Bob E.O (Lobby)", function()
        pcall(function()
            local bob = findBobEOModel(); local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); local bRoot = bob and getMobRoot(bob)
            if bRoot and root then
                releaseCombatLock(); root.CFrame = bRoot.CFrame + (bRoot.CFrame.LookVector * 3.5) + Vector3.new(0, 1, 0)
                root.AssemblyLinearVelocity = Vector3.zero; notify("Merchant", "Đã dịch chuyển tới trước mặt Bob E.O!", 3)
                return
            end
            notify("Merchant", "Không tìm thấy NPC Bob E.O trong map này (Bob E.O ở Lobby)!", 3)
        end)
    end)
end)

-- TAB 5: TIỆN ÍCH, NHẬN THƯỞNG & SIÊU TỐI ƯU HIỆU NĂNG (MISC & SYSTEM)
pcall(function()
    local TabMisc = Window:CreateTab("Tiện Ích"); local SecCodes = TabMisc:CreateSector("🎁 Nhận Thưởng & Sự Kiện", "left")
    local SecSystem = TabMisc:CreateSector("⚡ Tối Ưu Game & Multi-Acc", "right")
    SecCodes:AddButton("💎 Nhận Hết Thưởng 1-Chạm (All Rewards)", claimAllRewardsOneClick)
    SecCodes:AddButton("🎁 Tự Nhập Hết Code (Redeem All)", redeemAllCodes)
    SecCodes:AddTextbox("Nhập Code Thủ Công", Config.CustomCodeInput or "", function(text) Config.CustomCodeInput = tostring(text or ""):gsub("%s+", "") end)
    SecCodes:AddButton("Nhập Mã Code Này", function()
        local code = tostring(Config.CustomCodeInput or ""):gsub("%s+", "")
        if #code > 0 then
            pcall(function() if RemoteBank and RemoteBank.RedeemCode then RemoteBank.RedeemCode:Fire(code) end end); notify("Nhập Code", "Đã gửi yêu cầu nhập mã: " .. code, 3)
        else
            notify("Nhập Code", "Vui lòng nhập mã code vào ô trước khi bấm!", 3)
        end
    end)
    SecCodes:AddButton("🌟 Nhận Quà Sự Kiện (Update Event)", function() local count = claimAllUpdateEvents(); notify("Sự Kiện Update", string.format("Đã gửi yêu cầu nhận thưởng cho %d thẻ sự kiện!", count), 3) end)
    SecCodes:AddToggle("Nút Menu Tròn Nổi (Floating Button)", Config.FloatingMenuButton ~= false, function(val) Config.FloatingMenuButton = val; setFloatingButtonVisible(val) end)
    SecCodes:AddButton("Ẩn / Hiện Menu (Toggle GUI)", function() if Window and Window.Frame then Window.Frame.Visible = not Window.Frame.Visible end end)
    SecCodes:AddButton("🐎 Bật / Tắt Thú Cưỡi (Toggle Mount)", function() pcall(function() if RemoteBank and RemoteBank.MountToggle then RemoteBank.MountToggle:Fire() end end) end)
    SecSystem:AddToggle("🖥️ Headless (Tắt 3D, 0% GPU)", Config.HeadlessMode, setHeadlessMode)
    SecSystem:AddToggle("🚫 Tắt Hiệu Ứng Đòn Đánh & Số Dame", Config.SuppressHitFX, setVFXSuppression)
    SecSystem:AddToggle("🥔 Đồ Họa Khoai Tây (Potato Graphics)", Config.PotatoGraphics, setPotatoGraphics)
    SecSystem:AddToggle("🌑 Tắt Bóng Râm & Ánh Sáng", Config.DisableLightingEffects, setLightingOptimization)
    SecSystem:AddDropdown("🎯 Khóa FPS (FPS Cap)", { "15 FPS (Treo Tiết Kiệm)", "30 FPS (Mượt Nhẹ)", "60 FPS (Mặc Định)", "120 FPS (Tần Số Cao)", "Không Giới Hạn (Uncapped)" }, "60 FPS (Mặc Định)", false, function(val)
        local str = tostring(val or "")
        if str:find("15") then applyFPSCap(15)
        elseif str:find("30") then applyFPSCap(30)
        elseif str:find("60") then applyFPSCap(60)
        elseif str:find("120") then applyFPSCap(120)
        elseif str:find("Không") or str:find("Uncap") then applyFPSCap(0) end
    end)
    SecSystem:AddToggle("🚀 Siêu Tối Ưu FPS (Super Boost)", Config.SuperBoostFPS, setSuperBoostFPS)
    local function applyCustomWalkSpeed(speed)
        pcall(function() LocalPlayer:SetAttribute("WalkSpeed", speed); local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed = speed end end)
    end
    SecSystem:AddToggle("⚡ Tùy Chỉnh Tốc Chạy (Custom Speed)", Config.CustomPlayerSpeedEnabled, function(val) Config.CustomPlayerSpeedEnabled = val; applyCustomWalkSpeed(val and (Config.PlayerWalkSpeed or 26) or 16) end)
    SecSystem:AddSlider("🏃 Tốc Độ Chạy (WalkSpeed)", 12, 26, 80, 0, function(val) Config.PlayerWalkSpeed = math.floor(tonumber(val) or 26); if Config.CustomPlayerSpeedEnabled then applyCustomWalkSpeed(Config.PlayerWalkSpeed) end end)
    SecSystem:AddToggle("Luôn Chạy Nhanh (Always Sprint)", Config.AlwaysSprint, function(val) Config.AlwaysSprint = val; applyCustomWalkSpeed(val and 28 or 16) end)
    trackConnection(RunService.Heartbeat:Connect(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and not RT.isActivelyLockingTarget then
            if Config.CustomPlayerSpeedEnabled then
                local targetSpd = math.clamp(tonumber(Config.PlayerWalkSpeed) or 26, 12, 100)
                if hum.WalkSpeed ~= targetSpd then hum.WalkSpeed = targetSpd; LocalPlayer:SetAttribute("WalkSpeed", targetSpd) end
            elseif Config.AlwaysSprint and hum.WalkSpeed < 26 then
                hum.WalkSpeed = 28; LocalPlayer:SetAttribute("WalkSpeed", 28)
            end
        end
    end))
    SecSystem:AddToggle("Chống Mất Kết Nối (Anti-AFK)", Config.AntiAFK, function(val) Config.AntiAFK = val end)
    SecSystem:AddButton("🔄 Vào Lại Server (Rejoin)", function() pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end) end)
    SecSystem:AddButton("🌐 Đổi Server Khác (Server Hop)", function()
        pcall(function()
            local ts = game:GetService("TeleportService")
            local raw = game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", game.PlaceId))
            local data = HttpService:JSONDecode(raw)
            if data and data.data then
                for _, srv in ipairs(data.data) do if srv.id ~= game.JobId and srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers - 1 then ts:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer); return end end
            end
            ts:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)
end)

-- [12] HỆ THỐNG DISCORD WEBHOOK TELEMETRY & TAB WEBHOOK
do
local RARITY_RANK = { Common = 0, Uncommon = 0, Rare = 1, Epic = 2, Legendary = 3, Mythic = 4, Exclusive = 5, Secret = 6 }
local RARITY_COLOR = { Rare = 3447003, Epic = 10181046, Legendary = 15844367, Mythic = 15158332, Exclusive = 16738740, Secret = 16711680 }

local function fmtNum(n) local num = tonumber(n) or 0; return (Format and Format.formatWithCommas and Format.formatWithCommas(math.floor(num))) or tostring(math.floor(num)) end

local function lookupCatalogInfo(itemName, fallbackRarity)
    local name = tostring(itemName or ""); local entry, catLabel = nil, "Vật Phẩm"
    if type(PowersData) == "table" and type(PowersData[name]) == "table" then
        entry, catLabel = PowersData[name], "🎴 Thẻ Kỹ Năng"
    elseif type(WeaponsData) == "table" and type(WeaponsData[name]) == "table" then
        entry, catLabel = WeaponsData[name], "⚔️ Vũ Khí"
    elseif type(GearsData) == "table" then
        local gTbl = (type(GearsData.Gears) == "table" and GearsData.Gears[name]) or GearsData[name]
        if type(gTbl) == "table" then entry, catLabel = gTbl, "🛡️ Trang Bị (Gear)" end
    end
    if not entry and type(MountsData) == "table" then
        local okM, mTbl = pcall(function() return (typeof(MountsData.Get) == "function" and MountsData.Get(name)) or MountsData[name] end)
        if okM and type(mTbl) == "table" then entry, catLabel = mTbl, "🐎 Thú Cưỡi (Mount)" end
    end
    if not entry and type(ItemsData) == "table" and type(ItemsData[name]) == "table" then entry, catLabel = ItemsData[name], "🎒 Vật Phẩm" end
    local rarity = (type(fallbackRarity) == "string" and RARITY_RANK[fallbackRarity] and fallbackRarity) or (type(entry) == "table" and entry.Rarity and tostring(entry.Rarity)) or tostring(fallbackRarity or "Rare")
    local displayName = (type(entry) == "table" and entry.DisplayName) or name
    return rarity, catLabel, displayName
end

local missionSession = { active = false, startClock = 0, elapsedSince = nil, lastWave = 0, totalWaves = 0, midDrops = {}, collectedDrops = {} }
if RemoteBank.MissionWaveUpdate and RemoteBank.MissionWaveUpdate.OnClientEvent then
    trackConnection(RemoteBank.MissionWaveUpdate.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then return end
        if not missionSession.active then
            missionSession.active = true
            missionSession.startClock = os.clock()
            missionSession.collectedDrops = {}
            table.clear(missionSession.midDrops)
        end
        if type(data.elapsedSince) == "number" then missionSession.elapsedSince = data.elapsedSince end
        if tonumber(data.wave) then missionSession.lastWave = tonumber(data.wave) end
        if tonumber(data.totalWaves) then missionSession.totalWaves = tonumber(data.totalWaves) end
    end))
end
if RemoteBank.Teleport and RemoteBank.Teleport.OnClientEvent then
    trackConnection(RemoteBank.Teleport.OnClientEvent:Connect(function(dest)
        table.clear(RT.activeTelegraphs)
        table.clear(RT.pendingDrops)
        if type(dest) == "string" and dest:find("-") then
            missionSession.active = true
            missionSession.startClock = os.clock()
            missionSession.elapsedSince = nil
            missionSession.lastWave = 0
            missionSession.totalWaves = 0
            missionSession.collectedDrops = {}
            table.clear(missionSession.midDrops)
        else
            missionSession.active = false
            missionSession.collectedDrops = {}
            table.clear(missionSession.midDrops)
        end
    end))
end

local function meetsWebhookRarityFilter(rarity, isShiny)
    local mode = tostring(Config.WebhookMinRarity or "Mythic Trở Lên")
    if mode:find("Shiny") then return isShiny == true end
    local rank = RARITY_RANK[tostring(rarity or "")] or 0
    if isShiny and rank >= 3 then return true end
    if mode:find("Secret") then return rank >= 6
    elseif mode:find("Exclusive") then return rank >= 5
    elseif mode:find("Legendary") then return rank >= 3
    else return rank >= 4 end
end

local function getAccountSummaryFields()
    local gems, coins = getPlayerCurrency("Gems"), getPlayerCurrency("Coins"); local rerolls, cubes, prisms, souls, lvl = 0, 0, 0, 0, 1
    pcall(function()
        if DataClient and typeof(DataClient.Get) == "function" then
            rerolls = tonumber(DataClient.Get("Trait Rerolls")) or 0; cubes = tonumber(DataClient.Get("Stat Cubes")) or 0
            prisms = tonumber(DataClient.Get("Stat Prisms")) or 0; souls = tonumber(DataClient.Get("Souls")) or 0; lvl = tonumber(DataClient.Get("PlrLvl")) or 1
        end
    end)
    local invSt = getInvasionStatus()
    return {
        {
            name = "📊 Tổng Quan Tài Khoản",
            value = string.format("👤 `%s` (Lv.%d) • 🗺️ `%s`\n💎 Gems: **%s** | 🪙 Yen: **%s** | 🌀 Rerolls: **%s** | 👻 Souls: **%s**\n🎲 Cubes: **%s** • Prisms: **%s** | ⚔️ Invasion: **%s/%s Gems • %s/%s Rerolls**",
                tostring(LocalPlayer.Name), lvl, tostring(getCurrentMapName()),
                fmtNum(gems), fmtNum(coins), fmtNum(rerolls), fmtNum(souls),
                fmtNum(cubes), fmtNum(prisms),
                fmtNum(invSt.gems.received), fmtNum(invSt.gems.max),
                fmtNum(invSt.rerolls.received), fmtNum(invSt.rerolls.max)
            ),
            inline = false
        }
    }
end

local function sendDiscordWebhook(title, description, color, extraFields, isTest, forcePing)
    if not isTest and not Config.WebhookEnabled then return false end
    local url = tostring(Config.WebhookURL or ""):gsub("%s+", "")
    if url == "" or not (url:find("discord%.com/api/webhooks") or url:find("discordapp%.com/api/webhooks")) then
        if isTest then notify("Webhook Lỗi", "URL Discord Webhook không hợp lệ!", 4) end
        return false
    end
    local httpReq = (env and env.syn and env.syn.request) or (env and env.http and env.http.request) or (env and env.http_request) or (env and env.request) or (env and env.fluxus and env.fluxus.request)
    if not httpReq then
        if isTest then notify("Webhook Lỗi", "Executor không hỗ trợ hàm HTTP Request!", 4) end
        return false
    end
    task.spawn(function()
        pcall(function()
            local fields = {}
            if type(extraFields) == "table" then for _, f in ipairs(extraFields) do table.insert(fields, f) end end
            for _, f in ipairs(getAccountSummaryFields()) do table.insert(fields, f) end
            local pingContent = ""
            if forcePing and Config.WebhookPingRare then
                local uid = tostring(Config.WebhookDiscordUserId or ""):match("%d+")
                pingContent = (uid and #uid > 5) and string.format("<@%s> 🚨 **PHÁT HIỆN VẬT PHẨM HIẾM!**", uid) or "@everyone 🚨 **PHÁT HIỆN VẬT PHẨM HIẾM!**"
            end
            local payload = {
                username = "HelmHub | Anime CardVerse",
                avatar_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(LocalPlayer.UserId) .. "&width=420&height=420&format=png",
                content = pingContent ~= "" and pingContent or nil,
                embeds = {{
                    title = tostring(title or "📊 Báo Cáo Anime CardVerse"),
                    description = tostring(description or ""),
                    color = tonumber(color) or 5814783,
                    thumbnail = { url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(LocalPlayer.UserId) .. "&width=150&height=150&format=png" },
                    fields = fields,
                    footer = { text = "HelmHub Production Suite • Anime CardVerse" },
            timestamp = DateTime.now():ToIsoDate() }} }
            httpReq({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload) })
            if isTest then notify("Discord Webhook", "Đã bắn thông báo thử nghiệm lên Discord thành công!", 4) end
        end)
    end)
    return true
end

local function queueDropForWebhook(itemName, rawQty, fallbackRarity, isShiny, autoSold)
    if not Config.WebhookEnabled or not Config.WebhookOnDrops then return end
    if os.clock() < (RT.suppressDropWebhookUntil or 0) then return end
    if missionSession.active or isInMission() or isInInvasion() then return end
    local rarity, catLabel, dispName = lookupCatalogInfo(itemName, fallbackRarity)
    local isItemShiny = (isShiny == true)
    if not meetsWebhookRarityFilter(rarity, isItemShiny) then return end

    local rank = RARITY_RANK[rarity] or 1
    local buf = RT.dropWebhookBuffer
    if not buf then return end
    if rank > buf.highestRank then
        buf.highestRank = rank
        buf.bestColor = RARITY_COLOR[rarity] or buf.bestColor
    end
    if rank >= 4 or isItemShiny then buf.shouldPing = true end

    local key = tostring(itemName or ""):lower()
    local qtyNum = tonumber(rawQty) or 1
    local nowClock = os.clock()

    local existing = buf.pending[key]
    if existing and (nowClock - existing.timestamp < 1.5) then
        if qtyNum > existing.qty then existing.qty = qtyNum end
        return
    end

    buf.pending[key] = {
        name = tostring(itemName),
        displayName = tostring(dispName),
        qty = qtyNum,
        rarity = rarity,
        catLabel = catLabel,
        isShiny = isItemShiny,
        autoSold = autoSold == true,
        rank = rank,
        timestamp = nowClock
    }

    if not buf.batchTimer then
        buf.batchTimer = task.delay(0.7, function()
            buf.batchTimer = nil
            local list = {}
            for _, it in pairs(buf.pending) do table.insert(list, it) end
            table.clear(buf.pending)
            if #list == 0 then return end

            table.sort(list, function(a, b)
                if a.rank ~= b.rank then return a.rank > b.rank end
                return a.qty > b.qty
            end)

            local matchedLines = {}
            for _, it in ipairs(list) do
                local shinyTag = it.isShiny and " ✨**[SHINY]**" or ""
                local soldTag = it.autoSold and " *(Auto-Sold)*" or ""
                table.insert(matchedLines, string.format("• %s **[%s]** `%s`: **x%s**%s%s", it.catLabel, it.rarity, it.displayName, fmtNum(it.qty), shinyTag, soldTag))
            end

            local ping = buf.shouldPing
            local clr = buf.bestColor
            buf.highestRank = 0
            buf.bestColor = 5814783
            buf.shouldPing = false

            sendDiscordWebhook(
                "🎁 VẬT PHẨM & PHẦN THƯỞNG MỚI (DROP REWARD)",
                string.format("🎉 Đã nhận được **%d** vật phẩm đạt ngưỡng lọc độ hiếm!", #matchedLines),
                clr,
                { { name = "📦 Danh Sách Nhận Được", value = table.concat(matchedLines, "\n"), inline = false } },
                false,
                ping
            )
        end)
    end
end

local function processGachaOrDropBatch(results, sourceTitle, isSummon)
    if type(results) ~= "table" then return end
    if isSummon and not Config.WebhookOnSummon then return end
    if not isSummon and not Config.WebhookOnDrops then return end
    local matched, highestRank, bestColor, shouldPing = {}, 0, 5814783, false
    local itemsList = (results.Name and { results }) or results
    for _, item in ipairs(itemsList) do
        if type(item) == "table" and item.Name then
            local rarity = lookupCatalogInfo(item.Name, item.Rarity)
            local isShiny = (item.Shiny == true)
            if meetsWebhookRarityFilter(rarity, isShiny) then
                local rank = RARITY_RANK[rarity] or 1
                if rank > highestRank then highestRank = rank; bestColor = RARITY_COLOR[rarity] or bestColor end
                if rank >= 4 or isShiny then shouldPing = true end
                local shinyTag = isShiny and " ✨ **[SHINY]**" or ""
                local qty = tonumber(item.Quantity) or 1; local soldTag = item.autoSold and " *(Auto-Sold)*" or ""
                table.insert(matched, string.format("• **[%s]** `%s` x%d%s%s", rarity, tostring(item.DisplayName or item.Name), qty, shinyTag, soldTag))
            end
        end
    end
    if #matched > 0 then
        sendDiscordWebhook(
            sourceTitle,
            string.format("🎉 Đã nhận được **%d** thẻ / vật phẩm đạt ngưỡng lọc độ hiếm!", #matched),
            bestColor,
            {{ name = "🎁 Danh Sách Nhận Được", value = table.concat(matched, "\n"), inline = false }},
            false,
            shouldPing
        )
    end
end

if RemoteBank.BannerResult and RemoteBank.BannerResult.OnClientEvent then trackConnection(RemoteBank.BannerResult.OnClientEvent:Connect(function(results) processGachaOrDropBatch(results, "🎴 KẾT QUẢ QUAY THẺ (POWER GACHA)", true) end)) end

if RemoteBank.WeaponSummonResult and RemoteBank.WeaponSummonResult.OnClientEvent then trackConnection(RemoteBank.WeaponSummonResult.OnClientEvent:Connect(function(results) processGachaOrDropBatch(results, "⚔️ KẾT QUẢ QUAY VŨ KHÍ (WEAPON GACHA)", true) end)) end

if RemoteBank.DisplayRewards and RemoteBank.DisplayRewards.OnClientEvent then
    trackConnection(RemoteBank.DisplayRewards.OnClientEvent:Connect(function(rewards)
        if type(rewards) ~= "table" then return end
        local inGamemode = missionSession.active or isInMission() or isInInvasion()
        if inGamemode or os.clock() < (RT.suppressDropWebhookUntil or 0) then return end
        local itemsList = (rewards.Name and { rewards }) or rewards
        for _, item in ipairs(itemsList) do
            if type(item) == "table" and item.Name then
                queueDropForWebhook(item.Name, item.Quantity, item.Rarity, item.Shiny, item.autoSold)
            end
        end
    end))
end

if RemoteBank.RewardNotifyPlayer and RemoteBank.RewardNotifyPlayer.OnClientEvent then
    trackConnection(RemoteBank.RewardNotifyPlayer.OnClientEvent:Connect(function(qtyText, itemName)
        if not itemName then return end
        local rarity, catLabel, dispName = lookupCatalogInfo(itemName, nil)
        local isShiny = tostring(qtyText or ""):lower():find("shiny") ~= nil
        local rawNum = tostring(qtyText or ""):match("[%d,]+")
        local numVal = rawNum and tonumber((rawNum:gsub(",", ""))) or 1

        local inGamemode = missionSession.active or isInMission() or isInInvasion()
        if inGamemode then
            local key = tostring(dispName or itemName):lower()
            if not missionSession.collectedDrops then missionSession.collectedDrops = {} end
            local existing = missionSession.collectedDrops[key]
            if existing then
                if numVal > existing.qty then existing.qty = numVal end
            else
                missionSession.collectedDrops[key] = {
                    name = tostring(dispName or itemName),
                    qty = numVal,
                    rarity = rarity,
                    catLabel = catLabel,
                    isShiny = isShiny
                }
            end
            return
        end

        if os.clock() < (RT.suppressDropWebhookUntil or 0) then return end
        queueDropForWebhook(itemName, numVal, rarity, isShiny, false)
    end))
end

if RemoteBank.MissionComplete and RemoteBank.MissionComplete.OnClientEvent then
    trackConnection(RemoteBank.MissionComplete.OnClientEvent:Connect(function(resultData)
        if not Config.WebhookEnabled or not Config.WebhookOnMission or type(resultData) ~= "table" then
            missionSession.active = false
            missionSession.collectedDrops = {}
            table.clear(missionSession.midDrops)
            return
        end

        local now = os.clock()
        if now - (RT.lastMissionCompleteWebhookClock or 0) < 6.0 then return end
        RT.lastMissionCompleteWebhookClock = now

        RT.suppressDropWebhookUntil = now + 8.0
        if RT.dropWebhookBuffer then
            if RT.dropWebhookBuffer.batchTimer then
                pcall(task.cancel, RT.dropWebhookBuffer.batchTimer)
                RT.dropWebhookBuffer.batchTimer = nil
            end
            table.clear(RT.dropWebhookBuffer.pending)
            RT.dropWebhookBuffer.highestRank = 0
            RT.dropWebhookBuffer.shouldPing = false
        end

        local isVictory = (resultData.victory ~= false)
        local mData = type(resultData.missionData) == "table" and resultData.missionData or {}
        local stats = type(resultData.stats) == "table" and resultData.stats or {}
        local gm = tostring(mData.gamemode or LocalPlayer:GetAttribute("Gamemode") or (isInInvasion() and "Invasion" or "Mission"))
        local worldName = tostring(mData.universeName or mData.title or getCurrentMapName())
        local actStr = mData.actNumber and (" • Act " .. tostring(mData.actNumber)) or ""
        local modeStr = (mData.mode or mData.modeLabel) and (" [" .. tostring(mData.modeLabel or mData.mode) .. "]") or ""
        local clearTime = tonumber(stats.clearTime) or 0
        if clearTime <= 0 then
            if type(missionSession.elapsedSince) == "number" and missionSession.elapsedSince > 0 then
                clearTime = math.max(0, workspace:GetServerTimeNow() - missionSession.elapsedSince)
            elseif missionSession.startClock > 0 then
                clearTime = math.max(0, os.clock() - missionSession.startClock)
            end
        end
        local timeFmt = (Format and typeof(Format.formatTime) == "function" and clearTime > 0 and Format.formatTime(clearTime)) or string.format("%02dp %02ds", math.floor(clearTime / 60), math.floor(clearTime % 60))
        local waveInfoStr = (missionSession.lastWave > 0) and ((missionSession.totalWaves > 0) and string.format("%d/%d", missionSession.lastWave, missionSession.totalWaves) or tostring(missionSession.lastWave))
        or ((currentWaveInfo.wave > 0) and tostring(currentWaveInfo.wave) or "Hoàn tất")

        local mergedRewards = {}
        local shouldPing = false

        if type(resultData.rewards) == "table" then
            for _, rw in ipairs(resultData.rewards) do
                if type(rw) == "table" and (rw.Name or rw.DisplayName) then
                    local rawName = tostring(rw.Name or rw.DisplayName)
                    local rRarity, catLabel, dispName = lookupCatalogInfo(rawName, rw.Rarity)
                    local finalName = tostring(rw.DisplayName or dispName)
                    local key = finalName:lower()
                    local rank = RARITY_RANK[rRarity] or 0
                    if rank >= 4 or rw.Shiny then shouldPing = true end
                    local qty = tonumber(rw.Quantity) or 1
                    local pityMax = tonumber(rw.PityMax) or 0
                    mergedRewards[key] = {
                        name = finalName,
                        catLabel = catLabel,
                        rarity = rRarity,
                        rank = rank,
                        qty = qty,
                        shiny = rw.Shiny == true,
                        autoSold = rw.autoSold == true,
                        pityMax = pityMax
                    }
                end
            end
        end

        if type(missionSession.collectedDrops) == "table" then
            for key, drop in pairs(missionSession.collectedDrops) do
                if not mergedRewards[key] then
                    local rank = RARITY_RANK[drop.rarity] or 0
                    if rank >= 4 or drop.isShiny then shouldPing = true end
                    mergedRewards[key] = {
                        name = drop.name,
                        catLabel = drop.catLabel,
                        rarity = drop.rarity,
                        rank = rank,
                        qty = drop.qty or 1,
                        shiny = drop.isShiny == true,
                        autoSold = false,
                        pityMax = 0
                    }
                end
            end
        end

        missionSession.active = false
        missionSession.collectedDrops = {}
        table.clear(missionSession.midDrops)

        local sortedItems = {}
        for _, item in pairs(mergedRewards) do table.insert(sortedItems, item) end
        table.sort(sortedItems, function(a, b)
            if a.rank ~= b.rank then return a.rank > b.rank end
            return a.qty > b.qty
        end)

        local rewardLines = {}
        for _, item in ipairs(sortedItems) do
            local shinyTag = item.shiny and " ✨**[SHINY]**" or ""
            local soldTag = item.autoSold and " *(Auto-Sold)*" or ""
            local pityTag = (item.pityMax > 0) and string.format(" *(Pity: %d)*", item.pityMax) or ""
            table.insert(rewardLines, string.format("• %s **[%s]** `%s`: **+x%s**%s%s%s", item.catLabel, item.rarity, item.name, fmtNum(item.qty), shinyTag, soldTag, pityTag))
        end

        sendDiscordWebhook(
            isVictory and string.format("🏆 HOÀN THÀNH %s (VICTORY)", string.upper(gm)) or string.format("💀 KẾT THÚC %s (DEFEAT)", string.upper(gm)),
            string.format("**Màn chơi:** `%s%s%s` • **Wave:** `%s`", worldName, actStr, modeStr, waveInfoStr),
            isVictory and 3066993 or 15158332,
            {
                { name = "⏱️ Thời Gian & Hiệu Suất Chiến Đấu", value = string.format("⏳ Thời gian đi (Clear Time): **`%s`**\n💀 Quái hạ gục: **%s** | 💥 Tổng sát thương: **%s**", timeFmt, fmtNum(stats.kills or 0), fmtNum(stats.damage or 0)), inline = false },
                { name = "🎁 Kết Quả Rơi Item / Thẻ / Phần Thưởng", value = #rewardLines > 0 and table.concat(rewardLines, "\n") or "Không có vật phẩm rơi thêm trong lượt này", inline = false }
            },
            false,
            shouldPing
        )
    end))
end

task.spawn(function()
    local lastReportTick = tick()
    while isScriptRunning do
        task.wait(5)
        if Config.WebhookEnabled and Config.WebhookPeriodic then
            local intervalSec = math.max(5, tonumber(Config.WebhookInterval) or 15) * 60
            if tick() - lastReportTick >= intervalSec then
                lastReportTick = tick()
                sendDiscordWebhook("⏱️ BÁO CÁO TREO MÁY ĐỊNH KỲ (AFK STATUS)", "Cập nhật tiến độ cày cuốc và tài nguyên hiện tại của tài khoản.", 3447003, nil, false, false)
            end
        else
            lastReportTick = tick()
        end
    end
end)

pcall(function()
    local TabWebhook = Window:CreateTab("Webhook"); local SecWhConfig = TabWebhook:CreateSector("1. Cấu Hình Webhook", "left")
    local SecWhTriggers = TabWebhook:CreateSector("2. Bật Thông Báo (Triggers)", "right")
    local WhStatusLabel = SecWhConfig:AddLabel("Trạng thái: ⚪ Chưa nhập Webhook URL", false)
    local function refreshWhStatus()
        local url = tostring(Config.WebhookURL or ""):gsub("%s+", "")
        if url:find("discord%.com/api/webhooks") or url:find("discordapp%.com/api/webhooks") then
            WhStatusLabel:Set(Config.WebhookEnabled and "Trạng thái: 🟢 Đã kết nối URL" or "Trạng thái: 🟡 Đã có URL (Chưa bật)")
        else
            WhStatusLabel:Set("Trạng thái: ⚪ URL không hợp lệ")
        end
    end
    SecWhConfig:AddTextbox("Discord Webhook URL", Config.WebhookURL, function(val) Config.WebhookURL = tostring(val or ""):gsub("%s+", ""); refreshWhStatus() end)
    SecWhConfig:AddTextbox("Discord User ID (Tag Khi Ra Đồ Hiếm)", Config.WebhookDiscordUserId, function(val) Config.WebhookDiscordUserId = tostring(val or ""):gsub("%s+", "") end)
    SecWhConfig:AddToggle("🚨 Tag Discord Khi Ra Mythic / Secret", Config.WebhookPingRare, function(val) Config.WebhookPingRare = val end)
    SecWhConfig:AddButton("🔔 Gửi Thử Webhook (Test)", function() sendDiscordWebhook("🔔 KIỂM TRA KẾT NỐI WEBHOOK", "Kết nối **HelmHub | Anime CardVerse** tới Discord thành công!", 3066993, nil, true, true) end)
    SecWhConfig:AddButton("📊 Gửi Báo Cáo Tài Khoản (Status)", function() sendDiscordWebhook("📊 BÁO CÁO TRẠNG THÁI TÀI KHOẢN", "Báo cáo nhanh toàn bộ tiền tệ, đá nâng cấp và tiến độ Invasion hôm nay.", 3447003, nil, true, false) end)
    SecWhTriggers:AddToggle("🌐 Bật Thông Báo Discord", Config.WebhookEnabled, function(val) Config.WebhookEnabled = val; refreshWhStatus() end)
    SecWhTriggers:AddToggle("🎴 Báo Khi Quay Ra Đồ Hiếm (Gacha)", Config.WebhookOnSummon, function(val) Config.WebhookOnSummon = val end)
    SecWhTriggers:AddDropdown("⭐ Độ Hiếm Tối Thiểu Để Báo", { "Legendary Trở Lên", "Mythic Trở Lên", "Exclusive Trở Lên", "Chỉ Secret", "Chỉ Shiny" }, Config.WebhookMinRarity, false, function(val) Config.WebhookMinRarity = tostring(val or "Mythic Trở Lên") end)
    SecWhTriggers:AddToggle("⚔️ Báo Khi Xong Phó Bản / Invasion", Config.WebhookOnMission, function(val) Config.WebhookOnMission = val end)
    SecWhTriggers:AddToggle("🎁 Báo Khi Rơi Đồ Hiếm (Drops)", Config.WebhookOnDrops, function(val) Config.WebhookOnDrops = val end)
    SecWhTriggers:AddToggle("⏱️ Báo Cáo Định Kỳ (AFK Report)", Config.WebhookPeriodic, function(val) Config.WebhookPeriodic = val end)
    SecWhTriggers:AddSlider("⏳ Chu Kỳ Báo Cáo (Phút)", 5, Config.WebhookInterval, 120, 0, function(val) Config.WebhookInterval = math.floor(tonumber(val) or 15) end)
    refreshWhStatus()
end)

task.spawn(function()
    while isScriptRunning do
        task.wait(120)
        pcall(function()
            local cg = env and env.collectgarbage
            if typeof(cg) == "function" then
                pcall(cg, "step", 200)
            end
        end)
    end
end)

pcall(sanitizeUIGlyphs)

end
notify("HelmHub Sẵn Sàng", "Anime CardVerse Combat Suite đã khởi động đầy đủ!", 4)
