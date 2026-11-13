local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
 
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
 
local PLACE_ID = 120219252362013
local VERSION = "1.0"
local tokenValue = ReplicatedStorage:FindFirstChild("TFFA_HubToken")
if not tokenValue then
    tokenValue = Instance.new("NumberValue")
    tokenValue.Name = "TFFA_HubToken"
    tokenValue.Parent = ReplicatedStorage
end
local TOKEN = tick()
tokenValue.Value = TOKEN
 
local function executorGlobal(name)
    local ok, env = pcall(getfenv, 0)
    if ok and type(env) == "table" then
        return env[name]
    end
    return nil
end
 
local function getGuiParent()
    local gethui = executorGlobal("gethui")
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            return hui
        end
    end
    local ok, core = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and core then
        return core
    end
    return PlayerGui
end
 
local parentGui = getGuiParent()
for _, obj in ipairs(parentGui:GetChildren()) do
    if obj.Name:match("^TFFA_Hub_") then
        obj:Destroy()
    end
end
 
local S = {
    autoThrow = false,
    autoIndex = false,
    autoTrain = false,
    autoTap = true,
    autoEquip = false,
    autoSell = false,
    autoBuy = false,
    autoStand = false,
    autoFence = false,
    autoFree = true,
    autoOffline = true,
    autoEggs = false,
    throwDelay = 1.4,
    trainDelay = 0.5,
    perfect = 1.08,
    zone = "Авто (макс)",
    foodMode = "Авто",
    status = "Загрузка...",
    running = true,
}
 
local Toggles: { [string]: (boolean, boolean?) -> () } = {}
local UI = {}
local Remotes = nil
local Modules = {}
local remotesReady = false
local Zones = {}
local activeDropdown = nil
local lastFoodAction = 0
local indexCache = { target = nil, count = -1, time = 0 }
 
local function getRemote(name)
    if not Remotes then
        return nil
    end
    return Remotes:FindFirstChild(name)
end
 
local function invoke(name, ...)
    local remote = getRemote(name)
    if not remote then
        return nil
    end
    local args = table.pack(...)
    local ok, result = pcall(function()
        return remote:InvokeServer(table.unpack(args, 1, args.n))
    end)
    if ok then
        return result
    end
    return nil
end
 
local function fire(name, ...)
    local remote = getRemote(name)
    if not remote then
        return false
    end
    local args = table.pack(...)
    local ok = pcall(function()
        remote:FireServer(table.unpack(args, 1, args.n))
    end)
    return ok
end
 
local function loadRemoteFolder()
    for _ = 1, 80 do
        if not S.running or tokenValue.Value ~= TOKEN then
            return false
        end
        local folder = ReplicatedStorage:FindFirstChild("Remotes")
        if folder then
            Remotes = folder
            remotesReady = true
            return true
        end
        task.wait(0.25)
    end
    return false
end
 
local function requireChild(parent, name)
    if not parent then
        return nil
    end
    local child = parent:FindFirstChild(name)
    if not child then
        local ok, waited = pcall(function()
            return parent:WaitForChild(name, 8)
        end)
        child = ok and waited or nil
    end
    if not child then
        return nil
    end
    local ok, module = pcall(require, child)
    if ok then
        return module
    end
    return nil
end
 
local function loadModules()
    local shared = ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared", 10)
    local config = ReplicatedStorage:FindFirstChild("Config") or ReplicatedStorage:WaitForChild("Config", 10)
    Modules.AreaUtil = requireChild(shared, "AreaUtil")
    Modules.AnimalRoll = requireChild(shared, "AnimalRoll")
    Modules.FoodsConfig = requireChild(config, "FoodsConfig")
    Modules.LevelConfig = requireChild(config, "LevelConfig")
    Modules.AnimalsData = requireChild(ReplicatedStorage, "AnimalsData")
    local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local client = playerScripts and playerScripts:FindFirstChild("Client")
    local controllers = client and client:FindFirstChild("Controllers")
    Modules.DataController = requireChild(controllers, "DataController")
    Modules.ClientState = requireChild(controllers, "ClientState")
end
 
local function dataGet(key, default)
    if Modules.DataController then
        local ok, value = pcall(function()
            return Modules.DataController:Get(key)
        end)
        if ok and value ~= nil then
            return value
        end
    end
    local stats = LocalPlayer:FindFirstChild("leaderstats")
    if stats then
        local stat = stats:FindFirstChild(key)
        if stat and stat:IsA("ValueBase") then
            return stat.Value
        end
    end
    return default
end
 
local function getMoney()
    local value = dataGet("Money", nil)
    if value == nil then
        value = dataGet("Cash", nil)
    end
    if value == nil then
        value = dataGet("Coins", 0)
    end
    return tonumber(value) or 0
end
 
local function getPower()
    local value = dataGet("ThrowPower", nil)
    if value == nil then
        value = dataGet("Throw Power", nil)
    end
    if value == nil then
        value = dataGet("Power", 0)
    end
    return tonumber(value) or 0
end
 
local function getLevel()
    local value = dataGet("Level", nil)
    if value == nil then
        value = dataGet("LVL", 1)
    end
    return tonumber(value) or 1
end
 
local function getEquippedFood()
    return tonumber(dataGet("EquippedFood", 1)) or 1
end
 
local function getIndexTable()
    local value = dataGet("Index", {})
    if type(value) == "table" then
        return value
    end
    return {}
end
 
local function getIndexCount()
    local count = 0
    for _ in pairs(getIndexTable()) do
        count = count + 1
    end
    return count
end
 
local function fmt(value)
    value = tonumber(value) or 0
    local abs = math.abs(value)
    if abs >= 1000000000 then
        return string.format("%.2fB", value / 1000000000)
    end
    if abs >= 1000000 then
        return string.format("%.2fM", value / 1000000)
    end
    if abs >= 1000 then
        return string.format("%.1fK", value / 1000)
    end
    return tostring(math.floor(value))
end
 
local function getChar()
    local char = LocalPlayer.Character
    if not char then
        return nil
    end
    local humanoid = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if humanoid and root and humanoid.Health > 0 then
        return char
    end
    return nil
end
 
local function getLaunchPos()
    local starter = workspace:FindFirstChild("StarterArea")
    local cross = starter and starter:FindFirstChild("CrossLine")
    if cross and cross:IsA("BasePart") then
        return Vector3.new(0, 5.5, cross.Position.Z)
    end
    if starter then
        local ok, pivot = pcall(function()
            return starter:GetPivot()
        end)
        if ok and pivot then
            return Vector3.new(0, 5.5, pivot.Position.Z - 5)
        end
    end
    return Vector3.new(0, 5.5, -45)
end
 
