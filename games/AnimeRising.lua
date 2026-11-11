--[[
    ========================================================================================
    HelmHub | Anime Rising Master Engine
    PlaceId: 118712332916577
    Tác giả: dj & VANTA
    Phiên bản: 3.1 (Refactored, Optimized & Clean Architecture)
    ========================================================================================
    CÁC ĐIỂM NÂNG CẤP & TỐI ƯU HÓA ĐỘT PHÁ:
      1. TỐI ƯU HIỆU NĂNG & DỌN DẸP BỘ NHỚ:
         - Triệt tiêu hoàn toàn vòng lặp quét full workspace (GetDescendants) định kỳ,
           thay bằng CollectionService Tag & Indexed Folder search, triệt tiêu lag giật.
         - Cache tập trung toàn bộ Remotes, Bindables và ModuleScripts của game
           (CommonLib, GameBalance, GameConfig, AbilityUtility, TreeUpgrades, QuestTaskHandler).
         - Tách biệt rõ ràng 100% giữa Tầng Xử Lý Logic (Engine) và Tầng Giao Diện (UI).
      2. TỰ ĐỘNG CHIẾN ĐẤU & GIAN LẬN PET (COMBAT & PET EXPLOITS):
         - Sticky Target Locking: Khóa chặt quái đến khi chết, không giật qua lại.
         - Minions First: Tự động diệt sạch quái nhỏ bảo vệ trước khi đánh Boss (chuẩn cơ chế Raid).
         - Safe Position Hover: Treo lơ lửng an toàn trên đầu quái, triệt tiêu xoay dọc (Pitch),
           chống hoàn toàn hiện tượng Gimbal Lock gây rung giật camera / đau mắt.
         - [EXPLOIT 1] Pet Dịch Chuyển Tức Thời (Instant Flash): Hook PetBrain.CanTeleport & _MoveTick,
           bỏ qua thời gian chạy bộ, snap Pet thẳng vào quái trong 0.001s và xả đòn ngay lập tức!
         - [EXPLOIT 2] Pet Siêu Tốc Độ (Super Speed Dash): Khai thác PoolMoveBonus & phá vỡ giới hạn
           8 studs/frame của game, pet lướt cực nhanh (5x - 100x speed) như tia chớp!
         - [EXPLOIT 3] Sticky Pet Target (Hooks 0A & 0B): Chặn game reset mục tiêu về nil, giữ Pet
           tấn công liên tục không bị quay đầu về người chơi.
         - [EXPLOIT 4] Bỏ Qua Hoạt Ảnh Chiêu Pet (FastSkillAnimation): Triệt tiêu thời gian chờ
           WaitOrCancel, ra chiêu tức thì với sát thương chuẩn của Pet.
      3. VƯỢT ẢI & ĐỀN THỜ (STAGE LOOP & SHRINES):
         - Tự động vượt ải thông minh khi sạch quái (Anti-Spam & Delay chống giật).
         - Tự kích hoạt Đền Thờ (Shrines) qua CollectionService & thu hoạch Soul (SoulShrine).
      4. PHỤ BẢN & SĂN RAID / LEO THÁP INFINITY CASTLE:
         - Tab RAID chuyên dụng với 5 thế giới chuẩn: DBZ, OnePiece, Naruto, SoloLeveling, DemonSlayer.
         - Chuẩn 3 độ khó chính thức: Normal, Hard, Nightmare.
         - Tự Động Leo Tháp Infinity Castle: Tự động chọn Tháp nguyên tố theo ngày hoặc cố định.
         - Tự Động Úp Rank Thợ Săn (Hunter Rank & Assessments): Tự làm thử thách và claim rank.
      5. TỰ ĐỘNG NHẬN QUÀ (1-CLICK & AUTO REWARDS):
         - Nhận sạch 9 nguồn quà Free (Playtime 1-12, Daily Calendar, Group, Training Return,
           Season Pass All & Bonus, Achievements, Tournaments, IndexClaim, AntiAFK).
      6. CÂY KỸ NĂNG (UPGRADE TREE):
         - Tự động quét và nâng cấp tất cả nhánh kỹ năng khả dụng theo dữ liệu game.
      7. GACHA & QUAY THẺ THÔNG MINH (SMART GACHA & AUTO REROLL):
         - Tự động kéo Banner Free, Single, 10x; Bỏ qua Cutscene mở trứng/thẻ.
         - Auto Reroll Quirk thông minh cho Nhân Vật & Pet theo mốc Tier mong muốn.
      8. KHO ĐỒ, TRANG BỊ & NÂNG CẤP (AUTO INVENTORY & UPGRADES):
         - Tự động trang bị đồ mạnh nhất, thăng hoa toàn bộ, bán pet rác và nâng cấp vũ khí/ngọc.
    ========================================================================================
]]

repeat task.wait(0.1) until game:IsLoaded()

_G.HelmGameName = "Anime Rising"
local currentSessionId = os.clock() + math.random()
_G.AnimeRising_SessionId = currentSessionId
local function isSessionActive()
    return _G.AnimeRising_SessionId == currentSessionId
end

-- ========================================================================
-- DỊCH VỤ HỆ THỐNG (ROBLOX SERVICES)
-- ========================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
repeat task.wait(0.1) until localPlayer

-- ========================================================================
-- 1. DỌN DẸP GIAO DIỆN CŨ (PREVENT GHOST WINDOWS)
-- ========================================================================
pcall(function()
    local containers = {}
    if gethui then pcall(function() table.insert(containers, gethui()) end) end
    pcall(function() table.insert(containers, game:GetService("CoreGui")) end)
    local pg = localPlayer:FindFirstChild("PlayerGui")
    if pg then table.insert(containers, pg) end

    for _, c in ipairs(containers) do
        for _, gui in ipairs(c:GetChildren()) do
            if gui.Name:find("Anime Rising") or gui.Name:find("AnimeRising") or gui.Name:find("HelmHub") then
                pcall(function() gui:Destroy() end)
            end
        end
    end
end)

-- ========================================================================
-- 2. HỆ THỐNG LOG & THÔNG BÁO
-- ========================================================================
local function Log(msg)
    print(string.format("[%s | Anime Rising] %s", os.date("%X"), tostring(msg)))
end

local function Notification(title, text, duration)
    duration = duration or 3
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = string.format("[HelmHub] %s", tostring(title)),
            Text = tostring(text),
            Duration = duration
        })
    end)
    Log(string.format("%s: %s", tostring(title), tostring(text)))
end

-- ========================================================================
-- 3. ANTI-AFK CHỐNG KICK
-- ========================================================================
pcall(function()
    localPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end)

-- ========================================================================
-- 4. TẢI THƯ VIỆN GIAO DIỆN (Library/inventory.lua)
-- ========================================================================
local library = nil
local libraryLoaded = false

-- 1. Ưu tiên Local Test Server khi đang chạy start_local_test.bat (Local PC)
local localUrls = {
    "http://127.0.0.1:8000/Library/inventory.lua",
    "http://localhost:8000/Library/inventory.lua"
}

for _, url in ipairs(localUrls) do
    local s, res = pcall(function()
        return game:HttpGet(url .. "?t=" .. tick())
    end)
    if s and res and #res > 500 then
        local fn, compileErr = loadstring(res)
        if fn then
            local execSuccess, lib = pcall(fn)
            if execSuccess and lib then
                library = lib
                libraryLoaded = true
                Log("Đã nạp thư viện UI từ Local Server: " .. url)
                pcall(function()
                    if writefile then
                        writefile("Library/inventory.lua", res)
                    end
                end)
                break
            else
                warn("[HelmHub] Lỗi thực thi inventory.lua từ " .. url .. ": " .. tostring(lib))
            end
        else
            warn("[HelmHub] Lỗi cú pháp inventory.lua từ " .. url .. ": " .. tostring(compileErr))
        end
    end
end

-- 2. Nạp nhanh từ file cục bộ nếu executor có sẵn file Library/inventory.lua
if not libraryLoaded and readfile and isfile then
    local localPaths = {
        "Library/inventory.lua",
        "!HelmHub/Library/inventory.lua"
    }
    for _, p in ipairs(localPaths) do
        if isfile(p) then
            local content = readfile(p)
            if content and #content > 500 then
                local fn, compileErr = loadstring(content)
                if fn then
                    local s, lib = pcall(fn)
                    if s and lib then
                        library = lib
                        libraryLoaded = true
                        Log("Đã nạp thư viện UI từ file cục bộ: " .. p)
                        break
                    else
                        warn("[HelmHub] Lỗi chạy file local " .. p .. ": " .. tostring(lib))
                    end
                else
                    warn("[HelmHub] Lỗi cú pháp file local " .. p .. ": " .. tostring(compileErr))
                end
            end
        end
    end
end

if not library then
    Notification("Lỗi Thư Viện", "Không thể nạp UI inventory.lua! Vui lòng kiểm tra server local.", 10)
    return
end

-- ========================================================================
-- 5. PHÂN GIẢI REMOTES, BINDABLES & MODULES CHÍNH THỨC
-- ========================================================================
local Remote = ReplicatedStorage:WaitForChild("Remote", 10)
local Bindable = ReplicatedStorage:WaitForChild("Bindable", 10)

-- Cache ModuleScripts của Game
local ModuleScripts = ReplicatedStorage:WaitForChild("ModuleScripts", 10)

local function getGameModule(folderName, moduleName)
    if not ModuleScripts then return nil end
    local folder = folderName and ModuleScripts:FindFirstChild(folderName) or ModuleScripts
    local mod = folder and folder:FindFirstChild(moduleName or folderName)
    if mod and mod:IsA("ModuleScript") then
        local ok, res = pcall(require, mod)
        if ok and res then return res end
    end
    return nil
end

local CommonLib = getGameModule("SharedFunctions", "CommonLib")
local GameBalance = getGameModule(nil, "GameBalance")
local GameConfig = getGameModule("Config", "GameConfig")
local AbilityUtility = getGameModule("PetAbilities", "AbilityUtility")
local QuestTaskHandler = getGameModule("Handlers", "QuestTaskHandler")

-- Module Cây Kỹ Năng
local TreeUpgrades = nil
pcall(function()
    local treeMod = ModuleScripts and ModuleScripts:FindFirstChild("Config")
        and ModuleScripts.Config:FindFirstChild("UpgradeStats")
        and ModuleScripts.Config.UpgradeStats:FindFirstChild("Modules")
        and ModuleScripts.Config.UpgradeStats.Modules:FindFirstChild("TreeUpgrades")
    if treeMod then
        TreeUpgrades = require(treeMod)
    end
end)

-- Khởi tạo vĩnh viễn tầm xích Pet vô hạn để Pet thoải mái đánh quái không bị kéo về
if GameBalance then
    pcall(function()
        GameBalance.AutoAttackRetreatRange = 99999
    end)
end

-- ========================================================================
-- 6. BẢNG CẤU HÌNH (CONFIG TABLE & DEFAULTS)
-- ========================================================================
local Config = {
    -- 1. Tự Động Chiến Đấu
    AutoAttack = false,
    TargetMode = "Gần Nhất", -- "Gần Nhất", "Ít Máu Nhất", "Chỉ Boss", "Độ Hiếm Cao"
    AutoTeleportMob = false,
    HoverDistance = 7,
    AutoSpamSkills = true,
    FastSkillAnimation = false, -- Bỏ qua hoạt ảnh múa chiêu của Pet, ra chiêu tức thì với sát thương chuẩn
    FastWeaponAttack = true,
    IgnoreInvulnerable = false,
    InfiniteAttackRange = false,  -- Tầm đánh & khóa mục tiêu toàn map (vô cực 99,999 studs)

    -- Gian Lận Tốc Độ & Di Chuyển Pet (Pet Movement Exploits)
    PetInstantTeleport = false, -- Tốc biến tức thời tới quái trong 0.001s
    PetSuperSpeed = false,      -- Siêu tốc độ dash nhanh gấp 5x - 100x
    PetSpeedMultiplier = 50,    -- Hệ số nhân tốc độ pet (Mặc định: 50x)

    -- 2. Vượt Ải & Đền Thờ
    AutoNextZone = false,
    AutoBuyStage = false,
    AutoActivateShrines = false,
    AutoClaimFreeRewards = false,

    -- 3. Phụ Bản & Săn Raid
    AutoFarmRaid = false,
    AutoRepeatRaid = true,
    AutoChangeRaidStage = true,
    AutoTargetRaidBoss = true,
    SelectedRaidMap = "W3: Hidden Village (Naruto)",
    SelectedRaidId = "Naruto",
    SelectedRaidDifficulty = "Hard",
    RaidAutoStagesMode = "Retry", -- "Off", "Retry", "Next"

    -- Leo Tháp Infinity Castle (Tower) & Thử Thách Hunter Rank
    AutoInfinityCastle = false,
    SelectedTowerOption = "Tự Động Theo Ngày (Auto Day)",
    SelectedTowerId = "AutoDay",
    AutoHunterRank = false,

    -- 4. Gacha & Reroll
    AutoPullFree = false,
    AutoRollSingle = false,
    AutoRoll10 = false,
    FastSkipGachaAnim = true,
    SelectedBanner = "PremiumBanner1",
    AutoRerollQuirk = false,
    RerollTarget = "Nhân Vật (Player)",
    RerollDesiredTier = "Mythical+",
    RerollSelectedSlot = 1,

    -- 5. Kho Đồ & Nâng Cấp
    AutoEquipBest = false,
    AutoAscendAll = false,
    AutoSellTrashPets = false,
    AutoUpgradeWeapons = false,

    -- 6. Tiện Ích
    AutoUpgradeTree = false,
    NoClip = false,
    WalkSpeed = 16,
    JumpPower = 50
}

-- Sao lưu cấu hình mặc định (Default State)
local DEFAULT_CONFIG = {}
for k, v in pairs(Config) do
    DEFAULT_CONFIG[k] = v
end

-- ========================================================================
-- 7. HỆ THỐNG TỰ ĐỘNG LƯU & NẠP CẤU HÌNH (AUTO-SAVE & LOAD CONFIG)
-- ========================================================================
local CONFIG_FOLDER = "!HelmHub/Anime Rising"
local CONFIG_FILE = CONFIG_FOLDER .. "/settings.json"
local FALLBACK_FILE = "AnimeRising_Settings.json"

local uiRegistry = {}
local isSavingConfig = false
local saveDebounceTimer = nil

local function SaveSettings(manual)
    if isSavingConfig then return end
    isSavingConfig = true
    pcall(function()
        if not writefile then
            if manual and Notification then
                Notification("Cấu Hình", "Executor không hỗ trợ writefile!", 3)
            end
            return
        end

        local stateTable = {}
        for k, v in pairs(Config) do
            local t = typeof(v)
            if t == "boolean" or t == "number" or t == "string" then
                stateTable[k] = v
            end
        end

        local jsonStr = HttpService:JSONEncode(stateTable)

        pcall(function()
            if isfolder and makefolder then
                if not isfolder("!HelmHub") then makefolder("!HelmHub") end
                if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
            end
            writefile(CONFIG_FILE, jsonStr)
        end)
        pcall(function() writefile(FALLBACK_FILE, jsonStr) end)

        if manual and Notification then
            Notification("Cấu Hình", "Đã lưu toàn bộ cài đặt vào máy thành công!", 3)
        end
    end)
    isSavingConfig = false
end

local function triggerAutoSave()
    if saveDebounceTimer then
        task.cancel(saveDebounceTimer)
        saveDebounceTimer = nil
    end
    saveDebounceTimer = task.delay(0.6, function()
        SaveSettings(false)
        saveDebounceTimer = nil
    end)
end

local function LoadSettings(manual)
    local loaded = nil
    pcall(function()
        if isfile and readfile then
            if isfile(CONFIG_FILE) then
                loaded = HttpService:JSONDecode(readfile(CONFIG_FILE))
            elseif isfile(FALLBACK_FILE) then
                loaded = HttpService:JSONDecode(readfile(FALLBACK_FILE))
            end
        end
    end)

    if type(loaded) == "table" then
        for k, v in pairs(loaded) do
            if Config[k] ~= nil and typeof(Config[k]) == typeof(v) then
                Config[k] = v
                local elem = uiRegistry[k]
                if elem and elem.Set then
                    pcall(function() elem:Set(v) end)
                end
            end
        end
        if manual and Notification then
            Notification("Cấu Hình", "Đã nạp cài đặt đã lưu thành công!", 3)
        end
    elseif manual and Notification then
        Notification("Cấu Hình", "Chưa có file cài đặt nào được lưu trước đó!", 3)
    end
