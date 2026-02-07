local function deleteConfig(name)
	if not isfolder or not isfile or not delfile then return end
	local path = "lemon_lua/configs/" .. name .. ".json"
	if isfile(path) then delfile(path) end
end

local function getConfigList()
	local list = {"none"}
	if not isfolder or not listfiles then return list end
	if not isfolder("lemon_lua/configs") then return list end
	for _, file in listfiles("lemon_lua/configs") do
		local name = file:match("([^/\\]+)%.json$")
		if name then table.insert(list, name) end
	end
	return list
end

local function saveCurrentConfig(name)
	if not isfolder or not writefile then return end
	if not isfolder("lemon_lua") then makefolder("lemon_lua") end
	if not isfolder("lemon_lua/configs") then makefolder("lemon_lua/configs") end
	local data = {}
	for key, val in pairs(cfg) do
		if typeof(val) == "boolean" or typeof(val) == "number" or typeof(val) == "string" then
			data[key] = val
		elseif typeof(val) == "Color3" then
			data[key] = {R = math.floor(val.R * 255), G = math.floor(val.G * 255), B = math.floor(val.B * 255), _type = "Color3"}
		elseif typeof(val) == "EnumItem" then
			data[key] = {_type = "EnumItem", _enum = tostring(val.EnumType), _value = val.Name}
		end
	end
	data._skinConfig = weaponSkinConfig
	data._knifeGloveMapping = knifeGloveMapping
	writefile("lemon_lua/configs/" .. name .. ".json", HttpService:JSONEncode(data))
end

local function loadConfig(name)
	if not isfile then return end
	local path = "lemon_lua/configs/" .. name .. ".json"
	if not isfile(path) then return end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
	if not ok or not data then return end
	for key, val in pairs(data) do
		if key == "_skinConfig" then
			if type(val) == "table" then weaponSkinConfig = val end
		elseif key == "_knifeGloveMapping" then
			if type(val) == "table" then knifeGloveMapping = val end
		elseif type(val) == "table" and val._type == "Color3" then
			cfg[key] = Color3.fromRGB(val.R, val.G, val.B)
		elseif type(val) == "table" and val._type == "EnumItem" then
			pcall(function() cfg[key] = Enum[val._enum][val._value] end)
		else
			if cfg[key] ~= nil then cfg[key] = val end
		end
	end
	-- Re-apply all settings
	setupHitsound(); setupBhop(); setupRiskyBhop(); setupAntiFlash(); setupSmoke()
	setupNightMode(); setupFOV(); setupSpeed(); setupThirdPerson()
	setupNoScopeSway(); setupInstantScope(); setupQuickscope(); setupBombTimer()
	setupAntiAim(); setupAutoStrafe(); setupEdgeJump(); setupRapidfire()
	setupDesync(); setupGunChams(); setupCharacterChanger()
	if cfg.skinChangerEnabled then forceReequipWeapon() end
	if cfg.skyboxEnabled then applySkybox(cfg.skyboxSelected) end
end

local function saveConfigs() end
local function loadConfigs() end