local function teleportTo(position)
    local char = getChar()
    if not char then
        return false
    end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Anchored then
            part.Anchored = false
        end
    end
    local target = CFrame.lookAt(position, position + Vector3.new(0, 0, -10))
    char:PivotTo(target)
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end
    return true
end
 
local function getMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return plot
        end
        if plot:GetAttribute("Player") == LocalPlayer.Name then
            return plot
        end
        if plot.Name == LocalPlayer.Name then
            return plot
        end
    end
    return plots:FindFirstChild(tostring(LocalPlayer.UserId)) or plots:FindFirstChild("1")
end
 
local function getPlotPos()
    local plot = getMyPlot()
    if not plot then
        return nil
    end
    local server = plot:FindFirstChild("Server")
    local stand = server and server:FindFirstChild("PullUpStand")
    if stand then
        local ok, pivot = pcall(function()
            return stand:GetPivot()
        end)
        if ok and pivot then
            return pivot.Position + Vector3.new(4, 0, 4)
        end
    end
    local ok, pivot = pcall(function()
        return plot:GetPivot()
    end)
    if ok and pivot then
        return pivot.Position + Vector3.new(0, 5, 0)
    end
    return nil
end
 
local FALLBACK_ZONES = {
    { name = "Forest", dist = 88 },
    { name = "Savanna", dist = 256 },
    { name = "Desert", dist = 425 },
    { name = "Jungle", dist = 593 },
    { name = "Ocean", dist = 761 },
    { name = "Mountains", dist = 941 },
    { name = "Taiga", dist = 1145 },
    { name = "Winter", dist = 1373 },
    { name = "Prehistoric Forest", dist = 1625 },
    { name = "Deep Waters", dist = 1901 },
    { name = "Hell", dist = 2213 },
    { name = "Ancient Ruins", dist = 2573 },
    { name = "Mythical Paradise", dist = 3005 },
    { name = "Shadow Realm", dist = 3665 },
    { name = "Harvest Fields", dist = 4625 },
    { name = "Phantom Harbor", dist = 5705 },
    { name = "Nuclear Wasteland", dist = 7109 },
    { name = "Cursed Carnival", dist = 8837 },
    { name = "Eclipse Kingdom", dist = 10565 },
}
 
