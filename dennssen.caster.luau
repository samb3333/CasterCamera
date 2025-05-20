local version: string = "1.3.0"
metadata = {
	name = "Caster",
	description = "The Caster camera is a Driftball focused caster tool that let's you access everything from freecam, first person pov, third person pov, 3 different configurable overviews, a cool particle system for goal explosions, and MANY confgurable preferences.",
	author = "Dennssen",
	defaultKeybind = "",
}

--Notes:
-- make speed linearly interpolate when switching gears
-- clean up config with more "Categories" like post processing has
-- ballCam?

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
	for _, _ in dict do
		i += 1
	end

	return i
end

function keyToString(key: Key): string
	return string.gsub(tostring(key), "Gamepad_", "")
end

local deltaTime: number = 0

local loadTime: number
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

type BoxType = {
	__index: BoxType,
	position: Vec3,
	size: Vec3,
	rotation: Vec3,
	vertexLocations: { Vec3 },

	__tostring: (self: BoxType) -> string,
	new: (inputPosition: Vec3, inputSize: Vec3, inputRotation: Vec3) -> BoxType,
	setPosition: (self: BoxType, inputPosition: Vec3) -> (),
	setSize: (self: BoxType, inputPosition: Vec3) -> (),
	setRotation: (self: BoxType, inputPosition: Vec3) -> (),
	setRotationDeg: (self: BoxType, inputRotation: Vec3) -> (),
	getPosition: (self: BoxType) -> Vec3,
	getSize: (self: BoxType) -> Vec3,
	getRotation: (self: BoxType) -> Vec3,
	getRotationDeg: (self: BoxType) -> Vec3,
	generatePoints: (self: BoxType) -> (),
	multiplyMatrices: (self: BoxType, matrix1: { { number } }, matrix2: { { number } }) -> { { number } },
	applyRotationMatrix: (self: BoxType, vec: Vec3, matrix: { { number } }) -> Vec3,
	render: (self: BoxType, r: number, g: number, b: number) -> (),
	checkPointIntersect: (self: BoxType, point: Vec3) -> boolean,
}

local Box: BoxType = {} :: BoxType
Box.__index = Box

function Box.new(inputPosition: Vec3, inputSize: Vec3, inputRotation: Vec3): BoxType
	local self: BoxType = setmetatable({}, Box) :: any

	self.position = inputPosition
	self.size = inputSize
	self.rotation = Vec3.new(math.rad(inputRotation.x), math.rad(inputRotation.y), math.rad(inputRotation.z))

	self.vertexLocations = {}
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

function Box:setRotation(inputRotation: Vec3): ()
	self.rotation = inputRotation
	self:generatePoints()
end

function Box:setRotationDeg(inputRotation: Vec3): ()
	inputRotation.x = (inputRotation.x * math.pi) / 180
	inputRotation.y = (inputRotation.y * math.pi) / 180
	inputRotation.z = (inputRotation.z * math.pi) / 180
	self.rotation = inputRotation
	self:generatePoints()
end

function Box:getPosition(): Vec3
	return Vec3.new(self.position.x, self.position.y, self.position.z)
end

function Box:getSize(): Vec3
	return Vec3.new(self.size.x, self.size.y, self.size.z)
end

function Box:getRotation(): Vec3
	return Vec3.new(self.rotation.x, self.rotation.y, self.rotation.z)
end

function Box:getRotationDeg(): Vec3
	return Vec3.new(
		(self.rotation.x * 180) / math.pi,
		(self.rotation.y * 180) / math.pi,
		(self.rotation.z * 180) / math.pi
	)
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

	local rotationQuat = Quat.fromEuler(math.deg(self.rotation.x), math.deg(self.rotation.y), math.deg(self.rotation.z))

	for i = 1, #newVertexLocations do
		newVertexLocations[i] = rotationQuat:rotateVector(newVertexLocations[i])
	end

	-- Translate the vertices by the box position.
	for i = 1, #newVertexLocations do
		newVertexLocations[i].x = newVertexLocations[i].x + self.position.x
		newVertexLocations[i].y = newVertexLocations[i].y + self.position.y
		newVertexLocations[i].z = newVertexLocations[i].z + self.position.z
	end

	self.vertexLocations = newVertexLocations
end

function Box:multiplyMatrices(matrix1: { { number } }, matrix2: { { number } }): { { number } }
	local result: { { number } } = {}
	for i = 1, 3 do
		result[i] = {}
		for j = 1, 3 do
			result[i][j] = 0
			for k = 1, 3 do
				result[i][j] = result[i][j] + matrix1[i][k] * matrix2[k][j]
			end
		end
	end
	return result
end

function Box:applyRotationMatrix(vec: Vec3, matrix: { { number } }): Vec3
	local x = vec.x * matrix[1][1] + vec.y * matrix[1][2] + vec.z * matrix[1][3]
	local y = vec.x * matrix[2][1] + vec.y * matrix[2][2] + vec.z * matrix[2][3]
	local z = vec.x * matrix[3][1] + vec.y * matrix[3][2] + vec.z * matrix[3][3]
	return Vec3.new(x, y, z)
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

	World.drawPoint(self.position, 0.2, 3, 0.2, 5, 0)
	for i: number, line: { start: Vec3, finish: Vec3 } in lines do
		World.drawLine(line.start, line.finish, r, g, b, 4, 0)
	end

	local rotationQuat = Quat.fromEuler(math.deg(self.rotation.x), math.deg(self.rotation.y), math.deg(self.rotation.z))
	World.drawLine(self.position, self.position + rotationQuat:getForwardVector() * 100, 1, 0, 0, 10, 0)
	World.drawLine(self.position, self.position + rotationQuat:getUpVector() * 100, 0, 1, 0, 10, 0)
	World.drawLine(self.position, self.position + rotationQuat:getRightVector() * 100, 0, 0, 1, 10, 0)
end

