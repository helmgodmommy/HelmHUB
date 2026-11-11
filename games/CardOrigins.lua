--[[
    ========================================================================
    HelmHub | Card Origins (Refactored Ultra & Instant-Win Edition)
    PlaceId: 78312396550517 | Tối ưu hóa dựa trên Telemetry & Decompile Dump
    Tác giả: dj & VANTA
    
    CÁC NÂNG CẤP ĐỘT PHÁ:
      1. Tích hợp chuẩn 100% Remotes Trùm Cuối:
         - Queen / Shadow Monarch: BuildNamiBattle (Khắc phục triệt để lỗi sai remote)
         - Gojo: BuildGojoBattle
         - Kurumi: BuildKurumiBattle
         - Hỗ trợ sẵn các Boss mở rộng: Makima, Miku, Klein, Ishtar, Eydis
      2. Phân loại Mini Boss chính xác theo từng World & Khám phá 5 Boss Ẩn:
         - World 02 (Dungeon): Cha Hae-In, Guild Master
         - World 03 (Devil Heart): Yuno
         - World 04 (Limitless Domain): Sukuna (Cursed King), Yuta Okkotsu
         - World 05 (Revolution): Sword Empress, Boothill, Ragna
         - KHU VỰC BOSS ẨN: 5 Hidden Bosses (Hidden Boss 1..5, Lord Boros)
           + Có sẵn nút Teleport tới tận nơi 5 Boss Ẩn
           + Hỗ trợ chọn độ khó riêng cho từng con (Normal, Gold, Rainbow, Uni, Paradox, Origin)
      3. Quy trình Instant-Win (Bỏ qua hoàn toàn hoạt ảnh giao tranh):
         - BuildBattle -> StartBattle -> ReportDamage (999,999) -> ReportVictory -> EndBattle
         - Tự động dọn dẹp cờ server bằng SetAutoBossFight("") để xoay tua mượt mà
      4. RiftGATE (Chu kỳ 15 phút): Tự động tham gia từ xa, giữ nguyên vị trí nhân vật
      5. Tab Mới: Tiện Ích & Auto Roll (Auto Roll thẻ bài, Auto leo Tháp Vô Tận)
      6. Cài Đặt: Anti-AFK, WhiteScreen, FPS Boost, Tốc độ di chuyển, Ẩn Menu
    ========================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer

local function safeLog(...)
    if _G.DisableConsoleLogs then return end
    pcall(function(...) print(...) end, ...)
end

local function safeWarn(...)
    if _G.DisableConsoleLogs then return end
    pcall(function(...) warn(...) end, ...)
end

local function Notification(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title or "HelmHub"),
            Text = tostring(text or ""),
            Duration = tonumber(duration) or 3
        })
    end)
end

-- ========================================================================
-- 1. LOAD UI LIBRARY (Library/inventory.lua)
-- ========================================================================
local library
local function loadLibrary()
    -- 1. Ưu tiên Local Test Server (127.0.0.1:8000 / localhost)
    pcall(function()
        library = loadstring(game:HttpGet("http://127.0.0.1:8000/Library/inventory.lua?t=" .. tostring(tick())))()
    end)
    -- 2. Đọc file local executor
    if not library and isfile and readfile then
        local localPaths = { "Library/inventory.lua", "!HelmHub/Library/inventory.lua" }
        for _, p in ipairs(localPaths) do
            if isfile(p) then
                pcall(function()
                    library = loadstring(readfile(p))()
                end)
                if library then break end
            end
        end
    end
    return library
end

library = loadLibrary()
if not library then
    safeWarn("[HelmHub] Không thể tải Library/inventory.lua!")
    return
end

-- ========================================================================
-- 2. CẤU HÌNH REMOTES (CHUẨN XÁC THEO TELEMETRY DUMP)
-- ========================================================================
local eventRemotes = ReplicatedStorage:WaitForChild("EventRemotes", 5)

-- Remote Trận Đấu & Boss
local reportVictoryRemote = eventRemotes and eventRemotes:FindFirstChild("ReportBossVictory") or ReplicatedStorage:FindFirstChild("ReportBossVictory", true)
local getCooldownRemote = eventRemotes and eventRemotes:FindFirstChild("GetBossCooldown") or ReplicatedStorage:FindFirstChild("GetBossCooldown", true)
local getBorderProgRemote = eventRemotes and eventRemotes:FindFirstChild("GetBossBorderProgress") or ReplicatedStorage:FindFirstChild("GetBossBorderProgress", true)
local getAutoBossRemote = eventRemotes and eventRemotes:FindFirstChild("GetAutoBossFight") or ReplicatedStorage:FindFirstChild("GetAutoBossFight", true)
local setAutoBossRemote = eventRemotes and eventRemotes:FindFirstChild("SetAutoBossFight") or ReplicatedStorage:FindFirstChild("SetAutoBossFight", true)
local startBattleRemote = eventRemotes and eventRemotes:FindFirstChild("StartBattle") or ReplicatedStorage:FindFirstChild("StartBattle", true)
local reportBattleDmgRemote = eventRemotes and eventRemotes:FindFirstChild("ReportBattleDamage") or ReplicatedStorage:FindFirstChild("ReportBattleDamage", true)
local endBattleRemote = eventRemotes and eventRemotes:FindFirstChild("EndBattle") or ReplicatedStorage:FindFirstChild("EndBattle", true)
local buildMiniBossRemote = eventRemotes and eventRemotes:FindFirstChild("BuildMiniBossBattle") or ReplicatedStorage:FindFirstChild("BuildMiniBossBattle", true)
local worldsTeleportRemote = ReplicatedStorage:FindFirstChild("WorldsTeleportRequest", true)

-- Bản đồ Remote khởi tạo Trùm Cuối (Khớp nối từ mã nguồn Decompile)
local MAIN_BOSS_REMOTE_MAP = {
    ["queen"]  = "BuildNamiBattle",    -- The Shadow Monarch thực tế gọi BuildNamiBattle!
    ["nami"]   = "BuildNamiBattle",
    ["gojo"]   = "BuildGojoBattle",
    ["kurumi"] = "BuildKurumiBattle",
    ["makima"] = "BuildMakimaBattle",
    ["miku"]   = "BuildMikuBattle",
    ["klein"]  = "BuildKleinBattle",
    ["ishtar"] = "BuildIshtarBattle",
    ["eydis"]  = "BuildEydisBattle"
}

-- Remote RiftGATE
local riftGateEnterRemote = eventRemotes and eventRemotes:FindFirstChild("RiftGateEnterRequest") or ReplicatedStorage:FindFirstChild("RiftGateEnterRequest", true)
local buildRiftBattleRemote = eventRemotes and eventRemotes:FindFirstChild("BuildRiftGateBattle") or ReplicatedStorage:FindFirstChild("BuildRiftGateBattle", true)
local riftStartFightRemote = eventRemotes and eventRemotes:FindFirstChild("RiftGateStartFight") or ReplicatedStorage:FindFirstChild("RiftGateStartFight", true)
local reportRiftVictoryRemote = eventRemotes and eventRemotes:FindFirstChild("ReportRiftGateVictory") or ReplicatedStorage:FindFirstChild("ReportRiftGateVictory", true)
local riftRewardRemote = eventRemotes and eventRemotes:FindFirstChild("RiftGateReward") or ReplicatedStorage:FindFirstChild("RiftGateReward", true)
local riftGateLeaveRemote = eventRemotes and eventRemotes:FindFirstChild("RiftGateLeave") or ReplicatedStorage:FindFirstChild("RiftGateLeave", true)
local riftGateSpawnedRemote = eventRemotes and eventRemotes:FindFirstChild("RiftGateSpawned") or ReplicatedStorage:FindFirstChild("RiftGateSpawned", true)
local riftGateClosedRemote = eventRemotes and eventRemotes:FindFirstChild("RiftGateClosed") or ReplicatedStorage:FindFirstChild("RiftGateClosed", true)

-- Remote Roll, Leo Tháp & Gacha
local rollRemote = eventRemotes and eventRemotes:FindFirstChild("RollRequest") or ReplicatedStorage:FindFirstChild("RollRequest", true)
local nextFloorRemote = eventRemotes and eventRemotes:FindFirstChild("NextFloor") or ReplicatedStorage:FindFirstChild("NextFloor", true)
local claimAllBattlePassRemote = ReplicatedStorage:FindFirstChild("ClaimAllBattlePass", true)

-- Remotes Phân Hệ 1: Phó Bản & Sự Kiện (Dungeon, Raid Boss & Eydis Hourly)
local startDungeonStageRemote = eventRemotes and eventRemotes:FindFirstChild("StartDungeonStage") or ReplicatedStorage:FindFirstChild("StartDungeonStage", true)
local claimDungeonRewardRemote = eventRemotes and eventRemotes:FindFirstChild("ClaimDungeonReward") or ReplicatedStorage:FindFirstChild("ClaimDungeonReward", true)
local getDungeonProgressRemote = eventRemotes and eventRemotes:FindFirstChild("GetDungeonProgress") or ReplicatedStorage:FindFirstChild("GetDungeonProgress", true)
local getDungeonCooldownRemote = eventRemotes and eventRemotes:FindFirstChild("GetDungeonCooldown") or ReplicatedStorage:FindFirstChild("GetDungeonCooldown", true)
local getAutoDungeonStageRemote = eventRemotes and eventRemotes:FindFirstChild("GetAutoDungeonStage") or ReplicatedStorage:FindFirstChild("GetAutoDungeonStage", true)
local setAutoDungeonStageRemote = eventRemotes and eventRemotes:FindFirstChild("SetAutoDungeonStage") or ReplicatedStorage:FindFirstChild("SetAutoDungeonStage", true)
local buyDungeonShopItemRemote = eventRemotes and eventRemotes:FindFirstChild("BuyDungeonShopItem") or ReplicatedStorage:FindFirstChild("BuyDungeonShopItem", true)
local openDungeonUIRemote = ReplicatedStorage:FindFirstChild("OpenDungeonUI", true)

local raidStartBattleRemote = ReplicatedStorage:FindFirstChild("RaidStartBattle", true)
local raidReportResultRemote = ReplicatedStorage:FindFirstChild("RaidReportResult", true)
local raidPurchaseRequestRemote = ReplicatedStorage:FindFirstChild("RaidPurchaseRequest", true)
local raidStateRequestRemote = ReplicatedStorage:FindFirstChild("RaidStateRequest", true)
local openRaidUIRemote = ReplicatedStorage:FindFirstChild("OpenRaidUI", true)

local buildEydisBattleRemote = eventRemotes and eventRemotes:FindFirstChild("BuildEydisBattle") or ReplicatedStorage:FindFirstChild("BuildEydisBattle", true)
local reportEydisVictoryRemote = eventRemotes and eventRemotes:FindFirstChild("ReportEydisVictory") or ReplicatedStorage:FindFirstChild("ReportEydisVictory", true)
local getEydisProgressRemote = eventRemotes and eventRemotes:FindFirstChild("GetEydisProgress") or ReplicatedStorage:FindFirstChild("GetEydisProgress", true)
local evoShardTradeRemote = eventRemotes and eventRemotes:FindFirstChild("EvoShardTrade") or ReplicatedStorage:FindFirstChild("EvoShardTrade", true)
local openEydisBattleRemote = ReplicatedStorage:FindFirstChild("OpenEydisBattle", true)

local isServerRiftGateOpen = false
local hasFarmedCurrentRiftGate = false

if riftGateSpawnedRemote and riftGateSpawnedRemote.OnClientEvent then
    pcall(function()
        riftGateSpawnedRemote.OnClientEvent:Connect(function()
            isServerRiftGateOpen = true
            hasFarmedCurrentRiftGate = false
            Notification("RiftGATE", "Cổng RiftGATE vừa xuất hiện trên máy chủ!", 4)
        end)
    end)
end

if riftGateClosedRemote and riftGateClosedRemote.OnClientEvent then
    pcall(function()
        riftGateClosedRemote.OnClientEvent:Connect(function()
            isServerRiftGateOpen = false
            hasFarmedCurrentRiftGate = false
        end)
    end)
end

