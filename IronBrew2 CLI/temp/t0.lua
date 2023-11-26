local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Player = Players.LocalPlayer


local Character = Player.Character
if (not Character) then
	Character = Player.CharacterAdded:Wait()
end

local Humanoid = Character:WaitForChild('Humanoid', 60)
local HumanoidRootPart = Humanoid.RootPart
local CharacterHead = Character:FindFirstChild('Head') or HumanoidRootPart

local GAME_KEY = ""
local MeleeModule = require(ReplicatedStorage.GunLibrary:WaitForChild("MeleeModule"))
local sha1 = require(ReplicatedStorage.GunLibrary.SHA1Module)
local BinaryUtil = require(ReplicatedStorage.GunLibrary.BinaryUtil)
local RandomLookup = require(ReplicatedStorage.GunLibrary.Lookup)
local GunModifiers = require(ReplicatedStorage.GunLibrary.GunModifiers)
local SoundGroupManager = require(ReplicatedStorage.GunLibrary.SoundGroupManager);
local SpringModule = require(script.Data:WaitForChild("Spring"))
local cpairs = require(script.Data.cpairs)
script.Parent:WaitForChild("CustomCamera",60*5)

local isEnabled = script.IsEnabled.Value
local isSpectating = not not script.Spectating.Value
local customCamera = script.Parent.CustomCamera
local camera = workspace.CurrentCamera

local aimTween = 0
local holdingRight = false
local holdingLeft = false
local holdingW = false
local holdingShift = false
local ReleasedSpace = true
local lastCenter = Vector3.new()
local lastSpeed = 0
local speed = 0
local velocity = Vector3.zero
local Jumping = false
local ticks = 0
local bobSpeed = 0
local IsInFirstPerson = false
local reloading = false
local reloadingIndividual = false
local RequiresManualRechamber = false
local cancelReloadingIndividual = false
local lastShootTime = 0
local crouched = false
local running = false
local speedModifier = 1.0
local takeoutRot = 0
local holsterWeapon = false
local cameraHeight = -1
local hitmarkerDelay = 0
local ThirdPerson = false
local rechambering = false
local scoped = false
local stepHeightOffset = 0
local GUN_DIP = 0
local GUN_DIP_SPEED = 0
local AllowThirdPerson = false
local AllowFirstPerson = true
local WeaponSwitchTransitionTime = 0
local mobileFire = false
local UserCanDisable = false
local GunTakeoutCanShootTime = 0
local IsDead = false
local RepeatShoot = 0
local OVERRIDE_CAMERA_HEIGHT = nil
local AttachmentData = {}
local SwaySteadyMultiplier = 0

local Minimum_Scope_Aim_Tween = 0.25
local ScopeBlurRatioX = 1.0
local ScopeBlurRatioY = 1.0

local ShouldInvisible = false
local CurrentlyInvisible = false

local MagnifierRatio = 0

local CAMERA_ROATION_BASE = nil
local SHOOTING_OFFSET = 0
local RECOIL_VERTICAL = 0
local RECOIL_VERTICAL_CURRENT = 0
local RECOIL_HORIZONTAL = 0
local gunHasChanged = false
local BlockedGun = false
local CurrentSpectatingCharacter
local IsDisplayingViewModel = true
local PLAYER_EYE = Vector3.new()
local WorldLookAtPos = Vector3.new()
local JumpController = nil
local JumpStamina = 1
local JumpDebounce = 0
local JumpPower = 0
local FOVMultiplier = 1
local RUN_BOB_X = 0
local RUN_BOB_Y = 0
local IDLE_BOB_X = 0
local IDLE_BOB_Y = 0
local tK = nil
local heiSt = 0
local heiCr = 0
local jmpNrm = 0
local jmpFat = 0

local MAX_JUMP_STAMINA = 1.3
local BLANK_MODIFIERS = GunModifiers:Generate()

script.IsEnabled.Changed:Connect(function()
	isEnabled = script.IsEnabled.Value
end)

script.Spectating.Changed:Connect(function()
	isSpectating = not not script.Spectating.Value
end)

workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
	camera = workspace.CurrentCamera
end)

local serverGunConfiguration = ReplicatedStorage:FindFirstChild("GunConfiguration").Server

local PositionGun = require(ReplicatedStorage:WaitForChild("SharedLibraries"):WaitForChild("Gun"):FindFirstChild("PositionGun"))

local recoilSpring = SpringModule.new(Vector3.zero)
recoilSpring.Speed = 8
recoilSpring.Damper = 0.75
local RECOIL_POWER = 1
local RECOIL_SCALE = 1/64

local CrosshairRaycastParams = RaycastParams.new()
CrosshairRaycastParams.IgnoreWater = true
CrosshairRaycastParams.FilterDescendantsInstances = { Character, camera, workspace.Terrain, workspace:WaitForChild("IgnoreList") }
CrosshairRaycastParams.FilterType = Enum.RaycastFilterType.Blacklist

local HitmarkerEnabled = serverGunConfiguration:FindFirstChild("sv_hitmarker_enabled")

local AnimationRedirectTable = {
	["Draw"] = {
		"Draw",
		"Equip",
	},
	["Run"] = {
		"Run",
		"Sprint",
	}
}



local Key53 = 8186584168865098
local Key14 = 4887

local inv256

function E(str)
	if ( not str ) then
		return
	end

	if not inv256 then
		inv256 = {}
		for M = 0, 127 do
			local inv = -1
			repeat inv = inv + 2
			until inv * (2*M + 1) % 256 == 1
			inv256[M] = inv
		end
	end
	local K, F = Key53, 16384 + Key14
	return (str:gsub('.',
		function(m)
			local L = K % 274877906944  
			local H = (K - L) / 274877906944
			local M = H % 128
			m = m:byte()
			local c = (m * inv256[M] - (H - M) / 128) % 256
			K = L * F + H + c + m
			return ('%02x'):format(c)
		end
		))
end

function D(str)
	if ( not str ) then
		return
	end

	local K, F = Key53, 16384 + Key14
	return (str:gsub('%x%x',
		function(c)
			local L = K % 274877906944  
			local H = (K - L) / 274877906944
			local M = H % 128
			c = tonumber(c, 16)
			local m = (c + (H - M) / 128) * (2*M + 1) % 256
			K = L * F + H + c + m
			return string.char(m)
		end
		))
end










local BulletModule = {}

local CurrentHeartbeatDelta = nil;

local GameLogicEvent = nil
if ( game:GetService("RunService"):IsClient() ) then
	GameLogicEvent = game:GetService("RunService").RenderStepped
else
	GameLogicEvent = game:GetService("RunService").Heartbeat
end

local SoundGroupManager = require(game.ReplicatedStorage:WaitForChild('GunLibrary').SoundGroupManager);