local function buildZones()
    local list = { { name = "Авто (макс)", dist = 0 } }
    local seen = { ["Авто (макс)"] = true }
    local areaUtil = Modules.AreaUtil
    if areaUtil and type(areaUtil.GetAll) == "function" then
        local ok, areas = pcall(function()
            return areaUtil:GetAll()
        end)
        if not ok or type(areas) ~= "table" then
            ok, areas = pcall(areaUtil.GetAll, areaUtil)
        end
        if ok and type(areas) == "table" then
            for _, area in ipairs(areas) do
                local name = area.Name or area.Key
                local zStart = area.ZStart
                if name and type(zStart) == "number" and not seen[name] then
                    seen[name] = true
                    list[#list + 1] = { name = tostring(name), dist = math.max(0, math.floor(zStart + 45)) }
                end
            end
        end
    end
    if #list < 3 then
        for _, zone in ipairs(FALLBACK_ZONES) do
            if not seen[zone.name] then
                seen[zone.name] = true
                list[#list + 1] = { name = zone.name, dist = zone.dist }
            end
        end
    end
    Zones = list
    for _, zone in ipairs(Zones) do
        if zone.name == S.zone then
            return
        end
    end
    S.zone = "Авто (макс)"
end
 
local function zoneDistance(name)
    for _, zone in ipairs(Zones) do
        if zone.name == name then
            return zone.dist
        end
    end
    return 0
end
 
local function zoneOptions()
    local list = {}
    for _, zone in ipairs(Zones) do
        list[#list + 1] = zone.name
    end
    return list
end
 
local notify
local setStatus
 
local function foodOwned(owned, index)
    if type(owned) ~= "table" then
        return false
    end
    local value = owned[index]
    if value == nil then
        value = owned[tostring(index)]
    end
    if value == true then
        return true
    end
    if type(value) == "number" then
        return value > 0
    end
    if type(value) == "table" then
        return true
    end
    return false
end
 
local function getFood(index)
    local foods = Modules.FoodsConfig
    if not foods then
        return nil
    end
    if type(foods.Get) == "function" then
        local ok, food = pcall(foods.Get, index)
        if ok then
            return food
        end
    end
    if type(foods.List) == "table" then
        return foods.List[index]
    end
    return nil
end
 
local function getMaxFoodIndex()
    local foods = Modules.FoodsConfig
    if not foods then
        return 1
    end
    if type(foods.CountAll) == "function" then
        local ok, count = pcall(foods.CountAll)
        if ok and type(count) == "number" and count > 0 then
            return math.min(count, 100)
        end
    end
    if type(foods.List) == "table" and #foods.List > 0 then
        return math.min(#foods.List, 100)
    end
    return 1
end
 
local function buyAndEquipBestFood()
    local now = tick()
    if now - lastFoodAction < 2 then
        return
    end
    lastFoodAction = now
    if not Modules.FoodsConfig then
        return
    end
    local money = getMoney()
    local equipped = getEquippedFood()
    local best = equipped
    for index = 1, getMaxFoodIndex() do
        local food = getFood(index)
        local price = food and tonumber(food.Price)
        if price and money >= price and index > best then
            best = index
        end
    end
    if best ~= equipped then
        invoke("Shop_Buy", best)
        invoke("Shop_Equip", best)
    end
end
 
local function equipBestOwnedFood()
    if not Modules.FoodsConfig then
        return
    end
    local owned = dataGet("OwnedFoods", {})
    if type(owned) ~= "table" then
        return
    end
    local equipped = getEquippedFood()
    local best = equipped
    for index = 1, getMaxFoodIndex() do
        if foodOwned(owned, index) and index > best then
            best = index
        end
    end
    if best ~= equipped then
        invoke("Shop_Equip", best)
    end
end
 
local function ensureFood()
    if S.foodMode == "Не менять" and not S.autoBuy then
        return
    end
    if S.autoBuy then
        buyAndEquipBestFood()
    else
        equipBestOwnedFood()
    end
end
 
local function indexReady()
    return Modules.AreaUtil ~= nil and Modules.AnimalsData ~= nil and Modules.DataController ~= nil
end
 
local function getNextIndexTarget()
    if not indexReady() then
        return nil
    end
    local count = getIndexCount()
    if indexCache.target and indexCache.count == count and tick() - indexCache.time < 5 then
        return indexCache.target
    end
    local areaUtil = Modules.AreaUtil
    local animalsData = Modules.AnimalsData
    local areas = nil
    if type(areaUtil.GetAll) == "function" then
        local ok, result = pcall(areaUtil.GetAll, areaUtil)
        if ok and type(result) == "table" then
            areas = result
        end
    end
    if not areas or #areas == 0 then
        return nil
    end
    local discovered = getIndexTable()
    local maxArea = #areas
    if type(areaUtil.MaxReachableArea) == "function" then
        local ok, reachable = pcall(areaUtil.MaxReachableArea, getPower())
        if ok and type(reachable) == "number" and reachable > 0 then
            maxArea = math.min(maxArea, reachable)
        end
    end
    local maxFood = math.min(getMaxFoodIndex(), 60)
    local depths = { 0.08, 0.2, 0.35, 0.5, 0.65, 0.8, 0.92 }
    local animalRoll = Modules.AnimalRoll
    local weightsFunction = animalRoll and animalRoll.Weights
    for areaIndex = 1, maxArea do
        local area = areas[areaIndex]
        if type(area) == "table" then
            local key = area.Key or area.Name
            local list = animalsData[key] or animalsData[area.Name]
            if type(list) == "table" then
                local missing = 0
                local first = nil
                for rank, animal in ipairs(list) do
                    local model = animal.ModelName or animal.Name
                    if model and not discovered[model] and not discovered[animal.Name] then
                        missing = missing + 1
                        if not first then
                            local bestFood = getEquippedFood()
                            local bestDepth = 0.5
                            if type(weightsFunction) == "function" then
                                local bestWeight = -1
                                for foodIndex = 1, maxFood do
                                    for _, depth in ipairs(depths) do
                                        local okWeights, weights = pcall(weightsFunction, foodIndex, areaIndex, depth)
                                        if okWeights and type(weights) == "table" then
                                            local weight = tonumber(weights[rank])
                                            if weight and weight > bestWeight then
                                                bestWeight = weight
                                                bestFood = foodIndex
                                                bestDepth = depth
                                            end
                                        end
                                    end
                                end
                            end
                            local zStart = area.ZStart
                            local zEnd = area.ZEnd
                            local distance = 0
                            if type(zStart) == "number" and type(zEnd) == "number" then
                                local targetZ = zStart + (zEnd - zStart) * bestDepth
                                distance = math.max(0, math.floor(math.abs(targetZ + 45)))
                            else
                                distance = zoneDistance(area.Name or key or "")
                            end
                            first = {
                                name = animal.Name or model,
                                area = area.Name or key,
                                dist = distance,
                                food = bestFood,
                                missing = 0,
                            }
                        end
                    end
                end
                if first then
                    first.missing = missing
                    indexCache = { target = first, count = count, time = tick() }
                    return first
                end
            end
        end
    end
    return nil
end
 
local function setPushback(enabled)
    return
end
 
local function startResOk(result)
    if result == true then
        return true
    end
    return type(result) == "table" and result.Ok == true
end
 
local function handleStartFailure(result)
    local reason = type(result) == "table" and result.Reason or nil
    if reason == "TooFar" then
        teleportTo(getLaunchPos())
        task.wait(0.3)
    elseif reason == "Cooldown" then
        task.wait(0.6)
    elseif reason == "Busy" then
        fire("Shop_PromptClosed")
        invoke("Throw_Cancel")
        invoke("Training_Stop")
        task.wait(0.4)
    else
        task.wait(0.5)
    end
end
 
local function throwCycle()
    local char = getChar()
    if not char then
        return false
    end
    local launch = getLaunchPos()
    local root = char.HumanoidRootPart
    if (root.Position - launch).Magnitude > 8 then
        teleportTo(launch)
        task.wait(0.25)
        char = getChar()
        if not char then
            return false
        end
    end
    local targetPower = zoneDistance(S.zone)
    if S.autoIndex then
        if not indexReady() then
            if setStatus then
                setStatus("Индекс: модули ещё грузятся")
            end
            task.wait(1)
            return false
        end
        local target = getNextIndexTarget()
        if not target then
            S.autoIndex = false
            if Toggles.autoIndex then
                Toggles.autoIndex(false, true)
            end
            if notify then
                notify("Индекс собран: все животные найдены")
            end
            return false
        end
        targetPower = target.dist or 0
        if target.food then
            if S.autoBuy and not foodOwned(dataGet("OwnedFoods", {}), target.food) then
                invoke("Shop_Buy", target.food)
            end
            invoke("Shop_Equip", target.food)
        end
    else
        ensureFood()
    end
    invoke("Player_SetThrowPower", targetPower)
    fire("Shop_PromptClosed")
    local startResult = invoke("Throw_Start")
    if not startResOk(startResult) then
        handleStartFailure(startResult)
        return false
    end
    fire("Throw_MeterStarted")
    task.wait(S.perfect)
    local resolveResult = invoke("Throw_Resolve", 1.0)
    task.wait(0.06)
    invoke("Throw_Complete")
    if type(resolveResult) == "table" and resolveResult.IsNew and notify then
        local name = tostring(resolveResult.DisplayName or "?")
        local rarity = tostring(resolveResult.Rarity or "?")
        notify("Новый индекс: " .. name .. " (" .. rarity .. ")")
    end
    if S.autoEquip then
        task.spawn(function()
            invoke("Plot_EquipBest")
        end)
    end
    if S.autoSell then
        task.spawn(function()
            invoke("Plot_SellAll")
        end)
    end
    return true
end
 
task.spawn(function()
    while S.running and tokenValue.Value == TOKEN do
        if S.autoThrow or S.autoIndex then
            local ok, err = pcall(throwCycle)
            if not ok and setStatus then
                setStatus("Ошибка броска: " .. tostring(err))
            end
            task.wait(math.max(0.35, S.throwDelay - S.perfect - 0.08))
        else
            task.wait(0.25)
        end
    end
end)
 
task.spawn(function()
    while S.running and tokenValue.Value == TOKEN do
        if S.autoTrain and not S.autoThrow and not S.autoIndex then
            local ok, err = pcall(function()
                local plot = getMyPlot()
                local server = plot and plot:FindFirstChild("Server")
                local stand = server and server:FindFirstChild("PullUpStand")
                if stand then
                    local okPivot, pivot = pcall(function()
                        return stand:GetPivot()
                    end)
                    if okPivot and pivot then
                        local position = pivot.Position + Vector3.new(0, 3, 0)
                        local char = getChar()
                        if char and (char.HumanoidRootPart.Position - position).Magnitude > 15 then
                            char:PivotTo(CFrame.new(position))
                            task.wait(0.2)
                        end
                    end
                end
                invoke("Training_Start")
            end)
            if not ok and setStatus then
                setStatus("Тренировка: " .. tostring(err))
            end
            task.wait(S.trainDelay)
        else
            task.wait(0.4)
        end
    end
end)
 
task.spawn(function()
    while S.running and tokenValue.Value == TOKEN do
        local remote = getRemote("Training_Bonus")
        if remote and remote:IsA("RemoteEvent") then
            local connection = remote.OnClientEvent:Connect(function(data)
                if not S.autoTap then
                    return
                end
                local id = nil
                if type(data) == "table" then
                    id = data.Id or data.BonusId or data.id
                elseif type(data) == "string" or type(data) == "number" then
                    id = data
                end
                if id ~= nil then
                    invoke("Training_TapBonus", id)
                end
            end)
            while S.running and tokenValue.Value == TOKEN and remote.Parent do
                task.wait(0.5)
            end
            connection:Disconnect()
        else
            task.wait(1)
        end
    end
end)
 
task.spawn(function()
    local firesignal = executorGlobal("firesignal")
    while S.running and tokenValue.Value == TOKEN do
        if S.autoTap and type(firesignal) == "function" then
            pcall(function()
                local button = PlayerGui:FindFirstChild("TapBonus", true)
                if button and button:IsA("GuiButton") and button.Visible then
                    firesignal(button.MouseButton1Click)
                end
            end)
        end
        task.wait(0.4)
    end
end)
 
task.spawn(function()
    while S.running and tokenValue.Value == TOKEN do
        if S.autoStand then
            invoke("Stand_Upgrade")
        end
        if S.autoFence then
            invoke("Plot_UpgradeFence")
        end
        if S.autoFree then
            invoke("Shop_ClaimFree")
        end
        if S.autoOffline then
            invoke("Offline_Claim")
        end
        if S.autoBuy and not (S.autoThrow or S.autoIndex) then
            buyAndEquipBestFood()
        end
        task.wait(2.5)
    end
end)
 
task.spawn(function()
    while S.running and tokenValue.Value == TOKEN do
        if S.autoEggs then
            pcall(function()
                local plotPosition = getPlotPos()
                if plotPosition then
                    local eggs = {}
                    local function collect(container)
                        if not container then
                            return
                        end
                        for _, item in ipairs(container:GetChildren()) do
                            local key = item:GetAttribute("EggKey")
                            if key then
                                eggs[#eggs + 1] = key
                            end
                        end
                    end
                    collect(LocalPlayer:FindFirstChild("Backpack"))
                    collect(LocalPlayer.Character)
                    for _, key in ipairs(eggs) do
                        invoke("Egg_Place", key, plotPosition)
                        task.wait(0.12)
                    end
                end
                local firesignal = executorGlobal("firesignal")
                if type(firesignal) == "function" then
                    local eggGui = PlayerGui:FindFirstChild("EggHatch", true)
                    if eggGui then
                        for _, button in ipairs(eggGui:GetDescendants()) do
                            if button:IsA("GuiButton") and button.Visible then
                                pcall(firesignal, button.MouseButton1Click)
                            end
                        end
                    end
                end
            end)
        end
        task.wait(1.5)
    end
end)
 
local C = {
    bg = Color3.fromRGB(14, 16, 22),
    panel = Color3.fromRGB(23, 26, 35),
    panel2 = Color3.fromRGB(32, 36, 48),
    line = Color3.fromRGB(48, 54, 70),
    accent = Color3.fromRGB(74, 222, 128),
    accent2 = Color3.fromRGB(250, 204, 21),
    text = Color3.fromRGB(236, 240, 248),
    dim = Color3.fromRGB(148, 156, 174),
    red = Color3.fromRGB(248, 113, 113),
    white = Color3.fromRGB(255, 255, 255),
}
 
local function new(class, props, parent)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end
 
local function rounded(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = object
    return corner
end
 
local function stroke(object, color, thickness, transparency)
    local line = Instance.new("UIStroke")
    line.Color = color
    line.Thickness = thickness
    line.Transparency = transparency or 0
    line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    line.Parent = object
    return line
end
 
local sg = new("ScreenGui", {
    Name = "TFFA_Hub_" .. tostring(math.random(100000, 999999)),
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
}, nil)
local syn = executorGlobal("syn")
if type(syn) == "table" and type(syn.protect_gui) == "function" then
    pcall(syn.protect_gui, sg)
end
local parentOk = pcall(function()
    sg.Parent = parentGui
end)
if not parentOk or not sg.Parent then
    sg.Parent = PlayerGui
end
 
local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(360, 640)
local W = math.max(300, math.min(372, viewport.X - 16))
local H = math.max(380, math.min(524, viewport.Y - 96))
local main = new("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(W, H),
    Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 10,
}, sg)
rounded(main, 16)
stroke(main, C.accent, 1.5, 0.55)
 
local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
    ZIndex = 11,
}, main)
rounded(header, 16)
new("UIGradient", {
    Color = ColorSequence.new(Color3.fromRGB(30, 34, 47), Color3.fromRGB(18, 21, 30)),
    Rotation = 90,
}, header)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 14),
    Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = Color3.fromRGB(18, 21, 30),
    BorderSizePixel = 0,
    ZIndex = 11,
}, header)
 