end

local function ResetSettings()
    pcall(function()
        if isfile and delfile then
            if isfile(CONFIG_FILE) then delfile(CONFIG_FILE) end
            if isfile(FALLBACK_FILE) then delfile(FALLBACK_FILE) end
        end
    end)

    for k, v in pairs(DEFAULT_CONFIG) do
        Config[k] = v
        local elem = uiRegistry[k]
        if elem and elem.Set then
            pcall(function() elem:Set(v) end)
        end
    end

    if Notification then
        Notification("Cấu Hình", "Đã xóa file lưu và khôi phục cài đặt gốc mặc định!", 3)
    end
end

-- Tự động nạp cấu hình đã lưu ngay khi khởi động
LoadSettings(false)

-- ========================================================================
-- 8. BỘ QUÉT QUÁI THÔNG MINH & NHẬN DIỆN PHÒNG RAID CHUẨN XÁC
-- ========================================================================
local function isInRaid()
    local world = localPlayer:FindFirstChild("World")
    local wVal = world and tostring(world.Value) or ""
    if wVal == "Raids" or wVal:find("Tower") ~= nil or wVal:find("Castle") ~= nil or wVal:find("Assessment") ~= nil or wVal:find("Challenge") ~= nil then
        return true
    end
    if localPlayer:GetAttribute("InRaid") == true or localPlayer:GetAttribute("InTower") == true or localPlayer:GetAttribute("RaidRoomID") ~= nil then
        return true
    end
    -- Kiểm tra HUD Raid / Challenge trên màn hình
    local pGui = localPlayer:FindFirstChild("PlayerGui")
    local mainGui = pGui and pGui:FindFirstChild("MainGui")
    if mainGui then
        local raidTimer = mainGui:FindFirstChild("RaidTimer", true) or mainGui:FindFirstChild("ChallengeTimer", true)
        if raidTimer and raidTimer.Visible then
            return true
        end
    end
    return false
end

-- Kiểm tra tính hợp lệ của quái vật (Enemy Validator)
-- Triệt tiêu hoàn toàn lỗi: khóa quái chết 0 HP, quái rơi vào hư không (void Y < -150), quái ở World khác
local function isEnemyValid(model)
    if not model or not model:IsA("Model") or not model.Parent then return false end
    if model:GetAttribute("Disabled") == true then return false end
    if Config.IgnoreInvulnerable and model:GetAttribute("Invulnerable") == true then return false end

    -- Máu: Bắt buộc > 0 (Tuyệt đối không dùng fallback 100 gây khóa xác quái chết / hư không)
    local rawHp = tonumber(model:GetAttribute("Health"))
    local hum = model:FindFirstChildWhichIsA("Humanoid")
    local hp = rawHp or (hum and tonumber(hum.Health)) or 0
    if hp <= 0 then return false end

    -- Tọa độ Y: Chống quái rớt sàn / rơi vào hư không (void)
    local pivot = model:GetPivot()
    if pivot.Position.Y < -150 then return false end

    -- Kiểm tra thế giới (World Check): Khi ở map thường (W1-W5), chặn đánh quái ngoài World
    local inRaid = isInRaid()
    if not inRaid then
        local myWorld = localPlayer:FindFirstChild("World") and localPlayer.World.Value
        if myWorld and myWorld ~= "" then
            local enemyWorld = model:GetAttribute("World")
            if enemyWorld and type(enemyWorld) == "string" and enemyWorld ~= "" and enemyWorld ~= myWorld then
                return false
            end
            local worlds = workspace:FindFirstChild("Worlds")
            if worlds then
                local myWorldFolder = worlds:FindFirstChild(myWorld)
                if myWorldFolder and model:IsDescendantOf(worlds) and not model:IsDescendantOf(myWorldFolder) then
                    return false
                end
            end
        end
    end

    -- WorldInstanceId (Instance Check)
    local myInst = (localPlayer:FindFirstChild("WorldInstanceId") and localPlayer.WorldInstanceId.Value) or localPlayer:GetAttribute("WorldInstanceId")
    local enemyInst = model:GetAttribute("WorldInstanceId")
    if myInst and enemyInst and tostring(myInst) ~= "" and tostring(enemyInst) ~= "" and tostring(myInst) ~= tostring(enemyInst) then
        return false
    end

    return true, hp, pivot.Position
end

local function getValidEnemies()
    local enemies = {}
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return enemies end
    local myPos = root.Position
    local inRaid = isInRaid()
    local maxDistance = Config.InfiniteAttackRange and 99999 or (inRaid and 3000 or 1500)

    local addedMap = {}

    local function checkAndAdd(model)
        if not model or not model:IsA("Model") or addedMap[model] then return end
        local valid, hp, pos = isEnemyValid(model)
        if not valid then return end

        local dist = (pos - myPos).Magnitude
        if dist <= maxDistance then
            addedMap[model] = true
            local isBoss = model:GetAttribute("Boss") == true or model.Name:find("Boss") ~= nil or model:HasTag("ShieldedByAdds")
            local rarity = model:GetAttribute("Rarity") or "Common"
            table.insert(enemies, {
                Model = model,
                Position = pos,
                Distance = dist,
                Health = hp,
                IsBoss = isBoss,
                Rarity = rarity
            })
        end
    end

    -- 1. Quét CollectionService Tag "Enemy" (Cực nhanh và chuẩn xác trong mọi Raid / Tháp / Hunter Challenge)
    for _, model in ipairs(CollectionService:GetTagged("Enemy")) do
        checkAndAdd(model)
    end

    -- 2. Quét CommonLib của game (nếu có)
    if CommonLib and CommonLib.Enemy and CommonLib.Enemy.GetEnemyModelsForPlayer then
        pcall(function()
            local list = CommonLib.Enemy:GetEnemyModelsForPlayer(localPlayer)
            if list then
                for _, m in ipairs(list) do
                    checkAndAdd(m)
                end
            end
        end)
    end

    -- 3. Quét thư mục Enemies của World hiện tại của player (khi ở map thường)
    if not inRaid then
        local myWorld = localPlayer:FindFirstChild("World") and localPlayer.World.Value
        if myWorld and myWorld ~= "" then
            pcall(function()
                local worlds = workspace:FindFirstChild("Worlds")
                local curWorldFolder = worlds and worlds:FindFirstChild(myWorld)
                local eFolder = curWorldFolder and (curWorldFolder:FindFirstChild("Enemies") or curWorldFolder:FindFirstChild("Mobs"))
                if eFolder then
                    for _, child in ipairs(eFolder:GetChildren()) do
                        checkAndAdd(child)
                    end
                end
            end)
        end
    end

    -- 4. Quét fallback trong workspace.Enemies
    pcall(function()
        local eFolder = workspace:FindFirstChild("Enemies")
        if eFolder then
            for _, child in ipairs(eFolder:GetChildren()) do
                checkAndAdd(child)
            end
        end
    end)

    return enemies
end

local function selectTarget()
    local list = getValidEnemies()
    if #list == 0 then return nil end

    local bosses = {}
    local minions = {}

    for _, e in ipairs(list) do
        if e.IsBoss then
            table.insert(bosses, e)
        else
            table.insert(minions, e)
        end
    end

    -- Quy tắc chuẩn: BẮT BUỘC diệt sạch toàn bộ quái nhỏ xung quanh trước khi đánh Boss!
    local candidateList = list
    if #minions > 0 then
        candidateList = minions
    elseif #minions == 0 and #bosses > 0 then
        candidateList = bosses
        if isInRaid() and Remote and Remote:FindFirstChild("Raid") and Remote.Raid:FindFirstChild("TargetBoss") then
            pcall(function() Remote.Raid.TargetBoss:FireServer() end)
        end
    end

    -- Sắp xếp theo chế độ ưu tiên
    if Config.TargetMode == "Ít Máu Nhất" then
        table.sort(candidateList, function(a, b) return (tonumber(a.Health) or 0) < (tonumber(b.Health) or 0) end)
        return candidateList[1]
    elseif Config.TargetMode == "Độ Hiếm Cao" then
        local rarityWeight = { Secret = 6, Mythical = 5, Legendary = 4, Epic = 3, Rare = 2, Common = 1 }
        table.sort(candidateList, function(a, b)
            local wA = rarityWeight[a.Rarity] or 0
            local wB = rarityWeight[b.Rarity] or 0
            if wA == wB then return a.Distance < b.Distance end
            return wA > wB
        end)
        return candidateList[1]
    elseif Config.TargetMode == "Chỉ Boss" and #bosses > 0 and #minions == 0 then
        table.sort(bosses, function(a, b) return a.Distance < b.Distance end)
        return bosses[1]
    end

    -- Mặc định: Gần Nhất
    table.sort(candidateList, function(a, b) return a.Distance < b.Distance end)
    return candidateList[1]
end

-- ========================================================================
-- 9. TỰ ĐỘNG CHIẾN ĐẤU & SAFE POSITION FARM (KHÔNG RUNG GIẬT)
-- ========================================================================
local currentCombatTarget = nil
local lockedTargetModel = nil
local lastDispatchedTarget = nil

local function isTargetModelValid(model)
    local valid, hp, pos = isEnemyValid(model)
    if not valid then return false end
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local dist = (pos - root.Position).Magnitude
    local inRaid = isInRaid()
    local maxDist = Config.InfiniteAttackRange and 99999 or (inRaid and 3000 or 1500)
    if dist > maxDist then return false end
    return true
end

task.spawn(function()
    while true do
        if not isSessionActive() then break end

        local inRaid = isInRaid()
        local inRaidFarmActive = inRaid and (Config.AutoFarmRaid or Config.AutoInfinityCastle or Config.AutoHunterRank)
        -- Khi ở trong phụ bản (Raid/Tháp/Hunter): CHỈ đánh nếu có toggle Auto tương ứng đang bật (tắt Auto tháp là dừng đánh ngay!)
        local shouldCombat = inRaid and inRaidFarmActive or (not inRaid and Config.AutoAttack)
        -- Kích hoạt bay áp sát: Có lệnh đánh và bật Bay Áp Sát Quái HOẶC khi đang chạy Auto phụ bản
        local shouldTeleport = shouldCombat and (Config.AutoTeleportMob or inRaidFarmActive)

        if shouldCombat then
            local char = localPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")

            -- 1. Sticky Target Locking: Khóa chặt quái đến khi chết, không giật đổi qua lại
            if not isTargetModelValid(lockedTargetModel) then
                local best = selectTarget()
                lockedTargetModel = best and best.Model or nil
                currentCombatTarget = best
                lastDispatchedTarget = nil
            else
                -- Nếu đang khóa Boss mà có quái nhỏ xuất hiện (Adds phase), tự động nhả Boss để dọn quái nhỏ trước
                local isBossLocked = lockedTargetModel:GetAttribute("Boss") == true or lockedTargetModel:HasTag("ShieldedByAdds") or lockedTargetModel.Name:find("Boss")
                if isBossLocked then
                    local enemies = getValidEnemies()
                    for _, e in ipairs(enemies) do
                        if not e.IsBoss and not e.Model:HasTag("ShieldedByAdds") and not e.Model.Name:find("Boss") then
                            lockedTargetModel = nil
                            local best = selectTarget()
                            lockedTargetModel = best and best.Model or nil
                            currentCombatTarget = best
                            lastDispatchedTarget = nil
                            break
                        end
                    end
                end
            end

            if lockedTargetModel and root then
                local targetPivot = lockedTargetModel:GetPivot()
                local targetPos = targetPivot.Position
                local currentPos = root.Position
                local hoverPos = targetPos + Vector3.new(0, Config.HoverDistance, 0)
                local distToHover = (hoverPos - currentPos).Magnitude

                -- 2. Safe Position Farm: Treo lơ lửng an toàn trên đầu quái, KHÔNG GIẬT CAMERA, KHÔNG GIMBAL LOCK
                if shouldTeleport then
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero

                    -- Giữ góc quay ngang (Yaw) tự nhiên của nhân vật, triệt tiêu xoay dọc (Pitch)
                    local lookVec = root.CFrame.LookVector
                    local yaw = math.atan2(lookVec.X, lookVec.Z)
                    local uprightRotation = CFrame.Angles(0, yaw, 0)

                    if distToHover > 25 then
                        -- Quái ở xa (> 25 studs): Dịch chuyển tức thời tới ngay vị trí lơ lửng trên đầu quái
                        root.CFrame = CFrame.new(hoverPos) * uprightRotation
                    elseif distToHover > 1.5 then
                        -- Tiếp cận mềm mại: Lướt êm ái, êm ru như drone
                        local smoothPos = currentPos:Lerp(hoverPos, 0.45)
                        root.CFrame = CFrame.new(smoothPos) * uprightRotation
                    else
                        -- Đã ở đúng vị trí an toàn (<= 1.5 studs): Khóa cứng tọa độ hoverPos, chống rơi tự do hay rung lắc
                        root.CFrame = CFrame.new(hoverPos) * uprightRotation
                    end
                end

                -- 3. Đồng bộ mục tiêu cho Server & Pet Squad (Bắt đầu chu trình tấn công chính thức)
                pcall(function()
                    -- Kích hoạt ValueObjects.AutoAttack & AutoAbility của game để PetTargetingHandler & AutoAttackHandler hoạt động
                    local valObj = Bindable and Bindable:FindFirstChild("ValueObjects")
                    if valObj then
                        local aa = valObj:FindFirstChild("AutoAttack")
                        if aa and aa:IsA("ValueBase") and aa.Value ~= true then aa.Value = true end
                        local ab = valObj:FindFirstChild("AutoAbility")
                        if ab and ab:IsA("ValueBase") and ab.Value ~= true then ab.Value = true end
                    end

                    -- Đồng bộ Server MainTarget
                    if Remote and Remote:FindFirstChild("Player") and Remote.Player:FindFirstChild("SetMainTarget") then
                        Remote.Player.SetMainTarget:FireServer(lockedTargetModel)
                    end

                    -- Điều phối Pet Squad: CHỈ gọi SendPets khi đổi mục tiêu mới (TUYỆT ĐỐI KHÔNG gọi SendAllPets vì SendAllPets là toggle làm Pet retreat)
                    if lastDispatchedTarget ~= lockedTargetModel then
                        lastDispatchedTarget = lockedTargetModel
                        if Bindable and Bindable:FindFirstChild("SendPets") then
                            Bindable.SendPets:Fire(lockedTargetModel)
                        end
                    end

                    local pets = localPlayer:FindFirstChild("Pets")
                    if pets then
                        for _, petVal in ipairs(pets:GetChildren()) do
                            local petModel = petVal.Value
                            if petModel then
                                if Bindable and Bindable:FindFirstChild("Pets") and Bindable.Pets:FindFirstChild("SetPetTarget") then
                                    Bindable.Pets.SetPetTarget:Fire(petModel, lockedTargetModel)
                                end
                                -- 4. Kích hoạt chiêu Pet thông qua Bindable Client chính thức
                                if Config.AutoSpamSkills and Bindable and Bindable:FindFirstChild("UsePetAbility") then
                                    Bindable.UsePetAbility:Fire(petModel)
                                end
                            end
                        end
                    end
                end)

                -- 4. Kích hoạt chiêu thức Mount & Remote Pet
                if Config.AutoSpamSkills then
                    pcall(function()
                        if Remote:FindFirstChild("Mounts") and Remote.Mounts:FindFirstChild("UseAbility") then
                            Remote.Mounts.UseAbility:FireServer()
                        end
                        if Remote:FindFirstChild("Pets") and Remote.Pets:FindFirstChild("UseAbility") then
                            Remote.Pets.UseAbility:FireServer()
                        end
                    end)
                end

                -- 5. Kích hoạt vũ khí nhân vật (Tool M1 nếu có)
                if Config.FastWeaponAttack and char then
                    local tool = char:FindFirstChildWhichIsA("Tool") or localPlayer.Backpack:FindFirstChildWhichIsA("Tool")
                    if tool and tool.Parent == localPlayer.Backpack then tool.Parent = char end
                    if tool then pcall(function() tool:Activate() end) end
                end
            else
                lockedTargetModel = nil
                currentCombatTarget = nil
                lastDispatchedTarget = nil
            end
        else
            if lockedTargetModel or currentCombatTarget then
                lockedTargetModel = nil
                currentCombatTarget = nil
                lastDispatchedTarget = nil
                pcall(function()
                    local char = localPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                        local ray = workspace:Raycast(root.Position, Vector3.new(0, -100, 0))
                        if ray then
                            root.CFrame = CFrame.new(ray.Position + Vector3.new(0, 3, 0))
                        end
                    end
                    -- Khi ngừng chiến đấu, gọi Pet quay trở về bên cạnh nhân vật
                    if Bindable and Bindable:FindFirstChild("RetreatPets") then
                        Bindable.RetreatPets:Fire()
                    end
                    local valObj = Bindable and Bindable:FindFirstChild("ValueObjects")
                    if valObj then
                        local aa = valObj:FindFirstChild("AutoAttack")
                        if aa and aa:IsA("ValueBase") and aa.Value == true then aa.Value = false end
                    end
                end)
            end
        end

        task.wait(0.08)
    end
end)

