--[[
    ========================================================================
    HelmHub | Anime Eyes Master
    PlaceId: 97617452700163
    Tác giả: dj & VANTA
    Phiên bản: 19.3 (Anti-Void Fall & Safe Streaming World Engine)
    ========================================================================
    Quy chuẩn vận hành theo yêu cầu của dj:
      1. Chỉ nhận Cúp tại đúng Stage đích đã chọn (Target Stage):
         - Ở các Stage trước đích (Stage 1, 2... < Target): Diệt sạch quái và tiến thẳng qua Cổng sang ải tiếp theo, TUYỆT ĐỐI KHÔNG chạm vào bất kỳ bệ cúp nào.
         - Khi đạt đúng Stage đích (hoặc vượt qua): Diệt sạch quái, tiến lên BỆ VÀNG duy nhất (Cúp thường Free, KHÔNG chạm vào Bệ Tím x3 nạp tiền).
      2. Nhận cúp xong tự động Reset ván đấu về Stage 1:
         - Khi nhận cúp tại Stage đích, ván đấu kết thúc và nhân vật tự động quay về Stage 1 để lặp lại chu trình farm cúp mới.
      3. Đứng giữa Stage bao quát quái & boss:
         - Tự động định vị trọng tâm đàn quái và tâm sàn đấu, xả đòn M1 + chiêu E (Shinra Tensei) & R (Chibaku Tensei) với tốc độ CPS cao (25-30 hit/s).
    ========================================================================
]]

if not game:IsLoaded() then
    pcall(function() game.Loaded:Wait() end)
end

print("[HelmHub] ◈ Khởi chạy Anime Eyes Master (v19.3)...")

_G.HelmGameName = "Anime Eyes"
local currentSessionId = os.clock() + math.random()
_G.AnimeEyes_SessionId = currentSessionId
local function isSessionActive()
    return _G.AnimeEyes_SessionId == currentSessionId
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local StatsService = game:GetService("Stats")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
if not localPlayer then
    pcall(function()
        localPlayer = Players.PlayerAdded:Wait()
    end)
end

-- ========================================================================
-- 1. DỌN DẸP GIAO DIỆN CŨ (PREVENT DUPLICATE / GHOST WINDOWS)
-- ========================================================================
pcall(function()
    local env = (typeof(getgenv) == "function" and getgenv()) or _G
    if env.watermark then
        pcall(function() env.watermark:Destroy() end)
        env.watermark = nil
    end
    if env.uilib then
        pcall(function() env.uilib:Destroy() end)
        env.uilib = nil
    end
    local containers = {}
    if gethui then pcall(function() table.insert(containers, gethui()) end) end
    pcall(function() table.insert(containers, game:GetService("CoreGui")) end)
    if localPlayer then
        local pg = localPlayer:FindFirstChild("PlayerGui")
        if pg then table.insert(containers, pg) end
    end

    for _, c in ipairs(containers) do
        local ok, children = pcall(function() return c:GetChildren() end)
        if ok and children then
            for _, gui in ipairs(children) do
                if gui.Name:find("Anime Eyes") or gui.Name:find("HelmHub") or gui.Name:find("Watermark") or gui.Name:find("HelmMasterUI") then
                    pcall(function() gui:Destroy() end)
                end
            end
        end
    end
end)

-- ========================================================================
-- 2. HỆ THỐNG LOG & THÔNG BÁO
-- ========================================================================
local function safeLog(...)
    if _G.DisableConsoleLogs then return end
    pcall(function(...) print(...) end, ...)
end

local _lastNotificationTimes = {}
local function Notification(title, text, duration)
    if _G.AnimeEyes_MuteToasts then return end
    local key = tostring(title or "") .. ":" .. tostring(text or "")
    local now = tick()
    -- Chống spam lặp thông báo nếu cùng nội dung xuất hiện trong vòng 6 giây
    if _lastNotificationTimes[key] and (now - _lastNotificationTimes[key]) < 6 then
        return
    end
    _lastNotificationTimes[key] = now

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "HelmHub"),
            Text = tostring(text or ""),
            Duration = tonumber(duration) or 2
        })
    end)
    safeLog(string.format("[HelmHub] %s: %s", tostring(title or ""), tostring(text or "")))
end

-- Helper cập nhật Text cho nhãn UI (Hỗ trợ cả label:Set và label.Main.Text)
local function updateLabel(labelObj, text)
    if not labelObj then return end
    pcall(function()
        if labelObj.Set then
            labelObj:Set(text)
        end
        if labelObj.Main and labelObj.Main:IsA("TextLabel") then
            labelObj.Main.Text = text
        end
    end)
end

-- ========================================================================
-- 3. TẢI THƯ VIỆN GIAO DIỆN THẾ HỆ MỚI (inventory.lua - HelmXGenimi Theme)
-- ========================================================================
local library = nil
local function loadLibrary()
    safeLog("[HelmHub] ◈ Bắt đầu nạp Library/inventory.lua...")
    local localHosts = {}
    if _G.LocalHost then table.insert(localHosts, _G.LocalHost) end
    table.insert(localHosts, "127.0.0.1:8000")
    table.insert(localHosts, "localhost:8000")
    table.insert(localHosts, "192.168.2.203:8000")
    table.insert(localHosts, "10.0.2.2:8000")

    local function isValidLua(content)
        if not content or typeof(content) ~= "string" or #content < 1000 then return false end
        if content:find("404: Not Found") or content:find("403: Forbidden") or content:find("<!DOCTYPE") or content:find("<html") or content:find("Error response") then
            return false
        end
        return true
    end

    -- 1. Ưu tiên nạp từ Local Test Server (127.0.0.1:8000 / localhost / LAN IP)
    local libEndpoints = { "Library/inventory.lua" }
    for _, host in ipairs(localHosts) do
        if host and not library then
            for _, ep in ipairs(libEndpoints) do
                local url = string.format("http://%s/%s?t=%s", host, ep, tostring(tick()))
                local getOk, raw = pcall(function() return game:HttpGet(url) end)
                if getOk and isValidLua(raw) then
                    local fn, compileErr = loadstring(raw)
                    if fn then
                        local callOk, result = pcall(fn)
                        if callOk and result then
                            library = result
                            safeLog(string.format("[HelmHub] ✅ Nạp thành công UI Master từ %s (%s)", host, ep))
                            break
                        else
                            warn(string.format("[HelmHub] ❌ Lỗi runtime khi chạy %s: %s", ep, tostring(result)))
                        end
                    else
                        warn(string.format("[HelmHub] ❌ Lỗi biên dịch %s từ %s: %s", ep, host, tostring(compileErr)))
                    end
                end
            end
        end
    end

    -- 2. Đọc file local nếu executor có sẵn file Library/inventory.lua trong thư mục executor
    if not library and isfile and readfile then
        local localPaths = { "Library/inventory.lua", "!HelmHub/Library/inventory.lua" }
        for _, p in ipairs(localPaths) do
            local hasFile = false
            pcall(function() hasFile = isfile(p) end)
            if hasFile then
                local readOk, raw = pcall(readfile, p)
                if readOk and isValidLua(raw) then
                    local fn, compileErr = loadstring(raw)
                    if fn then
                        local callOk, result = pcall(fn)
                        if callOk and result then
                            library = result
                            safeLog(string.format("[HelmHub] ✅ Nạp thành công UI Master từ file local %s", p))
                            break
                        else
                            warn(string.format("[HelmHub] ❌ Lỗi runtime file local %s: %s", p, tostring(result)))
                        end
                    end
                end
            end
        end
    end

    return library
end

library = loadLibrary()
if not library then
    Notification("Lỗi Thư Viện", "Không thể nạp UI inventory.lua! Vui lòng kiểm tra kết nối mạng hoặc server local.", 5)
    safeLog("[HelmHub] Không thể nạp inventory.lua!")
    return
end

-- ========================================================================
-- 4. TRẠNG THÁI TOÀN CỤC (GLOBAL STATE)
-- ========================================================================
-- Tab 1: Chiến Đấu (Stage, World & Timeout Engine)
-- Ngắt triệt để mọi vòng lặp ngầm (ghost loops) từ phiên chạy cũ trong bộ nhớ
_G.AnimeEyes_AutoStage = false
_G.AnimeEyes_AutoBoss = false
_G.Helm_AutoStage = (_G.Helm_AutoStage ~= nil) and _G.Helm_AutoStage or false
_G.Helm_AutoBoss = (_G.Helm_AutoBoss ~= nil) and _G.Helm_AutoBoss or false
_G.AnimeEyes_CenterStage = _G.AnimeEyes_CenterStage ~= nil and _G.AnimeEyes_CenterStage or true
_G.AnimeEyes_TargetStage = math.clamp(tonumber(_G.AnimeEyes_TargetStage) or 5, 1, 15)
_G.AnimeEyes_SelectedWorld = tonumber(_G.AnimeEyes_SelectedWorld) or 1
_G.AnimeEyes_StageTimeout = tonumber(_G.AnimeEyes_StageTimeout) or 20
_G.AnimeEyes_BossFightDuration = tonumber(_G.AnimeEyes_BossFightDuration) or 10
_G.AnimeEyes_StageCPS = _G.AnimeEyes_StageCPS or 25
_G.AnimeEyes_StageDelay = _G.AnimeEyes_StageDelay or 1.0
_G.AnimeEyes_InBossFight = false
_G.AnimeEyes_BossHoverHeight = _G.AnimeEyes_BossHoverHeight or 26

-- Tab 2: Tự Động Farm & Trùng Sinh
_G.AnimeEyes_AutoClick = _G.AnimeEyes_AutoClick or false
_G.AnimeEyes_TargetCPS = _G.AnimeEyes_TargetCPS or 25
_G.AnimeEyes_BypassCooldown = _G.AnimeEyes_BypassCooldown ~= nil and _G.AnimeEyes_BypassCooldown or true
_G.AnimeEyes_AutoSkills = _G.AnimeEyes_AutoSkills or false
_G.AnimeEyes_KeepFreeOn = _G.AnimeEyes_KeepFreeOn ~= nil and _G.AnimeEyes_KeepFreeOn or true
_G.AnimeEyes_AutoClaims = _G.AnimeEyes_AutoClaims or false
_G.AnimeEyes_MuteToasts = _G.AnimeEyes_MuteToasts ~= nil and _G.AnimeEyes_MuteToasts or false
_G.AnimeEyes_AutoRebirth = _G.AnimeEyes_AutoRebirth or false
_G.AnimeEyes_AutoTrainPad = (_G.AnimeEyes_AutoTrainPad ~= nil) and _G.AnimeEyes_AutoTrainPad or true
_G.AnimeEyes_RebirthDelay = _G.AnimeEyes_RebirthDelay or 1.5

-- Tab 3: Mở Trứng
_G.AnimeEyes_AutoHatch = _G.AnimeEyes_AutoHatch or false
_G.AnimeEyes_SelectedEgg = _G.AnimeEyes_SelectedEgg or "Starter Egg"
_G.Helm_HatchAmount = tonumber(_G.Helm_HatchAmount) or 3
_G.AnimeEyes_HatchAmount = _G.Helm_HatchAmount
_G.AnimeEyes_AutoEquipBestPet = _G.AnimeEyes_AutoEquipBestPet or false

-- Tab 4: Cửa Hàng
_G.AnimeEyes_AutoUnlockEyes = _G.AnimeEyes_AutoUnlockEyes or false
_G.AnimeEyes_AutoEquipBestEye = _G.AnimeEyes_AutoEquipBestEye or false
_G.AnimeEyes_AutoRollAuras = _G.AnimeEyes_AutoRollAuras or false
_G.AnimeEyes_AutoEquipBestAura = _G.AnimeEyes_AutoEquipBestAura or false
_G.AnimeEyes_AutoBossShop = _G.AnimeEyes_AutoBossShop or false
_G.AnimeEyes_AutoClaims = _G.AnimeEyes_AutoClaims or false

-- Tab 5: Cài Đặt
_G.AntiAFK = _G.AntiAFK ~= nil and _G.AntiAFK or true
_G.WhiteScreen = _G.WhiteScreen or false
_G.FPSBoost = _G.FPSBoost or false
_G.WalkSpeedEnabled = _G.WalkSpeedEnabled ~= nil and _G.WalkSpeedEnabled or true
_G.WalkSpeedValue = _G.WalkSpeedValue or 70
_G.DisableConsoleLogs = _G.DisableConsoleLogs or false
_G.AnimeEyes_AutoSaveConfig = _G.AnimeEyes_AutoSaveConfig or false

-- Tab 6: Discord Webhook & Báo Cáo Tự Động
_G.AnimeEyes_WebhookURL = _G.AnimeEyes_WebhookURL or ""
_G.AnimeEyes_WebhookEnabled = (_G.AnimeEyes_WebhookEnabled ~= nil) and _G.AnimeEyes_WebhookEnabled or false
_G.AnimeEyes_WebhookHatch = (_G.AnimeEyes_WebhookHatch ~= nil) and _G.AnimeEyes_WebhookHatch or true
_G.AnimeEyes_WebhookBoss = (_G.AnimeEyes_WebhookBoss ~= nil) and _G.AnimeEyes_WebhookBoss or true
_G.AnimeEyes_WebhookEye = (_G.AnimeEyes_WebhookEye ~= nil) and _G.AnimeEyes_WebhookEye or true
_G.AnimeEyes_WebhookPeriodic = (_G.AnimeEyes_WebhookPeriodic ~= nil) and _G.AnimeEyes_WebhookPeriodic or true
_G.AnimeEyes_WebhookInterval = math.clamp(tonumber(_G.AnimeEyes_WebhookInterval) or 30, 5, 120)

-- ========================================================================
-- 4.5. NẠP NGAY LẬP TỨC CẤU HÌNH TỪ DISK TRƯỚC KHI KHỞI TẠO GIAO DIỆN (PRE-UI LOAD)
-- ========================================================================
local function loadSettingsFromDisk()
    local paths = { "!HelmHub/Anime Eyes/settings.json", "AnimeEyes_settings.json" }
    for _, p in ipairs(paths) do
        local ok, raw = pcall(function()
            if readfile then return readfile(p) end
            return nil
        end)
        if ok and raw and #raw > 2 then
            local decOk, data = pcall(function()
                return HttpService:JSONDecode(raw)
            end)
            if decOk and typeof(data) == "table" then
                for k, v in pairs(data) do
                    if k == "AnimeEyes_AutoStage" then
                        _G.Helm_AutoStage = (v == true)
                        _G.AnimeEyes_AutoStage = false
                    elseif k == "AnimeEyes_AutoBoss" then
                        _G.Helm_AutoBoss = (v == true)
                        _G.AnimeEyes_AutoBoss = false
                    elseif k == "AnimeEyes_HatchAmount" then
                        -- Bỏ qua key cũ mặc định 1 trứng; dùng Helm_HatchAmount (mặc định 3 - HATCH x3)
                    elseif k == "Helm_HatchAmount" then
                        _G.Helm_HatchAmount = (tonumber(v) == 1) and 1 or 3
                        _G.AnimeEyes_HatchAmount = _G.Helm_HatchAmount
                    else
                        _G[k] = v
                    end
                end
                if safeLog then
                    safeLog(string.format("[HelmHub] Đã nạp thành công cấu hình đã lưu từ %s!", p))
                end
                return true
            end
        end
    end
    return false
end
pcall(loadSettingsFromDisk)

local queueAutoSave
do
    local saveDebounce = nil
    queueAutoSave = function()
        if saveDebounce then return end
        saveDebounce = task.delay(0.3, function()
            saveDebounce = nil
            if autoSaveSettings then
                autoSaveSettings(false)
            end
        end)
    end
end

-- ========================================================================
-- 4.8. BỘ ĐỊNH DẠNG SỐ HỌC VÀ CHUỖI VIẾT TẮT CHUẨN 47 BẬC CỦA ANIME EYES
-- ========================================================================
local FORMAT_SUFFIXES = {
    "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
    "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod",
    "Vg", "Uvg", "Dvg", "Tvg", "Qavg", "Qivg", "Sxvg", "Spvg", "Ocvg", "Novg",
    "Tg", "Utg", "Dtg", "Ttg", "Qatg", "Qitg", "Sxtg", "Sptg", "Octg", "Notg",
    "Qag", "Uqag", "Dqag", "Tqag", "Qaqag", "Qiqag", "Sxqag"
}

local FORMAT_SUFFIX_MAP = {}
for i, v in ipairs(FORMAT_SUFFIXES) do
    FORMAT_SUFFIX_MAP[v:lower()] = i
end

local function formatNumber(n)
    if not n or n ~= n then return "0" end
    n = tonumber(n) or 0
    local absN = math.abs(n)
    local sign = n < 0 and "-" or ""
    if absN < 1000 then
        return sign .. tostring(math.floor(absN))
    end

    local exp = math.log10(absN) / 3
    local idx = math.floor(exp)
    local maxIdx = #FORMAT_SUFFIXES
    local sIdx = math.min(idx, maxIdx)
    local val = absN / (10 ^ (sIdx * 3))

    if val >= 999.95 and sIdx < maxIdx then
        sIdx = sIdx + 1
        val = absN / (10 ^ (sIdx * 3))
    end

    local str
    if val < 100 then
        str = string.format("%.2f", val)
    else
        str = string.format("%.1f", val)
    end
    if str:find("%.") then
        str = str:gsub("0+$", ""):gsub("%.$", "")
    end
    return sign .. str .. FORMAT_SUFFIXES[sIdx]
end

local function formatMultiplier(n)
    if not n or n ~= n then return "x1" end
    n = tonumber(n) or 1
    if n >= 1000 then
        return "x" .. formatNumber(n)
    end
    local s = string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
    return "x" .. s
end

local function parseShortNumber(str)
    if not str then return 0 end
    if typeof(str) == "number" then return str end
    local s = tostring(str):gsub(",", ""):gsub("%s+", ""):lower()
    local numPart, suffPart = s:match("^([%d%.]+)(.*)$")
    if not numPart then return 0 end
    local val = tonumber(numPart) or 0
    if not suffPart or suffPart == "" then return val end

    local ePow = suffPart:match("^e([%+%-]?%d+)$")
    if ePow then
        return val * (10 ^ (tonumber(ePow) or 0))
    end

    local sIdx = FORMAT_SUFFIX_MAP[suffPart]
    if sIdx then
        return val * (10 ^ (sIdx * 3))
    end
    return val
end

-- Bảng đăng ký lưu trữ đối tượng UI để đồng bộ 100% hai chiều
local uiRegistry = {
    toggles = {},
    sliders = {},
    dropdowns = {}
}

-- Dữ liệu hiển thị trực tiếp Stage & Cúp
local currentStageData = {
    stageNum = 1,
    stageName = "Đang quét...",
    recommendedChakra = "Chưa rõ",
    yellowTrophies = "+0",
    purpleTrophies = "+0",
    yellowPad = nil,
    purplePad = nil,
    gatePart = nil,
    stageCenter = nil,
    enemiesCount = 0,
    combatState = "Đang chờ lệnh..."
}

-- Forward Declarations (Tối ưu số lượng biến local cấp cao nhất dưới ngưỡng 200 của Luau)
local startStageLoop, teleportToWorld, teleportToStageOne, stageLoopEpoch = nil, nil, nil, 0
local startNativeClickLoop, triggerRebirthOnce, toggleWhiteScreen, applyFPSBoost
local unlockNextEyeAction, equipBestEyeAction, rollAuraAction
local updateEggTabForWorld, getSelectedCupEggData, scanLiveWorldCupEggs
local LabelCurrentWorldEgg, LabelEggCost, DropdownEgg
local autoSaveSettings, autoLoadSettings
local buyBossShopAction, claimAllFreeRewards, redeemAllKnownCodes, openGameMenu
local findAndClickJoinBoss, isKyubiJoinButton, getKyubiTimerStatus, dumpKyubiBossNow, dismissRobuxModals
local isInsideKyubiArena, isPlayerNearArenaExitPortal, getKyubiBossTarget, executeBossVictoryExit, restorePlayerMovementControls
local LabelWorldBossStatus, LabelWorldBossPhase, bossRemote, bossDropRemote, bossShopRemote, bossHunterState
local LabelCurrentEye, LabelNextEye, LabelEyeProgress, LabelCurrentAura, LabelOwnedAurasCount, LabelCurrentTrainingPad
local sendDiscordWebhook

sendDiscordWebhook = function(title, description, color, fields, isTest)
    local url = _G.AnimeEyes_WebhookURL
    if not url or url == "" or (not url:find("discord%.com/api/webhooks") and not url:find("discordapp%.com/api/webhooks")) then
        if isTest then
            Notification("Webhook", "Vui lòng dán Discord Webhook URL hợp lệ!", 3)
        end
        return false, "Vui lòng nhập đúng URL Discord Webhook!"
    end

    local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request
    if not httpRequest then
        if isTest then
            Notification("Webhook", "Executor hiện tại không hỗ trợ hàm HTTP request!", 3)
        end
        return false, "Executor không hỗ trợ request()"
    end

    local pName = (localPlayer and localPlayer.Name) or "Player"
    local dName = (localPlayer and localPlayer.DisplayName) or pName
    local uid = tostring(localPlayer and localPlayer.UserId or 1)
    local avatarThumb = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%s&width=150&height=150&format=png", uid)

    local embed = {
        title = title or "HelmHub | Anime Eyes Master",
        description = description or "",
        color = color or 8246268,
        fields = fields or {},
        thumbnail = { url = avatarThumb },
        footer = {
            text = "HelmHub // Anime Eyes Master • HelmXGenimi",
            icon_url = "https://t0.rbxcdn.com/42f66da98c40252ee151326a82aab51f"
        },
        timestamp = DateTime.now():ToIsoDate()
    }

    local payload = {
        username = "Helm Resonator Monitor",
        avatar_url = "https://t0.rbxcdn.com/42f66da98c40252ee151326a82aab51f",
        embeds = { embed }
    }

    local encOk, bodyJson = pcall(function() return HttpService:JSONEncode(payload) end)
    if not encOk or not bodyJson then
        return false, "JSON encode error"
    end

    local success, response = pcall(function()
        return httpRequest({
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = bodyJson
        })
    end)

    if success and response then
        local code = tonumber(response.StatusCode or response.Status or 0)
        if code >= 200 and code < 300 then
            if isTest then
                Notification("Webhook", "✅ Gửi Discord Webhook thành công (Mã: 204 OK)!", 3)
            end
            return true
        else
            if isTest then
                Notification("Webhook", "❌ Discord từ chối yêu cầu (Mã HTTP: " .. tostring(code) .. ")", 4)
            end
            return false, "Mã HTTP: " .. tostring(code)
        end
    else
        if isTest then
            Notification("Webhook", "❌ Không thể kết nối tới Discord Webhook!", 4)
        end
        return false, tostring(response)
    end
end

-- ========================================================================
-- 5. KHỞI TẠO NGAY GIAO DIỆN CHÍNH THỨC (INSTANT UI CREATION AT TOP)
-- ========================================================================
local Window = library:CreateWindow("HelmHub | Anime Eyes Master")

-- Hỗ trợ phím tắt đóng/mở UI linh hoạt (Insert, RightControl, RightShift)
pcall(function()
    local uis = game:GetService("UserInputService")
    uis.InputBegan:Connect(function(input, gpe)
        if not gpe and (input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.RightShift) then
            if Window and Window.Frame then
                Window.Frame.Visible = not Window.Frame.Visible
            end
        end
    end)
end)

Notification("HelmHub", "Giao diện thế hệ mới đã mở! (Phím tắt: Insert / RightShift / RightControl)", 4)

-- ------------------------------------------------------------------------
-- TAB 1: CHIẾN ĐẤU (WORLD SELECTOR, STAGE & COMBAT TIMEOUT ENGINE)
-- ------------------------------------------------------------------------
local TabStage = Window:CreateTab("Chiến Đấu")
local SecStageLeft = TabStage:CreateSector("1. Vượt Ải Stage & Thời Gian", "left")
local SecStageRight = TabStage:CreateSector("2. Chọn World, Stage Nhận Cúp & Boss", "right")

local WORLD_LIST = {
    "World 1: Shinobi Lands",
    "World 2: Celestial Realm",
    "World 3: Blood Moon",
    "World 4: Frozen Abyss",
    "World 5: Cosmic Void",
    "World 6: Soul Society",
    "World 7: Hueco Mundo",
    "World 8: Spirit World",
    "World 9: Dragon Realm"
}
local WORLD_NAMES = WORLD_LIST

local WORLD_ORIGINS = {
    Vector3.new(0, 0, 0),
    Vector3.new(3000, 0, 0),
    Vector3.new(6000, 0, 0),
    Vector3.new(9000, 0, 0),
    Vector3.new(12000, 0, 0),
    Vector3.new(15000, 0, 0),
    Vector3.new(18000, 0, 0),
    Vector3.new(21000, 0, 0),
    Vector3.new(24000, 0, 0)
}

-- Hàm tự động phát hiện World theo tọa độ thực tế của nhân vật
local function detectPhysicalWorld()
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local posX = root.Position.X
        local bestW = 1
        local minDiff = 1e9
        for i, orig in ipairs(WORLD_ORIGINS) do
            local diff = math.abs(posX - orig.X)
            if diff < minDiff then
                minDiff = diff
                bestW = i
            end
        end
        return bestW, WORLD_ORIGINS[bestW]
    end
    local w = math.clamp(tonumber(_G.AnimeEyes_SelectedWorld) or 1, 1, 9)
    return w, WORLD_ORIGINS[w]
end

-- Hàm lấy World farm (usePhysical = true sẽ dò theo vị trí đứng thực tế)
local function getFarmWorld(usePhysical)
    if usePhysical then
        return detectPhysicalWorld()
    end
    if _G.AnimeEyes_SelectedWorld then
        local w = math.clamp(tonumber(_G.AnimeEyes_SelectedWorld) or 1, 1, 9)
        return w, WORLD_ORIGINS[w] or Vector3.new((w - 1) * 3000, 0, 0)
    end
    return detectPhysicalWorld()
end

-- Tự động gán World ban đầu theo vị trí nhân vật đang đứng
if not _G.AnimeEyes_SelectedWorld or _G.AnimeEyes_SelectedWorld == 1 then
    local pW = detectPhysicalWorld()
    if pW and pW > 1 then
        _G.AnimeEyes_SelectedWorld = pW
    end
end

-- Khởi tạo Remotes sớm cho toàn bộ UI và Logic
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local function getRemote(name)
    if not remotes then remotes = ReplicatedStorage:FindFirstChild("Remotes") end
    if remotes then
        return remotes:FindFirstChild(name) or remotes:FindFirstChild(name:lower())
    end
    return nil
end

