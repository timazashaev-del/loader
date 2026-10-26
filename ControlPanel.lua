--[[
	ПАНЕЛЬ УПРАВЛЕНИЯ ПЕРСОНАЖЕМ (версия для Delta)

	Запуск: вставьте весь скрипт в Delta и нажмите Execute.
	  (или по ссылке: loadstring(game:HttpGet("RAW_ССЫЛКА"))())

	Функции (у каждой есть ON/OFF):
	  1. Скорость передвижения (ползунок + ввод числа)
	  2. Скорость на питомце (ползунок + ввод числа)
	  3. Бесконечная выносливость питомца
	  4. Полёт (WASD/джойстик по камере, Пробел/E — вверх, Ctrl/Q — вниз,
	     на телефоне кнопки ▲ ▼)
	  5. Бесконечная выносливость игрока (в том числе во время полёта)

	Меню: кнопка слева (её можно перетаскивать) или RightShift.
	Полёт: переключатель в меню или клавиша F.
	Повторный запуск безопасен — старая копия выгружается автоматически.
	Кнопка «Выгрузить скрипт» полностью удаляет панель и возвращает скорость.
]]

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
while not player do
	task.wait()
	player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui")

local env = (typeof(getgenv) == "function" and getgenv()) or _G

-- Выгружаем предыдущую копию (если скрипт запустили повторно)
if type(env.ControlPanelUnload) == "function" then
	pcall(env.ControlPanelUnload)
	env.ControlPanelUnload = nil
end

--------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------
local CONFIG = {
	MenuKey = Enum.KeyCode.RightShift,
	FlyKey = Enum.KeyCode.F,
	FlyUpKeys = { Enum.KeyCode.Space, Enum.KeyCode.E },
	FlyDownKeys = { Enum.KeyCode.LeftControl, Enum.KeyCode.Q },

	Walk = { Min = 16, Max = 300, Default = 50 },
	Pet = { Min = 16, Max = 400, Default = 80 },
	Fly = { Min = 10, Max = 500, Default = 80 },

	Notify = true, -- уведомление при запуске

	-- Имена значений выносливости (NumberValue / IntValue / Attribute).
	-- Совпадение ищется по части имени.
	StaminaKeywords = { "stamina", "stam", "energy", "endurance", "выносл", "Выносл", "энерг", "Энерг" },
	-- Эти слова в имени/пути значат, что выносливость относится к питомцу.
	PetKeywords = { "pet", "mount", "horse", "питом", "Питом", "конь", "Конь", "ездов", "Ездов" },
	-- Слова, которые НЕ считаются выносливостью (максимум, регенерация и т.п.).
	StaminaExclude = { "max", "regen", "drain", "cost", "rate", "delay", "cooldown", "consum", "speed", "stamp" },
	-- Атрибуты скорости питомца (если игра хранит скорость в атрибутах).
	SpeedAttributes = { "Speed", "WalkSpeed", "MoveSpeed", "RunSpeed", "MountSpeed", "PetSpeed" },

	-- Если питомец определяется особым образом, верните его модель:
	-- CustomGetMount = function(player, character) return workspace.Pets:FindFirstChild(player.Name) end
	CustomGetMount = nil,
}

--------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------
local State = {
	Walk = { On = false, Value = CONFIG.Walk.Default },
	Pet = { On = false, Value = CONFIG.Pet.Default },
	PetStamina = { On = false },
	Fly = { On = false, Value = CONFIG.Fly.Default },
	Stamina = { On = false },
}

