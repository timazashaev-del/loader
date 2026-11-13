
--[[
    CITY CRIMINAL SIMULATOR — v7 MINIMAL
    Исправления по фидбеку:
      • Автофарм: всегда БЛИЖАЙШИЙ лут (не прыгает по всей карте)
      • Телепорт: ровно один раз, без «подпрыгиваний»
      • Автосбор: держит промпт его реальное HoldDuration
      • Полёт: на ИГРОВОМ джойстике (Humanoid.MoveDirection) + наклон камеры
      • Меню: минимализм, нормальная прокрутка (ElasticBehavior = Never)
      • Убрано: бесконечное HP, стамина, автобег, no-fall, невидимость
    Данные из дампа: Trucks, LootSpawns (1001), SellZone, Police, SafeZone.
]]
 
pcall(function() print("[CrimSim] v7 старт") end)
 
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local WS = game:GetService("Workspace")
local player = Players.LocalPlayer
 
local CFG = {
    speed = false, speedVal = 32,
    jump = false, jumpVal = 100,
    noclip = false, fly = false,
    espLoot = false, espPolice = false,
    autocollect = false, autosell = false, autofarm = false,
    magnet = false, magnetTruck = false,
    fullbright = false, fps = true,
}
local sessionStart = os.clock()
local lootPicked = 0
local espRegistry = {}
local espLabels = {}
local pickCount = 0
 
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
 
    -- ОДИН телепорт, без повторов
    local function tpOnce(pos, off)
        local hrp = getHRP()
        if hrp and pos then
            pcall(function()
                hrp.CFrame = CFrame.new(pos + Vector3.new(0, off or 3, 0))
            end)
        end
    end
 
    -- ================= КЕШ =================
    local cache = { loot = {}, trucks = {}, sells = {}, police = {}, safe = nil, t = -99 }
    local function refreshCache()
        local now = os.clock()
        if now - cache.t < 2 then return end
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
 
    -- ================= ПРОМПТЫ =================
    local op = OverlapParams.new()
    op.FilterType = Enum.RaycastFilterType.Exclude
    op.MaxParts = 80
 
    local function promptsNear(radius)
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
                if enabled then res[#res + 1] = prompt end
            end
        end
        return res
    end
 
    -- Держим промпт его реальное HoldDuration
    local function triggerPrompt(prompt)
        local hold = 0.2
        pcall(function()
            local h = prompt.HoldDuration
            if type(h) == "number" then
                hold = math.max(0.05, math.min(h, 1.2))
            end
        end)
        pcall(function() prompt:InputHoldBegin() end)
        task.delay(hold + 0.05, function()
            pcall(function() prompt:InputHoldEnd() end)
        end)
        lootPicked = lootPicked + 1
    end
 
    -- ================= МАГНИТ ЛУТА (эксперимент) =================
    local LOOT_NAMES = {
        "loot", "diamond", "gem", "money", "cash", "card", "bank",
        "crate", "box", "item", "stash", "package", "valuable", "gold",
    }
    local isLootName = function(nm)
        nm = string.lower(nm or "")
        for _, k in ipairs(LOOT_NAMES) do
            if string.find(nm, k, 1, true) then return true end
        end
        return false
    end
 
    local opLoot = OverlapParams.new()
    opLoot.FilterType = Enum.RaycastFilterType.Exclude
    opLoot.MaxParts = 220
 
    local function lootPartsNear(radius)
        local hrp = getHRP()
        local res = {}
        if not hrp then return res end
        opLoot.FilterDescendantsInstances = { player.Character }
        local ok, parts = pcall(function()
            return WS:GetPartBoundsInRadius(hrp.Position, radius, opLoot)
        end)
        if not ok or not parts then return res end
        local seen = {}
        for _, p in ipairs(parts) do
            if p and p.Parent and p ~= hrp then
                local hit = isLootName(p.Name)
                if not hit and p.Parent and p.Parent:IsA("Model") then
                    hit = isLootName(p.Parent.Name)
                end
                if not hit then
                    local hasPrompt = false
                    pcall(function()
                        hasPrompt = p:FindFirstChildOfClass("ProximityPrompt") ~= nil
                    end)
                    hit = hasPrompt
                end
                local size = 0
                pcall(function() size = p.Size.Magnitude end)
                if hit and size < 14 and not seen[p] then
                    seen[p] = true
                    res[#res + 1] = p
                end
            end
        end
        return res
    end
 
    local function magnetTargetPos()
        local hrp = getHRP()
        if not hrp then return nil end
        if CFG.magnetTruck then
            refreshCache()
            local t = nearestFrom(cache.trucks, function(x) return x.part end)
            if t then return t.part.Position + Vector3.new(0, 3, 0) end
        end
        return hrp.Position + Vector3.new(0, 2, 0)
    end
 
    local function moveLoot(part, target)
        if not part or not part.Parent or not target then return end
        local jitter = Vector3.new(
            (math.random() - 0.5) * 3,
            1.5 + math.random() * 2,
            (math.random() - 0.5) * 3)
        local pos = target + jitter
        local parent = part.Parent
        if parent and parent:IsA("Model") and parent.PrimaryPart then
            local ok = pcall(function() parent:PivotTo(CFrame.new(pos)) end)
            if ok then return end
        end
        pcall(function() part.CFrame = CFrame.new(pos) end)
    end
 
    -- ================= UI =================
    local function getGuiParent()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then pcall(function() pg = player:WaitForChild("PlayerGui", 15) end) end
        if pg then return pg end
        local ok, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok and cg then return cg end
        return nil
    end
 
    local sg = Instance.new("ScreenGui")
    sg.Name = "CrimSimMinimal"
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
    panel.Size = UDim2.fromOffset(300, 470)
    panel.Position = UDim2.fromOffset(18, 64)
    panel.BackgroundColor3 = BG
    panel.BackgroundTransparency = 0.03
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.ClipsDescendants = true
    panel.Parent = sg
    local pc1 = Instance.new("UICorner")
    pc1.CornerRadius = UDim.new(0, 12)
    pc1.Parent = panel
    local ps = Instance.new("UIStroke")
    ps.Color = Color3.fromRGB(58, 58, 84)
    ps.Thickness = 1
    ps.Transparency = 0.15
    ps.Parent = panel
 
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 42)
    header.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
    header.BorderSizePixel = 0
    header.Parent = panel
    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(0, 12)
    hc.Parent = header
    pcall(function()
        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new(Color3.fromRGB(46, 40, 82), Color3.fromRGB(24, 24, 36))
        grad.Rotation = 90
        grad.Parent = header
    end)
 
    local logo = Instance.new("TextLabel")
    logo.Size = UDim2.fromOffset(26, 26)
    logo.Position = UDim2.fromOffset(12, 8)
    logo.BackgroundColor3 = ACCENT
    logo.BorderSizePixel = 0
    logo.Text = "C"
    logo.TextColor3 = Color3.fromRGB(255, 255, 255)
    logo.TextSize = 14
    logo.Font = Enum.Font.GothamBold
    logo.Parent = header
    local lc = Instance.new("UICorner")
    lc.CornerRadius = UDim.new(0, 8)
    lc.Parent = logo
 
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -150, 0, 16)
    title.Position = UDim2.fromOffset(46, 6)
    title.BackgroundTransparency = 1
    title.Text = "CRIMINAL SIM"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(240, 240, 255)
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.Parent = header
 
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -150, 0, 12)
    subtitle.Position = UDim2.fromOffset(46, 21)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "minimal  •  v7"
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = Color3.fromRGB(154, 148, 200)
    subtitle.TextSize = 9
    subtitle.Font = Enum.Font.Gotham
    subtitle.Parent = header
 
    local btnMin = Instance.new("TextButton")
    btnMin.Size = UDim2.fromOffset(24, 24)
    btnMin.Position = UDim2.new(1, -62, 0, 9)
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
    btnClose.Position = UDim2.new(1, -32, 0, 9)
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
 
    local sc = Instance.new("ScrollingFrame")
    sc.Size = UDim2.new(1, 0, 1, -70)
    sc.Position = UDim2.fromOffset(0, 42)
    sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0
    sc.CanvasSize = UDim2.new(0, 0, 0, 0)
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.ScrollingDirection = Enum.ScrollingDirection.Y
    sc.ElasticBehavior = Enum.ElasticBehavior.Never
    sc.ScrollBarThickness = 3
    sc.ScrollBarImageColor3 = Color3.fromRGB(92, 88, 130)
    sc.Parent = panel
 
    local lay = Instance.new("UIListLayout")
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Padding = UDim.new(0, 3)
    lay.Parent = sc
    local pd = Instance.new("UIPadding")
    pd.PaddingTop = UDim.new(0, 4)
    pd.PaddingLeft = UDim.new(0, 8)
    pd.PaddingRight = UDim.new(0, 8)
    pd.PaddingBottom = UDim.new(0, 4)
    pd.Parent = sc
 
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
 
    local minimized = false
    local fullSize = panel.Size
    local function applyMin()
        pcall(function()
            TweenService:Create(panel, TweenInfo.new(0.16, Enum.EasingStyle.Quad),
                { Size = minimized and UDim2.fromOffset(300, 42) or fullSize }):Play()
        end)
        sc.Visible = not minimized
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
 
    -- ================= ЭЛЕМЕНТЫ =================
    local order = 0
    local function nextOrder() order = order + 1; return order end
 
    local function addSection(text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -4, 0, 22)
        l.BackgroundTransparency = 1
        l.Text = string.upper(text)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = ACCENT
        l.TextSize = 9
        l.Font = Enum.Font.GothamBold
        l.LayoutOrder = nextOrder()
        l.Parent = sc
    end
 
    local function addToggle(key, text, desc, onF, offF)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 42)
        row.BackgroundColor3 = CARD
        row.BorderSizePixel = 0
        row.LayoutOrder = nextOrder()
        row.Parent = sc
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 8)
        rc.Parent = row
 
        local nm = Instance.new("TextLabel")
        nm.Size = UDim2.new(1, -62, 0, 16)
        nm.Position = UDim2.fromOffset(10, 4)
        nm.BackgroundTransparency = 1
        nm.Text = text
        nm.TextXAlignment = Enum.TextXAlignment.Left
        nm.TextColor3 = Color3.fromRGB(236, 236, 248)
        nm.TextSize = 12
        nm.Font = Enum.Font.Gotham
        nm.Parent = row
 
        local ds = Instance.new("TextLabel")
        ds.Size = UDim2.new(1, -62, 0, 13)
        ds.Position = UDim2.fromOffset(10, 22)
        ds.BackgroundTransparency = 1
        ds.Text = desc or ""
        ds.TextXAlignment = Enum.TextXAlignment.Left
        ds.TextColor3 = MUTED
        ds.TextSize = 9
        ds.Font = Enum.Font.Gotham
        ds.TextTruncate = Enum.TextTruncate.AtEnd
        ds.Parent = row
 
        local track = Instance.new("Frame")
        track.Size = UDim2.fromOffset(40, 20)
        track.Position = UDim2.new(1, -50, 0.5, -10)
        track.BackgroundColor3 = Color3.fromRGB(58, 58, 78)
        track.BorderSizePixel = 0
        track.Parent = row
        local tc = Instance.new("UICorner")
        tc.CornerRadius = UDim.new(1, 0)
        tc.Parent = track
 
        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(14, 14)
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
 
    local function addButton(text, desc, fn)
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -4, 0, 36)
        row.BackgroundColor3 = Color3.fromRGB(36, 36, 52)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = true
        row.LayoutOrder = nextOrder()
        row.Parent = sc
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 8)
        rc.Parent = row
 
        local nm = Instance.new("TextLabel")
        nm.Size = UDim2.new(1, -16, 0, 15)
        nm.Position = UDim2.fromOffset(10, 3)
        nm.BackgroundTransparency = 1
        nm.Text = text
        nm.TextXAlignment = Enum.TextXAlignment.Left
        nm.TextColor3 = Color3.fromRGB(236, 236, 248)
        nm.TextSize = 12
        nm.Font = Enum.Font.GothamBold
        nm.Parent = row
 
        local ds = Instance.new("TextLabel")
        ds.Size = UDim2.new(1, -16, 0, 12)
        ds.Position = UDim2.fromOffset(10, 19)
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
 
    -- ================= МЕНЮ =================
    addSection("ПЕРСОНАЖ")
    addToggle("speed", "Скорость", "WalkSpeed 32 (если сервер разрешает)")
    addToggle("jump", "Прыжок", "JumpPower 100")
 
    addSection("ДВИЖЕНИЕ")
    addToggle("noclip", "Noclip", "Сквозь стены (сервер может вернуть)")
    addToggle("fly", "Полёт", "Твой джойстик + наклон камеры")
 
    addSection("ТЕЛЕПОРТ")
    addButton("На грузовик", "Один раз, к CargoZone", function()
        refreshCache()
        local t = nearestFrom(cache.trucks, function(x) return x.part end)
        if t then tpOnce(t.part.Position, 3) end
    end)
    addButton("К продаже", "Ближайшая SellZone", function()
        refreshCache()
        local s = nearestFrom(cache.sells)
        if s then tpOnce(s.Position, 2) end
    end)
    addButton("На базу", "Hideout, 29, 5, 53", function()
        tpOnce(Vector3.new(29, 5, 53), 0)
    end)
 
    addSection("ЛУТ")
    addToggle("autocollect", "Автосбор", "Держит промпты подбора рядом")
    addToggle("autosell", "Автопродажа", "Жмёт промпты у SellZone")
    addToggle("autofarm", "Автофарм", "Ближайший лут → продажа → база")
    addButton("Собрать рядом", "Все промпты в радиусе 25", function()
        for _, pr in ipairs(promptsNear(25)) do triggerPrompt(pr) end
    end)
 
    addSection("МАГНИТ (ЭКСПЕРИМЕНТ)")
    addToggle("magnet", "Магнит лута", "Тянет предметы к тебе (визуально)")
    addToggle("magnetTruck", "Магнит в грузовик", "Тянет к CargoZone")
    addButton("Один рывок", "Притянуть всё в радиусе 300", function()
        local target = magnetTargetPos()
        if not target then return end
        for _, p in ipairs(lootPartsNear(300)) do moveLoot(p, target) end
    end)
 
    addSection("ESP")
    addToggle("espLoot", "Лут", "Подписи с дистанцией")
    addToggle("espPolice", "Полиция", "Officer / Chief / Sniper")
 
    addSection("ПРОЧЕЕ")
    addToggle("fullbright", "FullBright", "Светло, 12:00")
    addToggle("fps", "FPS", "Счётчик кадров")
 
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
 
    -- Скорость/прыжок — до физики (Stepped), чтобы успеть раньше игры
    RunService.Stepped:Connect(function()
        local h = getHum()
        if not h then return end
        if CFG.speed then
            pcall(function() h.WalkSpeed = CFG.speedVal end)
        end
        if CFG.jump then
            pcall(function()
                h.UseJumpPower = true
                h.JumpPower = CFG.jumpVal
            end)
        end
    end)
 
    -- Noclip
    loop(0.1, function()
        if not CFG.noclip then return end
        local c = player.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
 
    -- Полёт на игровом джойстике
    local flyVelo
    loop(0.05, function()
        local hrp = getHRP()
        local h = getHum()
        if not CFG.fly then
            if flyVelo then pcall(function() flyVelo:Destroy() end); flyVelo = nil end
            return
        end
        if not hrp or not h then return end
        if not flyVelo or not flyVelo.Parent then
            flyVelo = Instance.new("BodyVelocity")
            flyVelo.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            flyVelo.Parent = hrp
        end
 
        local md = h.MoveDirection
        local dir = Vector3.new(md.X, 0, md.Z)
        local sp = CFG.speedVal
 
        local vertical = 0
        if UIS:IsKeyDown(Enum.KeyCode.Space) then vertical = 1 end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then vertical = -1 end
 
        local cam = workspace.CurrentCamera
        if dir.Magnitude > 0.05 then
            local camY = cam.CFrame.LookVector.Y
            if math.abs(camY) > 0.30 then
                vertical = camY * 1.8
            end
            dir = dir.Unit
        end
 
        local vel = dir * sp + Vector3.new(0, vertical * sp, 0)
        if vel.Magnitude > 0 then
            flyVelo.Velocity = vel
        else
            flyVelo.Velocity = Vector3.new()
        end
    end)
 
    -- Автосбор
    loop(0.3, function()
        if not CFG.autocollect then return end
        local prompts = promptsNear(20)
        local n = 0
        for _, pr in ipairs(prompts) do
            if n >= 4 then break end
            triggerPrompt(pr)
            n = n + 1
        end
    end)
 
    -- Автопродажа
    loop(0.8, function()
        if not CFG.autosell then return end
        refreshCache()
        local s, d = nearestFrom(cache.sells)
        if s and d and d < 30 then
            for _, pr in ipairs(promptsNear(20)) do triggerPrompt(pr) end
        end
    end)
 
    -- Автофарм: ближайший лут (локально), затем продажа, затем база
    local farmState, farmTimer = 1, 0
    loop(0.8, function()
        if not CFG.autofarm then
            farmState, farmTimer = 1, 0
            return
        end
        refreshCache()
        farmTimer = farmTimer + 1
        if farmState == 1 then
            local p = nearestFrom(cache.loot)
            if p then
                tpOnce(p.Position, 2)
                task.delay(0.2, function()
                    for _, pr in ipairs(promptsNear(18)) do triggerPrompt(pr) end
                end)
            end
            if farmTimer >= 20 then
                farmState, farmTimer = 2, 0
            end
        elseif farmState == 2 then
            local s = nearestFrom(cache.sells)
            if s then tpOnce(s.Position, 2) end
            task.delay(0.2, function()
                for _, pr in ipairs(promptsNear(20)) do triggerPrompt(pr) end
            end)
            if farmTimer >= 4 then
                farmState, farmTimer = 3, 0
            end
        elseif farmState == 3 then
            tpOnce(Vector3.new(29, 5, 53), 0)
            if farmTimer >= 2 then
                farmState, farmTimer = 1, 0
            end
        end
    end)
 
    -- Магнит лута: тянет предметы к цели (визуально; сервер может не засчитать)
    loop(0.35, function()
        if not CFG.magnet then return end
        local target = magnetTargetPos()
        if not target then return end
        for _, p in ipairs(lootPartsNear(300)) do moveLoot(p, target) end
    end)
 
    -- ESP: подсветка + подписи
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
                    b.Size = UDim2.fromOffset(120, 20)
                    b.StudsOffset = Vector3.new(0, 3, 0)
                    b.AlwaysOnTop = true
                    b.MaxDistance = 220
                    local t = Instance.new("TextLabel")
                    t.Size = UDim2.fromScale(1, 1)
                    t.BackgroundTransparency = 0.5
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
        if not (CFG.espLoot or CFG.espPolice) then
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
        if CFG.espLoot then
            local hrp = getHRP()
            if hrp then
                local near = {}
                for _, p in ipairs(cache.loot) do
                    near[#near + 1] = { part = p, d = (p.Position - hrp.Position).Magnitude }
                end
                table.sort(near, function(a, b) return a.d < b.d end)
                for i = 1, math.min(8, #near) do
                    local it = near[i]
                    highlight(it.part, GREEN, true)
                    label(it.part, string.format("LOOT %d", math.floor(it.d)), GREEN, true)
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
 
    loop(0.5, function()
        local parts = {}
        if CFG.fps then parts[#parts + 1] = string.format("%.0f FPS", fps) end
        parts[#parts + 1] = fmtTime(os.clock() - sessionStart)
        parts[#parts + 1] = "Lv " .. readLevel()
        parts[#parts + 1] = "Loot " .. lootPicked
        local _, pd = nearestFrom(cache.police)
        if pd ~= math.huge then
            parts[#parts + 1] = string.format("P%d", math.floor(pd))
        end
        status.Text = table.concat(parts, "  ")
    end)
 
    -- Перетаскивание строго за шапку
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
 
    print("[CrimSim] v7 загружен. Правый Shift — меню.")
end
 
local ok, err = xpcall(main, function(e)
    return tostring(e) .. "\n" .. (debug and debug.traceback and debug.traceback() or "")
end)
if not ok then
    warn("[CrimSim] ОШИБКА: " .. tostring(err))
end