local trainRemote = getRemote("Train")
local castRemote = getRemote("Cast")
local equipRemote = getRemote("Equip")
local unlockEyeRemote = getRemote("UnlockEye")
bossRemote = getRemote("Boss")
bossDropRemote = getRemote("BossDrop")
bossShopRemote = getRemote("BossShop")
local padRemote = getRemote("Pad")
local teleportRemote = getRemote("Teleport")
local rebirthRemote = getRemote("Rebirth")
local autoRebirthRemote = getRemote("AutoRebirth")
local autoOpRemote = getRemote("AutoOp")
local openEggRemote = getRemote("OpenEgg") or getRemote("Hatch") or getRemote("Egg")
local petActionRemote = getRemote("PetAction") or getRemote("Pet") or getRemote("Pets")
local equipAuraRemote = getRemote("EquipAura") or getRemote("Aura")
local arcadeStartRemote = getRemote("ArcadeStart")
local arcadeFinishRemote = getRemote("ArcadeFinish")
local claimQuestRemote = getRemote("ClaimQuest")
local claimDailyRemote = getRemote("ClaimDaily")
local claimGroupRemote = getRemote("ClaimGroup")
local claimRewardRemote = getRemote("ClaimReward")
local exitBonusRemote = getRemote("ExitBonus")
local welcomeBackRemote = getRemote("WelcomeBack")
local redeemCodeRemote = getRemote("RedeemCode")

-- Labels thông số thời gian thực
local LabelStageTitle = SecStageLeft:AddLabel("Ải: Đang quét...")
local LabelStageTimer = SecStageLeft:AddLabel("Thời gian đánh ải: 0.0s / 20s")
local LabelEnemyLive  = SecStageLeft:AddLabel("Quái còn sống: 0 con")
local LabelStageState = SecStageLeft:AddLabel("Trạng thái: Đang chờ lệnh...")

uiRegistry.toggles["AnimeEyes_AutoStage"] = SecStageLeft:AddToggle("Bật Auto Đi Stage Đến Đích", _G.Helm_AutoStage, function(v)
    _G.Helm_AutoStage = (v == true)
    _G.AnimeEyes_AutoStage = false
    stageLoopEpoch = (stageLoopEpoch or 0) + 1
    if queueAutoSave then queueAutoSave() end
    if v then
        currentStageData.combatState = "Đang khởi động Auto Stage..."
        updateLabel(LabelStageState, "Trạng thái: Đang khởi động Auto Stage...")
        if startStageLoop then
            startStageLoop()
        end
        Notification("Auto Stage", string.format("ĐÃ BẬT Auto đi Stage đến đích (Stage %d)!", tonumber(_G.AnimeEyes_TargetStage) or 5), 2)
    else
        if restorePlayerMovementControls then restorePlayerMovementControls() end
        currentStageData.combatState = "Đã dừng Auto Đi Stage."
        updateLabel(LabelStageState, "Trạng thái: Đã dừng Auto Đi Stage.")
        Notification("Auto Stage", "Đã TẮT Auto Đi Stage!", 2)
    end
end)

SecStageLeft:AddToggle("Luôn Đứng Giữa Sàn (Bao Quát Quái & Boss)", _G.AnimeEyes_CenterStage, function(v)
    _G.AnimeEyes_CenterStage = v
    Notification("Vị Trí Sàn", v and "ĐÃ BẬT Đứng giữa sàn đấu bao quát!" or "Đã TẮT đứng giữa sàn!", 2)
end)

SecStageLeft:AddSlider("Giới Hạn Thời Gian Đánh Ải (Giây)", 5, _G.AnimeEyes_StageTimeout, 60, 0, function(v)
    _G.AnimeEyes_StageTimeout = math.floor(tonumber(v) or 20)
end)

SecStageLeft:AddSlider("Tốc Độ Đánh Auto Stage (CPS)", 5, _G.AnimeEyes_StageCPS, 50, 0, function(v)
    _G.AnimeEyes_StageCPS = math.floor(tonumber(v) or 25)
end)

SecStageLeft:AddSlider("Delay Sau Khi Qua Cổng (Giây)", 0.5, _G.AnimeEyes_StageDelay, 3.0, 1, function(v)
    _G.AnimeEyes_StageDelay = tonumber(v) or 1.0
end)

-- Sector 2: Chọn World & Stage Nhận Cúp
local defaultWorldName = WORLD_LIST[_G.AnimeEyes_SelectedWorld] or WORLD_LIST[1]
SecStageRight:AddDropdown("Chọn World Muốn Farm (World 1 - 9)", WORLD_LIST, defaultWorldName, false, function(v)
    local wNum = tonumber(tostring(v):match("World%s*(%d+)")) or 1
    _G.AnimeEyes_SelectedWorld = wNum
    if teleportToWorld then
        teleportToWorld(wNum)
    end
    if updateEggTabForWorld then
        updateEggTabForWorld(wNum)
    end
end)

SecStageRight:AddButton("Dịch Chuyển Đến World Này Ngay", function()
    if teleportToWorld then
        teleportToWorld(_G.AnimeEyes_SelectedWorld or 1)
    end
end)

uiRegistry.sliders["AnimeEyes_TargetStage"] = SecStageRight:AddSlider("Chọn Stage Đích Để Nhận Cúp (1 - 15)", 1, _G.AnimeEyes_TargetStage, 15, 0, function(v)
    _G.AnimeEyes_TargetStage = math.floor(math.clamp(tonumber(v) or 5, 1, 15) + 0.5)
    if queueAutoSave then queueAutoSave() end
end)

SecStageRight:AddLabel("Lưu ý: Chỉ nhận Cúp Vàng (Free) tại Stage đích.")
SecStageRight:AddLabel("Bỏ qua Bệ Tím x3 (Nạp tiền). Nhận xong sẽ tự Reset ván!")

LabelWorldBossStatus = SecStageRight:AddLabel("Boss Thế Giới: Đang theo dõi...")
LabelWorldBossPhase = SecStageRight:AddLabel("Tiến trình: Đang chờ sự kiện")

uiRegistry.toggles["AnimeEyes_AutoBoss"] = SecStageRight:AddToggle("Tự Động Săn Boss Thế Giới (Kyubi & Menoz)", _G.Helm_AutoBoss, function(v)
    _G.Helm_AutoBoss = (v == true)
    _G.AnimeEyes_AutoBoss = false
    if not v and restorePlayerMovementControls then
        restorePlayerMovementControls()
    end
    if queueAutoSave then queueAutoSave() end
    Notification("World Boss", v and "ĐÃ BẬT Tự động săn Boss Thế Giới Kyubi & Menoz (Ưu tiên số 1)!" or "Đã TẮT săn Boss!", 2)
end)

_G.AnimeEyes_SelectedBossVote = _G.AnimeEyes_SelectedBossVote or "menos"
SecStageRight:AddDropdown("Chọn Boss Ưu Tiên Vote", { "MENOZ (Boss Mới - Bleach)", "KYUBI (Cửu Vĩ Kurama)" }, (_G.AnimeEyes_SelectedBossVote == "kyubi") and "KYUBI (Cửu Vĩ Kurama)" or "MENOZ (Boss Mới - Bleach)", false, function(v)
    _G.AnimeEyes_SelectedBossVote = tostring(v):find("KYUBI") and "kyubi" or "menos"
    if queueAutoSave then queueAutoSave() end
    Notification("Vote Boss", string.format("Đã chọn ưu tiên vote cho %s!", _G.AnimeEyes_SelectedBossVote:upper()), 2)
end)

_G.AnimeEyes_AutoVoteBoss = (_G.AnimeEyes_AutoVoteBoss ~= nil) and _G.AnimeEyes_AutoVoteBoss or true
SecStageRight:AddToggle("Tự Động Vote Boss Khi Mở Cổng Vote", _G.AnimeEyes_AutoVoteBoss, function(v)
    _G.AnimeEyes_AutoVoteBoss = v
    if queueAutoSave then queueAutoSave() end
    Notification("Vote Boss", v and "ĐÃ BẬT Tự động Vote Boss khi mở cổng!" or "Đã TẮT Auto Vote Boss!", 2)
end)

SecStageRight:AddSlider("Độ Cao Bay Trên Đầu Boss (Studs)", 10, _G.AnimeEyes_BossHoverHeight or 26, 40, 0, function(v)
    _G.AnimeEyes_BossHoverHeight = math.floor(tonumber(v) or 26)
    if queueAutoSave then queueAutoSave() end
end)

SecStageRight:AddButton("Tham Gia Boss / Nhận Quà Boss Ngay", function()
    pcall(function()
        if findAndClickJoinBoss then findAndClickJoinBoss() end
        if bossRemote then bossRemote:FireServer(true) end
        if bossDropRemote then bossDropRemote:FireServer() end
    end)
    Notification("Boss", "Đã gửi lệnh tham gia Boss & nhận quà!", 2)
end)

SecStageRight:AddButton("Tự Động Mua Vật Phẩm Boss Shop (Kyubi & Menoz)", function()
    if buyBossShopAction then buyBossShopAction(true) end
end)

SecStageRight:AddButton("Rời Khỏi Map Boss (Về Hub Spawn)", function()
    task.spawn(function()
        if executeBossVictoryExit then
            executeBossVictoryExit("Bấm nút Rời Khỏi Map Boss thủ công")
        end
    end)
end)

SecStageRight:AddButton(">>> DUMP QUÁ TRÌNH & GIAO DIỆN BOSS <<<", function()
    if dumpKyubiBossNow then
        dumpKyubiBossNow()
    else
        Notification("Boss Dump", "Hệ thống đang chuẩn bị bộ Dump...", 2)
    end
end)

-- ------------------------------------------------------------------------
-- TAB 2: TỰ ĐỘNG FARM (FARM CHAKRA & TRÙNG SINH TÍCH HỢP)
-- ------------------------------------------------------------------------
do
local TabFarm = Window:CreateTab("Tự Động Farm")
local SecClick = TabFarm:CreateSector("1. Đòn Đánh Chakra Native", "left")
local SecRebirth = TabFarm:CreateSector("2. Trùng Sinh (Auto Rebirth)", "left")
local SecFarmSkills = TabFarm:CreateSector("3. Kỹ Năng & Trạng Thái", "right")

-- Hiển thị Ping
local PingLabel = SecFarmSkills:AddLabel("Ping: Đang đo...")
task.spawn(function()
    while isSessionActive() do
        pcall(function()
            local ping = 50
            local net = StatsService:FindFirstChild("Network") and StatsService.Network:FindFirstChild("ServerStatsItem")
            local p = net and net:FindFirstChild("Data Ping")
            if p then ping = math.floor(p:GetValue()) end
            if PingLabel and PingLabel.Set then
                PingLabel:Set(string.format("Ping: %d ms (Mượt)", ping))
            end
        end)
        task.wait(1.5)
    end
end)

uiRegistry.toggles["AnimeEyes_AutoClick"] = SecClick:AddToggle("Bật Auto Click Native (Chuẩn Game)", _G.AnimeEyes_AutoClick, function(v)
    _G.AnimeEyes_AutoClick = v
    if queueAutoSave then queueAutoSave() end
    if v and startNativeClickLoop then
        startNativeClickLoop()
        Notification("Auto Click", "ĐÃ BẬT Auto Click Native!", 2)
    else
        Notification("Auto Click", "Đã TẮT Auto Click!", 2)
    end
end)

SecClick:AddSlider("Tốc Độ Click (CPS)", 5, _G.AnimeEyes_TargetCPS, 50, 0, function(v)
    _G.AnimeEyes_TargetCPS = math.floor(tonumber(v) or 25)
end)

SecClick:AddToggle("Bỏ Giới Hạn Cooldown Đòn Đánh", _G.AnimeEyes_BypassCooldown, function(v)
    _G.AnimeEyes_BypassCooldown = v
end)

-- Trùng Sinh (Auto Rebirth) đưa vào chung Tab Farm
uiRegistry.toggles["AnimeEyes_AutoRebirth"] = SecRebirth:AddToggle("Bật Tự Động Trùng Sinh (Auto Rebirth)", _G.AnimeEyes_AutoRebirth, function(v)
    _G.AnimeEyes_AutoRebirth = v
    if v and _G.AnimeEyes_AutoTrainPad == nil then
        _G.AnimeEyes_AutoTrainPad = true
    end
    if queueAutoSave then queueAutoSave() end
    Notification("Auto Rebirth", v and "ĐÃ BẬT Tự Động Trùng Sinh & Tự động đứng bệ tối ưu!" or "Đã TẮT Trùng Sinh!", 2)
end)

uiRegistry.toggles["AnimeEyes_AutoTrainPad"] = SecRebirth:AddToggle("Tự Đứng Bệ Farm Chakra (Rebirth)", _G.AnimeEyes_AutoTrainPad, function(v)
    _G.AnimeEyes_AutoTrainPad = v
    if queueAutoSave then queueAutoSave() end
    Notification("Training Pad", v and "ĐÃ BẬT Tự động đứng bệ Trùng Sinh tối ưu để farm Chakra!" or "Đã TẮT!", 2)
end)

LabelCurrentTrainingPad = SecRebirth:AddLabel("Bệ Farm: Đang quét...")

SecRebirth:AddSlider("Khoảng Cách Giữa Các Lần (Giây)", 0.5, _G.AnimeEyes_RebirthDelay, 5.0, 1, function(v)
    _G.AnimeEyes_RebirthDelay = tonumber(v) or 1.5
end)

SecRebirth:AddButton("Trùng Sinh Ngay Lập Tức (1 Lần)", function()
    if triggerRebirthOnce then triggerRebirthOnce() end
    Notification("Rebirth", "Đã gửi lệnh Trùng Sinh!", 2)
end)

uiRegistry.toggles["AnimeEyes_AutoSkills"] = SecFarmSkills:AddToggle("Tự Tung Chiêu E & R (Shinra & Chibaku)", _G.AnimeEyes_AutoSkills, function(v)
    _G.AnimeEyes_AutoSkills = v
    if queueAutoSave then queueAutoSave() end
end)

SecFarmSkills:AddToggle("Duy Trì 'FREE Auto Clicker' Của Game", _G.AnimeEyes_KeepFreeOn, function(v)
    _G.AnimeEyes_KeepFreeOn = v
end)

SecFarmSkills:AddToggle("Tự Nhận Thưởng Quests / Daily / Group", _G.AnimeEyes_AutoClaims, function(v)
    _G.AnimeEyes_AutoClaims = v
end)
end

-- ------------------------------------------------------------------------
-- TAB 3: MỞ TRỨNG (EGGS & PETS - CHỈ HIỆN TRỨNG CÚP THEO TỪNG WORLD)
-- ------------------------------------------------------------------------
local MASTER_CUP_EGGS = {
    [1] = { worldName = "World 1: Shinobi Lands", eggs = { { id = "normal", name = "Normal Egg", cost = "10 Cúp", offset = Vector3.new(60, 1, 30) }, { id = "shinobi", name = "Shinobi Egg", cost = "400 Cúp", offset = Vector3.new(84, 1, 30) } } },
    [2] = { worldName = "World 2: Celestial Realm", eggs = { { id = "leaf", name = "Leaf Egg", cost = "15K Cúp", offset = Vector3.new(60, 1, 30) }, { id = "sand", name = "Sand Egg", cost = "500K Cúp", offset = Vector3.new(84, 1, 30) } } },
    [3] = { worldName = "World 3: Blood Moon", eggs = { { id = "sound", name = "Sound Egg", cost = "20M Cúp", offset = Vector3.new(60, 1, 30) }, { id = "mist", name = "Mist Egg", cost = "750M Cúp", offset = Vector3.new(84, 1, 30) } } },
    [4] = { worldName = "World 4: Frozen Abyss", eggs = { { id = "cloud", name = "Cloud Egg", cost = "30B Cúp", offset = Vector3.new(60, 1, 30) }, { id = "waterfall", name = "Waterfall Egg", cost = "1T Cúp", offset = Vector3.new(84, 1, 30) } } },
    [5] = { worldName = "World 5: Cosmic Void", eggs = { { id = "rain", name = "Rain Egg", cost = "45T Cúp", offset = Vector3.new(60, 1, 30) }, { id = "star", name = "Star Egg", cost = "1.5Qa Cúp", offset = Vector3.new(84, 1, 30) } } },
    [6] = { worldName = "World 6: Soul Society", eggs = { { id = "soul", name = "Soul Egg", cost = "60Qa Cúp", offset = Vector3.new(60, 1, 30) }, { id = "reaper", name = "Reaper Egg", cost = "2Qi Cúp", offset = Vector3.new(84, 1, 30) } } },
    [7] = { worldName = "World 7: Hueco Mundo", eggs = { { id = "hollow", name = "Hollow Egg", cost = "80Qi Cúp", offset = Vector3.new(60, 1, 30) }, { id = "arrancar", name = "Arrancar Egg", cost = "3Sx Cúp", offset = Vector3.new(84, 1, 30) } } },
    [8] = { worldName = "World 8: Spirit World", eggs = { { id = "spirit", name = "Spirit Egg", cost = "120Sx Cúp", offset = Vector3.new(60, 1, 30) }, { id = "ghost", name = "Ghost Egg", cost = "5Sp Cúp", offset = Vector3.new(84, 1, 30) } } },
    [9] = { worldName = "World 9: Dragon Realm", eggs = { { id = "dragon", name = "Dragon Egg", cost = "200Sp Cúp", offset = Vector3.new(60, 1, 30) }, { id = "celestial_dragon", name = "Celestial Dragon Egg", cost = "8Oc Cúp", offset = Vector3.new(84, 1, 30) } } }
}

