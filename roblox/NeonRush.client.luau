-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")

local width, height, playerY = 480, 854, 700
local lanes = {110, 240, 370}
local patterns = {
	{{"X.."}, {".X."}, {"..X"}, {"X.C"}, {"C.X"}},
	{{"XX."}, {"X.X"}, {".XX"}, {"X..", ".X."}, {"..X", ".X."}, {".X.", "X.."}},
	{{"XX.", ".X.", "X.."}, {".XX", "X..", "..X"}, {"X.X", ".X.", "X.X"}, {"..X", "X..", "..X"}},
}
local random = Random.new()
local cyan = Color3.fromRGB(56, 234, 255)
local pink = Color3.fromRGB(255, 67, 134)
local gold = Color3.fromRGB(255, 225, 107)
local dark = Color3.fromRGB(8, 13, 34)

local gui = Instance.new("ScreenGui")
gui.Name = "NeonRush"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local board = Instance.new("Frame")
board.Size = UDim2.fromScale(1, 1)
board.AnchorPoint = Vector2.new(0.5, 0.5)
board.Position = UDim2.fromScale(0.5, 0.5)
board.BackgroundColor3 = dark
board.ClipsDescendants = true
board.Parent = gui
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = width / height
aspect.Parent = board

local function place(object, x, y, w, h)
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Position = UDim2.fromScale(x / width, y / height)
	object.Size = UDim2.fromScale(w / width, h / height)
	object.BorderSizePixel = 0
	object.Parent = board
end

local function shape(x, y, w, h, color, round)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = color
	place(frame, x, y, w, h)
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
	end
	return frame
end

local function text(class, caption, x, y, w, h)
	local item = Instance.new(class)
	item.Text = caption
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextScaled = true
	item.Font = Enum.Font.GothamBold
	item.BackgroundColor3 = Color3.fromRGB(24, 37, 68)
	item.BackgroundTransparency = class == "TextLabel" and 1 or 0
	item.ZIndex = 4
	place(item, x, y, w, h)
	return item
end

for _, x in {45, 175, 305, 435} do
	shape(x, height / 2, 2, height, Color3.fromRGB(35, 56, 98), false)
end
local orb = shape(lanes[2], playerY, 48, 48, cyan, true)
orb.ZIndex = 3
local hud = text("TextLabel", "", 240, 45, 420, 35)
local title = text("TextLabel", "NEON RUSH", 240, 310, 420, 90)
title.TextColor3 = cyan
local action = text("TextButton", "PLAY", 240, 415, 200, 64)
local left = text("TextButton", "LEFT", 125, 800, 185, 72)
local right = text("TextButton", "RIGHT", 355, 800, 185, 72)

local objects, queue = {}, {}
local lane, safeLane, playerX = 2, 2, lanes[2]
local elapsed, spawnClock, score, combo, best = 0, 0.9, 0, 0, 0
local running = false

local function updateHud()
	hud.Text = string.format("SCORE %d   ·   BEST %d   ·   x%d", math.floor(score), best, math.min(combo, 5))
end

local function step(direction)
	if running then
		lane = math.clamp(lane + direction, 1, #lanes)
	end
end

local function start()
	for _, object in objects do
		object.frame:Destroy()
	end
	table.clear(objects)
	table.clear(queue)
	lane, safeLane, playerX = 2, 2, lanes[2]
	elapsed, spawnClock, score, combo = 0, 0.9, 0, 0
	orb.Position = UDim2.fromScale(playerX / width, playerY / height)
	title.Visible, action.Visible = false, false
	running = true
	updateHud()
end

local function finish()
	running = false
	best = math.max(best, math.floor(score))
	title.Text = "RUN OVER"
	action.Text = "RETRY"
	title.Visible, action.Visible = true, true
	updateHud()
end

-- Plan the entire pattern from the previous row so each queued row stays reachable.
local function plan(pattern)
	local path = {}
	local function visit(rowIndex, previous)
		if rowIndex > #pattern then
			return true
		end
		local row = pattern[rowIndex]
		for index = math.max(1, previous - 1), math.min(#lanes, previous + 1) do
			if row:sub(index, index) ~= "X" then
				path[rowIndex] = index
				if visit(rowIndex + 1, index) then
					return true
				end
			end
		end
		return false
	end
	return visit(1, safeLane) and path or nil
end

local function addObject(index, crystal)
	local frame = shape(lanes[index], -55, crystal and 24 or 72, crystal and 24 or 48, crystal and gold or pink, false)
	frame.Rotation = crystal and 45 or 0
	frame.ZIndex = 2
	table.insert(objects, {lane = index, y = -55, crystal = crystal, frame = frame})
end

local function spawnRow()
	if #queue == 0 then
		local tier = elapsed >= 60 and 3 or (elapsed >= 25 and 2 or 1)
		local candidates = {}
		for _, pattern in patterns[tier] do
			local path = plan(pattern)
			if path then
				table.insert(candidates, {rows = pattern, path = path})
			end
		end
		if #candidates == 0 then
			table.insert(queue, {row = "...", safe = safeLane})
		else
			local selected = candidates[random:NextInteger(1, #candidates)]
			for index, row in selected.rows do
				table.insert(queue, {row = row, safe = selected.path[index]})
			end
		end
	end
	local nextRow = table.remove(queue, 1)
	safeLane = nextRow.safe
	local safe = {}
	for index = 1, #lanes do
		if nextRow.row:sub(index, index) == "X" then
			addObject(index, false)
		else
			table.insert(safe, index)
		end
	end
	if random:NextNumber() < 0.75 then
		addObject(nextRow.row:find("C") or safe[random:NextInteger(1, #safe)], true)
	end
end

action.Activated:Connect(start)
left.Activated:Connect(function() step(-1) end)
right.Activated:Connect(function() step(1) end)
Input.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
		step(-1)
	elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
		step(1)
	end
end)

RunService.RenderStepped:Connect(function(delta)
	if not running then
		return
	end
	local dt = math.min(delta, 0.05)
	elapsed += dt
	local speed = math.min(680, 270 + elapsed * 7)
	local offset = lanes[lane] - playerX
	playerX += math.clamp(offset, -1800 * dt, 1800 * dt)
	orb.Position = UDim2.fromScale(playerX / width, playerY / height)
	score += dt * (15 + math.min(combo, 10))
	spawnClock -= dt
	if spawnClock <= 0 then
		spawnRow()
		spawnClock += 190 / speed
	end
	for index = #objects, 1, -1 do
		local object = objects[index]
		local previousY = object.y
		object.y += speed * dt
		object.frame.Position = UDim2.fromScale(lanes[object.lane] / width, object.y / height)
		local dx = math.abs(playerX - lanes[object.lane])
		local crosses = previousY <= playerY + 35 and object.y >= playerY - 35
		local collected = crosses and dx <= 44 and object.crystal
		if crosses and dx <= 44 and not object.crystal then
			finish()
			return
		end
		if collected then
			combo += 1
			score += 50 * math.min(combo, 5)
		elseif not object.crystal and previousY <= playerY and object.y > playerY and dx <= 145 then
			combo += 1
			score += 25 * math.min(combo, 5)
		end
		if collected or object.y > height + 70 then
			object.frame:Destroy()
			table.remove(objects, index)
		end
	end
	updateHud()
end)

updateHud()