--------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------
local connections = {}
local function track(conn)
	connections[#connections + 1] = conn
	return conn
end

local lastWarn = 0
local function safeConnect(signal, fn)
	return track(signal:Connect(function(...)
		local ok, err = pcall(fn, ...)
		if not ok and os.clock() - lastWarn > 2 then
			lastWarn = os.clock()
			warn("[ControlPanel] " .. tostring(err))
		end
	end))
end

local function getHumanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function containsAny(str, list)
	local lowered = string.lower(str)
	for _, key in ipairs(list) do
		if string.find(str, key, 1, true) or string.find(lowered, key, 1, true) then
			return true
		end
	end
	return false
end

local function relName(inst, root)
	local parts = {}
	local cur = inst
	while cur and cur ~= root do
		parts[#parts + 1] = cur.Name
		cur = cur.Parent
	end
	return table.concat(parts, "/")
end

-- Куда класть GUI: gethui() -> CoreGui -> PlayerGui
local function resolveGuiParent()
	if typeof(gethui) == "function" then
		local ok, ui = pcall(gethui)
		if ok and typeof(ui) == "Instance" then
			return ui
		end
	end
	local ok = pcall(function()
		local probe = Instance.new("Folder")
		probe.Parent = game:GetService("CoreGui")
		probe:Destroy()
	end)
	if ok then
		return game:GetService("CoreGui")
	end
	return playerGui
end

--------------------------------------------------------------------
-- ПОИСК ПИТОМЦА (на котором сидит игрок)
--------------------------------------------------------------------
local function detectMount()
	local char = player.Character
	local hum = getHumanoid()
	local root = getRoot()
	if not (char and hum and root) then
		return nil
	end

	if CONFIG.CustomGetMount then
		local ok, model = pcall(CONFIG.CustomGetMount, player, char)
		if ok and typeof(model) == "Instance" then
			return model
		end
	end

	-- 1) обычное сиденье
	local seat = hum.SeatPart
	if seat then
		local model = seat:FindFirstAncestorOfClass("Model")
		if model and model ~= char then
			return model
		end
	end

	-- 2) персонаж приварен (Weld/Motor6D/WeldConstraint) к чужой модели
	for _, joint in ipairs(root:GetJoints()) do
		local other
		if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
			other = (joint.Part0 == root) and joint.Part1 or joint.Part0
		end
		if other and not other:IsDescendantOf(char) then
			local model = other:FindFirstAncestorOfClass("Model")
			if model and model ~= char and not Players:GetPlayerFromCharacter(model) then
				return model
			end
		end
	end

	return nil
end

local mountCache, lastMountCheck = nil, 0
local function currentMount()
	local now = os.clock()
	if now - lastMountCheck > 0.2 then
		lastMountCheck = now
		mountCache = detectMount()
	end
	if mountCache and not mountCache.Parent then
		mountCache = nil
	end
	return mountCache
end

--------------------------------------------------------------------
-- СКОРОСТЬ (с автоматическим возвратом исходных значений)
--------------------------------------------------------------------
local saved = {}   -- [Instance] = { [key] = original }
local touched = {} -- [Instance] = true (в текущем кадре)

local function readProp(inst, key)
	if string.sub(key, 1, 1) == "@" then
		return inst:GetAttribute(string.sub(key, 2))
	end
	return inst[key]
end

local function writeProp(inst, key, value)
	if string.sub(key, 1, 1) == "@" then
		inst:SetAttribute(string.sub(key, 2), value)
	else
		inst[key] = value
	end
end

local function force(inst, key, value)
	local s = saved[inst]
	if not s then
		s = {}
		saved[inst] = s
	end
	if s[key] == nil then
		s[key] = readProp(inst, key)
	end
	touched[inst] = true
	if readProp(inst, key) ~= value then
		writeProp(inst, key, value)
	end
end

local function releaseUntouched()
	for inst, props in pairs(saved) do
		if not touched[inst] then
			if inst.Parent then
				for key, original in pairs(props) do
					pcall(writeProp, inst, key, original)
				end
			end
			saved[inst] = nil
		end
	end
	table.clear(touched)
end