-- ========================================================================
-- 10. PET MOVEMENT & ATTACK EXPLOIT ENGINE
-- Khai thác trực tiếp mã nguồn LocalPetHandler.PetBrain & PetStatHandler
-- ========================================================================
local petBrainHooked = false
local origPetMoveTick = nil
local origPetCanTeleport = nil
local origPetGetSpeed = nil
local origSetTarget = nil
local origUpdateCurrentTarget = nil

local function hookPetBrain()
    if petBrainHooked then return true end
    local success, _ = pcall(function()
        local playerScripts = localPlayer:WaitForChild("PlayerScripts", 5)
        if not playerScripts then return end
        local petHandler = playerScripts:WaitForChild("LocalPetHandler", 5)
        if not petHandler then return end
        local petBrainMod = petHandler:WaitForChild("PetBrain", 5)
        if not petBrainMod then return end

        local PetBrain = require(petBrainMod)
        if type(PetBrain) ~= "table" then return end

        origPetMoveTick = PetBrain._MoveTick
        origPetCanTeleport = PetBrain.CanTeleport
        origPetGetSpeed = PetBrain.GetSpeed
        origSetTarget = PetBrain.SetTarget
        origUpdateCurrentTarget = PetBrain._UpdateCurrentTarget

        -- Hook 0A: Khóa chết mục tiêu của Pet (Chặn hoàn toàn cơ chế game tự ý hủy Target làm Pet quay về Player)
        PetBrain.SetTarget = function(self, newTarget)
            local isCombatActive = Config.AutoAttack or (isInRaid() and (Config.AutoFarmRaid or Config.AutoInfinityCastle or Config.AutoHunterRank))
            if isCombatActive and newTarget == nil then
                if self.Target ~= nil and isEnemyValid(self.Target) then
                    -- Quái vẫn còn sống, ngăn chặn tuyệt đối lệnh gán nil / retreat từ game!
                    return
                end
            end
            if origSetTarget then
                return origSetTarget(self, newTarget)
            end
        end

        -- Hook 0B: Chặn vòng lặp AI tự động ngắt Target vì khoảng cách người chơi
        PetBrain._UpdateCurrentTarget = function(self)
            local isCombatActive = Config.AutoAttack or (isInRaid() and (Config.AutoFarmRaid or Config.AutoInfinityCastle or Config.AutoHunterRank))
            if isCombatActive and self.Target ~= nil then
                if isEnemyValid(self.Target) then
                    return -- Giữ chặt Target, không cho game reset về nil
                end
            end
            if origUpdateCurrentTarget then
                return origUpdateCurrentTarget(self)
            end
        end

        -- Hook 1: Mở khóa quyền Tốc Biến của Pet (CanTeleport)
        PetBrain.CanTeleport = function(self)
            if Config.PetInstantTeleport then
                return true
            end
            if origPetCanTeleport then
                return origPetCanTeleport(self)
            end
            return false
        end

        -- Hook 2: Mở khóa Siêu Tốc Độ trong bảng thuộc tính game
        PetBrain.GetSpeed = function(self)
            local baseSpeed = 16
            if origPetGetSpeed then
                local ok, spd = pcall(origPetGetSpeed, self)
                if ok and typeof(spd) == "number" then
                    baseSpeed = spd
                end
            end
            if Config.PetSuperSpeed then
                return baseSpeed * (Config.PetSpeedMultiplier or 50)
            end
            return baseSpeed
        end

        -- Hook 3: Can thiệp trực tiếp vòng lặp di chuyển _MoveTick
        PetBrain._MoveTick = function(self, p102, p103, p104)
            if self.Stunned then
                return false
            end

            -- Chế Độ 1: TỐC BIẾN TỨC THỜI (Instant Flash Snap)
            if Config.PetInstantTeleport and self.Target ~= nil then
                local targetPos = self:GetTargetPosition()
                if targetPos then
                    self._GlideTo = nil
                    if typeof(self.Teleport) == "function" then
                        self:Teleport(targetPos, false)
                    elseif self.Model and self.Model:IsA("Model") then
                        local pivot = self.Model:GetPivot()
                        local diff = targetPos - pivot.Position
                        local lookDir = diff.Magnitude > 0.001 and diff.Unit or Vector3.new(0, 0, 1)
                        self.Model:PivotTo(CFrame.new(targetPos, targetPos + lookDir))
                        self._LastSetPos = targetPos
                    end
                    return true -- Đã tới nơi -> game lập tức gọi _CombatTick & DoAttack() trong frame này
                end
            end

            -- Chế Độ 2: SIÊU TỐC ĐỘ (Super Speed Dash)
            if Config.PetSuperSpeed and self.Target ~= nil then
                local targetPos = self:GetTargetPosition()
                if targetPos and self.Model and self.Model:IsA("Model") then
                    local pivot = self.Model:GetPivot()
                    local diff = targetPos - pivot.Position
                    local horizDiff = Vector3.new(diff.X, 0, diff.Z)
                    local mag = horizDiff.Magnitude

                    if mag <= 2 then
                        -- Đã áp sát mục tiêu
                        return true
                    end

                    local mult = math.clamp(Config.PetSpeedMultiplier or 50, 1, 150)
                    local baseSpd = 20
                    if origPetGetSpeed then
                        local ok, spd = pcall(origPetGetSpeed, self)
                        if ok and typeof(spd) == "number" then
                            baseSpd = spd
                        end
                    end
                    local spd = baseSpd * mult
                    local dt = (type(p102) == "number" and p102 > 0) and p102 or 0.033
                    local step = spd * dt

                    if step >= (mag - 1) then
                        -- Lướt tới ngay mục tiêu trong frame này
                        self._GlideTo = nil
                        local lookRot = CFrame.new(Vector3.zero, horizDiff.Unit)
                        self.Model:PivotTo(CFrame.new(targetPos) * lookRot)
                        self._LastSetPos = targetPos
                        return true
                    else
                        -- Lướt tốc độ cao mượt mà không bị giới hạn 8 studs của game
                        self._GlideTo = nil
                        local dir = horizDiff.Unit
                        local nextPos = pivot.Position + dir * step
                        local lookRot = CFrame.new(Vector3.zero, dir)
                        self.Model:PivotTo(CFrame.new(nextPos) * lookRot)
                        self._LastSetPos = nextPos
                        return false
                    end
                end
            end

            if origPetMoveTick then
                return origPetMoveTick(self, p102, p103, p104)
            end
            return false
        end

        -- Hook 4: Bỏ qua hoạt ảnh múa chiêu của Pet (Zero Animation Wait - Mức An Toàn 100%)
        if AbilityUtility then
            local origWait = AbilityUtility.WaitOrCancel
            AbilityUtility.WaitOrCancel = function(pet, target, duration)
                if Config.FastSkillAnimation then
                    return 0, false -- Không chờ animation múa chiêu (triệt tiêu delay 3-5s)
                end
                if origWait then return origWait(pet, target, duration) end
                return 0, false
            end

            local origWaitForEvent = AbilityUtility.WaitForEventOrCancel
            AbilityUtility.WaitForEventOrCancel = function(pet, target, event)
                if Config.FastSkillAnimation then
                    return true -- Hoàn tất animation marker tức thì
                end
                if origWaitForEvent then return origWaitForEvent(pet, target, event) end
                return true
            end

            local origPlayAnimation = AbilityUtility.PlayAnimation
            AbilityUtility.PlayAnimation = function(petModel, anim)
                local track = origPlayAnimation and origPlayAnimation(petModel, anim)
                if Config.FastSkillAnimation and track then
                    pcall(function()
                        track:AdjustSpeed(25) -- Tua nhanh hoạt ảnh 25x để marker chạm đích tức thì
                        task.delay(0.04, function()
                            pcall(function() track:Stop() end)
                        end)
                    end)
                end
                return track
            end

            local origPlayStandAnimation = AbilityUtility.PlayStandAnimation
            AbilityUtility.PlayStandAnimation = function(petModel, anim)
                local track = origPlayStandAnimation and origPlayStandAnimation(petModel, anim)
                if Config.FastSkillAnimation and track then
                    pcall(function()
                        track:AdjustSpeed(25)
                        task.delay(0.04, function()
                            pcall(function() track:Stop() end)
                        end)
                    end)
                end
                return track
            end
        end

        petBrainHooked = true
        Log("Đã nạp và kích hoạt toàn bộ Pet Exploit Hooks (0A, 0B, 1, 2, 3, 4) thành công!")
    end)
    return success
end

-- Tầm Đánh & Khóa Quái Toàn Map (Infinite Attack Range)
local origGameBalanceAttackRadius = nil
local origGameBalanceAutoAttackRadius = nil

local function SetInfiniteAttackRange(enable)
    if GameBalance then
        if origGameBalanceAttackRadius == nil then
            origGameBalanceAttackRadius = GameBalance.PlayerAttackRadius or 20
            origGameBalanceAutoAttackRadius = GameBalance.AutoAttackRadius or 35
        end

        if enable then
            GameBalance.PlayerAttackRadius = 99999
            GameBalance.AutoAttackRadius = 99999
            GameBalance.AutoAttackRetreatRange = 99999
        else
            GameBalance.PlayerAttackRadius = origGameBalanceAttackRadius
            GameBalance.AutoAttackRadius = origGameBalanceAutoAttackRadius
            GameBalance.AutoAttackRetreatRange = 99999 -- Luôn mở rộng tầm xích quái vô hạn để Pet không tự quay đầu
        end
    end

    if GameConfig then
        if enable then
            GameConfig.MaxAttackDistance = 99999
            GameConfig.MaxTargetDistance = 99999
        else
            GameConfig.MaxAttackDistance = 160
            GameConfig.MaxTargetDistance = 150
        end
    end
end

-- Tự động kích hoạt Hooks ngay khi nạp script nếu tính năng đã được bật sẵn
task.spawn(function()
    task.wait(0.5)
    if Config.FastSkillAnimation or Config.PetInstantTeleport or Config.PetSuperSpeed then
        hookPetBrain()
    end
    if Config.InfiniteAttackRange then
        SetInfiniteAttackRange(true)
    end
end)

-- ========================================================================
-- 11. VƯỢT ẢI THẾ GIỚI & KÍCH HOẠT ĐỀN THỜ (SHRINES & STAGE HOPPING)
-- ========================================================================
-- Tự động kích hoạt Đền Thờ (Shrines) & SoulShrine - Tối ưu hóa cực độ, không lag
local function activateAllShrines()
    local activatedCount = 0

    -- 1. Kích hoạt Shrines trên bản đồ bằng CollectionService Tag "Shrine" (Cực nhanh & nhẹ)
    pcall(function()
        local shrines = CollectionService:GetTagged("Shrine")
        for _, s in ipairs(shrines) do
            if s and s.Parent then
                if Bindable and Bindable:FindFirstChild("Shrines") and Bindable.Shrines:FindFirstChild("ActivateShrine") then
                    Bindable.Shrines.ActivateShrine:Fire(s)
                end
                if Remote and Remote:FindFirstChild("Shrines") and Remote.Shrines:FindFirstChild("ActivateShrine") then
                    Remote.Shrines.ActivateShrine:FireServer(s)
                end
                activatedCount = activatedCount + 1
            end
        end

        -- Fallback cục bộ (chỉ quét folder Shrines nếu có, KHÔNG quét toàn bộ workspace)
        local shrineFolder = workspace:FindFirstChild("Shrines")
        if shrineFolder then
            for _, s in ipairs(shrineFolder:GetChildren()) do
                if s:IsA("Model") and Remote and Remote:FindFirstChild("Shrines") and Remote.Shrines:FindFirstChild("ActivateShrine") then
                    Remote.Shrines.ActivateShrine:FireServer(s)
                    activatedCount = activatedCount + 1
                end
            end
        end
    end)

    -- 2. Thu hoạch SoulShrine (chạy bất đồng bộ, không gây nghẽn luồng)
    task.spawn(function()
        pcall(function()
            if Remote and Remote:FindFirstChild("SoulShrine") and Remote.SoulShrine:FindFirstChild("Request") then
                for slot = 1, 5 do
                    Remote.SoulShrine.Request:InvokeServer("Collect", slot)
                end
            end
        end)
    end)

    return activatedCount
end

-- Vòng lặp Vượt ải & Kích hoạt Đền Thờ
local lastZoneHopTime = 0
local zeroEnemiesStreak = 0

task.spawn(function()
    local lastShrineCheck = 0
    while true do
        if not isSessionActive() then break end

        -- 1. Tự động qua ải an toàn (Anti-Spam & Delay chống nhảy ải liên tục)
        if Config.AutoNextZone then
            local now = os.clock()
            local enemiesLeft = #getValidEnemies()

            if enemiesLeft == 0 then
                zeroEnemiesStreak = zeroEnemiesStreak + 1
            else
                zeroEnemiesStreak = 0
            end

            -- Chỉ qua ải khi sạch quái liên tục ít nhất 3 nhịp (~2.5s) và cách lần qua ải trước ít nhất 8 giây
            if zeroEnemiesStreak >= 3 and (now - lastZoneHopTime) >= 8 then
                lastZoneHopTime = now
                zeroEnemiesStreak = 0

                pcall(function()
                    if Config.AutoBuyStage and Remote:FindFirstChild("Loop") and Remote.Loop:FindFirstChild("BuyStage") then
                        Remote.Loop.BuyStage:InvokeServer()
                    end
                    if Remote:FindFirstChild("Loop") and Remote.Loop:FindFirstChild("Teleport") then
                        Remote.Loop.Teleport:InvokeServer()
                        Notification("Vượt Ải", "Đã di chuyển sang ải tiếp theo!", 3)
                    end
                end)
            end
        end

        -- 2. Tự động kích hoạt Đền Thờ (Shrines) định kỳ mỗi 5s
        if Config.AutoActivateShrines then
            local now = os.clock()
            if now - lastShrineCheck >= 5 then
                lastShrineCheck = now
                pcall(activateAllShrines)
            end
        end

        task.wait(1.5)
    end
end)

-- ========================================================================
-- 12. SĂN RAID & LEO THÁP INFINITY CASTLE (INFINITE RAID ENGINE)
-- ========================================================================
local RAID_MAPS = {
    "W1: Galactic Ruins (DBZ)",
    "W2: Blackshell Port (OnePiece)",
    "W3: Hidden Village (Naruto)",
    "W4: Monarch City (SoloLeveling)",
    "W5: Wisteria Snowfield (DemonSlayer)"
}

local RAID_DIFFICULTIES = { "Normal", "Hard", "Nightmare", "Endless" }

local TOWER_OPTIONS = {
    "Tự Động Theo Ngày (Auto Day)",
    "Fire Infinity Castle (Hỏa)",
    "Water Infinity Castle (Thủy)",
    "Earth Infinity Castle (Thổ)",
    "Ice Infinity Castle (Băng)",
    "Light Infinity Castle (Quang)",
    "Dark Infinity Castle (Ám)"
}

local TOWER_ID_MAP = {
    ["Tự Động Theo Ngày (Auto Day)"] = "AutoDay",
    ["Fire Infinity Castle (Hỏa)"] = "Tower_Fire",
    ["Water Infinity Castle (Thủy)"] = "Tower_Water",
    ["Earth Infinity Castle (Thổ)"] = "Tower_Earth",
    ["Ice Infinity Castle (Băng)"] = "Tower_Ice",
    ["Light Infinity Castle (Quang)"] = "Tower_Light",
    ["Dark Infinity Castle (Ám)"] = "Tower_Dark"
}