function Box:checkPointIntersect(point: Vec3): boolean
	if point == nil then
		return false
	end

	local zeroPoint: Vec3 = self.vertexLocations[1]
	local fullPoint: Vec3 = self.vertexLocations[8]
	local centerPoint: Vec3 = (zeroPoint + fullPoint) / 2

	local projectionVector: Vec3 = point - centerPoint

	-- Thanks to MrStick, Brick_Rage, and RAD_David
	local xLocal = self.vertexLocations[5] - self.vertexLocations[1]
	local yLocal = self.vertexLocations[3] - self.vertexLocations[1]
	local zLocal = self.vertexLocations[2] - self.vertexLocations[1]

	local pX: number = math.abs(Vec3.dot(projectionVector, xLocal:getSafeNormal()))
	local pY: number = math.abs(Vec3.dot(projectionVector, yLocal:getSafeNormal()))
	local pZ: number = math.abs(Vec3.dot(projectionVector, zLocal:getSafeNormal()))

	if 2 * pX <= xLocal:length() and 2 * pY <= yLocal:length() and 2 * pZ <= zLocal:length() then
		return true
	else
		return false
	end
end

type MessageValues = {
	readLocation: number?,
	showNameTags: boolean?,
	isLeftHanded: boolean?,
	muteSelf: boolean?,
	targetPlayerName: string?,
	targetPlayerId: number?,
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
}

type Color = {
	r: number,
	g: number,
	b: number,
}

type Particle = {
	position: Vec3,
	rotation: Vec3,
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

type Arena = {
	name: string,
	position: Vec3,
	rotation: Quat, -- Rotated Towards Home
	box: BoxType,
	home: {
		overview: {
			{
				position: Vec3,
				rotation: Vec3,
			}
		},
		goal: {
			position: Vec3,
			rotation: Quat,
		},
		midfield: {
			position: Vec3,
		},
		players: { ReplayPlayer },
	},
	away: {
		overview: {
			{
				position: Vec3,
				rotation: Quat,
			}
		},
		goal: {
			position: Vec3,
			rotation: Quat,
		},
		midfield: {
			position: Vec3,
		},
		players: { ReplayPlayer },
	},
	players: { ReplayPlayer },
}

function createArena(name: string, position: Vec3, rotation: Quat): Arena
	return {
		name = name,
		position = position,
		rotation = rotation,
		box = nil,
		home = {
			overview = {},
			goal = nil,
			midfield = {
				position = nil,
			},
			players = {},
		},
		away = {
			overview = {},
			goal = nil,
			midfield = {
				position = nil,
			},
			players = {},
		},
		players = {},
	}
end

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
		sendOverlayInfo = false,
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

-- goal
local goalPositionOffset = 3150
local goalHeightOffset = Vec3.new(0, 0, -50)
local homeGoalRotationOffset = Quat.fromEuler(0, 0, 180)
local awayGoalRotationOffset = Quat.fromEuler(0, 0, 0)

--arena
local overviewOffsets = {}
for _, overview in config.overviewOffsets do
	table.insert(overviewOffsets, overview)
end

local midfieldOffset = 840
local midfieldMaxTime = 20
local midfieldTimePassed: number = 0

local requiredBallCenterTime: number = 5
local ballCenterTime: number = 0

local boxPositionOffset = Vec3.new(0, 0, 425)
local boxSize = Vec3.new(6750, 5100, 1440)

local arenas: { [any]: Arena } = {
	gatewayArena = createArena("Gateway Arena", Vec3.new(0, 9900, -29650), Quat.fromEuler(0, 0, 0)),
	plazaEast = createArena("Plaza East", Vec3.new(-4425, 18550, -29650), Quat.fromEuler(0, 0, 90)),
	plazaWest = createArena("Plaza West", Vec3.new(4425, 18550, -29650), Quat.fromEuler(0, 0, -90)),
	stadiumPrime = createArena("Stadium Prime", Vec3.new(0, 27250, -28050), Quat.fromEuler(0, 0, 0)),
	theBunker = createArena("The Bunker", Vec3.new(-112.6, 24944.6, -31545), Quat.fromEuler(0, 0, 180)),
	fieldhouseEast = createArena("Fieldhouse East", Vec3.new(-4500, 27100, -29850), Quat.fromEuler(0, 0, 90)),
	fieldhouseWest = createArena("Fieldhouse West", Vec3.new(4500, 27100, -29850), Quat.fromEuler(0, 0, -90)),
	driftplex1 = createArena("Driftplex 01", Vec3.new(12799.231, 13600.000, -27568.920), Quat.fromEuler(30, 0, 90)),
	driftplex2 = createArena("Driftplex 02", Vec3.new(17475.770, 13600.000, -24868.920), Quat.fromEuler(-30, 0, -90)),
	driftplex3 = createArena("Driftplex 03", Vec3.new(12799.231, 6400.000, -27568.920), Quat.fromEuler(30, 0, 90)),
	driftplex4 = createArena("Driftplex 04", Vec3.new(17475.770, 6400.000, -24868.920), Quat.fromEuler(-30, 0, -90)),
	driftplex5 = createArena("Driftplex 05", Vec3.new(17475.770, 23200.000, -24868.920), Quat.fromEuler(-30, 0, -90)),
	driftplex6 = createArena("Driftplex 06", Vec3.new(12799.231, 23200.000, -27568.920), Quat.fromEuler(30, 0, 90)),
	driftplexLab = createArena("Driftplex Lab", Vec3.new(15137.500, 29200.000, -26218.920), Quat.fromEuler(0, 30, 0)),
}

for _, arena in pairs(arenas) do
	arena.box =
		Box.new(arena.position + arena.rotation:rotateVector(boxPositionOffset), boxSize, arena.rotation:euler())

	for _, overview in overviewOffsets do
		local homeOverview = {
			position = arena.position + arena.rotation:rotateVector(overview.position),
			rotation = (arena.rotation * overview.rotation),
		}
		local awayOverview = {
			position = arena.position + (arena.rotation * Quat.fromEuler(0, 0, 180)):rotateVector(overview.position),
			rotation = (arena.rotation * Quat.fromEuler(0, 0, 180) * overview.rotation),
		}

		table.insert(arena.home.overview, homeOverview)
		table.insert(arena.away.overview, awayOverview)
	end

	arena.home.goal = {
		position = arena.position
			+ arena.rotation:rotateVector(goalHeightOffset)
			+ arena.rotation:getForwardVector() * goalPositionOffset,
		rotation = arena.rotation * homeGoalRotationOffset,
	}
	arena.away.goal = {
		position = arena.position
			+ arena.rotation:rotateVector(goalHeightOffset)
			+ arena.rotation:getForwardVector() * -goalPositionOffset,
		rotation = arena.rotation * awayGoalRotationOffset,
	}

	arena.home.midfield = {
		position = arena.position + arena.rotation:getForwardVector() * midfieldOffset,
	}
	arena.away.midfield = {
		position = arena.position + arena.rotation:getForwardVector() * -midfieldOffset,
	}
end

function updateArenaOverviews()
	overviewOffsets = {}
	for _, overview in config.overviewOffsets do
		table.insert(overviewOffsets, overview)
	end

	for _, arena in arenas do
		arena.home.overview = {}
		arena.away.overview = {}

		for _, overview in overviewOffsets do
			local homeOverview = {
				position = arena.position + arena.rotation:rotateVector(overview.position),
				rotation = (arena.rotation * overview.rotation),
			}
			local awayOverview = {
				position = arena.position
					+ (arena.rotation * Quat.fromEuler(0, 0, 180)):rotateVector(overview.position),
				rotation = (arena.rotation * Quat.fromEuler(0, 0, 180) * overview.rotation),
			}

			table.insert(arena.home.overview, homeOverview)
			table.insert(arena.away.overview, awayOverview)
		end
	end
end

local selectedArena: Arena = arenas.gatewayArena

-- Particles
local homeGoalEnter: boolean = false
local previousHomeGoalEnter: boolean = false
local awayGoalEnter: boolean = false
local previousAwayGoalEnter: boolean = false
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
local isSafeTime: boolean = false
local homeGoalPotentialEnter: boolean = false
local previousHomeGoalPotentialEnter: boolean = false
local awayGoalPotentialEnter: boolean = false
local previousAwayGoalPotentialEnter: boolean = false

local maximumTimeSincePass: number = 5
local timeSincePass: number = 0

local assistPlayer: ReplayPlayer? = nil
local goalPlayer: ReplayPlayer? = nil

-- Gravity
local gravityChaser: Quat = gravity.upRotation

-- GameData
local readLocation = 0
local gameData: ReplayFrame

-- Caster Camera
local cameraFOV = config.cameraFOV
local cameraMode = nil
local positionSmoothing = config.positionSmoothing
local lookSmoothness = config.lookSmoothness
local dynamicLookSmoothness = lookSmoothness
local speedIndex: number = 1
local speedGears = {
	5,
	10,
	15,
	25,
}
local speedMultiplierHoldBuffer = false
local speedGearMultiplier = 1
local turnVelocity: Vec2 = Vec2.zeroVector

-- Follow Camera
local followPlussCamera: SpectatorCamera = nil
local playerFollow = false
local currentPlayerName: string = ""
local currentPlayerId: number = -1
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

-- Overlay Camera
local overlayCamera: SpectatorCamera = nil
local usingOverlay: boolean = false
local sendOverlayInfo: boolean = config.sendOverlayInfo
local homeTeam: string = ""
local awayTeam: string = ""

-- Ball
local ball: ReplayBall
local ballRotation: Quat = Quat.identity
local GetBallVariant = {
	PlayerBallDistance = "PlayerBallDistance",
	LineOfSight = "LineOfSight",
}
local getBallVariant = config.getBallVariant

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

function getAnyGamepadKeyDown(): Key?
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

			return Input.Gamepad[key]
		end
	end
	return nil
end

function getAnyKeyboardKeyDown()
	local bannedInputs = {}

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

			return Input.Key[key]
		end
	end
	return nil
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
	}
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
local overviewMessage = {
	overviewNumber = 0,
	message = "",
}