new("TextLabel", {
    Text = "TFFA HUB",
    Position = UDim2.fromOffset(16, 7),
    Size = UDim2.new(1, -110, 0, 20),
    BackgroundTransparency = 1,
    TextColor3 = C.text,
    TextSize = 17,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 12,
}, header)
new("TextLabel", {
    Text = "Throw Food For Animals",
    Position = UDim2.fromOffset(16, 26),
    Size = UDim2.new(1, -110, 0, 14),
    BackgroundTransparency = 1,
    TextColor3 = C.dim,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 12,
}, header)
UI.dot = new("Frame", {
    Size = UDim2.fromOffset(7, 7),
    Position = UDim2.new(0, 16, 1, -14),
    BackgroundColor3 = C.red,
    BorderSizePixel = 0,
    ZIndex = 12,
}, header)
rounded(UI.dot, 4)
UI.status = new("TextLabel", {
    Text = "Подключение...",
    Position = UDim2.new(0, 28, 1, -18),
    Size = UDim2.new(1, -150, 0, 12),
    BackgroundTransparency = 1,
    TextColor3 = C.dim,
    TextSize = 9,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 12,
}, header)
 
local minimizeButton = new("TextButton", {
    Text = "−",
    Size = UDim2.fromOffset(26, 24),
    Position = UDim2.new(1, -64, 0, 12),
    BackgroundColor3 = C.panel2,
    TextColor3 = C.dim,
    TextSize = 15,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
    BorderSizePixel = 0,
    ZIndex = 13,
}, header)
rounded(minimizeButton, 7)
local closeButton = new("TextButton", {
    Text = "✕",
    Size = UDim2.fromOffset(26, 24),
    Position = UDim2.new(1, -34, 0, 12),
    BackgroundColor3 = Color3.fromRGB(70, 28, 36),
    TextColor3 = C.red,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
    BorderSizePixel = 0,
    ZIndex = 13,
}, header)
rounded(closeButton, 7)
 
