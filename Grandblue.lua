local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local function SendWebhook(msg)
    if WEBHOOK_URL == "" then return end
    local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if req then
        pcall(function()
            req({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({content = msg})
            })
        end)
    end
end

local DiscordLink = "https://discord.gg/vfmjNqSwWM"

local function sendNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = duration or 3})
    end)
end

local ConfigFolder = "AutoFarmConfig"
local ConfigFile = ConfigFolder .. "/Settings.json"

local DefaultSettings = {
    AntiAdmin = true
}

local function LoadConfig()
    if isfolder and not isfolder(ConfigFolder) then
        pcall(function() makefolder(ConfigFolder) end)
    end
    
    if isfile and isfile(ConfigFile) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(ConfigFile))
        end)
        if success and result then
            return result
        end
    end
    return DefaultSettings
end

local function SaveConfig()
    if writefile then
        local dataToSave = {
            AntiAdmin = getgenv().AntiAdminEnabled
        }
        pcall(function()
            if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end
            writefile(ConfigFile, HttpService:JSONEncode(dataToSave))
        end)
    end
end

local CurrentConfig = LoadConfig()

local LAG_OFFSET = 0.04 
local FALLBACK_TARGET = 0.55 
local MINING_DISTANCE = 12 
local SAFE_ZONE_POS = Vector3.new(15000, 50000, 15000)
local FISH_ZONE_CFRAME = CFrame.new(-344, -1, -971)

if getgenv().AutoFarmingRunning then getgenv().AutoFarmingRunning = false task.wait(0.2) end
if getgenv().NoclipConnection then getgenv().NoclipConnection:Disconnect() getgenv().NoclipConnection = nil end
if getgenv().AntiAdminConnection then getgenv().AntiAdminConnection:Disconnect() getgenv().AntiAdminConnection = nil end
if getgenv().HotkeyConnection then getgenv().HotkeyConnection:Disconnect() getgenv().HotkeyConnection = nil end
if getgenv().QTEHooked then getgenv().QTEHooked = nil end

getgenv().AutoFarmingRunning = true
getgenv().AutoMineEnabled = false
getgenv().AutoFishEnabled = false
getgenv().AntiAdminEnabled = CurrentConfig.AntiAdmin -- Carga el valor guardado
getgenv().TargetZone = "Todos"

local UIToggles = {}

SendWebhook("✅ **Script Ejecutado** | Jugador: " .. LocalPlayer.Name .. " | Anti-Admin: " .. (getgenv().AntiAdminEnabled and "ON" or "OFF"))

local function CreateSkyBase()
    local baseName = "CustomAutoFarmBase_Sky"
    if workspace:FindFirstChild(baseName) then
        workspace[baseName]:Destroy()
    end
    local base = Instance.new("Part")
    base.Name = baseName
    base.Size = Vector3.new(150, 5, 150)
    base.Position = SAFE_ZONE_POS - Vector3.new(0, 5, 0)
    base.Anchored = true
    base.CanCollide = true
    base.Transparency = 0.7 
    base.Color = Color3.fromRGB(0, 255, 100)
    base.Material = Enum.Material.Neon
    base.Parent = workspace
end
CreateSkyBase()
local uiName = "Custom_Base_UI"
if CoreGui:FindFirstChild(uiName) then
    CoreGui[uiName]:Destroy()
    task.wait(0.2)
end
local GROUP_ID = 34564085
local isHopping = false

