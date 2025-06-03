-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Flying handler names and connection references
local velocityHandlerName = "VelocityHandler"
local gyroHandlerName = "GyroHandler"
local mfly1, mfly2

-- Flag to allow unfly only after placing parts
local canUnfly = false

-- Main variables
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Prevent collisions on character parts
task.spawn(function()
    while true do
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        task.wait(0.1)
    end
end)
Player.CharacterAdded:Connect(function()
    Character = Player.Character or Player.CharacterAdded:Wait()
    Humanoid = Character:WaitForChild("Humanoid")
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    task.wait(0.2)
    while true do
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        task.wait(0.1)
    end
end)

if not Character.PrimaryPart then
    Character.PrimaryPart = HumanoidRootPart
end

local originalWalkSpeed = Humanoid.WalkSpeed
local originalJumpPower = Humanoid.JumpPower

-- Disable flying function (triggered on jump once allowed or manually)
local function disableFlying()
    pcall(function()
        _G.FLYING = false
        local root = HumanoidRootPart
        if root:FindFirstChild(velocityHandlerName) then
            root:FindFirstChild(velocityHandlerName):Destroy()
        end
        if root:FindFirstChild(gyroHandlerName) then
            root:FindFirstChild(gyroHandlerName):Destroy()
        end
        Humanoid.PlatformStand = false
        if mfly1 then
            mfly1:Disconnect()
            mfly1 = nil
        end
        if mfly2 then
            mfly2:Disconnect()
            mfly2 = nil
        end
    end)
end

Humanoid.WalkSpeed = 0

-- Teleport to Generator
local Generator = Workspace:WaitForChild("TeslaLab"):WaitForChild("Generator")
local generatorCFrame = Generator:GetPivot()
local modelPosition = generatorCFrame.Position
HumanoidRootPart.CFrame = CFrame.new(modelPosition + Vector3.new(0, 5, 0))
HumanoidRootPart.Anchored = true
task.wait(2)

-- Find and sit on nearest chair
local RuntimeItems = Workspace:WaitForChild("RuntimeItems")
local function findClosestSeat()
    local closestSeat, minDist = nil, math.huge
    local pos = HumanoidRootPart.Position
    for _, chairModel in ipairs(RuntimeItems:GetChildren()) do
        if chairModel:IsA("Model") and chairModel.Name == "Chair" then
            local seat = chairModel:FindFirstChildOfClass("Seat")
            if seat and seat.Occupant == nil then
                local d = (seat.Position - pos).Magnitude
                if d < minDist then
                    minDist = d
                    closestSeat = seat
                end
            end
        end
    end
    return closestSeat
end

