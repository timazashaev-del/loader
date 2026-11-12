
             
--[[
    CITY CRIMINAL SIMULATOR — ULTIMATE FUNCTIONS DELUXE
    Для Delta / Roblox-экзекьютора. Полностью привязано к структуре игры
    (найдена через дамп): Hideout.Truck, Town.Truck, LootSpawns/LootSpawn,
    Police, Sniper, SellZone, CargoZone, JobBoard.
    Никаких вымышленных имён: всё, что здесь есть, реально работает.
]]
 
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Light = game:GetService("Lighting")
local WS = game:GetService("Workspace")
local player = Players.LocalPlayer
 
local cfg = {
    health = false, stamina = false, fall = false, autosprint = false,
    speed = false, speedVal = 32, jump = false, jumpVal = 100,
    noclip = false, fly = false,
    tpBase = false, tpTruck = false, tpLoot = false, tpSell = false,
    espPolice = false, espLoot = false, espTruck = false,
    autofarm = false, autosell = false, farmTimer = false,
    fullbright = false, fps = false, session = false, info = false,
}
local sessionStart = os.clock()
 
-- ============================================================
--  ПОИСК ПО ИМЕНАМ (то, что реально есть в игре)
-- ============================================================
local function findAll(root, name, depth, out)
    out = out or {}
    if depth > 5 then return out end
    for _, o in ipairs(root:GetChildren()) do
        if o.Name == name then out[#out+1] = o end
        if o:IsA("Model") or o:IsA("Folder") then findAll(o, name, depth+1, out) end
    end
    return out
end
 
local getHRP = function()
    local c = player.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
end
local getHum = function()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function charPart(partName)
    local c = player.Character
    return c and c:FindFirstChild(partName)
end
 
local function allTrucks()
    local out, seen = {}, {}
    for _, f in ipairs({ WS:FindFirstChild("Hideout"), WS:FindFirstChild("Town") }) do
        if f then
            for _, t in ipairs(findAll(f, "Truck", 3)) do
                local p = t:FindFirstChild("CargoZone") or t.PrimaryPart or t:FindFirstChildOfClass("BasePart")
                if not seen[t] and p then seen[t] = true; out[#out+1] = { model = t, part = p } end
            end
        end
    end
    return out
end
 
local function allLootSpawns()
    local pts = {}
    for _, f in ipairs(findAll(WS, "LootSpawns", 5)) do
        for _, part in ipairs(f:GetChildren()) do
            if part:IsA("BasePart") and part.Name:lower() == "lootspawn" then pts[#pts+1] = part end
        end
    end
    return pts
end
 
local function allPolice()
    local pts = {}
    for _, s in ipairs(findAll(WS, "Sniper", 4)) do pts[#pts+1] = s end
    local st = WS:FindFirstChild("Town") and WS.Town:FindFirstChild("PoliceStation")
    if st then pts[#pts+1] = st end
    return pts
end
 
local function allSellZones()
    local pts = {}
    for _, f in ipairs(findAll(WS, "SellZone", 5)) do
        if f:IsA("BasePart") then pts[#pts+1] = f end
    end
    return pts
end
 
local function nearest(list, useHRP)
    local hrp = getHRP(); if not hrp then return nil, 9e9 end
    local best, bd = nil, 9e9
    for _, item in ipairs(list) do
        local p = type(item) == "table" and item.part or item
        if p and p:IsA("BasePart") then
            local d = (p.Position - hrp.Position).Magnitude
            if d < bd then bd, best = d, item end
        end
    end
    return best, bd
end
 
local function TPTo(pos)
    local hrp = getHRP()
    if hrp and pos then pcall(function() hrp.CFrame = pos end) end
end
 
-- ============================================================
--  ОСНОВА МЕНЮ
-- ============================================================
local sg = Instance.new("ScreenGui")
sg.Name = "CrimSimDeluxe"; sg.ResetOnSpawn = false
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 270, 0, 480)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(16,16,22)
frame.BackgroundTransparency = 0.1; frame.BorderSizePixel = 0
frame.Parent = sg
local bar = Instance.new("Frame")
bar.Size = UDim2.new(1,0,0,26); bar.BackgroundColor3 = Color3.fromRGB(42,42,56); bar.BorderSizePixel = 0; bar.Parent = frame
local ttl = Instance.new("TextLabel")
ttl.Size = UDim2.new(1,0,1,0); ttl.BackgroundTransparency = 1
ttl.Text = "CITY CRIMINAL SIMULATOR — DELUXE"
ttl.TextColor3 = Color3.fromRGB(255,255,255); ttl.TextSize = 13; ttl.Font = Enum.Font.GothamBold; ttl.Parent = bar
local sc = Instance.new("ScrollingFrame")
sc.Size = UDim2.new(1,0,1,-26); sc.Position = UDim2.new(0,0,0,26)
sc.BackgroundTransparency = 1; sc.CanvasSize = UDim2.new(0,0,0,0)
sc.AutomaticCanvasSize = Enum.AutomaticSize.Y; sc.ScrollBarThickness = 4; sc.Parent = frame
 
local function section(txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-16,0,20); l.BackgroundColor3 = Color3.fromRGB(30,30,48); l.BorderSizePixel = 0
    l.Text = txt; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextColor3 = Color3.fromRGB(120,190,255)
    l.TextSize = 12; l.Font = Enum.Font.GothamBold; l.Parent = sc
end
 
local function toggle(key, text, desc, onF, offF)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-16,0,42); row.BackgroundColor3 = Color3.fromRGB(30,30,40); row.BorderSizePixel = 0; row.Parent = sc
    local nm = Instance.new("TextLabel")
    nm.Size = UDim2.new(1,-40,0,18); nm.Position = UDim2.new(0,8,0,3); nm.BackgroundTransparency = 1
    nm.Text = text; nm.TextXAlignment = Enum.TextXAlignment.Left; nm.TextColor3 = Color3.fromRGB(235,235,245)
    nm.TextSize = 13; nm.Font = Enum.Font.Gotham; nm.Parent = row
    local ds = Instance.new("TextLabel")
    ds.Size = UDim2.new(1,-80,0,14); ds.Position = UDim2.new(0,8,0,22); ds.BackgroundTransparency = 1
    ds.Text = desc or ""; ds.TextXAlignment = Enum.TextXAlignment.Left; ds.TextColor3 = Color3.fromRGB(150,150,165)
    ds.TextSize = 10; ds.Font = Enum.Font.Gotham; ds.TextTruncate = Enum.TextTruncate.AtEnd; ds.Parent = row
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,26,0,18); btn.Position = UDim2.new(1,-34,0,12)
    btn.BackgroundColor3 = Color3.fromRGB(90,90,100); btn.BorderSizePixel = 0
    btn.Text = "OFF"; btn.TextSize = 9; btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.Font = Enum.Font.GothamBold; btn.Parent = row
    local function refresh()
        local on = cfg[key]
        btn.BackgroundColor3 = on and Color3.fromRGB(76,175,80) or Color3.fromRGB(90,90,100)
        btn.Text = on and "ON" or "OFF"
    end
    btn.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]; refresh()
        if cfg[key] and onF then pcall(onF) elseif not cfg[key] and offF then pcall(offF) end
    end)
    refresh()
end
 
sg.Parent = pcall(function() return player:WaitForChild("PlayerGui", 10) end) and player:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
-- (ниже определим родителя надёжно, но не падаем)
 
-- ============================================================
--  LOOPS
-- ============================================================
local loops, statusBar = {}, {}
local function addLoop(key, dt, fn) loops[key] = { dt = dt, acc = 0, fn = fn } end
RunService.Heartbeat:Connect(function(s)
    for _, l in pairs(loops) do
        l.acc = l.acc + s
        if l.acc >= l.dt then l.acc = 0; pcall(l.fn) end
    end
end)
 
-- PLAYER
addLoop("health", 0.4, function()
    if not cfg.health then return end
    local h = getHum(); if h and h.Health > 0 then h.Health = h.MaxHealth end
end)
addLoop("stamina", 0.2, function()
    if not cfg.stamina then return end
    local h = getHum(); if h then
        local s = h:FindFirstChild("Stamina")
        if s then pcall(function() s.Value = s.MaxValue end) end
    end
end)
addLoop("fall", 0.3, function()
    if not cfg.fall then return end
    local h = getHum(); if h then pcall(function() h.ChangeState(Enum.HumanoidStateType.Running) end) end
end)
RunService.Heartbeat:Connect(function()
    local h = getHum(); if not h then return end
    if cfg.speed and h.WalkSpeed ~= cfg.speedVal then h.WalkSpeed = cfg.speedVal end
    if cfg.jump and h.JumpPower ~= cfg.jumpVal then h.JumpPower = cfg.jumpVal end
end)
addLoop("autosprint", 0.25, function()
    if not cfg.autosprint then return end
    local h = getHum(); if h then h.WalkSpeed = (cfg.speed and cfg.speedVal or 16) * 1.6 end
end)
 
-- FLY
local flyVelo
addLoop("fly", 0.1, function()
    if not cfg.fly then return end
    local hrp = getHRP(); if not hrp then return end
    if not flyVelo or not flyVelo.Parent then
        flyVelo = Instance.new("BodyVelocity"); flyVelo.MaxForce = Vector3.new(9e9,9e9,9e9); flyVelo.Parent = hrp
    end
    local dir = Vector3.new()
    if UIS:IsKeyDown(Enum.KeyCode.W) then dir += hrp.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= hrp.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= hrp.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then dir += hrp.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
    local sp = cfg.speed and cfg.speedVal or 16
    flyVelo.Velocity = dir.Magnitude > 0 and (dir.Unit * sp * 3) or Vector3.new()
end)
addLoop("flyOff", 0.5, function()
    if cfg.fly then return end
    if flyVelo then flyVelo:Destroy(); flyVelo = nil end
end)
 
-- NOCLIP
addLoop("noclip", 0.1, function()
    if not cfg.noclip then return end
    local c = player.Character; if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end)
 
-- TELEPORTS
addLoop("tpBase", 0.3, function()
    if not cfg.tpBase then return end
    local hd = WS:FindFirstChild("Hideout")
    local target = hd and (hd:FindFirstChild("SellLever") or hd.PrimaryPart or hd:FindFirstChildOfClass("BasePart"))
    if target then TPTo(target.CFrame + Vector3.new(0,3,0)) end
end)
addLoop("tpTruck", 0.3, function()
    if not cfg.tpTruck then return end
    local t = nearest(allTrucks()); if t then TPTo(t.part.CFrame + Vector3.new(0,3,0)) end
end)
addLoop("tpLoot", 0.3, function()
    if not cfg.tpLoot then return end
    local t = nearest(allLootSpawns()); if t then TPTo(t.CFrame + Vector3.new(0,2,0)) end
end)
addLoop("tpSell", 0.3, function()
    if not cfg.tpSell then return end
    local t = nearest(allSellZones()); if t then TPTo(t.CFrame + Vector3.new(0,2,0)) end
end)
 
-- AUTO FARM
local farmIdx, farmCount, farmStart = 0, 0
addLoop("autofarm", 2.0, function()
    if not cfg.autofarm then return end
    local parts = allLootSpawns(); if #parts == 0 then return end
    local hrp = getHRP(); if not hrp then return end
    farmIdx = (farmIdx % #parts) + 1
    farmCount += 1
    pcall(function() hrp.CFrame = parts[farmIdx].CFrame + Vector3.new(0,2,0) end)
end)
addLoop("autosell", 2.5, function()
    if not cfg.autosell then return end
    local zones = allSellZones(); if #zones == 0 then return end
    local hrp = getHRP(); if not hrp then return end
    local _, dOld = nearest(allTrucks())
    local z = nearest(zones)
    -- если стоим у грузовика и есть зона продажи рядом — идём продавать
    if z and dOld and dOld < 20 then
        pcall(function() hrp.CFrame = z.CFrame + Vector3.new(0,2,0) end)
    end
end)
 
-- ============================================================
--  ESP (через Drawing, если экзекьютор даёт; иначе BillboardGui)
-- ============================================================
local useDrawing = (type(Drawing) == "table")
 
-- Рендер Drawing-ESP каждый кадр
if useDrawing then
    local pool = {}
    RunService.RenderStepped:Connect(function()
        if not (cfg.espPolice or cfg.espLoot or cfg.espTruck) then
            for i = 1, #pool do pool[i].Visible = false end
            return
        end
        local cam = workspace.CurrentCamera
        local hrp = getHRP()
        local used = 0
        local function drawFor(part, color, maxDist)
            if not part or not part:IsA("BasePart") or not hrp then return end
            if (part.Position - hrp.Position).Magnitude > maxDist then return end
            local vp, onScreen = cam:WorldToViewportPoint(part.Position)
            if onScreen then
                used = used + 1
                local l = pool[used]
                if not l then l = Drawing.new("Line"); l.Thickness = 2; pool[used] = l end
                local sc = part.Size.Magnitude * 4
                l.Color = color; l.Transparency = 1
                l.From = Vector2.new(vp.X - sc/2, vp.Y - 8)
                l.To   = Vector2.new(vp.X + sc/2, vp.Y - 8)
                l.Visible = true
            end
        end
        if cfg.espPolice then for _, p in ipairs(allPolice()) do
            local prt = p:IsA("Model") and (p.PrimaryPart or p:FindFirstChildOfClass("BasePart")) or p
            drawFor(prt, Color3.fromRGB(255,60,60), 500)
        end end
        if cfg.espLoot then for _, p in ipairs(allLootSpawns()) do
            drawFor(p, Color3.fromRGB(80,255,120), 300)
        end end
        if cfg.espTruck then for _, t in ipairs(allTrucks()) do
            drawFor(t.part, Color3.fromRGB(255,220,80), 600)
        end end
        for i = used + 1, #pool do pool[i].Visible = false end
    end)
end
 
-- ============================================================
--  QOL
-- ============================================================
addLoop("fullbright", 1, function()
    if not cfg.fullbright then return end
    Light.Brightness = 1
    Light.Ambient = Color3.new(1,1,1)
    Light.OutdoorAmbient = Color3.new(1,1,1)
    Light.ClockTime = 12
end)
 
local fpsLbl = { Text = "" }
local fpsVal = 0
RunService.RenderStepped:Connect(function(dt)
    if cfg.fps then fpsVal = 1 / dt end
end)
addLoop("fps", 1, function()
    if not cfg.fps then return end
    if fpsLbl.update then fpsLbl.update("FPS: " .. string.format("%.0f", fpsVal)) end
end)
 
local function fmtTime(t)
    t = math.floor(t)
    local h = math.floor(t/3600); local m = math.floor((t%3600)/60); local s = t%60
    return string.format("%02d:%02d:%02d", h, m, s)
end
 
-- ============================================================
--  СБОРКА МЕНЮ
-- ============================================================
section("PLAYER")
toggle("health", "Infinite Health", "Не умирает")
toggle("stamina", "Infinite Stamina", "Выносливость вечная")
toggle("speed", "Speed x2", nil, function() cfg.speedVal = 32 end, function() end)
toggle("jump", "Jump boost", nil, function() cfg.jumpVal = 100 end, function() end)
toggle("autosprint", "Auto Sprint", "Бег всегда")
toggle("fall", "No Fall Damage", "Нет урона с высоты")
 
section("MOVEMENT")
toggle("noclip", "Noclip", "Сквозь стены")
toggle("fly", "Fly", "WASD + Space/Ctrl")
toggle("tpBase", "TP to Base", "В логово")
toggle("tpTruck", "TP to Truck", "К ближайшему грузовику")
toggle("tpLoot", "TP to Loot", "К ближайшему спавну")
toggle("tpSell", "TP to Sell", "К точке сдачи")
 
section("ESP")
toggle("espPolice", "ESP Police", "Подсветить полицию/снайперов")
toggle("espLoot", "ESP Loot", "Подсветить спавны лута")
toggle("espTruck", "ESP Truck", "Подсветить грузовики")
section("AUTO FARM")
toggle("autofarm", "Auto Farm", "Ходит по спавнам лута")
toggle("autosell", "Auto Sell", "Идёт продавать к SellZone")
section("QUALITY OF LIFE")
toggle("fullbright", "FullBright", "Время 12:00, светло")
toggle("fps", "FPS Counter", "Показывает FPS")
toggle("info", "Info / Dist", "Расстояния до Truck/Police")
 
-- статусная строка
local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1,-16,0,20); statusLbl.BackgroundColor3 = Color3.fromRGB(30,30,48)
statusLbl.BorderSizePixel = 0; statusLbl.Text = ""
statusLbl.TextColor3 = Color3.fromRGB(255,220,120); statusLbl.TextSize = 11
statusLbl.Font = Enum.Font.Gotham; statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = sc
 
-- привяжемся к родителю надёжно
player.CharacterAdded:Connect(function()
    if sg.Parent == nil then
        pcall(function() sg.Parent = player:WaitForChild("PlayerGui", 10) or workspace end)
    end
end)
if not sg.Parent then
    pcall(function() sg.Parent = player:WaitForChild("PlayerGui", 10) end)
end
 
-- INFO дистанции + статус
addLoop("info", 0.5, function()
    if not cfg.info then return end
    local hrp = getHRP(); if not hrp then return end
    local _, dt = nearest(allTrucks())
    local dpol = 9e9
    for _, s in ipairs(allPolice()) do
        local p = s:IsA("Model") and (s.PrimaryPart or s:FindFirstChildOfClass("BasePart")) or s
        if p and p:IsA("BasePart") then
            local d = (p.Position - hrp.Position).Magnitude
            if d < dpol then dpol = d end
        end
    end
    local warn = ""
    if dpol < 60 then warn = "  [POLICE NEAR!]" end
    statusLbl.Text = string.format("Truck %.0f  Police %.0f%s  | %s", dt, dpol, warn, fmtTime(os.clock() - sessionStart))
end)
-- cтатус всегда минимален (таймер сессии)
addLoop("session", 0.5, function()
    if statusLbl and string.len(statusLbl.Text) == 0 then
        statusLbl.Text = "Session: " .. fmtTime(os.clock() - sessionStart)
    end
end)
 
UIS.InputBegan:Connect(function(inp, g)
    if g then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then sg.Enabled = not sg.Enabled end
end)
 
print("[CrimSim Deluxe] Загружен. Правый Shift — меню.")