local function getAutoDayTower()
    local bestTower = nil
    if CommonLib and CommonLib.Tower and CommonLib.Tower.GetAvailableTowers then
        pcall(function()
            local avail = CommonLib.Tower:GetAvailableTowers()
            if avail and #avail > 0 then
                for _, tId in ipairs(avail) do
                    local count = 0
                    pcall(function()
                        count = CommonLib.Tower:GetDailyTowerPlayCount(localPlayer, tId)
                    end)
                    if count and count > 0 then
                        bestTower = tId
                        break
                    end
                end
                if not bestTower then
                    bestTower = avail[1]
                end
            end
        end)
    end
    if bestTower and bestTower ~= "Tower" then return bestTower end

    local wday = os.date("*t").wday
    if wday == 2 then return "Tower_Fire"
    elseif wday == 3 then return "Tower_Water"
    elseif wday == 4 then return "Tower_Earth"
    elseif wday == 5 then return "Tower_Ice"
    elseif wday == 6 then return "Tower_Light"
    elseif wday == 7 then return "Tower_Dark"
    else return "Tower_Fire"
    end
end

-- Bảng định danh Stage cho chế độ Endless Raids (InfiniteStage) theo từng World
local ENDLESS_STAGE_BY_WORLD = {
    DBZ = "DBZInfiniteStageSpellburst",
    OnePiece = "OnePieceInfiniteStageHorde",
    Naruto = "NarutoInfiniteStageShield",
    SoloLeveling = "SoloLevelingInfiniteStageSpellburst",
    DemonSlayer = "DemonSlayerInfiniteStageHorde"
}

local function getEndlessStageId(worldKey)
    local pcallOk, RaidData = pcall(function()
        return require(game:GetService("ReplicatedStorage"):WaitForChild("ModuleScripts"):WaitForChild("Config"):WaitForChild("RaidData"))
    end)
    if pcallOk and type(RaidData) == "table" then
        for id, data in pairs(RaidData) do
            if type(id) == "string" and type(data) == "table" and type(data.Metadata) == "table" then
                if data.Metadata.World == worldKey and data.Metadata.Subtype == "InfiniteStage" and (data.Difficulty == "Easy" or data.Difficulty == "Normal") then
                    return id
                end
            end
        end
    end
    return ENDLESS_STAGE_BY_WORLD[worldKey] or (worldKey .. "InfiniteStage")
end

local function isInEndlessRaid()
    local world = localPlayer:FindFirstChild("World")
    if not (world and tostring(world.Value) == "Raids") then return false end
    local wInst = localPlayer:FindFirstChild("WorldInstanceId")
    local raids = workspace:FindFirstChild("Worlds") and workspace.Worlds:FindFirstChild("Raids")
    local inst = wInst and raids and raids:FindFirstChild(tostring(wInst.Value))
    local rId = inst and inst:GetAttribute("RaidId")
    if type(rId) == "string" and (rId:find("InfiniteStage") or rId:find("Endless")) then
        return true, rId, inst
    end
    return false, nil, inst
end

local function getEndlessWave()
    local inEndless, _, inst = isInEndlessRaid()
    if not inEndless then return nil end
    local wave = inst and (inst:GetAttribute("LoopWave") or inst:GetAttribute("Wave"))
    if not wave then
        wave = localPlayer:GetAttribute("LoopWave") or localPlayer:GetAttribute("Wave")
    end
    return tonumber(wave) or 1
end

local function createRaidRoom()
    local rawId = Config.SelectedRaidId or "Naruto"
    local diff = Config.SelectedRaidDifficulty or "Hard"

    local isEndless = (diff == "Endless")
    local endlessStageId = isEndless and getEndlessStageId(rawId) or nil
    local loopId = isEndless and endlessStageId or ("LoopRaid_" .. rawId .. "_" .. diff)
    local targetWorld = rawId:find("Raid") and rawId or (rawId .. "Raid")

    if isEndless then
        Notification("Tạo Phòng ENDLESS RAID", string.format("Đang tạo phòng Endless: %s (%s)...", tostring(rawId), tostring(endlessStageId)), 3)
    else
        Notification("Tạo Phòng RAID", string.format("Đang tạo phòng chờ: %s [%s]...", tostring(rawId), tostring(diff)), 3)
    end

    -- Cài đặt chế độ Auto Stages (RaidAutoFollow: Retry / Next / Off)
    pcall(function()
        local rf = require(game:GetService("ReplicatedStorage"):WaitForChild("ModuleScripts"):WaitForChild("Handlers"):WaitForChild("RaidAutoFollow"))
        if rf and rf.SetMine then
            local autoChoice = Config.RaidAutoStagesMode or "Retry"
            rf.SetMine(autoChoice == "Off" and "" or autoChoice)
        end
    end)

    -- 1. Gọi Bindable AttemptStartRaid
    pcall(function()
        if Bindable and Bindable:FindFirstChild("AttemptStartRaid") then
            if isEndless then
                Bindable.AttemptStartRaid:Fire(endlessStageId)
            else
                Bindable.AttemptStartRaid:Fire(loopId)
                Bindable.AttemptStartRaid:Fire(targetWorld)
            end
        end
    end)

    -- 2. Gọi Remote StartRaidForPlayer
    pcall(function()
        if Remote and Remote:FindFirstChild("Raid") and Remote.Raid:FindFirstChild("StartRaidForPlayer") then
            if isEndless then
                Remote.Raid.StartRaidForPlayer:FireServer(endlessStageId)
            else
                Remote.Raid.StartRaidForPlayer:FireServer(loopId)
                Remote.Raid.StartRaidForPlayer:FireServer(targetWorld)
            end
        end
    end)

    -- 3. Cài đặt thông số phòng chờ
    pcall(function()
        if Remote and Remote:FindFirstChild("Raid") then
            local roomId = localPlayer:GetAttribute("RaidRoomID")
            if roomId and Remote.Raid:FindFirstChild("Room") and Remote.Raid.Room:FindFirstChild("ChangeStage") then
                if isEndless then
                    Remote.Raid.Room.ChangeStage:FireServer(roomId, endlessStageId, "Easy", 1)
                else
                    Remote.Raid.Room.ChangeStage:FireServer(roomId, "LoopBossRaid", diff, loopId)
                end
            end

            local rooms = workspace:FindFirstChild("RaidRooms") or workspace:FindFirstChild("Rooms")
            if rooms then
                for _, r in ipairs(rooms:GetChildren()) do
                    if r:FindFirstChild("Owner") and r.Owner.Value == localPlayer then
                        if Remote.Raid:FindFirstChild("SetRaidSetting") then
                            Remote.Raid.SetRaidSetting:FireServer(r, "TargetWorld", targetWorld)
                            Remote.Raid.SetRaidSetting:FireServer(r, "Difficulty", isEndless and "Easy" or diff)
                        end
                    end
                end
            end
        end
    end)
end

local function startRaidMatchInRoom()
    Notification("Bắt Đầu Trận", "Đang gửi lệnh bắt đầu trận đánh trong phòng...", 3)
    pcall(function()
        if Remote and Remote:FindFirstChild("Raid") then
            if Remote.Raid:FindFirstChild("Room") and Remote.Raid.Room:FindFirstChild("Start") then
                Remote.Raid.Room.Start:FireServer()
            end

            local rooms = workspace:FindFirstChild("RaidRooms") or workspace:FindFirstChild("Rooms")
            if rooms then
                for _, r in ipairs(rooms:GetChildren()) do
                    if r:FindFirstChild("Owner") and r.Owner.Value == localPlayer then
                        if Remote.Raid:FindFirstChild("StartRaidFromRoom") then
                            Remote.Raid.StartRaidFromRoom:FireServer(r)
                        end
                    end
                end
            end

            if Remote.Raid:FindFirstChild("Lobby") and Remote.Raid.Lobby:FindFirstChild("StartRaid") then
                Remote.Raid.Lobby.StartRaid:FireServer()
            end

            if Remote.Raid:FindFirstChild("StartRaid") then
                Remote.Raid.StartRaid:FireServer()
            end
        end
    end)
end

local function repeatRaidMatch()
    pcall(function()
        local roomId = localPlayer:GetAttribute("RaidRoomID")
        if roomId and Remote and Remote:FindFirstChild("Raid") and Remote.Raid:FindFirstChild("Retry") and Remote.Raid.Retry:FindFirstChild("Communication") then
            Remote.Raid.Retry.Communication:FireServer(roomId, "Retry")
        end

        if Remote and Remote:FindFirstChild("Raid") and Remote.Raid:FindFirstChild("RepeatRaid") then
            Remote.Raid.RepeatRaid:FireServer()
            Notification("RAID", "Đã gửi lệnh thử lại / đánh lại trận vừa xong!", 2)
        else
            createRaidRoom()
        end
    end)
end

local function leaveRaidToHub()
    pcall(function()
        -- 1. Kích hoạt trực tiếp nút Leave trên bảng Results (PlayerGui.RaidCompleteGui)
        local pGui = localPlayer:FindFirstChild("PlayerGui")
        local rcGui = pGui and pGui:FindFirstChild("RaidCompleteGui")
        if rcGui then
            local leaveBtn = rcGui:FindFirstChild("LeaveButton", true) or rcGui:FindFirstChild("Leave", true)
            if leaveBtn then
                local btn = leaveBtn:IsA("GuiButton") and leaveBtn or leaveBtn:FindFirstChildWhichIsA("GuiButton", true)
                if btn then
                    if firesignal then
                        pcall(function() firesignal(btn.Activated) end)
                        pcall(function() firesignal(btn.MouseButton1Click) end)
                    end
                    if getconnections then
                        pcall(function()
                            for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                        end)
                    end
                end
            end
        end

        -- 2. Bindable AttemptTeleport chính thức của game về Hub
        if Bindable and Bindable:FindFirstChild("AttemptTeleport") then
            Bindable.AttemptTeleport:Fire("Hub", "Stages")
        end

        -- 3. Remotes rời phòng và kết thúc trận đánh
        if Remote and Remote:FindFirstChild("Raid") then
            local roomId = localPlayer:GetAttribute("RaidRoomID")
            if roomId and Remote.Raid:FindFirstChild("Retry") and Remote.Raid.Retry:FindFirstChild("Communication") then
                Remote.Raid.Retry.Communication:FireServer(roomId, "Leave")
            end
            if Remote.Raid:FindFirstChild("Room") and Remote.Raid.Room:FindFirstChild("Leave") then
                Remote.Raid.Room.Leave:FireServer()
            end
            if Remote.Raid:FindFirstChild("Lobby") and Remote.Raid.Lobby:FindFirstChild("LeaveLobby") then
                Remote.Raid.Lobby.LeaveLobby:FireServer()
            end
        end

        -- 4. Remote Player Teleport về Hub
        if Remote and Remote:FindFirstChild("Player") and Remote.Player:FindFirstChild("Teleport") then
            Remote.Player.Teleport:FireServer("Hub")
        end

        Notification("Rời Phòng", "Đang rời khỏi thử thách về Sảnh chính (Hub)...", 2)
    end)
end

-- Tự động bấm nút Equip Suggested Pets & Start trên giao diện StageLobby của game
local function handleStageLobbyAutoEquip()
    pcall(function()
        local pGui = localPlayer:FindFirstChild("PlayerGui")
        local mainGui = pGui and pGui:FindFirstChild("MainGui")
        if mainGui then
            local stageLobby = mainGui:FindFirstChild("StageLobby", true) or mainGui:FindFirstChild("StageRaidLobby", true)
            if stageLobby and stageLobby.Visible then
                -- 1. Click nút Equip đội hình gợi ý (Suggested Team)
                local suggestion = stageLobby:FindFirstChild("Suggestion", true)
                local equipFrame = suggestion and suggestion:FindFirstChild("Equip", true)
                local equipBtn = equipFrame and (equipFrame:FindFirstChild("Button", true) or equipFrame:FindFirstChildWhichIsA("GuiButton", true))
                if equipBtn and equipBtn:IsA("GuiButton") then
                    if firesignal then
                        pcall(function() firesignal(equipBtn.Activated) end)
                        pcall(function() firesignal(equipBtn.MouseButton1Click) end)
                    end
                end

                -- 2. Tự động click Start nếu đang bật Auto Leo Tháp hoặc Auto Raid
                if Config.AutoInfinityCastle or Config.AutoFarmRaid then
                    local buttons = stageLobby:FindFirstChild("Buttons", true)
                    local startFrame = buttons and buttons:FindFirstChild("Start", true)
                    local startBtn = startFrame and (startFrame:FindFirstChild("Button", true) or startFrame:FindFirstChildWhichIsA("GuiButton", true))
                    if startBtn and startBtn:IsA("GuiButton") then
                        if firesignal then
                            pcall(function() firesignal(startBtn.Activated) end)
                            pcall(function() firesignal(startBtn.MouseButton1Click) end)
                        end
                    end
                end
            end
        end
    end)
end

-- Tự động trang bị dàn Pet nguyên tố chuẩn cho từng Tháp Infinity Castle
local function autoEquipTeamForTower(towerId)
    local rawId = towerId or Config.SelectedTowerId or "AutoDay"
    local tId = (rawId == "AutoDay" or not rawId or rawId == "Tower") and getAutoDayTower() or rawId
    if not tId or tId == "Tower" then tId = "Tower_Fire" end

    pcall(function()
        -- 1. Gọi Bindable PetData.EquipBest chính thức của game theo TowerId / Element
        if Bindable and Bindable:FindFirstChild("Data") and Bindable.Data:FindFirstChild("PetData") and Bindable.Data.PetData:FindFirstChild("EquipBest") then
            Bindable.Data.PetData.EquipBest:Fire(tId)
        end

        -- 2. Tự động click nút Equip trên giao diện StageLobby nếu đang mở
        handleStageLobbyAutoEquip()

        -- 3. Gọi Remote EquipBest dự phòng
        if Remote and Remote:FindFirstChild("Pets") and Remote.Pets:FindFirstChild("EquipBest") then
            Remote.Pets.EquipBest:InvokeServer(tId)
        end
    end)
end

local function startSelectedTower()
    local rawId = Config.SelectedTowerId or "AutoDay"
    local towerId = rawId
    if towerId == "AutoDay" or not towerId or towerId == "Tower" then
        towerId = getAutoDayTower()
    end
    if not towerId or towerId == "Tower" then
        towerId = "Tower_Fire"
    end

    -- Tự động trang bị đội hình Pet nguyên tố tối ưu trước khi vào tháp
    autoEquipTeamForTower(towerId)

    Notification("Infinity Castle", "Tiến vào tháp: " .. tostring(towerId) .. "...", 3)

    pcall(function()
        if Remote and Remote:FindFirstChild("Raid") and Remote.Raid:FindFirstChild("StartRaidForPlayer") then
            Remote.Raid.StartRaidForPlayer:FireServer(towerId)
        end
    end)

    pcall(function()
        if Bindable and Bindable:FindFirstChild("AttemptStartRaid") then
            Bindable.AttemptStartRaid:Fire(towerId)
        end
    end)
end

-- ========================================================================
-- 13. HỆ THỐNG THĂNG CẤP RANK THỢ SĂN (HUNTER RANK & ASSESSMENTS)
-- ========================================================================
local function claimHunterRankPromotion(silent)
    local claimed = false
    pcall(function()
        -- 1. Nhận thưởng các task thử thách lẻ
        if Remote and Remote:FindFirstChild("Data") and Remote.Data:FindFirstChild("CompleteTask") then
            for i = 1, 5 do
                pcall(function()
                    Remote.Data.CompleteTask:FireServer("HunterAssessment", i)
                end)
            end
        end

        -- 2. Nhận thăng cấp Rank chính
        if Remote and Remote:FindFirstChild("Data") and Remote.Data:FindFirstChild("CompleteQuest") then
            local canClaim = true
            if CommonLib and CommonLib.Quests and CommonLib.Quests.CanClaimQuest then
                canClaim = CommonLib.Quests:CanClaimQuest(localPlayer, "HunterAssessment")
            end
            if canClaim then
                Remote.Data.CompleteQuest:FireServer("HunterAssessment")
                claimed = true
                if not silent then
                    Notification("Hunter Rank", "Đã gửi lệnh thăng cấp Hunter Rank & nhận thưởng kim cương!", 3)
                end
            elseif not silent then
                Notification("Hunter Rank", "Chưa hoàn thành toàn bộ thử thách của Rank này!", 2)
            end
        end
    end)
    return claimed
end