local function ServerHop()
    if isHopping then return end
    isHopping = true
    
    task.spawn(function()
        pcall(function()
            local events = ReplicatedStorage:FindFirstChild("Events")
            if events and events:FindFirstChild("GetSettings") then
                events.GetSettings:InvokeServer()
            end
        end)
        task.wait(0.5)
        
        local clickedQuickJoin = false
        pcall(function()
            local serversGui = LocalPlayer.PlayerGui:FindFirstChild("Servers")
            if serversGui and serversGui:FindFirstChild("Frame") then
                local quickJoinBtn = serversGui.Frame:FindFirstChild("QuickJoin")
                if quickJoinBtn then
                    if getconnections then
                        for _, conn in pairs(getconnections(quickJoinBtn.MouseButton1Click)) do conn:Fire() end
                        for _, conn in pairs(getconnections(quickJoinBtn.Activated)) do conn:Fire() end
                    end
                    if firesignal then
                        firesignal(quickJoinBtn.MouseButton1Click)
                        firesignal(quickJoinBtn.Activated)
                    end
                    clickedQuickJoin = true
                end
            end
        end)
        
        if clickedQuickJoin then task.wait(5) end
        
        local serversApi = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        
        if req then
            local success, response = pcall(function() return req({Url = serversApi, Method = "GET"}) end)
            if success and response.StatusCode == 200 then
                local data = HttpService:JSONDecode(response.Body)
                if data and data.data then
                    for _, server in ipairs(data.data) do
                        if server.playing < server.maxPlayers and server.id ~= game.JobId then
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                            task.wait(5)
                            return
                        end
                    end
                end
            end
        end
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local function CheckPlayerForAdmin(player)
    if player == LocalPlayer then return end
    task.spawn(function()
        local success, rank = pcall(function() return player:GetRankInGroup(GROUP_ID) end)
        if success and rank > 1 then
            if getgenv().AntiAdminEnabled then
                local msg = "**Admin Detected**: `" .. player.Name .. "`\nIniciando Server Hop para proteger la cuenta."
                sendNotification("Anti-Admin", "Admin Detected: " .. player.Name .. "\nIniciando Quick Join...", 5)
                SendWebhook(msg)
                ServerHop()
            end
        end
    end)
end

local MouseController = {
    IsDown = false,
    Set = function(self, state, force)
        if self.IsDown ~= state or force then
            local cx = Camera.ViewportSize.X / 2
            local cy = Camera.ViewportSize.Y / 2
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, state, game, 0)
            self.IsDown = state
        end
    end
}

local LastTransparentOre = nil
local function HandleOreTransparency(currentOre)
    if LastTransparentOre ~= currentOre then
        if LastTransparentOre and LastTransparentOre.Parent then
            for _, part in ipairs(LastTransparentOre:GetDescendants()) do
                if part:IsA("BasePart") then part.LocalTransparencyModifier = 0 end
            end
            if LastTransparentOre:IsA("BasePart") then LastTransparentOre.LocalTransparencyModifier = 0 end
        end
        LastTransparentOre = currentOre
        if currentOre then
            for _, part in ipairs(currentOre:GetDescendants()) do
                if part:IsA("BasePart") then part.LocalTransparencyModifier = 0.85 end
            end
            if currentOre:IsA("BasePart") then currentOre.LocalTransparencyModifier = 0.85 end
        end
    end
end
local function getQTEMiningFrames()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local miningGui = char.HumanoidRootPart:FindFirstChild("Mining")
        if miningGui and miningGui:IsA("BillboardGui") then
            local uiFrame = miningGui:FindFirstChild("Frame")
            if uiFrame and uiFrame.Visible then
                local amount = uiFrame:FindFirstChild("Amount")
                if amount and miningGui.Enabled then return amount, uiFrame end
            end
        end
    end
    local qte = LocalPlayer.PlayerGui:FindFirstChild("QuickTimeEvents")
    if qte then
        local events = qte:FindFirstChild("QTEClient") and qte.QTEClient:FindFirstChild("Events")
        if events then
            local miningEvent = events:FindFirstChild("Mining")
            if miningEvent then
                local miningInner = miningEvent:FindFirstChild("Mining")
                if miningInner and miningInner.Enabled then
                    local uiFrame = miningInner:FindFirstChild("Frame")
                    if uiFrame and uiFrame.Visible and uiFrame:FindFirstChild("Amount") then return uiFrame.Amount, uiFrame end
                end
            end
        end
    end
    return nil, nil
end

