
--[[
    CITY CRIMINAL SIMULATOR — v6 LUXE
    Клиентский набор для Delta. Данные взяты из реального дампа:
      Trucks: Hideout (CargoZone 0,10,80), Town (-251,10,1482), Desert, NewMap
      Loot:   16 папок LootSpawns, 1001 LootSpawn
      Sell:   Hideout/SellBox/SellZone (29,3,53), Town/ChopShop/SellZone (-231,5,1524)
      Safe:   Hideout/Compound/SafeZone (0,25,0)
      Police: Workspace/Police (10 Officer + Chief), Hideout/Sniper
      Remotes: LootGrab, LootRelease, Travel, ShopBuy, ...
      GUI: PoliceHud/Wanted, HUD/StaminaBar, ProximityPrompts
    Подбор/продажа — через ProximityPrompt (штатный клиентский вызов).
    Серверные значения (деньги/долг/квота, урон, ИИ) клиентом не меняются.
]]
 
pcall(function() print("[CrimSim] v6 LUXE старт") end)
 
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local WS = game:GetService("Workspace")
local player = Players.LocalPlayer
 
local CFG = {
    health = false, speed = false, speedVal = 32, jump = false, jumpVal = 100,
    autosprint = false, fall = false, stamina = false, invisible = false,
    noclip = false, fly = false,
    tpBase = false, tpTruck = false, tpSell = false, tpLoot = false,
    espLoot = false, espPolice = false, espTruck = false,
    autocollect = false, autosell = false, autofarm = false,
    fullbright = false, fps = true, info = true,
}
local sessionStart = os.clock()
local savedPositions = {}
local lootPicked = 0
local espRegistry = {}
local espLabels = {}
 
local ACCENT = Color3.fromRGB(126, 108, 255)
local GREEN = Color3.fromRGB(72, 196, 120)
local RED = Color3.fromRGB(232, 88, 88)
local YELLOW = Color3.fromRGB(255, 206, 84)
local BG = Color3.fromRGB(17, 17, 24)
local CARD = Color3.fromRGB(27, 27, 38)
local MUTED = Color3.fromRGB(142, 142, 168)
 