-- ========================================================================
-- 3. ĐỊNH NGHĨA DỮ LIỆU CỐT LÕI (SẮP XẾP CHUẨN XÁC THEO TỪNG WORLD)
-- ========================================================================
local GAME_WORLDS = {
    ["World 01: LOBBY (Sảnh Chính)"] = {
        mapId = "lobby",
        mainBoss = nil,
        miniBosses = {}
    },
    ["World 02: DUNGEON (Shadow Realm - queen)"] = {
        mapId = "sjwmap",
        mainBoss = { name = "The Shadow Monarch", id = "queen" },
        miniBosses = {
            { name = "Cha Hae-In (chahaein)", id = "chahaein" },
            { name = "Guild Master (guildmaster)", id = "guildmaster" }
        }
    },
    ["World 03: ENDLESS CASTLE"] = {
        mapId = "infinitycastle",
        mainBoss = nil,
        miniBosses = {
            { name = "Ragna (ragna)", id = "ragna" }
        }
    },
    ["World 04: LIMITLESS DOMAIN (gojo)"] = {
        mapId = "gojodomainv2",
        mainBoss = { name = "The Honored One", id = "gojo" },
        miniBosses = {
            { name = "Sukuna - Cursed King (sukuna)", id = "sukuna" },
            { name = "Yuta Okkotsu (yuta)", id = "yuta" }
        }
    },
    ["World 05: DEVIL HEART (kurumi)"] = {
        mapId = "kurumimapspawn",
        mainBoss = { name = "Clockmaiden", id = "kurumi" },
        miniBosses = {
            { name = "Sword Empress (swordempress)", id = "swordempress" },
            { name = "Yuno (yuno)", id = "yuno" }
        }
    },
    ["World 06: THE MYSTERIOUS LIBRARY (klein)"] = {
        mapId = "mysteriouslibrary",
        mainBoss = { name = "Klein Moretti", id = "klein" },
        miniBosses = {}
    },
    ["World 07: CELESTIAL EXPRESS (Love of Remembrance - ishtar)"] = {
        mapId = "astralexpress",
        mainBoss = { name = "Love of Remembrance", id = "ishtar" },
        miniBosses = {
            { name = "Cyborg Gunslinger (boothill)", id = "boothill" },
            { name = "Sword Champion of the Cloud City (jingliu)", id = "jingliu" },
            { name = "Mini Boss 3 (Celestial Express)", id = "hsr_mini3" }
        }
    },
    ["World 08: UNKNOWN REALM (Sealed)"] = {
        mapId = nil,
        mainBoss = nil,
        miniBosses = {}
    },
    ["Khu Vực: BOSS ẨN (5 Hidden Bosses)"] = {
        mapId = "hidden",
        mainBoss = nil,
        miniBosses = {
            { name = "Hidden Boss 1", id = "hidden boss 1" },
            { name = "Hidden Boss 2", id = "hidden boss 2" },
            { name = "Hidden Boss 3 (Lord Boros)", id = "hidden boss 3" },
            { name = "Hidden Boss 4", id = "hidden boss 4" },
            { name = "Hidden Boss 5", id = "hidden boss 5" }
        }
    }
}

local MapOptions = {
    "World 01: LOBBY (Sảnh Chính)",
    "World 02: DUNGEON (Shadow Realm - queen)",
    "World 03: ENDLESS CASTLE",
    "World 04: LIMITLESS DOMAIN (gojo)",
    "World 05: DEVIL HEART (kurumi)",
    "World 06: THE MYSTERIOUS LIBRARY (klein)",
    "World 07: CELESTIAL EXPRESS (Love of Remembrance - ishtar)",
    "World 08: UNKNOWN REALM (Sealed)",
    "Khu Vực: BOSS ẨN (5 Hidden Bosses)"
}

-- Trọn bộ Mini Boss & Boss Ẩn (Sắp xếp theo World)
local ALL_MINI_BOSS_LIST = {
    -- World 02: Dungeon
    "chahaein",
    "guildmaster",
    -- World 03: Endless Castle
    "ragna",
    -- World 04: Limitless Domain
    "sukuna",
    "yuta",
    -- World 05: Devil Heart
    "swordempress",
    "yuno",
    -- World 07: Celestial Express (3 Mini Boss)
    "boothill",
    "jingliu",
    "hsr_mini3",
    -- 5 Boss Ẩn (Hidden Bosses)
    "hidden boss 1",
    "hidden boss 2",
    "hidden boss 3",
    "hidden boss 4",
    "hidden boss 5"
}

-- Danh sách Trùm Cuối đầy đủ
local ALL_MAIN_BOSS_LIST = {
    "The Shadow Monarch (queen)",
    "The Honored One (gojo)",
    "Clockmaiden (kurumi)",
    "Love of Remembrance (ishtar)",
    "Klein Moretti (klein)",
    "Makima (makima)",
    "Hatsune Miku (miku)",
    "Evolution Boss - Hourly (eydis)"
}

local MAIN_BOSS_DIFFICULTIES = {
    "01: NORMAL (Normal)",
    "02: CALAMITY (Gold)",
    "03: UMBRAL (Rainbow)",
    "04: ASTRAL (Uni)",
    "05: PARADOX (Paradox)",
    "06: ORIGIN (Origin)"
}

local BOSS_MAP_MAPPING = {
    ["queen"]  = "sjwmap",
    ["gojo"]   = "gojodomainv2",
    ["kurumi"] = "kurumimapspawn",
    ["klein"]  = "mysteriouslibrary",
    ["ishtar"] = "astralexpress"
}

local BOSS_GUI_NAME_MAP = {
    ["queen"]  = "WorldBossGui",
    ["kurumi"] = "KurumiBossGui",
    ["gojo"]   = "GojoBossGui",
    ["eydis"]  = "EydisBossGui",
    ["ishtar"] = "IshtarBossGui"
}

-- Trạng thái toàn cục
_G.SelectedMap = _G.SelectedMap or "World 02: DUNGEON (Shadow Realm - queen)"
_G.SelectedMiniBosses = _G.SelectedMiniBosses or { "chahaein", "guildmaster" }
_G.AutoMiniBoss = _G.AutoMiniBoss or false

-- Độ khó Mini Boss (Có thể tùy chỉnh cho cả Mini Boss lẫn 5 Boss Ẩn)
_G.SelectedMiniDifficulty = _G.SelectedMiniDifficulty or "01: NORMAL (Normal)"
_G.MiniBossDifficulties = _G.MiniBossDifficulties or {
    ["chahaein"]     = "01: NORMAL (Normal)",
    ["guildmaster"]  = "01: NORMAL (Normal)",
    ["yuno"]         = "01: NORMAL (Normal)",
    ["sukuna"]       = "01: NORMAL (Normal)",
    ["yuta"]         = "01: NORMAL (Normal)",
    ["swordempress"] = "01: NORMAL (Normal)",
    ["ragna"]        = "01: NORMAL (Normal)",
    ["boothill"]     = "01: NORMAL (Normal)",
    ["jingliu"]      = "01: NORMAL (Normal)",
    ["hsr_mini3"]    = "01: NORMAL (Normal)",
    ["hidden boss 1"] = "01: NORMAL (Normal)",
    ["hidden boss 2"] = "01: NORMAL (Normal)",
    ["hidden boss 3"] = "01: NORMAL (Normal)",
    ["hidden boss 4"] = "01: NORMAL (Normal)",
    ["hidden boss 5"] = "01: NORMAL (Normal)"
}

_G.SelectedMainBosses = _G.SelectedMainBosses or { "The Shadow Monarch (queen)", "The Honored One (gojo)", "Clockmaiden (kurumi)", "Love of Remembrance (ishtar)" }
_G.SelectedMainDifficulty = _G.SelectedMainDifficulty or "01: NORMAL (Normal)"
_G.MainBossDifficulties = _G.MainBossDifficulties or {
    ["queen"]  = "04: ASTRAL (Uni)",
    ["gojo"]   = "02: CALAMITY (Gold)",
    ["kurumi"] = "03: UMBRAL (Rainbow)",
    ["ishtar"] = "01: NORMAL (Normal)"
}
_G.AutoMainBoss = _G.AutoMainBoss or false
_G.PriorityMode = _G.PriorityMode or "RiftGate > Boss Chính > Boss Mini (Mặc Định)"
_G.BossDelay = _G.BossDelay or 0.3
_G.RiftNotify = _G.RiftNotify or true
_G.AutoRiftGate = _G.AutoRiftGate or false

-- Cài đặt mới: Auto Roll & Auto Tháp
_G.AutoRoll = _G.AutoRoll or false
_G.AutoNextFloor = _G.AutoNextFloor or false

-- Cài đặt Phân Hệ 1: Dungeon, Raid Boss & Trùm Giờ Eydis
_G.AutoDungeon = _G.AutoDungeon or false
_G.SelectedDungeonStage = _G.SelectedDungeonStage or "Tự Động (Stage Cao Nhất)"
_G.AutoClaimDungeonReward = _G.AutoClaimDungeonReward or true

_G.AutoRaidBoss = _G.AutoRaidBoss or false
_G.SelectedRaidNode = _G.SelectedRaidNode or "Tự Động Quét Hết (Node 1 -> 5)"

_G.AutoEydis = _G.AutoEydis or false
_G.SelectedEydisDiff = _G.SelectedEydisDiff or "Normal"
_G.EydisChallengeMode = _G.EydisChallengeMode or false

_G.AntiAFK = _G.AntiAFK or true
_G.DisableConsoleLogs = _G.DisableConsoleLogs or false
_G.WhiteScreen = _G.WhiteScreen or false
_G.FPSBoost = _G.FPSBoost or false
_G.HideMenuOnStartup = _G.HideMenuOnStartup or false
_G.WalkSpeedEnabled = _G.WalkSpeedEnabled or false
_G.WalkSpeedValue = _G.WalkSpeedValue or 16

local isMiniBossBusy = false
local isMainBossFighting = false
local isRiftGateBusy = false
local isDungeonBusy = false
local isRaidBusy = false
local isEydisBusy = false

-- ========================================================================
-- 4. HỆ THỐNG LƯU / TẢI CẤU HÌNH (PERSISTENT CONFIG)
-- ========================================================================
local CONFIG_DIR = "!HelmHub/Card Origins"
local CONFIG_FILE_NAME = CONFIG_DIR .. "/config.json"

local function ensureConfigDir()
    pcall(function()
        if isfolder and makefolder then
            if not isfolder("!HelmHub") then makefolder("!HelmHub") end
            if not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end
        end
    end)
end

local function saveConfig()
    pcall(function()
        if not writefile then return end
        ensureConfigDir()
        local cfg = {
            SelectedMap = _G.SelectedMap,
            SelectedMiniBosses = _G.SelectedMiniBosses,
            AutoMiniBoss = _G.AutoMiniBoss,
            SelectedMiniDifficulty = _G.SelectedMiniDifficulty,
            MiniBossDifficulties = _G.MiniBossDifficulties,
            SelectedMainBosses = _G.SelectedMainBosses,
            SelectedMainDifficulty = _G.SelectedMainDifficulty,
            MainBossDifficulties = _G.MainBossDifficulties,
            AutoMainBoss = _G.AutoMainBoss,
            PriorityMode = _G.PriorityMode,
            BossDelay = _G.BossDelay,
            RiftNotify = _G.RiftNotify,
            AutoRiftGate = _G.AutoRiftGate,
            AutoRoll = _G.AutoRoll,
            AutoNextFloor = _G.AutoNextFloor,
            AutoDungeon = _G.AutoDungeon,
            SelectedDungeonStage = _G.SelectedDungeonStage,
            AutoClaimDungeonReward = _G.AutoClaimDungeonReward,
            AutoRaidBoss = _G.AutoRaidBoss,
            SelectedRaidNode = _G.SelectedRaidNode,
            AutoEydis = _G.AutoEydis,
            SelectedEydisDiff = _G.SelectedEydisDiff,
            EydisChallengeMode = _G.EydisChallengeMode,
            AntiAFK = _G.AntiAFK,
            DisableConsoleLogs = _G.DisableConsoleLogs,
            WhiteScreen = _G.WhiteScreen,
            FPSBoost = _G.FPSBoost,
            HideMenuOnStartup = _G.HideMenuOnStartup,
            WalkSpeedEnabled = _G.WalkSpeedEnabled,
            WalkSpeedValue = _G.WalkSpeedValue
        }
        writefile(CONFIG_FILE_NAME, HttpService:JSONEncode(cfg))
    end)
