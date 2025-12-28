--!strict

local version: string = "2.1.5"

-- Known Issues:
-- No replay compatibility
-- Ball outline does not show in POV mode
-- Double clicking and hold right click while not moving the mouse makes you unable to rotate the camera. (This is a spectator issue, only happens with UI open)
-- Overtime goals don't have particle affects (think this is fixed)
-- Update Follow+ Framework implementation

-- Dependencies
local Util = require("util")

Util.initializeConfig({
	cameraFOV = 90,
	deadzone = 0,
	followFOV = 100,
	followPosititonSmoothing = 0.1,
	followRadius = 20,
	mouseSensitivity = 1,
	invertMouseLookHorizontal = false,
	invertMouseLookVertical = false,
	invertControllerLookHorizontal = false,
	invertControllerLookVertical = false,
	controllerSensitivity = 1,
	positionSmoothing = 0.02,
	lookSmoothness = 0.25,
	ballOutline = true,
	particleSimSpeed = 1,
	vibrance = 1,
	getBallVariant = "PlayerBallDistance",
	sendOverlayInfo = true,
	thirdPersonMode = 2,
	homeTeamDefaultColor = {
		r = 0,
		g = 0.5,
		b = 0.5,
	},
	awayTeamDefaultColor = {
		r = 1,
		g = 0.1,
		b = 0.1,
	},
	overviewOffsets = {
		_3v3 = {
			{
				position = Vec3.new(1300, -2200, 950),
				rotation = Quat.fromEuler(0, -20, 60),
			},
			{
				position = Vec3.new(1000, 0, 1000),
				rotation = Quat.fromEuler(0, -35, 0),
			},
			{
				position = Vec3.new(1300, 2200, 950),
				rotation = Quat.fromEuler(0, -20, -60),
			},
		},
		_4v4 = {
			{
				position = Vec3.new(1055, -2600, 540),
				rotation = Quat.fromEuler(0, -7.5, 30),
			},
			{
				position = Vec3.new(2935, 0, 65),
				rotation = Quat.fromEuler(0, 5, 0),
			},
			{
				position = Vec3.new(3390, 2595, 215),
				rotation = Quat.fromEuler(0, -7.5, -105),
			},
		},
		_driftblitz = {
			{
				position = Vec3.new(795, -3565, 1140),
				rotation = Quat.fromEuler(0, -20, 60),
			},
			{
				position = Vec3.new(3585, -1670, 40),
				rotation = Quat.fromEuler(0, 0, 50),
			},
			{
				position = Vec3.new(4500, 3135, 620),
				rotation = Quat.fromEuler(0, -15, -90),
			},
		},
		_zdrift = {
			{
				position = Vec3.new(5425, -3355, 1445),
				rotation = Quat.fromEuler(0, -15, 75),
			},
			{
				position = Vec3.new(8845, 0, 630),
				rotation = Quat.fromEuler(0, 5, -180),
			},
			{
				position = Vec3.new(4915, 1560, 1640),
				rotation = Quat.fromEuler(0, -8.5, -170),
			},
		},
	},
	keyboardKeybinds = "",
	gamepadKeybinds = "",
	postProcessing = {
		bloomIntensity = 0.675,
		bloomThreshold = -1,
		depthOfFieldFstop = 4,
		depthOfFieldFocalDistance = 0,
		depthOfFieldSensorWidth = 24.576,
		chromaticAberrationIntensity = 0,
		motionBlurAmount = 0,
		vignetteIntensity = 0.4,
		exposureBias = 1,
	},
})

local InputSystem = require("inputsystem")
type Keybind = InputSystem.Keybind
type CustomInput = InputSystem.CustomInput
type InputSystem = InputSystem.InputSystem

local Box = require("box")
type BoxType = typeof(Box)

local Arena = require("arena")
type OverviewData = {
	overview: { { position: Vec3, rotation: Quat } },
}
type ArenaTeam = Arena.ArenaTeam<OverviewData>
type CasterArena = Arena.Arena<{}, OverviewData, OverviewData> & {
	sendInfoMessage: (self: CasterArena) -> (),
	setupOverviews: (self: CasterArena) -> (),
}

local HUD = require("hud")
type HUD = HUD.HUD

-- GameData
local readLocation = 0
local gameData: ReplayFrame

local defaultKeybinds = {
	keyboard = {
		lineOfSight = { primary = Input.Key.Q, modifiers = { Input.Key.LeftAlt } },
		previousPlayer = { primary = Input.Key.A, modifiers = {} },
		right = { primary = Input.Key.D, modifiers = {} },
		left = { primary = Input.Key.A, modifiers = {} },
		resetFOV = { primary = Input.Key.MiddleMouseButton, modifiers = {} },
		getClosestArena = { primary = Input.Key.Enter, modifiers = {} },
		thirdPerson = { primary = Input.Key.V, modifiers = {} },
		speedDown = { primary = Input.Key.LeftControl, modifiers = {} },
		lookAround = { primary = Input.Key.RightMouseButton, modifiers = {} },
		up = { primary = Input.Key.E, modifiers = {} },
		clearOverlayInfo = { primary = Input.Key.BackSpace, modifiers = {} },
		forwards = { primary = Input.Key.W, modifiers = {} },
		overview3 = { primary = Input.Key.Seven, modifiers = {} },
		freeCam = { primary = Input.Key.Z, modifiers = {} },
		overview1 = { primary = Input.Key.Five, modifiers = {} },
		backwards = { primary = Input.Key.S, modifiers = {} },
		playerBallDistance = { primary = Input.Key.E, modifiers = { Input.Key.LeftAlt } },
		speedUp = { primary = Input.Key.LeftShift, modifiers = {} },
		overview2 = { primary = Input.Key.Six, modifiers = {} },
		nextPlayer = { primary = Input.Key.D, modifiers = {} },
		down = { primary = Input.Key.Q, modifiers = {} },
		firstPerson = { primary = Input.Key.C, modifiers = {} },
	},
	gamepad = {
		moveY = { primary = Input.Gamepad.LeftY, modifiers = {} },
		previousPlayer = { primary = Input.Gamepad.LeftShoulder, modifiers = {} },
		moveX = { primary = Input.Gamepad.LeftX, modifiers = {} },
		nextPlayer = { primary = Input.Gamepad.RightShoulder, modifiers = {} },
		clearOverlayInfo = { primary = Input.Gamepad.Special_Left, modifiers = {} },
		lookY = { primary = Input.Gamepad.RightY, modifiers = {} },
		resetFOV = { primary = Input.Gamepad.DPad_Right, modifiers = {} },
		getClosestArena = { primary = Input.Gamepad.Special_Right, modifiers = {} },
		thirdPerson = { primary = Input.Gamepad.FaceButton_Top, modifiers = {} },
		speedDown = { primary = Input.Gamepad.LeftShoulder, modifiers = {} },
		up = { primary = Input.Gamepad.RightTrigger, modifiers = {} },
		overview3 = { primary = Input.Gamepad.FaceButton_Right, modifiers = { Input.Gamepad.DPad_Left } },
		overview1 = { primary = Input.Gamepad.FaceButton_Left, modifiers = { Input.Gamepad.DPad_Left } },
		zoomOut = { primary = Input.Gamepad.DPad_Down, modifiers = {} },
		zoomIn = { primary = Input.Gamepad.DPad_Up, modifiers = {} },
		firstPerson = { primary = Input.Gamepad.FaceButton_Right, modifiers = {} },
		freeCam = { primary = Input.Gamepad.FaceButton_Left, modifiers = {} },
		playerBallDistance = { primary = Input.Gamepad.RightThumbstick, modifiers = {} },
		speedUp = { primary = Input.Gamepad.RightShoulder, modifiers = {} },
		overview2 = { primary = Input.Gamepad.FaceButton_Top, modifiers = { Input.Gamepad.DPad_Left } },
		lineOfSight = { primary = Input.Gamepad.LeftThumbstick, modifiers = {} },
		down = { primary = Input.Gamepad.LeftTrigger, modifiers = {} },
		lookX = { primary = Input.Gamepad.RightX, modifiers = {} },
	},
}

InputSystem.setDefaultKeybinds(defaultKeybinds.keyboard, defaultKeybinds.gamepad)

function compareVersion(
	actualRelease: number,
	expectedRelease: number,
	actualMajor: number,
	expectedMajor: number,
	actualMinor: number,
	expectedMinor: number
): number
	if actualRelease ~= expectedRelease then
		return actualRelease - expectedRelease
	end
	if actualMajor ~= expectedMajor then
		return actualMajor - expectedMajor
	end
	return actualMinor - expectedMinor
end

function checkVersion(version: string, versionExpression: string, cameraName: string): { success: boolean, msg: string }
	local msg: string = ""
	local release: string? | number, major: string? | number, minor: string? | number =
		version:match("(%d+)%.(%d+)%.(%d+)")
	local exLogic: string?, exRelease: string? | number, exMajor: string? | number, exMinor: string? | number =
		versionExpression:match("([=<>]+)(%d+)%.(%d+)%.(%d+)")

	if not exRelease or not exMajor or not exMinor then
		return { success = false, msg = `Required version expression is wrong, please contact the dev of this issue` }
	end

	if not release or not major or not minor then
		return {
			success = false,
			msg = `Your version of {cameraName} is outdated, the recommended version is {exRelease}.{exMajor}.{exMinor}`,
		}
	end

	release = tonumber(release)
	major = tonumber(major)
	minor = tonumber(minor)
	exRelease = tonumber(exRelease)
	exMajor = tonumber(exMajor)
	exMinor = tonumber(exMinor)

	local comparison = compareVersion(
		release :: number,
		exRelease :: number,
		major :: number,
		exMajor :: number,
		minor :: number,
		exMinor :: number
	)

	msg = `Your {cameraName} version is {release}.{major}.{minor}`
	if exLogic == "=" then
		msg ..= `\nRecommended version of {cameraName} is {exRelease}.{exMajor}.{exMinor}`
		if comparison ~= 0 then
			return { success = false, msg = msg }
		end
	elseif exLogic == ">=" then
		msg ..= `\nRecommended version of {cameraName} is {exRelease}.{exMajor}.{exMinor} or higher`

		if comparison < 0 then
			return { success = false, msg = msg }
		end
	elseif exLogic == "<=" then
		msg ..= `\nRecommended version of {cameraName} is {exRelease}.{exMajor}.{exMinor} or lower`

		if comparison > 0 then
			return { success = false, msg = msg }
		end
	elseif exLogic == ">" then
		msg ..= `\nRecommended version of {cameraName} is higher than {exRelease}.{exMajor}.{exMinor}`

		if comparison <= 0 then
			return { success = false, msg = msg }
		end
	elseif exLogic == "<" then
		msg ..= `\nRecommended version of {cameraName} is lower than {exRelease}.{exMajor}.{exMinor}`

		if comparison >= 0 then
			return { success = false, msg = msg }
		end
	else
		return { success = false, msg = "Unsupported comparison operator" }
	end

	return { success = true, msg = "" }
end

function capitalize(s: string): string
	local firstLetter = s:sub(1, 1):upper()
	s = s:sub(2)
	return `{firstLetter}{s}`
end

function setHideHead(hide: boolean)
	camera.hideNearestHead = hide
end

local deltaTime: number = 0

local loadTime: number = 0
local transitionTime: number
local firstTransition: boolean
local defaultPosition = Vec3.new(0, -3000, -27700)
local defaultRotation = Quat.fromEuler(0, 0, 90)
local rotDelta: Vec3 = Vec3.zeroVector
local perservedGravityUp: Quat = gravity.upRotation

function getGravityUp(): Quat
	if gravity.strength > 0 then
		perservedGravityUp = gravity.upRotation
		return gravity.upRotation
	else
		return perservedGravityUp
	end
end

local cameraPosition: Vec3 = defaultPosition
local cameraVelocity: Vec3 = Vec3.zeroVector

local CameraMode = {
	FirstPerson = 1,
	HeadRotation = 2,
	VelocityRotation = 3,
	FaceTheBall = 4,
}
local CAMERA_MODE_NAMES = {
	[1] = "First Person",
	[2] = "Head Rotation",
	[3] = "Velocity Rotation",
	[4] = "Face The Ball",
}

local ui = HUD.new("", 1920, 1080, 100)

-- Ball
local ball: ReplayBall
local ballOutline: boolean = config.ballOutline
local GetBallVariant = {
	PlayerBallDistance = "PlayerBallDistance",
	LineOfSight = "LineOfSight",
}
local getBallVariant = config.getBallVariant

-- Overlay Camera
local overlayCamera: SpectatorCamera = nil
local overlayId: string = "dennssen.overlayInfo"
local requiredOverlayVersion: string = "=1.0.0"
local overlayWarning: string = ""
local overlayVersion: string = ""
local usingOverlay: boolean = false
local sendOverlayInfo: boolean = config.sendOverlayInfo
local homeTeam: string = ""
local awayTeam: string = ""
local homePreviousRoundScore: number = 0
local awayPreviousRoundScore: number = 0

function sendSafeMessage(camera: SpectatorCamera, message)
	if not usingOverlay or not sendOverlayInfo then
		return
	end

	sendMessage(camera, message)
end

function getOverlayVersion(version: string)
	overlayVersion = version
end

-- Follow Camera
local followPlussCamera: SpectatorCamera = nil
local followPlussId: string = "dennssen.followpluss"
local requiredFollowPlussVersion: string = ">=1.13.0"
local followPlussVersion: string = ""
local followPlussWarning: string = ""
local followPlussTick: (dt: number, isFollowing: boolean) -> ()

local playerFollow = false
local currentPlayer: ReplayPlayer? = nil
local currentPlayerIndex: number = 1
local followFOV: number = config.followFOV
local followPosititonSmoothing: number = config.followPosititonSmoothing
local followRadius: number = config.followRadius
local thirdPersonMode: number = config.thirdPersonMode
local THIRD_PERSON_MODES = {
	HeadRotation = 2,
	VelocityRotation = 3,
	FaceTheBall = 4,
}

function getFollowVersion(version: string)
	followPlussVersion = version
end

function getFollowPlussTick(_followPlussTick: (number, boolean) -> ())
	followPlussTick = _followPlussTick
end

type FollowPlusData = {
	-- Callbacks
	versionCallback: (string) -> ()?,
	getMainProcessCallback: ((number, boolean) -> ()) -> ()?,
	guiCallback: (() -> ()) -> ()?,
	topSettingsCallback: (() -> ()) -> ()?,
	checkboxSettingsCallback: (() -> ()) -> ()?,
	playerSettingsCallback: (() -> ()) -> ()?,
	cameraSettingsCallback: (() -> ()) -> ()?,
	followSettingsCallback: (() -> ()) -> ()?,
	mainSettingsCallback: (() -> ()) -> ()?,
	autoCameraSettingsCallback: (() -> ()) -> ()?,
	savingSettingsCallback: (() -> ()) -> ()?,
	debugSettingsCallback: (() -> ()) -> ()?,
	gestureSettingsCallback: (() -> ()) -> ()?,
	autoShootingSettingsCallback: (() -> ()) -> ()?,
	goalCamSettingsCallback: (() -> ()) -> ()?,
	getTargetPlayerCallback: (() -> ReplayPlayer?) -> ()?,
	getFollowDataCallback: (() -> FollowPlusData) -> ()?,
	setHideHeadCallback: (boolean) -> ()?,

	-- Data
	readLocation: number?,
	showNameTags: boolean?,
	isLeftHanded: boolean?,
	muteSelf: boolean?,
	targetPlayer: ReplayPlayer?,
	targetPlayerName: string?,
	positionSmoothing: number?,
	rotationSmoothing: number?,
	cameraFOV: number?,
	cameraMode: number?,
	radius: number?,
	threshold: number?,
	cameraPositionOffset: Vec3?,
	cameraRotationOffset: Quat?,
	gestureControls: boolean?,
	forwardGestureMode: number?,
	upGestureMode: number?,
	backwardsGestureMode: number?,
	autoBall: boolean?,
	simResolutionScale: number?,
	simTimeLength: number?,
	autoGoalCam: boolean?,
	ballGoalMode: number?,
	goalMode: number?,
	hideNearestHead: boolean?,
	showQuests: boolean?,
	autoRecordReplays: boolean?,
}

type Color = {
	r: number,
	g: number,
	b: number,
}

type Particle = {
	position: Vec3,
	rotation: Quat,
	scale: number,
	velocity: Vec3,
	Color: Color,
	variant: string,
	lifespan: number,
	aliveTime: number,
}

local ParticleVariant = {
	Embers = "embers",
	Rings = "rings",
	GoalRing = "goalring",
	Rocket = "rocket",
}

type Overview = {
	position: Vec3,
	rotation: Quat,
}

