--[[
    CITY CRIMINAL SIMULATOR — DELUXE MENU v2 (исправленная)
    Привязка к реальной структуре: Hideout.Truck, Town.Truck,
    LootSpawns/LootSpawn, Police, Sniper, SellZone, CargoZone.
    Все строки меню — через UIListLayout, поэтому панель отображается.
]]
 
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local WS = game:GetService("Workspace")
local player = Players.LocalPlayer
 
local CFG = {
    health=false, stamina=false, fall=false, autosprint=false,
    speed=false, speedVal=32, jump=false, jumpVal=100,
    noclip=false, fly=false,
    tpBase=false, tpTruck=false, tpLoot=false, tpSell=false,
    espPolice=false, espLoot=false, espTruck=false,
    autofarm=false, autosell=false,
    fullbright=false, fps=true, info=true,
}
local sessionStart = os.clock()
 
local function main()
    -- ========================================================
    --  УТИЛИТЫ
    -- ========================================================
    local function findAll(root, name, maxDepth, out, depth)
        out = out or {}
        depth = depth or 0
        if depth > (maxDepth or 5) then return out end
        if root:IsA("Terrain") then return out end
        for _, ch in ipairs(root:GetChildren()) do
            if ch.Name == name then out[#out+1] = ch end
            if ch:IsA("Model") or ch:IsA("Folder") then
                findAll(ch, name, maxDepth, out, depth + 1)
            end
        end
        return out
    end
 
    local function getHRP()
        local c = player.Character
        return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
    end
    local function getHum()
        local c = player.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end
    local function tpToPart(part, offset)
        local hrp = getHRP()
        if hrp and part and part:IsA("BasePart") then
            pcall(function()
                hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, offset or 3, 0))
            end)
        end
    end
 
    -- кеш объектов (обновляется раз в 3 сек, а не каждый кадр)
    local cache = { loot = {}, trucks = {}, police = {}, sells = {}, t = -99 }
    local function refreshCache()
        local now = os.clock()
        if now - cache.t < 3 then return end
        cache.t = now
 
        local loot = {}
        for _, folder in ipairs(findAll(WS, "LootSpawns", 4)) do
            for _, p in ipairs(folder:GetChildren()) do
                if p:IsA("BasePart") and p.Name == "LootSpawn" then
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
 
    local function partOf(inst)
        if inst:IsA("BasePart") then return inst end
        if inst:IsA("Model") then
            return inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")
        end
        return nil
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
 
    -- ========================================================
    --  UI
    -- ========================================================
    local sg = Instance.new("ScreenGui")
    sg.Name = "CrimSimDeluxe"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999
    sg.Parent = player:WaitForChild("PlayerGui", 10) or game:GetService("CoreGui")
 
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(280, 470)
    frame.Position = UDim2.fromOffset(16, 60)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    frame.BackgroundTransparency = 0.06
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
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.fromOffset(10, 0)
    title.BackgroundTransparency = 1
    title.Text = "CITY CRIMINAL SIMULATOR"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(235, 235, 250)
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.Parent = bar
 
    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(24, 24)
    close.Position = UDim2.new(1, -28, 0, 3)
    close.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    close.BorderSizePixel = 0
    close.Text = "×"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.TextSize = 16
    close.Font = Enum.Font.GothamBold
    close.Parent = bar
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 5); cc.Parent = close
 
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
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = l
    end
 
    local function addToggle(key, text, desc, onF, offF)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 40)
        row.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
        row.BorderSizePixel = 0
        row.LayoutOrder = nextOrder()
        row.Parent = sc
        local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 5); rc.Parent = row
 
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
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 5); bc.Parent = btn
 
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
 
    -- ========================================================
    --  МЕНЮ
    -- ========================================================
    addSection("PLAYER")
    addToggle("health",   "Infinite Health",  "Не умирает")
    addToggle("stamina",  "Infinite Stamina", "Выносливость вечная")
    addToggle("speed",    "Speed x2",         "Скорость 32",      function() CFG.speedVal = 32 end)
    addToggle("jump",     "Jump Boost",       "Прыжок 100",       function() CFG.jumpVal = 100 end)
    addToggle("autosprint","Auto Sprint",     "Всегда бежит")
    addToggle("fall",     "No Fall Damage",   "Нет урона от падения")
 
    addSection("MOVEMENT")
    addToggle("noclip",   "Noclip",           "Сквозь стены")
    addToggle("fly",      "Fly",              "WASD + Space/Ctrl")
    addToggle("tpBase",   "TP to Base",       "В логово")
    addToggle("tpTruck",  "TP to Truck",      "К ближайшему грузовику")
    addToggle("tpLoot",   "TP to Loot",       "К ближайшему спавну")
    addToggle("tpSell",   "TP to Sell",       "К точке сдачи")
 
    addSection("ESP")
    addToggle("espPolice","ESP Police",       "Подсветка полиции")
    addToggle("espLoot",  "ESP Loot",         "Подсветка лута")
    addToggle("espTruck", "ESP Truck",        "Подсветка грузовиков")
 
    addSection("AUTO FARM")
    addToggle("autofarm", "Auto Farm",        "Обход спавнов лута")
    addToggle("autosell", "Auto Sell",        "Идёт к точке сдачи")
 
    addSection("QUALITY OF LIFE")
    addToggle("fullbright","FullBright",      "Светло, время 12:00")
    addToggle("fps",      "FPS Counter",      "Показывать FPS")
    addToggle("info",     "Info / Distances", "До Truck и Police")
 
    -- ========================================================
    --  LOOPS
    -- ========================================================
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
 
    -- player
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
            if s and s:IsA("ValueBase") then s.Value = s.MaxValue end
        end
    end)
 
    loop(0.3, function()
        if not CFG.fall then return end
        local h = getHum()
        if h then h:ChangeState(Enum.HumanoidStateType.Running) end
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
 
    -- noclip
    loop(0.1, function()
        if not CFG.noclip then return end
        local c = player.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
 
    -- fly
    local flyVelo
    loop(0.05, function()
        local hrp = getHRP()
        if not CFG.fly then
            if flyVelo then flyVelo:Destroy(); flyVelo = nil end
            return
        end
        if not hrp then return end
        if not flyVelo or not flyVelo.Parent then
            flyVelo = Instance.new("BodyVelocity")
            flyVelo.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            flyVelo.Parent = hrp
        end
        local dir = Vector3.new()
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + hrp.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - hrp.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - hrp.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + hrp.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        local sp = (CFG.speed and CFG.speedVal or 16) * 3
        flyVelo.Velocity = dir.Magnitude > 0 and (dir.Unit * sp) or Vector3.new()
    end)
 
    -- teleports
    loop(0.25, function()
        refreshCache()
        if CFG.tpBase then
            local hideout = WS:FindFirstChild("Hideout")
            local target = hideout and (hideout:FindFirstChild("SellLever") or hideout.PrimaryPart)
            local p = target and partOf(target)
            if not p and hideout then p = hideout:FindFirstChildOfClass("BasePart") end
            if p then tpToPart(p, 3) end
        end
        if CFG.tpTruck then
            local t = nearestFrom(cache.trucks, function(x) return x.part end)
            if t then tpToPart(t.part, 3) end
        end
        if CFG.tpLoot then
            local t = nearestFrom(cache.loot)
            if t then tpToPart(t, 2) end
        end
        if CFG.tpSell then
            local t = nearestFrom(cache.sells)
            if t then tpToPart(t, 2) end
        end
    end)
 
    -- auto farm
    local farmIdx = 0
    loop(1.8, function()
        refreshCache()
        if not CFG.autofarm then return end
        local n = #cache.loot
        if n == 0 then return end
        local hrp = getHRP()
        if not hrp then return end
        farmIdx = (farmIdx % n) + 1
        local p = cache.loot[farmIdx]
        if p and p.Parent then
            pcall(function() hrp.CFrame = CFrame.new(p.Position + Vector3.new(0, 2, 0)) end)
        end
    end)
 
    -- auto sell: если рядом грузовик — к зоне продажи
    loop(2.5, function()
        refreshCache()
        if not CFG.autosell then return end
        local truck, td = nearestFrom(cache.trucks, function(x) return x.part end)
        if not truck or td > 40 then return end
        local zone = nearestFrom(cache.sells)
        if zone then tpToPart(zone, 2) end
    end)
 
    -- ESP через Highlight (работает без Drawing)
    local espRegistry = {}
    local function highlight(inst, color, enabled)
        if not inst or not inst.Parent then return end
        local h = espRegistry[inst]
        if enabled then
            if not h or not h.Parent then
                h = Instance.new("Highlight")
                h.Name = "CrimESP"
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.FillTransparency = 0.6
                h.OutlineTransparency = 0
                h.Parent = inst
                espRegistry[inst] = h
            end
            h.FillColor = color
            h.OutlineColor = color
            h.Enabled = true
        elseif h and h.Parent then
            h.Enabled = false
        end
    end
 
    local function clearGroup(list, getPart, enable)
        for _, inst in ipairs(list) do
            local target = getPart and getPart(inst) or inst
            highlight(target, Color3.new(1, 1, 1), enable)
        end
    end
 
    loop(0.5, function()
        refreshCache()
        -- police
        for _, inst in ipairs(cache.police) do
            highlight(inst, Color3.fromRGB(255, 70, 70), CFG.espPolice)
        end
        -- truck
        for _, t in ipairs(cache.trucks) do
            highlight(t.model, Color3.fromRGB(255, 210, 70), CFG.espTruck)
        end
        -- loot: только ближайшие 12, чтобы не спамить Highlight
        local hrp = getHRP()
        if hrp then
            local near = {}
            for _, p in ipairs(cache.loot) do
                local d = (p.Position - hrp.Position).Magnitude
                near[#near + 1] = { part = p, d = d }
            end
            table.sort(near, function(a, b) return a.d < b.d end)
            for i, item in ipairs(near) do
                highlight(item.part, Color3.fromRGB(80, 255, 130), CFG.espLoot and i <= 12)
            end
        end
    end)
 
    -- fullbright
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
 
    -- статус
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
 
    -- ========================================================
    --  DRAG + KEYBIND
    -- ========================================================
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
 
    close.MouseButton1Click:Connect(function() sg.Enabled = false end)
    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            sg.Enabled = not sg.Enabled
        end
    end)
 
    print("[CrimSim Deluxe] Загружено. Правый Shift — открыть/скрыть меню.")
end
 
local ok, err = xpcall(main, function(e)
    return tostring(e) .. "\n" .. (debug and debug.traceback and debug.traceback() or "")
end)
if not ok then
    warn("[CrimSim Deluxe] ОШИБКА: " .. tostring(err))
end