function main()
	loadTime = os.clock()
	camera.position = defaultPosition
	camera.rotation = defaultRotation
	rotEuler = defaultRotation:euler()
	followPlussCamera = getCameraById("dennssen.followpluss")
	overlayCamera = getCameraById("dennssen.overlayInfo")
	if overlayCamera ~= nil then
		usingOverlay = true
	end
	print(pressedInputKeys)
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
	local closestArena: Arena = getClosestArena(globalOverviewPosition)

	if not closestArena.box:checkPointIntersect(globalOverviewPosition) then
		return "Overviews cannot be outside an arena!"
	end

	local isOnHomeSide = closestArena.rotation
		:getForwardVector()
		:dot(getForward(closestArena.position, globalOverviewPosition)) >= 0

	local translatedOverviewPosition
	local translatedOverviewRotation
	if isOnHomeSide then
		translatedOverviewPosition =
			closestArena.rotation:inverse():rotateVector(globalOverviewPosition - closestArena.position)
		translatedOverviewRotation = closestArena.rotation:inverse() * globalOverviewRotation
	else
		local flipQuat = closestArena.rotation:inverse() * Quat.fromEuler(0, 0, 180)
		translatedOverviewPosition = flipQuat:rotateVector(globalOverviewPosition - closestArena.position)
		translatedOverviewRotation = flipQuat * globalOverviewRotation
	end

	config.overviewOffsets[overviewKey] = {
		position = translatedOverviewPosition,
		rotation = translatedOverviewRotation,
	}
	saveConfig()
	updateArenaOverviews()
	return `Succesfully set Overview #{overviewKey} to Camera`
end

