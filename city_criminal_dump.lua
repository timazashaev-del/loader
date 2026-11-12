--[[
    CITY CRIMINAL SIMULATOR — DISCOVERY v3 (компактный)
    Печатает только то, что нужно для ESP/телепортов/трекеров.
    Ищет по ключевым словам и показывает где лежат нужные объекты.
    Только чтение, ничего не меняет.
]]
 
local Players = game:GetService("Players")
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
 
local OUT = {}
local function log(s) OUT[#OUT+1] = s end
 
local KEYWORDS = { "truck", "car", "vehicle", "police", "cop", "serg", "dog",
    "loot", "crate", "box", "stash", "sell", "debt", "quota", "money", "cash",
    "cashvalue", "shop", "base", "safe", "job", "objective", "wanted", "fuel" }
 
-- 1) Топ-уровневые модели Workspace (имена) — здесь живут грузовик/полиция/лут
log("=== WORKSPACE top-level ===")
for _, obj in ipairs(WS:GetChildren()) do
    log(obj.Name .. " [" .. obj.ClassName .. "]")
end
 
-- 2) Раскладка твоего персонажа (папки/значения)
log("\n=== CHARACTER stats ===")
local ch = player.Character
if ch then
    for _, obj in ipairs(ch:GetDescendants()) do
        if obj:IsA("ValueBase") then
            log(obj.Name .. " = " .. tostring(obj.Value))
        end
    end
else
    log("(персонажа нет в этот момент)")
end
 
-- 3) Поиск ключевых объектов по всей игре (глубина 5)
log("\n=== KEYWORD SCAN (Workspace) ===")
local function scan(root, depth)
    if depth > 5 then return end
    for _, obj in ipairs(root:GetChildren()) do
        for _, kw in ipairs(KEYWORDS) do
            if obj.Name:lower():find(kw, 1, true) then
                local pos = ""
                if obj:IsA("BasePart") then
                    pcall(function() pos = " @ " .. tostring(obj.Position) end)
                end
                log(kw .. " -> " .. obj.Parent.Name .. "/" .. obj.Name .. " [" .. obj.ClassName .. "]" .. pos)
                break
            end
        end
        if (obj:IsA("Model") or obj:IsA("Folder")) then
            scan(obj, depth + 1)
        end
    end
end
pcall(function() scan(WS, 0) end)
 
-- 4) Поиск значений по деньгам/долгу/квоте по всей игре
log("\n=== VALUE SCAN (деньги/долг/квота) ===")
local VALUE_KW = { "money", "debt", "quota", "cash", "balance", "wallet", "worth" }
local function scanV(root, depth)
    if depth > 6 then return end
    for _, obj in ipairs(root:GetChildren()) do
        for _, kw in ipairs(VALUE_KW) do
            if obj.Name:lower():find(kw, 1, true) then
                local v = ""
                pcall(function() v = " = " .. tostring(obj.Value) end)
                log(obj.Parent.Name .. "/" .. obj.Name .. " [" .. obj.ClassName .. "]" .. v)
                break
            end
        end
        scanV(obj, depth + 1)
    end
end
pcall(function() scanV(WS, 0) end)
pcall(function() scanV(game:GetService("Players"), 0) end)
 
local dump = table.concat(OUT, "\n")
 
if type(setclipboard) == "function" then
    pcall(function() setclipboard(dump) end)
end
print("=== V3 DUMP ===")
print(dump)
print("=== END ===")
