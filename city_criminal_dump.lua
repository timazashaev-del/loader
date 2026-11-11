
--[[
    CITY CRIMINAL SIMULATOR — DISCOVERY v2
    Запуск в экзекьюторе Delta. Только читает игру, ничего не меняет.
    Результат:
      1) копируется в буфер обмена (вставь прямо в чат MultiTool);
      2) сохраняется в файлы (если writefile доступен) — печатает пути.
]]
 
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local player = Players.LocalPlayer
 
local OUT = {}
local function log(s) OUT[#OUT+1] = s end
 
log("=== PLACE ===")
log("PlaceId: " .. tostring(game.PlaceId))
log("GameId:  " .. tostring(game.GameId))
 
local function walk(root, depth, maxDepth, prefix)
    if depth > maxDepth then return end
    for _, obj in ipairs(root:GetChildren()) do
        local cls = obj.ClassName
        local mark = ""
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then mark = "  <== REMOTE" end
        if obj:IsA("NumberValue") or obj:IsA("StringValue") or obj:IsA("BoolValue") or obj:IsA("IntValue") then
            local safe
            pcall(function() safe = tostring(obj.Value) end)
            mark = " = " .. (safe or "?") .. "  <== VALUE"
        end
        log(prefix .. obj.Name .. " [" .. cls .. "]" .. mark)
        local childable = obj:IsA("Folder") or obj:IsA("Model") or obj:IsA("Configuration") or obj:IsA("Instance")
        if childable and obj:GetChildren() then
            walk(obj, depth + 1, maxDepth, prefix .. "  ")
        end
    end
end
 
log("\n=== ReplicatedStorage (глубина 4) ===")
pcall(function() walk(RS, 0, 4, "") end)
 
log("\n=== Workspace (глубина 2) ===")
pcall(function() walk(WS, 0, 2, "") end)
 
log("\n=== PlayerGui (глубина 2) ===")
local pg = player:FindFirstChild("PlayerGui")
if pg then pcall(function() walk(pg, 0, 2, "") end) else log("PlayerGui нет") end
 
log("\n=== Character ===")
local ch = player.Character or player.CharacterAdded:Wait(5)
if ch then
    for _, obj in ipairs(ch:GetDescendants()) do
        if obj:IsA("ValueBase") or obj:IsA("BasePart") then
            log(obj.Name .. " [" .. obj.ClassName .. "]")
        end
    end
else
    log("Character нет")
end
 
local dump = table.concat(OUT, "\n")
 
-- 1) В буфер обмена
local copied = false
if type(setclipboard) == "function" then
    pcall(function() setclipboard(dump) end)
    copied = true
    print("\n[CLIPBOARD] Дамп скопирован. Нажми Ctrl+V в чате MultiTool и пришли.")
end
 
-- 2) В файлы (перебираем кандидатов, печатаем куда реально записал)
if type(writefile) == "function" then
    local names = {
        "city_criminal_dump.txt",
        "lua/city_criminal_dump.txt",
        "workspace/city_criminal_dump.txt",
    }
    local wrote = false
    for _, n in ipairs(names) do
        local ok, err = pcall(function() writefile(n, dump) end)
        if ok then
            print("[SAVED] файл: " .. n .. "  (папка экзекьютора)")
            wrote = true
            break
        end
    end
    if not wrote then print("[WARN] writefile не смог сохранить файл") end
end
 
-- 3) Полный вывод в консоль (на случай, если clipboard/file не сработали)
if not copied and (type(writefile) ~= "function") then
    print("\n=== ПОЛНЫЙ ДАМП (скопируй отсюда) ===")
    print(dump)
    print("\n=== КОНЕЦ ДАМПА ===")
end
 
if copied then
    print("\nВставь вывод (из буфера) в чат. Если clipboard не сработал — включи консоль и сообщи.")
end