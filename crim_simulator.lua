
--[[
    CITY CRIMINAL SIMULATOR — v9 PARAGON-STYLE
    Ориентир — публичный список функций Paragon Hub. Реализовано то, что
    работает на клиенте честно (промпты, ESP, телепорты, кнопки интерфейса).
 
    Данные:
      • Лут берётся промптом «Нажмите, чтобы забрать»
      • Тайник — TouchControls/STASH, продажа — TouchControls/SELL
      • Предметы: CashBag, GoldBar, DiamondNecklace, Handbag, SeizedCash,
        TaserItem, CashBox, PoliceRadio, PoliceBadge, Ring, RingBox, Wallet,
        Watch, Necklace, Valuables, Camera, Tablet, Laptop, Phone
      • Папки: Police (Officer/Chief), Guards, Npcs
      • Зоны: Hideout/SellBox/SellZone (29,3,53), Town/ChopShop/SellZone (-231,5,1524)
      • Полёт: PlatformStand + BodyVelocity + BodyGyro
    Серверное (нельзя клиентом): деньги/долг/квота, HP, стамина, ИИ.
]]
 
pcall(function() print("[CrimSim] v9 старт") end)
 
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
    espLoot = false, espMen = false, espPlayers = false, espCams = false,
    espSafes = false, espSwipers = false,
    autocollect = false, autostash = false, autosell = false, autofarm = false,
    tpTruckWanted = false,
    autobreak = false, autohack = false,
    fullbright = false, thirdperson = false,
    fps = true,
}
local sessionStart = os.clock()
local lootPicked = 0
local stashPressed = 0
local espRegistry = {}
local espLabels = {}
local pickupReach = 18
local breakReach = 25
local camDistance = 24
 
local ACCENT = Color3.fromRGB(126, 108, 255)
local GREEN = Color3.fromRGB(72, 196, 120)
local RED = Color3.fromRGB(232, 88, 88)
local YELLOW = Color3.fromRGB(255, 206, 84)
local CYAN = Color3.fromRGB(86, 204, 242)
local PINK = Color3.fromRGB(255, 120, 200)
local BG = Color3.fromRGB(17, 17, 24)
local CARD = Color3.fromRGB(27, 27, 38)
local MUTED = Color3.fromRGB(142, 142, 168)
 
local LOOT_NAMES = {
    CashBag = true, GoldBar = true, DiamondNecklace = true, Handbag = true,
    SeizedCash = true, TaserItem = true, CashBox = true, PoliceRadio = true,
    PoliceBadge = true, Ring = true, RingBox = true, Wallet = true,
    Watch = true, Necklace = true, Valuables = true, Item = true,
    Camera = true, Tablet = true, Laptop = true, Phone = true,
    Diamond = true, Gold = true, Money = true, Cash = true,
    BankCard = true, CreditCard = true, Card = true, Jewelry = true,
}
local LOOT_KEYS = {
    "loot", "cash", "money", "gold", "diamond", "jewel", "necklace", "ring",
    "wallet", "watch", "handbag", "badge", "radio", "taser", "valuable",
    "camera", "tablet", "laptop", "phone", "card",
}
local VALUE_RANK = {
    ["DiamondNecklace"] = 10, ["GoldBar"] = 9, ["CashBag"] = 8,
    ["Ring"] = 7, ["RingBox"] = 7, ["Watch"] = 6, ["Necklace"] = 6,
    ["Wallet"] = 5, ["Handbag"] = 5, ["SeizedCash"] = 4,
    ["Valuables"] = 4, ["CashBox"] = 4, ["PoliceRadio"] = 3,
    ["PoliceBadge"] = 3, ["TaserItem"] = 2, ["Camera"] = 3,
    ["Tablet"] = 3, ["Laptop"] = 3, ["Phone"] = 2,
}
local BREAK_KEYS = { "door", "lock", "safe", "window", "glass", "crate", "drawer", "locker" }
local HACK_KEYS = { "phone", "card", "terminal", "computer", "atm", "register", "swiper", "reader" }
 