local function getTargetOresList()
    local safeOres = {}
    local islands = workspace:FindFirstChild("Islands")
    local selectedZone = getgenv().TargetZone or "Todos"
    if not islands then return safeOres end
    
    local function scanIslandForOres(islandName)
        local islandFolder = islands:FindFirstChild(islandName)
        if islandFolder and islandFolder:FindFirstChild("Island") then
            for _, obj in pairs(islandFolder.Island:GetChildren()) do
                if string.match(obj.Name, "^OreBlock") and obj:GetAttribute("Mined") ~= true then table.insert(safeOres, obj) end
            end
        end
    end

    if selectedZone == "Todos" or selectedZone == "Anchor Town" then scanIslandForOres("Anchor Town") end
    if selectedZone == "Todos" or selectedZone == "Maple Village" then scanIslandForOres("Maple Village") end
    return safeOres
end

local function findNearestOre()
    local nearestOre, shortestDistance = nil, math.huge
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local myPos = char.HumanoidRootPart.Position
        for _, obj in pairs(getTargetOresList()) do
            local orePos = nil
            if obj:IsA("Model") and obj.PrimaryPart then orePos = obj.PrimaryPart.Position
            elseif obj:IsA("BasePart") then orePos = obj.Position
            else
                local part = obj:FindFirstChildWhichIsA("BasePart")
                if part then orePos = part.Position end
            end
            if orePos then
                local distance = (orePos - myPos).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    nearestOre = obj
                end
            end
        end
    end
    return nearestOre, shortestDistance
end

local function getFishingCastFrames()
    local qte = LocalPlayer.PlayerGui:FindFirstChild("QuickTimeEvents")
    if qte then
        local qteClient = qte:FindFirstChild("QTEClient")
        if qteClient then
            local events = qteClient:FindFirstChild("Events")
            if events then
                local timedRelease = events:FindFirstChild("Timed Release")
                if timedRelease then
                    local fishingBar = timedRelease:FindFirstChild("Fishing Bar")
                    if fishingBar then
                        local success, isEnabled = pcall(function() return fishingBar.Enabled end)
                        if success and isEnabled then
                            local uiFrame = fishingBar:FindFirstChild("Frame")
                            if uiFrame and uiFrame.Visible then 
                                local amount = uiFrame:FindFirstChild("Amount")
                                if amount then return amount, uiFrame end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

local function CalculateRelease(amountBar, parentFrame)
    if parentFrame.AbsoluteSize.X > 5 and parentFrame.AbsoluteSize.Y > 5 then
        local isHorizontal = parentFrame.AbsoluteSize.X > parentFrame.AbsoluteSize.Y
        local targetZone = nil
        for _, child in ipairs(parentFrame:GetChildren()) do
            if (child:IsA("Frame") or child:IsA("ImageLabel")) and child.Name ~= "Amount" and child.Name ~= "Background" and child.Name ~= "UIStroke" and child.Name ~= "UICorner" then
                if child:IsA("Frame") and child.BackgroundColor3.G > 0.4 and child.BackgroundColor3.R < 0.6 then
                    targetZone = child
                    break
                elseif not targetZone then
                    targetZone = child
                end
            end
        end
        local requiredFill = FALLBACK_TARGET 
        if targetZone then
            if isHorizontal then
                local parentWidth = parentFrame.AbsoluteSize.X
                local targetHitX = targetZone.AbsolutePosition.X + (targetZone.AbsoluteSize.X * 0.2) 
                local parentLeft = parentFrame.AbsolutePosition.X
                requiredFill = (targetHitX - parentLeft) / parentWidth
            else
                local parentHeight = parentFrame.AbsoluteSize.Y
                local targetHitY = targetZone.AbsolutePosition.Y + (targetZone.AbsoluteSize.Y * 0.8) 
                local parentBottom = parentFrame.AbsolutePosition.Y + parentFrame.AbsoluteSize.Y
                requiredFill = (parentBottom - targetHitY) / parentHeight
            end
        end
        local currentFill = isHorizontal and (amountBar.AbsoluteSize.X / parentFrame.AbsoluteSize.X) or (amountBar.AbsoluteSize.Y / parentFrame.AbsoluteSize.Y)
        if currentFill >= (requiredFill - LAG_OFFSET) then return true end
    end
    return false