local speedCache = { mount = nil, at = 0, list = {} }
local function getPetSpeedTargets(mount)
	local now = os.clock()
	if speedCache.mount ~= mount or now - speedCache.at > 1 then
		speedCache.mount = mount
		speedCache.at = now
		local list = {}
		local speedNames = {}
		for _, n in ipairs(CONFIG.SpeedAttributes) do
			speedNames[string.lower(n)] = true
		end
		local function addAttrs(inst)
			for _, name in ipairs(CONFIG.SpeedAttributes) do
				if type(inst:GetAttribute(name)) == "number" then
					list[#list + 1] = { inst, "@" .. name }
				end
			end
		end
		addAttrs(mount)
		for _, d in ipairs(mount:GetDescendants()) do
			if d:IsA("Humanoid") then
				list[#list + 1] = { d, "WalkSpeed" }
				addAttrs(d)
			elseif d:IsA("VehicleSeat") then
				list[#list + 1] = { d, "MaxSpeed" }
				addAttrs(d)
			elseif (d:IsA("NumberValue") or d:IsA("IntValue")) and speedNames[string.lower(d.Name)] then
				list[#list + 1] = { d, "Value" }
			end
		end
		speedCache.list = list
	end
	return speedCache.list
end

-- Запасной способ для питомца: если игра двигает его физикой, задаём
-- горизонтальную скорость сборки (только пока есть ввод движения).
local function boostAssembly(part)
	if not part or part.Anchored then
		return
	end
	local v = part.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude > 2 then
		local d = flat.Unit * State.Pet.Value
		part.AssemblyLinearVelocity = Vector3.new(d.X, v.Y, d.Z)
	end
end

local function boostMount(mount)
	if State.Fly.On then
		return
	end
	local hum = getHumanoid()
	local root = getRoot()
	if not (hum and root) or hum.MoveDirection.Magnitude < 0.05 then
		return
	end
	boostAssembly(root)
	local pp = mount.PrimaryPart
	if pp and pp.AssemblyRootPart ~= root.AssemblyRootPart then
		boostAssembly(pp)
	end
end

local function applySpeeds()
	local hum = getHumanoid()
	if hum and hum.Health > 0 then
		local mount = currentMount()
		if mount and State.Pet.On then
			force(hum, "WalkSpeed", State.Pet.Value)
			for _, t in ipairs(getPetSpeedTargets(mount)) do
				if t[1].Parent then
					force(t[1], t[2], State.Pet.Value)
				end
			end
			boostMount(mount)
		elseif State.Walk.On then
			force(hum, "WalkSpeed", State.Walk.Value)
		end
	end
	releaseUntouched()
end

--------------------------------------------------------------------
-- ВЫНОСЛИВОСТЬ
--------------------------------------------------------------------
local staminaTargets = { General = {}, Pet = {} }
local lastScan = 0
local seenStore = setmetatable({}, { __mode = "k" })
local playerFolders, lastFolderScan = {}, 0

local function isStaminaName(name)
	return containsAny(name, CONFIG.StaminaKeywords) and not containsAny(name, CONFIG.StaminaExclude)
end

local function readStamina(t)
	if t.attr then
		return t.inst:GetAttribute(t.attr)
	end
	return t.inst.Value
end

local function writeStamina(t, value)
	if t.attr then
		t.inst:SetAttribute(t.attr, value)
	else
		t.inst.Value = value
	end
end

-- запоминает максимальное виденное значение (для игр без явного Max)
local function noteSeen(t, cur)
	local store = seenStore[t.inst]
	if not store then
		store = {}
		seenStore[t.inst] = store
	end
	local key = t.attr or "#value"
	if not store[key] or cur > store[key] then
		store[key] = cur
	end
	return store[key]
end

local function findMaxFor(inst, attr)
	local base = string.lower(attr or inst.Name)
	local function check(name, value)
		if type(value) == "number" then
			local l = string.lower(name)
			if string.find(l, "max", 1, true) and string.find(l, base, 1, true) then
				return value
			end
		end
		return nil
	end
	for n, v in pairs(inst:GetAttributes()) do
		local r = check(n, v)
		if r then return r end
	end
	if not attr then
		local parent = inst.Parent
		if parent then
			for _, sib in ipairs(parent:GetChildren()) do
				if sib:IsA("NumberValue") or sib:IsA("IntValue") then
					local r = check(sib.Name, sib.Value)
					if r then return r end
				end
			end
			for n, v in pairs(parent:GetAttributes()) do
				local r = check(n, v)
				if r then return r end
			end
		end
	end
	return nil
end

local function scanInstance(inst, add)
	if inst:IsA("NumberValue") or inst:IsA("IntValue") then
		if isStaminaName(inst.Name) then
			add(inst, nil)
		end
	end
	for name, value in pairs(inst:GetAttributes()) do
		if type(value) == "number" and isStaminaName(name) then
			add(inst, name)
		end
	end
end

local function rescanStamina()
	local general, pet = {}, {}

	local function makeAdd(relRoot, forcePet)
		return function(inst, attr)
			local rel = relName(inst, relRoot) .. "/" .. (attr or "")
			local isPet = forcePet or containsAny(rel, CONFIG.PetKeywords)
			local list = isPet and pet or general
			local entry = { inst = inst, attr = attr, max = findMaxFor(inst, attr) }
			list[#list + 1] = entry
			local cur = readStamina(entry)
			if type(cur) == "number" then
				noteSeen(entry, cur)
			end
		end
	end

	local function scanTree(root, relRoot, forcePet)
		local add = makeAdd(relRoot, forcePet)
		scanInstance(root, add)
		for _, d in ipairs(root:GetDescendants()) do
			scanInstance(d, add)
		end
	end

	scanInstance(player, makeAdd(player, false))
	for _, child in ipairs(player:GetChildren()) do
		if not (child:IsA("PlayerGui") or child:IsA("PlayerScripts")) then
			scanTree(child, player, false)
		end
	end

	local char = player.Character
	if char then
		scanTree(char, char, false)
	end

	local mount = currentMount()
	if mount then
		scanTree(mount, mount, true)
	end

	-- данные игрока в ReplicatedStorage / Workspace (папка с именем или UserId игрока)
	if os.clock() - lastFolderScan > 5 then
		lastFolderScan = os.clock()
		playerFolders = {}
		for _, holder in ipairs({ ReplicatedStorage, Workspace }) do
			for _, child in ipairs(holder:GetChildren()) do
				if child:IsA("Folder") or child:IsA("Model") or child:IsA("Configuration") then
					local mine = child:FindFirstChild(player.Name) or child:FindFirstChild(tostring(player.UserId))
					if mine then
						playerFolders[#playerFolders + 1] = { mine, containsAny(child.Name, CONFIG.PetKeywords) }
					end
				end
			end
		end
	end
	for _, f in ipairs(playerFolders) do
		if f[1].Parent then
			scanTree(f[1], f[1], f[2])
		end
	end

	staminaTargets.General = general
	staminaTargets.Pet = pet
end

local function enforce(list)
	for i = #list, 1, -1 do
		local t = list[i]
		if not t.inst.Parent then
			table.remove(list, i)
		else
			local cur = readStamina(t)
			if type(cur) == "number" then
				local seen = noteSeen(t, cur)
				local target = t.max or seen
				if target <= 0 then
					target = 100
				end
				if cur < target then
					writeStamina(t, target)
				end
			end
		end
	end
end

--------------------------------------------------------------------
-- ПОЛЁТ
--------------------------------------------------------------------
local Fly = { att = nil, lv = nil, ao = nil, vel = Vector3.zero, platform = false, upTouch = false, downTouch = false }
local controls = nil

task.spawn(function()
	local ps = player:WaitForChild("PlayerScripts", 15)
	local pm = ps and ps:WaitForChild("PlayerModule", 15)
	if not pm then
		return
	end
	local ok, module = pcall(require, pm)
	if ok and type(module) == "table" then
		local ok2, c = pcall(function()
			return module:GetControls()
		end)
		if ok2 and c then
			controls = c
			return
		end
	end
	local cm = pm:FindFirstChild("ControlModule")
	if cm then
		local ok3, c3 = pcall(require, cm)
		if ok3 and type(c3) == "table" and c3.GetMoveVector then
			controls = c3
		end
	end
end)

local Debug = { src = "нет", x = 0, z = 0 }

local function flatUnit(v)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude > 0.001 then
		return f.Unit
	end
	return nil
end

-- Ввод относительно камеры: X — вправо, Z — назад (вперёд = -Z).
-- Источники по порядку: штатные контролы -> Humanoid.MoveDirection -> клавиатура.
local function getMoveVector()
	if controls then
		local ok, v = pcall(controls.GetMoveVector, controls)
		if ok and typeof(v) == "Vector3" and (math.abs(v.X) > 0.01 or math.abs(v.Z) > 0.01) then
			Debug.src = "controls"
			return v
		end
	end

	local hum = getHumanoid()
	local cam = Workspace.CurrentCamera
	if hum and cam then
		local md = hum.MoveDirection
		if md.Magnitude > 0.05 then
			local cf = cam.CFrame
			local fwd = flatUnit(cf.LookVector) or flatUnit(cf.UpVector)
			local rgt = flatUnit(cf.RightVector)
			if fwd and rgt then
				Debug.src = "humanoid"
				return Vector3.new(md:Dot(rgt), 0, -md:Dot(fwd))
			end
		end
	end

	local x, z = 0, 0
	if UserInputService:GetFocusedTextBox() == nil then
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then z -= 1 end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then z += 1 end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then x -= 1 end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then x += 1 end
	end
	Debug.src = (x ~= 0 or z ~= 0) and "клавиши" or "нет"
	return Vector3.new(x, 0, z)
end

local function anyKeyDown(keys)
	if UserInputService:GetFocusedTextBox() ~= nil then
		return false
	end
	for _, k in ipairs(keys) do
		if UserInputService:IsKeyDown(k) then
			return true
		end
	end
	return false
end

local function stopFly()
	if Fly.lv then Fly.lv:Destroy() end
	if Fly.ao then Fly.ao:Destroy() end
	if Fly.att then Fly.att:Destroy() end
	Fly.lv, Fly.ao, Fly.att = nil, nil, nil
	Fly.vel = Vector3.zero
	if Fly.platform then
		Fly.platform = false
		local hum = getHumanoid()
		if hum and hum.Health > 0 then
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end
end

local function startFly(root)
	stopFly()
	local att = Instance.new("Attachment")
	att.Name = "ControlPanelFlyAttachment"
	att.Parent = root

	local lv = Instance.new("LinearVelocity")
	lv.Name = "ControlPanelFlyVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = math.huge
	lv.VectorVelocity = Vector3.zero
	lv.Parent = root

	local ao = Instance.new("AlignOrientation")
	ao.Name = "ControlPanelFlyAlign"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = false
	ao.MaxTorque = math.huge
	ao.Responsiveness = 20
	ao.CFrame = root.CFrame.Rotation
	ao.Parent = root

	Fly.att, Fly.lv, Fly.ao = att, lv, ao
end

local function updateFly(dt)
	local root, hum = getRoot(), getHumanoid()
	if not State.Fly.On or not root or not hum or hum.Health <= 0 then
		if Fly.lv then stopFly() end
		return
	end

	if not Fly.lv or Fly.lv.Parent ~= root then
		startFly(root)
	end

	local cam = Workspace.CurrentCamera
	if not cam then return end

	local mounted = currentMount() ~= nil
	Fly.platform = true
	hum.PlatformStand = not mounted
	Fly.ao.Enabled = not mounted

	local mv = getMoveVector()
	Debug.x, Debug.z = mv.X, mv.Z
	local cf = cam.CFrame
	local dir = cf.RightVector * mv.X + cf.LookVector * (-mv.Z)

	local vertical = 0
	if anyKeyDown(CONFIG.FlyUpKeys) or Fly.upTouch then vertical += 1 end
	if anyKeyDown(CONFIG.FlyDownKeys) or Fly.downTouch then vertical -= 1 end
	dir += Vector3.new(0, vertical, 0)
	if dir.Magnitude > 1 then
		dir = dir.Unit
	end

	Fly.vel = Fly.vel:Lerp(dir * State.Fly.Value, math.clamp(dt * 12, 0, 1))
	Fly.lv.VectorVelocity = Fly.vel

	if Fly.ao.Enabled then
		local look = cf.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			Fly.ao.CFrame = CFrame.lookAt(Vector3.zero, flat)
		end
	end
end

--------------------------------------------------------------------
-- UI
--------------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(22, 23, 29),
	card = Color3.fromRGB(32, 34, 43),
	stroke = Color3.fromRGB(52, 55, 68),
	text = Color3.fromRGB(240, 241, 245),
	sub = Color3.fromRGB(148, 152, 168),
	accent = Color3.fromRGB(99, 102, 241),
	on = Color3.fromRGB(52, 199, 120),
	off = Color3.fromRGB(70, 73, 88),
	danger = Color3.fromRGB(190, 70, 80),
	white = Color3.new(1, 1, 1),
}

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function tween(inst, props, t)
	TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local guiParent = resolveGuiParent()
for _, parent in ipairs({ guiParent, playerGui }) do
	local old = parent:FindFirstChild("ControlPanelGui")
	if old then
		old:Destroy()
	end
end

local gui = new("ScreenGui", {
	Name = "ControlPanelGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
gui.Parent = guiParent

local Unload -- объявлена ниже, нужна кнопке «Выгрузить»

local main = new("Frame", {
	Name = "Main",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.fromOffset(330, 480),
	BackgroundColor3 = C.bg,
	Active = true,
	Parent = gui,
}, {
	corner(14),
	new("UIStroke", { Color = C.stroke, Thickness = 1 }),
})
local uiScale = new("UIScale", { Parent = main })

-- Заголовок
local header = new("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 52),
	BackgroundTransparency = 1,
	Parent = main,
})
new("TextLabel", {
	Position = UDim2.new(0, 16, 0, 8),
	Size = UDim2.new(1, -110, 0, 20),
	BackgroundTransparency = 1,
	Text = "Панель управления",
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = header,
})
local statusLabel = new("TextLabel", {
	Position = UDim2.new(0, 16, 0, 29),
	Size = UDim2.new(1, -110, 0, 16),
	BackgroundTransparency = 1,
	Text = "Питомец: не найден",
	TextColor3 = C.sub,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = header,
})

local function headerButton(text, xOffset)
	return new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, xOffset, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = C.card,
		Text = text,
		TextColor3 = C.text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = true,
		Parent = header,
	}, { corner(8) })
end
local closeBtn = headerButton("X", -12)
local collapseBtn = headerButton("-", -48)
new("Frame", {
	Position = UDim2.new(0, 14, 1, -2),
	Size = UDim2.new(1, -28, 0, 2),
	BackgroundColor3 = C.accent,
	BorderSizePixel = 0,
	Parent = header,
}, {
	corner(1),
	new("UIGradient", { Color = ColorSequence.new(C.accent, C.on) }),
})

local content = new("ScrollingFrame", {
	Name = "Content",
	Position = UDim2.new(0, 8, 0, 54),
	Size = UDim2.new(1, -16, 1, -62),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.stroke,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = main,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
})

-- Живая информация (обновляется в цикле статуса)
local infoCard = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.card,
	LayoutOrder = 0,
	Parent = content,
}, {
	corner(12),
	new("UIStroke", { Color = C.stroke, Thickness = 1 }),
	new("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}),
})
local liveLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Text = "Загрузка…",
	TextColor3 = C.text,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextWrapped = true,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = infoCard,
})

-- Карточка функции
local function createCard(opts)
	local api = {}
	local isOn = false
	local currentValue
	local cardStroke = new("UIStroke", { Color = C.stroke, Thickness = 1 })

	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.card,
		LayoutOrder = opts.order,
		Parent = content,
	}, {
		corner(12),
		cardStroke,
		new("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card })
	new("TextLabel", {
		Size = UDim2.new(1, -104, 1, 0),
		BackgroundTransparency = 1,
		Text = opts.title,
		TextColor3 = C.text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = top,
	})
	local status = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -52, 0.5, 0),
		Size = UDim2.fromOffset(36, 20),
		BackgroundTransparency = 1,
		Text = "OFF",
		TextColor3 = C.sub,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = top,
	})
	local pill = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(46, 24),
		BackgroundColor3 = C.off,
		Text = "",
		AutoButtonColor = false,
		Parent = top,
	}, { corner(12) })
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = C.white,
		Parent = pill,
	}, { corner(9) })

	if opts.desc then
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = opts.desc,
			TextColor3 = C.sub,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			Parent = card,
		})
	end

	function api.setOn(on, silent)
		isOn = on and true or false
		status.Text = isOn and "ON" or "OFF"
		tween(status, { TextColor3 = isOn and C.on or C.sub })
		tween(pill, { BackgroundColor3 = isOn and C.on or C.off })
		tween(cardStroke, { Color = isOn and C.on or C.stroke })
		tween(knob, { Position = isOn and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
		if not silent and opts.onToggle then
			opts.onToggle(isOn)
		end
	end
	function api.isOn()
		return isOn
	end
	pill.Activated:Connect(function()
		api.setOn(not isOn)
	end)

	if opts.slider then
		local s = opts.slider
		local group = new("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, LayoutOrder = 3, Parent = card })
		new("TextLabel", {
			Size = UDim2.new(1, -72, 0, 22),
			BackgroundTransparency = 1,
			Text = s.label,
			TextColor3 = C.text,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = group,
		})
		local box = new("TextBox", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(64, 22),
			BackgroundColor3 = C.bg,
			Text = "",
			TextColor3 = C.text,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			ClearTextOnFocus = false,
			Parent = group,
		}, { corner(6) })
		local track_ = new("Frame", {
			Position = UDim2.new(0, 0, 0, 33),
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = C.off,
			Parent = group,
		}, { corner(3) })
		local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.accent, Parent = track_ }, { corner(3) })
		local sKnob = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = C.white,
			Parent = track_,
		}, { corner(8) })
		local hit = new("TextButton", {
			Position = UDim2.new(0, -8, 0, 22),
			Size = UDim2.new(1, 16, 0, 26),
			BackgroundTransparency = 1,
			Text = "",
			Parent = group,
		})

		function api.setValue(v, silent)
			v = math.clamp(math.floor(v + 0.5), s.min, s.max)
			currentValue = v
			local rel = (v - s.min) / (s.max - s.min)
			fill.Size = UDim2.new(rel, 0, 1, 0)
			sKnob.Position = UDim2.new(rel, 0, 0.5, 0)
			box.Text = tostring(v)
			if not silent and opts.onValue then
				opts.onValue(v)
			end
		end
		function api.getValue()
			return currentValue
		end

		local dragging = false
		local function fromX(x)
			local rel = math.clamp((x - track_.AbsolutePosition.X) / math.max(track_.AbsoluteSize.X, 1), 0, 1)
			api.setValue(s.min + rel * (s.max - s.min))
		end
		hit.InputBegan:Connect(function(input)
			if isPointer(input) then
				dragging = true
				content.ScrollingEnabled = false
				fromX(input.Position.X)
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						content.ScrollingEnabled = true
					end
				end)
			end
		end)
		track(UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				fromX(input.Position.X)
			end
		end))
		box.FocusLost:Connect(function()
			local n = tonumber((box.Text:gsub("[^%d%.]", "")))
			if n then
				api.setValue(n)
			else
				api.setValue(currentValue)
			end
		end)

		api.setValue(s.default, true)

		if s.presets then
			local row = new("Frame", {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				Parent = card,
			}, {
				new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			for i, v in ipairs(s.presets) do
				local chip = new("TextButton", {
					Size = UDim2.fromOffset(48, 26),
					BackgroundColor3 = C.bg,
					Text = tostring(v),
					TextColor3 = C.text,
					Font = Enum.Font.GothamBold,
					TextSize = 12,
					LayoutOrder = i,
					AutoButtonColor = true,
					Parent = row,
				}, { corner(8) })
				chip.Activated:Connect(function()
					api.setValue(v)
				end)
			end
		end
	end

	return api
end

local walkCard = createCard({
	order = 1,
	title = "Скорость передвижения",
	desc = "Меняет скорость бега персонажа.",
	slider = { label = "Скорость", min = CONFIG.Walk.Min, max = CONFIG.Walk.Max, default = CONFIG.Walk.Default, presets = { 16, 50, 100, 200, 300 } },
	onToggle = function(on) State.Walk.On = on end,
	onValue = function(v) State.Walk.Value = v end,
})

local petCard = createCard({
	order = 2,
	title = "Скорость на питомце",
	desc = "Действует, пока вы едете на питомце.",
	slider = { label = "Скорость", min = CONFIG.Pet.Min, max = CONFIG.Pet.Max, default = CONFIG.Pet.Default, presets = { 40, 80, 150, 250, 400 } },
	onToggle = function(on) State.Pet.On = on end,
	onValue = function(v) State.Pet.Value = v end,
})

local petStaminaCard = createCard({
	order = 3,
	title = "Выносливость питомца",
	desc = "Выносливость питомца всегда на максимуме.",
	onToggle = function(on)
		State.PetStamina.On = on
		lastScan = 0
	end,
})

local flyPad, flyQuick -- кнопки ▲▼ для телефона (создаются ниже)
local flyCard = createCard({
	order = 4,
	title = "Полёт",
	desc = "WASD / джойстик — по направлению камеры. Пробел или E — вверх, Ctrl или Q — вниз. Клавиша F — вкл/выкл.",
	slider = { label = "Скорость полёта", min = CONFIG.Fly.Min, max = CONFIG.Fly.Max, default = CONFIG.Fly.Default, presets = { 30, 80, 150, 300, 500 } },
	onToggle = function(on)
		State.Fly.On = on
		if flyQuick then
			flyQuick.BackgroundColor3 = on and C.on or C.accent
		end
		if flyPad then
			flyPad.Visible = on and UserInputService.TouchEnabled
		end
		if not on then
			Fly.upTouch, Fly.downTouch = false, false
		end
	end,
	onValue = function(v) State.Fly.Value = v end,
})

local staminaCard = createCard({
	order = 5,
	title = "Бесконечная выносливость",
	desc = "Выносливость игрока не тратится, в том числе при полёте.",
	onToggle = function(on)
		State.Stamina.On = on
		lastScan = 0
	end,
})

-- Нижние кнопки
local function bottomButton(text, order, color)
	return new("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = color or C.card,
		Text = text,
		TextColor3 = C.text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		LayoutOrder = order,
		AutoButtonColor = true,
		Parent = content,
	}, { corner(12), new("UIStroke", { Color = C.stroke, Thickness = 1 }) })
end

local offAll = bottomButton("Выключить всё", 6)
offAll.Activated:Connect(function()
	for _, c in ipairs({ walkCard, petCard, petStaminaCard, flyCard, staminaCard }) do
		c.setOn(false)
	end
end)

local debugLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Text = "Диагностика…",
	TextColor3 = C.sub,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 8,
	Parent = content,
})

