-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Player setup
local Player = Players.LocalPlayer
if not Player.Character then
    Player.CharacterAdded:Wait()
end
local Character = Player.Character
local HRP = Character:WaitForChild("HumanoidRootPart")
local HUM = Character:FindFirstChildOfClass("Humanoid")

-- Store original WalkSpeed
local originalWalkSpeed = HUM.WalkSpeed

-- Disable default movement
HUM.WalkSpeed = 0

-- Step 1: Teleport above Generator and anchor
local Generator = Workspace:WaitForChild("TeslaLab"):WaitForChild("Generator")
local modelPosition = Generator:GetPivot().Position
HRP:PivotTo(CFrame.new(modelPosition + Vector3.new(0, 5, 0)))
HRP.Anchored = true
task.wait(2)

-- Step 2: Find and sit on closest available Chair.Seat
local RuntimeItems = Workspace:WaitForChild("RuntimeItems")
local function findClosestSeat()
    local closestSeat, minDist = nil, math.huge
    local pos = HRP.Position
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
local chosenSeat, seatWeld
if seat then
    HRP.Anchored = true
    HRP:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
    task.delay(0.1, function()
        if HRP and HRP.Anchored then HRP.Anchored = false end
    end)
    task.delay(0.15, function()
        if HRP and HRP.Anchored then HRP.Anchored = false end
    end)
    task.wait(0.5)
    seat:Sit(HUM)

    -- Weld HRP to seat to remain seated during actions
    local weld = Instance.new("WeldConstraint")
    weld.Name = "PersistentSeatWeld"
    weld.Part0 = HRP
    weld.Part1 = seat
    weld.Parent = HRP
    chosenSeat = seat
    seatWeld = weld

    -- Disable collisions on entire chair model
    local chairModel = seat.Parent
    for _, part in ipairs(chairModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
else
    HRP.Anchored = false
    return
end

-- Step 3: Enable scripted flying via BodyVelocity, BodyGyro, and Noclip
local v3inf = Vector3.new(9e9, 9e9, 9e9)
local BV = Instance.new("BodyVelocity")
BV.Name = "FlyBV"
BV.Parent = HRP
BV.MaxForce = v3inf
BV.Velocity = Vector3.new()

local BG = Instance.new("BodyGyro")
BG.Name = "FlyBG"
BG.Parent = HRP
BG.MaxTorque = v3inf
BG.P = 1000
BG.D = 50

-- Noclip connection (character and chair)
local noclipConn
local function enableNoclip()
    noclipConn = RunService.Stepped:Connect(function()
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        if chosenSeat then
            local chairModel = chosenSeat.Parent
            for _, part in ipairs(chairModel:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function disableNoclip()
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
    for _, part in ipairs(Character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
    if chosenSeat then
        local chairModel = chosenSeat.Parent
        for _, part in ipairs(chairModel:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

local function flyTo(targetPos)
    while (HRP.Position - targetPos).Magnitude > 2 do
        local dir = (targetPos - HRP.Position).Unit
        BV.Velocity = dir * 50
        BG.CFrame = CFrame.new(HRP.Position, targetPos)
        RunService.Heartbeat:Wait()
    end
    BV.Velocity = Vector3.new()
end

enableNoclip()

-- Restore movement speed
task.wait(1)
HUM.WalkSpeed = originalWalkSpeed

-- Step 4: Equip Sack tool
local sackTool = Player.Backpack:FindFirstChild("Sack")
if sackTool then
    HUM:EquipTool(sackTool)
    task.wait(0.5)
end

-- Step 5: Collect Werewolf parts by flying to each
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

-- Step 6: Fly to front of ExperimentTable to drop parts
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
                task.wait(0.5)
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
    end
end

-- **After dropping all parts onto table: fly to generator and turn on power**
local powerPromptPart = Workspace.TeslaLab.Generator.BasePart:FindFirstChild("PowerPrompt")
if powerPromptPart and powerPromptPart:IsA("BasePart") then
    local prompt = powerPromptPart:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 100
        local promptPos = powerPromptPart.Position + Vector3.new(0, 2, 0)
        flyTo(promptPos)
        task.wait(0.1)
        while prompt.Enabled do
            prompt:InputHoldBegin()
            task.wait(0.05)
            prompt:InputHoldEnd()
            task.wait(0.05)
        end
    end
end

-- Prevent falling through map
HUM.Jump = true
task.wait(0.25)

-- Cleanup flying handlers and disable noclip
BV:Destroy()
BG:Destroy()
disableNoclip()
