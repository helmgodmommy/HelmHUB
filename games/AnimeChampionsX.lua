-- HelmHub | Anime Champions X v1.8
-- Place: Anime Champions X [RUNS] (PlaceId 79755351995296, UniverseId 10778033190)
-- Nguồn dữ liệu: dump Anime Champions X PlaceVersion 4. Hằng số dự phòng nằm trong bảng Known và được đọc lại
-- từ ReplicatedStorage.Config.* / ReplicatedStorage.Shared.* bất đồng bộ sau khi dựng UI qua SafeRequire + EnsureHighIdentity.
-- Trạng thái: đã xử lý triệt để lỗi hạ thread identity (lacking capability Plugin), giới hạn 200 biến local của Luau (tách stack frame IIFE), dựng UI tức thì không chờ SafeRequire, tối ưu hiệu năng (Remote/ECS/Store/UI Cache) và nâng cấp toàn diện theo Logic/Rules của game.

local SCRIPT_VERSION = "1.8"

local env = (typeof(getgenv) == "function" and getgenv()) or _G
if env.__HelmACXCleanup and typeof(env.__HelmACXCleanup) == "function" then
    pcall(env.__HelmACXCleanup)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local Running = true
local Connections = {}

local function TrackConnection(conn)
    if conn then
        table.insert(Connections, conn)
    end
    return conn
end

local _getIdentity = (typeof(getthreadidentity) == "function" and getthreadidentity)
    or (typeof(getidentity) == "function" and getidentity)
    or (typeof(getthreadcontext) == "function" and getthreadcontext)
    or (type(syn) == "table" and typeof(syn.get_thread_identity) == "function" and syn.get_thread_identity)
    or nil

local _setIdentity = (typeof(setthreadidentity) == "function" and setthreadidentity)
    or (typeof(setidentity) == "function" and setidentity)
    or (typeof(setthreadcontext) == "function" and setthreadcontext)
    or (type(syn) == "table" and typeof(syn.set_thread_identity) == "function" and syn.set_thread_identity)
    or nil

local EXECUTOR_IDENTITY = 8
if _getIdentity then
    local okId, curId = pcall(_getIdentity)
    if okId and type(curId) == "number" and curId >= 6 then
        EXECUTOR_IDENTITY = curId
    end
end

local function EnsureHighIdentity()
    if _setIdentity then
        pcall(_setIdentity, EXECUTOR_IDENTITY)
    end
end

local function SafeCallGame(fn, ...)
    if typeof(fn) ~= "function" then
        return false, "not_a_function"
    end
    local packed = table.pack(pcall(fn, ...))
    EnsureHighIdentity()
    return table.unpack(packed, 1, packed.n)
end

local function StartLoop(interval, fn)
    task.spawn(function()
        while Running do
            EnsureHighIdentity()
            local ok, err = pcall(fn)
            EnsureHighIdentity()
            if not ok then
                warn("[HelmHUB ACX] Vòng lặp lỗi: " .. tostring(err))
            end
            task.wait(interval)
        end
    end)
end

-- ============================================================================
-- [1] UI LIBRARY (cùng cơ chế nạp với các game khác trong HelmHub)
-- ============================================================================
local function LoadUILibrary()
    local cache = env.HelmSharedLibraryCache
    if cache and typeof(cache.fn) == "function" then
        env.HelmSharedLibraryCache = nil
        local okExec, lib = pcall(cache.fn)
        if okExec and lib then
            return lib
        end
    end

    local sources = {}
    if (_G.DevMode == true) or env.DevMode == true then
        sources[#sources + 1] = function()
            return game:HttpGet("http://127.0.0.1:8000/Library/inventory.lua?t=" .. tostring(tick()))
        end
    end
    if isfile and readfile then
        sources[#sources + 1] = function()
            if isfile("Library/inventory.lua") then return readfile("Library/inventory.lua") end
            if isfile("inventory.lua") then return readfile("inventory.lua") end
            return nil
        end
    end
    sources[#sources + 1] = function()
        return game:HttpGet("https://raw.githubusercontent.com/helmgodmommy/HelmHUB/main/Library/inventory.lua?t=" .. tostring(math.floor(tick() / 60)))
    end

    for _, fetch in ipairs(sources) do
        local okGet, body = pcall(fetch)
        if okGet and type(body) == "string" and #body > 1000 then
            if body:sub(1, 3) == "\239\187\191" then
                body = body:sub(4)
            end
            if body:sub(1, 1) ~= "<" then
                local fn = loadstring(body)
                if fn then
                    local okLib, lib = pcall(fn)
                    if okLib and type(lib) == "table" then
                        return lib
                    end
                end
            end
        end
    end

    if env.HelmLibrary and typeof(env.HelmLibrary.CreateWindow) == "function" then
        return env.HelmLibrary
    end
    return nil
end

local library = LoadUILibrary()
if not library then
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "HelmHub • Anime Champions X",
            Text = "Không thể nạp UI Library (Library/inventory.lua)!",
            Duration = 6
        })
    end)
    return
end

local function Notify(title, text, duration, nType)
    EnsureHighIdentity()
    pcall(library.Notify, library, tostring(title or "HelmHub | Anime Champions X"), tostring(text or ""), tonumber(duration) or 3, nType)
end

-- ============================================================================
-- [2] SAFE REQUIRE (khôi phục Executor Identity chống lỗi lacking capability Plugin)
-- ============================================================================
local function SafeRequire(moduleScript, timeoutSeconds)
    if not (moduleScript and typeof(moduleScript) == "Instance" and moduleScript:IsA("ModuleScript")) then
        return nil, "invalid_module"
    end
    local result, okFlag, done = nil, false, false
    local limit = timeoutSeconds or 4
    local worker = task.spawn(function()
        if _setIdentity then
            pcall(_setIdentity, 2)
        end
        okFlag, result = pcall(require, moduleScript)
        EnsureHighIdentity()
        done = true
    end)

    local deadline = os.clock() + limit
    while not done and os.clock() < deadline do
        task.wait(0.05)
    end
    EnsureHighIdentity()
    if not done then
        pcall(task.cancel, worker)
        EnsureHighIdentity()
        return nil, string.format("require quá thời gian %ss", tostring(limit))
    end
    if not okFlag then
        return nil, "require thất bại: " .. tostring(result)
    end
    return result, nil
end

local function FindModuleByPath(root, pathParts)
    local cur = root
    for _, part in ipairs(pathParts) do
        if not cur then return nil end
        cur = cur:FindFirstChild(part)
    end
    if cur and cur:IsA("ModuleScript") then
        return cur
    end
    return nil
end

local ModuleCache = {}
local function GetGameModule(pathKey, pathParts)
    if ModuleCache[pathKey] ~= nil then
        return ModuleCache[pathKey] or nil
    end
    local modInst = FindModuleByPath(ReplicatedStorage, pathParts)
    if not modInst then
        ModuleCache[pathKey] = false
        return nil
    end
    local loaded = SafeRequire(modInst, 4)
    ModuleCache[pathKey] = loaded or false
    return loaded
end

-- ============================================================================
-- [3] HẰNG SỐ DỰ PHÒNG TỪ DUMP (Known) + ĐỌC LẠI RUNTIME
-- ============================================================================
local Known = {
    ChestTag = "Chest",
    ChestIdAttribute = "ChestId",
    NpcTag = "Npc",
    NpcIdAttribute = "NpcId",
    QuestItemTag = "QuestItem",
    QuestItemIdAttribute = "QuestItemId",
    GamemodeAttribute = "GamemodeId",
    OverworldAreaAttribute = "OverworldWorldId",
    PlayRewardsOnAttribute = "PlayRewardsOn",
    AfkSinceAttribute = "AfkSince",
    AfkEarnedAttribute = "AfkEarned",
    AttackOrderMaxDistance = 40,
    DefaultWalkSpeed = 12,
    DefaultSprintSpeed = 32,
    Worlds = { "champion_city", "alien", "pirate", "ninja", "city" },
    BossWorlds = { "alien", "pirate", "ninja", "city" },
    Banners = { "alien", "pirate", "ninja", "city" },
    -- Danh sách quái tách riêng theo từng World (không gộp chung toàn game)
    EnemiesByWorld = {
        alien = {
            "alien_recruit",
            "alien_warrior",
            "alien_gunner",
            "alien_brute",
            "alien_general",
            "alien_boss"
        },
        pirate = {
            "marine_grunt",
            "marine_rifleman",
            "marine_cannoneer",
            "marine_medic",
            "marine_officer",
            "prisoner_post",
            "marine_lieutenant_miniboss",
            "marine_captain"
        },
        ninja = {
            "water_shinobi",
            "water_kunoichi",
            "water_jonin",
            "sand_shinobi",
            "sand_kunoichi",
            "sand_jonin",
            "lightning_shinobi",
            "lightning_kunoichi",
            "lightning_jonin",
            "fire_shinobi",
            "fire_kunoichi",
            "fire_jonin",
            "snake_ninja"
        },
        city = {
            "cursed_spirit",
            "bound_spirit",
            "malformed_curse",
            "vessel",
            "weeping_bud",
            "veil_vessel_1",
            "veil_vessel_2",
            "veil_vessel_3",
            "spirit_user",
            "curse_king"
        }
    },
    -- Danh sách NPC giao nhiệm vụ theo từng World
    QuestWorlds = { "Tất cả World (Theo Tiến Độ)", "alien", "pirate", "ninja", "city" },
    QuestNpcsByWorld = {
        ["Tất cả World (Theo Tiến Độ)"] = {
            "Tất cả NPC trong World",
            "alien_scout", "alien_soldier", "alien_researcher",
            "pirate_captain", "pirate_hunter", "bounty_hunter",
            "ninja_exile", "ninja_elder", "ninja_healer", "ninja_watch",
            "cursed_boy", "sorcerer"
        },
        alien = { "Tất cả NPC trong World", "alien_scout", "alien_soldier", "alien_researcher" },
        pirate = { "Tất cả NPC trong World", "pirate_captain", "pirate_hunter", "bounty_hunter" },
        ninja = { "Tất cả NPC trong World", "ninja_exile", "ninja_elder", "ninja_healer", "ninja_watch" },
        city = { "Tất cả NPC trong World", "cursed_boy", "sorcerer" }
    },
    UniversalTargets = {
        "Vào & Farm Raid Đã Chọn",
        "Vào & Farm World Boss Đã Chọn",
        "Vào & Farm Story Mission Đã Chọn",
        "Làm Nhiệm Vụ NPC Theo World Đã Chọn",
        "Chỉ Tự Đánh Trong Chế Độ Hiện Tại"
    },
    Boosters = { "Không dùng", "luck_booster", "super_luck_booster", "ultra_luck_booster" },
    TimedBoostItems = {
        "damage_booster", "gold_booster", "xp_booster",
        "luck_booster", "super_luck_booster", "ultra_luck_booster"
    },
    BoosterKindMap = {
        damage_booster = "damage",
        gold_booster = "gold",
        xp_booster = "xp",
        luck_booster = "luck",
        super_luck_booster = "super_luck",
        ultra_luck_booster = "ultra_luck"
    },
    Starters = { "soulbreaker", "gum_gum_pirate", "cursed_vessel" },
    MatchVoteOptions = { "retry", "next", "lobby" },
    RaidBases = { "marines", "curse_city" },
    RaidCards = {
        "Tự động theo thứ tự ưu tiên DPS",
        "giant_slayer", "overload", "quickcast", "killer_instinct", "elemental_fury",
        "showdown", "second_wind", "grievous_wounds", "double_dose", "no_respite",
        "steady_footing", "shackles", "antidote", "mend"
    },
    RaidCardPriority = {
        giant_slayer = 100,
        overload = 95,
        quickcast = 92,
        killer_instinct = 88,
        elemental_fury = 85,
        showdown = 82,
        second_wind = 78,
        grievous_wounds = 75,
        double_dose = 70,
        no_respite = 68,
        steady_footing = 65,
        shackles = 60,
        antidote = 55,
        mend = 50
    },
    Missions = {
        "alien_1", "alien_2", "alien_3",
        "pirate_1", "pirate_2", "pirate_3",
        "ninja_1", "ninja_2", "ninja_3",
        "city_1", "city_2", "city_3"
    },
    Merchants = { "GoldMerchant", "DefenseMerchant", "RaidMerchant", "ShardMerchant" },
    MerchantCurrencyMap = {
        GoldMerchant = "gold",
        DefenseMerchant = "defense_crystals",
        RaidMerchant = "raid_medal",
        ShardMerchant = "comet_shard"
    },
    MerchantItemLabels = {
        gold_team_slot = "[Upgrade] Ô Đội I +1 Tướng (100K Gold) [gold_team_slot]",
        gold_team_slot_2 = "[Upgrade] Ô Đội II +1 Tướng (100M Gold) [gold_team_slot_2]",
        auto_abilities = "[Upgrade] Tự Dùng Kỹ Năng (1K Gold) [auto_abilities]",
        storage_1 = "[Upgrade] Mở Rộng Kho I +25 (1K Gold) [storage_1]",
        storage_2 = "[Upgrade] Mở Rộng Kho II +25 (100K Gold) [storage_2]",
        storage_3 = "[Upgrade] Mở Rộng Kho III +50 (10M Gold) [storage_3]",
        alien_fruit = "[Vật phẩm] Trái Alien / Ki (100 Gold - Lv 10) [alien_fruit]",
        pirate_fruit = "[Vật phẩm] Trái Hải Tặc / Tide (300 Gold - Lv 20) [pirate_fruit]",
        ninja_fruit = "[Vật phẩm] Trái Nguyên Tố / Ninja (1K Gold - Lv 30) [ninja_fruit]",
        city_fruit = "[Vật phẩm] Trái Bị Nguyền / Curse City (2.5K Gold - Lv 40) [city_fruit]",
        ant_fruit = "[Vật phẩm] Trái Kiến / Amber (8K Gold - Lv 50) [ant_fruit]",
        secret_fruit = "[Vật phẩm] Trái Bí Ẩn / Cosmic (+1 Level) [secret_fruit]",
        trait_tokens = "[Vật phẩm] Trait Tokens (Đá Quay Trait) [trait_tokens]",
        luck_booster = "[Vật phẩm] Thuốc May Mắn (Luck Booster) [luck_booster]",
        super_luck_booster = "[Vật phẩm] Siêu Thuốc May Mắn (Super Luck) [super_luck_booster]",
        gems = "[Vật phẩm] Đá Quý (Gems x100) [gems]"
    },
    MerchantUpgradeDefsFallback = {
        gold_team_slot = { id = "gold_team_slot", label = "Ô Đội I (+1 Tướng)", price = 100000, currencyId = "gold", released = true },
        gold_team_slot_2 = { id = "gold_team_slot_2", label = "Ô Đội II (+1 Tướng - 100M Gold)", price = 100000000, currencyId = "gold", requires = "gold_team_slot", released = true },
        auto_abilities = { id = "auto_abilities", label = "Tự Dùng Kỹ Năng", price = 1000, currencyId = "gold", released = true },
        storage_1 = { id = "storage_1", label = "Mở Rộng Kho I (+25)", price = 1000, currencyId = "gold", released = false },
        storage_2 = { id = "storage_2", label = "Mở Rộng Kho II (+25)", price = 100000, currencyId = "gold", requires = "storage_1", released = false },
        storage_3 = { id = "storage_3", label = "Mở Rộng Kho III (+50)", price = 10000000, currencyId = "gold", requires = "storage_2", released = false }
    },
    MerchantOfferDefsFallback = {
        GoldMerchant = {
            { itemId = "alien_fruit", packSize = 1, price = 100, requiredWorld = "alien", ladder = "world_fruit" },
            { itemId = "pirate_fruit", packSize = 1, price = 300, requiredWorld = "pirate", ladder = "world_fruit" },
            { itemId = "ninja_fruit", packSize = 1, price = 1000, requiredWorld = "ninja", ladder = "world_fruit" },
            { itemId = "city_fruit", packSize = 1, price = 2500, requiredWorld = "city", ladder = "world_fruit" }
        },
        DefenseMerchant = {
            { itemId = "luck_booster", packSize = 1, price = 5000 },
            { itemId = "trait_tokens", packSize = 3, price = 1000 }
        },
        RaidMerchant = {
            { itemId = "trait_tokens", packSize = 1, price = 10 },
            { itemId = "secret_fruit", packSize = 1, price = 500, weeklyLimit = 5 },
            { itemId = "luck_booster", packSize = 1, price = 100 }
        },
        ShardMerchant = {
            { itemId = "gems", packSize = 100, price = 10 },
            { itemId = "luck_booster", packSize = 1, price = 25 },
            { itemId = "super_luck_booster", packSize = 1, price = 100 },
            { itemId = "trait_tokens", packSize = 5, price = 25 }
        }
    },
    MerchantUpgradesByMerchant = {
        GoldMerchant = {
            "gold_team_slot",
            "gold_team_slot_2",
            "auto_abilities",
            "storage_1",
            "storage_2",
            "storage_3"
        },
        DefenseMerchant = {},
        RaidMerchant = {},
        ShardMerchant = {}
    },
    MerchantItemsByMerchant = {
        GoldMerchant = {
            "gold_team_slot",
            "gold_team_slot_2",
            "auto_abilities",
            "ninja_fruit",
            "city_fruit",
            "pirate_fruit",
            "alien_fruit",
            "storage_1",
            "storage_2",
            "storage_3"
        },
        DefenseMerchant = { "trait_tokens", "luck_booster" },
        RaidMerchant = { "trait_tokens", "secret_fruit", "luck_booster" },
        ShardMerchant = { "trait_tokens", "gems", "luck_booster", "super_luck_booster" }
    },
    VoucherPasses = {
        "AutoAttack", "Nostalgic", "Lucky", "ExtraChampionStorage",
        "DoubleBattleXP", "VIP", "DoubleGold", "MegaChampionStorage",
        "ShinyHunter", "SuperLucky"
    },
    VoucherPassCosts = {
        AutoAttack = 5,
        Nostalgic = 8,
        Lucky = 8,
        ExtraChampionStorage = 12,
        DoubleBattleXP = 23,
        VIP = 27,
        DoubleGold = 31,
        MegaChampionStorage = 39,
        ShinyHunter = 77,
        SuperLucky = 193
    },
    ServerAutoDismantleModes = { "All", "Shinies", "None" },
    CityWarps = {
        "Summon", "Raids", "Market", "Upgrades", "Leaderboards",
        "npc:daireb", "npc:gold_merchant", "npc:defense_merchant", "npc:raid_merchant",
        "npc:shard_merchant", "npc:trait_reroll", "npc:evolution", "npc:ascension", "npc:mentor"
    },
    WorldWarps = {
        "WorldSpawn", "WorldBoss",
        "gate:alien", "gate:pirate", "gate:ninja", "gate:city",
        "npc:alien_scout", "npc:alien_soldier", "npc:alien_researcher",
        "npc:pirate_captain", "npc:pirate_hunter", "npc:bounty_hunter",
        "npc:ninja_watch", "npc:ninja_healer", "npc:ninja_exile", "npc:ninja_elder",
        "npc:cursed_boy", "npc:sorcerer"
    },
    Windows = {
        "Inventory", "Banner", "Quests", "SeasonPass", "Travel", "Store",
        "Index", "Evolve", "Ascend", "TraitReroll", "Crafting", "Merchant", "RaidSelect", "CodeList"
    },
    Repairs = {
        "evolve_machine", "trait_machine", "ascension_machine",
        "auto_abilities", "gold_team_slot", "gold_team_slot_2",
        "storage_1", "storage_2", "storage_3",
        "summon_hatch_5", "summon_hatch_10",
        "alien_boss_portal", "pirate_boss_portal", "ninja_boss_portal", "city_boss_portal"
    },
    Traits = {
        "HonouredOne",
        "CrimsonDemon", "Deadeye", "Boxer", "Draconic", "Commander", "Lucky", "Giant",
        "Strong3", "Tough3", "Accurate3", "Agile3", "Sorcerer3", "Genius3", "Rich3",
        "Searing", "Barbed", "Concussive", "Executioner", "Tactical", "Taunt", "Supporter",
        "Strong2", "Tough2", "Accurate2", "Agile2", "Sorcerer2", "Genius2", "Rich2",
        "Strong1", "Tough1", "Accurate1", "Agile1", "Sorcerer1", "Genius1", "Rich1"
    },
    TraitRarities = { "Bất kỳ (chỉ lọc theo Trait)", "Secret", "Mythic", "Legendary", "Epic", "Rare" },
    TraitRarityMap = {
        HonouredOne = "Secret",
        Giant = "Mythic", CrimsonDemon = "Mythic", Deadeye = "Mythic", Boxer = "Mythic",
        Draconic = "Mythic", Commander = "Mythic", Lucky = "Mythic",
        Strong3 = "Legendary", Tough3 = "Legendary", Accurate3 = "Legendary", Agile3 = "Legendary",
        Sorcerer3 = "Legendary", Genius3 = "Legendary", Rich3 = "Legendary",
        Searing = "Legendary", Barbed = "Legendary", Concussive = "Legendary",
        Executioner = "Legendary", Tactical = "Legendary", Taunt = "Legendary", Supporter = "Legendary",
        Strong2 = "Epic", Tough2 = "Epic", Accurate2 = "Epic", Agile2 = "Epic",
        Sorcerer2 = "Epic", Genius2 = "Epic", Rich2 = "Epic",
        Strong1 = "Rare", Tough1 = "Rare", Accurate1 = "Rare", Agile1 = "Rare",
        Sorcerer1 = "Rare", Genius1 = "Rare", Rich1 = "Rare"
    },
    DismantleRarities = { "Common", "Rare", "Epic", "Legendary" },
    RarityRanks = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5, Secret = 6 },
    StatIds = { "strength", "spirit", "vitality" },
    StatGrades = { "F", "D", "C", "B", "A", "S", "SS", "SSS" },
    StatGradeRanks = { F = 1, D = 2, C = 3, B = 4, A = 5, S = 6, SS = 7, SSS = 8 },
    Fruits = { "alien_fruit", "pirate_fruit", "ninja_fruit", "city_fruit", "ant_fruit", "secret_fruit" },
    CraftingItems = { "trait_tokens", "luck_booster", "super_luck_booster", "ultra_luck_booster", "damage_booster", "gold_booster", "xp_booster" },
    Npcs = {
        "daireb", "gold_merchant", "defense_merchant", "raid_merchant", "shard_merchant",
        "trait_reroll", "evolution", "ascension", "mentor",
        "alien_scout", "alien_soldier", "alien_researcher",
        "pirate_captain", "pirate_hunter", "bounty_hunter",
        "ninja_watch", "ninja_healer", "ninja_exile", "ninja_elder",
        "cursed_boy", "sorcerer"
    }
}

local C = {}
for k, v in pairs(Known) do
    C[k] = v
end