function onGui()
	if followPlussCamera == nil then
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
				if readLocation ~= i then
					selectedArena.home.players = {}
					selectedArena.away.players = {}
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
		selectedArena = getClosestArena(camera.position)
		selectedArena.home.players = {}
		selectedArena.away.players = {}
	end
	Gui.setItemTooltip("Gets the closest arena | For most accuracy be inside the arena when pressing")

	if Gui.beginCombo("Selected Arena", selectedArena.name) then
		for _, arena in arenas do
			if Gui.selectable(arena.name, arena.name == selectedArena.name) then
				selectedArena = arena
			end
		end
		Gui.endCombo()
	end
	Gui.newLine()
	Gui.setItemTooltip("The currently selected arena")

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

		if Gui.button("Save Post Processing to Preset") then
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

	if Gui.collapsingHeader("POV") then
		Gui.indent()

		followFOV = Gui.sliderInt("Field of View", followFOV, 1, 179)
		Gui.setItemTooltip("Sets the FOV for when the camera is in POV mode")
		followFOV = math.clamp(followFOV, 1, 179)

		followPosititonSmoothing = Gui.sliderFloat("Position Smoothing##2", followPosititonSmoothing, 0, 1)
		Gui.setItemTooltip("Sets the smoothing for when the camera is in POV mode")
		followPosititonSmoothing = math.clamp(followPosititonSmoothing, 0, 1)

		Gui.newLine()

		if Gui.beginCombo("Third Person Mode", CAMERA_MODE_NAMES[thirdPersonMode]) then
			for key, value in THIRD_PERSON_MODES do
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

	if Gui.collapsingHeader("Overviews") then
		Gui.indent()

		for i, overview in overviewOffsets do
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
			sendOverlayInfo = Gui.checkbox("Send Overlay Info", sendOverlayInfo)
			Gui.setItemTooltip(
				"Toggle this off to stop the camera from sending info to the overlay even if you have the overlay script \nThis is useful if you don't want the script to reload because you have pressed F5 (spectator bug)"
			)

			Gui.newLine()

			homeTeam = Gui.inputText("Home Team Name", homeTeam)
			awayTeam = Gui.inputText("Away Team Name", awayTeam)

			if Gui.button(Icon.Upload .. "Send Teams to Overlay") then
				sendMessage(overlayCamera, {
					info = "teamNames",
					value = {
						home = homeTeam,
						away = awayTeam,
					},
				})
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
		if Gui.button("Print Closest Gamemode") then
			local gamemode = camera:getClosestGamemodeSlot()
			print("Gamemode SlotID: ")
			print(gamemode.slotId)
			print("Gamemode Position: ")
			print(gamemode.transform.position)
			print("Gamemode Rotation: ")
			print(gamemode.transform.rotation:euler())
		end
		if Gui.button("Set Orientation to Arena") then
			camera.position = selectedArena.position
			rotEuler = selectedArena.rotation:euler()
			camera.rotation = selectedArena.rotation
		end
		Gui.sameLine()
		if Gui.button("Print Relative Orientation") then
			local RelativeLocation = selectedArena.rotation:rotateVector(camera.position - selectedArena.position)
			local RelativeRotation = camera.rotation * selectedArena.rotation:inverse()
			print(`Relative Position ({selectedArena.name}):`)
			print(RelativeLocation)
			print(`Relative Rotation ({selectedArena.name}):`)
			print(RelativeRotation:euler())
		end
		if Gui.button("Reset All Stats") then
			sendMessage(overlayCamera, { resetAllStats = true })
		end
		Gui.sameLine()
		if Gui.button("Reset Inactive Stats") then
			sendMessage(overlayCamera, { resetInactiveStats = true })
		end
		Gui.text(tostring("Vertical:" .. Vertical))
		Gui.text(tostring("Horizontal: " .. Horizontal))
		Gui.text("Camera Rotation: " .. tostring(camera.rotation:euler()))
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
	if replayIndex > 0 and Replay.getByIndex(replayIndex) then
		return Replay.getByIndex(replayIndex):getCurrentFrame(true)
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
	for _, arena in pairs(arenas) do
		local distance = getDist(targetPosition, arena.position)
		-- because some arenas are directly above others
		-- we limit the arenas to those where the player is between the arenas floor and roof position
		if not selectedArena.box:checkPointIntersect(targetPosition) then
			continue
		end
		if distance < closestArenaDistance then
			closestArenaDistance = distance
			closestArena = arena
		end
	end

	-- if the camera is placed in such a way that it is not leveled with any arena we loop again without limiting height
	if closestArena == nil then
		for _, arena in pairs(arenas) do
			local distance = getDist(targetPosition, arena.position)
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

		local rootDistance = getDist(ball.transform.position, root.position)
		local headDistance = getDist(ball.transform.position, headPosition)
		local leftHandDistance = getDist(ball.transform.position, leftHandPosition)
		local rightHandDistance = getDist(ball.transform.position, rightHandPosition)

		local minimumDistance = math.min(rootDistance, headDistance, leftHandDistance, rightHandDistance)

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
	if followPlussCamera == nil then
		return
	end

	local tryGetPlayer: ReplayPlayer?

	if getBallVariant == GetBallVariant.PlayerBallDistance then
		tryGetPlayer = getClosestPlayerToBall()
	else
		tryGetPlayer = getClosestPlayerToLineOfSight()
	end

	if tryGetPlayer then
		currentPlayerName = tryGetPlayer.playerName
		currentPlayerId = tryGetPlayer.playerId
	else
		return
	end
	local playerIndex = findPlayerInTable(selectedArena.players, tryGetPlayer)
	if playerIndex == nil then
		return
	else
		currentPlayerIndex = playerIndex
	end
	followPlayer()
end

function stopFollow()
	toggleSmoothing(true, true)
	playerFollow = false
	camera:followCamera(nil)
	camera.position = followPlussCamera:getSmoothedPosition()
	rotEuler = followPlussCamera:getSmoothedRotation():euler()
	rotEuler.x = 0
	currentPlayerName = ""
	camera.fieldOfView = cameraFOV
	camera.hideNearestHead = false
end