end

local function loadConfig()
    pcall(function()
        if not isfile or not readfile then return end
        ensureConfigDir()
        local targetFile = CONFIG_FILE_NAME
        if not isfile(targetFile) and isfile("HelmHub_CardOrigins_Config.json") then
            targetFile = "HelmHub_CardOrigins_Config.json"
        end
        if isfile(targetFile) then
            local data = HttpService:JSONDecode(readfile(targetFile))
            if data then
                if data.SelectedMap ~= nil then _G.SelectedMap = data.SelectedMap end
                if data.SelectedMiniBosses ~= nil then _G.SelectedMiniBosses = data.SelectedMiniBosses end
                if data.AutoMiniBoss ~= nil then _G.AutoMiniBoss = data.AutoMiniBoss end
                if data.SelectedMiniDifficulty ~= nil then _G.SelectedMiniDifficulty = data.SelectedMiniDifficulty end
                if data.MiniBossDifficulties ~= nil then _G.MiniBossDifficulties = data.MiniBossDifficulties end
                if data.SelectedMainBosses ~= nil then _G.SelectedMainBosses = data.SelectedMainBosses end
                if data.SelectedMainDifficulty ~= nil then _G.SelectedMainDifficulty = data.SelectedMainDifficulty end
                if data.MainBossDifficulties ~= nil then _G.MainBossDifficulties = data.MainBossDifficulties end
                if data.AutoMainBoss ~= nil then _G.AutoMainBoss = data.AutoMainBoss end
                if data.PriorityMode ~= nil then _G.PriorityMode = data.PriorityMode end
                if data.BossDelay ~= nil then _G.BossDelay = data.BossDelay end
                if data.RiftNotify ~= nil then _G.RiftNotify = data.RiftNotify end
                if data.AutoRiftGate ~= nil then _G.AutoRiftGate = data.AutoRiftGate end
                if data.AutoRoll ~= nil then _G.AutoRoll = data.AutoRoll end
                if data.AutoNextFloor ~= nil then _G.AutoNextFloor = data.AutoNextFloor end
                if data.AutoDungeon ~= nil then _G.AutoDungeon = data.AutoDungeon end
                if data.SelectedDungeonStage ~= nil then _G.SelectedDungeonStage = data.SelectedDungeonStage end
                if data.AutoClaimDungeonReward ~= nil then _G.AutoClaimDungeonReward = data.AutoClaimDungeonReward end
                if data.AutoRaidBoss ~= nil then _G.AutoRaidBoss = data.AutoRaidBoss end
                if data.SelectedRaidNode ~= nil then _G.SelectedRaidNode = data.SelectedRaidNode end
                if data.AutoEydis ~= nil then _G.AutoEydis = data.AutoEydis end
                if data.SelectedEydisDiff ~= nil then _G.SelectedEydisDiff = data.SelectedEydisDiff end
                if data.EydisChallengeMode ~= nil then _G.EydisChallengeMode = data.EydisChallengeMode end
                if data.AntiAFK ~= nil then _G.AntiAFK = data.AntiAFK end
                if data.DisableConsoleLogs ~= nil then _G.DisableConsoleLogs = data.DisableConsoleLogs end
                if data.WhiteScreen ~= nil then _G.WhiteScreen = data.WhiteScreen end
                if data.FPSBoost ~= nil then _G.FPSBoost = data.FPSBoost end
                if data.HideMenuOnStartup ~= nil then _G.HideMenuOnStartup = data.HideMenuOnStartup end
                if data.WalkSpeedEnabled ~= nil then _G.WalkSpeedEnabled = data.WalkSpeedEnabled end
                if data.WalkSpeedValue ~= nil then _G.WalkSpeedValue = data.WalkSpeedValue end
            end
        end
    end)
end

loadConfig()
if not GAME_WORLDS[_G.SelectedMap] then
    _G.SelectedMap = "World 02: DUNGEON (Shadow Realm - queen)"
end

-- ========================================================================
-- 5. CÁC HÀM TIỆN ÍCH, PHÂN GIẢI ID VÀ ĐIỀU KHIỂN
-- ========================================================================
local function clickGuiElement(btn)
    if not btn then return false end
    local clicked = false
    if firesignal then
        pcall(function()
            if btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end
            if btn.Activated then firesignal(btn.Activated) end
            clicked = true
        end)
    end
    if not clicked then
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            local pos = btn.AbsolutePosition + (btn.AbsoluteSize / 2)
            vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
            task.wait(0.02)
            vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
            clicked = true
        end)
    end
    return clicked
end

-- Reset cờ trạng thái Auto Fight trên Server (Cực kỳ quan trọng để không bị lock)
local function resetServerAutoBossFlag()
    pcall(function()
        local rem = setAutoBossRemote or (eventRemotes and eventRemotes:FindFirstChild("SetAutoBossFight")) or ReplicatedStorage:FindFirstChild("SetAutoBossFight", true)
        if rem then
            rem:FireServer("", nil)
        end
    end)
end

local function setInGameAutoBoss(bossId, enable, diffInternal)
    pcall(function()
        local rem = setAutoBossRemote or (eventRemotes and eventRemotes:FindFirstChild("SetAutoBossFight")) or ReplicatedStorage:FindFirstChild("SetAutoBossFight", true)
        if not rem then return end
        if enable and bossId then
            diffInternal = diffInternal or "Normal"
            rem:FireServer(bossId, diffInternal)
        else
            rem:FireServer("", nil)
        end
    end)
end

local function teleportToWorld(mapId)
    if not mapId then return false end
    if not worldsTeleportRemote then
        worldsTeleportRemote = ReplicatedStorage:FindFirstChild("WorldsTeleportRequest", true)
    end
    if worldsTeleportRemote then
        local ok = pcall(function()
            if worldsTeleportRemote:IsA("RemoteFunction") then
                worldsTeleportRemote:InvokeServer(mapId)
            else
                worldsTeleportRemote:FireServer(mapId)
            end
        end)
        return ok
    end
    return false
end

local function resolveMainBossId(title)
    if not title then return "queen" end
    local lower = title:lower()
    if lower:find("shadow") or lower:find("queen") or lower:find("monarch") or lower:find("sjw") then
        return "queen"
    elseif lower:find("kurumi") or lower:find("clock") then
        return "kurumi"
    elseif lower:find("gojo") or lower:find("honored") or lower:find("limitless") then
        return "gojo"
    elseif lower:find("makima") then
        return "makima"
    elseif lower:find("miku") then
        return "miku"
    elseif lower:find("klein") then
        return "klein"
    elseif lower:find("ishtar") then
        return "ishtar"
    elseif lower:find("eydis") or lower:find("evolution") then
        return "eydis"
    end
    return "queen"
end

local function resolveDifficultyInternal(diffStr)
    if not diffStr then return "Normal" end
    local s = diffStr:lower()
    if s:find("astral") or s:find("uni") or s:find("04") then
        return "Uni"
    elseif s:find("umbral") or s:find("rainbow") or s:find("03") then
        return "Rainbow"
    elseif s:find("calamity") or s:find("gold") or s:find("02") then
        return "Gold"
    elseif s:find("paradox") or s:find("05") then
        return "Paradox"
    elseif s:find("origin") or s:find("06") then
        return "Origin"
    elseif s:find("normal") or s:find("01") then
        return "Normal"
    end
    return diffStr
end

-- Bảng ánh xạ bí danh tên Model trong Workspace
local BOSS_MODEL_ALIASES = {
    ["boothill"]     = { "boothill", "cyborg gunslinger", "gunslinger" },
    ["jingliu"]      = { "jingliu", "sword champion of the cloud city", "sword champion", "cloud city" },
    ["hsr_mini3"]    = { "hsr_mini3", "dan heng", "acheron", "blade", "himeko", "welt", "sunday", "robin", "aventurine", "silver wolf", "kafka" },
    ["ishtar"]       = { "ishtar_cyrenebase_verified", "love of remembrance", "ishtar", "cyrene" },
    ["swordempress"] = { "swordempress", "eydis", "sword empress" },
    ["yuno"]         = { "yuno", "yuno mini boss" },
    ["chahaein"]     = { "chahaein", "cha hae-in", "cha" },
    ["guildmaster"]  = { "guildmaster", "guild master" },
    ["sukuna"]       = { "sukuna", "awakened sukuna" },
    ["yuta"]         = { "yuta", "mini boss yuta", "yuta okkotsu" },
    ["ragna"]        = { "ragna" }
}

-- Định vị Model của Mini Boss & Boss Ẩn trong Workspace
local function findMiniBossModel(bossId)
    if not bossId then return nil end
    local clean = bossId:lower():gsub("%s+", "")
    local aliases = BOSS_MODEL_ALIASES[bossId:lower()] or {}

    local function matchName(str)
        if not str then return false end
        local s = str:lower():gsub("%s+", "")
        if s == clean or s:find(clean) or clean:find(s) then return true end
        for _, alias in ipairs(aliases) do
            local ac = alias:lower():gsub("%s+", "")
            if s == ac or s:find(ac) or ac:find(s) then return true end
        end
        return false
    end

    local function checkModel(obj)
        if not obj or not obj:IsA("Model") then return false end
        if matchName(obj.Name) then return true end
        -- Quét text trên BillboardGui nếu có
        for _, desc in ipairs(obj:GetDescendants()) do
            if desc:IsA("TextLabel") and matchName(desc.Text) then
                return true
            end
        end
        return false
    end

    -- 1. Tìm trực tiếp trong Workspace
    for _, obj in ipairs(workspace:GetChildren()) do
        if checkModel(obj) then return obj end
    end

    -- 2. Tìm trong các thư mục phổ biến
    for _, folderName in ipairs({"NPCs", "Bosses", "Enemies", "Monsters", "Spawns", "Map"}) do
        local f = workspace:FindFirstChild(folderName)
        if f then
            for _, obj in ipairs(f:GetChildren()) do
                if checkModel(obj) then return obj end
            end
        end
    end
    return nil
end

-- Teleport tới vị trí của Mini Boss hoặc Boss Ẩn
local function teleportToMiniBoss(bossId)
    local model = findMiniBossModel(bossId)
    if model then
        local targetCF = model:GetPivot()
        local char = localPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and targetCF then
            hrp.CFrame = targetCF + Vector3.new(0, 3, -4)
            Notification("Dịch Chuyển", "Đã bay tới vị trí: " .. tostring(model.Name), 2)
            return true
        end
    end
    Notification("Dịch Chuyển", "Không tìm thấy Model: " .. tostring(bossId) .. " trên map hiện tại!", 3)
    return false
end

-- Đóng Fountain / Popup rác
local function autoDismissFountain()
    pcall(function()
        local pg = localPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, g in ipairs(pg:GetChildren()) do
            if g:IsA("ScreenGui") and g.Enabled and g.Name:lower():find("fountain") then
                g.Enabled = false
            end
        end
        local sg = pg:FindFirstChild("ScreenGui")
        if sg then
            for _, child in ipairs(sg:GetChildren()) do
                if child:IsA("GuiObject") and child.Visible and child.Name:lower():find("fountain") then
                    child.Visible = false
                end
            end
        end
    end)
end

task.spawn(function()
    while true do
        autoDismissFountain()
        task.wait(1.0)
    end
end)

local BOSS_VICTORY_GUIS = {
    ["worldbossgui"] = true,
    ["kurumibossgui"] = true,
    ["gojobossgui"] = true,
    ["eydisbossgui"] = true,
    ["rewardpopupgui"] = true,
    ["raidresultbanner"] = true,
    ["cardoriginsriftbattle"] = true
}

