local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local INS_UI_URL = "https://raw.githubusercontent.com/lec1e/Matcha-UI-Libraries/refs/heads/main/INS%20UI.lua"

local function http_get(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" and #body > 0 then
		return body
	end
	if httpget then
		return httpget(url)
	end
	error("HttpGet failed for " .. tostring(url))
end

local cfg = {
	bat_hit_on = false,
	bat_hit_range = 50,
	attack_rate = 15,
	hits_per_attack = 2,
	void_bloaters = true,
}

local VOID_CF = CFrame.new(0, -10000, 0)
local VOID_HOLD = 0.1
local VOID_PARTS = { "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso", "Head" }

local last_void = {}
local last_hp = {}
local bloater_list = {}

local cached_tool, cached_swing, cached_hit
local cached_tool_addr
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
	local characters = Workspace:FindFirstChild("Characters")
	if characters then
		local by_name = characters:FindFirstChild(LocalPlayer.Name)
		if by_name then
			return by_name, characters
		end
	end
	local char = LocalPlayer.Character
	if char and char.Parent then
		return char, characters
	end
	return nil, characters
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

local function contains_bloater(text)
	if not text then
		return false
	end
	local ok, lower = pcall(string.lower, tostring(text))
	if not ok then
		return tostring(text) == "Bloater"
	end
	return string.find(lower, "bloater", 1, true) ~= nil
end

local function is_bloater(model)
	if not model then
		return false
	end
	if contains_bloater(model.Name) then
		return true
	end
	local ok, variant = pcall(function()
		return model:GetAttribute("Variant")
	end)
	return ok and contains_bloater(variant)
end

local function get_humanoid(model)
	if not model then
		return nil
	end
	return model:FindFirstChild("Humanoid") or model:FindFirstChildOfClass("Humanoid")
end

local function read_health(humanoid)
	if not humanoid then
		return nil
	end
	local ok, health = pcall(function()
		return humanoid.Health
	end)
	if ok then
		return health
	end
	return nil
end

local function bloater_health(model)
	return read_health(get_humanoid(model))
end

local function bloater_fusing()
	local kids = Workspace:GetChildren()
	for i = 1, #kids do
		if kids[i].Name == "BloaterIndicator" then
			return true
		end
	end
	return false
end

local function void_model(model)
	if not model then
		return
	end
	local id = addr(model)
	local now = tick()
	if id and last_void[id] and (now - last_void[id]) < VOID_HOLD then
		return
	end
	for i = 1, #VOID_PARTS do
		local part = model:FindFirstChild(VOID_PARTS[i])
		if part then
			pcall(function()
				part.CFrame = VOID_CF
			end)
		end
	end
	local root = model.PrimaryPart
	if root then
		pcall(function()
			root.CFrame = VOID_CF
		end)
	end
	if id then
		last_void[id] = now
	end
end

local function bloater_should_void(model)
	local id = addr(model)
	local humanoid = get_humanoid(model)
	local hp = read_health(humanoid)
	if hp ~= nil then
		if id then
			last_hp[id] = hp
		end
		if hp <= 0 then
			return true
		end
		return false
	end
	-- Humanoid gone after we had live HP = they just died
	if id and last_hp[id] ~= nil and last_hp[id] > 0 then
		return true
	end
	return false
end

local function handle_bloaters(characters)
	if not characters then
		return
	end
	local fusing = bloater_fusing()
	bloater_list = {}
	local children = characters:GetChildren()
	for i = 1, #children do
		local child = children[i]
		if is_bloater(child) then
			bloater_list[#bloater_list + 1] = child
			if fusing or bloater_should_void(child) then
				void_model(child)
			end
		end
	end
end

local function player_name_set()
	local names = {}
	local list = Players:GetPlayers()
	for i = 1, #list do
		names[list[i].Name] = true
	end
	return names
end

local function tool_is_held(tool, character)
	if not (tool and character) then
		return false
	end
	local ok, parent = pcall(function()
		return tool.Parent
	end)
	if not ok or not parent then
		return false
	end
	return addr(parent) == addr(character)
end

local function remotes_from_tool(tool)
	if not tool then
		return nil
	end
	local hit_targets = tool:FindFirstChild("HitTargets")
	if not hit_targets then
		return nil
	end
	return tool, tool:FindFirstChild("Swing"), hit_targets
end

local function find_combat_tool(character)
	local equipped = character:FindFirstChildOfClass("Tool")
	local equipped_addr = addr(equipped)

	if equipped_addr and cached_tool_addr == equipped_addr and cached_hit and tool_is_held(cached_tool, character) then
		local ok = pcall(function()
			return cached_hit.Parent
		end)
		if ok and cached_hit.Parent then
			return cached_tool, cached_swing, cached_hit
		end
	end

	local tool, swing, hit_targets = remotes_from_tool(equipped)
	if hit_targets then
		cached_tool_addr, cached_tool, cached_swing, cached_hit = equipped_addr, tool, swing, hit_targets
		return tool, swing, hit_targets
	end

	local children = character:GetChildren()
	for i = 1, #children do
		local child = children[i]
		if child.ClassName == "Tool" then
			tool, swing, hit_targets = remotes_from_tool(child)
			if hit_targets then
				cached_tool_addr, cached_tool, cached_swing, cached_hit = addr(child), tool, swing, hit_targets
				return tool, swing, hit_targets
			end
		end
	end

	cached_tool_addr, cached_tool, cached_swing, cached_hit = nil, nil, nil, nil
	return nil
end

local function get_closest_zombie(characters, my_character, max_range)
	local my_root = get_root(my_character)
	if not my_root then
		status = "no my root"
		return nil
	end

	local my_pos = my_root.Position
	local my_addr = addr(my_character)
	local my_name = LocalPlayer.Name
	local player_names = player_name_set()
	local best, best_head, best_d2 = nil, nil, max_range * max_range
	local children = characters:GetChildren()

	for i = 1, #children do
		local child = children[i]
		local name = child.Name
		if name ~= my_name and not player_names[name] and addr(child) ~= my_addr and is_alive(child) then
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

	if best then
		status = string.format("target %s (%.1f)", best.Name, math.sqrt(best_d2))
	else
		status = "no zombie in range"
	end
	return best, best_head, my_root
end

local Lib
do
	local ok_load, result = pcall(function()
		return loadstring(http_get(INS_UI_URL))()
	end)
	Lib = (ok_load and result) or INSUI or INSui
end

if not Lib then
	error("[STA] INSUI failed to load — check HttpGet / INSUI global")
end

local win = Lib:CreateWindow({
	title = "Survive the Apocalypse",
	subtitle = "Melee",
	size = Vector2.new(620, 460),
	menuKey = "p",
	configName = "sta_melee",
	configFolder = "sta_melee",
	autoSave = true,
	checkboxStyle = true,
	smartFps = true,
	keybindOverlay = true,
	startOpen = true,
	font = "Proxima",
	opacity = 0.95,
	gameInput = false,
	backgroundEffect = "Off",
})

win:AddSettingsTab("cog")
pcall(function()
	Lib:SetPerformance(true)
end)

local function bloater_note()
	if not cfg.void_bloaters then
		return "off"
	end
	local n = #bloater_list
	if n == 0 then
		return "none"
	end
	local hp = bloater_health(bloater_list[1])
	return string.format("%d | HP %.0f", n, hp or -1)
end

local status_box
local status_lines
pcall(function()
	status_box = Lib:CreateBox({
		title = "STA",
		position = Vector2.new(18, 120),
		width = 220,
	})
	if status_box then
		status_lines = {
			status_box:Stat("status: idle"),
			status_box:Stat("bloaters: none"),
		}
	end
end)

local last_box = ""
local function refresh_status_box()
	pcall(function()
		if status_box then
			status_box:SetVisible(win:IsOpen() ~= true)
		end
	end)
	local note = bloater_note()
	local key = tostring(status) .. "|" .. note
	if key == last_box then
		return
	end
	last_box = key
	pcall(function()
		if status_lines then
			status_lines[1].Value = "status: " .. tostring(status)
			status_lines[2].Value = "bloaters: " .. note
		end
	end)
end

Lib:Category("COMBAT")
local tab = win:Tab("Melee", "swords")

local sec = tab:Section("Combat", "Left", "held Tool → Swing + HitTargets")

local melee_toggle = sec:Toggle("Enabled", false, function(on)
	cfg.bat_hit_on = on == true
	accum = 0
	status = on and "armed" or "idle"
	Lib:Notify("Melee", on and "enabled" or "disabled", 2, on and "success" or "warning")
end)
melee_toggle:AddKeybind("b", "Toggle")
melee_toggle:Tooltip("Fires Swing + HitTargets on the closest zombie. B toggles. P opens the menu.")

sec:Divider("Timing")
sec:Slider("Range", 50, 1, 1, 500, "studs", function(v)
	cfg.bat_hit_range = tonumber(v) or 50
end)
sec:Slider("Attack Rate", 15, 1, 1, 40, "/s", function(v)
	cfg.attack_rate = math.max(1, math.floor(tonumber(v) or 15))
end)
sec:Slider("Hits / Attack", 2, 1, 1, 6, "x", function(v)
	cfg.hits_per_attack = math.max(1, math.floor(tonumber(v) or 2))
end)

local extras = tab:Section("Bloaters", "Right", "void dead / fusing Bloaters")
extras:Toggle("Void Bloaters", true, function(on)
	cfg.void_bloaters = on == true
end, "send dead or fusing Bloaters under the map")

extras:Divider("Status")
extras:Label(function()
	return "Status: " .. tostring(status)
end)
extras:Label(function()
	return "Bloaters: " .. bloater_note()
end)
extras:Info("Hold any melee tool. P toggles the menu, B toggles melee.")

pcall(function()
	Lib:Notify("Loaded", "Survive the Apocalypse — P / B", 3, "success")
end)

local hb = RunService.Heartbeat
if not hb then
	error("[STA] RunService.Heartbeat missing")
end

local ok_conn, err_conn = pcall(function()
	hb:Connect(function(dt)
		local function frame(dt)
		if cfg.void_bloaters then
			local characters = Workspace:FindFirstChild("Characters")
			handle_bloaters(characters)
		end

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

		local character, characters = get_character()
		if not characters then
			status = "no Characters folder"
			return
		end
		if not character then
			status = "no character"
			return
		end
		if not is_alive(character) then
			status = "character dead"
			return
		end

		local tool, swing, hit_targets = find_combat_tool(character)
		if not hit_targets then
			status = "hold a melee tool"
			return
		end

		local zombie = get_closest_zombie(characters, character, cfg.bat_hit_range or 50)
		if not zombie then
			return
		end

		local payload = { zombie }
		local fired = 0
		local last_err
		for _ = 1, cfg.hits_per_attack do
			if swing then
				pcall(function()
					swing:FireServer()
				end)
			end
			local ok, err = pcall(function()
				hit_targets:FireServer(payload)
			end)
			if ok then
				fired += 1
			else
				last_err = err
			end
		end

		if fired == 0 then
			status = "FireServer fail: " .. tostring(last_err)
		else
			status = string.format("%s → %s x%d", tostring(tool and tool.Name or "melee"), zombie.Name, fired)
		end

		if cfg.void_bloaters and is_bloater(zombie) then
			if bloater_should_void(zombie) then
				void_model(zombie)
			end
		end
		end
		frame(dt)
		refresh_status_box()
	end)
end)

if not ok_conn then
	error("[STA] Heartbeat:Connect failed — " .. tostring(err_conn))
end