type Round = {
	home: {
		score: number,
	},
	away: {
		score: number,
	},
}

local ARENA_TYPES = {
	Arena3v3 = "3v3",
	Arena4v4 = "4v4",
	Driftblitz = "driftblitz",
	ZDrift = "zdrift",
}
local centerBoxSize = Vec3.new(50, 50, 125)
local overviewOffsets = config.overviewOffsets

local CasterArena = {} :: CasterArena
CasterArena.__index = CasterArena
setmetatable(CasterArena, { __index = Arena })

function CasterArena:onGameStartHook()
	sendSafeMessage(overlayCamera, {
		info = "stats",
		value = "clear",
	})

	sendSafeMessage(overlayCamera, {
		info = "rounds",
		value = "clear",
	})
end

function CasterArena:onRoundStartHook() end

function CasterArena:onRoundEndHook(isRestart: boolean, homeScore: number, awayScore: number)
	if isRestart then
		return
	end

	local round: Round = {
		home = {
			score = homeScore,
		},
		away = {
			score = awayScore,
		},
	}

	sendSafeMessage(overlayCamera, {
		info = "rounds",
		value = round,
	})
end

function CasterArena:postTickHook()
	(self :: CasterArena):sendInfoMessage()
end

function CasterArena:sendInfoMessage()
	local homePlayerNames = {}
	local awayPlayerNames = {}
	for _, player in self.home.players do
		table.insert(homePlayerNames, player.playerName)
	end
	for _, player in self.away.players do
		table.insert(awayPlayerNames, player.playerName)
	end

	sendSafeMessage(overlayCamera, {
		info = "players",
		value = {
			team = "home",
			players = homePlayerNames,
		},
	})
	sendSafeMessage(overlayCamera, {
		info = "players",
		value = {
			team = "away",
			players = awayPlayerNames,
		},
	})

	local followedPlayerName = ""
	if currentPlayer then
		followedPlayerName = currentPlayer.playerName
	end

	sendSafeMessage(overlayCamera, {
		info = "followedPlayer",
		value = followedPlayerName,
	})

	sendSafeMessage(overlayCamera, {
		info = "overtime",
		value = self.isOvertime,
	})
	sendSafeMessage(overlayCamera, {
		info = "grace",
		value = self.isGracePeriod,
	})
	sendSafeMessage(overlayCamera, {
		info = "bestOf",
		value = self.bestOfAmount,
	})

	sendSafeMessage(overlayCamera, {
		info = "matchLength",
		value = self.matchLengthSeconds,
	})
end

type Arena3v3 = CasterArena & {
	__index: Arena3v3,

	new: (gamemode: ModuleStateSpectatorLuaApi, frameIndex: number) -> Arena3v3,

	homeRotationOffset: Quat,
	awayRotationOffset: Quat,
	boxSize: Vec3,
	boxOffset: Vec3,
	centerBoxOffset: Vec3,
	goalBoxSize: Vec3,
	goalPositionOffset: Vec3,
}

local Arena3v3 = {} :: Arena3v3
Arena3v3.__index = Arena3v3
setmetatable(Arena3v3, { __index = CasterArena })

Arena3v3.homeRotationOffset = Quat.fromEuler(0, 0, 90)
Arena3v3.awayRotationOffset = Quat.fromEuler(0, 0, -90)
Arena3v3.boxSize = Vec3.new(5100, 6750, 1440)
Arena3v3.boxOffset = Vec3.new(0, 0, 650)
Arena3v3.centerBoxOffset = Vec3.new(0, 0, 300)
Arena3v3.goalBoxSize = Vec3.new(150, 500, 225)
Arena3v3.goalPositionOffset = Vec3.new(3250, 0, 175)

function Arena3v3.new(gamemode: ModuleStateSpectatorLuaApi, frameIndex: number): Arena3v3
	local self: CasterArena = setmetatable(CasterArena.new(gamemode, frameIndex), Arena3v3) :: any
	self.type = "3v3"
	self.name = self.slotId:gsub("TKB_", "")
	self.home.data = { overview = {} }
	self.away.data = { overview = {} }
	self:setupDimensions()
	self:setupOverviews()
	return self :: Arena3v3
end

function Arena3v3:isPointOnHomeSide(point: Vec3): boolean
	local homeDirection = self:getTeamRotation(Util.TeamIndex.HomeTeam):getForwardVector()
	local ballDirection = Util.getForward(self.transform.position, point)
	if homeDirection:dot(ballDirection) >= 0 then
		return true
	else
		return false
	end
end

function Arena3v3:setupDimensions()
	self.box = Box.new(
		self.transform.position + self.transform.rotation:rotateVector(Arena3v3.boxOffset),
		Arena3v3.boxSize,
		self.transform.rotation
	)

	self.centerBox = Box.new(
		self.transform.position + self.transform.rotation:rotateVector(Arena3v3.centerBoxOffset),
		centerBoxSize,
		self.transform.rotation
	)

	self.home.goal = {
		position = self.transform.position + self:getTeamRotation(Util.TeamIndex.HomeTeam)
			:rotateVector(Arena3v3.goalPositionOffset),
		rotation = self.transform.rotation * Arena3v3.homeRotationOffset:inverse(),
		box = Box.empty,
	}

	self.home.goal.box = Box.new(self.home.goal.position, Arena3v3.goalBoxSize, self.home.goal.rotation)

	self.away.goal = {
		position = self.transform.position + self:getTeamRotation(Util.TeamIndex.AwayTeam)
			:rotateVector(Arena3v3.goalPositionOffset),
		rotation = self.transform.rotation * Arena3v3.awayRotationOffset:inverse(),
		box = Box.empty,
	}
	self.away.goal.box = Box.new(self.away.goal.position, Arena3v3.goalBoxSize, self.away.goal.rotation)
end

function Arena3v3:setupOverviews()
	self.home.data.overview = {}
	self.away.data.overview = {}

	for _, overview in overviewOffsets._3v3 do
		local homeOverview = {
			position = self.transform.position + self:getTeamRotation(Util.TeamIndex.HomeTeam)
				:rotateVector(overview.position),
			rotation = self:getTeamRotation(Util.TeamIndex.HomeTeam) * overview.rotation,
		}
		local awayOverview = {
			position = self.transform.position + self:getTeamRotation(Util.TeamIndex.AwayTeam)
				:rotateVector(overview.position),
			rotation = self:getTeamRotation(Util.TeamIndex.AwayTeam) * overview.rotation,
		}

		table.insert(self.home.data.overview, homeOverview)
		table.insert(self.away.data.overview, awayOverview)
	end
end

function Arena3v3:getTeamRotation(teamIndex: number): Quat
	local rotation = Quat.identity
	if teamIndex == Util.TeamIndex.HomeTeam then
		rotation = self.transform.rotation * Arena3v3.homeRotationOffset
	elseif teamIndex == Util.TeamIndex.AwayTeam then
		rotation = self.transform.rotation * Arena3v3.awayRotationOffset
	end

	return rotation
end

function Arena3v3:GUIChangeDimensions()
	Arena3v3.boxSize = Gui.dragFloat3("Arena3v3 Arena Size", Arena3v3.boxSize, 1, -math.huge, math.huge)
	Arena3v3.boxOffset = Gui.dragFloat3("Arena3v3 Position Offset", Arena3v3.boxOffset, 1, -math.huge, math.huge)
	Arena3v3.centerBoxOffset =
		Gui.dragFloat3("Arena3v3 Place Ball Box Position Offset", Arena3v3.centerBoxOffset, 1, -math.huge, math.huge)
	Arena3v3.goalBoxSize = Gui.dragFloat3("Arena3v3 Goal Size", Arena3v3.goalBoxSize, 1, -math.huge, math.huge)
	Arena3v3.goalPositionOffset =
		Gui.dragFloat3("Arena3v3 Goal Position Offset", Arena3v3.goalPositionOffset, 1, -math.huge, math.huge)

	if Gui.button("Print Dimensions") then
		print(`boxSize: {Arena3v3.boxSize}`)
		print(`boxOffset: {Arena3v3.boxOffset}`)
		print(`centerBoxOffset: {Arena3v3.centerBoxOffset}`)
		print(`goalBoxSize: {Arena3v3.goalBoxSize}`)
		print(`goalPositionOffset: {Arena3v3.goalPositionOffset}`)
	end

	self:setupDimensions()
end

type Arena4v4 = CasterArena & {
	__index: Arena4v4,

	new: (gamemode: ModuleStateSpectatorLuaApi, frameIndex: number) -> Arena4v4,
	isOld4v4: (self: Arena4v4) -> boolean,

	homeRotationOffset: Quat,
	awayRotationOffset: Quat,
	boxSize: Vec3,
	boxOffset: Vec3,
	centerBoxOffset: Vec3,
	goalBoxSize: Vec3,
	goalPositionOffset: Vec3,
}

local Arena4v4 = {} :: Arena4v4
Arena4v4.__index = Arena4v4
setmetatable(Arena4v4, { __index = CasterArena })

Arena4v4.homeRotationOffset = Quat.fromEuler(0, 0, 90)
Arena4v4.awayRotationOffset = Quat.fromEuler(0, 0, -90)
Arena4v4.boxSize = Vec3.new(6110, 8400, 1490)
Arena4v4.boxOffset = Vec3.new(0, 0, 600)
Arena4v4.centerBoxOffset = Vec3.new(0, 0, 250)
Arena4v4.goalBoxSize = Vec3.new(220, 450, 225)
Arena4v4.goalPositionOffset = Vec3.new(4050, 0, 175)

function Arena4v4.new(gamemode: ModuleStateSpectatorLuaApi, frameIndex: number): Arena4v4
	local self: Arena4v4 = setmetatable(Arena.new(gamemode, frameIndex), Arena4v4) :: any
	self.type = "4v4"

	local name: string = ""

	if self.slotId:find("TKB") then
		name = self.slotId:gsub("TKB_", "")
	else
		local nameEnd = self.slotId:find("_") :: number
		name = `{self.slotId:sub(1, nameEnd - 1)} {self.slotId:sub(self.slotId:len() - 2)}`
	end

	self.name = name
	self.home.data = { overview = {} }
	self.away.data = { overview = {} }

	self:setupDimensions()
	self:setupOverviews()
	return self :: Arena4v4
end

function Arena4v4:isOld4v4(): boolean
	return self.slotId:find("Jakeball") ~= nil or self.slotId:find("Driftball") ~= nil
end

function Arena4v4:isPointOnHomeSide(point: Vec3): boolean
	local homeDirection = self:getTeamRotation(Util.TeamIndex.HomeTeam):getForwardVector()
	local ballDirection = Util.getForward(self.transform.position, point)
	if homeDirection:dot(ballDirection) >= 0 then
		return true
	else
		return false
	end
end

function Arena4v4:setupDimensions()
	self.box = Box.new(
		self.transform.position + self.transform.rotation:rotateVector(Arena4v4.boxOffset),
		Arena4v4.boxSize,
		self.transform.rotation
	)

	self.centerBox = Box.new(
		self.transform.position + self.transform.rotation:rotateVector(Arena4v4.centerBoxOffset),
		centerBoxSize,
		self.transform.rotation
	)

	self.home.goal = {
		position = self.transform.position + self:getTeamRotation(Util.TeamIndex.HomeTeam)
			:rotateVector(Arena4v4.goalPositionOffset),
		rotation = self.transform.rotation * Arena4v4.homeRotationOffset:inverse(),
		box = Box.empty,
	}

	self.home.goal.box = Box.new(self.home.goal.position, Arena4v4.goalBoxSize, self.home.goal.rotation)

	self.away.goal = {
		position = self.transform.position + self:getTeamRotation(Util.TeamIndex.AwayTeam)
			:rotateVector(Arena4v4.goalPositionOffset),
		rotation = self.transform.rotation * Arena4v4.awayRotationOffset:inverse(),
		box = Box.empty,
	}
	self.away.goal.box = Box.new(self.away.goal.position, Arena4v4.goalBoxSize, self.away.goal.rotation)
end

function Arena4v4:setupOverviews()
	self.home.data.overview = {}
	self.away.data.overview = {}

	for _, overview in overviewOffsets._4v4 do
		local homeOverview = {
			position = self.transform.position + self:getTeamRotation(Util.TeamIndex.HomeTeam)
				:rotateVector(overview.position),
			rotation = self:getTeamRotation(Util.TeamIndex.HomeTeam) * overview.rotation,
		}
		local awayOverview = {
			position = self.transform.position + self:getTeamRotation(Util.TeamIndex.AwayTeam)
				:rotateVector(overview.position),
			rotation = self:getTeamRotation(Util.TeamIndex.AwayTeam) * overview.rotation,
		}

		table.insert(self.home.data.overview, homeOverview)
		table.insert(self.away.data.overview, awayOverview)
	end
end

function Arena4v4:getTeamRotation(teamIndex: number?): Quat
	local rotation = Quat.identity
	if teamIndex == Util.TeamIndex.HomeTeam then
		rotation = self.transform.rotation * Arena4v4.homeRotationOffset
	elseif teamIndex == Util.TeamIndex.AwayTeam then
		rotation = self.transform.rotation * Arena4v4.awayRotationOffset
	end

	if (self :: Arena4v4):isOld4v4() then
		rotation *= Quat.fromEuler(0, 0, 180) -- Comp build has Home and Away side flipped
	end

	return rotation
end

function Arena4v4:GUIChangeDimensions()
	Arena4v4.boxSize = Gui.dragFloat3("Arena4v4 Arena Size", Arena4v4.boxSize, 1, -math.huge, math.huge)
	Arena4v4.boxOffset = Gui.dragFloat3("Arena4v4 Position Offset", Arena4v4.boxOffset, 1, -math.huge, math.huge)
	Arena4v4.centerBoxOffset =
		Gui.dragFloat3("Arena4v4 Place Ball Box Position Offset", Arena4v4.centerBoxOffset, 1, -math.huge, math.huge)
	Arena4v4.goalBoxSize = Gui.dragFloat3("Arena4v4 Goal Size", Arena4v4.goalBoxSize, 1, -math.huge, math.huge)
	Arena4v4.goalPositionOffset =
		Gui.dragFloat3("Arena4v4 Goal Position Offset", Arena4v4.goalPositionOffset, 1, -math.huge, math.huge)

	if Gui.button("Print Dimensions") then
		print(`boxSize: {Arena4v4.boxSize}`)
		print(`boxOffset: {Arena4v4.boxOffset}`)
		print(`centerBoxOffset: {Arena4v4.centerBoxOffset}`)
		print(`goalBoxSize: {Arena4v4.goalBoxSize}`)
		print(`goalPositionOffset: {Arena4v4.goalPositionOffset}`)
	end

	self:setupDimensions()
end

type Driftblitz = CasterArena & {
	__index: Driftblitz,

	new: (gamemode: ModuleStateSpectatorLuaApi, frameIndex: number) -> Driftblitz,

	homeRotationOffset: Quat,
	awayRotationOffset: Quat,
	boxSize: Vec3,
	boxOffset: Vec3,
	centerBoxOffset: Vec3,
	goalBoxSize: Vec3,
	goalPositionOffset: Vec3,
}

local Driftblitz = {} :: Driftblitz
Driftblitz.__index = Driftblitz
setmetatable(Driftblitz, { __index = CasterArena })

Driftblitz.homeRotationOffset = Quat.fromEuler(0, 0, 90)
Driftblitz.awayRotationOffset = Quat.fromEuler(0, 0, -90)
Driftblitz.boxSize = Vec3.new(7270, 11825, 1440)
Driftblitz.boxOffset = Vec3.new(0, 0, 740)
Driftblitz.centerBoxOffset = Vec3.new(0, 0, 100)
Driftblitz.goalBoxSize = Vec3.new(100, 890, 300)
Driftblitz.goalPositionOffset = Vec3.new(5295, 0, 175)

function Driftblitz.new(gamemode: ModuleStateSpectatorLuaApi, frameIndex: number): Driftblitz
	local self: Driftblitz = setmetatable(Arena.new(gamemode, frameIndex), Driftblitz) :: any
	self.name = self.slotId
	self.type = "driftblitz"

	self.home.data = { overview = {} }
	self.away.data = { overview = {} }
	self:setupDimensions()
	self:setupOverviews()
	return self :: Driftblitz
end

function Driftblitz:isPointOnHomeSide(point: Vec3): boolean
	local homeDirection = self:getTeamRotation(Util.TeamIndex.HomeTeam):getForwardVector()
	local ballDirection = Util.getForward(self.transform.position, point)
	if homeDirection:dot(ballDirection) >= 0 then
		return true
	else
		return false
	end
end