function BulletModule:IgnoreList(IgnorePlayers, CustomIgnoreList)
	debug.profilebegin('create_ray_ignore_list')
	local ignore = {};

	local PlayerList = game.Players:GetPlayers()
	if ( game:GetService("RunService"):IsClient() ) then
		PlayerList = _G.PlayerList.Players
	end

	if (IgnorePlayers) then
		
		debug.profilebegin('add_player_characters')
		for i = 1, #PlayerList do
			local v = PlayerList[i]
			if (v.Character) then
				ignore[#ignore+1] = v.Character
			end
		end
		debug.profileend();
	else
		
		debug.profilebegin('add_player_humanoid_root_part')
		for i = 1, #PlayerList do
			local v = PlayerList[i]
			if (v.Character) then
				local RootPart = v.Character:FindFirstChild("HumanoidRootPart")
				if ( RootPart ) then
					ignore[#ignore+1] = RootPart
				end
			end
		end
		debug.profileend();
	end

	debug.profilebegin('add_camera_objects');

	
	ignore[#ignore+1] = workspace.CurrentCamera

	
	if ( CustomIgnoreList ) then
		for i = 1, #CustomIgnoreList do
			ignore[#ignore+1] = CustomIgnoreList[i]
		end
	end

	
	if ( workspace:FindFirstChild("IgnoreList") ) then
		ignore[#ignore+1] = workspace.IgnoreList
	end

	debug.profileend();
	debug.profileend();

	return ignore
end




function BulletModule:rayTest( Player, start, finish, ignorePlayers, TracerObject, CustomIgnoreList, CustomWhiteList )
	if ( ignorePlayers == nil ) then
		ignorePlayers = true
	end

	ignorePlayers = ignorePlayers == true

	if ( not finish or not start ) then
		return nil, finish
	end

	
	local params = RaycastParams.new()
	params.CollisionGroup = "BulletGroup"

	if (not CustomWhiteList) then
		local ignore = self:IgnoreList(ignorePlayers, CustomIgnoreList)
		if ( TracerObject ) then
			debug.profilebegin('add_tracer_object');
			table.insert(ignore, TracerObject)
			debug.profileend();
		end

		if ( not ignorePlayers ) then
			debug.profilebegin('add_shooter_character');
			if (typeof(Player.Character) == "Instance" and Player.Character) then
				table.insert(ignore, Player.Character)
			end
			debug.profileend();
		end

		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
	else
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = CustomWhiteList
	end

	local result = workspace:Raycast(start, finish-start, params)
	if ( not result ) then
		return nil, finish
	end

	local hitPart = result and result.Instance
	local hitPosition = result and result.Position or finish
	local hitNormal = result and result.Normal or Vector3.zero
	local hitMaterial = result and result.Material or Enum.Material.Air
	return hitPart, hitPosition or finish, hitNormal or Vector3.one, hitMaterial or Enum.Material.Air
end

function BulletModule:GetBulletDrop(GunData, Distance)
	local BulletSpeed = (GunData == nil or not GunData.Stats.BulletSettings:FindFirstChild("BulletSpeed")) 
		and game.ReplicatedStorage:FindFirstChild("GunConfiguration").Server:FindFirstChild("sv_default_bullet_speed").Value 
		or GunData.Stats.BulletSettings.BulletSpeed.Value

	local Gravity = (GunData == nil or not GunData.Stats.BulletSettings:FindFirstChild("BulletGravity") or (GunData.Stats.BulletSettings:FindFirstChild("BulletGravity")
		and GunData.Stats.BulletSettings:FindFirstChild("BulletGravity").Value)) and 0.95 or 0

	local dt = Distance / BulletSpeed

	return Gravity * dt
end











function BulletModule:BulletSimulation( Player, StartPosition, Direction, GunData, Tracer, CustomTracerFolder, dts, test_positions, TracerOffsetPosition )
	Tracer = Tracer == true
	TracerOffsetPosition = TracerOffsetPosition or Vector3.zero
	CustomTracerFolder = (CustomTracerFolder and CustomTracerFolder:IsA("Instance")) and CustomTracerFolder or nil

	local new_dts = {};
	local new_test_positions = {};

	
	Direction = Direction.Unit

	local MaxDistance = GunData == nil and 0 or GunData.Stats.BulletSettings.MaxDistance.Value + 4

	local DefaultGravity = game.ReplicatedStorage:FindFirstChild("GunConfiguration").Server:FindFirstChild("sv_default_bullet_gravity") and game.ReplicatedStorage:FindFirstChild("GunConfiguration").Server:FindFirstChild("sv_default_bullet_gravity").Value or 0.95

	local BulletSpeed = (GunData == nil or not GunData.Stats.BulletSettings:FindFirstChild("BulletSpeed")) and game.ReplicatedStorage:FindFirstChild("GunConfiguration").Server:FindFirstChild("sv_default_bullet_speed").Value or GunData.Stats.BulletSettings.BulletSpeed.Value
	local Gravity = (GunData == nil or not GunData.Stats.BulletSettings:FindFirstChild("BulletGravity") or (GunData.Stats.BulletSettings:FindFirstChild("BulletGravity") and GunData.Stats.BulletSettings:FindFirstChild("BulletGravity").Value)) and DefaultGravity or 0
	local GSpeed = 0

	local OriginalBulletSpeed = BulletSpeed

	local Player = Player

	local BulletPosition = CFrame.new(test_positions and test_positions[1][1] or StartPosition)
	local TravelTime = 0

	local P = nil
	local CustomTracer = (CustomTracerFolder and CustomTracerFolder:FindFirstChild("Tracer")) and CustomTracerFolder:FindFirstChild("Tracer"):Clone() or nil
	local CustomTracerRotationMatrix = CFrame.identity
	local CustomTracerPositionOffset = Vector3.zero
	if ( Tracer and not test_positions ) then
		P = Instance.new("Part")
		P.Name = "Tracer"
		P.Anchored = true
		P.Size = Vector3.new(0.002, 0.002, 0.002)
		P.CFrame = BulletPosition
		P.CanCollide = false
		P.CanTouch = false
		P.CanQuery = false
		P.Transparency = 1;
		P.Parent = workspace:FindFirstChild("IgnoreList") or workspace
		P.CollisionGroup = "RaycastIgnore"

		local scalar = 0.25 

		local a1 = Instance.new('Attachment');
		a1.CFrame = CFrame.new(0,-0.25*scalar,-3);
		a1.Parent = P;

		local a2 = Instance.new('Attachment');
		a2.CFrame = CFrame.new(0,0.25*scalar,18);
		a2.Parent = P;

		local Light = nil
		if ( not CustomTracerFolder ) then
			if ( game:GetService("RunService"):IsClient() ) then
				local HasTracers = game.Players.LocalPlayer.PlayerScripts.GunController.Configuration.cl_tracers_light_enabled.Value
				local HasShadows = game.Players.LocalPlayer.PlayerScripts.GunController.Configuration.cl_muzzle_flash_shadows.Value
				if ( HasTracers ) then
					Light = game.ReplicatedStorage.Assets.Particles.DefaultBullet.Light:Clone()
					Light.Shadows = HasShadows
					Light.Parent = P
				end
			end
		end

		local TrailReference = CustomTracerFolder and CustomTracerFolder:FindFirstChild("Trail") or game.ReplicatedStorage.Assets.Particles.DefaultBullet.Trail 
		local trail = TrailReference:Clone();
		trail.Attachment0 = a1;
		trail.Attachment1 = a2;
		trail.Parent = P;

		if ( CustomTracer ) then
			CustomTracerRotationMatrix = CustomTracer:GetPrimaryPartCFrame()-(CustomTracer:GetPrimaryPartCFrame().Position)
			CustomTracer.Parent = P
		end

		if ( CustomTracerFolder ) then
			local children = CustomTracerFolder:GetChildren();
			for i = 1, #children do
				local v = children[i];
				if (v:IsA("ParticleEmitter")) then
					v:Clone().Parent = P
				end
			end
		end

		if ( CustomTracer ) then
			for _,v in cpairs(CustomTracer:GetDescendants()) do
				if ( v:IsA("Sound") ) then
					v.SoundGroup = v.SoundGroup or SoundGroupManager:GetSoundGroup('Game');
					v:Play()
				end
			end
		end
	end

	local step = 1;
	while ( true ) do
		local expected_loc = nil;
		local dt = nil;
		if (not dts) then
			if ( step == 1 and CurrentHeartbeatDelta and not Tracer ) then
				dt = CurrentHeartbeatDelta
			else
				dt = GameLogicEvent:Wait()
			end
		else
			dt = dts[step];
			if (not dt) then
				_cleanup(P, CustomTracer)
				return nil, nil, nil, nil, nil, nil, new_dts, new_test_positions
			end
		end

		TravelTime = TravelTime + dt

		if (test_positions) then
			expected_loc = test_positions[step][2]
		end

		
		step = step + 1;
		table.insert(new_dts, dt);

		
		GSpeed = (Gravity * TravelTime ^ 2)

		
		BulletSpeed = BulletSpeed

		
		local Distance = BulletSpeed*dt
		local Interrupt = false
		local TraveledDistance = (BulletPosition.Position-StartPosition).Magnitude
		local RemainingDistance = MaxDistance-TraveledDistance
		if ( RemainingDistance < BulletSpeed*dt ) then
			Distance = RemainingDistance + 1
			Interrupt = true
		end

		
		local NextCFrame = BulletPosition * CFrame.new(Direction*Distance)
		local BulletDrop = Vector3.new(0, -GSpeed, 0)

		local custom_whitelist = nil;
		if (game:GetService('RunService'):IsServer() and _G.StaticAssetsStorage) then
			custom_whitelist = { _G.StaticAssetsStorage, workspace.Terrain };
		end

		
		local FlyDirection = (NextCFrame.Position - BulletPosition.Position).Unit
		local PartHit, WorldHit, NormalHit, MaterialHit = self:rayTest(Player, BulletPosition.Position + BulletDrop, NextCFrame.Position + BulletDrop, false, P, nil, custom_whitelist)
		if ( PartHit and PartHit:GetAttribute("BulletMaterial") ) then
			MaterialHit = Enum.Material[PartHit:GetAttribute("BulletMaterial")]
		end

		table.insert(new_test_positions, { BulletPosition.Position + BulletDrop, WorldHit });

		local function RepositionBullet(Transform)
			if ( not P ) then
				return
			end

			local offsetResetSpeed = 4
			local offsetPosition = TracerOffsetPosition:Lerp(Vector3.zero, math.clamp(TravelTime*offsetResetSpeed, 0, 1))

			local targetPosition = Transform.Position + offsetPosition
			P.CFrame = CFrame.new(targetPosition, targetPosition+FlyDirection)

			if ( CustomTracer ) then
				CustomTracer:SetPrimaryPartCFrame(P.CFrame*CustomTracerRotationMatrix)
			end
		end


		
		if ( not PartHit ) then
			RepositionBullet(NextCFrame + BulletDrop)
		else
			RepositionBullet(CFrame.new(WorldHit))
			_cleanup(P, CustomTracer)

			
			local internal = getHitInternal(PartHit)
			return internal[1], internal[2], PartHit, WorldHit, NormalHit, MaterialHit, new_dts, new_test_positions
		end

		BulletPosition = NextCFrame

		
		if ( Interrupt ) then
			break
		end
	end

	_cleanup(P, CustomTracer)
	return nil, nil, nil, nil, nil, nil, new_dts, new_test_positions
end

function _cleanup(Tracer, CustomTracer)
	if ( Tracer and Tracer:IsA("Instance") ) then
		local WaitTime = 2

		local children = Tracer:GetChildren();
		for i = 1, #children do
			local v = children[i];
			if ( v:IsA("ParticleEmitter") ) then
				WaitTime = math.max(WaitTime,v.Lifetime.Max )
			end

			if ( v:IsA("Light") ) then
				v.Enabled = false
			end
		end

		
		local Trail = CustomTracer or Tracer:FindFirstChildOfClass("Trail", true)
		if ( Trail and Trail:IsA("Trail") ) then
			game:GetService("TweenService"):Create(Trail, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {MaxLength = 1}):Play()
		end

		
		game:GetService("Debris"):AddItem(Tracer, WaitTime); 
	end

	if ( CustomTracer ) then
		CustomTracer:Destroy()
	end
end




function getHitInternal(PartHit)
	local Character = getCharacterFromObject(PartHit)
	local HitType = nil

	if ( Character ) then
		HitType = require(game.ReplicatedStorage.GunLibrary.GetHitType):GetHitType(PartHit)
	end

	return { Character, HitType }
end

function getCharacterFromObject( hitObject )
	
	local tries = 0
	local currentObject = hitObject
	while( tries < 4 ) do
		tries = tries + 1

		if ( not currentObject ) then
			break
		end

		
		local huma = currentObject:FindFirstChild("Humanoid")
		if ( huma ) then
			return currentObject
		end

		
		currentObject = currentObject.Parent
		if ( currentObject == game.Workspace or currentObject == nil ) then
			break
		end
	end

	return nil
end

GameLogicEvent:Connect(function(Delta)
	CurrentHeartbeatDelta = Delta
end)














local gunCurrent = nil
local gunCurrentStats = {}
local gunCurrentSlot = 1
local gunCurrentInventory = nil
local previousWeapon = nil
local gunViewModel = nil
local gunWorldModel = nil
local currentlyPlayingAnimation = nil
local currentlyPlayingAnimationName = nil
local currentlyPlayingAnimationKeyFrameChangeFunction = nil
local currentlyPlayingAnimationKeyFrameChangeFunction2 = nil
local currentlyPlayingAnimationPriorityMap = {}
local staticIronSightOffsetMatrix = CFrame.new()
local crosshairGui = nil
local defaultScopeImage = nil
local TimeSinceLastRespawn = 0
local TimeSinceLastGunUpdate = 0
local storedTracks = {}
local BulletID = 0
local playInitialSound = false
local AnimationsPreloaded = {}
local DISABLEGUNDRAWTAKEOUT = false

local bobticks = 0
local idleticks = 0
local swayticks = 0
local deltaSwayX = 0
local deltaSwayY = 0
local currentAccuracy = 0
local lastRunXPosition = 0
local TweenedAimPoint = Vector3.new()
local ShotsInSuccession = 0

local Temp1 = nil
local Temp2 = nil
local t = {}

local gunSystemEvents = {}

for i = 1, #script.Events:GetChildren() do
	local event = script.Events:GetChildren()[i]
	if (event:IsA('BindableEvent')) then
		gunSystemEvents[event.Name] = event
	end
end

local Ready = false
PositionGun:Initialize(script)

function getGunStats(weaponConfig)
	local gunStats = {}
	local function check(data, parentInstance)
		for _,v in cpairs(parentInstance:GetChildren()) do
			local entry = {}
			if ( v:IsA("ValueBase") ) then
				entry.Value = v.Value
			end
			if ( #v:GetChildren() > 0 ) then
				check(entry, v)
			end

			for attrName,attrValue in cpairs(v:GetAttributes()) do
				entry[attrName] = attrValue
			end
			data[v.Name] = entry
		end
	end
	check(gunStats, weaponConfig.Stats)
	return gunStats
end

Player.CharacterAdded:Connect(function(character)
	Humanoid = character:WaitForChild('Humanoid', 60)
	HumanoidRootPart = character.PrimaryPart
	CharacterHead = character:FindFirstChild('Head') or HumanoidRootPart

	character:GetPropertyChangedSignal('PrimaryPart'):Connect(function()
		if (character.PrimaryPart) then
			HumanoidRootPart = character.PrimaryPart
			CharacterHead = character:FindFirstChild('Head') or HumanoidRootPart
			CurrentlyInvisible = false
			updateCharacterVisibility()
		end
	end)

	Character = character
	
	CrosshairRaycastParams:AddToFilter(character)
end)

local Keybinds = Player:WaitForChild('GunSystemKeybinds')


ReplicatedStorage.GunEvent.GunForceEnable.OnClientEvent:Connect(function()
	while( not Ready ) do
		wait()
	end

	script.IsEnabled.Value = true
	takeoutWeapon( gunCurrentSlot, true )
	script.ForceRunning.Value = false
end)

local GunPlugins = Instance.new("Folder")
GunPlugins.Name = "GunPlugins"
GunPlugins.Parent = script






print("Initializing Gun System")

local function clampMagnitude(vector, maxMagnitude)
	return (vector.Magnitude > maxMagnitude and (vector.Unit * maxMagnitude) or vector)
end

function getInventoryItem( slot )
	if (slot == gunCurrentSlot and gunCurrentInventory) then
		return gunCurrentInventory
	end

	local Inventory = getViewablePlayer().GunInventory
	local Children = Inventory:GetChildren()
	for i=1,#Children do
		local Child = Children[i]
		local Slot = Child:FindFirstChild("Slot")
		if ( Slot ~= nil ) then
			if ( Slot.Value == slot ) then
				return Child
			end
		end		
	end
	return nil
end

function destroyWeapons(ignore)
	reloading = false

	
	local old = getCamera():FindFirstChild("CurrentWeapon")
	if ( old ~= nil ) then
		old.Parent = nil
		spawn(function()
			old:Destroy()
		end)
	end

	
	if ( gunWorldModel ~= nil ) then
		if ( ignore == nil or not ignore ) then
			ReplicatedStorage.GunEvent.GunDestroy:FireServer()
		end
		gunWorldModel = nil
	end
end

local function locateBone(Parent, BoneName)
	local Bone = nil
	for _,v in cpairs(Parent:GetChildren()) do
		if ( v:IsA("Bone") ) then
			if ( v.Name == BoneName ) then
				return v
			end

			local t = locateBone(v, BoneName)
			if ( t ) then
				Bone = t
				break
			end
		end
	end

	return Bone
end

function isDrawAnimation(Animation)
	if ( not Animation ) then
		return
	end

	local AnimName = tostring(Animation)
	return AnimName:find("^Draw") or AnimName:find("^Equip")
end

local AimInvisibleParts = {}
local tempConnections = {}
function takeoutWeapon( weaponSlot, forceTakeout, IgnoreSafeTakeoutTime )
	forceTakeout = forceTakeout or false

	if ( weaponSlot == gunCurrentSlot and (gunViewModel ~= nil and not forceTakeout) ) then
		return
	end

	if ( getHumanoid() == nil ) then
		return
	end

	if ( IsDead ) then
		return
	end

	
	local InventoryItem = getInventoryItem( weaponSlot )

	if ( InventoryItem == nil ) then
		return
	end

	local weapon = InventoryItem.Value
	if ( weapon == nil ) then
		return
	end

	gunCurrentInventory = InventoryItem

	holsterWeapon = true
	RequiresManualRechamber = InventoryItem.Rechambering.Value
	
	
	CAMERA_ROATION_BASE = nil
	storedTracks = {}
	currentlyPlayingAnimationPriorityMap = {}
	RepeatShoot = 0
	clearReloadFlags()

	debug.profilebegin("Destroy Old Weapon")
	destroyWeapons()
	debug.profileend()

	if ( weapon == nil or weapon:FindFirstChild("ViewModel") == nil ) then
		return
	end

	pcall(function() getPlayer():FindFirstChild("CurrentSelected").Value = weaponSlot end)

	
	local AnimSaves = weapon.ViewModel:FindFirstChild("AnimSaves")
	if ( AnimSaves ) then
		AnimSaves:Destroy()
	end

	
	local temp = weapon.ViewModel:Clone()
	local pointer = Instance.new("ObjectValue")
	pointer.Name = "Pointer"
	pointer.Value = weapon
	pointer.Parent = temp
	temp.Name = "CurrentWeapon"
	temp.Parent = getCamera()

	
	debug.profilebegin("Metadata setup")
	local Objects = temp:GetDescendants()
	
	for i = 1, #Objects do
		local v = Objects[i];
		if ( v:IsA("BasePart") ) then
			v.CanCollide = false
			v.Anchored = false
			v.CastShadow = false
		end
	end
	debug.profileend()

	
	debug.profilebegin("Copy Plugins")
	GunPlugins:ClearAllChildren()
	local CustomP = weapon:FindFirstChild("Plugins")
	if ( CustomP ) then
		local Children = CustomP:GetChildren()
		for i = 1, #Children do
			local v = Children[i]
			
			v:Clone().Parent = GunPlugins
		end
	end
	debug.profileend()

	
	debug.profilebegin("Finalize Takeout")
	previousWeapon = gunCurrentSlot
	gunCurrentSlot = weaponSlot
	gunCurrent = weapon

	gunCurrentStats = getGunStats(weapon)

	if (gunViewModel) then
		gunViewModel.Parent = nil
	end
	gunViewModel = temp
	gunViewModel.PrimaryPart.Anchored = true
	script.CurrentWeapon.Value = gunCurrent
	ReplicatedStorage.GunEvent.ClientUpdate:FireServer(gunCurrentSlot, isAiming(), crouched, running, getHumanoid().JumpPower, getCamera().CFrame, Temp1 ~= nil, t["Temp1"] == t["Temp2"])
	gunSystemEvents.OnGunChange:Fire(weapon, gunViewModel, InventoryItem)
	debug.profileend()

	
	debug.profilebegin("Find Aimparts")
	AimInvisibleParts = {}
	local children = gunViewModel:GetDescendants()
	for i = 1, #children do
		local v = children[i]
		
		if ( v:IsA("BasePart") and v.Name == "AimInvisible" ) then
			AimInvisibleParts[#AimInvisibleParts+1] = v
		end
	end
	gunViewModel.DescendantAdded:Connect(function(v)
		if ( v:IsA("BasePart") and v.Name == "AimInvisible" ) then
			AimInvisibleParts[#AimInvisibleParts+1] = v
		end
	end)
	debug.profileend()

	local CURGUN = gunCurrent

	
	debug.profilebegin("Temporary Attachment Initialize")
	for _,v in cpairs(AttachmentData) do
		if ( v and v.Parent ) then
			v:Destroy()
		end
	end
	AttachmentData = {}
	for _,v in cpairs(gunViewModel.PrimaryPart:GetChildren()) do
		if ( v:IsA("Attachment") ) then
			local BoneName = v:GetAttribute("Bone")
			if ( BoneName ) then
				local Bone = locateBone(gunViewModel.PrimaryPart, BoneName)
				if ( Bone ) then
					local AttachmentPart = script.Data.AttachmentPart:Clone()
					AttachmentPart.Name = v.Name

					local AttachData = {
						Reference = v,
						Bone = Bone,
						Offset = Bone.WorldCFrame:Inverse() * v.WorldCFrame * CFrame.fromEulerAnglesXYZ(0, -math.pi/2, 0),
						Part = AttachmentPart,
					}

					AttachmentData[#AttachmentData+1] = AttachData
					AttachmentPart.Parent = gunViewModel
				else
					warn("--GunController. Failed to locate bone", BoneName)
				end
			end
		end
	end
	debug.profileend()

	
	ReplicatedStorage.GunEvent.GunCreate:FireServer( weaponSlot )

	
	task.spawn(computeGunOffsetMatrix, gunCurrent, gunViewModel)

	
	local Stats = getInternalGunStats(gunCurrent)

	
	local TakeoutTime = (tonumber(Stats.TakeoutTime and Stats.TakeoutTime.Value) or WeaponSwitchTransitionTime)
	GunTakeoutCanShootTime = tick() + math.max(TakeoutTime, 0)

	
	takeoutRot = IgnoreSafeTakeoutTime and 0 or 75
	holsterWeapon = false
	playInitialSound = true

	
	local AnimationController = gunViewModel:FindFirstChild("Humanoid") or gunViewModel:FindFirstChildOfClass("AnimationController")
	local Animations = weapon:FindFirstChild("Animations"):GetChildren()
	for i=1,#Animations do
		local Animation = Animations[i]	
		local Track = AnimationController:LoadAnimation(Animation)
		Track.Name = Animation.Name
		Track:Play(nil, 0.05, 1)
		storedTracks[Track] = Track

		task.spawn(function()
			while(Track.Length <= 0) do
				task.wait()
			end
			Track:Stop(nil)
		end)
	end

	
	SetGunAnimation( "Idle", true ) 
	SetGunAnimation( "Draw", true ) 

	
	local Sound = nil
	if ( (not findAnimationReference("Draw") or not findAnimationReference("Draw"):FindFirstChild("Initial")) and not weapon.Sounds:FindFirstChild("Draw") ) then
		Sound =  script.Data.Draw:Clone()
	else
		if ( weapon.Sounds:FindFirstChild("Draw") ) then
			Sound = weapon.Sounds:FindFirstChild("Draw"):Clone()
		end
	end

	
	if ( Sound ) then
		Sound.Parent = gunViewModel.PrimaryPart
		Sound.SoundGroup = Sound.SoundGroup or SoundGroupManager:GetSoundGroup('Game');
		if ( not Sound.Playing ) then
			Sound:Play() 
		end
	end

	
	playInitialSound = not Sound
	gunWorldModel = getCharacter():FindFirstChild("WorldModel")
	return gunCurrent
end

function computeGunOffsetMatrix(CurrentWeaponData, ViewModel)
	local TempViewModel = ViewModel:Clone()
	TempViewModel.Name = "TempViewModel"
	TempViewModel.Parent = camera

	local tempVMPrimaryPart = TempViewModel.PrimaryPart

	for _,v in cpairs(AttachmentData) do
		if ( v.Part ) then
			v.PartTemp = TempViewModel:FindFirstChild(v.Part.Name)
			
			v.PartTemp.Anchored = true
			v.BoneTemp = locateBone(tempVMPrimaryPart, v.Bone.Name)
		end
	end

	
	local desc = TempViewModel:GetDescendants()
	for i=1,#desc do
		local v = desc[i]
		if ( v:IsA("BasePart") ) then
			v.Transparency = 1
		end

		if ( v:IsA("Decal") or v:IsA("SurfaceAppearance") ) then
			v:Destroy()
		end

		if ( v:IsA("Light") or v:IsA("BillboardGui") or v:IsA("Beam") ) then
			v.Enabled = false
		end
	end

	local AnimationController = TempViewModel:FindFirstChildOfClass("AnimationController")
	local ReferencePose = gunCurrent.Animations:FindFirstChild("ReferencePose") or gunCurrent.Animations:FindFirstChild("Idle")
	local Track = AnimationController:LoadAnimation(ReferencePose)

	local takeoutAnim = function(Position)
		Track:Play(0, 1, 1)
		Track.TimePosition = 0
		local dt = gunSystemEvents.OnPreRender.Event:Wait()
		
		
		if ( tempVMPrimaryPart ) then
			tempVMPrimaryPart.CFrame = camera.CFrame * CFrame.new(0, -4, 8)
		end
		return dt
	end

	local computeOffset = function()
		local root = tempVMPrimaryPart
		if ( not root ) then
			return gunCurrent
		end
		local TempViewModelCamera = getViewModelPart("CAMERA", TempViewModel)
		if ( TempViewModelCamera ) then
			local rootMatrix = root.CFrame
			local ironSightMatrix = TempViewModelCamera.CFrame
			if ( TempViewModelCamera:GetAttribute("OrientationOffset") ) then
				local Orientation = TempViewModelCamera:GetAttribute("OrientationOffset")
				ironSightMatrix = ironSightMatrix * CFrame.fromEulerAnglesXYZ(Orientation.X, Orientation.Y, Orientation.Z)
			end

			staticIronSightOffsetMatrix = ironSightMatrix:toObjectSpace(rootMatrix)
		else
			staticIronSightOffsetMatrix = CFrame.new(0, -2.125, 0)
		end

		local cameraBone = TempViewModel:FindFirstChild("Cam") or TempViewModel:FindFirstChild("CameraBone") or TempViewModel:FindFirstChild("CameraPart")
		if ( cameraBone ) then
			CAMERA_ROATION_BASE = cameraBone.CFrame:toObjectSpace(root.CFrame)
		end
	end

	
	local attempts = 0
	local WaitTime = 60
	while (Track and Track.Length<=0 and gunCurrent == CurrentWeaponData and attempts < 60) do
		attempts = attempts + 1
		local dt = takeoutAnim()
		WaitTime = WaitTime + dt
	end

	
	local StartTime = tick()
	while(tick()-StartTime < WaitTime and gunCurrent == CurrentWeaponData) do
		takeoutAnim()
		gunSystemEvents.OnRender.Event:Wait()
		computeOffset()
	end

	TempViewModel:Destroy()
end

function findAnimationReference( name )
	if ( not gunCurrent ) then
		return nil
	end

	local animationFolder = gunCurrent:FindFirstChild("Animations")
	if ( not animationFolder ) then
		return nil
	end	

	
	if ( AnimationRedirectTable[name] ) then
		for _,v in cpairs(AnimationRedirectTable[name]) do
			local animationObject = gunCurrent.Animations:FindFirstChild(v)
			if ( animationObject ) then
				return animationObject
			end
		end
	end

	local animationObject = gunCurrent.Animations:FindFirstChild(name)
	if ( animationObject == nil ) then
		return nil
	end

	return animationObject
end

local totemap = {
	["BoolValue"] = function(Input)
		return Input.Value == true and 10 or 0
	end,
	["NumberValue"] = function(Input)
		return Input.Value * 2
	end,
	["IntValue"] = function(Input)
		return Input.Value * 3
	end,
	["StringValue"] = function(Input)
		local t = 0
		for i = 1, string.len(Input.Value) do
			t = t + string.byte(string.sub(Input.Value, i, i))
		end
		return t
	end,
}

function onAnimationFinish()
	local CurrentTrack = currentlyPlayingAnimation
	getNextAnimationLogic()	
	gunSystemEvents.OnGunAnimationFinish:Fire(CurrentTrack)
end

function getNextAnimationLogic()

	
	local AnimationObject = findAnimationReference(currentlyPlayingAnimationName)
	if ( AnimationObject ) then
		local Finished = AnimationObject:FindFirstChild("Finished")
		if ( Finished and Finished.Value ) then
			SetGunAnimation(Finished.Value.Name)
			return
		end
	end

	
	local IsEndOfAction = currentlyPlayingAnimationName == "Shoot"
		or isDrawAnimation(currentlyPlayingAnimationName) 
		or currentlyPlayingAnimationName == "ReloadEnd"
		or currentlyPlayingAnimationName == "Reload"
		or currentlyPlayingAnimationName == "Special"

	
	local IsEndOfMovement = isBaseAnimation(currentlyPlayingAnimationName)

	
	
	
	
	

	
	if ( IsEndOfAction ) then
		clearReloadFlags()
		SetGunAnimation("Idle", false)
		return
	end

	
	if ( currentlyPlayingAnimationName == "Rechamber" ) then
		onRechamberGun()
		return
	end

	
	if ( reloading ) then
		if ( not reloadingIndividual ) then
			onReloadGun()

			clearReloadFlags()
		else
			reloadLogic()
		end
		return
	end

	
	if ( not currentlyPlayingAnimation.Looped and IsEndOfMovement ) then
		SetGunAnimation(currentlyPlayingAnimationName, false)
		return
	end

	
	
end

function isGunDrawDisabled()
	return Player:FindFirstChild("GunDrawDisabled") and Player.GunDrawDisabled.Value
end

local animationPriorityMap = {
	["ReferencePose"] = Enum.AnimationPriority.Core,
	["Idle"] = Enum.AnimationPriority.Core,
	["Walk"] = Enum.AnimationPriority.Idle,
	["Run"] = Enum.AnimationPriority.Movement,
	["Draw"] = Enum.AnimationPriority.Action,
	["Shoot"] = Enum.AnimationPriority.Action2,
	["Reload"] = Enum.AnimationPriority.Action3,
	["ReloadStart"] = Enum.AnimationPriority.Action3,
	["ReloadEnd"] = Enum.AnimationPriority.Action3,
}

function isBaseAnimation(AnimationName)
	if ( not AnimationName ) then
		return true
	end

	return string.match(AnimationName, "Run") ~= nil
		or string.match(AnimationName, "Idle") ~= nil
		or string.match(AnimationName, "Walk") ~= nil
		or string.match(AnimationName, "ReferencePose") ~= nil
end

function getAnimationPriority(animationObject)
	local animationName = animationObject.Name

	if ( animationObject:GetAttribute("Priority") ) then
		return Enum.AnimationPriority[animationObject:GetAttribute("Priority")]
	end

	if ( animationPriorityMap[animationName] ) then
		return animationPriorityMap[animationName]
	else
		
		for k,v in cpairs(animationPriorityMap) do
			if ( string.match(animationName, k) ) then
				return v
			end
		end

		return Enum.AnimationPriority.Action3
	end
end

function isAnimationPlaying(animationName)
	local track = storedTracks[findAnimationReference(animationName)]
	if ( not track ) then
		return false
	end

	return track.IsPlaying
end

local IsCurrentAnimationFinished = true
function SetGunAnimation(DesiredAnimationName, ForceAnimation, transition, forceSpeed, forceLooped)
	transition = transition and transition or 0
	forceSpeed = forceSpeed and forceSpeed or 1
	forceLooped = forceLooped and forceLooped or nil

	if ( transition <= 0 ) then
		transition = nil
	end

	if ( forceSpeed <= 0 ) then
		forceSpeed = nil
	end

	local IsDifferentAnimation = DesiredAnimationName ~= currentlyPlayingAnimationName
	local IsBaseAnim = isBaseAnimation(currentlyPlayingAnimationName)
	local ToBaseAnim = isBaseAnimation(DesiredAnimationName)

	
	local ShouldPlayAnimation = ForceAnimation or IsCurrentAnimationFinished or not currentlyPlayingAnimation or IsDifferentAnimation
	if ( not ShouldPlayAnimation ) then
		return
	end

	
	local animationObject = findAnimationReference(DesiredAnimationName)
	if ( not animationObject ) then
		return
	end

	
	local Animator = gunViewModel:FindFirstChild("Humanoid") or gunViewModel:FindFirstChildOfClass("AnimationController")
	if ( not Animator ) then
		return
	end

	
	local animationPriority = getAnimationPriority(animationObject)
	local lastTrackWithPriority = currentlyPlayingAnimationPriorityMap[animationPriority]
	if ( lastTrackWithPriority ) then
		lastTrackWithPriority:Stop(transition)
	end

	
	local playingAnimationTrack = storedTracks[animationObject]
	if ( not playingAnimationTrack ) then
		playingAnimationTrack = Animator:LoadAnimation(animationObject)
		playingAnimationTrack.Priority = animationPriority
		playingAnimationTrack.Name = animationObject.Name
		storedTracks[animationObject] = playingAnimationTrack
	end

	
	currentlyPlayingAnimation = playingAnimationTrack
	currentlyPlayingAnimationName = DesiredAnimationName
	currentlyPlayingAnimationPriorityMap[animationPriority] = playingAnimationTrack

	
	IsCurrentAnimationFinished = false
	currentlyPlayingAnimation.TimePosition = 0
	if ( not currentlyPlayingAnimation.IsPlaying ) then
		local SpeedMultiplier = tonumber(animationObject:GetAttribute("AnimationSpeed") or nil) or 1
		currentlyPlayingAnimation:Play(transition, 1, forceSpeed * SpeedMultiplier)
	end

	
	if ( ToBaseAnim ) then
		currentlyPlayingAnimation.Looped = true
	end

	
	if ( forceLooped ~= nil ) then
		currentlyPlayingAnimation.Looped = forceLooped
	end

	
	if ( currentlyPlayingAnimationKeyFrameChangeFunction ~= nil ) then
		currentlyPlayingAnimationKeyFrameChangeFunction:Disconnect()
		currentlyPlayingAnimationKeyFrameChangeFunction = nil
	end

	
	if ( currentlyPlayingAnimationKeyFrameChangeFunction2 ~= nil ) then
		currentlyPlayingAnimationKeyFrameChangeFunction2:Disconnect()
		currentlyPlayingAnimationKeyFrameChangeFunction2 = nil
	end

	
	currentlyPlayingAnimationKeyFrameChangeFunction = currentlyPlayingAnimation.KeyframeReached:connect(keyFrameReachedFunc)

	
	if ( not isBaseAnimation(currentlyPlayingAnimation.Name) ) then
		currentlyPlayingAnimationKeyFrameChangeFunction2 = currentlyPlayingAnimation.Stopped:Connect(onAnimationFinish)
	end

	
	gunSystemEvents.OnGunAnimationChange:Fire(animationObject, currentlyPlayingAnimation)
	playInitialSound = true
end

function keyFrameReachedFunc( frameName )		
	if ( frameName == "Reload" ) then
		onReloadGun()
	end

	if ( frameName == "Rechamber" ) then
		onRechamberGun()
	end

	
	if ( string.len(frameName) > 0 ) then
		local PotentialGunSound = currentlyPlayingAnimationName .. frameName
		playGunSound(PotentialGunSound)
		playGunSoundKeyframe(frameName)
	end

	gunSystemEvents.OnGunAnimationKeyframeReached:Fire(currentlyPlayingAnimation, frameName)
end

function clearReloadFlags()
	if ( reloading ) then
		ReplicatedStorage.GunEvent.GunReloadEnd:FireServer()
	end

	cancelReloadingIndividual = false
	reloadingIndividual = false
	rechambering = false
	reloading = false
end

function rechamberGun()
	rechambering = true
	SetGunAnimation( "Rechamber", true )
	playGunSound("Rechamber")
	ReplicatedStorage.GunEvent.GunRechamber:FireServer()
end

function check_rechamber()
	local IsBaseAnimation = isBaseAnimation(currentlyPlayingAnimationName)
	if ( IsBaseAnimation and RequiresManualRechamber ) then
		rechamberGun()
		return
	end
end

function onRechamberGun()
	RequiresManualRechamber = false
	rechambering = false
	reloading = false
end

function onReloadGun()
	if ( not reloading ) then
		return
	end

	if ( isGunDrawDisabled() ) then
		return
	end

	local InventoryItem = getInventoryItem(gunCurrentSlot)
	if ( not InventoryItem ) then
		return
	end

	
	
	
	
	
	
	
	
	
	

	

	
	
	
	

	if ( gunCurrentStats.NeedsAmmo.ReloadPerformsRechamber and gunCurrentStats.NeedsAmmo.ReloadPerformsRechamber.Value ) then
		RequiresManualRechamber = false
	end

	
end

function playGunSoundKeyframe(KeyframeName)
	local Sound = findAnimationReference(currentlyPlayingAnimationName) and findAnimationReference(currentlyPlayingAnimationName):FindFirstChild(KeyframeName)
	if ( Sound ) then
		local s = Sound:Clone()
		s.Parent = getRoot()
		s.SoundGroup = s.SoundGroup or SoundGroupManager:GetSoundGroup('Game');
		s:Play()
		Debris:AddItem(s, s.TimeLength)

		if ( SoundService.RespectFilteringEnabled ) then
			ReplicatedStorage.GunEvent.GunRequestSound:FireServer(currentlyPlayingAnimationName .. Sound.Name, true)
		end

		return s
	end

	return nil
end

function playGunSound(SoundName, waitFor, forceSpeed, forceVolume)
	local SoundTo = getRoot()

	
	local Sound = nil
	local PotentialSounds = {}
	local Children = gunCurrent.Sounds:GetChildren()
	for i=1, #Children do
		local Child = Children[i]
		if ( Child.Name == SoundName ) then
			if ( not Child.Playing ) then
				Sound = Child
				PotentialSounds[#PotentialSounds+1] = Child
			end
		end
	end

	if ( #PotentialSounds > 0  ) then
		Sound = PotentialSounds[math.random(1,#PotentialSounds)]
	end

	
	if ( Sound ) then
		forceSpeed = forceSpeed or 1.0
		forceVolume = forceVolume or 1.0

		local TempSound = Sound:Clone()
		TempSound.Parent = SoundTo
		TempSound.PlaybackSpeed = Sound.PlaybackSpeed * forceSpeed
		TempSound.Volume = TempSound.Volume * forceVolume
		TempSound.SoundGroup = TempSound.SoundGroup or SoundGroupManager:GetSoundGroup('Game');
		TempSound:Play()

		Debris:AddItem(TempSound, TempSound.TimeLength)

		if ( SoundService.RespectFilteringEnabled and SoundName ~= "FireSound" ) then
			ReplicatedStorage.GunEvent.GunRequestSound:FireServer(SoundName)
		end

		return TempSound
	else
		return playGunSoundKeyframe(SoundName)
	end
end

function stopGunSound(SoundName)
	if ( gunWorldModel == nil ) then
		return
	end
	if ( gunWorldModel:FindFirstChild("Handle") == nil ) then
		return
	end

	
	local Sound = gunWorldModel.Handle:FindFirstChild(SoundName)

	
	if ( Sound ~= nil ) then
		Sound:Stop()
	end
end





function getPlayer()
	return Player or Players.LocalPlayer
end

function getCharacter()
	if (Character) then
		return Character
	end

	return Player and Player.Character
end

function getRoot()
	return HumanoidRootPart
end

function getHumanoid()
	return Humanoid
end

function IsInAir()
	
	
	
	
	local state = getHumanoid():GetState()

	return state == Enum.HumanoidStateType.FallingDown 
		or state == Enum.HumanoidStateType.Climbing
		or state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
end

function getCustomCamera()
	return customCamera
end

local Testerz = 1.052
local Testerz2 = 1.054
local silentAimEnabled = false
local silentAimTarget = nil

function getLookDirection()
	

	
	
	
	

	
	
	

	

	

	

	

	
	
	
	

	
	

	return getCustomCamera().CurrentDirection.Value
end

function getCamera()
	return camera
end

function getMouse()
	return Player:GetMouse()
end

function tween( valueA, valueB, amount )
	amount = math.min(1, math.max(0, amount))

	if ( typeof(valueA) == "Vector3" ) then
		return Vector3.new(
			tween(valueA.X, valueB.X, amount),
			tween(valueA.Y, valueB.Y, amount),
			tween(valueA.Z, valueB.Z, amount)
		)
	end

	return valueA + (valueB - valueA) * amount
end

function canAim()
	local CanAim = gunCurrentStats.Zoom.CanZoom.Value

	
	local CanZoomWhileReloading = gunCurrentStats.Zoom.CanZoomWhileReloading and gunCurrentStats.Zoom.CanZoomWhileReloading.Value
	CanZoomWhileReloading = CanZoomWhileReloading == nil and true or CanZoomWhileReloading
	if ( reloading and not CanZoomWhileReloading ) then
		CanAim = false
	end

	
	local CanZoomWhileEmpty = gunCurrentStats.Zoom.CanZoomWhileEmpty and gunCurrentStats.Zoom.CanZoomWhileEmpty.Value
	CanZoomWhileEmpty = CanZoomWhileEmpty == nil and true or CanZoomWhileEmpty
	local InventoryItem = getInventoryItem(gunCurrentSlot)
	if ( InventoryItem and InventoryItem.BulletsInMagazine.Value <= 0 and not CanZoomWhileEmpty ) then
		CanAim = false
	end

	return CanAim
end

function updateAiming(delta)

	
	local wasAiming = isAiming()
	if ( not script.DisabledGun.Value ) then
		script.Aimed.Value = (holdingRight or mobileFire) and canAim() and not holsterWeapon and not isGunDrawBlocked()
	end

	if ( isSpectating ) then
		script.Aimed.Value = script.Spectating.Value.Aiming.Value
	end

	if ( isAiming() ~= wasAiming ) then
		gunHasChanged = true

		if ( isAiming() ) then
			SetGunAnimation("AimStart")
		else
			if ( string.find(currentlyPlayingAnimationName, "Aim") or isBaseAnimation(currentlyPlayingAnimationName) ) then
				if ( aimTween < 0.1 ) then
					SetGunAnimation("AimEnd")
				else
					
				end
			end
		end
	end

	if ( aimTween < 0.5 and isAiming() and currentlyPlayingAnimationName ~= "AimLoop" ) then
		SetGunAnimation("AimLoop")
	end

	local aimSpeedModifier = gunCurrentStats.Zoom.AimSpeed.Value

	local AttachmentReticle = getAttachment('AttachmentReticle')
	if ( AttachmentReticle and AttachmentReticle.Modifiers:FindFirstChild("AimSpeed") ) then
		local aimSpeedMod = math.clamp(AttachmentReticle.Modifiers.AimSpeed.Value, 0, 2)
		aimSpeedModifier = aimSpeedModifier * aimSpeedMod
	end

	aimSpeedModifier = aimSpeedModifier * (tonumber(_G.GunModifiers["GunAimSpeedMultiplier"] or nil) or 1)
	aimSpeedModifier = aimSpeedModifier * (tonumber(getInternalGunMultipliers()["GunAimSpeedMultiplier"] or nil) or 1)

	local t = aimTween
	local direction = -1
	if ( not isAiming() or reloading ) then
		direction = 1
	end

	t = t + (aimSpeedModifier*direction)*delta*5
	t = math.max( 0, math.min( 1, t ) )
	aimTween = t
end

function onHitGround()
	

	ScopeBlurRatioY = ScopeBlurRatioY + 0.2
	gunSystemEvents.OnHitGround:Fire()
end

function isGunDrawBlocked()
	return BlockedGun or script.DisabledCamera.Value
end

local SwayBreathMultiplier = 1
function doPositionGun(delta, ViewModel)
	if ( gunCurrent == nil ) then
		return
	end

	local root = getRoot()
	if ( root == nil ) then
		return
	end

	
	if ( takeoutRot > 1 ) then
		aimTween = 1
	end

	
	if ( holsterWeapon ) then
		takeoutRot = 75
	elseif ( isGunDrawBlocked() ) then
		takeoutRot = tween( takeoutRot, 75, 0.1 )
	else
		takeoutRot = tween( takeoutRot, 0, 0.2 )
	end

	local vmPrimaryPart = ViewModel and ViewModel.PrimaryPart

	
	if ( not vmPrimaryPart) then
		return
	end

	debug.profilebegin("Compute Offsets")

	local customCamera = getCustomCamera()

	
	SHOOTING_OFFSET = tween( SHOOTING_OFFSET, 0, delta * 6 )
	RECOIL_HORIZONTAL = tween( RECOIL_HORIZONTAL, 0, 12 * delta )
	RECOIL_VERTICAL = RECOIL_VERTICAL - (12 * delta)
	RECOIL_VERTICAL_CURRENT = RECOIL_VERTICAL_CURRENT + RECOIL_VERTICAL
	if ( RECOIL_VERTICAL_CURRENT < 0 ) then
		RECOIL_VERTICAL_CURRENT = 0
		RECOIL_VERTICAL = 0
	end

	
	GUN_DIP_SPEED = GUN_DIP_SPEED - (1/8) * delta
	ScopeBlurRatioY = math.clamp(ScopeBlurRatioY + GUN_DIP_SPEED * 8, 0, 2)
	GUN_DIP = GUN_DIP + GUN_DIP_SPEED
	if ( GUN_DIP < 0 or script.DisabledGun.Value ) then
		GUN_DIP_SPEED = 0
		GUN_DIP = 0
	end
	if ( GUN_DIP > 1 ) then
		GUN_DIP = 1
	end

	
	local RotateWithCameraTurn = 1
	RotateWithCameraTurn = (gunCurrentStats.Offset.RotateWithCameraTurn and gunCurrentStats.Offset.RotateWithCameraTurn.Value) and 1 or 0

	
	

	
	local div = 2
	local EnabledBob = script.ViewBobEnabled.Value
	bobticks = bobticks + (speed*(Jumping and 0 or 1))
	local TX = math.cos(bobticks / div)
	local TY = math.cos(bobticks / (div / 2))
	RUN_BOB_X = TX
	RUN_BOB_Y = TY

	
	bobSpeed = tween( bobSpeed, speed, 0.1 )
	local BOB_SCALE = tween( 0.05, 0.15, aimTween ) 
	local RUN_BOB_SCALE = BOB_SCALE * bobSpeed * speedModifier
	RUN_BOB_X = RUN_BOB_X * RUN_BOB_SCALE
	RUN_BOB_Y = RUN_BOB_Y * RUN_BOB_SCALE
	local bobOffset = Vector3.new( RUN_BOB_X, (RUN_BOB_Y*0.6), 0 )

	
	if ( (lastRunXPosition > 0 and TX < 0) or (lastRunXPosition < 0 and TX > 0) and not IsInAir() ) then
		
		
		
		
		
	end
	lastRunXPosition = TX

	
	local desiredSwaySteadyMultiplier = (holdingShift and 0 or 1) * serverGunConfiguration:FindFirstChild("sv_scope_sway_multiplier").Value
	SwaySteadyMultiplier = tween(SwaySteadyMultiplier, desiredSwaySteadyMultiplier, delta*4)
	swayticks = swayticks + SwaySteadyMultiplier*delta*(1-aimTween)
	idleticks = idleticks + SwaySteadyMultiplier*delta 
	local IDLE_BOB_SPED = scoped and 2.0 or 0.5
	IDLE_BOB_X = math.cos((idleticks / 240) * IDLE_BOB_SPED)	
	IDLE_BOB_Y = math.cos((idleticks / 120) * IDLE_BOB_SPED)

	
	if ( not ThirdPerson and not getHumanoid().Sit ) then
		customCamera.BobOffset.Value = Vector3.new( RUN_BOB_X * 3, RUN_BOB_Y * 3, 0 )
	else
		RUN_BOB_X = 0
		RUN_BOB_Y = 0
		bobOffset = Vector3.new()
		customCamera.BobOffset.Value = Vector3.new()
	end

	
	local eye = (getCamera().CFrame*CFrame.new(customCamera.BobOffset.Value*-1)).Position
	IsInFirstPerson = customCamera.CurrentOffset.Value < 0.66
	local AimedAndScoped = isFullyAimed() and isScoped()
	if ( not IsInFirstPerson or AimedAndScoped or getPlayer():WaitForChild("GunDrawDisabled").Value or DISABLEGUNDRAWTAKEOUT or takeoutRot > 40 ) then
		eye = Vector3.new(0,0,0)

		if ( IsDisplayingViewModel ) then
			IsDisplayingViewModel = false
			gunSystemEvents.OnGunViewModelDisable:Fire(gunCurrent, ViewModel)
		end
	elseif ( not IsDisplayingViewModel ) then
		IsDisplayingViewModel = true
		gunSystemEvents.OnGunViewModelEnable:Fire(gunCurrent, ViewModel)
	end
	eye = eye + Vector3.new( 0, -GUN_DIP, 0 )

	local actualTakeoutRot = DISABLEGUNDRAWTAKEOUT and 0 or takeoutRot
	debug.profileend()

	
	PositionGun:Position(ViewModel, delta, getCamera(), eye, staticIronSightOffsetMatrix, CAMERA_ROATION_BASE, SHOOTING_OFFSET)

	
	do
		debug.profilebegin("Compute Crosshair")
		local desiredAccuracy = 128 / gunCurrentStats.Accuracy.Value
		desiredAccuracy = desiredAccuracy + (GetCurrentSpeed() / gunCurrentStats.Accuracy.RunModifier.Value) * 24
		if ( crouched ) then
			desiredAccuracy = desiredAccuracy / gunCurrentStats.Accuracy.CrouchModifier.Value
		end
		desiredAccuracy = tween( desiredAccuracy / gunCurrentStats.Accuracy.AimModifier.Value, desiredAccuracy, aimTween*aimTween )
		desiredAccuracy = desiredAccuracy + SHOOTING_OFFSET
		currentAccuracy = tween( currentAccuracy, desiredAccuracy, 0.1 )

		
		for i = 1, #AimInvisibleParts do
			local v = AimInvisibleParts[i]
			v.Transparency = isFullyAimed() and 1 or 0
		end

		
		updateCrosshair(delta)
		debug.profileend()
	end
end

function isFullyAimed()
	return aimTween < Minimum_Scope_Aim_Tween
end

function flip(x)
	return 1-x
end

function getAlphaSmoothStep(a, lowerExponent, upperExponent)
	return tween(math.pow(a, lowerExponent), flip(math.pow(flip(a), upperExponent)), a)
end

function updateCrosshair(Delta)
	if ( isFullyAimed() and isAiming() ) then
		ScopeBlurRatioX = tween(ScopeBlurRatioX, 0.0, Delta*6)
	else
		ScopeBlurRatioX = tween(ScopeBlurRatioX, 1.0, Delta*18)
	end
	ScopeBlurRatioY = tween(ScopeBlurRatioY, 0.0, Delta*6)

	
	scoped = aimTween < 0.02 and isScoped()
	if ( crosshairGui ~= nil ) then
		local center = crosshairGui.Center
		local scope = crosshairGui.Scope
		local reticleOffset = crosshairGui.ReticleOffset

		local crosshairDist = currentAccuracy * 3
		center.Visible = script.ShowCrosshair.Value and ((aimTween > 0.1) or (ThirdPerson and not scoped)) 
		reticleOffset.Visible = center.Visible;
		scope.Visible = true

		local scopeX = 0.5 + math.sign(ScopeBlurRatioX)*(math.pow(math.abs(ScopeBlurRatioX),3)/8)
		local scopeY = 0.5 + math.sign(ScopeBlurRatioY)*(math.pow(math.abs(ScopeBlurRatioY),3)/8)
		scope.Position = UDim2.new(scopeX, 0, scopeY, _G.IS_PLAYING_CONSOLE() and 0 or -18 )

		
		local PointFarAway = PLAYER_EYE + getCamera().CFrame.lookVector * 1024
		local RayToPointFarAway = Ray.new(PLAYER_EYE, PointFarAway-PLAYER_EYE)

		
		local HitResult = workspace:Raycast(PLAYER_EYE, PointFarAway-PLAYER_EYE, CrosshairRaycastParams);
		local PartHit, WorldHit = nil, PointFarAway

		if (HitResult) then
			PartHit, WorldHit = HitResult.Instance, HitResult.Position
		end
		

		local ProjectedPointIn2D1 = getCamera():WorldToScreenPoint(WorldHit)
		local ProjectedPointIn2D2 = getCamera():WorldToScreenPoint(PointFarAway)

		WorldLookAtPos = WorldHit

		TweenedAimPoint = tween(TweenedAimPoint, ProjectedPointIn2D1, 0.4)
		reticleOffset.Position = UDim2.new(0, TweenedAimPoint.X, 0, TweenedAimPoint.Y)
		center.Position = UDim2.new(0, ProjectedPointIn2D2.X-1, 0, ProjectedPointIn2D2.Y)

		local tSize = tween((1-aimTween)*4, 12, Vector2.new(TweenedAimPoint.X-ProjectedPointIn2D2.X, TweenedAimPoint.Y-ProjectedPointIn2D2.Y).Magnitude/32)
		reticleOffset.Size = UDim2.new(0, tSize, 0, tSize)
		reticleOffset.ImageTransparency = (ThirdPerson and 0 or 1) * (1.0-aimTween)

		if ( gunCurrent.Stats:FindFirstChild("CrosshairAim") ) then
			local crosshairAim = crosshairGui.CrosshairAim
			crosshairAim.ImageTransparency = aimTween
			crosshairAim.ImageColor3 = gunCurrent.Stats.CrosshairAim.ImageColor3
			crosshairAim.Image = gunCurrent.Stats.CrosshairAim.Image
			crosshairAim.Size = gunCurrent.Stats.CrosshairAim.Size
		else
			crosshairGui.CrosshairAim.ImageTransparency = 1
		end

		local scopeTrans = isScoped() and isFullyAimed() and 0.0 or 1.0 
		scope.ImageTransparency = scopeTrans
		scope.Frame1.BackgroundTransparency = scopeTrans
		scope.Frame2.BackgroundTransparency = scopeTrans
		scope.Frame3.BackgroundTransparency = scopeTrans
		scope.Frame4.BackgroundTransparency = scopeTrans

		local rx = getAlphaSmoothStep(ScopeBlurRatioX, 2, 4)
		local ry = getAlphaSmoothStep(ScopeBlurRatioY, 2, 4)
		local blurX = tween(0.5, 0.5 + (math.sign(ScopeBlurRatioX)*0.7), rx)
		local blurY = tween(0.5, 0.5 + (math.sign(ScopeBlurRatioY)*0.7), ry)
		scope.Blur.Position = UDim2.fromScale(blurX, blurY)
		scope.Blur.ImageTransparency = scopeTrans

		local ScopeTexture = defaultScopeImage
		local Attachment = getAttachment('AttachmentReticle')
		if ( Attachment and Attachment.Modifiers:FindFirstChild("Scoped") and Attachment.Modifiers.Scoped.Value and Attachment.Modifiers.Scoped:FindFirstChild('ScopeTextureId') ) then
			ScopeTexture = Attachment.Modifiers.Scoped.ScopeTextureId.Value
		elseif ( gunCurrentStats.Scoped.ScopeTextureId ) then
			ScopeTexture = gunCurrentStats.Scoped.ScopeTextureId.Value
		end

		if (scope.Image ~= ScopeTexture) then
			scope.Image = ScopeTexture
		end

		center.Crosshairs.Size = UDim2.fromOffset(crosshairDist * 2, crosshairDist * 2)
	end
end

function getAttachment(AttachmentName)
	local InventoryItem = getInventoryItem(gunCurrentSlot)
	if ( not InventoryItem ) then
		return
	end

	local Attachment = InventoryItem:FindFirstChild(AttachmentName)
	if ( not Attachment ) then
		return
	end

	return Attachment.Value
end

function getAttachments()
	local InventoryItem = getInventoryItem(gunCurrentSlot)
	if ( not InventoryItem ) then
		return {}
	end

	local t = {}
	local items = InventoryItem:GetChildren()
	
	for i = 1, #items do
		local v = items[i]
		if ( v:IsA("ObjectValue") and v.Value and string.find(v.Name, "Attachment") ) then
			t[#t+1] = v.Value
		end
	end
	return t
end





function enable()
	if ( script.IsEnabled.Value ) then
		return
	end
	script.IsEnabled.Value = true
end

function disable()
	if ( not script.IsEnabled.Value ) then
		return
	end
	script.IsEnabled.Value = false
	ReplicatedStorage.GunEvent['GunDisable']:FireServer()
	
end





function reloadLogic()
	local spd = tonumber(_G.GunModifiers["GunReloadSpeedMultiplier"]) or 1 
	spd = spd * tonumber(getInternalGunMultipliers()["GunReloadSpeedMultiplier"] or nil) or 1

	local InventoryItem = getInventoryItem(gunCurrentSlot)
	if ( not InventoryItem ) then
		return
	end

	local hasAmmo = InventoryItem.BulletsInReserve.Value > 0
	local maxCapacity = gunCurrentStats.MagazineCapacity.Value
	local bulletsInGun = InventoryItem.BulletsInMagazine.Value
	local isEmpty = bulletsInGun == 0
	RepeatShoot = 0 

	if ( hasAmmo and bulletsInGun < maxCapacity and not cancelReloadingIndividual ) then

		
		if ( gunCurrentStats.NeedsAmmo.RequiresManualRechamber and gunCurrentStats.NeedsAmmo.RequiresManualRechamber.Value ) then
			if ( isEmpty ) then
				RequiresManualRechamber = true
			end
		end

		local reloadIndividual = gunCurrentStats.NeedsAmmo.ReloadSingularBullet

		
		if ( not reloadIndividual or not reloadIndividual.Value ) then
			if ( isEmpty and gunCurrent.Animations:FindFirstChild("ReloadEmpty") ~= nil ) then
				SetGunAnimation("ReloadEmpty", true, 0.0, spd)
				playGunSound("ReloadEmptySound", false)
			else
				SetGunAnimation("Reload", true, 0.0, spd)
				playGunSound("ReloadSound", false)
			end

			
			if ( not string.find(currentlyPlayingAnimationName, "Reload") ) then
				print("Reloading. (2)")
				reloading = true
				onReloadGun()
				clearReloadFlags()
				ReplicatedStorage.GunEvent.GunReloadStart:FireServer()
				wait(1)
				ReplicatedStorage.GunEvent.GunReloadEnd:FireServer()
				return false
			end
		else
			
			reloadingIndividual = true

			if ( reloading ) then
				SetGunAnimation("ReloadLoop", true, 0.1, spd)
				currentlyPlayingAnimation.Looped = false
				playGunSound("ReloadLoop", false)
			else
				SetGunAnimation("ReloadStart", false, 0.1, spd)
				playGunSound("ReloadStart", false)
			end
		end
		return true
	else
		if ( reloadingIndividual ) then
			currentlyPlayingAnimation:Stop()
			SetGunAnimation("ReloadEnd", true, 0.1, spd)
			playGunSound("ReloadEnd", false)
		end

		clearReloadFlags()
	end

	return false
end

function reload()
	if ( reloading ) then
		return
	end

	local DebounceWait = 0
	if ( gunCurrentStats.ReloadDebounceOnShoot ) then
		DebounceWait = gunCurrentStats.ReloadDebounceOnShoot.Value
	end

	if ( workspace.DistributedGameTime - lastShootTime < -0.05 ) then
		return
	end

	if ( getPlayer().GunDrawDisabled.Value ) then
		return
	end

	if ( not reloading and gunCurrent ~= nil ) then
		if ( script.Configuration.cl_reload_cancel_running.Value ) then
			setRunning(false)
		end
		reloadingIndividual = false

		if ( reloadLogic() ) then
			ReplicatedStorage.GunEvent.GunReloadStart:FireServer()
			reloading = true
		end
	end
end

function doReloadCancel()
	if ( not reloading ) then
		return
	end

	
	
	clearReloadFlags()
	stopGunSound("ReloadSound")
	SetGunAnimation("Idle", true)
end

function onClickDown( button )
	if ( getViewableCharacter() ~= getCharacter() ) then
		return
	end

	if ( script.DisabledGun.Value ) then
		return
	end

	if ( getCustomCamera().ForceFreeMouse.Value ) then
		return
	end

	if ( button == 0 ) then
		holdingLeft = true
	end
	if ( button == 1 ) then
		holdingRight = true
	end
end

function onClickUp( button )
	if ( getViewableCharacter() ~= getCharacter() ) then
		return
	end

	if ( script.DisabledGun.Value ) then
		return
	end

	local InventoryItem = getInventoryItem(gunCurrentSlot)
	if ( not InventoryItem ) then
		return
	end

	if ( button == 0 ) then
		local MinimumShootAimRatio = gunCurrent and gunCurrentStats.MinimumShootAimRatio and gunCurrentStats.MinimumShootAimRatio.Value or 0
		local ShootOnRelease = gunCurrent and gunCurrentStats.ShootOnRelease
		if ( ShootOnRelease and ShootOnRelease.Value and (1.0-aimTween) >= MinimumShootAimRatio ) then
			handleShooting()
		end

		releaseTrigger()
		gunSystemEvents.OnPlayerRequestStopShoot:Fire(gunCurrent)
		gunSystemEvents.OnPlayerStopShootGun:Fire(gunCurrent)

		local AutoReload = script.Configuration.cl_auto_reload.Value
		if ( gunCurrent ~= nil and InventoryItem.BulletsInMagazine.Value == 0 and AutoReload ) then
			if ( gunCurrentStats.ReloadDebounceOnShoot ) then
				task.delay(gunCurrentStats.ReloadDebounceOnShoot.Value, function()
					reload()
				end)
			else
				reload()
			end
		end
	end

	if ( button == 1 ) then
		holdingRight = false
	end
end

function checkSetRunning()
	
	if ( speed <= 0 ) then
		return
	end

	
	if ( gunCurrent ) then
		local scopedWeapon = isScoped()
		if ( (scopedWeapon and not holdingRight) or not scopedWeapon ) then
			holdingRight = false
			setCrouch(false)
		end
	end

	
	setRunning(true)
	gunSystemEvents.OnPlayerRequestSprinting:Fire()

	
	if ( running and script.Configuration.cl_reload_cancel_on_run.Value ) then
		doReloadCancel()
	end
end

function setRunning(run)
	if ( running == run ) then
		return
	end

	running = run
	
end

function setCrouch(Crouched)
	if ( crouched == Crouched ) then
		return
	end

	crouched = Crouched
	gunSystemEvents.OnCrouchChange:Fire(Crouched)
end

function onKeyPress( inputObject, isProcessed )
	if ( getViewableCharacter() ~= getCharacter() ) then
		return
	end

	if ( script.DisabledGun.Value ) then
		return
	end

	if ( not inputObject ) then
		return
	end

	local keyCode = inputObject.KeyCode

	if ( getPlayer().PlayerGui:FindFirstChild("PauseGui") ~= nil ) then
		return
	end

	if ( getCustomCamera().ForceFreeMouse.Value ) then
		return
	end
	if ( keyCode == Enum.KeyCode.Unknown ) then
		return
	end

	local Spectating = Player.Spectator.Spectating.Value and true or false

	
	if ( isEnabled and keyCode == Enum.KeyCode[Keybinds.Keyboard:GetAttribute('Sprint')] and not Spectating ) then
		holdingShift = true
		checkSetRunning()
	end

	
	if ( not isProcessed ) then
		
		if ( keyCode == Enum.KeyCode.P ) then
			enable()
		end

		
		if ( keyCode == Enum.KeyCode.L and UserCanDisable ) then
			disable()
		end

		
		if ( keyCode == Enum.KeyCode[Keybinds.Keyboard:GetAttribute('ThirdPersonView')] and isEnabled ) then
			if ( not ThirdPerson and AllowThirdPerson ) then
				ThirdPerson = true
			elseif (ThirdPerson and AllowFirstPerson) then
				ThirdPerson = false
			end
			updateCharacterVisibility()
		end

		if ( isEnabled and not Spectating and not getHumanoid().Sit ) then

			
			if ( keyCode == Enum.KeyCode[Keybinds.Keyboard:GetAttribute('Crouch')] ) then
				setCrouch(true)
			end

			
			if ( keyCode == Enum.KeyCode[Keybinds.Keyboard:GetAttribute('ToggleCrouch')] ) then
				setCrouch(not crouched)
			end

			
			if ( keyCode == Enum.KeyCode[Keybinds.Keyboard:GetAttribute('Reload')] ) then
				reload()
			end
		end
	end

	
	if ( keyCode == Enum.KeyCode.W ) then
		holdingW = true
	end
end

function onKeyRelease( inputObject, isProcessed )
	if ( getViewableCharacter() ~= getCharacter() ) then
		return
	end

	if ( Player.Spectator.Spectating.Value ) then
		return false
	end

	if ( script.DisabledGun.Value ) then
		return
	end

	if ( inputObject.KeyCode == Enum.KeyCode.Space ) then
		ReleasedSpace = true
	end
	local keyCode = inputObject.KeyCode
	if ( keyCode == Enum.KeyCode.W ) then
		holdingW = false
	end	

	if ( isProcessed ) then
		return
	end
	if ( keyCode == Enum.KeyCode.Unknown ) then
		return
	end

	if ( keyCode == Enum.KeyCode[Keybinds.Keyboard:GetAttribute('Sprint')] ) then
		holdingShift = false
	end

	if ( keyCode == Enum.KeyCode[Keybinds.Keyboard:GetAttribute('Crouch')] ) then
		setCrouch(false)
	end
end





function onDeath()
	if ( script.Died.Value ) then
		return
	end

	script.Died.Value = true
	scoped = false
	aimTween = 1
	mobileFire = false
	holdingRight = false
	holdingLeft = false

	getCustomCamera().CameraOffset.Value = 0
	getCustomCamera().CameraPitch.Value = 0
	destroyWeapons()

	pcall(function()
		if ( crosshairGui ~= nil ) then
			crosshairGui.Scope.Visible = false
		end
	end)

	
	
	task.spawn(function()
		wait(0.1)
		getCharacter().Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
		pcall(function() getCharacter().Humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
		for i=1,30 do
			getCharacter().Humanoid.Jump = not getCharacter().Humanoid.Jump
			wait(1/30)
		end
	end)
end

local jumpFunc = nil
function onRespawn(Character)
	if ( not Character ) then
		warn("--GunController. Player respawned without Character?")
		return
	end

	local Humanoid = Character:WaitForChild("Humanoid")
	if ( not Humanoid ) then
		warn("--GunController. Player respawned without Humanoid?")
		return
	end

	if ( not Character:FindFirstChild("Head") ) then
		Humanoid.CameraOffset = Vector3.new(0, (heiSt or 0) * 0.66, 0)
	end

	Humanoid.UseJumpPower = true

	if ( not isEnabled ) then
		return
	end

	script.Died.Value = false
	TimeSinceLastRespawn = 0
	Humanoid.Died:Connect(onDeath)
	Humanoid.HealthChanged:Connect(function(Health) 
		if ( Health <= 0 ) then
			IsDead = true
			CurrentlyInvisible = false
			setLocalTransparencyRecursive( Character, 0.0 )
			onDeath()
		end
	end)

	Humanoid.Seated:Connect(function()
		CurrentlyInvisible = false
		updateCharacterVisibility()
	end)

	getCustomCamera().CameraOffset.Value = 0
	getCustomCamera().CameraOffset.CanZoom.Value = false
	getCustomCamera().CameraPitch.Maximum.Value = math.pi/2 - 0.1
	getCustomCamera().CameraPitch.Minimum.Value = -math.pi/2 + 0.1
	getCustomCamera().CameraYaw.Offset.Value = 0
	getCustomCamera().CameraPitch.Offset.Value = 0
	

	if (gunViewModel) then
		gunViewModel:Destroy()
	end

	updateCharacterVisibility()
	Character.DescendantAdded:Connect(function(v)
		updateVisibility(CurrentlyInvisible, v)
	end);

	task.defer(function()
		updateCharacterVisibility()
	end)

	gunCurrent = nil
	gunViewModel = nil
	
	gunHasChanged = true
	aimTween = 0
	IsDead = false
	holdingRight = false
	setCrouch(false)

	Humanoid.AutoRotate = false
	ReleasedSpace = true

	
	task.delay(0.5, function()
		if ( jumpFunc ) then
			jumpFunc:Disconnect()
		end

		jumpFunc = Humanoid.Changed:connect(function(event)
			if ( event == "Jump" or event == "JumpReplicate" ) then
				if ( Humanoid.Jump ) then
					local BlockJump = JumpDebounce > 0 and JumpStamina <= 0 or crouched or (not ReleasedSpace and not script.Configuration.cl_auto_jump.Value)
					if ( BlockJump ) then
						JumpDebounce = 8
						Humanoid.Jump = false
						setCrouch(false)
					else
						JumpStamina = JumpStamina - 0.5

						gunSystemEvents.OnJump:Fire(JumpStamina)
					end

					if ( event == "JumpReplicate" ) then
						ReleasedSpace = false
					end
				else
					ReleasedSpace = false
				end
			end
		end)
	end)

	
	if ( JumpController ) then
		JumpController:Disconnect()
		JumpController = nil
	end

	local JumpTimestamp = 0
	JumpController = Humanoid.StateChanged:Connect(function(oldState, newState)
		if ( newState == Enum.HumanoidStateType.Freefall ) then
			JumpTimestamp = tick()
			Jumping = true
		end
		if ( oldState == Enum.HumanoidStateType.Freefall and newState ~= Enum.HumanoidStateType.Freefall ) then
			Jumping = false

			local TimeInJump = tick()-JumpTimestamp
			if ( TimeInJump > 0.2 ) then
				onHitGround()
			end
		end
	end)

	takeoutWeapon( getPlayer().CurrentSelected.Value, true )
	gunSystemEvents.OnRespawn:Fire(Character)
end

function GetCanShoot(gunSlot)
	gunSlot = gunSlot or gunCurrentSlot

	local Item = getInventoryItem(gunSlot)
	if ( Item == nil ) then
		return false, "Invalid Item"
	end

	if ( not script.CanShoot.Value or script.DisabledGun.Value ) then
		return false, "Disabled"
	end

	local ammo = Item.BulletsInMagazine.Value
	if ( gunSlot == gunCurrentSlot ) then
		ammo = Item.BulletsInMagazine.Value
	end
	if ( ammo <= 0 and Item.Value.Stats.NeedsAmmo.Value ) then
		return false, "No ammo"
	end

	if ( Item.Disabled.Value ) then
		return false, "Disabled (2)"
	end

	if ( workspace.DistributedGameTime - lastShootTime < 0  ) then
		return false, "Slow down cowboy!"
	end

	if ( tick() - GunTakeoutCanShootTime < 0 and not isSpecial(gunSlot) ) then
		return false, "Slow down some more cowboy!"
	end

	return true
end

function hitmarkerSound(headshot)
	headshot = headshot or false
	hitmarkerDelay = 15
	if ( headshot ) then
		script.Data.Headshot.SoundGroup = script.Data.Headshot.SoundGroup or SoundGroupManager:GetSoundGroup('Game');
		script.Data.Headshot:Play()
	else
		script.Data.Hitmarker.SoundGroup = script.Data.Hitmarker.SoundGroup or SoundGroupManager:GetSoundGroup('Game');
		script.Data.Hitmarker:Play()
	end
end

function isScoped()
	if ( gunCurrentStats.Scoped.Value ) then
		return true
	end

	local Attachment = getAttachment('AttachmentReticle')
	if ( Attachment and Attachment.Modifiers:FindFirstChild("Scoped") and Attachment.Modifiers.Scoped.Value ) then
		return true
	end

	return false
end

function isSpecial(gunSlot)
	gunSlot = gunSlot or gunCurrentSlot

	local Item = getInventoryItem(gunSlot)
	if ( Item == nil ) then
		return false
	end

	return Item.Value.Stats:FindFirstChild("Special") and Item.Value.Stats.Special.Value
end

function getShootAnimation()
	local isSpecial = isSpecial()
	if ( isSpecial ) then
		return "Special"
	end

	local AttachmentReticle = getAttachment("AttachmentReticle")
	if ( isAiming() ) then
		if ( AttachmentReticle ) then
			local tAnim = findAnimationReference("Shoot" .. AttachmentReticle.AttachmentType.Value)
			if ( tAnim ) then
				return tAnim.Name
			end
		else
			local tAnim = findAnimationReference("ShootADS")
			if ( tAnim ) then
				return tAnim.Name
			end
		end
	end

	return "Shoot"
end

function getViewModelPart(PartName, OptionalViewModel)
	local Weapon = OptionalViewModel or gunViewModel
	if ( Weapon:FindFirstChild("Weapon") ) then
		Weapon = Weapon.Weapon
	end

	local MyPart = Weapon:FindFirstChild(PartName)
	if ( not MyPart ) then
		
	end

	return MyPart
end

function getInternalGunStats(GunReference)
	if ( not GunReference or typeof(GunReference) ~= "Instance" ) then
		return {}
	end

	local Stats = GunReference:FindFirstChild("Stats")
	if ( not Stats ) then
		return {}
	end

	local EncodedStats = Stats:GetAttribute(E(GunReference.Name))
	local JSONStats = D(EncodedStats) or "{}"
	local DecodedStats = HttpService:JSONDecode(JSONStats)
	return DecodedStats
end

script.Events.IsLoaded.OnInvoke = function()
	return script.SystemLoaded.Value
end

script.Events.OverrideShootObject.OnInvoke = function(Object)
	return Object, nil
end

function getInternalPlayerMultipliers()
	local t = {}
	for k,v in cpairs(_G.GunModifiers) do
		t[k] = v
	end

	return t
end

function getInternalGunMultipliers()
	local InventoryItem = getInventoryItem( gunCurrentSlot )
	if ( InventoryItem == nil ) then
		return {}
	end

	local Metadata = InventoryItem:FindFirstChild("Metadata")
	if ( not Metadata ) then
		return {}
	end

	Metadata = HttpService:JSONDecode(Metadata.Value)

	local Multipliers = Metadata.Multipliers
	if ( not Multipliers ) then
		Multipliers = {}
	end

	for k,v in cpairs(BLANK_MODIFIERS) do
		if ( not Multipliers[k] ) then
			Multipliers[k] = v
		end
	end

	return Multipliers
end


function AttachmentAccuracyMultiplier(RefName)
	local AttachmentAccuracyMultiplier = 1
	local Attachment = getAttachment("AttachmentUnderbarrel")
	if ( Attachment ) then
		local AccuracyRef = Attachment.Modifiers:FindFirstChild(RefName)
		if ( AccuracyRef ) then
			AttachmentAccuracyMultiplier = AccuracyRef.Value
		end
	end

	return AttachmentAccuracyMultiplier
end

function AttemptShootGun()
	setRunning(false)

	if ( reloadingIndividual and rechambering ) then
		cancelReloadingIndividual = true
		return false, "Ending Rechamber"
	end

	if ( rechambering ) then
		return false, "Rechambering"
	end

	local InventoryItem = getInventoryItem(gunCurrentSlot)
	if ( not InventoryItem ) then
		return false, "No inventory item"
	end

	if ( not gunCurrent:IsDescendantOf(ReplicatedStorage) ) then
		return false, "Not valid gun def"
	end

	local CurrentPlayerMultipliers = getInternalPlayerMultipliers()
	local CurrentStats = getInternalGunStats(gunCurrent)
	local FiremodeData = getFiremodeData()

	
	local baserpm = CurrentStats.RPM.Value
	local GunShootSpeedMultiplier = CurrentPlayerMultipliers["GunShootSpeedMultiplier"] 
	GunShootSpeedMultiplier = GunShootSpeedMultiplier * tonumber(getInternalGunMultipliers()["GunShootSpeedMultiplier"] or nil) or 1
	local rpm = baserpm*GunShootSpeedMultiplier
	lastShootTime = workspace.DistributedGameTime + (1.0 / (rpm/60))

	if ( not FiremodeData.Auto ) then
		releaseTrigger()
		gunSystemEvents.OnPlayerStopShootGun:Fire(gunCurrent)
	end

	if ( isGunDrawDisabled() ) then
		ReplicatedStorage.GunEvent['GunRequestCancelGunDrawDisabled']:FireServer()
		return false, "Gun draw is disabled"
	end

	if ( not rechambering and RequiresManualRechamber ) then
		if ( reloading ) then
			cancelReloadingIndividual = true
		else
			rechamberGun()
		end

		return false, "Needs to rechamber"
	end

	
	if ( InventoryItem.Rechambering.Value ) then
		RequiresManualRechamber = true
		return false, "Rechambering (2)"
	end

	
	local te = 0
	local children = gunCurrent.Stats:GetDescendants()
	for i = 1, #children do
		local v = children[i]
		te = te + (totemap[v.ClassName] and totemap[v.ClassName](v) or 0)
	end

	
	SetGunAnimation( getShootAnimation(), true, 0.0, GunShootSpeedMultiplier, false )
	if ( CurrentStats.NeedsAmmo ) then
		if ( CurrentStats.NeedsAmmo.RequiresManualRechamber and CurrentStats.NeedsAmmo.RequiresManualRechamber.Value ) then
			RequiresManualRechamber = true
		end
	end

	
	local shootDelay = CurrentStats.ShootDelay and CurrentStats.ShootDelay.Value or 0
	if ( shootDelay > 0 ) then
		local curGun = gunCurrent
		wait(shootDelay)
		if ( gunCurrent ~= curGun ) then
			return false, "Gun Changed while shooting"
		end
	end

	
	local NeedsAmmo = CurrentStats.NeedsAmmo and CurrentStats.NeedsAmmo.Value
	if ( NeedsAmmo ) then
		InventoryItem.BulletsInMagazine.Value = InventoryItem.BulletsInMagazine.Value - 1
	end

	
	local Attachments = getAttachments()
	local AttachmentShootSound = nil
	local AttachmentShouldMuzzleFlash = true
	
	for i = 1, #Attachments do
		local AttachmentDataTemp = Attachments[i]
		local snd = AttachmentDataTemp.Modifiers:FindFirstChild("ShootSound")
		if ( snd ) then
			AttachmentShootSound = snd
		end

		local muzzle = AttachmentDataTemp.Modifiers:FindFirstChild("MuzzleFlash")
		if ( muzzle and not muzzle.Value ) then
			AttachmentShouldMuzzleFlash = false
		end
	end
	if ( not AttachmentShootSound ) then
		playGunSound("FireSound", false)
	else
		local snd = AttachmentShootSound:Clone()
		snd.Parent = getCharacter().PrimaryPart
		snd.SoundGroup = snd.SoundGroup or SoundGroupManager:GetSoundGroup('Game');
		snd:Play()
		Debris:AddItem(snd, snd.TimeLength)

		playGunSound("FireSound", false, nil, 0.1)
	end


	
	local Randy = Random.new(tick())
	local BaseRecoil = CurrentStats.Recoil.Value
	local THIRDPERSONMODIFIER = ThirdPerson and 1.2 or 1.0
	local VISUAL_RECOIL_MULTIPLIER = tonumber(CurrentStats.Recoil.VisualRecoilMultiplier) or 1
	SHOOTING_OFFSET = math.min(BaseRecoil, 1.5) * 8 * VISUAL_RECOIL_MULTIPLIER
	RECOIL_VERTICAL = BaseRecoil * tween( 0.9, 1.1, Randy:NextNumber() ) * THIRDPERSONMODIFIER 
	RECOIL_HORIZONTAL = RECOIL_HORIZONTAL + ((Randy:NextNumber() - Randy:NextNumber()) * ((BaseRecoil)*0.33))

	local RecoilMultiplier = 1
	RecoilMultiplier = RecoilMultiplier * CurrentPlayerMultipliers["GunRecoilMultiplier"]
	RecoilMultiplier = RecoilMultiplier * tonumber(getInternalGunMultipliers()["GunRecoilMultiplier"] or nil) or 1
	RecoilMultiplier = RecoilMultiplier * AttachmentAccuracyMultiplier("RecoilMultiplier")

	if ( mobileFire ) then
		RecoilMultiplier = RecoilMultiplier * 0.5
	end

	RECOIL_VERTICAL = RECOIL_VERTICAL * RecoilMultiplier
	RECOIL_HORIZONTAL = RECOIL_HORIZONTAL * RecoilMultiplier

	local xx = 1.0 + (math.min(ShotsInSuccession, 20) * 0.25)
	local Impulse = Vector3.new(RECOIL_HORIZONTAL, RECOIL_VERTICAL, 0) * (RECOIL_POWER * xx)
	recoilSpring:SetPosition(recoilSpring.Position + Impulse)
	recoilSpring:Impulse(Impulse)
	ShotsInSuccession = ShotsInSuccession + 1

	
	if ( gunViewModel and AttachmentShouldMuzzleFlash and _G.muzzleFlash ) then
		_G.muzzleFlash( getPlayer(), ThirdPerson and gunWorldModel and gunWorldModel:FindFirstChild("Main") or getViewModelPart("Main"), gunCurrent, true )
	end

	
	local pellets = CurrentStats.Pellets.Value
	local accuracy = CurrentStats.Accuracy.Value
	if ( crouched ) then
		accuracy = accuracy * CurrentStats.Accuracy.CrouchModifier.Value
	end
	if ( speed > 0.01 ) then
		accuracy = accuracy * CurrentStats.Accuracy.RunModifier.Value
	end
	if ( IsInAir() ) then
		local jumpAcc = gunCurrentStats.Accuracy.JumpModifier
		if ( jumpAcc ~= nil ) then
			accuracy = accuracy * jumpAcc.Value
		else
			accuracy = accuracy * 0.25
		end
	end

	
	local iAimTween = 1.0-aimTween
	local tweenSquare = 1.0 - math.pow( iAimTween, 14 )
	accuracy = accuracy * tween( CurrentStats.Accuracy.AimModifier.Value, 1, tweenSquare )


	
	if ( aimTween > 0.7 ) then
		accuracy = accuracy * CurrentPlayerMultipliers["GunAccuracyHipfireMultiplier"]
		accuracy = accuracy * tonumber(getInternalGunMultipliers()["GunAccuracyHipfireMultiplier"] or nil) or 1
		accuracy = accuracy * AttachmentAccuracyMultiplier("AccuracyHipfireMultiplier")
	else
		accuracy = accuracy * CurrentPlayerMultipliers["GunAccuracyAimedMultiplier"]
		accuracy = accuracy * tonumber(getInternalGunMultipliers()["GunAccuracyAimedMultiplier"] or nil) or 1
		accuracy = accuracy * AttachmentAccuracyMultiplier("AccuracyAimedMultiplier")
	end

	local rangeMultiplier = 1
	rangeMultiplier = rangeMultiplier * CurrentPlayerMultipliers["GunRangeMultiplier"]
	rangeMultiplier = rangeMultiplier * tonumber(getInternalGunMultipliers()["GunRangeMultiplier"] or nil) or 1

	local cpit = getCustomCamera().CameraPitch.Value + getCustomCamera().CameraPitch.Offset.Value
	local cyaw = getCustomCamera().CameraYaw.Value + getCustomCamera().CameraYaw.Offset.Value

	local isSpecial = isSpecial()
	local CamDir = getLookDirection()

	
	if (gunCurrentStats.Melee and gunCurrentStats.Melee.Value) then
		task.spawn(function()
			
			local WaitTime = CurrentStats.Melee and CurrentStats.Melee.SwingTime and CurrentStats.Melee.SwingTime.Value or 0.1
			local t1 = tick()
			local dt = task.wait(WaitTime)
			local t2 = tick()

			local HitParts, ClosestHit, ClosestHitWorld, ClosestHitNormal, ClosestHitMaterial, Humanoid = MeleeModule:TestMelee(Player, gunCurrent, rangeMultiplier)

			if ( ClosestHit ) then
				
				local OriginalHit = ClosestHit
				ClosestHit = script.Events.OverrideShootObject:Invoke(ClosestHit)
				if ( not Humanoid or not Humanoid:IsA("Humanoid") or OriginalHit ~= ClosestHit ) then
					Humanoid = ClosestHit.Parent:FindFirstChildOfClass("Humanoid")
				end

				
				local MeleePacket = {}
				BinaryUtil:WriteString(MeleePacket, OriginalHit.Name)
				BinaryUtil:WriteVector3(MeleePacket, ClosestHitWorld)
				BinaryUtil:WriteVector3(MeleePacket, ClosestHitNormal)
				BinaryUtil:WriteString(MeleePacket, ClosestHitMaterial.Name)
				BinaryUtil:WriteString(MeleePacket, ClosestHit:GetAttribute("CustomUUID") or "nil")
				BinaryUtil:WriteDouble(MeleePacket, t2-t1)
				BinaryUtil:WriteDouble(MeleePacket, dt)
				ReplicatedStorage.GunEvent["GunMelee"]:FireServer(HitParts, ClosestHit, MeleePacket, Humanoid)
			else
				ReplicatedStorage.GunEvent["GunMelee"]:FireServer(nil, nil, nil, nil)
			end
		end)
	else
		
		local tB = BulletID
		BulletID = BulletID + 1	

		local GunFirePacket = {}
		BinaryUtil:WriteInt(GunFirePacket, tB)
		BinaryUtil:WriteString(GunFirePacket, tK)
		BinaryUtil:WriteDouble(GunFirePacket, tick())
		BinaryUtil:WriteVector3(GunFirePacket, PLAYER_EYE)
		BinaryUtil:WriteVector3(GunFirePacket, CamDir)
		BinaryUtil:WriteDouble(GunFirePacket, cpit)
		BinaryUtil:WriteDouble(GunFirePacket, cyaw)
		BinaryUtil:WriteVector3(GunFirePacket, (getCamera().CFrame.Rotation*CFrame.new(0,0,-1)).Position)
		BinaryUtil:WriteDouble(GunFirePacket, accuracy)
		BinaryUtil:WriteInt(GunFirePacket, gunCurrentSlot)
		BinaryUtil:WriteInt(GunFirePacket, baserpm * 1024)
		BinaryUtil:WriteInt(GunFirePacket, rpm * 1024)
		BinaryUtil:WriteByte(GunFirePacket, aimTween * 255) 
		BinaryUtil:WriteBool(GunFirePacket, not ThirdPerson)
		BinaryUtil:WriteInt(GunFirePacket, te)
		BinaryUtil:WriteBit(GunFirePacket, crouched)
		BinaryUtil:WriteBit(GunFirePacket, speed > 0.01)
		BinaryUtil:WriteBit(GunFirePacket, IsInAir())
		
		local x = 0
		for _,_ in cpairs(CurrentPlayerMultipliers) do x = x + 1 end
		BinaryUtil:WriteByte(GunFirePacket, x)
		for k,v in cpairs(CurrentPlayerMultipliers) do
			BinaryUtil:WriteByte(GunFirePacket, GunModifiers[k].Index)
			BinaryUtil:WriteInt(GunFirePacket, v * 1024)
		end
		
		BinaryUtil:Fill(GunFirePacket)
		ReplicatedStorage.GunEvent.GunFire:FireServer(GunFirePacket)

		local isServerSided = (gunCurrentStats.BulletSettings.ServerSided and gunCurrentStats.BulletSettings.ServerSided.Value)
		if ( not isServerSided and not isSpecial ) then

			for i=1,pellets do
				local maxDistance = CurrentStats.BulletSettings.MaxDistance.Value

				local newRandom = Random.new(tB + i)
				local accmat = {
					newRandom:NextNumber(),
					newRandom:NextNumber(),
					newRandom:NextNumber(),
					newRandom:NextNumber(),
					newRandom:NextNumber(),
					newRandom:NextNumber(),
				}
				local accuracyX = (accmat[1] - accmat[2]) / accuracy
				local accuracyY = (accmat[3] - accmat[4]) / accuracy
				local accuracyZ = (accmat[5] - accmat[6]) / accuracy
				local accuracyVec = Vector3.new(accuracyX, accuracyY, accuracyZ)
				local direction = CamDir + accuracyVec
				local origin = PLAYER_EYE + (velocity * 2)
				local destination = direction * maxDistance

				
				local tracer = Instance.new("BindableEvent")
				tracer.Event:Connect(function()
					local TracerOrigin = origin
					local tip = (ThirdPerson and gunWorldModel:FindFirstChild("Main")) or getViewModelPart("Main")
					if ( tip and not scoped ) then
						TracerOrigin = tip.Position
					end

					local tracerOffset = TracerOrigin - origin
					BulletModule:BulletSimulation(getPlayer(), origin, direction, gunCurrent, true, gunCurrent:FindFirstChild("BulletTrail"), nil, nil, tracerOffset)
				end)
				tracer:Fire()
				tracer:Destroy()

				
				task.spawn(function()
					local CharacterHit, HitType, HitPart, HitWorld, HitNormal, HitMaterial, dts, test_points = BulletModule:BulletSimulation(getPlayer(), origin, direction, gunCurrent, false, nil, nil, nil)
					local NewHitPart, _HitTypeOverride = script.Events.OverrideShootObject:Invoke(HitPart)
					local OriginalHitPartName = (_HitTypeOverride and tostring(_HitTypeOverride)) or (NewHitPart and NewHitPart.Name) or nil
					local WorldPos = NewHitPart and NewHitPart.Position or Vector3.new()

					if ( NewHitPart ) then
						local HitPacket = {}
						BinaryUtil:WriteInt(HitPacket, tB)
						BinaryUtil:WriteByte(HitPacket, i)
						BinaryUtil:WriteVector3(HitPacket, origin)
						BinaryUtil:WriteVector3(HitPacket, direction)
						BinaryUtil:WriteVector3(HitPacket, accuracyVec)
						BinaryUtil:WriteVector3(HitPacket, origin + destination)
						BinaryUtil:WriteVector3(HitPacket, HitWorld)
						BinaryUtil:WriteVector3(HitPacket, HitNormal)
						BinaryUtil:WriteVector3(HitPacket, WorldPos)
						BinaryUtil:WriteVector3(HitPacket, HitWorld - HitPart.Position)
						BinaryUtil:WriteShort(HitPacket, HitPart.Size.Magnitude)
						BinaryUtil:WriteVector3(HitPacket, NewHitPart.Size)
						BinaryUtil:WriteString(HitPacket, HitMaterial.Name)
						BinaryUtil:WriteString(HitPacket, OriginalHitPartName)
						BinaryUtil:WriteString(HitPacket, NewHitPart:GetAttribute("CustomUUID") or "nil")

						
						

						
						
						

						
						
						
						
						
						
						ReplicatedStorage.GunEvent.BulletHole:FireServer( HitPacket, NewHitPart, dts, test_points, direction )
					end
				end)
			end
		end
	end
	gunSystemEvents.OnPlayerShootGun:Fire(BaseRecoil, VISUAL_RECOIL_MULTIPLIER)
end

function getViewableCharacter()
	local ViewableCharacter = getCharacter()
	if ( isSpectating ) then
		local t = script.Spectating.Value.Character
		if ( t ~= nil ) then
			ViewableCharacter = t
		end
	end

	return ViewableCharacter
end

function getViewablePlayer()
	if ( isSpectating ) then
		return script.Spectating.Value
	end

	return getPlayer()
end





local enabled = false
function onEnableChange()
	if ( script.IsEnabled.Value ) then
		isEnabled = true
		enabled = true
		script.DisabledGun.Value = false	
		ReleasedSpace = true

		if ( not tK ) then
			local Packet = ReplicatedStorage["GunEvent"]["GunEnable"]:InvokeServer()

			local a = BinaryUtil:ReadInt(Packet)
			for i=1,a do BinaryUtil:ReadDouble(Packet) end
			local b = BinaryUtil:ReadDouble(Packet)
			local c = BinaryUtil:ReadDouble(Packet)
			local d = BinaryUtil:ReadBool(Packet)
			local e = BinaryUtil:ReadString(Packet)
			local f = BinaryUtil:ReadDouble(Packet)
			local g = BinaryUtil:ReadDouble(Packet)
			local h = BinaryUtil:ReadBool(Packet)
			local i = BinaryUtil:ReadBool(Packet)
			local j = BinaryUtil:ReadDouble(Packet)
			local k = BinaryUtil:ReadBool(Packet)

			heiSt = b
			heiCr = c
			tK = e

			jmpNrm = f
			jmpFat = g

			AllowFirstPerson = h
			AllowThirdPerson = i
			WeaponSwitchTransitionTime = j
			UserCanDisable = k
		end

		
		if ( not AllowFirstPerson ) then
			ThirdPerson = true
		end

		
		
		
		
		

		CurrentlyInvisible = false
		updateCharacterVisibility()
		onRespawn(getCharacter())
	else
		isEnabled = false
		if ( enabled ) then
			if ( gunViewModel ~= nil ) then
				gunViewModel:Destroy()
			end

			if ( gunWorldModel ~= nil ) then
				gunWorldModel:Destroy()
			end

			if ( crosshairGui ) then
				crosshairGui:Destroy()
				crosshairGui = nil
			end

			script.CurrentWeapon.Value = nil

			getCustomCamera().IsEnabled.Value = false

			ShouldInvisible = false
			updateCharacterVisibility()
		end

		







		while ( getHumanoid() == nil ) do
			wait(0.1)
		end
		getHumanoid().AutoRotate = true
		enabled = false
	end
end

local FiremodeType = {
	Auto = "Auto",
	Burst = "Burst",
	Semi = "Semi",
}
function getFiremodeData()
	local InventoryItem = getInventoryItem(gunCurrentSlot)
	assert(InventoryItem ~= nil, "Inventory Item must be not nil")

	
	local Firemode = FiremodeType[InventoryItem.Firemode.Value]
	if ( gunCurrentStats.Auto and gunCurrentStats.Auto.Value ) then
		Firemode = FiremodeType.Auto
	end
	if ( gunCurrentStats.Burst and gunCurrentStats.Burst.Value > 1 ) then
		Firemode = FiremodeType.Burst
	end

	
	local fMode = gunCurrentStats.Firemodes and gunCurrentStats.Firemodes[Firemode]

	
	local Timeout = gunCurrentStats.Burst and tonumber(gunCurrentStats.Burst.Timeout or nil) or 0
	local BulletsPerBurst = gunCurrentStats.Burst and tonumber(gunCurrentStats.Burst.Value) or 1
	if ( fMode and Firemode == FiremodeType.Burst ) then
		BulletsPerBurst = tonumber(fMode["Bullets"] or nil) or BulletsPerBurst
		Timeout = tonumber(fMode["Timeout"] or nil) or Timeout
	end

	
	local FiremodeData = {}
	FiremodeData.Firemode = Firemode
	FiremodeData.Semi = Firemode == FiremodeType.Semi
	FiremodeData.Auto = Firemode == FiremodeType.Auto
	FiremodeData.Burst = Firemode == FiremodeType.Burst
	FiremodeData.Bullets = BulletsPerBurst
	FiremodeData.Timeout = Timeout
	FiremodeData.Reference = fMode
	return FiremodeData
end

function isAiming()
	return script.Aimed.Value
end

function handleShooting()

	
	if ( GetCanShoot() ) then

		
		local IsSpecial = isSpecial()
		if ( not IsSpecial ) then

			local FiremodeData = getFiremodeData()

			
			local RPM = gunCurrentStats.RPM.Value
			local waitTime = (1.0 / (RPM/60))
			if ( RepeatShoot == 0 and holdingLeft ) then
				RepeatShoot = FiremodeData.Bullets
			end

			
			if ( not reloading or (reloading and reloadingIndividual) ) then
				
				AttemptShootGun()
				RepeatShoot = RepeatShoot - 1

				
				if ( RepeatShoot == 0 and not FiremodeData.Auto ) then
					releaseTrigger()
					lastShootTime = math.max(lastShootTime, workspace.DistributedGameTime) + FiremodeData.Timeout
				end
			end
		end

		gunSystemEvents.OnPlayerRequestShoot:Fire(gunCurrent)
	else
		local InventoryItem = getInventoryItem(gunCurrentSlot)
		if ( not InventoryItem ) then
			return
		end

		local isEmpty = InventoryItem.BulletsInMagazine.Value == 0 and gunCurrentStats.NeedsAmmo.Value
		if ( holdingLeft and isEmpty and gunWorldModel ~= nil ) then
			mobileFire = false
			playGunSound("DrySound")
			releaseTrigger()
			gunSystemEvents.OnPlayerStopShootGun:Fire(gunCurrent)
			RepeatShoot = 0
		end
	end
end

function releaseTrigger()
	holdingLeft = false

	
	local lastBulletId = BulletID
	task.spawn(function()
		wait(0.5)

		
		
		if ( BulletID ~= lastBulletId ) then
			local BulletsShotSince = BulletID - lastBulletId
			local Subtract = math.max(1-(BulletsShotSince/4), 0)
			ShotsInSuccession = math.max(ShotsInSuccession-Subtract, 0)
		else
			ShotsInSuccession = 0 
		end
	end)
end

local lastTeam = getPlayer().Team
local lastTick = 0
local LastY = 0
function onStep( delta )
	local compatabilityTickrate = delta * 60

	ticks = ticks + compatabilityTickrate
	hitmarkerDelay = hitmarkerDelay - compatabilityTickrate
	JumpDebounce = JumpDebounce - compatabilityTickrate

	if ( not Temp1 ) then
		return
	end

	if ( getHumanoid() == nil or IsDead ) then
		return
	end

	
	local position = getRoot() and getRoot().CFrame.Position or nil
	if ( position ) then
		velocity = position - lastCenter
		lastCenter = position

		lastSpeed = speed
		speed = (velocity * Vector3.new(1, 0, 1)).Magnitude
	else
		velocity = Vector3.zero
		speed = 0
	end

	
	gunWorldModel = getCharacter():FindFirstChild("WorldModel")

	
	JumpStamina = math.min( 1, math.max( -1, JumpStamina + delta*1.2 ) )
	JumpPower = tween( jmpFat, jmpNrm, JumpStamina*MAX_JUMP_STAMINA )
	if ( not getHumanoid().Sit ) then
		getHumanoid().JumpPower = JumpPower
	end

	if ( not isEnabled ) then
		return
	end

	
	local CurrentItem = getInventoryItem( gunCurrentSlot )
	if ( CurrentItem and CurrentItem.Value ~= gunCurrent ) then
		takeoutWeapon( gunCurrentSlot, true )
	elseif ( not CurrentItem ) then
		takeoutWeapon( 1, true )
	end

	if ( tick() - lastTick > 1 ) then
		lastTick = tick()
		TimeSinceLastRespawn = TimeSinceLastRespawn + compatabilityTickrate
	end

	if ( holsterWeapon or isGunDrawBlocked() ) then
		return
	end

	if ( getCharacter():FindFirstChild("HumanoidRootPart") == nil ) then
		return
	end

	
	updateCoreAnimations()

	if ( not crosshairGui or not crosshairGui.Parent ) then
		crosshairGui = script.Data.Crosshair:Clone()
		crosshairGui.Parent = getPlayer().PlayerGui
		defaultScopeImage = crosshairGui.Scope.Image
	else
		crosshairGui.Hitmarker.Visible = hitmarkerDelay > 0
		crosshairGui.Enabled = isEnabled
		crosshairGui.ReticleOffset.Visible = script.ShowCrosshair.Value;

		


	end

	
	if ( gunHasChanged or tick()-TimeSinceLastGunUpdate > 0.1 ) then
		TimeSinceLastGunUpdate = tick()
		gunHasChanged = false
		ReplicatedStorage.GunEvent.ClientUpdate:FireServer(gunCurrentSlot, isAiming(), crouched, running, getHumanoid().JumpPower, getCamera().CFrame, Temp1 ~= nil, t["Temp1"] == t["Temp2"])
		if ( getHumanoid().JumpPower > 30 ) then
			getHumanoid().JumpPower = 30
		end
	end

	
	if ( getPlayer().Team ~= lastTeam ) then
		lastTeam = getPlayer().Team
		if ( Teams:FindFirstChild('Spectator') and isEnabled ) then
			script.IsEnabled.Value = false
			script.IsEnabled.Value = true
			return
		end

		if ( gunCurrent and gunCurrent:FindFirstChild("ViewModel") ) then
			takeoutWeapon( gunCurrentSlot )
		else
			takeoutWeapon( 1 )
		end
	end

	if ( gunCurrent == nil or #gunCurrent:GetChildren() == 0 ) then
		return
	end

	
	local canAim = canAim()
	local isAimed = canAim and aimTween <= 0 or aimTween <= 1
	if ( mobileFire ) then
		if ( canAim ) then
			local isAuto = getFiremodeData().Firemode == FiremodeType.Auto
			if ( aimTween <= 0 or isAuto ) then
				holdingLeft = true
			end
		else
			
			holdingLeft = true
		end
	end

	
	if ( holdingLeft or RepeatShoot > 0 ) then
		local MinimumShootAimRatio = gunCurrentStats.MinimumShootAimRatio and gunCurrentStats.MinimumShootAimRatio.Value or 0
		local ShootOnRelease = gunCurrentStats.ShootOnRelease
		if ( (not ShootOnRelease or not ShootOnRelease.Value) and (1.0-aimTween) >= MinimumShootAimRatio ) then
			handleShooting()
		end
	end

	
	if ( (crouched or not holdingW or scoped) and not IsInAir() ) then
		setRunning(false)
	end

	
	speedModifier = 1.0
	local oldRunning = running
	local runReload = not script.Configuration.cl_reload_can_run.Value and reloading 
	if ( running and not runReload and not isAiming() and takeoutRot < 1 ) then
		speedModifier = speedModifier * script.Configuration.BaseWalkSpeed.SprintModifier.Value
	end

	
	if ( getPlayer():FindFirstChild("Crouched") ~= nil ) then
		getPlayer().Crouched.Value = crouched
		if ( crouched ) then
			speedModifier = speedModifier * script.Configuration.BaseWalkSpeed.CrouchModifier.Value
		end
	end

	
	local gunSpeedMultiplier = 1
	if ( gunCurrent ~= nil and gunCurrentStats.SpeedMultiplier ~= nil ) then
		gunSpeedMultiplier = gunCurrentStats.SpeedMultiplier.Value
	end

	
	local Humanoid = getHumanoid()
	if ( Humanoid ~= nil ) then
		local CanMove = Humanoid:FindFirstChild("CanMove")
		if ( (CanMove and CanMove.Value) or not CanMove ) then
			local jumpSlowdown = tween( 0.5, 1.0, JumpStamina + 1.0 )
			local WALK_SPEED = script.Configuration.BaseWalkSpeed.Value
			local SCOPE_SPEED = script.Configuration.BaseWalkSpeed.AimModifier.Value
			local CROUCH_MOD = script.Configuration.BaseWalkSpeed.CrouchModifier.Value;
			local BASE_SPEED = WALK_SPEED * tween(1, SCOPE_SPEED, (1.0-aimTween)*(Jumping and 0 or 1))
			Humanoid.WalkSpeed = BASE_SPEED * speedModifier * jumpSlowdown * gunSpeedMultiplier
		end
	end

	
	if ( not gunWorldModel or not gunWorldModel.Parent ) then
		gunWorldModel = getCharacter():FindFirstChild("WorldModel")
	end

	
	if ( takeoutRot < 20 and playInitialSound ) then
		playInitialSound = false

		local Sound = playGunSound("Initial")
		if ( Sound ) then
			Sound.Parent = getCharacter().PrimaryPart
		end
	end

	gunSystemEvents.OnStep:Fire(delta)
end

function GetCurrentSpeed()
	return speed
end

function setLocalTransparencyRecursive( root, alpha )
	if ( root == nil ) then
		return
	end

	if ( root:IsA("BasePart") ) then
		setTransparency(root, alpha)
	end

	local children = root:GetDescendants()
	
	for i = 1, #children do
		local v = children[i]
		setTransparency(v, alpha)
	end
end

function setTransparency(Object, Transparency)
	if ( Object:IsA("BasePart") ) then
		Object.LocalTransparencyModifier = Transparency
	end

	local Visible = Transparency < 0.5
	if ( Object:IsA("Light") or Object:IsA("Beam") or Object:IsA("BillboardGui") ) then
		if ( Object:GetAttribute("GunControllerIgnore") ~= true ) then
			Object.Enabled = Visible
		end
	end
end

local smoothedSpectateYaw = 0
local smoothedSpectatePitch = 0
local tWeaponChange = nil
local tThingAdd = nil
function onSpectateChange( SpectatingPlayer )
	if ( tWeaponChange ~= nil ) then
		tWeaponChange:Disconnect()
	end
	if ( tThingAdd ~= nil ) then
		tThingAdd:Disconnect()
	end

	if ( SpectatingPlayer == getPlayer() ) then
		return
	end

	tWeaponChange = SpectatingPlayer.CurrentSelected.Changed:Connect(function(value)
		takeoutWeapon(value, true)
	end)

	tThingAdd = SpectatingPlayer.Character.ChildAdded:Connect(function(Child)
		setLocalTransparencyRecursive( Child, 0.0 )
	end)
end


function onUpdate1(delta)
	Temp1 = camera.CFrame
end

function onUpdate2(delta)
	Temp2 = camera.CFrame

	t["Temp1"] = Temp1
	t["Temp2"] = Temp2
end

function updateCharacterVisibility(force)
	if (isSpectating) then
		local spectate = getViewableCharacter()
		if ( not spectate ) then
			return
		end

		local spectateHead = spectate:FindFirstChild("Head") or spectate:FindFirstChild("HumanoidRootPart")
		if ( not spectateHead ) then
			return
		end

		ShouldInvisible = getCustomCamera().CameraOffset.Value < 1 and (getCustomCamera().CurrentPosition.Value-spectateHead.Position).magnitude < 10 and isEnabled
		if ( ShouldInvisible == CurrentlyInvisible and not force ) then
			return
		end

		updateVisibility(ShouldInvisible, spectate)
	else
		if (not CharacterHead) then
			return
		end

		ShouldInvisible = getCustomCamera().CameraOffset.Value < 1 and (getCustomCamera().CurrentPosition.Value-CharacterHead.Position).magnitude < 10 and isEnabled
		if ( ShouldInvisible == CurrentlyInvisible and not force ) then
			return
		end

		updateVisibility(ShouldInvisible, getCharacter())
	end
	CurrentlyInvisible = ShouldInvisible
end

function updateVisibility(Invisible, Root)
	setLocalTransparencyRecursive( Root, Invisible and 1.0 or 0.0 )
end

function updateCoreAnimations(force, optionalFade)
	if ( DISABLEGUNDRAWTAKEOUT ) then
		return
	end

	if ( not gunCurrent ) then
		return
	end

	local IsMoving = GetCurrentSpeed() > 0

	local VisiblyRunning = running
	if ( isSpectating ) then
		VisiblyRunning = script.Spectating.Value.Running.Value
	end

	local shouldRunAnimation = nil
	if ( VisiblyRunning and IsMoving ) then
		shouldRunAnimation = true
	end

	if ( reloading or rechambering or isAiming() or IsInAir() or takeoutRot >= 1 ) then
		shouldRunAnimation = false
	end

	if ( isAnimationPlaying("Draw") ) then
		shouldRunAnimation = false
	end

	local shouldWalkAnimation = IsMoving and not IsInAir() and gunCurrent.Animations:FindFirstChild("Walk")	
	
	
	
	

	if ( takeoutRot > 1 or holsterWeapon ) then
		shouldRunAnimation = nil
		shouldWalkAnimation = nil
	end

	
	
	

	local shouldPlayAnimation = shouldRunAnimation and "Run" or (shouldWalkAnimation and "Walk" or "Idle")

	
	local base_track = storedTracks[findAnimationReference(shouldPlayAnimation)]
	if ( not base_track ) then
		SetGunAnimation( shouldPlayAnimation )
	end

	
	for _,v in cpairs(storedTracks) do
		if ( isBaseAnimation(v.Name) and not string.match(v.Name, "Idle") ) then
			if ( string.match(v.Name, shouldPlayAnimation) ) then
				if ( not v.IsPlaying ) then
					v:Play(0.33)
				end
			else
				if ( v.IsPlaying ) then
					v:Stop(0.25)
				end
			end
		end
	end

	
	check_rechamber()
end

local ATTACHMENT_ZERO = Instance.new("Attachment")
local ThirdPersonCameraOffset = nil
local ThirdPersonCameraOffset = nil
local ReCompute = tick()
function getThirdPersonCameraOffset()
	if ( not ThirdPersonCameraOffset or not ThirdPersonCameraOffset.Parent ) then
		ThirdPersonCameraOffset = nil
		if ( tick() - ReCompute > 1 ) then
			ReCompute = tick()
			ThirdPersonCameraOffset = getCharacter():FindFirstChild("ThirdPersonCameraOffset", true)
		end
	end

	
	if ( not ThirdPersonCameraOffset ) then
		local offsetDistance = tween( 1.25, 1.75, aimTween )
		if ( isScoped() ) then
			offsetDistance = offsetDistance * tween( 0, 1, aimTween )
		end

		local direction = getCustomCamera().CameraYaw.Value
		local OffsetVector = Vector3.new( offsetDistance, offsetDistance * 0.33, 0 )
		local TempCFrame = CFrame.fromEulerAnglesYXZ(getCustomCamera().CameraPitch.Value+math.pi, direction, 0)
		return TempCFrame * OffsetVector
	else
		local direction = getCustomCamera().CameraYaw.Value
		local ThirdPersonAimOffset = ThirdPersonCameraOffset.Parent.ThirdPersonAimOffset
		if ( isScoped() ) then
			ThirdPersonAimOffset = ATTACHMENT_ZERO
		end

		local OffsetVector = tween(ThirdPersonAimOffset.Position, ThirdPersonCameraOffset.Position, aimTween)
		local TempCFrame = CFrame.fromEulerAnglesYXZ(getCustomCamera().CameraPitch.Value, direction, 0)
		return TempCFrame * OffsetVector
	end
end

function updateCamera(delta)
	if ( not getRoot() ) then
		print('no root for camera')
		return
	end

	debug.profilebegin("Update Camera")
	if ( gunCurrent and gunCurrentStats and not IsDead ) then
		
		local customCamera = getCustomCamera()
		local character = getCharacter()
		local humanoid = getHumanoid()
		local root = getRoot()

		local CharHeightOffset = humanoid.HipHeight
		if ( getRoot().CanCollide ) then
			CharHeightOffset = CharHeightOffset + getRoot().Size.Y/2
		end

		local isSitting = humanoid.Sit

		
		local desiredHeight = (crouched and heiCr or heiSt) - CharHeightOffset
		if ( isSitting ) then
			desiredHeight = heiCr - CharHeightOffset - 0.66
		end
		if ( OVERRIDE_CAMERA_HEIGHT ) then
			desiredHeight = OVERRIDE_CAMERA_HEIGHT
		end
		if ( cameraHeight == -1 ) then cameraHeight = desiredHeight end
		cameraHeight = tween( cameraHeight, desiredHeight, 0.15 )

		
		local CameraOffset = 0
		local ThirdPersonDistance = isSitting and 24 or 7
		if isScoped() then
			ThirdPersonDistance = tween(0, ThirdPersonDistance, aimTween)
		end

		if ( ThirdPerson ) then
			CameraOffset = ThirdPersonDistance
		end

		customCamera.CameraOffset.Value = CameraOffset
		

		local ViewableCharacter = getViewableCharacter()

		local isGunDisabled = script.DisabledGun.Value

		
		if ( not isGunDisabled ) then
			local Root = ViewableCharacter:FindFirstChild("HumanoidRootPart")
			if ( Root ) then
				local rootPosition = Root.Position
				PLAYER_EYE = rootPosition
					+ Vector3.new(0,cameraHeight-(GUN_DIP*2)-stepHeightOffset,0)
					+ PositionGun:CameraOffset()
			end

			if ( ThirdPerson ) then				
				local ThirdPersonOffset = getThirdPersonCameraOffset()
				local _,WorldHit = BulletModule:rayTest( Player, PLAYER_EYE, PLAYER_EYE + ThirdPersonOffset, true, nil, {camera, character})
				if ( getHumanoid().Sit ) then
					WorldHit = PLAYER_EYE + ThirdPersonOffset
				end

				customCamera.Center.Value = WorldHit - (ThirdPersonOffset*0.01)
			else
				customCamera.Center.Value = PLAYER_EYE

			end
		else
			print('gun disabled')
		end

		
		local BOB_SCALE = tween( 0.05, 0.15, aimTween ) 
		local ViewBob = Vector3.new( -RUN_BOB_X*0.2+(IDLE_BOB_X*BOB_SCALE*0.2), -RUN_BOB_Y*0.2+(IDLE_BOB_Y*BOB_SCALE*0.2), 0 )
		if ( not isGunDisabled ) then

			local SwayIntensity = gunCurrentStats.Zoom.SwayIntensity and gunCurrentStats.Zoom.SwayIntensity.Value or 0
			local AttachmentReticle = getAttachment("AttachmentReticle")
			if ( AttachmentReticle and AttachmentReticle.Modifiers:FindFirstChild("SwayIntensity") ) then
				SwayIntensity = SwayIntensity + AttachmentReticle.Modifiers.SwayIntensity.Value
			end
			local ConsoleRecoilModifier = _G.IS_PLAYING_CONSOLE() and 0.5 or 1.0
			local AimModifier = tween( 1.0, 0.75, aimTween )
			local recoilpitch = recoilSpring.Position.Y * RECOIL_SCALE
			local recoilyaw = recoilSpring.Position.X * RECOIL_SCALE

			local SwaySens = 1 
			local SwayAmplitude = SwayIntensity / 60
			local SwayYaw = math.sin(swayticks * SwaySens) * SwayAmplitude
			local SwayPitch = math.sin(swayticks * SwaySens * 2) * SwayAmplitude

			local ViewYaw = SwayYaw + (recoilyaw * ConsoleRecoilModifier * AimModifier)
			local ViewPitch = SwayPitch + (recoilpitch * ConsoleRecoilModifier * AimModifier)

			customCamera.CameraYaw.Offset.Value = ViewYaw
			customCamera.CameraPitch.Offset.Value = ViewPitch
		end		

		
		local iAimTween = getAlphaSmoothStep(aimTween, 2, 1024) 
		local BaseFOV = gunCurrentStats.Zoom.Value
		local Attachment = getAttachment('AttachmentReticle')
		if ( Attachment and Attachment.Modifiers:FindFirstChild("FOV") ) then
			BaseFOV = Attachment.Modifiers:FindFirstChild("FOV").Value
		end

		local FOVMultiplier = 1
		if ( Attachment ) then
			local FOVMultiplierRef = Attachment.Modifiers:FindFirstChild("FOVMultiplier")
			if ( FOVMultiplierRef ) then
				local ReticleAttachmentInPlayer = getInventoryItem(gunCurrentSlot).AttachmentReticle
				local MagnifierAttrib = ReticleAttachmentInPlayer.Value.Modifiers.FOVMultiplier:GetAttribute("MagnifierRange")
				if ( MagnifierAttrib ) then
					MagnifierRatio = tonumber(ReticleAttachmentInPlayer:GetAttribute("MagnifierRatio") or MagnifierRatio) or MagnifierRatio 
					FOVMultiplier = tween( MagnifierAttrib.Min, MagnifierAttrib.Max, MagnifierRatio )
					
				else
					FOVMultiplier = 1 / getInventoryItem(gunCurrentSlot).AttachmentReticle.Value.Modifiers.FOVMultiplier.Value
				end
			end
		end

		
		local ZOOM_FOV = math.deg(math.atan(math.tan(math.rad(BaseFOV)) / FOVMultiplier))
		customCamera.CameraFOV.Value = tween( ZOOM_FOV, script.Configuration.cl_default_fov.Value, iAimTween )
	else
		print('dead or no gun data')
	end
	debug.profileend()

	updatePlayerRotation(delta, getCustomCamera().CameraPitch.Value, getCustomCamera().CameraYaw.Value)
end

function updatePlayerRotation(Delta, CameraPitch, CameraYaw)
	local ViewableCharacter = getViewableCharacter()
	if ( not ViewableCharacter ) then
		return
	end

	
	if ( ViewableCharacter == getCharacter() ) then
		if ( not getHumanoid().Sit and getHumanoid().RootPart and script.RotateCharacter.Value ) then
			local playerRot = CFrame.fromEulerAnglesXYZ(0,CameraYaw,0)
			getHumanoid().RootPart.CFrame = CFrame.new(getHumanoid().RootPart.CFrame.Position)*playerRot
		end
		CurrentSpectatingCharacter = nil
	else
		local CustomCamera = getCustomCamera()
		smoothedSpectateYaw = smoothedSpectateYaw + (CameraYaw-smoothedSpectateYaw)*0.4
		smoothedSpectatePitch = smoothedSpectatePitch + (CameraPitch-smoothedSpectatePitch)*0.4
		CustomCamera.CameraYaw.Value = smoothedSpectateYaw
		CustomCamera.CameraPitch.Value = smoothedSpectatePitch
		CustomCamera.CameraYaw.Offset.Value = 0
		CustomCamera.CameraPitch.Offset.Value = 0
		CurrentSpectatingCharacter = ViewableCharacter
	end
end

function updateStepHeightOffset()
	local root = getRoot()
	if ( not root ) then
		return
	end

	local y = root.Position.Y

	local OnGround = not IsInAir()
	local DeltaY = y-LastY
	if ( OnGround and DeltaY > 0.5 ) then
		stepHeightOffset = stepHeightOffset + DeltaY
	end
	LastY = y
	stepHeightOffset = tween(stepHeightOffset, 0, 0.2)

	if ( getHumanoid().Sit ) then
		stepHeightOffset = 0
	end
end

function updateLocalCharacterTransparency()
	debug.profilebegin("Local Transparency Modifier")
	if (isSpectating) then
		local spectate = getViewableCharacter()
		local spectateHead = spectate:FindFirstChild("Head") or spectate:FindFirstChild("HumanoidRootPart")
		if ( spectateHead ) then
			if ( spectate ~= CurrentSpectatingCharacter ) then
				onSpectateChange(getViewablePlayer())
			end
			updateCharacterVisibility()
		end
	else
		if (getRoot()) then
			updateCharacterVisibility()
		end
	end
	debug.profileend()
end

function onRender1(delta)
	local compatabilityTickrate = delta * 60

	if ( not isEnabled ) then
		return
	end

	local customCamera = getCustomCamera()	
	local character = getCharacter()
	local rootPart = getRoot()
	local humanoid = getHumanoid()

	
	if ( gunCurrent == nil or #gunCurrent:GetChildren() == 0 ) then
		return
	end

	
	
	
	
	
	

	local base_fov = script.Configuration.cl_default_fov.Value
	local current_fov = getCamera().FieldOfView

	local tt = current_fov / base_fov

	
	local zoomSens = tween( script.Configuration.cl_sensitivity_aim_multiplier.Value*tt, 1, aimTween )
	customCamera.Sensitivity.Value = script.Configuration.cl_sensitivity.Value / zoomSens
	customCamera.IsEnabled.Value = not script.DisabledCamera.Value
	customCamera.MouseLookEnabled.Value = true

	
	local ScopeBlurSens = 2048
	ScopeBlurRatioX = ScopeBlurRatioX + (customCamera.MouseDeltaX.Value / ScopeBlurSens)
	ScopeBlurRatioY = ScopeBlurRatioY + (customCamera.MouseDeltaY.Value / ScopeBlurSens)

	
	updateLocalCharacterTransparency()

	
	

	
	debug.profilebegin("Update Aiming")
	updateAiming(delta)
	debug.profileend()
end

function onRender2(delta)
	local compatabilityTickrate = delta * 60

	
	gunSystemEvents.OnPreRender:Fire(delta)

	
	debug.profilebegin("Position Gun")
	doPositionGun(delta, gunViewModel)
	debug.profileend()

	
	for _,v in cpairs(AttachmentData) do
		v.Part.CFrame = v.Bone.TransformedWorldCFrame * v.Offset
		v.Part.Velocity = Vector3.new()

		v.PartTemp.CFrame = v.BoneTemp.TransformedWorldCFrame * v.Offset
		v.PartTemp.Velocity = Vector3.new()
	end

	
	gunSystemEvents.OnRender:Fire(delta)
end

function onRender3(Delta, CameraCFrame, CameraPitch, CameraYaw)
	if ( not isEnabled ) then
		return
	end

	
	updateStepHeightOffset()

	updateCamera(Delta)

	
	
end

function onStart()
	print("Starting Gun System")

	
	ReplicatedStorage:WaitForChild("GunData", 600)
	script:FindFirstChild('IsEnabled').Changed:connect(onEnableChange)
	onEnableChange()

	getPlayer().CharacterAdded:connect(onRespawn)

	
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if ( UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter ) then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onClickDown(0)
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			onClickDown(1)
		end
	end)

	
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onClickUp(0)
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			onClickUp(1)
		end
	end)

	
	UserInputService.InputBegan:connect(onKeyPress)	
	UserInputService.InputEnded:connect(onKeyRelease)

	RunService:BindToRenderStep("GunRendering2", Enum.RenderPriority.Camera.Value,onUpdate1)
	RunService:BindToRenderStep("GunRendering3", Enum.RenderPriority.Camera.Value+math.huge,onUpdate2)
	RunService:BindToRenderStep("GunRendering1", Enum.RenderPriority.Camera.Value-2, onRender1) 
	RunService:BindToRenderStep("GunRendering4", Enum.RenderPriority.Camera.Value-1, onRender2) 
	RunService.Heartbeat:Connect(onStep)
	getCustomCamera().OnPreUpdate.Event:Connect(onRender3) 

	while(not getCharacter())do
		wait()
	end
	Ready = true
	print("Gun System started")
end

onStart()


script.Events.IsActive.OnInvoke = function()
	if ( getViewableCharacter() ~= getCharacter() ) then
		return false
	end

	if ( Player.Spectator.Spectating.Value ) then
		return false
	end

	
	if ( script:FindFirstChild("DisabledGun") ~= nil and script.DisabledGun.Value ) then
		return false
	end

	
	if ( not isEnabled ) then
		return false
	end

	return true
end


script.Events.CanShootGun.OnInvoke = function(inventorySlot)
	return GetCanShoot(inventorySlot)
end


script.Events.GetCurrentGunSlot.OnInvoke = function()
	return gunCurrentSlot
end


script.Events.AttemptShootGun.OnInvoke = function()
	local canShoot, response = GetCanShoot()
	if ( not canShoot ) then
		return canShoot, response
	end
	return AttemptShootGun()
end


script.Events.GetCurrentInventoryData.OnInvoke = function()
	return getInventoryItem(gunCurrentSlot)
end


script.Events.GetCurrentGunData.OnInvoke = function()
	return gunCurrent
end


script.Events.GetGunViewModel.OnInvoke = function()
	return gunViewModel
end


script.Events.GetGunAnimation.OnInvoke = function()
	return currentlyPlayingAnimation
end


script.Events.GetWorldLookAtPos.OnInvoke = function()
	return WorldLookAtPos
end


script.Events.GetGunAnimationName.OnInvoke = function()
	return currentlyPlayingAnimationName
end


script.Events.GetJumpFatigue.OnInvoke = function()
	return math.max(0.5, math.min(1, JumpStamina * MAX_JUMP_STAMINA))
end


script.Events.Flinch.Event:Connect(function(impulse)
	assert(typeof(impulse) == "Vector3")
	recoilSpring:SetPosition(recoilSpring.Position + impulse)
	recoilSpring:Impulse(impulse)
end)


script.Events.SetJumpFatigue.Event:Connect(function(Value)
	JumpStamina = math.clamp(Value, 0, MAX_JUMP_STAMINA)
end)


script.Events.SetAimed.Event:Connect(function(Aimed)
	holdingRight = Aimed == true
end)


script.Events.SetSprinting.Event:Connect(function(Sprinting)
	Sprinting = Sprinting == true
	holdingW = Sprinting
	setRunning(Sprinting)
end)


script.Events.SetCrouching.Event:Connect(function(Crouch)
	setCrouch(Crouch == true)
end)


script.Events.SetThirdPerson.Event:Connect(function(thirdp)
	if ( thirdp and AllowThirdPerson ) then
		ThirdPerson = true
	elseif (not thirdp and AllowFirstPerson) then
		ThirdPerson = false
	end
end)


script.Events.GetSpeed.OnInvoke = function()
	return speed
end


script.Events.IsMobile.OnInvoke = function()
	return script:FindFirstChild("Mobile").Value and script.Mobile.Value or false
end


script.Events.GetAimTween.OnInvoke = function()
	return 1.0 - aimTween
end


script.Events.GetPlayer.OnInvoke = function()
	return Player.Spectator.Spectating.Value or getPlayer()
end


script.Events.IsViewModelEnabled.OnInvoke = function()
	return IsDisplayingViewModel
end


script.Events.IsJumping.OnInvoke = function()
	return IsInAir()
end


script.Events.IsThirdPerson.OnInvoke = function()
	return ThirdPerson
end


script.Events.IsFirstPerson.OnInvoke = function()
	return IsInFirstPerson
end


script.Events.IsSprinting.OnInvoke = function()
	local runReload = not script.Configuration.cl_reload_can_run.Value and reloading
	return running and not runReload and not isAiming() and takeoutRot < 1
end


script.Events.IsCrouching.OnInvoke = function()
	return crouched
end


script.Events.IsReloading.OnInvoke = function()
	return reloading
end


script.Events.IsAimed.OnInvoke = function()
	return isAiming()
end


script.Events.PlayGunSound.Event:Connect(function(SoundName)
	pcall(function()
		local timeout = 0
		while( gunWorldModel == nil and timeout < 100 ) do
			wait()
			timeout = timeout + 1
		end
		if ( gunWorldModel == nil ) then
			return
		end
		playGunSound(SoundName)
	end)
end)

script.Events:FindFirstChild("SetUberschreibenHohe").Event:Connect(function(OverrideHeight)
	OverrideHeight = tonumber(OverrideHeight)
	if ( not OverrideHeight ) then
		OVERRIDE_CAMERA_HEIGHT = nil
		return
	end

	OverrideHeight = math.clamp(OverrideHeight, 0, 10)
	OVERRIDE_CAMERA_HEIGHT = OverrideHeight
end)


script.Events.SetGunAnimation.Event:Connect(function(AnimationName)
	SetGunAnimation(AnimationName, true, 0)
end)

script.Events.Disable.Event:Connect(function()
	if ( not UserCanDisable ) then
		return
	end

	disable()
end)


script.Events.TakeoutWeapon.Event:Connect(function( slot, force, IgnoreSafeTakeoutTime )
	force = force or false

	doReloadCancel()
	script.IsEnabled.Value = true

	takeoutWeapon( slot, force, IgnoreSafeTakeoutTime )
end)


script.Events.SetMagnifierRatio.Event:Connect(function(Ratio)
	Ratio = tonumber(Ratio or 0) or 0
	Ratio = math.clamp(Ratio, 0, 1)

	

	local InventorySlot = getInventoryItem(gunCurrentSlot)
	if ( not InventorySlot ) then
		return
	end

	local AttachmentReticle = InventorySlot:FindFirstChild("AttachmentReticle")
	if ( not AttachmentReticle ) then
		return
	end

	AttachmentReticle:SetAttribute("MagnifierRatio", Ratio)
end)


script.Events.SetBlocked.Event:Connect(function(Blocked)
	BlockedGun = Blocked
end)


ReplicatedStorage.GunEvent.GunForceTakeout.OnClientEvent:Connect(function(Slot, IgnoreSameSlot)
	
	doReloadCancel()
	script.IsEnabled.Value = true

	
	if ( Slot == gunCurrentSlot and not IgnoreSameSlot ) then
		return
	end

	
	takeoutWeapon( Slot, true )
end)

ReplicatedStorage.GunEvent.GunForceReload.OnClientEvent:Connect(function()
	while(holsterWeapon)do
		wait()
	end
	reload()
end)


ReplicatedStorage:WaitForChild("GunSystemSetCharacterRotate").OnClientEvent:Connect(function(Value)
	script.RotateCharacter.Value = Value
end)


ReplicatedStorage.GunEvent.GunForceDisable.OnClientEvent:Connect(function()	
	script.IsEnabled.Value = false
end)


ReplicatedStorage.GunEvent.GunForceRefresh.OnClientEvent:Connect(function()
	if ( not script.IsEnabled.Value ) then
		return
	end

	local InventoryItem = getInventoryItem( gunCurrentSlot )
	if ( InventoryItem == nil ) then
		return
	end

	
	if ( not gunCurrent ) then
		script.Events.TakeoutWeapon:Fire(gunCurrentSlot, true)
	end

	
	if ( not gunCurrent ) then
		return
	end

	
	
end)


ReplicatedStorage.GunEvent.GunForceHitmarker.OnClientEvent:Connect(function(headshot)
	if (HitmarkerEnabled.Value) then
		hitmarkerSound(headshot)
	end
end)

wait(1)


do
	local function get_fn(state, f1, f2)
		return state == Enum.UserInputState.Begin and f1 or f2;
	end

	local CAS = game:GetService('ContextActionService');

	local ControllerReload = 'GunSystemControllerReload';
	local ControllerLeftClick = 'GunSystemControllerLeftclick';
	local ControllerRightClick = 'GunSystemControllerRightclick';
	local ControllerJump = 'GunSystemControllerJump';
	local ControllerCrouch = 'GunSystemControllerCrouch';
	local ControllerSprint = 'GunSystemControllerSprint';
	local ControllerThirdPerson = 'GunSystemControllerThirdPerson';

	local function check_controller_keybind_active(keybind)
		return Keybinds.Controller:GetAttribute(keybind) and Keybinds.Controller:GetAttribute(keybind) ~= ''
	end

	local function bind_controller()
		if (check_controller_keybind_active('Reload')) then
			CAS:BindActionAtPriority(ControllerReload,
				function(_, state)
					get_fn(state, onKeyPress, onKeyRelease)( { KeyCode = Enum.KeyCode[Keybinds.Keyboard:GetAttribute('Reload')] }, false )
					return Enum.ContextActionResult.Pass;
				end,
				false, 1, Enum.KeyCode[Keybinds.Controller:GetAttribute('Reload')]
			);
		else
			CAS:UnbindAction(ControllerReload);
		end

		if (check_controller_keybind_active('Fire')) then
			CAS:BindAction(ControllerLeftClick,
				function(_, state)
					get_fn(state, onClickDown, onClickUp)(0)
					return Enum.ContextActionResult.Pass;
				end,
				false, Enum.KeyCode[Keybinds.Controller:GetAttribute('Fire')]
			);
		else
			CAS:UnbindAction(ControllerLeftClick);
		end

		if (check_controller_keybind_active('Aim')) then
			CAS:BindAction(ControllerRightClick,
				function(_, state)
					get_fn(state, onClickDown, onClickUp)(1)
					return Enum.ContextActionResult.Pass;
				end,
				false, Enum.KeyCode[Keybinds.Controller:GetAttribute('Aim')]
			);
		else
			CAS:UnbindAction(ControllerRightClick);
		end

		if (check_controller_keybind_active('Jump')) then
			CAS:BindActionAtPriority(ControllerJump, 
				function(_, state)
					get_fn(state, onKeyPress, onKeyRelease)( { KeyCode = Enum.KeyCode.Space }, false )
					return Enum.ContextActionResult.Pass;
				end,
				false, Enum.ContextActionPriority.High.Value, Enum.KeyCode[Keybinds.Controller:GetAttribute('Jump')]
			);
		else
			CAS:UnbindAction(ControllerJump);
		end

		if (check_controller_keybind_active('ToggleCrouch')) then
			CAS:BindActionAtPriority(ControllerCrouch,
				function(_, state)
					get_fn(state, onKeyPress, onKeyRelease)( { KeyCode = Enum.KeyCode[Keybinds.Keyboard:GetAttribute('ToggleCrouch')] }, false )
					return Enum.ContextActionResult.Pass;
				end,
				false, 1, Enum.KeyCode[Keybinds.Controller:GetAttribute('ToggleCrouch')]
			);
		else
			CAS:UnbindAction(ControllerCrouch);
		end

		if (check_controller_keybind_active('Sprint')) then
			CAS:BindActionAtPriority(ControllerSprint, function(_, state)
				get_fn(state, onKeyPress, onKeyRelease)( { KeyCode = Enum.KeyCode[Keybinds.Keyboard:GetAttribute('Sprint')] }, false )
				if (state == Enum.UserInputState.Begin) then
					if ( holdingW ) then
						onKeyRelease( { KeyCode = Enum.KeyCode.W }, false )
					else
						onKeyPress( { KeyCode = Enum.KeyCode.W }, false )
					end
				end
				return Enum.ContextActionResult.Pass;
			end, false, 1, Enum.KeyCode[Keybinds.Controller:GetAttribute('Sprint')]);
		else
			CAS:UnbindAction(ControllerSprint);
		end

		if (check_controller_keybind_active('ThirdPersonView')) then
			CAS:BindActionAtPriority(ControllerThirdPerson,
				function(_, state)
					get_fn(state, onKeyPress, onKeyRelease)( { KeyCode = Enum.KeyCode[Keybinds.Keyboard:GetAttribute('ThirdPersonView')] }, false )
					return Enum.ContextActionResult.Pass;
				end,
				false, 1, Enum.KeyCode[Keybinds.Controller:GetAttribute('ThirdPersonView')]
			);
		else
			CAS:UnbindAction(ControllerThirdPerson);
		end
	end

	bind_controller();

	Keybinds.Controller.AttributeChanged:Connect(bind_controller);
end

local mobile_callbacks = {}

script.Events.AddMobileButton.OnInvoke = function(button, callback)
	assert(typeof(button) == "Instance")
	assert(button:IsA("GuiObject"))
	assert(typeof(callback) == "function")

	if ( mobile_callbacks[button] ) then
		error("Cannot overwrite button callback")
	end

	mobile_callbacks[button] = callback
end

script.SystemLoaded.Value = true
script.Events.OnLoad:Fire()
ReplicatedStorage.GunEvent.GunReady:FireServer()


do
	if Player.PlayerGui:WaitForChild("MobileUI", 100000) then
		local touchy =  Player.PlayerGui:WaitForChild("TouchGui").TouchControlFrame
		local buttons = Player.PlayerGui.MobileUI:WaitForChild("Frame")
		local aimBnt = buttons:WaitForChild("AimButton")
		local crouchBnt = buttons:WaitForChild("CrouchButton")
		local reloadBnt = buttons:WaitForChild("ReloadButton")
		local shootBnt = buttons:WaitForChild("ShootButton")
		local jumpBnt = touchy:WaitForChild("JumpButton")

		mobile_callbacks[aimBnt] = function()
			if holdingRight == false then
				onClickDown(1)
			else
				onClickUp(1)
			end
		end

		mobile_callbacks[crouchBnt] = function()
			onKeyPress( { KeyCode = Enum.KeyCode[Keybinds.Keyboard:GetAttribute('ToggleCrouch')] }, false )
		end

		mobile_callbacks[reloadBnt] = function()
			onKeyPress( { KeyCode = Enum.KeyCode[Keybinds.Keyboard:GetAttribute('Reload')] }, false )
		end

		mobile_callbacks[shootBnt] = function()
			mobileFire = true
		end

		local function isInsideButton(inputObject, button)
			local position = inputObject.Position
			local buttonPosition = button.AbsolutePosition
			local buttonSize = button.AbsoluteSize

			return position.X >= buttonPosition.X
				and position.X <= buttonPosition.X + buttonSize.X
				and position.Y >= buttonPosition.Y
				and position.Y <= buttonPosition.Y + buttonSize.Y
		end

		
		UserInputService.InputBegan:Connect(function(inputObject, processed)
			if ( inputObject.UserInputType ~= Enum.UserInputType.Touch ) then
				return
			end

			for button,callback in cpairs(mobile_callbacks) do
				if ( isInsideButton(inputObject, button) ) then
					callback()
				end
			end
		end)

		
		jumpBnt.MouseButton1Up:Connect(function()
			ReleasedSpace = true
		end)

		
		UserInputService.InputEnded:Connect(function(inputObject, processed)
			if ( inputObject.UserInputType ~= Enum.UserInputType.Touch ) then
				return
			end

			local DynamicThumbstickFrame = touchy:FindFirstChild("DynamicThumbstickFrame")
			if ( not DynamicThumbstickFrame ) then
				return
			end

			
			local thumbStick = DynamicThumbstickFrame.ThumbstickEnd
			local t = thumbStick.ImageTransparency
			for i=1,4 do
				task.wait()
			end
			local didLetGo = thumbStick.ImageTransparency > t
			if ( didLetGo ) then
				return
			end

			
			
			mobileFire = false
			holdingLeft = false
			onClickUp(0)
		end)
	end
end