local function isLootName(nm)
    if not nm then return false end
    if LOOT_NAMES[nm] then return true end
    local low = string.lower(nm)
    for _, k in ipairs(LOOT_KEYS) do
        if string.find(low, k, 1, true) then return true end
    end
    return false
end
 
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
    local function tpOnce(pos, off)
        local hrp = getHRP()
        if hrp and pos then
            pcall(function()
                hrp.CFrame = CFrame.new(pos + Vector3.new(0, off or 3, 0))
            end)
        end
    end
    local function hasKey(low, keys)
        for _, k in ipairs(keys) do
            if string.find(low, k, 1, true) then return true end
        end
        return false
    end
 
    -- ================= КЕШ =================
    local cache = { trucks = {}, sells = {}, police = {}, guards = {}, npcs = {}, t = -99 }
    local function refreshCache()
        local now = os.clock()
        if now - cache.t < 2 then return end
        cache.t = now
 
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
 
        local function folderModels(name)
            local list = {}
            local f = WS:FindFirstChild(name)
            if f then
                local ok, ch = pcall(function() return f:GetChildren() end)
                if ok then
                    for _, m in ipairs(ch) do
                        if m:IsA("Model") or m:IsA("BasePart") then list[#list + 1] = m end
                    end
                end
            end
            return list
        end
        cache.police = folderModels("Police")
        cache.guards = folderModels("Guards")
        cache.npcs = folderModels("Npcs")
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
 
    -- ================= ПОИСК =================
    local opItems = OverlapParams.new()
    opItems.FilterType = Enum.RaycastFilterType.Exclude
    opItems.MaxParts = 320
 
    local function itemNameOf(part)
        if not part then return nil end
        if isLootName(part.Name) then return part.Name end
        local parent = part.Parent
        local guard = 0
        while parent and parent ~= WS and guard < 3 do
            if isLootName(parent.Name) then return parent.Name end
            parent = parent.Parent
            guard = guard + 1
        end
        return nil
    end
 
    local function nearbyItems(radius)
        local hrp = getHRP()
        local res = {}
        if not hrp then return res end
        opItems.FilterDescendantsInstances = { player.Character }
        local ok, parts = pcall(function()
            return WS:GetPartBoundsInRadius(hrp.Position, radius, opItems)
        end)
        if not ok or not parts then return res end
        local seen = {}
        for _, p in ipairs(parts) do
            if p and p.Parent and p ~= hrp then
                local nm = itemNameOf(p)
                if nm then
                    local size = 0
                    pcall(function() size = p.Size.Magnitude end)
                    if size < 16 and not seen[p] then
                        seen[p] = true
                        res[#res + 1] = { part = p, name = nm, rank = VALUE_RANK[nm] or 1 }
                    end
                end
            end
        end
        return res
    end
 
    local function nearbyByKeyword(radius, keyword, excludeWord)
        local hrp = getHRP()
        local res = {}
        if not hrp then return res end
        opItems.FilterDescendantsInstances = { player.Character }
        local ok, parts = pcall(function()
            return WS:GetPartBoundsInRadius(hrp.Position, radius, opItems)
        end)
        if not ok or not parts then return res end
        local seen = {}
        for _, p in ipairs(parts) do
            if p and p.Parent and p ~= hrp then
                local nm = string.lower(p.Name)
                local pn = ""
                if p.Parent then pn = string.lower(p.Parent.Name) end
                local match = string.find(nm, keyword, 1, true) or string.find(pn, keyword, 1, true)
                local excluded = false
                if excludeWord then
                    if string.find(nm, excludeWord, 1, true) or string.find(pn, excludeWord, 1, true) then
                        excluded = true
                    end
                end
                if match and not excluded and not seen[p] then
                    local size = 0
                    pcall(function() size = p.Size.Magnitude end)
                    if size < 30 then
                        seen[p] = true
                        res[#res + 1] = p
                    end
                end
            end
        end
        return res
    end
 
    -- ================= ПРОМПТЫ =================
    local op = OverlapParams.new()
    op.FilterType = Enum.RaycastFilterType.Exclude
    op.MaxParts = 100
 
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
                if enabled then
                    local nm = ""
                    pcall(function()
                        if prompt.Parent then nm = prompt.Parent.Name end
                    end)
                    res[#res + 1] = { prompt = prompt, name = nm }
                end
            end
        end
        return res
    end
 
    local function triggerPrompt(prompt)
        local hold = 0.05
        pcall(function()
            local h = prompt.HoldDuration
            if type(h) == "number" then
                hold = math.max(0.05, math.min(h, 1.5))
            end
        end)
        pcall(function() prompt:InputHoldBegin() end)
        task.delay(hold + 0.05, function()
            pcall(function() prompt:InputHoldEnd() end)
        end)
        lootPicked = lootPicked + 1
    end
 
    local function triggerMatching(radius, keys)
        local n = 0
        for _, rec in ipairs(promptsNear(radius)) do
            if hasKey(string.lower(rec.name), keys) then
                triggerPrompt(rec.prompt)
                n = n + 1
                if n >= 4 then break end
            end
        end
        return n
    end
 
    local function pressGuiButton(guiName, btnName)
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return false end
        local gui = pg:FindFirstChild(guiName)
        if not gui then return false end
        local btn = gui:FindFirstChild(btnName, true)
        if not btn or not btn:IsA("GuiButton") then return false end
        local ok = false
        pcall(function()
            -- selene: allow(undefined_variable)
            if type(firesignal) == "function" then
                -- selene: allow(undefined_variable)
                firesignal(btn.MouseButton1Click)
                ok = true
            end
        end)
        return ok
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
    sg.Name = "CrimSimV9"
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
    panel.Size = UDim2.fromOffset(316, 520)
    panel.Position = UDim2.fromOffset(18, 58)
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
    header.Size = UDim2.new(1, 0, 0, 44)
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
    logo.Position = UDim2.fromOffset(12, 9)
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
    title.Position = UDim2.fromOffset(46, 7)
    title.BackgroundTransparency = 1
    title.Text = "CRIMINAL SIM"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(240, 240, 255)
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.Parent = header
 
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -150, 0, 12)
    subtitle.Position = UDim2.fromOffset(46, 22)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "v9  •  paragon style"
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextColor3 = Color3.fromRGB(154, 148, 200)
    subtitle.TextSize = 9
    subtitle.Font = Enum.Font.Gotham
    subtitle.Parent = header
 
    local btnMin = Instance.new("TextButton")
    btnMin.Size = UDim2.fromOffset(24, 24)
    btnMin.Position = UDim2.new(1, -62, 0, 10)
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
    btnClose.Position = UDim2.new(1, -32, 0, 10)
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
    tabBar.Size = UDim2.new(1, -16, 0, 28)
    tabBar.Position = UDim2.fromOffset(8, 48)
    tabBar.BackgroundColor3 = Color3.fromRGB(23, 23, 32)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = panel
    local tbc = Instance.new("UICorner")
    tbc.CornerRadius = UDim.new(0, 8)
    tbc.Parent = tabBar
    local tabLay = Instance.new("UIListLayout")
    tabLay.FillDirection = Enum.FillDirection.Horizontal
    tabLay.Padding = UDim.new(0, 3)
    tabLay.Parent = tabBar
    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingTop = UDim.new(0, 3)
    tabPad.PaddingBottom = UDim.new(0, 3)
    tabPad.PaddingLeft = UDim.new(0, 3)
    tabPad.PaddingRight = UDim.new(0, 3)
    tabPad.Parent = tabBar
 
    local pageArea = Instance.new("Frame")
    pageArea.Size = UDim2.new(1, 0, 1, -104)
    pageArea.Position = UDim2.fromOffset(0, 80)
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
        sc.ScrollingDirection = Enum.ScrollingDirection.Y
        sc.ElasticBehavior = Enum.ElasticBehavior.Never
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
        btn.TextSize = 9
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
 
    -- элементы
    local function addSection(parent, text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -4, 0, 22)
        l.BackgroundTransparency = 1
        l.Text = string.upper(text)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = ACCENT
        l.TextSize = 9
        l.Font = Enum.Font.GothamBold
        l.Parent = parent
    end
 
    local function addToggle(parent, key, text, desc, onF, offF)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 42)
        row.BackgroundColor3 = CARD
        row.BorderSizePixel = 0
        row.Parent = parent
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
 
    local function addButton(parent, text, desc, fn)
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -4, 0, 38)
        row.BackgroundColor3 = Color3.fromRGB(36, 36, 52)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = true
        row.Parent = parent
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 8)
        rc.Parent = row
 
        local nm = Instance.new("TextLabel")
        nm.Size = UDim2.new(1, -16, 0, 15)
        nm.Position = UDim2.fromOffset(10, 4)
        nm.BackgroundTransparency = 1
        nm.Text = text
        nm.TextXAlignment = Enum.TextXAlignment.Left
        nm.TextColor3 = Color3.fromRGB(236, 236, 248)
        nm.TextSize = 12
        nm.Font = Enum.Font.GothamBold
        nm.Parent = row
 
        local ds = Instance.new("TextLabel")
        ds.Size = UDim2.new(1, -16, 0, 12)
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
 
    -- страницы
    makePage("farm")
    makePage("break")
    makePage("esp")
    makePage("tp")
    makePage("misc")
 
    addTab("farm", "ФАРМ", 1)
    addTab("break", "ВЗЛОМ", 2)
    addTab("esp", "ESP", 3)
    addTab("tp", "ТП", 4)
    addTab("misc", "ПРОЧЕЕ", 5)
 
    -- ФАРМ
    local fp = pages.farm
    addSection(fp, "Сбор")
    addToggle(fp, "autocollect", "Автосбор", "Жмёт «забрать» у предметов")
    addButton(fp, "Собрать сейчас", "Промпты в радиусе " .. pickupReach, function()
        for _, rec in ipairs(promptsNear(pickupReach)) do triggerPrompt(rec.prompt) end
    end)
    addButton(fp, "Радиус +5", "Сейчас: " .. pickupReach, function()
        pickupReach = math.min(pickupReach + 5, 60)
    end)
    addButton(fp, "Радиус −5", "Сейчас: " .. pickupReach, function()
        pickupReach = math.max(pickupReach - 5, 5)
    end)
    addSection(fp, "Тайник и продажа")
    addToggle(fp, "autostash", "Автотайник", "Жмёт STASH")
    addToggle(fp, "autosell", "Автопродажа", "Жмёт SELL у зоны")
    addButton(fp, "Тайник сейчас", "Нажать STASH", function()
        if pressGuiButton("TouchControls", "STASH") then stashPressed = stashPressed + 1 end
    end)
    addButton(fp, "Продать всё", "ТП к продаже + SELL", function()
        refreshCache()
        local s = nearestFrom(cache.sells)
        if s then tpOnce(s.Position, 2) end
        task.delay(0.4, function()
            pressGuiButton("TouchControls", "SELL")
            for _, rec in ipairs(promptsNear(20)) do triggerPrompt(rec.prompt) end
        end)
    end)
    addButton(fp, "Дёрнуть рычаг", "SellLever в Hideout", function()
        local hideout = WS:FindFirstChild("Hideout")
        local lever = hideout and hideout:FindFirstChild("SellLever")
        local base = lever and partOf(lever)
        if base then
            tpOnce(base.Position, 2)
            task.delay(0.4, function()
                for _, rec in ipairs(promptsNear(12)) do triggerPrompt(rec.prompt) end
            end)
        end
    end)
    addSection(fp, "Автофарм")
    addToggle(fp, "autofarm", "Автофарм", "Лут → тайник → продажа → база")
    addToggle(fp, "tpTruckWanted", "ТП к грузовику при розыске", "Уходить, когда WANTED")
 
    -- ВЗЛОМ
    local bp = pages["break"]
    addSection(bp, "Вскрытие")
    addToggle(bp, "autobreak", "Авто-вскрытие", "Двери, замки, сейфы, окна")
    addButton(bp, "Вскрыть рядом", "Промпты в радиусе " .. breakReach, function()
        triggerMatching(breakReach, BREAK_KEYS)
    end)
    addButton(bp, "Радиус +5", "Сейчас: " .. breakReach, function()
        breakReach = math.min(breakReach + 5, 80)
    end)
    addButton(bp, "Радиус −5", "Сейчас: " .. breakReach, function()
        breakReach = math.max(breakReach - 5, 8)
    end)
    addSection(bp, "Электроника")
    addToggle(bp, "autohack", "Авто-хак", "Телефоны, карты, терминалы")
    addButton(bp, "Хакнуть рядом", "Промпты электроники", function()
        triggerMatching(breakReach, HACK_KEYS)
    end)
    addSection(bp, "Магазин")
    addButton(bp, "К магазину", "ShopComputer в грузовике", function()
        refreshCache()
        local t = nearestFrom(cache.trucks, function(x) return x.part end)
        if t then
            local comp = t.model:FindFirstChild("ShopComputer")
            local p = comp and partOf(comp)
            if p then tpOnce(p.Position, 2) end
        end
    end)
    addButton(bp, "Открыть магазин", "Промпты у ShopComputer", function()
        triggerMatching(10, { "shop", "computer", "buy", "store" })
    end)
 
    -- ESP
    local ep = pages.esp
    addSection(ep, "Мир")
    addToggle(ep, "espLoot", "Лут", "Реальные предметы + имена")
    addToggle(ep, "espSafes", "Сейфы", "Имя Safe (кроме SafeZone)")
    addToggle(ep, "espSwipers", "Картридеры", "Swiper / Reader")
    addToggle(ep, "espCams", "Камеры", "Security Cameras")
    addSection(ep, "Персонажи")
    addToggle(ep, "espMen", "Полиция и охрана", "Police, Guards, Dogs")
    addToggle(ep, "espPlayers", "Игроки", "Другие игроки")
 
    -- ТЕЛЕПОРТ
    local tp = pages.tp
    addSection(tp, "Точки")
    addButton(tp, "База", "Hideout, 29, 5, 53", function()
        tpOnce(Vector3.new(29, 5, 53), 0)
    end)
    addButton(tp, "Продажа", "Ближайшая SellZone", function()
        refreshCache()
        local s = nearestFrom(cache.sells)
        if s then tpOnce(s.Position, 2) end
    end)
    addButton(tp, "Грузовик", "Ближайший CargoZone", function()
        refreshCache()
        local t = nearestFrom(cache.trucks, function(x) return x.part end)
        if t then tpOnce(t.part.Position, 3) end
    end)
    addButton(tp, "Самый ценный лут", "По рейтингу предметов", function()
        local items = nearbyItems(800)
        local best, bd = nil, -1
        for _, it in ipairs(items) do
            local score = it.rank * 1000 - distTo(it.part.Position) / 10
            if score > bd then bd, best = score, it end
        end
        if best then tpOnce(best.part.Position, 2) end
    end)
    addButton(tp, "Ближайший игрок", "К другому игроку", function()
        local best, bd = nil, math.huge
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= player and pl.Character then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = distTo(hrp.Position)
                    if d < bd then bd, best = d, hrp end
                end
            end
        end
        if best then tpOnce(best.Position, 3) end
    end)
    addButton(tp, "К камере", "Ближайшая Security Camera", function()
        local cams = nearbyByKeyword(600, "camera")
        local best, bd = nil, math.huge
        for _, p in ipairs(cams) do
            local d = distTo(p.Position)
            if d < bd then bd, best = d, p end
        end
        if best then tpOnce(best.Position, 3) end
    end)
 
    -- ПРОЧЕЕ
    local mp = pages.misc
    addSection(mp, "Персонаж")
    addToggle(mp, "speed", "Скорость", "WalkSpeed 32 (если сервер разрешает)")
    addToggle(mp, "jump", "Прыжок", "JumpPower 100")
    addToggle(mp, "noclip", "Noclip", "Сквозь стены")
    addToggle(mp, "fly", "Полёт", "Джойстик + камера")
    addSection(mp, "Камера и свет")
    addToggle(mp, "thirdperson", "Третье лицо", "Камера сзади")
    addToggle(mp, "fullbright", "FullBright", "Светло, 12:00")
    addButton(mp, "Камера +5", "Дистанция " .. camDistance, function()
        camDistance = math.min(camDistance + 5, 80)
    end)
    addButton(mp, "Камера −5", "Дистанция " .. camDistance, function()
        camDistance = math.max(camDistance - 5, 8)
    end)
    addSection(mp, "Инфо")
    addToggle(mp, "fps", "FPS", "Счётчик кадров")
 
    selectTab("farm")
 
    -- статус
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
                { Size = minimized and UDim2.fromOffset(316, 44) or fullSize }):Play()
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
 
    RunService.Stepped:Connect(function()
        local h = getHum()
        if not h then return end
        if CFG.speed then pcall(function() h.WalkSpeed = CFG.speedVal end) end
        if CFG.jump then
            pcall(function()
                h.UseJumpPower = true
                h.JumpPower = CFG.jumpVal
            end)
        end
    end)
 
    loop(0.1, function()
        if not CFG.noclip then return end
        local c = player.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
 
    -- полёт
    local flyVelo, flyGyro
    local function stopFly()
        if flyVelo then pcall(function() flyVelo:Destroy() end); flyVelo = nil end
        if flyGyro then pcall(function() flyGyro:Destroy() end); flyGyro = nil end
        local h = getHum()
        if h then pcall(function() h.PlatformStand = false end) end
    end
 
    loop(0.05, function()
        local hrp = getHRP()
        local h = getHum()
        if not CFG.fly then
            stopFly()
            return
        end
        if not hrp or not h then return end
 
        if not flyVelo or not flyVelo.Parent then
            flyVelo = Instance.new("BodyVelocity")
            flyVelo.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            flyVelo.Velocity = Vector3.zero
            flyVelo.Parent = hrp
        end
        if not flyGyro or not flyGyro.Parent then
            flyGyro = Instance.new("BodyGyro")
            flyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            flyGyro.P = 1e4
            flyGyro.CFrame = hrp.CFrame
            flyGyro.Parent = hrp
        end
        pcall(function() h.PlatformStand = true end)
 
        local cam = workspace.CurrentCamera
        local camCF = cam.CFrame
        local dir = Vector3.new()
 
        local md = h.MoveDirection
        if md.Magnitude > 0.05 then
            dir = dir + Vector3.new(md.X, 0, md.Z).Unit
        end
        local lookFlat = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
        if lookFlat.Magnitude > 0.001 then lookFlat = lookFlat.Unit end
        local rightFlat = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
        if rightFlat.Magnitude > 0.001 then rightFlat = rightFlat.Unit end
 
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + lookFlat end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - lookFlat end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + rightFlat end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - rightFlat end
 
        local vertical = 0
        if UIS:IsKeyDown(Enum.KeyCode.Space) then vertical = 1 end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then vertical = -1 end
        if md.Magnitude > 0.05 then
            local camY = camCF.LookVector.Y
            if math.abs(camY) > 0.30 then vertical = camY * 1.8 end
        end
 
        local sp = 50
        flyVelo.Velocity = dir * sp + Vector3.new(0, vertical * sp, 0)
        flyGyro.CFrame = CFrame.new(hrp.Position, hrp.Position + lookFlat)
    end)
 
    -- автосбор
    loop(0.3, function()
        if not CFG.autocollect then return end
        local n = 0
        for _, rec in ipairs(promptsNear(pickupReach)) do
            if n >= 6 then break end
            triggerPrompt(rec.prompt)
            n = n + 1
        end
    end)
 
    -- автотайник
    loop(3.0, function()
        if not CFG.autostash then return end
        if pressGuiButton("TouchControls", "STASH") then
            stashPressed = stashPressed + 1
        end
    end)
 
    -- автопродажа
    loop(1.0, function()
        if not CFG.autosell then return end
        refreshCache()
        local s, d = nearestFrom(cache.sells)
        if s and d and d < 35 then
            pressGuiButton("TouchControls", "SELL")
            for _, rec in ipairs(promptsNear(20)) do triggerPrompt(rec.prompt) end
        end
    end)
 
    -- авто-вскрытие и хак
    loop(0.45, function()
        if CFG.autobreak then triggerMatching(breakReach, BREAK_KEYS) end
        if CFG.autohack then triggerMatching(breakReach, HACK_KEYS) end
    end)
 
    -- автофарм
    local farmState, farmTimer = 1, 0
    loop(1.0, function()
        if not CFG.autofarm then
            farmState, farmTimer = 1, 0
            return
        end
        refreshCache()
        farmTimer = farmTimer + 1
        if farmState == 1 then
            local items = nearbyItems(800)
            local best, bd = nil, math.huge
            for _, it in ipairs(items) do
                local d = distTo(it.part.Position)
                if d < bd then bd, best = d, it end
            end
            if best and bd > 14 then tpOnce(best.part.Position, 2) end
            task.delay(0.15, function()
                for _, rec in ipairs(promptsNear(pickupReach)) do triggerPrompt(rec.prompt) end
            end)
            if farmTimer >= 12 then farmState, farmTimer = 2, 0 end
        elseif farmState == 2 then
            pressGuiButton("TouchControls", "STASH")
            if farmTimer >= 2 then farmState, farmTimer = 3, 0 end
        elseif farmState == 3 then
            local s = nearestFrom(cache.sells)
            if s then tpOnce(s.Position, 2) end
            task.delay(0.2, function()
                pressGuiButton("TouchControls", "SELL")
                for _, rec in ipairs(promptsNear(20)) do triggerPrompt(rec.prompt) end
            end)
            if farmTimer >= 3 then farmState, farmTimer = 4, 0 end
        elseif farmState == 4 then
            tpOnce(Vector3.new(29, 5, 53), 0)
            if farmTimer >= 2 then farmState, farmTimer = 1, 0 end
        end
    end)
 
    -- третье лицо / камера
    loop(1, function()
        if not CFG.thirdperson then return end
        pcall(function()
            player.CameraMode = Enum.CameraMode.Classic
            player.CameraMinZoomDistance = 8
            player.CameraMaxZoomDistance = camDistance
        end)
    end)
 
    -- ESP
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
 
    local function label(inst, text, color, enabled)
        if not inst or not inst.Parent then return end
        local bg = espLabels[inst]
        if enabled then
            if not bg or not bg.Parent then
                local ok, newBg = pcall(function()
                    local b = Instance.new("BillboardGui")
                    b.Name = "CrimESP_Label"
                    b.Size = UDim2.fromOffset(146, 20)
                    b.StudsOffset = Vector3.new(0, 3, 0)
                    b.AlwaysOnTop = true
                    b.MaxDistance = 280
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
 
    loop(0.7, function()
        refreshCache()
        if not (CFG.espLoot or CFG.espMen or CFG.espPlayers or CFG.espCams
            or CFG.espSafes or CFG.espSwipers) then
            for _, h in pairs(espRegistry) do
                if h and h.Parent then h.Enabled = false end
            end
            for _, b in pairs(espLabels) do
                if b and b.Parent then b.Enabled = false end
            end
            return
        end
 
        if CFG.espLoot then
            for _, it in ipairs(nearbyItems(240)) do
                local d = distTo(it.part.Position)
                highlight(it.part, YELLOW, true)
                label(it.part, string.format("%s %d", it.name, math.floor(d)), YELLOW, true)
            end
        end
 
        if CFG.espSafes then
            for _, p in ipairs(nearbyByKeyword(240, "safe", "safezone")) do
                highlight(p, RED, true)
                label(p, "SAFE", RED, true)
            end
        end
 
        if CFG.espSwipers then
            for _, p in ipairs(nearbyByKeyword(240, "swiper")) do
                highlight(p, PINK, true)
                label(p, "SWIPER", PINK, true)
            end
        end
 
        if CFG.espCams then
            for _, p in ipairs(nearbyByKeyword(280, "camera")) do
                highlight(p, CYAN, true)
                label(p, "CAM", CYAN, true)
            end
        end
 
        if CFG.espMen then
            for _, inst in ipairs(cache.police) do
                local p = partOf(inst)
                local d = p and distTo(p.Position) or math.huge
                highlight(inst, CYAN, true)
                label(inst, string.format("POLICE %d", math.floor(d)), CYAN, true)
            end
            for _, inst in ipairs(cache.guards) do
                local p = partOf(inst)
                local d = p and distTo(p.Position) or math.huge
                highlight(inst, RED, true)
                label(inst, string.format("GUARD %d", math.floor(d)), RED, true)
            end
            for _, inst in ipairs(cache.npcs) do
                local nm = string.lower(inst.Name)
                local isDog = string.find(nm, "dog", 1, true) or string.find(nm, "k9", 1, true)
                local p = partOf(inst)
                local d = p and distTo(p.Position) or math.huge
                highlight(inst, isDog and PINK or GREEN, true)
                label(inst, string.format("%s %d", isDog and "DOG" or "NPC", math.floor(d)),
                    isDog and PINK or GREEN, true)
            end
        end
 
        if CFG.espPlayers then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= player and pl.Character then
                    local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local d = distTo(hrp.Position)
                        highlight(pl.Character, GREEN, true)
                        label(pl.Character, string.format("%s %d", pl.Name, math.floor(d)), GREEN, true)
                    end
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
 
    -- Уход к грузовику при розыске
    local lastWantedTP = 0
    loop(1.0, function()
        if not CFG.tpTruckWanted then return end
        if not isWanted() then return end
        if os.clock() - lastWantedTP < 4 then return end
        refreshCache()
        local t = nearestFrom(cache.trucks, function(x) return x.part end)
        if t then
            tpOnce(t.part.Position, 3)
            lastWantedTP = os.clock()
        end
    end)
 
    -- чтение чисел из HUD (Pockets / Truck Value / Detection)
    local function readHudByKeywords(keys)
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return nil end
        local found = nil
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") and d.Visible then
                local nm = string.lower(d.Name)
                local hit = false
                for _, k in ipairs(keys) do
                    if string.find(nm, k, 1, true) then hit = true break end
                end
                if hit then
                    local txt = ""
                    pcall(function() txt = d.Text end)
                    if txt and txt ~= "" then
                        found = txt
                        break
                    end
                end
            end
        end
        return found
    end
 
    -- HUD ������ ����� (������ ����� GUI)
    local hudPockets, hudTruckVal = nil, nil
    loop(3.0, function()
        hudPockets = readHudByKeywords({ "pocket" })
        hudTruckVal = readHudByKeywords({ "truckvalue", "truck value" })
    end)
 
    loop(0.5, function()
        local parts = {}
        if CFG.fps then parts[#parts + 1] = string.format("%.0f FPS", fps) end
        parts[#parts + 1] = fmtTime(os.clock() - sessionStart)
        parts[#parts + 1] = "Lv " .. readLevel()
        parts[#parts + 1] = "Loot " .. lootPicked
        parts[#parts + 1] = "Stash " .. stashPressed
        pcall(function()
            local ct = Lighting.ClockTime
            local hh = math.floor(ct) % 24
            local mm = math.floor((ct % 1) * 60)
            parts[#parts + 1] = string.format("%02d:%02d", hh, mm)
        end)
        local _, pd = nearestFrom(cache.police)
        if pd ~= math.huge then parts[#parts + 1] = string.format("P%d", math.floor(pd)) end
        if isWanted() then parts[#parts + 1] = "WANTED" end
        if hudPockets then parts[#parts + 1] = "Pkt " .. hudPockets end
        if hudTruckVal then parts[#parts + 1] = "Truck " .. hudTruckVal end
        status.Text = table.concat(parts, "  ")
    end)
 
    -- перетаскивание
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
 
    print("[CrimSim] v9 загружен. Правый Shift — меню.")
end
 
local ok, err = xpcall(main, function(e)
    return tostring(e) .. "\n" .. (debug and debug.traceback and debug.traceback() or "")
end)
if not ok then
    warn("[CrimSim] ОШИБКА: " .. tostring(err))
end
