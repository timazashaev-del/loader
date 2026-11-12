[[
    CITY CRIMINAL SIMULATOR — ULTIMATE FUNCTIONS (final rewrite)
    Версия 4.0. Вся структура игры взята из реального дампа:
      Workspace: Hideout/Truck, Town/Truck + PoliceStation, Desert, NewMap,
                 LootSpawns/LootSpawn, SellZone (SellBox, ChopShop),
                 Police, Sniper, ArmoredTruck
      ReplicatedStorage.Remotes: LootGrab, LootRelease, ShopBuy, CardCharge ...
    Меню: перетаскивание, сворачивание (−), закрытие (×), правый Shift.
    Флай: мобильный джойстик + кнопки UP/DOWN, на ПК WASD+Space/Ctrl.
    Все циклы защищены pcall. Скрипт не падает ни при какой ошибке.
]]
 
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
 
local CFG = {
    health = false, stamina = false, fall = false, autosprint = false,
    speed = false, speedVal = 32, jump = false, jumpVal = 100,
    noclip = false, fly = false,
    tpBase = false, tpTruck = false, tpLoot = false, tpSell = false,
    espPolice = false, espLoot = false, espTruck = false,
    autocollect = false, autofarm = false,
    invisible = false, fullbright = false, fps = true, info = true,
}
local sessionStart = os.clock()
local savedPositions = {}
local basePoint, truckPoint, sellPoint
 
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
    local function tpToPos(pos, off)
        local hrp = getHRP()
        if hrp and pos then
            pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, off or 3, 0)) end)
        end
    end
    local function partOf(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then return inst end
        if inst:IsA("Model") then
            return inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")
        end
        return nil
    end
 
    local function findAll(root, name, maxDepth, out, depth)
        out = out or {}
        depth = depth or 0
        if depth > (maxDepth or 5) then return out end
        if root:IsA("Terrain") then return out end
        for _, ch in ipairs(root:GetChildren()) do
            if ch.Name == name then out[#out + 1] = ch end
            if ch:IsA("Model") or ch:IsA("Folder") then
                findAll(ch, name, maxDepth, out, depth + 1)
            end
        end
        return out
    end
 
    -- Кеш игровых объектов: обновляется раз в 3 секунды (не грузит кадр)
    local cache = { loot = {}, trucks = {}, police = {}, sells = {}, t = -99 }
    local function refreshCache()
        local now = os.clock()
        if now - cache.t < 3 then return end
        cache.t = now
 
        local loot = {}
        for _, folder in ipairs(findAll(WS, "LootSpawns", 4)) do
            for _, p in ipairs(folder:GetChildren()) do
                if p:IsA("BasePart") and (p.Name == "LootSpawn" or p.Name:lower() == "lootspawn") then
                    loot[#loot + 1] = p
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
 
        local police = {}
        local pf = WS:FindFirstChild("Police")
        if pf then
            for _, ch in ipairs(pf:GetChildren()) do
                if ch:IsA("Model") or ch:IsA("BasePart") then police[#police + 1] = ch end
            end
        end
        for _, sn in ipairs(findAll(WS, "Sniper", 4)) do
            if sn:IsA("Model") then police[#police + 1] = sn end
        end
        local town = WS:FindFirstChild("Town")
        local station = town and town:FindFirstChild("PoliceStation")
        if station then police[#police + 1] = station end
        cache.police = police
 
        local sells = {}
        for _, s in ipairs(findAll(WS, "SellZone", 4)) do
            if s:IsA("BasePart") then sells[#sells + 1] = s end
        end
        cache.sells = sells
    end
 
    local function nearestFrom(list, getPart)
        local hrp = getHRP()
        if not hrp then return nil, math.huge end
        local best, bd = nil, math.huge
        for _, item in ipairs(list) do
            local p = getPart and getPart(item) or partOf(item)
            if p and p:IsA("BasePart") then
                local d = (p.Position - hrp.Position).Magnitude
                if d < bd then bd, best = d, item end
            end
        end
        return best, bd
    end
 
    -- Ближайший сброшенный лут по ключевым словам (для автосбора/фарма)
    local LOOT_KEYS = { "loot", "money", "cash", "diamond", "gem", "item", "box" }
    local function nearestDropped(maxDist)
        local hrp = getHRP()
        if not hrp then return nil end
        local best, bd = nil, math.huge
        for _, part in ipairs(WS:GetDescendants()) do
            local ok, nm, d = false, nil, nil
            pcall(function()
                if part:IsA("BasePart") and part.Parent then
                    nm = part.Name:lower()
                    for _, kw in ipairs(LOOT_KEYS) do
                        if nm:find(kw, 1, true) then ok = true break end
                    end
                    if ok then d = (part.Position - hrp.Position).Magnitude end
                end
            end)
            if ok and d and d < bd then bd, best = d, part end
        end
        if bd <= (maxDist or 400) then return best end
        return nil
    end
 
    -- ================= UI =================
    local sg = Instance.new("ScreenGui")
    sg.Name = "CrimSimUltimate"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999
    sg.Parent = player:WaitForChild("PlayerGui", 10) or game:GetService("CoreGui")
 
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(290, 520)
    frame.Position = UDim2.fromOffset(16, 60)
    frame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.ClipsDescendants = true
    frame.Parent = sg
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 70, 95)
    stroke.Thickness = 1
    stroke.Parent = frame
 
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
    bar.BorderSizePixel = 0
    bar.Parent = frame
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 8)
    barCorner.Parent = bar
 
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -118, 1, 0)
    title.Position = UDim2.fromOffset(10, 0)
    title.BackgroundTransparency = 1
    title.Text = "CRIMINAL SIMULATOR"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(235, 235, 250)
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.Parent = bar
 
    local btnMin = Instance.new("TextButton")
    btnMin.Size = UDim2.fromOffset(24, 24)
    btnMin.Position = UDim2.new(1, -58, 0, 3)
    btnMin.BackgroundColor3 = Color3.fromRGB(80, 80, 110)
    btnMin.BorderSizePixel = 0
    btnMin.Text = "−"
    btnMin.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnMin.TextSize = 16
    btnMin.Font = Enum.Font.GothamBold
    btnMin.Parent = bar
    local mc = Instance.new("UICorner")
    mc.CornerRadius = UDim.new(0, 5)
    mc.Parent = btnMin
 
    local btnClose = Instance.new("TextButton")
    btnClose.Size = UDim2.fromOffset(24, 24)
    btnClose.Position = UDim2.new(1, -30, 0, 3)
    btnClose.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    btnClose.BorderSizePixel = 0
    btnClose.Text = "×"
    btnClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnClose.TextSize = 16
    btnClose.Font = Enum.Font.GothamBold
    btnClose.Parent = bar
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 5)
    cc.Parent = btnClose
 
    local sc = Instance.new("ScrollingFrame")
    sc.Size = UDim2.new(1, 0, 1, -52)
    sc.Position = UDim2.fromOffset(0, 30)
    sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0
    sc.CanvasSize = UDim2.new(0, 0, 0, 0)
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.ScrollBarThickness = 4
    sc.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 120)
    sc.Parent = frame
 
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 2)
    list.Parent = sc
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    pad.Parent = sc
 
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -12, 0, 20)
    status.Position = UDim2.new(0, 6, 1, -22)
    status.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    status.BorderSizePixel = 0
    status.Text = ""
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextColor3 = Color3.fromRGB(255, 220, 120)
    status.TextSize = 11
    status.Font = Enum.Font.Gotham
    status.Parent = frame
 
    -- сворачивание/закрытие
    local minimized = false
    local fullSize = frame.Size
    local function applyMin()
        frame.Size = minimized and UDim2.fromOffset(290, 30) or fullSize
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
 
    local order = 0
    local function nextOrder() order = order + 1; return order end
 
    local function addSection(text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -4, 0, 22)
        l.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
        l.BorderSizePixel = 0
        l.Text = "  " .. text
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = Color3.fromRGB(120, 190, 255)
        l.TextSize = 11
        l.Font = Enum.Font.GothamBold
        l.LayoutOrder = nextOrder()
        l.Parent = sc
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = l
    end
 
    local function addToggle(key, text, desc, onF, offF)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 40)
        row.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
        row.BorderSizePixel = 0
        row.LayoutOrder = nextOrder()
        row.Parent = sc
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 5)
        rc.Parent = row
 
        local nm = Instance.new("TextLabel")
        nm.Size = UDim2.new(1, -52, 0, 18)
        nm.Position = UDim2.fromOffset(8, 2)
        nm.BackgroundTransparency = 1
        nm.Text = text
        nm.TextXAlignment = Enum.TextXAlignment.Left
        nm.TextColor3 = Color3.fromRGB(235, 235, 245)
        nm.TextSize = 12
        nm.Font = Enum.Font.Gotham
        nm.Parent = row
 
        local ds = Instance.new("TextLabel")
        ds.Size = UDim2.new(1, -52, 0, 14)
        ds.Position = UDim2.fromOffset(8, 20)
        ds.BackgroundTransparency = 1
        ds.Text = desc or ""
        ds.TextXAlignment = Enum.TextXAlignment.Left
        ds.TextColor3 = Color3.fromRGB(140, 140, 160)
        ds.TextSize = 9
        ds.Font = Enum.Font.Gotham
        ds.TextTruncate = Enum.TextTruncate.AtEnd
        ds.Parent = row
 
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(38, 20)
        btn.Position = UDim2.new(1, -46, 0, 10)
        btn.BackgroundColor3 = Color3.fromRGB(85, 85, 100)
        btn.BorderSizePixel = 0
        btn.Text = "OFF"
        btn.TextSize = 9
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.AutoButtonColor = false
        btn.Parent = row
        local btc = Instance.new("UICorner")
        btc.CornerRadius = UDim.new(0, 5)
        btc.Parent = btn
 
        local function refresh()
            if CFG[key] then
                btn.BackgroundColor3 = Color3.fromRGB(70, 180, 90)
                btn.Text = "ON"
            else
                btn.BackgroundColor3 = Color3.fromRGB(85, 85, 100)
                btn.Text = "OFF"
            end
        end
        btn.MouseButton1Click:Connect(function()
            CFG[key] = not CFG[key]
            refresh()
            if CFG[key] and onF then pcall(onF) end
            if not CFG[key] and offF then pcall(offF) end
        end)
        refresh()
    end
 
    local function addButton(text, desc, fn)
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -4, 0, 34)
        row.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
        row.BorderSizePixel = 0
        row.Text = text
        row.TextColor3 = Color3.fromRGB(235, 235, 250)
        row.TextSize = 12
        row.Font = Enum.Font.GothamBold
        row.LayoutOrder = nextOrder()
        row.Parent = sc
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 5)
        rc.Parent = row
        local tp = Instance.new("TextLabel")
        tp.Size = UDim2.new(1, -20, 0, 14)
        tp.Position = UDim2.fromOffset(10, 18)
        tp.BackgroundTransparency = 1
        tp.Text = desc or ""
        tp.TextXAlignment = Enum.TextXAlignment.Left
        tp.TextColor3 = Color3.fromRGB(140, 140, 165)
        tp.TextSize = 9
        tp.Font = Enum.Font.Gotham
        tp.Parent = row
        row.MouseButton1Click:Connect(function() pcall(fn) end)
    end
 
    -- ================= МЕНЮ =================
    addSection("PLAYER")
    addToggle("health",   "Infinite Health",  "Не умирает")
    addToggle("stamina",  "Infinite Stamina", "Выносливость вечная")
    addToggle("speed",    "Speed x2",         "Скорость 32",        function() CFG.speedVal = 32 end)
    addToggle("jump",     "Jump Boost",       "Прыжок 100",         function() CFG.jumpVal = 100 end)
    addToggle("autosprint","Auto Sprint",     "Всегда бежит")
    addToggle("fall",     "No Fall Damage",   "Нет урона от падения")
    addToggle("invisible","Invisibility",     "Прозрачность (локально)")
 
    addSection("MOVEMENT")
    addToggle("noclip",   "Noclip",           "Сквозь стены")
    addToggle("fly",      "Fly",              "Джойстик / WASD+Space")
 
    addSection("TELEPORT")
    addButton("Save position", "Сохранить точку", function()
        local hrp = getHRP()
        if hrp then table.insert(savedPositions, hrp.CFrame) end
    end)
    addButton("TP to saved", "К последней точке", function()
        if #savedPositions > 0 then
            pcall(function() getHRP().CFrame = savedPositions[#savedPositions] end)
        end
    end)
    addButton("Set Base here", "Запомнить базу", function()
        local hrp = getHRP()
        if hrp then basePoint = hrp.Position end
    end)
    addToggle("tpBase",  "TP to Base",  "К базе")
    addButton("Set Truck here", "Запомнить грузовик", function()
        local hrp = getHRP()
        if hrp then truckPoint = hrp.Position end
    end)
    addToggle("tpTruck", "TP to Truck", "К грузовику")
    addButton("Set Sell here", "Запомнить точку продажи", function()
        local hrp = getHRP()
        if hrp then sellPoint = hrp.Position end
    end)
    addToggle("tpSell",  "TP to Sell",  "К точке продажи")
    addToggle("tpLoot",  "TP to Loot",  "К ближайшему спавну лута")
 
    addSection("FARM / COLLECT")
    addToggle("autocollect", "Auto Collect", "Подбор лута поблизости")
    addToggle("autofarm",   "Auto Farm route", "Лут → продажа → база")
 
    addSection("ESP")
    addToggle("espPolice", "ESP Police", "Подсветка полиции")
    addToggle("espLoot",   "ESP Loot",   "Подсветка спавнов лута")
    addToggle("espTruck",  "ESP Truck",  "Подсветка грузовиков")
 
    addSection("QUALITY OF LIFE")
    addToggle("fullbright","FullBright", "Светло, время 12:00")
    addToggle("fps",       "FPS Counter", "Показывать FPS")
    addToggle("info",      "Info / Distances", "Расстояния до Truck/Police")
 
    -- ================= ДЖОЙСТИК (мобильный флай) =================
    local joyFrame, knob, joyVec = nil, nil, Vector2.new()
    local flyBtnUp, flyBtnDown
    local upKey, downKey = false, false
 
    if UIS.TouchEnabled then
        joyFrame = Instance.new("Frame")
        joyFrame.AnchorPoint = Vector2.new(0, 1)
        joyFrame.Position = UDim2.new(0.06, 0, 1, -24)
        joyFrame.Size = UDim2.fromOffset(130, 130)
        joyFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        joyFrame.BackgroundTransparency = 0.85
        joyFrame.Visible = false
        joyFrame.Parent = sg
        local jc = Instance.new("UICorner")
        jc.CornerRadius = UDim.new(1, 0)
        jc.Parent = joyFrame
 
        knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(48, 48)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.fromScale(0.5, 0.5)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BackgroundTransparency = 0.3
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
        flyBtnUp.Position = UDim2.new(0.9, 0, 1, -170)
        flyBtnUp.Size = UDim2.fromOffset(64, 64)
        flyBtnUp.BackgroundColor3 = Color3.fromRGB(120, 120, 255)
        flyBtnUp.BackgroundTransparency = 0.4
        flyBtnUp.Text = "UP"
        flyBtnUp.TextColor3 = Color3.fromRGB(255, 255, 255)
        flyBtnUp.Font = Enum.Font.GothamBold
        flyBtnUp.Visible = false
        flyBtnUp.Parent = sg
        local uc = Instance.new("UICorner")
        uc.CornerRadius = UDim.new(1, 0)
        uc.Parent = flyBtnUp
        flyBtnDown = flyBtnUp:Clone()
        flyBtnDown.Position = UDim2.new(0.9, 0, 1, -92)
        flyBtnDown.Text = "DOWN"
        flyBtnDown.Parent = sg
 
        flyBtnUp.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                upKey = true
            end
        end)
        flyBtnUp.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                upKey = false
            end
        end)
        flyBtnDown.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                downKey = true
            end
        end)
        flyBtnDown.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
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
 
    loop(0.4, function()
        if not CFG.health then return end
        local h = getHum()
        if h and h.Health > 0 then h.Health = h.MaxHealth end
    end)
 
    loop(0.2, function()
        if not CFG.stamina then return end
        local h = getHum()
        if h then
            local s = h:FindFirstChild("Stamina")
            if s and s:IsA("ValueBase") then
                pcall(function() s.Value = s.MaxValue end)
            end
        end
    end)
 
    loop(0.3, function()
        if not CFG.fall then return end
        local h = getHum()
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end) end
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
 
    -- ФЛАЙ: джойстик (моб.) / WASD (ПК), движение от камеры
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
        if UIS:IsKeyDown(Enum.KeyCode.Space) or upKey then d = d + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or downKey then d = d - Vector3.new(0, 1, 0) end
        local sp = (CFG.speed and CFG.speedVal or 16) * 3
        flyVelo.Velocity = d.Magnitude > 0 and (d.Unit * sp) or Vector3.new()
    end)
 
    -- ТЕЛЕПОРТЫ: пока тумблер включён — держат точку (каждые 0.25с)
    loop(0.25, function()
        refreshCache()
        if CFG.tpBase and basePoint then tpToPos(basePoint, 3) end
        if CFG.tpTruck and truckPoint then tpToPos(truckPoint, 3) end
        if CFG.tpSell and sellPoint then tpToPos(sellPoint, 3) end
        if CFG.tpLoot then
            local t = nearestFrom(cache.loot)
            if t then tpToPos(t.Position, 2) end
        end
    end)
 
    -- АВТОСБОР: подбирает лут рядом (Remote LootGrab, если есть)
    loop(0.4, function()
        if not CFG.autocollect then return end
        local hrp = getHRP()
        if not hrp then return end
        local remotes = RS:FindFirstChild("Remotes")
        local grab = remotes and remotes:FindFirstChild("LootGrab")
        for _, part in ipairs(WS:GetDescendants()) do
            local isLoot = false
            pcall(function()
                if part:IsA("BasePart") and part.Parent and part ~= hrp then
                    local nm = part.Name:lower()
                    for _, kw in ipairs(LOOT_KEYS) do
                        if nm:find(kw, 1, true) then isLoot = true break end
                    end
                end
            end)
            if isLoot and (part.Position - hrp.Position).Magnitude < 14 then
                if grab and grab:IsA("RemoteEvent") then
                    pcall(function() grab:FireServer(part) end)
                end
                pcall(function() part.CFrame = hrp.CFrame - Vector3.new(0, 2, 0) end)
            end
        end
    end)
 
    -- АВТОФАРМ РОУТ: лут → точка продажи → база
    local farmState = 1
    loop(1.0, function()
        if not CFG.autofarm then
            farmState = 1
            return
        end
        local hrp = getHRP()
        if not hrp then return end
        if farmState == 1 then
            local target = nearestDropped(400)
            if target then
                tpToPos(target.Position, 2)
            else
                farmState = 2
            end
        elseif farmState == 2 then
            if sellPoint then tpToPos(sellPoint, 3) end
            farmState = 3
        elseif farmState == 3 then
            if basePoint then tpToPos(basePoint, 3) end
            farmState = 1
        end
    end)
 
    -- ESP через Highlight (без Drawing — работает везде)
    local espRegistry = {}
    local function highlight(inst, color, enabled)
        if not inst or not inst.Parent then return end
        local h = espRegistry[inst]
        if enabled then
            if not h or not h.Parent then
                local ok, newH = pcall(function()
                    local x = Instance.new("Highlight")
                    x.Name = "CrimESP"
                    x.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    x.FillTransparency = 0.6
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
 
    loop(0.5, function()
        refreshCache()
        local anyOn = CFG.espPolice or CFG.espLoot or CFG.espTruck
        if not anyOn then
            for _, h in pairs(espRegistry) do
                if h and h.Parent then h.Enabled = false end
            end
            return
        end
        -- police
        for _, inst in ipairs(cache.police) do
            highlight(inst, Color3.fromRGB(255, 70, 70), CFG.espPolice)
        end
        -- truck
        for _, t in ipairs(cache.trucks) do
            highlight(t.model, Color3.fromRGB(255, 210, 70), CFG.espTruck)
        end
        -- loot: только ближайшие 12
        if CFG.espLoot then
            local hrp = getHRP()
            if hrp then
                local near = {}
                for _, p in ipairs(cache.loot) do
                    local d = (p.Position - hrp.Position).Magnitude
                    near[#near + 1] = { part = p, d = d }
                end
                table.sort(near, function(a, b) return a.d < b.d end)
                for i = 1, math.min(12, #near) do
                    highlight(near[i].part, Color3.fromRGB(80, 255, 130), true)
                end
            end
        end
    end)
 
    -- НЕВИДИМОСТЬ (локальная прозрачность)
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
 
    -- FULLBRIGHT
    loop(1, function()
        if not CFG.fullbright then return end
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        Lighting.ClockTime = 12
    end)
 
    -- FPS
    local fps = 0
    RunService.RenderStepped:Connect(function(dt)
        if dt > 0 then fps = 1 / dt end
    end)
 
    local function fmtTime(t)
        t = math.floor(t)
        return string.format("%02d:%02d:%02d",
            math.floor(t / 3600), math.floor((t % 3600) / 60), t % 60)
    end
 
    -- СТАТУС
    loop(0.5, function()
        local parts = {}
        if CFG.fps then parts[#parts + 1] = string.format("FPS %.0f", fps) end
        parts[#parts + 1] = "S " .. fmtTime(os.clock() - sessionStart)
        if CFG.info then
            local _, td = nearestFrom(cache.trucks, function(x) return x.part end)
            local _, pd = nearestFrom(cache.police, function(x) return partOf(x) end)
            if td == math.huge then td = -1 end
            if pd == math.huge then pd = -1 end
            parts[#parts + 1] = string.format("T %.0f P %.0f", td, pd)
            if pd >= 0 and pd < 60 then parts[#parts + 1] = "!POLICE!" end
        end
        status.Text = table.concat(parts, "  ")
    end)
 
    -- ПЕРЕТАСКИВАНИЕ
    local dragging, dragStart, startPos = false, nil, nil
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
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
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
 
    print("[CrimSim ULTIMATE] Загружено. Правый Shift — меню.")
end
 
local ok, err = xpcall(main, function(e)
    return tostring(e) .. "\n" .. (debug and debug.traceback and debug.traceback() or "")
end)
if not ok then
    warn("[CrimSim ULTIMATE] ОШИБКА: " .. tostring(err))
end