local function startCurrentHunterChallenge()
    local started = false
    pcall(function()
        if not CommonLib or not CommonLib.Quests or not QuestTaskHandler then return end

        local questData, questId = CommonLib.Quests:GetQuestData(localPlayer, "HunterAssessment")
        if not questData or not questId then return end

        local progress = CommonLib.Quests:GetPlayerQuestProgress(localPlayer, "HunterAssessment")
        local taskDataList = QuestTaskHandler.GetTaskData("HunterAssessment", progress, questId)
        if not taskDataList then return end

        -- Tìm task đầu tiên chưa hoàn thành (Value < Max)
        for taskIndex, taskInfo in ipairs(taskDataList) do
            if taskInfo and taskInfo.Value and taskInfo.Max and taskInfo.Value < taskInfo.Max then
                local taskDetails = CommonLib.Quests:GetTaskData(localPlayer, "HunterAssessment", taskIndex, questId)
                local raidId = taskDetails and taskDetails.RaidId
                if raidId then
                    Notification("Hunter Rank", "Bắt đầu thử thách: " .. tostring(taskInfo.DisplayName or raidId), 3)
                    pcall(function()
                        if Remote and Remote:FindFirstChild("Raid") and Remote.Raid:FindFirstChild("StartRaidForPlayer") then
                            Remote.Raid.StartRaidForPlayer:FireServer(raidId)
                        end
                    end)
                    pcall(function()
                        if Bindable and Bindable:FindFirstChild("AttemptStartRaid") then
                            Bindable.AttemptStartRaid:Fire(raidId)
                        end
                    end)
                    started = true
                    break
                end
            end
        end
    end)
    return started
end

local function openHunterRankGUI()
    pcall(function()
        if Bindable and Bindable:FindFirstChild("Gui") and Bindable.Gui:FindFirstChild("ToggleAreaWindow") then
            Bindable.Gui.ToggleAreaWindow:Fire("HunterAssessment", true)
            Notification("Hunter Rank", "Đã mở giao diện Hunter Rank & Thử Thách!", 2)
        end
    end)
end

-- Lắng nghe kết thúc Raid / Tháp để tự động đánh lại
pcall(function()
    if Remote and Remote:FindFirstChild("Raid") and Remote.Raid:FindFirstChild("RaidResults") then
        Remote.Raid.RaidResults.OnClientEvent:Connect(function()
            if isSessionActive() then
                if Config.AutoRepeatRaid then
                    task.wait(1.5)
                    pcall(repeatRaidMatch)
                elseif Config.AutoInfinityCastle then
                    task.wait(1.5)
                    pcall(startSelectedTower)
                elseif Config.AutoHunterRank then
                    task.wait(1.5)
                    pcall(function()
                        claimHunterRankPromotion(true)
                    end)
                    task.wait(0.5)
                    pcall(leaveRaidToHub)
                end
            end
        end)
    end
end)

-- Lắng nghe sự kiện chuyển tầng tháp từ game (ChangeStage)
pcall(function()
    if Bindable and Bindable:FindFirstChild("Gui") and Bindable.Gui:FindFirstChild("Raids") and Bindable.Gui.Raids:FindFirstChild("ChangeStage") then
        Bindable.Gui.Raids.ChangeStage.Event:Connect(function(lobbyType, roomId, startTime, endTime)
            if Config.AutoInfinityCastle and (lobbyType == "Tower" or isInRaid()) then
                task.wait(0.5)
                local rawId = Config.SelectedTowerId or "AutoDay"
                local towerId = (rawId == "AutoDay" or not rawId or rawId == "Tower") and getAutoDayTower() or rawId
                if not towerId or towerId == "Tower" then towerId = "Tower_Fire" end

                -- Tự động trang bị đội hình Pet nguyên tố tối ưu cho tầng tháp mới
                autoEquipTeamForTower(towerId)

                pcall(function()
                    if Bindable.Gui:FindFirstChild("ToggleAreaWindow") then
                        Bindable.Gui.ToggleAreaWindow:Fire("ChangeTower", false)
                    end
                end)
                pcall(function()
                    Bindable.Gui.Raids.StageSelectionChosen:Fire(roomId, towerId, "Easy")
                end)
                pcall(function()
                    if Remote and Remote.Raid and Remote.Raid.Room and Remote.Raid.Room.ChangeStage then
                        Remote.Raid.Room.ChangeStage:FireServer(roomId, towerId, "Easy")
                    end
                end)
            end
        end)
    end
end)

-- Vòng lặp giám sát phòng Raid & Chuyển ải
task.spawn(function()
    while true do
        if not isSessionActive() then break end

        -- Tự động chuyển ải trong phòng Raid khi đã sạch quái nhỏ
        pcall(function()
            if isInRaid() and Remote and Remote:FindFirstChild("Raid") then
                if Config.AutoChangeRaidStage and Remote.Raid:FindFirstChild("Room") and Remote.Raid.Room:FindFirstChild("ChangeStage") then
                    local enemies = getValidEnemies()
                    if #enemies == 0 then
                        Remote.Raid.Room.ChangeStage:FireServer()
                    end
                end
            end
        end)

        task.wait(1.5)
    end
end)

-- Vòng lặp chuyên trách Tự Động Leo Tháp (Auto Infinity Castle)
task.spawn(function()
    local lastEnterAttempt = 0
    local lastFloorAdvance = 0
    local lastLobbyCheck = 0
    while true do
        if not isSessionActive() then break end

        -- Tự động bấm Equip và Start trên bảng StageLobby nếu xuất hiện
        local now = os.clock()
        if now - lastLobbyCheck >= 1 then
            lastLobbyCheck = now
            handleStageLobbyAutoEquip()
        end

        if Config.AutoInfinityCastle then
            local inRaid = isInRaid()

            if not inRaid then
                -- Nếu đang ở ngoài Sảnh / Hub -> tự động vào tháp sau mỗi 4 giây
                if now - lastEnterAttempt >= 4 then
                    lastEnterAttempt = now
                    pcall(startSelectedTower)
                end
            else
                -- Đang bên trong tháp: kiểm tra sạch quái để vượt tầng
                local enemies = getValidEnemies()
                if #enemies == 0 and (now - lastFloorAdvance >= 1.5) then
                    lastFloorAdvance = now
                    local roomId = localPlayer:GetAttribute("RaidRoomID")
                    local rawId = Config.SelectedTowerId or "AutoDay"
                    local towerId = (rawId == "AutoDay" or not rawId or rawId == "Tower") and getAutoDayTower() or rawId
                    if not towerId or towerId == "Tower" then towerId = "Tower_Fire" end

                    -- Tự động đảm bảo đội hình nguyên tố luôn được trang bị
                    autoEquipTeamForTower(towerId)

                    pcall(function()
                        if Remote and Remote.Raid and Remote.Raid.Room and Remote.Raid.Room.ChangeStage then
                            Remote.Raid.Room.ChangeStage:FireServer(roomId, towerId, "Easy")
                        end
                    end)
                    pcall(function()
                        if Bindable and Bindable:FindFirstChild("Gui") and Bindable.Gui:FindFirstChild("Raids") and Bindable.Gui.Raids:FindFirstChild("StageSelectionChosen") then
                            Bindable.Gui.Raids.StageSelectionChosen:Fire(roomId, towerId, "Easy")
                        end
                    end)
                    pcall(function()
                        if Bindable and Bindable:FindFirstChild("Gui") and Bindable.Gui:FindFirstChild("ToggleAreaWindow") then
                            Bindable.Gui.ToggleAreaWindow:Fire("ChangeTower", false)
                        end
                    end)
                end
            end
        end

        task.wait(1)
    end
end)

-- Vòng lặp chuyên trách Tự Động Úp Rank Thợ Săn (Auto Hunter Rank)
task.spawn(function()
    local lastActionTime = 0
    local lastResultsLeaveAttempt = 0
    while true do
        if not isSessionActive() then break end

        if Config.AutoHunterRank then
            local inRaid = isInRaid()
            local now = os.clock()

            if inRaid then
                -- Kiểm tra nếu bảng Results / Hết trận đang hiển thị
                local isResultsOpen = false
                pcall(function()
                    local valObj = Bindable and Bindable:FindFirstChild("ValueObjects")
                    local ro = valObj and valObj:FindFirstChild("RaidResultsOpen")
                    if ro and ro:IsA("BoolValue") and ro.Value == true then
                        isResultsOpen = true
                    end
                    local pGui = localPlayer:FindFirstChild("PlayerGui")
                    local rcGui = pGui and pGui:FindFirstChild("RaidCompleteGui")
                    if rcGui and rcGui.Enabled == true then
                        isResultsOpen = true
                    end
                end)

                if isResultsOpen and (now - lastResultsLeaveAttempt >= 2) then
                    lastResultsLeaveAttempt = now
                    pcall(function()
                        claimHunterRankPromotion(true)
                    end)
                    task.wait(0.5)
                    pcall(leaveRaidToHub)
                end
            else
                -- Đang ở ngoài Sảnh / Hub
                if now - lastActionTime >= 3.5 then
                    lastActionTime = now
                    claimHunterRankPromotion(true)

                    task.wait(0.5)

                    if not isInRaid() then
                        startCurrentHunterChallenge()
                    end
                end
            end
        end

        task.wait(1)
    end
end)

-- ========================================================================
-- 14. TỰ ĐỘNG NHẬN QUÀ MIỄN PHÍ (1-CLICK & AUTO REWARDS)
-- ========================================================================
local function claimAllFreeRewards(silent)
    if not silent then
        Notification("Nhận Quà", "Đang tự động nhận tất cả phần thưởng free...", 3)
    end
    task.spawn(function()
        local count = 0
        local function safeClaim(fn)
            pcall(function()
                task.spawn(function()
                    pcall(fn)
                end)
                count = count + 1
            end)
        end

        pcall(function()
            -- 1. Quà online theo mốc thời gian (Playtime Rewards 1-12)
            if Remote:FindFirstChild("PlaytimeRewards") and Remote.PlaytimeRewards:FindFirstChild("Claim") then
                for i = 1, 12 do
                    safeClaim(function() Remote.PlaytimeRewards.Claim:InvokeServer(i) end)
                end
            end
            -- 2. Điểm danh hàng ngày (Daily Login Calendar)
            if Remote:FindFirstChild("LoginCalendar") and Remote.LoginCalendar:FindFirstChild("Claim") then
                safeClaim(function() Remote.LoginCalendar.Claim:InvokeServer() end)
            end
            -- 3. Quà gia nhập Roblox Group (Group Reward)
            if Remote:FindFirstChild("GroupReward") and Remote.GroupReward:FindFirstChild("Claim") then
                safeClaim(function() Remote.GroupReward.Claim:InvokeServer() end)
            end
            -- 4. Quà AFK luyện tập (Training Return)
            if Remote:FindFirstChild("TrainingReturn") and Remote.TrainingReturn:FindFirstChild("Claim") then
                safeClaim(function() Remote.TrainingReturn.Claim:InvokeServer() end)
            end
            -- 5. Season Pass (Claim tất cả mốc Season Pass miễn phí + Bonus)
            if Remote:FindFirstChild("SeasonPass") then
                if Remote.SeasonPass:FindFirstChild("ClaimAllSeasonPassRewards") then
                    safeClaim(function() Remote.SeasonPass.ClaimAllSeasonPassRewards:FireServer() end)
                end
                if Remote.SeasonPass:FindFirstChild("ClaimSeasonPassBonus") then
                    safeClaim(function() Remote.SeasonPass.ClaimSeasonPassBonus:FireServer() end)
                end
            end
            -- 6. Nhiệm vụ & Thành tựu (Achievements)
            if Remote:FindFirstChild("Achievements") and Remote.Achievements:FindFirstChild("ClaimAchievement") then
                safeClaim(function() Remote.Achievements.ClaimAchievement:FireServer() end)
            end
            -- 7. Thưởng xếp hạng giải đấu (Tournaments)
            if Remote:FindFirstChild("Tournaments") and Remote.Tournaments:FindFirstChild("ClaimRewards") then
                safeClaim(function() Remote.Tournaments.ClaimRewards:FireServer() end)
            end
            -- 8. Kim Cương Chỉ Mục Toàn World (Claim All Index Rewards)
            if Remote:FindFirstChild("Loop") and Remote.Loop:FindFirstChild("IndexClaim") then
                safeClaim(function() Remote.Loop.IndexClaim:InvokeServer(nil) end)
            end
            -- 9. Thưởng tích lũy AFK (Anti-AFK Rewards)
            if Remote:FindFirstChild("AntiAFK") and Remote.AntiAFK:FindFirstChild("AcceptRewards") then
                safeClaim(function() Remote.AntiAFK.AcceptRewards:FireServer() end)
            end
        end)

        task.wait(0.5)
        if not silent and count > 0 then
            Notification("Hoàn Tất", string.format("Đã gửi %d yêu cầu nhận quà thành công!", count), 4)
        end
    end)
end

-- Vòng lặp tự động nhận quà định kỳ
task.spawn(function()
    while true do
        if not isSessionActive() then break end
        if Config.AutoClaimFreeRewards then
            pcall(function()
                claimAllFreeRewards(true)
            end)
        end
        task.wait(60)
    end
end)

-- ========================================================================
-- 15. HỆ THỐNG CÂY KỸ NĂNG (UPGRADE TREE - LOOP/TREE)
-- ========================================================================
local function upgradeTreeAvailableNodes(silent)
    local upgradedCount = 0
    pcall(function()
        local buyRemote = Remote and Remote:FindFirstChild("Loop") and Remote.Loop:FindFirstChild("BuyTreeNode")
        if not buyRemote then return end

        local treeMod = TreeUpgrades
        local cLib = CommonLib
        if not treeMod or not treeMod.Nodes or not treeMod.GetState then return end

        local maxPasses = 15
        while maxPasses > 0 do
            maxPasses = maxPasses - 1
            local tree = {}
            if cLib and cLib.GetData then
                pcall(function()
                    local d = cLib.GetData(localPlayer)
                    tree = d and d.Loop and d.Loop.Tree or {}
                end)
            end

            local coins = 0
            pcall(function()
                local ld = localPlayer:FindFirstChild("leaderstats")
                local c = ld and (ld:FindFirstChild("Coins") or ld:FindFirstChild("Coin") or ld:FindFirstChild("Gold"))
                coins = c and tonumber(c.Value) or 0
                if coins == 0 and cLib and cLib.GetData then
                    local d = cLib.GetData(localPlayer)
                    coins = d and tonumber(d.Coins) or 0
                end
            end)

            local anyBought = false
            for nodeId, nodeData in pairs(treeMod.Nodes) do
                local state = treeMod.GetState(nodeId, tree)
                if state == "Available" then
                    local cost = tonumber(nodeData.Cost) or 0
                    if coins >= cost then
                        local ok = buyRemote:InvokeServer(nodeId)
                        if ok == true or ok == nil then
                            upgradedCount = upgradedCount + 1
                            anyBought = true
                            tree[nodeId] = true
                            coins = coins - cost
                            if not silent then
                                Notification("Cây Kỹ Năng", "Đã nâng cấp: " .. tostring(nodeData.Name or nodeId), 1.5)
                            end
                            task.wait(0.12)
                        end
                    end
                end
            end

            if not anyBought then
                break
            end
        end
    end)

    if not silent then
        if upgradedCount > 0 then
            Notification("Upgrade Tree", "Đã nâng cấp thành công " .. tostring(upgradedCount) .. " nút kỹ năng!", 3)
        else
            Notification("Upgrade Tree", "Không có nút kỹ năng nào đủ điều kiện hoặc đủ tiền để nâng!", 2)
        end
    end

    return upgradedCount
end

local function openUpgradeTreeGUI()
    pcall(function()
        if Bindable and Bindable:FindFirstChild("Gui") and Bindable.Gui:FindFirstChild("ToggleAreaWindow") then
            Bindable.Gui.ToggleAreaWindow:Fire("UpgradeTree", true)
            Notification("Upgrade Tree", "Đã mở giao diện Cây Kỹ Năng!", 2)
        end
    end)
end

-- Vòng lặp chuyên trách Tự Động Nâng Cấp Cây Kỹ Năng (Auto Upgrade Tree)
task.spawn(function()
    while true do
        if not isSessionActive() then break end

        if Config.AutoUpgradeTree then
            pcall(function()
                upgradeTreeAvailableNodes(true)
            end)
        end

        task.wait(6)
    end
end)

