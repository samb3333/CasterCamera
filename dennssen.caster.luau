--!strict

local version: string = "1.4.0"
metadata = {
	name = "Caster",
	description = "The Caster camera is a Driftball focused caster tool that let's you access everything from freecam, first person pov, third person pov, 3 different configurable overviews, a cool particle system for goal explosions, and MANY confgurable preferences.",
	author = "Dennssen",
	defaultKeybind = "",
}

--TODO:
-- Add arena loading text in follow pluss.
-- Create release message for follow pluss.
-- Create release message for caster update:
-- - Include info about the update
-- - Patch notes
-- - Known issues
-- Create forum and release message for overlay.
-- Launch everything.

--Notes:
-- clean up config with more "Categories" like post processing has
-- ballCam?

--Fix:
-- When overview has a different gravity direction the cameras rotation ends up wrong.
-- When arenas are loading the cameras movement feels smoothed.

--Add:
-- When exiting POV set the camera to look at the ball. Possibly make an option under controls.
-- Black box behind player names to make it easier to read (Maybe, overlay should help with this)
-- White circle around ball to see it behind walls

-- Future ideas:
-- Addon script that let's you make your own gamemodes (Set bounding boxes, goals, and overviews)
-- Send who last touched the ball to overlay.
-- Make a template minimap for the overlay

-- Known Issues:
-- Double click right click while not moving mouse makes you unable to rotate the camera. (This is a spectator issue, only happens with UI open)
-- Overtime goals are not detected
-- Game crashes when joining any server for the second time

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

local function initializeConfig()
	local saveToConfig = false
	local neededValues = {
		cameraFOV = 90,
		deadzone = 0,
		followFOV = 100,
		followPosititonSmoothing = 0.01,
		followRadius = 20,
		mouseSensitivity = 1,
		invertMouseLookHorizontal = false,
		invertMouseLookVertical = false,
		invertControllerLookHorizontal = false,
		invertControllerLookVertical = false,
		controllerSensitivity = 0.5,
		positionSmoothing = 0.02,
		lookSmoothness = 0,
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
	}

	-- saves new values that are not there from before to all profiles
	for neededKey, neededValue in pairs(neededValues) do
		if config[neededKey] == nil then
			saveToConfig = true
			config[neededKey] = neededValue
		end
	end

	-- removes saved but no longer used values in all profiles
	for configKey, configValue in pairs(config) do
		if neededValues[configKey] == nil then
			saveToConfig = true
			config[configKey] = nil
		end
	end

	if saveToConfig then
		saveConfig()
	end
end

initializeConfig()

local function parseBallJSON(str)
	-- Table to store the parsed data
	local result = {}

	-- Parse type
	local typeVal = string.match(str, '"type"%s*:%s*([%d]+)')
	result.type = tonumber(typeVal)

	return result
end

function getDictSize(dict): number
	local i = 0

	if dict == nil then
		return i
	end

	for _, _ in dict do
		i += 1
	end

	return i
end

function getDictIndex(dict, index: number)
	local i = 0
	local dictSize = getDictSize(dict)
	local dictItem = nil

	if index < 0 or index > dictSize then
		return dictItem
	end

	for _, item in dict do
		if i == index then
			dictItem = item
			break
		end

		i += 1
	end

	return dictItem
end

function capitalize(s: string): string
	local firstLetter = s:sub(1, 1):upper()
	s = s:sub(2)
	return `{firstLetter}{s}`
end

-- math.lerp is nil for some reason
function lerp(a: number, b: number, t: number): number
	if a == nil then
		return b
	end
	if b == nil then
		return a
	end
	return a * (1.0 - t) + b * t
end

function keyToString(key: Key): string
	return string.gsub(tostring(key), "Gamepad_", "")
end

local deltaTime: number = 0

local loadTime: number = 0
local arenaLoadTime: number = 0
local getArenaDelay: number = 7
local transitionTime: number
local firstTransition: boolean
local defaultPosition = Vec3.new(0, -3000, -27700)
local defaultRotation = Quat.fromEuler(0, 0, 90)

local TeamIndex = {
	NoTeam = -1,
	homeTeam = 0,
	awayTeam = 1,
}
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

-- Bounding Box start

type Local = {
	position: Vec3,
	normal: Vec3,
	length: number,
}

type BoxType = {
	__index: BoxType,
	position: Vec3,
	size: Vec3,
	rotation: Quat,
	vertexLocations: { Vec3 },
	locals: {
		x: Local,
		y: Local,
		z: Local,
	},

	__tostring: (self: BoxType) -> string,
	new: (inputPosition: Vec3, inputSize: Vec3, inputRotation: Quat) -> BoxType,
	setPosition: (self: BoxType, inputPosition: Vec3) -> (),
	setSize: (self: BoxType, inputPosition: Vec3) -> (),
	setRotation: (self: BoxType, inputPosition: Quat) -> (),
	setRotationDeg: (self: BoxType, inputRotation: Vec3) -> (),
	generatePoints: (self: BoxType) -> (),
	render: (self: BoxType, r: number, g: number, b: number) -> (),
	checkPointIntersect: (self: BoxType, point: Vec3) -> boolean,

	empty: BoxType,
}

local Box: BoxType = {} :: BoxType
Box.__index = Box

function Box.new(inputPosition: Vec3, inputSize: Vec3, inputRotation: Quat): BoxType
	local self: BoxType = setmetatable({}, Box) :: any

	self.position = inputPosition
	self.size = inputSize
	self.rotation = inputRotation

	self.vertexLocations = {}
	self.locals = {
		x = {
			position = Vec3.zeroVector,
			normal = Vec3.zeroVector,
			length = 0,
		},
		y = {
			position = Vec3.zeroVector,
			normal = Vec3.zeroVector,
			length = 0,
		},
		z = {
			position = Vec3.zeroVector,
			normal = Vec3.zeroVector,
			length = 0,
		},
	}
	self:generatePoints()
	return self
end

function Box:setPosition(inputPosition: Vec3): ()
	self.position = inputPosition
	self:generatePoints()
end

function Box:setSize(inputSize: Vec3): ()
	self.size = inputSize
	self:generatePoints()
end

function Box:setRotation(inputRotation: Quat): ()
	self.rotation = inputRotation
	self:generatePoints()
end

function Box:setRotationDeg(inputRotation: Vec3): ()
	self.rotation = Quat.fromEuler(inputRotation.x, inputRotation.y, inputRotation.z)
	self:generatePoints()
end

function Box:generatePoints(): ()
	local shift = { x = self.size.x / 2, y = self.size.y / 2, z = self.size.z / 2 }
	local newVertexLocations = {
		Vec3.new(shift.x, shift.y, shift.z),
		Vec3.new(shift.x, shift.y, -shift.z),
		Vec3.new(shift.x, -shift.y, shift.z),
		Vec3.new(shift.x, -shift.y, -shift.z),
		Vec3.new(-shift.x, shift.y, shift.z),
		Vec3.new(-shift.x, shift.y, -shift.z),
		Vec3.new(-shift.x, -shift.y, shift.z),
		Vec3.new(-shift.x, -shift.y, -shift.z),
	}

	for i = 1, #newVertexLocations do
		newVertexLocations[i] = self.rotation:rotateVector(newVertexLocations[i])
	end

	-- Translate the vertices by the box position.
	for i = 1, #newVertexLocations do
		newVertexLocations[i].x = newVertexLocations[i].x + self.position.x
		newVertexLocations[i].y = newVertexLocations[i].y + self.position.y
		newVertexLocations[i].z = newVertexLocations[i].z + self.position.z
	end

	self.vertexLocations = newVertexLocations

	self.locals.x.position = self.vertexLocations[5] - self.vertexLocations[1]
	self.locals.y.position = self.vertexLocations[3] - self.vertexLocations[1]
	self.locals.z.position = self.vertexLocations[2] - self.vertexLocations[1]

	for _, l: Local in self.locals :: { Local } do
		l.normal = l.position:getSafeNormal()
		l.length = l.position:length()
	end
end

function Box:render(r: number, g: number, b: number): ()
	local lines: { { start: Vec3, finish: Vec3 } } = {
		{ start = self.vertexLocations[1], finish = self.vertexLocations[2] },
		{ start = self.vertexLocations[1], finish = self.vertexLocations[3] },
		{ start = self.vertexLocations[1], finish = self.vertexLocations[5] },
		{ start = self.vertexLocations[4], finish = self.vertexLocations[2] },
		{ start = self.vertexLocations[4], finish = self.vertexLocations[3] },
		{ start = self.vertexLocations[4], finish = self.vertexLocations[8] },
		{ start = self.vertexLocations[7], finish = self.vertexLocations[8] },
		{ start = self.vertexLocations[7], finish = self.vertexLocations[3] },
		{ start = self.vertexLocations[7], finish = self.vertexLocations[5] },
		{ start = self.vertexLocations[6], finish = self.vertexLocations[5] },
		{ start = self.vertexLocations[6], finish = self.vertexLocations[2] },
		{ start = self.vertexLocations[6], finish = self.vertexLocations[8] },
	}

	WorldDraw.drawPoint(self.position, 0.2, 3, 0.2, 5, 0)
	for i: number, line: { start: Vec3, finish: Vec3 } in lines do
		WorldDraw.drawLine(line.start, line.finish, r, g, b, 4, 0)
	end

	WorldDraw.drawLine(self.position, self.position + self.rotation:getForwardVector() * 100, 1, 0, 0, 10, 0)
	WorldDraw.drawLine(self.position, self.position + self.rotation:getUpVector() * 100, 0, 1, 0, 10, 0)
	WorldDraw.drawLine(self.position, self.position + self.rotation:getRightVector() * 100, 0, 0, 1, 10, 0)
end

function Box:checkPointIntersect(point: Vec3?): boolean
	if point == nil then
		return false
	end

	local zeroPoint: Vec3 = self.vertexLocations[1]
	local fullPoint: Vec3 = self.vertexLocations[8]
	local centerPoint: Vec3 = (zeroPoint + fullPoint) / 2

	local projectionVector: Vec3 = point - centerPoint

	local pX: number = math.abs(Vec3.dot(projectionVector, self.locals.x.normal))
	local pY: number = math.abs(Vec3.dot(projectionVector, self.locals.y.normal))
	local pZ: number = math.abs(Vec3.dot(projectionVector, self.locals.z.normal))

	if 2 * pX <= self.locals.x.length and 2 * pY <= self.locals.y.length and 2 * pZ <= self.locals.z.length then
		return true
	else
		return false
	end
end

Box.empty = Box.new(Vec3.zeroVector, Vec3.zeroVector, Quat.identity)

-- Ball
local ball: ReplayBall
local ballRotation: Quat = Quat.identity
local GetBallVariant = {
	PlayerBallDistance = "PlayerBallDistance",
	LineOfSight = "LineOfSight",
}
local getBallVariant = config.getBallVariant

-- Overlay Camera
local overlayCamera: SpectatorCamera = nil
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
local followPlussVersion: string = ""
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