local toastWidth = math.min(320, viewport.X - 24)
local toast = new("TextLabel", {
    Size = UDim2.fromOffset(toastWidth, 38),
    Position = UDim2.new(0.5, -toastWidth / 2, 0, 10),
    BackgroundColor3 = C.panel,
    TextColor3 = C.text,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    TextWrapped = true,
    Visible = false,
    BorderSizePixel = 0,
    ZIndex = 100,
}, sg)
rounded(toast, 10)
stroke(toast, C.accent, 1, 0.45)
 
local toastToken = 0
notify = function(text)
    if not toast or not toast.Parent then
        return
    end
    toastToken = toastToken + 1
    local token = toastToken
    toast.Text = tostring(text)
    toast.Visible = true
    toast.BackgroundTransparency = 0
    toast.TextTransparency = 0
    task.delay(2.4, function()
        if token ~= toastToken or not toast.Parent then
            return
        end
        TweenService:Create(toast, TweenInfo.new(0.35), {
            BackgroundTransparency = 1,
            TextTransparency = 1,
        }):Play()
        task.wait(0.35)
        if token == toastToken and toast.Parent then
            toast.Visible = false
        end
    end)
end
 
setStatus = function(text)
    S.status = tostring(text)
    if UI.status then
        UI.status.Text = S.status
    end
end
 
local float = new("TextButton", {
    Name = "Toggle",
    Size = UDim2.fromOffset(46, 46),
    Position = UDim2.fromOffset(12, 92),
    BackgroundColor3 = C.accent,
    Text = "T",
    TextColor3 = C.bg,
    TextSize = 20,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
    BorderSizePixel = 0,
    ZIndex = 20,
}, sg)
rounded(float, 23)
stroke(float, C.accent2, 2, 0.25)
new("UIGradient", {
    Color = ColorSequence.new(C.accent, C.accent2),
    Rotation = 45,
}, float)
UI.float = float
float.Visible = not main.Visible
main:GetPropertyChangedSignal("Visible"):Connect(function()
    float.Visible = not main.Visible
end)
 
local floatDragging = false
local floatMoved = false
local floatStart = nil
local floatStartPosition = nil
float.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        floatDragging = true
        floatMoved = false
        floatStart = input.Position
        floatStartPosition = float.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not floatDragging then
        return
    end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - floatStart
        if delta.Magnitude > 6 then
            floatMoved = true
        end
        float.Position = UDim2.new(
            floatStartPosition.X.Scale,
            floatStartPosition.X.Offset + delta.X,
            floatStartPosition.Y.Scale,
            floatStartPosition.Y.Offset + delta.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if not floatDragging then
        return
    end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        floatDragging = false
        if not floatMoved then
            main.Visible = not main.Visible
        else
            local position = float.AbsolutePosition
            local size = float.AbsoluteSize
            float.Position = UDim2.fromOffset(
                math.clamp(position.X, 4, viewport.X - size.X - 4),
                math.clamp(position.Y, 4, viewport.Y - size.Y - 4)
            )
        end
    end
end)
 
local closeDropdown
local content
local tabBar
local minimized = false
local dragging = false
local dragStart = nil
local dragStartPosition = nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        dragStartPosition = main.Position
        if closeDropdown then
            closeDropdown()
        end
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            dragStartPosition.X.Scale,
            dragStartPosition.X.Offset + delta.X,
            dragStartPosition.Y.Scale,
            dragStartPosition.Y.Offset + delta.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if dragging then
            local position = main.AbsolutePosition
            local size = main.AbsoluteSize
            main.Position = UDim2.fromOffset(
                math.clamp(position.X, 0, math.max(0, viewport.X - size.X)),
                math.clamp(position.Y, 0, math.max(0, viewport.Y - size.Y))
            )
        end
        dragging = false
    end
end)
 
closeButton.MouseButton1Click:Connect(function()
    main.Visible = false
    if closeDropdown then
        closeDropdown()
    end
end)
 
local pages = {}
local tabButtons = {}
local tabNames = { "Фарм", "Действия", "Настройки" }
 
local function selectTab(index)
    for pageIndex, page in ipairs(pages) do
        page.Visible = pageIndex == index
    end
    for buttonIndex, button in ipairs(tabButtons) do
        if buttonIndex == index then
            button.BackgroundColor3 = C.accent
            button.TextColor3 = C.bg
        else
            button.BackgroundColor3 = C.panel2
            button.TextColor3 = C.dim
        end
    end
    if closeDropdown then
        closeDropdown()
    end
end
 
tabBar = new("Frame", {
    Size = UDim2.new(1, -16, 0, 36),
    Position = UDim2.fromOffset(8, 60),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
    ZIndex = 11,
}, main)
rounded(tabBar, 10)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Center,
}, tabBar)
new("UIPadding", {
    PaddingLeft = UDim.new(0, 4),
    PaddingRight = UDim.new(0, 4),
    PaddingTop = UDim.new(0, 4),
    PaddingBottom = UDim.new(0, 4),
}, tabBar)
 
for tabIndex, tabName in ipairs(tabNames) do
    local button = new("TextButton", {
        Text = tabName,
        Size = UDim2.new(1 / 3, -4, 1, -2),
        BackgroundColor3 = C.panel2,
        TextColor3 = C.dim,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        LayoutOrder = tabIndex,
        ZIndex = 12,
    }, tabBar)
    rounded(button, 7)
    button.MouseButton1Click:Connect(function()
        selectTab(tabIndex)
    end)
    tabButtons[tabIndex] = button
end
 
content = new("Frame", {
    Size = UDim2.new(1, -16, 1, -108),
    Position = UDim2.fromOffset(8, 100),
    BackgroundTransparency = 1,
    ZIndex = 11,
}, main)
 