local unloadBtn = bottomButton("Выгрузить скрипт", 7, C.danger)
unloadBtn.Activated:Connect(function()
	if Unload then
		Unload()
	end
end)

-- Кнопки полёта для телефона
flyPad = new("Frame", {
	Name = "FlyPad",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -20, 0.5, 0),
	Size = UDim2.fromOffset(60, 130),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
local function padButton(text, y, flag)
	local b = new("TextButton", {
		Position = UDim2.new(0, 0, 0, y),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = C.accent,
		BackgroundTransparency = 0.15,
		Text = text,
		TextColor3 = C.white,
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		AutoButtonColor = false,
		Parent = flyPad,
	}, { corner(30) })
	b.InputBegan:Connect(function(input)
		if isPointer(input) then
			Fly[flag] = true
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					Fly[flag] = false
				end
			end)
		end
	end)
end
padButton("▲", 0, "upTouch")
padButton("▼", 70, "downTouch")

-- Плавающая кнопка открытия меню
local fab = new("TextButton", {
	Name = "MenuButton",
	Position = UDim2.new(0, 12, 0.5, -22),
	Size = UDim2.fromOffset(46, 46),
	BackgroundColor3 = Color3.fromRGB(10, 10, 12),
	Text = "",
	AutoButtonColor = true,
	Parent = gui,
}, { corner(23), new("UIStroke", { Color = C.stroke, Thickness = 1.5 }) })
for i = 0, 2 do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, (i - 1) * 6),
		Size = UDim2.fromOffset(18, 2),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Parent = fab,
	}, { corner(1) })