function Driftblitz:setupDimensions()
	self.box = Box.new(
		self.transform.position + self.transform.rotation:rotateVector(Driftblitz.boxOffset),
		Driftblitz.boxSize,
		self.transform.rotation
	)

	self.centerBox = Box.new(
		self.transform.position + self.transform.rotation:rotateVector(Driftblitz.centerBoxOffset),
		centerBoxSize,
		self.transform.rotation
	)

	self.home.goal = {
		position = self.transform.position + self:getTeamRotation(Util.TeamIndex.HomeTeam)
			:rotateVector(Driftblitz.goalPositionOffset),
		rotation = self.transform.rotation * Driftblitz.homeRotationOffset:inverse(),
		box = Box.empty,
	}

	self.home.goal.box = Box.new(self.home.goal.position, Driftblitz.goalBoxSize, self.home.goal.rotation)

	self.away.goal = {
		position = self.transform.position + self:getTeamRotation(Util.TeamIndex.AwayTeam)
			:rotateVector(Driftblitz.goalPositionOffset),
		rotation = self.transform.rotation * Driftblitz.awayRotationOffset:inverse(),
		box = Box.empty,
	}
	self.away.goal.box = Box.new(self.away.goal.position, Driftblitz.goalBoxSize, self.away.goal.rotation)
end

function Driftblitz:setupOverviews()
	self.home.data.overview = {}
	self.away.data.overview = {}

	for _, overview in overviewOffsets._driftblitz do
		local homeOverview = {
			position = self.transform.position + self:getTeamRotation(Util.TeamIndex.HomeTeam)
				:rotateVector(overview.position),
			rotation = self:getTeamRotation(Util.TeamIndex.HomeTeam) * overview.rotation,
		}
		local awayOverview = {
			position = self.transform.position + self:getTeamRotation(Util.TeamIndex.AwayTeam)
				:rotateVector(overview.position),
			rotation = self:getTeamRotation(Util.TeamIndex.AwayTeam) * overview.rotation,
		}

		table.insert(self.home.data.overview, homeOverview)
		table.insert(self.away.data.overview, awayOverview)
	end
end

function Driftblitz:getTeamRotation(teamIndex: number): Quat
	local rotation = Quat.identity
	if teamIndex == Util.TeamIndex.HomeTeam then
		rotation = self.transform.rotation * Driftblitz.homeRotationOffset
	elseif teamIndex == Util.TeamIndex.AwayTeam then
		rotation = self.transform.rotation * Driftblitz.awayRotationOffset
	end

	return rotation
end

function Driftblitz:GUIChangeDimensions()
	Driftblitz.boxSize = Gui.dragFloat3("Driftblitz Arena Size", Driftblitz.boxSize, 1, -math.huge, math.huge)
	Driftblitz.boxOffset = Gui.dragFloat3("Driftblitz Position Offset", Driftblitz.boxOffset, 1, -math.huge, math.huge)
	Driftblitz.centerBoxOffset = Gui.dragFloat3(
		"Driftblitz Place Ball Box Position Offset",
		Driftblitz.centerBoxOffset,
		1,
		-math.huge,
		math.huge
	)
	Driftblitz.goalBoxSize = Gui.dragFloat3("Driftblitz Goal Size", Driftblitz.goalBoxSize, 1, -math.huge, math.huge)
	Driftblitz.goalPositionOffset =
		Gui.dragFloat3("Driftblitz Goal Position Offset", Driftblitz.goalPositionOffset, 1, -math.huge, math.huge)

	if Gui.button("Print Dimensions") then
		print(`boxSize: {Driftblitz.boxSize}`)
		print(`boxOffset: {Driftblitz.boxOffset}`)
		print(`centerBoxOffset: {Driftblitz.centerBoxOffset}`)
		print(`goalBoxSize: {Driftblitz.goalBoxSize}`)
		print(`goalPositionOffset: {Driftblitz.goalPositionOffset}`)
	end

	self:setupDimensions()
end

type ZDrift = CasterArena & {
	__index: ZDrift,

	new: (gamemode: ModuleStateSpectatorLuaApi, frameIndex: number) -> ZDrift,

	homeRotationOffset: Quat,
	awayRotationOffset: Quat,
	boxSize: Vec3,
	boxOffset: Vec3,
	centerBoxOffset: Vec3,
	goalBoxSize: Vec3,
	goalPositionOffset: Vec3,
}

local ZDrift = {} :: ZDrift
ZDrift.__index = ZDrift
setmetatable(ZDrift, { __index = CasterArena })

ZDrift.homeRotationOffset = Quat.fromEuler(0, 0, 90)
ZDrift.awayRotationOffset = Quat.fromEuler(0, 0, -90)
ZDrift.boxSize = Vec3.new(7180, 17800, 1710)
ZDrift.boxOffset = Vec3.new(0, 0, 880)
ZDrift.centerBoxOffset = Vec3.new(0, 0, 500)
ZDrift.goalBoxSize = Vec3.new(600, 600, 600)
ZDrift.goalPositionOffset = Vec3.new(8200, 0, 585)

function ZDrift.new(gamemode: ModuleStateSpectatorLuaApi, frameIndex: number): ZDrift
	local self: ZDrift = setmetatable(Arena.new(gamemode, frameIndex), ZDrift) :: any
	self.type = "zdrift"

	local name: string = self.slotId:gsub("_", " ")

	self.name = name
	self.home.data = { overview = {} }
	self.away.data = { overview = {} }

	self:setupDimensions()
	self:setupOverviews()

	return self :: ZDrift
end

function ZDrift:isPointOnHomeSide(point: Vec3): boolean
	local homeDirection = self:getTeamRotation(Util.TeamIndex.HomeTeam):getForwardVector()
	local ballDirection = Util.getForward(self.transform.position, point)
	if homeDirection:dot(ballDirection) >= 0 then
		return true
	else
		return false
	end
end

function ZDrift:setupDimensions()
	self.box = Box.new(
		self.transform.position + self.transform.rotation:rotateVector(ZDrift.boxOffset),
		ZDrift.boxSize,
		self.transform.rotation
	)

	self.centerBox = Box.new(
		self.transform.position + self.transform.rotation:rotateVector(ZDrift.centerBoxOffset),
		centerBoxSize,
		self.transform.rotation
	)

	self.home.goal = {
		position = self.transform.position + self:getTeamRotation(Util.TeamIndex.HomeTeam)
			:rotateVector(ZDrift.goalPositionOffset),
		rotation = self.transform.rotation * ZDrift.homeRotationOffset:inverse(),
		box = Box.empty,
	}

	self.home.goal.box = Box.new(self.home.goal.position, ZDrift.goalBoxSize, self.home.goal.rotation)

	self.away.goal = {
		position = self.transform.position + self:getTeamRotation(Util.TeamIndex.AwayTeam)
			:rotateVector(ZDrift.goalPositionOffset),
		rotation = self.transform.rotation * ZDrift.awayRotationOffset:inverse(),
		box = Box.empty,
	}
	self.away.goal.box = Box.new(self.away.goal.position, ZDrift.goalBoxSize, self.away.goal.rotation)
end

function ZDrift:setupOverviews()
	self.home.data.overview = {}
	self.away.data.overview = {}

	for _, overview in overviewOffsets._zdrift do
		local homeOverview = {
			position = self.transform.position + self:getTeamRotation(Util.TeamIndex.HomeTeam)
				:rotateVector(overview.position),
			rotation = self:getTeamRotation(Util.TeamIndex.HomeTeam) * overview.rotation,
		}
		local awayOverview = {
			position = self.transform.position + self:getTeamRotation(Util.TeamIndex.AwayTeam)
				:rotateVector(overview.position),
			rotation = self:getTeamRotation(Util.TeamIndex.AwayTeam) * overview.rotation,
		}

		table.insert(self.home.data.overview, homeOverview)
		table.insert(self.away.data.overview, awayOverview)
	end
end

function ZDrift:getTeamRotation(teamIndex: number?): Quat
	local rotation = Quat.identity
	if teamIndex == Util.TeamIndex.HomeTeam then
		rotation = self.transform.rotation * ZDrift.homeRotationOffset
	elseif teamIndex == Util.TeamIndex.AwayTeam then
		rotation = self.transform.rotation * ZDrift.awayRotationOffset
	end

	return rotation
end

function ZDrift:GUIChangeDimensions()
	ZDrift.boxSize = Gui.dragFloat3("ZDrift Arena Size", ZDrift.boxSize, 1, -math.huge, math.huge)
	ZDrift.boxOffset = Gui.dragFloat3("ZDrift Position Offset", ZDrift.boxOffset, 1, -math.huge, math.huge)
	ZDrift.centerBoxOffset =
		Gui.dragFloat3("ZDrift Place Ball Box Position Offset", ZDrift.centerBoxOffset, 1, -math.huge, math.huge)
	ZDrift.goalBoxSize = Gui.dragFloat3("ZDrift Goal Size", ZDrift.goalBoxSize, 1, -math.huge, math.huge)
	ZDrift.goalPositionOffset =
		Gui.dragFloat3("ZDrift Goal Position Offset", ZDrift.goalPositionOffset, 1, -math.huge, math.huge)

	if Gui.button("Print Dimensions") then
		print(`boxSize: {ZDrift.boxSize}`)
		print(`boxOffset: {ZDrift.boxOffset}`)
		print(`centerBoxOffset: {ZDrift.centerBoxOffset}`)
		print(`goalBoxSize: {ZDrift.goalBoxSize}`)
		print(`goalPositionOffset: {ZDrift.goalPositionOffset}`)
	end

	self:setupDimensions()
end

local cachedGamemodesAmount: number = 0

function getArenas(): { [any]: CasterArena }
	local arenas: { [any]: CasterArena } = {}
	local gamemodes = SpectatorGamemodes.listGamemodes()
	for _, gamemode in gamemodes do
		local slotId = gamemode:getSlotId()
		if
			slotId:find("TKB")
			and not slotId:find("Driftplex")
			and not slotId:find("Full")
			and not slotId:find("Playground")
		then
			local arena: CasterArena = Arena3v3.new(gamemode, readLocation) :: Arena3v3
			arenas[arena.name] = arena
		elseif slotId:find("Soccer") then
			local arena: CasterArena = Driftblitz.new(gamemode, readLocation) :: Driftblitz
			arenas[arena.name] = arena
		elseif
			(slotId:find("Jakeball") or slotId:find("Driftball"))
			or (slotId:find("TKB") and slotId:find("Driftplex") and not slotId:find("Full"))
		then
			local arena: CasterArena = Arena4v4.new(gamemode, readLocation) :: Arena4v4
			arenas[arena.name] = arena
		elseif slotId:find("ZDrift") then
			local arena: CasterArena = ZDrift.new(gamemode, readLocation) :: ZDrift
			arenas[arena.name] = arena
		end
	end

	return arenas
end

-- arena
local arenas: { [any]: CasterArena }?

function updateArenaOverviews()
	overviewOffsets = config.overviewOffsets

	if not arenas then
		return
	end

	for _, arena in arenas do
		arena:setupOverviews()
	end
end

local selectedArena: CasterArena = nil

-- Particles
local homeTeamDefaultColor: Color = config.homeTeamDefaultColor
local awayTeamDefaultColor: Color = config.awayTeamDefaultColor
local homeTeamPrimaryColor: Color = homeTeamDefaultColor
local awayTeamPrimaryColor: Color = awayTeamDefaultColor
local vibrance = config.vibrance
local particlesTable = {}
local particleSimSpeed = config.particleSimSpeed

-- Post Processing

local bloomIntensity = config.postProcessing.bloomIntensity
local bloomThreshold = config.postProcessing.bloomThreshold
local depthOfFieldFstop = config.postProcessing.depthOfFieldFstop
local depthOfFieldFocalDistance = config.postProcessing.depthOfFieldFocalDistance
local depthOfFieldSensorWidth = config.postProcessing.depthOfFieldSensorWidth
local chromaticAberrationIntensity = config.postProcessing.chromaticAberrationIntensity
local motionBlurAmount = config.postProcessing.motionBlurAmount
local vignetteIntensity = config.postProcessing.vignetteIntensity
local exposureBias = config.postProcessing.exposureBias

-- Stats
type BallCollision = {
	home: {
		current: {
			lastContactPlace: Vec3,
			contactTime: number,
			player: ReplayPlayer,
		}?,
		previous: {
			lastContactPlace: Vec3,
			contactTime: number,
			player: ReplayPlayer,
		}?,
	},
	away: {
		current: {
			lastContactPlace: Vec3,
			contactTime: number,
			player: ReplayPlayer,
		}?,
		previous: {
			lastContactPlace: Vec3,
			contactTime: number,
			player: ReplayPlayer,
		}?,
	},
}

local ballCollisionInfo: BallCollision = {
	home = {
		current = nil,
		previous = nil,
	},
	away = {
		current = nil,
		previous = nil,
	},
}

local homeGoalPotentialEnter: boolean = false
local previousHomeGoalPotentialEnter: boolean = false
local awayGoalPotentialEnter: boolean = false
local previousAwayGoalPotentialEnter: boolean = false

local maximumTimeSincePass: number = 5

local goalPlayer: ReplayPlayer? = nil

-- Gravity
local gravityChaser: Quat = gravity.upRotation

-- Caster Camera
local cameraFOV = config.cameraFOV
local cameraMode = nil
-- amount of seconds it takes for the camera to reach it's target
local positionSmoothing = config.positionSmoothing
local cameraPositionSmoothing: number = positionSmoothing
local lookSmoothness = config.lookSmoothness
local dynamicLookSmoothness = lookSmoothness
local targetSpeedIndex: number = 1
local speedGears = {
	7,
	14,
	21,
	28,
	35,
}
local currentSpeedIndex: number = targetSpeedIndex
local gearShiftTime: number = 0
local gearShiftTimeRequired: number = 0.3
local speedLastGearBuffer = false
local turnVelocity: Vec2 = Vec2.zeroVector

-- Input

local Vertical: number = 0
local Horizontal: number = 0
local Up: number = 0
local deadzone: number = config.deadzone
local rotEuler: Vec3 = Vec3.zeroVector

local keyboardKeybindsDeserialized = InputSystem.decodeKeybinds(config.keyboardKeybinds)
local gamepadKeybindsDeserialized = InputSystem.decodeKeybinds(config.gamepadKeybinds)

if Util.getDictSize(keyboardKeybindsDeserialized) == 0 then
	keyboardKeybindsDeserialized = InputSystem.defaultKeybinds.keyboard
end

if Util.getDictSize(gamepadKeybindsDeserialized) == 0 then
	gamepadKeybindsDeserialized = InputSystem.defaultKeybinds.gamepad
end

