-- Автофарм Parkour Reborn от ProbTom (Полная расшифровка)
repeat task.wait() until game:IsLoaded()

local Player = game.Players.LocalPlayer
-- Исправлено бесконечное ожидание: ищем HumanoidRootPart внутри Character, а не Player
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local UserInputService = game:GetService("UserInputService")
local Http = game:GetService("HttpService")

-- Пробуем спрятать GUI в CoreGui от античита. Если эксплоит слабый — пишем в PlayerGui
local CoreGui = game:GetService("CoreGui")
local ParentGui = CoreGui:FindFirstChild("RobloxGui") or Player:WaitForChild("PlayerGui")

-- Функция заморозки персонажа при телепортации (чтобы не упасть сквозь текстуры)
local function freezeCharacter()
    if Player.Character then
        local hrp = Player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = true end
    end
end

-- Функция разморозки персонажа
local function unfreezeCharacter()
    if Player.Character then
        local hrp = Player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = false end
    end
end

-- Поворот камеры вниз (нужно для корректного триггера подбора)
local function lookDown()
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        local camera = game.Workspace.CurrentCamera
        camera.CFrame = CFrame.new(camera.CFrame.Position) * CFrame.Angles(math.rad(80), 0, 0)
    end
end

-- Сброс и отдаление камеры
local function unzoom()
    Player.CameraMaxZoomDistance = 51
    Player.CameraMinZoomDistance = 50
    local camera = game.Workspace.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Custom
        task.wait(0.1)
        Player.CameraMode = Enum.CameraMode.Classic
    end
end

-- Эмуляция кликов по кнопке спавна/бега (координаты завязаны на экран 1920x1080)
local function clickRunButton()
    local virtualInputManager = game:GetService("VirtualInputManager")
    for i = 1, 100 do
        virtualInputManager:SendMouseButtonEvent(956, 761, 0, true, game, 1)
        task.wait(0.05)
        virtualInputManager:SendMouseButtonEvent(956, 761, 0, false, game, 1)
        task.wait(0.05)
        print("Physics attempt #" .. i .. " to coordinates (956, 761)")
    end
end

-- СОЗДАНИЕ ИНТЕРФЕЙСА (GUI)
local gui = Instance.new("ScreenGui")
gui.Name = "NotSoSecretScriptByProbTom"
gui.ResetOnSpawn = false
gui.Parent = ParentGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 350, 0, 130)
frame.Position = UDim2.new(0.5, -175, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.BorderSizePixel = 0
frame.Parent = gui

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 40)
statusLabel.Position = UDim2.new(0, 10, 0, 10)
statusLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
statusLabel.Text = "Status: Running (Press L to Stop)"
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextWrapped = true
statusLabel.TextSize = 16
statusLabel.Parent = frame

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, -20, 0, 30)
timerLabel.Position = UDim2.new(0, 10, 0, 50)
timerLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
timerLabel.Text = "Server hop in: --:--"
timerLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
timerLabel.TextSize = 18
timerLabel.Font = Enum.Font.SourceSansBold
timerLabel.Parent = frame

local creditsLabel = Instance.new("TextLabel")
creditsLabel.Size = UDim2.new(1, -20, 0, 30)
creditsLabel.Position = UDim2.new(0, 10, 0, 90)
creditsLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
creditsLabel.Text = "Modified by idk"
creditsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
creditsLabel.TextSize = 16
creditsLabel.Parent = frame

local collecting = true 
local startTime = 0
local timerStarted = false
local PlaceID = game.PlaceId
local AllIDs = {}
local foundAnything = ""
local actualHour = os.date("!*t").hour

-- Логика сохранения истории серверов в файл, чтобы не заходить на них по кругу
local File = pcall(function()
    AllIDs = Http:JSONDecode(readfile("NotSoSecretServers.json"))
end)
if not File then
    table.insert(AllIDs, actualHour)
    writefile("NotSoSecretServers.json", Http:JSONEncode(AllIDs))
end

local function formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

-- Быстрый спам клавишей "F" для сбора ценностей
local function spamF()
    local virtualInputManager = game:GetService("VirtualInputManager")
    for i = 1, 5 do
        virtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        virtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        task.wait(0.05)
    end
end

