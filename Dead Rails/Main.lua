local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local cfg = {
	bat_hit_on = false,
	bat_hit_range = 50,
	attack_rate = 15,
	hits_per_attack = 2,
}

local ENEMY_FOLDERS = { "RuntimeEnemies", "NightEnemies" }

local cached_tool
local cached_char_addr
local cached_swing
local accum = 0
local status = "idle"

local function addr(inst)
	if not inst then
		return nil
	end
	local ok, value = pcall(function()
		return inst.Address
	end)
	if ok then
		return value
	end
	return nil
end

local function get_character()
	local char = LocalPlayer.Character
	if char and char.Parent then
		return char
	end
	return Workspace:FindFirstChild(LocalPlayer.Name)
end

local function get_root(model)
	if not model then
		return nil
	end
	return model:FindFirstChild("HumanoidRootPart")
		or model.PrimaryPart
		or model:FindFirstChild("Torso")
		or model:FindFirstChild("UpperTorso")
		or model:FindFirstChildWhichIsA("BasePart")
end

local function get_head(model)
	if not model then
		return nil
	end
	return model:FindFirstChild("Head") or get_root(model)
end

local function dist2(a, b)
	local dx = a.X - b.X
	local dy = a.Y - b.Y
	local dz = a.Z - b.Z
	return dx * dx + dy * dy + dz * dz
end