local function createPage()
    local page = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.line,
        Visible = false,
        ZIndex = 12,
    }, content)
    new("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, page)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 6),
    }, page)
    pages[#pages + 1] = page
    return page
end
 
local pageFarm = createPage()
local pageActions = createPage()
local pageSettings = createPage()
selectTab(1)
 
local function setMinimized(value)
    minimized = value
    content.Visible = not value
    tabBar.Visible = not value
    main.Size = UDim2.fromOffset(W, value and 54 or H)
    minimizeButton.Text = value and "+" or "−"
end
 
minimizeButton.MouseButton1Click:Connect(function()
    setMinimized(not minimized)
end)
 
local function section(page, text, order)
    return new("TextLabel", {
        Text = string.upper(text),
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        TextColor3 = C.accent,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order,
        ZIndex = 12,
    }, page)
end
 
local function addToggle(page, key, title, description, order, onChange)
    local height = description and 50 or 42
    local row = new("TextButton", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = C.panel,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = order,
        ZIndex = 12,
    }, page)
    rounded(row, 10)
    stroke(row, C.line, 1, 0.45)
    new("TextLabel", {
        Text = title,
        Position = UDim2.fromOffset(12, description and 4 or 0),
        Size = UDim2.new(1, -70, 0, description and 18 or height),
        BackgroundTransparency = 1,
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 13,
    }, row)
    if description then
        new("TextLabel", {
            Text = description,
            Position = UDim2.fromOffset(12, 22),
            Size = UDim2.new(1, -70, 0, 14),
            BackgroundTransparency = 1,
            TextColor3 = C.dim,
            TextSize = 8,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 13,
        }, row)
    end
    local pill = new("Frame", {
        Size = UDim2.fromOffset(40, 20),
        Position = UDim2.new(1, -52, 0.5, -10),
        BackgroundColor3 = C.panel2,
        BorderSizePixel = 0,
        ZIndex = 13,
    }, row)
    rounded(pill, 10)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = C.dim,
        BorderSizePixel = 0,
        ZIndex = 14,
    }, pill)
    rounded(knob, 8)
    local function set(value, silent)
        S[key] = value
        TweenService:Create(pill, TweenInfo.new(0.18), {
            BackgroundColor3 = value and C.accent or C.panel2,
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.18), {
            Position = value and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2),
            BackgroundColor3 = value and C.bg or C.dim,
        }):Play()
        if onChange and not silent then
            local ok, err = pcall(onChange, value)
            if not ok and notify then
                notify("Ошибка: " .. tostring(err))
            end
        end
    end
    row.MouseButton1Click:Connect(function()
        set(not S[key])
    end)
    Toggles[key] = set
    set(S[key] or false, true)
    return row
end
 
local function addButton(page, text, color, order, callback, textColor)
    local button = new("TextButton", {
        Text = text,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = color,
        TextColor3 = textColor or C.bg,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = 12,
    }, page)
    rounded(button, 9)
    button.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback)
        if not ok and notify then
            notify("Ошибка: " .. tostring(err))
        end
    end)
    return button
end
 
local function addSlider(page, title, minimum, maximum, step, getValue, setValue, formatValue, order)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = 12,
    }, page)
    rounded(row, 10)
    stroke(row, C.line, 1, 0.45)
    new("TextLabel", {
        Text = title,
        Position = UDim2.fromOffset(12, 5),
        Size = UDim2.new(1, -90, 0, 16),
        BackgroundTransparency = 1,
        TextColor3 = C.text,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 13,
    }, row)
    local valueLabel = new("TextLabel", {
        Text = "",
        Position = UDim2.new(1, -78, 0, 5),
        Size = UDim2.fromOffset(66, 16),
        BackgroundTransparency = 1,
        TextColor3 = C.accent2,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 13,
    }, row)
    local bar = new("TextButton", {
        Text = "",
        Size = UDim2.new(1, -24, 0, 6),
        Position = UDim2.fromOffset(12, 30),
        BackgroundColor3 = C.panel2,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 13,
    }, row)
    rounded(bar, 3)
    local fill = new("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
        ZIndex = 14,
    }, bar)
    rounded(fill, 3)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.new(0, -7, 0.5, -7),
        BackgroundColor3 = C.text,
        BorderSizePixel = 0,
        ZIndex = 15,
    }, bar)
    rounded(knob, 7)
    local function normalize(value)
        value = math.clamp(value, minimum, maximum)
        if step > 0 then
            value = math.floor((value / step) + 0.5) * step
        end
        return math.clamp(value, minimum, maximum)
    end
    local function refresh()
        local value = normalize(getValue())
        local alpha = 0
        if maximum > minimum then
            alpha = (value - minimum) / (maximum - minimum)
        end
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.new(alpha, -7, 0.5, -7)
        if formatValue then
            valueLabel.Text = formatValue(value)
        else
            valueLabel.Text = tostring(value)
        end
    end
    local sliderDragging = false
    local sliderStartX = 0
    local sliderStartValue = 0
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliderDragging = true
            sliderStartX = input.Position.X
            sliderStartValue = normalize(getValue())
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not sliderDragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            local width = math.max(1, bar.AbsoluteSize.X)
            local delta = (input.Position.X - sliderStartX) / width
            local value = normalize(sliderStartValue + delta * (maximum - minimum))
            setValue(value)
            refresh()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliderDragging = false
        end
    end)
    refresh()
    return row
end
 
closeDropdown = function()
    if activeDropdown then
        activeDropdown.overlay:Destroy()
        activeDropdown.popup:Destroy()
        activeDropdown = nil
    end
end
 
local function openDropdown(anchor, options, current, onSelect)
    closeDropdown()
    if type(options) ~= "table" or #options == 0 then
        return
    end
    local overlay = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 90,
    }, sg)
    overlay.MouseButton1Click:Connect(function()
        closeDropdown()
    end)
    local maxHeight = math.min(230, #options * 30 + 8)
    local x = math.clamp(anchor.AbsolutePosition.X, 8, math.max(8, viewport.X - anchor.AbsoluteSize.X - 8))
    local y = anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y + 4
    if y + maxHeight > viewport.Y - 8 then
        y = math.max(8, anchor.AbsolutePosition.Y - maxHeight - 4)
    end
    local popup = new("Frame", {
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(anchor.AbsoluteSize.X, maxHeight),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 91,
    }, sg)
    rounded(popup, 10)
    stroke(popup, C.accent, 1, 0.35)
    local scroll = new("ScrollingFrame", {
        Size = UDim2.new(1, -4, 1, -4),
        Position = UDim2.fromOffset(2, 2),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.line,
        ZIndex = 92,
    }, popup)
    new("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, scroll)
    for optionIndex, option in ipairs(options) do
        local selected = option == current
        local button = new("TextButton", {
            Text = tostring(option),
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = selected and C.accent or C.panel2,
            TextColor3 = selected and C.bg or C.text,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = optionIndex,
            ZIndex = 93,
        }, scroll)
        rounded(button, 6)
        button.MouseButton1Click:Connect(function()
            onSelect(option)
            closeDropdown()
        end)
    end
    activeDropdown = { overlay = overlay, popup = popup }
end
 
local function addDropdown(page, title, getOptions, getValue, onSelect, order)
    local row = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = C.panel,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = 12,
    }, page)
    rounded(row, 10)
    stroke(row, C.line, 1, 0.45)
    new("TextLabel", {
        Text = title,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -130, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = C.text,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 13,
    }, row)
    local valueLabel = new("TextLabel", {
        Text = tostring(getValue()),
        Position = UDim2.new(1, -128, 0, 0),
        Size = UDim2.fromOffset(104, 42),
        BackgroundTransparency = 1,
        TextColor3 = C.accent2,
        TextSize = 9,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 13,
    }, row)
    new("TextLabel", {
        Text = "▾",
        Position = UDim2.new(1, -20, 0, 0),
        Size = UDim2.fromOffset(16, 42),
        BackgroundTransparency = 1,
        TextColor3 = C.dim,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        ZIndex = 13,
    }, row)
    row.MouseButton1Click:Connect(function()
        local options = getOptions()
        openDropdown(row, options, getValue(), function(choice)
            onSelect(choice)
            valueLabel.Text = tostring(choice)
        end)
    end)
    return row