end
local function performCleanup()
    getgenv().AutoFarmingRunning = false
    getgenv().AutoMineEnabled = false
    getgenv().AutoFishEnabled = false
    getgenv().AntiAdminEnabled = false
    
    if getgenv().NoclipConnection then getgenv().NoclipConnection:Disconnect() getgenv().NoclipConnection = nil end
    if getgenv().AntiAdminConnection then getgenv().AntiAdminConnection:Disconnect() getgenv().AntiAdminConnection = nil end
    if getgenv().HotkeyConnection then getgenv().HotkeyConnection:Disconnect() getgenv().HotkeyConnection = nil end
    
    MouseController:Set(false, true)
    LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
    HandleOreTransparency(nil)
    
    if workspace:FindFirstChild("CustomAutoFarmBase_Sky") then
        workspace.CustomAutoFarmBase_Sky:Destroy()
    end
    
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local float = LocalPlayer.Character.HumanoidRootPart:FindFirstChild("AutoFarmFloat")
        if float then float:Destroy() end
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end
local function MakeDraggable(dragHandle, targetObject)
    local dragging, dragInput, dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetObject.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            targetObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = uiName
ScreenGui.AncestryChanged:Connect(function(_, parent) if not parent then performCleanup() end end)

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 310, 0, 520) 
Main.Position = UDim2.new(0.5, -155, 0.5, -200)
Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Main.Active = true

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, -30, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Title.TextColor3 = Color3.new(1,1,1)
Title.Font = Enum.Font.Code
Title.TextSize = 15
Title.Text = " Auto Farm Simple"
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Active = true

local CloseBtn = Instance.new("TextButton", Main)
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Font = Enum.Font.Code
CloseBtn.TextSize = 14
CloseBtn.Text = "X"
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local BottomDrag = Instance.new("TextLabel", Main)
BottomDrag.Size = UDim2.new(1, 0, 0, 20)
BottomDrag.Position = UDim2.new(0, 0, 1, -20)
BottomDrag.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
BottomDrag.TextColor3 = Color3.fromRGB(150, 150, 150)
BottomDrag.Font = Enum.Font.Code
BottomDrag.TextSize = 12
BottomDrag.Text = "≡ Arrastrar desde aquí ≡"
BottomDrag.Active = true

MakeDraggable(Title, Main)
MakeDraggable(BottomDrag, Main)

local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Size = UDim2.new(1, 0, 1, -50) 
Scroll.Position = UDim2.new(0, 0, 0, 30)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 4
Scroll.ClipsDescendants = true 

local Layout = Instance.new("UIListLayout", Scroll)
Layout.Padding = UDim.new(0, 5) -- Un poco más de padding
Layout.SortOrder = Enum.SortOrder.LayoutOrder 
local uiOrderIndex = 0

local mobileToggle = Instance.new("ImageButton", ScreenGui)
mobileToggle.Name = "MobileToggleButton"
mobileToggle.Size = UDim2.new(0, 60, 0, 60)
mobileToggle.Position = UDim2.new(0.35, 0, 0.1, 0)
mobileToggle.BackgroundTransparency = 0.3
mobileToggle.Image = "rbxassetid://89426383398852" 
mobileToggle.ImageColor3 = Color3.fromRGB(255, 255, 255)
mobileToggle.Draggable = true
mobileToggle.Active = true

local isMinimized = false
mobileToggle.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    Main.Visible = not isMinimized
end)

local function createToggle(name, defaultState, callback)
    local btn = Instance.new("TextButton", Scroll)
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.Code
    btn.TextSize = 13
    btn.LayoutOrder = uiOrderIndex
    uiOrderIndex = uiOrderIndex + 1
    
    local on = defaultState
    local function toggleState(forcedState)
        if forcedState ~= nil then on = forcedState else on = not on end
        btn.Text = name .. (on and " [ON]" or " [OFF]")
        btn.BackgroundColor3 = on and Color3.fromRGB(0, 140, 70) or Color3.fromRGB(50, 50, 50)
        callback(on)
    end
    
    toggleState(defaultState)
    btn.MouseButton1Click:Connect(function() toggleState() end)
    
    UIToggles[name] = toggleState
    return btn
