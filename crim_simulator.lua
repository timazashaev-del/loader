
--[[
    MULTITOOL TESTING MENU v3 (собственный плейс / одиночная среда)
    Универсальная тестовая панель: клиентские механики без обхода анти-чита.
    Работает в любом плейсе. Для точной привязки (ESP под конкретные модели,
    автосбор через свой Remote) — укажи название плейса или вставь свои имена.
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
    savePos=false, tpSaved=false, tpBase=false, tpTruck=false, tpSell=false,
    esp=false, espRange=150,
    autofarm=false, autocollect=false,
    invisible=false, fullbright=false, fps=true, info=true,
}
local sessionStart = os.clock()
local savedPositions = {}
local basePoint, truckPoint, sellPoint
 
local function main()
    local function getHRP()
        local c = player.Character
        return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
    end
    local function getHum()
        local c = player.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end
 
    local function tpToCFrame(cf)
        local hrp = getHRP()
        if hrp and cf then pcall(function() hrp.CFrame = cf end) end
    end
    local function tpToPoint(pos, off)
        local hrp = getHRP()
        if hrp and pos then
            pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, off or 3, 0)) end)
        end
    end
    local function partRoot(model)
        if not model then return nil end
        if model:IsA("BasePart") then return model end
        return model.PrimaryPart or model:FindFirstChildOfClass("BasePart")
    end
 
    local function nearestKeyword(keywords, maxDist)
        local hrp = getHRP()
        if not hrp then return nil, math.huge end
        local best, bd = nil, math.huge
        for _, part in ipairs(WS:GetDescendants()) do
            if part:IsA("BasePart") then
                local nm = part.Name:lower()
                local ok = false
                for _, kw in ipairs(keywords) do
                    if nm:find(kw, 1, true) then ok = true break end
                end
                if ok then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < bd then bd, best = d, part end
                end
            end
        end
        return best, bd
    end
 
    local function nearestNamed(name, root)
        local hrp = getHRP(); if not hrp then return nil end
        local best, bd = nil, math.huge
        for _, o in ipairs((root or WS):GetDescendants()) do
            if o.Name == name and (o:IsA("BasePart") or o:IsA("Model")) then
                local p = partRoot(o)
                if p then
                    local d = (p.Position - hrp.Position).Magnitude
                    if d < bd then bd, best = d, o end
                end
            end
        end
        return best
    end
 
    -- ========================================================
    -- UI
    -- ========================================================
    local sg = Instance.new("ScreenGui")
    sg.Name = "MTTestMenu"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999
    sg.Parent = player:WaitForChild("PlayerGui", 10) or game:GetService("CoreGui")
 
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(290, 500)
    frame.Position = UDim2.fromOffset(16, 60)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.ClipsDescendants = true
    frame.Parent = sg
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = frame
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(70, 70, 95); stroke.Thickness = 1; stroke.Parent = frame
 
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
    bar.BorderSizePixel = 0
    bar.Parent = frame
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 8); bc.Parent = bar
 
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -118, 1, 0)
    title.Position = UDim2.fromOffset(10, 0)
    title.BackgroundTransparency = 1
    title.Text = "TESTING MENU"
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
    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 5); mc.Parent = btnMin
 
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
    local cc2 = Instance.new("UICorner"); cc2.CornerRadius = UDim.new(0, 5); cc2.Parent = btnClose
 
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
 
    -- сворачивание (меню не закрывается, только прячется в шапку)
    local minimized = false
    local fullSize = frame.Size
    local function applyMin()
        if minimized then
            frame.Size = UDim2.fromOffset(290, 30)
        else
            frame.Size = fullSize
        end
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
        local btc = Instance.new("UICorner"); btc.CornerRadius = UDim.new(0, 5); btc.Parent = btn
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
        local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 5); rc.Parent = row
        local tp = Instance.new("TextLabel")
        tp.Size = UDim2.new(1, -20, 0, 14)
        tp.Position = UDim2.new(0, 10, 0, 18)
        tp.BackgroundTransparency = 1
        tp.Text = desc or ""
        tp.TextXAlignment = Enum.TextXAlignment.Left
        tp.TextColor3 = Color3.fromRGB(140, 140, 165)
        tp.TextSize = 9
        tp.Font = Enum.Font.Gotham
        tp.ZIndex = 2
        tp.Parent = row
        row.MouseButton1Click:Connect(function()
            pcall(fn)
        end)
    end
 
    -- ========================================================
    -- МЕНЮ
    -- ========================================================
    addSection("PLAYER")
    addToggle("health",     "Infinite Health",  "Не умирает")
    addToggle("stamina",    "Infinite Stamina", "Выносливость вечная")
    addToggle("speed",      "Speed x2",         "Скорость 32",       function() CFG.speedVal = 32 end)
    addToggle("jump",       "Jump Boost",       "Прыжок 100",        function() CFG.jumpVal = 100 end)
    addToggle("autosprint", "Auto Sprint",      "Всегда бежит")
    addToggle("fall",       "No Fall Damage",   "Нет урона от падения")
    addToggle("invisible",  "Invisibility (test)","Прозрачность персонажа (локально)")
 
    addSection("MOVEMENT")
    addToggle("noclip",     "Noclip",           "Сквозь стены (без анти-чита)")
    addToggle("fly",        "Fly",              "Джойстик/кнопки — см. экран")
 
    addSection("TELEPORT")
    addButton("Save position", "Сохранить текущие координаты", function()
        local hrp = getHRP()
        if hrp then table.insert(savedPositions, hrp.CFrame) end
    end)
    addButton("TP to saved", "К последней сохранённой точке", function()
        if #savedPositions > 0 then tpToCFrame(savedPositions[#savedPositions]) end
    end)
    addButton("Set Base here", "Запомнить базу", function()
        local hrp = getHRP(); if hrp then basePoint = hrp.CFrame end
    end)
    addToggle("tpBase", "TP to Base", "К базе", function() if basePoint then tpToCFrame(basePoint) end end)
    addButton("Set Truck here", "Запомнить грузовик", function()
        local hrp = getHRP(); if hrp then truckPoint = hrp.CFrame end
    end)
    addToggle("tpTruck", "TP to Truck", "К грузовику",
        function() if truckPoint then tpToCFrame(truckPoint) end end)
    addButton("Set Sell here", "Запомнить точку продажи", function()
        local hrp = getHRP(); if hrp then sellPoint = hrp.CFrame end
    end)
    addToggle("tpSell", "TP to Sell", "К точке продажи",
        function() if sellPoint then tpToCFrame(sellPoint) end end)
 
    addSection("FARM / COLLECT (свой плейс)")
    addToggle("autocollect", "Auto Collect", "Хватает ближайший Loot рядом")
    addToggle("autofarm",   "Auto Farm route", "Цикл: сбор → продажа → база")
 
    addSection("ESP")
    addToggle("esp", "ESP keywords", "Подсветка: loot/money/cop/truck",
        function() CFG.espRange = 150 end)
 
    addSection("QUALITY OF LIFE")
    addToggle("fullbright", "FullBright", "Светло")
    addToggle("fps",        "FPS Counter", "Показывать FPS")
    addToggle("info",       "Info / Stats", "Статус снизу")
 
    -- ========================================================
    -- JOYSTICK (мобильный флай) + кнопки UP/DOWN
    -- ========================================================
    local joyFrame, knob, joyVec = nil, nil, Vector2.new()
    local flyBtnUp, flyBtnDown
    if UIS.TouchEnabled then
        joyFrame = Instance.new("Frame")
        joyFrame.AnchorPoint = Vector2.new(0, 1)
        joyFrame.Position = UDim2.new(0.06, 0, 1, -24)
        joyFrame.Size = UDim2.fromOffset(130, 130)
        joyFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        joyFrame.BackgroundTransparency = 0.85
        joyFrame.Visible = false
        joyFrame.Parent = sg
        local jc = Instance.new("UICorner"); jc.CornerRadius = UDim.new(1, 0); jc.Parent = joyFrame
        knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(48, 48)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.fromScale(0.5, 0.5)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BackgroundTransparency = 0.3
        knob.Parent = joyFrame
        local kc = Instance.new("UICorner"); kc.CornerRadius = UDim.new(1, 0); kc.Parent = knob
 
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
        local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(1, 0); uc.Parent = flyBtnUp
        flyBtnDown = flyBtnUp:Clone()
        flyBtnDown.Position = UDim2.new(0.9, 0, 1, -92)
        flyBtnDown.Text = "DOWN"
        flyBtnDown.Parent = sg
    end
 
    -- обработка удержания кнопок: используем InputBegan/Ended на самих кнопках
    local upKey, downKey = false, false
    if flyBtnUp then
        flyBtnUp.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then upKey = true end
        end)
        flyBtnUp.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then upKey = false end
        end)
        flyBtnDown.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then downKey = true end
        end)
        flyBtnDown.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then downKey = false end
        end)
    end
 
    -- ========================================================
    -- LOOPS
    -- ========================================================
    local function loop(dt, fn)
        local acc = 0
        return RunService.Heartbeat:Connect(function(s)
            acc = acc + s
            if acc >= dt then acc = 0; pcall(fn) end
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
        if h then
            if CFG.speed and h.WalkSpeed ~= CFG.speedVal then h.WalkSpeed = CFG.speedVal end
            if CFG.jump and h.JumpPower ~= CFG.jumpVal then h.JumpPower = CFG.jumpVal end
        end
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
        if h then h:ChangeState(Enum.HumanoidStateType.Flying) end
    end)
 
    -- ФЛАЙ: джойстик (моб.) / WASD (ПК), камера-относительно
    local flyVelo
    loop(0.05, function()
        local hrp = getHRP()
        if not CFG.fly then
            if flyVelo then flyVelo:Destroy(); flyVelo = nil end
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
 
    -- TELEPORT TOGGLES: удерживают цель и телепортят каждый тик, пока включено
    loop(0.25, function()
        if CFG.tpBase and basePoint then tpToCFrame(basePoint) end
        if CFG.tpTruck and truckPoint then tpToCFrame(truckPoint) end
        if CFG.tpSell and sellPoint then tpToCFrame(sellPoint) end
    end)
 
    -- AUTO COLLECT: в своём плейсе подбираем части по ключевым словам
    loop(0.4, function()
        if not CFG.autocollect then return end
        local hrp = getHRP(); if not hrp then return end
        for _, part in ipairs(WS:GetDescendants()) do
            if part:IsA("BasePart") and part.Parent then
                local nm = part.Name:lower()
                local isLoot = nm:find("loot", 1, true) or nm:find("money", 1, true)
                    or nm:find("diamond", 1, true) or nm:find("gem", 1, true)
                if isLoot and part ~= hrp and (part.Position - hrp.Position).Magnitude < 12 then
                    -- 1) если в игре есть Remote для сбора — пробуем его (своё место!)
                    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                    local grab = remotes and remotes:FindFirstChild("LootGrab")
                    if grab and grab:IsA("RemoteEvent") then
                        pcall(function() grab:FireServer(part) end)
                    end
                    pcall(function() part.CFrame = hrp.CFrame - Vector3.new(0, 2, 0) end)
                end
            end
        end
    end)
 
    -- AUTO FARM ROUTE (свой плейс): сбор → точка продажи → база
    local farmState, farmTimer = 1, 0
    loop(1.0, function()
        if not CFG.autofarm then farmState = 1; return end
        local hrp = getHRP(); if not hrp then return end
        farmTimer = farmTimer + 1
        if farmState == 1 then
            local target = nearestKeyword({ "loot", "money", "diamond", "gem" }, 400)
            if target then
                tpToPoint(target.Position, 2)
            else
                farmState = 2
            end
        elseif farmState == 2 then
            if sellPoint then tpToCFrame(sellPoint); farmState = 3
            else farmState = 3 end
        elseif farmState == 3 then
            if basePoint then tpToCFrame(basePoint); farmState = 1 end
        end
    end)
 
    -- ESP keywords через Highlight
    local espRegistry = {}
    local function highlight(inst, color, enabled)
        if not inst or not inst.Parent then return end
        local h = espRegistry[inst]
        if enabled then
            if not h or not h.Parent then
                h = Instance.new("Highlight")
                h.Name = "MTESP"
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
 
    loop(0.5, function()
        if not CFG.esp then
            for _, h in pairs(espRegistry) do if h and h.Parent then h.Enabled = false end end
            return
        end
        local hrp = getHRP(); if not hrp then return end
        for _, part in ipairs(WS:GetDescendants()) do
            if part:IsA("BasePart") and part.Parent then
                local nm = part.Name:lower()
                local d = (part.Position - hrp.Position).Magnitude
                if d <= CFG.espRange then
                    if nm:find("loot", 1, true) or nm:find("money", 1, true) or nm:find("diamond", 1, true) or nm:find("gem", 1, true) then
                        highlight(part, Color3.fromRGB(80, 255, 130), true)
                    elseif nm:find("cop", 1, true) or nm:find("police", 1, true) or nm:find("guard", 1, true) then
                        highlight(part, Color3.fromRGB(255, 70, 70), true)
                    elseif nm:find("truck", 1, true) or nm:find("car", 1, true) then
                        highlight(part, Color3.fromRGB(255, 210, 70), true)
                    end
                end
            end
        end
    end)
 
    -- INVISIBILITY (локально, для теста в своём плейсе)
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
 
    -- fullbright
    loop(1, function()
        if not CFG.fullbright then return end
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        Lighting.ClockTime = 12
    end)
 
    local fps = 0
    RunService.RenderStepped:Connect(function(dt) if dt > 0 then fps = 1 / dt end end)
    local function fmtTime(t)
        t = math.floor(t)
        return string.format("%02d:%02d:%02d", math.floor(t / 3600), math.floor((t % 3600) / 60), t % 60)
    end
 
    loop(0.5, function()
        local parts = {}
        if CFG.fps then parts[#parts + 1] = string.format("FPS %.0f", fps) end
        parts[#parts + 1] = "S " .. fmtTime(os.clock() - sessionStart)
        if CFG.info then parts[#parts + 1] = "pts " .. #savedPositions end
        status.Text = table.concat(parts, "  ")
    end)
 
    -- drag
    local dragging, dragStart, startPos = false, nil, nil
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
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
 
    print("[MT Test Menu] Загружено. Правый Shift — меню.")
end
 
local ok, err = xpcall(main, function(e)
    return tostring(e) .. "\n" .. (debug and debug.traceback and debug.traceback() or "")
end)
if not ok then
    warn("[MT Test Menu] ОШИБКА: " .. tostring(err))
end
