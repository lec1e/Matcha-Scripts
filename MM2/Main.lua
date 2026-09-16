if _G.mm2_rage_unload then
	pcall(_G.mm2_rage_unload)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local MY_ID = LP and LP.UserId
local SCRIPT_NAME = "Gunkin-Ware"

local INS_UI_URLS = {
	"https://raw.githubusercontent.com/lec1e/Matcha-UI-Libraries/refs/heads/main/INS%20UI.lua",
}

local PART_CLASS = {
	Part = true,
	MeshPart = true,
	UnionOperation = true,
	WedgePart = true,
	CornerWedgePart = true,
	TrussPart = true,
	VehicleSeat = true,
	Seat = true,
	SpawnLocation = true,
}

local BODY_PARTS = { "HumanoidRootPart", "UpperTorso", "Torso", "Head", "LowerTorso" }
local GUN_HIT_PARTS = { "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso" }
local GUN_PICKUP_HEIGHT = 1

local COLOR_GUN = Color3.fromRGB(255, 196, 48)
local TP_PARTS = { "HumanoidRootPart", "UpperTorso", "Torso" }
local ZERO = Vector3.new(0, 0, 0)

local running = true
local connections = {}
local Lib, win, auto_handle
local status = "boot"
local busy = false
local last_role = "None"
local last_fire_err = nil
local selected = {}
local role_cache = { t = 0, map = {} }
local round_mod
local round_try_t = 0
local last_m_name
local last_s_name
local status_box, status_lines
local targets_dd
local last_box_key = ""

local cfg = {
	auto = false,
	auto_kill_all = false,
	auto_get_gun = false,
	restore_gun_tp = true,
	restore_get_gun = true,
	position_track = true,
	knife_cycles = 2,
	knife_delay = 0,
	gun_shots = 6,
	gun_delay = 0,
	gun_standoff = 8,
	auto_wait = 0.35,
	status_box = false,
	esp_guns = true,
	esp_box = true,
	esp_name = true,
	esp_dist = true,
	color_gun = COLOR_GUN,
}

local esp_guns = {}
local GUN_POOL = 4
local gun_pool = {}
local render_conn
local collect_running = false
local esp_suppressed = false
local menu_open_cache = false
local menu_open_at = 0
local ui_labels = {}
local ui_role = {
	murderer = {},
	sheriff_kill = {},
	get_gun = {},
	last = nil,
}
local ignore_auto = true
local stored = {
	Map = nil,
	Gun = nil,
	OldPosition = nil,
	Grabbing = false,
	ScanningGun = false,
}

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
	return nil
end

local matcha_notify = notify
local function clamp(n, lo, hi)
	if n < lo then
		return lo
	end
	if n > hi then
		return hi
	end
	return n
end

local function tell(msg, kind, secs)
	pcall(function()
		if Lib then
			Lib:Notify(SCRIPT_NAME, tostring(msg), secs or 2, kind or "info")
		end
	end)
	pcall(function()
		if matcha_notify then
			matcha_notify(tostring(msg), SCRIPT_NAME, secs or 2)
		end
	end)
end

