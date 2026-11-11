repeat task.wait(0.5) until game:IsLoaded()
local localPlayer = game:GetService("Players").LocalPlayer
repeat task.wait(0.5) until localPlayer and localPlayer:FindFirstChild("PlayerGui")

local isExtremeConfirmed = false

function isExtremeDimension()
    if isExtremeConfirmed then return true end

    -- 1. Loại bỏ các PlaceId không phải Dungeon trận đấu (Lobby, HighLevelLobby, RaidLobby, Afk, CharacterTest)
    if game.PlaceId == 6938803436 or game.PlaceId == 7274690025 or game.PlaceId == 7338881230 or game.PlaceId == 6990131029 or game.PlaceId == 6990133340 then
        return false
    end

    -- 2. Kiểm tra chế độ Raid: Nếu là Raid thì KHÔNG phải Extreme Dimension
    local pgui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
    local bg = pgui and pgui:FindFirstChild("BattleGui")
    if bg then
        local cFrame = bg:FindFirstChild("CenterUIFrame")
        if cFrame and cFrame:FindFirstChild("RaidDataFrame") and cFrame.RaidDataFrame.Visible == true then
            return false
        end
    end

    -- 3. Kiểm tra GameMode Attribute trên Workspace (Raid, Infinite, BossRush...)
    local gMode = workspace:GetAttribute("GameMode")
    if gMode then
        local gmLower = tostring(gMode):lower()
        if gmLower:find("raid") or gmLower:find("infinite") or gmLower:find("bossrush") then
            return false
        end
        if gmLower:find("extreme") then
            isExtremeConfirmed = true
            return true
        end
    end

    -- 4. Kiểm tra cấu hình AutoJoin / Cờ Difficulty từ UI của dj
    if _G.AutoJoinExtreme == true or _G.Difficulty == "Extreme" then
        isExtremeConfirmed = true
        return true
    end

    -- 5. Kiểm tra quái vật độc quyền chỉ có ở Extreme Dimension (Primordial, Ramura, Oni)
    local monstersFolder = workspace:FindFirstChild("Folders") and workspace.Folders:FindFirstChild("Monsters")
    if monstersFolder then
        for _, m in ipairs(monstersFolder:GetChildren()) do
            local name = m.Name:lower()
            if name:find("primordial") or name:find("ramura") or name:find("oni") then
                isExtremeConfirmed = true
                return true
            end
        end
    end

    -- 6. Kiểm tra GameMap (Extreme Dimension sử dụng các bản đồ Nightmare / Extreme)
    local gMap = workspace:FindFirstChild("GameMap")
    if gMap then
        for attrName, attrVal in pairs(gMap:GetAttributes()) do
            if tostring(attrName):lower():find("extreme") or tostring(attrVal):lower():find("extreme") then
                isExtremeConfirmed = true
                return true
            end
        end
        for _, child in ipairs(gMap:GetChildren()) do
            local cName = child.Name:lower()
            if cName:find("extreme") or cName:find("nightmare") then
                isExtremeConfirmed = true
                return true
            end
        end
    end

    -- 7. Kiểm tra Text trên BattleGui hiển thị "Extreme" hoặc thời gian trận đấu đặc trưng (15:00 / 14:xx)
    if bg then
        for _, desc in ipairs(bg:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Visible then
                local txt = desc.Text:lower()
                if txt:find("extreme") then
                    isExtremeConfirmed = true
                    return true
                end
                -- Thời gian Extreme Dimension bắt đầu từ 15:00 (14:xx hoặc 15:00)
                -- Trong khi Normal Dimension chỉ có 10:00 (09:xx/10:00) hoặc 12:00 (11:xx/12:00)
                if txt:find("^14:") or txt:find("^15:00") then
                    isExtremeConfirmed = true
                    return true
                end
            end
        end
    end

    -- 8. Nếu không có bất kỳ dấu hiệu nào của Extreme Dimension -> Đó là Normal Dimension / chế độ khác
    return false
end
_G.isExtremeDimension = isExtremeDimension


MapSelection = {}
RaidSelection = {}

if game.PlaceId == 6938803436 or game.PlaceId == 6990129309 or game.PlaceId == 6990133340 or game.PlaceId == 6990131029 or game.PlaceId == 7338881230 or game.PlaceId == 7274690025 or game.GameId == 2712497672 then
    local library
    -- 1. Ưu tiên nạp Local Test Server (127.0.0.1:8000 / localhost)
    pcall(function()
        library = loadstring(game:HttpGet("http://127.0.0.1:8000/Library/inventory.lua?t=" .. tostring(tick())))()
    end)
    -- 2. Nạp từ file cục bộ nếu executor lưu sẵn Library/inventory.lua
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
    if not library then
        warn("[HelmHub] Không thể nạp thư viện UI Library/inventory.lua!")
        return
    end
    local function getGMT7Time(fmt)
        return os.date(fmt or "%H:%M:%S (%d/%m/%Y)", os.time() + (7 * 3600))
    end
    local function Notification(mode, title, text, duration)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = tostring(title or "HelmHub"),
                Text = tostring(text or ""),
                Duration = tonumber(duration or 5)
            })
        end)
        print(string.format("[%s] %s", tostring(title or "HelmHub"), tostring(text or "")))
    end
    _G.Notification = Notification
    pcall(function() if getgenv then getgenv().Notification = Notification end end)
    local function GetAvailableMaps()
        local maps = {}
        local seen = {}

        local function addMap(rawName)
            if type(rawName) ~= "string" then return end
            local name = rawName:gsub("^%s+", ""):gsub("%s+$", "")
            if #name == 0 then return end
            local lower = name:lower()

            -- 1. TUYET DOI KHONG LAY RAID CHO MAP SELECTION
            if lower:find("raid") then return end

            -- 2. Loc bo cac UI component / template
            if lower:find("template") 
               or lower:find("frame") 
               or lower:find("scrolling") 
               or lower:find("button") 
               or lower:find("layout") 
               or lower:find("grid") 
               or lower:find("corner") 
               or lower:find("shadow") 
               or lower:find("padding") 
               or lower:find("back") 
               or lower:find("close") 
               or lower:find("textlabel") 
               or lower:find("bossrush") 
               or lower:find("speedraid") then
                return
            end

            -- 3. Chi nhan Dimension hoac Infinite Mode / TimeChallenge
            if lower:find("dimension") or lower == "infinite mode" or lower == "timechallenge" then
                if not seen[name] then
                    seen[name] = true
                    table.insert(maps, name)
                end
            end
        end

        -- Chi quet MapSelectionScrollingFrame khi o sanh thuong (PlaceId ~= 7338881230)
        if game.PlaceId ~= 7338881230 then
            pcall(function()
                local pg = localPlayer:FindFirstChild("PlayerGui")
                local mg = pg and pg:FindFirstChild("MainGui")
                local cf = mg and mg:FindFirstChild("CenterUIFrame")
                local pf = cf and cf:FindFirstChild("PlayFrame")
                local fr = pf and pf:FindFirstChild("Frame")
                local prf = fr and fr:FindFirstChild("PlayRoomFrame")
                local mapFrame = prf and prf:FindFirstChild("MapSelectionScrollingFrame")
                if mapFrame then
                    for _, v in ipairs(mapFrame:GetChildren()) do
                        if v:IsA("ImageButton") or v:IsA("TextButton") then
                            addMap(v.Name)
                        end
                    end
                end
            end)
        end

        -- Danh sach chuan cac Dimension thuong (Titan Dimension dung dau lam mac dinh farm)
        local defaultMaps = {
            "Titan Dimension",
            "Demon Dimension",
            "Dragon Dimension",
            "Hero Dimension",
            "Curse Dimension",
            "Sword Dimension",
            "Ghoul Dimension",
            "Soul Dimension",
            "Bleach Dimension",
            "Slime Dimension",
            "Fate Dimension",
            "Devil Dimension",
            "Pirate Dimension",
            "Hunter Dimension",
            "Shield Dimension",
            "Vampire Dimension",
            "Alien Dimension",
            "Chainsaw Dimension",
            "Shadow Dimension",
            "Halloween Dimension",
            "Summer Dimension",
            "Winter Dimension",
            "Infinite Mode",
            "TimeChallenge"
        }
        for _, def in ipairs(defaultMaps) do
            addMap(def)
        end

        table.sort(maps, function(a, b)
            return a:lower() < b:lower()
        end)

        return maps
    end

    local function GetAvailableRaids()
        local raids = {}
        local seen = {}

        local function addRaid(rawName)
            if type(rawName) ~= "string" then return end
            local name = rawName:gsub("^%s+", ""):gsub("%s+$", "")
            if #name == 0 then return end
            local lower = name:lower()

            -- 1. BAT BUOC LA RAID
            if not lower:find("raid") then return end

            -- 2. Loc bo cac UI component
            if lower:find("template") 
               or lower:find("frame") 
               or lower:find("scrolling") 
               or lower:find("button") 
               or lower:find("layout") 
               or lower:find("grid") 
               or lower:find("corner") 
               or lower:find("shadow") 
               or lower:find("padding") 
               or lower:find("back") 
               or lower:find("close") 
               or lower:find("textlabel") then
                return
            end

            if not seen[name] then
                seen[name] = true
                table.insert(raids, name)
            end
        end

        -- 1. Quet truc tiep tu PlayRoomFrame (uu tien khi o sanh Raid 7338881230)
        pcall(function()
            local pg = localPlayer:FindFirstChild("PlayerGui")
            local mg = pg and pg:FindFirstChild("MainGui")
            local cf = mg and mg:FindFirstChild("CenterUIFrame")
            local pf = cf and cf:FindFirstChild("PlayFrame")
            local fr = pf and pf:FindFirstChild("Frame")
            local prf = fr and fr:FindFirstChild("PlayRoomFrame")
            local mapFrame = prf and prf:FindFirstChild("MapSelectionScrollingFrame")
            if mapFrame then
                for _, v in ipairs(mapFrame:GetChildren()) do
                    if v:IsA("ImageButton") or v:IsA("TextButton") then
                        addRaid(v.Name)
                    end
                end
            end
        end)

        -- 2. Quet cac ScrollingFrame chua Raid trong PlayerGui
        pcall(function()
            local pg = localPlayer:FindFirstChild("PlayerGui")
            if pg then
                for _, d in ipairs(pg:GetDescendants()) do
                    if d:IsA("ScrollingFrame") and d.Name:lower():find("raid") then
                        for _, btn in ipairs(d:GetChildren()) do
                            if btn:IsA("ImageButton") or btn:IsA("TextButton") then
                                addRaid(btn.Name)
                            end
                        end
                    end
                end
            end
        end)

        -- 3. Danh sach day du toan bo Bi Canh Raid chuan Anime Dimensions Simulator (Fallback)
        local defaultRaids = {
            "Goddess Madoki Raid",
            "Chainsaw Raid",
            "Demon King Raid",
            "Shadow Raid",
            "Curse Raid",
            "Titan Raid",
            "Dragon Raid",
            "Fate Raid",
            "Hero Raid",
            "Jujutsu Raid",
            "Bleach Raid",
            "One Piece Raid",
            "Naruto Raid",
            "Slime Raid",
            "Halloween Raid",
            "Summer Raid",
            "Winter Raid",
            "Christmas Raid",
            "Fairy Raid",
            "Shield Raid",
            "Ghoul Raid",
            "Esper Raid",
            "Vampire Raid",
            "Alien Raid",
            "Sword Raid",
            "Hunter Raid",
            "Kaiju Raid",
            "Solo Raid",
            "Red Dragon Raid",
            "Cursed Spirit Raid",
            "Destruction Raid",
            "Slayer Raid",
            "Academy Raid",
            "Cosmic Raid",
            "Reaper Raid"
        }
        for _, def in ipairs(defaultRaids) do
            addRaid(def)
        end

        table.sort(raids, function(a, b)
            return a:lower() < b:lower()
        end)

        return raids
    end

    local function GetAvailableCapsules()
        local capsules = {}
        local seen = {}

        local function addCapsule(rawName)
            if type(rawName) ~= "string" then return end
            local name = rawName:gsub("^%s+", ""):gsub("%s+$", "")
            if #name == 0 then return end
            local lower = name:lower()
            if (lower:find("capsule") or lower:find("egg")) 
               and not lower:find("template") 
               and not lower:find("frame") 
               and not lower:find("holder") 
               and not lower:find("scroll") 
               and not lower:find("shadow") 
               and not lower:find("image") 
               and not lower:find("button") 
               and not lower:find("layout") 
               and not lower:find("corner") 
               and not lower:find("grid") then
                if not seen[name] then
                    seen[name] = true
                    table.insert(capsules, name)
                end
            end
        end

        pcall(function()
            local rep = game:GetService("ReplicatedStorage")
            for _, folder in ipairs(rep:GetChildren()) do
                local fn = folder.Name:lower()
                if fn:find("capsule") or fn:find("pet") or fn:find("egg") or fn:find("shop") or fn:find("item") then
                    for _, item in ipairs(folder:GetChildren()) do
                        addCapsule(item.Name)
                    end
                    addCapsule(folder.Name)
                end
            end
        end)

        pcall(function()
            local ws = game:GetService("Workspace")
            for _, obj in ipairs(ws:GetDescendants()) do
                if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("Configuration") then
                    if obj.Name:lower():find("capsule") then
                        addCapsule(obj.Name)
                    end
                elseif obj:IsA("TextLabel") and obj.Parent and obj.Parent:IsA("BillboardGui") then
                    if obj.Text:lower():find("capsule") then
                        local firstLine = obj.Text:split("\n")[1] or obj.Text
                        addCapsule(firstLine:gsub("%[.-%]", ""))
                    end
                end
            end
        end)

        pcall(function()
            local pgui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
            if pgui then
                for _, d in ipairs(pgui:GetDescendants()) do
                    if d.Name:lower():find("capsule") then
                        addCapsule(d.Name)
                    end
                    if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text:lower():find("capsule") then
                        local firstLine = d.Text:split("\n")[1] or d.Text
                        addCapsule(firstLine:gsub("%[.-%]", ""))
                    end
                end
            end
        end)

        local defaultCapsules = {
            "Gear 5 Fluffy Capsule",
            "Matsuri Capsule",
            "Chainsaw Capsule",
            "Shadow Capsule",
            "Demon Capsule",
            "Dragon Capsule",
            "Titan Capsule",
            "Cursed Capsule",
            "Alien Capsule",
            "Vampire Capsule",
            "Basic Capsule"
        }
        for _, def in ipairs(defaultCapsules) do
            addCapsule(def)
        end

        table.sort(capsules)
        return capsules
    end
    MapSelection = GetAvailableMaps()
    RaidSelection = GetAvailableRaids()
    PetCapsuleSelection = GetAvailableCapsules()
    _G.SelectedCapsule = PetCapsuleSelection[1] or "Gear 5 Fluffy Capsule"
    _G.RaidSelection = _G.RaidSelection or "Goddess Madoki Raid"
    _G.MapSelection = _G.MapSelection or "Titan Dimension"
    _G.PetSpinDelay = 1.0
    _G.SpinHalloweenDelay = 1.0
    _G.Method = _G.Method or "Behind"
    _G.Distance = _G.Distance or 6
    _G.TWSpeed = _G.TWSpeed or "200"
    _G.Automob = true
    _G.DistanceToSkill = _G.DistanceToSkill or 30
    _G.AutoSkill = true
    _G.AutoAssistSkill = true
    _G.AutoFruit = true
    _G.SelectAttackMethod = _G.SelectAttackMethod or "Remote"
    _G.AutoMelee = true
    _G.SkillDelay = 0.2
    _G.AssistSkillDelay = 0.8
    _G.FruitDelay = 0.8
    _G.MeleeDelay = 0.05
    _G.skill1 = _G.skill1 or "1"
    _G.skill2 = _G.skill2 or "2"
    _G.skill3 = _G.skill3 or "3"
    _G.skill4 = _G.skill4 or "4"
    _G.skill5 = _G.skill5 or "5"
    _G.KillAuraHeight = tonumber(_G.KillAuraHeight) or 35
    _G.KillAuraExtreme = true
    if getgenv then getgenv().SaveKillAuraExtreme = true end
    _G.Replay = true

    local tbSkillDelay1, tbAssistDelay1, tbFruitDelay1
    local tbSkillDelay2, tbAssistDelay2, tbFruitDelay2

    local isSyncingSkill = false
    local function setSyncSkillDelay(w, src)
        local n = tonumber(w) or 0.2
        _G.SkillDelay = n
        if not isSyncingSkill then
            isSyncingSkill = true
            local str = tostring(n)
            if src ~= 1 and tbSkillDelay1 and tbSkillDelay1.Main and tbSkillDelay1.Main.Text ~= str then
                tbSkillDelay1.Main.Text = str
                tbSkillDelay1.value = str
            end
            if src ~= 2 and tbSkillDelay2 and tbSkillDelay2.Main and tbSkillDelay2.Main.Text ~= str then
                tbSkillDelay2.Main.Text = str
                tbSkillDelay2.value = str
            end
            isSyncingSkill = false
        end
    end

    local isSyncingAssist = false
    local function setSyncAssistDelay(w, src)
        local n = tonumber(w) or 0.8
        _G.AssistSkillDelay = n
        if not isSyncingAssist then
            isSyncingAssist = true
            local str = tostring(n)
            if src ~= 1 and tbAssistDelay1 and tbAssistDelay1.Main and tbAssistDelay1.Main.Text ~= str then
                tbAssistDelay1.Main.Text = str
                tbAssistDelay1.value = str
            end
            if src ~= 2 and tbAssistDelay2 and tbAssistDelay2.Main and tbAssistDelay2.Main.Text ~= str then
                tbAssistDelay2.Main.Text = str
                tbAssistDelay2.value = str
            end
            isSyncingAssist = false
        end
    end

    local isSyncingFruit = false
    local function setSyncFruitDelay(w, src)
        local n = tonumber(w) or 0.8
        _G.FruitDelay = n
        if not isSyncingFruit then
            isSyncingFruit = true
            local str = tostring(n)
            if src ~= 1 and tbFruitDelay1 and tbFruitDelay1.Main and tbFruitDelay1.Main.Text ~= str then
                tbFruitDelay1.Main.Text = str
                tbFruitDelay1.value = str
            end
            if src ~= 2 and tbFruitDelay2 and tbFruitDelay2.Main and tbFruitDelay2.Main.Text ~= str then
                tbFruitDelay2.Main.Text = str
                tbFruitDelay2.value = str
            end
            isSyncingFruit = false
        end
    end
    local Window = library:CreateWindow("HelmHub • CỬU THIÊN VẤN ĐẠO | ".."AnimeDimensions".." |")
    local Tab1 = Window:CreateTab("Tu Tiên")
	local Sector1 = Tab1:CreateSector("Farming", "left")
    local mapDropdown = Sector1:AddDropdown("MapSelection(AutoUpdate!)", MapSelection, _G.MapSelection or "Titan Dimension", false, function(v)
        _G.MapSelection = v
    end)
    Sector1:AddButton("Quét Lại DS Map (Refresh)", function()
        MapSelection = GetAvailableMaps()
        if mapDropdown and mapDropdown.Refresh then
            mapDropdown:Refresh(MapSelection)
        end
        if Notification then
            Notification(1, "Helm Tiên Các", "Đã cập nhật " .. tostring(#MapSelection) .. " Phụ Bản Map!", 3)
        end
    end)
    Sector1:AddTextbox("Custom Map (Nhập Tên)", "", function(w)
        if w and #w > 0 then
            _G.MapSelection = w
        end
    end)
    Sector1:AddDropdown("SelectDifficulty",{"Easy" , "Hard" , "Nightmare", "Extreme" }, false ,false , function(v)
        _G.Difficulty = v
    end)
    Sector1:AddToggle("Fixed Auto Join Extreme Dimension", false, function(t)
        _G.AutoJoinExtreme = t
        if t then
            _G.Difficulty = "Extreme"
        end
    end)
    Sector1:AddDropdown("Added MinReward%", {"100%", "75%", "50%", "25%", "15%"}, "100%", false, function(v)
        _G.MinRewardPercent = v
    end)
    Sector1:AddTextbox("WaitOnLobbyAfterJoin(OnlyNumber)" , "10" , function(w)
        _G.CooldownOnlobby = w
    end)
    Sector1:AddToggle("AutoPlay", false, function(t)
		_G.AutoPlay = t
	end)
    Sector1:AddToggle("Hardcore", false, function(t)
		_G.Hardcore = t
	end)
    Sector1:AddToggle("AutoReplay", true, function(t)
		_G.Replay = t
	end)
    Sector1:AddToggle("FriendOnly", false, function(t)
		_G.FriendOnly = t
	end)
    Sector1:AddToggle("AutoSelectMap(DetectedLevel)", false, function(t)
		_G.AutoSelectMap = t
	end)
    Sector1:AddToggle("GetAllDimensionCharacter", false, function(t)
		_G.GetAllDimensionCharacter = t
	end)


    local Sector2 = Tab1:CreateSector("InGame", "Right")
    Sector2:AddDropdown("Method",{"Behind" , "Front" , "Over" , "Under" }, "Behind" ,false , function(v)
        _G.Method = v
    end)
    Sector2:AddTextbox("ImportDistance(OnlyNumber)" , "6" , function(w)
        _G.Distance = tonumber(w)
    end)
    Sector2:AddTextbox("TweenSpeed(OnlyNumber)" , "200" , function(w)
        _G.TWSpeed = w
    end)
	Sector2:AddToggle("AutoMob", true, function(t)
		_G.Automob = t
	end)
    Sector2:AddTextbox("DistanceToSkill(OnlyNumber)" , "30" , function(w)
        _G.DistanceToSkill = tonumber(w)
    end)
    tbSkillDelay1 = Sector2:AddTextbox("SkillDelay(Sec)" , tostring(_G.SkillDelay or 0.2) , function(w)
        setSyncSkillDelay(w, 1)
    end)
    tbAssistDelay1 = Sector2:AddTextbox("AssistDelay(Sec)" , tostring(_G.AssistSkillDelay or 0.8) , function(w)
        setSyncAssistDelay(w, 1)
    end)
    tbFruitDelay1 = Sector2:AddTextbox("FruitDelay(Sec)" , tostring(_G.FruitDelay or 0.8) , function(w)
        setSyncFruitDelay(w, 1)
    end)
    Sector2:AddToggle("AutoSkill", true, function(t)
		_G.AutoSkill = t
	end)
    Sector2:AddToggle("AutoAssistSkill", true, function(t)
		_G.AutoAssistSkill = t
	end)
	Sector2:AddToggle("AutoFruit", true, function(t)
		_G.AutoFruit = t
	end)
    Sector2:AddDropdown("SelectAttackMethod",{"Remote" , "Click" }, "Remote" ,false , function(v)
        _G.SelectAttackMethod = v
    end)
    Sector2:AddToggle("AutoMelee", true, function(t)
		_G.AutoMelee = t
	end)
    local killAuraToggleObj = nil
    killAuraToggleObj = Sector2:AddToggle("Kill Aura (Only Extreme Dimension)", true, function(t)
        _G.KillAuraExtreme = t
        if getgenv then
            getgenv().SaveKillAuraExtreme = t
        end
        if not t then
            pcall(function()
                local char = game.Players.LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Anchored = false end
            end)
        end
    end)
    Sector2:AddTextbox("Kill Aura Height (Y)", tostring(_G.KillAuraHeight or 35), function(w)
        _G.KillAuraHeight = tonumber(w) or 35
    end)
    Sector2:AddTextbox("MeleeDelay(Sec)", "0.05", function(w)
        _G.MeleeDelay = tonumber(w) or 0.05
    end)

    local Tab2 = Window:CreateTab("Phụ Trợ")
    local SectorRaid = Tab2:CreateSector("Phụ Bản Raid (Auto Raid)", "left")
    SectorRaid:AddLabel("Chọn Bí Cảnh Raid", true)
    local raidDropdown = SectorRaid:AddDropdown("Bí Cảnh Raid", RaidSelection, _G.RaidSelection or RaidSelection[1] or "Goddess Madoki Raid", false, function(v)
        _G.RaidSelection = v
    end)
    SectorRaid:AddButton("Quét Lại DS Raid (Refresh)", function()
        RaidSelection = GetAvailableRaids()
        if raidDropdown and raidDropdown.Refresh then
            raidDropdown:Refresh(RaidSelection)
        end
        if Notification then
            Notification(1, "Helm Tiên Các", "Đã cập nhật " .. tostring(#RaidSelection) .. " Bí Cảnh Raid!", 3)
        end
    end)
    SectorRaid:AddTextbox("Custom Raid (Nhập Tên)", "", function(w)
        if w and #w > 0 then
            _G.RaidSelection = w
            if Notification then
                Notification(1, "Helm Tiên Các", "Đã chọn Custom Raid: " .. tostring(w), 3)
            end
        end
    end)
    SectorRaid:AddTextbox("Cooldown JoinRaid (Giây)", "10", function(w)
        _G.waitonJoinRiad = w
    end)
    SectorRaid:AddToggle("AutoRaid", false, function(t)
		_G.AutoRaid = t
	end)
    SectorRaid:AddToggle("FreeBossRush", false, function(t)
		_G.FreeBossRush = t
	end)
    SectorRaid:AddToggle("BossRush", false, function(t)
		_G.BossRush = t
	end)
    SectorRaid:AddToggle("AutoSpeedRaid(RandomSelect)", false, function(t)
		_G.AutoSpeedRaid = t
	end)
    SectorRaid:AddToggle("AutoTraitTokens(Need LV:20)", false, function(t)
		_G.AutoTraitTokens = t
	end)
    local SectorMadoki = Tab2:CreateSector("Bí Cảnh Madoki (Event Raid)", "left")
    SectorMadoki:AddToggle("MadokiRaid(Need Raid Token)", false, function(t)
		_G.AutoMadokiRaid = t
	end)
    SectorMadoki:AddToggle("JoinMadokiRaid(AutoJoinRaidLobby)", false, function(t)
		_G.AutoJoinMadokiRaid = t
	end)
    local Sector4 = Tab2:CreateSector("MoreFunction", "Right")
    Sector4:AddToggle("AutoDodgeSkill", false, function(t)
		_G.AutoDodgeSkill = t
	end)
    Sector4:AddToggle("BackToLobbyIfGotExploitsDetected", false, function(t)
		_G.BackToLobbyIfGotExploitsDetected = t
	end)
    Sector4:AddToggle("HideName", false, function(t)
        _G.HideName = t
    end)
    Sector4:AddToggle("DashNoCooldown", false, function(t)
        _G.DashNoCooldown = t
    end)
    Sector4:AddToggle("AutoWalk(Only Boss)", false, function(t)
        _G.AutoWalk = t
    end)
    Sector4:AddToggle("AutoClaimQuestAndReward", false, function(t)
		_G.AutoClaimQuestAndReward = t
	end)
    Sector4:AddDropdown("GoLobbyMethod",{"ResetCharacter" , "TeleportToLobby" }, false ,false , function(v)
        _G.GoLobbyMethod = v
    end)
    Sector4:AddToggle("BackToLobbyIfRaidOpen", false, function(t)
		_G.OnRaidOpen = t
	end)
    Sector4:AddToggle("StopReplayIfRaidOpen", false, function(t)
		_G.StopReplay = t
	end)
    Sector4:AddToggle("Disable Noclip", false, function(t)
		_G.DontNoclip = t
	end)
    Sector4:AddToggle("DoNotThingIfHavePlayer", false, function(t)
		_G.DoNotThingIfHavePlayer = t
	end)
    local Config = {}
    function Save_Config()
        pcall(function()
            if writefile then
                writefile("Character_Helm.json", game:GetService("HttpService"):JSONEncode(Config))
            end
            for i, v in pairs(Config) do
                if Notification then
                    Notification(1, "HelmHub", ("ConfigSaved: " .. tostring(i) .. " " .. tostring(v)), 5)
                end
                wait(0.5)
            end
        end)
    end

    pcall(function()
        if isfile and isfile("Character_Helm.json") then
            Config = game:GetService("HttpService"):JSONDecode(readfile("Character_Helm.json"))
        end
    end)



    local Tab3 = Window:CreateTab("Đạo Thân")
    local Sector1 = Tab3:CreateSector("AutoEquip", "left")
    Sector1:AddToggle("AutoEquip Character", false, function(t)
		_G.AutoEquipCharacter = t
	end)
    Sector1:AddButton("SaveCharacter" , function()
        Config["Character1"] = game:GetService("ReplicatedStorage")[game.Players.LocalPlayer.Name.."StatDisplay"].CharacterName.Value
        Config["Character2"] = game:GetService("ReplicatedStorage")[game.Players.LocalPlayer.Name.."StatDisplay"].AssistCharacterName1.Value
        Config["Character3"] = game:GetService("ReplicatedStorage")[game.Players.LocalPlayer.Name.."StatDisplay"].AssistCharacterName2.Value
        Save_Config()
    end)
	
	Sector1:AddToggle("Auto Change Main Character", false, function(t)
		_G.AutoMainCharacter = t
		
		local function autoMainCharacter()
			if _G.autoMainC == true then return end
			_G.autoMainC = false

			local respawnTimer;
			for i,v in pairs(game:GetService('Players').LocalPlayer.PlayerGui:GetDescendants()) do
				if v.Name == 'RespawnTimerFrame' then 
					respawnTimer = v
				end
			end

			local waitLimit = tick() + 8
			repeat
				for _, v in pairs(game:GetService('Players').LocalPlayer.PlayerGui:GetDescendants()) do
					if v.Name == 'RespawnTimerFrame' then respawnTimer = v break end
				end
				if not respawnTimer then task.wait(0.5) end
			until respawnTimer ~= nil or tick() > waitLimit
			if not respawnTimer then return end

			if _G.AutoMainCharacter == true then
				local resetTime = 0
				local a={['Main']=0,['Assist1']=1,['Assist2']=2};
				local connection;
				
				if _G.MainChar then
					if a[_G.MainChar] >0 then
					
						local function resetChar()
							local s, e = pcall(function() game.Players.LocalPlayer.Character.Humanoid.Health=0; end)
							if not s then print(e) end
							resetTime = resetTime + 1
						end
						if resetTime ~= a[_G.MainChar] and resetTime < a[_G.MainChar] then
							resetChar()
						end
						
						connection = respawnTimer.Changed:Connect(function()
							if not _G.AutoMainCharacter then connection:Disconnect(); return end
							if respawnTimer.Visible == false then
								if resetTime ~= a[_G.MainChar] and resetTime < a[_G.MainChar] then
									resetChar()
								elseif resetTime == a[_G.MainChar] then
									print('Main Character Success.')
									connection:Disconnect()
								end
							end
						end)
					end
				end
			end

		end
		
		if t then
			if game.PlaceId == 6938803436 or game.PlaceId == 7274690025 or game.PlaceId == 7338881230 then return end
			task.spawn(autoMainCharacter)
		end
	end)
	Sector1:AddDropdown("SelectChar", {"Main", "Assist1", "Assist2"}, "Main", false, function(v)
		_G.MainChar = v
	end)
	


    local Tab9 = Window:CreateTab("Thiết Lập")
    local Sector1 = Tab9:CreateSector("Setting DodgeSkill", "left")
    Sector1:AddTextbox("SizeDodgePart (OnlyNumber)" , "3.5" , function(w)
        _G.SizeDodgePart = w
    end)
    Sector1:AddTextbox("SizeDodgePart Y (OnlyNumber)" , "100" , function(w)
        _G.SizeDodgePartY = w
    end)
    Sector1:AddTextbox("TweenSpeedDodgePart (Sec)" , "0.25" , function(w)
        _G.TweenDodgePart = w
    end)
    Sector1:AddTextbox("DodgePartTransparency (OnlyNumber)" , "0.9" , function(w)
        _G.DodgePartTransparency = w
    end)
    local Sector5 = Tab9:CreateSector("MoreFunction2", "left")
    Sector5:AddToggle("Go AFK (If Raid Not Open)", false, function(t)
		_G.AutoGoAFK = t
	end)
    Sector5:AddTextbox("SelectWaveToReset" , "100" , function(w)
        _G.SelectWaveToEnd = w
    end)
    Sector5:AddToggle("Reset INF Mode (SelectWave)", false, function(t)
		_G.ResetifWave = t
	end)
    local Sector1 = Tab9:CreateSector("Setting AutoSkill", "Right")
    tbSkillDelay2 = Sector1:AddTextbox("SkillDelay(Sec)" , tostring(_G.SkillDelay or 0.2) , function(w)
        setSyncSkillDelay(w, 2)
    end)
    tbAssistDelay2 = Sector1:AddTextbox("AssistDelay(Sec)" , tostring(_G.AssistSkillDelay or 0.8) , function(w)
        setSyncAssistDelay(w, 2)
    end)
    tbFruitDelay2 = Sector1:AddTextbox("FruitDelay(Sec)" , tostring(_G.FruitDelay or 0.8) , function(w)
        setSyncFruitDelay(w, 2)
    end)
    Sector1:AddTextbox("MeleeDelay(Sec)" , "0.05" , function(w)
        _G.MeleeDelay = tonumber(w) or 0.05
    end)
    Sector1:AddDropdown("SkillFirst",{"1","2","3","4","5"},"4",false , function(v)
        _G.skill1 = v
    end)
    Sector1:AddDropdown("SkillSecond",{"1","2","3","4","5"},"3",false , function(v)
        _G.skill2 = v
    end)
    Sector1:AddDropdown("SkillThird",{"1" , "2" , "3", "4","5"},"5",false , function(v)
        _G.skill3 = v
    end)
    Sector1:AddDropdown("SkillFourth",{"1","2","3","4","5"}, "1" ,false , function(v)
        _G.skill4 = v
    end)
    Sector1:AddDropdown("SkillFifth",{"1","2","3","4","5"}, "2" ,false , function(v)
        _G.skill5 = v
    end)
    local Tab10 = Window:CreateTab("Tàng Bảo Các")
	local Sector1 = Tab10:CreateSector("Tàng Bảo Sảnh (Shop & Keys)", "left")
    Sector1:AddDropdown("Loại Tiền Mua Vé",{"(Raid)" , "(Gem)"}, false ,false , function(v)
        _G.methodbuy = v
    end)
    Sector1:AddToggle("Tự Mua Boss Rush Ticket", false, function(t)
		_G.BuyRushTicket = t
	end)
    Sector1:AddToggle("Tự Mua Madoki Raid Key", false, function(t)
		_G.BuyKey = t
	end)

    local SectorPet = Tab10:CreateSector("Linh Thú Các (Pet Gacha)", "left")
    local petDropdown = SectorPet:AddDropdown("Chọn Capsule (AutoUpdate)", PetCapsuleSelection, PetCapsuleSelection[1] or "Gear 5 Fluffy Capsule", false, function(v)
        _G.SelectedCapsule = v
    end)
    SectorPet:AddButton("Quét Lại DS Capsule", function()
        PetCapsuleSelection = GetAvailableCapsules()
        if petDropdown and petDropdown.Refresh then
            petDropdown:Refresh(PetCapsuleSelection)
        end
        if Notification then
            Notification(1, "Helm Tiên Các", "Đã cập nhật " .. tostring(#PetCapsuleSelection) .. " Pet Capsules!", 3)
        end
    end)
    SectorPet:AddTextbox("Custom Capsule (Nhập Tên)", "", function(w)
        if w and #w > 0 then
            _G.SelectedCapsule = w
        end
    end)
    SectorPet:AddButton("Mua Pet (x1)", function()
        pcall(function()
            local cap = _G.SelectedCapsule or "Gear 5 Fluffy Capsule"
            game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("BuyEgg", cap)
        end)
    end)
    SectorPet:AddButton("Mua Pet (x4)", function()
        pcall(function()
            local cap = _G.SelectedCapsule or "Gear 5 Fluffy Capsule"
            game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("Buy4Pets", cap)
        end)
    end)
    SectorPet:AddTextbox("Nhịp Mua Pet (Sec)", "1.0", function(w)
        _G.PetSpinDelay = tonumber(w) or 1.0
    end)
    SectorPet:AddToggle("Tự Động Mua Pet (x1)", false, function(t)
        _G.AutoBuyPet1 = t
    end)
    SectorPet:AddToggle("Tự Động Mua Pet (x4)", false, function(t)
        _G.AutoBuyPet4 = t
    end)

    local SectorFruit = Tab10:CreateSector("Trái Tiên Các (Fruit Gacha)", "Right")
    SectorFruit:AddButton("Quay Fruit (x1)", function()
        pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("BuyFruit", "BasicFruitGacha")
        end)
    end)
    SectorFruit:AddButton("Quay Fruit (x4)", function()
        pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("BuyFruitQuad", "BasicFruitGacha")
        end)
    end)
    SectorFruit:AddTextbox("Nhịp Quay Fruit (Sec)", "1.0", function(w)
        _G.SpinFruitDelay = tonumber(w) or 1.0
    end)
    SectorFruit:AddToggle("Tự Động Quay Fruit (x1)", false, function(t)
        _G.AutoSpinFruit1 = t
    end)
    SectorFruit:AddToggle("Tự Động Quay Fruit (x4)", false, function(t)
        _G.AutoSpinFruit4 = t
    end)

    local SectorHalloween = Tab10:CreateSector("Bí Ngô Lễ Hội (Halloween Event)", "Right")
    SectorHalloween:AddButton("Quay Event (x1)", function()
        pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("SpinEventReward", "HalloweenEventSettings")
        end)
    end)
    SectorHalloween:AddButton("Quay Event (x4)", function()
        pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("QuadEventSpin", "HalloweenEventSettings")
        end)
    end)
    SectorHalloween:AddTextbox("Nhịp Quay Event (Sec)", "1.0", function(w)
        _G.SpinHalloweenDelay = tonumber(w) or 1.0
    end)
    SectorHalloween:AddToggle("Tự Động Quay Event (x1)", false, function(t)
        _G.AutoSpinHalloween1 = t
    end)
    SectorHalloween:AddToggle("Tự Động Quay Event (x4)", false, function(t)
        _G.AutoSpinHalloween4 = t
    end)

    local function PlayerDetect()
        local Players = game.Players:GetPlayers()
        return tonumber(#Players)
    end
    -- Tu dong theo doi va cap nhat dropdown khi giao dien Map/Raid xuat hien
    task.spawn(function()
        pcall(function()
            local pg = localPlayer:WaitForChild("PlayerGui", 10)
            if not pg then return end

            local function onMapFrameDetected(mf)
                if not mf then return end
                task.wait(0.3)
                if game.PlaceId == 7338881230 then
                    RaidSelection = GetAvailableRaids()
                    if raidDropdown and raidDropdown.Refresh then
                        raidDropdown:Refresh(RaidSelection)
                    end
                else
                    MapSelection = GetAvailableMaps()
                    if mapDropdown and mapDropdown.Refresh then
                        mapDropdown:Refresh(MapSelection)
                    end
                end

                mf.ChildAdded:Connect(function(c)
                    if (c:IsA("ImageButton") or c:IsA("TextButton")) and c.Name ~= "MapSelectionTemplate" then
                        task.wait(0.2)
                        if game.PlaceId == 7338881230 then
                            RaidSelection = GetAvailableRaids()
                            if raidDropdown and raidDropdown.Refresh then
                                raidDropdown:Refresh(RaidSelection)
                            end
                        else
                            MapSelection = GetAvailableMaps()
                            if mapDropdown and mapDropdown.Refresh then
                                mapDropdown:Refresh(MapSelection)
                            end
                        end
                    end
                end)
            end

            local mg = pg:FindFirstChild("MainGui")
            local cf = mg and mg:FindFirstChild("CenterUIFrame")
            local pf = cf and cf:FindFirstChild("PlayFrame")
            local fr = pf and pf:FindFirstChild("Frame")
            local prf = fr and fr:FindFirstChild("PlayRoomFrame")
            local mf = prf and prf:FindFirstChild("MapSelectionScrollingFrame")
            if mf then
                onMapFrameDetected(mf)
            end

            pg.DescendantAdded:Connect(function(desc)
                if desc.Name == "MapSelectionScrollingFrame" and desc:IsA("ScrollingFrame") then
                    onMapFrameDetected(desc)
                end
            end)
        end)
    end)

    spawn(function()
        pcall(function()
            while task.wait() do
                pcall(function()
                    if tonumber(os.date("!*t").min) <= 9 then
                        _G.RaidOpened = true
                    else
                        _G.RaidOpened = false
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while wait(1) do
                spawn(function()
                    if _G.BuyRushTicket == true then
                        game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer({[1] = "BuyBossRushShopItem",[2] = "Boss Rush Ticket ".._G.methodbuy})
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while wait(1) do
                spawn(function()
                    if _G.BuyKey == true then
                        game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer({[1] = "BuyRaidShopItem",[2] = "Madoki Raid Key (2 Per Day)"})
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while task.wait(0.2) do
                pcall(function()
                    if _G.AutoSpinFruit1 == true then
                        game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("BuyFruit", "BasicFruitGacha")
                        task.wait(tonumber(_G.SpinFruitDelay or 1.0))
                    elseif _G.AutoSpinFruit4 == true then
                        game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("BuyFruitQuad", "BasicFruitGacha")
                        task.wait(tonumber(_G.SpinFruitDelay or 1.0))
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while task.wait(0.2) do
                pcall(function()
                    if _G.AutoBuyPet1 == true then
                        local cap = _G.SelectedCapsule or "Gear 5 Fluffy Capsule"
                        game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("BuyEgg", cap)
                        task.wait(tonumber(_G.PetSpinDelay or 1.0))
                    elseif _G.AutoBuyPet4 == true then
                        local cap = _G.SelectedCapsule or "Gear 5 Fluffy Capsule"
                        game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("Buy4Pets", cap)
                        task.wait(tonumber(_G.PetSpinDelay or 1.0))
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while task.wait(0.2) do
                pcall(function()
                    if _G.AutoSpinHalloween1 == true then
                        game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("SpinEventReward", "HalloweenEventSettings")
                        task.wait(tonumber(_G.SpinHalloweenDelay or 1.0))
                    elseif _G.AutoSpinHalloween4 == true then
                        game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("QuadEventSpin", "HalloweenEventSettings")
                        task.wait(tonumber(_G.SpinHalloweenDelay or 1.0))
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while task.wait() do
                task.spawn(function()
                    if _G.AutoJoinMadokiRaid == true then
                        for _,v in pairs(game.Players.LocalPlayer.PlayerGui.MainGui.CenterUIFrame.PlayFrame.Frame.PlayRoomFrame.PlayRoomScrollingFrame:GetChildren()) do
                            if v.Name == "Goddess Madoki RaidEasy" and v.Players.Text ~= "Players: 5/5" and v.FriendsOnly.Visible == false then
                                for _,vv in pairs({"MouseButton1Click"}) do
                                    firesignal(v.JoinButton[vv])
                                end
                            end
                        end
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while task.wait() do
                pcall(function()
                    if tonumber(#game.Players:GetPlayers()) > 1 then
                        _G.CheckPlayer = true
                    else
                        _G.CheckPlayer = false
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while wait(1) do
                pcall(function()
                    if _G.AutoJoinMadokiRaid == true then
                        if game:GetService("Players").LocalPlayer.PlayerGui.BattleGui.CenterUIFrame.RaidDataFrame.Visible == false and game:GetService("Players").LocalPlayer.PlayerGui.BattleGui.CenterUIFrame.BossHealthFrame.Visible == false then
                            if game.PlaceId ~= 7338881230 and game.PlaceId ~= 6990129309 then
                                game:GetService("TeleportService"):Teleport(7338881230)
                                wait(10)
                            end
                        end
                    end
                end)
            end
        end)
    end)

    local function getMobHumanoid(v)
        if not v or not v.Parent then return nil end
        local hum = v:FindFirstChild("Monster")
        if hum and hum:IsA("Humanoid") then return hum end
        hum = v:FindFirstChildOfClass("Humanoid")
        if hum and hum:IsA("Humanoid") then return hum end
        return nil
    end

    local deadEntities = {}

    local function isAliveMob(v)
        if not v or not v.Parent then return false end
        if deadEntities[v] then return false end

        local hrp = v:FindFirstChild("HumanoidRootPart")
        if not hrp or not hrp.Parent then return false end

        -- Quái hoặc Boss đã rớt xuống vực / văng khỏi map
        if hrp.Position.Y < -80 then
            deadEntities[v] = true
            return false
        end

        local hum = getMobHumanoid(v)
        if hum then
            -- 1. Trạng thái chết (Dead state) - Nhận diện Boss đã chết nhưng UI thanh máu chưa tắt
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Dead then
                deadEntities[v] = true
                return false
            end

            -- 2. Máu <= 0
            local hp = tonumber(hum.Health)
            if hp and hp <= 0 then
                deadEntities[v] = true
                return false
            end

            return true
        end

        return false
    end

    local function getCurrentTarget()
        local char = game.Players.LocalPlayer.Character
        local myHrp = char and char:FindFirstChild("HumanoidRootPart")
        if not myHrp then return nil end

        local monstersFolder = workspace:FindFirstChild("Folders") and workspace.Folders:FindFirstChild("Monsters")
        if not monstersFolder then return nil end

        local closestDist = math.huge
        local closestTarget = nil

        for _, v in ipairs(monstersFolder:GetChildren()) do
            if isAliveMob(v) then
                local hrp = v:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (myHrp.Position - hrp.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestTarget = v
                    end
                end
            end
        end

        return closestTarget
    end

    local function getClosestMob()
        return getCurrentTarget()
    end

    function getClosestBoss()
        return getCurrentTarget()
    end

    function walk(P)
        if game:GetService("Players").LocalPlayer.PlayerGui.BattleGui.CenterUIFrame.RaidDataFrame.Visible == true and _G.DoNotThingIfHavePlayer == true and _G.CheckPlayer == true then
        else
            game.Players.LocalPlayer.Character.Humanoid.WalkToPoint = (P.HumanoidRootPart.Position)
        end
    end

    function Tween(P)
        if game:GetService("Players").LocalPlayer.PlayerGui.BattleGui.CenterUIFrame.RaidDataFrame.Visible == true and _G.DoNotThingIfHavePlayer == true and _G.CheckPlayer == true then
        else
            game:GetService("TweenService"):Create(game.Players.LocalPlayer.Character.HumanoidRootPart,TweenInfo.new((getClosestMob().HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude/tonumber(_G.TWSpeed), Enum.EasingStyle.Linear),{CFrame = P}):Play()
        end
    end

    local comboIndex = 0
    function melee()
        if _G.AutoMelee ~= true then return end
        if _G.KillAuraExtreme == true and isExtremeDimension() then return end
        local mob = getCurrentTarget()
        if not mob or not mob:FindFirstChild("HumanoidRootPart") then return end

        if _G.SelectAttackMethod == "Remote" then
            comboIndex = (comboIndex % 4) + 1
            local char = game.Players.LocalPlayer.Character
            local isBow = char and char:FindFirstChild("Bow")
            local targetPos = mob.HumanoidRootPart.Position
            local payload = {
                ["hrpCFrame"] = CFrame.new(targetPos),
                ["attackNumber"] = comboIndex,
                ["combo"] = isBow and 3 or comboIndex
            }
            game:GetService("ReplicatedStorage").RemoteEvents.MainRemoteEvent:FireServer("UseSkill", payload, "BasicAttack")
        elseif _G.SelectAttackMethod == "Click" then
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.01)
            vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end
    end

    local lastSkillTime = 0
    local function canUseSkill(skillNum)
        if not skillNum then return false end
        local pgui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        if not pgui then return false end
        local uGui = pgui:FindFirstChild("UniversalGui")
        if not uGui then return false end
        local holder = uGui:FindFirstChild("UniversalCenterUIFrame") and uGui.UniversalCenterUIFrame:FindFirstChild("SlotsHolder")
        if not holder then return false end

        local slot = holder:FindFirstChild("Skill" .. tostring(skillNum))
        if not slot or slot.Visible == false then return false end
        local sName = slot:FindFirstChild("SkillName")
        if not sName then return false end

        local cd = tonumber(sName.Text)
        return (cd == nil or cd <= 0)
    end

    function skill()
        if _G.AutoSkill ~= true then return end
        if _G.KillAuraExtreme == true and isExtremeDimension() then return end
        local delay = tonumber(_G.SkillDelay or 0.2)
        if (tick() - lastSkillTime) < delay then return end

        local mob = getCurrentTarget()
        if not mob or not mob:FindFirstChild("HumanoidRootPart") then return end

        local order = {_G.skill1, _G.skill2, _G.skill3, _G.skill4, _G.skill5}
        for _, s in ipairs(order) do
            if s and canUseSkill(s) then
                game:GetService("ReplicatedStorage").RemoteEvents.MainRemoteEvent:FireServer(
                    "UseSkill",
                    {["hrpCFrame"] = CFrame.new(mob.HumanoidRootPart.Position)},
                    tonumber(s)
                )
                lastSkillTime = tick()
                break
            end
        end
    end

    function skillmelee()
        if _G.AutoSkill == true then
            skill()
        end
        if _G.AutoMelee == true then
            melee()
        end
    end

    -- ===================================================================================
    -- HELMHUB | EXTREME DIMENSION INSTANT KILL AURA ENGINE (MAX SPEED & ZERO LATENCY)
    -- Tác giả: dj & VANTA
    -- Tự động kích hoạt khi vào map, tối ưu triệt để đợt quái đầu tiên
    -- ===================================================================================
    local killAuraCombo = 0
    local lastKillSkillTick = 0

    local function eradicateMob(mob, hum, hrp)
        pcall(function()
            hrp.CanCollide = false
            if sethiddenproperty then
                pcall(function() sethiddenproperty(hrp, "NetworkIsSleeping", false) end)
            end

            -- Ép Roblox Physics Engine chuyển giao quyền Network Ownership ngay lập tức qua va chạm ảo
            local char = game.Players.LocalPlayer.Character
            local myHrp = char and char:FindFirstChild("HumanoidRootPart")
            if firetouchinterest and myHrp then
                pcall(function()
                    firetouchinterest(myHrp, hrp, 0)
                    firetouchinterest(myHrp, hrp, 1)
                end)
            end

            -- Triệt tiêu sinh mệnh quái ngay lập tức
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.Dead)
                hum.Health = 0
            end)
        end)
    end

    spawn(function()
        pcall(function()
            local remoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("MainRemoteEvent")

            while task.wait(0.03) do
                pcall(function()
                    if _G.KillAuraExtreme ~= true then return end
                    if not isExtremeDimension() then return end
                    if game.PlaceId == 6938803436 or game.PlaceId == 7274690025 or game.PlaceId == 7338881230 then return end

                    local bg = game.Players.LocalPlayer:FindFirstChild("PlayerGui") and game.Players.LocalPlayer.PlayerGui:FindFirstChild("BattleGui")
                    local rdf = bg and bg:FindFirstChild("CenterUIFrame") and bg.CenterUIFrame:FindFirstChild("RaidDataFrame")
                    if rdf and rdf.Visible == true and _G.DoNotThingIfHavePlayer == true and _G.CheckPlayer == true then
                        return
                    end

                    local monstersFolder = workspace:FindFirstChild("Folders") and workspace.Folders:FindFirstChild("Monsters")
                    if not monstersFolder then return end

                    local mobs = monstersFolder:GetChildren()
                    local char = game.Players.LocalPlayer.Character
                    local myHrp = char and char:FindFirstChild("HumanoidRootPart")
                    if not myHrp then return end

                    for _, mob in ipairs(mobs) do
                        if isAliveMob(mob) then
                            local hrp = mob:FindFirstChild("HumanoidRootPart")
                            local hum = getMobHumanoid(mob)
                            if hrp and hum then
                                local dist = (myHrp.Position - hrp.Position).Magnitude
                                -- Server Anime Dimensions giới hạn cự ly đánh < 60 studs
                                if dist < 58 then
                                    local targetPos = hrp.Position
                                    killAuraCombo = (killAuraCombo % 4) + 1

                                    -- 1. Triệt tiêu tức thì qua Network Ownership & Physics Injection
                                    eradicateMob(mob, hum, hrp)

                                    -- 2. Remote Attack Strike trực tiếp vào vị trí quái (Sát thương Server)
                                    local payload = {
                                        ["hrpCFrame"] = CFrame.new(targetPos),
                                        ["attackNumber"] = killAuraCombo,
                                        ["combo"] = 3
                                    }
                                    remoteEvent:FireServer("UseSkill", payload, "BasicAttack")

                                    -- 3. Xả dồn 4 Skill AoE liên tục không ngắt quãng (giảm hồi chiêu xuống 0.1s)
                                    if (tick() - lastKillSkillTick) >= 0.1 then
                                        lastKillSkillTick = tick()
                                        for sNum = 1, 4 do
                                            pcall(function()
                                                local sPayload = {
                                                    ["hrpCFrame"] = CFrame.new(targetPos),
                                                    ["skillNumber"] = sNum
                                                }
                                                remoteEvent:FireServer("UseSkill", sPayload, tostring(sNum))
                                            end)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end)
    end)

    spawn(function()
        pcall(function()
            while task.wait(tonumber(_G.MeleeDelay or 0.05)) do
                pcall(function()
                    if game:GetService("Players").LocalPlayer.PlayerGui.BattleGui.CenterUIFrame.RaidDataFrame.Visible == true and _G.DoNotThingIfHavePlayer == true and _G.CheckPlayer == true then
                    else
                        local mob = getClosestMob()
                        if mob and mob:FindFirstChild("HumanoidRootPart") and game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            Distance = (mob.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                            if game.PlaceId ~= 6938803436 and game.PlaceId ~= 7274690025 and game.PlaceId ~= 7338881230 and Distance <= tonumber(_G.DistanceToSkill or 30) then
                                if _G.AutoMelee == true and _G.AutoSkill == true then
                                    skillmelee()
                                elseif _G.AutoMelee == true and _G.AutoSkill == false then
                                    melee()
                                elseif _G.AutoMelee == false and _G.AutoSkill == true then
                                    skill()
                                end
                            end
                        end
                    end
                end)
            end
        end)
    end)
    
    spawn(function()
        pcall(function()
            while wait(1) do
                pcall(function()
                    Distance = (getClosestMob().HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                    if game.PlaceId ~= 6938803436 and game.PlaceId ~= 7274690025 and game.PlaceId ~= 7338881230 then
                        if Distance > 500 then
                            if workspace.GameMap:FindFirstChild("Curse Dimension") then
                                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.GameMap["Curse Dimension"].CurseTeleportDestination.CFrame
                            elseif workspace.GameMap:FindFirstChild("Fate Dimension") then
                                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.GameMap["Fate Dimension"].CenterTeleportDestination.CFrame
                            elseif workspace.GameMap:FindFirstChild("Pirate Dimension") then
                                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.GameMap["Pirate Dimension"].Part2TeleportDestination.CFrame
                            end
                        end
                    end
                end)
            end
        end)
    end)
    -- Bo dieu phoi luan phien: Chuyen doi qua lai giua Fruit va AutoAssistSkill
    local lastAltActionTime = 0
    local altTurn = "Fruit" -- Luan phien: Fruit -> Assist -> Fruit -> Assist
    local nextFruitSlot = 1
    local nextAssistSlot = 1

    local function castFruit(fr)
        if not fr then return end
        local events = { "MouseButton1Click", "MouseButton1Down", "Activated" }
        for _, ev in ipairs(events) do
            pcall(function() firesignal(fr[ev]) end)
        end
    end

    local function castAssist(slotNum, mob)
        if not slotNum or not mob or not mob:FindFirstChild("HumanoidRootPart") then return end
        game:GetService("ReplicatedStorage").RemoteEvents.MainRemoteEvent:FireServer(
            "UseAssistSkill",
            {["hrpCFrame"] = CFrame.new(mob.HumanoidRootPart.Position)},
            slotNum
        )
    end

    spawn(function()
        pcall(function()
            while wait(0.08) do
                pcall(function()
                    if game.PlaceId == 6938803436 or game.PlaceId == 7274690025 or game.PlaceId == 7338881230 then return end
                    if _G.AutoFruit ~= true and _G.AutoAssistSkill ~= true then return end

                    local mob = getClosestMob()
                    if not mob or not mob:FindFirstChild("HumanoidRootPart") or not game.Players.LocalPlayer.Character or not game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
                    local dist = (mob.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                    if dist > tonumber(_G.DistanceToSkill or 30) then return end

                    local plr = game:GetService("Players").LocalPlayer
                    local pg = plr:FindFirstChild("PlayerGui")
                    if not pg then return end

                    -- Kiem tra trang thai Fruit (SkillFruit1, SkillFruit2)
                    local fr1 = pg:FindFirstChild("SkillFruit1", true)
                    local fr2 = pg:FindFirstChild("SkillFruit2", true)
                    local cdF1 = fr1 and fr1:FindFirstChild("SkillName")
                    local cdF2 = fr2 and fr2:FindFirstChild("SkillName")
                    local f1Ready = (fr1 and cdF1 and cdF1.Visible == false)
                    local f2Ready = (fr2 and cdF2 and cdF2.Visible == false)
                    local hasFruitReady = f1Ready or f2Ready

                    -- Kiem tra trang thai Assist (SkillAssist1, SkillAssist2)
                    local uGui = pg:FindFirstChild("UniversalGui")
                    local holder = uGui and uGui:FindFirstChild("UniversalCenterUIFrame") and uGui.UniversalCenterUIFrame:FindFirstChild("SlotsHolder")
                    local cdA1 = holder and holder:FindFirstChild("SkillAssist1") and tonumber(holder.SkillAssist1.SkillName.Text)
                    local cdA2 = holder and holder:FindFirstChild("SkillAssist2") and tonumber(holder.SkillAssist2.SkillName.Text)
                    local a1Ready = (holder and holder:FindFirstChild("SkillAssist1") and (cdA1 == nil or cdA1 <= 0))
                    local a2Ready = (holder and holder:FindFirstChild("SkillAssist2") and (cdA2 == nil or cdA2 <= 0))
                    local hasAssistReady = a1Ready or a2Ready

                    -- Logic chuyen doi qua lai giua Fruit va Assist
                    if altTurn == "Fruit" then
                        if _G.AutoFruit == true and hasFruitReady then
                            local fDelay = tonumber(_G.FruitDelay or 0.8)
                            if (tick() - lastAltActionTime) >= fDelay then
                                if nextFruitSlot == 1 then
                                    if f1Ready then
                                        castFruit(fr1)
                                        nextFruitSlot = 2
                                    elseif f2Ready then
                                        castFruit(fr2)
                                        nextFruitSlot = 1
                                    end
                                else
                                    if f2Ready then
                                        castFruit(fr2)
                                        nextFruitSlot = 1
                                    elseif f1Ready then
                                        castFruit(fr1)
                                        nextFruitSlot = 2
                                    end
                                end
                                lastAltActionTime = tick()
                                -- Da tung Fruit xong -> chuyen doi luot sang Assist
                                altTurn = "Assist"
                            end
                        else
                            -- Neu Fruit chua hoi hoac khong bat, nhuong luot cho Assist neu Assist san sang
                            if _G.AutoAssistSkill == true and hasAssistReady then
                                altTurn = "Assist"
                            end
                        end
                    elseif altTurn == "Assist" then
                        if _G.AutoAssistSkill == true and hasAssistReady then
                            local aDelay = tonumber(_G.AssistSkillDelay or 0.8)
                            if (tick() - lastAltActionTime) >= aDelay then
                                if nextAssistSlot == 1 then
                                    if a1Ready then
                                        castAssist(1, mob)
                                        nextAssistSlot = 2
                                    elseif a2Ready then
                                        castAssist(2, mob)
                                        nextAssistSlot = 1
                                    end
                                else
                                    if a2Ready then
                                        castAssist(2, mob)
                                        nextAssistSlot = 1
                                    elseif a1Ready then
                                        castAssist(1, mob)
                                        nextAssistSlot = 2
                                    end
                                end
                                lastAltActionTime = tick()
                                -- Da tung Assist xong -> chuyen doi luot sang Fruit
                                altTurn = "Fruit"
                            end
                        else
                            -- Neu Assist chua hoi hoac khong bat, nhuong luot cho Fruit neu Fruit san sang
                            if _G.AutoFruit == true and hasFruitReady then
                                altTurn = "Fruit"
                            end
                        end
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while wait() do
                pcall(function()
                    if _G.ResetifWave then
                        if tonumber(game:GetService("Players").LocalPlayer.PlayerGui.BattleGui.CenterUIFrame.WaveClearClearText.Text) >= tonumber(_G.SelectWaveToEnd) and game:GetService("Players").LocalPlayer.PlayerGui.BattleGui.CenterUIFrame.BossHealthFrame.Visible == false then
                            game.Players.LocalPlayer.Character.Humanoid.Health = 0
                        end
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while wait(1) do
                pcall(function()
                    if _G.DashNoCooldown then
                        game.ReplicatedStorage[game.Players.LocalPlayer.Name .. "StatDisplay"].No_DashCooldown.Value = true
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while wait(1) do
                pcall(function()
                    if _G.AutoClaimQuestAndReward then
                        if game.PlaceId == 6938803436 or game.PlaceId == 7274690025 or game.PlaceId == 7338881230 then
                            for i = 1,9 do
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("ClaimWeeklySpeedRaidReward",i)
                            end
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("GiveFreeDailyGemFromShop")
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CompleteDailyQuest","DailyQuest_Login")
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CompleteDailyQuest","DailyQuest_DungeonClear")
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CompleteDailyQuest","DailyQuest_Enemies")
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CompleteDailyQuest","DailyQuest_TimeChallenge")
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CompleteDailyQuest","DailyQuest_Raid")
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CompleteDailyQuest","DailyQuest_BossRush")
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CompleteDailyQuest","DailyQuest_AllQuestClear")
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CompleteDailyQuest","WeeklyQuest_Logins")
                            wait(600)
                        end
                    end
                end)
            end
        end)
    end)
    spawn(function()
    pcall(function()
        while task.wait() do
            pcall(function()
                if _G.AutoWalk == true then
                    if game.PlaceId ~= 6938803436 and game.PlaceId ~= 7274690025 and game.PlaceId ~= 7338881230 then
                        walk(getClosestBoss())
                    end
                end
            end)
        end
    end)
    end)

    spawn(function()
    pcall(function()
        while task.wait() do
            pcall(function()
                if _G.Automob or _G.KillAuraExtreme == true then
                    if game.PlaceId ~= 6938803436 and game.PlaceId ~= 7274690025 and game.PlaceId ~= 7338881230 then
                        local myChar = game.Players.LocalPlayer.Character
                        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                        local target = getCurrentTarget()
                        local shouldFlySky = (_G.KillAuraExtreme == true) and isExtremeDimension()

                        if shouldFlySky then
                            local rawHeight = tonumber(_G.KillAuraHeight or 35)
                            local auraHeight = math.clamp(rawHeight, 20, 38)
                            if myHrp then
                                if target and target:FindFirstChild("HumanoidRootPart") then
                                    myHrp.Anchored = true
                                    myHrp.Velocity = Vector3.zero
                                    myHrp.RotVelocity = Vector3.zero
                                    local targetPos = target.HumanoidRootPart.Position
                                    -- Bay ngay trên đỉnh đầu mục tiêu ở độ cao an toàn (35 studs) theo toạ độ Y của mục tiêu
                                    myHrp.CFrame = CFrame.new(targetPos.X, targetPos.Y + auraHeight, targetPos.Z) * CFrame.Angles(math.rad(-90), 0, 0)
                                else
                                    -- Chưa có mục tiêu còn sống: thả Anchored để không bị treo lơ lửng trên trời
                                    if myHrp.Anchored then
                                        myHrp.Anchored = false
                                    end
                                end
                            end
                        else
                            if myHrp and myHrp.Anchored then
                                myHrp.Anchored = false
                            end
                            if _G.Method == "Behind" then
                                MethodFarm = CFrame.new(0,0,_G.Distance) * CFrame.Angles(math.rad(0),0,0)
                            elseif _G.Method == "Front" then
                                MethodFarm = CFrame.new(0,0,-_G.Distance) * CFrame.Angles(math.rad(0),1800,0)
                            elseif _G.Method == "Under" then
                                MethodFarm = CFrame.new(0,-_G.Distance,0) * CFrame.Angles(math.rad(90),0,0)
                            elseif _G.Method == "Over" then
                                MethodFarm = CFrame.new(0,_G.Distance,0)  * CFrame.Angles(math.rad(-90),0,0)
                            else
                                MethodFarm = CFrame.new(0,0,_G.Distance)
                            end
                            local V3 = Vector3.new(0, 0, 0)
                            if myChar then
                                for _, v in ipairs(myChar:GetDescendants()) do
                                    if v:IsA("BasePart") then
                                        v.Velocity, v.RotVelocity = V3, V3
                                    end
                                end
                            end
                            if target and target:FindFirstChild("HumanoidRootPart") then
                                Tween(target.HumanoidRootPart.CFrame * MethodFarm)
                            end
                        end
                    end
                else
                    local myChar = game.Players.LocalPlayer.Character
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if myHrp and myHrp.Anchored then
                        myHrp.Anchored = false
                    end
                end
            end)
        end
    end)
    end)


    
    spawn(function()
        pcall(function()
            wait(10)
            while wait(1) do
                pcall(function()
                    if game.PlaceId ~= 6938803436 and game.PlaceId ~= 7274690025 and game.PlaceId ~= 7338881230 then
                        if _G.GoLobbyMethod == "ResetCharacter" and _G.OnRaidOpen == true and _G.RaidOpened == true and game:GetService("Players").LocalPlayer.PlayerGui.BattleGui.CenterUIFrame.BossHealthFrame.Visible == false then
                            game.Players.LocalPlayer.Character.Humanoid.Health = 0
                        elseif _G.GoLobbyMethod == "TeleportToLobby" and _G.OnRaidOpen == true and _G.RaidOpened == true and game:GetService("Players").LocalPlayer.PlayerGui.BattleGui.CenterUIFrame.BossHealthFrame.Visible == false then
                            game:GetService("TeleportService"):Teleport(6938803436)
                            wait(60)
                        end
                    end
                end)
            end
        end)
    end)


    spawn(function()
        pcall(function()
            Notification(1, "HelmHub", "Waiting on join raid", tonumber(_G.waitonJoinRiad))
            wait(tonumber(_G.waitonJoinRiad))
            while wait() do
                pcall(function()
                    if _G.AutoMadokiRaid == true and tonumber(game:GetService("ReplicatedStorage")[game.Players.LocalPlayer.Name.."StatDisplay"]["Madoki Raid Key"].Value) <= 0 then
                        game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("BuyRaidShopItem","Madoki Raid Key (2 Per Day)")
                    elseif game:GetService("ReplicatedStorage")[game.Players.LocalPlayer.Name.."StatDisplay"]:FindFirstChild("Madoki Raid Key") and tonumber(game:GetService("ReplicatedStorage")[game.Players.LocalPlayer.Name.."StatDisplay"]["Madoki Raid Key"].Value) > 0 and _G.AutoMadokiRaid == true then
                        game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Easy",["FriendsOnly"] = _G.FriendOnly,["MapName"] = "Goddess Madoki Raid",["Hardcore"] = false})
                        wait(1)
                        game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportPlayers")
                    else
                        if _G.AutoRaid == true and _G.AutoGoAFK == true then
                            if _G.RaidOpened == true then
                                if game.PlaceId == 6938803436 or game.PlaceId == 7274690025 or game.PlaceId == 7338881230 then
                                    game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Easy",["FriendsOnly"] = _G.FriendOnly,["MapName"] = (_G.RaidSelection and tostring(_G.RaidSelection) ~= "nil" and tostring(_G.RaidSelection) ~= "") and tostring(_G.RaidSelection) or "Goddess Madoki Raid",["Hardcore"] = false})
                                    wait()
                                    game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportPlayers")
                                elseif game.PlaceId == 6990131029 then
                                    game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions"):WaitForChild("MainRemoteFunction"):InvokeServer("TeleportToLobbyAFK",true)
                                end
                            elseif _G.RaidOpened == false and game.PlaceId ~= 6990131029 then
                                Notification(1, "HelmHub", "Go AFK in 10 Sec", 10)
                                wait(10)
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportToAFK")
                            end
                        elseif _G.AutoRaid == true and _G.AutoGoAFK == false then
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Easy",["FriendsOnly"] = _G.FriendOnly,["MapName"] = (_G.RaidSelection and tostring(_G.RaidSelection) ~= "nil" and tostring(_G.RaidSelection) ~= "") and tostring(_G.RaidSelection) or "Goddess Madoki Raid",["Hardcore"] = false})
                            wait(1)
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportPlayers")
                        end
                    end
                end)
            end
        end)
    end)


    spawn(function()
        pcall(function()
            Notification(1, "HelmHub", "Waiting CooldownOnlobby", tonumber(_G.CooldownOnlobby))
            wait(tonumber(_G.CooldownOnlobby))
            while wait() do
                pcall(function()
                    if _G.AutoRaid == true then
                        if _G.FreeBossRush == true and game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.BossRushFrame.BossRushFreeEntry.Text == "1 Free Entry Left" and _G.RaidOpened == false then
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportToBossRush")
                        elseif _G.BossRush == true and tonumber(game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.BossRushFrame.BossRushEntryPassCount.Text) > 0 and _G.RaidOpened == false then
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportToBossRush")
                        elseif _G.AutoTraitTokens == true and game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.PlayFrame.Frame.PlayRoomFrame.MapSelectionScrollingFrame["Infinite Mode"].PlayerReq.Text == "Trait Tokens Available" and game.Players.LocalPlayer.leaderstats.Level.Value >= 20 and _G.RaidOpened == false then
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Infinite",["FriendsOnly"] = _G.FriendOnly,["MapName"] = "Infinite Mode",["Hardcore"] = false})
                        elseif _G.AutoSpeedRaid == true and game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.PlayButtonsFrame.Frame.SpeedRaidBanner.SpeedRaidBannerOpenText.Text == "Ready to enter" and _G.RaidOpened == false then
                            for i,v in pairs(game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.SpeedRaidCharacterSelector.Shade.SpeedRaidCharacterInventoryScrollingFrame:GetChildren()) do
                                if v.ClassName == "ImageButton" then
                                    for ii,vv in pairs(v:GetChildren()) do
                                        if vv.ClassName == "ImageButton" and vv.Name == "CharacterImage" and vv.ImageTransparency == 0 then
                                            if v.Name ~= game:GetService("ReplicatedStorage")[game.Players.LocalPlayer.Name.."StatDisplay"].AssistCharacterName1.Value and v.Name ~= game:GetService("ReplicatedStorage")[game.Players.LocalPlayer.Name.."StatDisplay"].AssistCharacterName2.Value then
                                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportToShadowRaid",v.Name)
                                                wait(60)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif _G.AutoRaid == false then
                        if _G.FreeBossRush == true and game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.BossRushFrame.BossRushFreeEntry.Text == "1 Free Entry Left" then
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportToBossRush")
                        elseif _G.BossRush == true and tonumber(game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.BossRushFrame.BossRushEntryPassCount.Text) > 0 then
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportToBossRush")
                        elseif _G.AutoTraitTokens == true and game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.PlayFrame.Frame.PlayRoomFrame.MapSelectionScrollingFrame["Infinite Mode"].PlayerReq.Text == "Trait Tokens Available" and game.Players.LocalPlayer.leaderstats.Level.Value >= 20 then
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Infinite",["FriendsOnly"] = _G.FriendOnly,["MapName"] = "Infinite Mode",["Hardcore"] = false})
                        elseif _G.AutoSpeedRaid == true and game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.PlayButtonsFrame.Frame.SpeedRaidBanner.SpeedRaidBannerOpenText.Text == "Ready to enter" then
                            for i,v in pairs(game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.SpeedRaidCharacterSelector.Shade.SpeedRaidCharacterInventoryScrollingFrame:GetChildren()) do
                                if v.ClassName == "ImageButton" then
                                    for ii,vv in pairs(v:GetChildren()) do
                                        if vv.ClassName == "ImageButton" and vv.Name == "CharacterImage" and vv.ImageTransparency == 0 then
                                            if v.Name ~= game:GetService("ReplicatedStorage")[game.Players.LocalPlayer.Name.."StatDisplay"].AssistCharacterName1.Value and v.Name ~= game:GetService("ReplicatedStorage")[game.Players.LocalPlayer.Name.."StatDisplay"].AssistCharacterName2.Value then
                                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportToShadowRaid",v.Name)
                                                wait(60)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    wait(60)
                end)
            end
        end)
    end)

    spawn(function()
        pcall(function()
            wait(tonumber(_G.CooldownOnlobby))
            wait(5)
            while wait() do
                pcall(function()
                    if _G.AutoPlay == true then
                        if _G.GetAllDimensionCharacter == true then
                            if not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Sakura") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Easy",["FriendsOnly"] = true,["MapName"] = "Titan Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Natsu") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Hard",["FriendsOnly"] = true,["MapName"] = "Titan Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Killua") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Nightmare",["FriendsOnly"] = true,["MapName"] = "Titan Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Asta") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Easy",["FriendsOnly"] = true,["MapName"] = "Demon Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Itadori") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Hard",["FriendsOnly"] = true,["MapName"] = "Demon Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Akaza") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Nightmare",["FriendsOnly"] = true,["MapName"] = "Demon Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Sasuke") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Easy",["FriendsOnly"] = true,["MapName"] = "Curse Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Gray") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Hard",["FriendsOnly"] = true,["MapName"] = "Curse Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Sukuna") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Nightmare",["FriendsOnly"] = true,["MapName"] = "Curse Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Rukia") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Easy",["FriendsOnly"] = true,["MapName"] = "Villain Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Shinra") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Hard",["FriendsOnly"] = true,["MapName"] = "Villain Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("All Might") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Nightmare",["FriendsOnly"] = true,["MapName"] = "Villain Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Zoro") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Easy",["FriendsOnly"] = true,["MapName"] = "Sword Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("AsunaCharacter") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Nightmare",["FriendsOnly"] = true,["MapName"] = "Sword Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Emiya Archer") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Easy",["FriendsOnly"] = true,["MapName"] = "Ghoul Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("KanekiCharacter") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Nightmare",["FriendsOnly"] = true,["MapName"] = "Ghoul Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Lancer") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Easy",["FriendsOnly"] = true,["MapName"] = "Fate Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Saber Alter Character") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Nightmare",["FriendsOnly"] = true,["MapName"] = "Fate Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Diablo") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Easy",["FriendsOnly"] = true,["MapName"] = "Slime Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Rimuru") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Nightmare",["FriendsOnly"] = true,["MapName"] = "Slime Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("PowerCharacter") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Nightmare",["FriendsOnly"] = true,["MapName"] = "Devil Dimension",["Hardcore"] = _G.Hardcore})
                            elseif not game:GetService("Players").LocalPlayer.PlayerGui.MainGui.CenterUIFrame.Inventory.Frame.CharacterInventoryFrame.CharacterInventoryScrollingFrame:FindFirstChild("Yamato") then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Nightmare",["FriendsOnly"] = true,["MapName"] = "Pirate Dimension",["Hardcore"] = _G.Hardcore})
                            elseif _G.MapSelection == "Infinite Mode" then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Infinite",["FriendsOnly"] = _G.FriendOnly,["MapName"] = "Infinite Mode",["Hardcore"] = false})
                            elseif _G.MapSelection == "TimeChallenge" then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportToTimeChallenge")
                            elseif _G.MapSelection ~= "Infinite Mode" then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = _G.Difficulty,["FriendsOnly"] = _G.FriendOnly,["MapName"] = _G.MapSelection,["Hardcore"] = _G.Hardcore})
                            end
                        else
                            if _G.MapSelection == "Infinite Mode" then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = "Infinite",["FriendsOnly"] = _G.FriendOnly,["MapName"] = "Infinite Mode",["Hardcore"] = false})
                            elseif _G.MapSelection == "TimeChallenge" then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportToTimeChallenge")
                            elseif _G.MapSelection ~= "Infinite Mode" then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("CreateRoom",{["Difficulty"] = _G.Difficulty,["FriendsOnly"] = _G.FriendOnly,["MapName"] = _G.MapSelection,["Hardcore"] = _G.Hardcore})
                            end
                        end
                        wait(1)
                        game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("TeleportPlayers")
                        wait(60)
                    end
                end)
            end
        end)
    end)

    spawn(function()
        pcall(function()
            while task.wait() do
                pcall(function()
                    if _G.AutoSelectMap == true then
                        Lvl = game.Players.LocalPlayer.leaderstats.Level.Value
                        if Lvl > 0 and Lvl < 6 then
                            _G.Difficulty = "Easy"
                            _G.MapSelection = "Titan Dimension"
                        elseif Lvl > 5 and Lvl < 11 then
                            _G.Difficulty = "Hard"
                             _G.MapSelection = "Titan Dimension"
                        elseif Lvl > 10 and Lvl < 16 then
                            _G.Difficulty = "Nightmare"
                            _G.MapSelection = "Titan Dimension"
                        elseif Lvl > 15 and Lvl < 21 then
                            _G.Difficulty = "Easy"
                            _G.MapSelection = "Demon Dimension"
                        elseif Lvl > 20 and Lvl < 26 then
                            _G.Difficulty = "Hard"
                            _G.MapSelection = "Demon Dimension"
                        elseif Lvl > 25 and Lvl < 31 then
                            _G.Difficulty = "Nightmare"
                            _G.MapSelection = "Demon Dimension"
                        elseif Lvl > 30 and Lvl < 36 then
                            _G.Difficulty = "Easy"
                            _G.MapSelection = "Curse Dimension"
                        elseif Lvl > 35 and Lvl < 41 then
                            _G.Difficulty = "Hard"
                            _G.MapSelection = "Curse Dimension"
                        elseif Lvl > 40 and Lvl < 46 then
                            _G.Difficulty = "Nightmare"
                            _G.MapSelection = "Curse Dimension"
                        elseif Lvl > 45 and Lvl < 51 then
                            _G.Difficulty = "Easy"
                            _G.MapSelection = "Villain Dimension"
                        elseif Lvl > 50 and Lvl < 56 then
                            _G.Difficulty = "Hard"
                            _G.MapSelection = "Villain Dimension"
                        elseif Lvl > 55 and Lvl < 61 then
                            _G.Difficulty = "Nightmare"
                            _G.MapSelection = "Villain Dimension"
                        elseif Lvl > 60 and Lvl < 68 then
                            _G.Difficulty = "Easy"
                            _G.MapSelection = "Sword Dimension"
                        elseif Lvl > 67 and Lvl < 76 then
                            _G.Difficulty = "Nightmare"
                            _G.MapSelection = "Sword Dimension"
                        elseif Lvl > 75 and Lvl < 83 then
                            _G.Difficulty = "Easy"
                            _G.MapSelection = "Ghoul Dimension"
                        elseif Lvl > 82 and Lvl < 91 then
                            _G.Difficulty = "Nightmare"
                            _G.MapSelection = "Ghoul Dimension"
                        elseif Lvl > 90 and Lvl < 98 then
                            _G.Difficulty = "Easy"
                            _G.MapSelection = "Fate Dimension"
                        elseif Lvl > 97 and Lvl < 106 then
                            _G.Difficulty = "Nightmare"
                            _G.MapSelection = "Fate Dimension"
                        elseif Lvl > 105 and Lvl < 113 then
                            _G.Difficulty = "Easy"
                            _G.MapSelection = "Slime Dimension"
                        elseif Lvl > 112 and Lvl < 121 then
                            _G.Difficulty = "Nightmare"
                            _G.MapSelection = "Slime Dimension"
                        elseif Lvl > 120 and Lvl < 131 then
                            _G.Difficulty = "Nightmare"
                            _G.MapSelection = "Devil Dimension"
                        elseif Lvl > 130 then
                            _G.Difficulty = "Nightmare"
                            _G.MapSelection = "Pirate Dimension"
                        end
                    end
                end)
            end
        end)
    end)

    spawn(function()
        pcall(function()
            while wait(1) do
                pcall(function()
                    if _G.AutoEquipCharacter then
                        if isfile("Character_Helm.json") then
                            Config = game:GetService("HttpService"):JSONDecode(readfile("Character_Helm.json"))
                        end
                        for i,v in pairs(Config) do
                            if tostring(i) == "Character1" then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("EquipCharacter",tostring(v))
                                print("Character1 : "..tostring(v))
                            elseif tostring(i) == "Character2" then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("EquipCharacterAssist",tostring(v),1)
                                print("Character2 : "..tostring(v))
                            elseif tostring(i) == "Character3" then
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("EquipCharacterAssist",tostring(v),2)
                                print("Character3 : "..tostring(v))
                            end
                        end
                        wait(6000)
                    end
                end)
            end
        end)
    end)

    local function isGuiActuallyVisible(obj)
        if not obj or not obj:IsA("GuiObject") then return false end
        if not obj.Visible then return false end
        if obj.AbsoluteSize.X <= 5 or obj.AbsoluteSize.Y <= 5 then return false end
        local curr = obj.Parent
        while curr and curr:IsA("GuiObject") do
            if not curr.Visible then return false end
            curr = curr.Parent
        end
        if curr and curr:IsA("LayerCollector") then
            if not curr.Enabled then return false end
        end
        return true
    end

    spawn(function()
        pcall(function()
            local isReplaying = false
            while task.wait(0.5) do
                pcall(function()
                    if _G.Replay == true and not isReplaying then
                        local pgui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
                        if not pgui then return end

                        -- Dung replay neu dang mo Raid va bat StopReplay
                        if _G.RaidOpened == true and _G.StopReplay == true then
                            return
                        end

                        local uGui = pgui:FindFirstChild("UniversalGui")
                        local cFrame = uGui and uGui:FindFirstChild("UniversalCenterUIFrame")
                        local resUI = cFrame and cFrame:FindFirstChild("ResultUI")
                        local raidResUI = cFrame and cFrame:FindFirstChild("RaidResultUI")

                        -- Chi kich hoat khi ResultUI hoac RaidResultUI thuc su hien tren man hinh
                        local resultVisible = (resUI and resUI.Visible == true) or (raidResUI and raidResUI.Visible == true)
                        
                        -- Kiem tra them cac bang ket qua khac neu co
                        if not resultVisible then
                            for _, gui in ipairs(pgui:GetChildren()) do
                                if gui:IsA("ScreenGui") and gui.Enabled == true then
                                    for _, frame in ipairs(gui:GetChildren()) do
                                        if frame:IsA("GuiObject") and frame.Visible == true then
                                            local n = frame.Name:lower()
                                            if (n:find("result") or n:find("clear") or n:find("finish")) and frame.AbsoluteSize.X > 100 then
                                                resultVisible = true
                                                break
                                            end
                                        end
                                    end
                                end
                                if resultVisible then break end
                            end
                        end

                        if resultVisible then
                            -- Tim nut Retry / Replay
                            local targetBtn = nil
                            
                            -- 1. Uu tien nut goc RetryDungeonButton trong ResultUI
                            if resUI and resUI:FindFirstChild("RetryDungeonButton", true) then
                                local btn = resUI:FindFirstChild("RetryDungeonButton", true)
                                if btn:IsA("GuiButton") and btn.Visible == true then
                                    targetBtn = btn
                                end
                            end

                            -- 2. Quet ben trong frame ket qua
                            if not targetBtn and resUI then
                                for _, d in ipairs(resUI:GetDescendants()) do
                                    if d:IsA("GuiButton") and d.Visible == true then
                                        local n = d.Name:lower()
                                        if n:find("retry") or n:find("replay") or n:find("again") then
                                            targetBtn = d
                                            break
                                        end
                                    end
                                end
                            end

                            -- 3. Quet toan bo PlayerGui tim nut thuc su nhin thay duoc
                            if not targetBtn then
                                for _, d in ipairs(pgui:GetDescendants()) do
                                    if d:IsA("GuiButton") and isGuiActuallyVisible(d) then
                                        local n = d.Name:lower()
                                        if n:find("retry") or n:find("replay") then
                                            targetBtn = d
                                            break
                                        end
                                    end
                                end
                            end

                            -- Kich hoat choi lai
                            isReplaying = true
                            print("[Helm AutoReplay] Ket qua xuat hien! Chuan bi replay...")
                            task.wait(1.2) -- Cho animation ket qua mo hoan tat

                            -- A. Goi RemoteEvents cua Game
                            pcall(function()
                                game:GetService("ReplicatedStorage").RemoteEvents.MainRemoteEvent:FireServer("RetryDungeon")
                            end)

                            -- B. Goi RemoteFunctions cua Game
                            pcall(function()
                                game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("RetryDungeon")
                            end)

                            -- C. Neu tim thay nut thi nhan truc tiep
                            if targetBtn then
                                pcall(function()
                                    if getconnections then
                                        for _, ev in ipairs({"MouseButton1Click", "Activated", "MouseButton1Down"}) do
                                            if targetBtn[ev] then
                                                for _, conn in ipairs(getconnections(targetBtn[ev])) do
                                                    conn:Fire()
                                                end
                                            end
                                        end
                                    end
                                end)

                                pcall(function()
                                    for _, ev in ipairs({"MouseButton1Click", "MouseButton1Down", "Activated"}) do
                                        if targetBtn[ev] then firesignal(targetBtn[ev]) end
                                    end
                                end)

                                pcall(function()
                                    local pos = targetBtn.AbsolutePosition + (targetBtn.AbsoluteSize / 2)
                                    local vim = game:GetService("VirtualInputManager")
                                    vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
                                    task.wait(0.05)
                                    vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
                                end)
                            end

                            task.wait(4.0) -- Cho game nhan remote va chuyen man hinh
                            isReplaying = false
                        end
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while task.wait() do
                if game:GetService("Players").LocalPlayer.DevCameraOcclusionMode ~= "Invisicam" then
                    game:GetService("Players").LocalPlayer.DevCameraOcclusionMode = "Invisicam"
                end
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while task.wait() do
                pcall(function()
                    if _G.DontNoclip == true then
                        for i,v in pairs(game.Players.LocalPlayer.Character:GetChildren()) do
                            if v:IsA("BasePart") then
                                v.CanCollide = true
                            end
                        end
                    else
                        if _G.DodgeSkill == true and game.PlaceId ~= 6938803436 and game.PlaceId ~= 7274690025 and game.PlaceId ~= 7338881230 then
                            if _G.Automob == false and _G.DodgeSkill == true then
                                for i,v in pairs(game.Players.LocalPlayer.Character:GetChildren()) do
                                    if v:IsA("BasePart") then
                                        v.CanCollide = true
                                    end
                                end
                            elseif workspace.Folders.Debris:FindFirstChild("DodgePart") then
                                for i,v in pairs(game.Players.LocalPlayer.Character:GetChildren()) do
                                    if v:IsA("BasePart") then
                                        v.CanCollide = true
                                    end
                                end
                            elseif not workspace.Folders.Debris:FindFirstChild("DodgePart") then
                                for i,v in pairs(game.Players.LocalPlayer.Character:GetChildren()) do
                                    if v:IsA("BasePart") then
                                        v.CanCollide = false
                                    end
                                end
                            end
                        elseif _G.DodgeSkill == false and game.PlaceId ~= 6938803436 and game.PlaceId ~= 7274690025 and game.PlaceId ~= 7338881230 then
                            for i,v in pairs(game.Players.LocalPlayer.Character:GetChildren()) do
                                if v:IsA("BasePart") then
                                    v.CanCollide = false
                                end
                            end
                        end
                    end
                end)
            end
        end)
    end)
        
    spawn(function()
        pcall(function()
            while task.wait() do
                pcall(function()
                    if _G.BackToLobbyIfGotExploitsDetected then
                        if game.ReplicatedStorage[game.Players.LocalPlayer.Name .. "StatDisplay"].ExploitsDetected.Value == true then
                            game:GetService("TeleportService"):Teleport(6938803436)
                        end
                    end
                end)
            end
        end)
    end)
    spawn(function()
        pcall(function()
            while task.wait() do
                pcall(function()
                    if _G.HideName then
                        for i,v in pairs(game.Players.LocalPlayer.Character.Head:GetChildren()) do
                            if v.ClassName == "BillboardGui" then
                                v:Destroy()
                            end
                        end
                    end
                end)
            end
        end)
    end)

    spawn(function()
        pcall(function()
            workspace.Folders.Debris.ChildAdded:Connect(function(v)
                pcall(function()
                    if table.find({"telegraph"},v.Name:lower()) and v.Material ~= Enum.Material.Neon and _G.AutoDodgeSkill == true then
                        local op = v.Material
                        local a = v:Clone()
                        local side = math.clamp(tonumber(_G.SizeDodgePart),0,10)
                        local Sizeto = v.Size + Vector3.new(side,tonumber(_G.SizeDodgePartY),side)
                        a.Size = Vector3.new(0,0,v.Size.Z)
                        if v.ClassName == "MeshPart" then
                            a.Size = Vector3.new(0,0,100)
                            Sizeto = v.Size + Vector3.new(side,side,100)
                        end
                        game:GetService("TweenService"):Create(a,TweenInfo.new(tonumber(_G.TweenDodgePart)),{Size = Sizeto}):Play()
                        a.CFrame = v.CFrame + Vector3.new(0,0,0)
                        a.Anchored = true
                        a.Transparency = tonumber(_G.DodgePartTransparency)
                        a.CanCollide = true
                        a.Name = "DodgePart"
                        a.Parent = v.Parent
                        repeat wait() until not v.Parent
                        a:Destroy()
                    end
                end)
            end)
        end)
    end)

    spawn(function()
        pcall(function()
            while wait(2) do
                pcall(function()
                    if _G.AutoRedeemAllCode == true then
                        Code = {}
                        for i,v in pairs(workspace.Leaderboards.MilestoneBoard.Center.Surface.ScrollingFrame:GetChildren()) do
                            if v.ClassName == "Frame" then
                                Code = {v.MilestoneCode.Text}
                            end
                        end
                        for i,v in pairs(Code) do
                            game:GetService("ReplicatedStorage").RemoteFunctions.MainRemoteFunction:InvokeServer("RedeemPromoCode",v)
                        end
                        wait(600)
                    end
                end)
            end
        end)
    end)









































    local TabSetting = Window:CreateTab("Tiện Ích")
    local Setting1 = TabSetting:CreateSector("Điều Khiển Giao Diện & Tiện Ích", "left")
    Setting1:AddToggle("Ẩn GUI Khi Khởi Động (Auto Hide)", false, function(o)
        _G.AutoHideGui = o
        _G.CloseGuiAfterExecute = o
    end, "AutoHideGui")
    Setting1:AddButton("Ẩn / Hiện GUI (Toggle)", function()
        pcall(function()
            for _, v in pairs(game:GetService("CoreGui"):GetChildren()) do
                if v:FindFirstChild("main") then
                    v.main.Visible = not v.main.Visible
                end
            end
            local plrGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
            if plrGui then
                for _, v in pairs(plrGui:GetChildren()) do
                    if v:FindFirstChild("main") then
                        v.main.Visible = not v.main.Visible
                    end
                end
            end
        end)
    end)
    Setting1:AddTextbox("Speed" , "16" , function(w)
        _G.Speed = w
    end)
    Setting1:AddTextbox("Jump" , "50" , function(w)
        _G.Jump = w
    end)
    Setting1:AddToggle("WalkSpeed", false, function(t)
		_G.WalkSpeed = t
	end)
    Setting1:AddToggle("JumpPower", false, function(t)
		_G.JumpPower = t
	end)
    Setting1:AddToggle("Ctrl+ClickTP", false, function(t)
		_G.CtrlClickTP = t
	end)
	Setting1:AddButton("Rejoin" , function()
	    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, game:GetService("Players").LocalPlayer)
	end)
	Setting1:AddButton("HopServer" , function()
	    local v0=game.PlaceId;local v1={};local v2="";local v3=os.date("!*t").hour;local v4=false;local v5=pcall(function()v1=game:GetService("HttpService"):JSONDecode(readfile("NotSameServers.json"));end);if  not v5 then table.insert(v1,v3);writefile("NotSameServers.json",game:GetService("HttpService"):JSONEncode(v1));end function TPReturner()local v6;if (v2=="") then v6=game.HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"   .. v0   .. "/servers/Public?sortOrder=Asc&limit=100" ));else v6=game.HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"   .. v0   .. "/servers/Public?sortOrder=Asc&limit=100&cursor="   .. v2 ));end local v7="";if (v6.nextPageCursor and (v6.nextPageCursor~="null") and (v6.nextPageCursor~=nil)) then v2=v6.nextPageCursor;end local v8=0;for v9,v10 in pairs(v6.data) do local v11=true;v7=tostring(v10.id);if (tonumber(v10.maxPlayers)>tonumber(v10.playing)) then for v13,v14 in pairs(v1) do if (v8~=0) then if (v7==tostring(v14)) then v11=false;end elseif (tonumber(v3)~=tonumber(v14)) then local v15=pcall(function()delfile("NotSameServers.json");v1={};table.insert(v1,v3);end);end v8=v8 + 1 ;end if (v11==true) then table.insert(v1,v7);wait();pcall(function()writefile("NotSameServers.json",game:GetService("HttpService"):JSONEncode(v1));wait();game:GetService("TeleportService"):TeleportToPlaceInstance(v0,v7,game.Players.LocalPlayer);end);wait(4);end end end end function Teleport()while wait() do pcall(function()TPReturner();if (v2~="") then TPReturner();end end);end end Teleport();
	end)
	Setting1:AddButton("FireProximityPrompt" , function()
        for i, v in pairs(game:GetService("Workspace"):GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                fireproximityprompt(v)
            end
        end
	end)
	Setting1:AddButton("InstantProximityPrompt" , function()
        game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt)
            prompt.HoldDuration = 0
        end)
	end)
    spawn(function()
    pcall(function()
        while task.wait() do
            pcall(function()
                if _G.WalkSpeed then
                    pcall(function()
                        game.Players.LocalPlayer.character.Humanoid.WalkSpeed = tonumber(_G.Speed)
                    end)
                end
            end)
        end
    end)
    end)
    spawn(function()
    pcall(function()
        while task.wait() do
            pcall(function()
                if _G.JumpPower then
                    pcall(function()
                        game.Players.LocalPlayer.character.Humanoid.JumpPower = tonumber(_G.Jump)
                    end)
                end
            end)
        end
    end)
    end)
    function ClickTP()
        local UIS = game:GetService("UserInputService")
        local Player = game.Players.LocalPlayer
        local Mouse = Player:GetMouse()
        function GetCharacter()
        return game.Players.LocalPlayer.Character
        end
        function Teleport(pos)
        local Char = GetCharacter()
        if Char then
            Char:MoveTo(pos)
        end
        end
        UIS.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and UIS:IsKeyDown(Enum.KeyCode.LeftControl) and _G.CtrlClickTP == true then
                Teleport(Mouse.Hit.p)
            end
        end)
    end
	local Setting2 = TabSetting:CreateSector("Section2", "Right")
    Setting2:AddDropdown("StatGuiPosition", {"Center","Left","Right"}, "Right", false, function(h)
        pcall(function()
            game:GetService("CoreGui").StatBySmell.Frame.UIListLayout.HorizontalAlignment = h
        end)
    end)
    Setting2:AddToggle("StatGui", true, function(o)
        pcall(function()
            game:GetService("CoreGui").StatBySmell.Enabled = o
        end)
    end)
	Setting2:AddToggle("RejoinIfGotKick", false, function(o)
    	_G.rejoinKick = o
    end)

    spawn(function()
        getgenv().rejoin = game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(Kick)
            if ((Kick.Name == "ErrorPrompt") and Kick:FindFirstChild("MessageArea") and Kick.MessageArea:FindFirstChild("ErrorFrame")) then
                if _G.rejoinKick == true then
                    game:GetService("TeleportService"):Teleport(6938803436)
                end
            end
        end)
    end)
    Setting2:AddToggle("BootsWhitescreen", false, function(o)
    	_G.BootsWhitescreen = o
    end)
    Setting2:AddButton("Infinite Yield", function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
        end)
    end)
    Setting2:AddButton("Dark Dex (Soi Thu Muc)", function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/babyhamsta/RBLX_Scripts/main/Universal/DarkDexV4.lua"))()
        end)
    end)
    Setting2:AddButton("SimpleSpy (Soi Remote)", function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/SimpleSpyV3/main.lua"))()
        end)
    end)
    Setting2:AddButton("ResetCamera" , function()
        game:GetService("Workspace").CurrentCamera:Destroy()
        wait(.1)
        game:GetService("Workspace").CurrentCamera.CameraSubject = game:GetService("Players").LocalPlayer.Character.Humanoid
        game:GetService("Workspace").CurrentCamera.CameraType = "Custom"
        game:GetService("Players").LocalPlayer.CameraMinZoomDistance = .5
        game:GetService("Players").LocalPlayer.CameraMaxZoomDistance = 100000
        game:GetService("Players").LocalPlayer.CameraMode = "Classic"
    end)

    spawn(function()
    pcall(function()
        while wait() do
            pcall(function()
                if _G.CloseGuiAfterExecute then
                    pcall(function()
                        wait()
                        for i,v in pairs(game:GetService("CoreGui"):GetChildren()) do
                            if v:FindFirstChild("main") then
                                v.main.Visible = not v.main.Visible
                            end
                        end
                        wait(99999999999999999999999)
                    end)
                end
            end)
        end
    end)
    end)
    spawn(function()
    pcall(function()
    	while wait() do
    		if _G.BootsWhitescreen then
    		    wait()
                local v0;local v1=game;local v2=v1.Workspace;local v3=v1.Lighting;local v4=v2.Terrain;v4.WaterWaveSize=0;v4.WaterWaveSpeed=0;v4.WaterReflectance=0;v4.WaterTransparency=0;v3.GlobalShadows=false;v3.FogEnd=8999999488;v3.Brightness=0;settings().Rendering.QualityLevel="Level01";for v18,v19 in pairs(v1:GetDescendants()) do if (v19:IsA("Part") or v19:IsA("Union") or v19:IsA("CornerWedgePart") or v19:IsA("TrussPart")) then v19.Material="Plastic";v19.Reflectance=0;elseif (v19:IsA("Decal") or (v19:IsA("Texture") and v0)) then v19.Transparency=1;elseif (v19:IsA("ParticleEmitter") or v19:IsA("Trail")) then v19.Lifetime=NumberRange.new(0);elseif v19:IsA("Explosion") then v19.BlastPressure=1;v19.BlastRadius=1;elseif (v19:IsA("Fire") or v19:IsA("SpotLight") or v19:IsA("Smoke")) then v19.Enabled=false;elseif v19:IsA("MeshPart") then v19.Material="Plastic";v19.Reflectance=0;v19.TextureID=10385902758728956;end end for v20,v21 in pairs(v3:GetChildren()) do if (v21:IsA("BlurEffect") or v21:IsA("SunRaysEffect") or v21:IsA("ColorCorrectionEffect") or v21:IsA("BloomEffect") or v21:IsA("DepthOfFieldEffect")) then v21.Enabled=false;end end local v13=game:GetService("UserInputService");local v14=game:GetService("RunService");local v15=function()v14:Set3dRenderingEnabled(false);return;end;local v16=function()v14:Set3dRenderingEnabled(true);return;end;local v17=function()v13.WindowFocusReleased:Connect(v15);v13.WindowFocused:Connect(v16);return;end;v17();
    			wait(99999999999999999999999)
    		end
    	end
    end)
    end)
	game:GetService("Players").LocalPlayer.Idled:connect(function()
		game:GetService("VirtualUser"):CaptureController()
		game:GetService("VirtualUser"):ClickButton2(Vector2.new())
	end)
    ClickTP()
	pcall(function()
		library:ConfigSystem("HelmHub"):Load()
	end)
	-- TỰ ĐỘNG BẬT SẴN KILL AURA KHI VÀO MAP THEO YÊU CẦU CỦA DJ
	-- Không bao giờ ép tắt toggle: Kill Aura sẽ tự động kích hoạt khi ở Extreme Dimension
	-- và tự động ngủ yên (vô hiệu hóa) ở các map khác (Normal Dimension, Raid, Lobby).
	_G.KillAuraExtreme = true
	if getgenv then getgenv().SaveKillAuraExtreme = true end
	if killAuraToggleObj and killAuraToggleObj.Set then
		pcall(function()
			killAuraToggleObj:Set(true)
		end)
	end

	-- Giám sát kiểm tra map liên tục trong 15s đầu khi vừa load game để bắt trọn thời điểm quái/map Extreme spawn
	task.spawn(function()
		local startTime = tick()
		while (tick() - startTime) < 15 do
			if isExtremeDimension() then
				_G.KillAuraExtreme = true
				if getgenv then getgenv().SaveKillAuraExtreme = true end
				break
			end
			task.wait(0.3)
		end
	end)
    task.spawn(function()
        task.wait(1.0)
        if _G.AutoHideGui == true or _G.CloseGuiAfterExecute == true then
            pcall(function()
                for _, v in pairs(game:GetService("CoreGui"):GetChildren()) do
                    if v:FindFirstChild("main") then
                        v.main.Visible = false
                    end
                end
                local plrGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
                if plrGui then
                    for _, v in pairs(plrGui:GetChildren()) do
                        if v:FindFirstChild("main") then
                            v.main.Visible = false
                        end
                    end
                end
                if Notification then
                    Notification(1, "Helm Tiên Các", "Đã tự động ẩn GUI! Bấm nút Menu trên StatGui để mở lại.", 4)
                end
            end)
        end
    end)
    while wait(1) do
    	pcall(function()
    		library:ConfigSystem("HelmHub"):Save()
    	end)
	end
end
