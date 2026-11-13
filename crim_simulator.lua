
--[[
    SNIFFER: показывает, какие Remote-вызовы делает игра.
    Запуск в игре через Delta:
      loadstring(game:HttpGet("https://raw.githubusercontent.com/timazashaev-del/loader/mai…"))()
 
    Что делать после запуска:
      1. Подойди к любому луту и подбери 1 предмет.
      2. Продай 1 предмет в зоне продажи.
      3. Открой/закрой дверь, сядь в машину (по желанию).
    Скрипт печатает каждый вызов: Имя:FireServer(аргументы).
    Потом Ctrl+V в чат MultiTool — я увижу точные аргументы.
]]
 
-- selene: allow(undefined_variable)
local setclipboardFn = setclipboard
-- selene: allow(undefined_variable)
local getrawmetatableFn = getrawmetatable
-- selene: allow(undefined_variable)
local setreadonlyFn = setreadonly
-- selene: allow(undefined_variable)
local getnamecallmethodFn = getnamecallmethod
 
local OUT = {}
local function add(s)
    OUT[#OUT + 1] = s
    print(s)
end
 
add("=== SNIFFER START ===")
add("Действуй: подбери лут, продай, открой дверь. Потом Ctrl+V.")
 
local function describe(a)
    local t = typeof(a)
    if t == "Instance" then
        local ok, cls = pcall(function() return a.ClassName end)
        local ok2, nm = pcall(function() return a:GetFullName() end)
        return (ok2 and nm or "?") .. " [" .. (ok and cls or "?") .. "]"
    elseif t == "table" then
        local parts = {}
        for k, v in pairs(a) do
            if #parts >= 6 then break end
            parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return tostring(a)
    end
end
 
local hooked = false
if getrawmetatableFn and setreadonlyFn and getnamecallmethodFn then
    local ok = pcall(function()
        local mt = getrawmetatableFn(game)
        local old = mt.__namecall
        setreadonlyFn(mt, false)
        mt.__namecall = function(self, ...)
            local method = getnamecallmethodFn()
            if method == "FireServer" or method == "InvokeServer" then
                local okName, nm = pcall(function() return self.Name end)
                if okName then
                    local args = { ... }
                    local parts = {}
                    for i = 1, #args do
                        parts[#parts + 1] = describe(args[i])
                    end
                    add(tostring(nm) .. ":" .. method .. "(" .. table.concat(parts, ", ") .. ")")
                end
            end
            return old(self, ...)
        end
        setreadonlyFn(mt, true)
        hooked = true
    end)
    if not hooked then
        add("[WARN] не удалось поставить хук метаметода")
    end
else
    add("[WARN] экзекьютор не даёт getrawmetatable/setreadonly")
end
 
-- копирование по нажатию правого Shift
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        local dump = table.concat(OUT, "\n")
        pcall(function() setclipboardFn(dump) end)
        print("[SNIFFER] скопировано в буфер (" .. #OUT .. " строк). Вставь в чат.")
    end
end)
 
add("[SNIFFER] хук активен: " .. tostring(hooked) .. ". Правый Shift — копировать лог.")