local function bind(signal, fn)
	if not signal then
		return
	end
	local ok, conn = pcall(function()
		return signal:Connect(fn)
	end)
	if ok and conn then
		connections[#connections + 1] = conn
	end
	return conn
end

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

local function same(a, b)
	if not a or not b then
		return false
	end
	local aa, bb = addr(a), addr(b)
	if aa and bb then
		return aa == bb
	end
	return false
end

local function is_part(inst)
	return inst and PART_CLASS[inst.ClassName] == true
end

local function is_remote(inst)
	if not inst then
		return false
	end
	local class = inst.ClassName
	return class == "RemoteEvent" or class == "RemoteFunction" or class == "UnreliableRemoteEvent"
end

local function looks_like_tool(obj)
	if not obj then
		return false
	end
	if obj.ClassName == "Tool" then
		return true
	end
	local name = obj.Name
	return name == "Gun" or name == "Knife" or obj:FindFirstChild("GunClient") ~= nil or obj:FindFirstChild("KnifeClient") ~= nil
end

local function find_named(root, name)
	if not root or not name then
		return nil
	end
	local direct = root:FindFirstChild(name)
	if direct then
		return direct
	end
	local ok, desc = pcall(function()
		return root:GetDescendants()
	end)
	if not ok or not desc then
		return nil
	end
	for i = 1, #desc do
		if desc[i].Name == name then
			return desc[i]
		end
	end
	return nil
end

local function get_root(model)
	if not model then
		return nil
	end
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("Head")
end

local function get_head(model)
	if not model then
		return nil
	end
	return model:FindFirstChild("Head") or get_root(model)
end

local function get_humanoid(model)
	if not model then
		return nil
	end
	local hum = model:FindFirstChild("Humanoid") or model:FindFirstChildOfClass("Humanoid")
	if hum and hum.ClassName == "Humanoid" then
		return hum
	end
	return nil
end

local function read_health(hum)
	if not hum then
		return nil
	end
	local ok, hp = pcall(function()
		return hum.Health
	end)
	if ok then
		return hp
	end
	return nil
end

local function my_char()
	return LP and LP.Character
end

local function my_root()
	return get_root(my_char())
end

local function player_alive(plr)
	if not plr or not plr.Parent then
		return false
	end
	if plr.UserId == MY_ID then
		return false
	end
	local char = plr.Character
	if not char then
		return false
	end
	local hum = get_humanoid(char)
	local hp = read_health(hum)
	if hp ~= nil and hp <= 0 then
		return false
	end
	return get_root(char) ~= nil
end

local function tool_kind(tool)
	if not tool then
		return nil
	end
	local name = tool.Name
	if name == "Knife" or tool:FindFirstChild("KnifeClient") then
		return "Knife"
	end
	if name == "Gun" or tool:FindFirstChild("GunClient") then
		return "Gun"
	end
	return nil
end

local function container_has(container, name)
	if not container then
		return false
	end
	return container:FindFirstChild(name) ~= nil
end

local function detect_role(plr)
	if not plr then
		return nil
	end
	local char = plr.Character
	local pack = plr:FindFirstChild("Backpack")
	if container_has(char, "Knife") or container_has(pack, "Knife") then
		return "Murderer"
	end
	if container_has(char, "Gun") or container_has(pack, "Gun") then
		return "Sheriff"
	end
	return nil
end

local function normalize_role(role)
	if type(role) ~= "string" or role == "" then
		return nil
	end
	local lower = string.lower((role:gsub("^%s+", ""):gsub("%s+$", "")))
	if lower == "" then
		return nil
	end
	if lower == "murderer" or lower == "murder" then
		return "Murderer"
	end
	if lower == "sheriff" then
		return "Sheriff"
	end
	if lower == "innocent" or lower == "hero" then
		return "Innocent"
	end
	if lower == "ghost" or lower == "dead" then
		return "Dead"
	end
	return nil
end

local function player_by_userid(uid)
	uid = tonumber(uid)
	if not uid then
		return nil
	end
	local list = Players:GetPlayers()
	for i = 1, #list do
		if list[i].UserId == uid then
			return list[i]
		end
	end
	return nil
end

local function player_from_name(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local direct = Players:FindFirstChild(name)
	if direct then
		return direct
	end
	local list = Players:GetPlayers()
	for i = 1, #list do
		if list[i].Name == name then
			return list[i]
		end
	end
	return nil
end

local function resolve_round_player(key, data)
	if type(key) == "number" then
		return player_by_userid(key)
	end
	if type(key) == "string" then
		return player_from_name(key) or player_by_userid(key)
	end
	local ok, name = pcall(function()
		return key.Name
	end)
	if ok and type(name) == "string" then
		local plr = player_from_name(name)
		if plr then
			return plr
		end
	end
	local ok_uid, uid = pcall(function()
		return key.UserId
	end)
	if ok_uid then
		local plr = player_by_userid(uid)
		if plr then
			return plr
		end
	end
	if type(data) ~= "table" then
		return nil
	end
	local pname = data.Name or data.Username or data.PlayerName
	if type(pname) == "string" then
		local plr = player_from_name(pname)
		if plr then
			return plr
		end
	end
	return player_by_userid(data.UserId or data.userId)
end

local function load_round()
	return round_mod
end

local function round_player_data()
	local round = round_mod
	if not round then
		return nil
	end
	local pd = round.PlayerData
	if type(pd) == "function" then
		local ok, result = pcall(pd, round)
		if ok then
			pd = result
		end
	end
	if type(pd) == "table" then
		return pd
	end
	return nil
end

local function player_data_dead(data)
	return type(data) == "table" and (data.Dead == true or data.Killed == true)
end

local function apply_player_data(playerData, map)
	if type(playerData) ~= "table" then
		return
	end
	pcall(function()
		for key, data in pairs(playerData) do
			local plr = resolve_round_player(key, data)
			if plr then
				if player_data_dead(data) then
					map[plr.UserId] = nil
				else
					local role = data
					if type(data) == "table" then
						role = data.Role or data.role or data.Job or data.job
					end
					role = normalize_role(role)
					if role and role ~= "Dead" then
						map[plr.UserId] = role
					end
				end
			end
		end
	end)
end

local function scan_attr_roles(map)
	local list = Players:GetPlayers()
	for i = 1, #list do
		local plr = list[i]
		local role
		pcall(function()
			role = normalize_role(plr:GetAttribute("Role") or plr:GetAttribute("role") or plr:GetAttribute("Job"))
		end)
		if not role and plr.Character then
			pcall(function()
				role = normalize_role(plr.Character:GetAttribute("Role") or plr.Character:GetAttribute("role") or plr.Character:GetAttribute("Job"))
			end)
			local value = plr.Character:FindFirstChild("Role") or plr:FindFirstChild("Role")
			if value then
				pcall(function()
					role = normalize_role(value.Value)
				end)
			end
		end
		if role and role ~= "Dead" then
			map[plr.UserId] = role
		end
	end
end

local function scan_weapon(container, kind)
	if not container then
		return nil
	end
	local kids = container:GetChildren()
	for i = 1, #kids do
		local child = kids[i]
		if tool_kind(child) == kind then
			return child
		end
	end
	return nil
end

local function get_weapon(plr, kind)
	if not plr then
		return nil
	end
	return scan_weapon(plr.Character, kind) or scan_weapon(plr:FindFirstChild("Backpack"), kind)
end

local function has_weapon(plr, kind)
	return get_weapon(plr, kind) ~= nil
end

local function player_by_name(name)
	if not name then
		return nil
	end
	local list = Players:GetPlayers()
	for i = 1, #list do
		if list[i].Name == name then
			return list[i]
		end
	end
	return nil
end

local function player_names()
	local out = {}
	local list = Players:GetPlayers()
	for i = 1, #list do
		local plr = list[i]
		if plr.UserId ~= MY_ID then
			out[#out + 1] = plr.Name
		end
	end
	table.sort(out)
	return out
end

local function prune_selected()
	local alive = {}
	local names = player_names()
	for i = 1, #names do
		alive[names[i]] = true
	end
	for name in pairs(selected) do
		if not alive[name] then
			selected[name] = nil
		end
	end
end

local function selected_list()
	prune_selected()
	local out = {}
	for name, on in pairs(selected) do
		if on then
			out[#out + 1] = name
		end
	end
	table.sort(out)
	return out
end

local function selected_text()
	local list = selected_list()
	if #list == 0 then
		return "(none)"
	end
	return table.concat(list, ", ")
end

local function set_targets_from_list(v)
	selected = {}
	if type(v) ~= "table" then
		if type(v) == "string" and v ~= "" then
			selected[v] = true
		end
		return
	end
	if v[1] then
		for i = 1, #v do
			if type(v[i]) == "string" then
				selected[v[i]] = true
			end
		end
		return
	end
	for name, on in pairs(v) do
		if type(name) == "string" and on then
			selected[name] = true
		end
	end
end

local function sync_roles()
	local now = tick()
	if now - (role_cache.t or 0) < 0.12 then
		return role_cache.map
	end
	role_cache.t = now
	local map = {}
	apply_player_data(round_player_data(), map)
	scan_attr_roles(map)
	local dropped = false
	local kids = Workspace:GetChildren()
	for i = 1, #kids do
		local child = kids[i]
		if child.Name == "GunDrop" or child.Name == "DroppedGun" or (child.ClassName == "Tool" and tool_kind(child) == "Gun") then
			dropped = true
			break
		end
		local cls = child.ClassName
		if cls == "Model" or cls == "Folder" then
			if child:FindFirstChild("GunDrop") or child:FindFirstChild("DroppedGun") then
				dropped = true
				break
			end
		end
	end
	local list = Players:GetPlayers()
	for i = 1, #list do
		local plr = list[i]
		local uid = plr.UserId
		if has_weapon(plr, "Knife") or detect_role(plr) == "Murderer" then
			map[uid] = "Murderer"
		elseif has_weapon(plr, "Gun") or detect_role(plr) == "Sheriff" then
			map[uid] = "Sheriff"
		elseif dropped and map[uid] == "Sheriff" then
			map[uid] = "Innocent"
		end
	end
	role_cache.map = map
	return map
end

local function role_of(plr)
	if not plr then
		return nil
	end
	local map = sync_roles()
	local role = map[plr.UserId]
	if role then
		return role
	end
	if has_weapon(plr, "Knife") then
		return "Murderer"
	end
	if has_weapon(plr, "Gun") then
		return "Sheriff"
	end
	return nil
end

local function local_role()
	local role = role_of(LP)
	if role and role ~= "Dead" then
		last_role = role
		return role
	end
	if has_weapon(LP, "Knife") then
		last_role = "Murderer"
		return "Murderer"
	end
	if has_weapon(LP, "Gun") then
		last_role = "Sheriff"
		return "Sheriff"
	end
	last_role = role or "Innocent"
	return last_role
end

local function find_role_player(want)
	sync_roles()
	local list = Players:GetPlayers()
	for i = 1, #list do
		local plr = list[i]
		if player_alive(plr) and role_of(plr) == want then
			return plr
		end
	end
	return nil
end

local function get_sheriff()
	return find_role_player("Sheriff")
end

local function get_murderer()
	local found = find_role_player("Murderer")
	if found then
		return found
	end
	local list = Players:GetPlayers()
	for i = 1, #list do
		local plr = list[i]
		if player_alive(plr) and has_weapon(plr, "Knife") then
			return plr
		end
	end
	return nil
end

local function named_role_player(want)
	local map = sync_roles()
	local list = Players:GetPlayers()
	for i = 1, #list do
		local plr = list[i]
		if map[plr.UserId] == want then
			return plr
		end
	end
	return nil
end

local function role_line()
	local you = last_role or local_role()
	local m = named_role_player("Murderer")
	local s = named_role_player("Sheriff")
	local m_name = m and m.Name or "--"
	local s_name = s and s.Name or "--"
	return string.format("You: %s | M: %s | S: %s", tostring(you), m_name, s_name)
end

local function announce_round_roles()
	local m = named_role_player("Murderer")
	local s = named_role_player("Sheriff")
	local m_name = m and m.Name or nil
	local s_name = s and s.Name or nil
	if m_name and m_name ~= last_m_name then
		last_m_name = m_name
		tell("Murderer: " .. m_name, "warning", 3)
		status = "murderer " .. m_name
	elseif not m_name then
		last_m_name = nil
	end
	if s_name and s_name ~= last_s_name then
		last_s_name = s_name
		tell("Sheriff: " .. s_name, "info", 3)
		if status == "idle" or string.find(tostring(status), "murderer", 1, true) then
			status = "sheriff " .. s_name
		end
	elseif not s_name then
		last_s_name = nil
	end
end

local function is_enemy(plr)
	if not player_alive(plr) then
		return false
	end
	local mine = local_role()
	local theirs = role_of(plr)
	if theirs == "Dead" then
		return false
	end
	if mine == "Murderer" then
		return theirs ~= "Murderer"
	end
	if mine == "Sheriff" then
		return theirs == "Murderer"
	end
	return theirs == "Murderer"
end

local function body_parts(plr)
	local char = plr and plr.Character
	if not char then
		return {}
	end
	local parts = {}
	for i = 1, #BODY_PARTS do
		local part = char:FindFirstChild(BODY_PARTS[i])
		if is_part(part) then
			parts[#parts + 1] = part
		end
	end
	if #parts == 0 then
		local kids = char:GetChildren()
		for i = 1, #kids do
			if is_part(kids[i]) then
				parts[#parts + 1] = kids[i]
			end
		end
	end
	return parts
end

local function enable_game_input()
	pcall(function()
		if setrobloxinput then
			setrobloxinput(true)
		end
	end)
end

local function tap_vk(code, hold)
	enable_game_input()
	pcall(function()
		keypress(code)
	end)
	task.wait(hold or 0.12)
	pcall(function()
		keyrelease(code)
	end)
end

local function backpack_slot(tool)
	local pack = LP and LP:FindFirstChild("Backpack")
	if not pack or not tool then
		return nil
	end
	local kids = pack:GetChildren()
	local n = 0
	for i = 1, #kids do
		if looks_like_tool(kids[i]) then
			n += 1
			if same(kids[i], tool) or kids[i].Name == tool.Name then
				return n
			end
		end
	end
	return nil
end

local function tool_equipped(tool)
	local char = my_char()
	if not char then
		return false
	end
	if tool then
		local held = char:FindFirstChild(tool.Name)
		if held and tool_kind(held) == tool_kind(tool) then
			return true
		end
	end
	return scan_weapon(char, tool and tool_kind(tool) or "Gun") ~= nil
end

local function menu_open()
	return menu_open_cache == true
end

local function poll_menu()
	local ok, open = pcall(function()
		return win and win.IsOpen and win:IsOpen()
	end)
	menu_open_cache = ok and open == true
	return menu_open_cache
end

local function close_menu()
	pcall(function()
		if win and win.SetOpen then
			win:SetOpen(false)
		end
	end)
end

local function equip_tool(tool, quick)
	if not tool then
		return false
	end
	if not my_char() then
		return false
	end
	if tool_equipped(tool) then
		return true
	end
	close_menu()
	enable_game_input()
	task.wait(0.1)
	if tool_equipped(tool) then
		return true
	end
	local slot = backpack_slot(tool) or 1
	if slot < 1 then
		slot = 1
	elseif slot > 9 then
		slot = 9
	end
	tap_vk(0x30 + slot, 0.16)
	task.wait(0.12)
	if tool_equipped(tool) then
		return true
	end
	if quick then
		return false
	end
	for s = 1, 9 do
		if tool_equipped(tool) then
			return true
		end
		tap_vk(0x30 + s, 0.14)
		task.wait(0.1)
	end
	return tool_equipped(tool)
end

local function as_vec3(v)
	if not v then
		return nil
	end
	local x, y, z
	local ok = pcall(function()
		x = v.X + 0
		y = v.Y + 0
		z = v.Z + 0
	end)
	if ok then
		return Vector3.new(x, y, z)
	end
	ok = pcall(function()
		local p = v.Position
		x = p.X + 0
		y = p.Y + 0
		z = p.Z + 0
	end)
	if ok then
		return Vector3.new(x, y, z)
	end
	return nil
end

local function copy_pos(value)
	return as_vec3(value)
end

local function inst_alive(obj)
	if not obj then
		return false
	end
	local ok, parent = pcall(function()
		return obj.Parent
	end)
	return ok and parent ~= nil
end

local function set_position(part, position)
	local target = copy_pos(position)
	if not part or not target then
		return false
	end
	local ok = pcall(function()
		part.Position = target
	end)
	pcall(function()
		part.AssemblyLinearVelocity = ZERO
	end)
	pcall(function()
		part.Velocity = ZERO
	end)
	return ok
end

local function is_vec3(v)
	return as_vec3(v) ~= nil
end

local function make_cf(pos, look)
	pos = as_vec3(pos)
	if not pos then
		return nil
	end
	look = as_vec3(look)
	if look then
		local ok, cf = pcall(function()
			return CFrame.lookAt(pos, look)
		end)
		if ok and cf then
			return cf
		end
		ok, cf = pcall(function()
			return CFrame.new(pos, look)
		end)
		if ok and cf then
			return cf
		end
	end
	return CFrame.new(pos.X, pos.Y, pos.Z)
end

local function aim_camera(pos)
	if not pos then
		return
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	pcall(function()
		cam.lookAt(cam.Position, pos)
	end)
	pcall(function()
		cam:lookAt(cam.Position, pos)
	end)
end

local function click_shoot()
	enable_game_input()
	pcall(function()
		mouse1click()
	end)
end

local function cf_at(pos, look)
	pos = as_vec3(pos)
	if not pos then
		return nil
	end
	if look then
		return make_cf(pos, look)
	end
	return CFrame.new(pos.X, pos.Y, pos.Z)
end

local function part_cf(part)
	if not part then
		return nil
	end
	local ok, cf = pcall(function()
		return part.CFrame
	end)
	if ok and cf then
		return cf
	end
	local pos = read_pos(part)
	return cf_at(pos)
end

local function weapon_origin(tool, look_at)
	local root = my_root()
	local root_pos = read_pos(root)
	local handle = tool and tool:FindFirstChild("Handle")
	local handle_pos = read_pos(handle)
	if handle_pos and root_pos then
		local dx = handle_pos.X - root_pos.X
		local dy = handle_pos.Y - root_pos.Y
		local dz = handle_pos.Z - root_pos.Z
		if math.sqrt(dx * dx + dy * dy + dz * dz) <= 12 then
			return part_cf(handle) or cf_at(handle_pos, look_at)
		end
	elseif handle_pos then
		return part_cf(handle) or cf_at(handle_pos, look_at)
	end
	if root then
		local att = root:FindFirstChild("GunRaycastAttachment")
		if att then
			local ok, cf = pcall(function()
				return att.WorldCFrame
			end)
			if ok and cf then
				return cf
			end
		end
		return part_cf(root) or cf_at(root_pos, look_at)
	end
	return cf_at(root_pos, look_at) or CFrame.new()
end

local function fire_remote(remote, a, b)
	if not remote then
		return false, "no remote"
	end
	local ok, err = pcall(function()
		if b ~= nil then
			remote:FireServer(a, b)
		elseif a ~= nil then
			remote:FireServer(a)
		else
			remote:FireServer()
		end
	end)
	if ok then
		return true
	end
	ok, err = pcall(function()
		if b ~= nil then
			remote:InvokeServer(a, b)
		elseif a ~= nil then
			remote:InvokeServer(a)
		else
			remote:InvokeServer()
		end
	end)
	if not ok then
		last_fire_err = err
	end
	return ok, err
end

local function read_pos(part)
	if not part then
		return nil
	end
	local pos
	pcall(function()
		pos = part.Position
	end)
	local v = as_vec3(pos)
	if v then
		return v
	end
	local cf
	pcall(function()
		cf = part.CFrame
	end)
	return as_vec3(cf)
end

local function is_player_model(model)
	if not model then
		return false
	end
	local name = model.Name
	local list = Players:GetPlayers()
	for i = 1, #list do
		local plr = list[i]
		if plr.Name == name then
			return true
		end
		local char = plr.Character
		if char and same(model, char) then
			return true
		end
	end
	return false
end

local function write_part_to(part, dest, cf)
	if not part then
		return false
	end
	local ok = false
	pcall(function()
		part.CFrame = cf
		ok = true
	end)
	pcall(function()
		part.Position = dest
		ok = true
	end)
	pcall(function()
		part.AssemblyLinearVelocity = ZERO
	end)
	pcall(function()
		part.Velocity = ZERO
	end)
	return ok
end

local function teleport_to(pos, y_off, look_at)
	pos = as_vec3(pos)
	if not pos then
		return false
	end
	local char = my_char()
	if not char then
		return false
	end
	local dest = Vector3.new(pos.X, pos.Y + (y_off or 0), pos.Z)
	local cf = look_at and make_cf(dest, look_at) or CFrame.new(dest.X, dest.Y, dest.Z)
	local wrote = false
	for i = 1, #TP_PARTS do
		local part = char:FindFirstChild(TP_PARTS[i])
		if write_part_to(part, dest, cf) then
			wrote = true
		end
	end
	local hum = get_humanoid(char)
	if hum then
		pcall(function()
			hum.WalkToPoint = dest
		end)
	end
	return wrote
end

local function restore_cf(saved)
	if not saved then
		return false
	end
	local pos = as_vec3(saved)
	if not pos then
		pcall(function()
			pos = saved.Position
		end)
		pos = as_vec3(pos)
	end
	if not pos then
		return false
	end
	local char = my_char()
	if not char then
		return false
	end
	local wrote = false
	for i = 1, #TP_PARTS do
		local part = char:FindFirstChild(TP_PARTS[i])
		if write_part_to(part, pos, saved) then
			wrote = true
		end
	end
	return wrote
end

local function write_root_cf(root, cf)
	return restore_cf(cf)
end

local function standoff_dest(plr, dist, up)
	dist = dist or cfg.gun_standoff or 6.5
	up = up or 1.85
	local char = plr and plr.Character
	local hit = get_root(char)
	local hit_pos = as_vec3(read_pos(hit))
	if not hit_pos then
		return nil
	end
	local aim = as_vec3(read_pos(get_head(char))) or hit_pos
	local look
	pcall(function()
		look = hit.CFrame.LookVector
	end)
	local ox, oz = 0, 1
	if is_vec3(look) then
		ox, oz = -look.X, -look.Z
	end
	if ox * ox + oz * oz < 1e-6 then
		local me = as_vec3(read_pos(my_root()))
		if me then
			ox, oz = me.X - hit_pos.X, me.Z - hit_pos.Z
		end
	end
	local mag = math.sqrt(ox * ox + oz * oz)
	if mag < 1e-3 then
		ox, oz, mag = 0, 1, 1
	end
	local dest = Vector3.new(hit_pos.X + ox / mag * dist, hit_pos.Y + up, hit_pos.Z + oz / mag * dist)
	return dest, aim, hit_pos
end

local function stand_off(plr)
	local dest, aim, hit_pos = standoff_dest(plr)
	if not dest then
		return nil
	end
	teleport_to(dest, 0, aim)
	return dest, aim, hit_pos
end

local function teleport_near(plr)
	local root = my_root()
	if not root then
		return nil
	end
	local saved = root.CFrame
	local dest, aim = standoff_dest(plr, 3, 1.5)
	if not dest then
		return nil
	end
	if not teleport_to(dest, 0, aim) then
		return nil
	end
	return saved
end

local function gun_fired_fallback()
	local services = ReplicatedStorage:FindFirstChild("ClientServices")
	local weapons = services and services:FindFirstChild("WeaponService")
	return weapons and weapons:FindFirstChild("GunFired")
end

local function gun_shoot_remote(tool)
	if tool then
		local direct = tool:FindFirstChild("Shoot")
		if direct then
			return direct
		end
		local events = tool:FindFirstChild("Events")
		local nested = events and events:FindFirstChild("Shoot")
		if nested then
			return nested
		end
		local named = find_named(tool, "Shoot") or find_named(tool, "Fire")
		if named then
			return named
		end
	end
	return gun_fired_fallback()
end

local function is_murderer()
	if has_weapon(LP, "Knife") then
		return true
	end
	local map = role_cache.map
	return last_role == "Murderer" or (map and map[MY_ID] == "Murderer")
end

local function is_sheriff()
	if is_murderer() then
		return false
	end
	if has_weapon(LP, "Gun") then
		return true
	end
	local map = role_cache.map
	return last_role == "Sheriff" or (map and map[MY_ID] == "Sheriff")
end

local function knife_kill(plr)
	if not player_alive(plr) then
		return false, "Invalid target"
	end
	local tool = get_weapon(LP, "Knife")
	if not tool then
		return false, "Knife missing"
	end
	if not tool_equipped(tool) then
		equip_tool(tool, true)
		tool = get_weapon(LP, "Knife") or tool
	end
	local stabbed = find_named(tool, "KnifeStabbed") or find_named(tool, "Stab")
	local touched = find_named(tool, "HandleTouched") or find_named(tool, "Touched")
	if not stabbed and not touched then
		return false, "Knife remotes missing (Hybrid Mode)"
	end
	local cycles = clamp(math.floor(cfg.knife_cycles or 2), 1, 8)
	local parts = body_parts(plr)
	local fired = 0
	for _ = 1, cycles do
		if not player_alive(plr) then
			break
		end
		if stabbed then
			fire_remote(stabbed)
		end
		for i = 1, #parts do
			if touched and fire_remote(touched, parts[i]) then
				fired += 1
			end
		end
	end
	if fired > 0 or not player_alive(plr) then
		return true, "Stabbed " .. plr.Name
	end
	return false, last_fire_err or "Stab failed (enable Hybrid Mode)"
end

local function gun_hit_parts(plr)
	local char = plr and plr.Character
	if not char then
		return {}
	end
	local parts = {}
	local seen = {}
	for i = 1, #GUN_HIT_PARTS do
		local part = char:FindFirstChild(GUN_HIT_PARTS[i])
		if is_part(part) then
			parts[#parts + 1] = part
			seen[GUN_HIT_PARTS[i]] = true
		end
	end
	if #parts == 0 then
		return body_parts(plr)
	end
	return parts
end

local function sheriff_snap(plr)
	local root = my_root()
	local hit = get_head(plr and plr.Character) or get_root(plr and plr.Character)
	local hit_pos = as_vec3(read_pos(hit))
	if not root or not hit_pos then
		return nil
	end
	local saved = root.CFrame
	local height = tonumber(cfg.gun_standoff) or 8
	if height < 4 then
		height = 4
	end
	local dest = Vector3.new(hit_pos.X, hit_pos.Y + height, hit_pos.Z)
	if not teleport_to(dest, 0) then
		return nil
	end
	teleport_to(dest, 0)
	return saved, dest, hit_pos
end

local function v3(pos)
	return as_vec3(pos)
end

local function shoot_origin_hit(from_pos, to_pos)
	local from = as_vec3(from_pos)
	local to = as_vec3(to_pos)
	if not from or not to then
		return nil, nil
	end
	local origin = make_cf(from, to)
	if not origin then
		return nil, nil
	end
	local dx, dy, dz = to.X - from.X, to.Y - from.Y, to.Z - from.Z
	local mag = math.sqrt(dx * dx + dy * dy + dz * dz)
	local hit = CFrame.new(to.X, to.Y, to.Z)
	if mag > 1e-3 then
		local look = Vector3.new(to.X + dx / mag, to.Y + dy / mag, to.Z + dz / mag)
		local ok, aimed = pcall(function()
			return CFrame.lookAt(to, look)
		end)
		if not ok or not aimed then
			ok, aimed = pcall(function()
				return CFrame.new(to, look)
			end)
		end
		if ok and aimed then
			hit = aimed
		end
	end
	return origin, hit
end

local function fire_shoot(remote, origin, hit)
	if not remote or not origin or not hit then
		return false
	end
	return fire_remote(remote, origin, hit)
end

local function gun_aim_point(plr)
	local char = plr and plr.Character
	if not char then
		return nil
	end
	local head = char:FindFirstChild("Head")
	local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	return as_vec3(read_pos(head)) or as_vec3(read_pos(root))
end

local function gun_kill(plr)
	if not player_alive(plr) then
		return false, "Invalid target"
	end
	local tool = get_weapon(LP, "Gun")
	if not tool then
		return false, "Gun missing — get the gun first"
	end
	if not tool_equipped(tool) then
		equip_tool(tool, true)
		tool = get_weapon(LP, "Gun") or tool
	end
	local shoot = gun_shoot_remote(tool)
	local extra = gun_fired_fallback()
	if extra and same(extra, shoot) then
		extra = nil
	end
	if not shoot and not extra then
		return false, "Gun Shoot remote missing (enable Hybrid Mode)"
	end
	local saved, dest = sheriff_snap(plr)
	if not dest then
		return false, "Could not teleport above target"
	end
	local shots = clamp(math.floor(cfg.gun_shots or 6), 1, 10)
	local fired = 0
	status = "Shoot " .. plr.Name
	local from = dest
	for _ = 1, shots do
		if not player_alive(plr) then
			break
		end
		local to = gun_aim_point(plr)
		if not to then
			break
		end
		local origin, hit = shoot_origin_hit(from, to)
		local origin_id = CFrame.new(from.X, from.Y, from.Z)
		local hit_id = CFrame.new(to.X, to.Y, to.Z)
		if shoot then
			if fire_shoot(shoot, origin, hit) then
				fired = fired + 1
			end
			if fire_shoot(shoot, origin_id, hit_id) then
				fired = fired + 1
			end
		end
		if extra then
			fire_shoot(extra, origin, hit)
			fire_shoot(extra, origin_id, hit_id)
		end
	end
	if cfg.restore_gun_tp ~= false and saved then
		restore_cf(saved)
	end
	if not player_alive(plr) then
		return true, "Shot " .. plr.Name
	end
	if fired > 0 then
		return true, "Fired Shoot x" .. tostring(fired)
	end
	return false, last_fire_err or "Shoot remote failed (enable Hybrid Mode)"
end

local function attack_player(plr, kind)
	if not player_alive(plr) then
		return false, "Invalid target"
	end
	if not kind then
		local role = local_role()
		if role == "Murderer" or has_weapon(LP, "Knife") then
			kind = "Knife"
		elseif role == "Sheriff" or has_weapon(LP, "Gun") then
			kind = "Gun"
		else
			return false, "Need Murderer or Sheriff"
		end
	end
	if kind == "Knife" then
		return knife_kill(plr)
	end
	return gun_kill(plr)
end

local function is_gun_drop(obj)
	if not obj then
		return false
	end
	local ok, name = pcall(function()
		return obj.Name
	end)
	return ok and name == "GunDrop"
end

local function gun_part(gun)
	if not gun then
		return nil
	end
	if is_part(gun) then
		return gun
	end
	if copy_pos(gun.Position) then
		return gun
	end
	local handle = gun:FindFirstChild("Handle")
	if handle then
		return handle
	end
	if gun.PrimaryPart then
		return gun.PrimaryPart
	end
	local kids = gun:GetChildren()
	for i = 1, #kids do
		local child = kids[i]
		if is_part(child) or copy_pos(child.Position) then
			return child
		end
	end
	return gun
end

local function get_map()
	local kids = Workspace:GetChildren()
	for i = 1, #kids do
		local child = kids[i]
		if child.ClassName == "Model" and child:FindFirstChild("CoinContainer") then
			return child
		end
	end
end

local function get_map_gun(map)
	map = map or stored.Map
	if not map then
		return nil
	end
	local ok, kids = pcall(function()
		return map:GetChildren()
	end)
	if not ok or not kids then
		return nil
	end
	for i = 1, #kids do
		if is_gun_drop(kids[i]) then
			return kids[i]
		end
	end
end

local function set_stored_gun(gun)
	if gun and not inst_alive(gun) then
		gun = nil
	end
	stored.Gun = gun
end

local function scan_gun_async()
	if stored.ScanningGun then
		return
	end
	stored.ScanningGun = true
	task.spawn(function()
		local map = stored.Map
		local found = get_map_gun(map)
		if not found and map then
			local ok, desc = pcall(function()
				return map:GetDescendants()
			end)
			if ok and desc then
				for i = 1, #desc do
					if is_gun_drop(desc[i]) then
						found = desc[i]
						break
					end
					if i % 40 == 0 then
						task.wait()
					end
				end
			end
		end
		if found then
			set_stored_gun(found)
		elseif not inst_alive(stored.Gun) then
			stored.Gun = nil
		end
		stored.ScanningGun = false
	end)
end

local function refresh_world()
	local map = get_map()
	if addr(map) ~= addr(stored.Map) then
		stored.Map = map
		stored.Gun = nil
		if map then
			scan_gun_async()
		end
		return
	end
	if not inst_alive(stored.Gun) then
		set_stored_gun(get_map_gun(map))
		if not stored.Gun then
			scan_gun_async()
		end
	end
end

local function find_dropped_gun()
	refresh_world()
	if not inst_alive(stored.Gun) then
		set_stored_gun(get_map_gun())
	end
	local gun = stored.Gun
	if not inst_alive(gun) then
		return nil, nil
	end
	return gun, gun_part(gun)
end

local function has_local_gun()
	return has_weapon(LP, "Gun")
end

local function get_gun()
	if has_local_gun() then
		return true, "You already have the gun"
	end
	if stored.Grabbing then
		return false, "Already grabbing"
	end
	local gun = select(1, find_dropped_gun())
	local root = my_root()
	if not gun or not root then
		if not gun then
			scan_gun_async()
			return false, "No dropped gun found"
		end
		return false, "Character not ready"
	end
	local gun_pos = copy_pos(gun.Position) or read_pos(gun_part(gun))
	if not gun_pos then
		return false, "No dropped gun found"
	end

	stored.Grabbing = true
	local return_to
	local camera = Workspace.CurrentCamera
	local camera_cf
	if cfg.position_track ~= false then
		return_to = copy_pos(root.Position)
		stored.OldPosition = return_to
		if camera then
			pcall(function()
				local cf = camera.CFrame
				camera_cf = CFrame.new(cf:GetComponents())
			end)
		end
	end

	status = string.format("tp gun %.0f,%.0f,%.0f", gun_pos.X, gun_pos.Y, gun_pos.Z)
	set_position(root, Vector3.new(gun_pos.X, gun_pos.Y + GUN_PICKUP_HEIGHT, gun_pos.Z))

	if not return_to then
		stored.Grabbing = false
		if has_local_gun() then
			return true, "Got the gun"
		end
		return true, "Teleported to gun"
	end

	task.wait()
	local current = my_root()
	if current then
		set_position(current, return_to)
	end
	if camera and camera_cf then
		pcall(function()
			camera.CFrame = camera_cf
		end)
	end
	stored.Grabbing = false
	if has_local_gun() then
		return true, "Got the gun"
	end
	return true, "Teleported to gun"
end

local function run_job(fn)
	if busy then
		status = "busy"
		return
	end
	busy = true
	task.spawn(function()
		local ok, msg = fn()
		busy = false
		status = msg or (ok and "ok" or "fail")
		tell(status, ok and "success" or "warning", 2)
	end)
end

local function kill_sheriff()
	run_job(function()
		local sheriff = get_sheriff()
		if not sheriff then
			return false, "No sheriff found"
		end
		local ok, msg = attack_player(sheriff, "Knife")
		return ok, ok and ("Killed sheriff " .. sheriff.Name) or msg
	end)
end

local function kill_murderer()
	run_job(function()
		local murderer = get_murderer()
		if not murderer then
			return false, "No murderer found"
		end
		local ok, msg = attack_player(murderer, "Gun")
		return ok, ok and ("Shot murderer " .. murderer.Name) or msg
	end)
end

local function kill_selected(kind)
	run_job(function()
		local names = selected_list()
		if #names == 0 then
			return false, "Select a player first"
		end
		local killed = 0
		for i = 1, #names do
			local plr = player_by_name(names[i])
			if plr and player_alive(plr) then
				local ok = attack_player(plr, kind)
				if ok then
					killed += 1
				end
			end
		end
		return killed > 0, string.format("Attacked %d/%d selected", killed, #names)
	end)
end

local function kill_all()
	run_job(function()
		local targets = {}
		local list = Players:GetPlayers()
		for i = 1, #list do
			if is_enemy(list[i]) then
				targets[#targets + 1] = list[i]
			end
		end
		if #targets == 0 then
			return false, "No living targets"
		end
		local killed = 0
		for i = 1, #targets do
			local ok = attack_player(targets[i], "Knife")
			if ok then
				killed += 1
			end
		end
		return killed > 0, string.format("Kill All: %d/%d", killed, #targets)
	end)
end

local function grab_gun()
	run_job(function()
		return get_gun()
	end)
end

local function dist_of(part, origin)
	origin = as_vec3(origin)
	local pos = as_vec3(read_pos(part))
	if not pos or not origin then
		return 0
	end
	local dx, dy, dz = pos.X - origin.X, pos.Y - origin.Y, pos.Z - origin.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function screen_xy(part)
	if not part then
		return nil, nil
	end
	local pos = copy_pos(part.Position)
	if not pos then
		return nil, nil
	end
	local screen, visible
	local ok = pcall(function()
		screen, visible = WorldToScreen(pos)
	end)
	if not ok or not visible or not screen then
		return nil, nil
	end
	local x, y
	local good = pcall(function()
		x = screen.X + 0
		y = screen.Y + 0
	end)
	if not good or (x == 0 and y == 0) then
		return nil, nil
	end
	return x, y
end

local function collect_esp()
	local guns_out = {}
	if not cfg.esp_guns then
		esp_guns = guns_out
		return
	end
	local gun = stored.Gun
	if not inst_alive(gun) then
		esp_guns = guns_out
		return
	end
	local part = gun_part(gun) or gun
	local origin = my_root()
	local origin_pos = copy_pos(origin and origin.Position)
	guns_out[1] = {
		name = "Gun",
		part = part,
		dist = origin_pos and dist_of(part, origin_pos) or 0,
		color = cfg.color_gun,
	}
	esp_guns = guns_out
end

local function make_gun_slot()
	local box = Drawing.new("Square")
	box.Thickness = 2
	box.Filled = false
	box.ZIndex = 8
	box.Visible = false
	local tag = Drawing.new("Text")
	tag.Size = 14
	tag.Center = true
	tag.Outline = true
	tag.ZIndex = 9
	tag.Visible = false
	return { box = box, tag = tag }
end

local function hide_slot(slot)
	slot.box.Visible = false
	slot.tag.Visible = false
end

local function destroy_slot(slot)
	pcall(function()
		slot.box:Remove()
		slot.tag:Remove()
	end)
end

local function hide_all_esp()
	for i = 1, #gun_pool do
		hide_slot(gun_pool[i])
	end
end

local function setup_esp()
	for i = 1, GUN_POOL do
		gun_pool[i] = make_gun_slot()
	end
	collect_running = true
	task.spawn(function()
		while running and collect_running do
			pcall(refresh_world)
			if cfg.auto_get_gun and stored.Gun and not stored.Grabbing and not has_local_gun() and not busy then
				grab_gun()
			end
			if cfg.esp_guns then
				pcall(collect_esp)
			else
				esp_guns = {}
			end
			task.wait(0.4)
		end
	end)
	render_conn = bind(RunService.RenderStepped, function()
		if not cfg.esp_guns then
			if not esp_suppressed then
				esp_suppressed = true
				hide_all_esp()
			end
			return
		end
		esp_suppressed = false
		local guns = esp_guns
		local g = 0
		for i = 1, #guns do
			if g >= GUN_POOL then
				break
			end
			local t = guns[i]
			local part = t and t.part
			if part then
				local x, y = screen_xy(part)
				if x and y then
					g = g + 1
					local e = gun_pool[g]
					if e then
						local size = clamp(1800 / math.max(t.dist or 20, 8), 16, 42)
						local color = t.color or COLOR_GUN
						e.box.Size = Vector2.new(size, size)
						e.box.Position = Vector2.new(x - size * 0.5, y - size * 0.5)
						e.box.Color = color
						e.box.Visible = cfg.esp_box ~= false
						local label = "Gun"
						if cfg.esp_dist ~= false then
							label = string.format("Gun [%.0f]", t.dist or 0)
						end
						e.tag.Text = label
						e.tag.Color = color
						e.tag.Position = Vector2.new(x, y - size * 0.5 - 14)
						e.tag.Visible = cfg.esp_name ~= false
					end
				end
			end
		end
		for i = g + 1, GUN_POOL do
			hide_slot(gun_pool[i])
		end
	end, "RenderStepped")
end

local function keep_row(list, row)
	if row then
		list[#list + 1] = row
	end
	return row
end

local function lock_rows(rows, locked)
	for i = 1, #rows do
		pcall(function()
			rows[i]:SetLocked(locked)
		end)
	end
end

local function gate_role_ui()
	if ui_role.last == "ALL" then
		return
	end
	ui_role.last = "ALL"
	lock_rows(ui_role.murderer, false)
	lock_rows(ui_role.sheriff_kill, false)
	lock_rows(ui_role.get_gun, false)
	pcall(function()
		if ui_role.murderer_section then
			ui_role.murderer_section.Desc = "KnifeStabbed + HandleTouched — no teleport"
		end
		if ui_role.sheriff_section then
			ui_role.sheriff_section.Desc = "teleport + Gun.Shoot"
		end
	end)
end

local function load_ui()
	local result
	for i = 1, #INS_UI_URLS do
		local ok_load, loaded = pcall(function()
			local src = http_get(INS_UI_URLS[i])
			if not src then
				error("empty")
			end
			return loadstring(src)()
		end)
		if ok_load and loaded then
			result = loaded
			break
		end
	end
	Lib = result or INSUI or INSui
	if not Lib then
		error("[Gunkin-Ware] INSUI failed to load — check HttpGet / INSUI global")
	end

	win = Lib:CreateWindow({
		title = SCRIPT_NAME,
		subtitle = "Murder Mystery 2",
		size = Vector2.new(680, 530),
		menuKey = "p",
		configName = "gunkin_ware_mm2",
		configFolder = "gunkin_ware_mm2",
		autoSave = true,
		checkboxStyle = true,
		smartFps = true,
		keybindOverlay = false,
		startOpen = true,
		opacity = 0.97,
		font = "Proxima",
		theme = { accent = Color3.fromRGB(255, 72, 92) },
		accentA = Color3.fromRGB(255, 72, 92),
		accentB = Color3.fromRGB(80, 140, 255),
		backgroundEffect = "Off",
		spotlight = false,
	})

	pcall(function()
		win:AddSettingsTab("cog")
	end)
	pcall(function()
		Lib:SetPerformance(true)
	end)

	pcall(function()
		if cfg.status_box then
			status_box = Lib:CreateBox({
				title = SCRIPT_NAME,
				position = Vector2.new(18, 120),
				width = 260,
			})
			if status_box then
				status_lines = {
					status_box:Stat("role: --"),
					status_box:Stat("status: boot"),
					status_box:Text("targets —"),
				}
				status_box:SetVisible(true)
			end
		end
	end)

	Lib:Category("RAGE")
	local tab = win:Tab("Rage", "crosshair")

	local rage = tab:Section("Rage", "Left", "murderer stabs, sheriff shoots")
	local auto_toggle = rage:Toggle("Auto Rage", false, function(on)
		if ignore_auto then
			cfg.auto = false
			return
		end
		cfg.auto = on == true
		if cfg.auto then
			status = "auto on"
			tell("auto rage on", "success", 2)
		else
			status = "idle"
		end
	end)
	auto_handle = auto_toggle
	pcall(function()
		auto_toggle:SetRisk()
	end)
	ui_role.auto_kill_all = rage:Toggle("Auto Kill All (Murderer)", false, function(on)
		cfg.auto_kill_all = on == true
	end)
	pcall(function()
		ui_role.auto_kill_all:SetRisk()
	end)
	keep_row(ui_role.murderer, ui_role.auto_kill_all)
	ui_role.auto_get_gun = rage:Toggle("Auto Get Gun", false, function(on)
		cfg.auto_get_gun = on == true
	end)
	keep_row(ui_role.get_gun, ui_role.auto_get_gun)
	rage:Info("Auto uses your current role only. Murderer stabs (no TP). Sheriff stands off and shoots.")
	rage:Slider("Auto Wait", 0.35, 0.05, 0.15, 1.5, "s", function(v)
		cfg.auto_wait = tonumber(v) or 0.35
	end)

	local murderer = tab:Section("Murderer", "Left", "KnifeStabbed + HandleTouched — no teleport")
	ui_role.murderer_section = murderer
	keep_row(
		ui_role.murderer,
		murderer:Button("Kill Sheriff", function()
			kill_sheriff()
		end)
	)
	keep_row(
		ui_role.murderer,
		murderer
			:Button("Kill All", function()
				kill_all()
			end)
			:AddButton("Kill Selected", function()
				kill_selected("Knife")
			end)
	)
	keep_row(
		ui_role.murderer,
		murderer:Slider("Knife Cycles", 8, 1, 1, 8, "x", function(v)
			cfg.knife_cycles = math.floor(tonumber(v) or 8)
		end)
	)

	local sheriff = tab:Section("Sheriff", "Right", "teleport + Gun.Shoot")
	ui_role.sheriff_section = sheriff
	keep_row(
		ui_role.get_gun,
		sheriff:Button("Get Gun", function()
			grab_gun()
		end)
	)
	keep_row(
		ui_role.sheriff_kill,
		sheriff
			:Button("Kill Murderer", function()
				kill_murderer()
			end)
			:AddButton("Kill Selected", function()
				kill_selected("Gun")
			end)
	)
	keep_row(ui_role.sheriff_kill, sheriff:Info("Snaps above their head, then Gun.Shoot(origin, hit) straight down. Hybrid Mode required."))
	keep_row(
		ui_role.sheriff_kill,
		sheriff:Toggle("Restore After TP", true, function(on)
			cfg.restore_gun_tp = on == true
		end)
	)
	keep_row(
		ui_role.get_gun,
		sheriff:Toggle("Position Track", true, function(on)
			cfg.position_track = on == true
			cfg.restore_get_gun = on == true
		end)
	)
	keep_row(
		ui_role.sheriff_kill,
		sheriff:Slider("Gun Shots", 6, 1, 1, 10, "x", function(v)
			cfg.gun_shots = math.floor(tonumber(v) or 6)
		end)
	)
	keep_row(
		ui_role.sheriff_kill,
		sheriff:Slider("Height Above", 8, 0.5, 4, 16, "st", function(v)
			cfg.gun_standoff = tonumber(v) or 8
		end)
	)

	local players = tab:Section("Targets", "Right", "multi-select — refresh on leave")
	targets_dd = players:Dropdown("Players", {}, player_names(), true, function(v)
		set_targets_from_list(v)
		status = "targets: " .. selected_text()
	end, "pick one or more players", false)
	players
		:Button("Select All", function()
			local all = player_names()
			set_targets_from_list(all)
			pcall(function()
				targets_dd:Set(all)
			end)
		end)
		:AddButton("Clear", function()
			set_targets_from_list({})
			pcall(function()
				targets_dd:Set({})
			end)
		end)
	players:Button("Refresh", function()
		pcall(function()
			if targets_dd.UpdateChoices then
				targets_dd:UpdateChoices(player_names())
			else
				targets_dd:Refresh()
			end
		end)
		prune_selected()
		tell("player list refreshed", "success", 2)
	end)
	ui_labels.selected = players:Label("Selected: (none)")
	ui_labels.role = players:Label("Role: --")
	ui_labels.status = players:Label("Status: idle")
	players:Toggle("Status Box", true, function(on)
		cfg.status_box = on == true
		pcall(function()
			if status_box then
				status_box:SetVisible(cfg.status_box)
			end
		end)
	end)

	Lib:Category("VISUALS")
	local vis = win:Tab("Visuals", "eye")
	local esp = vis:Section("ESP", "Left", "dropped guns only")
	esp:Toggle("Dropped Gun ESP", true, function(on)
		cfg.esp_guns = on == true
	end)
	esp:Colorpicker("Gun Color", COLOR_GUN, function(c)
		cfg.color_gun = c or COLOR_GUN
	end)

	local draw = vis:Section("Draw", "Right")
	draw:Toggle("Boxes", true, function(on)
		cfg.esp_box = on == true
	end)
	draw:Toggle("Names", true, function(on)
		cfg.esp_name = on == true
	end)
	draw:Toggle("Distance", true, function(on)
		cfg.esp_dist = on == true
	end)
	draw:Info("P opens the menu. Close it to see gun ESP. Get Gun uses the map GunDrop. Position Track returns you after pickup.")

	pcall(function()
		Lib:Notify(SCRIPT_NAME, "loaded — Hybrid Mode for remotes", 3, "success")
	end)
	gate_role_ui()
end

local function refresh_status_box()
	if not status_box or not status_lines then
		return
	end
	pcall(function()
		status_box:SetVisible(cfg.status_box and not menu_open())
	end)
	local key = tostring(last_role) .. "|" .. tostring(status) .. "|" .. selected_text() .. "|" .. tostring(last_m_name) .. "|" .. tostring(last_s_name)
	if key == last_box_key then
		return
	end
	last_box_key = key
	pcall(function()
		status_lines[1].Value = role_line()
		status_lines[2].Value = "status: " .. tostring(status)
		status_lines[3].Value = "targets: " .. selected_text()
	end)
end

local function set_label(handle, text)
	if not handle then
		return
	end
	pcall(function()
		if handle.SetText then
			handle:SetText(text)
		elseif handle.Set then
			handle:Set(text)
		else
			handle.Value = text
		end
	end)
end

local last_label_key = ""

local function refresh_ui_labels()
	local key = selected_text() .. "|" .. tostring(last_role) .. "|" .. tostring(status)
	if key == last_label_key then
		gate_role_ui()
		return
	end
	last_label_key = key
	set_label(ui_labels.selected, "Selected: " .. selected_text())
	set_label(ui_labels.role, role_line())
	set_label(ui_labels.status, "Status: " .. tostring(status))
	gate_role_ui()
end

local function auto_tick()
	if not cfg.auto or busy then
		return
	end
	if is_murderer() then
		if cfg.auto_kill_all then
			kill_all()
		else
			kill_sheriff()
		end
		return
	end
	if is_sheriff() then
		kill_murderer()
		return
	end
	if cfg.auto_get_gun and not stored.Grabbing and find_dropped_gun() then
		grab_gun()
	end
end

local function unload()
	running = false
	collect_running = false
	cfg.auto = false
	busy = false
	for i = 1, #connections do
		pcall(function()
			connections[i]:Disconnect()
		end)
	end
	connections = {}
	if render_conn then
		pcall(function()
			render_conn:Disconnect()
		end)
		render_conn = nil
	end
	for i = 1, #gun_pool do
		destroy_slot(gun_pool[i])
	end
	gun_pool = {}
	pcall(function()
		if status_box and status_box.Remove then
			status_box:Remove()
		end
	end)
	pcall(function()
		if win then
			win:Destroy()
		end
	end)
	pcall(function()
		if Lib and Lib.Destroy then
			Lib:Destroy()
		end
	end)
	_G.mm2_rage_unload = nil
end

_G.mm2_rage_unload = unload

load_ui()
menu_open_cache = true
pcall(poll_menu)
cfg.auto = false
pcall(function()
	if auto_handle and auto_handle.Set then
		auto_handle:Set(false)
	end
end)
task.spawn(function()
	task.wait(0.25)
	cfg.auto = false
	pcall(function()
		if auto_handle and auto_handle.Set then
			auto_handle:Set(false)
		end
	end)
	task.wait(0.6)
	cfg.auto = false
	pcall(function()
		if auto_handle and auto_handle.Set then
			auto_handle:Set(false)
		end
	end)
	ignore_auto = false
end)
pcall(setup_esp)
status = "idle"

local auto_accum = 0
local ui_accum = 0
local menu_poll_t = 0
bind(RunService.Heartbeat, function(dt)
	if not running then
		return
	end
	dt = dt or 0.016
	menu_poll_t += dt
	if menu_poll_t >= 0.2 then
		menu_poll_t = 0
		poll_menu()
	end
	if menu_open_cache then
		auto_accum = 0
		ui_accum = 0
		return
	end
	ui_accum += dt
	if ui_accum >= 1.25 then
		ui_accum = 0
		local_role()
		refresh_ui_labels()
	end
	if not cfg.auto then
		auto_accum = 0
		return
	end
	auto_accum += dt
	if auto_accum < (cfg.auto_wait or 0.35) then
		return
	end
	auto_accum = 0
	auto_tick()
end, "Heartbeat")