-- particle start
function createParticle(
	position: Vec3,
	rotation: Vec3,
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

function transformRot(vertices, origin, angle)
	local cosTheta = math.cos(math.rad(angle))
	local sinTheta = math.sin(math.rad(angle))

	local translatedX = vertices.x - origin.x
	local translatedY = vertices.y - origin.y

	local rotatedX = translatedX * cosTheta - translatedY * sinTheta
	local rotatedY = translatedX * sinTheta + translatedY * cosTheta

	local finalX = rotatedX + origin.x
	local finalY = rotatedY + origin.y

	return Vec3.new(finalX, finalY, vertices.z)
end

function particleAffect()
	World.clear()
	if #particlesTable < 1 then
		return
	end

	for i, particle: Particle in ipairs(particlesTable) do
		--LIFE DURATION
		particle.aliveTime -= 1 * particleSimSpeed

		if particle.aliveTime < 0 then
			table.remove(particlesTable, i)
		end

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

		--remove tiny particles
		if particle.scale < 0.01 then
			table.remove(particlesTable, i)
		end

		--draw parts
		if particle.variant == ParticleVariant.Embers or particle.variant == ParticleVariant.Rocket then
			World.drawLine(
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
			--local r = 100
			local resolution = 90
			local theta = 2 * math.pi / resolution
			local z = particle.position.z - 40

			local prevX = r * math.cos(0) + particle.position.x
			local prevY = r * math.sin(0) + particle.position.y

			for i = 1, resolution do
				local currentX = r * math.cos(i * theta) + particle.position.x
				local currentY = r * math.sin(i * theta) + particle.position.y

				World.drawLine(
					Vec3.new(prevX, prevY, z),
					Vec3.new(currentX, currentY, z),
					particle.Color.r,
					particle.Color.g,
					particle.Color.b,
					particle.scale * 90,
					0
				)

				prevX = currentX
				prevY = currentY
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
				World.drawLine(
					transformRot(goalOutline[i] + particle.position, particle.position, particle.rotation.z),
					transformRot(goalOutline[i + 1] + particle.position, particle.position, particle.rotation.z),
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
function GoalExplosionEffect(goalPosition: Vec3, particleColor: Color)
	for i = 1, 300 do
		local velocityVector = Vec3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
		createParticle(
			goalPosition,
			Vec3.zeroVector,
			0.3,
			velocityVector,
			particleColor,
			ParticleVariant.Embers,
			math.random(800, 1300)
		)
	end
	createParticle(
		goalPosition,
		selectedArena.rotation:euler(),
		0.9,
		Vec3.zeroVector,
		particleColor,
		ParticleVariant.Rings,
		150
	)

	--rings
	createParticle(
		goalPosition,
		selectedArena.rotation:euler(),
		1,
		Vec3.zeroVector,
		particleColor,
		ParticleVariant.Rings,
		200
	)
	createParticle(
		goalPosition,
		selectedArena.rotation:euler(),
		1,
		Vec3.zeroVector,
		particleColor,
		ParticleVariant.Rings,
		400
	)

	--goal outline
	local goalSpeed = 20
	for i = 1, 3 do
		createParticle(
			goalPosition,
			selectedArena.rotation:euler(),
			1,
			(selectedArena.position - goalPosition):normalize() * goalSpeed,
			particleColor,
			ParticleVariant.GoalRing,
			400
		)
		goalSpeed /= 2
	end
end

function GameStartEffect()
	local colourAverage = {
		r = homeTeamPrimaryColor.r + awayTeamPrimaryColor.r / 2,
		g = homeTeamPrimaryColor.g + awayTeamPrimaryColor.g / 2,
		b = homeTeamPrimaryColor.b + awayTeamPrimaryColor.b / 2,
	}
	createParticle(
		selectedArena.position + Vec3.new(0, 0, 100),
		Vec3.zeroVector,
		0.9,
		Vec3.zeroVector,
		colourAverage,
		ParticleVariant.Rings,
		150
	)
	createParticle(
		selectedArena.position + Vec3.new(0, 0, 100),
		Vec3.zeroVector,
		0.7,
		Vec3.new(0, 0, 10),
		colourAverage,
		ParticleVariant.Rings,
		600
	)
	createParticle(
		selectedArena.position + Vec3.new(0, 0, 100),
		Vec3.zeroVector,
		0.7,
		Vec3.new(0, 0, 2),
		colourAverage,
		ParticleVariant.Rings,
		400
	)
	local colourPallette = { homeTeamPrimaryColor, awayTeamPrimaryColor }
	for i = 1, math.random(50, 80) do
		createParticle(
			selectedArena.position - Vec3.new(0, 0, 100),
			Vec3.zeroVector,
			0.5,
			Vec3.new(math.random(-30, 30), math.random(-30, 30), math.random(20, 80)),
			colourPallette[math.random(1, 2)],
			ParticleVariant.Embers,
			math.random(800, 1300)
		)
	end
end
--effects end

function ballIsOnHomeSide(): boolean
	local arenaForward = selectedArena.rotation:getForwardVector()
	local ballRelativePosition = ball.transform.position - selectedArena.position
	if arenaForward:dot(ballRelativePosition) >= 0 then -- ball is in front of arena
		return true
	else
		return false
	end
end

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
		if speedIndex == #speedGears - 1 then
			speedMultiplierHoldBuffer = true
		end
		speedIndex += 1
	end
	if getCasterKey(inputs.keyboard.speedDown).down or getCasterKey(inputs.gamepad.speedDown).down then
		speedIndex -= 1
	end
	speedIndex = math.clamp(speedIndex, 1, #speedGears)

	if
		speedMultiplierHoldBuffer
		and (getCasterKey(inputs.keyboard.speedUp).up or getCasterKey(inputs.gamepad.speedUp).up)
	then
		speedMultiplierHoldBuffer = false
	end

	if getCasterKey(inputs.keyboard.getClosestArena).down or getCasterKey(inputs.gamepad.getClosestArena).down then
		selectedArena = getClosestArena(camera.position)
		selectedArena.home.players = {}
		selectedArena.away.players = {}
	end

	if getCasterKey(inputs.keyboard.clearOverlayInfo).down or getCasterKey(inputs.gamepad.clearOverlayInfo).down then
		sendMessage(overlayCamera, {
			info = "clearStats",
		})
	end

	if
		(getCasterKey(inputs.keyboard.speedUp).held or getCasterKey(inputs.gamepad.speedUp).held)
		and speedIndex == #speedGears
		and not speedMultiplierHoldBuffer
	then
		speedGearMultiplier = 2
	else
		speedGearMultiplier = 1
	end

	if getCasterKey(inputs.keyboard.overview1).down or getCasterKey(inputs.gamepad.overview1).down then
		if playerFollow then
			stopFollow()
		end
		toggleSmoothing(false, false)
		if ballIsOnHomeSide() then
			camera.position = selectedArena.home.overview[1].position
			setGlobalCameraRotation(selectedArena.home.overview[1].rotation)
		else
			camera.position = selectedArena.away.overview[1].position
			setGlobalCameraRotation(selectedArena.away.overview[1].rotation)
		end
	end
	if getCasterKey(inputs.keyboard.overview2).down or getCasterKey(inputs.gamepad.overview2).down then
		if playerFollow then
			stopFollow()
		end
		toggleSmoothing(false, false)
		if ballIsOnHomeSide() then
			camera.position = selectedArena.home.overview[2].position
			setGlobalCameraRotation(selectedArena.home.overview[2].rotation)
		else
			camera.position = selectedArena.away.overview[2].position
			setGlobalCameraRotation(selectedArena.away.overview[2].rotation)
		end
	end
	if getCasterKey(inputs.keyboard.overview3).down or getCasterKey(inputs.gamepad.overview3).down then
		if playerFollow then
			stopFollow()
		end
		toggleSmoothing(false, false)
		if ballIsOnHomeSide() then
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
		if currentPlayerName == "" or cameraMode == thirdPersonMode then
			cameraMode = thirdPersonMode
			getPlayer()
		else
			cameraMode = thirdPersonMode
			followPlayer()
		end
	end

	if getCasterKey(inputs.keyboard.firstPerson).down or getCasterKey(inputs.gamepad.firstPerson).down then
		if currentPlayerName == "" or cameraMode == CameraMode.FirstPerson then
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
		currentPlayerName = selectedArena.players[currentPlayerIndex].playerName
		currentPlayerId = selectedArena.players[currentPlayerIndex].playerId
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
		currentPlayerName = selectedArena.players[currentPlayerIndex].playerName
		currentPlayerId = selectedArena.players[currentPlayerIndex].playerId
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

	local speedMultiplier = speedGears[speedIndex] * speedGearMultiplier

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

function teamLists()
	local tempHome = {}
	local tempAway = {}

	for _, player in gameData.players do
		if player.teamIndex == TeamIndex.NoTeam then
			continue
		end

		if not selectedArena.box:checkPointIntersect(player.root.position) then
			continue
		end

		if player.teamIndex == TeamIndex.homeTeam then
			table.insert(tempHome, player)
		elseif player.teamIndex == TeamIndex.awayTeam then
			table.insert(tempAway, player)
		end
	end

	selectedArena.home.players = tempHome
	selectedArena.away.players = tempAway

	local allPlayers = {}
	for _, player in selectedArena.home.players do
		table.insert(allPlayers, player)
	end
	for _, player in selectedArena.away.players do
		table.insert(allPlayers, player)
	end
	selectedArena.players = allPlayers
end

-- Custom function to extract the primary color
function extractPrimaryColor(json)
	local r = json:match('"primary"%s*:%s*{.-"r"%s*:%s*(%d+)')
	local g = json:match('"primary"%s*:%s*{.-"g"%s*:%s*(%d+)')
	local b = json:match('"primary"%s*:%s*{.-"b"%s*:%s*(%d+)')

	return { r = tostring(r / 255), g = tostring(g / 255), b = tostring(b / 255) }
end

function followPlayer()
	playerFollow = true
	local message: MessageValues = {
		readLocation = readLocation,
		showNameTags = true,
		muteSelf = false,
		targetPlayerId = currentPlayerId,
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
	}
	toggleSmoothing(false, false)
	sendMessage(followPlussCamera, message)
	camera:followCamera(followPlussCamera)
end

function playersAreOnSameTeam(player1: ReplayPlayer, player2: ReplayPlayer): boolean
	local sameTeam = false
	if
		findPlayerInTable(selectedArena.home.players, player1)
		and findPlayerInTable(selectedArena.home.players, player2)
	then
		sameTeam = true
	end

	if
		findPlayerInTable(selectedArena.away.players, player1)
		and findPlayerInTable(selectedArena.away.players, player2)
	then
		sameTeam = true
	end

	return sameTeam
end

function goalExitCheck()
	if not homeGoalEnter and not awayGoalEnter then
		return
	end

	local isHomeGoal: boolean
	if homeGoalEnter and not awayGoalEnter then
		isHomeGoal = true
	else
		isHomeGoal = false
	end
	local ballPosition = ball.transform.position
	local midfieldPosition

	if isHomeGoal then
		midfieldPosition = selectedArena.home.midfield.position
	else
		midfieldPosition = selectedArena.away.midfield.position
	end

	local baseAxis = Vec3.new(1, 0, 0)
	local crossingAxis = selectedArena.rotation:rotateVector(baseAxis)

	local relativePosition = ballPosition - midfieldPosition
	local projection = Vec3.dot(relativePosition, crossingAxis)

	if (isHomeGoal and projection < 0) or (not isHomeGoal and projection > 0) then
		isSafeTime = false
		if isHomeGoal then
			homeGoalEnter = false
		else
			awayGoalEnter = false
		end
		return
	end

	midfieldTimePassed += deltaTime

	if midfieldTimePassed >= midfieldMaxTime then
		isSafeTime = false
		if isHomeGoal then
			homeGoalEnter = false
		else
			awayGoalEnter = false
		end
		return
	end
end

function sendArenaInfo()
	if not usingOverlay or not sendOverlayInfo then
		return
	end

	local homePlayerNames = {}
	local awayPlayerNames = {}
	for _, player in selectedArena.home.players do
		table.insert(homePlayerNames, player.playerName)
	end
	for _, player in selectedArena.away.players do
		table.insert(awayPlayerNames, player.playerName)
	end

	sendMessage(overlayCamera, {
		info = "players",
		value = {
			team = "home",
			players = homePlayerNames,
		},
	})
	sendMessage(overlayCamera, {
		info = "players",
		value = {
			team = "away",
			players = awayPlayerNames,
		},
	})

	sendMessage(overlayCamera, {
		info = "color",
		value = {
			team = "home",
			color = homeTeamPrimaryColor,
		},
	})
	sendMessage(overlayCamera, {
		info = "color",
		value = {
			team = "away",
			color = awayTeamPrimaryColor,
		},
	})

	sendMessage(overlayCamera, {
		info = "followedPlayer",
		value = currentPlayerName,
	})
end

function resetPlayersWithBall()
	lastPlayerWithBall = nil
	previousLastPlayerWithBall = nil
end

function checkForPlayerBallContact(): ReplayPlayer?
	local contactPlayer: ReplayPlayer? = getClosestPlayerToBall(30)
	if contactPlayer ~= nil then
		if lastPlayerWithBall ~= nil and contactPlayer.playerId == lastPlayerWithBall.playerId then
			return lastPlayerWithBall
		end
		return contactPlayer
	end
	return lastPlayerWithBall
end

function checkForAssist()
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
		if findPlayerInTable(selectedArena.away.players, lastPlayerWithBall) then
			goalPlayer = lastPlayerWithBall
			successfulPotential = true
		end
	end

	if awayGoalPotentialEnter and not previousAwayGoalPotentialEnter then
		if findPlayerInTable(selectedArena.home.players, lastPlayerWithBall) then
			goalPlayer = lastPlayerWithBall
			successfulPotential = true
		end
	end

	return successfulPotential
end

function checkForSave(homeDist: number, awayDist: number): boolean
	local goalie = getClosestPlayerToBall(60)

	local successfulSave = false
	if not homeGoalPotentialEnter and previousHomeGoalPotentialEnter then
		if homeDist <= 600 then
			if goalie and findPlayerInTable(selectedArena.home.players, goalie) then
				successfulSave = true

				resetPlayersWithBall()

				sendMessage(overlayCamera, {
					info = "stats",
					value = {
						team = "home",
						stat = "saves",
						player = goalie.playerName,
					},
				})
			end
		end
	end

	if not awayGoalPotentialEnter and previousAwayGoalPotentialEnter then
		if awayDist <= 600 then
			if goalie and findPlayerInTable(selectedArena.away.players, goalie) then
				successfulSave = true

				resetPlayersWithBall()

				sendMessage(overlayCamera, {
					info = "stats",
					value = {
						team = "away",
						stat = "saves",
						player = goalie.playerName,
					},
				})
			end
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
	if isSafeTime then
		earlyStatChangeReturn(true)
		return
	end

	local ballToHomeGoalDist = getDist(ball.transform.position, homeGoalBox.position)
	local ballToAwayGoalDist = getDist(ball.transform.position, awayGoalBox.position)
	local ballHomePotentialPosition = ball.transform.position + (ball.velocity:normalize() * ballToHomeGoalDist)
	local ballAwayPotentialPosition = ball.transform.position + (ball.velocity:normalize() * ballToAwayGoalDist)

	local homeHit = camera:castRay(ball.transform.position, ballHomePotentialPosition)
	local awayHit = camera:castRay(ball.transform.position, ballAwayPotentialPosition)

	if homeHit.successful then
		local velocityDotNormal = ball.velocity:dot(homeHit.normal)
		local reflectedVelocityNormalized = (ball.velocity - (homeHit.normal * (2 * velocityDotNormal))):normalize()
		local distanceLeft = getDist(homeHit.position, homeGoalBox.position)

		ballHomePotentialPosition = homeHit.position + (reflectedVelocityNormalized * distanceLeft)
	end

	if awayHit.successful then
		local velocityDotNormal = ball.velocity:dot(awayHit.normal)
		local reflectedVelocityNormalized = (ball.velocity - (awayHit.normal * (2 * velocityDotNormal))):normalize()
		local distanceLeft = getDist(awayHit.position, awayGoalBox.position)

		ballAwayPotentialPosition = awayHit.position + (reflectedVelocityNormalized * distanceLeft)
	end

	if
		homeGoalBox:checkPointIntersect(ballHomePotentialPosition) or homeGoalBox:checkPointIntersect(homeHit.position)
	then
		homeGoalPotentialEnter = true
	else
		homeGoalPotentialEnter = false
	end

	if
		awayGoalBox:checkPointIntersect(ballAwayPotentialPosition) or awayGoalBox:checkPointIntersect(awayHit.position)
	then
		awayGoalPotentialEnter = true
	else
		awayGoalPotentialEnter = false
	end

	lastPlayerWithBall = checkForPlayerBallContact()

	checkForAssist()

	if checkForGoalPotential() then
		earlyStatChangeReturn(false)
		return
	end

	if checkForSave(ballToHomeGoalDist, ballToAwayGoalDist) then
		earlyStatChangeReturn(false)
		return
	end

	previousLastPlayerWithBall = lastPlayerWithBall
	previousHomeGoalPotentialEnter = homeGoalPotentialEnter
	previousAwayGoalPotentialEnter = awayGoalPotentialEnter
end

function goalScoreCheck()
	local homeGoalBox: BoxType = Box.new(
		selectedArena.home.goal.position + (selectedArena.rotation:getForwardVector() * 135),
		Vec3.new(100, 500, 225),
		selectedArena.home.goal.rotation:euler()
	)
	if boundingBoxDebug then
		homeGoalBox:render(0, 1, 0)
	end
	local awayGoalBox: BoxType = Box.new(
		selectedArena.away.goal.position - (selectedArena.rotation:getForwardVector() * 135),
		Vec3.new(100, 500, 225),
		selectedArena.away.goal.rotation:euler()
	)
	if boundingBoxDebug then
		awayGoalBox:render(0, 1, 0)
	end

	checkPotentialStatChange(homeGoalBox, awayGoalBox)

	if homeGoalBox:checkPointIntersect(ball.transform.position) then
		homeGoalEnter = true
	end

	if awayGoalBox:checkPointIntersect(ball.transform.position) then
		awayGoalEnter = true
	end

	-- the ball has newely scored
	if homeGoalEnter and not previousHomeGoalEnter then
		isSafeTime = true
		GoalExplosionEffect(selectedArena.home.goal.position + Vec3.new(0, 0, -60), awayTeamPrimaryColor)
		midfieldTimePassed = 0

		sendMessage(overlayCamera, {
			info = "score",
			value = {
				team = "away",
			},
		})

		if goalPlayer then
			resetPlayersWithBall()

			sendMessage(overlayCamera, {
				info = "stats",
				value = {
					team = "away",
					stat = "goals",
					player = goalPlayer.playerName,
				},
			})

			if assistPlayer then
				sendMessage(overlayCamera, {
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

	if awayGoalEnter and not previousAwayGoalEnter then
		isSafeTime = true
		GoalExplosionEffect(selectedArena.away.goal.position + Vec3.new(0, 0, -60), homeTeamPrimaryColor)
		midfieldTimePassed = 0

		sendMessage(overlayCamera, {
			info = "score",
			value = {
				team = "home",
			},
		})

		if goalPlayer then
			resetPlayersWithBall()

			sendMessage(overlayCamera, {
				info = "stats",
				value = {
					team = "home",
					stat = "goals",
					player = goalPlayer.playerName,
				},
			})
			if assistPlayer then
				sendMessage(overlayCamera, {
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

	goalExitCheck()

	previousHomeGoalEnter = homeGoalEnter
	previousAwayGoalEnter = awayGoalEnter
end

function ballInCenterCheck()
	local centerBox: BoxType = Box.new(
		selectedArena.position + selectedArena.rotation:rotateVector(Vec3.new(0, 0, 75)),
		Vec3.new(50, 50, 125),
		selectedArena.rotation:euler()
	)
	if boundingBoxDebug then
		centerBox:render(0, 0, 1)
	end

	if centerBox:checkPointIntersect(ball.transform.position) then
		ballCenterTime += deltaTime
	else
		if ballCenterTime > requiredBallCenterTime then
			resetPlayersWithBall()
			GameStartEffect()
			if usingOverlay then
				local startTimestamp = os.date("%H:%M:%S", os.time())
				print(startTimestamp)
				sendMessage(overlayCamera, {
					info = "startTime",
					value = startTimestamp,
				})
			end
		end
		ballCenterTime = 0
	end
end

function getTeamColors()
	if #gameData.players > 0 and #selectedArena.home.players > 0 then
		local firstPlayer = selectedArena.home.players[1]
		local playerJson = firstPlayer:toJson()
		homeTeamPrimaryColor = extractPrimaryColor(playerJson)
	else
		homeTeamPrimaryColor = {
			r = tostring(math.round(homeTeamDefaultColor.r * 100) / 100),
			g = tostring(math.round(homeTeamDefaultColor.g * 100) / 100),
			b = tostring(math.round(homeTeamDefaultColor.b * 100) / 100),
		}
	end

	if #gameData.players > 0 and #selectedArena.away.players > 0 then
		local firstPlayer = selectedArena.away.players[1]
		local playerJson = firstPlayer:toJson()
		awayTeamPrimaryColor = extractPrimaryColor(playerJson)
	else
		awayTeamPrimaryColor = {
			r = tostring(math.round(awayTeamDefaultColor.r * 100) / 100),
			g = tostring(math.round(awayTeamDefaultColor.g * 100) / 100),
			b = tostring(math.round(awayTeamDefaultColor.b * 100) / 100),
		}
	end
end

function setNewInputTimes(newInput: Key?)
	if newInput then
		local newInputString = keyToString(newInput)

		local conciderModifier = true
		if table.find(modifierKeys, newInputString) ~= nil then
			for key, pressedInput in pressedInputKeys do
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
	print(keybindsSerilazied.gamepad)
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

			for key, pressedRebindInput in pressedRebindModifiers do
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

	setNewInputTimes(getAnyKeyboardKeyDown())
	setNewInputTimes(getAnyGamepadKeyDown())

	if keyToBeRebinded.key ~= "" then
		doRebind()
	end

	if Input.getKey(Input.Key.N) then
		local test: Key

		test = Input.Key["Å"]
		if test == nil then
			test = Input.Gamepad["LeftShoulder"]
		end

		print(Input.getKey(test))
	end

	deltaTime = dt
	camera.fieldOfView = cameraFOV

	gameData = getReplayFrameFromIndex(readLocation)
	ball = getClosestArenaBall(selectedArena.position, gameData)
	teamLists()

	getTeamColors()

	if Input.getKeyDown(one) then
		GoalExplosionEffect(selectedArena.home.goal.position + Vec3.new(0, 0, -60), awayTeamPrimaryColor)
	end

	if Input.getKeyDown(two) then
		GoalExplosionEffect(selectedArena.away.goal.position + Vec3.new(0, 0, -60), homeTeamPrimaryColor)
	end

	if Input.getKeyDown(three) then
		GameStartEffect()
	end

	if #gameData.players < 1 and playerFollow then
		stopFollow()
	end

	if playerFollow then
		World.clear()
		readOtherInputs()
	else
		toggleSmoothing(true, true)
		readInput()

		moveCamera()
		rotateCamera()
	end

	particleAffect()
	if ball ~= nil then
		goalScoreCheck()
		ballInCenterCheck()
	end
	sendArenaInfo()

	removeOldInputTimes()

	if boundingBoxDebug then
		for _, arena in arenas do
			arena.box:render(1, 0, 1)
		end
	end
end

function onExit()
	if playerFollow then
		stopFollow()
	end
end