end

-- Перетаскивание окна
do
	local dragging, dragStart, startPos = false, nil, nil
	header.InputBegan:Connect(function(input)
		if isPointer(input) then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
end

-- Свернуть / закрыть / автомасштаб
local collapsed = false
collapseBtn.Activated:Connect(function()
	collapsed = not collapsed
	content.Visible = not collapsed
	main.Size = collapsed and UDim2.fromOffset(330, 52) or UDim2.fromOffset(330, 480)
end)
closeBtn.Activated:Connect(function()
	main.Visible = false
end)
-- плавающие кнопки: тап — действие, движение пальцем — перетаскивание
local function makeDraggable(btn, onTap)
	local dragging, startInput, startPos, moved = false, nil, nil, false
	btn.InputBegan:Connect(function(input)
		if isPointer(input) then
			dragging, moved = true, false
			startInput = input.Position
			startPos = btn.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startInput
			if d.Magnitude > 8 then
				moved = true
			end
			if moved then
				btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end))
	btn.Activated:Connect(function()
		if moved then
			moved = false
			return
		end
		onTap()
	end)
end
makeDraggable(fab, function()
	main.Visible = not main.Visible
end)

local camConn
local function updateScale()
	local cam = Workspace.CurrentCamera
	if cam then
		local vp = cam.ViewportSize
		uiScale.Scale = math.clamp(math.min(vp.X / 380, vp.Y / 540), 0.5, 1)
	end