InputSystem.inputs = {
	keyboard = {
		forwards = InputSystem.createCustomInput(
			"Move Forwards",
			"Move camera forward",
			keyboardKeybindsDeserialized["forwards"].primary,
			keyboardKeybindsDeserialized["forwards"].modifiers
		),
		right = InputSystem.createCustomInput(
			"Move Right",
			"Move camera right",
			keyboardKeybindsDeserialized["right"].primary,
			keyboardKeybindsDeserialized["right"].modifiers
		),
		left = InputSystem.createCustomInput(
			"Move Left",
			"Move camera left",
			keyboardKeybindsDeserialized["left"].primary,
			keyboardKeybindsDeserialized["left"].modifiers
		),
		backwards = InputSystem.createCustomInput(
			"Move Backwards",
			"Move camera backward",
			keyboardKeybindsDeserialized["backwards"].primary,
			keyboardKeybindsDeserialized["backwards"].modifiers
		),
		up = InputSystem.createCustomInput(
			"Move Up",
			"Move camera up",
			keyboardKeybindsDeserialized["up"].primary,
			keyboardKeybindsDeserialized["up"].modifiers
		),
		down = InputSystem.createCustomInput(
			"Move Down",
			"Move camera down",
			keyboardKeybindsDeserialized["down"].primary,
			keyboardKeybindsDeserialized["down"].modifiers
		),
		nextPlayer = InputSystem.createCustomInput(
			"Next Player",
			"Cycle to next player (POV mode)",
			keyboardKeybindsDeserialized["nextPlayer"].primary,
			keyboardKeybindsDeserialized["nextPlayer"].modifiers
		),
		previousPlayer = InputSystem.createCustomInput(
			"Previous Player",
			"Cycle to previous player (POV mode)",
			keyboardKeybindsDeserialized["previousPlayer"].primary,
			keyboardKeybindsDeserialized["previousPlayer"].modifiers
		),
		lineOfSight = InputSystem.createCustomInput(
			"Line of Sight",
			"Target: Player in line of sight",
			keyboardKeybindsDeserialized["lineOfSight"].primary,
			keyboardKeybindsDeserialized["lineOfSight"].modifiers
		),
		playerBallDistance = InputSystem.createCustomInput(
			"Closest to Ball",
			"Target: Player nearest ball",
			keyboardKeybindsDeserialized["playerBallDistance"].primary,
			keyboardKeybindsDeserialized["playerBallDistance"].modifiers
		),
		speedUp = InputSystem.createCustomInput(
			"Speed Up",
			"Increase camera speed",
			keyboardKeybindsDeserialized["speedUp"].primary,
			keyboardKeybindsDeserialized["speedUp"].modifiers
		),
		speedDown = InputSystem.createCustomInput(
			"Speed Down",
			"Decrease camera speed",
			keyboardKeybindsDeserialized["speedDown"].primary,
			keyboardKeybindsDeserialized["speedDown"].modifiers
		),
		thirdPerson = InputSystem.createCustomInput(
			"Third Person",
			"Toggle third-person view",
			keyboardKeybindsDeserialized["thirdPerson"].primary,
			keyboardKeybindsDeserialized["thirdPerson"].modifiers
		),
		firstPerson = InputSystem.createCustomInput(
			"First Person",
			"Toggle first-person view",
			keyboardKeybindsDeserialized["firstPerson"].primary,
			keyboardKeybindsDeserialized["firstPerson"].modifiers
		),
		freeCam = InputSystem.createCustomInput(
			"Free Cam",
			"Toggle free-cam view",
			keyboardKeybindsDeserialized["freeCam"].primary,
			keyboardKeybindsDeserialized["freeCam"].modifiers
		),
		overview1 = InputSystem.createCustomInput(
			"Overview 1",
			"Jump to first overview position",
			keyboardKeybindsDeserialized["overview1"].primary,
			keyboardKeybindsDeserialized["overview1"].modifiers
		),
		overview2 = InputSystem.createCustomInput(
			"Overview 2",
			"Jump to second overview position",
			keyboardKeybindsDeserialized["overview2"].primary,
			keyboardKeybindsDeserialized["overview2"].modifiers
		),
		overview3 = InputSystem.createCustomInput(
			"Overview 3",
			"Jump to third overview position",
			keyboardKeybindsDeserialized["overview3"].primary,
			keyboardKeybindsDeserialized["overview3"].modifiers
		),
		getClosestArena = InputSystem.createCustomInput(
			"Select Arena",
			"Select closest arena",
			keyboardKeybindsDeserialized["getClosestArena"].primary,
			keyboardKeybindsDeserialized["getClosestArena"].modifiers
		),
		clearOverlayInfo = InputSystem.createCustomInput(
			"Clear Overlay Data",
			"Remove overlay data",
			keyboardKeybindsDeserialized["clearOverlayInfo"].primary,
			keyboardKeybindsDeserialized["clearOverlayInfo"].modifiers
		),
		lookAround = InputSystem.createCustomInput(
			"Look Around",
			"Hold to rotate camera",
			keyboardKeybindsDeserialized["lookAround"].primary,
			keyboardKeybindsDeserialized["lookAround"].modifiers
		),
		resetFOV = InputSystem.createCustomInput(
			"Reset FOV",
			"Reset field of view",
			keyboardKeybindsDeserialized["resetFOV"].primary,
			keyboardKeybindsDeserialized["resetFOV"].modifiers
		),
	},
	gamepad = {
		moveY = InputSystem.createCustomInput(
			"MoveY",
			"Move Camera Forwards/Backwards",
			gamepadKeybindsDeserialized["moveY"].primary,
			gamepadKeybindsDeserialized["moveY"].modifiers,
			false
		),
		moveX = InputSystem.createCustomInput(
			"MoveX",
			"Move Camera Left/Right",
			gamepadKeybindsDeserialized["moveX"].primary,
			gamepadKeybindsDeserialized["moveX"].modifiers,
			false
		),
		up = InputSystem.createCustomInput(
			"Move Up",
			"Move Camera Up",
			gamepadKeybindsDeserialized["up"].primary,
			gamepadKeybindsDeserialized["up"].modifiers
		),
		down = InputSystem.createCustomInput(
			"Move Down",
			"Move Camera Down",
			gamepadKeybindsDeserialized["down"].primary,
			gamepadKeybindsDeserialized["down"].modifiers
		),
		nextPlayer = InputSystem.createCustomInput(
			"Next Player",
			"Cycle to next player (POV mode)",
			gamepadKeybindsDeserialized["nextPlayer"].primary,
			gamepadKeybindsDeserialized["nextPlayer"].modifiers
		),
		previousPlayer = InputSystem.createCustomInput(
			"Previous Player",
			"Cycle to previous player (POV mode)",
			gamepadKeybindsDeserialized["previousPlayer"].primary,
			gamepadKeybindsDeserialized["previousPlayer"].modifiers
		),
		lineOfSight = InputSystem.createCustomInput(
			"Line Of Sight",
			"Target: Player in line of sight",
			gamepadKeybindsDeserialized["lineOfSight"].primary,
			gamepadKeybindsDeserialized["lineOfSight"].modifiers
		),
		playerBallDistance = InputSystem.createCustomInput(
			"Closest to Ball",
			"Target: Player nearest ball",
			gamepadKeybindsDeserialized["playerBallDistance"].primary,
			gamepadKeybindsDeserialized["playerBallDistance"].modifiers
		),
		speedUp = InputSystem.createCustomInput(
			"Speed Up",
			"Increase camera speed",
			gamepadKeybindsDeserialized["speedUp"].primary,
			gamepadKeybindsDeserialized["speedUp"].modifiers
		),
		speedDown = InputSystem.createCustomInput(
			"Speed Down",
			"Decrease camera speed",
			gamepadKeybindsDeserialized["speedDown"].primary,
			gamepadKeybindsDeserialized["speedDown"].modifiers
		),
		lookY = InputSystem.createCustomInput(
			"LookY",
			"Look Up/Down",
			gamepadKeybindsDeserialized["lookY"].primary,
			gamepadKeybindsDeserialized["lookY"].modifiers,
			false
		),
		lookX = InputSystem.createCustomInput(
			"LookX",
			"Look Left/Right",
			gamepadKeybindsDeserialized["lookX"].primary,
			gamepadKeybindsDeserialized["lookX"].modifiers,
			false
		),
		zoomIn = InputSystem.createCustomInput(
			"Zoom In",
			"Increase field of view",
			gamepadKeybindsDeserialized["zoomIn"].primary,
			gamepadKeybindsDeserialized["zoomIn"].modifiers
		),
		zoomOut = InputSystem.createCustomInput(
			"Zoom Out",
			"Decrease field of view",
			gamepadKeybindsDeserialized["zoomOut"].primary,
			gamepadKeybindsDeserialized["zoomOut"].modifiers
		),
		resetFOV = InputSystem.createCustomInput(
			"Reser FOV",
			"Reset field of view",
			gamepadKeybindsDeserialized["resetFOV"].primary,
			gamepadKeybindsDeserialized["resetFOV"].modifiers
		),
		freeCam = InputSystem.createCustomInput(
			"Free Cam",
			"Toggle free-cam view",
			gamepadKeybindsDeserialized["freeCam"].primary,
			gamepadKeybindsDeserialized["freeCam"].modifiers
		),
		firstPerson = InputSystem.createCustomInput(
			"First Person",
			"Toggle first-person view",
			gamepadKeybindsDeserialized["firstPerson"].primary,
			gamepadKeybindsDeserialized["firstPerson"].modifiers
		),
		thirdPerson = InputSystem.createCustomInput(
			"Third Person",
			"Toggle third-person view",
			gamepadKeybindsDeserialized["thirdPerson"].primary,
			gamepadKeybindsDeserialized["thirdPerson"].modifiers
		),
		overview1 = InputSystem.createCustomInput(
			"Overview 1",
			"Jump to first overview position",
			gamepadKeybindsDeserialized["overview1"].primary,
			gamepadKeybindsDeserialized["overview1"].modifiers
		),
		overview2 = InputSystem.createCustomInput(
			"Overview 2",
			"Jump to second overview position",
			gamepadKeybindsDeserialized["overview2"].primary,
			gamepadKeybindsDeserialized["overview2"].modifiers
		),
		overview3 = InputSystem.createCustomInput(
			"Overview 3",
			"Jump to third overview position",
			gamepadKeybindsDeserialized["overview3"].primary,
			gamepadKeybindsDeserialized["overview3"].modifiers
		),
		getClosestArena = InputSystem.createCustomInput(
			"Select Arena",
			"Select closest arena",
			gamepadKeybindsDeserialized["getClosestArena"].primary,
			gamepadKeybindsDeserialized["getClosestArena"].modifiers
		),
		clearOverlayInfo = InputSystem.createCustomInput(
			"Clear Overlay Data",
			"Remove Overlay Data",
			gamepadKeybindsDeserialized["clearOverlayInfo"].primary,
			gamepadKeybindsDeserialized["clearOverlayInfo"].modifiers
		),
	},
}

local inputOrder = {
	keyboard = {
		"forwards",
		"left",
		"backwards",
		"right",
		"down",
		"up",
		"nextPlayer",
		"previousPlayer",
		"lineOfSight",
		"playerBallDistance",
		"speedUp",
		"speedDown",
		"resetFOV",
		"lookAround",
		"freeCam",
		"firstPerson",
		"thirdPerson",
		"overview1",
		"overview2",
		"overview3",
		"getClosestArena",
		"clearOverlayInfo",
	},
	gamepad = {
		"moveY",
		"moveX",
		"up",
		"down",
		"nextPlayer",
		"previousPlayer",
		"lineOfSight",
		"playerBallDistance",
		"speedUp",
		"speedDown",
		"lookY",
		"lookX",
		"zoomIn",
		"zoomOut",
		"resetFOV",
		"freeCam",
		"firstPerson",
		"thirdPerson",
		"overview1",
		"overview2",
		"overview3",
		"getClosestArena",
		"clearOverlayInfo",
	},
}

--  Mouse
local invertMouseLookHorizontal: boolean = config.invertMouseLookHorizontal
local invertMouseLookVertical: boolean = config.invertMouseLookVertical
local mouseSensitivity: number = config.mouseSensitivity
local mouseWheelAxis = Input.Key.MouseWheelAxis

--  Gamepad
local invertControllerLookHorizontal: boolean = config.invertControllerLookHorizontal
local invertControllerLookVertical: boolean = config.invertControllerLookVertical
local controllerSensitivity: number = config.controllerSensitivity

-- Gui
local debugFreecam: boolean = false
local controlsScreen: boolean = false
local keyboardControls: boolean = true
local controllerControls: boolean = false
local boundingBoxDebug: boolean = false
local addRound: boolean = false
local overlayResponse: string = ""
local overviewMessage = {
	overviewNumber = 0,
	message = "",
}
local tpGamemodeName: string = ""

function getGamemodeByName(gamemodeName: string): ModuleStateSpectatorLuaApi?
	for _, gamemode in SpectatorGamemodes.listGamemodes() do
		if gamemode:getSlotId() == gamemodeName then
			return gamemode
		end
	end

	return nil
end

function setGlobalCameraRotation(globalRotation)
	camera.rotation = globalRotation
	perservedGravityUp = Util.getUpRotation(selectedArena.transform.rotation:getUpVector())
	local localRotation = getGravityUp():inverse() * globalRotation
	rotEuler = localRotation:euler()
end

function setGlobalCameraTransform(position: Vec3, rotation: Quat)
	cameraPosition = position
	setGlobalCameraRotation(rotation)
end

function main()
	loadTime = os.clock()
	camera.position = defaultPosition
	camera.rotation = defaultRotation
	camera.rotationSmoothing = 0
	camera.positionSmoothing = 0
	rotEuler = defaultRotation:euler()
	followPlussCamera = getCameraById(followPlussId)
	if followPlussCamera then
		local followSetupMessage: FollowPlusData = {
			getMainProcessCallback = getFollowPlussTick,
			versionCallback = getFollowVersion,
			setHideHeadCallback = setHideHead,
		}

		sendMessage(followPlussCamera, followSetupMessage)
		local result = checkVersion(followPlussVersion, requiredFollowPlussVersion, "Follow Pluss")
		if not result.success then
			followPlussWarning =
				`WARNING:\n{result.msg}.\nIf you are experiencing issues please install the recommended version.`
		end
	else
		followPlussWarning =
			"WARNING:\nFollow Pluss is not installed. POV mode will not work. \nPlease install Follow Pluss for POV to work."
	end
	overlayCamera = getCameraById(overlayId)
	if overlayCamera then
		usingOverlay = true
		sendMessage(overlayCamera, {
			info = "version",
			value = getOverlayVersion,
		})
		local result = checkVersion(overlayVersion, requiredOverlayVersion, "Overlay Info")
		if not result.success then
			overlayWarning =
				`WARNING:\n{result.msg}.\nIf you are experiencing issues please install the recommended version.`
		end
	end
end

function updateOverview(overviewKey: number, globalOverviewPosition: Vec3, globalOverviewRotation: Quat): string
	if not selectedArena.box:checkPointIntersect(globalOverviewPosition) then
		return "Overviews cannot be outside an arena!"
	end

	local isOnHomeSide = selectedArena:isPointOnHomeSide(globalOverviewPosition)

	local translatedOverviewPosition
	local translatedOverviewRotation
	local flipQuat
	if isOnHomeSide then
		flipQuat = selectedArena:getTeamRotation(Util.TeamIndex.HomeTeam):inverse()
	else
		flipQuat = selectedArena:getTeamRotation(Util.TeamIndex.AwayTeam):inverse()
	end

	translatedOverviewPosition = flipQuat:rotateVector(globalOverviewPosition - selectedArena.transform.position)
	translatedOverviewRotation = flipQuat * globalOverviewRotation

	config.overviewOffsets[`_{selectedArena.type}`][overviewKey] = {
		position = translatedOverviewPosition,
		rotation = translatedOverviewRotation,
	}
	saveConfig()
	updateArenaOverviews()
	return `Succesfully set Overview #{overviewKey} to Camera`
end

function resetPlayersWithBall()
	ballCollisionInfo.home.current = nil
	ballCollisionInfo.home.previous = nil
	ballCollisionInfo.away.current = nil
	ballCollisionInfo.away.previous = nil
end

function setSelectedArena(arena: CasterArena)
	if (selectedArena and arena.name ~= selectedArena.name) or not selectedArena then -- new arena
		resetPlayersWithBall()
		sendSafeMessage(overlayCamera, {
			info = "rounds",
			value = "clear",
		})
		sendSafeMessage(overlayCamera, {
			info = "slotId",
			value = arena.slotId,
		})
	end
	arena.instantUpdate = true
	selectedArena = arena
end