-- Đọc bổ sung danh sách quái của từng World từ ReplicatedStorage.Config.OverworldMode.Worlds.<worldId> lúc chạy
local function EnrichWorldEnemiesFromRuntime(worldId)
    local worldMod = GetGameModule("World_" .. tostring(worldId), { "Config", "OverworldMode", "Worlds", tostring(worldId) })
    if type(worldMod) ~= "table" then return end
    local seen = {}
    local list = {}
    for _, existing in ipairs(C.EnemiesByWorld[worldId] or {}) do
        seen[existing] = true
        list[#list + 1] = existing
    end
    if type(worldMod.packs) == "table" then
        for _, tierPacks in pairs(worldMod.packs) do
            if type(tierPacks) == "table" then
                for _, packDef in ipairs(tierPacks) do
                    if type(packDef) == "table" and type(packDef.characterIds) == "table" then
                        for _, cid in ipairs(packDef.characterIds) do
                            if type(cid) == "string" and not seen[cid] then
                                seen[cid] = true
                                list[#list + 1] = cid
                            end
                        end
                    end
                end
            end
        end
    end
    if type(worldMod.camps) == "table" then
        for _, campDef in pairs(worldMod.camps) do
            if type(campDef) == "table" and type(campDef.pack) == "table" and type(campDef.pack.enemies) == "table" then
                for _, enemyDef in ipairs(campDef.pack.enemies) do
                    local cid = type(enemyDef) == "table" and enemyDef.characterId or enemyDef
                    if type(cid) == "string" and not seen[cid] then
                        seen[cid] = true
                        list[#list + 1] = cid
                    end
                end
            end
        end
    end
    C.EnemiesByWorld[worldId] = list
end

local ConstSource = "hằng số ghim từ dump PlaceVersion 4"
local function EnrichConstantsFromRuntime()
    local loadedCount = 0
    local traitDefs = GetGameModule("TraitDefs", { "Shared", "TraitDefs" })
    if type(traitDefs) == "table" and typeof(traitDefs.ids) == "function" then
        local okIds, ids = pcall(traitDefs.ids)
        if okIds and type(ids) == "table" and #ids > 0 then
            table.sort(ids)
            C.Traits = ids
            loadedCount = loadedCount + 1
            for _, tid in ipairs(ids) do
                local okDef, def = pcall(traitDefs.tryGet, tid)
                if okDef and type(def) == "table" and type(def.rarity) == "string" then
                    C.TraitRarityMap[tid] = def.rarity
                end
            end
        end
    end

    local bannerCfg = GetGameModule("BannerConfig", { "Config", "BannerConfig" })
    if type(bannerCfg) == "table" and typeof(bannerCfg.getAllIds) == "function" then
        local okB, bIds = pcall(bannerCfg.getAllIds)
        if okB and type(bIds) == "table" and #bIds > 0 then
            C.Banners = bIds
            loadedCount = loadedCount + 1
        end
    end

    local overworldCfg = GetGameModule("OverworldMode", { "Config", "OverworldMode" })
    if type(overworldCfg) == "table" then
        if type(overworldCfg.CurrentWorldAttribute) == "string" and overworldCfg.CurrentWorldAttribute ~= "" then
            C.OverworldAreaAttribute = overworldCfg.CurrentWorldAttribute
        end
        local wIds = nil
        if typeof(overworldCfg.getWorldIds) == "function" then
            local okW, resW = SafeCallGame(overworldCfg.getWorldIds)
            if okW and type(resW) == "table" then wIds = resW end
        elseif type(overworldCfg.WORLD_ORDER) == "table" then
            wIds = overworldCfg.WORLD_ORDER
        end
        if type(wIds) == "table" and #wIds > 0 then
            local releasedWorlds = {}
            local areas = { overworldCfg.CITY_ID or "champion_city" }
            for _, wid in ipairs(wIds) do
                local released = true
                if typeof(overworldCfg.isWorldReleased) == "function" then
                    local okRel, isRel = SafeCallGame(overworldCfg.isWorldReleased, wid)
                    released = (not okRel) or (isRel == true)
                elseif typeof(overworldCfg.isComingSoon) == "function" then
                    local okCS, isCS = SafeCallGame(overworldCfg.isComingSoon, wid)
                    released = not (okCS and isCS == true)
                end
                if released then
                    releasedWorlds[#releasedWorlds + 1] = wid
                    areas[#areas + 1] = wid
                    SafeCallGame(EnrichWorldEnemiesFromRuntime, wid)
                end
            end
            if #releasedWorlds > 0 then
                C.BossWorlds = releasedWorlds
            end
            C.Worlds = areas
            loadedCount = loadedCount + 1
        end
    else
        for _, wid in ipairs(C.BossWorlds) do
            SafeCallGame(EnrichWorldEnemiesFromRuntime, wid)
        end
    end

    local repairsCfg = GetGameModule("Repairs", { "Config", "Repairs" })
    if type(repairsCfg) == "table" and typeof(repairsCfg.all) == "function" then
        local okR, allRepairs = pcall(repairsCfg.all)
        if okR and type(allRepairs) == "table" then
            local rList = {}
            for rid in pairs(allRepairs) do
                if type(rid) == "string" then
                    rList[#rList + 1] = rid
                end
            end
            table.sort(rList)
            if #rList > 0 then
                C.Repairs = rList
                loadedCount = loadedCount + 1
            end
        end
    end

    local missionsCfg = GetGameModule("Missions", { "Config", "Missions" })
    if type(missionsCfg) == "table" and typeof(missionsCfg.getAll) == "function" then
        local okM, allMissions = pcall(missionsCfg.getAll)
        if okM and type(allMissions) == "table" and #allMissions > 0 then
            local mIds = {}
            for _, m in ipairs(allMissions) do
                if type(m) == "table" and type(m.id) == "string" then
                    mIds[#mIds + 1] = m.id
                end
            end
            if #mIds > 0 then
                C.Missions = mIds
                loadedCount = loadedCount + 1
            end
        end
    end

    local raidRunCfg = GetGameModule("RaidRun", { "Config", "RaidRun" })
    if type(raidRunCfg) == "table" and typeof(raidRunCfg.getBoonIds) == "function" then
        local okBoon, boonIds = pcall(raidRunCfg.getBoonIds)
        if okBoon and type(boonIds) == "table" and #boonIds > 0 then
            local list = { "Tự động theo thứ tự ưu tiên DPS" }
            for _, bid in ipairs(boonIds) do
                list[#list + 1] = bid
            end
            C.RaidCards = list
            loadedCount = loadedCount + 1
        end
    end

    local purchaseCfg = GetGameModule("PurchaseItems", { "Config", "PurchaseItems" })
    if type(purchaseCfg) == "table" and type(purchaseCfg.Passes) == "table" then
        local vPasses = {}
        for passKey, passDef in pairs(purchaseCfg.Passes) do
            if type(passDef) == "table" and type(passDef.vouchers) == "number" and not passDef.seasonal then
                vPasses[#vPasses + 1] = passKey
                C.VoucherPassCosts[passKey] = passDef.vouchers
            end
        end
        table.sort(vPasses, function(a, b)
            return (C.VoucherPassCosts[a] or 999) < (C.VoucherPassCosts[b] or 999)
        end)
        if #vPasses > 0 then
            C.VoucherPasses = vPasses
            loadedCount = loadedCount + 1
        end
    end

    local merchantCat = GetGameModule("MerchantCatalog", { "Config", "MerchantCatalog" })
    if type(merchantCat) == "table" and typeof(merchantCat.get) == "function" then
        local enrichedAny = false
        for _, mId in ipairs(C.Merchants) do
            local combinedIds = {}
            local seenItems = {}
            local upgradeIds = {}

            if type(repairsCfg) == "table" and typeof(repairsCfg.forMerchant) == "function" then
                local okU, uList = SafeCallGame(repairsCfg.forMerchant, mId)
                if okU and type(uList) == "table" then
                    for _, uDef in ipairs(uList) do
                        local uid = type(uDef) == "table" and uDef.id or uDef
                        if type(uid) == "string" and uid ~= "" and not seenItems[uid] then
                            seenItems[uid] = true
                            upgradeIds[#upgradeIds + 1] = uid
                            combinedIds[#combinedIds + 1] = uid
                        end
                    end
                end
            end
            if #upgradeIds == 0 and type(C.MerchantUpgradesByMerchant[mId]) == "table" then
                for _, uid in ipairs(C.MerchantUpgradesByMerchant[mId]) do
                    if type(uid) == "string" and uid ~= "" and not seenItems[uid] then
                        seenItems[uid] = true
                        upgradeIds[#upgradeIds + 1] = uid
                        combinedIds[#combinedIds + 1] = uid
                    end
                end
            end
            C.MerchantUpgradesByMerchant[mId] = upgradeIds

            local okM, mDef = SafeCallGame(merchantCat.get, mId)
            if okM and type(mDef) == "table" and type(mDef.offers) == "table" and #mDef.offers > 0 then
                for _, offer in ipairs(mDef.offers) do
                    if type(offer) == "table" and type(offer.itemId) == "string" and offer.itemId ~= "" and not seenItems[offer.itemId] then
                        seenItems[offer.itemId] = true
                        combinedIds[#combinedIds + 1] = offer.itemId
                    end
                end
            end

            if #combinedIds > 0 then
                C.MerchantItemsByMerchant[mId] = combinedIds
                enrichedAny = true
            end
        end
        if enrichedAny then
            loadedCount = loadedCount + 1
        end
    end

    if loadedCount > 0 then
        ConstSource = string.format("runtime ReplicatedStorage (%d module dữ liệu)", loadedCount)
    end
    EnsureHighIdentity()
end

-- ============================================================================
-- [4] CẤU HÌNH & LƯU THEO TÀI KHOẢN (HelmHub/Anime Champions X)
-- ============================================================================
local Config = {
    -- Chiến đấu, Lọc Multi Quái Theo World, Kỹ năng & Buff
    AutoEngage = false,
    CombatWorld = "alien",
    FilterBySelectedMobs = false,
    AutoTravelToCombatWorld = false,
    SelectedMobs_alien = {},
    SelectedMobs_pirate = {},
    SelectedMobs_ninja = {},
    SelectedMobs_city = {},
    TeleportToPack = false,
    EngageMaxDist = 150,
    PrioritizeBoss = true,
    PauseOnUnitsDead = true,
    DeadUnitsPauseThreshold = 2,
    StepBackOnRecovery = true,
    AutoInGameAttack = false,
    AutoAbilities = false,
    OnlyCastReadyAbilities = true,
    AbilityInterval = 1.0,
    AutoCollectDrops = true,
    AutoOpenChests = true,
    TeleportToChestBeforeOpen = false,
    AutoSkipDialogue = false,
    AutoSkipTransitions = false,
    AutoDismissPopups = false,
    SelectedTimedBoost = "damage_booster",
    AutoUseTimedBoost = false,
    AutoVoidReturn = true,

    -- Auto Farm Tổng Hợp Đa Chế Độ + Boss, Mission, Raid, Defense & Match
    AutoUniversalModeFarm = false,
    UniversalOverworldTarget = "Vào & Farm Raid Đã Chọn",
    SelectedBossWorld = "alien",
    AutoChallengeBoss = false,
    AutoQuestGo = false,
    SelectedMission = C.Missions[1] or "alien_1",
    AutoPlayMission = false,
    AutoMatchVote = false,
    MatchVoteOption = "retry",
    WaitChestBeforeVote = true,
    SmartVoteFallback = true,
    AutoRaidVoteCard = false,
    PreferredRaidCard = "Tự động theo thứ tự ưu tiên DPS",
    AutoRaidReadyNext = false,
    AutoDefenseNextWave = false,
    SelectedRaidBase = "marines",
    SelectedRaidTier = 1,
    AutoLobbyReady = false,
    AutoAcceptPartyInvites = false,
    AcceptPartyFriendsOnly = false,
    AutoInviteFriendsToParty = false,
    SelectedPartyPlayer = "Chưa có người chơi khác",
    PartyCreateMode = "Tạo Phòng Theo Raid Đang Chọn",

    -- Triệu hồi, Đội hình, Feed, Dismantle, Lock, Ascend, Evolve, Trait & Stat
    SelectedBanner = "alien",
    PullCount = 10,
    SelectedBooster = "Không dùng",
    AutoSummon = false,
    AutoUnlockBanner = false,
    ServerKeepRare = "All",
    ServerKeepEpic = "All",
    ServerKeepLegendary = "All",
    AutoEquipBest = false,
    AutoFeedEquipped = false,
    AutoLockRare = true,
    AutoDismantle = false,
    DismantleMaxRarity = "Rare",
    DismantleKeepShiny = true,
    DismantleKeepStarred = true,
    AutoAscend = false,
    AutoEvolve = false,
    AutoEvolveAllInventory = false,
    SelectedTraitSlot = "1",
    TargetTrait = "HonouredOne",
    TargetTraitRarity = "Mythic",
    AutoTraitReroll = false,
    TargetStatGrade = "S",
    AutoLockReachedStats = true,
    AutoStatReroll = false,
    SelectedRepair = "evolve_machine",
    AutoRepairAll = false,
    SelectedCraftItem = "trait_tokens",
    CraftQuantity = 1,

    -- Nhiệm vụ NPC Theo Từng World, Tân Thủ, Sự kiện, Voucher & Cửa hàng
    QuestWorldFilter = "Tất cả World (Theo Tiến Độ)",
    SelectedQuestNpc = "Tất cả NPC trong World",
    AutoWorldNpcQuestLoop = false,
    AutoDailyQuests = true,
    AutoPinActiveQuest = false,
    AutoTravelForNpcQuest = true,
    AutoRunQuestMissionsAndBoss = true,
    AutoAcceptQuests = false,
    AutoClaimQuests = false,
    AutoFindQuestItems = false,
    AutoClaimMilestones = false,
    AutoClaimDaily = false,
    AutoClaimSeasonPass = false,
    AutoClaimSeasonRepeatables = false,
    AutoClaimCountdownPack = false,
    AutoCompleteTutorial = false,
    AutoClaimFreeStore = false,
    SelectedVoucherPass = "AutoAttack",
    AutoBuyVoucherPass = false,
    SelectedStarter = "soulbreaker",
    SelectedMerchant = "GoldMerchant",
    FilterMerchantBySelectedItems = false,
    SelectedMerchantItems_GoldMerchant = {},
    SelectedMerchantItems_DefenseMerchant = {},
    SelectedMerchantItems_RaidMerchant = {},
    SelectedMerchantItems_ShardMerchant = {},
    AutoBuyMerchant = false,
    MerchantBuyMaxPacks = false,
    CodeInputText = "",

    -- Dịch chuyển, Tốc độ, Cửa sổ & ESP
    SelectedWorld = "champion_city",
    SelectedCityWarp = "Summon",
    SelectedWorldWarp = "WorldSpawn",
    SelectedWindow = "Inventory",
    AutoSprint = true,
    EnableCustomWalkSpeed = false,
    CustomWalkSpeed = 45,
    ESPNpc = false,
    ESPChest = false,
    ESPEnemy = false,

    -- Hệ thống, Tối ưu FPS & Anti-AFK
    LowLagMode = false,
    AutoClearTips = false,
    AntiKick = true,
    AntiAfkYield = true,
    AntiAfkMove = false,
    AntiAfkInterval = 300
}

local accountName = tostring((LocalPlayer and LocalPlayer.Name) or (LocalPlayer and tostring(LocalPlayer.UserId)) or "default"):gsub("[^%w_%-]", "_")
if accountName == "" then accountName = "default" end
local GAME_FOLDER_NAME = "Anime Champions X"
local uiFullyLoaded = false
local SaveConfig, TriggerSave
(function()
    local configDir = "HelmHub/" .. GAME_FOLDER_NAME
    local configFile = string.format("%s/config_%s.json", configDir, accountName)
    local saveScheduled = false

    local function WriteJson(path, data)
        pcall(function()
            if not writefile then return end
            if isfolder and makefolder then
                if not isfolder("HelmHub") then makefolder("HelmHub") end
                if not isfolder(configDir) then makefolder(configDir) end
            end
            writefile(path, HttpService:JSONEncode(data))
        end)
    end

    local function ReadJson(path)
        local ok, data = pcall(function()
            if not (isfile and readfile and isfile(path)) then return nil end
            return HttpService:JSONDecode(readfile(path))
        end)
        if ok and type(data) == "table" then
            return data
        end
        return nil
    end

    SaveConfig = function()
        saveScheduled = false
        WriteJson(configFile, Config)
    end

    TriggerSave = function()
        if not uiFullyLoaded then return end
        if saveScheduled then return end
        saveScheduled = true
        task.delay(0.35, function()
            if saveScheduled and Running then
                SaveConfig()
            end
        end)
    end

    for k, v in pairs(ReadJson(configFile) or {}) do
        if Config[k] ~= nil and type(Config[k]) == type(v) then
            Config[k] = v
        end
    end
end)()

-- ============================================================================
-- [5] TIỆN ÍCH MẠNG, STORE & NHÂN VẬT
-- ============================================================================
local Session = {
    claimedDrops = {},
    openedChests = {},
    metNpcs = {},
    esp = { npc = {}, chest = {}, enemy = {} },
    espFolder = nil,
    labels = {},
    lastLabelTexts = {},
    networkFolder = nil,
    networkRemoteCache = {},
    reverseMerchantLabelToId = nil,
    cachedLiveEcs = nil,
    lastEcsGcScanAt = 0,
    cachedLocalEntity = nil,
    characterElementCache = {},
    championRarityCache = {},
    lastHealthEvalAt = 0,
    healthCache = { downCount = 0, totalUnits = 0, minHpPct = 1.0, avgHpPct = 1.0, foundUnits = 0 },
    lastUniversalQueueAt = 0,
    lastAbilityAt = 0,
    lastSessionCachePruneAt = os.clock(),
    lastAutoAttackSyncAt = 0,
    rerollingTrait = false,
    rerollingStats = false,
    lastPackEntity = nil,
    lastPackTime = 0,
    lastPackName = nil,
    lastMissionTalkRunId = nil,
    bossChestCooldownText = "Sẵn sàng",
    universalStatusText = "Đang chờ bật Auto Farm Đa Chế Độ",
    questStatusText = "Đang chờ quét nhiệm vụ NPC...",
    questOverrideMobIds = nil,
    questOverrideElement = nil,
    questCombatActive = false,
    activeQuestDoneInRun = false,
    lastQuestTravelAt = 0,
    lastKnownArea = nil,
    lastSuccessfulTravelAt = 0,
    isRecoveringUnits = false,
    lastRecoveryRetreatAt = 0,
    lastRecoveryStepBackAt = 0,
    unitHealthSummaryText = "Đang kiểm tra máu đội hình...",
    merchantStatusText = "Chọn thương nhân & món đồ muốn mua ở dưới",
    knownRepaired = {},
    upgradeTryCooldown = {},
    activeMerchantDropdown = nil,
    filterMerchantToggleUI = nil,
    matchSnapshot = nil,
    matchOutcome = nil,
    currentRunId = nil,
    currentVoteOption = nil,
    lastVotedRunId = nil,
    lastVotedChoice = nil,
    lastVoteSentAt = 0,
    lastBossWarpAt = 0,
    lastPinnedQuestId = nil,
    currentLobby = nil,
    invitedFriendsMap = {}
}

local F = {}

local function GetRootPart()
    local char = LocalPlayer.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

local function GetHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function ResetVelocity(part)
    if part and part:IsA("BasePart") then
        part.AssemblyLinearVelocity = Vector3.zero
    end
end

local function TeleportCharacterTo(posOrCf)
    local char = LocalPlayer.Character
    local hrp = GetRootPart()
    if not (char and hrp) then return false end
    local targetCf = typeof(posOrCf) == "CFrame" and posOrCf or CFrame.new(posOrCf + Vector3.new(0, 3, 0))
    pcall(function()
        char:PivotTo(targetCf)
        ResetVelocity(hrp)
    end)
    return true
end

local function GetNetworkRemote(name)
    local cached = Session.networkRemoteCache[name]
    if cached and cached.Parent then
        return cached
    end
    if not (Session.networkFolder and Session.networkFolder.Parent) then
        Session.networkFolder = ReplicatedStorage:FindFirstChild("Network")
    end
    local remote = Session.networkFolder and Session.networkFolder:FindFirstChild(name) or nil
    if remote then
        Session.networkRemoteCache[name] = remote
    end
    return remote
end

local function FireRemote(name, ...)
    local remote = GetNetworkRemote(name)
    if not (remote and remote:IsA("RemoteEvent")) then
        return false, "no_remote_event:" .. tostring(name)
    end
    return pcall(remote.FireServer, remote, ...)
end

local function InvokeRemote(name, ...)
    local remote = GetNetworkRemote(name)
    if not (remote and remote:IsA("RemoteFunction")) then
        return false, "no_remote_fn:" .. tostring(name)
    end
    local packed = table.pack(pcall(remote.InvokeServer, remote, ...))
    return table.unpack(packed, 1, packed.n)
end

local GetPlayerStore, ReadStore
(function()
    local cachedStore = nil
    local cachedGcRawTable = nil
    local triedStoreInit = false
    local lastGcScanAt = 0
    local PathPartsCache = {}

    local function ReadFromRawTableByPath(rootTbl, path)
        if type(rootTbl) ~= "table" then return nil end
        if type(path) ~= "string" or path == "" then return rootTbl end
        local parts = PathPartsCache[path]
        if not parts then
            parts = string.split(path, "/")
            PathPartsCache[path] = parts
        end
        local cur = rootTbl
        for i = 1, #parts do
            if type(cur) ~= "table" then
                return nil
            end
            cur = cur[parts[i]]
        end
        return cur
    end

    local function ScoreCandidatePlayerDataTable(tbl)
        if type(tbl) ~= "table" then return -1 end
        if rawget(tbl, "FirstJoinedAt") ~= nil or rawget(tbl, "NextChampionIndex") ~= nil or rawget(tbl, "PlaytestPlaythrough") ~= nil then
            return -1
        end
        local items = rawget(tbl, "Items")
        local champs = rawget(tbl, "Champions")
        local repaired = rawget(tbl, "Repaired")
        local cleared = rawget(tbl, "ClearedBosses")
        if type(items) ~= "table" or type(champs) ~= "table" or type(repaired) ~= "table" or type(cleared) ~= "table" then
            return -1
        end
        local score = 1
        if next(items) ~= nil then score = score + 20 end
        if type(rawget(items, "gold")) == "number" then score = score + 20 end
        if next(champs) ~= nil then score = score + 20 end
        if next(repaired) ~= nil then score = score + 10 end
        if next(cleared) ~= nil then score = score + 10 end
        local stats = rawget(tbl, "Stats")
        if type(stats) == "table" and (tonumber(rawget(stats, "TotalPlaytimeSeconds")) or 0) > 0 then
            score = score + 15
        end
        return score
    end

    local function FindLivePlayerStoreFromConnections()
        local getConns = (typeof(getconnections) == "function" and getconnections)
            or (typeof(get_signal_connections) == "function" and get_signal_connections)
            or nil
        local getUpvals = (type(debug) == "table" and typeof(debug.getupvalues) == "function" and debug.getupvalues)
            or (typeof(getupvalues) == "function" and getupvalues)
            or nil
        if not (getConns and getUpvals) then return nil end

        local liveRemote = ReplicatedStorage:FindFirstChild("__PlayerStore_LiveData1")
        if not liveRemote then
            for _, child in ipairs(ReplicatedStorage:GetChildren()) do
                if child:IsA("RemoteEvent") and string.sub(child.Name, 1, 14) == "__PlayerStore_" then
                    liveRemote = child
                    break
                end
            end
        end
        if not (liveRemote and liveRemote:IsA("RemoteEvent")) then return nil end

        local okC, conns = pcall(getConns, liveRemote.OnClientEvent)
        EnsureHighIdentity()
        if not (okC and type(conns) == "table") then return nil end

        local bestStore, bestTbl, bestScore = nil, nil, -1
        for _, conn in ipairs(conns) do
            local fn = type(conn) == "table" and (conn.Function or conn.Callback) or (typeof(conn) == "userdata" and pcall(function() return conn.Function end) and conn.Function) or nil
            if typeof(fn) == "function" then
                local okU, upvals = pcall(getUpvals, fn)
                if okU and type(upvals) == "table" then
                    for _, uv in pairs(upvals) do
                        if type(uv) == "table" then
                            local obs = rawget(uv, "_observable")
                            if rawget(uv, "_destroyed") == false and type(obs) == "table" and type(rawget(obs, "_table")) == "table" then
                                local inner = rawget(obs, "_table")
                                local sc = ScoreCandidatePlayerDataTable(inner)
                                if rawget(uv, "_loaded") == true then sc = sc + 50 end
                                if sc > bestScore then
                                    bestScore = sc
                                    bestStore = uv
                                    bestTbl = inner
                                end
                            elseif type(rawget(uv, "_table")) == "table" and type(rawget(uv, "_observerRoot")) == "table" then
                                local inner = rawget(uv, "_table")
                                local sc = ScoreCandidatePlayerDataTable(inner)
                                if sc > bestScore then
                                    bestScore = sc
                                    bestTbl = inner
                                end
                            end
                        end
                    end
                end
            end
        end
        EnsureHighIdentity()
        if bestStore then
            cachedStore = bestStore
        end
        if bestTbl and bestScore > 0 then
            cachedGcRawTable = bestTbl
        end
        return cachedStore
    end

    local function FindLivePlayerStoreInGc()
        if cachedStore then
            if rawget(cachedStore, "_destroyed") == true then
                cachedStore = nil
                cachedGcRawTable = nil
            elseif rawget(cachedStore, "_loaded") == true then
                local obs = rawget(cachedStore, "_observable")
                if type(obs) == "table" and type(rawget(obs, "_table")) == "table" then
                    cachedGcRawTable = rawget(obs, "_table")
                end
                return cachedStore
            end
        end

        local connStore = FindLivePlayerStoreFromConnections()
        if connStore and rawget(connStore, "_loaded") == true then
            return connStore
        end

        if cachedGcRawTable and ScoreCandidatePlayerDataTable(cachedGcRawTable) > 1 then
            return cachedStore
        end

        if os.clock() - lastGcScanAt < 3.0 then return cachedStore end
        lastGcScanAt = os.clock()

        local gcFn = (typeof(getgc) == "function" and getgc) or nil
        if not gcFn then return cachedStore end

        local okGc, list = pcall(gcFn, true)
        EnsureHighIdentity()
        if not (okGc and type(list) == "table") then return cachedStore end

        local bestStore, bestStoreScore = nil, -1
        local bestRawTbl, bestRawScore = nil, 1

        for i = 1, #list do
            local obj = list[i]
            if type(obj) == "table" then
                local isLoadedFlag = rawget(obj, "_loaded")
                local isDestroyedFlag = rawget(obj, "_destroyed")
                local observable = rawget(obj, "_observable")
                if isLoadedFlag == true and isDestroyedFlag == false and type(observable) == "table" then
                    local innerTbl = rawget(observable, "_table")
                    local sc = ScoreCandidatePlayerDataTable(innerTbl)
                    if sc >= 1 and sc > bestStoreScore then
                        bestStoreScore = sc
                        bestStore = obj
                        bestRawTbl = innerTbl
                        bestRawScore = sc
                    end
                elseif type(rawget(obj, "_table")) == "table" and type(rawget(obj, "_observerRoot")) == "table" then
                    local innerTbl = rawget(obj, "_table")
                    local sc = ScoreCandidatePlayerDataTable(innerTbl)
                    if sc > bestRawScore then
                        bestRawScore = sc
                        bestRawTbl = innerTbl
                    end
                else
                    local sc = ScoreCandidatePlayerDataTable(obj)
                    if sc > bestRawScore then
                        bestRawScore = sc
                        bestRawTbl = obj
                    end
                end
            end
        end

        if bestStore then
            cachedStore = bestStore
        end
        if bestRawTbl then
            cachedGcRawTable = bestRawTbl
        end
        return cachedStore
    end

    GetPlayerStore = function()
        if cachedStore then
            if rawget(cachedStore, "_destroyed") == true then
                cachedStore = nil
                cachedGcRawTable = nil
            elseif rawget(cachedStore, "_loaded") == true then
                return cachedStore
            end
        end
        local cds = GetGameModule("ClientDataService", { "Client", "services", "ClientDataService" })
        if type(cds) == "table" and typeof(cds.GetStore) == "function" then
            local ok, store = SafeCallGame(cds.GetStore)
            if ok and type(store) == "table" and rawget(store, "_loaded") == true and rawget(store, "_destroyed") ~= true then
                cachedStore = store
                local obs = rawget(store, "_observable")
                if type(obs) == "table" and type(rawget(obs, "_table")) == "table" then
                    cachedGcRawTable = rawget(obs, "_table")
                end
                return store
            end
        end
        local gcStore = FindLivePlayerStoreInGc()
        if gcStore and rawget(gcStore, "_loaded") == true then
            return gcStore
        end
        if not triedStoreInit and not cachedGcRawTable and type(cds) == "table" and typeof(cds.Init) == "function" then
            triedStoreInit = true
            task.spawn(function()
                SafeCallGame(cds.Init)
                if typeof(cds.GetStore) == "function" then
                    local okS, st = SafeCallGame(cds.GetStore)
                    if okS and type(st) == "table" then
                        SafeCallGame(function() return st:waitUntilLoaded(10) end)
                        if rawget(st, "_loaded") == true and rawget(st, "_destroyed") ~= true then
                            cachedStore = st
                            local obs = rawget(st, "_observable")
                            if type(obs) == "table" and type(rawget(obs, "_table")) == "table" then
                                cachedGcRawTable = rawget(obs, "_table")
                            end
                        end
                    end
                end
            end)
        end
        return cachedStore
    end

    ReadStore = function(path, expectedType, readOnly)
        local val = nil
        local gotVal = false

        local store = GetPlayerStore()
        if store and rawget(store, "_loaded") == true and rawget(store, "_destroyed") ~= true then
            local obs = rawget(store, "_observable")
            local rawTbl = type(obs) == "table" and rawget(obs, "_table") or nil
            if type(rawTbl) == "table" then
                local v = ReadFromRawTableByPath(rawTbl, path)
                if v ~= nil then
                    val = v
                    gotVal = true
                end
            end
            if not gotVal then
                local okVal, v = SafeCallGame(function() return store:get(path) end)
                if okVal and v ~= nil then
                    val = v
                    gotVal = true
                end
            end
        end

        if not gotVal and cachedGcRawTable then
            local v = ReadFromRawTableByPath(cachedGcRawTable, path)
            if v ~= nil then
                val = v
                gotVal = true
            end
        end

        if not gotVal then
            local cds = GetGameModule("ClientDataService", { "Client", "services", "ClientDataService" })
            local fusion = GetGameModule("Fusion", { "Packages", "Fusion" })
            if type(cds) == "table" and type(cds.Fusion) == "table" and type(fusion) == "table" and typeof(fusion.peek) == "function" then
                local itemKey = type(path) == "string" and path:match("^Items/(.+)$") or nil
                if itemKey and type(cds.Fusion.ItemCounts) == "table" and cds.Fusion.ItemCounts[itemKey] then
                    local okP, v = SafeCallGame(fusion.peek, cds.Fusion.ItemCounts[itemKey])
                    if okP and v ~= nil then
                        val = v
                        gotVal = true
                    end
                elseif cds.Fusion[path] then
                    local okP, v = SafeCallGame(fusion.peek, cds.Fusion[path])
                    if okP and v ~= nil then
                        val = v
                        gotVal = true
                    end
                end
            end
        end

        if not gotVal or val == nil then
            return nil
        end
        if expectedType and type(val) ~= expectedType then
            return nil
        end
        if not readOnly and type(val) == "table" then
            local okClone, cloned = pcall(table.clone, val)
            if okClone and type(cloned) == "table" then
                return cloned
            end
        end
        return val
    end
end)()

local function FormatNumber(n)
    local num = tonumber(n) or 0
    if num >= 1e9 then return string.format("%.2fB", num / 1e9) end
    if num >= 1e6 then return string.format("%.2fM", num / 1e6) end
    if num >= 1e3 then return string.format("%.1fK", num / 1e3) end
    return tostring(math.floor(num))
end

local function FormatDuration(seconds)
    local s = math.max(0, math.floor(tonumber(seconds) or 0))
    return string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor((s % 3600) / 60), s % 60)
end

-- Lấy danh sách quái chỉ thuộc về World được chọn
function F.GetWorldEnemyList(worldId)
    return C.EnemiesByWorld[tostring(worldId or "alien")] or C.EnemiesByWorld.alien
end

function F.GetSelectedMobsKey(worldId)
    local wid = tostring(worldId or Config.CombatWorld or "alien")
    local key = "SelectedMobs_" .. wid
    if Config[key] == nil then
        Config[key] = {}
    end
    return key
end

function F.GetActiveSelectedMobsSet()
    local key = F.GetSelectedMobsKey(Config.CombatWorld)
    local list = Config[key]
    local set = {}
    local count = 0
    if type(list) == "table" then
        for _, mobId in ipairs(list) do
            if type(mobId) == "string" and mobId ~= "" then
                set[mobId] = true
                count = count + 1
            end
        end
    end
    return set, count
end

-- Lấy danh sách vật phẩm chỉ thuộc về Thương Nhân (Merchant) đang chọn (kèm nhãn tiếng Việt rõ ràng)
function F.FormatMerchantItemOption(itemId)
    local id = tostring(itemId or "")
    return C.MerchantItemLabels[id] or id
end

function F.ResolveMerchantItemId(optionOrId)
    local raw = tostring(optionOrId or "")
    if raw == "" then return "" end
    local bracketed = raw:match("%[([^%[%]]+)%]$")
    if bracketed and bracketed ~= "" then
        return bracketed
    end
    if not Session.reverseMerchantLabelToId then
        Session.reverseMerchantLabelToId = {}
        for id, lbl in pairs(C.MerchantItemLabels or {}) do
            Session.reverseMerchantLabelToId[lbl] = id
            Session.reverseMerchantLabelToId[id] = id
        end
    end
    if Session.reverseMerchantLabelToId[raw] then
        return Session.reverseMerchantLabelToId[raw]
    end
    return raw
end

function F.GetMerchantItemList(merchantId)
    local mid = tostring(merchantId or Config.SelectedMerchant or "GoldMerchant")
    local rawList = C.MerchantItemsByMerchant[mid] or C.MerchantItemsByMerchant.GoldMerchant
    local formatted = {}
    local seen = {}
    for _, rawId in ipairs(rawList) do
        local cleanId = F.ResolveMerchantItemId(rawId)
        if cleanId ~= "" and not seen[cleanId] then
            seen[cleanId] = true
            formatted[#formatted + 1] = F.FormatMerchantItemOption(cleanId)
        end
    end
    return formatted
end

function F.GetSelectedMerchantItemsKey(merchantId)
    local mid = tostring(merchantId or Config.SelectedMerchant or "GoldMerchant")
    local key = "SelectedMerchantItems_" .. mid
    if Config[key] == nil then
        Config[key] = {}
    end
    return key
end

function F.GetActiveSelectedMerchantItemsSet(merchantId)
    local mid = tostring(merchantId or Config.SelectedMerchant or "GoldMerchant")
    local key = F.GetSelectedMerchantItemsKey(mid)
    local set = {}
    local count = 0

    local function addFromList(list)
        if type(list) ~= "table" then return end
        for _, entry in ipairs(list) do
            local cleanId = F.ResolveMerchantItemId(entry)
            if type(cleanId) == "string" and cleanId ~= "" and not set[cleanId] then
                set[cleanId] = true
                count = count + 1
            end
        end
    end

    -- Ưu tiên đọc trực tiếp từ Dropdown đang hiển thị trên màn hình nếu cùng Thương Nhân
    if mid == tostring(Config.SelectedMerchant or "GoldMerchant") and type(Session.activeMerchantDropdown) == "table" and typeof(Session.activeMerchantDropdown.Get) == "function" then
        local okG, liveValues = pcall(Session.activeMerchantDropdown.Get, Session.activeMerchantDropdown)
        if okG and type(liveValues) == "table" then
            addFromList(liveValues)
        end
    end
    if count == 0 then
        addFromList(Config[key])
    end
    return set, count
end

-- ============================================================================
-- [6] HỆ THỐNG ECS & CHIẾN ĐẤU (LỌC MULTI QUÁI THEO WORLD, ENGAGE PACKS, ABILITIES, DROPS)
-- ============================================================================
(function()
    -- Phân biệt thực thể jecs.World đang sống với bảng prototype class World (prototype có rawget(t, "query") == function nhưng không có entity_index/archetypes)
    local function IsValidWorldInstance(t)
        if type(t) ~= "table" then return false end
        if getmetatable(t) == nil then return false end
        if rawget(t, "query") ~= nil then return false end
        if rawget(t, "entity_index") == nil and rawget(t, "archetypes") == nil then
            return false
        end
        local ok, hasMethods = pcall(function()
            return typeof(t.query) == "function"
                and typeof(t.contains) == "function"
                and typeof(t.get) == "function"
                and typeof(t.has) == "function"
        end)
        return ok and hasMethods == true
    end

    -- Phân biệt thực thể replecs ClientReplicator đang sống với bảng prototype class ClientReplicator (thực thể thật có rawget(t, "world") là jecs.World instance)
    local function IsValidReplicatorInstance(t, expectedWorld)
        if type(t) ~= "table" then return false end
        if getmetatable(t) == nil then return false end
        if rawget(t, "get_server_entity") ~= nil then return false end
        local repWorld = rawget(t, "world")
        if not IsValidWorldInstance(repWorld) then
            return false
        end
        if expectedWorld and repWorld ~= expectedWorld then
            return false
        end
        local ok, hasMethods = pcall(function()
            return typeof(t.get_server_entity) == "function"
                and typeof(t.get_client_entity) == "function"
        end)
        return ok and hasMethods == true
    end

    local function IsValidComponentsTable(t)
        return type(t) == "table"
            and rawget(t, "Player") ~= nil
            and rawget(t, "CurrentHealth") ~= nil
            and rawget(t, "Targetable") ~= nil
            and rawget(t, "Pack") ~= nil
    end

    local function ExtractWorldAndComponentsFromClosure(fn, getUpvals)
        if not (getUpvals and typeof(fn) == "function") then
            return nil, nil
        end
        local okU, uvs = pcall(getUpvals, fn)
        if not (okU and type(uvs) == "table") then
            return nil, nil
        end
        local wFound, cFound = nil, nil
        for _, uv in pairs(uvs) do
            if type(uv) == "table" then
                if not wFound and IsValidWorldInstance(uv) then
                    wFound = uv
                elseif not cFound and IsValidComponentsTable(uv) then
                    cFound = uv
                end
            end
        end
        return wFound, cFound
    end

    F.GetEcsContext = function()
        local cached = Session.cachedLiveEcs
        if cached
            and IsValidWorldInstance(cached.world)
            and IsValidReplicatorInstance(cached.replicator, cached.world)
            and cached.Components
            and cached.Packs then
            return cached.world, cached.Components, cached.Packs, cached.replicator, cached.TeamUtils
        end
        if os.clock() - Session.lastEcsGcScanAt < 2.0 and cached then
            return cached.world, cached.Components, cached.Packs, cached.replicator, cached.TeamUtils
        end
        Session.lastEcsGcScanAt = os.clock()

        local getConns = (typeof(getconnections) == "function" and getconnections)
            or (typeof(get_signal_connections) == "function" and get_signal_connections)
            or nil
        local getUpvals = (type(debug) == "table" and typeof(debug.getupvalues) == "function" and debug.getupvalues)
            or (typeof(getupvalues) == "function" and getupvalues)
            or nil

        local liveWorld, liveComponents, livePacks, liveReplicator, liveTeamUtils = nil, nil, nil, nil, nil

        -- 1. Bắt trực tiếp live replicator, world, Components từ kết nối OnClientEvent đang chạy của game (O(1))
        if getConns and getUpvals then
            for _, remoteName in ipairs({ "Entity_PlayAnimation", "Entity_PlayEffect", "StageScene_Shout", "Action_Bark" }) do
                local rem = GetNetworkRemote(remoteName)
                if rem and rem:IsA("RemoteEvent") then
                    local okC, conns = pcall(getConns, rem.OnClientEvent)
                    EnsureHighIdentity()
                    if okC and type(conns) == "table" then
                        for _, conn in ipairs(conns) do
                            local fn = type(conn) == "table" and (conn.Function or conn.Callback)
                                or (typeof(conn) == "userdata" and pcall(function() return conn.Function end) and conn.Function)
                                or nil
                            if typeof(fn) == "function" then
                                local okU, upvals = pcall(getUpvals, fn)
                                if okU and type(upvals) == "table" then
                                    for _, uv in pairs(upvals) do
                                        if type(uv) == "table" then
                                            if not liveReplicator and IsValidReplicatorInstance(uv, liveWorld) then
                                                liveReplicator = uv
                                                liveWorld = liveWorld or rawget(uv, "world")
                                            elseif not liveWorld and IsValidWorldInstance(uv) then
                                                liveWorld = uv
                                            elseif not liveComponents and IsValidComponentsTable(uv) then
                                                liveComponents = uv
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if liveWorld and liveReplicator and liveComponents then
                    break
                end
            end
        end

        -- 2. Kiểm tra các module nạp qua GetGameModule (SafeRequire ở Identity 2)
        local modWorld = GetGameModule("ecs_world", { "Shared", "ecs", "world" })
        local modComponents = GetGameModule("Components", { "Shared", "Components" })
        local modPacks = GetGameModule("Packs", { "Shared", "combat", "Packs" })
        local modReplicator = GetGameModule("replicator", { "Client", "replicator" })
        local modTeamUtils = GetGameModule("TeamUtils", { "Shared", "utils", "TeamUtils" })

        if type(modPacks) == "table" and typeof(modPacks.isLivePack) == "function" and getUpvals then
            local packW, packC = ExtractWorldAndComponentsFromClosure(modPacks.isLivePack, getUpvals)
            if packW and (not liveWorld or packW == liveWorld) then
                liveWorld = liveWorld or packW
                liveComponents = liveComponents or packC
                livePacks = modPacks
            end
        end

        if not liveWorld and IsValidWorldInstance(modWorld) then
            liveWorld = modWorld
        end
        if not liveComponents and IsValidComponentsTable(modComponents) then
            liveComponents = modComponents
        end
        if not liveReplicator and IsValidReplicatorInstance(modReplicator, liveWorld) then
            liveReplicator = modReplicator
            liveWorld = liveWorld or rawget(modReplicator, "world")
        end
        if not livePacks and type(modPacks) == "table" and (not liveWorld or modWorld == liveWorld) then
            livePacks = modPacks
        end
        if not liveTeamUtils and type(modTeamUtils) == "table" and (not liveWorld or modWorld == liveWorld) then
            liveTeamUtils = modTeamUtils
        end

        -- 3. Nếu Executor tách cache require() khiến thiếu livePacks / liveReplicator / liveTeamUtils của đúng liveWorld, quét GC với bộ lọc instance chuẩn
        if not (liveWorld and liveComponents and livePacks and liveReplicator) then
            local gcFn = (typeof(getgc) == "function" and getgc) or nil
            if gcFn then
                local okGc, list = pcall(gcFn, true)
                EnsureHighIdentity()
                if okGc and type(list) == "table" then
                    for i = 1, #list do
                        local obj = list[i]
                        if type(obj) == "table" then
                            if not liveReplicator and IsValidReplicatorInstance(obj, liveWorld) then
                                liveReplicator = obj
                                liveWorld = liveWorld or rawget(obj, "world")
                            elseif typeof(rawget(obj, "activeSummaries")) == "function" and typeof(rawget(obj, "isLivePack")) == "function" then
                                local wCandidate, cCandidate = ExtractWorldAndComponentsFromClosure(rawget(obj, "isLivePack"), getUpvals)
                                if wCandidate and (not liveWorld or wCandidate == liveWorld) then
                                    livePacks = obj
                                    liveWorld = liveWorld or wCandidate
                                    liveComponents = liveComponents or cCandidate
                                elseif not livePacks then
                                    livePacks = obj
                                end
                            elseif not liveTeamUtils and typeof(rawget(obj, "areEntitiesHostile")) == "function" then
                                if getUpvals then
                                    local wCandidate = ExtractWorldAndComponentsFromClosure(rawget(obj, "areEntitiesHostile"), getUpvals)
                                    if not liveWorld or not wCandidate or wCandidate == liveWorld then
                                        liveTeamUtils = obj
                                    end
                                else
                                    liveTeamUtils = obj
                                end
                            elseif not liveComponents and IsValidComponentsTable(obj) then
                                liveComponents = obj
                            end
                        end
                    end
                end
            end
        end
        EnsureHighIdentity()

        liveWorld = (IsValidWorldInstance(liveWorld) and liveWorld) or (IsValidWorldInstance(modWorld) and modWorld) or nil
        liveComponents = liveComponents or modComponents
        livePacks = livePacks or modPacks
        liveReplicator = (IsValidReplicatorInstance(liveReplicator, liveWorld) and liveReplicator)
            or (IsValidReplicatorInstance(modReplicator, liveWorld) and modReplicator)
            or (IsValidReplicatorInstance(liveReplicator, nil) and liveReplicator)
            or (IsValidReplicatorInstance(modReplicator, nil) and modReplicator)
            or nil
        liveTeamUtils = liveTeamUtils or modTeamUtils

        if liveWorld and liveComponents and livePacks and liveReplicator then
            Session.cachedLiveEcs = {
                world = liveWorld,
                Components = liveComponents,
                Packs = livePacks,
                replicator = liveReplicator,
                TeamUtils = liveTeamUtils
            }
            return liveWorld, liveComponents, livePacks, liveReplicator, liveTeamUtils
        end
        return nil
    end
end)()

function F.FindLocalPlayerEntity(world, Components)
    if Session.cachedLocalEntity then
        local okHas, stillValid = pcall(function()
            return world:contains(Session.cachedLocalEntity) and world:get(Session.cachedLocalEntity, Components.Player) == LocalPlayer
        end)
        if okHas and stillValid then
            return Session.cachedLocalEntity
        end
        Session.cachedLocalEntity = nil
    end
    for entity, player in world:query(Components.Player) do
        if player == LocalPlayer then
            Session.cachedLocalEntity = entity
            return entity
        end
    end
    return nil
end

function F.GetCharacterElement(characterId)
    if type(characterId) ~= "string" or characterId == "" then return nil end
    local cached = Session.characterElementCache[characterId]
    if cached ~= nil then
        return cached or nil
    end
    local charDefs = GetGameModule("CharacterDefs", { "Shared", "CharacterDefs" })
    if type(charDefs) == "table" and typeof(charDefs.get) == "function" then
        local okD, def = SafeCallGame(charDefs.get, characterId)
        if okD and type(def) == "table" then
            local elem = type(def.element) == "string" and def.element or false
            Session.characterElementCache[characterId] = elem
            return elem or nil
        end
    end
    return nil
end

-- Kiểm tra Pack có quái thù địch hợp lệ, đồng thời kiểm tra bộ lọc Multi Quái hoặc mục tiêu Quest
function F.EvaluateHostilePack(world, Components, TeamUtils, localEntity, localTeam, summary, ignoreMobFilter)
    if not (summary and type(summary.members) == "table") then
        return false, false, nil
    end
    if localTeam and summary.team == localTeam then
        return false, false, nil
    end

    local isOverworld = tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld") == "overworld"
    local questMobMap = isOverworld and Session.questOverrideMobIds or nil
    local questElem = isOverworld and Session.questOverrideElement or nil
    local selectedSet, selectedCount = F.GetActiveSelectedMobsSet()
    -- Khi đang làm nhiệm vụ NPC có mục tiêu quái cụ thể (questMobMap / questElem) hoặc đang ở trong Raid/Mission (ignoreMobFilter),
    -- không để bộ lọc Multi Quái thường chặn mục tiêu nhiệm vụ!
    local useUserMobFilter = (not ignoreMobFilter) and isOverworld and (not questMobMap) and (not questElem) and Config.FilterBySelectedMobs and selectedCount > 0

    local hasValidTarget = false
    local hasBoss = false
    local matchedFilter = false
    local sampleCharId = nil

    for _, member in ipairs(summary.members) do
        local hostile = true
        if TeamUtils and localEntity and typeof(TeamUtils.areEntitiesHostile) == "function" then
            local okH, isH = SafeCallGame(TeamUtils.areEntitiesHostile, localEntity, member)
            if okH then hostile = isH end
        end
        if hostile then
            local targetable = world:has(member, Components.Targetable)
            local sealed = Components.Sealed and world:has(member, Components.Sealed) or false
            local unhurtable = Components.Unhurtable and world:has(member, Components.Unhurtable) or false
            if targetable and not sealed and not unhurtable then
                hasValidTarget = true
                local charId = Components.Character and world:get(member, Components.Character) or nil
                if type(charId) == "string" and not sampleCharId then
                    sampleCharId = charId
                end
                if (Components.Boss and world:has(member, Components.Boss))
                    or (Components.OverworldBoss and world:has(member, Components.OverworldBoss)) then
                    hasBoss = true
                end

                if useUserMobFilter then
                    if type(charId) == "string" and selectedSet[charId] then
                        matchedFilter = true
                        sampleCharId = charId
                    end
                elseif questMobMap then
                    if type(charId) == "string" and questMobMap[charId] then
                        matchedFilter = true
                        sampleCharId = charId
                    end
                elseif questElem then
                    if type(charId) == "string" and F.GetCharacterElement(charId) == questElem then
                        matchedFilter = true
                        sampleCharId = charId
                    end
                else
                    matchedFilter = true
                end
            end
        end
    end

    if not hasValidTarget or not matchedFilter then
        return false, false, nil
    end
    return true, hasBoss, sampleCharId
end

-- Tọa độ tâm từng khu vực Overworld (từ OverworldMode: u100[v] = Vector3.new(v99[(i - 1) % 3 + 1], 0, (i - 1) // 3) * 8000, AREA_SPAN = 5000)
local OverworldAreaCenters = {
    champion_city = Vector3.new(0, 0, 0),
    alien = Vector3.new(8000, 0, 0),
    pirate = Vector3.new(-8000, 0, 0),
    ninja = Vector3.new(0, 0, 8000),
    city = Vector3.new(8000, 0, 8000),
    ant = Vector3.new(-8000, 0, 8000)
}

function F.DetectOverworldAreaByPosition()
    if tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld") ~= "overworld" then
        return nil
    end
    local hrp = GetRootPart()
    if not hrp then return nil end
    local pos = hrp.Position
    local flatPos = Vector3.new(pos.X, 0, pos.Z)
    local bestArea, bestDist = nil, 2600 -- AREA_SPAN / 2 = 2500
    local overworldCfg = GetGameModule("OverworldMode", { "Config", "OverworldMode" })
    for areaId, fallbackCenter in pairs(OverworldAreaCenters) do
        local center = fallbackCenter
        if type(overworldCfg) == "table" and typeof(overworldCfg.getAreaMap) == "function" then
            if areaId == (overworldCfg.CITY_ID or "champion_city") then
                center = Vector3.zero
            else
                local okM, _, runtimeCenter = SafeCallGame(overworldCfg.getAreaMap, areaId)
                if okM and typeof(runtimeCenter) == "Vector3" then
                    center = runtimeCenter
                end
            end
        end
        local dist = (flatPos - Vector3.new(center.X, 0, center.Z)).Magnitude
        if dist < bestDist then
            bestDist = dist
            bestArea = areaId
        end
    end
    return bestArea
end

function F.GetCurrentOverworldArea()
    local attrArea = LocalPlayer:GetAttribute(C.OverworldAreaAttribute)
        or LocalPlayer:GetAttribute("OverworldWorldId")
        or LocalPlayer:GetAttribute("OverworldArea")
    if type(attrArea) == "string" and attrArea ~= "" then
        Session.lastKnownArea = attrArea
        return attrArea
    end

    local uiGlobals = GetGameModule("UIGlobals", { "Client", "services", "ClientUIService", "UIGlobals" })
    local fusion = GetGameModule("Fusion", { "Packages", "Fusion" })
    if type(uiGlobals) == "table" and type(fusion) == "table" and typeof(fusion.peek) == "function" then
        if uiGlobals.AreaId then
            local okA, aId = SafeCallGame(fusion.peek, uiGlobals.AreaId)
            if okA and type(aId) == "string" and aId ~= "" then
                Session.lastKnownArea = aId
                return aId
            end
        end
        if uiGlobals.InCity then
            local okC, inCity = SafeCallGame(fusion.peek, uiGlobals.InCity)
            if okC and inCity == true then
                Session.lastKnownArea = "champion_city"
                return "champion_city"
            end
        end
    end

    local posArea = F.DetectOverworldAreaByPosition()
    if type(posArea) == "string" and posArea ~= "" then
        Session.lastKnownArea = posArea
        return posArea
    end

    return Session.lastKnownArea or ""
end

function F.IsAlreadyInOverworldArea(targetAreaId)
    if type(targetAreaId) ~= "string" or targetAreaId == "" then
        return true
    end
    if F.GetCurrentOverworldArea() == targetAreaId then
        return true
    end
    if F.DetectOverworldAreaByPosition() == targetAreaId then
        return true
    end
    if Session.lastKnownArea == targetAreaId and (os.clock() - Session.lastSuccessfulTravelAt) < 12 then
        return true
    end
    return false
end

-- Dịch chuyển sang World bằng Overworld_Travel (chặn tự reload khi đã ở đúng World)
function F.TravelToWorld(areaId, silent)
    local target = tostring(areaId or Config.SelectedWorld or "")
    if target == "" then return false end
    if F.IsAlreadyInOverworldArea(target) then
        Session.lastKnownArea = target
        return true
    end
    local travelSvc = GetGameModule("ClientOverworldTravelService", { "Client", "services", "ClientOverworldTravelService" })
    if type(travelSvc) == "table" and typeof(travelSvc.Travel) == "function" then
        local ok, res = SafeCallGame(travelSvc.Travel, target)
        if ok and res ~= false then
            Session.lastKnownArea = target
            Session.lastSuccessfulTravelAt = os.clock()
            if not silent then Notify("Dịch Chuyển World", "Đã chuyển tới: " .. tostring(target), 3) end
            return true
        end
    end
    local pOk, poseOrErr = InvokeRemote("Overworld_Travel", target)
    if pOk and typeof(poseOrErr) == "CFrame" then
        TeleportCharacterTo(poseOrErr)
        Session.lastKnownArea = target
        Session.lastSuccessfulTravelAt = os.clock()
        if not silent then Notify("Dịch Chuyển World", "Đã dịch chuyển tới: " .. tostring(target), 3) end
        return true
    end
    if not silent then
        Notify("Dịch Chuyển World", "Không thể chuyển tới " .. tostring(target) .. ": " .. tostring(poseOrErr), 4)
    end
    return false
end

-- Đánh giá số lượng chiến binh (Unit) đang tử trận (Dying / KnockedOut / HP <= 0) và % máu thấp nhất của đội hình (có cache 0.25s chống quét lặp ECS)
function F.EvaluatePlayerUnitsHealthAndDowned()
    local now = os.clock()
    local hc = Session.healthCache
    if now - Session.lastHealthEvalAt < 0.25 then
        return hc.downCount, hc.totalUnits, hc.minHpPct, hc.avgHpPct, hc.foundUnits
    end
    Session.lastHealthEvalAt = now

    local rosterList = nil
    local rosterSvc = GetGameModule("ClientRosterService", { "Client", "services", "ClientRosterService" })
    local fusion = GetGameModule("Fusion", { "Packages", "Fusion" })
    if type(rosterSvc) == "table" and rosterSvc.ActiveRoster and type(fusion) == "table" and typeof(fusion.peek) == "function" then
        local okR, r = SafeCallGame(fusion.peek, rosterSvc.ActiveRoster)
        if okR and type(r) == "table" and #r > 0 then
            rosterList = r
        end
    end

    local world, Components = F.GetEcsContext()
    if not rosterList and world and Components and Components.ActiveRoster then
        local localEntity = F.FindLocalPlayerEntity(world, Components)
        if localEntity then
            local r = world:get(localEntity, Components.ActiveRoster)
            if type(r) == "table" and #r > 0 then
                rosterList = r
            end
        end
    end
    if not rosterList then
        rosterList = ReadStore("EquippedChampions", "table", true) or {}
    end

    local rosterSet = {}
    local totalUnits = 0
    for _, uid in ipairs(rosterList) do
        if type(uid) == "string" and uid ~= "" and not rosterSet[uid] then
            rosterSet[uid] = true
            totalUnits = totalUnits + 1
        end
    end

    if totalUnits == 0 then
        hc.downCount, hc.totalUnits, hc.minHpPct, hc.avgHpPct, hc.foundUnits = 0, 0, 1.0, 1.0, 0
        return 0, 0, 1.0, 1.0, 0
    end

    local foundUnits = 0
    local downCount = 0
    local minHpPct = 1.0
    local sumHpPct = 0

    if world and Components and Components.ChampionUID then
        local combatantMod = GetGameModule("Combatant", { "Shared", "combat", "Combatant" })
        local seenEntityUid = {}
        for entity, uid in world:query(Components.ChampionUID) do
            if type(uid) == "string" and rosterSet[uid] and not seenEntityUid[uid] then
                seenEntityUid[uid] = true
                foundUnits = foundUnits + 1

                local isDown = false
                if type(combatantMod) == "table" and typeof(combatantMod.isDowned) == "function" then
                    local okD, d = SafeCallGame(combatantMod.isDowned, entity)
                    if okD and d == true then
                        isDown = true
                    end
                end
                if not isDown then
                    if (Components.Dying and world:has(entity, Components.Dying))
                        or (Components.KnockedOut and world:has(entity, Components.KnockedOut)) then
                        isDown = true
                    end
                end

                local curHp = Components.CurrentHealth and world:get(entity, Components.CurrentHealth) or nil
                local maxHp = Components.MaxHealth and world:get(entity, Components.MaxHealth) or nil
                if type(curHp) == "number" and curHp <= 0 then
                    isDown = true
                end

                local hpPct = 1.0
                if isDown then
                    hpPct = 0.0
                    downCount = downCount + 1
                elseif type(curHp) == "number" and type(maxHp) == "number" and maxHp > 0 then
                    hpPct = math.clamp(curHp / maxHp, 0, 1)
                end

                if hpPct < minHpPct then
                    minHpPct = hpPct
                end
                sumHpPct = sumHpPct + hpPct
            end
        end
    end

    local combatState = tostring(LocalPlayer:GetAttribute("OverworldCombatState") or "")
    if combatState == "down" then
        downCount = totalUnits
        minHpPct = 0.0
        sumHpPct = 0.0
    end

    local avgHpPct = foundUnits > 0 and (sumHpPct / foundUnits) or 1.0
    if foundUnits == 0 and combatState ~= "down" then
        minHpPct = 1.0
        avgHpPct = 1.0
    end

    hc.downCount, hc.totalUnits, hc.minHpPct, hc.avgHpPct, hc.foundUnits = downCount, totalUnits, minHpPct, avgHpPct, foundUnits
    return downCount, totalUnits, minHpPct, avgHpPct, foundUnits
end

-- Nếu đang trong chế độ hồi phục mà nhân vật đứng quá sát bãi quái ở Overworld, lùi nhẹ ra ngoài tầm đánh để game tự hồi sinh & bơm máu
function F.StepBackFromNearestHostilePackForRecovery()
    if not Config.StepBackOnRecovery then return end
    if tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld") ~= "overworld" then return end
    if os.clock() - Session.lastRecoveryStepBackAt < 2.0 then return end

    local hrp = GetRootPart()
    if not hrp then return end
    local world, Components, Packs, _, TeamUtils = F.GetEcsContext()
    if not (world and Packs) then return end

    local localEntity = F.FindLocalPlayerEntity(world, Components)
    local localTeam = localEntity and Components.Team and world:get(localEntity, Components.Team) or "Players"
    local okSum, summaries = SafeCallGame(Packs.activeSummaries)
    if not (okSum and type(summaries) == "table") then return end

    local myPos = hrp.Position
    local nearestCentroid, nearestDist = nil, math.huge
    for _, summary in pairs(summaries) do
        if typeof(summary.centroid) == "Vector3" and summary.team ~= localTeam then
            local valid = F.EvaluateHostilePack(world, Components, TeamUtils, localEntity, localTeam, summary, true)
            if valid then
                local dist = (summary.centroid - myPos).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestCentroid = summary.centroid
                end
            end
        end
    end

    if nearestCentroid and nearestDist < 26 then
        Session.lastRecoveryStepBackAt = os.clock()
        local away = Vector3.new(myPos.X - nearestCentroid.X, 0, myPos.Z - nearestCentroid.Z)
        local dir = away.Magnitude > 0.5 and away.Unit or Vector3.new(0, 0, 1)
        TeleportCharacterTo(nearestCentroid + dir * 42)
    end
end

-- Cơ chế bảo vệ đội hình: nếu số unit chết >= ngưỡng (mặc định 2), tạm dừng toàn bộ chiến đấu & nhiệm vụ,
-- gọi RetreatUnits và chờ toàn bộ unit hồi sinh + bơm đầy 100% máu rồi mới tiếp tục.
function F.CheckTeamRecoveryPause()
    local downCount, totalUnits, minHpPct, avgHpPct, foundUnits = F.EvaluatePlayerUnitsHealthAndDowned()
    local minPctInt = math.floor(minHpPct * 100 + 0.5)
    local avgPctInt = math.floor(avgHpPct * 100 + 0.5)

    if not Config.PauseOnUnitsDead or totalUnits == 0 then
        Session.isRecoveringUnits = false
        Session.unitHealthSummaryText = string.format("Unit chết: %d/%d | Máu thấp nhất: %d%% (TB %d%%)", downCount, totalUnits, minPctInt, avgPctInt)
        return false, nil
    end

    local configuredThreshold = math.max(1, math.floor(tonumber(Config.DeadUnitsPauseThreshold) or 2))
    local effThreshold = math.min(configuredThreshold, totalUnits)
    local teamHealingAttr = LocalPlayer:GetAttribute("OverworldTeamHealing") == true
    local combatState = tostring(LocalPlayer:GetAttribute("OverworldCombatState") or "")

    if not Session.isRecoveringUnits then
        if downCount >= effThreshold then
            Session.isRecoveringUnits = true
            Session.lastRecoveryRetreatAt = os.clock()
            FireRemote("RetreatUnits")
            if Config.AutoInGameAttack then
                FireRemote("SetAutoAttack", false)
            end
            F.StepBackFromNearestHostilePackForRecovery()
            Notify("Tạm Dừng Hồi Phục Đội Hình", string.format("Có %d/%d unit tử trận! Tạm dừng mọi chiến đấu & nhiệm vụ chờ hồi sinh và bơm đầy 100%% máu.", downCount, totalUnits), 4)
        end
    end

    if Session.isRecoveringUnits then
        local allAlive = (downCount == 0) and (foundUnits == 0 or foundUnits >= totalUnits) and (combatState ~= "down")
        local allFullHp = (minHpPct >= 0.995) and (not teamHealingAttr)
        if allAlive and allFullHp then
            Session.isRecoveringUnits = false
            if Config.AutoInGameAttack then
                FireRemote("SetAutoAttack", true)
            end
            Session.unitHealthSummaryText = string.format("Đội hình khỏe mạnh: 0/%d chết | Máu: 100%% (Sẵn sàng chiến đấu)", totalUnits)
            Notify("Hồi Phục 100% Hoàn Tất", string.format("Toàn bộ %d/%d unit đã hồi sinh và đầy 100%% máu! Tiếp tục công việc.", totalUnits, totalUnits), 3)
            return false, nil
        end

        if os.clock() - Session.lastRecoveryRetreatAt >= 1.5 then
            Session.lastRecoveryRetreatAt = os.clock()
            FireRemote("RetreatUnits")
            if Config.AutoInGameAttack then
                FireRemote("SetAutoAttack", false)
            end
        end
        F.StepBackFromNearestHostilePackForRecovery()

        local reason = string.format("Đang chờ unit hồi sinh & bơm 100%% máu (%d/%d chết | Máu thấp nhất: %d%%)", downCount, totalUnits, minPctInt)
        Session.unitHealthSummaryText = "[ĐANG HỒI PHỤC] " .. reason
        return true, reason
    end

    Session.unitHealthSummaryText = string.format("Đội hình: %d/%d chết | Máu thấp nhất: %d%% (TB %d%%)", downCount, totalUnits, minPctInt, avgPctInt)
    return false, nil
end

function F.TryEngageNearestPack(forceTeleportInRun)
    local hrp = GetRootPart()
    if not hrp then return false, "chưa có nhân vật" end

    local pausedForHeal, healReason = F.CheckTeamRecoveryPause()
    if pausedForHeal then
        return false, healReason
    end

    local gamemode = tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld")
    local isOverworld = (gamemode == "overworld")
    if isOverworld and Config.AutoTravelToCombatWorld and not Config.AutoWorldNpcQuestLoop then
        if not F.IsAlreadyInOverworldArea(Config.CombatWorld) and os.clock() - Session.lastQuestTravelAt > 6 then
            Session.lastQuestTravelAt = os.clock()
            F.TravelToWorld(Config.CombatWorld, true)
            return false, "đang chuyển sang World " .. tostring(Config.CombatWorld)
        end
    end

    local world, Components, Packs, replicator, TeamUtils = F.GetEcsContext()
    if not world then
        return false, "chưa nạp được ECS world"
    end

    local localEntity = F.FindLocalPlayerEntity(world, Components)
    local localTeam = localEntity and Components.Team and world:get(localEntity, Components.Team) or "Players"

    local okSum, summaries = SafeCallGame(Packs.activeSummaries)
    if not (okSum and type(summaries) == "table") then
        return false, "không đọc được Packs.activeSummaries"
    end

    local hasQuestOverride = isOverworld and (Session.questOverrideMobIds ~= nil or Session.questOverrideElement ~= nil)
    local isQuestAutoCombat = Config.AutoWorldNpcQuestLoop and (not isOverworld or Session.questCombatActive or hasQuestOverride)
    local inRunMode = not isOverworld
    local forceTele = inRunMode or (forceTeleportInRun == true) or isQuestAutoCombat
    local maxDist = (forceTele and 5000)
        or (hasQuestOverride and math.max(tonumber(Config.EngageMaxDist) or 150, 5000))
        or (tonumber(Config.EngageMaxDist) or 150)
    local myPos = hrp.Position

    local function selectBestPack(ignoreFilterFlag)
        local bPack, bSummary, bDist, bFlatDist, bIsBoss, bCharId = nil, nil, math.huge, math.huge, false, nil
        for packEntity, summary in pairs(summaries) do
            if typeof(summary.centroid) == "Vector3" then
                local valid, isBoss, sampleChar = F.EvaluateHostilePack(world, Components, TeamUtils, localEntity, localTeam, summary, ignoreFilterFlag)
                if valid then
                    local delta = summary.centroid - myPos
                    local dist = delta.Magnitude
                    local flatDist = math.sqrt(delta.X * delta.X + delta.Z * delta.Z)
                    if dist <= maxDist then
                        local take = false
                        if Config.PrioritizeBoss and isBoss and not bIsBoss then
                            take = true
                        elseif (not Config.PrioritizeBoss or isBoss == bIsBoss) and dist < bDist then
                            take = true
                        end
                        if take then
                            bPack = packEntity
                            bSummary = summary
                            bDist = dist
                            bFlatDist = flatDist
                            bIsBoss = isBoss
                            bCharId = sampleChar
                        end
                    end
                end
            end
        end
        return bPack, bSummary, bDist, bFlatDist, bIsBoss, bCharId
    end

    -- Trong Raid/Stage/Boss/Defense luôn bỏ qua bộ lọc quái Overworld; ở Overworld thì lọc theo Quest hoặc Multi Quái trước
    local bestPack, bestSummary, bestDist, bestFlatDist, bestIsBoss, bestCharId = selectBestPack(inRunMode)
    if not bestPack and isOverworld and hasQuestOverride then
        bestPack, bestSummary, bestDist, bestFlatDist, bestIsBoss, bestCharId = selectBestPack(true)
    end

    if not (bestPack and bestSummary) then
        return false, "không có nhóm quái khớp bộ lọc trong tầm"
    end

    local okSrv, serverEntity = SafeCallGame(replicator.get_server_entity, replicator, bestPack)
    if not (okSrv and serverEntity) then
        return false, "chưa đồng bộ serverEntity của pack"
    end

    -- Server kiểm tra vector.flatten(centroid - playerPos).Magnitude <= CombatConfig.ATTACK_ORDER.MAX_DISTANCE (40 studs).
    local maxOrderRange = tonumber(C.AttackOrderMaxDistance) or 40
    local needsRangeApproach = bestFlatDist > (maxOrderRange - 6)
    local shouldTeleport = Config.TeleportToPack or forceTele or needsRangeApproach or (hasQuestOverride and bestDist > (tonumber(Config.EngageMaxDist) or 150))
    if shouldTeleport and (bestFlatDist > 16 or bestDist > 22) then
        local dir = (myPos - bestSummary.centroid)
        local flatDir = Vector3.new(dir.X, 0, dir.Z)
        local offset = flatDir.Magnitude > 0.5 and (flatDir.Unit * 10) or Vector3.new(0, 0, 10)
        TeleportCharacterTo(bestSummary.centroid + offset)
        task.wait(0.12)
    end

    local now = os.clock()
    local isAlreadyTargeting = false
    local hostileFocus = GetGameModule("HostileFocus", { "Client", "HostileFocus" })
    if type(hostileFocus) == "table" and typeof(hostileFocus.resolve) == "function" then
        local okF, focus = SafeCallGame(hostileFocus.resolve)
        if okF and type(focus) == "table" and type(focus.packSet) == "table" and focus.packSet[bestPack] == true then
            isAlreadyTargeting = true
        end
    end
    if not isAlreadyTargeting and localEntity and typeof(Packs.ownedPack) == "function" and Components.PackAttackOrder then
        local okP, playerPack = SafeCallGame(Packs.ownedPack, localEntity)
        if okP and playerPack then
            local okT, currentOrder = pcall(world.target, world, playerPack, Components.PackAttackOrder)
            if okT and currentOrder == bestPack then
                isAlreadyTargeting = true
            end
        end
    end

    local alreadyEngaged = isAlreadyTargeting
        and (Session.lastPackEntity == serverEntity)
        and (now - Session.lastPackTime < 1.5)

    if not alreadyEngaged then
        FireRemote("EngagePack", serverEntity)
        Session.lastPackEntity = serverEntity
        Session.lastPackTime = now
        Session.lastPackName = bestCharId
    end
    return true, string.format("Pack #%s [%s] (%.0f studs%s)", tostring(serverEntity), tostring(bestCharId or "?"), bestDist, bestIsBoss and ", BOSS" or "")
end

function F.FireAllEquippedAbilities()
    if Session.isRecoveringUnits then return 0 end
    local equipped = ReadStore("EquippedChampions", "table", true)
    if type(equipped) ~= "table" then return 0 end
    local abilitySvc = Config.OnlyCastReadyAbilities and GetGameModule("ClientChampionAbilityService", { "Client", "services", "ClientChampionAbilityService" }) or nil
    local count = 0
    for _, uid in ipairs(equipped) do
        if type(uid) == "string" and uid ~= "" then
            local canCast = true
            if type(abilitySvc) == "table" and typeof(abilitySvc.IsReady) == "function" then
                local okR, isReady = SafeCallGame(abilitySvc.IsReady, uid)
                if okR and isReady == false then
                    canCast = false
                end
            end
            if canCast and FireRemote("UseChampionAbility", uid) then
                count = count + 1
            end
        end
    end
    return count
end

function F.ClaimDropById(dropId)
    if not dropId or Session.claimedDrops[dropId] then return false end
    Session.claimedDrops[dropId] = os.clock()
    FireRemote("ClaimDrop", dropId)
    return true
end

function F.ScanAndClaimEcsDrops()
    local world, Components = F.GetEcsContext()
    if not (world and Components and Components.DropInfo) then return 0 end
    local count = 0
    for _, dropInfo in world:query(Components.DropInfo) do
        if type(dropInfo) == "table" and dropInfo.id then
            if type(dropInfo.group) == "table" then
                dropInfo.group.claimed = true
            end
            if F.ClaimDropById(dropInfo.id) then
                count = count + 1
            end
        end
    end
    return count
end

function F.ConnectNetworkEventListeners()
    local awardRemote = GetNetworkRemote("AwardDrops")
    if awardRemote and awardRemote:IsA("RemoteEvent") then
        TrackConnection(awardRemote.OnClientEvent:Connect(function(dropsPayload)
            if not (Running and (Config.AutoCollectDrops or Config.AutoUniversalModeFarm or Config.AutoWorldNpcQuestLoop) and type(dropsPayload) == "table") then
                return
            end
            task.spawn(function()
                task.wait(0.1)
                for _, entry in ipairs(dropsPayload) do
                    if type(entry) == "table" and entry.id then
                        F.ClaimDropById(entry.id)
                    end
                end
                F.ScanAndClaimEcsDrops()
            end)
        end))
    end

    local talkOpenRemote = GetNetworkRemote("MissionTalk_Open")
    if talkOpenRemote and talkOpenRemote:IsA("RemoteEvent") then
        TrackConnection(talkOpenRemote.OnClientEvent:Connect(function(runId)
            if type(runId) == "string" and runId ~= "" then
                Session.lastMissionTalkRunId = runId
                if Running and (Config.AutoSkipDialogue or Config.AutoUniversalModeFarm or Config.AutoWorldNpcQuestLoop) then
                    task.spawn(function()
                        task.wait(0.15)
                        FireRemote("MissionTalk_Ended", runId)
                        FireRemote("StageScene_Continue")
                    end)
                end
            end
        end))
    end

    local transBegin = GetNetworkRemote("TeleportTransition_Begin")
    if transBegin and transBegin:IsA("RemoteEvent") then
        TrackConnection(transBegin.OnClientEvent:Connect(function(token)
            if Running and (Config.AutoSkipTransitions or Config.AutoUniversalModeFarm or Config.AutoWorldNpcQuestLoop) and type(token) == "string" then
                task.spawn(function()
                    task.wait(0.05)
                    FireRemote("TeleportTransition_Ready", token)
                end)
            end
        end))
    end

    local transArrive = GetNetworkRemote("TeleportTransition_Arrive")
    if transArrive and transArrive:IsA("RemoteEvent") then
        TrackConnection(transArrive.OnClientEvent:Connect(function()
            if Running and (Config.AutoSkipTransitions or Config.AutoUniversalModeFarm or Config.AutoWorldNpcQuestLoop) then
                task.spawn(function()
                    task.wait(0.05)
                    FireRemote("PlayerArrival_Presented")
                end)
            end
        end))
    end

    local resShow = GetNetworkRemote("ResourcesGet_Show")
    if resShow and resShow:IsA("RemoteEvent") then
        TrackConnection(resShow.OnClientEvent:Connect(function(_, options)
            if Running and (Config.AutoDismissPopups or Config.AutoUniversalModeFarm or Config.AutoWorldNpcQuestLoop) then
                task.spawn(function()
                    task.wait(0.1)
                    local popupId = type(options) == "table" and options.popupId or nil
                    FireRemote("ResourcesGet_Dismissed", popupId)
                end)
            end
        end))
    end

    local inviteRecv = GetNetworkRemote("Lobby_InviteReceived")
    if inviteRecv and inviteRecv:IsA("RemoteEvent") then
        -- Chữ ký thực tế trong ClientLobbyService: OnClientEvent(inviterName: string, lobbyId: string, inviteData: table)
        TrackConnection(inviteRecv.OnClientEvent:Connect(function(inviterName, lobbyId, inviteData)
            if not (Running and Config.AutoAcceptPartyInvites) then
                return
            end
            local targetLobbyId = (type(lobbyId) == "string" and lobbyId ~= "" and lobbyId) or inviterName
            if not targetLobbyId then return end
            if Config.AcceptPartyFriendsOnly then
                local inviterUid = type(inviteData) == "table" and tonumber(inviteData.inviterUserId) or nil
                if inviterUid then
                    local okF, isF = pcall(LocalPlayer.IsFriendsWith, LocalPlayer, inviterUid)
                    if not (okF and isF == true) then
                        return
                    end
                end
            end
            task.spawn(function()
                task.wait(0.1)
                FireRemote("Lobby_RespondToInvite", targetLobbyId, true)
                Notify("Tổ Đội (Party)", "Đã tự đồng ý lời mời vào Party của " .. tostring(inviterName or "?"), 3)
            end)
        end))
    end

    local lobbyUpdated = GetNetworkRemote("LobbyState_Updated")
    if lobbyUpdated and lobbyUpdated:IsA("RemoteEvent") then
        TrackConnection(lobbyUpdated.OnClientEvent:Connect(function(lobbyPayload)
            Session.currentLobby = type(lobbyPayload) == "table" and lobbyPayload or nil
            if Session.currentLobby == nil then
                table.clear(Session.invitedFriendsMap)
            end
        end))
    end

    local bossCd = GetNetworkRemote("OverworldBoss_ChestCooldown")
    if bossCd and bossCd:IsA("RemoteEvent") then
        TrackConnection(bossCd.OnClientEvent:Connect(function(bossCharId, secondsLeft)
            Session.bossChestCooldownText = string.format("%s: còn %ds", tostring(bossCharId), math.ceil(tonumber(secondsLeft) or 0))
        end))
    end

    local matchSnap = GetNetworkRemote("MatchResults_Snapshot")
    if matchSnap and matchSnap:IsA("RemoteEvent") then
        TrackConnection(matchSnap.OnClientEvent:Connect(function(snapshot)
            if type(snapshot) == "table" then
                if snapshot.runId and snapshot.runId ~= Session.currentRunId then
                    Session.currentRunId = snapshot.runId
                    Session.matchOutcome = nil
                    Session.currentVoteOption = nil
                    Session.lastVotedRunId = nil
                    Session.lastVotedChoice = nil
                end
                Session.matchSnapshot = snapshot
                if type(snapshot.status) == "string" and snapshot.status ~= "ongoing" then
                    Session.matchOutcome = snapshot.status
                end
            end
        end))
    end

    local matchVoteState = GetNetworkRemote("MatchResults_VoteState")
    if matchVoteState and matchVoteState:IsA("RemoteEvent") then
        TrackConnection(matchVoteState.OnClientEvent:Connect(function(voteState)
            if type(voteState) == "table" and type(voteState.votes) == "table" then
                local myVote = nil
                for _, entry in ipairs(voteState.votes) do
                    if type(entry) == "table" and entry.userId == LocalPlayer.UserId and not entry.resolved then
                        myVote = entry.option
                        break
                    end
                end
                Session.currentVoteOption = myVote
            end
        end))
    end

    local matchBanner = GetNetworkRemote("MatchResults_OutcomeBanner")
    if matchBanner and matchBanner:IsA("RemoteEvent") then
        TrackConnection(matchBanner.OnClientEvent:Connect(function(outcome)
            if type(outcome) == "string" and outcome ~= "ongoing" then
                Session.matchOutcome = outcome
            end
        end))
    end

    local runReset = GetNetworkRemote("Gamemode_RunReset")
    if runReset and runReset:IsA("RemoteEvent") then
        TrackConnection(runReset.OnClientEvent:Connect(function()
            Session.matchSnapshot = nil
            Session.matchOutcome = nil
            Session.currentVoteOption = nil
            Session.lastVotedRunId = nil
            Session.lastVotedChoice = nil
            table.clear(Session.openedChests)
        end))
    end
end

function F.HasUnopenedChestInWorkspace()
    for _, chest in ipairs(CollectionService:GetTagged(C.ChestTag)) do
        if chest:IsDescendantOf(Workspace) then
            local chestId = chest:GetAttribute(C.ChestIdAttribute) or chest.Name
            local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            if type(chestId) == "string" and chestId ~= "" and not Session.openedChests[chestId] then
                if not prompt or prompt.Enabled then
                    return true, chest, chestId
                end
            end
        end
    end
    return false, nil, nil
end

function F.ScanAndOpenChests(forceTeleportToChest)
    local count = 0
    for _, chest in ipairs(CollectionService:GetTagged(C.ChestTag)) do
        if chest:IsDescendantOf(Workspace) then
            local chestId = chest:GetAttribute(C.ChestIdAttribute) or chest.Name
            if type(chestId) == "string" and chestId ~= "" and not Session.openedChests[chestId] then
                if Config.TeleportToChestBeforeOpen or forceTeleportToChest then
                    local pos = chest:IsA("Model") and chest:GetPivot().Position or (chest:IsA("BasePart") and chest.Position or nil)
                    if pos then
                        TeleportCharacterTo(pos)
                        task.wait(0.08)
                    end
                end
                Session.openedChests[chestId] = os.clock()
                FireRemote("OpenChest", chestId)
                count = count + 1
            end
        end
    end
    return count
end

function F.GetBoostRemainingSeconds(itemId)
    local kind = C.BoosterKindMap[itemId] or itemId:gsub("_booster$", "")
    local boostSvc = GetGameModule("ClientBoostService", { "Client", "services", "ClientBoostService" })
    local fusion = GetGameModule("Fusion", { "Packages", "Fusion" })
    if type(boostSvc) == "table" and type(boostSvc.Remaining) == "table" and boostSvc.Remaining[kind] and type(fusion) == "table" and typeof(fusion.peek) == "function" then
        local okP, rem = SafeCallGame(fusion.peek, boostSvc.Remaining[kind])
        if okP and type(rem) == "number" then
            return rem
        end
    end
    local boosts = ReadStore("Boosts", "table")
    local stats = ReadStore("Stats", "table")
    local playtime = stats and tonumber(stats.TotalPlaytimeSeconds) or nil
    if type(boosts) == "table" and playtime then
        local expireAt = tonumber(boosts[kind]) or 0
        return math.max(0, math.ceil(expireAt - playtime))
    end
    return 0
end

function F.TryUseTimedBooster(itemId)
    local target = itemId or Config.SelectedTimedBoost
    local owned = ReadStore("Items/" .. tostring(target), "number") or 0
    if owned < 1 then
        return false, "không có " .. tostring(target) .. " trong túi"
    end
    local rem = F.GetBoostRemainingSeconds(target)
    if rem > 3 then
        return false, string.format("đang còn hiệu lực (%ds)", rem)
    end
    local pOk, res = InvokeRemote("UseBooster", target)
    if pOk and type(res) == "table" and res.success then
        return true, string.format("Đã bật %s (%ds)", tostring(target), tonumber(res.remaining) or 0)
    end
    return false, tostring((type(res) == "table" and res.reason) or res or "bị từ chối")
end

-- ============================================================================
-- [7] BOSS, STORY MISSION, QUESTGO, SMART RAID CARDS, DEFENSE & MATCH RESULTS
-- ============================================================================
function F.RepairSingle(repairId)
    local pOk, ok, err = InvokeRemote("RepairObject", repairId)
    if pOk and ok == true then
        Session.knownRepaired[repairId] = true
        return true, nil
    end
    return false, tostring(err or ok or "chưa đủ điều kiện")
end

function F.ChallengeSelectedBoss(worldId)
    local targetWorld = tostring(worldId or Config.SelectedBossWorld or "alien")
    if tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld") ~= "overworld" then
        return false, "đang ở trong màn chơi khác"
    end

    local portalRepairId = targetWorld .. "_boss_portal"
    local repairedMap = ReadStore("Repaired", "table", true)
    if not ((type(repairedMap) == "table" and repairedMap[portalRepairId] == true) or Session.knownRepaired[portalRepairId] == true) then
        F.RepairSingle(portalRepairId)
    end

    -- 1. Thử gửi ChallengeBoss trực tiếp
    local pOk, ok, err = InvokeRemote("ChallengeBoss", targetWorld)
    if pOk and ok == true then
        return true, "Đã vào Boss " .. tostring(targetWorld)
    end

    -- 2. Nếu bị từ chối vì chưa đứng tại BossGate hoặc chưa ở đúng World: warp thẳng tới "gate:<worldId>" rồi khiêu chiến lại
    if os.clock() - (Session.lastBossWarpAt or 0) >= 2.0 then
        Session.lastBossWarpAt = os.clock()
        local wOk, pose = InvokeRemote("HubWarp_Request", "gate:" .. targetWorld)
        if wOk and typeof(pose) == "CFrame" then
            TeleportCharacterTo(pose)
            Session.lastKnownArea = targetWorld
            Session.lastSuccessfulTravelAt = os.clock()
            task.wait(0.18)
        else
            if not F.IsAlreadyInOverworldArea(targetWorld) then
                F.TravelToWorld(targetWorld, true)
                task.wait(0.2)
            end
            for _, inst in ipairs(CollectionService:GetTagged("BossGate")) do
                if inst:IsA("Model") and inst:IsDescendantOf(Workspace) and inst:GetAttribute("WorldId") == targetWorld then
                    TeleportCharacterTo(inst:GetPivot().Position + Vector3.new(0, 3, 6))
                    task.wait(0.15)
                    break
                end
            end
        end
        F.RepairSingle(portalRepairId)
        pOk, ok, err = InvokeRemote("ChallengeBoss", targetWorld)
        if pOk and ok == true then
            return true, "Đã warp tới cổng & vào Boss " .. tostring(targetWorld)
        end
    end

    return false, tostring(err or ok or "chưa mở cổng Boss hoặc đang hồi")
end

function F.RunActiveQuestGo()
    if tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld") ~= "overworld" then
        return false, "chỉ dùng QuestGo khi ở Overworld"
    end
    local qgoSvc = GetGameModule("ClientQuestGoService", { "Client", "services", "ClientQuestGoService" })
    if not (type(qgoSvc) == "table" and typeof(qgoSvc.Go) == "function") then
        return false, "chưa nạp được ClientQuestGoService"
    end
    local progress = ReadStore("QuestProgress", "table") or {}
    for questId in pairs(progress) do
        if type(questId) == "string" then
            local okGo, went = SafeCallGame(qgoSvc.Go, questId)
            if okGo and went then
                return true, "Đã điều hướng tới nhiệm vụ: " .. questId
            end
        end
    end
    return false, "không có nhiệm vụ đang nhận để điều hướng"
end

-- Chỉ gửi Lobby_SetChosenMission / Lobby_SetChosenChallenge khi phòng chờ chưa chọn đúng màn,
-- tránh tự reset đếm ngược 5 giây (countdownEndsAt) của Lobby mỗi chu kỳ lặp!
function F.QueueLobbyGamemodeAndReady(gamemodeId, missionId, raidBaseId, raidTier)
    if tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld") ~= "overworld" then
        return false, "đang ở trong màn chơi"
    end
    local lobby = nil
    local lobbySvc = GetGameModule("ClientLobbyService", { "Client", "services", "ClientLobbyService" })
    local fusion = GetGameModule("Fusion", { "Packages", "Fusion" })
    if type(lobbySvc) == "table" and lobbySvc.CurrentLobby and type(fusion) == "table" and typeof(fusion.peek) == "function" then
        local okL, st = SafeCallGame(fusion.peek, lobbySvc.CurrentLobby)
        if okL then
            lobby = st
            Session.currentLobby = st
        end
    else
        lobby = Session.currentLobby
    end

    local isAlreadySelected = false
    if type(lobby) == "table" and lobby.gamemodeId == gamemodeId and type(lobby.gamemodeData) == "table" then
        if gamemodeId == "stage" then
            local curMission = lobby.gamemodeData.missionId or lobby.gamemodeData.mission
            isAlreadySelected = (curMission == missionId)
        elseif gamemodeId == "raid" then
            isAlreadySelected = (lobby.gamemodeData.baseId == raidBaseId)
                and (tonumber(lobby.gamemodeData.tier) == tonumber(raidTier))
        end
    end

    if not isAlreadySelected then
        if gamemodeId == "stage" then
            if type(lobbySvc) == "table" and typeof(lobbySvc.OpenMission) == "function" then
                SafeCallGame(lobbySvc.OpenMission, missionId)
            else
                FireRemote("Lobby_SetChosenMission", missionId)
            end
        elseif gamemodeId == "raid" then
            FireRemote("Lobby_SetChosenChallenge", raidBaseId, tonumber(raidTier) or 1)
        end
        task.wait(0.15)
        if type(lobbySvc) == "table" and lobbySvc.CurrentLobby and type(fusion) == "table" and typeof(fusion.peek) == "function" then
            local okL, st = SafeCallGame(fusion.peek, lobbySvc.CurrentLobby)
            if okL then
                lobby = st
                Session.currentLobby = st
            end
        end
    end

    local alreadyReady = false
    if type(lobby) == "table" then
        if lobby.countdownEndsAt ~= nil or (type(lobby.state) == "string" and lobby.state ~= "selecting") then
            alreadyReady = true
        elseif type(lobby.readyUserIds) == "table" then
            for _, rUid in ipairs(lobby.readyUserIds) do
                if rUid == LocalPlayer.UserId then
                    alreadyReady = true
                    break
                end
            end
        end
    end

    if not alreadyReady then
        FireRemote("Lobby_SetReady", true)
    end

    if gamemodeId == "stage" then
        return true, "Đã chọn & sẵn sàng Mission: " .. tostring(missionId)
    end
    return true, string.format("Đã chọn & sẵn sàng Raid %s (Tier %d)", tostring(raidBaseId), tonumber(raidTier) or 1)
end

function F.StartSelectedStoryMission(missionId)
    local target = missionId or Config.SelectedMission
    return F.QueueLobbyGamemodeAndReady("stage", target, nil, nil)
end

function F.StartSelectedRaidChallenge(baseId, tier)
    local targetBase = baseId or Config.SelectedRaidBase
    local targetTier = tonumber(tier or Config.SelectedRaidTier) or 1
    return F.QueueLobbyGamemodeAndReady("raid", nil, targetBase, targetTier)
end

function F.VoteMatchResults(option, forceSend)
    local gamemode = tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld")
    if gamemode == "overworld" then
        return false, "đang ở Overworld"
    end

    local snap = Session.matchSnapshot
    if type(snap) ~= "table" then
        local getConns = (typeof(getconnections) == "function" and getconnections)
            or (typeof(get_signal_connections) == "function" and get_signal_connections)
            or nil
        local getUpvals = (type(debug) == "table" and typeof(debug.getupvalues) == "function" and debug.getupvalues)
            or (typeof(getupvalues) == "function" and getupvalues)
            or nil
        local fusion = GetGameModule("Fusion", { "Packages", "Fusion" })
        local snapRemote = GetNetworkRemote("MatchResults_Snapshot")
        if getConns and getUpvals and snapRemote and snapRemote:IsA("RemoteEvent") and type(fusion) == "table" and typeof(fusion.peek) == "function" then
            local okC, conns = pcall(getConns, snapRemote.OnClientEvent)
            EnsureHighIdentity()
            if okC and type(conns) == "table" then
                for _, conn in ipairs(conns) do
                    local fn = type(conn) == "table" and (conn.Function or conn.Callback)
                        or (typeof(conn) == "userdata" and pcall(function() return conn.Function end) and conn.Function)
                        or nil
                    if typeof(fn) == "function" then
                        local okU, uvs = pcall(getUpvals, fn)
                        if okU and type(uvs) == "table" then
                            for _, uv in pairs(uvs) do
                                if type(uv) == "table" then
                                    local okP, val = SafeCallGame(fusion.peek, uv)
                                    if okP and type(val) == "table" and type(val.status) == "string" and val.gamemodeId ~= nil then
                                        Session.matchSnapshot = val
                                        snap = val
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if type(snap) == "table" then break end
                end
            end
        end
    end

    local matchEnded = (type(snap) == "table" and type(snap.status) == "string" and snap.status ~= "ongoing")
        or (type(Session.matchOutcome) == "string" and Session.matchOutcome ~= "ongoing")

    -- Tuyệt đối không gửi vote khi trận đấu vẫn đang diễn ra (hoặc chưa có snapshot kết thúc trận)
    if not forceSend and not matchEnded then
        return false, "trận đấu vẫn đang diễn ra"
    end

    -- Nếu đang có rương chiến thắng chưa mở thì ưu tiên mở rương trước khi vote rời trận / chơi lại
    if Config.WaitChestBeforeVote and not forceSend then
        local hasChest = F.HasUnopenedChestInWorkspace()
        if hasChest or (type(snap) == "table" and snap.chestWaiting == true) then
            F.ScanAndOpenChests(true)
            if F.HasUnopenedChestInWorkspace() then
                return false, "đang mở rương chiến thắng trước khi vote"
            end
        end
    end

    local choice = option or Config.MatchVoteOption
    if Config.SmartVoteFallback and type(snap) == "table" then
        if choice == "next" and snap.nextActivityId == nil then
            choice = (snap.noRetry == true) and "lobby" or "retry"
        elseif choice == "retry" and snap.noRetry == true then
            choice = "lobby"
        end
    end

    local runKey = (type(snap) == "table" and tostring(snap.runId or "")) or tostring(Session.currentRunId or "active")
    local now = os.clock()
    if not forceSend then
        if Session.currentVoteOption == choice then
            return true, "đã giữ vote " .. tostring(choice)
        end
        if Session.lastVotedRunId == runKey and Session.lastVotedChoice == choice and (now - (Session.lastVoteSentAt or 0)) < 4.5 then
            return true, "đã gửi vote " .. tostring(choice)
        end
    end

    Session.lastVotedRunId = runKey
    Session.lastVotedChoice = choice
    Session.lastVoteSentAt = now
    Session.currentVoteOption = choice
    return FireRemote("MatchResults_SetVote", choice)
end

function F.LeaveCurrentRun()
    if tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld") == "overworld" then
        return false, "đang ở Overworld"
    end
    local transSvc = GetGameModule("ClientTeleportTransitionService", { "Client", "services", "ClientTeleportTransitionService" })
    if type(transSvc) == "table" and typeof(transSvc.Depart) == "function" then
        local okD, started = SafeCallGame(transSvc.Depart, {
            kind = "leave",
            send = function(token)
                FireRemote("MatchResults_LeaveRun", token)
            end
        })
        if okD and started then
            return true, "Đã gửi lệnh rời trận về Sảnh"
        end
    end
    FireRemote("MatchResults_LeaveRun")
    return true, "Đã gửi MatchResults_LeaveRun"
end

function F.HandleRaidIntermission(forceVoteAndReady)
    local gs = ReplicatedStorage:FindFirstChild("GamemodeState")
    local rawJson = gs and gs:GetAttribute("RaidIntermission")
    if type(rawJson) == "string" and #rawJson > 2 then
        local okDec, state = pcall(HttpService.JSONDecode, HttpService, rawJson)
        if okDec and type(state) == "table" then
            if (Config.AutoRaidVoteCard or forceVoteAndReady) and type(state.cards) == "table" and #state.cards > 0 then
                local preferred = Config.PreferredRaidCard
                local chosenId, bestScore = nil, -1
                for _, entry in ipairs(state.cards) do
                    local cid = type(entry) == "table" and (entry.id or entry.cardId) or entry
                    if type(cid) == "string" and cid ~= "" then
                        if preferred and preferred ~= "Tự động theo thứ tự ưu tiên DPS" and cid == preferred then
                            chosenId = cid
                            break
                        end
                        local score = C.RaidCardPriority[cid] or 10
                        if score > bestScore then
                            bestScore = score
                            chosenId = cid
                        end
                    end
                end
                if type(chosenId) == "string" and chosenId ~= "" then
                    FireRemote("Raid_VoteCard", chosenId)
                end
            end
            if Config.AutoRaidReadyNext or forceVoteAndReady then
                FireRemote("Raid_ReadyNextStage")
            end
            return true
        end
    end
    return false
end

-- ============================================================================
-- [7b] QUẢN LÝ TỔ ĐỘI / PARTY TỪ XA (Lobby_InvitePlayer, Lobby_Kick, Lobby_Promote, Lobby_CancelInvite)
-- ============================================================================
F.PartyCreateModes = {
    "Tạo Phòng Theo Raid Đang Chọn",
    "Tạo Phòng Theo Story Mission Đang Chọn"
}

function F.GetCurrentLobbyState()
    local lobbySvc = GetGameModule("ClientLobbyService", { "Client", "services", "ClientLobbyService" })
    local fusion = GetGameModule("Fusion", { "Packages", "Fusion" })
    if type(lobbySvc) == "table" and lobbySvc.CurrentLobby and type(fusion) == "table" and typeof(fusion.peek) == "function" then
        local okL, state = SafeCallGame(fusion.peek, lobbySvc.CurrentLobby)
        if okL and type(state) == "table" then
            Session.currentLobby = state
            return state
        elseif okL and state == nil then
            Session.currentLobby = nil
            return nil
        end
    end
    return Session.currentLobby
end

function F.FormatPlayerOption(plr)
    return string.format("%s (@%s) [%d]", tostring(plr.DisplayName or plr.Name), tostring(plr.Name), tonumber(plr.UserId) or 0)
end

function F.GetServerOtherPlayerOptions()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            list[#list + 1] = F.FormatPlayerOption(plr)
        end
    end
    table.sort(list)
    if #list == 0 then
        list[1] = "Chưa có người chơi khác"
    end
    return list
end

function F.ResolveSelectedPartyUserId(rawSelection)
    local sel = tostring(rawSelection or Config.SelectedPartyPlayer or "")
    local uidStr = sel:match("%[(%d+)%]$") or sel:match("^(%d+)$")
    if uidStr then
        return tonumber(uidStr)
    end
    local lowerSel = string.lower(sel)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            if string.lower(plr.Name) == lowerSel or string.lower(plr.DisplayName) == lowerSel or F.FormatPlayerOption(plr) == sel then
                return plr.UserId
            end
        end
    end
    return nil
end

function F.EnsurePartyLobbyExists()
    local lobby = F.GetCurrentLobbyState()
    if type(lobby) == "table" then
        return true
    end
    if Config.PartyCreateMode == "Tạo Phòng Theo Story Mission Đang Chọn" then
        FireRemote("Lobby_SetChosenMission", Config.SelectedMission)
    else
        FireRemote("Lobby_SetChosenChallenge", Config.SelectedRaidBase, Config.SelectedRaidTier)
    end
    task.wait(0.2)
    return true
end

function F.InviteUserToParty(targetUserId)
    local uid = tonumber(targetUserId) or F.ResolveSelectedPartyUserId(targetUserId)
    if not uid or uid == LocalPlayer.UserId then
        return false, "chưa chọn người chơi hợp lệ trong server"
    end
    local targetPlr = Players:GetPlayerByUserId(uid)
    if not targetPlr then
        return false, "người chơi không còn trong server"
    end
    F.EnsurePartyLobbyExists()
    FireRemote("Lobby_InvitePlayer", uid)
    return true, string.format("Đã gửi lời mời Tổ Đội tới %s (@%s)", tostring(targetPlr.DisplayName), tostring(targetPlr.Name))
end

function F.CancelPartyInviteForUser(targetUserId)
    local uid = tonumber(targetUserId) or F.ResolveSelectedPartyUserId(targetUserId)
    if not uid then
        return false, "chưa chọn người chơi hợp lệ"
    end
    local lobbySvc = GetGameModule("ClientLobbyService", { "Client", "services", "ClientLobbyService" })
    if type(lobbySvc) == "table" and typeof(lobbySvc.CancelInvite) == "function" then
        SafeCallGame(lobbySvc.CancelInvite, uid)
    else
        FireRemote("Lobby_CancelInvite", uid)
    end
    return true, "Đã hủy lời mời Tổ Đội tới UserId " .. tostring(uid)
end

function F.PromotePartyMember(targetUserId)
    local uid = tonumber(targetUserId) or F.ResolveSelectedPartyUserId(targetUserId)
    if not uid then
        return false, "chưa chọn thành viên hợp lệ để nhường chủ phòng"
    end
    local lobby = F.GetCurrentLobbyState()
    if type(lobby) == "table" and lobby.leaderUserId and lobby.leaderUserId ~= LocalPlayer.UserId then
        return false, "bạn không phải là chủ phòng hiện tại"
    end
    local lobbySvc = GetGameModule("ClientLobbyService", { "Client", "services", "ClientLobbyService" })
    if type(lobbySvc) == "table" and typeof(lobbySvc.Promote) == "function" then
        SafeCallGame(lobbySvc.Promote, uid)
    else
        FireRemote("Lobby_Promote", uid)
    end
    local targetPlr = Players:GetPlayerByUserId(uid)
    return true, "Đã nhường chủ phòng cho " .. tostring((targetPlr and targetPlr.DisplayName) or uid)
end

function F.KickPartyMember(targetUserId)
    local uid = tonumber(targetUserId) or F.ResolveSelectedPartyUserId(targetUserId)
    if not uid then
        return false, "chưa chọn thành viên hợp lệ để đuổi khỏi phòng"
    end
    local lobby = F.GetCurrentLobbyState()
    if type(lobby) == "table" and lobby.leaderUserId and lobby.leaderUserId ~= LocalPlayer.UserId then
        return false, "bạn không phải là chủ phòng hiện tại"
    end
    local lobbySvc = GetGameModule("ClientLobbyService", { "Client", "services", "ClientLobbyService" })
    if type(lobbySvc) == "table" and typeof(lobbySvc.Kick) == "function" then
        SafeCallGame(lobbySvc.Kick, uid)
    else
        FireRemote("Lobby_Kick", uid)
    end
    local targetPlr = Players:GetPlayerByUserId(uid)
    return true, "Đã đuổi khỏi Tổ Đội: " .. tostring((targetPlr and targetPlr.DisplayName) or uid)
end

function F.InviteMultiplePlayersToParty(friendsOnly)
    F.EnsurePartyLobbyExists()
    local pOkElig, eligMap = InvokeRemote("Lobby_GetInviteEligibility")
    local eligibility = (pOkElig and type(eligMap) == "table") and eligMap or nil
    local lobby = F.GetCurrentLobbyState()
    local inLobbySet = {}
    if type(lobby) == "table" and type(lobby.memberUserIds) == "table" then
        for _, mUid in ipairs(lobby.memberUserIds) do
            inLobbySet[mUid] = true
        end
    end

    local invitedCount = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not inLobbySet[plr.UserId] then
            local allow = true
            if friendsOnly then
                local okF, isF = pcall(LocalPlayer.IsFriendsWith, LocalPlayer, plr.UserId)
                allow = okF and isF == true
            end
            if allow and eligibility then
                local entry = eligibility[plr.UserId] or eligibility[tostring(plr.UserId)]
                if type(entry) == "table" and entry.canInvite == false then
                    allow = false
                end
            end
            if allow then
                FireRemote("Lobby_InvitePlayer", plr.UserId)
                Session.invitedFriendsMap[plr.UserId] = os.clock()
                invitedCount = invitedCount + 1
                task.wait(0.08)
            end
        end
    end
    return invitedCount
end

function F.GetPartyStatusSummaryText()
    local lobby = F.GetCurrentLobbyState()
    if type(lobby) ~= "table" then
        return "Tổ Đội: Chưa vào phòng chờ (Lobby)"
    end
    local mode = tostring(lobby.gamemodeId or "?")
    local detail = mode
    if type(lobby.gamemodeData) == "table" then
        if mode == "raid" then
            detail = string.format("Raid %s (Tier %s)", tostring(lobby.gamemodeData.baseId or "?"), tostring(lobby.gamemodeData.tier or "?"))
        elseif mode == "stage" then
            detail = "Mission " .. tostring(lobby.gamemodeData.missionId or "?")
        end
    end
    local leaderPlr = lobby.leaderUserId and Players:GetPlayerByUserId(lobby.leaderUserId) or nil
    local leaderName = (lobby.leaderUserId == LocalPlayer.UserId and "Bạn") or (leaderPlr and leaderPlr.DisplayName) or tostring(lobby.leaderUserId or "?")
    local memberCount = type(lobby.memberUserIds) == "table" and #lobby.memberUserIds or 1
    local readyCount = type(lobby.readyUserIds) == "table" and #lobby.readyUserIds or 0
    return string.format("Tổ Đội: %s | Chủ phòng: %s | Thành viên: %d (Ready: %d)", detail, leaderName, memberCount, readyCount)
end

-- ============================================================================
-- [8] TRIỆU HỒI, SERVER AUTO-DISMANTLE, ĐỘI HÌNH, FEED, LOCK, DISMANTLE, ASCEND, EVOLVE, TRAIT & STAT
-- ============================================================================
function F.PullBannerOnce()
    local booster = Config.SelectedBooster
    if booster == "Không dùng" or booster == "" then
        booster = nil
    end
    local count = math.clamp(math.floor(tonumber(Config.PullCount) or 1), 1, 10)
    local pOk, res, err = InvokeRemote("PullFromBanner", Config.SelectedBanner, count, booster)
    if pOk and type(res) == "table" then
        return true, res
    end
    return false, tostring(err or res or "không đủ tiền hoặc chưa mở banner")
end

function F.ApplyServerSummonAutoDismantle()
    local settingsSvc = GetGameModule("ClientSettingsService", { "Client", "services", "ClientSettingsService" })
    local pairsToSet = {
        { "AutoDismantleRare", Config.ServerKeepRare },
        { "AutoDismantleEpic", Config.ServerKeepEpic },
        { "AutoDismantleLegendary", Config.ServerKeepLegendary }
    }
    for _, pair in ipairs(pairsToSet) do
        local key, val = pair[1], pair[2]
        if type(settingsSvc) == "table" and typeof(settingsSvc.Set) == "function" then
            SafeCallGame(settingsSvc.Set, key, val)
        end
        FireRemote("SetSetting", key, val)
    end
    Notify("Auto-Dismantle Server", string.format("Đã đặt giữ tướng khi Summon: Rare=%s, Epic=%s, Legendary=%s",
        tostring(Config.ServerKeepRare), tostring(Config.ServerKeepEpic), tostring(Config.ServerKeepLegendary)), 4)
end

function F.EquipBestChampions(forceSend)
    local champions = ReadStore("Champions", "table", true)
    local equipped = ReadStore("EquippedChampions", "table", true) or {}
    local ranking = GetGameModule("ChampionRanking", { "Shared", "ChampionRanking" })

    if type(champions) == "table" and type(ranking) == "table" and typeof(ranking.pickBest) == "function" then
        local repaired = ReadStore("Repaired", "table", true) or {}
        local claimedLines = ReadStore("ClaimedQuestlines", "table", true) or {}
        -- Trong Balance.Progression: TEAM_BASE_SLOTS = 3, gold_team_slot (100K Gold) mở ô thứ 4, gold_team_slot_2 (100M Gold) mở ô thứ 5
        local baseSlots = 3
            + ((repaired.gold_team_slot or Session.knownRepaired.gold_team_slot) and 1 or 0)
            + ((repaired.gold_team_slot_2 or Session.knownRepaired.gold_team_slot_2) and 1 or 0)
        local equipSlotsCfg = GetGameModule("EquipSlotsConfig", { "Config", "EquipSlotsConfig" })
        if type(equipSlotsCfg) == "table" and typeof(equipSlotsCfg.resolve) == "function" then
            local okS, resolvedSlots = SafeCallGame(equipSlotsCfg.resolve, {
                ClaimedQuestlines = claimedLines,
                Repaired = repaired
            })
            if okS and type(resolvedSlots) == "number" and resolvedSlots >= baseSlots then
                baseSlots = resolvedSlots
            end
        end
        local maxSlots = math.max(#equipped, baseSlots)
        local okPick, bestUids = SafeCallGame(ranking.pickBest, champions, maxSlots, equipped)
        if okPick and type(bestUids) == "table" and #bestUids > 0 then
            if not forceSend and #bestUids == #equipped then
                local currentSet = {}
                for _, uid in ipairs(equipped) do
                    currentSet[uid] = true
                end
                local identical = true
                for _, uid in ipairs(bestUids) do
                    if not currentSet[uid] then
                        identical = false
                        break
                    end
                end
                if identical then
                    return false, "Đội hình hiện tại đã là mạnh nhất"
                end
            end
            FireRemote("SetEquippedChampions", bestUids)
            return true, string.format("Đã trang bị %d chiến binh mạnh nhất", #bestUids)
        end
    end

    local invSvc = GetGameModule("ClientInventoryService", { "Client", "services", "ClientInventoryService" })
    if type(invSvc) == "table" and typeof(invSvc.EquipBest) == "function" then
        local ok = SafeCallGame(invSvc.EquipBest)
        if ok then return true, "Đã trang bị đội hình mạnh nhất (ClientInventoryService)" end
    end
    return false, "không tính được đội hình mạnh nhất"
end

-- Tự trang bị 1 chiến binh có nguyên tố yêu cầu (dùng cho nhiệm vụ NPC ở Land of Ninjas)
function F.EnsureElementChampionEquipped(requiredElement)
    local champions = ReadStore("Champions", "table", true)
    local equipped = ReadStore("EquippedChampions", "table", true) or {}
    if type(champions) ~= "table" then return false end
    for _, uid in ipairs(equipped) do
        local ch = champions[uid]
        if type(ch) == "table" and F.GetCharacterElement(ch.id) == requiredElement then
            return true
        end
    end
    for uid, ch in pairs(champions) do
        if type(ch) == "table" and F.GetCharacterElement(ch.id) == requiredElement then
            local newTeam = table.clone(equipped)
            if #newTeam == 0 then
                newTeam[1] = uid
            else
                newTeam[#newTeam] = uid
            end
            FireRemote("SetEquippedChampions", newTeam)
            return true
        end
    end
    return false
end

function F.AutoFeedEquippedChampions()
    local champions = ReadStore("Champions", "table", true)
    local equipped = ReadStore("EquippedChampions", "table", true) or {}
    local items = ReadStore("Items", "table") or {}
    if type(champions) ~= "table" or #equipped == 0 then
        return 0, "chưa có chiến binh trang bị"
    end

    local feedCfg = GetGameModule("ChampionFeedConfig", { "Config", "ChampionFeedConfig" })
    local levelCfg = GetGameModule("LevelConfig", { "Config", "LevelConfig" })
    local levelCapMod = GetGameModule("ChampionLevelCap", { "Shared", "ChampionLevelCap" })
    local clearedBosses = ReadStore("ClearedBosses", "table", true) or {}

    local hardCap = 50
    if type(levelCapMod) == "table" and typeof(levelCapMod.hardForCleared) == "function" then
        local okCap, cap = SafeCallGame(levelCapMod.hardForCleared, clearedBosses)
        if okCap and type(cap) == "number" then hardCap = cap end
    end

    local fedCount = 0
    local fedSummary = {}
    for _, uid in ipairs(equipped) do
        local champ = champions[uid]
        if type(champ) == "table" then
            local curLevel = 1
            if type(levelCfg) == "table" and typeof(levelCfg.resolve) == "function" then
                local okL, resolved = SafeCallGame(levelCfg.resolve, champ)
                if okL and type(resolved) == "table" and type(resolved.level) == "number" then
                    curLevel = resolved.level
                end
            end
            if curLevel < hardCap then
                for _, fruitId in ipairs(C.Fruits) do
                    local owned = tonumber(items[fruitId]) or 0
                    if owned > 0 then
                        local feedAmount = 1
                        if type(feedCfg) == "table" and typeof(feedCfg.canUseFood) == "function" and typeof(feedCfg.getFoodCountToCap) == "function" then
                            local okUse, canUse = SafeCallGame(feedCfg.canUseFood, champ, fruitId, hardCap)
                            if not (okUse and canUse) then
                                feedAmount = 0
                            else
                                local okToCap, toCap = SafeCallGame(feedCfg.getFoodCountToCap, champ, fruitId, hardCap)
                                if okToCap and type(toCap) == "number" then
                                    feedAmount = math.min(owned, math.max(0, toCap))
                                end
                            end
                        end
                        if feedAmount > 0 then
                            local pOk, res = InvokeRemote("FeedChampion", uid, { [fruitId] = feedAmount })
                            if pOk and type(res) == "table" and res.success then
                                fedCount = fedCount + 1
                                items[fruitId] = math.max(0, owned - feedAmount)
                                fedSummary[#fedSummary + 1] = string.format("%s (%dx %s)", tostring(champ.id), feedAmount, fruitId)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    if fedCount > 0 then
        return fedCount, "Đã cho ăn: " .. table.concat(fedSummary, ", ")
    end
    return 0, "không có trái cây phù hợp hoặc đã đạt giới hạn cấp"
end

function F.GetChampionRarity(characterId)
    if type(characterId) ~= "string" or characterId == "" then return nil end
    local cached = Session.championRarityCache[characterId]
    if cached ~= nil then
        return cached or nil
    end
    local charDefs = GetGameModule("CharacterDefs", { "Shared", "CharacterDefs" })
    if type(charDefs) == "table" and typeof(charDefs.get) == "function" then
        local okD, def = SafeCallGame(charDefs.get, characterId)
        if okD and type(def) == "table" then
            local rar = type(def.rarity) == "string" and def.rarity or false
            Session.championRarityCache[characterId] = rar
            return rar or nil
        end
    end
    return nil
end

function F.AutoLockRareChampions()
    local champions = ReadStore("Champions", "table", true)
    if type(champions) ~= "table" then return 0 end
    local lockPayload = {}
    local count = 0
    for uid, champ in pairs(champions) do
        if type(champ) == "table" and champ.locked ~= true then
            local rarity = F.GetChampionRarity(champ.id)
            local rank = C.RarityRanks[rarity or ""] or 0
            if champ.shiny == true or rank >= C.RarityRanks.Mythic then
                lockPayload[uid] = true
                count = count + 1
            end
        end
    end
    if count > 0 then
        local pOk, res = InvokeRemote("SetChampionLocks", lockPayload)
        if pOk and type(res) == "table" and res.success then
            return count
        end
    end
    return 0
end

function F.AutoDismantleLowRarityChampions()
    local champions = ReadStore("Champions", "table", true)
    local equipped = ReadStore("EquippedChampions", "table", true) or {}
    if type(champions) ~= "table" then return 0, "chưa đọc được kho Champions" end

    local equippedMap = {}
    for _, uid in ipairs(equipped) do
        equippedMap[uid] = true
    end

    local maxRank = C.RarityRanks[Config.DismantleMaxRarity] or 2
    local toDismantle = {}

    for uid, champ in pairs(champions) do
        if type(champ) == "table" and not equippedMap[uid] and champ.locked ~= true then
            local skip = false
            if Config.DismantleKeepShiny and champ.shiny == true then
                skip = true
            end
            if Config.DismantleKeepStarred and (tonumber(champ.stars) or 0) > 0 then
                skip = true
            end
            if not skip and type(champ.traits) == "table" then
                for _, traitId in pairs(champ.traits) do
                    local trRarity = C.TraitRarityMap[traitId]
                    if trRarity == "Mythic" or trRarity == "Secret" then
                        skip = true
                        break
                    end
                end
            end
            if not skip then
                local rarity = F.GetChampionRarity(champ.id)
                local rank = C.RarityRanks[rarity or ""]
                if rank and rank <= maxRank then
                    toDismantle[#toDismantle + 1] = uid
                end
            end
        end
    end

    if #toDismantle == 0 then
        return 0, "không có chiến binh nào thuộc diện phân rã"
    end

    local pOk, res = InvokeRemote("DismantleChampions", toDismantle)
    if pOk and type(res) == "table" and res.success then
        return #toDismantle, string.format("Đã phân rã %d chiến binh (<= %s)", #toDismantle, tostring(Config.DismantleMaxRarity))
    end
    return 0, tostring((type(res) == "table" and res.reason) or "phân rã bị từ chối")
end

function F.AutoAscendAllPossible()
    local champions = ReadStore("Champions", "table")
    local equipped = ReadStore("EquippedChampions", "table", true) or {}
    local rules = GetGameModule("ChampionRules", { "Shared", "ChampionRules" })
    if not (type(champions) == "table" and type(rules) == "table" and typeof(rules.autoFill) == "function") then
        return 0, "chưa nạp được ChampionRules"
    end

    local equippedMap = {}
    for _, uid in ipairs(equipped) do
        equippedMap[uid] = true
    end
    local function isEquipped(uid)
        return equippedMap[uid] == true
    end

    local order = {}
    for _, uid in ipairs(equipped) do
        if champions[uid] then order[#order + 1] = uid end
    end
    for uid in pairs(champions) do
        if not equippedMap[uid] then order[#order + 1] = uid end
    end

    local fusedCount = 0
    for _, targetUid in ipairs(order) do
        local champ = champions[targetUid]
        if champ then
            local okFill, donorUids = SafeCallGame(rules.autoFill, champions, targetUid, isEquipped)
            if okFill and type(donorUids) == "table" and #donorUids > 0 then
                local okPlan = true
                if typeof(rules.planStarUp) == "function" then
                    local okP, plan = SafeCallGame(rules.planStarUp, champions, targetUid, donorUids, isEquipped)
                    okPlan = okP and type(plan) == "table"
                end
                if okPlan then
                    local pOk, res = InvokeRemote("FuseChampion", targetUid, donorUids)
                    if pOk and res then
                        fusedCount = fusedCount + 1
                        for _, dUid in ipairs(donorUids) do
                            champions[dUid] = nil
                        end
                    end
                end
            end
        end
    end
    return fusedCount
end

function F.AutoEvolveEquipped()
    local champions = ReadStore("Champions", "table")
    local equipped = ReadStore("EquippedChampions", "table") or {}
    local items = ReadStore("Items", "table") or {}
    if type(champions) ~= "table" then return 0, "chưa đọc được kho Champions" end

    local evolveRules = GetGameModule("EvolveRules", { "Shared", "EvolveRules" })
    local evolveCfg = GetGameModule("EvolveConfig", { "Config", "EvolveConfig" })

    local candidateUids = {}
    local seen = {}
    for _, uid in ipairs(equipped) do
        if type(uid) == "string" and champions[uid] then
            seen[uid] = true
            candidateUids[#candidateUids + 1] = uid
        end
    end
    if Config.AutoEvolveAllInventory then
        for uid, champ in pairs(champions) do
            if type(uid) == "string" and type(champ) == "table" and not seen[uid] then
                seen[uid] = true
                candidateUids[#candidateUids + 1] = uid
            end
        end
    end

    local evolved = 0
    for _, uid in ipairs(candidateUids) do
        local champ = champions[uid]
        if type(champ) == "table" and type(champ.id) == "string" then
            local canEvolve = false
            if type(evolveRules) == "table" and typeof(evolveRules.plan) == "function" then
                local okPlan, plan = SafeCallGame(evolveRules.plan, champions, items, uid)
                canEvolve = okPlan and type(plan) == "table"
            elseif type(evolveRules) == "table" and typeof(evolveRules.recipeFor) == "function" then
                local okRec, recipe = SafeCallGame(evolveRules.recipeFor, champ.id)
                if okRec and type(recipe) == "table" and type(recipe.requirements) == "table" then
                    canEvolve = true
                    for _, req in ipairs(recipe.requirements) do
                        if (tonumber(items[req.item_id]) or 0) < (tonumber(req.amount) or 1) then
                            canEvolve = false
                            break
                        end
                    end
                end
            elseif type(evolveCfg) == "table" and type(evolveCfg.COSTS) == "table" then
                -- Nếu chưa nạp được EvolveRules, chỉ thử khi có nguyên liệu tiến hóa trong túi
                if (tonumber(items.ki_shard) or 0) > 0 or (tonumber(items.thunderstruck_coin) or 0) > 0 or (tonumber(items.shattered_earring) or 0) >= 100 then
                    canEvolve = true
                end
            end

            if canEvolve then
                local pOk, res = InvokeRemote("EvolveChampion", uid)
                if pOk and type(res) == "table" and res.success then
                    evolved = evolved + 1
                    Notify("Tiến Hóa", "Đã tiến hóa chiến binh: " .. tostring(champ.id), 4)
                end
            end
        end
    end
    return evolved, evolved > 0 and string.format("Đã tiến hóa %d chiến binh!", evolved) or "chưa có chiến binh nào đủ nguyên liệu tiến hóa"
end

function F.DoesTraitMatchTarget(traitId)
    if type(traitId) ~= "string" or traitId == "" then
        return false
    end
    if traitId == Config.TargetTrait then
        return true
    end
    local wantedRarity = Config.TargetTraitRarity
    if wantedRarity and wantedRarity ~= "Bất kỳ (chỉ lọc theo Trait)" then
        local actualRarity = C.TraitRarityMap[traitId]
        if actualRarity == wantedRarity then
            return true
        end
    end
    return false
end

function F.GetTargetChampionUid()
    local trs = GetGameModule("ClientTraitRerollService", { "Client", "services", "ClientTraitRerollService" })
    local fusion = GetGameModule("Fusion", { "Packages", "Fusion" })
    if type(trs) == "table" and trs.ChampionUid and type(fusion) == "table" and typeof(fusion.peek) == "function" then
        local okP, uid = SafeCallGame(fusion.peek, trs.ChampionUid)
        if okP and type(uid) == "string" and uid ~= "" then
            return uid
        end
    end
    local equipped = ReadStore("EquippedChampions", "table")
    if type(equipped) == "table" and type(equipped[1]) == "string" then
        return equipped[1]
    end
    return nil
end

function F.StepTraitReroll()
    if Session.rerollingTrait then return end
    local uid = F.GetTargetChampionUid()
    if not uid then
        Config.AutoTraitReroll = false
        Notify("Trait Reroll", "Không tìm thấy chiến binh để Reroll (hãy trang bị hoặc chọn trong máy Trait).", 4)
        return
    end

    local champions = ReadStore("Champions", "table")
    local champ = champions and champions[uid]
    if not champ then return end

    local slotKey = tostring(Config.SelectedTraitSlot or "1")
    local currentTrait = type(champ.traits) == "table" and champ.traits[slotKey] or nil
    if currentTrait and F.DoesTraitMatchTarget(currentTrait) then
        Config.AutoTraitReroll = false
        TriggerSave()
        Notify("Trait Reroll", string.format("Đã đạt Trait mục tiêu: %s (%s)!", tostring(currentTrait), tostring(C.TraitRarityMap[currentTrait] or "?")), 6)
        return
    end

    local tokens = ReadStore("Items/trait_tokens", "number") or 0
    if tokens < 1 then
        Config.AutoTraitReroll = false
        TriggerSave()
        Notify("Trait Reroll", "Đã hết Trait Tokens!", 4)
        return
    end

    Session.rerollingTrait = true
    local pOk, res, err = InvokeRemote("RerollChampionTrait", uid, slotKey)
    Session.rerollingTrait = false

    if pOk and type(res) == "table" and res.traitId then
        if F.DoesTraitMatchTarget(res.traitId) then
            Config.AutoTraitReroll = false
            TriggerSave()
            Notify("Trait Reroll", string.format("Đã quay trúng Trait: %s (%s)!", tostring(res.traitId), tostring(C.TraitRarityMap[res.traitId] or "?")), 6)
        end
    else
        Config.AutoTraitReroll = false
        TriggerSave()
        Notify("Trait Reroll", "Dừng Reroll: " .. tostring((type(res) == "table" and res.message) or err or "bị từ chối"), 4)
    end
end

function F.StepStatReroll()
    if Session.rerollingStats then return end
    local uid = F.GetTargetChampionUid()
    if not uid then
        Config.AutoStatReroll = false
        Notify("Stat Reroll", "Không tìm thấy chiến binh để quay chỉ số.", 4)
        return
    end

    local champions = ReadStore("Champions", "table")
    local champ = champions and champions[uid]
    if not (champ and type(champ.stat_rolls) == "table") then return end

    local targetRank = C.StatGradeRanks[Config.TargetStatGrade] or 6
    local reachedStats = {}
    local unreachedCount = 0

    for _, statId in ipairs(C.StatIds) do
        local entry = champ.stat_rolls[statId]
        local grade = type(entry) == "table" and entry.grade or "F"
        local rank = C.StatGradeRanks[grade] or 1
        if rank >= targetRank then
            reachedStats[#reachedStats + 1] = statId
        else
            unreachedCount = unreachedCount + 1
        end
    end

    if unreachedCount == 0 then
        Config.AutoStatReroll = false
        TriggerSave()
        Notify("Stat Reroll", string.format("Cả 3 chỉ số đã đạt bậc >= %s!", tostring(Config.TargetStatGrade)), 6)
        return
    end

    local rerollItems = ReadStore("Items/stat_reroll", "number") or 0
    if rerollItems < 1 then
        Config.AutoStatReroll = false
        TriggerSave()
        Notify("Stat Reroll", "Đã hết vật phẩm Stat Reroll!", 4)
        return
    end

    local lockedArg = nil
    if Config.AutoLockReachedStats and #reachedStats > 0 and #reachedStats < #C.StatIds then
        local lockItems = ReadStore("Items/stat_lock", "number") or 0
        if lockItems >= #reachedStats then
            lockedArg = reachedStats
        end
    end

    Session.rerollingStats = true
    local pOk, res, err = InvokeRemote("RerollChampionStats", uid, lockedArg)
    Session.rerollingStats = false

    if not (pOk and res) then
        Config.AutoStatReroll = false
        TriggerSave()
        Notify("Stat Reroll", "Dừng quay chỉ số: " .. tostring(err or res or "bị từ chối"), 4)
    end
end

function F.AutoRepairAllUnrepaired()
    local repairedMap = ReadStore("Repaired", "table") or {}
    local clearedBosses = ReadStore("ClearedBosses", "table") or {}
    local items = ReadStore("Items", "table") or {}
    local repairRules = GetGameModule("RepairRules", { "Shared", "RepairRules" })
    local count = 0
    for _, rid in ipairs(C.Repairs) do
        local canPlan = not repairedMap[rid]
        if canPlan and type(repairRules) == "table" and typeof(repairRules.planRepair) == "function" then
            local okP, plan = SafeCallGame(repairRules.planRepair, repairedMap, clearedBosses, items, rid)
            canPlan = okP and type(plan) == "table"
        end
        if not repairedMap[rid] and canPlan then
            local ok = F.RepairSingle(rid)
            if ok then
                count = count + 1
                repairedMap[rid] = true
                Notify("Nâng Cấp & Sửa Chữa", "Đã mở khóa / sửa chữa: " .. tostring(rid), 3)
            end
        end
    end
    return count
end

-- ============================================================================
-- [9] ENGINE AUTO QUEST NPC THEO TỪNG WORLD (QUESTLOGIC), VẬT PHẨM NHIỆM VỤ & TÂN THỦ
-- ============================================================================
function F.BuildQuestContext()
    local questLogic = GetGameModule("QuestLogic", { "Shared", "QuestLogic" })
    local rawData = {
        QuestProgress = ReadStore("QuestProgress", "table") or {},
        ClaimedQuestlines = ReadStore("ClaimedQuestlines", "table", true) or {},
        ClearedBosses = ReadStore("ClearedBosses", "table", true) or {},
        DailyBonusClaimed = ReadStore("DailyBonusClaimed", "boolean", true) == true,
        Items = ReadStore("Items", "table", true) or {},
        Stats = ReadStore("Stats", "table", true) or {},
        MetGivers = ReadStore("MetGivers", "table", true) or {},
        DiscoveredCharacters = ReadStore("DiscoveredCharacters", "table", true) or {},
        EquippedChampions = ReadStore("EquippedChampions", "table", true) or {},
        Champions = ReadStore("Champions", "table", true) or {},
        Repaired = ReadStore("Repaired", "table", true) or {},
        WorldFlags = ReadStore("WorldFlags", "table", true) or {}
    }
    if type(questLogic) == "table" and typeof(questLogic.contextOf) == "function" then
        local okCtx, ctx = SafeCallGame(questLogic.contextOf, rawData)
        if okCtx and type(ctx) == "table" then
            return ctx, questLogic
        end
    end
    return {
        questProgress = rawData.QuestProgress,
        claimedQuestlines = rawData.ClaimedQuestlines,
        clearedBosses = rawData.ClearedBosses,
        dailyBonusClaimed = rawData.DailyBonusClaimed,
        items = rawData.Items,
        stats = rawData.Stats,
        metGivers = rawData.MetGivers,
        discovered = rawData.DiscoveredCharacters,
        repaired = rawData.Repaired,
        worldFlags = rawData.WorldFlags
    }, questLogic
end

-- Dịch chuyển tới vật phẩm nhiệm vụ (QuestItem) chưa nhặt trong Workspace và gọi FindQuestItem
function F.TeleportAndCollectQuestItemsForQuest(questId, spotList, questCtx, questLogic)
    local pOkDirect, okDirect = InvokeRemote("FindQuestItem", questId)
    if pOkDirect and okDirect == true then
        return true
    end
    local spotSet = nil
    if type(spotList) == "table" and #spotList > 0 then
        spotSet = {}
        for _, s in ipairs(spotList) do
            local alreadyFound = false
            if type(questLogic) == "table" and typeof(questLogic.spotFound) == "function" and type(questCtx) == "table" then
                local okF, isF = SafeCallGame(questLogic.spotFound, questId, s, questCtx)
                alreadyFound = okF and isF == true
            end
            if not alreadyFound then
                spotSet[s] = true
            end
        end
    end
    for _, model in ipairs(CollectionService:GetTagged(C.QuestItemTag)) do
        if model:IsA("Model") and model:IsDescendantOf(Workspace) then
            local spotId = model:GetAttribute(C.QuestItemIdAttribute)
            if not spotSet or (type(spotId) == "string" and spotSet[spotId]) then
                local pos = model:GetPivot().Position
                TeleportCharacterTo(pos)
                task.wait(0.2)
                local pOk, ok = InvokeRemote("FindQuestItem", questId)
                if pOk and ok == true then
                    return true
                end
            end
        end
    end
    return false
end

-- Ánh xạ cờ WorldFlag sang mục tiêu Camp ở Overworld (ví dụ city_veil_1 -> veil_vessel_1)
local FlagToEnemyMap = {
    city_veil_1 = "veil_vessel_1",
    city_veil_2 = "veil_vessel_2",
    city_veil_3 = "veil_vessel_3"
}

-- Ánh xạ ID Boss sang World (theo Bosses.worldOfBoss trong QuestGo)
local WorldBossEnemyToWorldMap = {
    alien_boss = "alien",
    marine_captain = "pirate",
    snake_ninja = "ninja",
    curse_king = "city"
}

function F.ResolveWorldOfBossEnemy(enemyId)
    if type(enemyId) ~= "string" or enemyId == "" then return nil end
    local bossesCfg = GetGameModule("Bosses", { "Config", "Bosses" })
    if type(bossesCfg) == "table" and typeof(bossesCfg.worldOfBoss) == "function" then
        local okB, wid = SafeCallGame(bossesCfg.worldOfBoss, enemyId)
        if okB and type(wid) == "string" and wid ~= "" then
            return wid
        end
    end
    return WorldBossEnemyToWorldMap[enemyId]
end

-- Tự động điều quân, dịch chuyển tới quái, tung kỹ năng, mở rương, chọn thẻ Raid & thoát về Sảnh khi đang ở trong Raid / Story Mission / World Boss của Nhiệm Vụ NPC
function F.StepQuestActiveRunCombat(gamemode, questDoneInRun)
    F.ScanAndClaimEcsDrops()
    F.ScanAndOpenChests(true)

    local pausedForHeal, healReason = F.CheckTeamRecoveryPause()
    if pausedForHeal then
        Session.questStatusText = string.format("[%s - HỒI PHỤC] %s", string.upper(tostring(gamemode)), tostring(healReason))
        return true
    end

    FireRemote("PlayerArrival_Presented")
    if gamemode == "raid" then
        if F.HandleRaidIntermission(true) then
            Session.questStatusText = "[QUEST -> RAID] Đang chọn thẻ Buff & qua màn kế tiếp..."
            return true
        end
    elseif gamemode == "defense" then
        FireRemote("Defense_RequestNextWave")
    elseif gamemode == "stage" then
        FireRemote("StageScene_Continue")
        if Session.lastMissionTalkRunId then
            FireRemote("MissionTalk_Ended", Session.lastMissionTalkRunId)
            Session.lastMissionTalkRunId = nil
        end
    end

    -- Khi đã xong mục tiêu nhiệm vụ trong màn chơi (hoặc xong trận), ưu tiên mở rương rồi vote về "lobby" để trả nhiệm vụ NPC
    local desiredVote = questDoneInRun and "lobby" or "retry"
    F.VoteMatchResults(desiredVote, false)

    local engaged, msg = F.TryEngageNearestPack(true)
    F.FireAllEquippedAbilities()
    if engaged then
        Session.questStatusText = string.format("[QUEST -> %s] Đang Tele & Đánh: %s", string.upper(tostring(gamemode)), tostring(msg))
    end
    return true
end

-- Bộ điều phối Auto Quest của các NPC theo từng World (nhận -> di chuyển -> làm mục tiêu chưa xong -> trả quest)
function F.StepWorldNpcQuestEngine(allowEnteringRuns)
    local pausedForHeal, healReason = F.CheckTeamRecoveryPause()
    if pausedForHeal then
        Session.questStatusText = "[TẠM DỪNG HỒI PHỤC] " .. tostring(healReason)
        return true
    end

    Session.questOverrideMobIds = nil
    Session.questOverrideElement = nil

    local questsCfg = GetGameModule("Quests", { "Config", "Quests" })
    if type(questsCfg) ~= "table" then
        Session.questStatusText = "Chưa nạp được Config.Quests"
        return false
    end

    local questCtx, questLogic = F.BuildQuestContext()
    local metGivers = questCtx.metGivers or {}
    for _, npcId in ipairs(C.Npcs) do
        if metGivers[npcId] == true then
            Session.metNpcs[npcId] = true
        elseif not Session.metNpcs[npcId] then
            Session.metNpcs[npcId] = true
            FireRemote("MeetNpc", npcId)
        end
    end
    local progress = questCtx.questProgress or {}
    local claimedLines = questCtx.claimedQuestlines or {}
    local clearedBosses = questCtx.clearedBosses or {}

    local targetWorlds = {}
    if Config.QuestWorldFilter and Config.QuestWorldFilter ~= "Tất cả World (Theo Tiến Độ)" then
        targetWorlds = { Config.QuestWorldFilter }
    else
        targetWorlds = C.BossWorlds
    end

    local wantedNpc = Config.SelectedQuestNpc
    if wantedNpc == "Tất cả NPC trong World" or wantedNpc == "" then
        wantedNpc = nil
    end

    local activeQuestId, activeQuestDef, activeWorldId, activeGiver, activeUnmetObj = nil, nil, nil, nil, nil

    local function processLine(lineDef, fallbackWorldId)
        if type(lineDef) ~= "table" or type(lineDef.quests) ~= "table" then return end
        if lineDef.daily and not Config.AutoDailyQuests then return end
        local lineId = lineDef.id
        if type(questLogic) == "table" and typeof(questLogic.lineLocked) == "function" then
            local okLock, isLocked = SafeCallGame(questLogic.lineLocked, lineId, questCtx)
            if okLock and isLocked == true then
                return
            end
        end

        local claimedOrder = tonumber(claimedLines[lineId]) or 0
        local nextOrder = claimedOrder + 1
        local qId = lineDef.quests[nextOrder]
        if type(qId) ~= "string" then return end

        if type(questLogic) == "table" and typeof(questLogic.stepClosed) == "function" then
            local okClosed, isClosed = SafeCallGame(questLogic.stepClosed, qId, questCtx)
            if okClosed and isClosed == true then
                return
            end
        end

        local okG, giver = false, nil
        if typeof(questsCfg.giverOf) == "function" then
            okG, giver = SafeCallGame(questsCfg.giverOf, qId)
        end
        if not okG then giver = nil end
        if wantedNpc and giver ~= wantedNpc then
            return
        end

        local okW, qWorld = false, nil
        if typeof(questsCfg.worldOf) == "function" then
            okW, qWorld = SafeCallGame(questsCfg.worldOf, qId)
        end
        local resolvedWorld = (okW and type(qWorld) == "string" and qWorld) or fallbackWorldId
        if Config.QuestWorldFilter and Config.QuestWorldFilter ~= "Tất cả World (Theo Tiến Độ)" then
            if resolvedWorld and resolvedWorld ~= Config.QuestWorldFilter then
                return
            end
        end

        if not progress[qId] and type(giver) == "string" then
            FireRemote("MeetNpc", giver)
            local metBefore = false
            if type(questLogic) == "table" and typeof(questLogic.metBeforeAccept) == "function" then
                local okMB, isMB = SafeCallGame(questLogic.metBeforeAccept, qId, questCtx)
                metBefore = okMB and isMB == true
            end
            if metBefore then
                InvokeRemote("ClaimNpcOffer", giver, qId)
                InvokeRemote("ClaimQuest", qId)
                return
            else
                local pOkAcc, accOk = InvokeRemote("AcceptNpcQuest", giver, qId)
                if pOkAcc and accOk then
                    progress[qId] = { counts = {} }
                end
            end
        end

        local okDef, qDef = false, nil
        if typeof(questsCfg.getQuest) == "function" then
            okDef, qDef = SafeCallGame(questsCfg.getQuest, qId)
        end
        if not (okDef and type(qDef) == "table") then return end

        local readyBy = (type(qDef.dialogue) == "table" and qDef.dialogue.readyBy) or giver
        local isClaimable = false
        local unmetObj = qDef.objectives and qDef.objectives[1] or nil

        if type(questLogic) == "table" and typeof(questLogic.evaluateQuest) == "function" then
            local okEval, evalRes = SafeCallGame(questLogic.evaluateQuest, qDef, questCtx, progress[qId])
            if okEval and type(evalRes) == "table" then
                isClaimable = evalRes.met == true
                if not isClaimable and typeof(questLogic.nextObjective) == "function" then
                    local okNext, _, nextObj = SafeCallGame(questLogic.nextObjective, qDef, evalRes)
                    if okNext and type(nextObj) == "table" then
                        unmetObj = nextObj
                    end
                end
            end
        else
            isClaimable = progress[qId] ~= nil
        end

        if progress[qId] and isClaimable then
            if type(readyBy) == "string" then
                InvokeRemote("ClaimNpcOffer", readyBy, qId)
            end
            if type(giver) == "string" and giver ~= readyBy then
                InvokeRemote("ClaimNpcOffer", giver, qId)
            end
            InvokeRemote("ClaimQuest", qId)
        end

        if not activeQuestId and not isClaimable then
            activeQuestId = qId
            activeQuestDef = qDef
            activeWorldId = resolvedWorld
            activeGiver = giver
            activeUnmetObj = unmetObj
        end
    end

    for _, wid in ipairs(targetWorlds) do
        local okWLines, worldLines = SafeCallGame(questsCfg.worldLines, wid)
        local linesList = (okWLines and type(worldLines) == "table") and worldLines or {}
        for _, lineDef in ipairs(linesList) do
            processLine(lineDef, wid)
        end
    end

    if Config.AutoDailyQuests and typeof(questsCfg.getAllLines) == "function" then
        local okAll, allLines = SafeCallGame(questsCfg.getAllLines)
        if okAll and type(allLines) == "table" then
            for _, lineDef in pairs(allLines) do
                if type(lineDef) == "table" and lineDef.daily == true then
                    processLine(lineDef, nil)
                end
            end
        end
    end

    local gamemode = tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld")
    local isOverworld = (gamemode == "overworld")

    if not (activeQuestId and activeQuestDef) then
        Session.questCombatActive = false
        Session.activeQuestDoneInRun = true
        if not isOverworld then
            F.StepQuestActiveRunCombat(gamemode, true)
            return true
        end
        Session.questStatusText = string.format("World [%s]: Đã hoàn tất mọi nhiệm vụ đã mở khóa!", tostring(Config.QuestWorldFilter))
        return false
    end

    Session.activeQuestDoneInRun = false

    if Config.AutoPinActiveQuest and Session.lastPinnedQuestId ~= activeQuestId then
        Session.lastPinnedQuestId = activeQuestId
        FireRemote("PinQuest", activeQuestId)
    end

    local obj = activeUnmetObj or (type(activeQuestDef.objectives) == "table" and activeQuestDef.objectives[1]) or nil
    local kind = type(obj) == "table" and (obj.kind == "event" and ("event:" .. tostring(obj.event or "?")) or obj.kind) or "unknown"
    Session.questStatusText = string.format("[%s] NPC %s -> %s (%s)",
        tostring(activeWorldId or "daily"), tostring(activeGiver or "Daily"), tostring(activeQuestDef.displayName or activeQuestId), tostring(kind))

    -- Nếu đang ở trong Raid / Story Mission / World Boss / Defense: tự động Tele tới quái, điều quân đánh, dùng kỹ năng, mở rương & vote kết quả
    if not isOverworld then
        Session.questCombatActive = true
        F.StepQuestActiveRunCombat(gamemode, false)
        return true
    end

    if Config.AutoTravelForNpcQuest and type(activeWorldId) == "string" and activeWorldId ~= "" then
        if not F.IsAlreadyInOverworldArea(activeWorldId) and os.clock() - Session.lastQuestTravelAt > 6 then
            Session.lastQuestTravelAt = os.clock()
            F.TravelToWorld(activeWorldId, true)
            return true
        end
    end

    -- Kiểm tra nếu nhiệm vụ có gắn Story Mission qua Quests.missionOf(activeQuestDef) và QuestLogic.holdsMission
    if allowEnteringRuns and Config.AutoRunQuestMissionsAndBoss and typeof(questsCfg.missionOf) == "function" then
        local okMId, heldMissionId = SafeCallGame(questsCfg.missionOf, activeQuestDef)
        if okMId and type(heldMissionId) == "string" and heldMissionId ~= "" then
            local holds = true
            if type(questLogic) == "table" and typeof(questLogic.holdsMission) == "function" then
                local okH, isHeld = SafeCallGame(questLogic.holdsMission, heldMissionId, questCtx)
                if okH then holds = (isHeld == true) end
            end
            if holds then
                Session.questCombatActive = true
                F.StartSelectedStoryMission(heldMissionId)
                return true
            end
        end
    end

    local needsWorldCombat = false
    local objectivesToRun = activeUnmetObj and { activeUnmetObj } or (type(activeQuestDef.objectives) == "table" and activeQuestDef.objectives or {})
    for _, o in ipairs(objectivesToRun) do
        if type(o) == "table" then
            if o.kind == "meet" and type(o.npcId) == "string" then
                FireRemote("MeetNpc", o.npcId)
            elseif o.kind == "find" then
                F.TeleportAndCollectQuestItemsForQuest(activeQuestId, o.spots, questCtx, questLogic)
            elseif o.kind == "repair" and type(o.repairId) == "string" then
                F.RepairSingle(o.repairId)
            elseif o.kind == "equip" and type(o.element) == "string" then
                F.EnsureElementChampionEquipped(o.element)
            elseif o.kind == "flag" and type(o.flag) == "string" then
                needsWorldCombat = true
                local flagMob = FlagToEnemyMap[o.flag]
                if flagMob then
                    Session.questOverrideMobIds = { [flagMob] = true }
                end
            elseif o.kind == "collect" then
                needsWorldCombat = true
                local targetEnemy = o.enemyId or o.from
                if type(targetEnemy) == "string" then
                    Session.questOverrideMobIds = { [targetEnemy] = true }
                end
            elseif o.kind == "kill" or o.kind == "event" then
                if o.kind == "event" and (o.event == "champion_fed" or o.event == "champion_level") then
                    F.AutoFeedEquippedChampions()
                    needsWorldCombat = true
                elseif o.kind == "event" and o.event == "summon" then
                    InvokeRemote("UnlockBanner", Config.SelectedBanner)
                    F.PullBannerOnce()
                elseif o.kind == "event" and (o.event == "weekly_challenge_win" or o.event == "raid_win" or o.event == "raid_complete") and allowEnteringRuns and Config.AutoRunQuestMissionsAndBoss then
                    Session.questCombatActive = true
                    F.StartSelectedRaidChallenge(Config.SelectedRaidBase, Config.SelectedRaidTier)
                    return true
                else
                    local targetBossWorld = (o.kind == "kill" and type(o.enemyId) == "string") and F.ResolveWorldOfBossEnemy(o.enemyId) or nil
                    if targetBossWorld and allowEnteringRuns and Config.AutoRunQuestMissionsAndBoss then
                        Session.questCombatActive = true
                        F.RepairSingle(targetBossWorld .. "_boss_portal")
                        F.ChallengeSelectedBoss(targetBossWorld)
                        return true
                    end
                    needsWorldCombat = true
                    if type(o.enemyId) == "string" then
                        Session.questOverrideMobIds = { [o.enemyId] = true }
                    elseif type(o.target) == "string" and o.kind == "kill" then
                        Session.questOverrideMobIds = { [o.target] = true }
                    elseif type(o.enemyElement) == "string" then
                        Session.questOverrideElement = o.enemyElement
                    end
                end
            elseif o.kind == "mission" and type(o.missionId) == "string" then
                if allowEnteringRuns and Config.AutoRunQuestMissionsAndBoss then
                    Session.questCombatActive = true
                    F.StartSelectedStoryMission(o.missionId)
                    return true
                end
            elseif o.kind == "boss" and type(o.worldId) == "string" then
                if allowEnteringRuns and Config.AutoRunQuestMissionsAndBoss then
                    Session.questCombatActive = true
                    F.RepairSingle(o.worldId .. "_boss_portal")
                    F.ChallengeSelectedBoss(o.worldId)
                    return true
                end
            end
        end
    end

    Session.questCombatActive = needsWorldCombat
    -- Tự động Tele tới bãi quái nhiệm vụ trong World và điều quân đánh + tung kỹ năng
    local engaged = F.TryEngageNearestPack(true)
    if engaged then
        F.FireAllEquippedAbilities()
    end
    return true
end

-- Auto Hoàn Thành Tân Thủ Cho Tài Khoản Mới (stage -> summon -> fight -> done)
function F.StepAutoTutorial()
    local tutorialMod = GetGameModule("Tutorial", { "Shared", "Tutorial" })
    local tutStep = ReadStore("TutorialStep", "string")
    local normStep = "done"
    if type(tutorialMod) == "table" and typeof(tutorialMod.normalise) == "function" then
        local okN, resN = SafeCallGame(tutorialMod.normalise, tutStep)
        if okN and type(resN) == "string" then normStep = resN end
    elseif type(tutStep) == "string" and tutStep ~= "" then
        normStep = tutStep
    end

    if ReadStore("LevelUpLesson", "boolean") == true then
        FireRemote("Tips_EndLesson", "level_up")
    end

    local champions = ReadStore("Champions", "table") or {}
    local hasAnyChampion = next(champions) ~= nil
    if not hasAnyChampion then
        InvokeRemote("Starter_Pick", Config.SelectedStarter)
    end

    if normStep == "done" and hasAnyChampion then
        return false
    end

    local gamemode = tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld")
    if normStep == "stage" or not hasAnyChampion then
        if gamemode == "overworld" then
            local tutSvc = GetGameModule("ClientTutorialService", { "Client", "services", "ClientTutorialService" })
            if type(tutSvc) == "table" and typeof(tutSvc.StartRescue) == "function" then
                local okS, started = SafeCallGame(tutSvc.StartRescue)
                if okS and started then return true end
            end
            FireRemote("Tutorial_StartRescue", 1)
            return true
        else
            FireRemote("PlayerArrival_Presented")
            FireRemote("StageScene_Continue")
            F.ScanAndOpenChests(true)
            F.TryEngageNearestPack(true)
            F.FireAllEquippedAbilities()
            F.VoteMatchResults("lobby", false)
            return true
        end
    elseif normStep == "summon" then
        if gamemode == "overworld" then
            InvokeRemote("UnlockBanner", "alien")
            InvokeRemote("PullFromBanner", "alien", 1, nil)
            return true
        end
    elseif normStep == "fight" then
        F.StepWorldNpcQuestEngine(true)
        return true
    end
    return false
end

function F.ScanAndHandleQuests()
    local pausedForHeal, healReason = F.CheckTeamRecoveryPause()
    if pausedForHeal then
        Session.questStatusText = "[TẠM DỪNG HỒI PHỤC] " .. tostring(healReason)
        return
    end
    if Config.AutoWorldNpcQuestLoop then
        F.StepWorldNpcQuestEngine(true)
        return
    end

    for _, npcId in ipairs(C.Npcs) do
        if not Session.metNpcs[npcId] then
            Session.metNpcs[npcId] = true
            FireRemote("MeetNpc", npcId)
        end
    end

    local questsCfg = GetGameModule("Quests", { "Config", "Quests" })
    local questCtx, questLogic = F.BuildQuestContext()
    local progress = questCtx.questProgress or {}

    if Config.AutoAcceptQuests and type(questsCfg) == "table" and typeof(questsCfg.getAllLines) == "function" then
        local okLines, allLines = SafeCallGame(questsCfg.getAllLines)
        if okLines and type(allLines) == "table" then
            local claimedLines = questCtx.claimedQuestlines or {}
            for lineId, lineDef in pairs(allLines) do
                if type(lineDef) == "table" and (not lineDef.daily or Config.AutoDailyQuests) and type(lineDef.quests) == "table" then
                    local locked = false
                    if type(questLogic) == "table" and typeof(questLogic.lineLocked) == "function" then
                        local okL, isL = SafeCallGame(questLogic.lineLocked, lineId, questCtx)
                        locked = okL and isL == true
                    end
                    if not locked then
                        local nextOrder = (tonumber(claimedLines[lineId]) or 0) + 1
                        local nextQuestId = lineDef.quests[nextOrder]
                        if type(nextQuestId) == "string" and not progress[nextQuestId] then
                            local okG, giver = false, nil
                            if typeof(questsCfg.giverOf) == "function" then
                                okG, giver = SafeCallGame(questsCfg.giverOf, nextQuestId)
                            end
                            if okG and type(giver) == "string" then
                                InvokeRemote("AcceptNpcQuest", giver, nextQuestId)
                            end
                        end
                    end
                end
            end
        end
    end

    for questId in pairs(progress) do
        if type(questId) == "string" then
            if Config.AutoFindQuestItems then
                F.TeleportAndCollectQuestItemsForQuest(questId, nil, questCtx, questLogic)
            end
            if Config.AutoClaimQuests then
                local canClaim = true
                if type(questLogic) == "table" and typeof(questLogic.getQuestState) == "function" then
                    local okSt, st = SafeCallGame(questLogic.getQuestState, questId, questCtx)
                    if okSt then
                        canClaim = (st == "claimable")
                    end
                end
                if canClaim then
                    local okG, giver = false, nil
                    if type(questsCfg) == "table" and typeof(questsCfg.giverOf) == "function" then
                        okG, giver = SafeCallGame(questsCfg.giverOf, questId)
                    end
                    if okG and type(giver) == "string" then
                        InvokeRemote("ClaimNpcOffer", giver, questId)
                    end
                    InvokeRemote("ClaimQuest", questId)
                end
            end
        end
    end
end

-- ============================================================================
-- [9b] AUTO FARM BOSS / RAID / CHẾ ĐỘ THÔNG MINH (TỰ NHẬN DIỆN MỌI CHẾ ĐỘ)
-- ============================================================================
function F.StepUniversalModeFarm()
    local gamemode = tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld")

    -- Mọi chế độ: nhặt drop, mở rương (tự dịch chuyển tới rương khi ở trong màn chơi)
    F.ScanAndClaimEcsDrops()
    F.ScanAndOpenChests(gamemode ~= "overworld")

    local pausedForHeal, healReason = F.CheckTeamRecoveryPause()
    if pausedForHeal then
        Session.universalStatusText = "[TẠM DỪNG HỒI PHỤC] " .. tostring(healReason)
        return
    end

    if gamemode == "raid" then
        FireRemote("PlayerArrival_Presented")
        if F.HandleRaidIntermission(true) then
            Session.universalStatusText = "[RAID] Đang chọn thẻ Buff & qua màn kế tiếp..."
            return
        end
        F.VoteMatchResults(Config.MatchVoteOption, false)
        local engaged, msg = F.TryEngageNearestPack(true)
        F.FireAllEquippedAbilities()
        Session.universalStatusText = engaged and ("[RAID] Đang đánh: " .. tostring(msg)) or "[RAID] Đang chờ đợt quái / kết quả..."
        return
    end

    if gamemode == "defense" then
        FireRemote("PlayerArrival_Presented")
        FireRemote("Defense_RequestNextWave")
        F.VoteMatchResults(Config.MatchVoteOption, false)
        local engaged, msg = F.TryEngageNearestPack(true)
        F.FireAllEquippedAbilities()
        Session.universalStatusText = engaged and ("[DEFENSE] Đang bảo vệ trụ: " .. tostring(msg)) or "[DEFENSE] Đang gọi đợt quái kế tiếp..."
        return
    end

    if gamemode == "stage" then
        FireRemote("PlayerArrival_Presented")
        FireRemote("StageScene_Continue")
        if Session.lastMissionTalkRunId then
            FireRemote("MissionTalk_Ended", Session.lastMissionTalkRunId)
            Session.lastMissionTalkRunId = nil
        end
        F.VoteMatchResults(Config.MatchVoteOption, false)
        local engaged, msg = F.TryEngageNearestPack(true)
        F.FireAllEquippedAbilities()
        Session.universalStatusText = engaged and ("[STAGE/BOSS] Đang chiến đấu: " .. tostring(msg)) or "[STAGE/BOSS] Đang dọn màn & mở rương..."
        return
    end

    -- Khi đang ở Overworld / Sảnh
    local targetMode = Config.UniversalOverworldTarget
    if targetMode == "Làm Nhiệm Vụ NPC Theo World Đã Chọn" then
        F.StepWorldNpcQuestEngine(true)
        F.FireAllEquippedAbilities()
        Session.universalStatusText = "[OVERWORLD -> QUEST] " .. tostring(Session.questStatusText)
        return
    end

    if os.clock() - Session.lastUniversalQueueAt >= 2.0 then
        Session.lastUniversalQueueAt = os.clock()
        if targetMode == "Vào & Farm World Boss Đã Chọn" then
            local okBoss, msg = F.ChallengeSelectedBoss(Config.SelectedBossWorld)
            Session.universalStatusText = "[OVERWORLD -> BOSS] " .. tostring(msg)
            if okBoss then
                return
            end
        elseif targetMode == "Vào & Farm Raid Đã Chọn" then
            local _, msg = F.StartSelectedRaidChallenge(Config.SelectedRaidBase, Config.SelectedRaidTier)
            Session.universalStatusText = "[OVERWORLD -> RAID] " .. tostring(msg)
        elseif targetMode == "Vào & Farm Story Mission Đã Chọn" then
            local _, msg = F.StartSelectedStoryMission(Config.SelectedMission)
            Session.universalStatusText = "[OVERWORLD -> MISSION] " .. tostring(msg)
        end
    end

    -- Mặc định khi ở Overworld (hoặc trong lúc chờ đếm ngược Lobby): tự đánh nhóm quái gần nhất
    local engaged, msg = F.TryEngageNearestPack(false)
    if engaged then
        F.FireAllEquippedAbilities()
    end
    Session.universalStatusText = engaged and ("[OVERWORLD] Đang farm quái: " .. tostring(msg)) or "[OVERWORLD] Đang chờ quái hoặc đếm ngược vào màn..."
end

function F.ClaimAllMilestonesSmart()
    local milestoneLogic = GetGameModule("MilestoneLogic", { "Shared", "MilestoneLogic" })
    if type(milestoneLogic) == "table" and typeof(milestoneLogic.countClaimable) == "function" then
        local mCtx = {
            stats = ReadStore("Stats", "table") or {},
            discoveredCharacters = ReadStore("DiscoveredCharacters", "table") or {},
            claimedMilestones = ReadStore("ClaimedMilestones", "table") or {}
        }
        local okC, count = SafeCallGame(milestoneLogic.countClaimable, mCtx)
        if okC and type(count) == "number" and count <= 0 then
            return 0
        end
    end
    local pOk, ok = InvokeRemote("ClaimAllMilestones")
    return (pOk and ok) and 1 or 0
end

function F.ClaimDailyBonusSmart()
    if ReadStore("DailyBonusClaimed", "boolean") == true then
        return false
    end
    local questCtx, questLogic = F.BuildQuestContext()
    if type(questLogic) == "table" and typeof(questLogic.getDailyBonusProgress) == "function" then
        local okD, prog = SafeCallGame(questLogic.getDailyBonusProgress, questCtx)
        if okD and type(prog) == "table" and prog.state ~= "claimable" then
            return false
        end
    end
    local pOk, ok = InvokeRemote("ClaimDailyBonus")
    return pOk and ok == true
end

function F.ClaimSeasonPassSmart()
    local spData = ReadStore("SeasonPass", "table")
    local spLogic = GetGameModule("SeasonPassLogic", { "Shared", "SeasonPassLogic" })
    local spLiveSvc = GetGameModule("ClientSeasonLiveService", { "Client", "services", "ClientSeasonLiveService" })
    local fusion = GetGameModule("Fusion", { "Packages", "Fusion" })
    if type(spData) == "table" and type(spLogic) == "table" and type(spLiveSvc) == "table" and spLiveSvc.Season and type(fusion) == "table" and typeof(fusion.peek) == "function" then
        local okS, seasonDef = SafeCallGame(fusion.peek, spLiveSvc.Season)
        if okS and type(seasonDef) == "table" and typeof(spLogic.progressFrom) == "function" and typeof(spLogic.rewardsLeft) == "function" then
            local okP, prog = SafeCallGame(spLogic.progressFrom, seasonDef, spData)
            if okP and type(prog) == "table" then
                local okL, left = SafeCallGame(spLogic.rewardsLeft, seasonDef, prog)
                if okL and type(left) == "number" and left <= 0 then
                    return 0
                end
            end
        end
    end
    local pOk, ok = InvokeRemote("ClaimAllSeasonPass")
    return (pOk and ok) and 1 or 0
end

function F.ClaimAllSeasonRepeatables()
    local spData = ReadStore("SeasonPass", "table")
    if not (type(spData) == "table" and type(spData.repeatables) == "table") then return 0 end
    local spLogic = GetGameModule("SeasonPassLogic", { "Shared", "SeasonPassLogic" })
    local spLiveSvc = GetGameModule("ClientSeasonLiveService", { "Client", "services", "ClientSeasonLiveService" })
    local fusion = GetGameModule("Fusion", { "Packages", "Fusion" })
    local seasonDef = nil
    if type(spLiveSvc) == "table" and spLiveSvc.Season and type(fusion) == "table" and typeof(fusion.peek) == "function" then
        local okS, sDef = SafeCallGame(fusion.peek, spLiveSvc.Season)
        if okS and type(sDef) == "table" then seasonDef = sDef end
    end

    local claimed = 0
    for repId, progressVal in pairs(spData.repeatables) do
        if type(repId) == "string" and type(progressVal) == "number" and progressVal > 0 then
            local readyToClaim = true
            if seasonDef and type(spLogic) == "table" and typeof(spLogic.planRepeatableClaim) == "function" then
                local okPlan, plan = SafeCallGame(spLogic.planRepeatableClaim, seasonDef, spData, repId, Workspace:GetServerTimeNow())
                readyToClaim = okPlan and type(plan) == "table"
            end
            if readyToClaim then
                local pOk, ok = InvokeRemote("ClaimSeasonRepeatable", repId)
                if pOk and ok then
                    claimed = claimed + 1
                end
            end
        end
    end
    return claimed
end

function F.ClaimFreeStoreAndGifts()
    local claimed = 0
    local freeClaims = ReadStore("FreeClaims", "table")
    local purchasedPacks = ReadStore("PurchasedPacks", "table") or {}
    if type(freeClaims) == "table" then
        for key, isFree in pairs(freeClaims) do
            if isFree == true and purchasedPacks[key] ~= true then
                local pOk, ok = InvokeRemote("ClaimFreeProduct", key)
                if pOk and ok == true then
                    claimed = claimed + 1
                end
            end
        end
    end

    local receivedGifts = ReadStore("ReceivedGifts", "table")
    if type(receivedGifts) == "table" then
        for giftKey, count in pairs(receivedGifts) do
            if type(count) == "number" and count > 0 then
                local pOk, ok = InvokeRemote("ClaimGift", giftKey)
                if pOk and ok == true then
                    claimed = claimed + 1
                end
            end
        end
    end
    return claimed
end

function F.TryBuyPassWithVouchers(passKey)
    local target = passKey or Config.SelectedVoucherPass
    local cost = C.VoucherPassCosts[target] or 0
    local vouchers = ReadStore("Items/voucher", "number") or 0
    if LocalPlayer:GetAttribute("OwnsPass_" .. tostring(target)) == true then
        return false, "đã sở hữu Gamepass " .. tostring(target)
    end
    if vouchers < cost then
        return false, string.format("cần %d Voucher (hiện có %d)", cost, vouchers)
    end
    local pOk, ok, err = InvokeRemote("BuyPassWithVouchers", target)
    if pOk and ok == true then
        return true, "Đã mở khóa Gamepass bằng Voucher: " .. tostring(target)
    end
    return false, tostring(err or ok or "bị từ chối")
end

function F.GetCurrencyBalance(currencyId, itemsTbl)
    local cid = tostring(currencyId or "gold")
    if type(itemsTbl) == "table" and type(itemsTbl[cid]) == "number" then
        return itemsTbl[cid]
    end
    local direct = ReadStore("Items/" .. cid, "number")
    if type(direct) == "number" then
        return direct
    end
    return nil
end

local WorldProgressionRank = {
    alien = 1,
    pirate = 2,
    ninja = 3,
    city = 4,
    ant = 5
}

local PrevWorldByWorld = {
    pirate = "alien",
    ninja = "pirate",
    city = "ninja",
    ant = "city"
}

function F.IsWorldUnlockedSmart(requiredWorld, clearedBosses, hasValidCleared, catalog, offer, overworldCfg)
    if type(requiredWorld) ~= "string" or requiredWorld == "" or requiredWorld == "alien" then
        return true
    end
    local prevWorld = PrevWorldByWorld[requiredWorld]
    if type(clearedBosses) == "table" then
        if prevWorld and clearedBosses[prevWorld] == true then
            return true
        end
        if clearedBosses[requiredWorld] == true then
            return true
        end
    end
    -- Nếu người chơi đang đứng ở một World >= requiredWorld hoặc đã mở khóa Banner của World đó thì chắc chắn đã mở khóa
    local reqRank = WorldProgressionRank[requiredWorld] or 99
    local curArea = F.GetCurrentOverworldArea()
    local curRank = WorldProgressionRank[curArea] or 0
    if curRank >= reqRank then
        return true
    end
    local unlockedBanners = ReadStore("UnlockedBanners", "table", true)
    if type(unlockedBanners) == "table" then
        for bannerId, isUnl in pairs(unlockedBanners) do
            if isUnl == true and (WorldProgressionRank[bannerId] or 0) >= reqRank then
                return true
            end
        end
    end
    if hasValidCleared then
        if type(catalog) == "table" and typeof(catalog.isOfferUnlocked) == "function" and type(offer) == "table" then
            local okU, isU = SafeCallGame(catalog.isOfferUnlocked, offer, clearedBosses)
            if okU then return isU == true end
        end
        if type(overworldCfg) == "table" and typeof(overworldCfg.isWorldUnlocked) == "function" then
            local okW, isW = SafeCallGame(overworldCfg.isWorldUnlocked, clearedBosses, requiredWorld)
            if okW then return isW == true end
        end
        return false
    end
    -- Khi chưa đọc được bảng ClearedBosses thực tế: không tự chặn oan ở client
    return true
end

function F.OpenMerchantWindowOnScreen(merchantId)
    local target = tostring(merchantId or Config.SelectedMerchant or "GoldMerchant")
    -- 1. Thử tìm trực tiếp thực thể ClientMerchantService hoặc ClientUIService đang sống trong GC của LocalScript game
    local gcFn = (typeof(getgc) == "function" and getgc) or nil
    if gcFn then
        local okGc, list = pcall(gcFn, true)
        EnsureHighIdentity()
        if okGc and type(list) == "table" then
            for i = 1, #list do
                local obj = list[i]
                if type(obj) == "table" then
                    if rawget(obj, "WindowId") == "Merchant" and typeof(rawget(obj, "OpenWindow")) == "function" then
                        local okOpen = SafeCallGame(obj.OpenWindow, target)
                        if okOpen then
                            Notify("Thương Nhân", "Đã mở giao diện: " .. target, 2)
                            return true
                        end
                    end
                end
            end
            for i = 1, #list do
                local obj = list[i]
                if type(obj) == "table" and typeof(rawget(obj, "Navigate")) == "function" and typeof(rawget(obj, "RegisterWindow")) == "function" then
                    local okNav = SafeCallGame(obj.Navigate, {
                        window = "Merchant",
                        intent = { merchant_id = target }
                    })
                    if okNav then
                        Notify("Thương Nhân", "Đã mở giao diện: " .. target, 2)
                        return true
                    end
                end
            end
        end
    end

    local mSvc = GetGameModule("ClientMerchantService", { "Client", "services", "ClientMerchantService" })
    if type(mSvc) == "table" and typeof(mSvc.OpenWindow) == "function" then
        SafeCallGame(mSvc.OpenWindow, target)
    end
    local uiSvc = GetGameModule("ClientUIService", { "Client", "services", "ClientUIService" })
    if type(uiSvc) == "table" and typeof(uiSvc.Navigate) == "function" then
        SafeCallGame(uiSvc.Navigate, {
            window = "Merchant",
            intent = { merchant_id = target }
        })
    end
    return true
end

function F.BuyAllMerchantOffers(merchantId, forceAttempt)
    local target = tostring(merchantId or Config.SelectedMerchant or "GoldMerchant")
    local selectedSet, selectedCount = F.GetActiveSelectedMerchantItemsSet(target)
    -- Chỉ áp dụng bộ lọc Multi khi người chơi có tích chọn ít nhất 1 món VÀ đang bật lọc (hoặc có chọn món trong hộp Multi).
    -- Nếu người chơi bật "Chỉ Mua Các Món Đồ Đã Chọn" nhưng hộp Multi đang để trống (0 món), tự động mua toàn bộ kệ thay vì đứng im!
    local useItemFilter = (selectedCount > 0) and (Config.FilterMerchantBySelectedItems ~= false)

    -- Đảm bảo đã gửi MeetNpc cho NPC thương nhân tương ứng
    local merchantNpcMap = {
        GoldMerchant = "gold_merchant",
        DefenseMerchant = "defense_merchant",
        RaidMerchant = "raid_merchant",
        ShardMerchant = "shard_merchant"
    }
    local npcId = merchantNpcMap[target]
    if npcId and not Session.metNpcs[npcId] then
        Session.metNpcs[npcId] = true
        FireRemote("MeetNpc", npcId)
    end

    local catalog = GetGameModule("MerchantCatalog", { "Config", "MerchantCatalog" })
    local repairsCfg = GetGameModule("Repairs", { "Config", "Repairs" })
    local questsCfg = GetGameModule("Quests", { "Config", "Quests" })
    local overworldCfg = GetGameModule("OverworldMode", { "Config", "OverworldMode" })

    local rawItems = ReadStore("Items", "table")
    local rawCleared = ReadStore("ClearedBosses", "table")
    local rawRepaired = ReadStore("Repaired", "table")
    local rawWeekly = ReadStore("MerchantWeeklyBuys", "table")

    local items = type(rawItems) == "table" and rawItems or {}
    local clearedBosses = type(rawCleared) == "table" and rawCleared or {}
    local repairedMap = type(rawRepaired) == "table" and rawRepaired or {}
    local weeklyBuys = type(rawWeekly) == "table" and rawWeekly or {}

    for repId, isRep in pairs(repairedMap) do
        if isRep == true then
            Session.knownRepaired[repId] = true
        end
    end

    local currencyId = C.MerchantCurrencyMap[target] or "gold"
    local knownBalance = F.GetCurrencyBalance(currencyId, rawItems)
    local knownGold = F.GetCurrencyBalance("gold", rawItems)
    local hasValidBalance = (type(knownBalance) == "number")
    local hasValidGold = (type(knownGold) == "number")
    local hasValidCleared = (type(rawCleared) == "table" and next(rawCleared) ~= nil)

    local now = Workspace:GetServerTimeNow()
    local bought = 0
    local boughtNames = {}
    local failReasons = {}

    -- 1. Mua các gói Upgrades thuộc Thương Nhân này:
    --    - auto_abilities: 1,000 Gold (1K Gold)
    --    - gold_team_slot (Ô Đội I +1 Tướng -> 4 tướng): 100,000 Gold (100K Gold)
    --    - gold_team_slot_2 (Ô Đội II +1 Tướng -> 5 tướng, yêu cầu đã mua gold_team_slot): 100,000,000 Gold (100M Gold)
    --    - storage_1 (1K), storage_2 (100K), storage_3 (10M): released = false trong PlaceVersion 4
    local merchantUpgrades = C.MerchantUpgradesByMerchant[target] or {}
    for _, upgradeId in ipairs(merchantUpgrades) do
        local isSelectedUpgrade = (selectedSet[upgradeId] == true)
        local upgradeAllowed = (not useItemFilter) or isSelectedUpgrade
        local alreadyOwned = (repairedMap[upgradeId] == true) or (Session.knownRepaired[upgradeId] == true)

        if upgradeAllowed and not alreadyOwned then
            local uDef = C.MerchantUpgradeDefsFallback[upgradeId]
            if type(repairsCfg) == "table" and typeof(repairsCfg.get) == "function" then
                local okU, runtimeDef = SafeCallGame(repairsCfg.get, upgradeId)
                if okU and type(runtimeDef) == "table" then
                    uDef = runtimeDef
                end
            end

            local upgradePrice = (type(uDef) == "table" and tonumber(uDef.price)) or 0
            local reqId = type(uDef) == "table" and uDef.requires or nil
            local isReleased = not (type(uDef) == "table" and uDef.released == false)
            local prereqMet = (not reqId) or (repairedMap[reqId] == true) or (Session.knownRepaired[reqId] == true)

            local canTryUpgrade = false
            if not isReleased then
                if isSelectedUpgrade then
                    failReasons[#failReasons + 1] = string.format("%s: chưa mở bán trong phiên bản game này", upgradeId)
                end
            elseif forceAttempt and isSelectedUpgrade then
                -- Người chơi tích chọn trực tiếp gói Upgrade này và bấm nút Mua Ngay: luôn gửi lệnh lên server
                canTryUpgrade = true
            elseif not hasValidGold then
                -- Khi chưa đọc được số Vàng từ PlayerStore: thử gửi với cooldown 12s để không spam server
                if prereqMet then
                    local lastTry = Session.upgradeTryCooldown[upgradeId] or 0
                    if forceAttempt or (os.clock() - lastTry >= 12.0) then
                        canTryUpgrade = true
                    end
                elseif isSelectedUpgrade then
                    failReasons[#failReasons + 1] = string.format("%s: cần mua %s trước", upgradeId, tostring(reqId))
                end
            else
                if not prereqMet then
                    if isSelectedUpgrade then
                        local reqPrice = (C.MerchantUpgradeDefsFallback[reqId] and C.MerchantUpgradeDefsFallback[reqId].price) or 100000
                        failReasons[#failReasons + 1] = string.format("%s: cần mua %s (%s Gold) trước", upgradeId, tostring(reqId), FormatNumber(reqPrice))
                    end
                elseif knownGold < upgradePrice then
                    if isSelectedUpgrade or forceAttempt then
                        failReasons[#failReasons + 1] = string.format("%s: cần %s Gold (hiện có %s Gold)", upgradeId, FormatNumber(upgradePrice), FormatNumber(knownGold))
                    end
                else
                    canTryUpgrade = true
                end
            end

            if canTryUpgrade then
                Session.upgradeTryCooldown[upgradeId] = os.clock()
                local okRep, errRep = F.RepairSingle(upgradeId)
                if okRep then
                    bought = bought + 1
                    boughtNames[#boughtNames + 1] = upgradeId
                    repairedMap[upgradeId] = true
                    Session.knownRepaired[upgradeId] = true
                    if hasValidGold and upgradePrice > 0 then
                        knownGold = math.max(0, knownGold - upgradePrice)
                        items.gold = knownGold
                        if currencyId == "gold" then
                            knownBalance = knownGold
                        end
                    end
                    Notify("Thương Nhân [Upgrades]", string.format("Đã mua nâng cấp: %s (%s Gold)", tostring(upgradeId), FormatNumber(upgradePrice)), 4)
                else
                    local errStr = tostring(errRep or "")
                    if string.find(string.lower(errStr), "already") then
                        repairedMap[upgradeId] = true
                        Session.knownRepaired[upgradeId] = true
                    elseif isSelectedUpgrade or forceAttempt then
                        failReasons[#failReasons + 1] = string.format("%s (giá %s Gold): %s", upgradeId, FormatNumber(upgradePrice), errStr)
                    end
                end
            end
        elseif upgradeAllowed and alreadyOwned and isSelectedUpgrade and forceAttempt then
            failReasons[#failReasons + 1] = upgradeId .. ": đã sở hữu"
        end
    end

    -- 2. Mua các Vật phẩm (Offers) thuộc Thương Nhân này
    local merchantDef = nil
    if type(catalog) == "table" and typeof(catalog.get) == "function" then
        local okM, mDef = SafeCallGame(catalog.get, target)
        if okM and type(mDef) == "table" and type(mDef.offers) == "table" then
            merchantDef = mDef
        end
    end

    -- Đồng bộ thời gian đóng cửa trực tiếp từ Workspace attribute (ví dụ ShardMerchantClosesAt) giống ClientMerchantHoursService
    if merchantDef and type(merchantDef.liveClosesAtKey) == "string" and type(catalog) == "table" and typeof(catalog.setLiveClosesAt) == "function" then
        local liveAttr = Workspace:GetAttribute(merchantDef.liveClosesAtKey)
        SafeCallGame(catalog.setLiveClosesAt, merchantDef, type(liveAttr) == "number" and liveAttr or nil)
    end

    if merchantDef and type(catalog) == "table" and typeof(catalog.isOpen) == "function" then
        local okOpen, isOpen = SafeCallGame(catalog.isOpen, merchantDef, now)
        if okOpen and isOpen == false then
            Session.merchantStatusText = string.format("[%s] Thương nhân này hiện đã đóng cửa!", target)
            return bought, Session.merchantStatusText
        end
    end

    local offersList = (merchantDef and merchantDef.offers) or C.MerchantOfferDefsFallback[target] or {}
    if #offersList == 0 then
        return bought, "Không tìm thấy danh sách vật phẩm của " .. target
    end

    if merchantDef and type(merchantDef.currencyId) == "string" then
        currencyId = merchantDef.currencyId
        knownBalance = F.GetCurrencyBalance(currencyId, items)
        hasValidBalance = (type(knownBalance) == "number")
    end

    local curWeek = 0
    if type(questsCfg) == "table" and typeof(questsCfg.dailyWeekOf) == "function" then
        local okW, w = SafeCallGame(questsCfg.dailyWeekOf, now)
        if okW and type(w) == "number" then curWeek = w end
    end

    -- Xác định thứ tự duyệt offerIndex:
    -- Với GoldMerchant (ladder = "world_fruit"), khi không lọc món cụ thể thì duyệt từ trái cây World cao nhất xuống thấp nhất
    -- để ưu tiên mua Trái Cây cấp cao nhất đang mở bán (ví dụ ninja_fruit / Trái Nguyên Tố 1,000 Gold ở World 3)
    local offerIndices = {}
    if target == "GoldMerchant" and not useItemFilter then
        for idx = #offersList, 1, -1 do
            offerIndices[#offerIndices + 1] = idx
        end
    else
        for idx = 1, #offersList do
            offerIndices[#offerIndices + 1] = idx
        end
    end

    local boughtLadder = {}
    for _, offerIndex in ipairs(offerIndices) do
        local offer = offersList[offerIndex]
        if type(offer) == "table" and type(offer.itemId) == "string" then
            local itemId = offer.itemId
            local isSelectedItem = (selectedSet[itemId] == true)
            local itemAllowed = (not useItemFilter) or isSelectedItem
            if not useItemFilter and offer.ladder and boughtLadder[offer.ladder] then
                itemAllowed = false
            end

            if itemAllowed then
                local packSize = tonumber(offer.packSize) or 1
                local unitPackPrice = tonumber(offer.price) or 1
                local unlocked = F.IsWorldUnlockedSmart(offer.requiredWorld, clearedBosses, hasValidCleared, catalog, offer, overworldCfg)

                local left = nil
                if type(rawWeekly) == "table" and type(catalog) == "table" and typeof(catalog.weeklyLeft) == "function" and typeof(catalog.weeklyKey) == "function" then
                    local okK, wKey = SafeCallGame(catalog.weeklyKey, target, itemId)
                    if okK and type(wKey) == "string" then
                        local okL, rem = SafeCallGame(catalog.weeklyLeft, offer, weeklyBuys[wKey], curWeek)
                        if okL and type(rem) == "number" then left = rem end
                    end
                end

                local canAttemptOffer = false
                if forceAttempt and isSelectedItem then
                    -- Khi người chơi chọn đích danh món này và bấm nút Mua Ngay: luôn gửi lệnh lên server
                    canAttemptOffer = true
                elseif not unlocked then
                    if isSelectedItem then
                        failReasons[#failReasons + 1] = string.format("%s: chưa mở khóa World %s", itemId, tostring(offer.requiredWorld or "?"))
                    end
                elseif left ~= nil and left < packSize then
                    if isSelectedItem or forceAttempt then
                        failReasons[#failReasons + 1] = itemId .. ": đã hết lượt mua tuần này"
                    end
                elseif not hasValidBalance then
                    -- Khi chưa đọc được số dư từ PlayerStore: thử gửi trực tiếp lên server
                    canAttemptOffer = true
                elseif knownBalance < unitPackPrice then
                    if isSelectedItem or forceAttempt then
                        failReasons[#failReasons + 1] = string.format("%s: cần %s %s (hiện có %s)", itemId, FormatNumber(unitPackPrice), currencyId, FormatNumber(knownBalance))
                    end
                else
                    canAttemptOffer = true
                end

                if canAttemptOffer then
                    local buyQty = packSize
                    if Config.MerchantBuyMaxPacks and hasValidBalance and knownBalance >= unitPackPrice then
                        if type(catalog) == "table" and typeof(catalog.getMaxAffordableQuantity) == "function" then
                            local okQ, maxQ = SafeCallGame(catalog.getMaxAffordableQuantity, offer, knownBalance, left)
                            if okQ and type(maxQ) == "number" and maxQ >= packSize then
                                buyQty = maxQ
                            end
                        else
                            local maxPacks = math.min(99, math.floor(knownBalance / unitPackPrice))
                            if type(left) == "number" then
                                maxPacks = math.min(maxPacks, math.floor(left / packSize))
                            end
                            buyQty = math.max(packSize, maxPacks * packSize)
                        end
                    end

                    local pOk, ok = InvokeRemote("PurchaseMerchantOffer", target, offerIndex, buyQty)
                    if not (pOk and ok == true) and buyQty > packSize then
                        -- Dự phòng: nếu mua số lượng lớn bị từ chối thì thử mua 1 gói chuẩn packSize
                        buyQty = packSize
                        pOk, ok = InvokeRemote("PurchaseMerchantOffer", target, offerIndex, buyQty)
                    end

                    if pOk and ok == true then
                        bought = bought + 1
                        boughtNames[#boughtNames + 1] = string.format("%dx %s", buyQty, itemId)
                        if offer.ladder then
                            boughtLadder[offer.ladder] = true
                        end
                        local totalCost = unitPackPrice * (buyQty / packSize)
                        if hasValidBalance then
                            knownBalance = math.max(0, knownBalance - totalCost)
                            items[currencyId] = knownBalance
                            if currencyId == "gold" then
                                knownGold = knownBalance
                            end
                        end
                    elseif isSelectedItem or (forceAttempt and unlocked) then
                        failReasons[#failReasons + 1] = string.format("%s (giá %s %s): server từ chối", itemId, FormatNumber(unitPackPrice), currencyId)
                    end
                end
            end
        end
    end

    local balanceTag = hasValidBalance and string.format(" | Số dư %s: %s", currencyId, FormatNumber(knownBalance)) or ""
    if bought > 0 then
        Session.merchantStatusText = string.format("[%s] Đã mua %d mục: %s%s", target, bought, table.concat(boughtNames, ", "), balanceTag)
    elseif #failReasons > 0 then
        Session.merchantStatusText = string.format("[%s] Chưa mua được: %s", target, table.concat(failReasons, " | "))
    else
        Session.merchantStatusText = string.format("[%s] Chưa có mục nào đủ tiền hoặc đủ điều kiện mua%s", target, balanceTag)
    end
    return bought, Session.merchantStatusText
end

function F.RedeemCodeString(rawText)
    local codes = {}
    for word in tostring(rawText or ""):gmatch("[^,%s;]+") do
        local clean = word:gsub("^%s+", ""):gsub("%s+$", "")
        if #clean > 0 then
            codes[#codes + 1] = clean
        end
    end
    if #codes == 0 then
        Notify("Giftcode", "Hãy nhập ít nhất 1 mã code.", 3)
        return
    end
    for _, code in ipairs(codes) do
        local pOk, status, detail, msg = InvokeRemote("RedeemCode", code)
        if pOk then
            Notify("Giftcode [" .. code .. "]", tostring(msg or detail or status or "Đã gửi"), 4)
        else
            Notify("Giftcode [" .. code .. "]", "Lỗi gọi RedeemCode", 3)
        end
        task.wait(0.3)
    end
end

function F.FetchAndRedeemServerCodes()
    local pOk, payload = InvokeRemote("CodeListGet")
    local redeemedMap = ReadStore("RedeemedCodes", "table") or {}
    local foundCodes = {}
    if pOk and type(payload) == "table" and type(payload.entries) == "table" then
        for codeKey, entry in pairs(payload.entries) do
            if type(codeKey) == "string" and (type(entry) ~= "table" or entry.active ~= false) then
                if not redeemedMap[codeKey] and not redeemedMap[string.lower(codeKey)] then
                    foundCodes[#foundCodes + 1] = codeKey
                end
            end
        end
    end
    if #foundCodes == 0 then
        Notify("Giftcode Server", "Server không trả về danh sách CodeListGet (chỉ mở cho dev) hoặc bạn đã nhập hết.", 4)
        return
    end
    for _, code in ipairs(foundCodes) do
        local ok, status, detail, msg = InvokeRemote("RedeemCode", code)
        if ok then
            Notify("Giftcode [" .. code .. "]", tostring(msg or detail or status or "Đã nhập"), 3)
        end
        task.wait(0.3)
    end
end

-- ============================================================================
-- [10] DỊCH CHUYỂN (HUBWARP), TỐC ĐỘ, TỐI ƯU FPS, MỞ CỬA SỔ UI & ESP
-- ============================================================================
function F.HubWarpTo(destination)
    local warpSvc = GetGameModule("ClientHubWarpService", { "Client", "services", "ClientHubWarpService" })
    if type(warpSvc) == "table" and typeof(warpSvc.Warp) == "function" then
        local ok, res = SafeCallGame(warpSvc.Warp, destination)
        if ok and res ~= false then
            Notify("HubWarp", "Đã warp tới: " .. tostring(destination), 3)
            return true
        end
    end
    local pOk, poseOrErr = InvokeRemote("HubWarp_Request", destination)
    if pOk and typeof(poseOrErr) == "CFrame" then
        TeleportCharacterTo(poseOrErr)
        Notify("HubWarp", "Đã warp tới: " .. tostring(destination), 3)
        return true
    end
    Notify("HubWarp", "Warp bị từ chối (" .. tostring(destination) .. "): " .. tostring(poseOrErr), 4)
    return false
end

function F.OpenGameWindow(windowId)
    local target = windowId or Config.SelectedWindow
    local uiSvc = GetGameModule("ClientUIService", { "Client", "services", "ClientUIService" })
    if type(uiSvc) == "table" and typeof(uiSvc.Navigate) == "function" then
        local ok, err = SafeCallGame(uiSvc.Navigate, { window = target })
        if ok then
            Notify("Cửa Sổ Game", "Đã mở cửa sổ: " .. tostring(target), 2)
            return true
        end
        Notify("Cửa Sổ Game", "Không mở được " .. tostring(target) .. ": " .. tostring(err), 4)
        return false
    end
    Notify("Cửa Sổ Game", "Chưa nạp được ClientUIService.", 3)
    return false
end

function F.ApplyAutoSprint(enabled)
    FireRemote("SetSetting", "AutoSprint", enabled == true)
    local moveSvc = GetGameModule("ClientMovementService", { "Client", "services", "ClientMovementService" })
    if type(moveSvc) == "table" and typeof(moveSvc.SetAutoSprint) == "function" then
        SafeCallGame(moveSvc.SetAutoSprint, enabled == true)
    end
    EnsureHighIdentity()
end

function F.ApplyLowLagMode(enabled)
    if enabled then
        pcall(function() ReplicatedStorage:SetAttribute("LowGraphics", true) end)
        EnsureHighIdentity()
        FireRemote("SetSetting", "Graphics", "Low")
        FireRemote("SetSetting", "OtherPlayersEffects", false)
        FireRemote("SetSetting", "CameraShake", false)
        FireRemote("SetSetting", "ScreenEffects", "Off")
        FireRemote("SetSetting", "SimpleDamageNumbers", true)
        local effPol = GetGameModule("EffectPolicy", { "Client", "EffectPolicy" })
        if type(effPol) == "table" then
            if typeof(effPol.setOtherPlayersEffects) == "function" then SafeCallGame(effPol.setOtherPlayersEffects, false) end
            if typeof(effPol.setOwnEffects) == "function" then SafeCallGame(effPol.setOwnEffects, false) end
        end
        local gfxMod = GetGameModule("GraphicsMode", { "Client", "GraphicsMode" })
        if type(gfxMod) == "table" and typeof(gfxMod.setMode) == "function" then
            SafeCallGame(gfxMod.setMode, "Low")
        end
    else
        pcall(function() ReplicatedStorage:SetAttribute("LowGraphics", false) end)
        EnsureHighIdentity()
        FireRemote("SetSetting", "Graphics", "Auto")
        FireRemote("SetSetting", "OtherPlayersEffects", true)
        FireRemote("SetSetting", "CameraShake", true)
        FireRemote("SetSetting", "ScreenEffects", "Mine")
        local effPol = GetGameModule("EffectPolicy", { "Client", "EffectPolicy" })
        if type(effPol) == "table" then
            if typeof(effPol.setOtherPlayersEffects) == "function" then SafeCallGame(effPol.setOtherPlayersEffects, true) end
            if typeof(effPol.setOwnEffects) == "function" then SafeCallGame(effPol.setOwnEffects, true) end
        end
        local gfxMod = GetGameModule("GraphicsMode", { "Client", "GraphicsMode" })
        if type(gfxMod) == "table" and typeof(gfxMod.setMode) == "function" then
            SafeCallGame(gfxMod.setMode, "Auto")
        end
    end
    EnsureHighIdentity()
end

function F.ClearTutorialTipsAndUnseen()
    local unseen = ReadStore("UnseenChampions", "table")
    if type(unseen) == "table" and next(unseen) ~= nil then
        FireRemote("ChampionsSeen")
    end
    local tipAction = ReadStore("TipAction", "string")
    if type(tipAction) == "string" and tipAction ~= "" then
        FireRemote("Tips_ActionDone")
    end
end

function F.GetEspFolder()
    EnsureHighIdentity()
    if Session.espFolder and Session.espFolder.Parent then
        return Session.espFolder
    end
    local folder = Instance.new("Folder")
    folder.Name = "HelmACXMainEsp"
    local okParent = pcall(function()
        folder.Parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    end)
    if not okParent then
        folder.Parent = Workspace
    end
    Session.espFolder = folder
    return folder
end

function F.SyncEsp(kind, enabled, targetsFn, fill)
    local registry = Session.esp[kind]
    if not enabled and next(registry) == nil then
        return
    end
    EnsureHighIdentity()
    local live = {}
    if enabled then
        for _, model in ipairs(targetsFn()) do
            if model and model.Parent then
                live[model] = true
                if not registry[model] then
                    local hl = Instance.new("Highlight")
                    hl.Adornee = model
                    hl.FillColor = fill
                    hl.OutlineColor = Color3.new(1, 1, 1)
                    hl.FillTransparency = 0.5
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = F.GetEspFolder()
                    registry[model] = hl
                end
            end
        end
    end
    for model, hl in pairs(registry) do
        if not live[model] or not model.Parent then
            pcall(hl.Destroy, hl)
            registry[model] = nil
        end
    end
end

F.EspKinds = {
    {
        kind = "npc",
        cfg = "ESPNpc",
        color = Color3.fromRGB(75, 186, 255),
        targets = function()
            return CollectionService:GetTagged(C.NpcTag)
        end
    },
    {
        kind = "chest",
        cfg = "ESPChest",
        color = Color3.fromRGB(255, 208, 67),
        targets = function()
            return CollectionService:GetTagged(C.ChestTag)
        end
    },
    {
        kind = "enemy",
        cfg = "ESPEnemy",
        color = Color3.fromRGB(255, 75, 75),
        targets = function()
            local list = {}
            local charsFolder = Workspace:FindFirstChild("Characters") or Workspace:FindFirstChild("Units")
            if charsFolder then
                for _, child in ipairs(charsFolder:GetChildren()) do
                    if child:IsA("Model") and child ~= LocalPlayer.Character then
                        list[#list + 1] = child
                    end
                end
            end
            return list
        end
    }
}

-- ============================================================================
-- [11] ANTI-AFK CHỦ ĐỘNG (nhường chế độ AFK của game để giữ thưởng chơi lâu)
-- ============================================================================
F.AntiAfk = { lastInput = Workspace:GetServerTimeNow(), lastNudge = nil, count = 0, detail = "", why = nil }
(function()
    local AFK_YIELD_UNTIL = 1020
    local AFK_LAST_RESORT = 1140

    local function DecideAntiAfk(enabled, yieldToGame, interval, idle, playOn, inAfkMode)
        if not enabled then return false, "đang TẮT" end
        if idle < interval then return false, "đang có thao tác" end
        if yieldToGame then
            if inAfkMode and idle < AFK_LAST_RESORT then
                return false, "nhường chế độ AFK của game"
            end
            if playOn and not inAfkMode and idle < AFK_YIELD_UNTIL then
                return false, "chờ game vào chế độ AFK"
            end
        end
        return true, nil
    end

    local function SendFakeInput(withMove)
        local userOk = pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
        local vimOk = pcall(function()
            local vim = game:GetService("VirtualInputManager")
            local function tap(key, hold)
                vim:SendKeyEvent(true, key, false, game)
                task.wait(hold)
                vim:SendKeyEvent(false, key, false, game)
            end
            tap(Enum.KeyCode.F15, 0.05)
            if withMove then
                tap(Enum.KeyCode.W, 0.1)
                tap(Enum.KeyCode.S, 0.1)
            end
        end)
        return userOk or vimOk, string.format("VirtualUser %s, VirtualInputManager %s",
            userOk and "OK" or "lỗi", vimOk and "OK" or "lỗi")
    end

    F.RunAntiAfk = function(force)
        local now = Workspace:GetServerTimeNow()
        local playOn = Workspace:GetAttribute(C.PlayRewardsOnAttribute) == true
        local inAfkMode = type(LocalPlayer:GetAttribute(C.AfkSinceAttribute)) == "number"
        local go, why = DecideAntiAfk(Config.AntiKick, Config.AntiAfkYield, Config.AntiAfkInterval, now - F.AntiAfk.lastInput, playOn, inAfkMode)
        F.AntiAfk.why = why
        if not (go or force) then
            return
        end
        local ok, detail = SendFakeInput(Config.AntiAfkMove)
        F.AntiAfk.lastInput, F.AntiAfk.lastNudge, F.AntiAfk.detail = now, now, detail
        F.AntiAfk.why = nil
        if ok then
            F.AntiAfk.count = F.AntiAfk.count + 1
        end
        return ok, detail
    end

    F.AntiAfkStatusText = function()
        if not Config.AntiKick then return "Anti-AFK: TẮT" end
        local now = Workspace:GetServerTimeNow()
        local text = "Anti-AFK: BẬT | rảnh " .. FormatDuration(now - F.AntiAfk.lastInput)
        if F.AntiAfk.lastNudge then
            text = text .. " | bấm cuối " .. FormatDuration(now - F.AntiAfk.lastNudge) .. " trước (" .. AntiAfk.detail .. ")"
        end
        if F.AntiAfk.why and F.AntiAfk.why ~= "đang có thao tác" then
            text = text .. " | " .. AntiAfk.why
        end
        return text
    end
end)()

-- ============================================================================
-- [12] NHÃN TRẠNG THÁI & CẬP NHẬT GIAO DIỆN
-- ============================================================================
function F.SetLabels(texts)
    EnsureHighIdentity()
    for key, text in pairs(texts) do
        if Session.lastLabelTexts[key] ~= text then
            local label = Session.labels[key]
            if label and typeof(label.Set) == "function" then
                Session.lastLabelTexts[key] = text
                pcall(label.Set, label, text)
            end
        end
    end
end

function F.GetLiveDpsValue()
    local dpsSvc = GetGameModule("ClientDpsMeterService", { "Client", "services", "ClientDpsMeterService" })
    local fusion = GetGameModule("Fusion", { "Packages", "Fusion" })
    if type(dpsSvc) == "table" and dpsSvc.Dps and type(fusion) == "table" and typeof(fusion.peek) == "function" then
        local okD, val = SafeCallGame(fusion.peek, dpsSvc.Dps)
        if okD and type(val) == "number" then
            return val
        end
    end
    return 0
end

function F.UpdateStatus()
    local gamemode = tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld")
    local area = F.GetCurrentOverworldArea()
    if area == "" then area = "?" end
    local liveDps = F.GetLiveDpsValue()
    local itemsTbl = ReadStore("Items", "table", true)
    local gold = (type(itemsTbl) == "table" and tonumber(itemsTbl.gold)) or ReadStore("Items/gold", "number") or 0
    local gems = (type(itemsTbl) == "table" and tonumber(itemsTbl.gems)) or ReadStore("Items/gems", "number") or 0
    local vouchers = (type(itemsTbl) == "table" and tonumber(itemsTbl.voucher)) or ReadStore("Items/voucher", "number") or 0
    local traitTokens = (type(itemsTbl) == "table" and tonumber(itemsTbl.trait_tokens)) or ReadStore("Items/trait_tokens", "number") or 0
    local statRerolls = (type(itemsTbl) == "table" and tonumber(itemsTbl.stat_reroll)) or ReadStore("Items/stat_reroll", "number") or 0
    local statLocks = (type(itemsTbl) == "table" and tonumber(itemsTbl.stat_lock)) or ReadStore("Items/stat_lock", "number") or 0
    local raidMedals = (type(itemsTbl) == "table" and tonumber(itemsTbl.raid_medal)) or ReadStore("Items/raid_medal", "number") or 0
    local defCrystals = (type(itemsTbl) == "table" and tonumber(itemsTbl.defense_crystals)) or ReadStore("Items/defense_crystals", "number") or 0
    local cometShards = (type(itemsTbl) == "table" and tonumber(itemsTbl.comet_shard)) or ReadStore("Items/comet_shard", "number") or 0

    local champions = ReadStore("Champions", "table", true) or {}
    local equipped = ReadStore("EquippedChampions", "table", true) or {}
    local totalChamps = 0
    for _ in pairs(champions) do totalChamps = totalChamps + 1 end

    local targetUid = F.GetTargetChampionUid()
    local targetChamp = targetUid and champions[targetUid] or nil
    local slotKey = tostring(Config.SelectedTraitSlot or "1")
    local curTrait = targetChamp and type(targetChamp.traits) == "table" and targetChamp.traits[slotKey] or "Chưa có"
    local curRarity = C.TraitRarityMap[curTrait] or "-"

    local statSummary = "-"
    if targetChamp and type(targetChamp.stat_rolls) == "table" then
        local parts = {}
        for _, sid in ipairs(C.StatIds) do
            local g = type(targetChamp.stat_rolls[sid]) == "table" and targetChamp.stat_rolls[sid].grade or "?"
            parts[#parts + 1] = string.sub(string.upper(sid), 1, 3) .. ":" .. tostring(g)
        end
        statSummary = table.concat(parts, " | ")
    end

    local _, selectedMobCount = F.GetActiveSelectedMobsSet()
    F.CheckTeamRecoveryPause()

    F.SetLabels({
        ovMode = string.format("Chế độ: %s | Khu vực: %s | DPS: %s | Rương Boss: %s", gamemode, area, FormatNumber(liveDps), Session.bossChestCooldownText),
        ovCurrency = string.format("Gold: %s | Gems: %s | Vouchers: %s", FormatNumber(gold), FormatNumber(gems), FormatNumber(vouchers)),
        ovRerolls = string.format("Trait Token: %s | Stat Reroll: %s | Stat Lock: %s", FormatNumber(traitTokens), FormatNumber(statRerolls), FormatNumber(statLocks)),
        ovTokens = string.format("Raid Medal: %s | Defense Crystal: %s | Comet Shard: %s", FormatNumber(raidMedals), FormatNumber(defCrystals), FormatNumber(cometShards)),
        ovTeam = string.format("Đội hình: %d trang bị / %d kho | %s", #equipped, totalChamps, tostring(Session.unitHealthSummaryText)),
        ovAfk = F.AntiAfkStatusText(),
        combatPack = Session.isRecoveringUnits
            and tostring(Session.unitHealthSummaryText)
            or (Session.lastPackEntity
                and string.format("Mục tiêu: Pack #%s [%s] (%.0fs trước) | DPS: %s | %s",
                    tostring(Session.lastPackEntity), tostring(Session.lastPackName or "?"), os.clock() - Session.lastPackTime, FormatNumber(liveDps), tostring(Session.unitHealthSummaryText))
                or string.format("Mục tiêu: chưa điều quân | DPS: %s | Lọc %s: %d quái | %s",
                    FormatNumber(liveDps), tostring(Config.CombatWorld), selectedMobCount, tostring(Session.unitHealthSummaryText))),
        universalFarmStatus = Config.AutoUniversalModeFarm
            and ("Trạng thái: " .. tostring(Session.universalStatusText))
            or "Trạng thái: Đang TẮT Auto Farm Đa Chế Độ",
        partyStatus = F.GetPartyStatusSummaryText(),
        questLiveStatus = "Tiến độ Quest NPC: " .. tostring(Session.questStatusText),
        merchantLiveStatus = "Thương nhân: " .. tostring(Session.merchantStatusText),
        traitStatus = targetChamp
            and string.format("Tướng: %s | Trait[Slot %s]: %s (%s) | Stats: %s", tostring(targetChamp.id), slotKey, tostring(curTrait), tostring(curRarity), statSummary)
            or "Tướng đang chọn: chưa có chiến binh"
    })
end

-- ============================================================================
-- [13] GIAO DIỆN HELMHUB (ĐÓNG GÓI TRONG IIFE FUNCTION ĐỂ TÁCH STACK FRAME LOCAL CỦA LUAU)
-- ============================================================================
(function()
    EnsureHighIdentity()
    if not env.HelmGameName then env.HelmGameName = GAME_FOLDER_NAME end
    if not _G.HelmGameName then _G.HelmGameName = GAME_FOLDER_NAME end
    local Window = library:CreateWindow("HelmHUB | " .. GAME_FOLDER_NAME)

    local function AddToggle(sec, text, key, onChange)
        EnsureHighIdentity()
        return sec:AddToggle(text, Config[key], function(v)
            Config[key] = v
            if not uiFullyLoaded then
                EnsureHighIdentity()
                return
            end
            TriggerSave()
            if onChange then
                task.spawn(function()
                    SafeCallGame(onChange, v)
                end)
            end
            EnsureHighIdentity()
        end)
    end

    local function AddDropdown(sec, text, list, key, onChange)
        EnsureHighIdentity()
        return sec:AddDropdown(text, list, Config[key], false, function(val)
            Config[key] = val
            if not uiFullyLoaded then
                EnsureHighIdentity()
                return
            end
            TriggerSave()
            if onChange then
                SafeCallGame(onChange, val)
            end
            EnsureHighIdentity()
        end)
    end

    local function AddSlider(sec, text, min, max, decimals, key, transform)
        EnsureHighIdentity()
        return sec:AddSlider(text, min, Config[key], max, decimals, function(val)
            Config[key] = transform and transform(val) or val
            if not uiFullyLoaded then
                EnsureHighIdentity()
                return
            end
            TriggerSave()
            EnsureHighIdentity()
        end)
    end

    local function AddStatusLabels(sec, keys)
        for _, key in ipairs(keys) do
            Session.labels[key] = sec:AddLabel("Đang đọc...")
        end
    end

    local function BuildOverviewTab()
    local tab = Window:CreateTab("Tổng Quan")
    local secInfo = tab:CreateSector("Trạng Thái Tài Khoản (" .. accountName .. ")", "left")
    AddStatusLabels(secInfo, { "ovMode", "ovCurrency", "ovRerolls", "ovTokens", "ovTeam", "ovAfk" })
    secInfo:AddLabel("Phiên bản script: v" .. SCRIPT_VERSION)
    secInfo:AddLabel("Nguồn dữ liệu: " .. ConstSource)

    local secStarter = tab:CreateSector("Tài Khoản Mới, Hoàn Thành Tân Thủ & Sự Kiện", "left")
    AddToggle(secStarter, "Auto Hoàn Thành Toàn Bộ Tân Thủ (Rescue -> Summon -> Fight)", "AutoCompleteTutorial")
    AddToggle(secStarter, "Auto Nhận Quà Sự Kiện Countdown Pack", "AutoClaimCountdownPack")
    secStarter:AddButton("Nhận Quà Countdown Pack Ngay", function()
        FireRemote("CountdownPack_Claim")
        Notify("Countdown Pack", "Đã gửi lệnh nhận quà sự kiện Countdown!", 3)
    end)
    AddDropdown(secStarter, "Chọn Chiến Binh Khởi Đầu", C.Starters, "SelectedStarter")
    secStarter:AddButton("Chọn Starter Ngay (Tài Khoản Mới)", function()
        local pOk, ok, err = InvokeRemote("Starter_Pick", Config.SelectedStarter)
        Notify("Starter", pOk and ok and ("Đã nhận Starter: " .. Config.SelectedStarter) or ("Không nhận được: " .. tostring(err or ok)), 4)
    end)

    local secSys = tab:CreateSector("Hệ Thống, Tối Ưu FPS & Anti-AFK", "Right")
    AddToggle(secSys, "Chế Độ Giảm Lag / Tối Ưu FPS (Tắt Hiệu Ứng & Rung)", "LowLagMode", F.ApplyLowLagMode)
    AddToggle(secSys, "Auto Tắt Gợi Ý Tân Thủ & Chấm Đỏ Tướng Mới", "AutoClearTips")
    AddToggle(secSys, "Auto Cứu Nhân Vật Khi Rơi Khỏi Map (VoidFall)", "AutoVoidReturn")
    AddToggle(secSys, "Anti-AFK Chủ Động (chống kick 20 phút)", "AntiKick")
    AddToggle(secSys, "Nhường Chế Độ AFK Của Game (giữ thưởng AFK)", "AntiAfkYield")
    AddToggle(secSys, "Anti-AFK Có Bấm Phím Di Chuyển Nhẹ (W/S)", "AntiAfkMove")
    AddSlider(secSys, "Chu Kỳ Anti-AFK (giây)", 60, 900, 0, "AntiAfkInterval", math.floor)
    secSys:AddButton("Bấm Thử Anti-AFK Ngay", function()
        local ok, detail = F.RunAntiAfk(true)
        Notify("Anti-AFK", ok and ("Đã bấm giả: " .. detail) or ("Không cách nào chạy được: " .. tostring(detail)), 5)
    end)
    secSys:AddButton("Lưu Cấu Hình", function()
        SaveConfig()
        Notify("Cấu Hình", "Đã lưu cấu hình cho " .. accountName, 3)
    end)
    secSys:AddButton("Rejoin Server Hiện Tại", function()
        pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, game.JobId, LocalPlayer)
    end)
    secSys:AddButton("Đóng & Dọn Sạch Script (Unload)", function()
        if env.__HelmACXCleanup then
            env.__HelmACXCleanup()
        end
    end)
end

function F.BuildCombatTab()
    local tab = Window:CreateTab("Chiến Đấu & Farm")
    local secEngage = tab:CreateSector("Điều Quân & Chọn Multi Quái Theo Từng World", "left")
    AddStatusLabels(secEngage, { "combatPack" })
    AddToggle(secEngage, "Auto Điều Quân Đánh Quái (EngagePack)", "AutoEngage")

    local mobMultiDropdown = nil
    AddDropdown(secEngage, "1. Chọn World Để Lọc Quái", C.BossWorlds, "CombatWorld", function(newWorld)
        if mobMultiDropdown then
            local worldMobs = F.GetWorldEnemyList(newWorld)
            local savedKey = F.GetSelectedMobsKey(newWorld)
            mobMultiDropdown:Refresh(worldMobs)
            mobMultiDropdown:Set(Config[savedKey] or {})
        end
    end)

    local initialWorldMobs = F.GetWorldEnemyList(Config.CombatWorld)
    local initialMobKey = F.GetSelectedMobsKey(Config.CombatWorld)
    mobMultiDropdown = secEngage:AddDropdown(
        "2. Chọn Multi Quái Của World Đang Chọn",
        initialWorldMobs,
        Config[initialMobKey] or {},
        true,
        function(selectedList)
            local key = F.GetSelectedMobsKey(Config.CombatWorld)
            if type(selectedList) == "table" then
                local copy = {}
                for _, item in ipairs(selectedList) do
                    copy[#copy + 1] = tostring(item)
                end
                Config[key] = copy
            end
            TriggerSave()
        end
    )

    AddToggle(secEngage, "Chỉ Đánh Các Quái Đã Chọn Ở Trên (Lọc Multi Quái)", "FilterBySelectedMobs")
    AddToggle(secEngage, "Tự Dịch Chuyển Sang World Đã Chọn Khi Farm Quái", "AutoTravelToCombatWorld")
    AddToggle(secEngage, "Ưu Tiên Nhóm Quái Có Boss Trước", "PrioritizeBoss")
    AddToggle(secEngage, "Dịch Chuyển Tới Nhóm Quái Trước Khi Đánh", "TeleportToPack")
    AddSlider(secEngage, "Bán Kính Quét Nhóm Quái (studs)", 25, 500, 0, "EngageMaxDist", math.floor)
    AddToggle(secEngage, "Tạm Dừng Mọi Chiến Đấu & Quest Khi Unit Chết (Chờ Hồi 100% Máu)", "PauseOnUnitsDead")
    AddSlider(secEngage, "Số Unit Chết Để Dừng Chờ Hồi Sinh & Bơm 100% Máu", 1, 6, 0, "DeadUnitsPauseThreshold", math.floor)
    AddToggle(secEngage, "Tự Lùi Nhẹ Khỏi Bãi Quái Khi Đang Chờ Unit Hồi Sinh", "StepBackOnRecovery")
    secEngage:AddButton("Điều Quân Đánh Nhóm Gần Nhất Ngay", function()
        local _, msg = F.TryEngageNearestPack(false)
        Notify("Chiến Đấu", msg, 3)
    end)
    secEngage:AddButton("Rút Quân Về (RetreatUnits)", function()
        FireRemote("RetreatUnits")
        Notify("Chiến Đấu", "Đã gọi rút quân.", 2)
    end)

    local secSkills = tab:CreateSector("Kỹ Năng, Nhặt Đồ, Bỏ Qua Cảnh & Thuốc Buff", "Right")
    AddToggle(secSkills, "Auto Dùng Kỹ Năng Chiến Binh (UseChampionAbility)", "AutoAbilities")
    AddToggle(secSkills, "Chỉ Kích Hoạt Kỹ Năng Đã Hồi Xong (IsReady Check)", "OnlyCastReadyAbilities")
    AddSlider(secSkills, "Chu Kỳ Dùng Kỹ Năng (giây)", 0.3, 5.0, 1, "AbilityInterval")
    AddToggle(secSkills, "Auto Bật Auto-Attack & Auto-Ability Của Game", "AutoInGameAttack", function(on)
        if on then
            FireRemote("SetAutoAttack", true)
            FireRemote("ToggleAutoAbilities", true)
        end
    end)
    AddToggle(secSkills, "Auto Nhặt Vật Phẩm Rơi (Instant ClaimDrop)", "AutoCollectDrops")
    AddToggle(secSkills, "Auto Mở Rương Trên Bản Đồ (OpenChest)", "AutoOpenChests")
    AddToggle(secSkills, "Dịch Chuyển Tới Rương Trước Khi Mở", "TeleportToChestBeforeOpen")
    AddToggle(secSkills, "Auto Bỏ Qua Hội Thoại / Cắt Cảnh (StageScene & MissionTalk)", "AutoSkipDialogue")
    AddToggle(secSkills, "Auto Bỏ Qua Màn Chuyển Cảnh & Cutscene Vào Trận", "AutoSkipTransitions")
    AddToggle(secSkills, "Auto Đóng Hộp Thoại Nhận Thưởng (ResourcesGet)", "AutoDismissPopups")

    AddDropdown(secSkills, "Chọn Thuốc Buff Theo Thời Gian (Booster)", C.TimedBoostItems, "SelectedTimedBoost")
    AddToggle(secSkills, "Auto Dùng Thuốc Buff Khi Hết Hiệu Lực (UseBooster)", "AutoUseTimedBoost")
    secSkills:AddButton("Dùng Thuốc Buff Đã Chọn Ngay", function()
        local _, msg = F.TryUseTimedBooster(Config.SelectedTimedBoost)
        Notify("Booster", msg, 3)
    end)
end

function F.BuildGamemodeTab()
    local tab = Window:CreateTab("Boss, Raid & Chế Độ")

    local secUniversal = tab:CreateSector("Auto Farm Tổng Hợp Đa Chế Độ (Tự Biết Đường Farm)", "left")
    AddStatusLabels(secUniversal, { "universalFarmStatus" })
    AddToggle(secUniversal, "Auto Farm Boss / Raid / Chế Độ Thông Minh (Độc Lập)", "AutoUniversalModeFarm")
    AddDropdown(secUniversal, "Hành Động Khi Đang Ở Sảnh / Overworld", C.UniversalTargets, "UniversalOverworldTarget")
    secUniversal:AddLabel("Tự nhận diện Raid / Defense / Stage Boss / Overworld để đánh, chọn thẻ, qua đợt & vote kết quả.")

    local secBoss = tab:CreateSector("World Boss, Story Mission & Kết Quả Màn Chơi (Chỉnh Lẻ)", "left")
    AddDropdown(secBoss, "Chọn World Boss", C.BossWorlds, "SelectedBossWorld")
    AddToggle(secBoss, "Auto Khiêu Chiến World Boss (Nút Lẻ)", "AutoChallengeBoss")
    secBoss:AddButton("Khiêu Chiến World Boss Ngay", function()
        local _, msg = F.ChallengeSelectedBoss(Config.SelectedBossWorld)
        Notify("World Boss", msg, 3)
    end)

    AddToggle(secBoss, "Auto Đi Tới Nhiệm Vụ Đang Nhận (Auto QuestGo)", "AutoQuestGo")
    secBoss:AddButton("Đi Tới Mục Tiêu Nhiệm Vụ Đang Nhận Ngay (QuestGo)", function()
        local _, msg = F.RunActiveQuestGo()
        Notify("QuestGo", msg, 3)
    end)

    AddDropdown(secBoss, "Chọn Màn Cốt Truyện (Story Mission)", C.Missions, "SelectedMission")
    AddToggle(secBoss, "Auto Vào Màn Cốt Truyện Đã Chọn (Nút Lẻ)", "AutoPlayMission")
    secBoss:AddButton("Đặt Mission Vào Lobby & Sẵn Sàng Ngay", function()
        local _, msg = F.StartSelectedStoryMission(Config.SelectedMission)
        Notify("Mission", msg, 3)
    end)

    AddDropdown(secBoss, "Lựa Chọn Khi Kết Thúc Màn Chơi", C.MatchVoteOptions, "MatchVoteOption")
    AddToggle(secBoss, "Auto Vote Khi Kết Thúc Màn Chơi (Retry/Next/Lobby)", "AutoMatchVote")
    AddToggle(secBoss, "Chờ Mở Rương Chiến Thắng Xong Mới Vote Kết Quả", "WaitChestBeforeVote")
    AddToggle(secBoss, "Tự Đổi Next -> Retry/Lobby Khi Hết Màn & Bỏ Qua Hỏi Retry Raid", "SmartVoteFallback")
    secBoss:AddButton("Gửi Vote Kết Quả Ngay", function()
        F.VoteMatchResults(Config.MatchVoteOption, true)
        Notify("Match Results", "Đã chọn: " .. tostring(Config.MatchVoteOption), 2)
    end)
    secBoss:AddButton("Rời Trận Đang Đánh Về Sảnh Ngay (Forfeit / LeaveRun)", function()
        local _, msg = F.LeaveCurrentRun()
        Notify("Rời Trận", msg, 3)
    end)

    local secRaid = tab:CreateSector("Raid, Thẻ Buff Thông Minh, Defense & Lobby", "Right")
    AddDropdown(secRaid, "Ưu Tiên Thẻ Buff Giữa Màn Raid", C.RaidCards, "PreferredRaidCard")
    AddToggle(secRaid, "Auto Chọn Thẻ Buff Giữa Màn Raid (Raid_VoteCard)", "AutoRaidVoteCard")
    AddToggle(secRaid, "Auto Sẵn Sàng Qua Màn Raid Kế Tiếp", "AutoRaidReadyNext")
    AddToggle(secRaid, "Auto Qua Đợt Quái Tiếp Theo (Defense Mode)", "AutoDefenseNextWave")
    AddDropdown(secRaid, "Chọn Bản Đồ Raid (Lobby)", C.RaidBases, "SelectedRaidBase")
    AddSlider(secRaid, "Chọn Bậc Raid (Tier)", 1, 10, 0, "SelectedRaidTier", math.floor)
    secRaid:AddButton("Đặt Raid Đã Chọn Vào Lobby", function()
        FireRemote("Lobby_SetChosenChallenge", Config.SelectedRaidBase, Config.SelectedRaidTier)
        Notify("Lobby", string.format("Đã chọn Raid %s (Tier %d)", Config.SelectedRaidBase, Config.SelectedRaidTier), 3)
    end)
    AddToggle(secRaid, "Auto Bấm Sẵn Sàng Trong Lobby (Lobby_SetReady)", "AutoLobbyReady")

    local secParty = tab:CreateSector("Quản Lý Tổ Đội / Party Từ Xa (Invite / Kick / Promote)", "Right")
    AddStatusLabels(secParty, { "partyStatus" })
    AddDropdown(secParty, "Chế Độ Tự Tạo Phòng Khi Chưa Có Party", F.PartyCreateModes, "PartyCreateMode")

    local initialPlayers = F.GetServerOtherPlayerOptions()
    if not table.find(initialPlayers, Config.SelectedPartyPlayer) then
        Config.SelectedPartyPlayer = initialPlayers[1]
    end
    local partyPlayerDropdown = AddDropdown(secParty, "Chọn Người Chơi Trong Server", initialPlayers, "SelectedPartyPlayer")

    local function RefreshPartyPlayerDropdown()
        if not partyPlayerDropdown then return end
        EnsureHighIdentity()
        local list = F.GetServerOtherPlayerOptions()
        pcall(function()
            partyPlayerDropdown:Refresh(list)
            if not table.find(list, Config.SelectedPartyPlayer) then
                Config.SelectedPartyPlayer = list[1]
                partyPlayerDropdown:Set(list[1])
            end
        end)
    end

    TrackConnection(Players.PlayerAdded:Connect(function()
        task.delay(0.5, RefreshPartyPlayerDropdown)
    end))
    TrackConnection(Players.PlayerRemoving:Connect(function()
        task.delay(0.2, RefreshPartyPlayerDropdown)
    end))

    secParty:AddButton("Làm Mới Danh Sách Người Chơi Trong Server", function()
        RefreshPartyPlayerDropdown()
        Notify("Tổ Đội (Party)", "Đã cập nhật danh sách người chơi trong server.", 2)
    end)
    secParty:AddButton("Mời Người Chơi Đã Chọn Vào Tổ Đội (Lobby_InvitePlayer)", function()
        task.spawn(function()
            local _, msg = F.InviteUserToParty(Config.SelectedPartyPlayer)
            Notify("Tổ Đội (Party)", msg, 3)
        end)
    end)
    secParty:AddButton("Mời Toàn Bộ Bạn Bè Trong Server Vào Tổ Đội", function()
        task.spawn(function()
            local count = F.InviteMultiplePlayersToParty(true)
            Notify("Tổ Đội (Party)", string.format("Đã gửi lời mời tới %d bạn bè trong server.", count), 3)
        end)
    end)
    secParty:AddButton("Mời Toàn Bộ Người Chơi Trong Server Vào Tổ Đội", function()
        task.spawn(function()
            local count = F.InviteMultiplePlayersToParty(false)
            Notify("Tổ Đội (Party)", string.format("Đã gửi lời mời tới %d người chơi trong server.", count), 3)
        end)
    end)
    secParty:AddButton("Hủy Lời Mời Đã Gửi Tới Người Chơi Này (Lobby_CancelInvite)", function()
        local _, msg = F.CancelPartyInviteForUser(Config.SelectedPartyPlayer)
        Notify("Tổ Đội (Party)", msg, 3)
    end)
    secParty:AddButton("Nhường Chủ Phòng Cho Người Chơi Này (Lobby_Promote)", function()
        local _, msg = F.PromotePartyMember(Config.SelectedPartyPlayer)
        Notify("Tổ Đội (Party)", msg, 3)
    end)
    secParty:AddButton("Đuổi (Kick) Người Chơi Này Khỏi Tổ Đội (Lobby_Kick)", function()
        local _, msg = F.KickPartyMember(Config.SelectedPartyPlayer)
        Notify("Tổ Đội (Party)", msg, 3)
    end)
    AddToggle(secParty, "Auto Mời Bạn Bè Trong Server Vào Tổ Đội", "AutoInviteFriendsToParty")
    AddToggle(secParty, "Auto Đồng Ý Lời Mời Vào Tổ Đội (Lobby_RespondToInvite)", "AutoAcceptPartyInvites")
    AddToggle(secParty, "Chỉ Tự Đồng Ý Lời Mời Từ Bạn Bè (Friends Only)", "AcceptPartyFriendsOnly")
    secParty:AddButton("Rời Khỏi Phòng Chờ / Tổ Đội (Lobby_Leave)", function()
        local lobbySvc = GetGameModule("ClientLobbyService", { "Client", "services", "ClientLobbyService" })
        if type(lobbySvc) == "table" and typeof(lobbySvc.Leave) == "function" then
            SafeCallGame(lobbySvc.Leave)
        else
            FireRemote("Lobby_Leave")
        end
        Session.currentLobby = nil
        Notify("Tổ Đội (Party)", "Đã gửi lệnh rời tổ đội.", 2)
    end)
end

function F.BuildChampionTab()
    local tab = Window:CreateTab("Triệu Hồi & Chiến Binh")
    local secSummon = tab:CreateSector("Triệu Hồi Nhanh & Auto-Dismantle Server", "left")
    AddDropdown(secSummon, "Chọn Banner Triệu Hồi", C.Banners, "SelectedBanner")
    AddSlider(secSummon, "Số Lượng Mỗi Lần Triệu Hồi", 1, 10, 0, "PullCount", math.floor)
    AddDropdown(secSummon, "Dùng Thuốc Tăng May Mắn (Booster)", C.Boosters, "SelectedBooster")
    AddToggle(secSummon, "Auto Mở Khóa Banner Đang Chọn", "AutoUnlockBanner")
    AddToggle(secSummon, "Auto Triệu Hồi Liên Tục (PullFromBanner)", "AutoSummon")
    secSummon:AddButton("Triệu Hồi 1 Lượt Ngay", function()
        local ok, res = F.PullBannerOnce()
        Notify("Triệu Hồi", ok and string.format("Đã triệu hồi thành công (%d kết quả)!", #(res.results or res)) or ("Thất bại: " .. tostring(res)), 3)
    end)
    secSummon:AddButton("Mở Khóa Banner Đang Chọn Ngay", function()
        local pOk, ok, err = InvokeRemote("UnlockBanner", Config.SelectedBanner)
        Notify("Banner", pOk and ok and ("Đã mở khóa banner " .. Config.SelectedBanner) or ("Không mở được: " .. tostring(err or ok)), 3)
    end)

    AddDropdown(secSummon, "Server Giữ Lại Tướng Rare Khi Quay", C.ServerAutoDismantleModes, "ServerKeepRare")
    AddDropdown(secSummon, "Server Giữ Lại Tướng Epic Khi Quay", C.ServerAutoDismantleModes, "ServerKeepEpic")
    AddDropdown(secSummon, "Server Giữ Lại Tướng Legendary Khi Quay", C.ServerAutoDismantleModes, "ServerKeepLegendary")
    secSummon:AddButton("Áp Dụng Auto-Dismantle Khi Quay Lên Server", F.ApplyServerSummonAutoDismantle)

    local secTeam = tab:CreateSector("Đội Hình, Cho Ăn, Khóa, Phân Rã, Nâng Sao & Tiến Hóa", "left")
    AddToggle(secTeam, "Auto Trang Bị Đội Hình Mạnh Nhất (EquipBest)", "AutoEquipBest")
    secTeam:AddButton("Trang Bị Đội Hình Mạnh Nhất Ngay", function()
        local _, msg = F.EquipBestChampions(true)
        Notify("Đội Hình", msg, 3)
    end)
    AddToggle(secTeam, "Auto Cho Đội Hình Ăn Trái Cây Lên Cấp (FeedChampion)", "AutoFeedEquipped")
    secTeam:AddButton("Cho Đội Hình Ăn Trái Cây Ngay", function()
        local _, msg = F.AutoFeedEquippedChampions()
        Notify("Cho Ăn", msg, 3)
    end)
    AddToggle(secTeam, "Auto Khóa Chiến Binh Shiny / Mythic / Secret", "AutoLockRare")
    AddDropdown(secTeam, "Độ Hiếm Tối Đa Để Phân Rã Trong Kho", C.DismantleRarities, "DismantleMaxRarity")
    AddToggle(secTeam, "Giữ Lại Chiến Binh Shiny Khi Phân Rã", "DismantleKeepShiny")
    AddToggle(secTeam, "Giữ Lại Chiến Binh Đã Nâng Sao Khi Phân Rã", "DismantleKeepStarred")
    AddToggle(secTeam, "Auto Phân Rã Chiến Binh Rác Trong Kho", "AutoDismantle")
    secTeam:AddButton("Phân Rã Chiến Binh Rác Ngay", function()
        local _, msg = F.AutoDismantleLowRarityChampions()
        Notify("Phân Rã", msg, 3)
    end)
    AddToggle(secTeam, "Auto Ghép Bản Sao Nâng Sao (Auto Ascend)", "AutoAscend")
    AddToggle(secTeam, "Auto Tiến Hóa Chiến Binh Khi Đủ Nguyên Liệu (EvolveRules)", "AutoEvolve")
    AddToggle(secTeam, "Tiến Hóa Cả Chiến Binh Trong Kho (Không Chỉ Đội Hình)", "AutoEvolveAllInventory")
    secTeam:AddButton("Kiểm Tra & Tiến Hóa Chiến Binh Ngay", function()
        local _, msg = F.AutoEvolveEquipped()
        Notify("Tiến Hóa", msg, 3)
    end)

    local secTrait = tab:CreateSector("Quay Trait, Quay Chỉ Số (Stats) & Sửa Máy / Chế Tạo", "Right")
    AddStatusLabels(secTrait, { "traitStatus" })
    AddDropdown(secTrait, "Chọn Ô Trait (Slot 1 hoặc 2)", { "1", "2" }, "SelectedTraitSlot")
    AddDropdown(secTrait, "Dừng Khi Trúng Trait", C.Traits, "TargetTrait")
    AddDropdown(secTrait, "Hoặc Dừng Khi Đạt Độ Hiếm", C.TraitRarities, "TargetTraitRarity")
    AddToggle(secTrait, "Auto Reroll Trait (Dừng Khi Đạt Mục Tiêu)", "AutoTraitReroll")
    secTrait:AddButton("Quay Thử 1 Lần Trait Ngay", function()
        task.spawn(F.StepTraitReroll)
    end)

    AddDropdown(secTrait, "Bậc Chỉ Số Mục Tiêu (Strength / Spirit / Vitality)", C.StatGrades, "TargetStatGrade")
    AddToggle(secTrait, "Tự Khóa Dòng Đã Đạt Bậc Mục Tiêu (Dùng Stat Lock)", "AutoLockReachedStats")
    AddToggle(secTrait, "Auto Quay Chỉ Số Chiến Binh (RerollChampionStats)", "AutoStatReroll")
    secTrait:AddButton("Quay Thử 1 Lần Chỉ Số Ngay", function()
        task.spawn(F.StepStatReroll)
    end)

    AddDropdown(secTrait, "Chọn Máy / Cổng Boss / Nâng Cấp Để Sửa", C.Repairs, "SelectedRepair")
    secTrait:AddButton("Sửa / Mở Khóa Mục Đang Chọn Ngay", function()
        local ok, err = F.RepairSingle(Config.SelectedRepair)
        Notify("Sửa Chữa", ok and ("Đã mở khóa: " .. Config.SelectedRepair) or ("Không sửa được: " .. tostring(err)), 3)
    end)
    AddToggle(secTrait, "Auto Sửa & Mở Khóa Mọi Máy / Nâng Cấp Khi Đủ Tiền", "AutoRepairAll")

    AddDropdown(secTrait, "Chọn Vật Phẩm / Công Thức Chế Tạo (Craft)", C.CraftingItems, "SelectedCraftItem")
    AddSlider(secTrait, "Số Lượng Chế Tạo", 1, 20, 0, "CraftQuantity", math.floor)
    secTrait:AddButton("Chế Tạo Vật Phẩm Ngay", function()
        local recipeId = tonumber(Config.SelectedCraftItem) or 1
        local recipes = GetGameModule("CraftingRecipes", { "Config", "CraftingRecipes" })
        if type(recipes) == "table" then
            for idx, rec in pairs(recipes) do
                if type(rec) == "table" and (rec.Id == Config.SelectedCraftItem or (type(rec.Output) == "table" and rec.Output.Id == Config.SelectedCraftItem)) then
                    recipeId = rec.Id or idx
                    break
                end
            end
        end
        local pOk, ok, err = InvokeRemote("CraftRecipe", recipeId, Config.CraftQuantity)
        Notify("Chế Tạo", pOk and ok == true and string.format("Đã chế tạo %dx %s!", Config.CraftQuantity, tostring(Config.SelectedCraftItem)) or ("Thất bại: " .. tostring(err or ok)), 3)
    end)
end

function F.BuildQuestTab()
    local tab = Window:CreateTab("Nhiệm Vụ & Cửa Hàng")
    local secWorldQuest = tab:CreateSector("Auto Nhiệm Vụ NPC Theo Từng World", "left")
    AddStatusLabels(secWorldQuest, { "questLiveStatus" })

    local npcQuestDropdown = nil
    AddDropdown(secWorldQuest, "1. Chọn World Làm Nhiệm Vụ NPC", C.QuestWorlds, "QuestWorldFilter", function(newWorld)
        if npcQuestDropdown then
            local npcs = C.QuestNpcsByWorld[newWorld] or C.QuestNpcsByWorld["Tất cả World (Theo Tiến Độ)"]
            npcQuestDropdown:Refresh(npcs)
            npcQuestDropdown:Set("Tất cả NPC trong World")
        end
    end)

    local initialQuestNpcs = C.QuestNpcsByWorld[Config.QuestWorldFilter] or C.QuestNpcsByWorld["Tất cả World (Theo Tiến Độ)"]
    npcQuestDropdown = AddDropdown(secWorldQuest, "2. Chọn NPC Giao Nhiệm Vụ Trong World", initialQuestNpcs, "SelectedQuestNpc")

    AddToggle(secWorldQuest, "Auto Làm Chuỗi Nhiệm Vụ NPC Của World Đã Chọn", "AutoWorldNpcQuestLoop", function(on)
        if not on then
            Session.questOverrideMobIds = nil
            Session.questOverrideElement = nil
            Session.questCombatActive = false
            Session.activeQuestDoneInRun = false
        end
    end)
    AddToggle(secWorldQuest, "Bao Gồm Cả Nhiệm Vụ Hàng Ngày (Daily Quests)", "AutoDailyQuests")
    AddToggle(secWorldQuest, "Tự Ghim Nhiệm Vụ Đang Làm Lên Màn Hình (PinQuest)", "AutoPinActiveQuest")
    AddToggle(secWorldQuest, "Tự Dịch Chuyển Sang World Của Nhiệm Vụ NPC", "AutoTravelForNpcQuest")
    AddToggle(secWorldQuest, "Tự Vào Màn Mission / Boss Khi Nhiệm Vụ NPC Yêu Cầu", "AutoRunQuestMissionsAndBoss")
    secWorldQuest:AddButton("Chạy Bước Nhiệm Vụ NPC Ngay", function()
        task.spawn(function()
            F.StepWorldNpcQuestEngine(true)
            Notify("Nhiệm Vụ NPC", Session.questStatusText, 3)
        end)
    end)

    local secQuest = tab:CreateSector("Nhiệm Vụ Chung, Milestones & Season Pass", "left")
    AddToggle(secQuest, "Auto Nhận Nhiệm Vụ Từ Mọi NPC (AcceptNpcQuest)", "AutoAcceptQuests")
    AddToggle(secQuest, "Auto Thu Thập Vật Phẩm Nhiệm Vụ (FindQuestItem)", "AutoFindQuestItems")
    AddToggle(secQuest, "Auto Trả & Nhận Thưởng Nhiệm Vụ (ClaimQuest)", "AutoClaimQuests")
    AddToggle(secQuest, "Auto Nhận Thưởng Mọi Mốc Thành Tựu (Milestones)", "AutoClaimMilestones")
    AddToggle(secQuest, "Auto Nhận Thưởng Nhiệm Vụ Hàng Ngày (Daily Bonus)", "AutoClaimDaily")
    AddToggle(secQuest, "Auto Nhận Toàn Bộ Thưởng Season Pass", "AutoClaimSeasonPass")
    AddToggle(secQuest, "Auto Nhận Thưởng Lặp Lại Season Pass (Repeatables)", "AutoClaimSeasonRepeatables")
    secQuest:AddButton("Nhận Toàn Bộ Milestones + Daily + Season Pass Ngay", function()
        task.spawn(function()
            F.ClaimAllMilestonesSmart()
            F.ClaimDailyBonusSmart()
            F.ClaimSeasonPassSmart()
            F.ClaimAllSeasonRepeatables()
            Notify("Nhận Thưởng", "Đã kiểm tra & nhận Milestones, Daily Bonus & Season Pass!", 3)
        end)
    end)

    local secMerchant = tab:CreateSector("Thương Nhân Tự Động (Chọn Multi Món Đồ & Ô Đội Upgrades)", "Right")
    AddStatusLabels(secMerchant, { "merchantLiveStatus" })

    local merchantItemMultiDropdown = nil
    local function GetFormattedSavedMerchantSelection(merchantId)
        local savedKey = F.GetSelectedMerchantItemsKey(merchantId)
        local rawSaved = Config[savedKey]
        local validSet = {}
        for _, opt in ipairs(F.GetMerchantItemList(merchantId)) do
            validSet[F.ResolveMerchantItemId(opt)] = opt
        end
        local formatted = {}
        if type(rawSaved) == "table" then
            for _, item in ipairs(rawSaved) do
                local cleanId = F.ResolveMerchantItemId(item)
                if validSet[cleanId] then
                    formatted[#formatted + 1] = validSet[cleanId]
                end
            end
        end
        return formatted
    end

    AddDropdown(secMerchant, "1. Chọn Thương Nhân (Merchant)", C.Merchants, "SelectedMerchant", function(newMerchant)
        if merchantItemMultiDropdown then
            local mItems = F.GetMerchantItemList(newMerchant)
            merchantItemMultiDropdown:Refresh(mItems)
            merchantItemMultiDropdown:Set(GetFormattedSavedMerchantSelection(newMerchant))
        end
    end)

    local initialMerchantItems = F.GetMerchantItemList(Config.SelectedMerchant)
    local initialFormattedSelection = GetFormattedSavedMerchantSelection(Config.SelectedMerchant)
    if #initialFormattedSelection > 0 then
        Config.FilterMerchantBySelectedItems = true
    end
    merchantItemMultiDropdown = secMerchant:AddDropdown(
        "2. Chọn Multi Món Đồ Của Thương Nhân Đang Chọn",
        initialMerchantItems,
        initialFormattedSelection,
        true,
        function(selectedList)
            if not uiFullyLoaded then
                EnsureHighIdentity()
                return
            end
            local key = F.GetSelectedMerchantItemsKey(Config.SelectedMerchant)
            local copy = {}
            if type(selectedList) == "table" then
                for _, item in ipairs(selectedList) do
                    local cleanId = F.ResolveMerchantItemId(item)
                    if type(cleanId) == "string" and cleanId ~= "" then
                        copy[#copy + 1] = cleanId
                    end
                end
                Config[key] = copy
            end
            -- Tự động bật/tắt công tắc Lọc Multi khi người chơi tích chọn hoặc bấm Xóa trong hộp chọn Multi
            local shouldFilter = (#copy > 0)
            if Config.FilterMerchantBySelectedItems ~= shouldFilter then
                Config.FilterMerchantBySelectedItems = shouldFilter
                if Session.filterMerchantToggleUI and typeof(Session.filterMerchantToggleUI.Set) == "function" then
                    pcall(Session.filterMerchantToggleUI.Set, Session.filterMerchantToggleUI, shouldFilter)
                end
            end
            TriggerSave()
        end
    )
    Session.activeMerchantDropdown = merchantItemMultiDropdown

    Session.filterMerchantToggleUI = AddToggle(secMerchant, "Chỉ Mua Các Món Đồ Đã Chọn Ở Trên (Lọc Multi)", "FilterMerchantBySelectedItems")
    AddToggle(secMerchant, "Auto Mua Vật Phẩm & Upgrades Thương Nhân", "AutoBuyMerchant")
    AddToggle(secMerchant, "Mua Tối Đa Số Gói Đủ Tiền (Max Affordable Packs)", "MerchantBuyMaxPacks")
    secMerchant:AddButton("Mua Các Món Đã Chọn (Hoặc Toàn Bộ) Ngay", function()
        task.spawn(function()
            local _, detailMsg = F.BuyAllMerchantOffers(Config.SelectedMerchant, true)
            Notify("Thương Nhân", detailMsg, 4)
        end)
    end)
    secMerchant:AddButton("Mở Cửa Sổ Thương Nhân Đang Chọn Trên Màn Hình", function()
        task.spawn(function()
            F.OpenMerchantWindowOnScreen(Config.SelectedMerchant)
        end)
    end)

    local secShop = tab:CreateSector("Đổi Voucher Gamepass, Quà Store & Giftcode", "Right")
    AddToggle(secShop, "Auto Nhận Quà Miễn Phí Trong Store & Hòm Quà (Free/Gift)", "AutoClaimFreeStore")
    secShop:AddButton("Nhận Quà Miễn Phí & Hòm Quà Ngay", function()
        local count = F.ClaimFreeStoreAndGifts()
        Notify("Store & Gift", string.format("Đã nhận %d gói miễn phí / quà tặng.", count), 3)
    end)

    AddDropdown(secShop, "Chọn Gamepass Đổi Bằng Voucher", C.VoucherPasses, "SelectedVoucherPass")
    AddToggle(secShop, "Auto Đổi Gamepass Đã Chọn Khi Đủ Voucher", "AutoBuyVoucherPass")
    secShop:AddButton("Đổi Gamepass Đã Chọn Bằng Voucher Ngay", function()
        local _, msg = F.TryBuyPassWithVouchers(Config.SelectedVoucherPass)
        Notify("Voucher Gamepass", msg, 4)
    end)

    secShop:AddTextbox("Nhập Mã Giftcode (cách nhau dấu phẩy)", Config.CodeInputText, function(val)
        Config.CodeInputText = tostring(val or "")
        TriggerSave()
    end)
    secShop:AddButton("Nhập Giftcode Đã Điền", function()
        task.spawn(F.RedeemCodeString, Config.CodeInputText)
    end)
    secShop:AddButton("Quét & Nhập Toàn Bộ Code Từ Server (CodeListGet)", function()
        task.spawn(F.FetchAndRedeemServerCodes)
    end)
end

function F.BuildTeleportTab()
    local tab = Window:CreateTab("Dịch Chuyển & Cửa Sổ")
    local secTravel = tab:CreateSector("Dịch Chuyển Thế Giới & HubWarp", "left")
    AddDropdown(secTravel, "Chọn Thế Giới (Overworld Travel)", C.Worlds, "SelectedWorld")
    secTravel:AddButton("Dịch Chuyển Tới Thế Giới Đã Chọn", function()
        task.spawn(F.TravelToWorld, Config.SelectedWorld, false)
    end)
    AddDropdown(secTravel, "Chọn Điểm Warp Tại Champion City", C.CityWarps, "SelectedCityWarp")
    secTravel:AddButton("Warp Tới Điểm Trong Champion City", function()
        task.spawn(F.HubWarpTo, Config.SelectedCityWarp)
    end)
    AddDropdown(secTravel, "Chọn Điểm Warp Trong World Chiến Đấu", C.WorldWarps, "SelectedWorldWarp")
    secTravel:AddButton("Warp Tới Điểm Trong World Hiện Tại", function()
        task.spawn(F.HubWarpTo, Config.SelectedWorldWarp)
    end)

    local secUi = tab:CreateSector("Tốc Độ Chạy, Mở Cửa Sổ Từ Xa & ESP", "Right")
    AddToggle(secUi, "Luôn Chạy Nhanh Của Game (AutoSprint = 32)", "AutoSprint", F.ApplyAutoSprint)
    AddToggle(secUi, "Ghi Đè Tốc Độ Di Chuyển Tùy Chỉnh (WalkSpeed)", "EnableCustomWalkSpeed", function(on)
        if not on then
            local hum = GetHumanoid()
            if hum then
                hum.WalkSpeed = Config.AutoSprint and C.DefaultSprintSpeed or C.DefaultWalkSpeed
            end
        end
    end)
    AddSlider(secUi, "Tốc Độ Di Chuyển (WalkSpeed)", 16, 120, 0, "CustomWalkSpeed", math.floor)

    AddDropdown(secUi, "Chọn Cửa Sổ Tính Năng (Window)", C.Windows, "SelectedWindow")
    secUi:AddButton("Mở Cửa Sổ Đã Chọn Ngay", function()
        F.OpenGameWindow(Config.SelectedWindow)
    end)
    AddToggle(secUi, "ESP NPC (Màu Xanh Lam)", "ESPNpc")
    AddToggle(secUi, "ESP Rương / Chest (Màu Vàng)", "ESPChest")
    AddToggle(secUi, "ESP Quái / Đơn Vị (Màu Đỏ)", "ESPEnemy")
end

    BuildOverviewTab()
    F.BuildCombatTab()
    F.BuildGamemodeTab()
    F.BuildChampionTab()
    F.BuildQuestTab()
    F.BuildTeleportTab()
end)()
uiFullyLoaded = true
EnsureHighIdentity()
SaveConfig()
pcall(F.UpdateStatus)

task.spawn(function()
    pcall(EnrichConstantsFromRuntime)
end)

if Config.AutoSprint then
    task.spawn(function()
        SafeCallGame(F.ApplyAutoSprint, true)
    end)
end
if Config.LowLagMode then
    task.spawn(function()
        SafeCallGame(F.ApplyLowLagMode, true)
    end)
end

-- ============================================================================
-- [14] VÒNG LẶP NỀN
-- ============================================================================
F.ConnectNetworkEventListeners()

-- Vòng lặp điều quân, Auto Farm Đa Chế Độ, Auto Đánh & Tele Cho Nhiệm Vụ NPC, nhặt drop & giữ WalkSpeed tùy chỉnh
StartLoop(0.35, function()
    if Config.AutoUniversalModeFarm then
        F.StepUniversalModeFarm()
    elseif Config.AutoWorldNpcQuestLoop then
        local gamemode = tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld")
        if gamemode ~= "overworld" then
            F.StepQuestActiveRunCombat(gamemode, Session.activeQuestDoneInRun)
        else
            if Session.questCombatActive or Config.AutoEngage then
                local engaged = F.TryEngageNearestPack(true)
                if engaged then
                    F.FireAllEquippedAbilities()
                end
            end
            F.ScanAndClaimEcsDrops()
        end
    else
        if Config.AutoEngage then
            local inRun = tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld") ~= "overworld"
            F.TryEngageNearestPack(inRun)
        end
        if Config.AutoCollectDrops then
            F.ScanAndClaimEcsDrops()
        end
    end
    if Config.EnableCustomWalkSpeed then
        local hum = GetHumanoid()
        if hum and hum.Health > 0 then
            hum.WalkSpeed = tonumber(Config.CustomWalkSpeed) or 45
        end
    end
end)

-- Vòng lặp dùng kỹ năng chiến binh
StartLoop(0.25, function()
    if Config.AutoAbilities and not Config.AutoUniversalModeFarm and os.clock() - Session.lastAbilityAt >= (tonumber(Config.AbilityInterval) or 1.0) then
        Session.lastAbilityAt = os.clock()
        F.FireAllEquippedAbilities()
    end
end)

-- Dọn dẹp định kỳ bảng cache drop & chest đã nhặt để tránh phình bộ nhớ khi treo máy nhiều giờ
function F.PruneSessionCaches()
    local now = os.clock()
    if now - Session.lastSessionCachePruneAt < 60 then return end
    Session.lastSessionCachePruneAt = now
    for id, ts in pairs(Session.claimedDrops) do
        if type(ts) == "number" and (now - ts) > 120 then
            Session.claimedDrops[id] = nil
        end
    end
    for id, ts in pairs(Session.openedChests) do
        if type(ts) == "number" and (now - ts) > 300 then
            Session.openedChests[id] = nil
        end
    end
end

-- Vòng lặp mở chest, bỏ qua hội thoại, chuyển cảnh, VoidFall, Raid/Defense/MatchResults
StartLoop(1.0, function()
    F.PruneSessionCaches()
    local gamemode = tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld")
    if Config.AutoOpenChests and not Config.AutoUniversalModeFarm then
        F.ScanAndOpenChests()
    end
    if Config.AutoSkipDialogue then
        if gamemode ~= "overworld" then
            FireRemote("StageScene_Continue")
        end
        if Session.lastMissionTalkRunId then
            FireRemote("MissionTalk_Ended", Session.lastMissionTalkRunId)
            Session.lastMissionTalkRunId = nil
        end
    end
    if Config.AutoSkipTransitions and gamemode ~= "overworld" then
        FireRemote("PlayerArrival_Presented")
    end
    if Config.AutoClearTips then
        F.ClearTutorialTipsAndUnseen()
    end
    if Config.AutoVoidReturn then
        local hrp = GetRootPart()
        if hrp and hrp.Position.Y < -150 then
            InvokeRemote("VoidFall_Return")
        end
    end
    if Config.AutoInGameAttack and not Session.isRecoveringUnits and (os.clock() - Session.lastAutoAttackSyncAt >= 5.0) then
        Session.lastAutoAttackSyncAt = os.clock()
        if LocalPlayer:GetAttribute("AutoAttack") ~= true then
            FireRemote("SetAutoAttack", true)
        end
        if LocalPlayer:GetAttribute("AutoAbilities") ~= true then
            FireRemote("ToggleAutoAbilities", true)
        end
    end
    if not Config.AutoUniversalModeFarm then
        if (Config.AutoRaidVoteCard or Config.AutoRaidReadyNext) and gamemode == "raid" then
            F.HandleRaidIntermission(false)
        end
        if Config.AutoDefenseNextWave and gamemode == "defense" then
            FireRemote("Defense_RequestNextWave")
        end
        if Config.AutoMatchVote and gamemode ~= "overworld" then
            F.VoteMatchResults(Config.MatchVoteOption)
        end
        if Config.AutoLobbyReady and gamemode == "overworld" then
            local lobby = F.GetCurrentLobbyState()
            if type(lobby) == "table" then
                local alreadyReady = false
                if type(lobby.readyUserIds) == "table" then
                    for _, rUid in ipairs(lobby.readyUserIds) do
                        if rUid == LocalPlayer.UserId then
                            alreadyReady = true
                            break
                        end
                    end
                end
                if not alreadyReady then
                    FireRemote("Lobby_SetReady", true)
                end
            end
        end
    end
end)

-- Vòng lặp triệu hồi, Trait Reroll & Stat Reroll
StartLoop(0.4, function()
    if Config.AutoUnlockBanner then
        local unlocked = ReadStore("UnlockedBanners", "table", true)
        if not (type(unlocked) == "table" and unlocked[Config.SelectedBanner] == true) then
            InvokeRemote("UnlockBanner", Config.SelectedBanner)
        end
    end
    if Config.AutoSummon then
        F.PullBannerOnce()
    end
    if Config.AutoTraitReroll then
        F.StepTraitReroll()
    end
    if Config.AutoStatReroll then
        F.StepStatReroll()
    end
end)

-- Vòng lặp đội hình, cho ăn, khóa, phân rã, nâng sao, tiến hóa, sửa máy, nhiệm vụ NPC theo World, booster & cửa hàng
StartLoop(2.5, function()
    local isOverworld = tostring(Workspace:GetAttribute(C.GamemodeAttribute) or "overworld") == "overworld"
    local pausedForHeal = F.CheckTeamRecoveryPause()
    if not Config.AutoUniversalModeFarm and not pausedForHeal then
        if Config.AutoChallengeBoss and isOverworld then
            F.ChallengeSelectedBoss(Config.SelectedBossWorld)
        end
        if Config.AutoPlayMission and isOverworld then
            F.StartSelectedStoryMission(Config.SelectedMission)
        end
        if Config.AutoQuestGo and isOverworld then
            F.RunActiveQuestGo()
        end
    end
    if Config.AutoUseTimedBoost then
        F.TryUseTimedBooster(Config.SelectedTimedBoost)
    end
    if Config.AutoLockRare then
        F.AutoLockRareChampions()
    end
    if Config.AutoEquipBest then
        F.EquipBestChampions()
    end
    if Config.AutoFeedEquipped then
        F.AutoFeedEquippedChampions()
    end
    if Config.AutoAscend then
        F.AutoAscendAllPossible()
    end
    if Config.AutoEvolve then
        F.AutoEvolveEquipped()
    end
    if Config.AutoDismantle then
        F.AutoDismantleLowRarityChampions()
    end
    if Config.AutoRepairAll then
        F.AutoRepairAllUnrepaired()
    end
    if Config.AutoCompleteTutorial and not pausedForHeal then
        F.StepAutoTutorial()
    end
    if Config.AutoInviteFriendsToParty and isOverworld then
        F.InviteMultiplePlayersToParty(true)
    end
    if Config.AutoWorldNpcQuestLoop or Config.AutoAcceptQuests or Config.AutoClaimQuests or Config.AutoFindQuestItems then
        F.ScanAndHandleQuests()
    end
    if Config.AutoClaimMilestones then
        F.ClaimAllMilestonesSmart()
    end
    if Config.AutoClaimDaily then
        F.ClaimDailyBonusSmart()
    end
    if Config.AutoClaimSeasonPass then
        F.ClaimSeasonPassSmart()
    end
    if Config.AutoClaimSeasonRepeatables then
        F.ClaimAllSeasonRepeatables()
    end
    if Config.AutoClaimCountdownPack then
        if ReadStore("CountdownPackClaimed", "boolean", true) ~= true then
            FireRemote("CountdownPack_Claim")
        end
    end
    if Config.AutoClaimFreeStore then
        F.ClaimFreeStoreAndGifts()
    end
    if Config.AutoBuyVoucherPass then
        F.TryBuyPassWithVouchers(Config.SelectedVoucherPass)
    end
    if Config.AutoBuyMerchant then
        F.BuyAllMerchantOffers(Config.SelectedMerchant)
    end
end)

-- Vòng lặp ESP & cập nhật trạng thái UI
StartLoop(1.0, function()
    for _, esp in ipairs(F.EspKinds) do
        pcall(F.SyncEsp, esp.kind, Config[esp.cfg], esp.targets, esp.color)
    end
    F.UpdateStatus()
end)

TrackConnection(UserInputService.InputBegan:Connect(function()
    F.AntiAfk.lastInput = Workspace:GetServerTimeNow()
end))
StartLoop(5.0, F.RunAntiAfk)

-- ============================================================================
-- [15] DỌN DẸP AN TOÀN (REVERSE PATH)
-- ============================================================================
env.__HelmACXCleanup = function()
    EnsureHighIdentity()
    Running = false
    local wasLowLag = Config.LowLagMode
    local wasCustomSpeed = Config.EnableCustomWalkSpeed
    for key, value in pairs(Config) do
        if type(value) == "boolean" then
            Config[key] = false
        end
    end
    Session.questOverrideMobIds = nil
    Session.questOverrideElement = nil
    if wasLowLag then
        SafeCallGame(F.ApplyLowLagMode, false)
    end
    if wasCustomSpeed then
        local hum = GetHumanoid()
        if hum then
            pcall(function() hum.WalkSpeed = C.DefaultSprintSpeed end)
        end
    end
    for _, conn in ipairs(Connections) do
        pcall(function()
            if typeof(conn) == "RBXScriptConnection" and conn.Connected then
                conn:Disconnect()
            end
        end)
    end
    table.clear(Connections)
    for _, registry in pairs(Session.esp) do
        for model, hl in pairs(registry) do
            pcall(hl.Destroy, hl)
            registry[model] = nil
        end
    end
    if Session.espFolder then
        pcall(Session.espFolder.Destroy, Session.espFolder)
        Session.espFolder = nil
    end
    if env.HelmLibrary and typeof(env.HelmLibrary.Destroy) == "function" then
        pcall(env.HelmLibrary.Destroy, env.HelmLibrary)
    end
    env.__HelmACXCleanup = nil
end

Notify("Anime Champions X", "Đã nạp v" .. SCRIPT_VERSION .. " (" .. ConstSource .. ")", 4)