local function main()
    -- ================= УТИЛИТЫ =================
    local function getHRP()
        local c = player.Character
        return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
    end
    local function getHum()
        local c = player.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end
    local function partOf(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then return inst end
        if inst:IsA("Model") then
            return inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")
        end
        return nil
    end
    local function distTo(pos)
        local hrp = getHRP()
        if not hrp or not pos then return math.huge end
        return (pos - hrp.Position).Magnitude
    end
    local function findAll(root, name, maxDepth, out, depth)
        out = out or {}
        depth = depth or 0
        if depth > (maxDepth or 5) then return out end
        local ok, children = pcall(function() return root:GetChildren() end)
        if not ok then return out end
        for _, ch in ipairs(children) do
            if ch.Name == name then out[#out + 1] = ch end
            if ch:IsA("Model") or ch:IsA("Folder") then
                findAll(ch, name, maxDepth, out, depth + 1)
            end
        end
        return out
    end
 
    -- «Липкий» телепорт: держит точку 1.6 сек, чтобы серверная коррекция не сбила
    local sticky = { cf = nil, untilT = 0 }
    local function stickyTP(cf, hold)
        if not cf then return end
        sticky.cf = cf
        sticky.untilT = os.clock() + (hold or 1.6)
        local hrp = getHRP()
        if hrp then pcall(function() hrp.CFrame = cf end) end
    end
    local function tpToPos(pos, off, hold)
        if not pos then return end
        stickyTP(CFrame.new(pos + Vector3.new(0, off or 3, 0)), hold)
    end
 
    -- ================= КЕШ =================
    local cache = { loot = {}, trucks = {}, sells = {}, police = {}, safe = nil, t = -99 }
    local function refreshCache()
        local now = os.clock()
        if now - cache.t < 3 then return end
        cache.t = now
 
        local loot = {}
        for _, folder in ipairs(findAll(WS, "LootSpawns", 5)) do
            local ok, children = pcall(function() return folder:GetChildren() end)
            if ok then
                for _, p in ipairs(children) do
                    if p:IsA("BasePart") and p.Name:lower() == "lootspawn" then
                        loot[#loot + 1] = p
                    end
                end
            end
        end
        cache.loot = loot
 
        local trucks = {}
        for _, rootName in ipairs({ "Hideout", "Town", "Desert", "NewMap" }) do
            local root = WS:FindFirstChild(rootName)
            if root then
                for _, m in ipairs(findAll(root, "Truck", 3)) do
                    if m:IsA("Model") then
                        local p = m:FindFirstChild("CargoZone") or m.PrimaryPart
                                  or m:FindFirstChildOfClass("BasePart")
                        if p then trucks[#trucks + 1] = { model = m, part = p } end
                    end
                end
            end
        end
        cache.trucks = trucks
 
        local sells = {}
        for _, s in ipairs(findAll(WS, "SellZone", 4)) do
            if s:IsA("BasePart") then sells[#sells + 1] = s end
        end
        cache.sells = sells
 
        local police = {}
        local pf = WS:FindFirstChild("Police")
        if pf then
            local ok, ch = pcall(function() return pf:GetChildren() end)
            if ok then
                for _, m in ipairs(ch) do
                    if m:IsA("Model") or m:IsA("BasePart") then police[#police + 1] = m end
                end
            end
        end
        for _, sn in ipairs(findAll(WS, "Sniper", 4)) do
            if sn:IsA("Model") then police[#police + 1] = sn end
        end
        local town = WS:FindFirstChild("Town")
        local station = town and town:FindFirstChild("PoliceStation")
        if station then police[#police + 1] = station end
        cache.police = police
 
        local hideout = WS:FindFirstChild("Hideout")
        local safe = nil
        if hideout then
            local zones = findAll(hideout, "SafeZone", 4)
            safe = zones[1]
        end
        cache.safe = safe
    end
 
    local function nearestFrom(list, getPart)
        local best, bd = nil, math.huge
        for _, item in ipairs(list) do
            local p = getPart and getPart(item) or partOf(item)
            if p and p:IsA("BasePart") then
                local d = distTo(p.Position)
                if d < bd then bd, best = d, item end
            end
        end
        return best, bd
    end
 
    -- ================= PROXIMITY PROMPTS =================
    local op = OverlapParams.new()
    op.FilterType = Enum.RaycastFilterType.Exclude
    op.MaxParts = 80
 
    local ACT_KEYS = { "take", "grab", "pick", "steal", "loot", "collect", "search", "open", "sell" }
    local OBJ_KEYS = { "loot", "item", "crate", "box", "bag", "cash", "money", "diamond", "gem", "safe" }
 
    local function promptMatches(prompt)
        local txt = ""
        pcall(function() txt = string.lower(prompt.ActionText or "") end)
        for _, k in ipairs(ACT_KEYS) do
            if string.find(txt, k, 1, true) then return true end
        end
        local nm = ""
        pcall(function()
            if prompt.Parent then nm = string.lower(prompt.Parent.Name) end
        end)
        for _, k in ipairs(OBJ_KEYS) do
            if string.find(nm, k, 1, true) then return true end
        end
        return false
    end
 
    local function promptsNear(radius, onlyMatching)
        local hrp = getHRP()
        local res = {}
        if not hrp then return res end
        op.FilterDescendantsInstances = { player.Character }
        local ok, parts = pcall(function()
            return WS:GetPartBoundsInRadius(hrp.Position, radius, op)
        end)
        if not ok or not parts then return res end
        local seen = {}
        for _, p in ipairs(parts) do
            local prompt = nil
            pcall(function()
                prompt = p:FindFirstChildOfClass("ProximityPrompt")
                if not prompt and p.Parent then
                    prompt = p.Parent:FindFirstChildOfClass("ProximityPrompt")
                end
            end)
            if prompt and not seen[prompt] then
                seen[prompt] = true
                local enabled = true
                pcall(function() enabled = prompt.Enabled end)
                if enabled and (not onlyMatching or promptMatches(prompt)) then
                    res[#res + 1] = prompt
                end
            end
        end
        return res
    end
 
    local function triggerPrompt(prompt)
        pcall(function() prompt:InputHoldBegin() end)
        task.delay(0.12, function()
            pcall(function() prompt:InputHoldEnd() end)
        end)
    end
 
    -- ================= UI КАРКАС =================
    local function getGuiParent()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then pcall(function() pg = player:WaitForChild("PlayerGui", 15) end) end
        if pg then return pg end
        local ok, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok and cg then return cg end
        return nil
    end
 
    local sg = Instance.new("ScreenGui")
    sg.Name = "CrimSimLuxe"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999
    local parentGui = getGuiParent()
    if not parentGui then
        warn("[CrimSim] PlayerGui не найден — меню не создано")
        return
    end
    sg.Parent = parentGui
 
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.fromOffset(316, 552)
    panel.Position = UDim2.fromOffset(18, 64)
    panel.BackgroundColor3 = BG
    panel.BackgroundTransparency = 0.03
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.ClipsDescendants = true
    panel.Parent = sg
 
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = panel
    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = Color3.fromRGB(58, 58, 84)
    panelStroke.Thickness = 1
    panelStroke.Transparency = 0.15
    panelStroke.Parent = panel
 
    -- шапка
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 46)
    header.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
    header.BorderSizePixel = 0
    header.Parent = panel
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header
    pcall(function()
        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new(Color3.fromRGB(46, 40, 82), Color3.fromRGB(24, 24, 36))
        grad.Rotation = 90
        grad.Parent = header
    end)
 
    local logo = Instance.new("TextLabel")
    logo.Size = UDim2.fromOffset(28, 28)
    logo.Position = UDim2.fromOffset(12, 9)
    logo.BackgroundColor3 = ACCENT
    logo.BorderSizePixel = 0
    logo.Text = "C"
    logo.TextColor3 = Color3.fromRGB(255, 255, 255)
    logo.TextSize = 15
    logo.Font = Enum.Font.GothamBold
    logo.Parent = header
    local logoCorner = Instance.new("UICorner")
    logoCorner.CornerRadius = UDim.new(0, 8)
    logoCorner.Parent = logo
 
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -150, 0, 16)
    title.Position = UDim2.fromOffset(48, 8)
    title.BackgroundTransparency = 1
    title.Text = "CRIMINAL SIMULATOR"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(240, 240, 255)
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.Parent = header
 
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -150, 0, 12)
    subtitle.Position = UDim2.fromOffset(48, 24)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "LUXE EDITION  •  v6"
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = Color3.fromRGB(154, 148, 200)
    subtitle.TextSize = 9
    subtitle.Font = Enum.Font.Gotham
    subtitle.Parent = header
 
    local btnMin = Instance.new("TextButton")
    btnMin.Size = UDim2.fromOffset(24, 24)
    btnMin.Position = UDim2.new(1, -62, 0, 11)
    btnMin.BackgroundColor3 = Color3.fromRGB(62, 62, 88)
    btnMin.BorderSizePixel = 0
    btnMin.Text = "−"
    btnMin.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnMin.TextSize = 16
    btnMin.Font = Enum.Font.GothamBold
    btnMin.Parent = header
    local mc = Instance.new("UICorner")
    mc.CornerRadius = UDim.new(0, 7)
    mc.Parent = btnMin
 
    local btnClose = Instance.new("TextButton")
    btnClose.Size = UDim2.fromOffset(24, 24)
    btnClose.Position = UDim2.new(1, -32, 0, 11)
    btnClose.BackgroundColor3 = Color3.fromRGB(196, 64, 64)
    btnClose.BorderSizePixel = 0
    btnClose.Text = "×"
    btnClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnClose.TextSize = 16
    btnClose.Font = Enum.Font.GothamBold
    btnClose.Parent = header
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 7)
    cc.Parent = btnClose
 
    -- вкладки
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -16, 0, 30)
    tabBar.Position = UDim2.fromOffset(8, 50)
    tabBar.BackgroundColor3 = Color3.fromRGB(23, 23, 32)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = panel
    local tabBarCorner = Instance.new("UICorner")
    tabBarCorner.CornerRadius = UDim.new(0, 8)
    tabBarCorner.Parent = tabBar
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 3)
    tabLayout.Parent = tabBar
    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingTop = UDim.new(0, 3)
    tabPad.PaddingBottom = UDim.new(0, 3)
    tabPad.PaddingLeft = UDim.new(0, 3)
    tabPad.PaddingRight = UDim.new(0, 3)
    tabPad.Parent = tabBar
 
    local pageArea = Instance.new("Frame")
    pageArea.Size = UDim2.new(1, 0, 1, -108)
    pageArea.Position = UDim2.fromOffset(0, 84)
    pageArea.BackgroundTransparency = 1
    pageArea.Parent = panel
 
    local pages = {}
    local tabButtons = {}
    local activeTab = nil
 
    local function makePage(id)
        local sc = Instance.new("ScrollingFrame")
        sc.Name = "Page_" .. id
        sc.Size = UDim2.fromScale(1, 1)
        sc.BackgroundTransparency = 1
        sc.BorderSizePixel = 0
        sc.CanvasSize = UDim2.new(0, 0, 0, 0)
        sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
        sc.ScrollBarThickness = 3
        sc.ScrollBarImageColor3 = Color3.fromRGB(92, 88, 130)
        sc.Visible = false
        sc.Parent = pageArea
        local lay = Instance.new("UIListLayout")
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Padding = UDim.new(0, 3)
        lay.Parent = sc
        local pd = Instance.new("UIPadding")
        pd.PaddingTop = UDim.new(0, 4)
        pd.PaddingLeft = UDim.new(0, 8)
        pd.PaddingRight = UDim.new(0, 8)
        pd.PaddingBottom = UDim.new(0, 6)
        pd.Parent = sc
        pages[id] = sc
        return sc
    end
 
    local function selectTab(id)
        if activeTab == id then return end
        activeTab = id
        for pid, page in pairs(pages) do
            page.Visible = (pid == id)
        end
        for tid, btn in pairs(tabButtons) do
            btn.BackgroundColor3 = (tid == id) and ACCENT or Color3.fromRGB(23, 23, 32)
            btn.TextColor3 = (tid == id) and Color3.fromRGB(255, 255, 255) or MUTED
        end
    end
 
    local function addTab(id, label, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 58, 1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(23, 23, 32)
        btn.BorderSizePixel = 0
        btn.Text = label
        btn.TextSize = 10
        btn.Font = Enum.Font.GothamBold
        btn.TextColor3 = MUTED
        btn.AutoButtonColor = false
        btn.LayoutOrder = order
        btn.Parent = tabBar
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
        tabButtons[id] = btn
        btn.MouseButton1Click:Connect(function() selectTab(id) end)
    end
 
    -- ================= ЭЛЕМЕНТЫ =================
    local function addSection(parent, text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -4, 0, 24)
        l.BackgroundTransparency = 1
        l.Text = string.upper(text)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = ACCENT
        l.TextSize = 9
        l.Font = Enum.Font.GothamBold
        l.Parent = parent
        return l
    end
 
    local function addToggle(parent, key, text, desc, onF, offF)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 44)
        row.BackgroundColor3 = CARD
        row.BorderSizePixel = 0
        row.Parent = parent
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 8)
        rc.Parent = row
 
        local nm = Instance.new("TextLabel")
        nm.Size = UDim2.new(1, -62, 0, 17)
        nm.Position = UDim2.fromOffset(10, 4)
        nm.BackgroundTransparency = 1
        nm.Text = text
        nm.TextXAlignment = Enum.TextXAlignment.Left
        nm.TextColor3 = Color3.fromRGB(236, 236, 248)
        nm.TextSize = 12
        nm.Font = Enum.Font.Gotham
        nm.Parent = row
 
        local ds = Instance.new("TextLabel")
        ds.Size = UDim2.new(1, -62, 0, 14)
        ds.Position = UDim2.fromOffset(10, 23)
        ds.BackgroundTransparency = 1
        ds.Text = desc or ""
        ds.TextXAlignment = Enum.TextXAlignment.Left
        ds.TextColor3 = MUTED
        ds.TextSize = 9
        ds.Font = Enum.Font.Gotham
        ds.TextTruncate = Enum.TextTruncate.AtEnd
        ds.Parent = row
 
        local track = Instance.new("Frame")
        track.Size = UDim2.fromOffset(42, 22)
        track.Position = UDim2.new(1, -52, 0.5, -11)
        track.BackgroundColor3 = Color3.fromRGB(58, 58, 78)
        track.BorderSizePixel = 0
        track.Parent = row
        local tc = Instance.new("UICorner")
        tc.CornerRadius = UDim.new(1, 0)
        tc.Parent = track
 
        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(16, 16)
        knob.Position = UDim2.fromOffset(3, 3)
        knob.BackgroundColor3 = Color3.fromRGB(245, 245, 255)
        knob.BorderSizePixel = 0
        knob.Parent = track
        local kc = Instance.new("UICorner")
        kc.CornerRadius = UDim.new(1, 0)
        kc.Parent = knob
 
        local function refresh(animate)
            local on = CFG[key]
            track.BackgroundColor3 = on and GREEN or Color3.fromRGB(58, 58, 78)
            local target = on and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
            if animate then
                pcall(function()
                    TweenService:Create(knob, TweenInfo.new(0.14, Enum.EasingStyle.Quad),
                        { Position = target }):Play()
                end)
            else
                knob.Position = target
            end
        end
 
        local click = Instance.new("TextButton")
        click.Size = UDim2.fromScale(1, 1)
        click.BackgroundTransparency = 1
        click.Text = ""
        click.Parent = row
        click.MouseButton1Click:Connect(function()
            CFG[key] = not CFG[key]
            refresh(true)
            if CFG[key] and onF then pcall(onF) end
            if not CFG[key] and offF then pcall(offF) end
        end)
        refresh(false)
    end
 
    local function addButton(parent, text, desc, fn, accent)
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -4, 0, 38)
        row.BackgroundColor3 = accent and Color3.fromRGB(56, 46, 96) or Color3.fromRGB(36, 36, 52)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = true
        row.Parent = parent
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 8)
        rc.Parent = row
 
        local nm = Instance.new("TextLabel")
        nm.Size = UDim2.new(1, -16, 0, 16)
        nm.Position = UDim2.fromOffset(10, 4)
        nm.BackgroundTransparency = 1
        nm.Text = text
        nm.TextXAlignment = Enum.TextXAlignment.Left
        nm.TextColor3 = Color3.fromRGB(236, 236, 248)
        nm.TextSize = 12
        nm.Font = Enum.Font.GothamBold
        nm.Parent = row
 
        local ds = Instance.new("TextLabel")
        ds.Size = UDim2.new(1, -16, 0, 13)
        ds.Position = UDim2.fromOffset(10, 20)
        ds.BackgroundTransparency = 1
        ds.Text = desc or ""
        ds.TextXAlignment = Enum.TextXAlignment.Left
        ds.TextColor3 = MUTED
        ds.TextSize = 9
        ds.Font = Enum.Font.Gotham
        ds.TextTruncate = Enum.TextTruncate.AtEnd
        ds.Parent = row
 
        row.MouseButton1Click:Connect(function() pcall(fn) end)
    end
 
    -- ================= СТРАНИЦЫ =================
    makePage("player")
    makePage("move")
    makePage("loot")
    makePage("esp")
    makePage("misc")
 
    addTab("player", "ПЕРСОНАЖ", 1)
    addTab("move", "ДВИЖЕНИЕ", 2)
    addTab("loot", "ЛУТ", 3)
    addTab("esp", "ESP", 4)
    addTab("misc", "ПРОЧЕЕ", 5)
 
    -- PLAYER
    local pp = pages.player
    addSection(pp, "Состояние")
    addToggle(pp, "health", "Бесконечное здоровье", "Держит HP на максимуме")
    addToggle(pp, "stamina", "Стамина (локально)", "Пробует держать 100")
    addToggle(pp, "speed", "Скорость", "WalkSpeed 32")
    addToggle(pp, "jump", "Прыжок", "JumpPower 100")
    addToggle(pp, "autosprint", "Автобег", "Всегда бежит")
    addToggle(pp, "fall", "Без урона от падения", "")
    addToggle(pp, "invisible", "Невидимость (локально)", "Только на твоём экране")
 
    -- MOVE
    local mp = pages.move
    addSection(mp, "Полёт и стены")
    addToggle(mp, "noclip", "Noclip", "Сквозь стены")
    addToggle(mp, "fly", "Полёт", "Джойстик / WASD + Space")
    addSection(mp, "Телепорт")
    addButton(mp, "База (Hideout)", "29, 5, 53", function()
        tpToPos(Vector3.new(29, 5, 53), 0)
    end, true)
    addButton(mp, "Городская продажа", "ChopShop -231, 7, 1524", function()
        tpToPos(Vector3.new(-231, 7, 1524), 0)
    end, true)
    addButton(mp, "Ближайший грузовик", "К CargoZone", function()
        refreshCache()
        local t = nearestFrom(cache.trucks, function(x) return x.part end)
        if t then tpToPos(t.part.Position, 3) end
    end)
    addButton(mp, "Ближайший лут", "К LootSpawn", function()
        refreshCache()
        local l = nearestFrom(cache.loot)
        if l then tpToPos(l.Position, 2) end
    end)
    addButton(mp, "Сохранить точку", "Запомнить где стоишь", function()
        local hrp = getHRP()
        if hrp then table.insert(savedPositions, hrp.Position) end
    end)
    addButton(mp, "К сохранённой", "Вернуться", function()
        if #savedPositions > 0 then tpToPos(savedPositions[#savedPositions], 2) end
    end)
    addSection(mp, "Удержание")
    addToggle(mp, "tpBase", "Держать у базы", "")
    addToggle(mp, "tpTruck", "Держать у грузовика", "")
    addToggle(mp, "tpSell", "Держать у продажи", "")
    addToggle(mp, "tpLoot", "Держать у лута", "")
 
    -- LOOT
    local lp = pages.loot
    addSection(lp, "Сбор")
    addToggle(lp, "autocollect", "Автосбор", "Жмёт промпты подбора")
    addButton(lp, "Собрать сейчас", "Всё в радиусе 20", function()
        for _, pr in ipairs(promptsNear(20, true)) do triggerPrompt(pr) end
    end, true)
    addSection(lp, "Продажа")
    addToggle(lp, "autosell", "Автопродажа", "Жмёт промпты у SellZone")
    addSection(lp, "Фарм")
    addToggle(lp, "autofarm", "Автофарм", "Лут → продажа → база")
 
    -- ESP
    local ep = pages.esp
    addSection(ep, "Подсветка")
    addToggle(ep, "espPolice", "Полиция", "10 Officer + Chief + Sniper")
    addToggle(ep, "espTruck", "Грузовики", "4 грузовика + CargoZone")
    addToggle(ep, "espLoot", "Лут", "Ближайшие 10 спавнов")
 
    -- MISC
    local xp = pages.misc
    addSection(xp, "Интерфейс")
    addToggle(xp, "fullbright", "FullBright", "Светло, 12:00")
    addToggle(xp, "fps", "FPS", "Показывать кадры")
    addToggle(xp, "info", "Инфо", "Дистанции и розыск")
    addButton(xp, "ПАНИКА", "Выключить всё и скрыть меню", function()
        for k in pairs(CFG) do
            if type(CFG[k]) == "boolean" then CFG[k] = false end
        end
        CFG.fps, CFG.info = true, true
        for _, h in pairs(espRegistry) do
            if h and h.Parent then h.Enabled = false end
        end
        for _, b in pairs(espLabels) do
            if b and b.Parent then b.Enabled = false end
        end
        sticky.cf = nil
        sg.Enabled = false
    end, false)
 
    selectTab("player")
 
    -- ================= СТАТУС =================
    local footer = Instance.new("Frame")
    footer.Size = UDim2.new(1, -16, 0, 22)
    footer.Position = UDim2.new(0, 8, 1, -26)
    footer.BackgroundColor3 = Color3.fromRGB(23, 23, 32)
    footer.BorderSizePixel = 0
    footer.Parent = panel
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 7)
    fc.Parent = footer
 
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -12, 1, 0)
    status.Position = UDim2.fromOffset(8, 0)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextColor3 = YELLOW
    status.TextSize = 10
    status.Font = Enum.Font.Gotham
    status.Parent = footer
 
    -- сворачивание / закрытие / клавиша
    local minimized = false
    local fullSize = panel.Size
    local function applyMin()
        pcall(function()
            TweenService:Create(panel, TweenInfo.new(0.16, Enum.EasingStyle.Quad),
                { Size = minimized and UDim2.fromOffset(316, 46) or fullSize }):Play()
        end)
        pageArea.Visible = not minimized
        tabBar.Visible = not minimized
        footer.Visible = not minimized
    end
    btnMin.MouseButton1Click:Connect(function()
        minimized = not minimized
        applyMin()
    end)
    btnClose.MouseButton1Click:Connect(function() sg.Enabled = false end)
    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            sg.Enabled = not sg.Enabled
        end
    end)
 
    -- ================= ДЖОЙСТИК =================
    local joyFrame, knob, joyVec = nil, nil, Vector2.new()
    local flyBtnUp, flyBtnDown
    local upKey, downKey = false, false
 
    if UIS.TouchEnabled then
        joyFrame = Instance.new("Frame")
        joyFrame.AnchorPoint = Vector2.new(0, 1)
        joyFrame.Position = UDim2.new(0.06, 0, 1, -24)
        joyFrame.Size = UDim2.fromOffset(132, 132)
        joyFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        joyFrame.BackgroundTransparency = 0.86
        joyFrame.Visible = false
        joyFrame.Parent = sg
        local jc = Instance.new("UICorner")
        jc.CornerRadius = UDim.new(1, 0)
        jc.Parent = joyFrame
 
        knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(50, 50)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.fromScale(0.5, 0.5)
        knob.BackgroundColor3 = ACCENT
        knob.BackgroundTransparency = 0.25
        knob.Parent = joyFrame
        local kc = Instance.new("UICorner")
        kc.CornerRadius = UDim.new(1, 0)
        kc.Parent = knob
 
        local joyActive = false
        local joyCenter = Vector2.new()
        local function joyUpdate(pos)
            if not joyActive then return end
            local rel = pos - joyCenter
            local mag = rel.Magnitude
            local maxR = 52
            if mag > maxR then rel = rel * (maxR / mag) end
            joyVec = rel / maxR
            knob.Position = UDim2.fromOffset(
                joyFrame.AbsoluteSize.X / 2 + rel.X,
                joyFrame.AbsoluteSize.Y / 2 + rel.Y)
        end
        joyFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                joyActive = true
                joyCenter = joyFrame.AbsolutePosition + joyFrame.AbsoluteSize / 2
                joyUpdate(input.Position)
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        joyActive = false
                        joyVec = Vector2.new()
                        knob.Position = UDim2.fromScale(0.5, 0.5)
                    end
                end)
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if joyActive and input.UserInputType == Enum.UserInputType.Touch then
                joyUpdate(input.Position)
            end
        end)
 
        flyBtnUp = Instance.new("TextButton")
        flyBtnUp.AnchorPoint = Vector2.new(1, 1)
        flyBtnUp.Position = UDim2.new(0.9, 0, 1, -172)
        flyBtnUp.Size = UDim2.fromOffset(62, 62)
        flyBtnUp.BackgroundColor3 = ACCENT
        flyBtnUp.BackgroundTransparency = 0.35
        flyBtnUp.Text = "UP"
        flyBtnUp.TextColor3 = Color3.fromRGB(255, 255, 255)
        flyBtnUp.Font = Enum.Font.GothamBold
        flyBtnUp.Visible = false
        flyBtnUp.Parent = sg
        local uc = Instance.new("UICorner")
        uc.CornerRadius = UDim.new(1, 0)
        uc.Parent = flyBtnUp
        flyBtnDown = flyBtnUp:Clone()
        flyBtnDown.Position = UDim2.new(0.9, 0, 1, -96)
        flyBtnDown.Text = "DOWN"
        flyBtnDown.Parent = sg
 
        flyBtnUp.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch
                or i.UserInputType == Enum.UserInputType.MouseButton1 then
                upKey = true
            end
        end)
        flyBtnUp.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch
                or i.UserInputType == Enum.UserInputType.MouseButton1 then
                upKey = false
            end
        end)
        flyBtnDown.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch
                or i.UserInputType == Enum.UserInputType.MouseButton1 then
                downKey = true
            end
        end)
        flyBtnDown.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch
                or i.UserInputType == Enum.UserInputType.MouseButton1 then
                downKey = false
            end
        end)
    end
 
    -- ================= ЦИКЛЫ =================
    local function loop(dt, fn)
        local acc = 0
        return RunService.Heartbeat:Connect(function(s)
            acc = acc + s
            if acc >= dt then
                acc = 0
                pcall(fn)
            end
        end)
    end
 
    -- липкий телепорт
    loop(0.08, function()
        if sticky.cf and os.clock() < sticky.untilT then
            local hrp = getHRP()
            if hrp then pcall(function() hrp.CFrame = sticky.cf end) end
        end
    end)
 
    loop(0.4, function()
        if not CFG.health then return end
        local h = getHum()
        if h and h.Health > 0 then h.Health = h.MaxHealth end
    end)
 
    RunService.Heartbeat:Connect(function()
        local h = getHum()
        if not h then return end
        if CFG.speed and h.WalkSpeed ~= CFG.speedVal then h.WalkSpeed = CFG.speedVal end
        if CFG.jump and h.JumpPower ~= CFG.jumpVal then h.JumpPower = CFG.jumpVal end
    end)
 
    loop(0.25, function()
        if not CFG.autosprint then return end
        local h = getHum()
        if h then h.WalkSpeed = (CFG.speed and CFG.speedVal or 16) * 1.6 end
    end)
 
    loop(0.3, function()
        if not CFG.fall then return end
        local h = getHum()
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end) end
    end)
 
    loop(0.3, function()
        if not CFG.stamina then return end
        local c = player.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then
            local attr = h:GetAttribute("Stamina")
            if attr ~= nil then pcall(function() h:SetAttribute("Stamina", 100) end) end
        end
        for _, inst in ipairs(c:GetDescendants()) do
            if inst:IsA("ValueBase") and inst.Name:lower():find("stamina", 1, true) then
                pcall(function() inst.Value = 100 end)
            end
        end
    end)
 
    loop(0.1, function()
        if not CFG.noclip then return end
        local c = player.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Flying) end) end
    end)
 
    loop(0.5, function()
        local c = player.Character
        if not c then return end
        local goal = CFG.invisible and 1 or 0
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency ~= goal then
                p.Transparency = goal
            end
        end
    end)
 
    local flyVelo
    loop(0.05, function()
        local hrp = getHRP()
        if not CFG.fly then
            if flyVelo then pcall(function() flyVelo:Destroy() end); flyVelo = nil end
            if joyFrame then joyFrame.Visible = false end
            if flyBtnUp then flyBtnUp.Visible = false end
            if flyBtnDown then flyBtnDown.Visible = false end
            return
        end
        if not hrp then return end
        if joyFrame then joyFrame.Visible = true end
        if flyBtnUp then flyBtnUp.Visible = true end
        if flyBtnDown then flyBtnDown.Visible = true end
        if not flyVelo or not flyVelo.Parent then
            flyVelo = Instance.new("BodyVelocity")
            flyVelo.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            flyVelo.Parent = hrp
        end
        local cam = workspace.CurrentCamera
        local fwd = -cam.CFrame.LookVector
        fwd = Vector3.new(fwd.X, 0, fwd.Z)
        if fwd.Magnitude < 0.001 then fwd = Vector3.new(0, 0, -1) end
        fwd = fwd.Unit
        local right = cam.CFrame.RightVector
        right = Vector3.new(right.X, 0, right.Z)
        if right.Magnitude < 0.001 then right = Vector3.new(1, 0, 0) end
        right = right.Unit
 
        local d = Vector3.new()
        if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + fwd end
        if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - fwd end
        if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - right end
        if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + right end
        d = d + right * joyVec.X + fwd * joyVec.Y
        if UIS:IsKeyDown(Enum.KeyCode.Space) or upKey then
            d = d + Vector3.new(0, 1, 0)
        end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or downKey then
            d = d - Vector3.new(0, 1, 0)
        end
        local sp = (CFG.speed and CFG.speedVal or 16) * 3
        flyVelo.Velocity = d.Magnitude > 0 and (d.Unit * sp) or Vector3.new()
    end)
 
    loop(0.25, function()
        refreshCache()
        if CFG.tpBase then tpToPos(Vector3.new(29, 5, 53), 0, 0.4) end
        if CFG.tpTruck then
            local t = nearestFrom(cache.trucks, function(x) return x.part end)
            if t then tpToPos(t.part.Position, 3, 0.4) end
        end
        if CFG.tpSell then
            local s = nearestFrom(cache.sells)
            if s then tpToPos(s.Position, 2, 0.4) end
        end
        if CFG.tpLoot then
            local l = nearestFrom(cache.loot)
            if l then tpToPos(l.Position, 2, 0.4) end
        end
    end)
 
    -- автосбор: все промпты рядом, каждые 0.15с
    loop(0.15, function()
        if not CFG.autocollect then return end
        local prompts = promptsNear(18, true)
        local n = 0
        for _, pr in ipairs(prompts) do
            if n >= 6 then break end
            triggerPrompt(pr)
            n = n + 1
            lootPicked = lootPicked + 1
        end
    end)
 
    loop(0.6, function()
        if not CFG.autosell then return end
        refreshCache()
        local s, d = nearestFrom(cache.sells)
        if s and d and d < 30 then
            for _, pr in ipairs(promptsNear(20, false)) do triggerPrompt(pr) end
        end
    end)
 
    local farmState, farmIdx, farmTimer = 1, 0, 0
    loop(1.0, function()
        if not CFG.autofarm then
            farmState, farmTimer = 1, 0
            return
        end
        refreshCache()
        if #cache.loot == 0 then return end
        farmTimer = farmTimer + 1
        if farmState == 1 then
            farmIdx = farmIdx % #cache.loot + 1
            local p = cache.loot[farmIdx]
            if p then tpToPos(p.Position, 2, 1.2) end
            if farmTimer >= 22 then
                farmState, farmTimer = 2, 0
            end
        elseif farmState == 2 then
            local s = nearestFrom(cache.sells)
            if s then tpToPos(s.Position, 2, 1.2) end
            for _, pr in ipairs(promptsNear(20, false)) do triggerPrompt(pr) end
            if farmTimer >= 5 then
                farmState, farmTimer = 3, 0
            end
        elseif farmState == 3 then
            tpToPos(Vector3.new(29, 5, 53), 0, 1.2)
            if farmTimer >= 4 then
                farmState, farmTimer = 1, 0
            end
        end
    end)
 
    -- ESP: Highlight + подпись с дистанцией
    local function highlight(inst, color, enabled)
        if not inst or not inst.Parent then return end
        local h = espRegistry[inst]
        if enabled then
            if not h or not h.Parent then
                local ok, newH = pcall(function()
                    local x = Instance.new("Highlight")
                    x.Name = "CrimESP"
                    x.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    x.FillTransparency = 0.62
                    x.OutlineTransparency = 0
                    x.Parent = inst
                    return x
                end)
                if ok and newH then
                    h = newH
                    espRegistry[inst] = h
                end
            end
            if h then
                h.FillColor = color
                h.OutlineColor = color
                h.Enabled = true
            end
        elseif h and h.Parent then
            h.Enabled = false
        end
    end
 
    local function label(inst, text, color, enabled)
        if not inst or not inst.Parent then return end
        local bg = espLabels[inst]
        if enabled then
            if not bg or not bg.Parent then
                local ok, newBg = pcall(function()
                    local b = Instance.new("BillboardGui")
                    b.Name = "CrimESP_Label"
                    b.Size = UDim2.fromOffset(132, 22)
                    b.StudsOffset = Vector3.new(0, 3.2, 0)
                    b.AlwaysOnTop = true
                    b.MaxDistance = 320
                    local t = Instance.new("TextLabel")
                    t.Size = UDim2.fromScale(1, 1)
                    t.BackgroundTransparency = 0.45
                    t.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    t.TextColor3 = color
                    t.TextSize = 11
                    t.Font = Enum.Font.GothamBold
                    t.Text = text
                    t.Parent = b
                    b.Parent = inst
                    return b
                end)
                if ok and newBg then
                    bg = newBg
                    espLabels[inst] = bg
                end
            end
            if bg then
                local t = bg:FindFirstChildOfClass("TextLabel")
                if t then
                    t.Text = text
                    t.TextColor3 = color
                end
                bg.Enabled = true
            end
        elseif bg and bg.Parent then
            bg.Enabled = false
        end
    end
 
    loop(0.5, function()
        refreshCache()
        if not (CFG.espLoot or CFG.espPolice or CFG.espTruck) then
            for _, h in pairs(espRegistry) do
                if h and h.Parent then h.Enabled = false end
            end
            for _, b in pairs(espLabels) do
                if b and b.Parent then b.Enabled = false end
            end
            return
        end
        if CFG.espPolice then
            for _, inst in ipairs(cache.police) do
                local p = partOf(inst)
                local d = p and distTo(p.Position) or math.huge
                highlight(inst, RED, true)
                label(inst, string.format("POLICE %d", math.floor(d)), RED, true)
            end
        end
        if CFG.espTruck then
            for _, t in ipairs(cache.trucks) do
                local d = distTo(t.part.Position)
                highlight(t.model, YELLOW, true)
                label(t.model, string.format("TRUCK %d", math.floor(d)), YELLOW, true)
            end
        end
        if CFG.espLoot then
            local hrp = getHRP()
            if hrp then
                local near = {}
                for _, p in ipairs(cache.loot) do
                    near[#near + 1] = { part = p, d = (p.Position - hrp.Position).Magnitude }
                end
                table.sort(near, function(a, b) return a.d < b.d end)
                for i = 1, math.min(10, #near) do
                    highlight(near[i].part, GREEN, true)
                end
            end
        end
    end)
 
    loop(1, function()
        if not CFG.fullbright then return end
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        Lighting.ClockTime = 12
    end)
 
    local fps = 0
    RunService.RenderStepped:Connect(function(dt)
        if dt > 0 then fps = 1 / dt end
    end)
 
    local function fmtTime(t)
        t = math.floor(t)
        return string.format("%02d:%02d:%02d",
            math.floor(t / 3600), math.floor((t % 3600) / 60), t % 60)
    end
 
    local function readLevel()
        local ok, lvl = pcall(function()
            local ls = player:FindFirstChild("leaderstats")
            local v = ls and ls:FindFirstChild("Level")
            return v and v.Value
        end)
        if ok and lvl then return tostring(lvl) end
        return "?"
    end
 
    local function isWanted()
        local pg = player:FindFirstChild("PlayerGui")
        local hud = pg and pg:FindFirstChild("PoliceHud")
        local lbl = hud and hud:FindFirstChild("Wanted")
        local vis = false
        pcall(function() vis = lbl and lbl.Visible end)
        return vis
    end
 
    loop(0.5, function()
        local parts = {}
        if CFG.fps then parts[#parts + 1] = string.format("%.0f FPS", fps) end
        parts[#parts + 1] = fmtTime(os.clock() - sessionStart)
        parts[#parts + 1] = "Lv " .. readLevel()
        parts[#parts + 1] = "Loot " .. lootPicked
        if CFG.info then
            local _, td = nearestFrom(cache.trucks, function(x) return x.part end)
            local _, pd = nearestFrom(cache.police)
            if td == math.huge then td = -1 end
            if pd == math.huge then pd = -1 end
            parts[#parts + 1] = string.format("T%.0f P%.0f", td, pd)
            local sd = cache.safe and distTo(cache.safe.Position) or math.huge
            if sd < 40 then
                parts[#parts + 1] = "SAFE"
            elseif sd ~= math.huge then
                parts[#parts + 1] = string.format("Safe %.0f", sd)
            end
            if pd >= 0 and pd < 60 then parts[#parts + 1] = "!COP!" end
        end
        if isWanted() then parts[#parts + 1] = "WANTED" end
        status.Text = table.concat(parts, "  ")
    end)
 
    -- перетаскивание за шапку
    local dragging, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = panel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
 
    print("[CrimSim] v6 LUXE загружен. Правый Shift — меню.")
end
 
local ok, err = xpcall(main, function(e)
    return tostring(e) .. "\n" .. (debug and debug.traceback and debug.traceback() or "")
end)
if not ok then
    warn("[CrimSim] ОШИБКА: " .. tostring(err))
end