end
local function hookCamera()
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	local cam = Workspace.CurrentCamera
	if cam then
		camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()
end
track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera))
hookCamera()

-- Горячие клавиши
track(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == CONFIG.MenuKey then
		main.Visible = not main.Visible
	elseif input.KeyCode == CONFIG.FlyKey then
		flyCard.setOn(not flyCard.isOn())
	end
end))

--------------------------------------------------------------------
-- ЦИКЛЫ
--------------------------------------------------------------------
safeConnect(RunService.Stepped, function()
	applySpeeds()
end)

safeConnect(RunService.RenderStepped, function(dt)
	updateFly(dt)
end)

safeConnect(RunService.Heartbeat, function()
	if State.Stamina.On or State.PetStamina.On then
		local now = os.clock()
		if now - lastScan > 1 then
			lastScan = now
			rescanStamina()
		end
		if State.Stamina.On then enforce(staminaTargets.General) end
		if State.PetStamina.On then enforce(staminaTargets.Pet) end
	end
end)

local unloading = false

task.spawn(function()
	while gui.Parent and not unloading do
		local mount = currentMount()
		if mount then
			statusLabel.Text = "Питомец: " .. mount.Name
			statusLabel.TextColor3 = C.on
		else
			statusLabel.Text = "Питомец: не найден"
			statusLabel.TextColor3 = C.sub
		end
		local rootNow = getRoot()
		local humNow = getHumanoid()
		local flatSpeed = 0
		if rootNow then
			local vel = rootNow.AssemblyLinearVelocity
			flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		end
		local modes = (State.Walk.On and "ходьба " or "")
			.. (State.Pet.On and "питомец " or "")
			.. (State.Stamina.On and "выносл. " or "")
			.. (State.PetStamina.On and "выносл.питомца" or "")
		if modes == "" then
			modes = "—"
		end
		liveLabel.Text = string.format(
			"<b>Скорость сейчас:</b> %.0f ст/с  |  <b>WalkSpeed:</b> %.0f\n<b>Питомец:</b> %s\n<b>Полёт:</b> %s  |  <b>Включено:</b> %s",
			flatSpeed, humNow and humNow.WalkSpeed or 0, mount and mount.Name or "не найден",
			State.Fly.On and "вкл" or "выкл", modes
		)
		debugLabel.Text = string.format(
			"Ввод полёта: %s (x %.2f, z %.2f) | controls: %s | питомец: %s",
			Debug.src, Debug.x, Debug.z, controls and "да" or "нет", mount and mount.Name or "нет"
		)
		task.wait(0.3)
	end
end)