local function autoDismissBossDefeated()
    pcall(function()
        local pg = localPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, g in ipairs(pg:GetChildren()) do
            if g:IsA("ScreenGui") and g.Enabled then
                local gn = g.Name:lower()
                -- TUYỆT ĐỐI BẢO VỆ CÁC GUI CHIẾN ĐẤU CỦA INFINITE RUN / TOWER / BATTLE SLOT
                if gn:find("battlegui") or gn:find("battlesgui") or gn:find("arena") or gn:find("tower") or gn:find("severed") or gn:find("gameui") then
                    continue
                end

                if BOSS_VICTORY_GUIS[gn] or (gn:find("boss") and gn:find("gui")) or gn:find("rewardpopup") then
                    for _, desc in ipairs(g:GetDescendants()) do
                        if desc:IsA("GuiButton") and desc.Visible then
                            local t = (desc:IsA("TextButton") and desc.Text or desc.Name):lower()
                            -- Không bao giờ bấm nút Kết Thúc, Đầu Hàng, Thoát
                            if t:find("end") or t:find("surrender") or t:find("cancel") or t:find("leave") or t:find("confirm") then
                                continue
                            end
                            if t:find("continue") or t:find("claim") or t:find("ok") or t:find("close") or t:find("skip") then
                                clickGuiElement(desc)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ========================================================================
-- 6. THUẬT TOÁN ĐÁNH BOSS INSTANT-WIN SIÊU TỐC (CHẠY NGẦM 100%)
-- ========================================================================

-- Kiểm tra Cooldown Trùm Cuối & Mini Boss từ Server
local function checkMainBossCooldown(bossId, diff)
    if not bossId then return 0 end
    diff = resolveDifficultyInternal(diff)
    if getCooldownRemote then
        local ok, cd = pcall(function()
            return getCooldownRemote:InvokeServer(bossId, diff)
        end)
        if ok and typeof(cd) == "number" and cd > 0 then
            return cd
        end
    end
    return 0
end

-- Thực thi đánh Trùm Cuối với quy trình Instant Win chuẩn xác
local function executeBossVictory(bossId, diff)
    if not bossId then return false end
    diff = resolveDifficultyInternal(diff)

    -- 1. Kiểm tra Cooldown trước khi gọi
    local cd = checkMainBossCooldown(bossId, diff)
    if cd > 0 then
        safeLog(string.format("[HelmHub] Boss %s [%s] còn Cooldown: %.1fs. Bỏ qua chờ hồi chiêu.", bossId, diff, cd))
        return false
    end

    -- 2. Gọi Remote khởi tạo trận đấu ở SLOT 2 (isSlot2 = true)
    local remoteName = MAIN_BOSS_REMOTE_MAP[bossId] or ("Build" .. bossId:sub(1,1):upper() .. bossId:sub(2) .. "Battle")
    local buildRemote = eventRemotes and eventRemotes:FindFirstChild(remoteName) or ReplicatedStorage:FindFirstChild(remoteName, true)

    if buildRemote and buildRemote:IsA("RemoteFunction") then
        pcall(function() buildRemote:InvokeServer(diff, true) end)
    end
    task.wait(0.05)

    -- 3. Báo cáo chiến thắng nhận thưởng trực tiếp (KHÔNG gọi StartBattle/ReportDamage/EndBattle để bảo vệ 100% run Infinite)
    local reportOk = false
    if reportVictoryRemote then
        local ok = pcall(function() reportVictoryRemote:FireServer(bossId, diff) end)
        if ok then reportOk = true end
    end

    -- 4. Đóng popup nhận thưởng tự động
    task.wait(0.05)
    autoDismissBossDefeated()
    autoDismissFountain()

    safeLog(string.format("[HelmHub] Đã đấm Trùm Cuối Instant-Win: %s [%s]", tostring(bossId), tostring(diff)))
    return reportOk
end

-- Thực thi đánh Mini Boss & Boss Ẩn với Chế Độ Độ Khó & Instant-Win
local function executeMiniBossBattle(bossId, diff)
    if not bossId then return false end
    diff = resolveDifficultyInternal(diff or (_G.MiniBossDifficulties and _G.MiniBossDifficulties[bossId]) or _G.SelectedMiniDifficulty or "Normal")

    -- 1. Kiểm tra Cooldown Mini Boss nếu Server quản lý
    local cd = checkMainBossCooldown(bossId, diff)
    if cd > 0 then
        safeLog(string.format("[HelmHub] Mini/Hidden Boss %s [%s] còn Cooldown: %.1fs. Bỏ qua.", bossId, diff, cd))
        return false
    end

    -- 2. Build trận ở SLOT 2: ưu tiên BuildMini_<id>(diff, true), fallback BuildMiniBossBattle(id, true)
    local cleanId = (bossId:gsub("%s+", ""))
    local specificMiniName = "BuildMini_" .. cleanId
    local specificMiniRemote = eventRemotes and eventRemotes:FindFirstChild(specificMiniName) or ReplicatedStorage:FindFirstChild(specificMiniName, true)

    if specificMiniRemote and specificMiniRemote:IsA("RemoteFunction") then
        pcall(function() specificMiniRemote:InvokeServer(diff, true) end)
    else
        if not buildMiniBossRemote then
            buildMiniBossRemote = eventRemotes and eventRemotes:FindFirstChild("BuildMiniBossBattle") or ReplicatedStorage:FindFirstChild("BuildMiniBossBattle", true)
        end
        if buildMiniBossRemote then
            pcall(function() buildMiniBossRemote:InvokeServer(bossId, true) end)
            if bossId == "jingliu" then
                pcall(function() buildMiniBossRemote:InvokeServer("swordchampion", true) end)
            end
        end
    end
    task.wait(0.05)

    -- 3. Báo cáo thắng nhận quà theo đúng Độ Khó đã chọn (Không đụng chạm Slot 1 Infinite)
    if not reportVictoryRemote then
        reportVictoryRemote = eventRemotes and eventRemotes:FindFirstChild("ReportBossVictory") or ReplicatedStorage:FindFirstChild("ReportBossVictory", true)
    end
    if reportVictoryRemote then
        pcall(function() reportVictoryRemote:FireServer(bossId, diff) end)
        if bossId == "jingliu" then
            pcall(function() reportVictoryRemote:FireServer("swordchampion", diff) end)
        end
    end

    -- 4. Dọn popup an toàn
    task.wait(0.05)
    autoDismissBossDefeated()
    safeLog(string.format("[HelmHub] Đã đấm Mini/Hidden Boss Instant-Win: %s [%s]", tostring(bossId), tostring(diff)))
    return true
end

-- ========================================================================
-- 7. CHU TRÌNH RIFTGATE TỪ XA (GIỮ NGUYÊN VỊ TRÍ 100%)
-- ========================================================================
local function executeRiftGateCycle()
    isRiftGateBusy = true
    safeLog("[HelmHub] Đang tham gia RiftGATE từ xa...")
    Notification("RiftGATE", "Đang tự động đánh RiftGATE từ xa...", 2)

    if riftGateEnterRemote then pcall(function() riftGateEnterRemote:FireServer() end) end
    task.wait(0.15)
    if buildRiftBattleRemote then pcall(function() buildRiftBattleRemote:InvokeServer(true) end) end
    if riftStartFightRemote then
        pcall(function()
            if riftStartFightRemote:IsA("RemoteEvent") then
                riftStartFightRemote:FireServer()
            else
                riftStartFightRemote:InvokeServer()
            end
        end)
    end
    if reportBattleDmgRemote then pcall(function() reportBattleDmgRemote:FireServer(999999, "dealt") end) end
    task.wait(0.2)

    if reportRiftVictoryRemote then pcall(function() reportRiftVictoryRemote:FireServer() end) end
    task.wait(0.15)
    if riftRewardRemote then pcall(function() riftRewardRemote:FireServer() end) end
    task.wait(0.15)
    if riftGateLeaveRemote then pcall(function() riftGateLeaveRemote:FireServer() end) end

    autoDismissBossDefeated()
    autoDismissFountain()

    hasFarmedCurrentRiftGate = true
    isRiftGateBusy = false
    safeLog("[HelmHub] Đã hoàn thành RiftGATE & nhận quà xong! Vị trí nhân vật bảo toàn 100%.")
    Notification("RiftGATE", "Đã nhận quà RiftGATE xong!", 3)
    return true
end

-- Điều kiện nhường đường
local function shouldYieldToRiftGate()
    if not _G.AutoRiftGate then return false end
    if _G.PriorityMode:find("Không Chờ") then return false end
    if hasFarmedCurrentRiftGate then return false end
    return isServerRiftGateOpen or isRiftGateBusy
end

local function shouldYieldToMainBoss()
    if not _G.AutoMainBoss then return false end
    if _G.PriorityMode:find("Không Chờ") then return false end
    return isMainBossFighting
end

-- ========================================================================
-- 7.1. CÁC HÀM THỰC THI PHÂN HỆ 1: DUNGEON, RAID BOSS & TRÙM GIỜ EYDIS
-- ========================================================================
local DUNGEON_STAGE_NAMES = {
    [1] = "Stage 01: Scorched Execution",
    [2] = "Stage 02: Toxic Collapse",
    [3] = "Stage 03: Broken Mind",
    [4] = "Stage 04: Blood Feast",
    [5] = "Stage 05: Absolute Despair"
}

local function parseDungeonStageNumber(stageInput)
    if typeof(stageInput) == "number" then return math.clamp(stageInput, 1, 5) end
    if typeof(stageInput) == "string" then
        local match = stageInput:match("(%d+)")
        if match then
            local n = tonumber(match)
            if n and n >= 1 and n <= 5 then return n end
        end
    end
    return nil -- Tự động cao nhất
end

local function getHighestUnlockedDungeonStage()
    local best = 1
    pcall(function()
        if getDungeonProgressRemote and getDungeonProgressRemote:IsA("RemoteFunction") then
            local prog = getDungeonProgressRemote:InvokeServer()
            if typeof(prog) == "number" and prog >= 1 and prog <= 5 then
                best = prog
            elseif typeof(prog) == "table" and prog.Stage then
                best = tonumber(prog.Stage) or 1
            end
        end
    end)
    return math.clamp(best, 1, 5)
end

local function executeDungeonStage(targetStage)
    if isDungeonBusy then return false end
    isDungeonBusy = true

    local stage = parseDungeonStageNumber(targetStage or _G.SelectedDungeonStage)
    if not stage then
        stage = getHighestUnlockedDungeonStage()
    end

    safeLog(string.format("[HelmHub] Đang khởi chạy Dungeon Stage %d (%s)...", stage, DUNGEON_STAGE_NAMES[stage] or "Gate"))

    -- 1. Kiểm tra Cooldown Dungeon nếu có
    local cd = 0
    pcall(function()
        if getDungeonCooldownRemote and getDungeonCooldownRemote:IsA("RemoteFunction") then
            cd = tonumber(getDungeonCooldownRemote:InvokeServer()) or 0
        end
    end)
    if cd > 0 then
        safeLog(string.format("[HelmHub] Dungeon đang Cooldown: %.1fs. Bỏ qua.", cd))
        isDungeonBusy = false
        return false, cd
    end

    -- 2. Gọi Remote StartDungeonStage
    if startDungeonStageRemote and startDungeonStageRemote:IsA("RemoteFunction") then
        pcall(function()
            startDungeonStageRemote:InvokeServer(stage)
        end)
    end

    -- 3. Click UI Enter nếu giao diện CardOriginsRift đang mở
    pcall(function()
        local pg = localPlayer:FindFirstChild("PlayerGui")
        local riftGui = pg and pg:FindFirstChild("CardOriginsRift")
        if riftGui and riftGui.Enabled then
            local enterBtn = riftGui:FindFirstChild("Enter", true)
            if enterBtn and enterBtn:IsA("GuiButton") and enterBtn.Visible then
                clickGuiElement(enterBtn)
            end
        end
    end)

    task.wait(0.5)

    -- 4. Tự động nhận thưởng nếu được bật
    if _G.AutoClaimDungeonReward then
        pcall(function()
            if claimDungeonRewardRemote and claimDungeonRewardRemote:IsA("RemoteFunction") then
                claimDungeonRewardRemote:InvokeServer()
            end
        end)
    end

    -- 5. Dọn màn hình chiến thắng CardOriginsRiftBattle nếu có
    task.wait(0.2)
    pcall(function()
        local pg = localPlayer:FindFirstChild("PlayerGui")
        local battleGui = pg and pg:FindFirstChild("CardOriginsRiftBattle")
        if battleGui and battleGui.Enabled then
            local shade = battleGui:FindFirstChild("Shade")
            if shade and shade:IsA("GuiButton") then
                clickGuiElement(shade)
            end
            local hint = battleGui:FindFirstChild("Hint", true)
            if hint and hint:IsA("GuiButton") then
                clickGuiElement(hint)
            end
        end
    end)

    isDungeonBusy = false
    safeLog(string.format("[HelmHub] Đã hoàn thành đợt càn quét Dungeon Stage %d!", stage))
    return true
end

local RAID_NODE_NAMES = {
    [1] = "Chapter 1: RETURN FROM DEATH",
    [2] = "Chapter 2: PRIDE MONSTER",
    [3] = "Chapter 3: Node 03",
    [4] = "Chapter 4: Node 04",
    [5] = "Chapter 5: Node 05"
}

local function parseRaidNodeNumber(nodeInput)
    if typeof(nodeInput) == "number" then return math.clamp(nodeInput, 1, 5) end
    if typeof(nodeInput) == "string" then
        local match = nodeInput:match("(%d+)")
        if match then
            local n = tonumber(match)
            if n and n >= 1 and n <= 5 then return n end
        end
    end
    return nil -- Quét hết
end

local function executeRaidBattle(targetNode)
    if isRaidBusy then return false end
    isRaidBusy = true

    local node = parseRaidNodeNumber(targetNode or _G.SelectedRaidNode)
    local nodesToRun = node and { node } or { 1, 2, 3, 4, 5 }

    for _, n in ipairs(nodesToRun) do
        if not _G.AutoRaidBoss and not targetNode then break end

        safeLog(string.format("[HelmHub] Đang tiến công Raid Node %d (%s)...", n, RAID_NODE_NAMES[n] or "Raid"))

        -- 1. Gọi Remote RaidStartBattle(n)
        if raidStartBattleRemote and raidStartBattleRemote:IsA("RemoteFunction") then
            pcall(function()
                raidStartBattleRemote:InvokeServer(n)
            end)
        end

        -- 2. Click nút trong UI RaidBossUI nếu có
        pcall(function()
            local pg = localPlayer:FindFirstChild("PlayerGui")
            local raidGui = pg and pg:FindFirstChild("RaidBossUI")
            if raidGui and raidGui.Enabled then
                local nodeBtn = raidGui:FindFirstChild("Node" .. tostring(n), true)
                if nodeBtn then
                    local btn = nodeBtn:FindFirstChild("Button") or nodeBtn:FindFirstChildWhichIsA("GuiButton", true)
                    if btn then clickGuiElement(btn) end
                end
                local enterBtn = raidGui:FindFirstChild("Enter", true)
                if enterBtn and enterBtn:IsA("GuiButton") and enterBtn.Visible then
                    clickGuiElement(enterBtn)
                end
            end
        end)

        task.wait(0.4)

        -- 3. Gửi báo cáo chiến thắng Raid: RaidReportResult(true) -> Nhận 3 Sao & Raid Souls!
        if raidReportResultRemote and raidReportResultRemote:IsA("RemoteFunction") then
            pcall(function()
                raidReportResultRemote:InvokeServer(true)
            end)
        end

        -- 4. Dọn banner RaidResultBanner
        task.wait(0.2)
        pcall(function()
            local pg = localPlayer:FindFirstChild("PlayerGui")
            local banner = pg and pg:FindFirstChild("RaidResultBanner")
            if banner and banner.Enabled then
                for _, b in ipairs(banner:GetDescendants()) do
                    if b:IsA("GuiButton") and b.Visible then
                        clickGuiElement(b)
                    end
                end
            end
        end)

        safeLog(string.format("[HelmHub] Đã hoàn thành hạ gục Raid Node %d (+Raid Soul / Stars)!", n))
        task.wait(0.3)
    end

    isRaidBusy = false
    return true
end

local function resolveEydisDiff(diffInput)
    if not diffInput then return "Normal", 1 end
    local str = tostring(diffInput):lower()
    if str:find("calamity") or str:find("gold") or str:find("2") then
        return "Gold", 2
    elseif str:find("umbral") or str:find("rainbow") or str:find("3") then
        return "Rainbow", 3
    elseif str:find("astral") or str:find("uni") or str:find("4") then
        return "Uni", 4
    elseif str:find("paradox") or str:find("5") then
        return "Astral", 5
    elseif str:find("origin") or str:find("6") then
        return "Origin", 6
    else
        return "Normal", 1
    end
end

local function executeEydisBattle(targetDiff, targetChallenge)
    if isEydisBusy then return false end
    isEydisBusy = true

    local diffName, diffIdx = resolveEydisDiff(targetDiff or _G.SelectedEydisDiff)
    local isChallenge = (targetChallenge ~= nil) and targetChallenge or _G.EydisChallengeMode or false

    safeLog(string.format("[HelmHub] Đang tiến công Trùm Giờ Eydis [%s - Tier %d, Challenge: %s]...", diffName, diffIdx, tostring(isChallenge)))

    -- 1. Kiểm tra Cooldown từ UI EydisBossGui (label BACK IN)
    local onCooldown = false
    pcall(function()
        local pg = localPlayer:FindFirstChild("PlayerGui")
        local eydisGui = pg and pg:FindFirstChild("EydisBossGui")
        if eydisGui and eydisGui.Enabled then
            for _, lbl in ipairs(eydisGui:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Text:find("BACK IN") then
                    onCooldown = true
                    safeLog("[HelmHub] Trùm Eydis đang Cooldown: " .. lbl.Text .. ". Bỏ qua.")
                    break
                end
            end
        end
    end)
    if onCooldown then
        isEydisBusy = false
        return false
    end

    -- 2. Chọn difficulty trong GUI nếu EydisBossGui mở
    pcall(function()
        local pg = localPlayer:FindFirstChild("PlayerGui")
        local eydisGui = pg and pg:FindFirstChild("EydisBossGui")
        if eydisGui and eydisGui.Enabled then
            local btn = eydisGui:FindFirstChild(diffName, true)
            if btn and btn:IsA("GuiButton") then
                clickGuiElement(btn)
            end
            local hitBtn = eydisGui:FindFirstChild("Hit", true)
            if hitBtn and hitBtn:IsA("GuiButton") and hitBtn.Visible then
                clickGuiElement(hitBtn)
            end
        end
    end)

    -- 3. Gọi Remote BuildEydisBattle(diff, isChallenge)
    if buildEydisBattleRemote and buildEydisBattleRemote:IsA("RemoteFunction") then
        pcall(function()
            buildEydisBattleRemote:InvokeServer(diffIdx, isChallenge)
        end)
        pcall(function()
            buildEydisBattleRemote:InvokeServer(diffName, isChallenge)
        end)
    end

    task.wait(0.4)

    -- 4. Báo cáo chiến thắng: ReportEydisVictory
    if reportEydisVictoryRemote and reportEydisVictoryRemote:IsA("RemoteEvent") then
        pcall(function()
            reportEydisVictoryRemote:FireServer(diffIdx)
        end)
        pcall(function()
            reportEydisVictoryRemote:FireServer(diffName)
        end)
    end

    -- 5. Dọn dẹp popup Eydis
    task.wait(0.2)
    autoDismissBossDefeated()

    isEydisBusy = false
    safeLog(string.format("[HelmHub] Đã hoàn thành săn Trùm Giờ Eydis [%s]!", diffName))
    return true
end

-- ========================================================================
-- 8. CÁC VÒNG LẶP NỀN (BACKGROUND LOOPS)
-- ========================================================================

-- Anti-AFK
task.spawn(function()
    localPlayer.Idled:Connect(function()
        if _G.AntiAFK then
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.05)
            vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end
    end)
end)

-- Chuẩn hóa danh sách Boss được chọn
local function getNormalizedSelectedBosses()
    local list = {}
    if typeof(_G.SelectedMainBosses) == "table" then
        for k, v in pairs(_G.SelectedMainBosses) do
            if typeof(k) == "number" and typeof(v) == "string" then
                table.insert(list, v)
            elseif typeof(k) == "string" and v == true then
                table.insert(list, k)
            elseif typeof(v) == "string" and v ~= "" then
                table.insert(list, v)
            end
        end
    elseif typeof(_G.SelectedMainBosses) == "string" and _G.SelectedMainBosses ~= "" then
        table.insert(list, _G.SelectedMainBosses)
    end
    if #list == 0 then
        list = { "The Shadow Monarch (queen)" }
    end
    return list
end

-- VÒNG LẶP AUTO BOSS CHÍNH
task.spawn(function()
    safeLog("[HelmHub] Vòng lặp Auto Boss Chính Instant-Win sẵn sàng!")
    while true do
        pcall(function()
            if _G.AutoMainBoss then
                while _G.AutoMainBoss and shouldYieldToRiftGate() do
                    task.wait(0.3)
                end
                if not _G.AutoMainBoss then return end

                local bossList = getNormalizedSelectedBosses()
                for _, bTitle in ipairs(bossList) do
                    if not _G.AutoMainBoss then break end
                    if shouldYieldToRiftGate() then break end

                    local bossId = resolveMainBossId(bTitle)
                    local diffDisplay = (_G.MainBossDifficulties and _G.MainBossDifficulties[bossId]) or _G.SelectedMainDifficulty or "01: NORMAL (Normal)"
                    local diffInternal = resolveDifficultyInternal(diffDisplay)

                    -- Chờ Mini Boss giải phóng slot 2 (tránh 2 trận cùng build vào 1 slot)
                    while isMiniBossBusy do task.wait(0.05) end

                    isMainBossFighting = true
                    executeBossVictory(bossId, diffInternal)
                    isMainBossFighting = false

                    local delayTime = tonumber(_G.BossDelay) or 0.3
                    task.wait(math.max(delayTime, 0.1))
                end
            end
        end)
        task.wait(0.2)
    end
end)

-- VÒNG LẶP AUTO MINI BOSS (VỚI TÙY CHỌN ĐỘ KHÓ)
task.spawn(function()
    safeLog("[HelmHub] Vòng lặp Auto Mini Boss Instant-Win với Độ Khó sẵn sàng!")
    while true do
        pcall(function()
            if _G.AutoMiniBoss and _G.SelectedMiniBosses and #_G.SelectedMiniBosses > 0 then
                for _, bossId in ipairs(_G.SelectedMiniBosses) do
                    if not _G.AutoMiniBoss then break end

                    while _G.AutoMiniBoss and (shouldYieldToRiftGate() or shouldYieldToMainBoss()) do
                        task.wait(0.2)
                    end
                    if not _G.AutoMiniBoss then break end

                    local diffDisplay = (_G.MiniBossDifficulties and _G.MiniBossDifficulties[bossId]) or _G.SelectedMiniDifficulty or "01: NORMAL (Normal)"
                    local diffInternal = resolveDifficultyInternal(diffDisplay)

                    -- Không bao giờ chạy song song với Trùm Cuối (dùng chung slot 2)
                    while isMainBossFighting do task.wait(0.05) end

                    isMiniBossBusy = true
                    executeMiniBossBattle(bossId, diffInternal)
                    isMiniBossBusy = false

                    local delay = tonumber(_G.BossDelay) or 0.3
                    task.wait(math.max(delay, 0.15))
                end
            end
        end)
        task.wait(0.2)
    end
end)

-- VÒNG LẶP AUTO ROLL THẺ BÀI (TIỆN ÍCH MỚI)
task.spawn(function()
    while true do
        pcall(function()
            if _G.AutoRoll then
                if rollRemote then
                    rollRemote:FireServer()
                end
            end
        end)
        task.wait(0.25)
    end
end)

-- VÒNG LẶP AUTO LEO THÁP (TOWER) - BẢO VỆ TUYỆT ĐỐI KHÔNG CAN THIỆP KHI ĐANG INFINITE
task.spawn(function()
    while true do
        pcall(function()
            if _G.AutoNextFloor then
                local pg = localPlayer:FindFirstChild("PlayerGui")
                local towerGui = pg and (pg:FindFirstChild("TowerGui") or pg:FindFirstChild("TowerSelectGui"))
                if towerGui and towerGui.Enabled and nextFloorRemote then
                    nextFloorRemote:InvokeServer()
                end
            end
        end)
        task.wait(1.5)
    end
end)

-- VÒNG LẶP ĐỒNG BỘ RIFTGATE (CHU KỲ 15 PHÚT)
local RiftStatusLabel, RiftTimerLabel
task.spawn(function()
    while true do
        pcall(function()
            local now = os.date("*t")
            local totalSec = (now.min * 60) + now.sec
            local secInCycle = totalSec % 900
            local secRemaining = 900 - secInCycle

            local isWindowOpen = isServerRiftGateOpen or (secInCycle >= 0 and secInCycle <= 120)

            if isWindowOpen then
                if hasFarmedCurrentRiftGate then
                    if RiftStatusLabel then RiftStatusLabel:Set("Trạng Thái: ĐÃ XONG ĐỢT NÀY (Chờ đợt sau)") end
                    if RiftTimerLabel then RiftTimerLabel:Set(string.format("Đợt Kế Tiếp Sau: %02d:%02d", math.floor(secRemaining / 60), secRemaining % 60)) end
                else
                    if RiftStatusLabel then RiftStatusLabel:Set("Trạng Thái: CỔNG ĐANG MỞ (Săn Thưởng!)") end
                    if RiftTimerLabel then RiftTimerLabel:Set(string.format("Đang Mở! Còn Lại: %02d:%02d", math.floor((120 - (secInCycle % 120)) / 60), (120 - (secInCycle % 120)) % 60)) end

                    if _G.AutoRiftGate and not isRiftGateBusy then
                        executeRiftGateCycle()
                    end
                end
            else
                hasFarmedCurrentRiftGate = false
                if RiftStatusLabel then RiftStatusLabel:Set("Trạng Thái: Đang Đóng (Chờ Mở)") end
                if RiftTimerLabel then RiftTimerLabel:Set(string.format("Đợt Kế Tiếp Sau: %02d:%02d", math.floor(secRemaining / 60), secRemaining % 60)) end
            end
        end)
        task.wait(1.0)
    end
end)

-- ========================================================================
-- PHÂN HỆ 1: VÒNG LẶP AUTO CÀN QUÉT DUNGEON (SOLO LEVELING GATE)
-- ========================================================================
local DungeonStatusLabel, RaidStatusLabel, EydisStatusLabel

task.spawn(function()
    safeLog("[HelmHub] Vòng lặp Auto Dungeon (Solo Leveling Gate) sẵn sàng!")
    while true do
        pcall(function()
            if _G.AutoDungeon then
                while _G.AutoDungeon and (shouldYieldToRiftGate() or isMainBossFighting) do
                    task.wait(0.4)
                end
                if not _G.AutoDungeon then return end

                local ok, cd = executeDungeonStage()
                if not ok and cd and cd > 0 then
                    task.wait(math.min(cd, 4))
                else
                    task.wait(1.2)
                end
            end
        end)
        task.wait(0.5)
    end
end)

-- ========================================================================
-- PHÂN HỆ 1: VÒNG LẶP AUTO SĂN RAID BOSS (RE:ZERO CHAPTER 1..3 / PRIDE MONSTER)
-- ========================================================================
task.spawn(function()
    safeLog("[HelmHub] Vòng lặp Auto Raid Boss (15 Sao & Raid Souls) sẵn sàng!")
    while true do
        pcall(function()
            if _G.AutoRaidBoss then
                while _G.AutoRaidBoss and (shouldYieldToRiftGate() or isMainBossFighting or isDungeonBusy) do
                    task.wait(0.5)
                end
                if not _G.AutoRaidBoss then return end

                executeRaidBattle()
                task.wait(1.5)
            end
        end)
        task.wait(1.0)
    end
end)

-- ========================================================================
-- PHÂN HỆ 1: VÒNG LẶP AUTO TRÙM GIỜ EYDIS (THE HOURLY EVOLUTION BOSS)
-- ========================================================================
task.spawn(function()
    safeLog("[HelmHub] Vòng lặp Auto Trùm Giờ Eydis sẵn sàng!")
    while true do
        pcall(function()
            if _G.AutoEydis then
                while _G.AutoEydis and (shouldYieldToRiftGate() or isMainBossFighting) do
                    task.wait(0.5)
                end
                if not _G.AutoEydis then return end

                executeEydisBattle()
                task.wait(3.0)
            end
        end)
        task.wait(2.0)
    end
end)

-- VÒNG LẶP CẬP NHẬT TRẠNG THÁI REALTIME CHO PHÂN HỆ 1
task.spawn(function()
    while true do
        task.wait(1.5)
        pcall(function()
            -- 1. Dungeon Status
            if DungeonStatusLabel then
                local cd = 0
                if getDungeonCooldownRemote and getDungeonCooldownRemote:IsA("RemoteFunction") then
                    pcall(function() cd = tonumber(getDungeonCooldownRemote:InvokeServer()) or 0 end)
                end
                if cd > 0 then
                    DungeonStatusLabel:Set(string.format("Trạng Thái: Cooldown (%.1fs)", cd))
                else
                    DungeonStatusLabel:Set("Trạng Thái: Cổng Sẵn Sàng (Ready)!")
                end
            end

            -- 2. Raid Status
            if RaidStatusLabel then
                local pg = localPlayer:FindFirstChild("PlayerGui")
                local raidGui = pg and pg:FindFirstChild("RaidBossUI")
                if raidGui and raidGui.Enabled then
                    local starsText = ""
                    local soulsText = ""
                    for _, lbl in ipairs(raidGui:GetDescendants()) do
                        if lbl:IsA("TextLabel") and lbl.Text:find("/") and lbl.Text:find("15") then
                            starsText = lbl.Text
                        end
                        if lbl.Name == "Currency" then
                            local sub = lbl:FindFirstChildWhichIsA("TextLabel")
                            if sub then soulsText = sub.Text end
                        end
                    end
                    if starsText ~= "" then
                        RaidStatusLabel:Set(string.format("Raid Sao: %s | Raid Soul: %s", starsText, soulsText ~= "" and soulsText or "0"))
                    end
                end
            end

            -- 3. Eydis Status
            if EydisStatusLabel then
                local pg = localPlayer:FindFirstChild("PlayerGui")
                local eydisGui = pg and pg:FindFirstChild("EydisBossGui")
                if eydisGui and eydisGui.Enabled then
                    for _, lbl in ipairs(eydisGui:GetDescendants()) do
                        if lbl:IsA("TextLabel") and lbl.Text:find("Next in") then
                            EydisStatusLabel:Set("Xoay Trùm Mới: " .. lbl.Text)
                            break
                        elseif lbl:IsA("TextLabel") and lbl.Text:find("BACK IN") then
                            EydisStatusLabel:Set("Hồi Chiêu: " .. lbl.Text)
                            break
                        end
                    end
                end
            end
        end)
    end
end)

-- ========================================================================
-- 9. GIAO DIỆN ĐIỀU KHIỂN (UI INTERFACE - INVENTORY.LUA)
-- ========================================================================
local Window = library:CreateWindow("HelmHub | Card Origins")
local uiFullyLoaded = false

local function setMenuVisible(visible)
    pcall(function()
        if Window and Window.Frame then
            Window.Frame.Visible = visible
        end
        local containers = {}
        if gethui then pcall(function() table.insert(containers, gethui()) end) end
        pcall(function() table.insert(containers, game:GetService("CoreGui")) end)
        if localPlayer and localPlayer:FindFirstChild("PlayerGui") then
            table.insert(containers, localPlayer.PlayerGui)
        end
        for _, c in ipairs(containers) do
            for _, v in pairs(c:GetChildren()) do
                local m = v:FindFirstChild("main")
                if m then
                    m.Visible = visible
                end
            end
        end
    end)
end

-- ------------------------------------------------------------------------
-- TAB 1: SĂN BOSS (AUTO BOSS & MAP)
-- ------------------------------------------------------------------------
local TabBoss = Window:CreateTab("Săn Boss")
local SecBossLeft = TabBoss:CreateSector("1. Boss Thường & Boss Ẩn Theo World", "left")
local SecBossRight = TabBoss:CreateSector("2. Boss Chính (Trùm Cuối)", "right")

local MiniBossDropdownItem
local MainBossDropdownItem

-- Cột Trái: Boss Thường & Boss Ẩn
SecBossLeft:AddDropdown("Chọn World / Khu Vực", MapOptions, _G.SelectedMap, false, function(v)
    _G.SelectedMap = v
    if not uiFullyLoaded then return end
    local cfg = GAME_WORLDS[v]
    if cfg then
        if cfg.miniBosses and #cfg.miniBosses > 0 then
            local bossList = {}
            for _, b in ipairs(cfg.miniBosses) do table.insert(bossList, b.id) end
            _G.SelectedMiniBosses = bossList
            if MiniBossDropdownItem and MiniBossDropdownItem.Set then
                MiniBossDropdownItem:Set(bossList)
            end
        end
        if cfg.mainBoss and MainBossDropdownItem and MainBossDropdownItem.Set then
            local title = string.format("%s (%s)", cfg.mainBoss.name, cfg.mainBoss.id)
            _G.SelectedMainBosses = { title }
            MainBossDropdownItem:Set({ title })
        end
    end
    saveConfig()
end)

SecBossLeft:AddButton("Teleport Vào Map World Này", function()
    local cfg = GAME_WORLDS[_G.SelectedMap]
    if cfg and cfg.mapId and cfg.mapId ~= "hidden" then
        teleportToWorld(cfg.mapId)
    else
        Notification("Teleport", "Khu vực này nằm ngay trên map hiện tại!", 2)
    end
end)

MiniBossDropdownItem = SecBossLeft:AddDropdown("Chọn Mini Boss (Chọn Nhiều)", ALL_MINI_BOSS_LIST, _G.SelectedMiniBosses, true, function(selected)
    if typeof(selected) == "table" then
        _G.SelectedMiniBosses = selected
    elseif typeof(selected) == "string" then
        _G.SelectedMiniBosses = { selected }
    end
    if uiFullyLoaded then saveConfig() end
end)

SecBossLeft:AddButton("Chọn Toàn Bộ Boss Trong World Đang Chọn", function()
    local cfg = GAME_WORLDS[_G.SelectedMap]
    if cfg and cfg.miniBosses and #cfg.miniBosses > 0 then
        local bossList = {}
        for _, b in ipairs(cfg.miniBosses) do table.insert(bossList, b.id) end
        _G.SelectedMiniBosses = bossList
        if MiniBossDropdownItem and MiniBossDropdownItem.Set then
            MiniBossDropdownItem:Set(bossList)
        end
        saveConfig()
        Notification("Mini Boss", string.format("Đã chọn %d Boss trong world này!", #bossList), 3)
    end
end)

SecBossLeft:AddButton("Chọn Toàn Bộ Mini Boss Thường (W2 - W7)", function()
    local standardAll = { "chahaein", "guildmaster", "ragna", "sukuna", "yuta", "swordempress", "yuno", "boothill", "jingliu", "hsr_mini3" }
    _G.SelectedMiniBosses = standardAll
    if MiniBossDropdownItem and MiniBossDropdownItem.Set then
        MiniBossDropdownItem:Set(standardAll)
    end
    saveConfig()
    Notification("Mini Boss", "Đã chọn toàn bộ Mini Boss Thường (W2 - W7)!", 3)
end)

SecBossLeft:AddButton("Chọn Toàn Bộ 5 Boss Ẩn (Hidden Bosses)", function()
    local hidden5 = { "hidden boss 1", "hidden boss 2", "hidden boss 3", "hidden boss 4", "hidden boss 5" }
    _G.SelectedMiniBosses = hidden5
    if MiniBossDropdownItem and MiniBossDropdownItem.Set then
        MiniBossDropdownItem:Set(hidden5)
    end
    saveConfig()
    Notification("Boss Ẩn", "Đã chọn toàn bộ 5 Boss Ẩn!", 3)
end)

SecBossLeft:AddDropdown("Độ Khó Chung Cho Mini Boss", MAIN_BOSS_DIFFICULTIES, _G.SelectedMiniDifficulty, false, function(v)
    _G.SelectedMiniDifficulty = v
    if uiFullyLoaded then saveConfig() end
    Notification("Độ Khó Mini Boss", "Đã đặt độ khó chung Mini Boss: " .. tostring(v), 2)
end)

SecBossLeft:AddLabel("--- TÙY CHỈNH ĐỘ KHÓ MINI BOSS (THEO WORLD) ---")

-- World 02 (Dungeon)
SecBossLeft:AddDropdown("[W2] Cha Hae-In", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["chahaein"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["chahaein"] = v
    if uiFullyLoaded then saveConfig() end
end)
SecBossLeft:AddDropdown("[W2] Guild Master", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["guildmaster"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["guildmaster"] = v
    if uiFullyLoaded then saveConfig() end
end)

-- World 03 (Endless Castle)
SecBossLeft:AddDropdown("[W3] Ragna", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["ragna"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["ragna"] = v
    if uiFullyLoaded then saveConfig() end
end)

-- World 04 (Limitless Domain)
SecBossLeft:AddDropdown("[W4] Sukuna (Cursed King)", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["sukuna"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["sukuna"] = v
    if uiFullyLoaded then saveConfig() end
end)
SecBossLeft:AddDropdown("[W4] Yuta Okkotsu", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["yuta"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["yuta"] = v
    if uiFullyLoaded then saveConfig() end
end)

-- World 05 (Devil Heart - Clockmaiden Kurumi)
SecBossLeft:AddDropdown("[W5] Sword Empress", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["swordempress"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["swordempress"] = v
    if uiFullyLoaded then saveConfig() end
end)
SecBossLeft:AddDropdown("[W5] Yuno", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["yuno"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["yuno"] = v
    if uiFullyLoaded then saveConfig() end
end)

-- World 07 (Celestial Express - 3 Mini Boss)
SecBossLeft:AddDropdown("[W7] Cyborg Gunslinger (Boothill)", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["boothill"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["boothill"] = v
    if uiFullyLoaded then saveConfig() end
end)
SecBossLeft:AddDropdown("[W7] Sword Champion (Jingliu)", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["jingliu"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["jingliu"] = v
    if uiFullyLoaded then saveConfig() end
end)
SecBossLeft:AddDropdown("[W7] Mini Boss 3 (Celestial Express)", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["hsr_mini3"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["hsr_mini3"] = v
    if uiFullyLoaded then saveConfig() end
end)

SecBossLeft:AddLabel("--- TÙY CHỈNH ĐỘ KHÓ 5 BOSS ẨN ---")
SecBossLeft:AddDropdown("[ẨN 1] Hidden Boss 1", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["hidden boss 1"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["hidden boss 1"] = v
    if uiFullyLoaded then saveConfig() end
end)
SecBossLeft:AddDropdown("[ẨN 2] Hidden Boss 2", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["hidden boss 2"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["hidden boss 2"] = v
    if uiFullyLoaded then saveConfig() end
end)
SecBossLeft:AddDropdown("[ẨN 3] Hidden Boss 3 (Lord Boros)", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["hidden boss 3"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["hidden boss 3"] = v
    if uiFullyLoaded then saveConfig() end
end)
SecBossLeft:AddDropdown("[ẨN 4] Hidden Boss 4", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["hidden boss 4"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["hidden boss 4"] = v
    if uiFullyLoaded then saveConfig() end
end)
SecBossLeft:AddDropdown("[ẨN 5] Hidden Boss 5", MAIN_BOSS_DIFFICULTIES, _G.MiniBossDifficulties["hidden boss 5"] or "01: NORMAL (Normal)", false, function(v)
    _G.MiniBossDifficulties["hidden boss 5"] = v
    if uiFullyLoaded then saveConfig() end
end)

SecBossLeft:AddLabel("--- TELEPORT TỚI 5 BOSS ẨN TRÊN MAP ---")
SecBossLeft:AddButton("Bay Tới Hidden Boss 1", function() teleportToMiniBoss("hidden boss 1") end)
SecBossLeft:AddButton("Bay Tới Hidden Boss 2", function() teleportToMiniBoss("hidden boss 2") end)
SecBossLeft:AddButton("Bay Tới Hidden Boss 3 (Lord Boros)", function() teleportToMiniBoss("hidden boss 3") end)
SecBossLeft:AddButton("Bay Tới Hidden Boss 4", function() teleportToMiniBoss("hidden boss 4") end)
SecBossLeft:AddButton("Bay Tới Hidden Boss 5", function() teleportToMiniBoss("hidden boss 5") end)

SecBossLeft:AddToggle("Auto Đấm Mini Boss & Boss Ẩn (Instant-Win)", _G.AutoMiniBoss, function(v)
    _G.AutoMiniBoss = v
    if not v then resetServerAutoBossFlag() end
    if uiFullyLoaded then saveConfig() end
    Notification("Mini Boss", v and "Đã BẬT Auto Mini Boss Instant-Win!" or "Đã TẮT!", 2)
end)

-- Cột Phải: Trùm Cuối
MainBossDropdownItem = SecBossRight:AddDropdown("Chọn Trùm Cuối (Chọn Nhiều)", ALL_MAIN_BOSS_LIST, _G.SelectedMainBosses, true, function(selected)
    if typeof(selected) == "table" then
        _G.SelectedMainBosses = selected
    elseif typeof(selected) == "string" then
        _G.SelectedMainBosses = { selected }
    end
    if uiFullyLoaded then saveConfig() end
end)

SecBossRight:AddButton("Chọn Toàn Bộ Trùm Cuối", function()
    _G.SelectedMainBosses = ALL_MAIN_BOSS_LIST
    if MainBossDropdownItem and MainBossDropdownItem.Set then
        MainBossDropdownItem:Set(ALL_MAIN_BOSS_LIST)
    end
    saveConfig()
    Notification("Trùm Cuối", "Đã chọn toàn bộ Trùm Cuối!", 3)
end)

SecBossRight:AddLabel("--- TÙY CHỈNH ĐỘ KHÓ TỪNG TRÙM CUỐI ---")

SecBossRight:AddDropdown("Độ Khó Queen (The Shadow Monarch)", MAIN_BOSS_DIFFICULTIES, _G.MainBossDifficulties["queen"] or "04: ASTRAL (Uni)", false, function(v)
    _G.MainBossDifficulties["queen"] = v
    if uiFullyLoaded then saveConfig() end
    Notification("Độ Khó Queen", "Đã đặt độ khó Queen: " .. tostring(v), 2)
end)

SecBossRight:AddDropdown("Độ Khó Gojo (The Honored One)", MAIN_BOSS_DIFFICULTIES, _G.MainBossDifficulties["gojo"] or "02: CALAMITY (Gold)", false, function(v)
    _G.MainBossDifficulties["gojo"] = v
    if uiFullyLoaded then saveConfig() end
    Notification("Độ Khó Gojo", "Đã đặt độ khó Gojo: " .. tostring(v), 2)
end)

SecBossRight:AddDropdown("Độ Khó Kurumi (Clockmaiden)", MAIN_BOSS_DIFFICULTIES, _G.MainBossDifficulties["kurumi"] or "03: UMBRAL (Rainbow)", false, function(v)
    _G.MainBossDifficulties["kurumi"] = v
    if uiFullyLoaded then saveConfig() end
    Notification("Độ Khó Kurumi", "Đã đặt độ khó Kurumi: " .. tostring(v), 2)
end)

SecBossRight:AddDropdown("Độ Khó [W7] Love of Remembrance (ishtar)", MAIN_BOSS_DIFFICULTIES, _G.MainBossDifficulties["ishtar"] or "01: NORMAL (Normal)", false, function(v)
    _G.MainBossDifficulties["ishtar"] = v
    if uiFullyLoaded then saveConfig() end
    Notification("Độ Khó Boss", "Đã đặt độ khó Love of Remembrance: " .. tostring(v), 2)
end)

local PRIORITY_OPTIONS = {
    "RiftGate > Boss Chính > Boss Mini (Mặc Định)",
    "Boss Chính > RiftGate > Boss Mini",
    "Tự Do (Không Chờ Nhau)"
}

SecBossRight:AddDropdown("Độ Ưu Tiên Farm", PRIORITY_OPTIONS, _G.PriorityMode, false, function(v)
    _G.PriorityMode = v
    if uiFullyLoaded then saveConfig() end
end)

SecBossRight:AddSlider("Nghỉ Giữa Các Trận (Giây)", 0.1, 0.3, 3.0, 0.1, function(v)
    _G.BossDelay = tonumber(v) or 0.3
    if uiFullyLoaded then saveConfig() end
end)

SecBossRight:AddToggle("Auto Đấm Boss Chính (Instant-Win)", _G.AutoMainBoss, function(v)
    _G.AutoMainBoss = v
    if not v then
        resetServerAutoBossFlag()
    end
    if uiFullyLoaded then saveConfig() end
    Notification("Boss Chính", v and "Đã BẬT Auto Trùm Cuối (Instant-Win Siêu Tốc)!" or "Đã TẮT!", 3)
end)

-- ------------------------------------------------------------------------
-- TAB 2: PHÓ BẢN & SỰ KIỆN (DUNGEON, RAID BOSS & EYDIS HOURLY)
-- ------------------------------------------------------------------------
local TabDungeonRaid = Window:CreateTab("Phó Bản & Raid")
local SecDungeon = TabDungeonRaid:CreateSector("1. Cổng Phó Bản Dungeon (Solo Leveling)", "left")
local SecRaid = TabDungeonRaid:CreateSector("2. Săn Raid Boss (Re:Zero) & Trùm Giờ Eydis", "right")

-- 1. CỘT TRÁI: AUTO DUNGEON
DungeonStatusLabel = SecDungeon:AddLabel("Trạng Thái: ĐANG ĐỒNG BỘ...", true)
SecDungeon:AddLabel("Mỗi ải nhận Origin Souls & Thẻ Bài Độc Quyền")

SecDungeon:AddToggle("Auto Càn Quét Dungeon (Auto Gate)", _G.AutoDungeon, function(v)
    _G.AutoDungeon = v
    if uiFullyLoaded then saveConfig() end
    Notification("Dungeon", v and "Đã BẬT Auto càn quét Dungeon!" or "Đã TẮT Auto Dungeon!", 2)
end)

local DUNGEON_STAGE_OPTIONS = {
    "Tự Động (Stage Cao Nhất)",
    "Stage 01: Scorched Execution",
    "Stage 02: Toxic Collapse",
    "Stage 03: Broken Mind",
    "Stage 04: Blood Feast",
    "Stage 05: Absolute Despair"
}

SecDungeon:AddDropdown("Chọn Stage Thử Thách", DUNGEON_STAGE_OPTIONS, _G.SelectedDungeonStage, false, function(v)
    _G.SelectedDungeonStage = v
    if uiFullyLoaded then saveConfig() end
    Notification("Dungeon", "Đã chọn: " .. tostring(v), 2)
end)

SecDungeon:AddToggle("Tự Động Nhận Quà (Auto Claim)", _G.AutoClaimDungeonReward, function(v)
    _G.AutoClaimDungeonReward = v
    if uiFullyLoaded then saveConfig() end
end)

SecDungeon:AddButton("Đánh Thử 1 Trận Stage Đã Chọn", function()
    task.spawn(function()
        Notification("Dungeon", "Đang thử chiến đấu Dungeon Stage...", 2)
        local ok = executeDungeonStage()
        Notification("Dungeon", "Kết quả: " .. (ok and "Thành công!" or "Đang hồi chiêu / Thất bại"), 3)
    end)
end)

SecDungeon:AddButton("Nhận Thưởng Dungeon Ngay (Claim Reward)", function()
    pcall(function()
        if claimDungeonRewardRemote and claimDungeonRewardRemote:IsA("RemoteFunction") then
            claimDungeonRewardRemote:InvokeServer()
            Notification("Dungeon", "Đã gửi lệnh nhận thưởng Dungeon!", 2)
        end
    end)
end)

SecDungeon:AddButton("Mở Giao Diện Cổng Dungeon (Open UI)", function()
    pcall(function()
        if openDungeonUIRemote then
            openDungeonUIRemote:FireServer()
        end
    end)
end)

-- 2. CỘT PHẢI: AUTO RAID BOSS & TRÙM GIỜ EYDIS
RaidStatusLabel = SecRaid:AddLabel("Raid Boss: 15/15 Sao • Raid Soul", true)

SecRaid:AddToggle("Auto Săn Raid Boss (Auto Win 3 Sao)", _G.AutoRaidBoss, function(v)
    _G.AutoRaidBoss = v
    if uiFullyLoaded then saveConfig() end
    Notification("Raid Boss", v and "Đã BẬT Auto Săn Raid Boss!" or "Đã TẮT!", 2)
end)

local RAID_NODE_OPTIONS = {
    "Tự Động Quét Hết (Node 1 -> 5)",
    "Node 01: RETURN FROM DEATH",
    "Node 02: PRIDE MONSTER",
    "Node 03: Chapter Node 03",
    "Node 04: Chapter Node 04",
    "Node 05: Chapter Node 05"
}

SecRaid:AddDropdown("Chọn Node Raid Thử Thách", RAID_NODE_OPTIONS, _G.SelectedRaidNode, false, function(v)
    _G.SelectedRaidNode = v
    if uiFullyLoaded then saveConfig() end
    Notification("Raid Boss", "Đã chọn Node: " .. tostring(v), 2)
end)

SecRaid:AddButton("Đánh Thắng Ngay Node Đã Chọn", function()
    task.spawn(function()
        Notification("Raid Boss", "Đang gửi báo cáo thắng trận Raid...", 2)
        local ok = executeRaidBattle()
        Notification("Raid Boss", "Đã càn quét Raid xong!", 3)
    end)
end)

SecRaid:AddButton("Mở Giao Diện Raid (Open UI)", function()
    pcall(function()
        if openRaidUIRemote then
            openRaidUIRemote:FireServer()
        end
    end)
end)

SecRaid:AddLabel("----------------------------------------")
EydisStatusLabel = SecRaid:AddLabel("Trùm Giờ Eydis: ĐANG ĐỒNG BỘ...", true)

SecRaid:AddToggle("Auto Săn Trùm Giờ Eydis (Tự Đánh Khi Hồi)", _G.AutoEydis, function(v)
    _G.AutoEydis = v
    if uiFullyLoaded then saveConfig() end
    Notification("Trùm Giờ Eydis", v and "Đã BẬT Auto săn Trùm Giờ Eydis!" or "Đã TẮT!", 2)
end)

local EYDIS_DIFF_OPTIONS = {
    "Normal (Tier 1 - Cơ Bản)",
    "Calamity / Gold (Tier 2)",
    "Umbral / Rainbow (Tier 3)",
    "Astral / Uni (Tier 4)",
    "Paradox (Tier 5)",
    "Origin (Tier 6 - Tối Thượng)"
}

SecRaid:AddDropdown("Chọn Độ Khó Trùm Giờ", EYDIS_DIFF_OPTIONS, _G.SelectedEydisDiff, false, function(v)
    _G.SelectedEydisDiff = v
    if uiFullyLoaded then saveConfig() end
    Notification("Trùm Giờ Eydis", "Đã đặt độ khó: " .. tostring(v), 2)
end)

SecRaid:AddToggle("Chế Độ Challenge (Thử Thách)", _G.EydisChallengeMode, function(v)
    _G.EydisChallengeMode = v
    if uiFullyLoaded then saveConfig() end
end)

SecRaid:AddButton("Đánh Thắng Trùm Eydis Ngay (Instant Win)", function()
    task.spawn(function()
        Notification("Trùm Giờ Eydis", "Đang gửi lệnh hạ gục Eydis...", 2)
        local ok = executeEydisBattle()
        Notification("Trùm Giờ Eydis", ok and "Đã thắng trận Trùm Eydis!" or "Trùm đang hồi chiêu / Không thành công", 3)
    end)
end)

SecRaid:AddButton("Mở Giao Diện Trùm Eydis (Open UI)", function()
    pcall(function()
        if openEydisBattleRemote then
            openEydisBattleRemote:FireServer()
        end
    end)
end)

-- ------------------------------------------------------------------------
-- TAB 3: RiftGATE (CHU KỲ 15 PHÚT)
-- ------------------------------------------------------------------------
local TabRift = Window:CreateTab("RiftGATE")
local SecRiftLeft = TabRift:CreateSector("1. Đếm Ngược & Trạng Thái Cổng", "left")
local SecRiftRight = TabRift:CreateSector("2. Tự Động & Tiện Ích RiftGATE", "right")

RiftStatusLabel = SecRiftLeft:AddLabel("Trạng Thái: ĐANG ĐỒNG BỘ GIỜ...", true)
RiftTimerLabel = SecRiftLeft:AddLabel("Đợt Kế Tiếp: xx:-- | Còn Lại: --:--")
SecRiftLeft:AddLabel("Các Mốc Giờ: xx:00 | xx:15 | xx:30 | xx:45")

SecRiftLeft:AddToggle("Báo Chuông Khi Cổng Mở", _G.RiftNotify, function(v)
    _G.RiftNotify = v
    if uiFullyLoaded then saveConfig() end
end)

SecRiftLeft:AddToggle("Tự Động Săn RiftGATE (Auto Join)", _G.AutoRiftGate, function(v)
    _G.AutoRiftGate = v
    if not v then hasFarmedCurrentRiftGate = false end
    if uiFullyLoaded then saveConfig() end
    Notification("RiftGATE", v and "Đã BẬT Auto tham gia RiftGATE khi cổng mở!" or "Đã TẮT Auto RiftGATE!", 2)
end)

SecRiftRight:AddButton("Đánh Thử 1 Trận RiftGATE", function()
    task.spawn(function()
        Notification("RiftGATE", "Đang thử chạy chu trình đấm RiftGATE...", 2)
        local ok = executeRiftGateCycle()
        Notification("RiftGATE", "Kết quả: " .. tostring(ok), 3)
    end)
end)

SecRiftRight:AddButton("Teleport Về Lobby (Sảnh)", function()
    teleportToWorld("lobby")
end)

-- ------------------------------------------------------------------------
-- TAB 4: TIỆN ÍCH & GACHA / AUTO ROLL (TAB MỚI)
-- ------------------------------------------------------------------------
local TabUtil = Window:CreateTab("Tiện Ích & Roll")
local SecUtilLeft = TabUtil:CreateSector("Quay Thẻ Tự Động (Auto Roll)", "left")
local SecUtilRight = TabUtil:CreateSector("Tháp Vô Tận & BattlePass", "right")

SecUtilLeft:AddToggle("Auto Roll Thẻ Bài (Từ Xa)", _G.AutoRoll, function(v)
    _G.AutoRoll = v
    if uiFullyLoaded then saveConfig() end
    Notification("Auto Roll", v and "Đã BẬT Auto Roll thẻ bài!" or "Đã TẮT Auto Roll!", 2)
end)

SecUtilLeft:AddButton("Quay Thử 1 Thẻ (Roll Request)", function()
    if rollRemote then
        rollRemote:FireServer()
        Notification("Roll", "Đã gửi RollRequest!", 2)
    end
end)

SecUtilRight:AddToggle("Auto Tự Động Leo Tháp (Next Floor)", _G.AutoNextFloor, function(v)
    _G.AutoNextFloor = v
    if uiFullyLoaded then saveConfig() end
    Notification("Tháp Vô Tận", v and "Đã BẬT Auto Next Floor!" or "Đã TẮT!", 2)
end)

SecUtilRight:AddButton("Nhận Toàn Bộ Quà BattlePass", function()
    if claimAllBattlePassRemote then
        pcall(function() claimAllBattlePassRemote:InvokeServer() end)
        Notification("BattlePass", "Đã gửi lệnh ClaimAllBattlePass!", 3)
    end
end)

-- ------------------------------------------------------------------------
-- TAB 5: CÀI ĐẶT (SETTINGS)
-- ------------------------------------------------------------------------
local TabSettings = Window:CreateTab("Cài Đặt")
local SecSetLeft = TabSettings:CreateSector("Tối Ưu Treo Máy", "left")
local SecSetRight = TabSettings:CreateSector("Hệ Thống & Giao Diện", "right")

SecSetLeft:AddToggle("Chống Văng (Anti-AFK)", _G.AntiAFK, function(v)
    _G.AntiAFK = v
    if uiFullyLoaded then saveConfig() end
end)

SecSetLeft:AddToggle("Ẩn Nhật Ký Console (Tối Ưu FPS)", _G.DisableConsoleLogs, function(v)
    _G.DisableConsoleLogs = v
    if uiFullyLoaded then saveConfig() end
    Notification("Console Logs", v and "Đã ẨN log Console!" or "Đã BẬT log Console!", 2)
end)

SecSetLeft:AddToggle("Màn Hình Trắng Giảm CPU (WhiteScreen)", _G.WhiteScreen, function(v)
    _G.WhiteScreen = v
    RunService:Set3dRenderingEnabled(not v)
    if uiFullyLoaded then saveConfig() end
    Notification("Màn Hình", v and "Đã BẬT màn hình trắng!" or "Đã TẮT màn hình trắng!", 2)
end)

SecSetLeft:AddToggle("Giảm Lag Đồ Họa (FPS Boost)", _G.FPSBoost, function(v)
    _G.FPSBoost = v
    if v then
        pcall(function()
            settings().Rendering.QualityLevel = 1
            for _, item in ipairs(workspace:GetDescendants()) do
                if item:IsA("BasePart") and not item.Parent:FindFirstChild("Humanoid") then
                    item.Material = Enum.Material.SmoothPlastic
                elseif item:IsA("Decal") or item:IsA("Texture") then
                    item.Transparency = 1
                elseif item:IsA("ParticleEmitter") or item:IsA("Trail") then
                    item.Enabled = false
                end
            end
        end)
    end
    if uiFullyLoaded then saveConfig() end
    Notification("FPS Boost", v and "Đã kích hoạt FPS Boost!" or "Đã tắt!", 2)
end)

SecSetLeft:AddToggle("Bật Chỉnh Tốc Độ Di Chuyển", _G.WalkSpeedEnabled, function(v)
    _G.WalkSpeedEnabled = v
    pcall(function()
        if localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid") then
            localPlayer.Character.Humanoid.WalkSpeed = v and (_G.WalkSpeedValue or 16) or 16
        end
    end)
    if uiFullyLoaded then saveConfig() end
end)

SecSetLeft:AddSlider("Tốc Độ (WalkSpeed)", 16, 16, 200, 1, function(v)
    if typeof(v) == "number" and v > 0 then
        _G.WalkSpeedValue = math.floor(v)
        if _G.WalkSpeedEnabled then
            pcall(function()
                if localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid") then
                    localPlayer.Character.Humanoid.WalkSpeed = _G.WalkSpeedValue
                end
            end)
        end
        if uiFullyLoaded then saveConfig() end
    end
end)

SecSetRight:AddButton("Vào Lại Server (Rejoin)", function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
end)

SecSetRight:AddButton("Đổi Server (Server Hop)", function()
    local success, res = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if success and res and res.data then
        for _, server in ipairs(res.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, localPlayer)
                break
            end
        end
    else
        Notification("Server Hop", "Không thể lấy danh sách Server!", 3)
    end
end)

SecSetRight:AddToggle("Ẩn Menu Khi Khởi Động", _G.HideMenuOnStartup, function(v)
    _G.HideMenuOnStartup = v
    if uiFullyLoaded then saveConfig() end
    Notification("Cài Đặt", v and "Đã BẬT: Menu sẽ tự ẩn khi vừa chạy script (Bấm [Insert] để mở lại)!" or "Đã TẮT!", 3)
end)

SecSetRight:AddButton("Ẩn Menu Ngay (Phím Insert)", function()
    local isVis = false
    if Window and Window.Frame then
        isVis = Window.Frame.Visible
    end
    setMenuVisible(not isVis)
    Notification("Giao Diện", isVis and "Đã ẩn menu! Bấm [Insert] để mở lại." or "Đã hiện menu!", 2)
end)

SecSetRight:AddButton("Lưu Cấu Hình (Save Config)", function()
    saveConfig()
    Notification("Cấu Hình", "Đã lưu cài đặt CardOrigins thành công!", 2)
end)

SecSetRight:AddButton("Tải Cấu Hình (Load Config)", function()
    loadConfig()
    if not GAME_WORLDS[_G.SelectedMap] then
        _G.SelectedMap = "World 02: DUNGEON (Shadow Realm - queen)"
    end
    Notification("Cấu Hình", "Đã nạp cài đặt đã lưu thành công!", 2)
end)

-- Phím tắt Insert để ẩn/hiện menu
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Insert then
        local isVis = false
        if Window and Window.Frame then
            isVis = Window.Frame.Visible
        end
        setMenuVisible(not isVis)
    end
end)

uiFullyLoaded = true
saveConfig()

if _G.HideMenuOnStartup then
    task.spawn(function()
        task.wait(0.3)
        setMenuVisible(false)
        Notification("HelmHub", "Menu đã tự động ẩn khi khởi động! Bấm [Insert] để mở lại.", 3)
    end)
end

Notification("HelmHub", "Card Origins Instant-Win & Hidden Boss Edition đã sẵn sàng!", 4)