end
 
local manualThrow
local destroyUI
local farmOrder = 0
local function farmNext()
    farmOrder = farmOrder + 1
    return farmOrder
end
 
local statsCard = new("Frame", {
    Size = UDim2.new(1, 0, 0, 94),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
    LayoutOrder = farmNext(),
    ZIndex = 12,
}, pageFarm)
rounded(statsCard, 12)
stroke(statsCard, C.line, 1, 0.4)
local function statBox(position, title)
    local box = new("Frame", {
        Size = UDim2.new(0.5, -14, 0, 30),
        Position = position,
        BackgroundTransparency = 1,
        ZIndex = 13,
    }, statsCard)
    new("TextLabel", {
        Text = title,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 11),
        BackgroundTransparency = 1,
        TextColor3 = C.dim,
        TextSize = 8,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, box)
    return new("TextLabel", {
        Text = "—",
        Position = UDim2.fromOffset(0, 12),
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        TextColor3 = C.text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    }, box)
end
UI.stats = {
    money = statBox(UDim2.fromOffset(12, 8), "ДЕНЬГИ"),
    power = statBox(UDim2.new(0.5, 4, 0, 8), "СИЛА БРОСКА"),
    level = statBox(UDim2.fromOffset(12, 44), "УРОВЕНЬ"),
    index = statBox(UDim2.new(0.5, 4, 0, 44), "ИНДЕКС"),
}
UI.stats.food = new("TextLabel", {
    Text = "Еда: —",
    Position = UDim2.fromOffset(12, 76),
    Size = UDim2.new(1, -24, 0, 14),
    BackgroundTransparency = 1,
    TextColor3 = C.accent2,
    TextSize = 9,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 13,
}, statsCard)
 
local function updateStats()
    if not UI.stats then
        return
    end
    UI.stats.money.Text = fmt(getMoney())
    UI.stats.power.Text = fmt(getPower())
    UI.stats.level.Text = tostring(math.floor(getLevel()))
    UI.stats.index.Text = tostring(getIndexCount())
    local equipped = getEquippedFood()
    local food = getFood(equipped)
    UI.stats.food.Text = "Еда: " .. tostring(food and food.Name or ("#" .. tostring(equipped)))
    if UI.dot then
        UI.dot.BackgroundColor3 = remotesReady and C.accent or C.red
    end
end
 
section(pageFarm, "Авто-фарм", farmNext())
addToggle(pageFarm, "autoThrow", "Auto Throw", "Идеальный бросок, авто-еда и максимальная зона", farmNext(), function(on)
    if on then
        if Toggles.autoIndex then
            Toggles.autoIndex(false, true)
        end
        if Toggles.autoTrain then
            Toggles.autoTrain(false, true)
        end
        invoke("Training_Stop")
        setPushback(false)
        setStatus("Auto Throw включён")
    else
        if not S.autoIndex then
            setPushback(true)
        end
        setStatus("Auto Throw выключен")
    end
end)
addToggle(pageFarm, "autoIndex", "Auto Index", "Ловит только недостающих животных по зонам", farmNext(), function(on)
    if on then
        if Toggles.autoThrow then
            Toggles.autoThrow(false, true)
        end
        if Toggles.autoTrain then
            Toggles.autoTrain(false, true)
        end
        invoke("Training_Stop")
        setPushback(false)
        if not indexReady() then
            notify("Модули индекса ещё грузятся")
        end
        setStatus("Auto Index включён")
    else
        if not S.autoThrow then
            setPushback(true)
        end
        setStatus("Auto Index выключен")
    end
end)
addToggle(pageFarm, "autoTrain", "Auto Train", "Качает Throw Power на турнике", farmNext(), function(on)
    if on then
        if Toggles.autoThrow then
            Toggles.autoThrow(false, true)
        end
        if Toggles.autoIndex then
            Toggles.autoIndex(false, true)
        end
        invoke("Throw_Cancel")
        setPushback(true)
        setStatus("Auto Train включён")
    else
        invoke("Training_Stop")
        setStatus("Auto Train выключен")
    end
end)
addToggle(pageFarm, "autoTap", "Auto Tap Bonus", "Забирает x2 бонус тренировки", farmNext(), function(on)
    setStatus(on and "Бонус x2 включён" or "Бонус x2 выключен")
end)
section(pageFarm, "Тайминги", farmNext())
addSlider(pageFarm, "Задержка броска", 0.8, 3.0, 0.1, function()
    return S.throwDelay
end, function(value)
    S.throwDelay = value
end, function(value)
    return string.format("%.1f с", value)
end, farmNext())
addSlider(pageFarm, "Тайминг метра", 0.8, 1.3, 0.01, function()
    return S.perfect
end, function(value)
    S.perfect = value
end, function(value)
    return string.format("%.2f с", value)
end, farmNext())
 
local actionOrder = 0
local function actionNext()
    actionOrder = actionOrder + 1
    return actionOrder
end
 