-- Quét trực tiếp các biển hiệu Trứng Cúp thực tế trên bản đồ (Đọc chính xác Tên và Giá Cúp từ BillboardGui)
scanLiveWorldCupEggs = function(worldNum)
    local w = math.clamp(tonumber(worldNum) or 1, 1, 9)
    local wData = MASTER_CUP_EGGS[w] or MASTER_CUP_EGGS[1]
    local orig = (WORLD_ORIGINS and WORLD_ORIGINS[w]) or Vector3.new((w - 1) * 3000, 0, 0)

    pcall(function()
        local stand1X = orig.X + 60
        local stand2X = orig.X + 84

        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
                local adornee = desc.Adornee or desc.Parent
                local aPos = (adornee and adornee:IsA("BasePart")) and adornee.Position or nil
                if not aPos and desc.Parent and desc.Parent:IsA("BasePart") then
                    aPos = desc.Parent.Position
                end

                if aPos and math.abs(aPos.Z - 30) <= 25 then
                    local dist1 = math.abs(aPos.X - stand1X)
                    local dist2 = math.abs(aPos.X - stand2X)

                    local eggIdx = nil
                    if dist1 <= 14 then eggIdx = 1
                    elseif dist2 <= 14 then eggIdx = 2 end

                    if eggIdx and wData.eggs[eggIdx] then
                        for _, tl in ipairs(desc:GetDescendants()) do
                            if tl:IsA("TextLabel") and tl.Text and #tl.Text > 0 then
                                local t = tl.Text:upper()
                                -- Nhận diện Tên Trứng (bỏ qua Robux)
                                if t:find("EGG") and not t:find("") and not t:find("ROBUX") and not t:find("BUY") then
                                    wData.eggs[eggIdx].name = tl.Text
                                -- Nhận diện Giá Mua Cúp
                                elseif not t:find("") and not t:find("ROBUX") and not t:find("R$") and not t:find("SKIP") then
                                    if t:match("%d") and not t:find("CHAKRA") and not t:find("STAGE") and not t:find("REACH") then
                                        wData.eggs[eggIdx].cost = tl.Text .. " Cúp"
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    return wData
end

do
local TabEggs = Window:CreateTab("Mở Trứng")
local SecEggsLeft = TabEggs:CreateSector("1. Tự Động Mở Trứng (Auto Hatch)", "left")
local SecEggsRight = TabEggs:CreateSector("2. Quản Lý Thú Cưng (Pets)", "right")

local curInitWorld = math.clamp(tonumber(_G.AnimeEyes_SelectedWorld) or 1, 1, 9)
local initWorldData = (MASTER_CUP_EGGS and MASTER_CUP_EGGS[curInitWorld]) or (MASTER_CUP_EGGS and MASTER_CUP_EGGS[1])
local initFirstEgg = (initWorldData and initWorldData.eggs and initWorldData.eggs[1]) or { name = "Normal Egg", cost = "10 Cúp" }

LabelCurrentWorldEgg = SecEggsLeft:AddLabel("Bản Đồ: " .. (WORLD_NAMES and WORLD_NAMES[curInitWorld] or ("World " .. curInitWorld)))
LabelEggCost = SecEggsLeft:AddLabel("Giá Mua: " .. tostring(initFirstEgg.cost or "10 Cúp"))

local function getEggDisplayList(w)
    local wData = (MASTER_CUP_EGGS and MASTER_CUP_EGGS[w]) or (MASTER_CUP_EGGS and MASTER_CUP_EGGS[1])
    local list = {}
    if wData and wData.eggs then
        for _, egg in ipairs(wData.eggs) do
            table.insert(list, string.format("%s (%s)", tostring(egg.name), tostring(egg.cost)))
        end
    end
    if #list == 0 then
        table.insert(list, "Normal Egg (10 Cúp)")
    end
    return list
end

local initialEggList = getEggDisplayList(curInitWorld)
local initialDefault = initialEggList[1] or "Normal Egg (10 Cúp)"
_G.AnimeEyes_SelectedEgg = tostring(initFirstEgg.name or "Normal Egg")

DropdownEgg = SecEggsLeft:AddDropdown("Chọn Trứng Mở Bằng Cúp", initialEggList, initialDefault, false, function(v)
    local str = tostring(v)
    local rawName = str:match("^(.-)%s*%(") or str
    rawName = rawName:gsub("^%s*(.-)%s*$", "%1")
    _G.AnimeEyes_SelectedEgg = rawName

    local costStr = str:match("%((.-)%)") or "Cúp"
    if LabelEggCost then
        updateLabel(LabelEggCost, "Giá Mua: " .. costStr)
    end
    Notification("Chọn Trứng", "Đã chọn: " .. rawName .. " (" .. costStr .. ")", 2)
end)

-- Hàm cập nhật toàn bộ Tab Mở Trứng theo World đang chọn (Chỉ hiện Trứng Cúp của World đó)
updateEggTabForWorld = function(worldNum)
    worldNum = math.clamp(tonumber(worldNum) or 1, 1, 9)
    local wData = scanLiveWorldCupEggs(worldNum)

    if LabelCurrentWorldEgg then
        updateLabel(LabelCurrentWorldEgg, "Bản Đồ: " .. (WORLD_NAMES[worldNum] or ("World " .. worldNum)))
    end

    local newEggItems = {}
    for _, egg in ipairs(wData.eggs) do
        table.insert(newEggItems, string.format("%s (%s)", tostring(egg.name), tostring(egg.cost)))
    end
    if #newEggItems == 0 then
        table.insert(newEggItems, "Normal Egg (10 Cúp)")
    end

    if DropdownEgg then
        pcall(function()
            if DropdownEgg.Refresh then
                DropdownEgg:Refresh(newEggItems)
            else
                local currentItems = {}
                for _, item in ipairs(DropdownEgg.items or {}) do
                    table.insert(currentItems, item)
                end
                for _, item in ipairs(currentItems) do
                    DropdownEgg:Remove(item)
                end
                for _, item in ipairs(newEggItems) do
                    DropdownEgg:Add(item)
                end
                if #newEggItems > 0 then
                    DropdownEgg:Set(newEggItems[1])
                end
            end

            if newEggItems[1] then
                local rawName = newEggItems[1]:match("^(.-)%s*%(") or newEggItems[1]
                _G.AnimeEyes_SelectedEgg = rawName:gsub("^%s*(.-)%s*$", "%1")
                if LabelEggCost then
                    local costStr = newEggItems[1]:match("%((.-)%)") or "Cúp"
                    updateLabel(LabelEggCost, "Giá Mua: " .. costStr)
                end
            end
        end)
    end
end

-- Lấy thông tin tọa độ bệ trứng Cúp đang chọn trong World
getSelectedCupEggData = function(targetWorld)
    local w = math.clamp(tonumber(targetWorld) or 1, 1, 9)
    local wData = MASTER_CUP_EGGS[w] or MASTER_CUP_EGGS[1]
    local selectedName = tostring(_G.AnimeEyes_SelectedEgg or ""):lower()
    for _, egg in ipairs(wData.eggs) do
        if egg.name:lower():find(selectedName) or selectedName:find(egg.name:lower()) then
            return egg
        end
    end
    return wData.eggs[1]
end

SecEggsLeft:AddButton("Dịch Chuyển Đến Bệ Trứng Này Ngay", function()
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local targetWorld, worldOrigin = getFarmWorld()
    local eggData = getSelectedCupEggData(targetWorld)
    local standPos = worldOrigin + eggData.offset + Vector3.new(0, 1.2, 0)

    root.CFrame = CFrame.new(standPos)
    root.Velocity = Vector3.zero
    Notification("Bệ Trứng", string.format("Đã đến bệ %s tại Hub World %d!", eggData.name, targetWorld), 2)
end)

local HATCH_AMOUNTS = { "HATCH x3 (Mở 3 Trứng)", "HATCH x1 (Mở 1 Trứng)" }
local defaultHatchLabel = (tonumber(_G.Helm_HatchAmount) == 1) and "HATCH x1 (Mở 1 Trứng)" or "HATCH x3 (Mở 3 Trứng)"
uiRegistry.dropdowns["Helm_HatchAmount"] = SecEggsLeft:AddDropdown("Số Lượng Mở Mỗi Lần", HATCH_AMOUNTS, defaultHatchLabel, false, function(v)
    local str = tostring(v)
    if str:find("1") then
        _G.Helm_HatchAmount = 1
    else
        _G.Helm_HatchAmount = 3
    end
    _G.AnimeEyes_HatchAmount = _G.Helm_HatchAmount
    if queueAutoSave then queueAutoSave() end
end)

uiRegistry.toggles["AnimeEyes_AutoHatch"] = SecEggsLeft:AddToggle("Bật Tự Động Mở Trứng (Auto Hatch)", _G.AnimeEyes_AutoHatch, function(v)
    _G.AnimeEyes_AutoHatch = v
    if queueAutoSave then queueAutoSave() end
    Notification("Auto Hatch", v and "ĐÃ BẬT Tự Động Mở Trứng (Bằng Cúp)!" or "Đã TẮT mở trứng!", 2)
end)

SecEggsLeft:AddButton("Quét / Làm Mới Trứng Map Này", function()
    local targetWorld = getFarmWorld(true)
    _G.AnimeEyes_SelectedWorld = targetWorld
    if updateEggTabForWorld then
        updateEggTabForWorld(targetWorld)
    end
    Notification("Trứng Map", string.format("Đã quét & nạp trứng Cúp cho %s!", WORLD_NAMES[targetWorld] or ("World " .. targetWorld)), 3)
end)

SecEggsRight:AddToggle("Tự Động Trang Bị Pet Tốt Nhất", _G.AnimeEyes_AutoEquipBestPet, function(v)
    _G.AnimeEyes_AutoEquipBestPet = v
    Notification("Pets", v and "ĐÃ BẬT Tự động trang bị Pet mạnh nhất!" or "Đã TẮT!", 2)
end)

SecEggsRight:AddButton("Trang Bị Pet Mạnh Nhất Ngay", function()
    pcall(function()
        if petActionRemote then
            if petActionRemote:IsA("RemoteFunction") then
                petActionRemote:InvokeServer("EquipBest")
            else
                petActionRemote:FireServer("EquipBest")
            end
        end
    end)
    Notification("Pets", "Đã gửi lệnh trang bị Pet mạnh nhất!", 2)
end)

SecEggsRight:AddButton("Mở Kho Thú Cưng (Pets Menu)", function()
    if openGameMenu then openGameMenu("Pets") end
end)

-- ------------------------------------------------------------------------
-- TAB 4: CỬA HÀNG (MY EYES, AURAS & QUÀ TẶNG MIỄN PHÍ)
-- ------------------------------------------------------------------------
local TabShop = Window:CreateTab("Cửa Hàng")
local SecEyes = TabShop:CreateSector("1. My Eyes (Mở Khóa & Trang Bị Mắt)", "left")
local SecAuras = TabShop:CreateSector("2. Auras (Hào Quang Chiến Đấu)", "right")
local SecClaims = TabShop:CreateSector("3. Quà Tặng & Giftcode Miễn Phí", "right")

-- 1. SECTOR MY EYES
LabelCurrentEye = SecEyes:AddLabel("Mắt Đang Dùng: Đang quét...")
LabelNextEye = SecEyes:AddLabel("Mắt Kế Tiếp: Đang quét...")
LabelEyeProgress = SecEyes:AddLabel("Tiến độ: Đang quét...")

uiRegistry.toggles["AnimeEyes_AutoUnlockEyes"] = SecEyes:AddToggle("Tự Động Mua Mắt Khi Đủ Cúp", _G.AnimeEyes_AutoUnlockEyes, function(v)
    _G.AnimeEyes_AutoUnlockEyes = v
    if queueAutoSave then queueAutoSave() end
    Notification("My Eyes", v and "ĐÃ BẬT Tự động mở khóa Mắt khi đủ Cúp!" or "Đã TẮT!", 2)
end)

SecEyes:AddToggle("Tự Động Trang Bị Mắt Xịn Nhất", _G.AnimeEyes_AutoEquipBestEye, function(v)
    _G.AnimeEyes_AutoEquipBestEye = v
    Notification("My Eyes", v and "ĐÃ BẬT Tự động trang bị Mắt mạnh nhất!" or "Đã TẮT!", 2)
    if v and equipBestEyeAction then equipBestEyeAction() end
end)

SecEyes:AddButton("⚡ Mua & Trang Bị Mắt Kế Tiếp", function()
    if unlockNextEyeAction then
        local bought = unlockNextEyeAction(false)
        if bought and equipBestEyeAction then
            task.wait(0.2)
            equipBestEyeAction(false)
        end
    end
end)

SecEyes:AddButton("⭐ Trang Bị Mắt Xịn Nhất", function()
    if equipBestEyeAction then equipBestEyeAction(false) end
end)

SecEyes:AddButton("📂 Mở Menu Eyes Game", function()
    if openGameMenu then openGameMenu("Eyes") end
end)

-- 2. SECTOR AURAS
LabelCurrentAura = SecAuras:AddLabel("Aura Đang Dùng: Đang quét...")
LabelOwnedAurasCount = SecAuras:AddLabel("Bộ Sưu Tập: 0 Auras Đã Sở Hữu")

uiRegistry.toggles["AnimeEyes_AutoRollAuras"] = SecAuras:AddToggle("Tự Động Quay / Mua Aura Game", _G.AnimeEyes_AutoRollAuras, function(v)
    _G.AnimeEyes_AutoRollAuras = v
    if queueAutoSave then queueAutoSave() end
    Notification("Auras", v and "ĐÃ BẬT Tự động quay Aura!" or "Đã TẮT!", 2)
end)

SecAuras:AddToggle("Tự Động Trang Bị Aura Xịn Nhất", _G.AnimeEyes_AutoEquipBestAura, function(v)
    _G.AnimeEyes_AutoEquipBestAura = v
    Notification("Auras", v and "ĐÃ BẬT Tự động trang bị Aura mới nhất!" or "Đã TẮT!", 2)
end)

SecAuras:AddButton("🎲 Quay Aura Ngay (Thủ Công)", function()
    if rollAuraAction then rollAuraAction(true) end
end)

SecAuras:AddButton("📂 Mở Menu Auras Game", function()
    if openGameMenu then openGameMenu("Aura") end
end)

-- 3. SECTOR REWARDS & CLAIMS
SecClaims:AddToggle("Tự Động Nhận Toàn Bộ Quà Miễn Phí", _G.AnimeEyes_AutoClaims, function(v)
    _G.AnimeEyes_AutoClaims = v
    Notification("Nhận Quà", v and "ĐÃ BẬT Tự động nhận Daily, Group, Quests, Online!" or "Đã TẮT!", 2)
end)

SecClaims:AddButton("🎁 Nhận Toàn Bộ Quà Miễn Phí", function()
    if claimAllFreeRewards then claimAllFreeRewards(true) end
end)

SecClaims:AddButton("💎 Kích Hoạt Toàn Bộ Giftcode (9 Mã)", function()
    if redeemAllKnownCodes then redeemAllKnownCodes() end
end)

-- ------------------------------------------------------------------------
-- TAB 5: CÀI ĐẶT (PERFORMANCE & CONFIG)
-- ------------------------------------------------------------------------
local TabSettings = Window:CreateTab("Cài Đặt")
local SecTreoMay = TabSettings:CreateSector("1. Tối Ưu Treo Máy (Performance)", "left")
local SecNhanVat = TabSettings:CreateSector("2. Tùy Biến Nhân Vật (Character)", "right")
local SecConfig = TabSettings:CreateSector("3. Quản Lý Cấu Hình (!HelmHub)", "left")

SecTreoMay:AddToggle("Anti-AFK (Chống Văng Game)", _G.AntiAFK, function(v)
    _G.AntiAFK = v
    Notification("Anti-AFK", v and "ĐÃ BẬT Anti-AFK!" or "Đã TẮT!", 2)
end)

SecTreoMay:AddToggle("Màn Hình Trắng (WhiteScreen)", _G.WhiteScreen, function(v)
    _G.WhiteScreen = v
    if toggleWhiteScreen then toggleWhiteScreen(v) end
    Notification("WhiteScreen", v and "ĐÃ BẬT Màn Hình Trắng!" or "Đã TẮT!", 2)
end)

SecTreoMay:AddButton("Kích Hoạt FPS Boost", function()
    if applyFPSBoost then applyFPSBoost() end
    Notification("FPS Boost", "Đã tối ưu đồ họa để tối đa hóa FPS!", 3)
end)

SecTreoMay:AddToggle("Tắt Log F9 Console", _G.DisableConsoleLogs, function(v)
    _G.DisableConsoleLogs = v
end)

SecTreoMay:AddToggle("Tắt Toàn Bộ Thông Báo Pop-up (No Toasts)", _G.AnimeEyes_MuteToasts, function(v)
    _G.AnimeEyes_MuteToasts = v
    if queueAutoSave then queueAutoSave() end
    if not v then Notification("Thông Báo", "Đã bật hiển thị thông báo popup!", 2) end
end)

SecNhanVat:AddToggle("Bật Tăng Tốc Độ Chạy (WalkSpeed)", _G.WalkSpeedEnabled, function(v)
    _G.WalkSpeedEnabled = v
    if not v and localPlayer.Character then
        local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end
end)

SecNhanVat:AddSlider("Tốc Độ Chạy (WalkSpeed)", 16, _G.WalkSpeedValue, 120, 0, function(v)
    _G.WalkSpeedValue = math.floor(tonumber(v) or 70)
end)

SecConfig:AddLabel("Chế độ: Tự Động Lưu 100% (Auto-Save)")
SecConfig:AddLabel("Mọi thay đổi cài đặt sẽ tự động lưu vào máy")

SecConfig:AddButton("Lưu Cấu Hình Thủ Công (Save)", function()
    if autoSaveSettings then autoSaveSettings(true) end
end)

SecConfig:AddButton("Nạp Lại Cấu Hình Thủ Công (Load)", function()
    if autoLoadSettings then autoLoadSettings(true) end
end)

-- ------------------------------------------------------------------------
-- TAB 6: DISCORD WEBHOOK & BÁO CÁO TỰ ĐỘNG
-- ------------------------------------------------------------------------
local TabWebhook = Window:CreateTab("Webhook")
local SecWebhookCfg = TabWebhook:CreateSector("1. Cấu Hình Discord Webhook", "left")
local SecWebhookTriggers = TabWebhook:CreateSector("2. Tự Động Bắn Thông Báo (Triggers)", "right")

SecWebhookCfg:AddLabel("Dán link Discord Webhook để nhận báo cáo:")
SecWebhookCfg:AddTextbox("Discord Webhook URL", _G.AnimeEyes_WebhookURL or "", function(v)
    _G.AnimeEyes_WebhookURL = tostring(v or ""):gsub("%s+", "")
    if queueAutoSave then queueAutoSave() end
    if _G.AnimeEyes_WebhookURL ~= "" then
        Notification("Webhook", "Đã lưu Discord Webhook URL thành công!", 2)
    end
end)

SecWebhookCfg:AddButton("🔔 Demo 1: Kiểm Tra Ping & Kết Nối", function()
    if sendDiscordWebhook then
        local success, err = sendDiscordWebhook(
            "◈ HelmHub // Kiểm Tra Kết Nối Discord Webhook",
            "Kênh Discord đã liên kết thành công với **HelmHub | Anime Eyes Master**!\nTrạng thái: **🟢 100% Sẵn Sàng Nhận Thông Báo**.",
            8246268,
            {
                { name = "Nhân Vật", value = string.format("**%s** (@%s)", localPlayer.DisplayName or localPlayer.Name, localPlayer.Name), inline = true },
                { name = "Engine", value = "HelmXGenimi", inline = true },
                { name = "Thời Gian", value = os.date("%H:%M:%S - %d/%m/%Y"), inline = true }
            },
            true
        )
        if not success and err then
            Notification("Webhook", "Lỗi gửi: " .. tostring(err), 3)
        end
    end
end)

SecWebhookCfg:AddLabel("Trạng thái: " .. ((_G.AnimeEyes_WebhookURL and _G.AnimeEyes_WebhookURL ~= "") and "🟢 Đã thiết lập URL" or "⚪ Chưa có URL"))
SecWebhookCfg:AddLabel("Lưu ý: Webhook chạy hoàn toàn ngầm không gây lag game.")

-- 2. SECTOR TRIGGERS
uiRegistry.toggles["AnimeEyes_WebhookEnabled"] = SecWebhookTriggers:AddToggle("Bật Toàn Bộ Hệ Thống Webhook", _G.AnimeEyes_WebhookEnabled, function(v)
    _G.AnimeEyes_WebhookEnabled = v
    if queueAutoSave then queueAutoSave() end
    Notification("Webhook", v and "ĐÃ BẬT toàn bộ hệ thống Discord Webhook!" or "Đã TẮT Webhook!", 2)
end)

uiRegistry.toggles["AnimeEyes_WebhookHatch"] = SecWebhookTriggers:AddToggle("Báo Mở Được Pet Khủng (Mythic/Secret)", _G.AnimeEyes_WebhookHatch, function(v)
    _G.AnimeEyes_WebhookHatch = v
    if queueAutoSave then queueAutoSave() end
end)

uiRegistry.toggles["AnimeEyes_WebhookBoss"] = SecWebhookTriggers:AddToggle("Báo Đánh Bại World Boss (Kyubi/Menoz)", _G.AnimeEyes_WebhookBoss, function(v)
    _G.AnimeEyes_WebhookBoss = v
    if queueAutoSave then queueAutoSave() end
end)

uiRegistry.toggles["AnimeEyes_WebhookEye"] = SecWebhookTriggers:AddToggle("Báo Khi Mở Khóa Mắt Mới", _G.AnimeEyes_WebhookEye, function(v)
    _G.AnimeEyes_WebhookEye = v
    if queueAutoSave then queueAutoSave() end
end)

uiRegistry.toggles["AnimeEyes_WebhookPeriodic"] = SecWebhookTriggers:AddToggle("Báo Cáo Tiến Độ Treo Máy Định Kỳ", _G.AnimeEyes_WebhookPeriodic, function(v)
    _G.AnimeEyes_WebhookPeriodic = v
    if queueAutoSave then queueAutoSave() end
end)

SecWebhookTriggers:AddSlider("Khoảng Cách Báo Cáo Định Kỳ (Phút)", 5, _G.AnimeEyes_WebhookInterval or 30, 120, 0, function(v)
    _G.AnimeEyes_WebhookInterval = math.clamp(math.floor(tonumber(v) or 30), 5, 120)
    if queueAutoSave then queueAutoSave() end
end)
end

-- ========================================================================
-- 6. KẾT NỐI REMOTES VÀ CLIENT MODULES (SAFE & NON-BLOCKING)
-- ========================================================================
-- (Các remotes đã được khởi tạo sớm tại phần đầu file để phục vụ UI và Boss Hunter)

local InputModule = nil
local AutoClickModule = nil
local EnemiesModule = nil
local StateModule = nil
local cooldownTable = nil

task.spawn(function()
    pcall(function()
        local ps = localPlayer:FindFirstChild("PlayerScripts") or localPlayer:WaitForChild("PlayerScripts", 2)
        local clientFolder = ps and (ps:FindFirstChild("Client") or ps:WaitForChild("Client", 2))
        if clientFolder then
            local inputScript = clientFolder:FindFirstChild("Input")
            if inputScript then
                InputModule = require(inputScript)
                if debug and debug.getupvalues and InputModule.cooldown then
                    local uvs = debug.getupvalues(InputModule.cooldown)
                    if uvs and typeof(uvs[1]) == "table" then
                        cooldownTable = uvs[1]
                    end
                end
            end

            local autoClickScript = clientFolder:FindFirstChild("AutoClick")
            if autoClickScript then
                AutoClickModule = require(autoClickScript)
            end

            local enemiesScript = clientFolder:FindFirstChild("Enemies")
            if enemiesScript then
                EnemiesModule = require(enemiesScript)
            end

            local stateScript = clientFolder:FindFirstChild("State")
            if stateScript then
                StateModule = require(stateScript)
            end
        end
    end)
end)

-- ========================================================================
-- 7. HỆ THỐNG ĐỊNH VỊ NATIVE WORLD & STAGE (CHUẨN XÁC 100% THEO GAME ENGINE)
-- ========================================================================
local STAGE_LENGTH = 90
local HUB_MIN_Z = -30
local FLOOR_Y = 3.0
local WorldConfig, GatesModule = nil, nil

pcall(function()
    local rsShared = ReplicatedStorage:FindFirstChild("Shared")
    if rsShared and rsShared:FindFirstChild("Config") and rsShared.Config:FindFirstChild("World") then
        WorldConfig = require(rsShared.Config.World)
    end
    local ps = localPlayer:FindFirstChild("PlayerScripts")
    local clientFolder = ps and ps:FindFirstChild("Client")
    if clientFolder and clientFolder:FindFirstChild("Gates") then
        GatesModule = require(clientFolder.Gates)
    end
end)

local getPlayerPhysicalWorld = detectPhysicalWorld
local getCurrentWorld = getFarmWorld

restorePlayerMovementControls = function()
    pcall(function()
        local char = localPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")

        if root then
            root.Anchored = false
            for _, child in ipairs(root:GetChildren()) do
                if child:IsA("BodyMover") or child.Name == "Helm_HoverVelocity" then
                    child:Destroy()
                end
            end
        end

        for _, obj in ipairs(workspace:GetChildren()) do
            if obj.Name == "Helm_SafeFloor" then obj:Destroy() end
        end

        if hum then
            hum.PlatformStand, hum.Sit, hum.AutoRotate = false, false, true
            if hum.WalkSpeed <= 0 then hum.WalkSpeed = (_G.WalkSpeedEnabled and tonumber(_G.WalkSpeedValue)) or 16 end
            if hum.UseJumpPower and hum.JumpPower <= 0 then hum.JumpPower = 50 end
        end

        local ps = localPlayer:FindFirstChild("PlayerScripts")
        local pm = ps and ps:FindFirstChild("PlayerModule")
        if pm then
            local ok, mod = pcall(require, pm)
            if ok and mod and mod.GetControls then
                local controls = mod:GetControls()
                if controls and controls.Enable then controls:Enable() end
            end
        end

        local cam = workspace.CurrentCamera
        if cam and hum then
            if cam.CameraType == Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Custom end
            if not cam.CameraSubject then cam.CameraSubject = hum end
        end
    end)
end

local function ensureStreamingSafeTeleport(targetCFrame)
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    local targetPos = targetCFrame.Position
    local tempPlatform = Instance.new("Part")
    tempPlatform.Name = "Helm_SafeFloor"
    tempPlatform.Size = Vector3.new(40, 3, 40)
    tempPlatform.Position = targetPos - Vector3.new(0, 2.5, 0)
    tempPlatform.Anchored, tempPlatform.CanCollide, tempPlatform.Transparency = true, true, 1
    tempPlatform.Parent = workspace

    root.Anchored = false
    root.CFrame = targetCFrame
    root.Velocity = Vector3.zero

    if localPlayer.RequestStreamAroundAsync then
        task.spawn(function() pcall(localPlayer.RequestStreamAroundAsync, localPlayer, targetPos) end)
    end
    task.delay(0.8, function()
        pcall(function()
            if tempPlatform and tempPlatform.Parent then tempPlatform:Destroy() end
            restorePlayerMovementControls()
        end)
    end)
    task.wait(0.45)
    restorePlayerMovementControls()
end

teleportToWorld = function(worldId)
    local wId = math.clamp(tonumber(worldId) or 1, 1, 9)
    _G.AnimeEyes_SelectedWorld = wId
    pcall(function()
        restorePlayerMovementControls()
        if teleportRemote then teleportRemote:FireServer(wId) end
        local char = localPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local orig = (WorldConfig and WorldConfig.origin and WorldConfig.origin(wId)) or WORLD_ORIGINS[wId] or Vector3.new(0, 0, 0)
            local groundY = (wId == 3) and 18.5 or (FLOOR_Y + 1.0)
            ensureStreamingSafeTeleport(CFrame.new(orig + Vector3.new(0, groundY, 46)))
        end
    end)
    Notification("Chuyển World", string.format("Đã về Hub %s!", WORLD_NAMES[wId] or ("World " .. wId)), 3)
    if updateEggTabForWorld then updateEggTabForWorld(wId) end
end

local function getStageCenter(stageNum)
    local _, worldOrigin = getCurrentWorld()
    stageNum = math.clamp(tonumber(stageNum) or 1, 1, 15)
    if WorldConfig and WorldConfig.spawnCentre then
        local localPos = WorldConfig.spawnCentre(stageNum)
        return worldOrigin + Vector3.new(localPos.X, FLOOR_Y, localPos.Z)
    end
    return worldOrigin + Vector3.new(0, FLOOR_Y, -75 - (stageNum - 1) * STAGE_LENGTH)
end

local function getYellowPadPos(stageNum)
    local _, worldOrigin = getCurrentWorld()
    stageNum = math.clamp(tonumber(stageNum) or 1, 1, 15)
    if WorldConfig and WorldConfig.padPosition then
        local localPos = WorldConfig.padPosition(stageNum, "gold")
        return worldOrigin + Vector3.new(localPos.X, 4.4, localPos.Z)
    end
    return worldOrigin + Vector3.new(20, 4.4, -111 - (stageNum - 1) * STAGE_LENGTH)
end

local function getStageAtZ(zCoord)
    local _, worldOrigin = getCurrentWorld()
    local localZ = zCoord - worldOrigin.Z
    if localZ > HUB_MIN_Z then return 0 end
    if WorldConfig and WorldConfig.stageAt then
        local s = WorldConfig.stageAt(localZ)
        if s and s > 0 then return math.clamp(s, 1, 15) end
    end
    return math.clamp(math.floor((HUB_MIN_Z - localZ) / STAGE_LENGTH) + 1, 1, 15)
end

local function getStageEnemies(stageNum)
    local enemies = {}
    if stageNum < 1 then return enemies end
    local center = getStageCenter(stageNum)

    if EnemiesModule and EnemiesModule.list then
        pcall(function()
            local list = EnemiesModule.list()
            if typeof(list) == "table" then
                for _, e in ipairs(list) do
                    if e and e.pos and (e.pos - center).Magnitude < 60 then
                        table.insert(enemies, e)
                    end
                end
            end
        end)
    end

    if #enemies == 0 then
        pcall(function()
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    local part = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                    if hum and hum.Health > 0 and part then
                        local dist = (part.Position - center).Magnitude
                        if dist < 60 then
                            table.insert(enemies, { id = obj.Name, pos = part.Position, dist = dist, model = obj })
                        end
                    end
                end
            end
        end)
    end
    return enemies
end

local function isStageBarrierOpen(_, stageNum)
    local ok, res = pcall(function()
        local targetWorld = getFarmWorld()
        for _, mapName in ipairs({"Map" .. targetWorld, "World" .. targetWorld, "World_" .. targetWorld}) do
            local m = workspace:FindFirstChild(mapName)
            local st = m and m:FindFirstChild("Stages") and m.Stages:FindFirstChild("Stage" .. stageNum)
            local b = st and st:FindFirstChild("Barrier", true)
            if b and b:IsA("BasePart") then
                if not b.CanCollide then return true end
                local sign = b:FindFirstChild("Sign")
                if sign and sign:FindFirstChild("Left") and sign.Left:IsA("TextLabel") and sign.Left.Text:upper():find("CLEARED") then
                    return true
                end
            end
        end
        return false
    end)
    return ok and res or false
end

local function isCurrentStageCleared(stageNum, elapsedInStage, hadEnemies)
    if stageNum < 1 or elapsedInStage < 0.35 then return false end
    if hadEnemies and #getStageEnemies(stageNum) == 0 then return true end
    if isStageBarrierOpen(getFarmWorld(), stageNum) then return true end
    if not hadEnemies and elapsedInStage >= 1.5 and #getStageEnemies(stageNum) == 0 then return true end
    return false
end

task.spawn(function()
    while isSessionActive() do
        pcall(function()
            local char = localPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local targetWorld = getFarmWorld()
            local curStage = root and getStageAtZ(root.Position.Z) or 0
            local target = math.clamp(tonumber(_G.AnimeEyes_TargetStage) or 5, 1, 15)
            local enemies = (curStage > 0) and getStageEnemies(curStage) or {}
            local stageText = (curStage == 0) and string.format("World %d | Hub (Spawn)", targetWorld) or string.format("World %d | Stage %d", targetWorld, curStage)
            updateLabel(LabelStageTitle, string.format("Ải: %s (Đích: Stage %d)", stageText, target))
            updateLabel(LabelEnemyLive, string.format("Quái còn sống: %d con", #enemies))
            updateLabel(LabelStageState, "Trạng thái: " .. tostring(currentStageData.combatState or "Đang chờ lệnh..."))
        end)
        task.wait(0.3)
    end
end)

-- (Đã tắt vòng lặp đóng bảng ngầm để không tự đóng Menu/Chức năng game người chơi đang mở)

-- ========================================================================
-- 9. LOGIC CHIẾN ĐẤU VƯỢT ẢI & NHẬN CÚP NATIVE (CLEAN & ROCK SOLID)
-- ========================================================================
local function isBossPriorityActive()
    if (isInsideKyubiArena and isInsideKyubiArena()) or (isPlayerNearArenaExitPortal and isPlayerNearArenaExitPortal(220)) then
        return true
    end
    if not _G.Helm_AutoBoss then return false end
    if _G.AnimeEyes_InBossFight or (bossHunterState and bossHunterState ~= "IDLE") then
        return true
    end
    if getKyubiTimerStatus then
        local bossTimerStatus, bossSecsLeft, _, _, _, _, bossHasJoinBtn = getKyubiTimerStatus()
        local secs = tonumber(bossSecsLeft) or 999
        if bossHasJoinBtn or (bossTimerStatus == "waiting" and secs <= 15) or (bossTimerStatus == "active") then
            return true
        end
    end
    return false
end

stageLoopEpoch = stageLoopEpoch or 0
startStageLoop = function()
    stageLoopEpoch = stageLoopEpoch + 1
    local currentEpoch = stageLoopEpoch

    task.spawn(function()
        local currentStageStartTime = os.clock()
        local lastStageIndex, stageHadEnemies = nil, false

        while isSessionActive() and _G.Helm_AutoStage and stageLoopEpoch == currentEpoch do
            local stepSuccess, err = pcall(function()
                local char = localPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not root or not hum or hum.Health <= 0 then task.wait(0.5); return end

                if isBossPriorityActive() then
                    currentStageData.combatState = "Tạm dừng Đi Stage -> Đang ưu tiên Săn Boss Kyubi!"
                    if LabelStageState then updateLabel(LabelStageState, "Trạng thái: Tạm dừng -> Đang ưu tiên Săn Boss Kyubi!") end
                    task.wait(0.4)
                    return
                end

                restorePlayerMovementControls()

                local targetWorld, worldOrigin = getFarmWorld()
                if getPlayerPhysicalWorld() ~= targetWorld then
                    if isBossPriorityActive() then return end
                    currentStageData.combatState = string.format("Đang chuyển sang World %d...", targetWorld)
                    pcall(function() if teleportRemote then teleportRemote:FireServer(targetWorld) end end)
                    root.CFrame = CFrame.new(worldOrigin + Vector3.new(0, FLOOR_Y + 1, 46))
                    root.Velocity = Vector3.zero
                    task.wait(0.5)
                    if isBossPriorityActive() then return end
                    root.CFrame = CFrame.new(worldOrigin + Vector3.new(0, FLOOR_Y + 1, -15))
                    task.wait(0.2)
                    if isBossPriorityActive() then return end
                    root.CFrame = CFrame.new(worldOrigin + Vector3.new(0, FLOOR_Y + 1, -38))
                    task.wait(0.2)
                    if isBossPriorityActive() then return end
                    root.CFrame = CFrame.new(getStageCenter(1))
                    root.Velocity = Vector3.zero
                    lastStageIndex, stageHadEnemies, currentStageStartTime = 1, false, os.clock()
                    task.wait(0.8)
                    return
                end

                local curStage = getStageAtZ(root.Position.Z)
                local targetStage = math.clamp(tonumber(_G.AnimeEyes_TargetStage) or 5, 1, 15)
                local timeout = tonumber(_G.AnimeEyes_StageTimeout) or 20

                if curStage == 0 then
                    if isBossPriorityActive() then return end
                    currentStageData.combatState = "Đang ở Hub -> Tiến vào Stage 1..."
                    root.CFrame = CFrame.new(worldOrigin + Vector3.new(0, FLOOR_Y + 1, -15)); root.Velocity = Vector3.zero; task.wait(0.2)
                    if isBossPriorityActive() then return end
                    root.CFrame = CFrame.new(worldOrigin + Vector3.new(0, FLOOR_Y + 1, -38)); root.Velocity = Vector3.zero; task.wait(0.2)
                    if isBossPriorityActive() then return end
                    root.CFrame = CFrame.new(getStageCenter(1)); root.Velocity = Vector3.zero
                    lastStageIndex, stageHadEnemies, currentStageStartTime = 1, false, os.clock()
                    task.wait(0.6)
                    return
                end

                if curStage ~= lastStageIndex then
                    lastStageIndex, stageHadEnemies, currentStageStartTime = curStage, false, os.clock()
                end

                local elapsed = os.clock() - currentStageStartTime
                local isTimeExpired = (elapsed >= timeout)
                local stageCenter = getStageCenter(curStage)
                local stageEnemies = getStageEnemies(curStage)
                if #stageEnemies > 0 then stageHadEnemies = true end

                local stageCleared = isCurrentStageCleared(curStage, elapsed, stageHadEnemies)
                if LabelStageTimer then
                    updateLabel(LabelStageTimer, string.format("Thời gian đánh ải: %.1fs / %.0fs", math.min(elapsed, timeout), timeout))
                end

                if not stageCleared and not isTimeExpired then
                    currentStageData.combatState = string.format("Stage %d/%d: Đang diệt %d quái (%.1fs/%.0fs)...", curStage, targetStage, #stageEnemies, elapsed, timeout)
                    local isPlayerMoving = (hum.MoveDirection and hum.MoveDirection.Magnitude > 0.05)

                    if _G.AnimeEyes_CenterStage and not isPlayerMoving then
                        if (root.Position - stageCenter).Magnitude > 8 or math.abs(root.Position.Y - FLOOR_Y) > 4.0 then
                            root.CFrame = CFrame.new(stageCenter)
                            root.Velocity = Vector3.zero
                        end
                    end

                    local targetPos, targetId = stageCenter, nil
                    if #stageEnemies > 0 then
                        targetPos, targetId = stageEnemies[1].pos, stageEnemies[1].id
                        if not isPlayerMoving then
                            pcall(function()
                                local lookAt = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
                                if (lookAt - root.Position).Magnitude > 0.5 then root.CFrame = CFrame.new(root.Position, lookAt) end
                            end)
                        end
                    end

                    pcall(function()
                        if cooldownTable and _G.AnimeEyes_BypassCooldown then cooldownTable.attack = 0 end
                        if InputModule and InputModule.autoClick then InputModule.autoClick()
                        elseif trainRemote then trainRemote:FireServer() end
                        if castRemote then castRemote:FireServer("attack", targetPos, targetId) end
                    end)

                    if _G.AnimeEyes_AutoSkills then
                        pcall(function()
                            if cooldownTable and _G.AnimeEyes_BypassCooldown then cooldownTable.E, cooldownTable.R = 0, 0 end
                            if castRemote then
                                castRemote:FireServer("E", targetPos, targetId)
                                castRemote:FireServer("R", targetPos, targetId)
                            end
                        end)
                    end

                    if _G.Helm_AutoBoss and bossDropRemote then pcall(function() bossDropRemote:FireServer() end) end
                    local cps = tonumber(_G.AnimeEyes_StageCPS) or 25
                    task.wait(math.clamp(1 / cps, 0.02, 0.1))
                else
                    if isBossPriorityActive() then return end
                    if curStage >= targetStage then
                        currentStageData.combatState = string.format("ĐẠT ĐÍCH STAGE %d! Đang bước lên Bệ Vàng nhận Cúp...", curStage)
                        root.CFrame = CFrame.new(getYellowPadPos(curStage))
                        root.Velocity = Vector3.zero
                        pcall(function() if padRemote then padRemote:FireServer(curStage, "gold") end end)
                        task.wait(0.8)

                        currentStageData.combatState = string.format("Đã nhận Cúp Vàng! Về Hub Spawn World %d chuẩn bị ván mới...", targetWorld)
                        root.CFrame = CFrame.new(worldOrigin + Vector3.new(0, FLOOR_Y + 1, 46))
                        root.Velocity = Vector3.zero
                        lastStageIndex, stageHadEnemies, currentStageStartTime = 0, false, os.clock()
                        task.wait(1.0)
                    else
                        local nextStage = math.clamp(curStage + 1, 1, 15)
                        currentStageData.combatState = string.format("Vượt Stage %d! Tiến vào sàn đấu Stage %d...", curStage, nextStage)
                        local barrierZ = HUB_MIN_Z - (curStage * STAGE_LENGTH)
                        root.CFrame = CFrame.new(worldOrigin + Vector3.new(0, FLOOR_Y + 1, barrierZ + 5)); root.Velocity = Vector3.zero; task.wait(0.12)
                        root.CFrame = CFrame.new(worldOrigin + Vector3.new(0, FLOOR_Y + 1, barrierZ - 5)); root.Velocity = Vector3.zero; task.wait(0.12)
                        root.CFrame = CFrame.new(getStageCenter(nextStage)); root.Velocity = Vector3.zero
                        lastStageIndex, stageHadEnemies, currentStageStartTime = nextStage, false, os.clock()
                        task.wait(math.clamp(tonumber(_G.AnimeEyes_StageDelay) or 0.5, 0.3, 2.0))
                    end
                end
            end)
            if not stepSuccess then
                safeLog("[HelmHub Stage Error]:", tostring(err))
                task.wait(0.5)
            end
        end
        currentStageData.combatState = "Đã dừng Auto Đi Stage."
    end)
end

if _G.Helm_AutoStage and startStageLoop then
    task.spawn(function() task.wait(0.5); startStageLoop() end)
end

-- ========================================================================
-- 9.5. HỆ THỐNG SĂN BOSS THẾ GIỚI KYUBI (ƯU TIÊN SỐ 1, AUTO DODGE 3D & CỔNG EXIT)
-- ========================================================================
local isGuiActuallyVisible, triggerGuiButton
do
_G.AnimeEyes_KyubiActiveOnScreen = false
bossHunterState = "IDLE"
local joinAttemptTime = 0
local lastLobbyPortalStepTime = 0
local notInFightSince = 0
local lastValidBossPos = nil
local arenaCenterPos = nil
local hadLiveBossInFight = false
local bossMissingSince = 0

localPlayer.CharacterAdded:Connect(function()
    if isSessionActive() and _G.Helm_AutoBoss and (bossHunterState == "FIGHTING" or bossHunterState == "JOINING" or _G.AnimeEyes_InBossFight) then
        task.spawn(function()
            task.wait(0.4)
            if not isSessionActive() or not _G.Helm_AutoBoss then return end
            safeLog("[Kyubi Boss] Phát hiện nhân vật hồi sinh -> Lập tức bấm JOIN lại đấu trường Boss!")
            if findAndClickJoinBoss then findAndClickJoinBoss() end
        end)
    end
end)

isGuiActuallyVisible = function(guiObj)
    if not guiObj or not guiObj:IsA("GuiObject") or not guiObj.Visible then return false end
    local cur = guiObj.Parent
    while cur and not cur:IsA("ScreenGui") do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        cur = cur.Parent
    end
    return not (cur and cur:IsA("ScreenGui") and not cur.Enabled)
end

-- Định vị chính xác Nút / Text LEAVE bên phải thanh máu Boss Kyubi (Main.HUD.Top.KuramaBar.KuramaSide)
local function findBossLeaveButton()
    local pg = localPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end

    local kuramaBar = pg:FindFirstChild("Main") and pg.Main:FindFirstChild("HUD")
        and pg.Main.HUD:FindFirstChild("Top") and pg.Main.HUD.Top:FindFirstChild("KuramaBar")
    if kuramaBar and isGuiActuallyVisible(kuramaBar) then
        for _, desc in ipairs(kuramaBar:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and isGuiActuallyVisible(desc) then
                if (desc.Text or ""):upper():find("LEAVE") then
                    local side = kuramaBar:FindFirstChild("KuramaSide")
                    if side and isGuiActuallyVisible(side) then return side end
                    return (desc.Parent and desc.Parent ~= kuramaBar and desc.Parent:IsA("GuiObject")) and desc.Parent or desc
                end
            end
        end
    end

    for _, desc in ipairs(pg:GetDescendants()) do
        if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and isGuiActuallyVisible(desc) then
            local txt = (desc:IsA("TextButton") and desc.Text or ""):upper()
            for _, child in ipairs(desc:GetDescendants()) do
                if child:IsA("TextLabel") and child.Text and #child.Text > 0 then
                    txt = txt .. " " .. child.Text:upper()
                end
            end
            txt = txt:gsub("^%s*(.-)%s*$", "%1")
            local bn = desc.Name:lower()
            if not txt:find("JOIN") and not txt:find("SKIP") and (txt == "LEAVE" or txt:find("LEAVE") or bn == "leave") then
                return desc
            end
        elseif desc:IsA("TextLabel") and isGuiActuallyVisible(desc) then
            local t = (desc.Text or ""):upper():gsub("^%s*(.-)%s*$", "%1")
            if t == "LEAVE" or t == "LEAVE FIGHT" then
                return (desc.Parent and desc.Parent:IsA("GuiObject")) and desc.Parent or desc
            end
        end
    end
    return nil
end

-- Tìm chính xác Cổng Vàng 3D "EXIT / BACK TO LOBBY" bên trong Đấu Trường Boss Kyubi
-- Trả về: vortexPart (BasePart cổng chạm), portalFloorPos (Vector3 tâm cổng dưới mặt sàn), touchParts (danh sách BasePart của cổng), signPos (Vector3 chữ EXIT)
local function findArenaExitPortal(maxDist)
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local signPart, signModel = nil, nil
    local bestDist = maxDist or 260

    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text then
            local t = desc.Text:upper()
            if t:find("BACK TO LOBBY") or (t == "EXIT" and not desc:FindFirstAncestor("Stages")) then
                local bGui = desc:FindFirstAncestorWhichIsA("BillboardGui") or desc:FindFirstAncestorWhichIsA("SurfaceGui")
                local part = nil
                if bGui then
                    if bGui.Adornee then
                        if bGui.Adornee:IsA("BasePart") then part = bGui.Adornee
                        elseif bGui.Adornee:IsA("Attachment") and bGui.Adornee.Parent and bGui.Adornee.Parent:IsA("BasePart") then part = bGui.Adornee.Parent
                        elseif bGui.Adornee:IsA("Model") then part = bGui.Adornee.PrimaryPart or bGui.Adornee:FindFirstChildWhichIsA("BasePart", true) end
                    end
                    if not part and bGui.Parent then
                        if bGui.Parent:IsA("BasePart") then part = bGui.Parent
                        elseif bGui.Parent:IsA("Attachment") and bGui.Parent.Parent and bGui.Parent.Parent:IsA("BasePart") then part = bGui.Parent.Parent end
                    end
                end
                if not part then part = desc:FindFirstAncestorWhichIsA("BasePart") end
                local mdl = desc:FindFirstAncestorWhichIsA("Model")
                if not part and mdl then part = mdl.PrimaryPart or mdl:FindFirstChildWhichIsA("BasePart", true) end

                if part and part:IsA("BasePart") then
                    if not root then
                        signPart, signModel = part, mdl
                        break
                    end
                    local d = (part.Position - root.Position).Magnitude
                    if d < bestDist then
                        bestDist, signPart, signModel = d, part, mdl
                    end
                end
            end
        end
    end

    if not signPart then return nil, nil, nil, nil end

    local signPos = signPart.Position
    local touchParts = {}
    local seenParts = {}
    local vortexPart = signPart

    local function addCandidatePart(p)
        if not p or not p:IsA("BasePart") or seenParts[p] then return end
        if char and p:IsDescendantOf(char) then return end
        local dXZ = Vector2.new(p.Position.X - signPos.X, p.Position.Z - signPos.Z).Magnitude
        local dY = math.abs(p.Position.Y - signPos.Y)
        if dXZ <= 16 and dY <= 18 then
            seenParts[p] = true
            table.insert(touchParts, p)
            local hasTouch = (p:FindFirstChildOfClass("TouchTransmitter") ~= nil) or (p:FindFirstChild("TouchInterest") ~= nil)
            local hasFX = (p:FindFirstChildOfClass("ParticleEmitter") ~= nil) or (p:FindFirstChildOfClass("Beam") ~= nil)
            local vHasTouch = (vortexPart:FindFirstChildOfClass("TouchTransmitter") ~= nil) or (vortexPart:FindFirstChild("TouchInterest") ~= nil)
            if hasTouch and not vHasTouch then
                vortexPart = p
            elseif not vHasTouch and hasFX then
                vortexPart = p
            elseif not vHasTouch and p.Size.Magnitude < 30 and p.Position.Y < vortexPart.Position.Y and p.Position.Y >= (signPos.Y - 12) then
                vortexPart = p
            end
        end
    end

    addCandidatePart(signPart)
    if signModel then
        for _, d in ipairs(signModel:GetDescendants()) do addCandidatePart(d) end
    end
    if signPart.Parent then
        for _, d in ipairs(signPart.Parent:GetDescendants()) do addCandidatePart(d) end
    end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("TouchTransmitter") and d.Parent and d.Parent:IsA("BasePart") then
            addCandidatePart(d.Parent)
        end
    end

    -- Dò mặt sàn ngay dưới chân chữ EXIT / BACK TO LOBBY để lấy đúng vị trí tâm cổng vàng dưới đất
    local floorY = nil
    pcall(function()
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = {}
        if char then table.insert(ignore, char) end
        for _, tp in ipairs(touchParts) do
            if tp.Size.Magnitude < 25 then table.insert(ignore, tp) end
        end
        rp.FilterDescendantsInstances = ignore
        local hit = workspace:Raycast(Vector3.new(signPos.X, signPos.Y + 4, signPos.Z), Vector3.new(0, -30, 0), rp)
        if hit and hit.Position then floorY = hit.Position.Y end
    end)

    local portalFloorPos
    if vortexPart ~= signPart and vortexPart.Position.Y <= signPos.Y - 1.5 then
        portalFloorPos = vortexPart.Position
    elseif floorY then
        portalFloorPos = Vector3.new(signPos.X, floorY + 3.0, signPos.Z)
    else
        portalFloorPos = Vector3.new(signPos.X, signPos.Y - 4.5, signPos.Z)
    end

    return vortexPart, portalFloorPos, touchParts, signPos
end

isPlayerNearArenaExitPortal = function(maxRadius)
    local vp = findArenaExitPortal(maxRadius or 220)
    return vp ~= nil
end

-- Đọc trực tiếp thanh trạng thái chính thức Main.HUD.Top.KuramaBar.Back.Name
local function getKuramaBarMainText()
    local pg = localPlayer:FindFirstChild("PlayerGui")
    local kb = pg and pg:FindFirstChild("Main") and pg.Main:FindFirstChild("HUD")
        and pg.Main.HUD:FindFirstChild("Top") and pg.Main.HUD.Top:FindFirstChild("KuramaBar")
    if kb and isGuiActuallyVisible(kb) then
        local back = kb:FindFirstChild("Back")
        local nameLbl = back and back:FindFirstChild("Name")
        if nameLbl and nameLbl:IsA("TextLabel") and isGuiActuallyVisible(nameLbl) then
            return (nameLbl.Text or ""):upper()
        end
    end
    return ""
end

-- Quét Cổng Vào Boss thực tế tại Hub/Sảnh ("KYUBI BOSS FIGHT" hoặc "MENOZ / GARGANTA")
local function findLobbyBossEntryPortal()
    local targetWorld, worldOrigin = getFarmWorld(true)
    local groundY = (targetWorld == 3) and 18.5 or (FLOOR_Y + 1.0)
    local foundSignPos = nil
    local fallbackSignPos = nil
    local nextFightText = ""

    pcall(function()
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Text then
                local t = desc.Text:upper()
                if t:find("BOSS FIGHT") or t:find("KYUBI") or t:find("MENOZ") or t:find("MENOS") or t:find("GARGANTA") then
                    local gui = desc:FindFirstAncestorWhichIsA("BillboardGui") or desc:FindFirstAncestorWhichIsA("SurfaceGui")
                    local adornee = gui and (gui.Adornee or gui.Parent)
                    local pPos = nil
                    if adornee and adornee:IsA("BasePart") then pPos = adornee.Position
                    elseif adornee and adornee:IsA("Model") then pPos = adornee:GetPivot().Position end

                    if pPos then
                        local subTxt = ""
                        if gui then
                            for _, sub in ipairs(gui:GetDescendants()) do
                                if sub:IsA("TextLabel") and sub ~= desc and sub.Text and #sub.Text > 0 then
                                    subTxt = subTxt .. " " .. sub.Text:upper()
                                end
                            end
                        end
                        if math.abs(pPos.X - worldOrigin.X) < 600 then
                            foundSignPos = pPos
                            nextFightText = subTxt
                            break
                        elseif not fallbackSignPos then
                            fallbackSignPos = pPos
                            nextFightText = subTxt
                        end
                    end
                end
            end
        end
    end)

    local signPos = foundSignPos or fallbackSignPos
    if not signPos then
        return nil, {}, "", false
    end

    local portalCenterXZ = Vector3.new(signPos.X, groundY, signPos.Z)

    -- Bắn tia Raycast xuống mặt sàn ngay dưới biển hiệu "KYUBI BOSS FIGHT" để lấy đúng cao độ mặt đất cổng Boss
    local rayOrigin = Vector3.new(signPos.X, signPos.Y - 2, signPos.Z)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    if localPlayer.Character then rayParams.FilterDescendantsInstances = { localPlayer.Character } end
    local rayHit = workspace:Raycast(rayOrigin, Vector3.new(0, -45, 0), rayParams)
    if rayHit and rayHit.Position then
        portalCenterXZ = rayHit.Position + Vector3.new(0, 2.5, 0)
    end

    -- Thu thập toàn bộ các BasePart của cánh cổng không gian Boss tại Hub để chạm vật lý & firetouchinterest
    local portalParts = {}
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name ~= "Terrain" then
                if not (localPlayer.Character and obj:IsDescendantOf(localPlayer.Character)) then
                    local dx = obj.Position.X - portalCenterXZ.X
                    local dz = obj.Position.Z - portalCenterXZ.Z
                    local dy = math.abs(obj.Position.Y - portalCenterXZ.Y)
                    if (dx * dx + dz * dz) <= (16 * 16) and dy <= 22 and obj.Size.Magnitude < 45 then
                        table.insert(portalParts, obj)
                    end
                end
            end
        end
    end)

    return portalCenterXZ, portalParts, nextFightText, true
end

-- Xử lý màn hình KNOCKED OUT! (Ảnh 3): Bấm nút Đỏ "No (BACK TO LOBBY)" để về sảnh miễn phí rồi lập tức JOIN lại!
local function checkAndHandleKnockedOut()
    local pg = localPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    local knockedOutFound = false
    for _, desc in ipairs(pg:GetDescendants()) do
        if desc:IsA("TextLabel") and isGuiActuallyVisible(desc) then
            local t = (desc.Text or ""):upper()
            if t:find("KNOCKED OUT") then
                knockedOutFound = true
                local container = desc.Parent
                while container and not container:IsA("ScreenGui") do
                    for _, btn in ipairs(container:GetDescendants()) do
                        if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and isGuiActuallyVisible(btn) then
                            local btxt = (btn:IsA("TextButton") and btn.Text or ""):upper()
                            for _, c in ipairs(btn:GetDescendants()) do
                                if c:IsA("TextLabel") and c.Text then btxt = btxt .. " " .. c.Text:upper() end
                            end
                            -- Chỉ bấm nút "NO" (Back to Lobby), TUYỆT ĐỐI KHÔNG bấm "REVIVE NOW" tốn 9 Robux
                            if (btxt:find("NO") and not btxt:find("NOW")) or btn.Name:lower() == "no" then
                                triggerGuiButton(btn)
                                return true
                            end
                        end
                    end
                    container = container.Parent
                end
                break
            end
        end
    end
    return knockedOutFound
end

isInsideKyubiArena = function()
    local pg = localPlayer:FindFirstChild("PlayerGui")
    if not pg then return false, 100, false, false, false end

    local barText = getKuramaBarMainText()
    local isPortalHome = barText:find("PORTAL HOME") ~= nil
    local hasLeaveBtn = (findBossLeaveButton() ~= nil)
    local bossHpPercent, hasBossPercent, hasKyubiLists = 100, false, false

    if isPortalHome then
        bossHpPercent, hasBossPercent = 0, true
    elseif barText:find("KYUBI") and not barText:find("IN ") and not barText:find("IS HERE") then
        local pct = barText:match("(%d+)%%")
        if pct then
            bossHpPercent, hasBossPercent = tonumber(pct), true
        end
    end

    if not hasBossPercent then
        for _, desc in ipairs(pg:GetDescendants()) do
            if desc:IsA("TextLabel") and isGuiActuallyVisible(desc) then
                local t = desc.Text:upper()
                if t:find("PORTAL HOME") then
                    isPortalHome, bossHpPercent, hasBossPercent = true, 0, true
                    break
                elseif t:find("KYUBI") and not t:find("IN ") and not t:find("IS HERE") and not t:find("IN 0:") and not t:find("IN 1:") and not t:find("IN 2:") and not t:find("IN 3:") then
                    local pct = t:match("(%d+)%%")
                    if pct then
                        bossHpPercent, hasBossPercent = tonumber(pct), true
                        break
                    end
                end
            end
        end
    end

    local kyubiLists = pg:FindFirstChild("KyubiLists")
    local bar = kyubiLists and kyubiLists:FindFirstChild("Bar")
    if bar then
        local dmgBar, dropBar = bar:FindFirstChild("KyubiDamage"), bar:FindFirstChild("KyubiDrops")
        if (dmgBar and isGuiActuallyVisible(dmgBar)) or (dropBar and isGuiActuallyVisible(dropBar)) then
            hasKyubiLists = true
        end
    end

    local hasEnragedTag = false
    local kb = pg:FindFirstChild("Main") and pg.Main:FindFirstChild("HUD")
        and pg.Main.HUD:FindFirstChild("Top") and pg.Main.HUD.Top:FindFirstChild("KuramaBar")
    if kb and isGuiActuallyVisible(kb) then
        local tagLbl = kb:FindFirstChild("Tag")
        if tagLbl and tagLbl:IsA("TextLabel") and isGuiActuallyVisible(tagLbl) then
            local tagTxt = (tagLbl.Text or ""):upper()
            if tagTxt:find("ENRAGED") then
                hasEnragedTag = true
            end
        end
    end

    local inFight = (hasLeaveBtn or hasBossPercent or hasKyubiLists or isPortalHome or hasEnragedTag)
    return inFight, bossHpPercent, hasLeaveBtn, hasBossPercent, isPortalHome
end

-- CHỈ lấy tọa độ Boss Kyubi / Menoz thực sự trong Đấu Trường Boss (TUYỆT ĐỐI KHÔNG lấy nhầm quái Stage thường!)
getKyubiBossTarget = function()
    if EnemiesModule and EnemiesModule.list then
        local ok, list = pcall(EnemiesModule.list)
        if ok and typeof(list) == "table" and #list > 0 then
            for _, item in ipairs(list) do
                local idStr = tostring(item.id or item.name or ""):lower()
                if (item.boss or idStr:find("kyubi") or idStr:find("kurama") or idStr:find("menos") or idStr:find("menoz") or idStr:find("boss")) and item.pos and item.pos.Y > -100 then
                    lastValidBossPos = item.pos
                    if not arenaCenterPos then arenaCenterPos = item.pos end
                    return item.pos, item.id or (idStr:find("menos") and "Menoz" or "Kyubi"), true
                end
            end
        end
    end

    local _, portalFloorPos, _, signPos = findArenaExitPortal(260)
    local refPos = arenaCenterPos or lastValidBossPos or portalFloorPos or signPos
    local myEnemies = workspace:FindFirstChild("MyEnemies")
    if myEnemies then
        for _, m in ipairs(myEnemies:GetChildren()) do
            local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart or m:FindFirstChild("root") or m:FindFirstChild("Torso") or m:FindFirstChildOfClass("BasePart")
            if r and r.Position.Y > -100 then
                local mName = m.Name:lower()
                local isNamedBoss = mName:find("kyubi") or mName:find("kurama") or mName:find("menos") or mName:find("menoz") or mName:find("boss") or (m:GetAttribute("Boss") == true)
                local isNearArena = refPos and ((r.Position - refPos).Magnitude <= 85) or false
                if isNamedBoss or isNearArena then
                    lastValidBossPos = r.Position
                    if not arenaCenterPos then arenaCenterPos = r.Position end
                    return r.Position, m.Name, true
                end
            end
        end
    end
    return lastValidBossPos, (workspace:GetAttribute("BossKind") == "menos" and "Menoz" or "Kyubi"), false
end

-- Giữ tọa độ (X, Z) của nhân vật luôn nằm gọn bên trong tường Đấu Trường Boss (không bao giờ văng ra ngoài tường đen)
local function clampInsideBossArena(pos, fallbackCenter)
    local center = arenaCenterPos or fallbackCenter or pos
    if not arenaCenterPos and fallbackCenter then
        arenaCenterPos = fallbackCenter
        center = arenaCenterPos
    end
    if not center then return pos end

    local offsetXZ = Vector2.new(pos.X - center.X, pos.Z - center.Z)
    local maxSafeRadius = 13.5
    if offsetXZ.Magnitude > maxSafeRadius then
        local clampedXZ = offsetXZ.Unit * maxSafeRadius
        return Vector3.new(center.X + clampedXZ.X, pos.Y, center.Z + clampedXZ.Y)
    end
    return pos
end

triggerGuiButton = function(btn)
    if not btn then return false end
    local clicked = false
    local targets = { btn }
    if btn.Parent and btn.Parent:IsA("GuiObject") and btn.Parent.AbsoluteSize.X < 450 and btn.Parent.AbsoluteSize.Y < 180 then
        table.insert(targets, btn.Parent)
    end
    for _, desc in ipairs(btn:GetDescendants()) do
        if desc:IsA("GuiButton") or desc:IsA("TextLabel") or desc:IsA("Frame") then table.insert(targets, desc) end
    end

    local btnCenter = Vector2.new(0, 0)
    pcall(function()
        if btn.AbsolutePosition and btn.AbsoluteSize then
            btnCenter = btn.AbsolutePosition + (btn.AbsoluteSize / 2)
        end
    end)

    for _, t in ipairs(targets) do
        pcall(function()
            if replicatesignal and t:IsA("GuiButton") then
                pcall(replicatesignal, t.Activated)
                pcall(replicatesignal, t.MouseButton1Click)
                clicked = true
            end
            if firesignal then
                for _, ev in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up"}) do
                    if t[ev] then pcall(firesignal, t[ev]); clicked = true end
                end
            end
            if getconnections then
                for _, ev in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up"}) do
                    local sig = t[ev]
                    if sig then
                        for _, conn in ipairs(getconnections(sig) or {}) do
                            if conn.Fire then pcall(conn.Fire, conn); clicked = true end
                            if conn.Function then pcall(conn.Function); clicked = true end
                        end
                    end
                end
                for _, ev in ipairs({"InputBegan", "InputEnded"}) do
                    local sig = t[ev]
                    if sig then
                        local uState = (ev == "InputBegan") and Enum.UserInputState.Begin or Enum.UserInputState.End
                        local posVec = Vector3.new(btnCenter.X, btnCenter.Y, 0)
                        local mockMouse = {
                            UserInputType = Enum.UserInputType.MouseButton1,
                            UserInputState = uState,
                            Position = posVec,
                            Delta = Vector3.zero,
                            KeyCode = Enum.KeyCode.Unknown
                        }
                        local mockTouch = {
                            UserInputType = Enum.UserInputType.Touch,
                            UserInputState = uState,
                            Position = posVec,
                            Delta = Vector3.zero,
                            KeyCode = Enum.KeyCode.Unknown
                        }
                        for _, conn in ipairs(getconnections(sig) or {}) do
                            if conn.Fire then
                                pcall(conn.Fire, conn, mockMouse, false)
                                pcall(conn.Fire, conn, mockTouch, false)
                                clicked = true
                            end
                            if conn.Function then
                                pcall(conn.Function, mockMouse, false)
                                pcall(conn.Function, mockTouch, false)
                                clicked = true
                            end
                        end
                    end
                end
            end
        end)
    end

    -- Luôn gửi kèm click VirtualInputManager vào đúng tâm nút (nếu nút không bị che bởi cửa sổ HelmHub)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local guiService = game:GetService("GuiService")
        local inset = guiService and guiService:GetGuiInset() or Vector2.new(0, 36)
        if vim and btn.AbsolutePosition and btn.AbsoluteSize and btn.AbsoluteSize.X > 0 and btn.AbsoluteSize.Y > 0 then
            local center = btn.AbsolutePosition + btn.AbsoluteSize / 2
            if Window and Window.Frame and Window.Frame.Visible then
                local wp, ws = Window.Frame.AbsolutePosition, Window.Frame.AbsoluteSize
                if center.X >= wp.X and center.X <= (wp.X + ws.X) and center.Y >= wp.Y and center.Y <= (wp.Y + ws.Y) then
                    return
                end
            end
            local clickX = center.X + (inset.X or 0)
            local clickY = (center.Y < 0) and math.max(center.Y + inset.Y, 18) or (center.Y + inset.Y)
            vim:SendMouseButtonEvent(clickX, clickY, 0, true, game, 1)
            task.wait(0.03)
            vim:SendMouseButtonEvent(clickX, clickY, 0, false, game, 1)
            clicked = true
        end
    end)
    return clicked
end

isKyubiJoinButton = function(btn)
    if not btn or not (btn:IsA("TextButton") or btn:IsA("ImageButton")) or not isGuiActuallyVisible(btn) then return false end
    if btn.AbsoluteSize and (btn.AbsoluteSize.X <= 5 or btn.AbsoluteSize.Y <= 5) then return false end

    local bName = btn.Name:lower()
    local txt = (btn:IsA("TextButton") and btn.Text:upper() or "")
    for _, c in ipairs(btn:GetDescendants()) do
        if c:IsA("TextLabel") and c.Text and #c.Text > 0 then txt = txt .. " " .. c.Text:upper() end
    end
    txt = txt:gsub("^%s*(.-)%s*$", "%1")

    if txt:find("LEAVE") or bName:find("leave") or bName:find("group") or txt:find("GROUP") or bName:find("member") or txt:find("MEMBER") or txt:find("BANDO") or bName:find("community") then
        return false
    end
    local cp = btn.Parent
    while cp and not cp:IsA("ScreenGui") do
        local pn = cp.Name:lower()
        if pn == "community" or pn == "store" or pn == "shop" then return false end
        cp = cp.Parent
    end
    if bName:find("skip") or txt:find("SKIP") or bName:find("robux") or txt:find("29") or txt:find("R$") or txt:find("") or bName:find("chest") or txt:find("CHEST") or bName:find("claim") or txt:find("CLAIM") or bName:find("reward") or txt:find("REWARD") or bName:find("daily") or txt:find("DAILY") or bName:find("code") or txt:find("CODE") or bName:find("like") or txt:find("LIKE") then
        return false
    end
    if not (txt == "JOIN" or txt:find("JOIN") or bName == "join" or bName:find("join")) then return false end

    local cur = btn.Parent
    while cur and not cur:IsA("ScreenGui") do
        local cn = cur.Name:lower()
        if cn:find("kyubi") or cn:find("worldboss") or cn:find("kurama") or cn:find("nine") or cn:find("boss") or cn:find("fight") or cn:find("menos") or cn:find("menoz") or cn:find("garganta") then return true end
        for _, desc in ipairs(cur:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Text then
                local dt = desc.Text:upper()
                if dt:find("KYUBI") or dt:find("MENOZ") or dt:find("MENOS") or dt:find("THE FIGHT") or dt:find("READY") then return true end
            end
        end
        cur = cur.Parent
    end
    return _G.AnimeEyes_KyubiActiveOnScreen == true
end

local function readRawKyubiBarTimer()
    local pg = localPlayer:FindFirstChild("PlayerGui")
    local bestStatus, bestSecondsLeft, hasJoinButton = "unknown", 9999, false
    if not pg then return bestStatus, bestSecondsLeft, hasJoinButton end

    pcall(function()
        -- 1. Ưu tiên tuyệt đối đọc từ thanh KuramaBar.Back.Name chính thức trên đỉnh màn hình
        local barText = getKuramaBarMainText()
        if barText ~= "" then
            if barText:find("PORTAL HOME") then
                bestStatus, bestSecondsLeft = "portal_home", 0
            elseif barText:find("IS HERE") or barText:find("HERE") or barText:find("FIGHT") or barText:find("SPAWN") or barText:find("READY") then
                -- Boss đang có sẵn trên map! ("KYUBI IS HERE!" hoặc "MENOZ IS HERE!")
                bestStatus, bestSecondsLeft, hasJoinButton = "active", 0, true
            else
                local m, s = barText:match("[%w_]+%s*IN%s*(%d+)%s*:%s*(%d+)")
                if m and s then
                    bestStatus, bestSecondsLeft = "waiting", tonumber(m) * 60 + tonumber(s)
                    if bestSecondsLeft <= 15 then hasJoinButton = true end
                else
                    local sOnly = barText:match("[%w_]+%s*IN%s*(%d+)")
                    if sOnly then
                        bestStatus, bestSecondsLeft = "waiting", tonumber(sOnly)
                        if bestSecondsLeft <= 15 then hasJoinButton = true end
                    elseif barText:find("%%") then
                        local pct = tonumber(barText:match("(%d+)%%"))
                        if pct and pct <= 0 then
                            bestStatus, bestSecondsLeft = "portal_home", 0
                        else
                            bestStatus, bestSecondsLeft = "active", 0
                        end
                    end
                end
            end
        end

        -- 1.5. Đọc bổ sung từ Server Workspace Attributes (Độ chuẩn xác 100%)
        local serverPhase = workspace:GetAttribute("BossPhase")
        if serverPhase == "fight" then
            bestStatus, bestSecondsLeft, hasJoinButton = "active", 0, true
        elseif serverPhase == "coming" then
            bestStatus = "waiting"
            if bestSecondsLeft > 15 then bestSecondsLeft = 10 end
            hasJoinButton = true
        end

        -- 2. Kiểm tra nút JOIN xanh lá trên KuramaBar.KuramaSide / MenosCall / Overlay
        local hud = pg:FindFirstChild("Main") and pg.Main:FindFirstChild("HUD")
        local kuramaCall = hud and hud:FindFirstChild("Overlay") and (hud.Overlay:FindFirstChild("KuramaCall") or hud.Overlay:FindFirstChild("MenosCall"))
        if kuramaCall and isGuiActuallyVisible(kuramaCall) then
            for _, c in ipairs(kuramaCall:GetDescendants()) do
                if (c:IsA("TextLabel") or c:IsA("TextButton")) and c.Text and c.Text:upper():find("JOIN") and isGuiActuallyVisible(c) then
                    hasJoinButton = true
                    break
                end
            end
        end
        local kuramaBar = hud and hud:FindFirstChild("Top") and (hud.Top:FindFirstChild("KuramaBar") or hud.Top:FindFirstChild("MenosBar"))
        if kuramaBar and isGuiActuallyVisible(kuramaBar) then
            local side = kuramaBar:FindFirstChild("KuramaSide") or kuramaBar:FindFirstChild("MenosSide") or kuramaBar:FindFirstChild("Join")
            if side and isGuiActuallyVisible(side) then
                local sideTxt = (side:IsA("TextLabel") or side:IsA("TextButton")) and (side.Text or ""):upper() or ""
                for _, c in ipairs(side:GetDescendants()) do
                    if (c:IsA("TextLabel") or c:IsA("TextButton")) and c.Text then
                        sideTxt = sideTxt .. " " .. c.Text:upper()
                    end
                end
                if sideTxt:find("JOIN") and not sideTxt:find("LEAVE") then
                    hasJoinButton = true
                    if bestStatus == "unknown" then
                        bestStatus, bestSecondsLeft = "active", 0
                    end
                end
            end
        end
    end)

    return bestStatus, bestSecondsLeft, hasJoinButton
end

-- Vào khu vực Boss an toàn (Không bao giờ kéo ngược nhân vật từ sàn Boss ra ngoài Map/Stage!)
local joinStepCounter = 0
findAndClickJoinBoss = function()
    -- 1. Nếu ĐÃ ở trong Đấu Trường Boss thì giữ nguyên tuyệt đối, KHÔNG dịch chuyển ra ngoài!
    local inArenaNow = isInsideKyubiArena()
    local _, _, hasLiveBoss = getKyubiBossTarget()
    if inArenaNow or hasLiveBoss or isPlayerNearArenaExitPortal(220) then
        return true
    end

    local clickedCount = 0
    local pg = localPlayer:FindFirstChild("PlayerGui")

    -- Chỉ vào Boss khi Boss thực sự đang có trên map / mở cổng (TUYỆT ĐỐI KHÔNG vào khi đang đếm ngược > 15s)
    local rawStatus, rawSecs, hasJoinBtn = readRawKyubiBarTimer()
    if rawStatus == "portal_home" or (rawStatus == "waiting" and rawSecs > 15 and not hasJoinBtn) then
        return false
    end

    -- 2. Khắc phục lỗi "Finish your wave first!":
    -- Nếu nhân vật đang đứng giữa ải Stage (Z < -30), phải Reset về Hub Spawn (Z = 46) trước khi bấm JOIN!
    pcall(function()
        local char = localPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and getStageAtZ(root.Position.Z) >= 1 then
            restorePlayerMovementControls()
            local curWorld, worldOrigin = detectPhysicalWorld()
            local groundY = (curWorld == 3) and 18.5 or (FLOOR_Y + 1.0)
            if teleportRemote then
                pcall(function() teleportRemote:FireServer(curWorld) end)
            end
            root.Anchored = false
            root.CFrame = CFrame.new(worldOrigin + Vector3.new(0, groundY, 46))
            root.Velocity = Vector3.zero
            task.wait(0.28)
        end
    end)

    -- 3. Ưu tiên Cách 1: Gửi Remote Boss & Bấm nút JOIN xanh lá trên KuramaBar / KuramaCall (Đứng yên đợi Server tele vào Boss)
    pcall(function()
        if bossRemote then
            bossRemote:FireServer(true)
            bossRemote:FireServer("join")
            bossRemote:FireServer(1)
            bossRemote:FireServer()
        end
    end)

    if pg then
        pcall(function()
            local kuramaCall = pg:FindFirstChild("Main") and pg.Main:FindFirstChild("HUD") and pg.Main.HUD:FindFirstChild("Overlay") and pg.Main.HUD.Overlay:FindFirstChild("KuramaCall")
            if kuramaCall and isGuiActuallyVisible(kuramaCall) then
                local joinBtn = kuramaCall:FindFirstChild("Join") or kuramaCall:FindFirstChildWhichIsA("TextButton") or kuramaCall:FindFirstChildWhichIsA("ImageButton")
                if joinBtn and triggerGuiButton(joinBtn) then clickedCount = clickedCount + 1 end
            end

            local kuramaBar = pg:FindFirstChild("Main") and pg.Main:FindFirstChild("HUD") and pg.Main.HUD:FindFirstChild("Top") and pg.Main.HUD.Top:FindFirstChild("KuramaBar")
            if kuramaBar and isGuiActuallyVisible(kuramaBar) then
                local sideJoin = kuramaBar:FindFirstChild("KuramaSide") or kuramaBar:FindFirstChild("Join")
                if sideJoin and isGuiActuallyVisible(sideJoin) then
                    local sideTxt = (sideJoin:IsA("TextLabel") or sideJoin:IsA("TextButton")) and (sideJoin.Text or ""):upper() or ""
                    for _, c in ipairs(sideJoin:GetDescendants()) do
                        if (c:IsA("TextLabel") or c:IsA("TextButton")) and c.Text then sideTxt = sideTxt .. " " .. c.Text:upper() end
                    end
                    if sideTxt:find("JOIN") and not sideTxt:find("LEAVE") and not sideTxt:find("SKIP") then
                        if triggerGuiButton(sideJoin) then clickedCount = clickedCount + 1 end
                    end
                end
            end
        end)
    end

    if pg and clickedCount == 0 then
        pcall(function()
            for _, btn in ipairs(pg:GetDescendants()) do
                if isKyubiJoinButton(btn) and triggerGuiButton(btn) then
                    clickedCount = clickedCount + 1
                end
            end
        end)
    end

    -- Đợi 0.35s để Server dịch chuyển nhân vật vào Đấu Trường Boss sau khi bấm JOIN
    task.wait(0.35)
    local inArenaAfterClick = isInsideKyubiArena()
    local _, _, hasLiveAfterClick = getKyubiBossTarget()
    if inArenaAfterClick or hasLiveAfterClick or isPlayerNearArenaExitPortal(220) then
        return true
    end

    -- 4. Cách 2 (Dự phòng khi không có nút JOIN hoặc sau 1.8s bấm JOIN chưa vào):
    -- Chỉ bước qua cổng vật lý "KYUBI BOSS FIGHT" tại Hub nếu thực sự tìm thấy cổng trên Map và chưa vào trong sàn Boss
    local elapsedSinceJoinStart = (joinAttemptTime > 0) and (os.clock() - joinAttemptTime) or 99
    if (clickedCount == 0 or elapsedSinceJoinStart >= 1.8) and (os.clock() - lastLobbyPortalStepTime) >= 1.2 then
        pcall(function()
            local portalPos, portalParts, nextFightText, hasRealPortal = findLobbyBossEntryPortal()
            if not hasRealPortal or not portalPos then return end

            local nfMin, nfSec = nextFightText:match("NEXT%s*FIGHT%s*(%d+)%s*:%s*(%d+)")
            local nfTotal = (nfMin and nfSec) and (tonumber(nfMin) * 60 + tonumber(nfSec)) or 0
            local bossIsOnMap = (rawStatus == "active") or hasJoinBtn or (rawStatus == "waiting" and rawSecs <= 15) or (nfTotal > 0 and nfTotal <= 15)

            if bossIsOnMap and not isInsideKyubiArena() and not isPlayerNearArenaExitPortal(220) then
                lastLobbyPortalStepTime = os.clock()
                restorePlayerMovementControls()
                local char = localPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if root then
                    joinStepCounter = (joinStepCounter % 3) + 1
                    local sweepZ = (joinStepCounter - 2) * 2.0
                    local stepPos = portalPos + Vector3.new(0, 0.5, sweepZ)
                    root.Anchored = false
                    root.CFrame = CFrame.new(stepPos)
                    root.Velocity = Vector3.zero
                    if hum then
                        hum:MoveTo(portalPos + Vector3.new(0, 0, -sweepZ))
                    end
                    if firetouchinterest then
                        for _, pp in ipairs(portalParts or {}) do
                            pcall(firetouchinterest, root, pp, 0)
                            pcall(firetouchinterest, root, pp, 1)
                        end
                    end
                    clickedCount = clickedCount + 1
                end
            end
        end)
    end

    return clickedCount > 0
end

getKyubiTimerStatus = function()
    local inFight, _, _, hasBossPct = isInsideKyubiArena()
    local bestStatus, bestSecondsLeft, hasJoinButton = readRawKyubiBarTimer()
    if inFight and (hasBossPct or bestStatus ~= "waiting") then
        _G.AnimeEyes_KyubiActiveOnScreen = true
        return "active", 0, true, nil, nil, nil, false
    end
    if bestStatus == "waiting" and bestSecondsLeft > 15 then
        hasJoinButton = false
        _G.AnimeEyes_KyubiActiveOnScreen = false
    elseif (bestSecondsLeft <= 15 and bestStatus == "waiting") or bestStatus == "active" or hasJoinButton then
        _G.AnimeEyes_KyubiActiveOnScreen = true
    elseif bestSecondsLeft > 60 then
        _G.AnimeEyes_KyubiActiveOnScreen = false
    end
    return bestStatus, bestSecondsLeft, inFight, nil, nil, nil, hasJoinButton
end

-- HÀM KẾT THÚC BOSS: Đứng giữa sàn hút hết quà -> Đi thẳng vào Cổng Vàng "EXIT / BACK TO LOBBY" để Server tự tele về World
executeBossVictoryExit = function(reason)
    bossHunterState = "REWARDING"
    safeLog(string.format("[Kyubi Boss] Kết thúc Boss (%s) -> Hút quà & đi vào cổng EXIT / BACK TO LOBBY...", tostring(reason)))
    if LabelWorldBossPhase then updateLabel(LabelWorldBossPhase, "Tiến trình: Boss đã chết! Đang chờ hút quà & đi vào cổng EXIT...") end
    safeLog("[Kyubi Boss] Đã hạ gục Boss! Đang đi vào cổng EXIT để về World...")

    if _G.AnimeEyes_WebhookEnabled and _G.AnimeEyes_WebhookBoss and sendDiscordWebhook then
        task.spawn(function()
            local bName = tostring(currentBossName or "World Boss"):upper()
            sendDiscordWebhook(
                "⚔️ ĐÃ ĐÁNH BẠI WORLD BOSS!",
                string.format("**%s** (@%s) vừa tiêu diệt thành công World Boss **%s**!", localPlayer.DisplayName or localPlayer.Name, localPlayer.Name, bName),
                15105570, -- Orange Vermilion
                {
                    { name = "Boss Thế Giới", value = "**" .. bName .. "**", inline = true },
                    { name = "Trạng Thái", value = "🏆 Tiêu diệt & Thu thập toàn bộ phần thưởng", inline = true },
                    { name = "Thời Gian", value = os.date("%H:%M:%S - %d/%m/%Y"), inline = true }
                },
                false
            )
        end)
    end

    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    -- Bước 1: Hạ xuống mặt sàn ngay tâm Đấu Trường (0.8s) để quà Boss tự động hút hết vào người (không bị rơi ra ngoài tường)
    local safeCenter = arenaCenterPos or lastValidBossPos
    for _ = 1, 4 do
        pcall(function()
            if bossDropRemote then bossDropRemote:FireServer() end
            char = localPlayer.Character
            root = char and char:FindFirstChild("HumanoidRootPart")
            if root and safeCenter then
                local collectY = (safeCenter.Y >= -15 and safeCenter.Y <= 40) and (safeCenter.Y + 3.0) or root.Position.Y
                root.CFrame = CFrame.new(Vector3.new(safeCenter.X, collectY, safeCenter.Z))
                root.Velocity = Vector3.zero
            end
        end)
        task.wait(0.2)
    end

    -- Bước 2: Gỡ khóa bay (HoverVelocity) để nhân vật đi bộ/chạm vật lý trực tiếp vào Cổng Vàng "EXIT / BACK TO LOBBY"
    restorePlayerMovementControls()
    local returnWorld = _G.AnimeEyes_WorldBeforeBoss or _G.AnimeEyes_SelectedWorld or 1

    if LabelWorldBossPhase then
        updateLabel(LabelWorldBossPhase, "Tiến trình: Đang đi vào cánh cổng EXIT / BACK TO LOBBY...")
    end

    for step = 1, 14 do
        local vortexPart, portalFloorPos, touchParts, signPos = findArenaExitPortal(260)
        local stillInGui, _, stillHasLeave = isInsideKyubiArena()

        -- Nếu không còn thấy cổng EXIT quanh 260 studs và đã thoát GUI Boss -> Server đã tele nhân vật về World thành công!
        if not vortexPart and not stillInGui and not stillHasLeave then
            safeLog("[Kyubi Boss] Cổng EXIT đã dịch chuyển nhân vật về World thành công!")
            break
        end

        pcall(function()
            char = localPlayer.Character
            root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if root and portalFloorPos then
                local sweepZ = ((step % 3) - 1) * 1.5
                local basePos = (step % 2 == 0 and vortexPart) and vortexPart.Position or portalFloorPos
                local targetPortalPos = basePos + Vector3.new(0, 0.5, sweepZ)
                root.Anchored = false
                root.CFrame = CFrame.new(targetPortalPos)
                root.Velocity = Vector3.zero
                if hum then
                    hum:MoveTo(portalFloorPos + Vector3.new(0, 0, -sweepZ))
                end

                if firetouchinterest then
                    if vortexPart then
                        pcall(firetouchinterest, root, vortexPart, 0)
                        pcall(firetouchinterest, root, vortexPart, 1)
                    end
                    for _, tp in ipairs(touchParts or {}) do
                        pcall(firetouchinterest, root, tp, 0)
                        pcall(firetouchinterest, root, tp, 1)
                    end
                end
            end

            local leaveBtn = findBossLeaveButton()
            if leaveBtn then triggerGuiButton(leaveBtn) end
        end)

        task.wait(0.22)
    end

    task.wait(0.35)
    restorePlayerMovementControls()

    -- Bước 3: Kiểm tra sau khi đi qua cổng EXIT. Nếu cổng đã đưa về đúng World thì giữ nguyên, chỉ tele nếu lệch World hoặc kẹt
    local stillNearExit = isPlayerNearArenaExitPortal(220)
    local currentPhysicalW = detectPhysicalWorld()
    if stillNearExit or currentPhysicalW ~= returnWorld then
        if teleportToWorld then
            pcall(teleportToWorld, returnWorld)
        end
    end

    restorePlayerMovementControls()
    hadLiveBossInFight, bossMissingSince, lastValidBossPos, arenaCenterPos = false, 0, nil, nil
    bossHunterState, _G.AnimeEyes_InBossFight, _G.AnimeEyes_KyubiActiveOnScreen = "IDLE", false, false

    if LabelWorldBossPhase then
        local msg = _G.Helm_AutoStage and string.format("Tiến trình: Đã qua cổng EXIT về World %d -> Tiếp tục đi Stage", returnWorld)
            or string.format("Tiến trình: Hoàn tất săn Boss! Đã qua cổng EXIT về World %d", returnWorld)
        updateLabel(LabelWorldBossPhase, msg)
    end
    safeLog(string.format("[Kyubi Boss] Đã đi qua cổng EXIT và trở về World %d!", returnWorld))
    task.wait(0.8)
end

dumpKyubiBossNow = function()
    local lines = {}
    local function dlog(fmt, ...) table.insert(lines, string.format("[%s] " .. fmt, os.date("%H:%M:%S"), ...)) end
    local inFight, pct, hasLeave, hasBossPct = isInsideKyubiArena()
    local vp, pFloor, tParts, sPos = findArenaExitPortal(300)
    local lobbyPos, lobbyParts, lobbyTxt = findLobbyBossEntryPortal()
    dlog("HelmHub BOSS DUMP | PlaceId: %s | inFight: %s | HP: %s%% | hasLeave: %s | hasBossPct: %s | state: %s",
        tostring(game.PlaceId), tostring(inFight), tostring(pct), tostring(hasLeave), tostring(hasBossPct), tostring(bossHunterState))
    dlog("ExitPortal: part=%s | floorPos=%s | signPos=%s | touchParts=%d",
        tostring(vp and vp:GetFullName() or "nil"), tostring(pFloor), tostring(sPos), tParts and #tParts or 0)
    dlog("LobbyEntryPortal: pos=%s | parts=%d | text='%s'",
        tostring(lobbyPos), lobbyParts and #lobbyParts or 0, tostring(lobbyTxt))

    local pg = localPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, desc in ipairs(pg:GetDescendants()) do
            local n = desc.Name:lower()
            local txt = (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text or ""
            local tu = txt:upper()
            if n:find("kyubi") or n:find("boss") or n:find("kurama") or tu:find("KYUBI") or tu:find("JOIN") or tu:find("LEAVE") then
                dlog(" * %s [%s] | Vis: %s | Text: '%s'", desc:GetFullName(), desc.ClassName, tostring(desc:IsA("GuiObject") and desc.Visible), txt)
            end
        end
    end
    local bPos, bName, hasLive = getKyubiBossTarget()
    dlog("Target Boss: %s | Name: %s | hasLive: %s", tostring(bPos), tostring(bName), tostring(hasLive))
    local fullTxt = table.concat(lines, "\n")
    if writefile then pcall(function() writefile("!HelmHub/Anime Eyes/boss_dump.txt", fullTxt); writefile("boss_dump.txt", fullTxt) end) end
    if setclipboard then pcall(setclipboard, fullTxt) end
    Notification("Boss Dump", string.format("Đã lưu thông tin Boss vào boss_dump.txt (%d dòng)!", #lines), 4)
end

task.spawn(function()
    while isSessionActive() do
        pcall(function()
            -- Khóa cứng biến cũ = false để vô hiệu hóa 100% mọi vòng lặp cũ từ lần chạy trước
            _G.AnimeEyes_AutoBoss = false
            _G.AnimeEyes_AutoStage = false

            local currentBossKind = workspace:GetAttribute("BossKind")
            local currentBossName = (currentBossKind == "menos") and "Menoz" or "Kyubi"

            -- Xử lý Tự Động Vote Boss khi Server mở cổng Vote
            if workspace:GetAttribute("BossVoteOpen") == true and _G.AnimeEyes_AutoVoteBoss and bossRemote then
                pcall(function()
                    local voteTarget = (_G.AnimeEyes_SelectedBossVote == "kyubi") and "kyubi" or "menos"
                    bossRemote:FireServer("vote", voteTarget)
                end)
            end

            if not _G.Helm_AutoBoss then
                if bossHunterState ~= "IDLE" or _G.AnimeEyes_InBossFight then restorePlayerMovementControls() end
                bossHunterState, _G.AnimeEyes_InBossFight, hadLiveBossInFight, bossMissingSince, notInFightSince = "IDLE", false, false, 0, 0
                if LabelWorldBossStatus then updateLabel(LabelWorldBossStatus, string.format("Boss Thế Giới (%s): Đang TẮT tự động săn", currentBossName)) end
                if LabelWorldBossPhase then updateLabel(LabelWorldBossPhase, "Tiến trình: Đã tắt") end
                task.wait(0.6)
                return
            end

            local inFight, bossHpPercent, hasLeaveBtn, hasBossPercent, isPortalHome = isInsideKyubiArena()
            local nearExitPortal = isPlayerNearArenaExitPortal(220)
            local rawBarStatus, rawBarSecondsLeft, rawHasJoinBtn = readRawKyubiBarTimer()
            local bossPos, bossId, hasLiveBoss = getKyubiBossTarget()

            -- Nếu bị Boss đánh hạ (KNOCKED OUT! - Ảnh 3): Bấm nút Đỏ "No" về Lobby rồi lập tức JOIN lại trận!
            if checkAndHandleKnockedOut() then
                bossHunterState, joinAttemptTime, notInFightSince = "JOINING", os.clock(), 0
                _G.AnimeEyes_InBossFight, _G.AnimeEyes_KyubiActiveOnScreen = true, true
                if LabelWorldBossPhase then updateLabel(LabelWorldBossPhase, string.format("Tiến trình: Bị %s hạ gục (KNOCKED OUT) -> Bấm No & đang vào lại Boss...", currentBossName)) end
                task.wait(0.5)
                findAndClickJoinBoss()
                return
            end

            -- Nếu vẫn đang đứng gần Boss sống (<= 160 studs) hoặc cạnh cổng EXIT và chưa hết trận thì luôn coi là đang trong trận
            local charNow = localPlayer.Character
            local rootNow = charNow and charNow:FindFirstChild("HumanoidRootPart")
            local nearLiveBoss = (hasLiveBoss and bossPos and rootNow and (rootNow.Position - bossPos).Magnitude <= 160) or false
            if (nearExitPortal or nearLiveBoss) and hasLiveBoss and not isPortalHome and rawBarStatus ~= "portal_home" then
                inFight = true
            end

            -- CHỈ kiểm tra Boss chết (bossDefeated) khi nhân vật ĐANG ở trong trận Boss hoặc cạnh cổng EXIT
            local bossDefeated, defeatReason = false, ""
            if inFight or bossHunterState == "FIGHTING" or nearExitPortal then
                if isPortalHome or rawBarStatus == "portal_home" then
                    bossDefeated, defeatReason = true, "Thanh trạng thái hiện PORTAL HOME (Boss 0% HP)"
                elseif hasBossPercent and bossHpPercent <= 0 then
                    bossDefeated, defeatReason = true, "Máu Boss về 0%"
                elseif rawBarStatus == "waiting" and rawBarSecondsLeft > 15 then
                    bossDefeated, defeatReason = true, string.format("%s đã xong -> Đi vào cổng EXIT", currentBossName)
                elseif (inFight or bossHunterState == "FIGHTING") and hadLiveBossInFight and not hasLiveBoss then
                    if bossMissingSince == 0 then bossMissingSince = os.clock()
                    elseif (os.clock() - bossMissingSince) >= 0.8 then bossDefeated, defeatReason = true, string.format("Model %s đã biến mất -> Đi vào cổng EXIT", currentBossName) end
                end
            end

            if bossDefeated then
                executeBossVictoryExit(defeatReason)
                return
            end

            if inFight then
                bossHunterState, _G.AnimeEyes_InBossFight, notInFightSince = "FIGHTING", true, 0
                local char = localPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not root or not hum or hum.Health <= 0 then task.wait(0.3); return end

                if hasLiveBoss then hadLiveBossInFight, bossMissingSince = true, 0 end
                if LabelWorldBossStatus then updateLabel(LabelWorldBossStatus, string.format("Boss (%s): ĐANG GIAO TRANH! (Máu: %d%%)", currentBossName, bossHpPercent)) end

                if not bossPos then
                    if LabelWorldBossPhase then updateLabel(LabelWorldBossPhase, "Tiến trình: Đang kiểm tra trạng thái Boss...") end
                    root.Velocity = Vector3.zero
                    task.wait(0.1)
                    return
                end

                local bv = root:FindFirstChild("Helm_HoverVelocity")
                if not bv then
                    bv = Instance.new("BodyVelocity")
                    bv.Name = "Helm_HoverVelocity"
                    bv.MaxForce = Vector3.new(1e7, 1e7, 1e7)
                    bv.Velocity = Vector3.zero
                    bv.Parent = root
                end

                local hoverH = tonumber(_G.AnimeEyes_BossHoverHeight) or 26
                local targetBaseY = (bossPos.Y >= -10 and bossPos.Y <= 25) and bossPos.Y or (FLOOR_Y + 1.0)
                local rawTarget = Vector3.new(bossPos.X, targetBaseY + hoverH, bossPos.Z + 4)
                local targetPos3D = clampInsideBossArena(rawTarget, bossPos)
                if LabelWorldBossPhase then
                    updateLabel(LabelWorldBossPhase, string.format("Tiến trình: Đang bay trên đầu %s xả chiêu (Tối đa DPS)...", currentBossName))
                end

                root.CFrame = CFrame.new(targetPos3D, Vector3.new(bossPos.X, targetBaseY + 4, bossPos.Z))
                root.Velocity = Vector3.zero
                if bv then bv.Velocity = Vector3.zero end

                pcall(function()
                        if cooldownTable and _G.AnimeEyes_BypassCooldown then
                            cooldownTable.attack, cooldownTable.E, cooldownTable.R = 0, 0, 0
                        end
                        if InputModule and InputModule.autoClick then InputModule.autoClick()
                        elseif trainRemote then trainRemote:FireServer() end
                        if InputModule and InputModule.press then InputModule.press("E"); InputModule.press("R") end
                        if castRemote then
                            castRemote:FireServer("attack", bossPos, bossId)
                            castRemote:FireServer("E", bossPos, bossId)
                            castRemote:FireServer("R", bossPos, bossId)
                        end
                        if bossDropRemote then bossDropRemote:FireServer() end
                    end)

                local cps = tonumber(_G.AnimeEyes_StageCPS) or 25
                task.wait(math.clamp(1 / cps, 0.02, 0.05))
                return
            end

            if bossHunterState == "FIGHTING" and not inFight then
                -- Chống nhiễu GUI 1-2 nhịp khi Boss chuyển trạng thái ENRAGED!: Phải thực sự rời sàn > 1.5s mới bấm JOIN lại
                if notInFightSince == 0 then
                    notInFightSince = os.clock()
                end
                if (os.clock() - notInFightSince) < 1.5 then
                    task.wait(0.2)
                    return
                end
                notInFightSince = 0
                bossHunterState, joinAttemptTime = "JOINING", os.clock()
                _G.AnimeEyes_InBossFight, _G.AnimeEyes_KyubiActiveOnScreen = true, true
                if LabelWorldBossPhase then updateLabel(LabelWorldBossPhase, "Tiến trình: Nhân vật đã hồi sinh -> Đang bấm JOIN vào lại Boss...") end
                safeLog("[Kyubi Boss] Nhân vật đã hồi sinh! Đang vào lại khu vực Boss...")
                findAndClickJoinBoss()
                task.wait(0.6)
                return
            end

            if bossHunterState == "JOINING" then
                -- Nếu trong lúc đang chờ Join mà thanh báo chuyển sang chờ hồi lâu (> 15s) thì dừng Join ngay
                if rawBarStatus == "waiting" and rawBarSecondsLeft > 15 and not rawHasJoinBtn then
                    bossHunterState, _G.AnimeEyes_InBossFight, _G.AnimeEyes_KyubiActiveOnScreen = "IDLE", false, false
                    restorePlayerMovementControls()
                    return
                end
                _G.AnimeEyes_InBossFight, _G.AnimeEyes_KyubiActiveOnScreen = true, true
                local elapsed = os.clock() - joinAttemptTime
                if elapsed > 45 then
                    bossHunterState, _G.AnimeEyes_InBossFight, _G.AnimeEyes_KyubiActiveOnScreen = "IDLE", false, false
                    if LabelWorldBossPhase then updateLabel(LabelWorldBossPhase, "Tiến trình: Hết thời gian chờ Join -> Tiếp tục Farm") end
                    return
                end
                if LabelWorldBossStatus then updateLabel(LabelWorldBossStatus, string.format("Boss (%s): ĐÃ XUẤT HIỆN! (Đang vào khu vực Boss)", currentBossName)) end
                if LabelWorldBossPhase then updateLabel(LabelWorldBossPhase, string.format("Tiến trình: Đang bấm JOIN & đi qua cổng %s tại Hub (%ds / 45s)...", currentBossName, math.floor(elapsed))) end
                findAndClickJoinBoss()
                task.wait(0.45)
                return
            end

            bossHunterState, _G.AnimeEyes_InBossFight = "IDLE", false
            restorePlayerMovementControls()

            local charRescue = localPlayer.Character
            local rootRescue = charRescue and charRescue:FindFirstChild("HumanoidRootPart")
            if rootRescue and not inFight and not nearExitPortal and rootRescue.Position.Y < -35 then
                local targetWorld, worldOrigin = getFarmWorld()
                local groundY = (targetWorld == 3) and 18.5 or (FLOOR_Y + 1.0)
                rootRescue.CFrame = CFrame.new(worldOrigin + Vector3.new(0, groundY, 46))
                rootRescue.Velocity = Vector3.zero
            end

            local status, secondsLeft, _, _, _, _, hasJoinButton = getKyubiTimerStatus()
            local isCooldown = (status == "waiting" and secondsLeft > 15 and not hasJoinButton)
            if isCooldown then
                bossHunterState, _G.AnimeEyes_InBossFight, _G.AnimeEyes_KyubiActiveOnScreen, hasJoinButton = "IDLE", false, false, false
            end

            if LabelWorldBossStatus then
                if isCooldown and secondsLeft < 9999 then
                    updateLabel(LabelWorldBossStatus, string.format("Boss (%s): Xuất hiện sau %02d:%02d", currentBossName, math.floor(secondsLeft / 60), secondsLeft % 60))
                elseif hasJoinButton or status == "active" or (status == "waiting" and secondsLeft <= 15) then
                    updateLabel(LabelWorldBossStatus, string.format("Boss (%s): Sẵn sàng tham chiến! (Đang vào cổng Boss)", currentBossName))
                else
                    updateLabel(LabelWorldBossStatus, string.format("Boss (%s): Đang theo dõi...", currentBossName))
                end
            end

            if LabelWorldBossPhase and bossHunterState == "IDLE" then
                if _G.Helm_AutoStage then
                    updateLabel(LabelWorldBossPhase, (isCooldown and secondsLeft < 9999)
                        and string.format("Tiến trình: Đang nhường quyền Auto Stage (Boss hồi: %02d:%02d)", math.floor(secondsLeft / 60), secondsLeft % 60)
                        or "Tiến trình: Đang nhường quyền cho Auto Stage")
                else
                    updateLabel(LabelWorldBossPhase, (isCooldown and secondsLeft < 9999)
                        and string.format("Tiến trình: Boss đang hồi (%02d:%02d) - Nghỉ tại Hub", math.floor(secondsLeft / 60), secondsLeft % 60)
                        or "Tiến trình: Đang chờ sự kiện Boss")
                end
            end

            if not isCooldown and (hasJoinButton or (status == "waiting" and secondsLeft <= 15) or status == "active") then
                _G.AnimeEyes_WorldBeforeBoss = detectPhysicalWorld() or _G.AnimeEyes_SelectedWorld or 1
                bossHunterState, joinAttemptTime = "JOINING", os.clock()
                _G.AnimeEyes_InBossFight, _G.AnimeEyes_KyubiActiveOnScreen = true, true
                if LabelWorldBossPhase then updateLabel(LabelWorldBossPhase, "Tiến trình: [Ưu Tiên Số 1] Tạm dừng Stage -> Đang qua cổng Boss...") end
                safeLog(string.format("[Kyubi Boss] %s đã xuất hiện! Đang bấm JOIN & qua cổng Boss...", currentBossName))
                findAndClickJoinBoss()
                task.wait(0.45)
            end
        end)
        task.wait(0.45)
    end
end)

end

-- ========================================================================
-- 10. LOGIC FARM CHAKRA, TRÙNG SINH & MỞ TRỨNG CÚP (TAB 2 & TAB 3 ENGINE)
-- ========================================================================
local isNativeClickRunning = false
startNativeClickLoop = function()
    if isNativeClickRunning then return end
    isNativeClickRunning = true
    task.spawn(function()
        while _G.AnimeEyes_AutoClick do
            if _G.AnimeEyes_BypassCooldown and cooldownTable then cooldownTable.attack = 0 end
            pcall(function()
                if InputModule and InputModule.autoClick then InputModule.autoClick()
                elseif trainRemote then trainRemote:FireServer() end
            end)
            task.wait(math.clamp(1 / (tonumber(_G.AnimeEyes_TargetCPS) or 25), 0.02, 0.2))
        end
        isNativeClickRunning = false
    end)
end

task.spawn(function()
    while isSessionActive() do
        if _G.AnimeEyes_AutoSkills and InputModule and InputModule.press then
            pcall(function()
                if _G.AnimeEyes_BypassCooldown and cooldownTable then cooldownTable.E, cooldownTable.R = 0, 0 end
                InputModule.press("E"); task.wait(0.1); InputModule.press("R")
            end)
        end
        task.wait(1.0)
    end
end)

task.spawn(function()
    while isSessionActive() do
        if _G.AnimeEyes_KeepFreeOn and AutoClickModule then
            pcall(function()
                if AutoClickModule.freeOn and not AutoClickModule.freeOn() and AutoClickModule.toggleFree then
                    AutoClickModule.toggleFree()
                end
            end)
        end
        task.wait(3.0)
    end
end)

triggerRebirthOnce = function()
    pcall(function()
        if rebirthRemote then
            if rebirthRemote:IsA("RemoteFunction") then rebirthRemote:InvokeServer() else rebirthRemote:FireServer() end
        end
    end)
end

task.spawn(function()
    while isSessionActive() do
        if _G.AnimeEyes_AutoRebirth then triggerRebirthOnce() end
        task.wait(tonumber(_G.AnimeEyes_RebirthDelay) or 1.5)
    end
end)

-- ========================================================================
-- MODULE TỰ ĐỘNG ĐỨNG BỆ TRÙNG SINH TỐI ƯU (AUTO FARM CHAKRA TRAINING PADS)
-- HỆ THỐNG PHÂN CẤP 3 TẦNG: [Ưu tiên 1: Boss] > [Ưu tiên 2: Stage] > [Ưu tiên 3: Farm Bệ Trùng Sinh]
-- BỎ QUA 100% CÁC BỆ MUA BẰNG ROBUX (pass ~= nil)
-- ========================================================================
local PlotsConfig = nil
pcall(function()
    PlotsConfig = require(ReplicatedStorage.Shared.Config.Plots)
end)

local EconomyLogic = nil
pcall(function()
    EconomyLogic = require(ReplicatedStorage.Shared.Logic.Economy)
end)

local DEFAULT_TRAINING_OFFSETS = {
    Vector3.new(-62, 0, 38),   -- Bệ 1 (Training Dummy)
    Vector3.new(-90, 0, 38),   -- Bệ 2 (Boxing Ring)
    Vector3.new(-118, 0, 38),  -- Bệ 3 (Golden Dojo - Robux train1)
    Vector3.new(-146, 0, 38),  -- Bệ 4 (Waterfall)
    Vector3.new(-62, 0, 66),   -- Bệ 5 (Fire Forge)
    Vector3.new(-90, 0, 66),   -- Bệ 6 (Thunder Dome - Robux train2)
    Vector3.new(-118, 0, 66),  -- Bệ 7 (Sage Temple)
    Vector3.new(-146, 0, 66),  -- Bệ 8 (Storm Tower)
    Vector3.new(-62, 0, 94),   -- Bệ 9 (Dragon Sanctum - Robux train3)
    Vector3.new(-90, 0, 94),   -- Bệ 10 (Gravity Chamber)
    Vector3.new(-118, 0, 94),  -- Bệ 11 (Blood Moon Shrine)
    Vector3.new(-146, 0, 94),  -- Bệ 12 (Sixth Path Throne - Robux train4)
    Vector3.new(-62, 0, 122)   -- Bệ 13 (Void Altar)
}

local KNOWN_ROBUX_PAD_INDICES = {
    [3] = true,
    [6] = true,
    [9] = true,
    [12] = true
}

local function formatCount(n)
    return formatNumber(n)
end

local function getPlayerRebirths()
    local rb = nil
    pcall(function()
        rb = localPlayer:GetAttribute("Rebirths")
    end)
    if rb == nil and localPlayer:FindFirstChild("leaderstats") then
        local st = localPlayer.leaderstats:FindFirstChild("Rebirths") or localPlayer.leaderstats:FindFirstChild("Rebirth")
        if st then rb = st.Value end
    end
    if rb == nil and StateModule and StateModule.number then
        pcall(function()
            rb = StateModule.number("Rebirths")
        end)
    end
    return tonumber(rb) or 0
end

local function isStagePriorityActive()
    if _G.Helm_AutoStage then
        return true
    end
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and getStageAtZ and getStageAtZ(root.Position.Z) > 0 then
        return true
    end
    return false
end

local function getHubFolder(targetWorld)
    local worldNames = {
        "Map" .. (targetWorld == 1 and "" or tostring(targetWorld)),
        "Map" .. targetWorld,
        "World" .. targetWorld,
        "World_" .. targetWorld,
        "Map"
    }
    for _, mapName in ipairs(worldNames) do
        local m = workspace:FindFirstChild(mapName)
        if m then
            local hub = m:FindFirstChild("Hub")
            if hub then return hub, m end
        end
    end
    for _, obj in ipairs(workspace:GetChildren()) do
        if (obj.Name:find("Map") or obj.Name:find("World")) and obj:FindFirstChild("Hub") then
            return obj.Hub, obj
        end
    end
    return nil, nil
end

local function getBestEligibleTrainingPad()
    local targetWorld, worldOrigin = getFarmWorld(true)
    worldOrigin = worldOrigin or (WORLD_ORIGINS and WORLD_ORIGINS[targetWorld or 1]) or Vector3.zero
    local hub = getHubFolder(targetWorld)
    local curRebirths = getPlayerRebirths()
    local groundY = (targetWorld == 3) and 18.5 or (FLOOR_Y + 1.2)

    local worldPadsConfig = nil
    if PlotsConfig and PlotsConfig.forWorld then
        pcall(function()
            worldPadsConfig = PlotsConfig.forWorld(targetWorld)
        end)
    end

    local candidates = {}

    for i = 1, 13 do
        local padName = "Training" .. i
        local padModel = hub and hub:FindFirstChild(padName)
        local cfg = worldPadsConfig and worldPadsConfig[i]

        -- 1. Lọc bỏ 100% các bệ mua bằng Robux
        local isRobux = false
        if cfg and cfg.pass ~= nil then
            isRobux = true
        end
        if KNOWN_ROBUX_PAD_INDICES[i] then
            isRobux = true
        end

        local signGui = nil
        local displayPart = nil
        if padModel then
            displayPart = padModel:FindFirstChild("Display")
            if displayPart and displayPart:FindFirstChild("Sign") then
                signGui = displayPart.Sign
            elseif padModel:FindFirstChild("Sign", true) then
                signGui = padModel:FindFirstChild("Sign", true)
            end
        end

        if signGui then
            if signGui:FindFirstChild("Price") then
                isRobux = true
            end
            local priceObj = signGui:FindFirstChild("Price")
            if priceObj and priceObj:IsA("TextLabel") then
                local txt = priceObj.Text
                if txt:find("") or txt:find("R%$") or tonumber(txt:match("%d+")) then
                    isRobux = true
                end
            end
        end

        if not isRobux then
            -- 2. Xác định số Trùng Sinh yêu cầu
            local reqRebirths = 0
            if cfg and cfg.rebirths then
                reqRebirths = tonumber(cfg.rebirths) or 0
            end

            -- Đọc trực tiếp từ Sign.Need trong live game (Need là Frame chứa TextLabel Count)
            local needParsed = false
            if signGui then
                local needObj = signGui:FindFirstChild("Need")
                if needObj then
                    local countObj = nil
                    if needObj:IsA("TextLabel") then
                        countObj = needObj
                    else
                        countObj = needObj:FindFirstChild("Count") or needObj:FindFirstChildWhichIsA("TextLabel")
                    end
                    if countObj and countObj.Text and countObj.Text ~= "" then
                        local parsed = parseShortNumber(countObj.Text)
                        if parsed and parsed > 0 then
                            reqRebirths = parsed
                            needParsed = true
                        end
                    end
                end
            end

            -- Nếu chưa có từ Sign, thử tính qua Economy.plotRebirths
            if not needParsed and EconomyLogic and EconomyLogic.plotRebirths and cfg and cfg.rebirths then
                pcall(function()
                    local anchors = nil
                    if StateModule and StateModule.rebirthAnchors then
                        anchors = StateModule.rebirthAnchors()
                    elseif localPlayer:GetAttribute("RebirthAnchors") then
                        anchors = HttpService:JSONDecode(localPlayer:GetAttribute("RebirthAnchors"))
                    end
                    local calculated = EconomyLogic.plotRebirths(cfg.rebirths, anchors)
                    if calculated and calculated > 0 then
                        reqRebirths = calculated
                    end
                end)
            end

            -- Multiplier & Tên
            local mult = (cfg and tonumber(cfg.mult)) or i
            local padTitle = (cfg and cfg.name) or string.format("Bệ %d", i)
            local multText = ""
            if signGui and signGui:FindFirstChild("Mult") then
                local mObj = signGui.Mult
                if mObj:IsA("TextLabel") then
                    multText = mObj.Text
                else
                    local t = mObj:FindFirstChildWhichIsA("TextLabel")
                    if t then multText = t.Text end
                end
            end
            if multText == "" and mult then
                multText = "x" .. formatCount(mult) .. " CHAKRA"
            end

            -- Tọa độ đứng trên bệ chuẩn xác: Đứng vững trên mặt sàn bệ (không bị lơ lửng trên không)
            local padFloorPart = padModel and (
                padModel:FindFirstChild("Pad", true)
                or padModel:FindFirstChild("Floor", true)
                or padModel:FindFirstChild("Base", true)
                or (padModel:FindFirstChild("Props") and padModel.Props:FindFirstChild("Pad"))
                or padModel.PrimaryPart
            )

            local posX, posZ = 0, 0
            local floorY = groundY + 1.2

            if padFloorPart and padFloorPart:IsA("BasePart") then
                posX = padFloorPart.Position.X
                posZ = padFloorPart.Position.Z
                floorY = padFloorPart.Position.Y + (padFloorPart.Size.Y / 2) + 2.5
            elseif displayPart and displayPart:IsA("BasePart") then
                posX = displayPart.Position.X
                posZ = displayPart.Position.Z
                -- Tuyệt đối không dùng Y của Display vì Display treo trên ngọn cột/biển báo
                floorY = groundY + 1.2
            elseif padModel then
                local pivot = padModel:GetPivot()
                posX = pivot.Position.X
                posZ = pivot.Position.Z
                floorY = groundY + 1.2
            else
                local relOffset = DEFAULT_TRAINING_OFFSETS[i] or Vector3.new(-62, 0, 38)
                local worldBase = worldOrigin or Vector3.zero
                posX = worldBase.X + relOffset.X
                posZ = worldBase.Z + relOffset.Z
                floorY = groundY + 1.2
            end

            local standPos = Vector3.new(posX, floorY, posZ)

            -- 3. Chỉ chọn các bệ mà người chơi đã đủ số Trùng Sinh
            if curRebirths >= reqRebirths then
                table.insert(candidates, {
                    index = i,
                    name = padTitle,
                    reqRebirths = reqRebirths,
                    mult = mult,
                    multText = multText,
                    standPos = standPos,
                    model = padModel
                })
            end
        end
    end

    -- Sắp xếp: Ưu tiên bệ có số Rebirth yêu cầu cao nhất (và multiplier cao nhất)
    table.sort(candidates, function(a, b)
        if a.reqRebirths ~= b.reqRebirths then
            return a.reqRebirths > b.reqRebirths
        end
        return (a.mult or a.index) > (b.mult or b.index)
    end)

    return candidates[1], curRebirths
end

-- Vòng lặp tự động di chuyển & Farm Chakra trên Bệ Trùng Sinh Tối Ưu (3-Tier Priority)
task.spawn(function()
    while isSessionActive() do
        local ok, err = pcall(function()
            local shouldTrain = (_G.AnimeEyes_AutoTrainPad == true) or (_G.AnimeEyes_AutoRebirth == true and _G.AnimeEyes_AutoTrainPad ~= false)
            if not shouldTrain then
                if LabelCurrentTrainingPad then
                    updateLabel(LabelCurrentTrainingPad, "Bệ Farm: Đã tắt (Bật công tắc để chạy)")
                end
                task.wait(1.0)
                return
            end

            -- [ƯU TIÊN 1]: WORLD BOSS (Kyubi / Menoz)
            if isBossPriorityActive() then
                if LabelCurrentTrainingPad then
                    updateLabel(LabelCurrentTrainingPad, "Bệ Farm: [Ưu tiên 1] Tạm dừng -> Đang săn Boss!")
                end
                task.wait(0.5)
                return
            end

            -- [ƯU TIÊN 2]: VƯỢT STAGE (Stage Runner)
            if isStagePriorityActive() then
                if LabelCurrentTrainingPad then
                    updateLabel(LabelCurrentTrainingPad, "Bệ Farm: [Ưu tiên 2] Tạm dừng -> Đang vượt Stage!")
                end
                task.wait(0.5)
                return
            end

            -- [ƯU TIÊN 3]: FARM CHAKRA TẠI BỆ TRÙNG SINH TỐI ƯU
            local char = localPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not root or not hum or hum.Health <= 0 then
                task.wait(0.5)
                return
            end

            local bestPad, curRebirths = getBestEligibleTrainingPad()
            if not bestPad or not bestPad.standPos then
                if LabelCurrentTrainingPad then
                    updateLabel(LabelCurrentTrainingPad, string.format("Bệ Farm: Chưa tìm thấy bệ (Rebirth: %s)", formatCount(curRebirths)))
                end
                task.wait(1.0)
                return
            end

            local targetPos = bestPad.standPos
            local rootPos = root.Position
            local horizDist = Vector2.new(rootPos.X - targetPos.X, rootPos.Z - targetPos.Z).Magnitude
            local vertDist = math.abs(rootPos.Y - targetPos.Y)

            -- Chỉ dịch chuyển khi nhân vật thực sự bị rơi hoặc lệch khỏi bệ (bán kính > 3.8 studs hoặc Y chênh > 4.5)
            if horizDist > 3.8 or vertDist > 4.5 then
                restorePlayerMovementControls()
                root.CFrame = CFrame.new(targetPos)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end)
                task.wait(0.12)
            else
                -- ĐÃ Ở TRÊN BỆ: ĐỨNG IM 100% TUYỆT ĐỐI (Không đè CFrame liên tục để chống hiện tượng giật nảy)
                hum.Jump = false
                if root.AssemblyLinearVelocity.Magnitude > 1.2 then
                    root.AssemblyLinearVelocity = Vector3.zero
                end
            end

            -- Tích lũy Chakra trên bệ: Dùng trainRemote native siêu mượt, không spam chiêu tấn công gây giật nhảy
            if trainRemote then
                trainRemote:FireServer()
            end

            -- Cập nhật HUD Label
            if LabelCurrentTrainingPad then
                updateLabel(LabelCurrentTrainingPad, string.format("Bệ: %s | %s (Cần: %s RB)",
                    bestPad.name,
                    bestPad.multText ~= "" and bestPad.multText or ("x" .. tostring(bestPad.mult)),
                    formatCount(bestPad.reqRebirths)
                ))
            end
        end)

        if not ok then
            safeLog("[TrainingPad Error]:", tostring(err))
            task.wait(0.5)
        else
            local cps = tonumber(_G.AnimeEyes_TargetCPS) or 20
            task.wait(math.clamp(1 / cps, 0.03, 0.1))
        end
    end
end)

do
local function isEggGuiVisible(obj)
    if not obj or not obj:IsA("GuiObject") then return false end
    if obj.AbsoluteSize.X <= 4 or obj.AbsoluteSize.Y <= 4 then return false end
    local curr = obj
    while curr do
        if curr:IsA("GuiObject") and not curr.Visible then return false end
        if curr:IsA("LayerCollector") then
            if not curr.Enabled then return false end
            break
        end
        curr = curr.Parent
    end
    return true
end

local function clickEggPopupHatchButton(preferredCount)
    local clickedAny = false
    pcall(function()
        local pg = localPlayer:FindFirstChild("PlayerGui")
        if not pg then return end

        local wantX3 = (tonumber(preferredCount) or 3) >= 3
        local x3Buttons = {}
        local x1Buttons = {}
        local seenContainers = {}

        for _, desc in ipairs(pg:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and isEggGuiVisible(desc) then
                local rawTxt = tostring(desc.Text or ""):upper():gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
                if #rawTxt > 0 and not rawTxt:find("DELETE") and not rawTxt:find("ROBUX") and not rawTxt:find("") then
                    local isX3 = (rawTxt == "HATCH X3" or rawTxt:find("HATCH%s*X%s*3") ~= nil)
                    local isX1 = (rawTxt == "HATCH X1" or rawTxt:find("HATCH%s*X%s*1") ~= nil)
                    if isX3 or isX1 then
                        local btnContainer = nil
                        if desc:IsA("GuiButton") then
                            btnContainer = desc
                        elseif desc.Parent and desc.Parent:IsA("GuiButton") then
                            btnContainer = desc.Parent
                        elseif desc.Parent and desc.Parent.Parent and desc.Parent.Parent:IsA("GuiButton") then
                            btnContainer = desc.Parent.Parent
                        elseif desc.Parent then
                            btnContainer = desc.Parent:FindFirstChildWhichIsA("GuiButton") or desc.Parent
                        else
                            btnContainer = desc
                        end

                        if btnContainer and not seenContainers[btnContainer] then
                            seenContainers[btnContainer] = true
                            if isX3 then
                                table.insert(x3Buttons, btnContainer)
                            else
                                table.insert(x1Buttons, btnContainer)
                            end
                        end
                    end
                end
            end
        end

        local targetList = wantX3 and (#x3Buttons > 0 and x3Buttons or x1Buttons) or (#x1Buttons > 0 and x1Buttons or x3Buttons)
        for _, btn in ipairs(targetList) do
            if triggerGuiButton(btn) then
                clickedAny = true
            end
        end
    end)
    return clickedAny
end

local lastEquipBestTick = 0
task.spawn(function()
    while isSessionActive() do
        if _G.AnimeEyes_AutoHatch and not (_G.Helm_AutoBoss and _G.AnimeEyes_InBossFight) then
            pcall(function()
                local char = localPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not root or not hum or hum.Health <= 0 then task.wait(0.5); return end

                local targetWorld, worldOrigin = getFarmWorld()
                local eggData = getSelectedCupEggData and getSelectedCupEggData(targetWorld)
                if not eggData then return end

                local count = tonumber(_G.Helm_HatchAmount) or tonumber(_G.AnimeEyes_HatchAmount) or 3
                local standPos = worldOrigin + eggData.offset + Vector3.new(0, 1.2, 0)
                if (root.Position - standPos).Magnitude > 5.5 then
                    root.CFrame = CFrame.new(standPos)
                    root.Velocity = Vector3.zero
                    task.wait(0.25)
                end

                -- 1. Ưu tiên bấm trực tiếp nút HATCH x3 (hoặc HATCH x1) trên bảng trứng đang mở (Void Egg, v.v.)
                local clickedPopup = clickEggPopupHatchButton(count)

                -- 2. Gửi kèm Remote dự phòng không chặn luồng nếu bảng trứng chưa kịp hiện
                if not clickedPopup and petActionRemote then
                    task.spawn(function()
                        pcall(function()
                            if petActionRemote:IsA("RemoteFunction") then
                                petActionRemote:InvokeServer("hatch", eggData.id or eggData.name, count)
                                petActionRemote:InvokeServer("Hatch", eggData.name, count)
                            else
                                petActionRemote:FireServer("hatch", eggData.id or eggData.name, count)
                                petActionRemote:FireServer("Hatch", eggData.name, count)
                            end
                        end)
                    end)
                end

                -- 3. Tự động trang bị Pet mạnh nhất (mỗi 2.5s để không làm nghẽn tốc độ bấm HATCH x3)
                if _G.AnimeEyes_AutoEquipBestPet and petActionRemote and (os.clock() - lastEquipBestTick >= 2.5) then
                    lastEquipBestTick = os.clock()
                    task.spawn(function()
                        pcall(function()
                            if petActionRemote:IsA("RemoteFunction") then petActionRemote:InvokeServer("EquipBest")
                            else petActionRemote:FireServer("EquipBest") end
                        end)
                    end)
                end
            end)
        end
        task.wait(0.3)
    end
end)
end

-- ========================================================================
-- 13. HỆ THỐNG CỬA HÀNG HOÀN CHỈNH (MY EYES, AURAS, BOSS SHOP & REWARDS)
-- ========================================================================
do
local FALLBACK_BOSS_EYES = {
    hakka_no_togame = { name = "Hakka no Togame", mult = 120000000000 },
    arrogante = { name = "Arrogante", mult = 45000000000 },
    cero_oscuras = { name = "Cero Oscuras", mult = 16000000000 },
    santa_teresa = { name = "Santa Teresa", mult = 4000000000 },
    negacion = { name = "Negacion", mult = 500000000 },
    grand_prize = { name = "Dark Star Kai", mult = 120000000000 },
    kurenai_mangekyo = { name = "Kurenai Mangekyo", mult = 16000000000 },
    fuma_mangekyo = { name = "Fuma Mangekyo", mult = 4000000000 },
    kanjogan = { name = "Kanjogan", mult = 500000000 }
}

local function getPrettyAuraName(rawName)
    if not rawName or rawName == "" or rawName:lower() == "none" then return "Chưa trang bị" end
    local clean = tostring(rawName):lower()
    local AURA_NAMES = {
        bijuu_mode = "Bijuu Mode",
        cero_corona = "Cero Corona",
        tailed_cloak = "Tailed Cloak",
        chakra_cloak = "Chakra Cloak",
        fox_fire = "Fox Fire",
        gillian_shroud = "Gillian Shroud",
        bala_storm = "Bala Storm",
        sonido = "Sonido"
    }
    if AURA_NAMES[clean] then return AURA_NAMES[clean] end
    return clean:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

local MASTER_EYES_CHAIN
do
local function E(id, name, wins, mult, world, padIndex) return { id = id, name = name, wins = wins, mult = mult, world = world, padIndex = padIndex } end
MASTER_EYES_CHAIN = {
    E("sharingan", "Sharinghan", 0, 1, 1, 1),
    E("mangekyo", "Mangekyu Sharinghan", 10, 2, 1, 2),
    E("geass", "Geas", 50, 3, 1, 3),
    E("eternal_mangekyo", "Eternal Mangekyu Sharinghan", 300, 4, 1, 4),
    E("rinnegan", "Rinneghan", 2000, 7, 1, 5),
    E("jogan", "Joghan", 15000, 10, 1, 6),
    E("tenseigan", "Tenseighan", 100000, 14, 1, 7),
    E("rinne_sharingan", "Rinne Sharinghan", 500000, 32, 1, 8),
    E("senrigan", "Senrighan", 2000000, 75, 1, 9),
    E("shion", "Sion\'s Dojutsu", 6000000, 170, 1, 10),
    E("six_eyes", "Sixfold Eyes", 15000000, 400, 1, 11),
    E("kokugan", "Kokughan", 40000000, 900, 1, 12),
    E("all_seeing", "All-Seeing Eyes of God", 100000000, 2100, 1, 13),
    E("beast_gaze", "Beast Gaze", 790000000, 3900, 2, 14),
    E("violet_halo", "Violet Halo", 3400000000, 16000, 2, 1),
    E("venom_tomoe", "Venom Tomoe", 14000000000, 66000, 2, 2),
    E("lotus_eye", "Lotus Eye", 59000000000, 270000, 2, 3),
    E("phantom_pinwheel", "Phantom Pinwheel", 240000000000, 1100000, 2, 4),
    E("amethyst_star", "Amethyst Star", 960000000000, 4500000, 2, 5),
    E("grave_rinne", "Grave Rinne", 14000000000000, 19000000, 2, 6),
    E("jade_seal", "Jade Seal", 54000000000000, 76000000, 2, 7),
    E("solar_lotus", "Solar Lotus", 210000000000000, 310000000, 2, 8),
    E("crimson_spiral", "Crimson Spiral", 820000000000000, 1300000000, 2, 9),
    E("sage_rings", "Sage Rings", 3200000000000000, 5200000000, 2, 10),
    E("oracle_eye", "Oracle Eye", 12000000000000000, 21000000000, 2, 11),
    E("celestial_gaze", "Celestial Gaze", 47000000000000000, 88000000000, 2, 12),
    E("blossom_orbit", "Blossom Orbit", 390000000000000000, 260000000000, 3, 13),
    E("thorn_blossom", "Thorn Blossom", 1700000000000000000, 1100000000000, 3, 14),
    E("crimson_bloom", "Crimson Bloom", 7100000000000000000, 4300000000000, 3, 1),
    E("nightshade_pinwheel", "Nightshade Pinwheel", 28000000000000000000, 17000000000000, 3, 2),
    E("iron_mandala", "Iron Mandala", 120000000000000000000, 70000000000000, 3, 3),
    E("void_compass", "Void Compass", 460000000000000000000, 290000000000000, 3, 4),
    E("blood_trident", "Blood Trident", 1.8e+21, 1100000000000000, 3, 5),
    E("moon_rinne", "Moon Rinne", 7.1e+21, 4700000000000000, 3, 6),
    E("rift_crescent", "Rift Crescent", 2.8e+22, 18000000000000000, 3, 7),
    E("scarlet_whirl", "Scarlet Whirl", 1.1e+23, 77000000000000000, 3, 8),
    E("eclipse_spiral", "Eclipse Spiral", 4.2e+23, 310000000000000000, 3, 9),
    E("inferno_star", "Inferno Star", 1.6e+24, 1200000000000000000, 3, 10),
    E("thorn_halo", "Thorn Halo", 6.1e+24, 5100000000000000000, 3, 11),
    E("arcane_sigil", "Arcane Sigil", 2.4e+25, 21000000000000000000, 3, 12),
    E("tide_tomoe", "Tide Tomoe", 2e+26, 47000000000000000000, 4, 13),
    E("frost_thorn", "Frost Thorn", 8.5e+26, 200000000000000000000, 4, 14),
    E("glacier_star", "Glacier Star", 3.6e+27, 770000000000000000000, 4, 1),
    E("frozen_rinne", "Frozen Rinne", 1.4e+28, 3.1e+21, 4, 2),
    E("abyss_spindle", "Abyss Spindle", 5.8e+28, 1.3e+22, 4, 3),
    E("starsea_rinne", "Starsea Rinne", 2.3e+29, 5.1e+22, 4, 4),
    E("azure_flame", "Azure Flame", 9.2e+29, 2.1e+23, 4, 5),
    E("polar_dial", "Polar Dial", 3.55e+30, 8.3e+23, 4, 6),
    E("blizzard_wheel", "Blizzard Wheel", 1.4e+31, 3.4e+24, 4, 7),
    E("dark_maelstrom", "Dark Maelstrom", 5.5e+31, 1.4e+25, 4, 8),
    E("ember_trinity", "Ember Trinity", 2.1e+32, 5.6e+25, 4, 9),
    E("glacier_sharingan", "Glacier Sharinghan", 8.4e+32, 1.1e+26, 4, 10),
    E("kurobyougan", "Kurobyoughan", 3.4e+33, 2.2e+26, 4, 11),
    E("yumegan", "Yumeghan", 1.35e+34, 4.5e+26, 4, 12),
    E("astral_bloom", "Astral Bloom", 1e+35, 1.2e+26, 5, 13),
    E("crimson_vortex", "Crimson Vortex", 4.2e+35, 4.8e+26, 5, 14),
    E("corona_gear", "Corona Gear", 1.8e+36, 1.9e+27, 5, 1),
    E("mangekyou_byakugan", "Mangekyu Byakughan", 6.9e+36, 7.7e+27, 5, 2),
    E("crimson_comet", "Crimson Comet", 2.9e+37, 3.1e+28, 5, 3),
    E("pulsar_tomoe", "Pulsar Tomoe", 1.14e+38, 1.2e+29, 5, 4),
    E("mangekyou_jigokugan", "Mangekyu Jigokughan", 4.6e+38, 4.9e+29, 5, 5),
    E("astral_sigil", "Astral Sigil", 1.8e+39, 2e+30, 5, 6),
    E("red_giant", "Red Giant", 7e+39, 7.9e+30, 5, 7),
    E("void_gaze", "Void Gaze", 2.75e+40, 3.1e+31, 5, 8),
    E("nova_trinity", "Nova Trinity", 1.05e+41, 1.3e+32, 5, 9),
    E("dark_star", "Dark Star", 4e+41, 5e+32, 5, 10),
    E("nebula_rinne", "Nebula Rinne", 1.54e+42, 2e+33, 5, 11),
    E("chikaragan", "Chikaraghan", 5.9e+42, 8e+33, 5, 12),
    E("raging_current", "Raging Current", 7.5e+43, 1.3e+35, 6, 13),
    E("hell_butterfly", "Hell Butterfly", 3.15e+44, 8.32e+35, 6, 14),
    E("raiko_gaze", "Raiko Gaze", 1.35e+45, 5.38e+36, 6, 1),
    E("kido_seal", "Kidou Seal", 5.17e+45, 3.4e+37, 6, 2),
    E("shinso_edge", "Shinsou Edge", 2.18e+46, 2.16e+38, 6, 3),
    E("shirayuki", "Shirayuki", 8.55e+46, 1.36e+39, 6, 4),
    E("quincy_cross", "Quincey Cross", 3.45e+47, 8.89e+39, 6, 5),
    E("sanrei_lattice", "Sanray Lattice", 1.35e+48, 5.64e+40, 6, 6),
    E("kyoka_suigetsu", "Kyouka Suigetsu", 5.25e+48, 3.65e+41, 6, 7),
    E("black_coffin", "Black Coffin", 2.06e+49, 2.34e+42, 6, 8),
    E("senbonzakura", "Senbonsakura", 7.87e+49, 1.54e+43, 6, 9),
    E("hyorinmaru", "Hyourinmaru", 3e+50, 9.5e+43, 6, 10),
    E("ryujin_jakka", "Ryuujin Jakka", 1.15e+51, 6.19e+44, 6, 11),
    E("getsuga_tensho", "Getzuga Tenshou", 4.42e+51, 3.92e+45, 6, 12),
    E("gamuza", "Gammuza", 7e+52, 7.88e+45, 7, 13),
    E("resurreccion", "Resureccion", 2.94e+53, 5.04e+46, 7, 14),
    E("gran_rey_cero", "Grand Rey Cero", 1.26e+54, 3.23e+47, 7, 1),
    E("cero_inferno", "Cero Inferno", 4.83e+54, 2.06e+48, 7, 2),
    E("tatarforas", "Tattarforas", 2.03e+55, 1.31e+49, 7, 3),
    E("los_lobos", "Los Loboz", 7.98e+55, 8.26e+49, 7, 4),
    E("pantera", "Panterra", 3.22e+56, 5.36e+50, 7, 5),
    E("compulsory", "The Compulsive", 1.26e+57, 3.44e+51, 7, 6),
    E("murcielago", "Murzielago", 4.9e+57, 2.22e+52, 7, 7),
    E("inner_hollow", "Inner Hollow", 1.92e+58, 1.42e+53, 7, 8),
    E("vasto_lorde", "Vasto Lord", 7.35e+58, 9.15e+53, 7, 9),
    E("hogyoku", "Hougyoku", 2.8e+59, 5.78e+54, 7, 10),
    E("soul_king", "Spirit King", 1.08e+60, 3.74e+55, 7, 11),
    E("almighty", "The Allmighty", 4.13e+60, 2.37e+56, 7, 12),
    E("briar_maiden", "Briar Maiden", 8.75e+61, 4.77e+56, 8, 13),
    E("four_leaf", "Four-Leaf Grimoire", 3.67e+62, 3.05e+57, 8, 14),
    E("sea_dragon", "Sea Dragon", 1.57e+63, 1.95e+58, 8, 1),
    E("leo_rugiens", "Leo Rugens", 6.04e+63, 1.25e+59, 8, 2),
    E("blood_curse", "Blood Curse", 2.54e+64, 7.98e+59, 8, 3),
    E("spirit_storm", "Spirit Storm", 9.98e+64, 5e+60, 8, 4),
    E("sealing_magic", "Sealing Magic", 4.03e+65, 3.24e+61, 8, 5),
    E("chronostasis", "Chronostasis", 1.57e+66, 2.07e+62, 8, 6),
    E("dimension_slash", "Dimension Slash", 6.12e+66, 1.34e+63, 8, 7),
    E("light_magic", "Light Magic", 2.41e+67, 8.58e+63, 8, 8),
    E("devil_eye", "Devil Eye", 9.19e+67, 5.54e+64, 8, 9),
    E("world_tree", "World Tree", 3.5e+68, 3.5e+65, 8, 10),
    E("black_asta", "Black Astra", 1.35e+69, 2.26e+66, 8, 11),
    E("gravity_king", "Gravity King", 5.16e+69, 1.44e+67, 8, 12),
    E("exploding_blood", "Exploding Blood", 1.09e+71, 2.89e+67, 9, 13),
    E("lower_moon", "Low Moon", 4.59e+71, 1.85e+68, 9, 14),
    E("blood_sickle", "Blood Sickle", 1.96e+72, 1.18e+69, 9, 1),
    E("black_thunder", "Black Thunder", 7.55e+72, 7.56e+69, 9, 2),
    E("thousand_needles", "Thousand Needles", 3.18e+73, 4.83e+70, 9, 3),
    E("zohakuten", "Zouhakuten", 1.25e+74, 3.03e+71, 9, 4),
    E("dead_calm", "Dead Calm", 5.04e+74, 1.96e+72, 9, 5),
    E("biwa_castle", "Biwa Castle", 1.96e+75, 1.25e+73, 9, 6),
    E("destructive_death", "Destructive Death", 7.65e+75, 8.11e+73, 9, 7),
    E("cryo_lotus", "Cryo Lotus", 3.01e+76, 5.19e+74, 9, 8),
    E("demon_seal", "Demon Seal", 1.15e+77, 3.35e+75, 9, 9),
    E("moon_breathing", "Moon Breath", 4.38e+77, 2.12e+76, 9, 10),
    E("sun_breathing", "Sun Breath", 1.69e+78, 1.37e+77, 9, 11),
    E("demon_king", "Demon King", 6.45e+78, 8.71e+77, 9, 12),
}
end

local function getLiveGameEyesConfig()
    local ok, res = pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        if not shared then return nil end
        local config = shared:FindFirstChild("Config")
        if not config then return nil end
        local eyesMod = config:FindFirstChild("Eyes")
        if not eyesMod then return nil end
        return require(eyesMod)
    end)
    return (ok and typeof(res) == "table") and res or nil
end

local function getEyesChain()
    local liveCfg = getLiveGameEyesConfig()
    if liveCfg and liveCfg.chain and #liveCfg.chain > 0 then
        return liveCfg.chain
    end
    return MASTER_EYES_CHAIN
end

local function getPlayerWins()
    local tw = localPlayer:GetAttribute("TotalWins")
    if typeof(tw) == "number" then return tw end
    if typeof(tw) == "string" then return tonumber(tw) or 0 end
    local w = localPlayer:GetAttribute("Wins")
    if typeof(w) == "number" then return w end
    if typeof(w) == "string" then return tonumber(w) or 0 end
    local ls = localPlayer:FindFirstChild("leaderstats")
    if ls then
        local obj = ls:FindFirstChild("Wins") or ls:FindFirstChild("TotalWins") or ls:FindFirstChild("Trophies")
        if obj and obj:IsA("ValueBase") then return tonumber(obj.Value) or 0 end
    end
    return 0
end

local function getPlayerCurrentWorld()
    local w = localPlayer:GetAttribute("World")
    if typeof(w) == "number" and w >= 1 then return w end
    if typeof(w) == "string" then
        local nw = tonumber(w)
        if nw and nw >= 1 then return nw end
    end
    return 1
end

local function isWorldAccessible(targetWorld)
    targetWorld = tonumber(targetWorld) or 1
    if targetWorld <= 1 then return true end
    local curWorld = getPlayerCurrentWorld()
    if curWorld >= targetWorld then return true end
    local ok, worldsCfg = pcall(function()
        return require(ReplicatedStorage.Shared.Config.Worlds)
    end)
    if ok and typeof(worldsCfg) == "table" and worldsCfg[targetWorld] then
        local wData = worldsCfg[targetWorld]
        if wData.ready == false then return false end
        local prevWorld = targetWorld - 1
        local stageAttr = (prevWorld == 1) and "BestStage" or ("BestStage" .. tostring(prevWorld))
        local bestStage = localPlayer:GetAttribute(stageAttr) or 0
        if wData.needStage and bestStage < wData.needStage then
            return false
        end
        return true
    end
    return curWorld >= targetWorld
end

local function getPlayerOwnedEyes()
    local raw = localPlayer:GetAttribute("Eyes")
    local owned = { sharingan = 1 }
    if typeof(raw) == "table" then
        for k, v in pairs(raw) do owned[tostring(k)] = v end
    elseif typeof(raw) == "string" and raw ~= "" then
        local ok, res = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and typeof(res) == "table" then
            for k, v in pairs(res) do owned[tostring(k)] = v end
        end
    end
    local curEye = localPlayer:GetAttribute("Eye")
    if curEye and curEye ~= "" then owned[tostring(curEye)] = 1 end
    return owned
end

local function getNextLockedEye()
    local chain = getEyesChain()
    local owned = getPlayerOwnedEyes()
    for i, eye in ipairs(chain) do
        if eye and eye.id and not owned[eye.id] then
            local eyeWorld = eye.world or 1
            local padIdx = eye.padIndex or ((i - 1) % 14 + 1)
            local worldOpen = isWorldAccessible(eyeWorld)
            return eye, eyeWorld, padIdx, worldOpen
        end
    end
    return nil, 1, 1, true
end

local function getEyeById(id)
    if not id or id == "" then return { id = "sharingan", name = "Sharingan", mult = 1, wins = 0 } end
    local cleanId = tostring(id):lower()
    local liveCfg = getLiveGameEyesConfig()
    if liveCfg and liveCfg.byId then
        local found = liveCfg.byId[id] or liveCfg.byId[cleanId]
        if found then return found end
        for k, v in pairs(liveCfg.byId) do
            if tostring(k):lower() == cleanId then return v end
        end
    end
    for _, e in ipairs(MASTER_EYES_CHAIN) do
        if e and e.id and e.id:lower() == cleanId then
            return e
        end
    end
    if FALLBACK_BOSS_EYES and FALLBACK_BOSS_EYES[cleanId] then
        return {
            id = id,
            name = FALLBACK_BOSS_EYES[cleanId].name,
            mult = FALLBACK_BOSS_EYES[cleanId].mult,
            wins = 0
        }
    end
    local prettyName = cleanId:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    return { id = id, name = prettyName, mult = 1, wins = 0 }
end

local function getBestOwnedEye()
    local owned = getPlayerOwnedEyes()
    local bestEye = nil
    local bestMult = -1

    local liveCfg = getLiveGameEyesConfig()
    if liveCfg and liveCfg.byId then
        for eyeId, eyeData in pairs(liveCfg.byId) do
            local kLower = tostring(eyeId):lower()
            if owned[kLower] or owned[eyeId] then
                local mult = tonumber(eyeData.mult) or 1
                if mult > bestMult then
                    bestMult = mult
                    bestEye = eyeData
                end
            end
        end
    end

    for _, eye in ipairs(MASTER_EYES_CHAIN) do
        if eye and eye.id then
            local kLower = eye.id:lower()
            if owned[kLower] or owned[eye.id] then
                local mult = tonumber(eye.mult) or 1
                if mult > bestMult then
                    bestMult = mult
                    bestEye = eye
                end
            end
        end
    end

    if FALLBACK_BOSS_EYES then
        for bId, bData in pairs(FALLBACK_BOSS_EYES) do
            if owned[bId] or owned[bId:lower()] then
                local mult = tonumber(bData.mult) or 1
                if mult > bestMult then
                    bestMult = mult
                    bestEye = { id = bId, name = bData.name, mult = mult, wins = 0 }
                end
            end
        end
    end

    return bestEye or MASTER_EYES_CHAIN[1]
end

local function getUnlockEyeRemote()
    local r = remotes or ReplicatedStorage:FindFirstChild("Remotes")
    if r then
        return r:FindFirstChild("UnlockEye")
    end
    return nil
end

local function getEquipRemote()
    local r = remotes or ReplicatedStorage:FindFirstChild("Remotes")
    if r then
        return r:FindFirstChild("Equip")
    end
    return nil
end

dismissRobuxModals = function()
end

openGameMenu = function(menuName)
    local opened = false
    pcall(function()
        local pg = localPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        local target = tostring(menuName or ""):lower()

        for _, frame in ipairs(pg:GetDescendants()) do
            if frame:IsA("Frame") then
                local fName = frame.Name:lower()
                local hasTitle = false
                for _, child in ipairs(frame:GetChildren()) do
                    if child:IsA("TextLabel") and child.Visible then
                        local ct = child.Text:lower()
                        if ((target == "eyes" or target == "eye") and ct:find("my eyes")) or ((target == "aura" or target == "auras") and ct:find("aura")) then
                            hasTitle = true; break
                        end
                    end
                end
                if hasTitle or ((target == "eyes" or target == "eye") and (fName == "myeyes" or fName == "eyesframe" or fName == "eyes")) then
                    frame.Visible = true; opened = true; return
                end
            end
        end

        for _, btn in ipairs(pg:GetDescendants()) do
            if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                local bName = btn.Name:lower()
                local txt = (btn:IsA("TextButton") and btn.Text:lower() or "")
                local l = btn:FindFirstChildOfClass("TextLabel")
                if l and l.Text then txt = txt .. " " .. l.Text:lower() end
                txt = txt:gsub("^%s*(.-)%s*$", "%1")
                local isForbidden = bName:find("robux") or txt:find("") or txt:find("buy") or bName:find("deal") or txt:find("deal") or bName:find("egg") or txt:find("egg") or bName:find("special") or txt:find("special") or bName:find("pack") or bName:find("pass")
                if not isForbidden then
                    local isMatch = ((target == "eyes" or target == "eye" or target == "my eyes") and (txt == "eyes" or txt == "my eyes" or bName == "eyes" or bName == "myeyes" or bName == "eyesbtn"))
                        or ((target == "aura" or target == "auras") and (txt == "auras" or txt == "aura" or bName == "auras" or bName == "aurabtn"))
                    if isMatch and not bName:find("unlock") and not bName:find("equip") and txt ~= "x" then
                        if triggerGuiButton(btn) then opened = true; return end
                    end
                end
            end
        end
    end)
    return opened
end

local isUnlockingEye = false
local lastUnlockAttempt = 0

unlockNextEyeAction = function(fromAuto)
    if isUnlockingEye then return false end
    if tick() - lastUnlockAttempt < 0.35 then return false end

    local nextEye, eyeWorld, padIndex, worldOpen = getNextLockedEye()
    if not nextEye then
        if not fromAuto then Notification("My Eyes", "Bạn đã mở khóa toàn bộ Mắt trong game!", 3) end
        return false
    end

    if not worldOpen then
        if not fromAuto then
            Notification("My Eyes", string.format("Mắt [%s] thuộc World %d! Bạn cần vượt Ải 15 World %d để mở map trước!", nextEye.name, eyeWorld, math.max(1, eyeWorld - 1)), 4)
        end
        return false
    end

    local totalWins = getPlayerWins()
    local requiredWins = nextEye.wins or 0
    if totalWins < requiredWins then
        if not fromAuto then
            Notification("My Eyes", string.format("Chưa đủ Cúp mua [%s]! Cần: %s (Có: %s) - Thiếu %s Cúp", nextEye.name, formatNumber(requiredWins), formatNumber(totalWins), formatNumber(requiredWins - totalWins)), 3)
        end
        return false
    end

    isUnlockingEye = true
    lastUnlockAttempt = tick()

    local ok = pcall(function()
        local remote = getUnlockEyeRemote()
        if remote then
            remote:FireServer(nextEye.id)
        else
            local okNet, Net = pcall(function() return require(ReplicatedStorage.Shared.Net) end)
            if okNet and Net and Net.event then
                Net.event("UnlockEye"):FireServer(nextEye.id)
            end
        end

        task.wait(0.25)

        local eqRemote = getEquipRemote()
        if eqRemote then
            eqRemote:FireServer(nextEye.id)
        else
            local okNet, Net = pcall(function() return require(ReplicatedStorage.Shared.Net) end)
            if okNet and Net and Net.event then
                Net.event("Equip"):FireServer(nextEye.id)
            end
        end

        if not fromAuto then
            Notification("My Eyes", string.format("MUA THÀNH CÔNG: %s (%s)!", nextEye.name, formatMultiplier(nextEye.mult)), 3)
        end
        safeLog(string.format("[My Eyes] Đã mua thành công Mắt: %s (%s, World %d)", nextEye.name, formatMultiplier(nextEye.mult), eyeWorld))

        if _G.AnimeEyes_WebhookEnabled and _G.AnimeEyes_WebhookEye and sendDiscordWebhook then
            task.spawn(function()
                sendDiscordWebhook(
                    "👁️ MỞ KHÓA MẮT MỚI THÀNH CÔNG!",
                    string.format("**%s** (@%s) vừa mở khóa thành công mắt **%s**!", localPlayer.DisplayName or localPlayer.Name, localPlayer.Name, nextEye.name),
                    8246268, -- Luminous Crystal Cyan
                    {
                        { name = "Mắt Mới", value = string.format("**%s** (%s)", nextEye.name, formatMultiplier(nextEye.mult)), inline = true },
                        { name = "Giá Mua", value = formatNumber(requiredWins) .. " Cúp", inline = true },
                        { name = "World", value = "World " .. tostring(eyeWorld or 1), inline = true }
                    },
                    false
                )
            end)
        end
    end)

    isUnlockingEye = false
    return ok
end

equipBestEyeAction = function(manual)
    local best = getBestOwnedEye()
    if not best then return end
    local curEye = tostring(localPlayer:GetAttribute("Eye") or "")
    if curEye:lower() == best.id:lower() then
        if manual then
            Notification("My Eyes", string.format("Đang dùng Mắt mạnh nhất: %s (%s)", best.name, formatMultiplier(best.mult)), 2)
        end
        return
    end

    pcall(function()
        local eqRemote = getEquipRemote()
        if eqRemote then
            eqRemote:FireServer(best.id)
        else
            local okNet, Net = pcall(function() return require(ReplicatedStorage.Shared.Net) end)
            if okNet and Net and Net.event then
                Net.event("Equip"):FireServer(best.id)
            end
        end
        if manual then
            Notification("My Eyes", string.format("ĐÃ TRANG BỊ: %s (%s)!", best.name, formatMultiplier(best.mult)), 2)
        end
    end)
end

local function getPlayerOwnedAuras()
    local raw = localPlayer:GetAttribute("OwnedAuras")
    if not raw or raw == "" then return {} end
    local ok, res = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and typeof(res) == "table" then
        local list = {}
        for k, v in pairs(res) do
            if v == true or v == 1 or typeof(v) == "table" or typeof(v) == "number" then table.insert(list, tostring(k)) end
        end
        return list
    end
    return {}
end

local function equipAuraByName(auraName)
    if not auraName or auraName == "" or not equipAuraRemote then return end
    pcall(function()
        if equipAuraRemote:IsA("RemoteFunction") then equipAuraRemote:InvokeServer(auraName)
        else equipAuraRemote:FireServer(auraName) end
    end)
end

rollAuraAction = function(manual)
    pcall(function()
        if arcadeStartRemote and arcadeStartRemote:IsA("RemoteFunction") then arcadeStartRemote:InvokeServer() end
        if arcadeFinishRemote and arcadeFinishRemote:IsA("RemoteFunction") then arcadeFinishRemote:InvokeServer() end
    end)
    if manual then
        Notification("Auras", "Đã gửi lệnh quay Aura!", 2)
    end
end

buyBossShopAction = function(manual)
    pcall(function()
        if bossShopRemote and bossShopRemote:IsA("RemoteFunction") then
            -- Mua ưu tiên từ Thần Thoại (Grand Prize Mắt / Aura) đến Boosts cho cả Kyubi và Menoz
            local buyPriority = {
                -- 1. Menoz Shop (Cửa hàng Boss Mới)
                "hakka_no_togame",      -- Mắt Thần Thoại Hakka no Togame (8000 MenosCoins)
                "arrogante",            -- Mắt Kage Arrogante (5000)
                "cero_oscuras",         -- Mắt Kage Cero Oscuras (3200)
                "cero_corona",          -- Aura Kage Cero Corona (3000)
                "santa_teresa",         -- Mắt Kage Santa Teresa (2400)
                "gillian_shroud",       -- Aura Jonin Gillian Shroud (1000)
                "negacion",             -- Mắt Jonin Negacion (1000)
                "bala_storm",           -- Aura Genin Bala Storm (500)
                "sonido",               -- Aura Genin Sonido (160)
                "menos_boost_chakra",   -- Boost Chakra 30 phút (200)
                "menos_boost_wins",     -- Boost Wins 30 phút (200)
                -- 2. Kyubi Shop (Cửa hàng Kyubi)
                "grand_prize",          -- Mắt Thần Thoại Dark Star (8000 KuramaCoins)
                "kurenai_mangekyo",     -- Mắt Kage Kurenai Mangekyo (3200)
                "bijuu_mode",           -- Aura Kage Bijuu Mode (3000)
                "fuma_mangekyo",        -- Mắt Kage Fuma Mangekyo (2400)
                "tailed_cloak",         -- Aura Jonin Tailed Cloak (1000)
                "kanjogan",             -- Mắt Jonin Kanjogan (1000)
                "chakra_cloak",         -- Aura Genin Chakra Cloak (500)
                "fox_fire",             -- Aura Genin Fox Fire (160)
                "boost_chakra",         -- Boost Chakra 30 phút (200)
                "boost_wins"            -- Boost Wins 30 phút (200)
            }
            for _, itemId in ipairs(buyPriority) do
                pcall(function() bossShopRemote:InvokeServer("buy", itemId) end)
            end
        end
    end)
    if manual then
        Notification("Boss Shop", "Đã gửi lệnh tự động mua toàn bộ vật phẩm Kyubi & Menoz Shop!", 2)
    end
end

claimAllFreeRewards = function(manual)
    pcall(function() if claimDailyRemote and claimDailyRemote:IsA("RemoteFunction") then claimDailyRemote:InvokeServer() end end)
    pcall(function() if claimGroupRemote and claimGroupRemote:IsA("RemoteFunction") then claimGroupRemote:InvokeServer() end end)
    pcall(function() if claimRewardRemote and claimRewardRemote:IsA("RemoteFunction") then for i = 1, 12 do claimRewardRemote:InvokeServer(i) end end end)
    pcall(function() if claimQuestRemote and claimQuestRemote:IsA("RemoteFunction") then for i = 1, 10 do claimQuestRemote:InvokeServer(i) end end end)
    pcall(function()
        if exitBonusRemote and exitBonusRemote:IsA("RemoteFunction") then exitBonusRemote:InvokeServer() end
        if welcomeBackRemote and welcomeBackRemote:IsA("RemoteFunction") then welcomeBackRemote:InvokeServer() end
    end)
    if manual then
        Notification("Nhận Quà", "Đã tự động nhận tất cả phần thưởng miễn phí!", 2)
    end
end

redeemAllKnownCodes = function()
    -- Danh sách Giftcode chuẩn xác 100% trích xuất từ mã nguồn ReplicatedStorage.Shared.Config.Codes
    local codeList = {
        "AWAKEN",          -- Cúp + Trứng World 2 + Boost Chakra 30p
        "SHARINGAN",       -- Cúp + Trứng Akatsuki + Boost Wins 30p
        "UPDATE1",         -- Boost Chakra 10p
        "NEWWORLDS",       -- Boost Wins 10p
        "1MILLIONVISITS",  -- Trứng Infernal Aegis
        "UPDATE2",         -- 15 KuramaCoins + Boost Chakra 5p
        "KURUMA",          -- 15 KuramaCoins + Boost Chakra 5p
        "UPDATE3",         -- 20 MenosCoins + Boost Chakra 10p
        "10MVISITS"        -- 25 MenosCoins + Boost Chakra 15p
    }
    if not redeemCodeRemote then Notification("Giftcode", "Không tìm thấy Remote RedeemCode!", 2); return end
    task.spawn(function()
        local redeemedCount = 0
        for _, code in ipairs(codeList) do
            pcall(function()
                if redeemCodeRemote:IsA("RemoteFunction") then
                    redeemCodeRemote:InvokeServer(code)
                else
                    redeemCodeRemote:FireServer(code)
                end
                redeemedCount = redeemedCount + 1
            end)
            task.wait(0.25)
        end
        Notification("Giftcode", string.format("Đã nhập toàn bộ %d mã Giftcode chính thức!", redeemedCount), 3)
    end)
end

task.spawn(function()
    while isSessionActive() do
        pcall(function()
            if LabelCurrentEye then
                local equippedId = tostring(localPlayer:GetAttribute("Eye") or "sharingan")
                local curEye = getEyeById(equippedId)
                updateLabel(LabelCurrentEye, string.format("Mắt Đang Dùng: %s (%s)", curEye.name, formatMultiplier(curEye.mult)))
            end
            if LabelNextEye and LabelEyeProgress then
                local nextEye, eyeWorld, padIndex, worldOpen = getNextLockedEye()
                if nextEye then
                    local totalWins = getPlayerWins()
                    local cost = nextEye.wins or 0
                    local pct = cost > 0 and math.clamp(math.floor((totalWins / cost) * 100), 0, 99) or 0
                    updateLabel(LabelNextEye, string.format("Mắt Kế Tiếp: %s (%s) [W%d]", nextEye.name, formatMultiplier(nextEye.mult), eyeWorld or 1))
                    if not worldOpen then
                        updateLabel(LabelEyeProgress, string.format("World %d chưa mở! (Cần vượt Ải 15 W%d)", eyeWorld, math.max(1, eyeWorld - 1)))
                    elseif totalWins >= cost then
                        updateLabel(LabelEyeProgress, string.format("Tiến Độ Cúp: 100%% [ĐỦ CÚP MUA NGAY] (%s/%s)", formatNumber(totalWins), formatNumber(cost)))
                    else
                        updateLabel(LabelEyeProgress, string.format("Cúp: %s / %s (%d%%) [Thiếu %s]", formatNumber(totalWins), formatNumber(cost), pct, formatNumber(cost - totalWins)))
                    end
                else
                    updateLabel(LabelNextEye, "Mắt Kế Tiếp: Đã mở khóa hết tất cả Mắt!")
                    updateLabel(LabelEyeProgress, "Tiến Độ Cúp: 100% Hoàn Thành (Max Level)")
                end
            end
            if LabelCurrentAura then
                local equippedAura = tostring(localPlayer:GetAttribute("Aura") or "")
                updateLabel(LabelCurrentAura, "Aura Đang Dùng: " .. getPrettyAuraName(equippedAura))
            end
            if LabelOwnedAurasCount then
                updateLabel(LabelOwnedAurasCount, string.format("Bộ Sưu Tập: %d Auras Đã Sở Hữu", #getPlayerOwnedAuras()))
            end
        end)
        task.wait(1.0)
    end
end)

task.spawn(function()
    while isSessionActive() do
        if _G.AnimeEyes_AutoUnlockEyes then pcall(unlockNextEyeAction, true) end
        if _G.AnimeEyes_AutoEquipBestEye then pcall(equipBestEyeAction) end
        if _G.AnimeEyes_AutoEquipBestAura then
            pcall(function()
                local auras = getPlayerOwnedAuras()
                if #auras > 0 then equipAuraByName(auras[#auras]) end
            end)
        end
        if _G.AnimeEyes_AutoRollAuras then pcall(rollAuraAction) end
        if _G.AnimeEyes_AutoBossShop then pcall(buyBossShopAction) end
        if _G.AnimeEyes_AutoClaims then pcall(claimAllFreeRewards) end
        task.wait(2.5)
    end
end)

end

-- ========================================================================
-- 14. TIỆN ÍCH TỐI ƯU TREO MÁY (ANTI-AFK & FPS BOOST & WALKSPEED)
-- ========================================================================
pcall(function()
    localPlayer.Idled:Connect(function()
        if _G.AntiAFK then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(0.2)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
        end
    end)
end)

toggleWhiteScreen = function(enable)
    local containers = {}
    if gethui then pcall(function() table.insert(containers, gethui()) end) end
    pcall(function() table.insert(containers, game:GetService("CoreGui")) end)
    local targetParent = containers[1] or game:GetService("CoreGui")

    local existing = targetParent:FindFirstChild("HelmWhiteScreen")
    if enable then
        if not existing then
            local sg = Instance.new("ScreenGui")
            sg.Name = "HelmWhiteScreen"
            sg.DisplayOrder = 999
            sg.IgnoreGuiInset = true
            local f = Instance.new("Frame", sg)
            f.Size = UDim2.fromScale(1, 1)
            f.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
            f.BorderSizePixel = 0
            local txt = Instance.new("TextLabel", f)
            txt.Size = UDim2.fromScale(1, 1)
            txt.BackgroundTransparency = 1
            txt.Text = "[HelmHub] Màn Hình Trắng Đang Bật\nBấm Tắt trong Hub để xem lại game!"
            txt.TextColor3 = Color3.fromRGB(40, 40, 40)
            txt.Font = Enum.Font.GothamBold
            txt.TextSize = 22
            sg.Parent = targetParent
        end
    else
        if existing then existing:Destroy() end
    end
end

applyFPSBoost = function()
    pcall(function()
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = false
        lighting.FogEnd = 9e9
        lighting.Brightness = 1

        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                obj.Enabled = false
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            elseif obj:IsA("BasePart") and not obj:IsA("Terrain") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.CastShadow = false
            end
        end
    end)
end

-- Vòng lặp duy trì WalkSpeed
task.spawn(function()
    while isSessionActive() do
        if _G.WalkSpeedEnabled and localPlayer.Character then
            pcall(function()
                local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.WalkSpeed ~= _G.WalkSpeedValue then
                    hum.WalkSpeed = _G.WalkSpeedValue
                end
            end)
        end
        task.wait(0.5)
    end
end)

-- ========================================================================
-- 15. HỆ THỐNG TỰ ĐỘNG LƯU & NẠP CẤU HÌNH (AUTO-SAVE / AUTO-LOAD DUAL-LAYER)
-- ========================================================================
do
local CONFIG_KEYS = {
    "AnimeEyes_AutoStage", "AnimeEyes_TargetStage", "AnimeEyes_SelectedWorld",
    "AnimeEyes_StageTimeout", "AnimeEyes_StageCPS", "AnimeEyes_StageDelay",
    "AnimeEyes_CenterStage", "AnimeEyes_AutoBoss", "AnimeEyes_BossHoverHeight",
    "AnimeEyes_AutoClick", "AnimeEyes_TargetCPS", "AnimeEyes_BypassCooldown",
    "AnimeEyes_AutoSkills", "AnimeEyes_KeepFreeOn", "AnimeEyes_AutoRebirth", "AnimeEyes_AutoTrainPad",
    "AnimeEyes_RebirthDelay", "AnimeEyes_AutoHatch", "AnimeEyes_SelectedEgg",
    "Helm_HatchAmount", "AnimeEyes_AutoEquipBestPet", "AnimeEyes_AutoUnlockEyes",
    "AnimeEyes_AutoEquipBestEye", "AnimeEyes_AutoRollAuras", "AnimeEyes_AutoEquipBestAura",
    "AnimeEyes_AutoClaims", "AnimeEyes_MuteToasts", "WalkSpeedEnabled", "WalkSpeedValue",
    "AntiAFK", "WhiteScreen", "DisableConsoleLogs",
    "AnimeEyes_WebhookURL", "AnimeEyes_WebhookEnabled", "AnimeEyes_WebhookHatch",
    "AnimeEyes_WebhookBoss", "AnimeEyes_WebhookEye", "AnimeEyes_WebhookPeriodic", "AnimeEyes_WebhookInterval"
}

local isSavingConfig = false
autoSaveSettings = function(manual)
    if isSavingConfig then return end
    isSavingConfig = true
    pcall(function()
        if not writefile then
            if manual then Notification("Cấu Hình", "Executor không hỗ trợ writefile!", 3) end
            return
        end
        local stateTable = {}
        for _, k in ipairs(CONFIG_KEYS) do
            if k == "AnimeEyes_AutoStage" then
                stateTable[k] = (_G.Helm_AutoStage == true)
            elseif k == "AnimeEyes_AutoBoss" then
                stateTable[k] = (_G.Helm_AutoBoss == true)
            else
                stateTable[k] = _G[k]
            end
        end
        local jsonStr = HttpService:JSONEncode(stateTable)
        pcall(function()
            if isfolder and makefolder then
                if not isfolder("!HelmHub") then makefolder("!HelmHub") end
                if not isfolder("!HelmHub/Anime Eyes") then makefolder("!HelmHub/Anime Eyes") end
            end
            writefile("!HelmHub/Anime Eyes/settings.json", jsonStr)
        end)
        pcall(function() writefile("AnimeEyes_settings.json", jsonStr) end)
        if manual then Notification("Cấu Hình", "Đã lưu cài đặt tự động vào máy!", 3) end
    end)
    isSavingConfig = false
end

autoLoadSettings = function(manual)
    pcall(function()
        local loaded = loadSettingsFromDisk()
        if loaded and uiRegistry then
            for _, group in pairs({ uiRegistry.toggles, uiRegistry.sliders }) do
                if group then
                    for flag, elem in pairs(group) do
                        local val = _G[flag]
                        if flag == "AnimeEyes_AutoStage" then val = _G.Helm_AutoStage
                        elseif flag == "AnimeEyes_AutoBoss" then val = _G.Helm_AutoBoss end
                        if val ~= nil and elem and elem.Set then
                            pcall(function() elem:Set(val) end)
                        end
                    end
                end
            end
        end
        if manual then Notification("Cấu Hình", "Đã nạp lại toàn bộ cài đặt từ file lưu!", 3) end
    end)
end

local function computeConfigHash()
    local parts = {}
    for _, k in ipairs(CONFIG_KEYS) do
        if k == "AnimeEyes_AutoStage" then
            table.insert(parts, tostring(_G.Helm_AutoStage))
        elseif k == "AnimeEyes_AutoBoss" then
            table.insert(parts, tostring(_G.Helm_AutoBoss))
        else
            table.insert(parts, tostring(_G[k]))
        end
    end
    return table.concat(parts, "_")
end

task.spawn(function()
    local lastSavedStateHash = computeConfigHash()
    while isSessionActive() do
        task.wait(3.0)
        pcall(function()
            local curHash = computeConfigHash()
            if curHash ~= lastSavedStateHash then
                lastSavedStateHash = curHash
                autoSaveSettings(false)
            end
        end)
    end
end)

pcall(function()
    game:BindToClose(function() autoSaveSettings(false) end)
end)

-- ========================================================================
-- 16. HỆ THỐNG WEBHOOK NỀN (AFK REPORT & MYTHIC/SECRET PET DETECTION)
-- ========================================================================
-- 1. Báo Cáo Treo Máy Định Kỳ
task.spawn(function()
    local startSessionTime = tick()
    local lastReportTick = tick()
    while isSessionActive() do
        local intervalMinutes = math.clamp(tonumber(_G.AnimeEyes_WebhookInterval) or 30, 5, 120)
        local intervalSeconds = intervalMinutes * 60
        task.wait(15)

        if _G.AnimeEyes_WebhookEnabled and _G.AnimeEyes_WebhookPeriodic and _G.AnimeEyes_WebhookURL and _G.AnimeEyes_WebhookURL ~= "" then
            if (tick() - lastReportTick) >= intervalSeconds then
                lastReportTick = tick()
                pcall(function()
                    local pName = (localPlayer and localPlayer.Name) or "Player"
                    local dName = (localPlayer and localPlayer.DisplayName) or pName
                    local uptimeHours = math.floor((tick() - startSessionTime) / 3600)
                    local uptimeMins = math.floor(((tick() - startSessionTime) % 3600) / 60)
                    local timeStr = string.format("%d giờ %d phút", uptimeHours, uptimeMins)

                    local curEye = (LabelCurrentEye and LabelCurrentEye.Main and LabelCurrentEye.Main.Text) or "N/A"
                    curEye = curEye:gsub("Mắt Đang Dùng:%s*", "")
                    local curPad = (LabelCurrentTrainingPad and LabelCurrentTrainingPad.Main and LabelCurrentTrainingPad.Main.Text) or "N/A"
                    local curAura = (LabelCurrentAura and LabelCurrentAura.Main and LabelCurrentAura.Main.Text) or "N/A"
                    curAura = curAura:gsub("Aura Đang Dùng:%s*", "")

                    local wins = getPlayerWins and getPlayerWins() or 0
                    local rb = getPlayerRebirths and getPlayerRebirths() or 0

                    if sendDiscordWebhook then
                        sendDiscordWebhook(
                            "📊 BÁO CÁO TIẾN ĐỘ TREO MÁY (AFK REPORT)",
                            string.format("Tài khoản **%s** (@%s) đang treo máy ổn định qua **HelmHub**.", dName, pName),
                            8246268, -- Luminous Crystal Cyan
                            {
                                { name = "Thời Gian Treo", value = timeStr, inline = true },
                                { name = "Trùng Sinh (Rebirths)", value = formatNumber(rb) .. " RB", inline = true },
                                { name = "Tổng Cúp / Wins", value = formatNumber(wins), inline = true },
                                { name = "Mắt Đang Dùng", value = curEye, inline = true },
                                { name = "Aura Đang Dùng", value = curAura, inline = true },
                                { name = "Bệ Farm Chakra", value = curPad, inline = false }
                            },
                            false
                        )
                    end
                end)
            end
        end
    end
end)

-- 2. Tự Động Bắn Thông Báo Khi Mở Được Pet Khủng (Mythic / Secret)
task.spawn(function()
    local lastPetAlertTick = 0
    local seenRarePets = {}
    local function checkPetText(text)
        if not text or typeof(text) ~= "string" or #text < 3 then return end
        local up = text:upper()
        if (up:find("MYTHIC") or up:find("SECRET") or up:find("TITAN") or up:find("DIVINE")) and not up:find("CHANCE") and not up:find("EQUIP") and not up:find("BUY") then
            if (tick() - lastPetAlertTick) > 3 and not seenRarePets[text] then
                seenRarePets[text] = true
                lastPetAlertTick = tick()
                if _G.AnimeEyes_WebhookEnabled and _G.AnimeEyes_WebhookHatch and sendDiscordWebhook then
                    task.spawn(function()
                        sendDiscordWebhook(
                            "🎉 NỔ PET KHỦNG (MYTHIC / SECRET)!",
                            string.format("Chúc mừng **%s** vừa mở ra được Pet siêu hiếm!", localPlayer.DisplayName or localPlayer.Name),
                            16766720, -- Gold / Secret Crimson
                            {
                                { name = "Thông Báo Trò Chơi", value = "**" .. text .. "**", inline = false },
                                { name = "Thời Gian", value = os.date("%H:%M:%S - %d/%m/%Y"), inline = true },
                                { name = "Người Chơi", value = string.format("%s (@%s)", localPlayer.DisplayName or localPlayer.Name, localPlayer.Name), inline = true }
                            },
                            false
                        )
                    end)
                end
            end
        end
    end

    pcall(function()
        local pg = localPlayer:WaitForChild("PlayerGui", 5)
        if pg then
            pg.DescendantAdded:Connect(function(desc)
                if desc:IsA("TextLabel") then
                    pcall(function() checkPetText(desc.Text) end)
                    desc:GetPropertyChangedSignal("Text"):Connect(function()
                        pcall(function() checkPetText(desc.Text) end)
                    end)
                end
            end)
        end
    end)
end)

Notification("HelmHub", "Anime Eyes v19.5: Đã tích hợp Discord Webhook & Giao diện tối ưu!", 4)
end