local function is_alive(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return true
	end
	local ok, health = pcall(function()
		return humanoid.Health
	end)
	if not ok then
		return true
	end
	return health > 0
end

local function get_swing_remote()
	if cached_swing then
		local ok = pcall(function()
			return cached_swing.Parent ~= nil
		end)
		if ok and cached_swing.Parent then
			return cached_swing
		end
	end

	-- Avoid WaitForChild on Matcha — it can hang / be unreliable
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local universe = shared and shared:FindFirstChild("Universe")
	local network = universe and universe:FindFirstChild("Network")
	local remotes = network and network:FindFirstChild("RemoteEvent")
	local swing = remotes and remotes:FindFirstChild("SwingMelee")
	if swing then
		cached_swing = swing
		return swing
	end
	return nil
end

local function tool_equipped(tool, character)
	if not (tool and character) then
		return false
	end
	local ok, parent = pcall(function()
		return tool.Parent
	end)
	if not ok or not parent then
		return false
	end
	return addr(parent) == addr(character) or parent.Name == character.Name
end

local function find_melee_tool(character)
	local char_addr = addr(character)
	if cached_char_addr == char_addr and cached_tool and tool_equipped(cached_tool, character) then
		return cached_tool
	end

	local equipped = character:FindFirstChildOfClass("Tool")
	if equipped then
		cached_char_addr, cached_tool = char_addr, equipped
		return equipped
	end

	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		local any = backpack:FindFirstChildOfClass("Tool")
		if any then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				pcall(function()
					humanoid:EquipTool(any)
				end)
			end
			cached_char_addr, cached_tool = char_addr, any
			return any
		end
	end

	cached_char_addr, cached_tool = char_addr, nil
	return nil
end

local function get_closest_enemy(my_character, max_range)
	local my_root = get_root(my_character)
	if not my_root then
		status = "no my root"
		return nil
	end

	local my_pos = my_root.Position
	local my_addr = addr(my_character)
	local my_name = LocalPlayer.Name
	local best, best_head, best_d2 = nil, nil, max_range * max_range

	for i = 1, #ENEMY_FOLDERS do
		local folder = Workspace:FindFirstChild(ENEMY_FOLDERS[i])
		if folder then
			local children = folder:GetChildren()
			for j = 1, #children do
				local child = children[j]
				local name = child.Name
				if name ~= my_name and addr(child) ~= my_addr and is_alive(child) then
					local head = get_head(child)
					if head then
						local d2 = dist2(my_pos, head.Position)
						if d2 <= best_d2 then
							best_d2 = d2
							best = child
							best_head = head
						end
					end
				end
			end
		end
	end

	if best then
		status = string.format("target %s (%.1f)", best.Name, math.sqrt(best_d2))
	else
		status = "no enemy in range"
	end
	return best, best_head, my_root
end

local Lib
do
	local ok_load, result = pcall(function()
		return loadstring(game:HttpGet("https://raw.githubusercontent.com/lec1e/Matcha-UI-Libraries/refs/heads/main/INS%20UI.lua"))()
	end)
	Lib = (ok_load and result) or INSui
end

if not Lib then
	error("[Dead Rails] INS ui failed to load — check HttpGet / INSui global")
end

local win = Lib:CreateWindow({
	title = "Dead Rails",
	subtitle = "Melee",
	size = Vector2.new(560, 420),
	menuKey = "p",
	configName = "dead_rails_melee",
	configFolder = "dead_rails_melee",
	checkboxStyle = true,
	smartFps = true,
	startOpen = true,
})

pcall(function()
	win:AddSettingsTab("cog")
end)

Lib:Category("COMBAT")
local tab = win:Tab("Melee", "swords")
local sec = tab:Section("Combat", "Left", "fires SwingMelee at one closest enemy")

local melee_toggle = sec:Toggle("Enabled", false, function(on)
	cfg.bat_hit_on = on == true
	accum = 0
	status = on and "armed" or "idle"
end)
pcall(function()
	melee_toggle:AddKeybind("b", "Toggle")
end)

sec:Slider("Range", 50, 1, 1, 500, "studs", function(v)
	cfg.bat_hit_range = tonumber(v) or 50
end)

sec:Slider("Attack Rate", 15, 1, 1, 40, "/s", function(v)
	cfg.attack_rate = math.max(1, math.floor(tonumber(v) or 15))
end)

sec:Slider("Hits / Attack", 2, 1, 1, 6, "x", function(v)
	cfg.hits_per_attack = math.max(1, math.floor(tonumber(v) or 2))
end)

sec:Label(function()
	return "Status: " .. tostring(status)
end)
sec:Info("Press P to open/close. Keybind: B")

local hb = RunService.Heartbeat
if not hb then
	error("[Dead Rails] RunService.Heartbeat missing")
end

local ok_conn, err_conn = pcall(function()
	hb:Connect(function(dt)
		if not cfg.bat_hit_on then
			accum = 0
			return
		end

		accum += dt
		local interval = 1 / math.max(1, cfg.attack_rate)
		if accum < interval then
			return
		end
		accum -= interval
		if accum > interval then
			accum = 0
		end

		local character = get_character()
		if not character then
			status = "no character"
			return
		end
		if not is_alive(character) then
			status = "character dead"
			return
		end

		local tool = find_melee_tool(character)
		local swing = get_swing_remote()
		if not tool then
			status = "no melee tool"
			return
		end
		if not swing then
			status = "no SwingMelee remote"
			return
		end

		if not tool_equipped(tool, character) then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				pcall(function()
					humanoid:EquipTool(tool)
				end)
			end
			if not tool_equipped(tool, character) then
				status = "equip melee tool"
				return
			end
		end

		local enemy, enemy_head, my_root = get_closest_enemy(character, cfg.bat_hit_range or 50)
		if not (enemy and enemy_head and my_root) then
			return
		end

		local head_pos = enemy_head.Position
		local dx = head_pos.X - my_root.Position.X
		local dy = head_pos.Y - my_root.Position.Y
		local dz = head_pos.Z - my_root.Position.Z
		local mag = math.sqrt(dx * dx + dy * dy + dz * dz)

		local dir
		if mag < 1e-3 then
			local cam = Workspace.CurrentCamera
			if cam then
				dir = cam.CFrame.LookVector
			else
				dir = my_root.CFrame.LookVector
			end
		else
			dir = Vector3.new(dx / mag, dy / mag, dz / mag)
			pcall(function()
				my_root.CFrame = CFrame.lookAt(
					my_root.Position,
					Vector3.new(head_pos.X, my_root.Position.Y, head_pos.Z)
				)
			end)
		end

		local fired = 0
		for _ = 1, cfg.hits_per_attack do
			local ok = pcall(function()
				swing:FireServer(tool, 1.78604e+09, dir)
			end)
			if ok then
				fired += 1
			end
		end

		if fired == 0 then
			status = "FireServer failed"
		else
			status = string.format("hit %s x%d", enemy.Name, fired)
		end
	end)
end)

if not ok_conn then
	error("[Dead Rails] Heartbeat:Connect failed — " .. tostring(err_conn))
end