type MessageValues = {
	versionCallback: (string) -> ()?,
	callback: (() -> ()) -> ()?,
	readLocation: number?,
	showNameTags: boolean?,
	isLeftHanded: boolean?,
	muteSelf: boolean?,
	targetPlayer: ReplayPlayer?,
	targetPlayerName: string?,
	positionSmoothing: number?,
	cameraFOV: number?,
	cameraMode: number?,
	radius: number?,
	threshold: number?,
	cameraPositionOffset: string?,
	cameraEulerOffset: string?,
	gestureControls: boolean?,
	forwardGestureMode: number?,
	upGestureMode: number?,
	backwardsGestureMode: number?,
	autoBall: boolean?,
	autoBallThreshold: number?,
	autoGoalCam: boolean?,
	ballGoalMode: number?,
	goalMode: number?,
	hideNearestHead: boolean?,
	showQuests: boolean?,
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

type ArenaTeam = {
	previousScore: number,
	score: number,
	scoreIncrease: boolean,
	roundsWon: number,
	goal: {
		position: Vec3,
		rotation: Quat,
		box: BoxType,
	},
	overview: { { position: Vec3, rotation: Quat } },
	players: { ReplayPlayer },
}

type Arena = {
	__index: Arena,
	type: string,

	slotId: string,
	gamemode: ModuleStateSpectatorLuaApi,
	name: string,
	transform: Transform,
	box: BoxType,
	centerBox: BoxType,
	home: ArenaTeam,
	away: ArenaTeam,
	players: { ReplayPlayer },

	lastIsGameActive: boolean,
	isGameActive: boolean,
	isKickoff: boolean,

	gameTimeSeconds: number,
	actionTimerSeconds: number,
	isGracePeriod: boolean,
	bestOfAmount: number,
	matchLengthSeconds: number,

	new: (gamemode: ModuleStateSpectatorLuaApi) -> Arena,
	tick: (self: Arena) -> (),
	onRoundEnd: (self: Arena) -> (),
	onGameStart: (self: Arena) -> (),
	setTeams: (self: Arena) -> (),
	sendInfoMessage: (self: Arena) -> (),

	-- Overrides
	isPointOnHomeSide: (self: Arena, point: Vec3) -> boolean,
	setupDimensions: (self: Arena) -> (),
	setupOverviews: (self: Arena) -> (),
	getTeamRotation: (self: Arena, teamIndex: number) -> Quat,

	GUIChangeDimensions: (self: Arena) -> (), -- Debuging
}

local Arena: Arena = {} :: Arena
Arena.__index = Arena

local arenaSwitch: boolean = false

local centerBoxSize = Vec3.new(50, 50, 125)
local timeSinceLastGracePeriod: number = 0

local overviewOffsets = config.overviewOffsets

function Arena.new(gamemode: ModuleStateSpectatorLuaApi): Arena
	local self: Arena = setmetatable({}, Arena) :: any

	self.slotId = gamemode:getSlotId()
	self.gamemode = gamemode
	self.transform = gamemode:getTransform()
	self.players = {}

	self.home = {
		previousScore = 0,
		score = 0,
		scoreIncrease = false,
		roundsWon = 0,
		goal = {
			position = Vec3.zeroVector,
			rotation = Quat.identity,
			box = Box.empty,
		},
		overview = {},
		players = {},
	}

	self.away = {
		previousScore = 0,
		score = 0,
		scoreIncrease = false,
		roundsWon = 0,
		goal = {
			position = Vec3.zeroVector,
			rotation = Quat.identity,
			box = Box.empty,
		},
		overview = {},
		players = {},
	}

	self.isKickoff = false

	print(`made arena {self.slotId}`)

	return self
end

function Arena:tick()
	local gameTimeComponent = self.gamemode:getGameTimeComponent()

	if gameTimeComponent then
		local gameTimeSeconds = gameTimeComponent:getTimeSeconds()
		local actionTimerSeconds = gameTimeComponent:getSecondaryTimeSeconds()
		self.gameTimeSeconds = gameTimeSeconds
		self.actionTimerSeconds = actionTimerSeconds
	else
		self.gameTimeSeconds = 0
		self.actionTimerSeconds = 0
	end

	self.lastIsGameActive = self.isGameActive
	self.isGameActive = self.gamemode:getIsGameRunning()

	if not self.isGameActive and self.lastIsGameActive then
		self:onRoundEnd()
	end

	self.home.previousScore = self.home.score
	self.home.score = self.gamemode:getTeamScore(TeamIndex.homeTeam)
	self.away.previousScore = self.away.score
	self.away.score = self.gamemode:getTeamScore(TeamIndex.awayTeam)

	self.home.roundsWon = self.gamemode:getTeamRoundsWon(TeamIndex.homeTeam)
	self.away.roundsWon = self.gamemode:getTeamRoundsWon(TeamIndex.awayTeam)

	if arenaSwitch then
		self.home.previousScore = self.home.score
		self.away.previousScore = self.away.score

		self.lastIsGameActive = self.isGameActive

		arenaSwitch = false
	end

	if self.gamemode:getBoolConfigVariable("busebestof") then
		self.bestOfAmount = self.gamemode:getNumberConfigVariable("roundspermatch")
	else
		self.bestOfAmount = 1
	end

	self.matchLengthSeconds = self.gamemode:getNumberConfigVariable("matchlengthseconds")

	self.home.scoreIncrease = self.home.previousScore < self.home.score
	self.away.scoreIncrease = self.away.previousScore < self.away.score

	if self.home.scoreIncrease or self.away.scoreIncrease then
		timeSinceLastGracePeriod = 0
		self.isGracePeriod = true
	end

	if not self.isGracePeriod and self.actionTimerSeconds > 0 and self.gameTimeSeconds < self.matchLengthSeconds then
		timeSinceLastGracePeriod = 0
		self.isGracePeriod = true
	end

	if
		self.isGracePeriod
		and (
			(timeSinceLastGracePeriod > 6 and self.actionTimerSeconds == 0)
			or self.gameTimeSeconds == self.matchLengthSeconds
		)
	then
		self.isGracePeriod = false
	end

	timeSinceLastGracePeriod += deltaTime

	if not self.isKickoff and not self.lastIsGameActive and self.isGameActive then
		self.isKickoff = true
	end

	local started = self.isGameActive and not self.lastIsGameActive

	if started and self.home.roundsWon == 0 and self.away.roundsWon == 0 then
		self:onGameStart()
	end

	self:setTeams()
	self:sendInfoMessage()
end

function Arena:onRoundEnd()
	if self.home.score == self.away.score then -- find who scored in overtime
		local homeDirection = getForward(self.transform.position, self.home.goal.position)
		local ballDirection = getForward(self.transform.position, ball.transform.position)
		local isHomePoint = homeDirection:dot(ballDirection) > 0

		if isHomePoint then
			self.home.score += 1
		else
			self.away.score += 1
		end
	end

	local round: Round = {
		home = {
			score = self.home.score,
		},
		away = {
			score = self.away.score,
		},
	}

	sendSafeMessage(overlayCamera, {
		info = "rounds",
		value = round,
	})
end

function Arena:onGameStart()
	sendSafeMessage(overlayCamera, {
		info = "clearStats",
		value = "",
	})

	sendSafeMessage(overlayCamera, {
		info = "rounds",
		value = "clear",
	})
end

function Arena:setTeams()
	local tempHome = {}
	local tempAway = {}

	for _, player in gameData.players do
		if player.teamIndex == TeamIndex.NoTeam then
			continue
		end

		if not self.box:checkPointIntersect(player.root.position) then
			continue
		end

		if player.teamIndex == TeamIndex.homeTeam then
			table.insert(tempHome, player)
		elseif player.teamIndex == TeamIndex.awayTeam then
			table.insert(tempAway, player)
		end
	end

	self.home.players = tempHome
	self.away.players = tempAway

	local allPlayers = {}
	for _, player in self.home.players do
		table.insert(allPlayers, player)
	end
	for _, player in self.away.players do
		table.insert(allPlayers, player)
	end
	self.players = allPlayers
end

function Arena:sendInfoMessage()
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

type Arena3v3 = Arena & {
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
setmetatable(Arena3v3, { __index = Arena })

Arena3v3.homeRotationOffset = Quat.fromEuler(0, 0, 90)
Arena3v3.awayRotationOffset = Quat.fromEuler(0, 0, -90)
Arena3v3.boxSize = Vec3.new(5100, 6750, 1440)
Arena3v3.boxOffset = Vec3.new(0, 0, 650)
Arena3v3.centerBoxOffset = Vec3.new(0, 0, 300)
Arena3v3.goalBoxSize = Vec3.new(100, 500, 225)
Arena3v3.goalPositionOffset = Vec3.new(3285, 0, 175)

function Arena3v3.new(gamemode: ModuleStateSpectatorLuaApi): Arena
	local self = setmetatable(Arena.new(gamemode), Arena3v3) :: any
	self.type = "3v3"
	self.name = self.slotId:gsub("TKB_", "")
	self:setupDimensions()
	self:setupOverviews()
	return self :: Arena3v3
end

function Arena3v3:isPointOnHomeSide(point: Vec3): boolean
	local homeDirection = (self.transform.rotation * Arena3v3.homeRotationOffset):getForwardVector()
	local ballDirection = getForward(self.transform.position, point)
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
		position = self.transform.position
			+ (self.transform.rotation * Arena3v3.homeRotationOffset):rotateVector(Arena3v3.goalPositionOffset),
		rotation = self.transform.rotation * Arena3v3.homeRotationOffset:inverse(),
		box = Box.empty,
	}

	self.home.goal.box = Box.new(self.home.goal.position, Arena3v3.goalBoxSize, self.home.goal.rotation)

	self.away.goal = {
		position = self.transform.position
			+ (self.transform.rotation * Arena3v3.awayRotationOffset):rotateVector(Arena3v3.goalPositionOffset),
		rotation = self.transform.rotation * Arena3v3.awayRotationOffset:inverse(),
		box = Box.empty,
	}
	self.away.goal.box = Box.new(self.away.goal.position, Arena3v3.goalBoxSize, self.away.goal.rotation)
end

function Arena3v3:setupOverviews()
	for _, overview in overviewOffsets._3v3 do
		local homeOverview = {
			position = self.transform.position
				+ (self.transform.rotation * Arena3v3.homeRotationOffset):rotateVector(overview.position),
			rotation = (self.transform.rotation * Arena3v3.homeRotationOffset * overview.rotation),
		}
		local awayOverview = {
			position = self.transform.position
				+ (self.transform.rotation * Arena3v3.awayRotationOffset):rotateVector(overview.position),
			rotation = (self.transform.rotation * Arena3v3.awayRotationOffset * overview.rotation),
		}

		table.insert(self.home.overview, homeOverview)
		table.insert(self.away.overview, awayOverview)
	end
end

function Arena3v3:getTeamRotation(teamIndex: number): Quat
	local rotation = Quat.identity
	if teamIndex == TeamIndex.homeTeam then
		rotation = self.transform.rotation * Arena3v3.homeRotationOffset
	elseif teamIndex == TeamIndex.awayTeam then
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

type Arena4v4 = Arena & {
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
setmetatable(Arena4v4, { __index = Arena })

Arena4v4.homeRotationOffset = Quat.fromEuler(0, 0, -90)
Arena4v4.awayRotationOffset = Quat.fromEuler(0, 0, 90)
Arena4v4.boxSize = Vec3.new(6110, 8400, 1490)
Arena4v4.boxOffset = Vec3.new(0, 0, 600)
Arena4v4.centerBoxOffset = Vec3.new(0, 0, 250)
Arena4v4.goalBoxSize = Vec3.new(200, 450, 225)
Arena4v4.goalPositionOffset = Vec3.new(4075, 0, 175)

function Arena4v4.new(gamemode: ModuleStateSpectatorLuaApi): Arena
	local self = setmetatable(Arena.new(gamemode), Arena4v4) :: any
	self.type = "4v4"
	self.name = `Jakeball {self.slotId:sub(self.slotId:len() - 2)}`
	self:setupDimensions()
	self:setupOverviews()
	return self :: Arena4v4
end

function Arena4v4:isPointOnHomeSide(point: Vec3): boolean
	local homeDirection = (self.transform.rotation * Arena4v4.homeRotationOffset):getForwardVector()
	local ballDirection = getForward(self.transform.position, point)
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
		position = self.transform.position
			+ (self.transform.rotation * Arena4v4.homeRotationOffset):rotateVector(Arena4v4.goalPositionOffset),
		rotation = self.transform.rotation * Arena4v4.homeRotationOffset:inverse(),
		box = Box.empty,
	}

	self.home.goal.box = Box.new(self.home.goal.position, Arena4v4.goalBoxSize, self.home.goal.rotation)

	self.away.goal = {
		position = self.transform.position
			+ (self.transform.rotation * Arena4v4.awayRotationOffset):rotateVector(Arena4v4.goalPositionOffset),
		rotation = self.transform.rotation * Arena4v4.awayRotationOffset:inverse(),
		box = Box.empty,
	}
	self.away.goal.box = Box.new(self.away.goal.position, Arena4v4.goalBoxSize, self.away.goal.rotation)
end

function Arena4v4:setupOverviews()
	for _, overview in overviewOffsets._4v4 do
		local homeOverview = {
			position = self.transform.position
				+ (self.transform.rotation * Arena4v4.homeRotationOffset):rotateVector(overview.position),
			rotation = (self.transform.rotation * Arena4v4.homeRotationOffset * overview.rotation),
		}
		local awayOverview = {
			position = self.transform.position
				+ (self.transform.rotation * Arena4v4.awayRotationOffset):rotateVector(overview.position),
			rotation = (self.transform.rotation * Arena4v4.awayRotationOffset * overview.rotation),
		}

		table.insert(self.home.overview, homeOverview)
		table.insert(self.away.overview, awayOverview)
	end
end

function Arena4v4:getTeamRotation(teamIndex: number?): Quat
	local rotation = Quat.identity
	if teamIndex == TeamIndex.homeTeam then
		rotation = self.transform.rotation * Arena4v4.homeRotationOffset
	elseif teamIndex == TeamIndex.awayTeam then
		rotation = self.transform.rotation * Arena4v4.awayRotationOffset
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

type Driftblitz = Arena & {
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
setmetatable(Driftblitz, { __index = Arena })

Driftblitz.homeRotationOffset = Quat.fromEuler(0, 0, 90)
Driftblitz.awayRotationOffset = Quat.fromEuler(0, 0, -90)
Driftblitz.boxSize = Vec3.new(7270, 11825, 1440)
Driftblitz.boxOffset = Vec3.new(0, 0, 740)
Driftblitz.centerBoxOffset = Vec3.new(0, 0, 100)
Driftblitz.goalBoxSize = Vec3.new(100, 890, 300)
Driftblitz.goalPositionOffset = Vec3.new(5295, 0, 175)

function Driftblitz.new(gamemode: ModuleStateSpectatorLuaApi): Arena
	local self = setmetatable(Arena.new(gamemode), Driftblitz) :: any
	self.name = self.slotId
	self.type = "driftblitz"
	self:setupDimensions()
	self:setupOverviews()
	return self :: Driftblitz
end

function Driftblitz:isPointOnHomeSide(point: Vec3): boolean
	local homeDirection = (self.transform.rotation * Driftblitz.homeRotationOffset):getForwardVector()
	local ballDirection = getForward(self.transform.position, point)
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
		position = self.transform.position
			+ (self.transform.rotation * Driftblitz.homeRotationOffset):rotateVector(Driftblitz.goalPositionOffset),
		rotation = self.transform.rotation * Driftblitz.homeRotationOffset:inverse(),
		box = Box.empty,
	}

	self.home.goal.box = Box.new(self.home.goal.position, Driftblitz.goalBoxSize, self.home.goal.rotation)

	self.away.goal = {
		position = self.transform.position
			+ (self.transform.rotation * Driftblitz.awayRotationOffset):rotateVector(Driftblitz.goalPositionOffset),
		rotation = self.transform.rotation * Driftblitz.awayRotationOffset:inverse(),
		box = Box.empty,
	}
	self.away.goal.box = Box.new(self.away.goal.position, Driftblitz.goalBoxSize, self.away.goal.rotation)
end

function Driftblitz:setupOverviews()
	for _, overview in overviewOffsets._driftblitz do
		local homeOverview = {
			position = self.transform.position
				+ (self.transform.rotation * Driftblitz.homeRotationOffset):rotateVector(overview.position),
			rotation = (self.transform.rotation * Driftblitz.homeRotationOffset * overview.rotation),
		}
		local awayOverview = {
			position = self.transform.position
				+ (self.transform.rotation * Driftblitz.awayRotationOffset):rotateVector(overview.position),
			rotation = (self.transform.rotation * Driftblitz.awayRotationOffset * overview.rotation),
		}

		table.insert(self.home.overview, homeOverview)
		table.insert(self.away.overview, awayOverview)
	end
end

function Driftblitz:getTeamRotation(teamIndex: number): Quat
	local rotation = Quat.identity
	if teamIndex == TeamIndex.homeTeam then
		rotation = self.transform.rotation * Driftblitz.homeRotationOffset
	elseif teamIndex == TeamIndex.awayTeam then
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

function getArenas(): { [any]: Arena }
	local arenas: { [any]: Arena } = {}
	local gamemodes = SpectatorGamemodes.listGamemodes()
	print("got gamemodes in getArenas")
	for _, gamemode in gamemodes do
		local slotId = gamemode:getSlotId()
		if slotId:find("TKB") and not slotId:find("Full") then
			local arena = Arena3v3.new(gamemode)
			arenas[arena.name] = arena
		elseif slotId:find("Soccer") then
			local arena = Driftblitz.new(gamemode)
			arenas[arena.name] = arena
		elseif slotId:find("Jakeball") then
			local arena = Arena4v4.new(gamemode)
			arenas[arena.name] = arena
		end
	end

	print("got arenas")

	return arenas
end

-- arena
local arenas: { [any]: Arena }

function updateArenaOverviews()
	overviewOffsets = config.overviewOffsets

	for _, arena in arenas do
		arena.home.overview = {}
		arena.away.overview = {}

		arena:setupOverviews()
	end
end

local selectedArena: Arena = nil

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
local lastPlayerWithBall: ReplayPlayer? = nil
local previousLastPlayerWithBall: ReplayPlayer? = nil
local homeGoalPotentialEnter: boolean = false
local previousHomeGoalPotentialEnter: boolean = false
local awayGoalPotentialEnter: boolean = false
local previousAwayGoalPotentialEnter: boolean = false

local lastPlayerBallContactPoint: Vec3 = Vec3.zeroVector
local maximumTimeSincePass: number = 5
local timeSincePass: number = 0

local assistPlayer: ReplayPlayer? = nil
local goalPlayer: ReplayPlayer? = nil

-- Gravity
local gravityChaser: Quat = gravity.upRotation

-- Caster Camera
local cameraFOV = config.cameraFOV
local cameraMode = nil
local positionSmoothing = config.positionSmoothing
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
function DeserializeKeybinds(string: string)
	local keybinds = {}

	for fullEntry in string:gmatch("{(.-:{.-}})}") do
		local key, content = fullEntry:match("(.-):{(.*)}")
		if not key or not content then
			continue
		end

		local entry = {}

		entry.primary = Input.Key[content:match('primary:"([^"]+)"')]
		if entry.primary == nil then
			entry.primary = Input.Gamepad[content:match('primary:"([^"]+)"')]
		end

		local modifierContent = content:match("modifiers:{(.-)}") or ""
		entry.modifiers = {}

		for modifier in modifierContent:gmatch('"([^"]+)"') do
			local modifierKey = Input.Key[modifier]
			if modifierKey == nil then
				modifierKey = Input.Gamepad[modifier]
			end

			table.insert(entry.modifiers, modifierKey)
		end

		keybinds[key] = entry
	end

	return keybinds
end

local keyboardKeys: { string } = {
	"Tab",
	"Enter",
	"Pause",
	"CapsLock",
	"Escape",
	"SpaceBar",
	"PageUp",
	"PageDown",
	"End",
	"Home",
	"Left",
	"Up",
	"Right",
	"Down",
	"Insert",
	"BackSpace",
	"Delete",
	"Zero",
	"One",
	"Two",
	"Three",
	"Four",
	"Five",
	"Six",
	"Seven",
	"Eight",
	"Nine",
	"A",
	"B",
	"C",
	"D",
	"E",
	"F",
	"G",
	"H",
	"I",
	"J",
	"K",
	"L",
	"M",
	"N",
	"O",
	"P",
	"Q",
	"R",
	"S",
	"T",
	"U",
	"V",
	"W",
	"X",
	"Y",
	"Z",
	"NumPadZero",
	"NumPadOne",
	"NumPadTwo",
	"NumPadThree",
	"NumPadFour",
	"NumPadFive",
	"NumPadSix",
	"NumPadSeven",
	"NumPadEight",
	"NumPadNine",
	"Multiply",
	"Add",
	"Subtract",
	"Decimal",
	"Divide",
	"F8",
	"F9",
	"F10",
	"F12",
	"NumLock",
	"ScrollLock",
	"LeftShift",
	"RightShift",
	"LeftControl",
	"RightControl",
	"LeftAlt",
	"RightAlt",
	"LeftCommand",
	"RightCommand",
	"Semicolon",
	"Equals",
	"Comma",
	"Hyphen",
	"Underscore",
	"Period",
	"Slash",
	"Tilde",
	"LeftBracket",
	"Backslash",
	"RightBracket",
	"Apostrophe",
	"Quote",
	"LeftParantheses",
	"RightParantheses",
	"Ampersand",
	"Asterix",
	"Caret",
	"Dollar",
	"Exclamation",
	"Colon",
	"A_AccentGrave",
	"E_AccentGrave",
	"E_AccentAigu",
	"C_Cedille",
	"Section",
	"LeftMouseButton",
	"MiddleMouseButton",
	"RightMouseButton",
}

function getGamepadKeysDown(): { Key }
	local bannedInputs =
		{ -- values to be ignored because their apperances are not predictable or should not be accepted
			Input.Gamepad.Left2D,
			Input.Gamepad.Right2D,
			Input.Gamepad.RightY,
			Input.Gamepad.RightX,
			Input.Gamepad.LeftY,
			Input.Gamepad.LeftX,
			Input.Gamepad.LeftTriggerAxis,
			Input.Gamepad.RightTriggerAxis,
			Input.Gamepad.LeftStick_Down,
			Input.Gamepad.LeftStick_Left,
			Input.Gamepad.LeftStick_Right,
			Input.Gamepad.LeftStick_Up,
			Input.Gamepad.RightStick_Down,
			Input.Gamepad.RightStick_Left,
			Input.Gamepad.RightStick_Right,
			Input.Gamepad.RightStick_Up,
		}
	local inputMeta = getmetatable(Input)
	local gamepad = inputMeta.__index.Gamepad
	local inputTable = nil
	for key, value in pairs(gamepad) do
		if type(value) == "table" then
			inputTable = value
			break
		end
	end

	local pressedKeys: { Key } = {}

	for key, _ in pairs(inputTable) do
		if Input.getKeyDown(Input.Gamepad[key]) then
			local banned = false
			for _, bannedValue in pairs(bannedInputs) do
				if keyToString(bannedValue) == keyToString(Input.Gamepad[key]) then
					banned = true
					break
				end
			end

			if banned then
				continue
			end

			table.insert(pressedKeys, Input.Gamepad[key])
		end
	end
	return pressedKeys
end

function getKeyboardKeysDown(): { Key } -- AnyKey early return?
	local bannedInputs = {}
	local pressedKeys: { Key } = {}

	for _, key in pairs(keyboardKeys) do
		if Input.getKeyDown(Input.Key[key]) then
			local banned = false
			for _, bannedValue: Key in pairs(bannedInputs) do
				if bannedValue == Input.Key[key] then
					banned = true
					break
				end
			end

			if banned then
				continue
			end

			table.insert(pressedKeys, Input.Key[key])
		end
	end
	return pressedKeys
end

local Vertical: number = 0
local Horizontal: number = 0
local Up: number = 0
local deadzone: number = config.deadzone
local rotEuler: Vec3 = Vec3.zeroVector

local pressedRebindModifiers = {}
local pressedInputKeys = {}

local modifierKeys = {
	"LeftAlt",
	"LeftControl",
	"LeftShift",
	"RightAlt",
	"RightControl",
	"RightShift",
	"DPad_Up",
	"DPad_Down",
	"DPad_Right",
	"DPad_Left",
}

type CasterInput = {
	name: string,
	description: string,
	hotkey: Key,
	modifiers: { Key }?,
	editable: boolean,
}

function createCasterInput(
	_name: string,
	_description: string,
	_hotkey: Key,
	_modifires: { Key }?,
	_editable: boolean?
): CasterInput
	if _editable == nil then
		_editable = true
	end

	return {
		name = _name,
		description = _description,
		hotkey = _hotkey,
		modifiers = _modifires,
		editable = _editable,
	} :: CasterInput
end

function compareCasterInputs(a: { hotkey: Key, modifiers: { Key }? }, b: { hotkey: Key, modifiers: { Key }? }): boolean
	if keyToString(a.hotkey) ~= keyToString(b.hotkey) then
		return false
	end

	if (a.modifiers ~= nil) ~= (b.modifiers ~= nil) then
		return false
	end

	local isEqual = true

	if a.modifiers and b.modifiers then
		for _, aKey: Key in a.modifiers do
			if table.find(b.modifiers, aKey) == nil then
				isEqual = false
				break
			end
		end

		for _, bKey: Key in b.modifiers do
			if table.find(a.modifiers, bKey) == nil then
				isEqual = false
				break
			end
		end
	end

	return isEqual
end

function getCasterKey(key: CasterInput): { down: boolean, held: boolean, up: boolean }
	local primary = key.hotkey
	local modifiers = key.modifiers

	local inputData = {
		down = false,
		held = false,
		up = false,
	}

	-- no keys are pressed atm
	if getDictSize(pressedInputKeys) == 0 then
		return inputData
	end

	-- primary key isn't pressed so no point in checking modifiers
	if pressedInputKeys[keyToString(primary)] == nil then
		return inputData
	end

	local currentPrimaryTime = pressedInputKeys[keyToString(primary)].time

	if modifiers then
		-- check for modifier keys not being held down
		for _, key: Key in modifiers do
			if not Input.getKeyDown(key) and not Input.getKey(key) then
				return inputData
			end

			-- if modifier is pressed after primary we don't allow the input
			local modTime = pressedInputKeys[keyToString(key)].time
			if modTime > currentPrimaryTime then
				return inputData
			end
		end
	else
		-- check for unwanted modifier keys that are pressed and held down and also CONCIDERED modifiers
		for _, key: string in modifierKeys do
			local modifier = pressedInputKeys[key]
			if modifier == nil then
				continue
			end

			-- check if the modifier key is concidered a modifier
			local isModifier = modifier.isModifier and key ~= keyToString(primary)

			local inputKey = Input.Key[key]
			if inputKey == nil then
				inputKey = Input.Gamepad[key]
			end

			if (Input.getKeyDown(inputKey) or Input.getKey(inputKey)) and isModifier then
				return inputData
			end
		end
	end

	if Input.getKeyDown(primary) then
		inputData.down = true
	end

	if Input.getKey(primary) then
		inputData.held = true
	end

	if Input.getKeyUp(primary) then
		inputData.up = true
	end

	return inputData
end

function getCasterAnalog(key: CasterInput): number
	local primary = key.hotkey
	local modifiers = key.modifiers

	if modifiers then
		-- check for modifier keys not being held down
		for _, key: Key in modifiers do
			if not Input.getKeyDown(key) and not Input.getKey(key) then
				return 0
			end
		end
	end

	return Input.getAnalog(primary)
end

local keyboardKeybindsDeserialized = DeserializeKeybinds(config.keyboardKeybinds)
local gamepadKeybindsDeserialized = DeserializeKeybinds(config.gamepadKeybinds)

if getDictSize(keyboardKeybindsDeserialized) == 0 then
	keyboardKeybindsDeserialized = defaultKeybinds.keyboard
end

if getDictSize(gamepadKeybindsDeserialized) == 0 then
	gamepadKeybindsDeserialized = defaultKeybinds.gamepad
end

local inputs = {
	keyboard = {
		forwards = createCasterInput(
			"Move Forwards",
			"Move camera forward",
			keyboardKeybindsDeserialized["forwards"].primary,
			keyboardKeybindsDeserialized["forwards"].modifiers
		),
		right = createCasterInput(
			"Move Right",
			"Move camera right",
			keyboardKeybindsDeserialized["right"].primary,
			keyboardKeybindsDeserialized["right"].modifiers
		),
		left = createCasterInput(
			"Move Left",
			"Move camera left",
			keyboardKeybindsDeserialized["left"].primary,
			keyboardKeybindsDeserialized["left"].modifiers
		),
		backwards = createCasterInput(
			"Move Backwards",
			"Move camera backward",
			keyboardKeybindsDeserialized["backwards"].primary,
			keyboardKeybindsDeserialized["backwards"].modifiers
		),
		up = createCasterInput(
			"Move Up",
			"Move camera up",
			keyboardKeybindsDeserialized["up"].primary,
			keyboardKeybindsDeserialized["up"].modifiers
		),
		down = createCasterInput(
			"Move Down",
			"Move camera down",
			keyboardKeybindsDeserialized["down"].primary,
			keyboardKeybindsDeserialized["down"].modifiers
		),
		nextPlayer = createCasterInput(
			"Next Player",
			"Cycle to next player (POV mode)",
			keyboardKeybindsDeserialized["nextPlayer"].primary,
			keyboardKeybindsDeserialized["nextPlayer"].modifiers
		),
		previousPlayer = createCasterInput(
			"Previous Player",
			"Cycle to previous player (POV mode)",
			keyboardKeybindsDeserialized["previousPlayer"].primary,
			keyboardKeybindsDeserialized["previousPlayer"].modifiers
		),
		lineOfSight = createCasterInput(
			"Line of Sight",
			"Target: Player in line of sight",
			keyboardKeybindsDeserialized["lineOfSight"].primary,
			keyboardKeybindsDeserialized["lineOfSight"].modifiers
		),
		playerBallDistance = createCasterInput(
			"Closest to Ball",
			"Target: Player nearest ball",
			keyboardKeybindsDeserialized["playerBallDistance"].primary,
			keyboardKeybindsDeserialized["playerBallDistance"].modifiers
		),
		speedUp = createCasterInput(
			"Speed Up",
			"Increase camera speed",
			keyboardKeybindsDeserialized["speedUp"].primary,
			keyboardKeybindsDeserialized["speedUp"].modifiers
		),
		speedDown = createCasterInput(
			"Speed Down",
			"Decrease camera speed",
			keyboardKeybindsDeserialized["speedDown"].primary,
			keyboardKeybindsDeserialized["speedDown"].modifiers
		),
		thirdPerson = createCasterInput(
			"Third Person",
			"Toggle third-person view",
			keyboardKeybindsDeserialized["thirdPerson"].primary,
			keyboardKeybindsDeserialized["thirdPerson"].modifiers
		),
		firstPerson = createCasterInput(
			"First Person",
			"Toggle first-person view",
			keyboardKeybindsDeserialized["firstPerson"].primary,
			keyboardKeybindsDeserialized["firstPerson"].modifiers
		),
		freeCam = createCasterInput(
			"Free Cam",
			"Toggle free-cam view",
			keyboardKeybindsDeserialized["freeCam"].primary,
			keyboardKeybindsDeserialized["freeCam"].modifiers
		),
		overview1 = createCasterInput(
			"Overview 1",
			"Jump to first overview position",
			keyboardKeybindsDeserialized["overview1"].primary,
			keyboardKeybindsDeserialized["overview1"].modifiers
		),
		overview2 = createCasterInput(
			"Overview 2",
			"Jump to second overview position",
			keyboardKeybindsDeserialized["overview2"].primary,
			keyboardKeybindsDeserialized["overview2"].modifiers
		),
		overview3 = createCasterInput(
			"Overview 3",
			"Jump to third overview position",
			keyboardKeybindsDeserialized["overview3"].primary,
			keyboardKeybindsDeserialized["overview3"].modifiers
		),
		getClosestArena = createCasterInput(
			"Select Arena",
			"Select closest arena",
			keyboardKeybindsDeserialized["getClosestArena"].primary,
			keyboardKeybindsDeserialized["getClosestArena"].modifiers
		),
		clearOverlayInfo = createCasterInput(
			"Clear Overlay Data",
			"Remove overlay data",
			keyboardKeybindsDeserialized["clearOverlayInfo"].primary,
			keyboardKeybindsDeserialized["clearOverlayInfo"].modifiers
		),
		lookAround = createCasterInput(
			"Look Around",
			"Hold to rotate camera",
			keyboardKeybindsDeserialized["lookAround"].primary,
			keyboardKeybindsDeserialized["lookAround"].modifiers
		),
		resetFOV = createCasterInput(
			"Reset FOV",
			"Reset field of view",
			keyboardKeybindsDeserialized["resetFOV"].primary,
			keyboardKeybindsDeserialized["resetFOV"].modifiers
		),
	},
	gamepad = {
		moveY = createCasterInput(
			"MoveY",
			"Move Camera Forwards/Backwards",
			gamepadKeybindsDeserialized["moveY"].primary,
			gamepadKeybindsDeserialized["moveY"].modifiers,
			false
		),
		moveX = createCasterInput(
			"MoveX",
			"Move Camera Left/Right",
			gamepadKeybindsDeserialized["moveX"].primary,
			gamepadKeybindsDeserialized["moveX"].modifiers,
			false
		),
		up = createCasterInput(
			"Move Up",
			"Move Camera Up",
			gamepadKeybindsDeserialized["up"].primary,
			gamepadKeybindsDeserialized["up"].modifiers
		),
		down = createCasterInput(
			"Move Down",
			"Move Camera Down",
			gamepadKeybindsDeserialized["down"].primary,
			gamepadKeybindsDeserialized["down"].modifiers
		),
		nextPlayer = createCasterInput(
			"Next Player",
			"Cycle to next player (POV mode)",
			gamepadKeybindsDeserialized["nextPlayer"].primary,
			gamepadKeybindsDeserialized["nextPlayer"].modifiers
		),
		previousPlayer = createCasterInput(
			"Previous Player",
			"Cycle to previous player (POV mode)",
			gamepadKeybindsDeserialized["previousPlayer"].primary,
			gamepadKeybindsDeserialized["previousPlayer"].modifiers
		),
		lineOfSight = createCasterInput(
			"Line Of Sight",
			"Target: Player in line of sight",
			gamepadKeybindsDeserialized["lineOfSight"].primary,
			gamepadKeybindsDeserialized["lineOfSight"].modifiers
		),
		playerBallDistance = createCasterInput(
			"Closest to Ball",
			"Target: Player nearest ball",
			gamepadKeybindsDeserialized["playerBallDistance"].primary,
			gamepadKeybindsDeserialized["playerBallDistance"].modifiers
		),
		speedUp = createCasterInput(
			"Speed Up",
			"Increase camera speed",
			gamepadKeybindsDeserialized["speedUp"].primary,
			gamepadKeybindsDeserialized["speedUp"].modifiers
		),
		speedDown = createCasterInput(
			"Speed Down",
			"Decrease camera speed",
			gamepadKeybindsDeserialized["speedDown"].primary,
			gamepadKeybindsDeserialized["speedDown"].modifiers
		),
		lookY = createCasterInput(
			"LookY",
			"Look Up/Down",
			gamepadKeybindsDeserialized["lookY"].primary,
			gamepadKeybindsDeserialized["lookY"].modifiers,
			false
		),
		lookX = createCasterInput(
			"LookX",
			"Look Left/Right",
			gamepadKeybindsDeserialized["lookX"].primary,
			gamepadKeybindsDeserialized["lookX"].modifiers,
			false
		),
		zoomIn = createCasterInput(
			"Zoom In",
			"Increase field of view",
			gamepadKeybindsDeserialized["zoomIn"].primary,
			gamepadKeybindsDeserialized["zoomIn"].modifiers
		),
		zoomOut = createCasterInput(
			"Zoom Out",
			"Decrease field of view",
			gamepadKeybindsDeserialized["zoomOut"].primary,
			gamepadKeybindsDeserialized["zoomOut"].modifiers
		),
		resetFOV = createCasterInput(
			"Reser FOV",
			"Reset field of view",
			gamepadKeybindsDeserialized["resetFOV"].primary,
			gamepadKeybindsDeserialized["resetFOV"].modifiers
		),
		freeCam = createCasterInput(
			"Free Cam",
			"Toggle free-cam view",
			gamepadKeybindsDeserialized["freeCam"].primary,
			gamepadKeybindsDeserialized["freeCam"].modifiers
		),
		firstPerson = createCasterInput(
			"First Person",
			"Toggle first-person view",
			gamepadKeybindsDeserialized["firstPerson"].primary,
			gamepadKeybindsDeserialized["firstPerson"].modifiers
		),
		thirdPerson = createCasterInput(
			"Third Person",
			"Toggle third-person view",
			gamepadKeybindsDeserialized["thirdPerson"].primary,
			gamepadKeybindsDeserialized["thirdPerson"].modifiers
		),
		overview1 = createCasterInput(
			"Overview 1",
			"Jump to first overview position",
			gamepadKeybindsDeserialized["overview1"].primary,
			gamepadKeybindsDeserialized["overview1"].modifiers
		),
		overview2 = createCasterInput(
			"Overview 2",
			"Jump to second overview position",
			gamepadKeybindsDeserialized["overview2"].primary,
			gamepadKeybindsDeserialized["overview2"].modifiers
		),
		overview3 = createCasterInput(
			"Overview 3",
			"Jump to third overview position",
			gamepadKeybindsDeserialized["overview3"].primary,
			gamepadKeybindsDeserialized["overview3"].modifiers
		),
		getClosestArena = createCasterInput(
			"Select Arena",
			"Select closest arena",
			gamepadKeybindsDeserialized["getClosestArena"].primary,
			gamepadKeybindsDeserialized["getClosestArena"].modifiers
		),
		clearOverlayInfo = createCasterInput(
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

local keyToBeRebinded = {
	key = "",
	type = "",
}

--example: "{key:{primary:"keybind",modifiers:{"keybind","keybind"}}}"
function SerializeKeybinds()
	local serializedKeyboardString = ""
	for key, value: CasterInput in inputs.keyboard :: { CasterInput } do
		serializedKeyboardString ..= "{" .. `{key}:` .. "{" .. `primary:"{keyToString(value.hotkey)}",modifiers:` .. "{"

		if value.modifiers then
			for i, modifier: Key in value.modifiers do
				serializedKeyboardString ..= `"{keyToString(modifier)}"`
				if i ~= #value.modifiers then
					serializedKeyboardString ..= `,`
				end
			end
		end

		serializedKeyboardString ..= "}}}"
	end

	local serializedGamepadString = ""
	for key, value: CasterInput in inputs.gamepad :: { CasterInput } do
		serializedGamepadString ..= "{" .. `{key}:` .. "{" .. `primary:"{keyToString(value.hotkey)}",modifiers:` .. "{"

		if value.modifiers then
			for i, modifier: Key in value.modifiers do
				serializedGamepadString ..= `"{keyToString(modifier)}"`
				if i ~= #value.modifiers then
					serializedGamepadString ..= `,`
				end
			end
		end

		serializedGamepadString ..= "}}}"
	end

	return {
		keybord = serializedKeyboardString,
		gamepad = serializedGamepadString,
	}
end

--  Keyboard (debug)
local one = Input.Key.One
local two = Input.Key.Two
local three = Input.Key.Three

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
local controlsScreen: boolean = false
local keyboardControls: boolean = true
local controllerControls: boolean = false
local boundingBoxDebug: boolean = false
local addRound: boolean = false
local overviewMessage = {
	overviewNumber = 0,
	message = "",
}

function main()
	loadTime = os.clock()
	arenaLoadTime = os.clock()
	camera.position = defaultPosition
	camera.rotation = defaultRotation
	rotEuler = defaultRotation:euler()
	followPlussCamera = getCameraById("dennssen.followpluss")
	if followPlussCamera then
		local versionMessage: MessageValues = { versionCallback = getFollowVersion }
		sendMessage(followPlussCamera, versionMessage)
	end
	overlayCamera = getCameraById("dennssen.overlayInfo")
	if overlayCamera then
		usingOverlay = true
		sendMessage(overlayCamera, {
			info = "version",
			value = getOverlayVersion,
		})
	end
end

function getLastEnumValue(enum): number
	local lastValue: number = 0
	for key, value in enum do
		if value > lastValue then
			lastValue = value
		end
	end

	return lastValue
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
		flipQuat = selectedArena:getTeamRotation(TeamIndex.homeTeam):inverse()
	else
		flipQuat = selectedArena:getTeamRotation(TeamIndex.awayTeam):inverse()
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

function setSelectedArena(arena: Arena)
	if selectedArena and arena.name ~= selectedArena.name then -- new arena
		sendSafeMessage(overlayCamera, {
			info = "rounds",
			value = "clear",
		})
		sendSafeMessage(overlayCamera, {
			info = "slotId",
			value = arena.slotId,
		})
		arenaSwitch = true
	end
	selectedArena = arena
end

function onGui()
	if not followPlussCamera then
		Gui.text(
			"WARNING: Follow Pluss is not installed. POV mode will not work. \nPlease install Follow Pluss for POV to work."
		)
	end

	if Gui.button(Icon.Question) then
		controlsScreen = not controlsScreen
	end
	Gui.setItemTooltip("Controls for the camera")

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
			if Gui.beginTable("KeyboardControls", 3) then
				Gui.tableSetupColumn("Name")
				Gui.tableSetupColumn("Description")
				Gui.tableSetupColumn("Hotkey")
				Gui.tableHeadersRow()

				for _, casterInputKey: string in inputOrder.keyboard do
					local casterInput = inputs.keyboard[casterInputKey]

					Gui.tableNextRow()
					Gui.tableNextColumn()
					Gui.text(casterInput.name)
					Gui.tableNextColumn()
					Gui.text(casterInput.description)
					Gui.tableNextColumn()

					local buttonLabel = ""
					if casterInput.modifiers then
						for _, input: Key in casterInput.modifiers do
							buttonLabel = buttonLabel .. `{keyToString(input)} + `
						end
					end
					buttonLabel = buttonLabel .. `{keyToString(casterInput.hotkey)}`

					if keyToBeRebinded.key == casterInputKey and keyToBeRebinded.type == "keyboard" then
						buttonLabel = "..."
					end

					if Gui.button(`{buttonLabel}##{casterInputKey}`) then
						if keyToBeRebinded.key ~= casterInputKey then
							keyToBeRebinded.key = casterInputKey
							keyToBeRebinded.type = "keyboard"
						else
							keyToBeRebinded.key = ""
						end
					end

					Gui.sameLine()

					if
						not compareCasterInputs({
							hotkey = casterInput.hotkey,
							modifiers = casterInput.modifiers,
						}, {
							hotkey = defaultKeybinds.keyboard[casterInputKey].primary,
							modifiers = defaultKeybinds.keyboard[casterInputKey].modifiers,
						}) and Gui.button(`{Icon.Undo}##{casterInputKey}`)
					then
						local defaultValue = defaultKeybinds.keyboard[casterInputKey]
						inputs.keyboard[casterInputKey].modifiers = defaultValue.modifiers
						inputs.keyboard[casterInputKey].hotkey = defaultValue.primary
					end
				end
				Gui.endTable()
			end
		end

		if controllerControls then
			if Gui.beginTable("ControllerControls", 3) then
				Gui.tableSetupColumn("Name")
				Gui.tableSetupColumn("Description")
				Gui.tableSetupColumn("Hotkey")
				Gui.tableHeadersRow()

				for _, casterInputKey: string in inputOrder.gamepad do
					local casterInput: CasterInput = inputs.gamepad[casterInputKey]

					Gui.tableNextRow()
					Gui.tableNextColumn()
					Gui.text(casterInput.name)
					Gui.tableNextColumn()
					Gui.text(casterInput.description)
					Gui.tableNextColumn()

					local buttonLabel = ""
					if casterInput.modifiers then
						for _, input: Key in casterInput.modifiers do
							buttonLabel = buttonLabel .. `{keyToString(input)} + `
						end
					end
					buttonLabel = buttonLabel .. `{keyToString(casterInput.hotkey)}`

					if keyToBeRebinded.key == casterInputKey and keyToBeRebinded.type == "gamepad" then
						buttonLabel = "..."
					end

					if not casterInput.editable then
						Gui.beginDisabled()
					end

					if Gui.button(`{buttonLabel}##{casterInputKey}`) then
						if keyToBeRebinded.key ~= casterInputKey then
							keyToBeRebinded.key = casterInputKey
							keyToBeRebinded.type = "gamepad"
						else
							keyToBeRebinded.key = ""
						end
					end

					if not casterInput.editable then
						Gui.endDisabled()
					end

					Gui.sameLine()

					if
						not compareCasterInputs({
							hotkey = casterInput.hotkey,
							modifiers = casterInput.modifiers,
						}, {
							hotkey = defaultKeybinds.gamepad[casterInputKey].primary,
							modifiers = defaultKeybinds.gamepad[casterInputKey].modifiers,
						}) and Gui.button(`{Icon.Undo}##{casterInputKey}`)
					then
						local defaultValue = defaultKeybinds.gamepad[casterInputKey]
						inputs.gamepad[casterInputKey].modifiers = defaultValue.modifiers
						inputs.gamepad[casterInputKey].hotkey = defaultValue.primary
					end
				end
				Gui.endTable()
			end
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
					arenas = {}
					arenaLoadTime = os.clock()
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
			for _, arena: Arena in arenas do
				if Gui.selectable(arena.name, arena.name == selectedArena.name) then
					setSelectedArena(arena)
				end
			end
		end
		Gui.endCombo()
	end
	Gui.setItemTooltip("The currently selected arena")

	local currentTime = os.clock()
	if math.round(((currentTime - arenaLoadTime) / getArenaDelay) * 100) < 100 then
		Gui.text(`Loading Arenas... ({math.round(((currentTime - arenaLoadTime) / getArenaDelay) * 100)}%)`)
	end

	Gui.newLine()
	cameraFOV = Gui.sliderFloat("Field Of View", cameraFOV, 1, 179)
	cameraFOV = math.clamp(cameraFOV, 1, 179)

	camera.position = Gui.dragFloat3("Camera Position", camera.position, 1, -math.huge, math.huge)
	local newRot = Gui.dragFloat3("Camera Rotation", rotEuler, 1, -180, 180)
	if Gui.isItemActive() then
		gravityChaser = gravity.upRotation
		rotEuler = newRot
		camera.rotation = Quat.fromEuler(rotEuler.x, rotEuler.y, rotEuler.z)
	end

	Gui.text(`Get Player Method: {getBallVariant}`)
	Gui.newLine()

	Gui.text("Settings")
	if Gui.collapsingHeader("Smoothing") then
		Gui.indent()
		positionSmoothing = Gui.sliderFloat("Position Smoothing", positionSmoothing, 0, 1)
		positionSmoothing = math.clamp(positionSmoothing, 0, 1)
		lookSmoothness = Gui.sliderFloat("Rotation Smoothing", lookSmoothness, 0, 1)
		lookSmoothness = math.clamp(lookSmoothness, 0, 1)
		Gui.unindent()
		Gui.newLine()
	end

	if Gui.collapsingHeader("Sensitivity & Deadzone") then
		Gui.indent()
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

			if Gui.button(Icon.Upload .. " Send Teams to Overlay") then
				sendMessage(overlayCamera, {
					info = "teamNames",
					value = {
						home = homeTeam,
						away = awayTeam,
					},
				})
				homeTeam = ""
				awayTeam = ""
			end

			Gui.newLine()

			if not addRound then
				if Gui.button("Add Previous Round") then
					addRound = true
				end
				Gui.setItemTooltip("Add info about a round that ended before you started casting")
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
		Gui.text(`Version: {version}`)
		boundingBoxDebug = Gui.checkbox("show boxes", boundingBoxDebug)
		if Gui.button("Print Arenas") then
			for _, arena in arenas do
				print(arena.slotId)
			end
		end
		Gui.sameLine()
		if Gui.button("Print Gamemode Ids") then
			for _, gamemodeId in SpectatorGamemodes.listGamemodeIds() do
				print(gamemodeId)
			end
		end
		if selectedArena and Gui.button("Set Orientation to Arena") then
			camera.position = selectedArena.transform.position
			camera.rotation = selectedArena.transform.rotation
			rotEuler = (selectedArena.transform.rotation * gravity.upRotation:inverse()):euler()
		end
		Gui.sameLine()
		if selectedArena and Gui.button("Print Relative Orientation") then
			local RelativeLocation =
				selectedArena.transform.rotation:rotateVector(camera.position - selectedArena.transform.position)
			local RelativeRotation = camera.rotation * selectedArena.transform.rotation:inverse()
			print(`Relative Position ({selectedArena.name}):`)
			print(RelativeLocation)
			print(`Relative Rotation ({selectedArena.name}):`)
			print(RelativeRotation:euler())
		end
		if Gui.button("Reset All Stats") then
			sendMessage(overlayCamera, {
				info = "clearStats",
			})
		end
		if Gui.button("Print Pressed Keys") then
			print(pressedInputKeys)
		end
		if selectedArena then
			Gui.sameLine()
			if Gui.button("Print Selected Arena") then
				print(selectedArena)
			end
			if Gui.treeNode("Selected Arena Dimensions") then
				selectedArena:GUIChangeDimensions()
				Gui.treePop()
			end
		end
		Gui.text(tostring("Vertical:" .. Vertical))
		Gui.text(tostring("Horizontal: " .. Horizontal))
		Gui.text("Camera Rotation: " .. tostring(camera.rotation:euler()))
		Gui.text("Target Speed Gear: " .. tostring(targetSpeedIndex))
		Gui.text("Current Speed Gear: " .. tostring(currentSpeedIndex))
		Gui.text("Gear Shift Time: " .. tostring(gearShiftTime))
		if selectedArena then
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
end

function toggleSmoothing(position: boolean, rotation: boolean)
	if position then
		camera.positionSmoothing = positionSmoothing
	else
		camera.positionSmoothing = 0
	end
	if rotation then
		camera.rotationSmoothing = 0.02
		dynamicLookSmoothness = lookSmoothness
	else
		camera.rotationSmoothing = 0
		dynamicLookSmoothness = 0
	end
end

function onTransitionBegin(transitionInfo: Transition)
	transitionTime = os.clock()
	firstTransition = transitionTime <= loadTime + 1 -- Margin of 1 second

	if firstTransition then
		camera.position = defaultPosition
		camera.rotation = defaultRotation
		rotEuler = defaultRotation:euler()
		rotEuler.x = 0
	else
		camera.position = transitionInfo.startPosition
		camera.rotation = transitionInfo.startRotation
		rotEuler = transitionInfo.startRotation:euler()
		rotEuler.x = 0
	end

	alwaysTick = true
	camera.rotationSmoothing = 0.02
	camera.hideNearestHead = false
	camera.showNameTags = true
end

function getReplayFrameFromIndex(replayIndex)
	replayIndex = math.clamp(replayIndex, 0, #Replay.listLoaded())
	local replay = Replay.getByIndex(replayIndex)
	if replay then
		return replay:getCurrentFrame(true)
	else
		-- 0 = live game
		return getGameData()
	end
end

function getDist(point1: Vec3, point2: Vec3): number
	local x: number = math.abs(point1.x - point2.x) ^ 2
	local y: number = math.abs(point1.y - point2.y) ^ 2
	local z: number = (point1.z - point2.z) ^ 2
	return math.sqrt(x + y + z)
end

function isBetweenVector(n: Vec3, min: Vec3, max: Vec3, up: Vec3): boolean
	local nHeight = n:dot(up)
	local minHeight = min:dot(up)
	local maxHeight = max:dot(up)

	return nHeight >= minHeight and nHeight <= maxHeight
end

function isBetween(n: number, min: number, max: number): boolean
	if n > min and n < max then
		return true
	else
		return false
	end
end

function getForward(positionA: Vec3, positionB: Vec3): Vec3
	local forward: Vec3 = Vec3.new((positionB.x - positionA.x), (positionB.y - positionA.y), positionB.z - positionA.z)
		:normalize()
	return forward
end

function findPlayerInTable(table: { ReplayPlayer }, player: ReplayPlayer): number?
	local index = nil
	for i, tablePlayer: ReplayPlayer in table do
		if tablePlayer.playerId == player.playerId then
			index = i
		end
	end
	return index
end

function velocityPivotPosition(position: Vec3, velocity: Vec3, radius: number, ball: boolean): Vec3
	local velocityPivot = Vec3.zeroVector

	local cameraDirection = velocity:getSafeNormal() + ballRotation:euler():normalize() * 20
	if not ball then
		cameraDirection = -cameraDirection
	end

	velocityPivot = Vec3.lerp(camera.position, position + cameraDirection * radius, 10)

	velocityPivot = position + cameraDirection * radius

	return velocityPivot
end

function getClosestArena(targetPosition: Vec3): Arena -- Remove this function when/if we get the arena from the player
	local closestArenaDistance = math.huge
	local closestArena = nil
	for _, arena: Arena in pairs(arenas) do
		local distance = getDist(targetPosition, arena.transform.position)
		-- because some arenas are directly above others
		-- we limit the arenas to those where the player is between the arenas floor and roof position
		if not arena.box:checkPointIntersect(targetPosition) then
			continue
		end
		if distance < closestArenaDistance then
			closestArenaDistance = distance
			closestArena = arena
		end
	end

	-- if the camera is placed in such a way that it is not leveled with any arena we loop again without limiting height
	if closestArena == nil then
		for _, arena: Arena in pairs(arenas) do
			local distance = getDist(targetPosition, arena.transform.position)
			if distance < closestArenaDistance then
				closestArenaDistance = distance
				closestArena = arena
			end
		end
	end

	return closestArena
end

function getClosestBall(targetPosition: Vec3, frameData: ReplayFrame): ReplayBall
	local balls = frameData.balls
	local closestBallDistance = math.huge
	local clostestBall: ReplayBall = nil
	for i in balls do
		local ball = balls[i]
		local distance = getDist(targetPosition, ball.transform.position)
		if distance < closestBallDistance then
			closestBallDistance = distance
			clostestBall = ball
		end
	end
	return clostestBall
end

function getClosestArenaBall(targetPosition: Vec3, frameData: ReplayFrame)
	local balls = frameData.balls
	local closestBallDistance = math.huge
	local clostestBall: ReplayBall = nil
	for i in balls do
		local ball = balls[i]

		if not selectedArena.box:checkPointIntersect(ball.transform.position) then
			continue
		end
		local distance = getDist(targetPosition, ball.transform.position)
		if distance < closestBallDistance and parseBallJSON(ball:toJson()).type ~= 2 then
			closestBallDistance = distance
			clostestBall = ball
		end
	end
	return clostestBall
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

		local headDistance = getDist(ball.transform.position, headPosition)
		local leftHandDistance = getDist(ball.transform.position, leftHandPosition)
		local rightHandDistance = getDist(ball.transform.position, rightHandPosition)

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

		local playerDistance = getDist(camera.position, player.root.position)
		local calculatedScreenPosition = camera.position + (cameraForward * playerDistance)
		local lineOfSightDistance = getDist(calculatedScreenPosition, player.root.position)

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
	local playerIndex = findPlayerInTable(selectedArena.players, tryGetPlayer)
	if playerIndex == nil then
		return
	end
	currentPlayerIndex = playerIndex
	followPlayer()
end

function stopFollow()
	toggleSmoothing(true, true)
	playerFollow = false
	camera:followCamera(nil)
	camera.position = followPlussCamera:getSmoothedPosition()
	rotEuler = followPlussCamera:getSmoothedRotation():euler()
	rotEuler.x = 0
	currentPlayer = nil
	camera.fieldOfView = cameraFOV
	camera.hideNearestHead = false
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
	WorldDraw.clear()
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
			local function dot(v1: Vec3, v2: Vec3): number
				return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
			end

			if particle.variant == ParticleVariant.Embers then
				local hit = camera:castRay(particle.position, particle.velocity + particle.position)
				if hit.successful then
					local dotProduct = dot(particle.velocity, hit.normal)
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
		Vec3.new(0, 0, 10),
		colourAverage,
		ParticleVariant.Rings,
		600
	)
	createParticle(
		particlePosition,
		selectedArena.transform.rotation,
		0.7,
		Vec3.new(0, 0, 2),
		colourAverage,
		ParticleVariant.Rings,
		400
	)
	local colourPallette = { homeTeamPrimaryColor, awayTeamPrimaryColor }
	for i = 1, 300 do
		createParticle(
			particlePosition,
			selectedArena.transform.rotation,
			0.5,
			Vec3.new(math.random(-30, 30), math.random(-30, 30), math.random(20, 80)),
			colourPallette[math.random(1, 2)],
			ParticleVariant.Embers,
			math.random(800, 1300)
		)
	end
end
--effects end

function readInput()
	readOtherInputs()
	readMoveInput()
	readUpInput()
end

function readOtherInputs()
	if keyToBeRebinded.key ~= "" then
		-- don't read inputs on rebind
		return
	end

	cameraFOV -= Input.getAnalog(mouseWheelAxis) * 10

	if getCasterKey(inputs.gamepad.zoomIn).held and getCasterKey(inputs.gamepad.zoomOut).held then
		cameraFOV += 0
	elseif getCasterKey(inputs.gamepad.zoomIn).held then
		cameraFOV -= 50 * deltaTime
	elseif getCasterKey(inputs.gamepad.zoomOut).held then
		cameraFOV += 50 * deltaTime
	end

	cameraFOV = math.clamp(cameraFOV, 1, 179)

	if getCasterKey(inputs.keyboard.resetFOV).down or getCasterKey(inputs.gamepad.resetFOV).down then
		cameraFOV = config.cameraFOV
	end

	if getCasterKey(inputs.keyboard.speedUp).down or getCasterKey(inputs.gamepad.speedUp).down then
		if targetSpeedIndex == #speedGears - 2 then
			speedLastGearBuffer = true
		end
		targetSpeedIndex = math.min(targetSpeedIndex + 1, #speedGears - 1)
	end
	if getCasterKey(inputs.keyboard.speedDown).down or getCasterKey(inputs.gamepad.speedDown).down then
		targetSpeedIndex = math.max(targetSpeedIndex - 1, 1)
	end

	if getCasterKey(inputs.keyboard.speedUp).up or getCasterKey(inputs.gamepad.speedUp).up then
		if speedLastGearBuffer then
			speedLastGearBuffer = false
		end

		if targetSpeedIndex == #speedGears then
			targetSpeedIndex -= 1
		end
	end

	if
		(getCasterKey(inputs.keyboard.speedUp).held or getCasterKey(inputs.gamepad.speedUp).held)
		and targetSpeedIndex >= #speedGears - 1
		and not speedLastGearBuffer
	then
		targetSpeedIndex = #speedGears
	end

	if selectedArena == nil then
		return
	end

	if getCasterKey(inputs.keyboard.getClosestArena).down or getCasterKey(inputs.gamepad.getClosestArena).down then
		setSelectedArena(getClosestArena(camera.position))
	end

	if getCasterKey(inputs.keyboard.clearOverlayInfo).down or getCasterKey(inputs.gamepad.clearOverlayInfo).down then
		sendMessage(overlayCamera, {
			info = "clearStats",
		})
	end

	if ball and (getCasterKey(inputs.keyboard.overview1).down or getCasterKey(inputs.gamepad.overview1).down) then
		if playerFollow then
			stopFollow()
		end
		toggleSmoothing(false, false)
		if selectedArena:isPointOnHomeSide(ball.transform.position) then
			camera.position = selectedArena.home.overview[1].position
			setGlobalCameraRotation(selectedArena.home.overview[1].rotation)
		else
			camera.position = selectedArena.away.overview[1].position
			setGlobalCameraRotation(selectedArena.away.overview[1].rotation)
		end
	end
	if ball and (getCasterKey(inputs.keyboard.overview2).down or getCasterKey(inputs.gamepad.overview2).down) then
		if playerFollow then
			stopFollow()
		end
		toggleSmoothing(false, false)
		if selectedArena:isPointOnHomeSide(ball.transform.position) then
			camera.position = selectedArena.home.overview[2].position
			setGlobalCameraRotation(selectedArena.home.overview[2].rotation)
		else
			camera.position = selectedArena.away.overview[2].position
			setGlobalCameraRotation(selectedArena.away.overview[2].rotation)
		end
	end
	if ball and (getCasterKey(inputs.keyboard.overview3).down or getCasterKey(inputs.gamepad.overview3).down) then
		if playerFollow then
			stopFollow()
		end
		toggleSmoothing(false, false)
		if selectedArena:isPointOnHomeSide(ball.transform.position) then
			camera.position = selectedArena.home.overview[3].position
			setGlobalCameraRotation(selectedArena.home.overview[3].rotation)
		else
			camera.position = selectedArena.away.overview[3].position
			setGlobalCameraRotation(selectedArena.away.overview[3].rotation)
		end
	end

	if getCasterKey(inputs.keyboard.lineOfSight).down or getCasterKey(inputs.gamepad.lineOfSight).down then
		getBallVariant = GetBallVariant.LineOfSight
	end

	if
		getCasterKey(inputs.keyboard.playerBallDistance).down or getCasterKey(inputs.gamepad.playerBallDistance).down
	then
		getBallVariant = GetBallVariant.PlayerBallDistance
	end

	if getCasterKey(inputs.keyboard.thirdPerson).down or getCasterKey(inputs.gamepad.thirdPerson).down then
		if currentPlayer == nil or cameraMode == thirdPersonMode then
			cameraMode = thirdPersonMode
			getPlayer()
		else
			cameraMode = thirdPersonMode
			followPlayer()
		end
	end

	if getCasterKey(inputs.keyboard.firstPerson).down or getCasterKey(inputs.gamepad.firstPerson).down then
		if currentPlayer == nil or cameraMode == CameraMode.FirstPerson then
			cameraMode = CameraMode.FirstPerson
			getPlayer()
		else
			cameraMode = CameraMode.FirstPerson
			followPlayer()
		end
	end

	if getCasterKey(inputs.keyboard.freeCam).down or getCasterKey(inputs.gamepad.freeCam).down then
		if playerFollow then
			stopFollow()
		end
	end

	if
		playerFollow
		and (getCasterKey(inputs.gamepad.previousPlayer).down or getCasterKey(inputs.keyboard.previousPlayer).down)
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
		and (getCasterKey(inputs.gamepad.nextPlayer).down or getCasterKey(inputs.keyboard.nextPlayer).down)
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
	if keyToBeRebinded.key ~= "" then
		-- don't read inputs on rebind
		return
	end

	local input = math.abs(getCasterAnalog(inputs.gamepad.moveY)) + math.abs(getCasterAnalog(inputs.gamepad.moveX))
	if input > deadzone then
		Vertical = getCasterAnalog(inputs.gamepad.moveY)
		Horizontal = getCasterAnalog(inputs.gamepad.moveX)
		return
	else
		if getCasterKey(inputs.keyboard.forwards).held and getCasterKey(inputs.keyboard.backwards).held then
			Vertical = 0
		elseif getCasterKey(inputs.keyboard.forwards).held then
			Vertical = 1
		elseif getCasterKey(inputs.keyboard.backwards).held then
			Vertical = -1
		else
			Vertical = 0
		end

		if getCasterKey(inputs.keyboard.right).held and getCasterKey(inputs.keyboard.left).held then
			Horizontal = 0
		elseif getCasterKey(inputs.keyboard.right).held then
			Horizontal = 1
		elseif getCasterKey(inputs.keyboard.left).held then
			Horizontal = -1
		else
			Horizontal = 0
		end
	end
end

function readUpInput()
	if keyToBeRebinded.key ~= "" then
		-- don't read inputs on rebind
		return
	end

	if getCasterKey(inputs.gamepad.down).held or getCasterKey(inputs.gamepad.up).held then
		if getCasterKey(inputs.gamepad.down).held and getCasterKey(inputs.gamepad.up).held then
			Up = 0
		elseif getCasterKey(inputs.gamepad.up).held then
			Up = 1
		elseif getCasterKey(inputs.gamepad.down).held then
			Up = -1
		else
			Up = 0
		end
		return
	end

	if getCasterKey(inputs.keyboard.down).held and getCasterKey(inputs.keyboard.up).held then
		Up = 0
	elseif getCasterKey(inputs.keyboard.up).held then
		Up = 1
	elseif getCasterKey(inputs.keyboard.down).held then
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

	local speedMultiplier = lerp(
		speedGears[math.max(currentSpeedIndex - 1, 1)],
		speedGears[currentSpeedIndex],
		gearShiftTime / gearShiftTimeRequired
	)

	local forwardMovement = forwardDirection * Vertical * speedMultiplier * 100 * deltaTime
	local sidewaysMovement = rightDirection * Horizontal * speedMultiplier * 100 * deltaTime
	local upwardsMovement = upDirection * Up * speedMultiplier * 50 * deltaTime

	camera.position += (forwardMovement + sidewaysMovement + upwardsMovement)
end

function setGlobalCameraRotation(globalRotation)
	camera.rotation = globalRotation
	local localRotation = gravity.upRotation:inverse() * globalRotation
	rotEuler = localRotation:euler()
end

local rotDelta: Vec3 = Vec3.zeroVector
function rotateCamera()
	if keyToBeRebinded.key ~= "" then
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
	if getCasterKey(inputs.keyboard.lookAround).held then
		turnVelocity = Vec2.new(mouse.x, mouse.y) * 10
		rotDelta += Vec3.new(0, turnVelocity.y, turnVelocity.x) * mouseSensitivity
	end

	-- Gamepad
	turnVelocity = Vec2.new(getCasterAnalog(inputs.gamepad.lookX), getCasterAnalog(inputs.gamepad.lookY))
		* controllerSensitivity
		* 2

	if invertControllerLookHorizontal then
		turnVelocity.x = -turnVelocity.x
	end

	if invertControllerLookVertical then
		turnVelocity.y = -turnVelocity.y
	end

	rotDelta += Vec3.new(0, turnVelocity.y, turnVelocity.x)

	local nextLookDiff = rotDelta * math.min((1 - adjustedLookSmoothness) * deltaTime * 60, 1)

	if gravityChaser ~= gravity.upRotation then
		local nextGravityChaser = gravity.upRotation

		local nextRotation = nextGravityChaser:inverse()
			* Quat.fromXZ(camera.rotation:getForwardVector(), nextGravityChaser:rotateVector(Vec3.new(0, 0, 1)))
		rotEuler = nextRotation:euler() + Vec3.new(rotEuler.x, 0, 0) -- preserve existing roll
		gravityChaser = nextGravityChaser
	end

	rotEuler += nextLookDiff
	rotDelta -= nextLookDiff

	rotEuler.y = math.clamp(rotEuler.y, -89.99, 89.99)
	camera.rotation = gravityChaser * Quat.fromEuler(rotEuler.x, rotEuler.y, rotEuler.z)
end

-- Custom function to extract the primary color
function extractPrimaryColor(json: string): Color
	local r: number? = tonumber(json:match('"primary"%s*:%s*{.-"r"%s*:%s*(%d+)'))
	local g: number? = tonumber(json:match('"primary"%s*:%s*{.-"g"%s*:%s*(%d+)'))
	local b: number? = tonumber(json:match('"primary"%s*:%s*{.-"b"%s*:%s*(%d+)'))

	if r == nil or g == nil or b == nil then
		return { r = 0, b = 0, g = 0 }
	end

	return { r = r / 255, g = g / 255, b = b / 255 } :: Color
end

function followPlayer()
	playerFollow = true
	local message: MessageValues = {
		readLocation = readLocation,
		showNameTags = true,
		muteSelf = false,
		targetPlayer = currentPlayer,
		positionSmoothing = followPosititonSmoothing,
		cameraFOV = followFOV,
		cameraMode = cameraMode,
		radius = followRadius,
		threshold = 5,
		cameraPositionOffset = tostring(Vec3.zeroVector),
		cameraEulerOffset = tostring(Vec3.zeroVector),
		gestureControls = false,
		autoBall = false,
		autoGoalCam = false,
		showQuests = false,
	}
	toggleSmoothing(false, false)
	sendMessage(followPlussCamera, message)
	camera:followCamera(followPlussCamera)
end

function playersAreOnSameTeam(player1: ReplayPlayer, player2: ReplayPlayer): boolean
	if player1.teamIndex == TeamIndex.NoTeam or player2.teamIndex == TeamIndex.NoTeam then
		return false
	end

	if player1.teamIndex == player2.teamIndex then
		return true
	end

	return false
end

function resetPlayersWithBall()
	lastPlayerWithBall = nil
	previousLastPlayerWithBall = nil
end

function checkForPlayerBallContact(): ReplayPlayer?
	local contactPlayer: ReplayPlayer? = getClosestPlayerToBall(30)
	if contactPlayer ~= nil then
		lastPlayerBallContactPoint = contactPlayer.root.position
		if lastPlayerWithBall ~= nil and contactPlayer.playerId == lastPlayerWithBall.playerId then
			return lastPlayerWithBall
		end
		return contactPlayer
	end
	return lastPlayerWithBall
end

function getAssistPlayer()
	if lastPlayerWithBall == nil or previousLastPlayerWithBall == nil then
		return
	end

	if
		playersAreOnSameTeam(lastPlayerWithBall, previousLastPlayerWithBall)
		and lastPlayerWithBall.playerId ~= previousLastPlayerWithBall.playerId
	then
		assistPlayer = previousLastPlayerWithBall
		timeSincePass = 0
	elseif not playersAreOnSameTeam(lastPlayerWithBall, previousLastPlayerWithBall) then
		assistPlayer = nil
	end

	if assistPlayer then
		timeSincePass += deltaTime
		if timeSincePass >= maximumTimeSincePass then
			timeSincePass = 0
			assistPlayer = nil
		end
	end
end

function checkForGoalPotential(): boolean
	local successfulPotential = false

	if lastPlayerWithBall == nil then
		return successfulPotential
	end

	if homeGoalPotentialEnter and not previousHomeGoalPotentialEnter then
		if lastPlayerWithBall.teamIndex == TeamIndex.awayTeam then
			goalPlayer = lastPlayerWithBall
			successfulPotential = true
		end
	end

	if awayGoalPotentialEnter and not previousAwayGoalPotentialEnter then
		if lastPlayerWithBall.teamIndex == TeamIndex.homeTeam then
			goalPlayer = lastPlayerWithBall
			successfulPotential = true
		end
	end

	return successfulPotential
end

function checkForSave(goal: { team: string, dist: number }): boolean
	local goalie = getClosestPlayerToBall(60)

	local successfulSave = false

	if goal.team == "home" then
		if
			not homeGoalPotentialEnter
			and previousHomeGoalPotentialEnter
			and goal.dist <= 600
			and goalie
			and goalie.teamIndex == TeamIndex.homeTeam
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
	elseif goal.team == "away" then
		if
			not awayGoalPotentialEnter
			and previousAwayGoalPotentialEnter
			and goal.dist <= 600
			and goalie
			and goalie.teamIndex == TeamIndex.awayTeam
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

	previousLastPlayerWithBall = lastPlayerWithBall
	previousHomeGoalPotentialEnter = homeGoalPotentialEnter
	previousAwayGoalPotentialEnter = awayGoalPotentialEnter
end

function checkPotentialStatChange(homeGoalBox: BoxType, awayGoalBox: BoxType)
	if selectedArena.isGracePeriod then
		earlyStatChangeReturn(true)
		return
	end

	local ballToHomeGoalDist = getDist(ball.transform.position, homeGoalBox.position)
	local ballToAwayGoalDist = getDist(ball.transform.position, awayGoalBox.position)
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
			local distanceLeft = getDist(homeHit.position, homeGoalBox.position)

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
			local distanceLeft = getDist(awayHit.position, awayGoalBox.position)

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

	lastPlayerWithBall = checkForPlayerBallContact()

	getAssistPlayer()

	if checkForGoalPotential() then
		earlyStatChangeReturn(false)
		return
	end

	if checkForSave(closestGoal) then
		earlyStatChangeReturn(false)
		return
	end

	previousLastPlayerWithBall = lastPlayerWithBall
	previousHomeGoalPotentialEnter = homeGoalPotentialEnter
	previousAwayGoalPotentialEnter = awayGoalPotentialEnter
end

function goalScoreCheck()
	local homeGoalBox: BoxType = selectedArena.home.goal.box
	local awayGoalBox: BoxType = selectedArena.away.goal.box

	if not selectedArena.isGameActive or selectedArena.actionTimerSeconds > 0 then
		return
	end

	checkPotentialStatChange(homeGoalBox, awayGoalBox)

	-- the ball has newely scored
	if selectedArena.away.scoreIncrease then
		GoalExplosionEffect(
			selectedArena.home.goal.position + Vec3.new(0, 0, -60),
			selectedArena.home.goal.rotation,
			awayTeamPrimaryColor
		)

		local shooterName = ""
		local assistName = ""

		if lastPlayerWithBall then
			shooterName = lastPlayerWithBall.playerName
		end

		if assistPlayer then
			assistName = assistPlayer.playerName
		end

		sendSafeMessage(overlayCamera, {
			info = "shot",
			value = {
				shooter = shooterName, -- use lastPlayerWithBall instead of goalPlayer incase it is a self goal
				assister = assistName,
				team = "away",
				shotSpeed = ball.velocity:length() / 100,
				shotDistanceMeters = getDist(lastPlayerBallContactPoint, ball.transform.position) / 100,
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
		GoalExplosionEffect(
			selectedArena.away.goal.position + Vec3.new(0, 0, -60),
			selectedArena.home.goal.rotation,
			homeTeamPrimaryColor
		)

		local shooterName = ""
		local assistName = ""

		if lastPlayerWithBall then
			shooterName = lastPlayerWithBall.playerName
		end

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
				shotDistanceMeters = getDist(lastPlayerBallContactPoint, ball.transform.position) / 100,
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
	if #gameData.players > 0 and #selectedArena.home.players > 0 then
		local firstPlayer = selectedArena.home.players[1]
		local playerJson = firstPlayer:toJson()
		homeTeamPrimaryColor = extractPrimaryColor(playerJson)
	else
		homeTeamPrimaryColor = {
			r = math.round(homeTeamDefaultColor.r * 100) / 100,
			g = math.round(homeTeamDefaultColor.g * 100) / 100,
			b = math.round(homeTeamDefaultColor.b * 100) / 100,
		}
	end

	if #gameData.players > 0 and #selectedArena.away.players > 0 then
		local firstPlayer = selectedArena.away.players[1]
		local playerJson = firstPlayer:toJson()
		awayTeamPrimaryColor = extractPrimaryColor(playerJson)
	else
		awayTeamPrimaryColor = {
			r = math.round(awayTeamDefaultColor.r * 100) / 100,
			g = math.round(awayTeamDefaultColor.g * 100) / 100,
			b = math.round(awayTeamDefaultColor.b * 100) / 100,
		}
	end
end

function setNewInputTimes(newInputs: { Key })
	for _, newInput in newInputs do
		if newInput then
			local newInputString = keyToString(newInput)

			local conciderModifier = true
			if table.find(modifierKeys, newInputString) ~= nil then
				for key: string, pressedInput in pressedInputKeys :: { [string]: any } do
					if table.find(modifierKeys, key) == nil then
						conciderModifier = false
					end
				end
			else
				conciderModifier = false
			end

			pressedInputKeys[newInputString] = {
				time = os.clock(),
				isModifier = conciderModifier,
			}
		end
	end
end

function removeOldInputTimes()
	local removeKeys = {}
	for keyKey: string, _ in pressedInputKeys do
		local key: Key
		if Input.Key[keyKey] then
			key = Input.Key[keyKey]
		else
			key = Input.Gamepad[keyKey]
		end

		if Input.getKeyDown(key) or Input.getKey(key) then
			continue
		end

		table.insert(removeKeys, keyKey)
	end

	for _, removeKeyKey: string in removeKeys do
		pressedInputKeys[removeKeyKey] = nil
	end
end

function saveKeybinds()
	local keybindsSerilazied = SerializeKeybinds()
	config.keyboardKeybinds = keybindsSerilazied.keybord
	config.gamepadKeybinds = keybindsSerilazied.gamepad
	saveConfig()
end

function removeGamepadKeys(keysList: { Key }): { Key }
	local removeIndexes: { number } = {}
	for i, key: Key in keysList do
		local keyString = keyToString(key)
		if table.find(keyboardKeys, keyString) == nil then
			table.insert(removeIndexes, i)
		end
	end

	for _, index in removeIndexes do
		table.remove(keysList, index)
	end

	return keysList
end

function removeKeyboardKeys(keysList: { Key })
	local removeIndexes: { number } = {}
	for i, key: Key in keysList do
		local keyString = keyToString(key)
		if table.find(keyboardKeys, keyString) ~= nil then
			table.insert(removeIndexes, i)
		end
	end

	for _, index in removeIndexes do
		table.remove(keysList, index)
	end

	return keysList
end

function rebind(primary: string, modifiers: { Key }?)
	if keyToBeRebinded.type == "keyboard" then
		if table.find(keyboardKeys, primary) == nil then
			return
		end

		if modifiers then
			modifiers = removeGamepadKeys(modifiers)
		end

		inputs.keyboard[keyToBeRebinded.key].modifiers = modifiers
		inputs.keyboard[keyToBeRebinded.key].hotkey = Input.Key[primary]
	elseif keyToBeRebinded.type == "gamepad" then
		if table.find(keyboardKeys, primary) ~= nil then
			return
		end

		if modifiers then
			modifiers = removeKeyboardKeys(modifiers)
		end

		inputs.gamepad[keyToBeRebinded.key].modifiers = modifiers
		inputs.gamepad[keyToBeRebinded.key].hotkey = Input.Gamepad[primary]
	end

	keyToBeRebinded.key = ""
	pressedRebindModifiers = {}
	saveKeybinds()
end

function doRebind()
	if getDictSize(pressedInputKeys) == 0 then
		if getDictSize(pressedRebindModifiers) ~= 0 then
			local primary: string
			local biggestTime = 0

			for key: string, pressedRebindInput in pressedRebindModifiers :: { [string]: { time: number } } do
				if pressedRebindInput.time > biggestTime then
					biggestTime = pressedRebindInput.time
					primary = key
				end
			end

			local modifiers = {}
			for key, _ in pressedRebindModifiers do
				if key ~= primary then
					table.insert(modifiers, Input.Key[key])
				end
			end

			rebind(primary, modifiers)
		end

		return
	end

	local newestKey: string
	local biggestTime = 0
	for key, pressedInputInfo in pressedInputKeys do
		if pressedInputInfo.time > biggestTime then
			biggestTime = pressedInputInfo.time
			newestKey = key
		end
	end

	-- newest key is primary
	if table.find(modifierKeys, newestKey) == nil then
		local modifiers = {}

		for key, pressedInputInfo in pressedInputKeys do
			if table.find(modifierKeys, key) ~= nil and pressedInputInfo.isModifier then
				local modifierKey = Input.Key[key]
				if modifierKey == nil then
					modifierKey = Input.Gamepad[key]
				end

				table.insert(modifiers, modifierKey)
			end
		end

		rebind(newestKey, modifiers)
	else
		-- store modifier
		pressedRebindModifiers[newestKey] = {
			time = biggestTime,
		}
	end
end

function tick(dt)
	if not camera.isActive and not camera.isFollowed then
		alwaysTick = false
		onExit()
		return
	end

	if arenas == nil then
		local currentTime = os.clock()
		if currentTime >= arenaLoadTime + getArenaDelay then
			arenas = getArenas()
			if getDictSize(arenas) > 0 then
				setSelectedArena(getDictIndex(arenas, 1))
			end
		end
	end

	setNewInputTimes(getKeyboardKeysDown())
	setNewInputTimes(getGamepadKeysDown())

	if keyToBeRebinded.key ~= "" then
		doRebind()
	end

	deltaTime = dt
	camera.fieldOfView = cameraFOV

	gameData = getReplayFrameFromIndex(readLocation)

	if selectedArena == nil then
		readInput()

		moveCamera()
		rotateCamera()
		return
	end

	ball = getClosestArenaBall(selectedArena.transform.position, gameData)
	selectedArena:tick()

	getTeamColors()

	if Input.getKeyDown(one) then
		GoalExplosionEffect(
			selectedArena.home.goal.position + Vec3.new(0, 0, -60),
			selectedArena.home.goal.rotation,
			awayTeamPrimaryColor
		)
	end

	if Input.getKeyDown(two) then
		GoalExplosionEffect(
			selectedArena.away.goal.position + Vec3.new(0, 0, -60),
			selectedArena.away.goal.rotation,
			homeTeamPrimaryColor
		)
	end

	if Input.getKeyDown(three) then
		GameStartEffect()
	end

	if #gameData.players < 1 and playerFollow then
		stopFollow()
	end

	if playerFollow then
		readOtherInputs()
	else
		toggleSmoothing(true, true)
		readInput()

		moveCamera()
		rotateCamera()
	end

	particleAffect()
	ballInCenterCheck()
	if ball then
		goalScoreCheck()
	end

	removeOldInputTimes()

	if boundingBoxDebug then
		for _, arena in arenas do
			arena.box:render(1, 0, 1)
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