section(pageActions, "Автоматизация", actionNext())
addToggle(pageActions, "autoEquip", "Auto Equip Best", "Ставит лучших животных на плот", actionNext(), function(on)
    if on then
        invoke("Plot_EquipBest")
    end
    setStatus(on and "Auto Equip включён" or "Auto Equip выключен")
end)
addToggle(pageActions, "autoSell", "Auto Sell", "Продаёт животных из резерва", actionNext(), function(on)
    if on then
        invoke("Plot_SellAll")
    end
    setStatus(on and "Auto Sell включён" or "Auto Sell выключен")
end)
addToggle(pageActions, "autoBuy", "Auto Buy Food", "Покупает и экипирует лучшую доступную еду", actionNext(), function(on)
    if on then
        buyAndEquipBestFood()
    end
    setStatus(on and "Auto Buy включён" or "Auto Buy выключен")
end)
addToggle(pageActions, "autoStand", "Auto Upgrade Stand", "Улучшает турник на плоту", actionNext(), function(on)
    if on then
        invoke("Stand_Upgrade")
    end
    setStatus(on and "Апгрейд турника включён" or "Апгрейд турника выключен")
end)
addToggle(pageActions, "autoFence", "Auto Upgrade Fence", "Расширяет плот под животных", actionNext(), function(on)
    if on then
        invoke("Plot_UpgradeFence")
    end
    setStatus(on and "Апгрейд плота включён" or "Апгрейд плота выключен")
end)
addToggle(pageActions, "autoFree", "Auto Claim Free", "Забирает бесплатные награды", actionNext(), function(on)
    if on then
        invoke("Shop_ClaimFree")
    end
    setStatus(on and "Авто-награды включены" or "Авто-награды выключены")
end)
addToggle(pageActions, "autoOffline", "Auto Claim Offline", "Забирает оффлайн-доход", actionNext(), function(on)
    if on then
        invoke("Offline_Claim")
    end
    setStatus(on and "Оффлайн-доход включён" or "Оффлайн-доход выключен")
end)
addToggle(pageActions, "autoEggs", "Auto Hatch Eggs", "Размещает и открывает яйца на плоту", actionNext(), function(on)
    setStatus(on and "Авто-яйца включены" or "Авто-яйца выключены")
end)
section(pageActions, "Действия", actionNext())
addButton(pageActions, "Мгновенный бросок", C.accent, actionNext(), function()
    task.spawn(function()
        manualThrow()
    end)
end)
addButton(pageActions, "Equip Best", C.panel2, actionNext(), function()
    invoke("Plot_EquipBest")
    notify("Лучшие животные размещены")
end, C.text)
addButton(pageActions, "Sell All", C.red, actionNext(), function()
    invoke("Plot_SellAll")
    notify("Резерв продан")
end, C.white)
addButton(pageActions, "Claim All", C.panel2, actionNext(), function()
    invoke("Shop_ClaimFree")
    invoke("Offline_Claim")
    notify("Награды получены")
end, C.text)
addButton(pageActions, "Rejoin", C.panel2, actionNext(), function()
    notify("Переподключение...")
    task.wait(0.4)
    pcall(function()
        TeleportService:Teleport(PLACE_ID, LocalPlayer)
    end)
end, C.text)
addButton(pageActions, "Stop All", C.red, actionNext(), function()
    for key in pairs(Toggles) do
        Toggles[key](false, true)
    end
    invoke("Training_Stop")
    invoke("Throw_Cancel")
    setPushback(true)
    setStatus("Всё остановлено")
end, C.white)
 
local settingsOrder = 0
local function settingsNext()
    settingsOrder = settingsOrder + 1
    return settingsOrder
end
 
section(pageSettings, "Цели", settingsNext())
addDropdown(pageSettings, "Зона броска", zoneOptions, function()
    return S.zone
end, function(choice)
    S.zone = choice
    setStatus("Зона: " .. tostring(choice))
end, settingsNext())
local function foodOptions()
    return { "Авто", "Не менять" }
end
addDropdown(pageSettings, "Режим еды", foodOptions, function()
    return S.foodMode
end, function(choice)
    S.foodMode = choice
    setStatus("Еда: " .. tostring(choice))
end, settingsNext())
section(pageSettings, "Тренировка", settingsNext())
addSlider(pageSettings, "Задержка тренировки", 0.25, 1.5, 0.05, function()
    return S.trainDelay
end, function(value)
    S.trainDelay = value
end, function(value)
    return string.format("%.2f с", value)
end, settingsNext())
section(pageSettings, "Инструменты", settingsNext())
addButton(pageSettings, "Проверить индекс", C.panel2, settingsNext(), function()
    if not indexReady() then
        notify("Модули индекса ещё не загружены")
        return
    end
    local target = getNextIndexTarget()
    if target then
        notify("Ближе всего: " .. tostring(target.name) .. " (" .. tostring(target.area) .. "), не хватает " .. tostring(target.missing))
    else
        notify("Индекс собран или данные недоступны")
    end
end, C.text)
section(pageSettings, "Информация", settingsNext())
new("TextLabel", {
    Text = "TFFA HUB v" .. VERSION,
    Size = UDim2.new(1, 0, 0, 16),
    BackgroundTransparency = 1,
    TextColor3 = C.text,
    TextSize = 9,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = settingsNext(),
    ZIndex = 12,
}, pageSettings)
new("TextLabel", {
    Text = "Игра: Throw Food For Animals",
    Size = UDim2.new(1, 0, 0, 16),
    BackgroundTransparency = 1,
    TextColor3 = C.dim,
    TextSize = 9,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = settingsNext(),
    ZIndex = 12,
}, pageSettings)
new("TextLabel", {
    Text = "Place ID: " .. tostring(PLACE_ID),
    Size = UDim2.new(1, 0, 0, 16),
    BackgroundTransparency = 1,
    TextColor3 = C.dim,
    TextSize = 9,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = settingsNext(),
    ZIndex = 12,
}, pageSettings)
new("TextLabel", {
    Text = "Delta Android • Luau",
    Size = UDim2.new(1, 0, 0, 16),
    BackgroundTransparency = 1,
    TextColor3 = C.dim,
    TextSize = 9,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = settingsNext(),
    ZIndex = 12,
}, pageSettings)
addButton(pageSettings, "Выгрузить меню", C.red, settingsNext(), function()
    destroyUI()
end, C.white)
 
manualThrow = function()
    if S.autoThrow or S.autoIndex then
        notify("Сначала выключи Auto Throw и Auto Index")
        return
    end
    local ok, err = pcall(throwCycle)
    if not ok then
        notify("Ошибка: " .. tostring(err))
    else
        notify("Бросок выполнен")
    end
end
 
destroyUI = function()
    S.running = false
    for key in pairs(Toggles) do
        Toggles[key](false, true)
    end
    pcall(function()
        invoke("Training_Stop")
    end)
    pcall(function()
        invoke("Throw_Cancel")
    end)
    setPushback(true)
    closeDropdown()
    sg:Destroy()
end
 
buildZones()
task.spawn(function()
    local ok = loadRemoteFolder()
    if ok then
        setStatus("Remotes подключены")
    else
        setStatus("Remotes не найдены")
    end
end)
task.spawn(function()
    loadModules()
    buildZones()
    if indexReady() then
        setStatus("Модули загружены")
    end
end)
task.spawn(function()
    while S.running and tokenValue.Value == TOKEN do
        pcall(updateStats)
        task.wait(0.5)
    end
end)
notify("TFFA HUB загружен")
setStatus("Готов")