local seat = findClosestSeat()
local seatWeld
if seat then
    HumanoidRootPart.Anchored = true
    HumanoidRootPart.CFrame = seat.CFrame + Vector3.new(0, 3, 0)
    task.delay(0.1, function()
        if HumanoidRootPart and HumanoidRootPart.Anchored then
            HumanoidRootPart.Anchored = false
        end
    end)
    task.delay(0.15, function()
        if HumanoidRootPart and HumanoidRootPart.Anchored then
            HumanoidRootPart.Anchored = false
        end
    end)
    task.wait(0.5)
    seat:Sit(Humanoid)

    seatWeld = Instance.new("WeldConstraint")
    seatWeld.Name = "PersistentSeatWeld"
    seatWeld.Part0 = HumanoidRootPart
    seatWeld.Part1 = seat
    seatWeld.Parent = HumanoidRootPart

    local chairModel = seat.Parent
    for _, part in ipairs(chairModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
else
    HumanoidRootPart.Anchored = false
    return
end

-- Enable hybrid flying
local FLYING = true
local flyingToTarget = false
local targetFlyPosition = nil
local iyflyspeed = 50

local function enableHybridFlying()
    local root = HumanoidRootPart
    local camera = Workspace.CurrentCamera
    local v3inf = Vector3.new(9e9, 9e9, 9e9)
    local controlModule = require(Player.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule"))

    local bv = Instance.new("BodyVelocity")
    bv.Name = velocityHandlerName
    bv.Parent = root
    bv.MaxForce = v3inf
    bv.Velocity = Vector3.new()

    local bg = Instance.new("BodyGyro")
    bg.Name = gyroHandlerName
    bg.Parent = root
    bg.MaxTorque = v3inf
    bg.P = 1000
    bg.D = 50

    mfly1 = Player.CharacterAdded:Connect(function()
        local newRoot = Player.Character:WaitForChild("HumanoidRootPart")
        if newRoot:FindFirstChild(velocityHandlerName) then
            newRoot:FindFirstChild(velocityHandlerName):Destroy()
        end
        if newRoot:FindFirstChild(gyroHandlerName) then
            newRoot:FindFirstChild(gyroHandlerName):Destroy()
        end
        bv.Parent = newRoot
        bg.Parent = newRoot
    end)

    mfly2 = RunService.RenderStepped:Connect(function()
        if _G.FLYING then
            local humanoidObj = Player.Character:FindFirstChildWhichIsA("Humanoid")
            local VelocityHandler = root:FindFirstChild(velocityHandlerName)
            local GyroHandler = root:FindFirstChild(gyroHandlerName)
            if humanoidObj and VelocityHandler and GyroHandler then
                if flyingToTarget and targetFlyPosition then
                    local dir = (targetFlyPosition - root.Position)
                    if dir.Magnitude > 2 then
                        local moveDir = dir.Unit
                        VelocityHandler.Velocity = moveDir * iyflyspeed
                        GyroHandler.CFrame = CFrame.new(root.Position, targetFlyPosition)
                    else
                        VelocityHandler.Velocity = Vector3.new()
                        flyingToTarget = false
                        targetFlyPosition = nil
                    end
                else
                    GyroHandler.CFrame = camera.CFrame
                    local direction = controlModule:GetMoveVector()
                    VelocityHandler.Velocity =
                        (camera.CFrame.RightVector * direction.X * iyflyspeed) +
                        (-camera.CFrame.LookVector * direction.Z * iyflyspeed)
                end
            end
        end
    end)
end

local function flyTo(targetPos)
    flyingToTarget = true
    targetFlyPosition = targetPos
    while flyingToTarget and targetFlyPosition and (HumanoidRootPart.Position - targetFlyPosition).Magnitude > 2 do
        RunService.RenderStepped:Wait()
    end
    flyingToTarget = false
    targetFlyPosition = nil
end

-- Start flying
_G.FLYING = true
enableHybridFlying()

-- On Humanoid state change: detect jump to unweld/unsit and possibly unfly
Humanoid.StateChanged:Connect(function(_, newState)
    if newState == Enum.HumanoidStateType.Jumping then
        -- Always remove weld and force unsit
        if seatWeld then
            seatWeld:Destroy()
            seatWeld = nil
        end
        if Humanoid.Sit then
            Humanoid.Sit = false
        end
        -- Unanchor so player can move
        HumanoidRootPart.Anchored = false
        -- Disable flying if allowed
        if canUnfly then
            disableFlying()
        end
    end
end)

-- Restore walk/jump after a brief delay
task.wait(1)
Humanoid.WalkSpeed = originalWalkSpeed
Humanoid.JumpPower = originalJumpPower

-- Equip Sack tool
local sackTool = Player.Backpack:FindFirstChild("Sack")
if sackTool then
    Humanoid:EquipTool(sackTool)
    task.wait(0.5)
end

-- Collect werewolf parts
local itemsToCollect = {
    Workspace.RuntimeItems:FindFirstChild("LeftWerewolfArm"),
    Workspace.RuntimeItems:FindFirstChild("LeftWerewolfLeg"),
    Workspace.RuntimeItems:FindFirstChild("RightWerewolfArm"),
    Workspace.RuntimeItems:FindFirstChild("RightWerewolfLeg"),
    Workspace.RuntimeItems:FindFirstChild("WerewolfTorso"),
    Workspace.RuntimeItems:FindFirstChild("BrainJar"),
    Workspace.RuntimeItems.BrainJar and Workspace.RuntimeItems.BrainJar:FindFirstChild("Brain")
}

local storeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StoreItem")
for _, item in ipairs(itemsToCollect) do
    if item and item:IsDescendantOf(Workspace.RuntimeItems) then
        local targetCFrame
        if item:IsA("BasePart") then
            targetCFrame = item.CFrame
        elseif item.PrimaryPart then
            targetCFrame = item.PrimaryPart.CFrame
        else
            for _, d in ipairs(item:GetDescendants()) do
                if d:IsA("BasePart") then
                    targetCFrame = d.CFrame
                    break
                end
            end
        end
        if targetCFrame then
            local flyTarget = targetCFrame.Position + Vector3.new(0, 2, 0)
            flyTo(flyTarget)
            task.wait(0.2)
            storeRemote:FireServer(item)
            task.wait(0.2)
        end
    end
end

-- Assemble parts on experiment table
local experimentTable = Workspace.TeslaLab:FindFirstChild("ExperimentTable")
local placedPartsFolder = experimentTable and experimentTable:FindFirstChild("PlacedParts")
if experimentTable and placedPartsFolder then
    local dropTarget = experimentTable.PrimaryPart
    if not dropTarget then
        for _, p in ipairs(experimentTable:GetDescendants()) do
            if p:IsA("BasePart") then
                dropTarget = p
                break
            end
        end
    end
    if dropTarget then
        local frontPos = dropTarget.Position + (dropTarget.CFrame.LookVector * 2) + Vector3.new(0, 5, 0)
        flyTo(frontPos)
        task.wait(0.5)
        local dropRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DropItem")
        local initialCount = #placedPartsFolder:GetChildren()
        for i = 1, #itemsToCollect do
            local success = false
            local attempts = 0
            while not success and attempts < 5 do
                dropRemote:FireServer()
                task.wait(0.2)
                local currentCount = #placedPartsFolder:GetChildren()
                if currentCount > initialCount then
                    success = true
                    initialCount = currentCount
                else
                    flyTo(frontPos)
                    task.wait(0.2)
                    attempts = attempts + 1
                end
            end
        end
        -- After dropping all parts on table, allow unfly via jump
        canUnfly = true
    end
end

-- Continue to generator and activate prompts
task.wait(1)
HumanoidRootPart.CFrame = generatorCFrame * CFrame.new(0, 4, 0)
task.wait(2)
local POSITION = HumanoidRootPart.Position
local nearestPrompt, nearestDist = nil, math.huge
for _, part in ipairs(Workspace:GetDescendants()) do
    if part:IsA("ProximityPrompt") and part.Enabled then
        local parent = part.Parent
        if parent and parent:IsA("BasePart") then
            local dist = (parent.Position - POSITION).Magnitude
            if dist < nearestDist then
                nearestPrompt = part
                nearestDist = dist
            end
        end
    end
end
if nearestPrompt then
    for i = 1, 3 do
        fireproximityprompt(nearestPrompt)
        task.wait(0.2)
    end
else
    warn("No enabled ProximityPrompt found near the teleport location.")
end

task.wait(3)

if experimentTable then
    local tpTarget = experimentTable.PrimaryPart or experimentTable:FindFirstChildWhichIsA("BasePart")
    if tpTarget then
        HumanoidRootPart.CFrame = tpTarget.CFrame * CFrame.new(0, 12, 0)
    end
end

while true do task.wait() end

-- Load additional scripts
task.spawn(function()
    task.wait(1)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/ringtaa/fly.github.io/refs/heads/main/fly.lua"))()
end)

task.spawn(function()
    task.wait(2)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/hbjrev/newhit.github.io/refs/heads/main/hithit.lua"))()
end)

task.spawn(function()
    local Backpack = Player:WaitForChild("Backpack")
    local Character = Player.Character or Player.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local shovel = Backpack:FindFirstChild("shovel")
    if shovel then
        Humanoid:EquipTool(shovel)
    else
        warn("No shovel found in your inventory!")
    end
end)