local function initializeScript()
	initializeSkinChanger()
	setupCharacterChanger()
	setupHitsound()

	conns.mouseClick = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and cfg.bulletTracerEnabled then
			task.defer(function()
				local char = LocalPlayer.Character; if not char then return end
				local weapon = Camera:FindFirstChildWhichIsA("Model")
				local muzzle = weapon and weapon:FindFirstChild("Muzzle", true)
				local origin = muzzle and muzzle.WorldPosition or Camera.CFrame.Position
				local mouseHit = LocalPlayer:GetMouse().Hit.Position
				local rayParams = RaycastParams.new()
				rayParams.FilterDescendantsInstances = {char, Workspace:FindFirstChild("Debris")}
				rayParams.FilterType = Enum.RaycastFilterType.Exclude
				local direction = (mouseHit - origin).Unit * 1000
				local result = Workspace:Raycast(origin, direction, rayParams)
				createBulletTracer(origin, result and result.Position or (origin + direction))
			end)
		end
	end)

	task.spawn(function() while true do currentPing = mathFloor(LocalPlayer:GetNetworkPing() * 1000); task.wait(0.5) end end)

	conns.render = RunService.RenderStepped:Connect(function(dt)
		currentFps = mathFloor(1 / dt)
		cameraPosition = Camera.CFrame.Position; cameraCFrame = Camera.CFrame
		viewportSize = Camera.ViewportSize; viewportSizeCenter = viewportSize / 2
		
		if cfg.aimEnabled and UserInputService:IsKeyDown(cfg.aimKey) then moveMouseToTarget(getClosestTarget()) end
		checkTriggerbot()
		
		if cfg.fovEnabled and cfg.aimEnabled then
			fovCircle.Position = viewportSizeCenter
			fovCircle.Radius = cfg.fovSize; fovCircle.Color = cfg.fovColor; fovCircle.Visible = true
		else fovCircle.Visible = false end
		
		if cfg.espEnabled then for _, esp in espObjects do esp:update() end else for _, esp in espObjects do esp:hide() end end
		for _, player in Players:GetPlayers() do updateHitbox(player); updateGlow(player); updateSkeleton(player) end
		if cfg.xrayEnabled then applyViewmodelXray() end
		updateSpreadCircle(); updateBombTimer(); updateDroppedWeaponESP()
		
		updateSpectators()
		
		-- Update Library watermark
		if cfg.watermarkEnabled then
			local parts = {}
			if cfg.watermarkName then table.insert(parts, LocalPlayer.Name) end
			if cfg.watermarkFps then table.insert(parts, "fps " .. currentFps) end
			if cfg.watermarkPing then table.insert(parts, "ping " .. currentPing .. "ms") end
			Library:SetWatermark("lemon.lua | " .. table.concat(parts, " | "))
		else
			Library:SetWatermarkVisibility(false)
		end
		
		-- Spectators via watermark or small label
		if cfg.spectatorsWindowEnabled and #spectatorsList > 0 then
			-- spectators are shown in the built-in keybind-style frame via custom label
		end
		
		for i = #bulletTracers, 1, -1 do
			local tracer = bulletTracers[i]
			local alpha = 1 - ((tick() - tracer.startTime) / cfg.bulletTracerDuration)
			if alpha <= 0 then
				if tracer.beam then tracer.beam:Destroy() end
				if tracer.part0 then tracer.part0:Destroy() end
				if tracer.part1 then tracer.part1:Destroy() end
				table.remove(bulletTracers, i)
			elseif tracer.beam then tracer.beam.Transparency = NumberSequence.new(1 - alpha) end
		end
	end)

	loadConfigs(); setupNoScopeSway(); setupInstantScope(); setupQuickscope(); setupBombTimer()
	setupAntiAim(); setupAutoStrafe(); setupEdgeJump(); setupRapidfire()

	-- ═══════════════════════════════════════════════════
	-- LINORIA UI CREATION
	-- ═══════════════════════════════════════════════════

	local Window = Library:CreateWindow({
		Title = 'lemon.lua',
		Center = true,
		AutoShow = true,
		TabPadding = 1,
		MenuFadeTime = 0.15,
	})

	local Tabs = {
		Combat = Window:AddTab('Combat'),
		Visuals = Window:AddTab('Visuals'),
		Misc = Window:AddTab('Misc'),
		['Skin Changer'] = Window:AddTab('Skin Changer'),
		Settings = Window:AddTab('Settings'),
	}

	-- ═══════════════════════════════════════════════════
	-- COMBAT TAB
	-- ═══════════════════════════════════════════════════
	do
		local LeftGroup = Tabs.Combat:AddLeftGroupbox('Soft Aim')
		LeftGroup:AddToggle('aimEnabled', { Text = 'Enable', Default = cfg.aimEnabled, Callback = function(v) cfg.aimEnabled = v end })
			:AddKeyPicker('aimKey', { Default = cfg.aimKey, Text = 'Aim Key', SyncToggleState = false, Mode = 'Hold',
				Callback = function(v) end, ChangedCallback = function(key) cfg.aimKey = key end })

		LeftGroup:AddSlider('aimSmooth', { Text = 'Smoothness', Default = 15, Min = 1, Max = 100, Rounding = 0,
			Callback = function(v) cfg.aimSmooth = v / 100 end })
		LeftGroup:AddSlider('aimFOV', { Text = 'FOV Size', Default = 200, Min = 50, Max = 500, Rounding = 0,
			Callback = function(v) cfg.aimFOV = v; cfg.fovSize = v end })
		LeftGroup:AddToggle('aimVisCheck', { Text = 'Visible Check', Default = cfg.aimVisCheck, Callback = function(v) cfg.aimVisCheck = v end })
		LeftGroup:AddToggle('fovEnabled', { Text = 'Show FOV Circle', Default = cfg.fovEnabled, Callback = function(v) cfg.fovEnabled = v end })
			:AddColorPicker('fovColor', { Default = cfg.fovColor, Title = 'FOV Color', Callback = function(c) cfg.fovColor = c end })
		LeftGroup:AddDropdown('aimPart', { Text = 'Body Part', Default = cfg.aimPart,
			Values = {"head", "upper torso", "lower torso", "closest", "random"},
			Callback = function(v) cfg.aimPart = v end })

		-- Triggerbot
		local RightGroup = Tabs.Combat:AddRightGroupbox('Triggerbot')
		RightGroup:AddToggle('triggerEnabled', { Text = 'Enable', Default = cfg.triggerEnabled, Callback = function(v) cfg.triggerEnabled = v end })
		RightGroup:AddSlider('triggerDelay', { Text = 'Delay (ms)', Default = cfg.triggerDelay, Min = 0, Max = 500, Rounding = 0,
			Callback = function(v) cfg.triggerDelay = v end })
		RightGroup:AddSlider('triggerChance', { Text = 'Chance (%)', Default = cfg.triggerChance, Min = 1, Max = 100, Rounding = 0,
			Callback = function(v) cfg.triggerChance = v end })
		RightGroup:AddToggle('triggerSmoke', { Text = 'Shoot Through Smoke', Default = cfg.triggerShootThroughSmoke,
			Callback = function(v) cfg.triggerShootThroughSmoke = v end })

		-- Rapidfire
		local RapidGroup = Tabs.Combat:AddLeftGroupbox('Rapidfire')
		RapidGroup:AddToggle('rapidfireEnabled', { Text = 'Enable', Default = cfg.rapidfireEnabled,
			Callback = function(v) cfg.rapidfireEnabled = v; setupRapidfire() end })
		RapidGroup:AddSlider('rapidfireDelay', { Text = 'Delay (ms)', Default = cfg.rapidfireDelay, Min = 10, Max = 200, Rounding = 0,
			Callback = function(v) cfg.rapidfireDelay = v end })

		-- Weapon
		local WeaponGroup = Tabs.Combat:AddRightGroupbox('Weapon')
		WeaponGroup:AddToggle('noScopeSwayEnabled', { Text = 'No Scope Sway', Default = cfg.noScopeSwayEnabled,
			Callback = function(v) cfg.noScopeSwayEnabled = v; setupNoScopeSway() end })
		WeaponGroup:AddToggle('instantScopeEnabled', { Text = 'Instant Scope', Default = cfg.instantScopeEnabled,
			Callback = function(v) cfg.instantScopeEnabled = v; setupInstantScope() end })
		WeaponGroup:AddToggle('quickscopeEnabled', { Text = 'Quickscope', Default = cfg.quickscopeEnabled,
			Callback = function(v) cfg.quickscopeEnabled = v; setupQuickscope() end })
		WeaponGroup:AddSlider('quickscopeDelay', { Text = 'QS Delay (ms)', Default = cfg.quickscopeDelay, Min = 0, Max = 200, Rounding = 0,
			Callback = function(v) cfg.quickscopeDelay = v end })

		-- Hitbox
		local HitboxGroup = Tabs.Combat:AddLeftGroupbox('Hitbox')
		HitboxGroup:AddToggle('hitboxEnabled', { Text = 'Enable', Default = cfg.hitboxEnabled,
			Callback = function(v) cfg.hitboxEnabled = v end })
		HitboxGroup:AddSlider('hitboxSize', { Text = 'Size', Default = cfg.hitboxSize, Min = 1, Max = 5, Rounding = 0,
			Callback = function(v) cfg.hitboxSize = v end })

		-- Recoil Control
		local RCSGroup = Tabs.Combat:AddRightGroupbox('Recoil Control')
		RCSGroup:AddToggle('rcsEnabled', { Text = 'Enable', Default = cfg.rcsEnabled,
			Callback = function(v) cfg.rcsEnabled = v; setupRCS() end })
		RCSGroup:AddSlider('rcsStrength', { Text = 'Strength', Default = math.floor(cfg.rcsStrength), Min = 1, Max = 10, Rounding = 0,
			Callback = function(v) cfg.rcsStrength = v end })

		-- Rage
		local RageGroup = Tabs.Combat:AddRightGroupbox('Rage')
		RageGroup:AddToggle('antiAimEnabled', { Text = 'Anti-Aim', Default = cfg.antiAimEnabled, Risky = true,
			Callback = function(v) cfg.antiAimEnabled = v; setupAntiAim() end })
		RageGroup:AddDropdown('antiAimMode', { Text = 'AA Mode', Default = cfg.antiAimMode,
			Values = {"Spin", "Jitter", "Random", "Sideways", "Backwards"},
			Callback = function(v) cfg.antiAimMode = v end })
		RageGroup:AddSlider('antiAimSpeed', { Text = 'AA Speed', Default = cfg.antiAimSpeed, Min = 1, Max = 50, Rounding = 0,
			Callback = function(v) cfg.antiAimSpeed = v end })
	end

	-- ═══════════════════════════════════════════════════
	-- VISUALS TAB
	-- ═══════════════════════════════════════════════════
	do
		local ESPGroup = Tabs.Visuals:AddLeftGroupbox('ESP')
		ESPGroup:AddToggle('espEnabled', { Text = 'Enable', Default = cfg.espEnabled, Callback = function(v) cfg.espEnabled = v end })
		ESPGroup:AddToggle('espBoxes', { Text = 'Boxes', Default = cfg.espBoxes, Callback = function(v) cfg.espBoxes = v end })
			:AddColorPicker('espBoxColor', { Default = cfg.espBoxColor, Title = 'Box Color', Callback = function(c) cfg.espBoxColor = c end })
		ESPGroup:AddDropdown('boxType', { Text = 'Box Type', Default = cfg.boxType,
			Values = {"box", "highlight"}, Callback = function(v) cfg.boxType = v end })
		ESPGroup:AddToggle('espNames', { Text = 'Names', Default = cfg.espNames, Callback = function(v) cfg.espNames = v end })
			:AddColorPicker('espNamesColor', { Default = cfg.espNamesColor, Title = 'Name Color', Callback = function(c) cfg.espNamesColor = c end })
		ESPGroup:AddToggle('espDistance', { Text = 'Distance', Default = cfg.espDistance, Callback = function(v) cfg.espDistance = v end })
		ESPGroup:AddToggle('espState', { Text = 'State', Default = cfg.espState, Callback = function(v) cfg.espState = v end })
		ESPGroup:AddToggle('espTracers', { Text = 'Tracers', Default = cfg.espTracers, Callback = function(v) cfg.espTracers = v end })
			:AddColorPicker('espTracerColor', { Default = cfg.espTracerColor, Title = 'Tracer Color', Callback = function(c) cfg.espTracerColor = c end })
		ESPGroup:AddToggle('espHealth', { Text = 'Health Bars', Default = cfg.espHealth, Callback = function(v) cfg.espHealth = v end })
		ESPGroup:AddToggle('espSkeleton', { Text = 'Skeleton', Default = cfg.espSkeleton, Callback = function(v) cfg.espSkeleton = v end })
			:AddColorPicker('espSkeletonColor', { Default = cfg.espSkeletonColor, Title = 'Skeleton Color', Callback = function(c) cfg.espSkeletonColor = c end })
		ESPGroup:AddToggle('espGlow', { Text = 'Glow', Default = cfg.espGlow, Callback = function(v) cfg.espGlow = v end })
			:AddColorPicker('espGlowColor', { Default = cfg.espGlowColor, Title = 'Glow Color', Callback = function(c) cfg.espGlowColor = c end })
		ESPGroup:AddToggle('espTeamCheck', { Text = 'Team Check', Default = cfg.espTeamCheck, Callback = function(v) cfg.espTeamCheck = v end })
		ESPGroup:AddToggle('espVisibleOnly', { Text = 'Visible Only', Default = cfg.espVisibleOnly, Callback = function(v) cfg.espVisibleOnly = v end })
		ESPGroup:AddToggle('espProximityArrows', { Text = 'Proximity Arrows', Default = cfg.espProximityArrows,
			Callback = function(v) cfg.espProximityArrows = v end })

		-- World ESP
		local WorldESPGroup = Tabs.Visuals:AddLeftGroupbox('World ESP')
		WorldESPGroup:AddToggle('droppedWeaponESPEnabled', { Text = 'Dropped Weapons', Default = cfg.droppedWeaponESPEnabled,
			Callback = function(v) cfg.droppedWeaponESPEnabled = v end })
			:AddColorPicker('droppedWeaponESPColor', { Default = cfg.droppedWeaponESPColor, Title = 'Weapon ESP Color',
				Callback = function(c) cfg.droppedWeaponESPColor = c end })
		WorldESPGroup:AddToggle('bombTimerEnabled', { Text = 'Bomb Timer', Default = cfg.bombTimerEnabled,
			Callback = function(v) cfg.bombTimerEnabled = v; setupBombTimer() end })
			:AddColorPicker('bombTimerColor', { Default = cfg.bombTimerColor, Title = 'Bomb Timer Color',
				Callback = function(c) cfg.bombTimerColor = c end })
		WorldESPGroup:AddToggle('spreadCircleEnabled', { Text = 'Spread Circle', Default = cfg.spreadCircleEnabled,
			Callback = function(v) cfg.spreadCircleEnabled = v end })
			:AddColorPicker('spreadCircleColor', { Default = cfg.spreadCircleColor, Title = 'Spread Circle Color',
				Callback = function(c) cfg.spreadCircleColor = c end })

		-- Gun Chams
		local GunChamsGroup = Tabs.Visuals:AddRightGroupbox('Gun Chams')
		GunChamsGroup:AddToggle('gunChamsEnabled', { Text = 'Enable', Default = cfg.gunChamsEnabled,
			Callback = function(v) cfg.gunChamsEnabled = v; setupGunChams() end })
			:AddColorPicker('gunChamsColor', { Default = cfg.gunChamsColor, Title = 'Gun Chams Color',
				Callback = function(c) cfg.gunChamsColor = c end })
		GunChamsGroup:AddDropdown('gunChamsStyle', { Text = 'Style', Default = cfg.gunChamsStyle,
			Values = {"Pulse", "ForceField", "Flat", "Glass", "Tween", "Smooth", "ForceOverlay", "Water"},
			Callback = function(v) cfg.gunChamsStyle = v; if cfg.gunChamsEnabled then resetGunChams(); setupGunChams() end end })
		GunChamsGroup:AddDropdown('gunChamsTexture', { Text = 'Texture', Default = cfg.gunChamsTexture,
			Values = {"None", "Hex", "Stars"}, Callback = function(v) cfg.gunChamsTexture = v end })
		GunChamsGroup:AddSlider('gunChamsReflectance', { Text = 'Reflectance', Default = 0, Min = 0, Max = 100, Rounding = 0,
			Callback = function(v) cfg.gunChamsReflectance = v / 100 end })

		-- World
		local WorldGroup = Tabs.Visuals:AddRightGroupbox('World')
		WorldGroup:AddToggle('flashDisable', { Text = 'No Flash', Default = cfg.flashDisable,
			Callback = function(v) cfg.flashDisable = v; setupAntiFlash() end })
		WorldGroup:AddToggle('smokeRemove', { Text = 'Remove Smoke', Default = cfg.smokeRemove,
			Callback = function(v) cfg.smokeRemove = v; setupSmoke() end })
		WorldGroup:AddToggle('nightModeEnabled', { Text = 'Night Mode', Default = cfg.nightModeEnabled,
			Callback = function(v) cfg.nightModeEnabled = v; setupNightMode() end })
		local skyboxList = {"None"}; for name in pairs(Skies) do table.insert(skyboxList, name) end; table.sort(skyboxList)
		WorldGroup:AddToggle('skyboxEnabled', { Text = 'Custom Skybox', Default = cfg.skyboxEnabled,
			Callback = function(v) cfg.skyboxEnabled = v; if v then applySkybox(cfg.skyboxSelected) else applySkybox("None") end end })
		WorldGroup:AddDropdown('skyboxSelected', { Text = 'Skybox', Default = cfg.skyboxSelected, Values = skyboxList,
			Callback = function(v) cfg.skyboxSelected = v; if cfg.skyboxEnabled then applySkybox(v) end end })

		-- Bullet Tracer
		local TracerGroup = Tabs.Visuals:AddRightGroupbox('Bullet Tracer')
		TracerGroup:AddToggle('bulletTracerEnabled', { Text = 'Enable', Default = cfg.bulletTracerEnabled,
			Callback = function(v) cfg.bulletTracerEnabled = v end })
			:AddColorPicker('bulletTracerColor', { Default = cfg.bulletTracerColor, Title = 'Tracer Color',
				Callback = function(c) cfg.bulletTracerColor = c end })
		TracerGroup:AddSlider('bulletTracerThickness', { Text = 'Thickness', Default = math.floor(cfg.bulletTracerThickness), Min = 1, Max = 5, Rounding = 0,
			Callback = function(v) cfg.bulletTracerThickness = v end })
		TracerGroup:AddSlider('bulletTracerDuration', { Text = 'Duration (ms)', Default = 500, Min = 100, Max = 2000, Rounding = 0,
			Callback = function(v) cfg.bulletTracerDuration = v / 1000 end })
	end

	-- ═══════════════════════════════════════════════════
	-- MISC TAB
	-- ═══════════════════════════════════════════════════
	do
		local MoveGroup = Tabs.Misc:AddLeftGroupbox('Movement')
		MoveGroup:AddToggle('bhopEnabled', { Text = 'Bunny Hop', Default = cfg.bhopEnabled,
			Callback = function(v) cfg.bhopEnabled = v; setupBhop() end })
		MoveGroup:AddToggle('riskyBhopEnabled', { Text = 'Risky Bunny Hop', Default = cfg.riskyBhopEnabled, Risky = true,
			Callback = function(v) cfg.riskyBhopEnabled = v; setupRiskyBhop() end })
		MoveGroup:AddSlider('riskyBhopSpeed', { Text = 'Risky Bhop Speed', Default = cfg.riskyBhopSpeed, Min = 16, Max = 100, Rounding = 0,
			Callback = function(v) cfg.riskyBhopSpeed = v end })
		MoveGroup:AddToggle('autoStrafeEnabled', { Text = 'Auto Strafe', Default = cfg.autoStrafeEnabled,
			Callback = function(v) cfg.autoStrafeEnabled = v; setupAutoStrafe() end })
		MoveGroup:AddToggle('edgeJumpEnabled', { Text = 'Edge Jump', Default = cfg.edgeJumpEnabled,
			Callback = function(v) cfg.edgeJumpEnabled = v; setupEdgeJump() end })
		MoveGroup:AddToggle('speedEnabled', { Text = 'Speed', Default = cfg.speedEnabled, Risky = true,
			Callback = function(v) cfg.speedEnabled = v; setupSpeed() end })
		MoveGroup:AddSlider('speedAmount', { Text = 'Speed Amount', Default = cfg.speedAmount, Min = 1, Max = 160, Rounding = 0,
			Callback = function(v) cfg.speedAmount = v end })
		MoveGroup:AddToggle('thirdPersonEnabled', { Text = 'Third Person', Default = cfg.thirdPersonEnabled,
			Callback = function(v) cfg.thirdPersonEnabled = v; setupThirdPerson() end })
		MoveGroup:AddSlider('thirdPersonDistance', { Text = '3rd Person Dist', Default = cfg.thirdPersonDistance, Min = 5, Max = 30, Rounding = 0,
			Callback = function(v) cfg.thirdPersonDistance = v end })

		-- Network
		local NetGroup = Tabs.Misc:AddLeftGroupbox('Network')
		NetGroup:AddToggle('desyncEnabled', { Text = 'Desync', Default = cfg.desyncEnabled, Risky = true,
			Callback = function(v) cfg.desyncEnabled = v; setupDesync() end })
		NetGroup:AddToggle('desyncVisualize', { Text = 'Visualize Desync', Default = cfg.desyncVisualize,
			Callback = function(v) cfg.desyncVisualize = v end })
			:AddColorPicker('desyncColor', { Default = cfg.desyncColor, Title = 'Desync Color', Callback = function(c) cfg.desyncColor = c end })
		NetGroup:AddSlider('desyncTicks', { Text = 'Desync Ticks', Default = cfg.desyncTicks, Min = 1, Max = 20, Rounding = 0,
			Callback = function(v) cfg.desyncTicks = v end })

		-- Camera
		local CamGroup = Tabs.Misc:AddRightGroupbox('Camera')
		CamGroup:AddSlider('cameraFOV', { Text = 'Field of View', Default = cfg.cameraFOV, Min = 60, Max = 120, Rounding = 0,
			Callback = function(v) cfg.cameraFOV = v; setupFOV() end })
		CamGroup:AddToggle('xrayEnabled', { Text = 'Viewmodel Xray', Default = cfg.xrayEnabled,
			Callback = function(v) cfg.xrayEnabled = v; if not v then resetViewmodelXray() end end })

		-- Watermark
		local WatermarkGroup = Tabs.Misc:AddRightGroupbox('Watermark')
		WatermarkGroup:AddToggle('watermarkEnabled', { Text = 'Enable', Default = cfg.watermarkEnabled,
			Callback = function(v) cfg.watermarkEnabled = v; if not v then Library:SetWatermarkVisibility(false) end end })
		WatermarkGroup:AddToggle('watermarkName', { Text = 'Show Name', Default = cfg.watermarkName, Callback = function(v) cfg.watermarkName = v end })
		WatermarkGroup:AddToggle('watermarkFps', { Text = 'Show FPS', Default = cfg.watermarkFps, Callback = function(v) cfg.watermarkFps = v end })
		WatermarkGroup:AddToggle('watermarkPing', { Text = 'Show Ping', Default = cfg.watermarkPing, Callback = function(v) cfg.watermarkPing = v end })

		-- Sounds
		local SoundGroup = Tabs.Misc:AddRightGroupbox('Sounds')
		SoundGroup:AddToggle('hitsoundEnabled', { Text = 'Hitsound', Default = cfg.hitsoundEnabled,
			Callback = function(v) cfg.hitsoundEnabled = v; setupHitsound() end })
		SoundGroup:AddDropdown('hitsoundSelected', { Text = 'Sound', Default = cfg.hitsoundSelected,
			Values = {"Bameware","Bell","Bubble","Pick","Pop","Rust","Skeet","Neverlose","Minecraft"},
			Callback = function(v)
				cfg.hitsoundSelected = v
				-- Preview the selected sound
				task.spawn(function()
					local s = Instance.new("Sound")
					s.SoundId = hitsounds[v] or hitsounds.Bell
					s.Volume = cfg.hitsoundVolume / 10
					s.Parent = Workspace
					s:Play()
					game:GetService("Debris"):AddItem(s, 2)
				end)
			end })
		SoundGroup:AddSlider('hitsoundVolume', { Text = 'Volume', Default = cfg.hitsoundVolume, Min = 1, Max = 10, Rounding = 0,
			Callback = function(v) cfg.hitsoundVolume = v end })

		-- Character Changer
		local CharGroup = Tabs.Misc:AddRightGroupbox('Character Changer')
		CharGroup:AddToggle('customCharacterEnabled', { Text = 'Enable', Default = cfg.customCharacterEnabled,
			Callback = function(v) cfg.customCharacterEnabled = v; setupCharacterChanger() end })
		local modelList = {}; for name in pairs(CharacterModels) do table.insert(modelList, name) end; table.sort(modelList)
		CharGroup:AddDropdown('customCharacterModel', { Text = 'Model', Default = cfg.customCharacterModel, Values = modelList,
			Callback = function(v) cfg.customCharacterModel = v; if cfg.customCharacterEnabled then setupCharacterChanger() end end })
	end

	-- ═══════════════════════════════════════════════════
	-- SKIN CHANGER TAB
	-- ═══════════════════════════════════════════════════
	do
		local SkinGroup = Tabs['Skin Changer']:AddLeftGroupbox('Weapon Skins')
		SkinGroup:AddToggle('skinChangerEnabled', { Text = 'Enable Skin Changer', Default = cfg.skinChangerEnabled,
			Callback = function(v)
				cfg.skinChangerEnabled = v
				if v then
					hookGetCameraModel(); hookViewmodelNew(); hookGetWeaponProperties()
					task.wait(0.2); forceReequipWeapon()
				end
			end })

		local currentWeaponName, currentSkinName, currentCondition = "none", "none", "factory new"

		local weaponList = {"none"}
		for weaponName in pairs(weaponSkins) do
			local isKnife = false
			for _, knifeName in ipairs(KnifeList) do
				if weaponName == knifeName then isKnife = true; break end
			end
			if not isKnife then table.insert(weaponList, weaponName) end
		end
		table.sort(weaponList)

		SkinGroup:AddDropdown('skinWeapon', { Text = 'Weapon', Default = "none", Values = weaponList,
			Callback = function(v)
				currentWeaponName = v
				local skinList = {"none"}
				if currentWeaponName ~= "none" and weaponSkins[currentWeaponName] then
					for _, skin in ipairs(weaponSkins[currentWeaponName]) do table.insert(skinList, skin) end
				end
				table.sort(skinList)
				Options.skinSkin:SetValues(skinList)
				Options.skinSkin:SetValue("none")
				currentSkinName = "none"
			end })

		SkinGroup:AddDropdown('skinSkin', { Text = 'Skin', Default = "none", Values = {"none"}, AllowNull = true,
			Callback = function(v)
				currentSkinName = v or "none"
				if currentWeaponName ~= "none" and currentSkinName ~= "none" then
					weaponSkinConfig[currentWeaponName] = { skin = currentSkinName, condition = currentCondition }
					task.wait(0.1); forceReequipWeapon()
				end
			end })

		SkinGroup:AddDropdown('skinCondition', { Text = 'Condition', Default = "factory new", Values = conditions,
			Callback = function(v)
				currentCondition = v
				if currentWeaponName ~= "none" and currentSkinName ~= "none" then
					weaponSkinConfig[currentWeaponName] = { skin = currentSkinName, condition = currentCondition }
					task.wait(0.1); forceReequipWeapon()
				end
			end })

		-- Knife Section
		local KnifeGroup = Tabs['Skin Changer']:AddRightGroupbox('Knife')
		local currentKnifeName, currentKnifeSkin, currentKnifeCondition = "none", "none", "factory new"
		
		local knifeList = {"none"}
		for weaponName in pairs(weaponSkins) do
			local isKnife = false
			for _, knifeName in ipairs(KnifeList) do
				if weaponName == knifeName then isKnife = true; break end
			end
			if isKnife then table.insert(knifeList, weaponName) end
		end
		table.sort(knifeList)

		KnifeGroup:AddDropdown('knifeModel', { Text = 'Knife', Default = "none", Values = knifeList,
			Callback = function(v)
				currentKnifeName = v
				local skinList = {"none"}
				if currentKnifeName ~= "none" and weaponSkins[currentKnifeName] then
					for _, skin in ipairs(weaponSkins[currentKnifeName]) do table.insert(skinList, skin) end
				end
				table.sort(skinList)
				Options.knifeSkin:SetValues(skinList)
				Options.knifeSkin:SetValue("none")
				currentKnifeSkin = "none"
			end })

		KnifeGroup:AddDropdown('knifeSkin', { Text = 'Skin', Default = "none", Values = {"none"}, AllowNull = true,
			Callback = function(v)
				currentKnifeSkin = v or "none"
				if currentKnifeName ~= "none" and currentKnifeSkin ~= "none" then
					weaponSkinConfig[currentKnifeName] = { skin = currentKnifeSkin, condition = currentKnifeCondition }
					knifeGloveMapping.knife = currentKnifeName
					task.wait(0.1); forceReequipWeapon()
				end
			end })

		KnifeGroup:AddDropdown('knifeCondition', { Text = 'Condition', Default = "factory new", Values = conditions,
			Callback = function(v)
				currentKnifeCondition = v
				if currentKnifeName ~= "none" and currentKnifeSkin ~= "none" then
					weaponSkinConfig[currentKnifeName] = { skin = currentKnifeSkin, condition = currentKnifeCondition }
					task.wait(0.1); forceReequipWeapon()
				end
			end })

		-- Glove Section
		local GloveGroup = Tabs['Skin Changer']:AddRightGroupbox('Gloves')
		local currentGloveName, currentGloveSkin, currentGloveCondition = "none", "none", "factory new"
		
		local gloveList = {"none"}
		for weaponName in pairs(weaponSkins) do
			if weaponName:find("Glove") then table.insert(gloveList, weaponName) end
		end
		table.sort(gloveList)

		GloveGroup:AddDropdown('gloveModel', { Text = 'Glove', Default = "none", Values = gloveList,
			Callback = function(v)
				currentGloveName = v
				local skinList = {"none"}
				if currentGloveName ~= "none" and weaponSkins[currentGloveName] then
					for _, skin in ipairs(weaponSkins[currentGloveName]) do table.insert(skinList, skin) end
				end
				table.sort(skinList)
				Options.gloveSkin:SetValues(skinList)
				Options.gloveSkin:SetValue("none")
				currentGloveSkin = "none"
			end })

		GloveGroup:AddDropdown('gloveSkin', { Text = 'Skin', Default = "none", Values = {"none"}, AllowNull = true,
			Callback = function(v)
				currentGloveSkin = v or "none"
				if currentGloveName ~= "none" and currentGloveSkin ~= "none" then
					weaponSkinConfig[currentGloveName] = { skin = currentGloveSkin, condition = currentGloveCondition }
					knifeGloveMapping.glove = currentGloveName
					task.wait(0.1); forceReequipWeapon()
				end
			end })

		GloveGroup:AddDropdown('gloveCondition', { Text = 'Condition', Default = "factory new", Values = conditions,
			Callback = function(v)
				currentGloveCondition = v
				if currentGloveName ~= "none" and currentGloveSkin ~= "none" then
					weaponSkinConfig[currentGloveName] = { skin = currentGloveSkin, condition = currentGloveCondition }
					task.wait(0.1); forceReequipWeapon()
				end
			end })

		-- Skin Viewer (ViewportFrame)
		local ViewerGroup = Tabs['Skin Changer']:AddLeftGroupbox('Skin Viewer')
		ViewerGroup:AddLabel('Select a knife to preview:')
		ViewerGroup:AddButton({
			Text = 'Preview Knife',
			Func = function()
				task.spawn(function()
					local kName = currentKnifeName ~= "none" and currentKnifeName or currentWeaponName
					local sName = currentKnifeName ~= "none" and currentKnifeSkin or currentSkinName
					if kName == "none" or sName == "none" then
						Library:Notify("Select a weapon and skin first!", 3)
						return
					end
					-- Try to use GetCameraModel to get the skin model
					if not skinsLibrary or not originalGetCameraModel then
						Library:Notify("Skin system not initialized", 3)
						return
					end
					local cond = currentKnifeName ~= "none" and currentKnifeCondition or currentCondition
					local float = getFloatFromCondition(cond)
					local ok, model = pcall(function()
						return originalGetCameraModel(kName, sName, float)
					end)
					if not ok or not model then
						Library:Notify("Failed to load skin model", 3)
						return
					end
					-- Create viewport window
					local viewerGui = Instance.new("ScreenGui")
					viewerGui.Name = "LemonSkinViewer"
					viewerGui.DisplayOrder = 100000
					viewerGui.ResetOnSpawn = false
					local protectGui = protectgui or (syn and syn.protect_gui) or function() end
					protectGui(viewerGui)
					viewerGui.Parent = game:GetService("CoreGui")
					
					local frame = Instance.new("Frame")
					frame.Size = UDim2.fromOffset(350, 300)
					frame.Position = UDim2.new(0.5, -175, 0.5, -150)
					frame.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
					frame.BorderSizePixel = 0
					frame.Parent = viewerGui
					Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
					local stroke = Instance.new("UIStroke", frame)
					stroke.Color = Color3.fromRGB(112, 146, 190)
					stroke.Thickness = 1
					
					local titleBar = Instance.new("TextLabel")
					titleBar.Size = UDim2.new(1, 0, 0, 28)
					titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
					titleBar.BorderSizePixel = 0
					titleBar.Text = "  " .. kName .. " | " .. sName
					titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
					titleBar.TextSize = 13
					titleBar.Font = Enum.Font.GothamSemibold
					titleBar.TextXAlignment = Enum.TextXAlignment.Left
					titleBar.Parent = frame
					Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)
					Instance.new("Frame", titleBar).Size = UDim2.new(1, 0, 0, 8)
					Instance.new("Frame", titleBar).Position = UDim2.new(0, 0, 1, -8)
					for _, f in titleBar:GetChildren() do
						if f:IsA("Frame") then f.BackgroundColor3 = Color3.fromRGB(28, 28, 30); f.BorderSizePixel = 0 end
					end
					
					local closeBtn = Instance.new("TextButton")
					closeBtn.Size = UDim2.fromOffset(24, 24)
					closeBtn.Position = UDim2.new(1, -26, 0, 2)
					closeBtn.BackgroundTransparency = 1
					closeBtn.Text = "×"
					closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
					closeBtn.TextSize = 18
					closeBtn.Font = Enum.Font.GothamBold
					closeBtn.Parent = frame
					closeBtn.MouseButton1Click:Connect(function() viewerGui:Destroy() end)
					
					local viewport = Instance.new("ViewportFrame")
					viewport.Size = UDim2.new(1, -8, 1, -36)
					viewport.Position = UDim2.new(0, 4, 0, 32)
					viewport.BackgroundColor3 = Color3.fromRGB(13, 13, 15)
					viewport.BorderSizePixel = 0
					viewport.Parent = frame
					Instance.new("UICorner", viewport).CornerRadius = UDim.new(0, 6)
					
					-- Clone model into viewport
					local clonedModel = model:Clone()
					clonedModel.Parent = viewport
					
					-- Setup camera
					local vpCam = Instance.new("Camera")
					vpCam.FieldOfView = 50
					viewport.CurrentCamera = vpCam
					vpCam.Parent = viewport
					
					-- Frame the model
					local cf, size = clonedModel:GetBoundingBox()
					local maxDim = math.max(size.X, size.Y, size.Z)
					vpCam.CFrame = cf * CFrame.new(0, 0, maxDim * 1.5)
					
					-- Add lighting
					local light = Instance.new("PointLight")
					light.Brightness = 2
					light.Range = 30
					local lightPart = Instance.new("Part")
					lightPart.Transparency = 1
					lightPart.Size = Vector3.new(0.1, 0.1, 0.1)
					lightPart.Anchored = true
					lightPart.CanCollide = false
					lightPart.CFrame = cf * CFrame.new(3, 3, 3)
					light.Parent = lightPart
					lightPart.Parent = viewport
					
					-- Spin animation
					local angle = 0
					local spinConn
					spinConn = RunService.RenderStepped:Connect(function(dt)
						if not viewport or not viewport.Parent then spinConn:Disconnect(); return end
						angle = angle + dt * 0.5
						vpCam.CFrame = cf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, maxDim * 1.5)
					end)
					
					-- Dragging for the viewer window
					local dragging, dragStart, startPos
					titleBar.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							dragging = true; dragStart = input.Position; startPos = frame.Position
						end
					end)
					UserInputService.InputChanged:Connect(function(input)
						if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
							local d = input.Position - dragStart
							frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
						end
					end)
					UserInputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
					end)
					
					Library:Notify("Skin viewer opened!", 2)
				end)
			end
		})
	end

	-- ═══════════════════════════════════════════════════
	-- SETTINGS TAB
	-- ═══════════════════════════════════════════════════
	do
		-- Config Section
		local ConfigGroup = Tabs.Settings:AddLeftGroupbox('Configuration')
		ConfigGroup:AddInput('configName', { Text = 'Config Name', Default = '', Placeholder = 'my config' })
		ConfigGroup:AddDropdown('autoLoadConfig', { Text = 'Config', Default = cfg.autoLoadConfig, Values = getConfigList(), AllowNull = true,
			Callback = function(v) cfg.autoLoadConfig = v or "none" end })
		ConfigGroup:AddButton({ Text = 'Save Config', Func = function()
			local name = Options.configName.Value
			if name and name ~= "" then
				saveCurrentConfig(name)
				Options.autoLoadConfig:SetValues(getConfigList())
				Library:Notify("Config '" .. name .. "' saved!", 2)
			else
				Library:Notify("Enter a config name first!", 2)
			end
		end })
		ConfigGroup:AddButton({ Text = 'Load Config', Func = function()
			local name = cfg.autoLoadConfig
			if name and name ~= "none" then
				loadConfig(name)
				Library:Notify("Config '" .. name .. "' loaded!", 2)
			else
				Library:Notify("Select a config to load!", 2)
			end
		end })
		ConfigGroup:AddButton({ Text = 'Delete Config', Func = function()
			local name = cfg.autoLoadConfig
			if name and name ~= "none" then
				deleteConfig(name)
				Options.autoLoadConfig:SetValues(getConfigList())
				Library:Notify("Config '" .. name .. "' deleted!", 2)
			end
		end })
		ConfigGroup:AddDivider()
		ConfigGroup:AddButton({
			Text = 'Unload Script',
			DoubleClick = true,
			Func = function()
				for _, esp in pairs(espObjects) do esp:destroy() end
				for _, esp in pairs(droppedWeaponESPObjects) do esp:destroy() end
				for _, t in pairs(bulletTracers) do if t.beam then t.beam:Destroy() end; if t.part0 then t.part0:Destroy() end; if t.part1 then t.part1:Destroy() end end
				for _, c in pairs(conns) do if typeof(c) == "function" then pcall(c) elseif c and c.Disconnect then c:Disconnect() end end
				for _, lines in pairs(skeletonLines) do for _, l in lines do l:Remove() end end
				for _, glow in pairs(glowCache) do if glow then glow:Destroy() end end
				for player in pairs(hitboxCache) do local char = player.Character; if char then local head = char:FindFirstChild("Head"); if head then head.Size = hitboxCache[player] end end end
				fovCircle:Remove(); watermarkText:Remove(); spreadCircle:Remove(); bombTimerText:Remove()
				resetViewmodelXray(); resetGunChams()
				cfg.nightModeEnabled = false; setupNightMode()
				cfg.antiAimEnabled = false; setupAntiAim()
				if riskyBhopVelocity then riskyBhopVelocity:Destroy() end
				if flashModule and originalFlash then local module = require(flashModule); module.Flash = originalFlash end
				if skinsLibrary and originalGetCameraModel then skinsLibrary.GetCameraModel = originalGetCameraModel end
				if customCharacterRig then for _, p in pairs(customCharacterRig) do if p then p:Destroy() end end end
				Library:Unload()
			end
		})

		-- Menu Settings
		local MenuGroup = Tabs.Settings:AddRightGroupbox('Menu')
		MenuGroup:AddLabel('Menu Toggle'):AddKeyPicker('menuToggleKey', {
			Default = Enum.KeyCode.Insert,
			Text = 'Menu Toggle',
			Mode = 'Toggle',
			Callback = function() end,
		})
		Library.ToggleKeybind = Options.menuToggleKey

		-- Theme Section
		local ThemeGroup = Tabs.Settings:AddRightGroupbox('Theme')
		ThemeGroup:AddLabel('Accent Color'):AddColorPicker('accentColor', {
			Default = Library.AccentColor,
			Title = 'Accent Color',
			Callback = function(c)
				Library.AccentColor = c
				Library.AccentColorDark = Library:GetDarkerColor(c)
				Library:UpdateColorsUsingRegistry()
			end
		})
	end

	if cfg.autoLoadConfig and cfg.autoLoadConfig ~= "none" then loadConfig(cfg.autoLoadConfig) end
	menuVisible = true
end

initializeScript()