end

local function createDropdown(name, options, defaultIndex, callback)
    local container = Instance.new("Frame", Scroll)
    container.Size = UDim2.new(1, 0, 0, 30)
    container.BackgroundTransparency = 1
    container.LayoutOrder = uiOrderIndex
    container.ClipsDescendants = true
    uiOrderIndex = uiOrderIndex + 1
    
    local mainBtn = Instance.new("TextButton", container)
    mainBtn.Size = UDim2.new(1, 0, 0, 30)
    mainBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainBtn.TextColor3 = Color3.new(1, 1, 1)
    mainBtn.Font = Enum.Font.Code
    mainBtn.TextSize = 13
    mainBtn.Text = name .. ": " .. tostring(options[defaultIndex] or options[1]) .. " ▼"
    
    local listFrame = Instance.new("Frame", container)
    listFrame.Size = UDim2.new(1, 0, 0, #options * 25)
    listFrame.Position = UDim2.new(0, 0, 0, 30)
    listFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    listFrame.BorderSizePixel = 0
    listFrame.Visible = false
    
    local listLayout = Instance.new("UIListLayout", listFrame)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    mainBtn.MouseButton1Click:Connect(function()
        listFrame.Visible = not listFrame.Visible
        container.Size = listFrame.Visible and UDim2.new(1, 0, 0, 30 + (#options * 25)) or UDim2.new(1, 0, 0, 30)
    end)
    
    for i, option in ipairs(options) do
        local optBtn = Instance.new("TextButton", listFrame)
        optBtn.Size = UDim2.new(1, 0, 0, 25)
        optBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        optBtn.TextColor3 = Color3.new(1,1,1)
        optBtn.Font = Enum.Font.Code
        optBtn.TextSize = 13
        optBtn.Text = tostring(option)
        optBtn.LayoutOrder = i
        
        optBtn.MouseButton1Click:Connect(function()
            mainBtn.Text = name .. ": " .. tostring(option) .. " ▼"
            listFrame.Visible = false
            container.Size = UDim2.new(1, 0, 0, 30)
            callback(option)
        end)
    end
    callback(options[defaultIndex] or options[1])
end

local function createButton(name, color, callback)
    local btn = Instance.new("TextButton", Scroll)
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.Text = name
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.Code
    btn.TextSize = 13
    btn.LayoutOrder = uiOrderIndex
    uiOrderIndex = uiOrderIndex + 1
    btn.MouseButton1Click:Connect(callback)
end

local function addSeparator(text)
    local sep = Instance.new("TextLabel", Scroll)
    sep.Size = UDim2.new(1, 0, 0, 20)
    sep.BackgroundTransparency = 1
    sep.TextColor3 = Color3.fromRGB(150, 150, 150)
    sep.Font = Enum.Font.Code
    sep.TextSize = 12
    sep.Text = "--- " .. text .. " ---"
    sep.LayoutOrder = uiOrderIndex
    uiOrderIndex = uiOrderIndex + 1
end

addSeparator("Seguridad")

createButton("TP Safe Zone", Color3.fromRGB(0, 100, 200), function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(SAFE_ZONE_POS)
        sendNotification("Seguridad", "Teletransportado a la base del cielo.", 2)
    end
end)

createToggle("Anti-Admin (Hop)", CurrentConfig.AntiAdmin, function(state)
    getgenv().AntiAdminEnabled = state
    SaveConfig() 
    if state then
        for _, player in ipairs(Players:GetPlayers()) do CheckPlayerForAdmin(player) end
    end
end)

addSeparator("Shops / Teleports")

createButton("Buy Pickaxe", Color3.fromRGB(150, 100, 0), function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(-428, 5, 426)
        sendNotification("Teleport", "Teleported to Buy Pickaxe", 2)
    end
end)

createButton("Buy Fishing Rod", Color3.fromRGB(0, 150, 200), function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(183, 1, -727)
        sendNotification("Teleport", "Teleported to Buy Fishing Rod", 2)
    end
end)

addSeparator("Farming")

createDropdown("Mining Zone", {"Todos", "Anchor Town", "Maple Village"}, 1, function(selectedZone)
    getgenv().TargetZone = selectedZone
end)

createToggle("Auto Mine", false, function(state)
    getgenv().AutoMineEnabled = state
    if state then
        LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
    else
        MouseController:Set(false, true)
        LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
        HandleOreTransparency(nil)
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = CFrame.new(SAFE_ZONE_POS) end
    end
end)

createToggle("Auto Fish", false, function(state)
    getgenv().AutoFishEnabled = state
    if state then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = FISH_ZONE_CFRAME end
    else
        MouseController:Set(false, true)
    end
end)

addSeparator("Community")

createButton("Floppa Hub join", Color3.fromRGB(88, 101, 242), function()
    if setclipboard then
        setclipboard(DiscordLink)
        sendNotification("Floppa Hub", "Discord link copied to clipboard!", 3)
    else
        sendNotification("Floppa Hub", "Your executor does not support clipboard copying.", 3)
    end
end)

local guideLabel = Instance.new("TextLabel", Scroll)
guideLabel.Size = UDim2.new(1, -10, 0, 0)
guideLabel.AutomaticSize = Enum.AutomaticSize.Y
guideLabel.Position = UDim2.new(0, 5, 0, 0)
guideLabel.BackgroundTransparency = 1
guideLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
guideLabel.Font = Enum.Font.Code
guideLabel.TextSize = 11
guideLabel.TextWrapped = true
guideLabel.TextXAlignment = Enum.TextXAlignment.Center
guideLabel.Text = "just buy a pixckaxe or fish rod and press auto mine or autofarm, the economy of this game is bored so you can auto mine tons of ores and sell to get money or fruits easy"
guideLabel.LayoutOrder = uiOrderIndex
uiOrderIndex = uiOrderIndex + 1

getgenv().AntiAdminConnection = Players.PlayerAdded:Connect(function(player)
    if getgenv().AntiAdminEnabled then CheckPlayerForAdmin(player) end
end)

getgenv().NoclipConnection = RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    if getgenv().AutoFarmingRunning and getgenv().AutoMineEnabled then
        local hrp = char.HumanoidRootPart
        local float = hrp:FindFirstChild("AutoFarmFloat")
        if not float then
            float = Instance.new("BodyVelocity")
            float.Name = "AutoFarmFloat"
            float.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            float.Velocity = Vector3.new(0, 0, 0)
            float.Parent = hrp
        end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    else
        local float = char.HumanoidRootPart:FindFirstChild("AutoFarmFloat")
        if float then float:Destroy() end
    end
end)
local isMineCharging = false
local currentOreTarget = nil
local targetStartTime = tick()

task.spawn(function()
    while getgenv().AutoFarmingRunning do
        task.wait(0.015) 
        if not getgenv().AutoMineEnabled then
            if isMineCharging then MouseController:Set(false) end
            isMineCharging = false
            currentOreTarget = nil
            HandleOreTransparency(nil)
            continue
        end

        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then continue end

        local nearestOre, distance = findNearestOre()
        HandleOreTransparency(nearestOre)
        
        if not nearestOre then
            if isMineCharging then 
                MouseController:Set(false)
                isMineCharging = false 
            end
            if (char.HumanoidRootPart.Position - SAFE_ZONE_POS).Magnitude > 5 then
                char.HumanoidRootPart.CFrame = CFrame.new(SAFE_ZONE_POS)
            end
            task.wait(0.5) 
            continue 
        end
        
        if nearestOre ~= currentOreTarget then
            currentOreTarget = nearestOre
            targetStartTime = tick()
            MouseController:Set(false, true)
        end

        local amountBar, parentFrame = getQTEMiningFrames()
        if amountBar and parentFrame then
            isMineCharging = true
            targetStartTime = tick()
            
            if CalculateRelease(amountBar, parentFrame) then
                MouseController:Set(false)
                task.wait(0.15) 
                isMineCharging = false
            else
                MouseController:Set(true) 
            end
            continue
        else
            if tick() - targetStartTime > 5 then
                MouseController:Set(false, true)
                isMineCharging = false
                targetStartTime = tick() + 1 
                task.wait(1)
                continue
            end
            
            isMineCharging = false
        end

        if distance > MINING_DISTANCE then
            local orePosition = nearestOre:IsA("BasePart") and nearestOre.Position or nearestOre:FindFirstChildWhichIsA("BasePart").Position
            if orePosition then
                local tpPosition = orePosition + Vector3.new(0, -6, 0) 
                char.HumanoidRootPart.CFrame = CFrame.lookAt(tpPosition, orePosition)
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, orePosition)
                MouseController:Set(false, true) 
                task.wait(0.2) 
            end
            continue 
        end
        
        if distance <= MINING_DISTANCE and not isMineCharging then
            MouseController:Set(true, true)
            task.wait(0.15) 
        end
    end
end)

task.spawn(function()
    local wasMinigameActive = false
    while getgenv().AutoFarmingRunning do
        task.wait(0.015) 
        if not getgenv().AutoFishEnabled then continue end

        local fishingGui = LocalPlayer.PlayerGui:FindFirstChild("Fishing")
        local main = fishingGui and fishingGui:FindFirstChild("Main")
        local qte = LocalPlayer.PlayerGui:FindFirstChild("QuickTimeEvents")
        local shakeActive = false

        if qte then
            local btn = qte:FindFirstChild("Button")
            local isVisible = false
            pcall(function() if btn and (btn.Visible or btn.AbsoluteSize.X > 0) then isVisible = true end end)
            if isVisible then
                shakeActive = true
                local clicked = false
                if getconnections then
                    pcall(function()
                        for _, conn in pairs(getconnections(btn.MouseButton1Click)) do conn:Fire() end
                        for _, conn in pairs(getconnections(btn.MouseButton1Down)) do conn:Fire() end
                        for _, conn in pairs(getconnections(btn.Activated)) do conn:Fire() end
                        clicked = true
                    end)
                end
                if not clicked and firesignal then
                    pcall(function() 
                        firesignal(btn.MouseButton1Click) 
                        firesignal(btn.MouseButton1Down)
                        firesignal(btn.Activated)
                        clicked = true
                    end)
                end
                if not clicked then
                    pcall(function()
                        MouseController:Set(false)
                        local inset = GuiService:GetGuiInset()
                        local btnX = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
                        local btnY = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2) + inset.Y
                        VirtualInputManager:SendMouseButtonEvent(btnX, btnY, 0, true, game, 1)
                        task.wait(0.01)
                        VirtualInputManager:SendMouseButtonEvent(btnX, btnY, 0, false, game, 1)
                    end)
                end
                task.wait(0.1) 
            end
        end

        if shakeActive then continue end

        if fishingGui and fishingGui.Enabled and main and main.Visible and main:FindFirstChild("Fish") and main:FindFirstChild("Move") then
            wasMinigameActive = true
            local fish = main.Fish
            local move = main.Move
            local fX = fish.AbsolutePosition.X + (fish.AbsoluteSize.X / 2)
            local mX = move.AbsolutePosition.X + (move.AbsoluteSize.X / 2)
            if mX < (fX - 2) then MouseController:Set(true)
            elseif mX > (fX + 2) then MouseController:Set(false)
            end
            continue
        end

        if wasMinigameActive then
            MouseController:Set(false)
            task.wait(2.5)
            wasMinigameActive = false
            continue
        end

        local castAmountBar, castParentFrame = getFishingCastFrames()
        if castAmountBar and castParentFrame then
            if CalculateRelease(castAmountBar, castParentFrame) then
                MouseController:Set(false)
                task.wait(1.5)
            else
                MouseController:Set(true)
            end
            continue
        end

        if fishingGui and fishingGui.Enabled then
            MouseController:Set(false)
            continue
        end

        MouseController:Set(true)
        task.wait(0.25)
        if not getFishingCastFrames() then
            MouseController:Set(false)
            task.wait(0.5) 
        end
    end
end)