-- ========================================================================
-- 16. NOCLIP & DI CHUYỂN
-- ========================================================================
RunService.Stepped:Connect(function()
    if Config.NoClip and localPlayer.Character then
        for _, part in ipairs(localPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

local function updateCharacterSpeed()
    pcall(function()
        local char = localPlayer.Character
        local hum = char and char:FindFirstChildWhichIsA("Humanoid")
        if hum then
            hum.WalkSpeed = Config.WalkSpeed
            hum.JumpPower = Config.JumpPower
        end
    end)
end

localPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    updateCharacterSpeed()
end)

-- ========================================================================
-- 17. GACHA & REROLL QUIRK TỰ ĐỘNG (GACHA & SMART REROLL ENGINE)
-- ========================================================================
local GACHA_BANNERS = {
    "PremiumBanner1",
    "RotatingBanner",
    "ChristmasBanner",
    "Normal"
}

-- Hàm bỏ qua animation / cutscene Gacha
local function applyGachaCutsceneSkip(skip)
    pcall(function()
        local bog = localPlayer.PlayerGui:FindFirstChild("BannerOpeningGui")
        if bog then
            bog.Enabled = not skip
            local scr = bog:FindFirstChild("BannerOpeningScript")
            if scr and scr:IsA("LocalScript") then
                scr.Disabled = skip
            end
        end
    end)
end

-- Lắng nghe nếu GUI xuất hiện để tự động tắt animation nếu bật skip
if localPlayer and localPlayer:FindFirstChild("PlayerGui") then
    localPlayer.PlayerGui.ChildAdded:Connect(function(child)
        if child.Name == "BannerOpeningGui" and Config.FastSkipGachaAnim then
            applyGachaCutsceneSkip(true)
        end
    end)
end

-- Hàm thực hiện kéo lượt quay
local function executeBannerPull(pullType)
    local banner = Config.SelectedBanner or "PremiumBanner1"
    pcall(function()
        if Config.FastSkipGachaAnim then
            applyGachaCutsceneSkip(true)
        end
        if pullType == "Free" then
            if Remote:FindFirstChild("Banners") and Remote.Banners:FindFirstChild("PullFree") then
                Remote.Banners.PullFree:FireServer(banner)
            elseif Remote:FindFirstChild("Summon") and Remote.Summon:FindFirstChild("RequestPull") then
                Remote.Summon.RequestPull:InvokeServer(banner, 1)
            end
            Notification("Gacha", "Đã gửi lệnh giật lượt quay Free: " .. banner, 2)
        elseif pullType == "Single" then
            if Remote:FindFirstChild("Banners") and Remote.Banners:FindFirstChild("PullSingle") then
                Remote.Banners.PullSingle:FireServer(banner)
            elseif Remote:FindFirstChild("Summon") and Remote.Summon:FindFirstChild("RequestPull") then
                Remote.Summon.RequestPull:InvokeServer(banner, 1)
            end
        elseif pullType == "10x" then
            if Remote:FindFirstChild("Banners") and Remote.Banners:FindFirstChild("Pull10") then
                Remote.Banners.Pull10:FireServer(banner)
            elseif Remote:FindFirstChild("Summon") and Remote.Summon:FindFirstChild("RequestPull") then
                Remote.Summon.RequestPull:InvokeServer(banner, 10)
            end
        end
    end)
end

-- Vòng lặp tự động quay Gacha
task.spawn(function()
    while true do
        if not isSessionActive() then break end
        if Config.AutoPullFree then
            pcall(function() executeBannerPull("Free") end)
            task.wait(5)
        end
        if Config.AutoRoll10 then
            pcall(function() executeBannerPull("10x") end)
            task.wait(1.5)
        elseif Config.AutoRollSingle then
            pcall(function() executeBannerPull("Single") end)
            task.wait(1.5)
        else
            task.wait(2)
        end
    end
end)

-- Reroll Quirk Constants & Logic
local REROLL_TARGETS = { "Nhân Vật (Player)", "Pet Đang Trang Bị (Pet)" }
local REROLL_TIERS = { "Mythical+ / Secret / Godly", "Legendary+", "S-Tier / Top Tier", "Epic+" }

-- Hàm lấy GUID pet đầu tiên đang trang bị
local function getFirstEquippedPetGuid()
    local guid = nil
    pcall(function()
        local pets = localPlayer:FindFirstChild("Pets")
        if pets then
            for _, p in ipairs(pets:GetChildren()) do
                if p:IsA("ValueBase") and p.Value then
                    guid = p.Name
                    break
                end
            end
        end
    end)
    return guid
end

local function executeQuirkRerollOnce()
    local slot = Config.RerollSelectedSlot or 1
    local isPlayer = (Config.RerollTarget == "Nhân Vật (Player)")
    pcall(function()
        if isPlayer then
            if Remote and Remote:FindFirstChild("Player") and Remote.Player:FindFirstChild("RerollPlayerQuirk") then
                Remote.Player.RerollPlayerQuirk:FireServer(slot, false, nil, false, nil)
            elseif Bindable and Bindable:FindFirstChild("Gui") and Bindable.Gui:FindFirstChild("QuirkReroll") and Bindable.Gui.QuirkReroll:FindFirstChild("DoQuirkReroll") then
                Bindable.Gui.QuirkReroll.DoQuirkReroll:Fire(nil, slot, true, false, false, false, nil)
            end
        else
            local petGuid = getFirstEquippedPetGuid()
            if petGuid and Remote and Remote:FindFirstChild("Pets") and Remote.Pets:FindFirstChild("RerollQuirkline") then
                Remote.Pets.RerollQuirkline:FireServer(petGuid, slot, false, nil, false, nil)
            elseif Bindable and Bindable:FindFirstChild("Gui") and Bindable.Gui:FindFirstChild("QuirkReroll") and Bindable.Gui.QuirkReroll:FindFirstChild("DoQuirkReroll") then
                Bindable.Gui.QuirkReroll.DoQuirkReroll:Fire(petGuid, slot, false, false, false, false, nil)
            end
        end
    end)
end

local function acceptCurrentQuirk()
    local slot = Config.RerollSelectedSlot or 1
    local isPlayer = (Config.RerollTarget == "Nhân Vật (Player)")
    pcall(function()
        if isPlayer then
            if Remote and Remote:FindFirstChild("Player") and Remote.Player:FindFirstChild("AcceptPlayerQuirk") then
                Remote.Player.AcceptPlayerQuirk:FireServer(slot, true, nil)
            end
        else
            local petGuid = getFirstEquippedPetGuid()
            if petGuid and Remote and Remote:FindFirstChild("Pets") and Remote.Pets:FindFirstChild("AcceptQuirkline") then
                Remote.Pets.AcceptQuirkline:FireServer(petGuid, slot, true, nil)
            end
        end
        Notification("Quirk", "Đã chấp nhận Quirk hiện tại!", 2)
    end)
end

-- Lắng nghe kết quả Reroll để kiểm tra Tier dừng
pcall(function()
    if Remote and Remote:FindFirstChild("Player") and Remote.Player:FindFirstChild("RerollPlayerQuirk") then
        Remote.Player.RerollPlayerQuirk.OnClientEvent:Connect(function(success, slot, quirkData)
            if not Config.AutoRerollQuirk then return end
            if type(quirkData) == "table" or type(slot) == "string" then
                local qName = tostring(type(quirkData) == "table" and (quirkData.Name or quirkData.Type or quirkData.Rarity) or slot)
                local tierTarget = Config.RerollDesiredTier
                local shouldStop = false
                if tierTarget:find("Mythical") and (qName:find("Mythical") or qName:find("Secret") or qName:find("Godly")) then
                    shouldStop = true
                elseif tierTarget:find("Legendary") and (qName:find("Legendary") or qName:find("Mythical") or qName:find("Secret")) then
                    shouldStop = true
                elseif tierTarget:find("S-Tier") and (qName:find("S") or qName:find("Mythical") or qName:find("Legendary")) then
                    shouldStop = true
                end
                if shouldStop then
                    Config.AutoRerollQuirk = false
                    if uiRegistry["AutoRerollQuirk"] and uiRegistry["AutoRerollQuirk"].Set then
                        uiRegistry["AutoRerollQuirk"]:Set(false)
                    end
                    acceptCurrentQuirk()
                    Notification("Reroll Quirk", "ĐÃ RA QUIRK XỊN (" .. qName .. ")! Tự động dừng và nhận!", 6)
                end
            end
        end)
    end
    if Remote and Remote:FindFirstChild("Pets") and Remote.Pets:FindFirstChild("RerollQuirkline") then
        Remote.Pets.RerollQuirkline.OnClientEvent:Connect(function(success, guid, slot, quirkData)
            if not Config.AutoRerollQuirk then return end
            if type(quirkData) == "table" or type(slot) == "string" then
                local qName = tostring(type(quirkData) == "table" and (quirkData.Name or quirkData.Type or quirkData.Rarity) or slot)
                local tierTarget = Config.RerollDesiredTier
                local shouldStop = false
                if tierTarget:find("Mythical") and (qName:find("Mythical") or qName:find("Secret") or qName:find("Godly")) then
                    shouldStop = true
                elseif tierTarget:find("Legendary") and (qName:find("Legendary") or qName:find("Mythical") or qName:find("Secret")) then
                    shouldStop = true
                end
                if shouldStop then
                    Config.AutoRerollQuirk = false
                    if uiRegistry["AutoRerollQuirk"] and uiRegistry["AutoRerollQuirk"].Set then
                        uiRegistry["AutoRerollQuirk"]:Set(false)
                    end
                    acceptCurrentQuirk()
                    Notification("Pet Quirk", "ĐÃ RA QUIRK PET XỊN (" .. qName .. ")! Tự động dừng!", 6)
                end
            end
        end)
    end
end)

-- Vòng lặp Auto Reroll Quirk
task.spawn(function()
    while true do
        if not isSessionActive() then break end
        if Config.AutoRerollQuirk then
            pcall(executeQuirkRerollOnce)
            task.wait(0.4)
        else
            task.wait(1)
        end
    end
end)

-- ========================================================================
-- 18. KHO ĐỒ & NÂNG CẤP TỰ ĐỘNG (AUTO INVENTORY & UPGRADES)
-- ========================================================================
local function equipBestLoadout()
    pcall(function()
        if Remote and Remote:FindFirstChild("Data") and Remote.Data:FindFirstChild("SetEquipBestSet") then
            Remote.Data.SetEquipBestSet:InvokeServer()
        end
        if Remote and Remote:FindFirstChild("Pets") and Remote.Pets:FindFirstChild("EquipBest") then
            Remote.Pets.EquipBest:InvokeServer()
        end
        if Remote and Remote:FindFirstChild("Gear") and Remote.Gear:FindFirstChild("EquipBest") then
            Remote.Gear.EquipBest:InvokeServer()
        end
    end)
end

local function ascendAllItemsAndPets()
    local count = 0
    pcall(function()
        if Remote and Remote:FindFirstChild("Items") and Remote.Items:FindFirstChild("AscendAllItems") then
            Remote.Items.AscendAllItems:FireServer()
            count = count + 1
        end
        if Remote and Remote:FindFirstChild("Items") and Remote.Items:FindFirstChild("DoUpgradeAction") then
            local items = localPlayer:FindFirstChild("Items") or localPlayer:FindFirstChild("Inventory")
            if items then
                for _, item in ipairs(items:GetChildren()) do
                    Remote.Items.DoUpgradeAction:FireServer("Ascend", item.Name)
                    count = count + 1
                end
            end
        end
        if Remote and Remote:FindFirstChild("Pets") and Remote.Pets:FindFirstChild("AscendPet") then
            local pets = localPlayer:FindFirstChild("Pets")
            if pets then
                for _, pet in ipairs(pets:GetChildren()) do
                    Remote.Pets.AscendPet:FireServer(pet.Name)
                    count = count + 1
                end
            end
        end
    end)
    return count
end

local function sellTrashPetsAndScrap()
    local petCount = 0
    pcall(function()
        local trashPetGuids = {}
        local pets = localPlayer:FindFirstChild("Pets")
        if pets then
            for _, p in ipairs(pets:GetChildren()) do
                local isLocked = p:GetAttribute("Locked") == true
                local rarity = p:GetAttribute("Rarity") or ""
                if not isLocked and (rarity == "Common" or rarity == "Rare" or rarity == "") then
                    table.insert(trashPetGuids, p.Name)
                    petCount = petCount + 1
                end
            end
        end
        if #trashPetGuids > 0 and Remote and Remote:FindFirstChild("Data") and Remote.Data:FindFirstChild("SellPets") then
            Remote.Data.SellPets:FireServer(trashPetGuids)
        end
        if Remote and Remote:FindFirstChild("Data") and Remote.Data:FindFirstChild("ScrapItems") then
            Remote.Data.ScrapItems:FireServer({})
        end
    end)
    return petCount
end

local function upgradeWeaponsAndRunes()
    pcall(function()
        if Remote and Remote:FindFirstChild("Items") and Remote.Items:FindFirstChild("DoUpgradeAction") then
            local gear = localPlayer:FindFirstChild("Gear") or localPlayer:FindFirstChild("Weapons")
            if gear then
                for _, w in ipairs(gear:GetChildren()) do
                    Remote.Items.DoUpgradeAction:FireServer("LevelUp", w.Name)
                end
            end
        end
        if Remote and Remote:FindFirstChild("Weapons") and Remote.Weapons:FindFirstChild("LevelUp") then
            Remote.Weapons.LevelUp:FireServer()
        end
        if Remote and Remote:FindFirstChild("Pets") and Remote.Pets:FindFirstChild("LevelUpPetSlot") then
            for slot = 1, 6 do
                Remote.Pets.LevelUpPetSlot:FireServer(slot)
            end
        end
        if Remote and Remote:FindFirstChild("Items") and Remote.Items:FindFirstChild("UpgradeRune") then
            Remote.Items.UpgradeRune:FireServer()
        end
    end)
end

-- Vòng lặp xử lý Kho Đồ & Nâng Cấp
task.spawn(function()
    while true do
        if not isSessionActive() then break end
        if Config.AutoEquipBest then
            pcall(equipBestLoadout)
        end
        if Config.AutoAscendAll then
            pcall(ascendAllItemsAndPets)
        end
        if Config.AutoSellTrashPets then
            pcall(sellTrashPetsAndScrap)
        end
        if Config.AutoUpgradeWeapons then
            pcall(upgradeWeaponsAndRunes)
        end
        task.wait(15)
    end
end)

-- ========================================================================
-- 19. GIAO DIỆN CHÍNH THỨC (HELMHUB MASTER UI)
-- ========================================================================
local Window = library:CreateWindow("HelmHub | Anime Rising", Vector2.new(550, 620))

-- ------------------------------------------------------------------------
-- TAB 1: CHIẾN ĐẤU (MASTER COMBAT)
-- ------------------------------------------------------------------------
local TabCombat = Window:CreateTab("Chiến Đấu")
local SecCombatLeft = TabCombat:CreateSector("1. Tự Động Diệt Quái & Pet Squad", "left")
local SecCombatRight = TabCombat:CreateSector("2. Định Vị An Toàn & Kỹ Năng", "right")

uiRegistry["AutoAttack"] = SecCombatLeft:AddToggle("Tự Động Đánh Quái (Auto Attack)", Config.AutoAttack, function(v)
    Config.AutoAttack = v
    triggerAutoSave()
    pcall(function()
        local valObj = Bindable and Bindable:FindFirstChild("ValueObjects")
        if valObj then
            local aa = valObj:FindFirstChild("AutoAttack")
            if aa and aa:IsA("ValueBase") then aa.Value = v end
            local ab = valObj:FindFirstChild("AutoAbility")
            if ab and ab:IsA("ValueBase") then ab.Value = v end
        end
        if not v and Bindable and Bindable:FindFirstChild("RetreatPets") then
            Bindable.RetreatPets:Fire()
        end
    end)
    Notification("Chiến Đấu", v and "Đã BẬT tự động đánh quái!" or "Đã tắt đánh quái", 2)
end)

uiRegistry["TargetMode"] = SecCombatLeft:AddDropdown("Chế Độ Ưu Tiên Mục Tiêu", { "Gần Nhất", "Ít Máu Nhất", "Chỉ Boss", "Độ Hiếm Cao" }, Config.TargetMode, false, function(v)
    Config.TargetMode = v
    triggerAutoSave()
    Notification("Mục Tiêu", "Chế độ: " .. tostring(v), 2)
end)

uiRegistry["IgnoreInvulnerable"] = SecCombatLeft:AddToggle("Bỏ Qua Quái Miễn Nhiễm (Invulnerable)", Config.IgnoreInvulnerable, function(v)
    Config.IgnoreInvulnerable = v
    triggerAutoSave()
end)

uiRegistry["AutoSpamSkills"] = SecCombatLeft:AddToggle("Xả Chiêu Pet & Mount (Auto Skills)", Config.AutoSpamSkills, function(v)
    Config.AutoSpamSkills = v
    triggerAutoSave()
end)

uiRegistry["FastWeaponAttack"] = SecCombatLeft:AddToggle("Vung Vũ Khí Nhanh (Fast M1)", Config.FastWeaponAttack, function(v)
    Config.FastWeaponAttack = v
    triggerAutoSave()
end)

uiRegistry["FastSkillAnimation"] = SecCombatLeft:AddToggle("⚡ Bỏ Qua Hoạt Ảnh Chiêu Pet (Animation Skip)", Config.FastSkillAnimation, function(v)
    Config.FastSkillAnimation = v
    triggerAutoSave()
    if v then
        hookPetBrain()
        Notification("Hoạt Ảnh Chiêu", "Đã BẬT bỏ qua múa chiêu của Pet! Ra đòn tức thì với sát thương chuẩn của Pet.", 3)
    else
        Notification("Hoạt Ảnh Chiêu", "Đã tắt bỏ qua hoạt ảnh.", 2)
    end
end)

uiRegistry["InfiniteAttackRange"] = SecCombatLeft:AddToggle("Tầm Đánh & Khóa Quái Toàn Map", Config.InfiniteAttackRange, function(v)
    Config.InfiniteAttackRange = v
    triggerAutoSave()
    SetInfiniteAttackRange(v)
    Notification("Tầm Đánh", v and "Đã nâng tầm đánh lên vô cực (99,999) - Khóa mục tiêu xuyên map!" or "Đã khôi phục tầm đánh gốc", 3)
end)

uiRegistry["PetInstantTeleport"] = SecCombatLeft:AddToggle("⚡ Pet Dịch Chuyển Tức Thời (Instant Flash)", Config.PetInstantTeleport, function(v)
    Config.PetInstantTeleport = v
    triggerAutoSave()
    if v then
        hookPetBrain()
        Notification("Pet Exploit", "Đã BẬT Tốc Biến Pet! Pet tới quái trong 0.001s.", 2)
    else
        Notification("Pet Exploit", "Đã TẮT Tốc Biến Pet.", 2)
    end
end)

uiRegistry["PetSuperSpeed"] = SecCombatLeft:AddToggle("🚀 Pet Chạy Siêu Tốc (Super Speed Dash)", Config.PetSuperSpeed, function(v)
    Config.PetSuperSpeed = v
    triggerAutoSave()
    if v then
        hookPetBrain()
        Notification("Pet Exploit", "Đã BẬT Siêu Tốc Độ Pet (" .. tostring(Config.PetSpeedMultiplier) .. "x)!", 2)
    else
        Notification("Pet Exploit", "Đã TẮT Siêu Tốc Độ Pet.", 2)
    end
end)

uiRegistry["PetSpeedMultiplier"] = SecCombatLeft:AddSlider("Hệ Số Tốc Độ Pet (Multiplier)", 5, 100, Config.PetSpeedMultiplier, 5, function(v)
    Config.PetSpeedMultiplier = v
    triggerAutoSave()
    if Config.PetSuperSpeed then
        Notification("Tốc Độ Pet", "Tốc độ: " .. tostring(v) .. "x", 1)
    end
end)

SecCombatLeft:AddButton("⚡ Dịch Chuyển Toàn Bộ Pet Tới Quái", function()
    local target = selectTarget()
    if target and target.Model then
        local targetPos = target.Position
        pcall(function()
            if Remote and Remote:FindFirstChild("Player") and Remote.Player:FindFirstChild("SetMainTarget") then
                Remote.Player.SetMainTarget:FireServer(target.Model)
            end
            if Bindable and Bindable:FindFirstChild("SendPets") then
                Bindable.SendPets:Fire(target.Model)
            end
        end)
        local pets = localPlayer:FindFirstChild("Pets")
        local count = 0
        if pets then
            for _, petVal in ipairs(pets:GetChildren()) do
                local petModel = petVal.Value
                if petModel and petModel:IsA("Model") then
                    pcall(function()
                        local offset = Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
                        petModel:PivotTo(CFrame.new(targetPos + offset))
                    end)
                    count = count + 1
                end
            end
        end
        Notification("Pet Snap", "Đã điều phối và dịch chuyển " .. tostring(count) .. " Pet tới quái!", 2)
    else
        Notification("Pet Snap", "Không có quái nào ở gần!", 2)
    end
end)

uiRegistry["AutoTeleportMob"] = SecCombatRight:AddToggle("Bay Áp Sát Quái (Safe Position Farm)", Config.AutoTeleportMob, function(v)
    Config.AutoTeleportMob = v
    triggerAutoSave()
    Notification("Vị Trí", v and "Đã bật treo lơ lửng trên đầu quái né sạch AOE!" or "Đã tắt bay", 2)
end)

uiRegistry["HoverDistance"] = SecCombatRight:AddSlider("Độ Cao Lơ Lửng (Studs)", 3, 20, Config.HoverDistance, 1, function(v)
    Config.HoverDistance = v
    triggerAutoSave()
end)

SecCombatRight:AddButton("Dịch Chuyển Tức Thời Tới Quái", function()
    local target = selectTarget()
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if target and root then
        local lookVec = root.CFrame.LookVector
        local yaw = math.atan2(lookVec.X, lookVec.Z)
        local uprightRotation = CFrame.Angles(0, yaw, 0)
        root.CFrame = CFrame.new(target.Position + Vector3.new(0, Config.HoverDistance, 0)) * uprightRotation
        root.AssemblyLinearVelocity = Vector3.zero
        Notification("Dịch Chuyển", "Đã bay tới quái: " .. target.Model.Name, 2)
    else
        Notification("Dịch Chuyển", "Không có quái nào hợp lệ!", 2)
    end
end)

SecCombatRight:AddButton("Hạ Cánh Xuống Đất (Ngừng Bay)", function()
    pcall(function()
        Config.AutoTeleportMob = false
        local char = localPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local ray = workspace:Raycast(root.Position, Vector3.new(0, -100, 0))
            if ray then
                root.CFrame = CFrame.new(ray.Position + Vector3.new(0, 3, 0))
            else
                root.CFrame = root.CFrame - Vector3.new(0, Config.HoverDistance, 0)
            end
            Notification("Hạ Cánh", "Đã tắt bay và hạ cánh an toàn!", 2)
        end
    end)
end)

-- ------------------------------------------------------------------------
-- TAB 2: VƯỢT ẢI (WORLD & STAGE LOOP)
-- ------------------------------------------------------------------------
local TabStage = Window:CreateTab("Vượt Ải")
local SecStageLeft = TabStage:CreateSector("1. Vượt Ải Tự Động (Stage Loop)", "left")
local SecStageRight = TabStage:CreateSector("2. Đền Thờ & Nhận Quà (Shrines & Rewards)", "right")

uiRegistry["AutoNextZone"] = SecStageLeft:AddToggle("Tự Động Sang Ải Tiếp Theo (Auto Next Zone)", Config.AutoNextZone, function(v)
    Config.AutoNextZone = v
    triggerAutoSave()
    Notification("Vượt Ải", v and "Đã bật tự động qua ải khi sạch quái!" or "Đã tắt qua ải", 2)
end)

uiRegistry["AutoBuyStage"] = SecStageLeft:AddToggle("Tự Động Mua Ải Mới (Auto Buy Stage)", Config.AutoBuyStage, function(v)
    Config.AutoBuyStage = v
    triggerAutoSave()
end)

SecStageLeft:AddButton("Bấm Qua Ải Ngay (Teleport Next)", function()
    pcall(function()
        if Remote:FindFirstChild("Loop") and Remote.Loop:FindFirstChild("Teleport") then
            Remote.Loop.Teleport:InvokeServer()
            Notification("Qua Ải", "Đã gửi lệnh chuyển sang ải tiếp theo!", 2)
        end
    end)
end)

SecStageLeft:AddButton("Teleport Về World 1 (Ninja Realm)", function()
    pcall(function()
        if Remote and Remote:FindFirstChild("Player") and Remote.Player:FindFirstChild("Teleport") then
            Remote.Player.Teleport:FireServer("Worlds", "World1")
            Notification("Chuyển World", "Đang chuyển về World 1...", 3)
        end
    end)
end)

SecStageLeft:AddButton("Teleport Về Sảnh Chính (Hub)", function()
    pcall(function()
        if Remote and Remote:FindFirstChild("Player") and Remote.Player:FindFirstChild("Teleport") then
            Remote.Player.Teleport:FireServer("Hub")
            Notification("Chuyển World", "Đang chuyển về Hub...", 3)
        end
    end)
end)

uiRegistry["AutoActivateShrines"] = SecStageRight:AddToggle("Tự Kích Hoạt Đền Thờ (Auto Shrines)", Config.AutoActivateShrines, function(v)
    Config.AutoActivateShrines = v
    triggerAutoSave()
end)

SecStageRight:AddButton("Kích Hoạt Đền Thờ & Thu Hoạch Soul", function()
    local n = activateAllShrines()
    Notification("Đền Thờ", string.format("Đã kích hoạt %d đền thờ và thu hoạch Soul!", n), 3)
end)

uiRegistry["AutoClaimFreeRewards"] = SecStageRight:AddToggle("Tự Động Nhận Quà Định Kỳ (Auto Claim Rewards)", Config.AutoClaimFreeRewards, function(v)
    Config.AutoClaimFreeRewards = v
    triggerAutoSave()
    Notification("Nhận Quà", v and "Đã bật tự động nhận sạch quà định kỳ mỗi 60s!" or "Đã tắt", 2)
end)

SecStageRight:AddButton(">>> 1-CLICK NHẬN SẠCH QUÀ FREE <<<", function()
    claimAllFreeRewards(false)
end)

-- ------------------------------------------------------------------------
-- TAB 3: RAID (RAIDS & DUNGEONS)
-- ------------------------------------------------------------------------
local TabRaid = Window:CreateTab("RAID")
local SecRaidLeft = TabRaid:CreateSector("1. Tự Động Săn Raid (Auto Farm Raid)", "left")
local SecRaidRight = TabRaid:CreateSector("2. Leo Tháp Infinity Castle & Thử Thách", "right")

uiRegistry["AutoFarmRaid"] = SecRaidLeft:AddToggle("TỰ ĐỘNG ĐÁNH RAID (AUTO FARM RAID)", Config.AutoFarmRaid, function(v)
    Config.AutoFarmRaid = v
    triggerAutoSave()
    if v then
        Notification("RAID", "Đã BẬT Auto Farm! Khi ở trong Raid sẽ tự động khóa quái, dọn quái nhỏ & diệt Boss!", 3)
    else
        lockedTargetModel = nil
        currentCombatTarget = nil
        lastDispatchedTarget = nil
        pcall(function()
            local char = localPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                local ray = workspace:Raycast(root.Position, Vector3.new(0, -100, 0))
                if ray then
                    root.CFrame = CFrame.new(ray.Position + Vector3.new(0, 3, 0))
                end
            end
            if Bindable and Bindable:FindFirstChild("RetreatPets") then
                Bindable.RetreatPets:Fire()
            end
            local valObj = Bindable and Bindable:FindFirstChild("ValueObjects")
            if valObj then
                local aa = valObj:FindFirstChild("AutoAttack")
                if aa and aa:IsA("ValueBase") and aa.Value == true then aa.Value = false end
            end
        end)
        Notification("RAID", "Đã TẮT Auto Farm Raid - Dừng tấn công quái ngay lập tức!", 2)
    end
end)

uiRegistry["SelectedRaidMap"] = SecRaidLeft:AddDropdown("Chọn Bản Đồ Raid (Map)", RAID_MAPS, Config.SelectedRaidMap, false, function(v)
    Config.SelectedRaidMap = v
    Config.SelectedRaidId = v:match("%((%w+)%)") or "Naruto"
    triggerAutoSave()
    Notification("RAID", "Đã chọn: " .. Config.SelectedRaidId, 2)
end)

uiRegistry["SelectedRaidDifficulty"] = SecRaidLeft:AddDropdown("Độ Khó Raid (Difficulty)", RAID_DIFFICULTIES, Config.SelectedRaidDifficulty, false, function(v)
    Config.SelectedRaidDifficulty = v
    triggerAutoSave()
    Notification("Độ Khó", "Đã đặt: " .. tostring(v), 2)
end)

uiRegistry["AutoRepeatRaid"] = SecRaidLeft:AddToggle("Tự Động Đánh Lại Khi Kết Thúc (Auto Repeat)", Config.AutoRepeatRaid, function(v)
    Config.AutoRepeatRaid = v
    triggerAutoSave()
    Notification("Lặp Lại Raid", v and "Đã bật tự động đánh lại khi trận kết thúc!" or "Đã tắt", 2)
end)

uiRegistry["AutoChangeRaidStage"] = SecRaidLeft:AddToggle("Tự Chuyển Ải Khi Sạch Quái Nhỏ (Change Stage)", Config.AutoChangeRaidStage, function(v)
    Config.AutoChangeRaidStage = v
    triggerAutoSave()
    Notification("Chuyển Ải", v and "Đã bật tự động qua ải/boss khi dọn sạch quái!" or "Đã tắt", 2)
end)

uiRegistry["RaidAutoStagesMode"] = SecRaidLeft:AddDropdown("Chế Độ Auto Stages (Lobby)", { "Retry", "Next", "Off" }, Config.RaidAutoStagesMode or "Retry", false, function(v)
    Config.RaidAutoStagesMode = v
    triggerAutoSave()
    pcall(function()
        local rf = require(game:GetService("ReplicatedStorage"):WaitForChild("ModuleScripts"):WaitForChild("Handlers"):WaitForChild("RaidAutoFollow"))
        if rf and rf.SetMine then
            rf.SetMine(v == "Off" and "" or v)
        end
    end)
    Notification("Auto Stages", "Đã đặt chế độ Lobby: " .. tostring(v), 2)
end)

SecRaidLeft:AddButton("🚪 Tạo / Vào Phòng Chờ Raid (Create Room)", function()
    createRaidRoom()
end)

SecRaidLeft:AddButton("⚔️ Bắt Đầu Trận Đánh Trong Phòng (Start Match)", function()
    startRaidMatchInRoom()
end)

SecRaidLeft:AddButton("🔄 Đánh Lại Raid Ngay (Repeat Raid)", function()
    repeatRaidMatch()
end)

SecRaidLeft:AddButton("🏠 Rời Phòng / Về Sảnh Chính (Hub)", function()
    leaveRaidToHub()
end)

uiRegistry["SelectedTowerOption"] = SecRaidRight:AddDropdown("Chọn Tháp Nguyên Tố (Castle)", TOWER_OPTIONS, Config.SelectedTowerOption, false, function(v)
    Config.SelectedTowerOption = v
    Config.SelectedTowerId = TOWER_ID_MAP[v] or "AutoDay"
    triggerAutoSave()
    Notification("Infinity Castle", "Đã chọn: " .. tostring(v), 2)
end)

uiRegistry["AutoInfinityCastle"] = SecRaidRight:AddToggle("TỰ ĐỘNG LEO THÁP (AUTO INFINITY CASTLE)", Config.AutoInfinityCastle, function(v)
    Config.AutoInfinityCastle = v
    triggerAutoSave()
    if v then
        Notification("Infinity Castle", "Đã BẬT Auto Leo Tháp! Sẽ tự động tiến vào và leo từng tầng!", 3)
        if not isInRaid() then
            task.spawn(startSelectedTower)
        end
    else
        lockedTargetModel = nil
        currentCombatTarget = nil
        lastDispatchedTarget = nil
        pcall(function()
            local char = localPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                local ray = workspace:Raycast(root.Position, Vector3.new(0, -100, 0))
                if ray then
                    root.CFrame = CFrame.new(ray.Position + Vector3.new(0, 3, 0))
                end
            end
            if Bindable and Bindable:FindFirstChild("RetreatPets") then
                Bindable.RetreatPets:Fire()
            end
            local valObj = Bindable and Bindable:FindFirstChild("ValueObjects")
            if valObj then
                local aa = valObj:FindFirstChild("AutoAttack")
                if aa and aa:IsA("ValueBase") and aa.Value == true then aa.Value = false end
            end
        end)
        Notification("Infinity Castle", "Đã TẮT Auto Leo Tháp - Dừng tấn công!", 2)
    end
end)

SecRaidRight:AddButton("Vào Leo Tháp Ngay (Challenge Castle)", function()
    startSelectedTower()
end)

uiRegistry["AutoTeleportMobRaid"] = SecRaidRight:AddToggle("Bay Áp Sát Né Đòn AOE Của Quái / Boss", Config.AutoTeleportMob, function(v)
    Config.AutoTeleportMob = v
    triggerAutoSave()
    Notification("Né Đòn", v and "Đã bật treo lơ lửng né đòn quét diện rộng!" or "Đã tắt", 2)
end)

SecRaidRight:AddButton("Dịch Chuyển Tức Thời Tới Quái / Boss", function()
    local target = selectTarget()
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if target and root then
        local lookVec = root.CFrame.LookVector
        local yaw = math.atan2(lookVec.X, lookVec.Z)
        local uprightRotation = CFrame.Angles(0, yaw, 0)
        root.CFrame = CFrame.new(target.Position + Vector3.new(0, Config.HoverDistance, 0)) * uprightRotation
        root.AssemblyLinearVelocity = Vector3.zero
        Notification("Dịch Chuyển", "Đã bay tới: " .. target.Model.Name, 2)
    else
        Notification("Dịch Chuyển", "Không có quái nào trong tầm quét!", 2)
    end
end)

uiRegistry["AutoHunterRank"] = SecRaidRight:AddToggle("TỰ ĐỘNG ÚP RANK THỢ SĂN (AUTO HUNTER RANK)", Config.AutoHunterRank, function(v)
    Config.AutoHunterRank = v
    triggerAutoSave()
    Notification("Hunter Rank", v and "Đã BẬT Auto Úp Rank Thợ Săn! Sẽ tự động làm thử thách và thăng hạng!" or "Đã tắt Auto Úp Rank", 3)
    if v then
        Config.AutoTeleportMob = true
        pcall(function()
            if uiRegistry["AutoTeleportMob"] and uiRegistry["AutoTeleportMob"].Set then uiRegistry["AutoTeleportMob"]:Set(true) end
            if uiRegistry["AutoTeleportMobRaid"] and uiRegistry["AutoTeleportMobRaid"].Set then uiRegistry["AutoTeleportMobRaid"]:Set(true) end
        end)
        if not isInRaid() then
            task.spawn(function()
                claimHunterRankPromotion(true)
                task.wait(0.5)
                startCurrentHunterChallenge()
            end)
        end
    else
        lockedTargetModel = nil
        currentCombatTarget = nil
        lastDispatchedTarget = nil
        pcall(function()
            local char = localPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                local ray = workspace:Raycast(root.Position, Vector3.new(0, -100, 0))
                if ray then
                    root.CFrame = CFrame.new(ray.Position + Vector3.new(0, 3, 0))
                end
            end
            if Bindable and Bindable:FindFirstChild("RetreatPets") then
                Bindable.RetreatPets:Fire()
            end
            local valObj = Bindable and Bindable:FindFirstChild("ValueObjects")
            if valObj then
                local aa = valObj:FindFirstChild("AutoAttack")
                if aa and aa:IsA("ValueBase") and aa.Value == true then aa.Value = false end
            end
        end)
    end
end)

SecRaidRight:AddButton("🎖️ Nhận Thăng Cấp Rank & Quà (Claim Rank Up)", function()
    claimHunterRankPromotion(false)
end)

SecRaidRight:AddButton("⚔️ Đi Đánh Thử Thách Rank Hiện Tại (Start Challenge)", function()
    local ok = startCurrentHunterChallenge()
    if not ok then
        Notification("Hunter Rank", "Không tìm thấy thử thách khả dụng hoặc đã hoàn thành hết!", 2)
    end
end)

SecRaidRight:AddButton("📋 Mở Bảng Hunter Rank (Open Hunter Rank GUI)", function()
    openHunterRankGUI()
end)

-- ------------------------------------------------------------------------
-- TAB 4: GACHA & REROLL (PHÂN HỆ 5: GACHA & TỰ ĐỘNG QUAY THẺ)
-- ------------------------------------------------------------------------
local TabGacha = Window:CreateTab("Gacha & Reroll")
local SecGachaLeft = TabGacha:CreateSector("1. Mở Trứng & Rút Pet Squad", "left")
local SecGachaRight = TabGacha:CreateSector("2. Auto Reroll Quirk Thông Minh", "right")

uiRegistry["SelectedBanner"] = SecGachaLeft:AddDropdown("Chọn Banner Triệu Hồi", GACHA_BANNERS, Config.SelectedBanner, false, function(v)
    Config.SelectedBanner = v
    triggerAutoSave()
    Notification("Banner", "Đã chọn banner: " .. tostring(v), 2)
end)

uiRegistry["FastSkipGachaAnim"] = SecGachaLeft:AddToggle("Bỏ Qua Animation Gacha (Fast Skip)", Config.FastSkipGachaAnim, function(v)
    Config.FastSkipGachaAnim = v
    triggerAutoSave()
    applyGachaCutsceneSkip(v)
    Notification("Gacha Cutscene", v and "Đã bật Fast Skip! Bỏ qua toàn bộ cảnh mở trứng/thẻ." or "Đã tắt", 2)
end)

uiRegistry["AutoPullFree"] = SecGachaLeft:AddToggle("Tự Động Giật Lượt Free (Auto Free Pull)", Config.AutoPullFree, function(v)
    Config.AutoPullFree = v
    triggerAutoSave()
    Notification("Gacha Free", v and "Đã bật tự động kéo lượt quay Free khi hồi xong!" or "Đã tắt", 2)
end)

uiRegistry["AutoRollSingle"] = SecGachaLeft:AddToggle("Tự Động Quay 1x (Auto Roll Single)", Config.AutoRollSingle, function(v)
    Config.AutoRollSingle = v
    triggerAutoSave()
    Notification("Gacha", v and "Đã bật tự động quay 1 lần liên tục!" or "Đã tắt", 2)
end)

uiRegistry["AutoRoll10"] = SecGachaLeft:AddToggle("Tự Động Quay 10x (Auto Roll 10x)", Config.AutoRoll10, function(v)
    Config.AutoRoll10 = v
    triggerAutoSave()
    Notification("Gacha 10x", v and "Đã bật tự động quay 10 lần liên tục!" or "Đã tắt", 2)
end)

SecGachaLeft:AddButton("Quay 1 Lần Ngay (Roll 1x)", function()
    executeBannerPull("Single")
end)

SecGachaLeft:AddButton("Quay 10 Lần Ngay (Roll 10x)", function()
    executeBannerPull("10x")
end)

SecGachaLeft:AddButton("Giật Lượt Free Ngay (Pull Free)", function()
    executeBannerPull("Free")
end)

uiRegistry["RerollTarget"] = SecGachaRight:AddDropdown("Đối Tượng Reroll Quirk", REROLL_TARGETS, Config.RerollTarget, false, function(v)
    Config.RerollTarget = v
    triggerAutoSave()
end)

uiRegistry["RerollDesiredTier"] = SecGachaRight:AddDropdown("Dừng Khi Đạt Tier", REROLL_TIERS, Config.RerollDesiredTier, false, function(v)
    Config.RerollDesiredTier = v
    triggerAutoSave()
    Notification("Reroll Target", "Mục tiêu dừng: " .. tostring(v), 2)
end)

uiRegistry["RerollSelectedSlot"] = SecGachaRight:AddSlider("Chọn Slot Quirk", 1, 3, Config.RerollSelectedSlot, 1, function(v)
    Config.RerollSelectedSlot = v
    triggerAutoSave()
end)

uiRegistry["AutoRerollQuirk"] = SecGachaRight:AddToggle("TỰ ĐỘNG REROLL QUIRK (AUTO REROLL)", Config.AutoRerollQuirk, function(v)
    Config.AutoRerollQuirk = v
    triggerAutoSave()
    Notification("Reroll", v and "Đã BẬT Auto Reroll! Sẽ tự dừng khi đạt " .. Config.RerollDesiredTier or "Đã tắt Auto Reroll", 3)
end)

SecGachaRight:AddButton("Reroll 1 Lần Ngay (Reroll Once)", function()
    executeQuirkRerollOnce()
    Notification("Reroll", "Đã gửi 1 lượt Reroll!", 2)
end)

SecGachaRight:AddButton("Chấp Nhận Quirk Hiện Tại (Accept)", function()
    acceptCurrentQuirk()
end)

-- ------------------------------------------------------------------------
-- TAB 5: KHO ĐỒ (PHÂN HỆ 6: KHO ĐỒ, TRANG BỊ & NÂNG CẤP TỰ ĐỘNG)
-- ------------------------------------------------------------------------
local TabInv = Window:CreateTab("Kho Đồ")
local SecInvLeft = TabInv:CreateSector("1. Quản Lý Trang Bị & Thăng Hoa", "left")
local SecInvRight = TabInv:CreateSector("2. Thanh Lý Rác & Nâng Cấp Tự Động", "right")

uiRegistry["AutoEquipBest"] = SecInvLeft:AddToggle("Tự Động Trang Bị Tốt Nhất (Auto Equip)", Config.AutoEquipBest, function(v)
    Config.AutoEquipBest = v
    triggerAutoSave()
    if v then equipBestLoadout() end
    Notification("Trang Bị", v and "Đã bật tự động trang bị Pet & Gear mạnh nhất!" or "Đã tắt", 2)
end)

SecInvLeft:AddButton("Trang Bị Tốt Nhất Ngay (Equip Best)", function()
    equipBestLoadout()
    Notification("Trang Bị", "Đã gửi lệnh trang bị dàn Pet và Gear tối ưu nhất!", 3)
end)

uiRegistry["AutoAscendAll"] = SecInvLeft:AddToggle("Tự Động Thăng Hoa (Auto Ascend All)", Config.AutoAscendAll, function(v)
    Config.AutoAscendAll = v
    triggerAutoSave()
    Notification("Thăng Hoa", v and "Đã bật tự động tiến hóa / thăng hoa vật phẩm & pet!" or "Đã tắt", 2)
end)

SecInvLeft:AddButton("Thăng Hoa Toàn Bộ Ngay (Ascend All)", function()
    Notification("Thăng Hoa", "Đang gửi lệnh thăng hoa toàn bộ vật phẩm...", 2)
    local n = ascendAllItemsAndPets()
    Notification("Thăng Hoa", string.format("Đã gửi %d yêu cầu thăng hoa / tiến hóa!", n), 3)
end)

uiRegistry["AutoSellTrashPets"] = SecInvRight:AddToggle("Tự Động Bán Pet Rác (Common & Rare)", Config.AutoSellTrashPets, function(v)
    Config.AutoSellTrashPets = v
    triggerAutoSave()
    Notification("Bán Pet", v and "Đã bật tự động bán pet Common & Rare để giải phóng kho!" or "Đã tắt", 2)
end)

SecInvRight:AddButton("Bán Pet Bậc Thấp Ngay (Sell Trash)", function()
    local n = sellTrashPetsAndScrap()
    Notification("Bán Pet", string.format("Đã thanh lý %d pet bậc thấp Common & Rare!", n), 3)
end)

uiRegistry["AutoUpgradeWeapons"] = SecInvRight:AddToggle("Tự Động Nâng Cấp Vũ Khí & Pet Slot", Config.AutoUpgradeWeapons, function(v)
    Config.AutoUpgradeWeapons = v
    triggerAutoSave()
    Notification("Nâng Cấp", v and "Đã bật tự động Level Up vũ khí và slot Pet!" or "Đã tắt", 2)
end)

SecInvRight:AddButton("Nâng Cấp Vũ Khí & Ghép Ngọc Ngay", function()
    upgradeWeaponsAndRunes()
    Notification("Nâng Cấp", "Đã gửi lệnh nâng cấp vũ khí, slot pet và ghép ngọc!", 3)
end)

-- ------------------------------------------------------------------------
-- TAB 6: TIỆN ÍCH (SETTINGS & UTILITIES)
-- ------------------------------------------------------------------------
local TabMisc = Window:CreateTab("Tiện Ích")
local SecMiscLeft = TabMisc:CreateSector("1. Cây Kỹ Năng & Nhân Vật", "left")
local SecMiscRight = TabMisc:CreateSector("2. Hệ Thống & Tối Ưu Game", "right")

uiRegistry["AutoUpgradeTree"] = SecMiscLeft:AddToggle("TỰ ĐỘNG NÂNG CẤP CÂY KỸ NĂNG (AUTO TREE)", Config.AutoUpgradeTree, function(v)
    Config.AutoUpgradeTree = v
    triggerAutoSave()
    Notification("Upgrade Tree", v and "Đã bật tự động nâng cấp Cây Kỹ Năng khi đủ tiền!" or "Đã tắt Auto Upgrade Tree", 2)
    if v then
        task.spawn(function()
            upgradeTreeAvailableNodes(false)
        end)
    end
end)

SecMiscLeft:AddButton("🌳 Nâng Cấp Tất Cả Có Thể (Upgrade All Available)", function()
    upgradeTreeAvailableNodes(false)
end)

SecMiscLeft:AddButton("📋 Mở Bảng Cây Kỹ Năng (Open Upgrade Tree GUI)", function()
    openUpgradeTreeGUI()
end)

uiRegistry["WalkSpeed"] = SecMiscLeft:AddSlider("Tốc Độ Chạy (WalkSpeed)", 16, 150, Config.WalkSpeed, 1, function(v)
    Config.WalkSpeed = v
    triggerAutoSave()
    updateCharacterSpeed()
end)

uiRegistry["JumpPower"] = SecMiscLeft:AddSlider("Độ Cao Nhảy (JumpPower)", 50, 250, Config.JumpPower, 1, function(v)
    Config.JumpPower = v
    triggerAutoSave()
    updateCharacterSpeed()
end)

uiRegistry["NoClip"] = SecMiscLeft:AddToggle("NoClip Xuyên Tường", Config.NoClip, function(v)
    Config.NoClip = v
    triggerAutoSave()
    Notification("NoClip", v and "Đã bật đi xuyên tường!" or "Đã tắt NoClip", 2)
end)

SecMiscRight:AddButton("💾 Lưu Cấu Hình Ngay (Save Settings)", function()
    SaveSettings(true)
end)

SecMiscRight:AddButton("🔄 Tải Lại Cấu Hình (Reload Settings)", function()
    LoadSettings(true)
end)

SecMiscRight:AddButton("🗑️ Khôi Phục Cài Đặt Gốc (Reset Default)", function()
    ResetSettings()
end)

SecMiscRight:AddButton("Bật Sáng Tối Đa (Fullbright)", function()
    pcall(function()
        local lighting = game:GetService("Lighting")
        lighting.Brightness = 2
        lighting.ClockTime = 14
        lighting.FogEnd = 100000
        lighting.GlobalShadows = false
        lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    end)
    Notification("Ánh Sáng", "Đã bật Fullbright xóa tan bóng tối!", 2)
end)

SecMiscRight:AddButton("Tối Ưu FPS Cực Độ (Boost FPS)", function()
    pcall(function()
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = false
        for _, v in ipairs(lighting:GetChildren()) do
            if v:IsA("PostEffect") then v.Enabled = false end
        end
    end)
    Notification("FPS Boost", "Đã giảm đồ họa và tăng mượt mà game!", 2)
end)

SecMiscRight:AddButton("Đổi Server Khác (Server Hop)", function()
    Notification("Server Hop", "Đang tìm server khác còn chỗ trống...", 3)
    task.spawn(function()
        pcall(function()
            local ts = game:GetService("TeleportService")
            local placeId = game.PlaceId
            local jobId = game.JobId
            local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
            if req then
                local res = req({
                    Url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100", tostring(placeId)),
                    Method = "GET"
                })
                if res and res.Body then
                    local parsed = HttpService:JSONDecode(res.Body)
                    if parsed and parsed.data then
                        for _, srv in ipairs(parsed.data) do
                            if srv.id ~= jobId and srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers then
                                ts:TeleportToPlaceInstance(placeId, srv.id, localPlayer)
                                return
                            end
                        end
                    end
                end
            end
            ts:Teleport(placeId, localPlayer)
        end)
    end)
end)

SecMiscRight:AddButton("Vào Lại Server (Rejoin)", function()
    pcall(function()
        local ts = game:GetService("TeleportService")
        ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
    end)
end)

Notification("HelmHub", "Đã nạp Anime Rising Master Engine v3.1 sẵn sàng!", 4)