function onGui()
	if followPlussWarning ~= "" then
		Gui.text(followPlussWarning)
		Gui.newLine()
	end

	Gui.text(`Version: {version}`)
	if Gui.button(Icon.Question) then
		controlsScreen = not controlsScreen
	end
	Gui.setItemTooltip("Keybinds for the camera")

	if controlsScreen then
		if keyboardControls then
			Gui.beginDisabled()
		end
		if Gui.button("Keyboard") then
			keyboardControls = true
			controllerControls = false
		end
		if keyboardControls then
			Gui.endDisabled()
		end
		Gui.sameLine()
		if controllerControls then
			Gui.beginDisabled()
		end
		if Gui.button("Controller") then
			controllerControls = true
			keyboardControls = false
		end
		if controllerControls then
			Gui.endDisabled()
		end

		if keyboardControls then
			InputSystem.guiKeyboardInputs(inputOrder.keyboard)
		end

		if controllerControls then
			InputSystem.guiGamepadInputs(inputOrder.gamepad)
		end

		return
	end

	Gui.text("Data Read")
	local readLocationString = ""
	if readLocation > 0 then
		readLocationString = "Replay " .. readLocation
	else
		readLocationString = "Live Game"
	end
	if Gui.beginCombo("Game Data", readLocationString) then
		if Gui.selectable("Live Game", readLocation == 0) then
			readLocation = 0
		end
		for i = 1, #Replay.listLoaded() do
			if Gui.selectable("Replay " .. i, i == readLocation) then
				if i ~= readLocation then
					cachedGamemodesAmount = 0
					selectedArena.instantUpdate = true
				end
				readLocation = i
			end
		end
		Gui.endCombo()
	end
	Gui.setItemTooltip("Start a replay and select it here to practice casting")

	Gui.newLine()
	Gui.separatorText("Camera")
	Gui.indent()

	if Gui.button("Get Closest Arena") then
		setSelectedArena(getClosestArena(camera.position))
	end
	Gui.setItemTooltip("Gets the closest arena | For most accuracy be inside the arena when pressing")

	local arenaName
	if selectedArena then
		arenaName = selectedArena.name
	else
		arenaName = ""
	end
	if Gui.beginCombo("Selected Arena", arenaName) then
		if arenas then
			local _3v3Arenas: { Arena3v3 } = {}
			local _4v4Arenas: { Arena4v4 } = {}
			local DriftblitzArenas: { Driftblitz } = {}
			local ZDriftArenas: { ZDrift } = {}
			for _, arena: CasterArena in arenas do
				if arena.type == ARENA_TYPES.Arena3v3 then
					table.insert(_3v3Arenas, arena :: Arena3v3)
				elseif arena.type == ARENA_TYPES.Arena4v4 then
					table.insert(_4v4Arenas, arena :: Arena4v4)
				elseif arena.type == ARENA_TYPES.Driftblitz then
					table.insert(DriftblitzArenas, arena :: Driftblitz)
				elseif arena.type == ARENA_TYPES.ZDrift then
					table.insert(ZDriftArenas, arena :: ZDrift)
				end
			end

			if Gui.beginCombo("##3v3", "3v3 Arenas...") then
				for _, arena: CasterArena in _3v3Arenas do
					if Gui.selectable(arena.name, selectedArena.name == arena.name) then
						setSelectedArena(arena)
					end
				end
				Gui.endCombo()
			end
			if Gui.beginCombo("##4v4", "4v4 Arenas...") then
				for _, arena: CasterArena in _4v4Arenas do
					if Gui.selectable(arena.name, selectedArena.name == arena.name) then
						setSelectedArena(arena)
					end
				end
				Gui.endCombo()
			end
			if Gui.beginCombo("##Driftblitz", "Driftblitz Arenas...") then
				for _, arena: CasterArena in DriftblitzArenas do
					if Gui.selectable(arena.name, selectedArena.name == arena.name) then
						setSelectedArena(arena)
					end
				end
				Gui.endCombo()
			end
			if Gui.beginCombo("##ZDrift", "ZDrift Arenas...") then
				for _, arena: CasterArena in ZDriftArenas do
					if Gui.selectable(arena.name, selectedArena.name == arena.name) then
						setSelectedArena(arena)
					end
				end
				Gui.endCombo()
			end
		end
		Gui.endCombo()
	end
	Gui.setItemTooltip("The currently selected arena")

	Gui.newLine()
	cameraFOV = Gui.sliderFloat("Field Of View", cameraFOV, 1, 179)
	cameraFOV = math.clamp(cameraFOV, 1, 179)

	cameraPosition = Gui.dragFloat3("Camera Position", cameraPosition, 1, -math.huge, math.huge)
	local newRot = Gui.dragFloat3("Camera Rotation", rotEuler, 1, -180, 180)
	if Gui.isItemActive() then
		gravityChaser = getGravityUp()
		rotEuler = newRot
		camera.rotation = Quat.fromEuler(rotEuler.x, rotEuler.y, rotEuler.z)
	end

	Gui.text(`Get Player Method: {getBallVariant}`)
	Gui.newLine()

	Gui.text("Settings")

	if Gui.collapsingHeader("Controls") then
		Gui.indent()
		positionSmoothing = Gui.sliderFloat("Position Smoothing", positionSmoothing, 0, 1)
		positionSmoothing = math.clamp(positionSmoothing, 0, 1)
		lookSmoothness = Gui.sliderFloat("Rotation Smoothing", lookSmoothness, 0, 1)
		lookSmoothness = math.clamp(lookSmoothness, 0, 1)
		Gui.newLine()
		invertControllerLookHorizontal = Gui.checkbox("Invert Controller Horizontal", invertControllerLookHorizontal)
		invertControllerLookVertical = Gui.checkbox("Invert Controller Vertical", invertControllerLookVertical)
		controllerSensitivity = Gui.sliderFloat("Controller Sensitivity", controllerSensitivity, 0.001, 2)
		controllerSensitivity = math.clamp(controllerSensitivity, 0.001, 2)
		deadzone = Gui.sliderFloat("Controller Deadzone", deadzone, 0, 0.999)
		deadzone = math.clamp(deadzone, 0, 0.999)
		Gui.newLine()
		invertMouseLookHorizontal = Gui.checkbox("Invert Mouse Horizontal", invertMouseLookHorizontal)
		invertMouseLookVertical = Gui.checkbox("Invert Mouse Vertical", invertMouseLookVertical)
		mouseSensitivity = Gui.sliderFloat("Mouse Sensitivity", mouseSensitivity, 0.001, 2)
		mouseSensitivity = math.clamp(mouseSensitivity, 0.001, 2)
		Gui.unindent()
		Gui.newLine()
	end

	if Gui.collapsingHeader("HUD") then
		Gui.indent()
		ballOutline = Gui.checkbox("Ball Outline", ballOutline)
		Gui.setItemTooltip("Toggles an outline around the arena ball that shows it's position through walls.")
		Gui.unindent()
		Gui.newLine()
	end

	if Gui.collapsingHeader("Particles") then
		Gui.indent()
		particleSimSpeed = Gui.sliderFloat("Particle Speed", particleSimSpeed, 0.001, 1)
		particleSimSpeed = math.clamp(particleSimSpeed, 0.001, 1)
		Gui.newLine()
		vibrance = Gui.sliderInt("Color Vibrance", vibrance, 1, 20)
		vibrance = math.clamp(vibrance, 1, 20)
		local homeDefault: Vec3 = Vec3.new(homeTeamDefaultColor.r, homeTeamDefaultColor.g, homeTeamDefaultColor.b)
		homeDefault = Gui.sliderFloat3("Home Default Color", homeDefault, 0, 1)
		homeTeamDefaultColor = {
			r = math.clamp(homeDefault.x, 0, 1),
			g = math.clamp(homeDefault.y, 0, 1),
			b = math.clamp(homeDefault.z, 0, 1),
		}
		Gui.setItemTooltip(
			"The default color for team Home, this gets overwritten by the actual color when a player joins the team"
		)
		local awayDefault: Vec3 = Vec3.new(awayTeamDefaultColor.r, awayTeamDefaultColor.g, awayTeamDefaultColor.b)
		awayDefault = Gui.sliderFloat3("Away Default Color", awayDefault, 0, 1)
		awayTeamDefaultColor = {
			r = math.clamp(awayDefault.x, 0, 1),
			g = math.clamp(awayDefault.y, 0, 1),
			b = math.clamp(awayDefault.z, 0, 1),
		}
		Gui.setItemTooltip(
			"The default color for team Away, this gets overwritten by the actual color when a player joins the team"
		)
		Gui.unindent()
		Gui.newLine()
	end

	if Gui.collapsingHeader("Post Processing") then
		if Gui.button("Apply Preset") then
			postProcessSettings.bloomIntensity = bloomIntensity
			postProcessSettings.bloomThreshold = bloomThreshold
			postProcessSettings.depthOfFieldFstop = depthOfFieldFstop
			postProcessSettings.depthOfFieldFocalDistance = depthOfFieldFocalDistance
			postProcessSettings.depthOfFieldSensorWidth = depthOfFieldSensorWidth
			postProcessSettings.chromaticAberrationIntensity = chromaticAberrationIntensity
			postProcessSettings.motionBlurAmount = motionBlurAmount
			postProcessSettings.vignetteIntensity = vignetteIntensity
			postProcessSettings.autoExposureBias = exposureBias
		end

		Gui.sameLine()

		if Gui.button("Apply Post Processing to Preset") then
			bloomIntensity = postProcessSettings.bloomIntensity
			bloomThreshold = postProcessSettings.bloomThreshold
			depthOfFieldFstop = postProcessSettings.depthOfFieldFstop
			depthOfFieldFocalDistance = postProcessSettings.depthOfFieldFocalDistance
			depthOfFieldSensorWidth = postProcessSettings.depthOfFieldSensorWidth
			chromaticAberrationIntensity = postProcessSettings.chromaticAberrationIntensity
			motionBlurAmount = postProcessSettings.motionBlurAmount
			vignetteIntensity = postProcessSettings.vignetteIntensity
			exposureBias = postProcessSettings.autoExposureBias
		end

		Gui.newLine()
		Gui.text("Preset")
		Gui.separator()

		bloomIntensity = Gui.sliderFloat("Bloom Intensity", bloomIntensity, 0, 10)
		bloomThreshold = Gui.sliderFloat("Bloom Threshold", bloomThreshold, -1, 10)
		depthOfFieldFstop = Gui.sliderFloat("Depth of Field Fstop", depthOfFieldFstop, 0, 22)
		depthOfFieldFocalDistance =
			Gui.dragFloat("Depth of Field Focal Distance", depthOfFieldFocalDistance, 1, 0, math.huge)
		depthOfFieldSensorWidth = Gui.sliderFloat("Depth of Field Sensor Width", depthOfFieldSensorWidth, 0, 200)
		chromaticAberrationIntensity =
			Gui.sliderFloat("Chromatic Aberration Intensity", chromaticAberrationIntensity, 0, 2)
		motionBlurAmount = Gui.sliderFloat("Motion Blur Amount", motionBlurAmount, 0, 1)
		vignetteIntensity = Gui.sliderFloat("Vignette Intenisty", vignetteIntensity, 0, 1)
		exposureBias = Gui.sliderFloat("Exposure Bias", exposureBias, -6, 6)
	end

	if followPlussCamera and Gui.collapsingHeader("POV") then
		Gui.indent()
		Gui.text(`Follow Pluss version: {followPlussVersion}`)

		followFOV = Gui.sliderInt("Field of View", followFOV, 1, 179)
		Gui.setItemTooltip("Sets the FOV for when the camera is in POV mode")
		followFOV = math.clamp(followFOV, 1, 179)

		followPosititonSmoothing = Gui.sliderFloat("Position Smoothing##2", followPosititonSmoothing, 0, 1)
		Gui.setItemTooltip("Sets the smoothing for when the camera is in POV mode")
		followPosititonSmoothing = math.clamp(followPosititonSmoothing, 0, 1)

		Gui.newLine()

		if Gui.beginCombo("Third Person Mode", CAMERA_MODE_NAMES[thirdPersonMode]) then
			for key, value: number in THIRD_PERSON_MODES :: { number } do
				if Gui.selectable(CAMERA_MODE_NAMES[value], thirdPersonMode == value) then
					thirdPersonMode = value
				end
			end
			Gui.endCombo()
		end
		Gui.setItemTooltip("Sets the Camera Mode to be used in 3rd Person POV mode")
		thirdPersonMode = math.clamp(thirdPersonMode, 2, #CAMERA_MODE_NAMES)

		followRadius = Gui.sliderFloat("3rd Person Radius", followRadius, 5, 100)
		Gui.setItemTooltip("The distance from the player when the camera is in 3rd Person POV mode")
		followRadius = math.clamp(followRadius, 5, 100)

		Gui.unindent()
		Gui.newLine()
	end

	if selectedArena and Gui.collapsingHeader("Overviews") then
		Gui.indent()
		Gui.separatorText(`{capitalize(selectedArena.type)} Overviews`)

		for i, overview in overviewOffsets[`_{selectedArena.type}`] do
			if i ~= 1 then
				Gui.separator()
			end
			Gui.text(`Overview #{i}`)
			Gui.dragFloat3(`Position##{i}`, overview.position, 0, -math.huge, math.huge)
			Gui.dragFloat3(`Rotation##{i}`, overview.rotation:euler(), 0, -math.huge, math.huge)

			if Gui.button(`Set Overview To Camera##{i}`) then
				overviewMessage.overviewNumber = i
				overviewMessage.message = updateOverview(i, camera.position, camera.rotation)
			end
			Gui.setItemTooltip(
				"This will overwrite the current overview with your current position and rotation and save it to your settings"
			)

			if overviewMessage.overviewNumber == i then
				Gui.text(overviewMessage.message)
			end
		end

		Gui.unindent()
		Gui.newLine()
	end

	if usingOverlay then
		if Gui.collapsingHeader("Overlay") then
			Gui.indent()
			Gui.text(`Overlay version: {overlayVersion}`)
			if overlayWarning ~= "" then
				Gui.text(overlayWarning)
			end
			if overlayResponse ~= "" then
				Gui.text(overlayResponse)
			end
			sendOverlayInfo = Gui.checkbox("Send Overlay Info", sendOverlayInfo)
			Gui.setItemTooltip("Toggle this off to stop the camera from sending info to the overlay")

			Gui.newLine()

			homeTeam = Gui.inputText("Home Team Name", homeTeam)
			Gui.setItemTooltip(
				"The team name for the home side to be sendt to the overlay for it to display.\nFor correctly setting the team logo please refer to the overlays instructions."
			)
			awayTeam = Gui.inputText("Away Team Name", awayTeam)
			Gui.setItemTooltip(
				"The team name for the away side to be sendt to the overlay for it to display.\nFor correctly setting the team logo please refer to the overlays instructions."
			)
			if Gui.button(`{Icon.Retweet} Swap team names`) then
				local temp = homeTeam
				homeTeam = awayTeam
				awayTeam = temp
				sendMessage(overlayCamera, {
					info = "teamNames",
					value = {
						home = homeTeam,
						away = awayTeam,
					},
				})
				overlayResponse = "Team names are swapped"
			end

			if Gui.button(Icon.Upload .. " Send Teams to Overlay") then
				sendMessage(overlayCamera, {
					info = "teamNames",
					value = {
						home = homeTeam,
						away = awayTeam,
					},
				})
				overlayResponse = "Team names are sendt"
			end

			Gui.newLine()

			if not addRound then
				if Gui.button(Icon.Plus .. "Add Previous Round") then
					addRound = true
				end
				Gui.setItemTooltip("Add info about a round that ended before you started casting")
				if Gui.button(Icon.Trash .. "Remove Previous Round") then
					sendMessage(overlayCamera, {
						info = "rounds",
						value = "remove",
					})
				end
				Gui.setItemTooltip("Remove info about the previous round like it never happened")
			else
				Gui.text("Previous Round Info")
				homePreviousRoundScore = Gui.dragInt("Home Score", homePreviousRoundScore, 1, 0, 100)
				homePreviousRoundScore = math.max(0, homePreviousRoundScore)
				Gui.setItemTooltip("The score for the home team in the pervious round")
				awayPreviousRoundScore = Gui.dragInt("Away Score", awayPreviousRoundScore, 1, 0, 100)
				awayPreviousRoundScore = math.max(0, awayPreviousRoundScore)
				Gui.setItemTooltip("The score for the away team in the pervious round")

				if Gui.button(Icon.Plus .. " Add Round") then
					local round: Round = {
						home = {
							score = homePreviousRoundScore,
						},
						away = {
							score = awayPreviousRoundScore,
						},
					}
					sendMessage(overlayCamera, {
						info = "rounds",
						value = round,
					})
					addRound = false
				end
			end
			Gui.unindent()
		end
	end
	Gui.unindent()

	Gui.newLine()

	if Gui.button(Icon.Save .. " Save Config") then
		config.cameraFOV = cameraFOV
		config.deadzone = deadzone
		config.followFOV = followFOV
		config.followPosititonSmoothing = followPosititonSmoothing
		config.followRadius = followRadius
		config.invertMouseLookHorizontal = invertMouseLookHorizontal
		config.invertMouseLookVertical = invertMouseLookVertical
		config.mouseSensitivity = mouseSensitivity
		config.invertControllerLookHorizontal = invertControllerLookHorizontal
		config.invertControllerLookVertical = invertControllerLookVertical
		config.controllerSensitivity = controllerSensitivity
		config.positionSmoothing = positionSmoothing
		config.lookSmoothness = lookSmoothness
		config.particleSimSpeed = particleSimSpeed
		config.ballOutline = ballOutline
		config.vibrance = vibrance
		config.getBallVariant = getBallVariant
		config.sendOverlayInfo = sendOverlayInfo
		config.thirdPersonMode = thirdPersonMode
		config.homeTeamDefaultColor = {
			r = homeTeamDefaultColor.r,
			g = homeTeamDefaultColor.g,
			b = homeTeamDefaultColor.b,
		}
		config.awayTeamDefaultColor = {
			r = awayTeamDefaultColor.r,
			g = awayTeamDefaultColor.g,
			b = awayTeamDefaultColor.b,
		}
		config.postProcessing = {
			bloomIntensity = bloomIntensity,
			bloomThreshold = bloomThreshold,
			depthOfFieldFstop = depthOfFieldFstop,
			depthOfFieldFocalDistance = depthOfFieldFocalDistance,
			depthOfFieldSensorWidth = depthOfFieldSensorWidth,
			chromaticAberrationIntensity = chromaticAberrationIntensity,
			motionBlurAmount = motionBlurAmount,
			vignetteIntensity = vignetteIntensity,
			exposureBias = exposureBias,
		}
		saveConfig()
	end
	Gui.setItemTooltip("Saves your settings!")

	Gui.newLine()

	if Gui.treeNode("Debug") then
		if Gui.treeNode("Camera") then
			Gui.text(`Camera position smoothing: {camera.positionSmoothing}`)
			Gui.text(`Camera rotation smoothing: {camera.rotationSmoothing}`)
			Gui.text("Camera Rotation: " .. tostring(camera:getSmoothedRotation():euler()))
			Gui.text(`Camera Position: {tostring(camera.position)}`)
			Gui.text("Target Speed Gear: " .. tostring(targetSpeedIndex))
			Gui.text("Current Speed Gear: " .. tostring(currentSpeedIndex))
			Gui.text("Gear Shift Time: " .. tostring(gearShiftTime))
			Gui.text(`Hide nearest head: {camera.hideNearestHead}`)
			Gui.treePop()
		end
		if Gui.treeNode("Arena") then
			local gamemodes = SpectatorGamemodes.listGamemodes()
			Gui.text(`Number of Gamemodes: {#gamemodes}`)
			if Gui.button("Print Gamemode Ids") then
				for _, gamemode in gamemodes do
					print(gamemode:getSlotId())
				end
			end

			tpGamemodeName = Gui.inputText("##gamemodeName", tpGamemodeName)
			Gui.sameLine()
			if Gui.button("TP to Gamemode") then
				local gamemode = getGamemodeByName(tpGamemodeName)
				if gamemode then
					local transform = gamemode.transform
					setGlobalCameraTransform(transform.position, transform.rotation)
				end
			end

			Gui.newLine()

			if arenas and Gui.button("Print Arenas") then
				for _, arena in arenas do
					print(arena.slotId)
				end
			end

			if selectedArena and Gui.button("Set Orientation to Arena") then
				Gui.sameLine()
				cameraPosition = selectedArena.transform.position
				camera.rotation = selectedArena.transform.rotation
				rotEuler = (selectedArena.transform.rotation * gravity.upRotation:inverse()):euler()
			end

			if selectedArena and Gui.button("Print Relative Orientation") then
				local RelativeLocation =
					selectedArena.transform.rotation:rotateVector(camera.position - selectedArena.transform.position)
				local RelativeRotation = camera.rotation * selectedArena.transform.rotation:inverse()
				print(`Relative Position ({selectedArena.name}):`)
				print(RelativeLocation)
				print(`Relative Rotation ({selectedArena.name}):`)
				print(RelativeRotation:euler())
				Gui.sameLine()
			end

			if selectedArena and Gui.button("Print Team Colors Array") then
				Gui.sameLine()
				for i, value in selectedArena.gamemode:getTeamColorsArray() do
					print(i)
					print(tostring(value))
				end
			end

			if selectedArena then
				if ball then
					Gui.text(
						`Home goal ball intersect: {selectedArena.home.goal.box:checkPointIntersect(
							ball.transform.position
						)}`
					)
					Gui.text(
						`Away goal ball intersect: {selectedArena.away.goal.box:checkPointIntersect(
							ball.transform.position
						)}`
					)
				end
				if Gui.button("Print Selected Arena") then
					print(`Selected Arena: {Util.tableToString(selectedArena)}`)
				end
				if Gui.treeNode("Selected Arena Dimensions") then
					selectedArena:GUIChangeDimensions()
					Gui.treePop()
				end

				Gui.text("Home Team: ")
				Gui.indent()
				for i, player in selectedArena.home.players do
					Gui.text(i .. " " .. player.playerName)
				end
				Gui.unindent()
				Gui.text("Away Team: ")
				Gui.indent()
				for i, player in selectedArena.away.players do
					Gui.text(i .. " " .. player.playerName)
				end
				Gui.unindent()

				Gui.text("All Players: ")
				Gui.indent()
				for i, player in selectedArena.players do
					Gui.text(i .. " " .. player.playerName)
				end
				Gui.unindent()
			end
			Gui.treePop()
		end
		if Gui.treeNode("Ball") then
			if Gui.button("Print arena ball json") then
				print(ball:toJson())
			end

			if selectedArena and Gui.button("Print closest ball json") then
				local closestBall = Util.getClosestBall(selectedArena.transform.position, gameData)
				print(closestBall:toJson())
			end

			if Gui.treeNode("Print ball collision info") then
				if Gui.treeNode("Home") then
					if Gui.treeNode("Current##Home") then
						if ballCollisionInfo.home.current then
							Gui.text(`PlayerName: {ballCollisionInfo.home.current.player.playerName}`)
							Gui.text(`Caught Ball Time: {ballCollisionInfo.home.current.contactTime}`)
							Gui.text(`Last Held Position: {ballCollisionInfo.home.current.lastContactPlace}`)
						end
						Gui.treePop()
					end
					if Gui.treeNode("Previous##Home") then
						if ballCollisionInfo.home.previous then
							Gui.text(`PlayerName: {ballCollisionInfo.home.previous.player.playerName}`)
							Gui.text(`Caught Ball Time: {ballCollisionInfo.home.previous.contactTime}`)
							Gui.text(`Last Held Position: {ballCollisionInfo.home.previous.lastContactPlace}`)
						end
						Gui.treePop()
					end
					Gui.treePop()
				end
				if Gui.treeNode("Away") then
					if Gui.treeNode("Current##Away") then
						if ballCollisionInfo.away.current then
							Gui.text(`PlayerName: {ballCollisionInfo.away.current.player.playerName}`)
							Gui.text(`Caught Ball Time: {ballCollisionInfo.away.current.contactTime}`)
							Gui.text(`Last Held Position: {ballCollisionInfo.away.current.lastContactPlace}`)
						end
						Gui.treePop()
					end
					if Gui.treeNode("Previous##Away") then
						if ballCollisionInfo.away.previous then
							Gui.text(`PlayerName: {ballCollisionInfo.away.previous.player.playerName}`)
							Gui.text(`Caught Ball Time: {ballCollisionInfo.away.previous.contactTime}`)
							Gui.text(`Last Held Position: {ballCollisionInfo.away.previous.lastContactPlace}`)
						end
						Gui.treePop()
					end
					Gui.treePop()
				end
				Gui.treePop()
			end
			Gui.treePop()
		end
		if Gui.treeNode("Particles") then
			if Gui.button("Home Scores") then
				DoGoalExplosion(selectedArena.home)
			end

			if Gui.button("Away Scores") then
				DoGoalExplosion(selectedArena.away)
			end

			if Gui.button("Round Starts") then
				GameStartEffect()
			end
			Gui.treePop()
		end
		if Gui.treeNode("Overlay") then
			if Gui.button("Reset All Stats") then
				sendMessage(overlayCamera, {
					info = "stats",
					value = "clear",
				})
			end
			Gui.treePop()
		end
		if Gui.treeNode("Inputs") then
			if Gui.button("Print Pressed Keys") then
				print(InputSystem.pressedInputKeys)
			end
			Gui.text(tostring("Vertical:" .. Vertical))
			Gui.text(tostring("Horizontal: " .. Horizontal))
			Gui.treePop()
		end
		if Gui.treeNode("Gravity") then
			Gui.text(`Gravity Direction: {gravity.upDirection}`)
			Gui.text(`Gravity Rotation: {gravity.upRotation:euler()}`)
			Gui.text(`Gravity Strenght: {gravity.strength}`)
			Gui.treePop()
		end
		if Gui.treeNode("Freecam") then
			if Gui.button("Follow Freecam") then
				debugFreecam = true
				ui:setCamera("anotheraxiom.freecam")
				camera:followCamera(getCameraById("anotheraxiom.freecam"))
			end
			Gui.treePop()
		end
		if Gui.treeNode("Debug Settings") then
			speedGears[#speedGears] = Gui.dragInt("Last Speed Override", speedGears[#speedGears], 1, 0, 5000)
			camera.nearClippingPlane = Gui.dragFloat("Near Clipping Plane", camera.nearClippingPlane, 1, 0, 999999)
			boundingBoxDebug = Gui.checkbox("show boxes", boundingBoxDebug)
			Gui.treePop()
		end

		Gui.treePop()
	end
end

function toggleSmoothing(position: boolean, rotation: boolean)
	if position then
		cameraPositionSmoothing = positionSmoothing
	else
		cameraPositionSmoothing = 0
	end
	if rotation then
		dynamicLookSmoothness = lookSmoothness
	else
		dynamicLookSmoothness = 0
	end
end

function onTransitionBegin(transitionInfo: Transition)
	transitionTime = os.clock()
	firstTransition = transitionTime <= loadTime + 1 -- Margin of 1 second

	if firstTransition then
		cameraPosition = defaultPosition
		camera.rotation = defaultRotation
		rotEuler = defaultRotation:euler()
		rotEuler.x = 0
	else
		cameraPosition = transitionInfo.startPosition
		camera.rotation = transitionInfo.startRotation
		rotEuler = transitionInfo.startRotation:euler()
		rotEuler.x = 0
	end

	alwaysTick = true
	camera.rotationSmoothing = 0
	setHideHead(false)
	camera.showNameTags = true
end

function getClosestArena(targetPosition: Vec3): CasterArena
	local closestArenaDistance = math.huge
	local closestArena = nil

	if not arenas then
		return closestArena
	end

	for _, arena: CasterArena in pairs(arenas) do
		if arena.box:checkPointIntersect(targetPosition) then
			return arena
		end
	end

	-- if the camera is placed in such a way that it is not leveled with any arena we loop again without limiting height
	for _, arena: CasterArena in pairs(arenas) do
		local distance = Util.getDist(targetPosition, arena.transform.position)
		if distance < closestArenaDistance then
			closestArenaDistance = distance
			closestArena = arena
		end
	end

	return closestArena
end

-- Remember: ball radius is 17.5, use an extra 10 for player contact
function getClosestPlayerToBall(maximumDistance: number?): ReplayPlayer?
	local players = selectedArena.players
	local closestPlayerDistance = maximumDistance or math.huge
	local closestPlayer: ReplayPlayer = nil

	for _, player in players do
		local root = player.root
		local headPosition = player.head.position
		local leftHandPosition = root.rotation:rotateVector(player.leftHand.position) + root.position
		local rightHandPosition = root.rotation:rotateVector(player.rightHand.position) + root.position

		local headDistance = Util.getDist(ball.transform.position, headPosition)
		local leftHandDistance = Util.getDist(ball.transform.position, leftHandPosition)
		local rightHandDistance = Util.getDist(ball.transform.position, rightHandPosition)

		local minimumDistance = math.min(headDistance, leftHandDistance, rightHandDistance)

		if minimumDistance < closestPlayerDistance then
			closestPlayerDistance = minimumDistance
			closestPlayer = player
		end
	end

	return closestPlayer
end

function getClosestPlayerToLineOfSight(): ReplayPlayer?
	local players = selectedArena.players
	local cameraForward = camera.rotation:getForwardVector()

	local closestPlayerDistance = math.huge
	local closestPlayer: ReplayPlayer = nil

	for _, player: ReplayPlayer in players do
		local playerRelativePostion = player.root.position - camera.position
		if cameraForward:dot(playerRelativePostion) < 0 then -- continue because player is behind camera
			continue
		end

		local playerDistance = Util.getDist(camera.position, player.root.position)
		local calculatedScreenPosition = camera.position + (cameraForward * playerDistance)
		local lineOfSightDistance = Util.getDist(calculatedScreenPosition, player.root.position)

		if lineOfSightDistance < closestPlayerDistance then
			closestPlayerDistance = lineOfSightDistance
			closestPlayer = player
		end
	end

	return closestPlayer
end

function getPlayer()
	if not followPlussCamera then
		return
	end

	local tryGetPlayer: ReplayPlayer?

	if getBallVariant == GetBallVariant.PlayerBallDistance then
		tryGetPlayer = getClosestPlayerToBall()
	else
		tryGetPlayer = getClosestPlayerToLineOfSight()
	end

	if tryGetPlayer then
		currentPlayer = tryGetPlayer
	else
		return
	end
	local playerIndex = Util.findPlayerInTable(selectedArena.players, tryGetPlayer)
	if playerIndex == nil then
		return
	end
	currentPlayerIndex = playerIndex
	followPlayer()
end

-- particle start
function createParticle(
	position: Vec3,
	rotation: Quat,
	scale: number,
	velocity: Vec3,
	Color: Color,
	variant: string,
	lifespan: number
)
	local variantExists = false
	for _, value in pairs(ParticleVariant) do
		if value == variant then
			variantExists = true
		end
	end

	if not variantExists then
		warn(`Bad Variant: {variant}`)
		return
	end

	-- change vibrancy of the color
	Color = { r = Color.r * vibrance, g = Color.g * vibrance, b = Color.b * vibrance }

	local newParticle: Particle = {
		position = position,
		rotation = rotation,
		scale = scale,
		velocity = velocity,
		Color = Color,
		variant = variant,
		lifespan = lifespan,
		aliveTime = lifespan,
	}
	table.insert(particlesTable, newParticle)
end

function particleAffect()
	if #particlesTable < 1 then
		return
	end

	local replay = Replay.getByIndex(readLocation)

	for i, particle: Particle in ipairs(particlesTable) do
		--LIFE DURATION
		if not replay or replay.isPlaying then
			particle.aliveTime -= 1 * particleSimSpeed
		end

		if particle.aliveTime < 0 then
			table.remove(particlesTable, i)
		end

		if not replay or replay.isPlaying then
			--affect position
			local emberDrag = 0.95
			local gravityMultiplier = 0.8
			if particle.variant == ParticleVariant.Embers or particle.variant == ParticleVariant.Rocket then
				particle.velocity -= (gravity.upDirection * gravityMultiplier * particleSimSpeed)

				--ember drag
				if particle.variant ~= ParticleVariant.Rocket then
					particle.velocity = particle.velocity * (emberDrag ^ particleSimSpeed)
				end
			end

			--collision
			if particle.variant == ParticleVariant.Embers then
				local hit = camera:castRay(particle.position, particle.velocity + particle.position)
				if hit.successful then
					local dotProduct = particle.velocity:dot(hit.normal)
					local reflection = particle.velocity - (hit.normal * (2 * dotProduct))

					particle.velocity = reflection --bounce embers
				end
			end

			--update position
			particle.position += (particle.velocity * particleSimSpeed)

			--affect scale
			if
				particle.variant == ParticleVariant.Embers
				or particle.variant == ParticleVariant.Rings
				or particle.variant == ParticleVariant.GoalRing
			then
				particle.scale *= ((particle.aliveTime / particle.lifespan) ^ particleSimSpeed)
			end
		end

		--remove tiny particles
		if particle.scale < 0.01 then
			table.remove(particlesTable, i)
		end

		--draw parts
		if particle.variant == ParticleVariant.Embers or particle.variant == ParticleVariant.Rocket then
			WorldDraw.drawLine(
				particle.position,
				particle.position - particle.velocity,
				particle.Color.r,
				particle.Color.g,
				particle.Color.b,
				particle.scale * 20,
				0
			)
		end

		--generate rings
		if particle.variant == ParticleVariant.Rings then
			local r = (1 - particle.aliveTime / particle.lifespan) * 6000
			local resolution = 90
			local theta = 2 * math.pi / resolution

			local previousRingOffset = Vec3.new(r * math.cos(0), r * math.sin(0), -40)

			for i = 1, resolution do
				local currentRingOffset = Vec3.new(r * math.cos(i * theta), r * math.sin(i * theta), -40)

				WorldDraw.drawLine(
					particle.rotation:rotateVector(previousRingOffset) + particle.position,
					particle.rotation:rotateVector(currentRingOffset) + particle.position,
					particle.Color.r,
					particle.Color.g,
					particle.Color.b,
					particle.scale * 90,
					0
				)

				previousRingOffset = currentRingOffset
			end

			--generate goal ring
		end
		if particle.variant == ParticleVariant.GoalRing then
			local goalOutline = {
				Vec3.new(0, -248.905, -52.404),
				Vec3.new(0, -248.905, 109.223),
				Vec3.new(0, -188.979, 172.762),
				Vec3.new(0, 188.979, 172.762),
				Vec3.new(0, 248.905, 109.223),
				Vec3.new(0, 248.905, -52.404),
			}
			for i = 1, 5 do
				WorldDraw.drawLine(
					particle.rotation:rotateVector(goalOutline[i]) + particle.position,
					particle.rotation:rotateVector(goalOutline[i + 1]) + particle.position,
					particle.Color.r,
					particle.Color.g,
					particle.Color.b,
					particle.scale * 15,
					0
				)
			end
		end
	end
end
-- particle end

--effects start
function GoalExplosionEffect(goalPosition: Vec3, goalRotation: Quat, particleColor: Color)
	for i = 1, 300 do
		local velocityVector = Vec3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
		createParticle(
			goalPosition,
			Quat.identity,
			0.3,
			velocityVector,
			particleColor,
			ParticleVariant.Embers,
			math.random(800, 1300)
		)
	end
	createParticle(goalPosition, goalRotation, 0.9, Vec3.zeroVector, particleColor, ParticleVariant.Rings, 150)

	--rings
	createParticle(goalPosition, goalRotation, 1, Vec3.zeroVector, particleColor, ParticleVariant.Rings, 200)
	createParticle(goalPosition, goalRotation, 1, Vec3.zeroVector, particleColor, ParticleVariant.Rings, 400)

	if selectedArena.type == ARENA_TYPES.Driftblitz or selectedArena.type == ARENA_TYPES.ZDrift then
		return
	end

	--goal outline
	local goalSpeed = 20
	for i = 1, 3 do
		createParticle(
			goalPosition,
			goalRotation,
			1,
			goalRotation:getForwardVector() * goalSpeed,
			particleColor,
			ParticleVariant.GoalRing,
			400
		)
		goalSpeed /= 2
	end
end

function GameStartEffect()
	local particlePosition = selectedArena.centerBox.position

	local colourAverage = {
		r = (homeTeamPrimaryColor.r + awayTeamPrimaryColor.r) / 2,
		g = (homeTeamPrimaryColor.g + awayTeamPrimaryColor.g) / 2,
		b = (homeTeamPrimaryColor.b + awayTeamPrimaryColor.b) / 2,
	}
	createParticle(
		particlePosition,
		selectedArena.transform.rotation,
		0.9,
		Vec3.zeroVector,
		colourAverage,
		ParticleVariant.Rings,
		150
	)
	createParticle(
		particlePosition,
		selectedArena.transform.rotation,
		0.7,
		selectedArena.transform.rotation:rotateVector(Vec3.new(0, 0, 10)),
		colourAverage,
		ParticleVariant.Rings,
		600
	)
	createParticle(
		particlePosition,
		selectedArena.transform.rotation,
		0.7,
		selectedArena.transform.rotation:rotateVector(Vec3.new(0, 0, 2)),
		colourAverage,
		ParticleVariant.Rings,
		400
	)
	local colourPallette = { homeTeamPrimaryColor, awayTeamPrimaryColor }
	for i = 1, 300 do
		local emberVeloctiy = Vec3.new(math.random(-30, 30), math.random(-30, 30), math.random(20, 80))
		createParticle(
			particlePosition,
			selectedArena.transform.rotation,
			0.5,
			selectedArena.transform.rotation:rotateVector(emberVeloctiy),
			colourPallette[math.random(1, 2)],
			ParticleVariant.Embers,
			math.random(800, 1300)
		)
	end
end
--effects end

function stopFollow()
	toggleSmoothing(true, true)
	ui:setCamera("")
	playerFollow = false
	cameraPosition = followPlussCamera:getSmoothedPosition()
	setGlobalCameraRotation(followPlussCamera:getSmoothedRotation())
	rotEuler.x = 0
	currentPlayer = nil
	camera.fieldOfView = cameraFOV
	setHideHead(false)
end

function readInput()
	readOtherInputs()
	readMoveInput()
	readUpInput()
end

function readOtherInputs()
	if InputSystem.keyToBeRebinded.key ~= "" then
		-- don't read inputs on rebind
		return
	end

	cameraFOV -= Input.getAnalog(mouseWheelAxis) * 10

	if
		InputSystem.getCustomKey(InputSystem.inputs.gamepad.zoomIn).held
		and InputSystem.getCustomKey(InputSystem.inputs.gamepad.zoomOut).held
	then
		cameraFOV += 0
	elseif InputSystem.getCustomKey(InputSystem.inputs.gamepad.zoomIn).held then
		cameraFOV -= 50 * deltaTime
	elseif InputSystem.getCustomKey(InputSystem.inputs.gamepad.zoomOut).held then
		cameraFOV += 50 * deltaTime
	end

	cameraFOV = math.clamp(cameraFOV, 1, 179)

	if
		InputSystem.getCustomKey(InputSystem.inputs.keyboard.resetFOV).down
		or InputSystem.getCustomKey(InputSystem.inputs.gamepad.resetFOV).down
	then
		cameraFOV = config.cameraFOV
	end

	if
		InputSystem.getCustomKey(InputSystem.inputs.keyboard.speedUp).down
		or InputSystem.getCustomKey(InputSystem.inputs.gamepad.speedUp).down
	then
		if targetSpeedIndex == #speedGears - 2 then
			speedLastGearBuffer = true
		end
		targetSpeedIndex = math.min(targetSpeedIndex + 1, #speedGears - 1)
	end
	if
		InputSystem.getCustomKey(InputSystem.inputs.keyboard.speedDown).down
		or InputSystem.getCustomKey(InputSystem.inputs.gamepad.speedDown).down
	then
		targetSpeedIndex = math.max(targetSpeedIndex - 1, 1)
	end

	if
		InputSystem.getCustomKey(InputSystem.inputs.keyboard.speedUp).up
		or InputSystem.getCustomKey(InputSystem.inputs.gamepad.speedUp).up
	then
		if speedLastGearBuffer then
			speedLastGearBuffer = false
		end

		if targetSpeedIndex == #speedGears then
			targetSpeedIndex -= 1
		end
	end

	if
		(
			InputSystem.getCustomKey(InputSystem.inputs.keyboard.speedUp).held
			or InputSystem.getCustomKey(InputSystem.inputs.gamepad.speedUp).held
		)
		and targetSpeedIndex >= #speedGears - 1
		and not speedLastGearBuffer
	then
		targetSpeedIndex = #speedGears
	end

	if selectedArena == nil then
		return
	end

	if
		InputSystem.getCustomKey(InputSystem.inputs.keyboard.getClosestArena).down
		or InputSystem.getCustomKey(InputSystem.inputs.gamepad.getClosestArena).down
	then
		setSelectedArena(getClosestArena(camera.position))
	end

	if
		InputSystem.getCustomKey(InputSystem.inputs.keyboard.clearOverlayInfo).down
		or InputSystem.getCustomKey(InputSystem.inputs.gamepad.clearOverlayInfo).down
	then
		sendMessage(overlayCamera, {
			info = "stats",
			value = "clear",
		})
	end

	if
		ball
		and (
			InputSystem.getCustomKey(InputSystem.inputs.keyboard.overview1).down
			or InputSystem.getCustomKey(InputSystem.inputs.gamepad.overview1).down
		)
	then
		if playerFollow then
			stopFollow()
		end
		toggleSmoothing(false, false)
		if selectedArena:isPointOnHomeSide(ball.transform.position) then
			cameraPosition = selectedArena.home.data.overview[1].position
			setGlobalCameraRotation(selectedArena.home.data.overview[1].rotation)
		else
			cameraPosition = selectedArena.away.data.overview[1].position
			setGlobalCameraRotation(selectedArena.away.data.overview[1].rotation)
		end
	end
	if
		ball
		and (
			InputSystem.getCustomKey(InputSystem.inputs.keyboard.overview2).down
			or InputSystem.getCustomKey(InputSystem.inputs.gamepad.overview2).down
		)
	then
		if playerFollow then
			stopFollow()
		end
		toggleSmoothing(false, false)
		if selectedArena:isPointOnHomeSide(ball.transform.position) then
			cameraPosition = selectedArena.home.data.overview[2].position
			setGlobalCameraRotation(selectedArena.home.data.overview[2].rotation)
		else
			cameraPosition = selectedArena.away.data.overview[2].position
			setGlobalCameraRotation(selectedArena.away.data.overview[2].rotation)
		end
	end
	if
		ball
		and (
			InputSystem.getCustomKey(InputSystem.inputs.keyboard.overview3).down
			or InputSystem.getCustomKey(InputSystem.inputs.gamepad.overview3).down
		)
	then
		if playerFollow then
			stopFollow()
		end
		toggleSmoothing(false, false)
		if selectedArena:isPointOnHomeSide(ball.transform.position) then
			cameraPosition = selectedArena.home.data.overview[3].position
			setGlobalCameraRotation(selectedArena.home.data.overview[3].rotation)
		else
			cameraPosition = selectedArena.away.data.overview[3].position
			setGlobalCameraRotation(selectedArena.away.data.overview[3].rotation)
		end
	end

	if
		InputSystem.getCustomKey(InputSystem.inputs.keyboard.lineOfSight).down
		or InputSystem.getCustomKey(InputSystem.inputs.gamepad.lineOfSight).down
	then
		getBallVariant = GetBallVariant.LineOfSight
	end

	if
		InputSystem.getCustomKey(InputSystem.inputs.keyboard.playerBallDistance).down
		or InputSystem.getCustomKey(InputSystem.inputs.gamepad.playerBallDistance).down
	then
		getBallVariant = GetBallVariant.PlayerBallDistance
	end

	if
		InputSystem.getCustomKey(InputSystem.inputs.keyboard.thirdPerson).down
		or InputSystem.getCustomKey(InputSystem.inputs.gamepad.thirdPerson).down
	then
		if currentPlayer == nil or cameraMode == thirdPersonMode then
			cameraMode = thirdPersonMode
			getPlayer()
		else
			cameraMode = thirdPersonMode
			followPlayer()
		end
	end

	if
		InputSystem.getCustomKey(InputSystem.inputs.keyboard.firstPerson).down
		or InputSystem.getCustomKey(InputSystem.inputs.gamepad.firstPerson).down
	then
		if currentPlayer == nil or cameraMode == CameraMode.FirstPerson then
			cameraMode = CameraMode.FirstPerson
			getPlayer()
		else
			cameraMode = CameraMode.FirstPerson
			followPlayer()
		end
	end

	if
		InputSystem.getCustomKey(InputSystem.inputs.keyboard.freeCam).down
		or InputSystem.getCustomKey(InputSystem.inputs.gamepad.freeCam).down
	then
		if playerFollow then
			stopFollow()
		end
	end

	if
		playerFollow
		and (
			InputSystem.getCustomKey(InputSystem.inputs.gamepad.previousPlayer).down
			or InputSystem.getCustomKey(InputSystem.inputs.keyboard.previousPlayer).down
		)
	then
		currentPlayerIndex -= 1
		if currentPlayerIndex < 1 then
			currentPlayerIndex = #selectedArena.players
		end
		currentPlayer = selectedArena.players[currentPlayerIndex]
		followPlayer()
	end
	if
		playerFollow
		and (
			InputSystem.getCustomKey(InputSystem.inputs.gamepad.nextPlayer).down
			or InputSystem.getCustomKey(InputSystem.inputs.keyboard.nextPlayer).down
		)
	then
		currentPlayerIndex += 1
		if currentPlayerIndex > #selectedArena.players then
			currentPlayerIndex = 1
		end
		currentPlayer = selectedArena.players[currentPlayerIndex]
		followPlayer()
	end
end

function readMoveInput()
	if InputSystem.keyToBeRebinded.key ~= "" then
		-- don't read inputs on rebind
		return
	end

	local input = math.abs(InputSystem.getCustomAnalog(InputSystem.inputs.gamepad.moveY))
		+ math.abs(InputSystem.getCustomAnalog(InputSystem.inputs.gamepad.moveX))
	if input > deadzone then
		Vertical = InputSystem.getCustomAnalog(InputSystem.inputs.gamepad.moveY)
		Horizontal = InputSystem.getCustomAnalog(InputSystem.inputs.gamepad.moveX)
		return
	else
		if
			InputSystem.getCustomKey(InputSystem.inputs.keyboard.forwards).held
			and InputSystem.getCustomKey(InputSystem.inputs.keyboard.backwards).held
		then
			Vertical = 0
		elseif InputSystem.getCustomKey(InputSystem.inputs.keyboard.forwards).held then
			Vertical = 1
		elseif InputSystem.getCustomKey(InputSystem.inputs.keyboard.backwards).held then
			Vertical = -1
		else
			Vertical = 0
		end

		if
			InputSystem.getCustomKey(InputSystem.inputs.keyboard.right).held
			and InputSystem.getCustomKey(InputSystem.inputs.keyboard.left).held
		then
			Horizontal = 0
		elseif InputSystem.getCustomKey(InputSystem.inputs.keyboard.right).held then
			Horizontal = 1
		elseif InputSystem.getCustomKey(InputSystem.inputs.keyboard.left).held then
			Horizontal = -1
		else
			Horizontal = 0
		end
	end
end

function readUpInput()
	if InputSystem.keyToBeRebinded.key ~= "" then
		-- don't read inputs on rebind
		return
	end

	if
		InputSystem.getCustomKey(InputSystem.inputs.gamepad.down).held
		or InputSystem.getCustomKey(InputSystem.inputs.gamepad.up).held
	then
		if
			InputSystem.getCustomKey(InputSystem.inputs.gamepad.down).held
			and InputSystem.getCustomKey(InputSystem.inputs.gamepad.up).held
		then
			Up = 0
		elseif InputSystem.getCustomKey(InputSystem.inputs.gamepad.up).held then
			Up = 1
		elseif InputSystem.getCustomKey(InputSystem.inputs.gamepad.down).held then
			Up = -1
		else
			Up = 0
		end
		return
	end

	if
		InputSystem.getCustomKey(InputSystem.inputs.keyboard.down).held
		and InputSystem.getCustomKey(InputSystem.inputs.keyboard.up).held
	then
		Up = 0
	elseif InputSystem.getCustomKey(InputSystem.inputs.keyboard.up).held then
		Up = 1
	elseif InputSystem.getCustomKey(InputSystem.inputs.keyboard.down).held then
		Up = -1
	else
		Up = 0
	end
end

function moveCamera()
	local forwardDirection = camera.rotation:getForwardVector()
	local rightDirection = camera.rotation:getRightVector()
	local upDirection = camera.rotation:getUpVector()

	if currentSpeedIndex <= targetSpeedIndex then
		gearShiftTime = math.min(gearShiftTime + deltaTime, gearShiftTimeRequired)
		if gearShiftTime >= gearShiftTimeRequired and currentSpeedIndex < targetSpeedIndex then
			currentSpeedIndex += 1
			gearShiftTime = 0
		end
	elseif currentSpeedIndex > targetSpeedIndex then
		gearShiftTime = math.max(gearShiftTime - deltaTime, 0)
		if gearShiftTime <= 0 then
			currentSpeedIndex -= 1
			gearShiftTime = gearShiftTimeRequired
		end
	end

	local speedMultiplier = Util.lerp(
		speedGears[math.max(currentSpeedIndex - 1, 1)],
		speedGears[currentSpeedIndex],
		gearShiftTime / gearShiftTimeRequired
	)

	local forwardMovement = forwardDirection * Vertical * speedMultiplier * 100 * deltaTime
	local sidewaysMovement = rightDirection * Horizontal * speedMultiplier * 100 * deltaTime
	local upwardsMovement = upDirection * Up * speedMultiplier * 50 * deltaTime

	cameraVelocity = (forwardMovement + sidewaysMovement + upwardsMovement)

	cameraPosition += cameraVelocity

	camera.position = Vec3.lerp(camera.position, cameraPosition, deltaTime / (cameraPositionSmoothing + deltaTime))
end

function rotateCamera()
	if InputSystem.keyToBeRebinded.key ~= "" then
		-- don't read input on rebind
		return
	end

	local mouse = Input.getMouseDelta()
	local adjustedLookSmoothness = 1 - (1 - dynamicLookSmoothness) ^ 3

	if invertMouseLookHorizontal then
		mouse.x = -mouse.x
	end

	if invertMouseLookVertical then
		mouse.y = -mouse.y
	end

	-- Keyboard
	if InputSystem.getCustomKey(InputSystem.inputs.keyboard.lookAround).held then
		turnVelocity = Vec2.new(mouse.x, mouse.y) * 10
		rotDelta += Vec3.new(0, turnVelocity.y, turnVelocity.x) * mouseSensitivity
	end

	-- Gamepad
	turnVelocity = Vec2.new(
		InputSystem.getCustomAnalog(InputSystem.inputs.gamepad.lookX),
		InputSystem.getCustomAnalog(InputSystem.inputs.gamepad.lookY)
	) * controllerSensitivity * 2

	if invertControllerLookHorizontal then
		turnVelocity.x = -turnVelocity.x
	end

	if invertControllerLookVertical then
		turnVelocity.y = -turnVelocity.y
	end

	rotDelta += Vec3.new(0, turnVelocity.y, turnVelocity.x)

	local nextLookDiff = rotDelta * math.min((1 - adjustedLookSmoothness) * deltaTime * 60, 1)

	local upRotation = getGravityUp()
	gravityChaser = Quat.slerp(gravityChaser, upRotation, math.min((1 - adjustedLookSmoothness) * deltaTime * 60, 1))

	rotEuler += nextLookDiff
	rotDelta -= nextLookDiff

	rotEuler.y = math.clamp(rotEuler.y, -89.99, 89.99)
	camera.rotation = gravityChaser * Quat.fromEuler(rotEuler.x, rotEuler.y, rotEuler.z)
end

function followPlayer()
	playerFollow = true
	local message: FollowPlusData = {
		readLocation = readLocation,
		showNameTags = true,
		muteSelf = false,
		targetPlayer = currentPlayer,
		cameraFOV = followFOV,
		cameraMode = cameraMode,
		radius = followRadius,
		threshold = 5,
		positionSmoothing = followPosititonSmoothing,
		cameraPositionOffset = Vec3.zeroVector,
		cameraRotationOffset = Quat.identity,
		gestureControls = false,
		autoBall = false,
		autoGoalCam = false,
		showQuests = false,
	}
	toggleSmoothing(false, false)
	sendMessage(followPlussCamera, message)
	ui:setCamera(followPlussId)
end

function DoGoalExplosion(team: ArenaTeam)
	local goalExplosionPosition: Vec3
	local goalExplosionColor: Color

	if selectedArena.type == ARENA_TYPES.Driftblitz or selectedArena.type == ARENA_TYPES.ZDrift then
		goalExplosionPosition = ball.transform.position
	elseif team.teamIndex == Util.TeamIndex.HomeTeam then
		goalExplosionPosition = selectedArena.away.goal.position + Vec3.new(0, 0, -60)
	elseif team.teamIndex == Util.TeamIndex.AwayTeam then
		goalExplosionPosition = selectedArena.home.goal.position + Vec3.new(0, 0, -60)
	end

	if team.teamIndex == Util.TeamIndex.HomeTeam then
		goalExplosionColor = homeTeamPrimaryColor
	else
		goalExplosionColor = awayTeamPrimaryColor
	end

	GoalExplosionEffect(goalExplosionPosition, team.goal.rotation * Quat.fromEuler(0, 0, 180), goalExplosionColor)
end

function checkBallContact()
	local contactPlayer: ReplayPlayer? = getClosestPlayerToBall(30)
	if contactPlayer == nil then
		return
	end

	local contactTime = os.clock()

	if contactPlayer.teamIndex == Util.TeamIndex.HomeTeam then
		if
			ballCollisionInfo.home.current
			and contactPlayer.playerId == ballCollisionInfo.home.current.player.playerId
		then
			ballCollisionInfo.home.current.lastContactPlace = ball.transform.position
			return
		end
		ballCollisionInfo.home.previous = ballCollisionInfo.home.current
		ballCollisionInfo.home.current = {
			lastContactPlace = ball.transform.position,
			contactTime = contactTime,
			player = contactPlayer,
		}
	elseif contactPlayer.teamIndex == Util.TeamIndex.AwayTeam then
		if
			ballCollisionInfo.away.current
			and contactPlayer.playerId == ballCollisionInfo.away.current.player.playerId
		then
			ballCollisionInfo.away.current.lastContactPlace = ball.transform.position
			return
		end
		ballCollisionInfo.away.previous = ballCollisionInfo.away.current
		ballCollisionInfo.away.current = {
			lastContactPlace = ball.transform.position,
			contactTime = contactTime,
			player = contactPlayer,
		}
	end
end

function getLastPlayerWithBall(): ReplayPlayer?
	local homeTouchTime: number = 0
	local homePlayer: ReplayPlayer
	local awayTouchTime: number = 0
	local awayPlayer: ReplayPlayer
	if ballCollisionInfo.home.current then
		homeTouchTime = ballCollisionInfo.home.current.contactTime
		homePlayer = ballCollisionInfo.home.current.player
	end

	if ballCollisionInfo.away.current then
		awayTouchTime = ballCollisionInfo.away.current.contactTime
		awayPlayer = ballCollisionInfo.away.current.player
	end

	if homeTouchTime > awayTouchTime then
		return homePlayer
	elseif awayTouchTime > homeTouchTime then
		return awayPlayer
	else
		return nil
	end
end

function getPossessionTeam(): string?
	if ballCollisionInfo.home.current == nil and ballCollisionInfo.away.current == nil then
		return nil
	end

	if ballCollisionInfo.home.current == nil then
		return "away"
	end

	if ballCollisionInfo.away.current == nil then
		return "home"
	end

	if ballCollisionInfo.home.current.contactTime > ballCollisionInfo.away.current.contactTime then
		return "home"
	else
		return "away"
	end
end

function getAssistPlayer(team: string): ReplayPlayer?
	local possessionTeam = ballCollisionInfo[team]

	if possessionTeam.current == nil or possessionTeam.previous == nil then
		return nil
	end

	if os.clock() - possessionTeam.current.contactTime < maximumTimeSincePass then
		return possessionTeam.previous.player
	else
		return nil
	end
end

function checkForGoalPotential(): boolean
	local successfulPotential = false
	local possesionTeamString: string? = getPossessionTeam()

	if not possesionTeamString then
		return successfulPotential
	end

	local possessionTeam = ballCollisionInfo[possesionTeamString]

	if possessionTeam.current == nil then
		return successfulPotential
	end

	if homeGoalPotentialEnter and not previousHomeGoalPotentialEnter then
		if possessionTeam.current.player.teamIndex == Util.TeamIndex.AwayTeam then
			goalPlayer = possessionTeam.current.player
			successfulPotential = true
		end
	end

	if awayGoalPotentialEnter and not previousAwayGoalPotentialEnter then
		if possessionTeam.current.player.teamIndex == Util.TeamIndex.HomeTeam then
			goalPlayer = possessionTeam.current.player
			successfulPotential = true
		end
	end

	return successfulPotential
end

function checkForSave(goal: { team: string, dist: number }): boolean
	local goalie = getClosestPlayerToBall(60)
	local lastPlayerWithBall = getLastPlayerWithBall()

	local successfulSave = false

	if goal.team == "home" and lastPlayerWithBall and lastPlayerWithBall.teamIndex == Util.TeamIndex.AwayTeam then
		if
			not homeGoalPotentialEnter
			and previousHomeGoalPotentialEnter
			and goal.dist <= 600
			and goalie
			and goalie.teamIndex == Util.TeamIndex.HomeTeam
		then
			successfulSave = true

			resetPlayersWithBall()

			sendSafeMessage(overlayCamera, {
				info = "stats",
				value = {
					team = "home",
					stat = "saves",
					player = goalie.playerName,
				},
			})
		end
	elseif goal.team == "away" and lastPlayerWithBall and lastPlayerWithBall.teamIndex == Util.TeamIndex.HomeTeam then
		if
			not awayGoalPotentialEnter
			and previousAwayGoalPotentialEnter
			and goal.dist <= 600
			and goalie
			and goalie.teamIndex == Util.TeamIndex.AwayTeam
		then
			successfulSave = true

			resetPlayersWithBall()

			sendSafeMessage(overlayCamera, {
				info = "stats",
				value = {
					team = "away",
					stat = "saves",
					player = goalie.playerName,
				},
			})
		end
	end

	return successfulSave
end

function earlyStatChangeReturn(ballExit: boolean)
	if ballExit then
		homeGoalPotentialEnter = false
		awayGoalPotentialEnter = false
	end

	previousHomeGoalPotentialEnter = homeGoalPotentialEnter
	previousAwayGoalPotentialEnter = awayGoalPotentialEnter
end

function checkPotentialStatChange(homeGoalBox: BoxType, awayGoalBox: BoxType)
	if selectedArena.isGracePeriod then
		earlyStatChangeReturn(true)
		return
	end

	local ballToHomeGoalDist = Util.getDist(ball.transform.position, homeGoalBox.position)
	local ballToAwayGoalDist = Util.getDist(ball.transform.position, awayGoalBox.position)
	local closestGoal = {}

	if ballToHomeGoalDist < ballToAwayGoalDist then
		closestGoal.team = "home"
		closestGoal.dist = ballToHomeGoalDist
	else
		closestGoal.team = "away"
		closestGoal.dist = ballToAwayGoalDist
	end

	if closestGoal.team == "home" then
		local ballHomePotentialPosition = ball.transform.position + (ball.velocity:normalize() * ballToHomeGoalDist)
		local homeHit = camera:castRay(ball.transform.position, ballHomePotentialPosition)

		if homeHit.successful then
			local velocityDotNormal = ball.velocity:dot(homeHit.normal)
			local reflectedVelocityNormalized = (ball.velocity - (homeHit.normal * (2 * velocityDotNormal))):normalize()
			local distanceLeft = Util.getDist(homeHit.position, homeGoalBox.position)

			ballHomePotentialPosition = homeHit.position + (reflectedVelocityNormalized * distanceLeft)
		end

		if
			homeGoalBox:checkPointIntersect(ballHomePotentialPosition)
			or homeGoalBox:checkPointIntersect(homeHit.position)
		then
			homeGoalPotentialEnter = true
		else
			homeGoalPotentialEnter = false
		end
		awayGoalPotentialEnter = false
	else
		local ballAwayPotentialPosition = ball.transform.position + (ball.velocity:normalize() * ballToAwayGoalDist)

		local awayHit = camera:castRay(ball.transform.position, ballAwayPotentialPosition)

		if awayHit.successful then
			local velocityDotNormal = ball.velocity:dot(awayHit.normal)
			local reflectedVelocityNormalized = (ball.velocity - (awayHit.normal * (2 * velocityDotNormal))):normalize()
			local distanceLeft = Util.getDist(awayHit.position, awayGoalBox.position)

			ballAwayPotentialPosition = awayHit.position + (reflectedVelocityNormalized * distanceLeft)
		end

		if
			awayGoalBox:checkPointIntersect(ballAwayPotentialPosition)
			or awayGoalBox:checkPointIntersect(awayHit.position)
		then
			awayGoalPotentialEnter = true
		else
			awayGoalPotentialEnter = false
		end
		homeGoalPotentialEnter = false
	end

	checkBallContact()

	if checkForGoalPotential() then
		earlyStatChangeReturn(false)
		return
	end

	if checkForSave(closestGoal) then
		earlyStatChangeReturn(false)
		return
	end

	previousHomeGoalPotentialEnter = homeGoalPotentialEnter
	previousAwayGoalPotentialEnter = awayGoalPotentialEnter
end

function goalScoreCheck()
	local homeGoalBox: BoxType = selectedArena.home.goal.box
	local awayGoalBox: BoxType = selectedArena.away.goal.box

	checkPotentialStatChange(homeGoalBox, awayGoalBox)

	-- the ball has newely scored
	if selectedArena.away.scoreIncrease then
		DoGoalExplosion(selectedArena.away)

		local shooterName = ""
		local assistName = ""
		local shotFrom: Vec3

		if ballCollisionInfo.away.current then
			shooterName = ballCollisionInfo.away.current.player.playerName
			shotFrom = ballCollisionInfo.away.current.lastContactPlace
		end

		local shotDistance: number = 0
		if shotFrom then
			shotDistance = Util.getDist(shotFrom, ball.transform.position) / 100
		end

		local assistPlayer = getAssistPlayer("away")

		if assistPlayer then
			assistName = assistPlayer.playerName
		end

		sendSafeMessage(overlayCamera, {
			info = "shot",
			value = {
				shooter = shooterName,
				assister = assistName,
				team = "away",
				shotSpeed = ball.velocity:length() / 100,
				shotDistanceMeters = shotDistance,
			},
		})

		if goalPlayer then
			resetPlayersWithBall()

			sendSafeMessage(overlayCamera, {
				info = "stats",
				value = {
					team = "away",
					stat = "goals",
					player = goalPlayer.playerName,
				},
			})

			if assistPlayer then
				sendSafeMessage(overlayCamera, {
					info = "stats",
					value = {
						team = "away",
						stat = "assists",
						player = assistPlayer.playerName,
					},
				})

				assistPlayer = nil
			end
		end
	end

	if selectedArena.home.scoreIncrease then
		DoGoalExplosion(selectedArena.home)

		local shooterName = ""
		local assistName = ""
		local shotFrom: Vec3

		if ballCollisionInfo.home.current then
			shooterName = ballCollisionInfo.home.current.player.playerName
			shotFrom = ballCollisionInfo.home.current.lastContactPlace
		end

		local shotDistance: number = 0
		if shotFrom then
			shotDistance = Util.getDist(shotFrom, ball.transform.position) / 100
		end

		local assistPlayer = getAssistPlayer("home")

		if assistPlayer then
			assistName = assistPlayer.playerName
		end

		sendSafeMessage(overlayCamera, {
			info = "shot",
			value = {
				shooter = shooterName, -- use lastPlayerWithBall instead of goalPlayer incase it is a self goal
				assister = assistName,
				team = "home",
				shotSpeed = ball.velocity:length() / 100,
				shotDistanceMeters = shotDistance,
			},
		})

		if goalPlayer then
			resetPlayersWithBall()

			sendSafeMessage(overlayCamera, {
				info = "stats",
				value = {
					team = "home",
					stat = "goals",
					player = goalPlayer.playerName,
				},
			})
			if assistPlayer then
				sendSafeMessage(overlayCamera, {
					info = "stats",
					value = {
						team = "home",
						stat = "assists",
						player = assistPlayer.playerName,
					},
				})
				assistPlayer = nil
			end
		end
	end
end

function ballInCenterCheck()
	local isKickoff = selectedArena.isKickoff
	if isKickoff and selectedArena.actionTimerSeconds == 0 then
		resetPlayersWithBall()
		GameStartEffect()
		selectedArena.isKickoff = false
	end
end

function getTeamColors()
	if #selectedArena.home.players > 0 then
		local firstPlayer = selectedArena.home.players[1]
		local playerJson = firstPlayer:toJson()
		homeTeamPrimaryColor = Util.extractPrimaryPlayerColor(playerJson)
	else
		homeTeamPrimaryColor = homeTeamDefaultColor
	end

	if #selectedArena.away.players > 0 then
		local firstPlayer = selectedArena.away.players[1]
		local playerJson = firstPlayer:toJson()
		awayTeamPrimaryColor = Util.extractPrimaryPlayerColor(playerJson)
	else
		awayTeamPrimaryColor = awayTeamDefaultColor
	end
end

function drawBallOutline()
	if not ballOutline then
		return
	end

	ui:tick()

	local ballHUDPosition: Vec2 = ui:worldToHUD(ball.transform.position)

	if ballHUDPosition == Vec2.zeroVector then
		return
	end

	local ballRadius = 17.5
	local segments = 20
	local radius = ui:getApparentLength(ballRadius, ball.transform.position)
	local thickness = math.min(ui.depth / 10, radius / 100)

	local angleStep = (2 * math.pi) / segments
	local prevPoint = nil

	for i = 0, segments do
		local angle = i * angleStep

		local x = radius * math.cos(angle)
		local y = radius * math.sin(angle)

		local point: Vec2 = ballHUDPosition + Vec2.new(x, y)

		if prevPoint then
			ui:drawLine(prevPoint, point, Vec3.oneVector, thickness, 0)
		end

		prevPoint = point
	end
end

function tick(dt)
	if not camera.isActive and not camera.isFollowed then
		alwaysTick = nil
		onExit()
		return
	end

	WorldDraw.clear()

	if cachedGamemodesAmount ~= #SpectatorGamemodes.listGamemodeIds() then
		arenas = getArenas()
		if Util.getDictSize(arenas) > 0 then
			setSelectedArena(Util.getDictIndex(arenas, 1))
		end
		cachedGamemodesAmount = #SpectatorGamemodes.listGamemodeIds()
	end

	InputSystem.readInputStart()

	deltaTime = dt
	camera.fieldOfView = cameraFOV

	gameData = Util.getReplayFrameFromIndex(readLocation)

	if selectedArena == nil then
		toggleSmoothing(true, true)
		readInput()

		moveCamera()
		rotateCamera()
		InputSystem.readInputEnd()
		return
	end

	selectedArena:tick()
	ball = selectedArena.ball

	getTeamColors()

	if #gameData.players < 1 and playerFollow then
		stopFollow()
	end

	if ball and debugFreecam then
		drawBallOutline()
		return
	end

	if playerFollow then
		followPlussTick(dt, true)
		Util.followCamera(followPlussId)
		readOtherInputs()
	else
		toggleSmoothing(true, true)
		readInput()

		moveCamera()
		rotateCamera()
		drawBallOutline()
	end

	particleAffect()
	ballInCenterCheck()
	if ball then
		goalScoreCheck()
	end

	InputSystem.readInputEnd()

	if arenas and boundingBoxDebug then
		for _, arena in arenas do
			arena.box:renderFaces(LinearColor.new(1, 0, 1, 0.5))
			arena.centerBox:render(0, 1, 0)
			arena.home.goal.box:render(1, 0, 0)
			arena.away.goal.box:render(0, 0, 1)
		end
	end
end

function onExit()
	if playerFollow then
		stopFollow()
	end
end