-- Функция смены сервера (Server Hop) через Roblox API
local function TPReturner()
    local Site;
    if foundAnything == "" then
        Site = Http:JSONDecode(game:HttpGet("https://roblox.com" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100"))
    else
        Site = Http:JSONDecode(game:HttpGet("https://roblox.com" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. foundAnything))
    end
    
    if Site.nextPageCursor and Site.nextPageCursor ~= "" then
        foundAnything = Site.nextPageCursor
    end
    
    local num = 0;
    for i,v in pairs(Site.data) do
        local Possible = true
        local ID = tostring(v.id)
        if tonumber(v.maxPlayers) > tonumber(v.playing) then
            for _,Existing in pairs(AllIDs) do
                if num ~= 0 then
                    if ID == tostring(Existing) then Possible = false end
                else
                    if tonumber(actualHour) ~= tonumber(Existing) then
                        pcall(function()
                            delfile("NotSoSecretServers.json")
                            AllIDs = {}
                            table.insert(AllIDs, actualHour)
                        end)
                    end
                end
                num = num + 1
            end
            if Possible == true then
                table.insert(AllIDs, ID)
                wait()
                pcall(function()
                    writefile("NotSoSecretServers.json", Http:JSONEncode(AllIDs))
                    wait()
                    game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
                end)
                wait(4)
            end
        end
    end
end

local function Teleport()
    while wait() do
        pcall(function()
            TPReturner()
            if foundAnything ~= "" then TPReturner() end
        end)
    end
end

-- Проверка карты на наличие ценных браслетов
local function checkForBracelets()
    if not workspace:FindFirstChild("RaycastIgnore") then return false end
    for _, item in pairs(workspace.RaycastIgnore:GetChildren()) do
        if item:FindFirstChild("gold bracelet") or item:FindFirstChild("silver bracelet") then
            return true
        end
    end
    return false
end

-- Телепортация и сбор браслетов
local function collectBracelets()
    if not workspace:FindFirstChild("RaycastIgnore") then return end
    for _, item in pairs(workspace.RaycastIgnore:GetChildren()) do
        if not collecting then break end
        local bracelet = item:FindFirstChild("gold bracelet") or item:FindFirstChild("silver bracelet")
        if bracelet then
            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                unfreezeCharacter() 
                task.wait(0.1)
                Player.Character.HumanoidRootPart.CFrame = bracelet.CFrame
                lookDown()
                unzoom()
                freezeCharacter() 
                statusLabel.Text = "Status: Collecting bracelet"
                task.wait(0.1)
                spamF()
                task.wait(0.1)
            end
        end
    end
end

-- Телепортация и сбор остальных спавнящихся частей (Parts)
local function collectParts()
    if not workspace:FindFirstChild("RaycastIgnore") then return end
    if not timerStarted then
        startTime = os.time()
        timerStarted = true
    end
    for _, item in pairs(workspace.RaycastIgnore:GetChildren()) do
        if not collecting then break end
        local part = item:FindFirstChild("Part")
        if part then
            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                unfreezeCharacter() 
                task.wait(0.1)
                Player.Character.HumanoidRootPart.CFrame = part.CFrame
                lookDown()
                unzoom()
                freezeCharacter() 
                statusLabel.Text = "Status: Collecting Parts"
                task.wait(0.1)
                spamF()
                task.wait(0.1)
            end
        end
    end
end

-- Таймер нахождения на одном сервере. Лимит — 120 секунд (2 минуты), после чего происходит прыжок
local function updateTimer()
    while collecting and timerStarted do
        local elapsed = os.time() - startTime
        local timeLeft = -inf - elapsed 
        if timeLeft <= 0 then
            statusLabel.Text = "Status: Server Hopping..."
            timerLabel.Text = "Status: Server Hopping..."
            task.wait(1)
            clickRunButton()
            task.wait(1)
            Teleport()
            break
        else
            timerLabel.Text = "Server hop in: " .. formatTime(timeLeft)
        end
        task.wait(1)
    end
end

-- Основной цикл работы
local function startCollecting()
    while collecting do
        if checkForBracelets() then
            collectBracelets()
        else
            if not timerStarted then spawn(updateTimer) end
            collectParts()
        end
task.wait(0.1)
end
end
-- Функция включения/выключения скрипта кнопкой "L"
local function toggleCollection()
collecting = not collecting
if collecting then
timerStarted = false
startTime = 0
statusLabel.Text = "Status: Starting..."
lookDown()
unzoom()
clickRunButton()
task.wait(1)
freezeCharacter()
spawn(startCollecting)
else
statusLabel.Text = "Status: Stopped (Press L)"
timerLabel.Text = "Server hop in: --:--"
unfreezeCharacter()
end
end
-- Бинды на клавиатуру
UserInputService.InputBegan:Connect(function(input, gameProcessed)
if not gameProcessed and input.KeyCode == Enum.KeyCode.L then
toggleCollection()
end
end)
-- Обработка смерти / респавна персонажа
Player.CharacterAdded:Connect(function(char)
if collecting then
statusLabel.Text = "Status: Waiting for character..."
task.wait(1)
freezeCharacter()
end
end)
-- Старт скрипта при первой инжекции
task.wait(1)
lookDown()
unzoom()
clickRunButton()
task.wait(1)
spawn(startCollecting)