track(player.CharacterAdded:Connect(function()
	mountCache = nil
	lastMountCheck = 0
	lastScan = 0
	table.clear(saved)
	table.clear(touched)
	Fly.lv, Fly.ao, Fly.att = nil, nil, nil
	Fly.platform = false
	Fly.vel = Vector3.zero
end))

--------------------------------------------------------------------
-- ВЫГРУЗКА
--------------------------------------------------------------------
Unload = function()
	if unloading then return end
	unloading = true

	State.Walk.On, State.Pet.On, State.Fly.On = false, false, false
	State.Stamina.On, State.PetStamina.On = false, false

	for _, c in ipairs(connections) do
		pcall(c.Disconnect, c)
	end
	table.clear(connections)
	if camConn then
		pcall(camConn.Disconnect, camConn)
		camConn = nil
	end

	pcall(stopFly)
	table.clear(touched)
	pcall(releaseUntouched) -- возвращает исходную скорость

	if gui then
		gui:Destroy()
	end
	if env.ControlPanelUnload == Unload then
		env.ControlPanelUnload = nil
	end
end
env.ControlPanelUnload = Unload

gui.Destroying:Connect(function()
	Unload()
end)

if CONFIG.Notify then
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Панель управления",
			Text = "Загружено! Меню — чёрная кнопка слева.",
			Duration = 5,
		})
	end)
end
