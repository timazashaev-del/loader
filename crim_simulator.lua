
--[[
    CITY CRIMINAL SIMULATOR — ПОЛНЫЙ ДАМП (один файл)
    Запуск в игре через экзекьютор:
      loadstring(game:HttpGet("https://raw.githubusercontent.com/timazashaev-del/loader/mai…"))()
 
    Что собирает:
      1. Экзекьютор и окружение
      2. Workspace: верхний уровень
      3. Грузовики + CargoZone
      4. Спавны лута (LootSpawn)
      5. Зоны продажи (SellZone)
      6. Полиция / снайперы
      7. Remotes (все события и функции)
      8. Shared-модули
      9. Значения: деньги/долг/квота/стамина/вес
     10. PlayerGui (интерфейс игры)
     11. Character
     12. Поиск по ключевым словам с координатами
    Результат: буфер обмена + файл game_dump.txt + вывод в консоль.
]]
 
-- selene: allow(undefined_variable)
 
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local player = Players.LocalPlayer
 
local LINES = {}
local function add(line) LINES[#LINES + 1] = tostring(line) end
local function addAll(list, prefix) for _, v in ipairs(list) do add((prefix or "") .. v) end end
 
local function pathOf(inst)
    local names, cur, guard = {}, inst, 0
    while cur and cur ~= game and guard < 7 do
        names[#names + 1] = cur.Name
        cur = cur.Parent
        guard = guard + 1
    end
    local out = {}
    for i = #names, 1, -1 do out[#out + 1] = names[i] end
    return table.concat(out, "/")
end
 
local function valueOf(inst)
    local ok, v = pcall(function() return inst.Value end)
    if ok and v ~= nil then return tostring(v) end
    return "?"
end
 
local function safeChildren(inst)
    local ok, ch = pcall(function() return inst:GetChildren() end)
    if ok and ch then return ch end
    return {}
end
 
local function walk(root, maxDepth, filter)
    local out = {}
    local function rec(node, depth)
        if depth > maxDepth then return end
        for _, ch in ipairs(safeChildren(node)) do
            if ch:IsA("Terrain") then
                out[#out + 1] = ch
            else
                if not filter or filter(ch) then out[#out + 1] = ch end
                if ch:IsA("Model") or ch:IsA("Folder") or ch:IsA("ScreenGui")
                    or ch:IsA("Configuration") or ch:IsA("PlayerGui") then
                    rec(ch, depth + 1)
                end
            end
        end
    end
    rec(root, 0)
    return out
end
 
local function findAllNamed(root, name, maxDepth)
    local res = {}
    local function rec(node, depth)
        if depth > maxDepth then return end
        for _, ch in ipairs(safeChildren(node)) do
            if ch.Name == name then res[#res + 1] = ch end
            if ch:IsA("Model") or ch:IsA("Folder") then rec(ch, depth + 1) end
        end
    end
    rec(root, 0)
    return res
end
 
-- ========== 1. ОКРУЖЕНИЕ ==========
add("=== ENV ===")
-- selene: allow(undefined_variable)
local okExec, exName = pcall(function() return identifyexecutor() end)
add("executor: " .. (okExec and tostring(exName) or "unknown"))
add("loadstring: " .. type(loadstring))
add("game.HttpGet: " .. type(game["HttpGet"]))
-- selene: allow(undefined_variable)
add("setclipboard: " .. type(setclipboard))
-- selene: allow(undefined_variable)
add("writefile: " .. type(writefile))
add("PlaceId: " .. tostring(game.PlaceId) .. "  GameId: " .. tostring(game.GameId))
add("Player: " .. tostring(player and player.Name))
add("Character: " .. ((player and player.Character) and "yes" or "no"))
 
-- ========== 2. WORKSPACE ==========
add("")
add("=== WORKSPACE TOP ===")
for _, ch in ipairs(safeChildren(WS)) do
    add(ch.Name .. " [" .. ch.ClassName .. "]")
end
 
-- ========== 3. ГРУЗОВИКИ ==========
add("")
add("=== TRUCKS ===")
local truckCount = 0
for _, rootName in ipairs({ "Hideout", "Town", "Desert", "NewMap" }) do
    local root = WS:FindFirstChild(rootName)
    if root then
        for _, m in ipairs(findAllNamed(root, "Truck", 3)) do
            truckCount = truckCount + 1
            add("TRUCK " .. pathOf(m))
            local cargo = m:FindFirstChild("CargoZone")
            if cargo and cargo:IsA("BasePart") then
                local p = cargo.Position
                add("  CargoZone @ " .. math.floor(p.X) .. "," .. math.floor(p.Y) .. "," .. math.floor(p.Z))
            end
            for _, child in ipairs(safeChildren(m)) do
                add("  child: " .. child.Name .. " [" .. child.ClassName .. "]")
            end
        end
    end
end
if truckCount == 0 then add("(грузовики не найдены)") end
 
-- ========== 4. ЛУТ ==========
add("")
add("=== LOOT SPAWNS ===")
local lootFolders = findAllNamed(WS, "LootSpawns", 4)
add("папок LootSpawns: " .. #lootFolders)
local lootParts = {}
for _, folder in ipairs(lootFolders) do
    local n = 0
    for _, p in ipairs(safeChildren(folder)) do
        if p:IsA("BasePart") then
            n = n + 1
            lootParts[#lootParts + 1] = p
        end
    end
    add("  " .. pathOf(folder) .. " -> частей: " .. n)
end
for i = 1, math.min(#lootParts, 12) do
    local p = lootParts[i].Position
    add("  spawn " .. i .. " @ " .. math.floor(p.X) .. "," .. math.floor(p.Y) .. "," .. math.floor(p.Z))
end
if #lootParts > 12 then add("  ... всего " .. #lootParts) end
 
-- ========== 5. ЗОНЫ ПРОДАЖИ ==========
add("")
add("=== SELL ZONES ===")
for _, z in ipairs(findAllNamed(WS, "SellZone", 4)) do
    if z:IsA("BasePart") then
        local p = z.Position
        add(pathOf(z) .. " @ " .. math.floor(p.X) .. "," .. math.floor(p.Y) .. "," .. math.floor(p.Z))
    end
end
for _, z in ipairs(findAllNamed(WS, "SellBox", 3)) do
    add("SellBox: " .. pathOf(z) .. " [" .. z.ClassName .. "]")
end
for _, z in ipairs(findAllNamed(WS, "SellLever", 3)) do
    add("SellLever: " .. pathOf(z) .. " [" .. z.ClassName .. "]")
end
 
-- ========== 6. ПОЛИЦИЯ ==========
add("")
add("=== POLICE ===")
local pf = WS:FindFirstChild("Police")
if pf then
    for _, ch in ipairs(safeChildren(pf)) do
        add("Police/" .. ch.Name .. " [" .. ch.ClassName .. "]")
    end
else
    add("(папки Police нет)")
end
for _, sn in ipairs(findAllNamed(WS, "Sniper", 4)) do
    if sn:IsA("Model") then add("Sniper: " .. pathOf(sn)) end
end
local town = WS:FindFirstChild("Town")
local station = town and town:FindFirstChild("PoliceStation")
if station then add("PoliceStation: " .. pathOf(station)) end
 
-- ========== 7. REMOTES ==========
add("")
add("=== REMOTES ===")
local remotes = RS:FindFirstChild("Remotes")
if remotes then
    local ev, fn = 0, 0
    for _, r in ipairs(safeChildren(remotes)) do
        if r:IsA("RemoteEvent") then ev = ev + 1 elseif r:IsA("RemoteFunction") then fn = fn + 1 end
        add(r.Name .. " [" .. r.ClassName .. "]")
    end
    add("итого: RemoteEvent=" .. ev .. " RemoteFunction=" .. fn)
else
    add("(папки Remotes нет)")
end
 
-- ========== 8. SHARED ==========
add("")
add("=== SHARED MODULES ===")
local shared = RS:FindFirstChild("Shared")
if shared then
    for _, m in ipairs(safeChildren(shared)) do
        add(m.Name .. " [" .. m.ClassName .. "]")
    end
else
    add("(папки Shared нет)")
end
 
-- ========== 9. ЗНАЧЕНИЯ ==========
add("")
add("=== VALUES (деньги/долг/квота/стамина/вес) ===")
local VALUE_KEYS = {
    "money", "cash", "debt", "quota", "stamina", "health", "weight",
    "cargo", "value", "wanted", "balance", "wallet", "earned", "profit",
    "level", "xp", "exp", "score", "stat", "hunger", "thirst", "fuel",
}
local valueCount = 0
local function dumpValues(root, maxDepth, label)
    for _, inst in ipairs(walk(root, maxDepth, nil)) do
        if inst:IsA("ValueBase") then
            local nm = inst.Name:lower()
            local match = false
            for _, kw in ipairs(VALUE_KEYS) do
                if nm:find(kw, 1, true) then match = true break end
            end
            if match then
                valueCount = valueCount + 1
                add(label .. " " .. pathOf(inst) .. " = " .. valueOf(inst))
            end
        end
    end
end
dumpValues(player, 5, "[player]")
dumpValues(RS, 5, "[RS]")
dumpValues(WS, 4, "[WS]")
local pg = player:FindFirstChild("PlayerGui")
if pg then dumpValues(pg, 5, "[gui]") end
if valueCount == 0 then add("(значения не найдены — возможно, они на сервере)") end
 
-- ========== 10. PLAYERGUI ==========
add("")
add("=== PLAYERGUI ===")
if pg then
    local screenGuiCount = 0
    for _, gui in ipairs(safeChildren(pg)) do
        if gui:IsA("ScreenGui") and gui.Name ~= "CrimSimUltimate" and gui.Name ~= "DiagGui" then
            screenGuiCount = screenGuiCount + 1
            add("GUI " .. gui.Name .. " (Enabled=" .. tostring(gui.Enabled) .. ")")
            local shown = 0
            for _, ch in ipairs(walk(gui, 2, nil)) do
                if shown < 40 then
                    shown = shown + 1
                    local extra = ""
                    if ch:IsA("TextLabel") or ch:IsA("TextButton") then
                        local okT, txt = pcall(function() return ch.Text end)
                        if okT and txt and txt ~= "" then extra = " text=\"" .. tostring(txt) .. "\"" end
                    elseif ch:IsA("ValueBase") then
                        extra = " = " .. valueOf(ch)
                    end
                    add("  " .. ch.Name .. " [" .. ch.ClassName .. "]" .. extra)
                end
            end
            if shown >= 40 then add("  ... (обрезано)") end
        end
    end
    add("ScreenGui всего: " .. screenGuiCount)
else
    add("(PlayerGui недоступен)")
end
 
-- ========== 11. CHARACTER ==========
add("")
add("=== CHARACTER ===")
local char = player.Character
if char then
    for _, ch in ipairs(safeChildren(char)) do
        local extra = ""
        if ch:IsA("ValueBase") then extra = " = " .. valueOf(ch) end
        if ch:IsA("BasePart") or ch:IsA("ValueBase") or ch:IsA("Humanoid") then
            add(ch.Name .. " [" .. ch.ClassName .. "]" .. extra)
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        add("Humanoid: Health=" .. tostring(math.floor(hum.Health)) .. "/" ..
            tostring(math.floor(hum.MaxHealth)) .. " WalkSpeed=" .. tostring(hum.WalkSpeed) ..
            " JumpPower=" .. tostring(hum.JumpPower))
        for _, ch in ipairs(safeChildren(hum)) do
            if ch:IsA("ValueBase") then add("  Humanoid/" .. ch.Name .. " = " .. valueOf(ch)) end
        end
    end
else
    add("(персонажа нет)")
end
 
-- ========== 12. KEYWORD SCAN ==========
add("")
add("=== KEYWORD SCAN ===")
local SCAN_KEYS = {
    "loot", "crate", "box", "stash", "police", "cop", "dog", "guard",
    "sell", "shop", "safe", "quota", "debt", "truck", "cargo", "base",
}
local found = 0
for _, inst in ipairs(walk(WS, 4, nil)) do
    if found >= 60 then break end
    local nm = inst.Name:lower()
    local hit = false
    for _, kw in ipairs(SCAN_KEYS) do
        if nm:find(kw, 1, true) then hit = true break end
    end
    if hit then
        found = found + 1
        local pos = ""
        if inst:IsA("BasePart") then
            local p = inst.Position
            pos = " @ " .. math.floor(p.X) .. "," .. math.floor(p.Y) .. "," .. math.floor(p.Z)
        end
        add(pathOf(inst) .. " [" .. inst.ClassName .. "]" .. pos)
    end
end
if found >= 60 then add("... (обрезано на 60)") end
if found == 0 then add("(совпадений нет)") end
 
-- ========== ИТОГ ==========
add("")
add("=== SUMMARY ===")
add("trucks=" .. truckCount .. " lootParts=" .. #lootParts ..
    " lootFolders=" .. #lootFolders .. " values=" .. valueCount .. " keywordHits=" .. found)
 
local dump = table.concat(LINES, "\n")
local bytes = #dump
 
-- буфер обмена
local copied = false
local okClip = pcall(function()
    -- selene: allow(undefined_variable)
    setclipboard(dump)
    copied = true
end)
 
-- файл
local saved = nil
local okFile, fileName = pcall(function()
    -- selene: allow(undefined_variable)
    writefile("game_dump.txt", dump)
    return "game_dump.txt"
end)
if okFile then saved = fileName end
 
-- консоль
print("=== GAME DUMP START (" .. bytes .. " bytes) ===")
print(dump)
print("=== GAME DUMP END ===")
print("[DUMP] скопировано в буфер: " .. tostring(copied) .. " | файл: " .. tostring(saved))
if copied then
    print("[DUMP] Нажми Ctrl+V в чате MultiTool и пришли весь текст.")
end
