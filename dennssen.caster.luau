metadata = {
	name = "Caster",
	description = "TBD",
	author = "Dennssen",
	defaultKeybind = "",
}

local function parseBallJSON(str)
	-- Table to store the parsed data
	local result = {}

	-- Parse type
	local typeVal = string.match(str, '"type"%s*:%s*([%d]+)')
	result.type = tonumber(typeVal)

	return result
end

function calculateRotatedOffset(position, angleDegrees)
	-- Convert angle from degrees to radians
	local angleRadians = -math.rad(angleDegrees)

	-- Extract original x, y, z from the offset
	local x = position.x
	local y = position.y
	local z = position.z -- z stays the same since we're rotating around Z-axis

	-- Apply 3D rotation around Z-axis
	local newX = x * math.cos(angleRadians) + y * math.sin(angleRadians)
	local newY = -x * math.sin(angleRadians) + y * math.cos(angleRadians)

	-- Return the new rotated offset (with the same Z component)
	return Vec3.new(newX, newY, z)
end

local deltaTime: number = 0

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

type MessageValues = {
	readLocation: number?,
	targetPlayerName: string?,
	targetPlayerId: number?,
	positionSmoothing: number?,
	cameraFOV: number?,
	cameraMode: number?,
	radius: number?,
	threshold: number?,
	cameraPositionOffset: string?,
	cameraEulerOffset: string?,
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
	home: {
		overview: {
			middle: {
				position: Vec3,
				rotation: Vec3,
			},
			right: {
				position: Vec3,
				rotation: Vec3,
			},
			left: {
				position: Vec3,
				rotation: Vec3,
			},
		},
		goal: {
			position: Vec3,
			rotation: Vec3,
		},
		midfield: {
			position: Vec3,
		},
		players: { ReplayPlayer },
	},
	away: {
		overview: {
			middle: {
				position: Vec3,
				rotation: Vec3,
			},
			right: {
				position: Vec3,
				rotation: Vec3,
			},
			left: {
				position: Vec3,
				rotation: Vec3,
			},
		},
		goal: {
			position: Vec3,
			rotation: Vec3,
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
		home = {
			overview = {
				middle = nil,
				right = nil,
				left = nil,
			},
			goal = nil,
			midfield = {
				position = nil,
			},
			players = {},
		},
		away = {
			overview = {
				middle = nil,
				right = nil,
				left = nil,
			},
			goal = nil,
			midfield = {
				position = nil,
			},
			players = {},
		},
		players = {},
	}
end

-- goal
local goalPositionOffset = 3150
local goalHeightOffset = Vec3.new(0, 0, -50)
local homeGoalRotationOffset = Vec3.new(0, 0, 180)
local awayGoalRotationOffset = Vec3.new(0, 0, 0)

--arena
local middleOverviewOffset = Vec3.new(1000, 0, 1000)
local middleOverviewRotationOffset = Vec3.new(0, -35, 0)
local rightOverviewOffset = Vec3.new(1300, 2200, 950)
local rightOverviewRotationOffset = Vec3.new(0, -20, -60)
local leftOverviewOffset = Vec3.new(1300, -2200, 950)
local leftOverviewRotationOffset = Vec3.new(0, -20, 60)

local midfieldOffset = 840
local midfieldMaxTime = 20
local midfieldTimePassed: number = 0

local requiredBallCenterTime: number = 10
local ballCenterTime: number = 0

local arenaFloorOffset = -350
local arenaRoofOffset = 1150

local arenas: { [any]: Arena } = {
	gatewayArena = createArena("Gateway Arena", Vec3.new(0, 9900, -29650), Quat.fromEuler(0, 0, 0)),
	plazaEast = createArena("Plaza East", Vec3.new(-4425, 18550, -29650), Quat.fromEuler(0, 0, 90)),
	plazaWest = createArena("Plaza West", Vec3.new(4425, 18550, -29650), Quat.fromEuler(0, 0, -90)),
	stadiumPrime = createArena("Stadium Prime", Vec3.new(0, 27250, -28050), Quat.fromEuler(0, 0, 0)),
	theBunker = createArena("The Bunker", Vec3.new(-112.6, 24944.6, -31545), Quat.fromEuler(0, 0, 180)),
	fieldhouseEast = createArena("Fieldhouse East", Vec3.new(-4500, 27100, -29850), Quat.fromEuler(0, 0, 90)),
	fieldhouseWest = createArena("Fieldhouse West", Vec3.new(4500, 27100, -29850), Quat.fromEuler(0, 0, -90)),
}

for _, arena in pairs(arenas) do
	arena.home.overview.middle = {
		position = arena.position + calculateRotatedOffset(middleOverviewOffset, arena.rotation:euler().z),
		rotation = middleOverviewRotationOffset + arena.rotation:euler(),
	}
	arena.away.overview.middle = {
		position = arena.position + calculateRotatedOffset(middleOverviewOffset, arena.rotation:euler().z + 180),
		rotation = middleOverviewRotationOffset + arena.rotation:euler() + Vec3.new(0, 0, 180),
	}

	arena.home.overview.right = {
		position = arena.position + calculateRotatedOffset(rightOverviewOffset, arena.rotation:euler().z),
		rotation = rightOverviewRotationOffset + arena.rotation:euler(),
	}
	arena.away.overview.right = {
		position = arena.position + calculateRotatedOffset(rightOverviewOffset, arena.rotation:euler().z + 180),
		rotation = rightOverviewRotationOffset + arena.rotation:euler() + Vec3.new(0, 0, 180),
	}

	arena.home.overview.left = {
		position = arena.position + calculateRotatedOffset(leftOverviewOffset, arena.rotation:euler().z),
		rotation = leftOverviewRotationOffset + arena.rotation:euler(),
	}
	arena.away.overview.left = {
		position = arena.position + calculateRotatedOffset(leftOverviewOffset, arena.rotation:euler().z + 180),
		rotation = leftOverviewRotationOffset + arena.rotation:euler() + Vec3.new(0, 0, 180),
	}

	arena.home.goal = {
		position = arena.position + goalHeightOffset + arena.rotation:getForwardVector() * goalPositionOffset,
		rotation = arena.rotation:euler() + homeGoalRotationOffset,
	}
	arena.away.goal = {
		position = arena.position + goalHeightOffset + arena.rotation:getForwardVector() * -goalPositionOffset,
		rotation = arena.rotation:euler() + awayGoalRotationOffset,
	}

	arena.home.midfield = {
		position = arena.position + arena.rotation:getForwardVector() * midfieldOffset,
	}
	arena.away.midfield = {
		position = arena.position + arena.rotation:getForwardVector() * -midfieldOffset,
	}
end

local function initializeConfig()
	local saveToConfig = false
	local neededValues = {
		cameraFOV = 90,
		deadzone = 0,
		mouseSensitivity = 1,
		controllerSensitivity = 0.5,
		positionSmoothing = 0.02,
		lookSmoothness = 0,
		particleSimSpeed = 1,
		vibrance = 1,
		getBallVariant = "PlayerBallDistance",
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

-- Stats
local lastPlayerWithBall: ReplayPlayer? = nil
local previousLastPlayerWithBall: ReplayPlayer? = nil
local isSafeTime: boolean = false
local homeGoalPotentialEnter: boolean = false
local previousHomeGoalPotentialEnter: boolean = false
local awayGoalPotentialEnter: boolean = false
local previousAwayGoalPotentialEnter: boolean = false

local requiredStealTime = 5
local stealTime = 0

local consideringSteal: boolean = false

local maximumTimeSincePass: number = 5
local timeSincePass: number = 0

local assistPlayer: ReplayPlayer? = nil
local goalPlayer: ReplayPlayer? = nil
local stealPlayer: ReplayPlayer = nil

local lastGoalPlayerName = ""
local lastAssistPlayerName = ""
local startTimestamp = nil

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
local currentPlayerName: string? = nil
local currentPlayerId: number = -1
local currentPlayerIndex: number = 1

-- Overlay Camera
local overlayCamera: SpectatorCamera = nil
local usingOverlay: boolean = false

-- Ball
local ball: ReplayBall
local ballRotation: Quat = Quat.identity
local GetBallVariant = {
	PlayerBallDistance = "PlayerBallDistance",
	LineOfSight = "LineOfSight",
}
local getBallVariant = config.getBallVariant

-- Input
local Vertical: number = 0
local Horizontal: number = 0
local Up: number = 0
local deadzone: number = config.deadzone
local rotEuler: Vec3 = Vec3.zeroVector

--  Keyboard
local wInput = Input.Key.W
local aInput = Input.Key.A
local sInput = Input.Key.S
local dInput = Input.Key.D
local qInput = Input.Key.Q
local eInput = Input.Key.E
local vInput = Input.Key.V
local cInput = Input.Key.C
local zInput = Input.Key.Z
local leftShiftInput = Input.Key.LeftShift
local leftControlInput = Input.Key.LeftControl
local numPadOne = Input.Key.NumPadOne
local numPadTwo = Input.Key.NumPadTwo
local numPadThree = Input.Key.NumPadThree
local one = Input.Key.One
local two = Input.Key.Two
local three = Input.Key.Three
local four = Input.Key.Four
local five = Input.Key.Five
local six = Input.Key.Six
local seven = Input.Key.Seven
local eight = Input.Key.Eight
local nine = Input.Key.Nine
local zero = Input.Key.Zero
local leftAlt = Input.Key.LeftAlt

--  Mouse
local rightMouseButton = Input.Key.RightMouseButton
local middleMouseButton = Input.Key.MiddleMouseButton
local mouseSensitivity: number = config.mouseSensitivity
local mouseWheelAxis = Input.Key.MouseWheelAxis

--  Gamepad
local controllerSensitivity: number = config.controllerSensitivity
local leftAnalogVertical = Input.Gamepad.LeftY
local leftAnalogHorizontal = Input.Gamepad.LeftX
local leftTrigger = Input.Gamepad.LeftTrigger
local rightTrigger = Input.Gamepad.RightTrigger
local leftShoulder = Input.Gamepad.LeftShoulder
local rightShoulder = Input.Gamepad.RightShoulder
local topFaceButton = Input.Gamepad.FaceButton_Top
local bottomFaceButton = Input.Gamepad.FaceButton_Bottom
local leftFaceButton = Input.Gamepad.FaceButton_Left
local rightFaceButton = Input.Gamepad.FaceButton_Right
local dPadUp = Input.Gamepad.DPad_Up
local dPadDown = Input.Gamepad.DPad_Down
local dPadLeft = Input.Gamepad.DPad_Left
local dPadRight = Input.Gamepad.DPad_Right
local leftJoystick = Input.Gamepad.LeftThumbstick
local rightJoystick = Input.Gamepad.RightThumbstick

-- Gui
local controlsScreen: boolean = false
local hoveredArena = ""
local keyboardControls: boolean = true
local controllerControls: boolean = false
local boundingBoxDebug: boolean = false

-- Bounding Box start

export type BoxType = {
	__index: BoxType,
	position: Vec3,
	size: Vec3,
	rotation: Vec3,
	traditionalRotation: Quat,
	vertexLocations: { Vec3 },

	new: (inputPosition: Vec3, inputSize: Vec3, inputRotation: Vec3) -> BoxType,
	generatePoints: (self: BoxType) -> (),
	getRotationMatrix: (self: BoxType, roll: number, pitch: number, yaw: number) -> { { number } },
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
	self.traditionalRotation =
		Quat.fromEuler(math.deg(self.rotation.z), math.deg(self.rotation.y), math.deg(self.rotation.x))

	self.vertexLocations = {}
	self:generatePoints()
	return self
end

function Box:generatePoints(): ()
	local shift: { x: number, y: number, z: number } = { x = self.size.x / 2, y = self.size.y / 2, z = self.size.z / 2 }
	local newVertexLocations: { Vec3 } = {
		Vec3.new(shift.x, shift.y, shift.z),
		Vec3.new(shift.x, shift.y, -shift.z),
		Vec3.new(shift.x, -shift.y, shift.z),
		Vec3.new(shift.x, -shift.y, -shift.z),
		Vec3.new(-shift.x, shift.y, shift.z),
		Vec3.new(-shift.x, shift.y, -shift.z),
		Vec3.new(-shift.x, -shift.y, shift.z),
		Vec3.new(-shift.x, -shift.y, -shift.z),
	}

	local rotationMatrix: { { number } } = self:getRotationMatrix(self.rotation.x, self.rotation.y, self.rotation.z)

	for i: number in newVertexLocations do
		newVertexLocations[i] = self:applyRotationMatrix(newVertexLocations[i], rotationMatrix)
	end
	for i: number in newVertexLocations do
		newVertexLocations[i].x += self.position.x
		newVertexLocations[i].y += self.position.y
		newVertexLocations[i].z += self.position.z
	end

	self.vertexLocations = newVertexLocations
end

function Box:getRotationMatrix(roll: number, pitch: number, yaw: number): { { number } }
	local cos: (number) -> number = math.cos
	local sin: (number) -> number = math.sin

	local yawMatrix: { { number } } = {
		{ cos(yaw), 0, sin(yaw) },
		{ 0, 1, 0 },
		{ -sin(yaw), 0, cos(yaw) },
	}

	local pitchMatrix: { { number } } = {
		{ 1, 0, 0 },
		{ 0, cos(pitch), -sin(pitch) },
		{ 0, sin(pitch), cos(pitch) },
	}

	local rollMatrix: { { number } } = {
		{ cos(roll), -sin(roll), 0 },
		{ sin(roll), cos(roll), 0 },
		{ 0, 0, 1 },
	}

	local combinedMatrix: { { number } } = self:multiplyMatrices(yawMatrix, pitchMatrix)
	combinedMatrix = self:multiplyMatrices(combinedMatrix, rollMatrix)

	return combinedMatrix
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

	World.drawPoint(self.position, r, g, b, 3, 0)
	for i: number, line: { start: Vec3, finish: Vec3 } in lines do
		World.drawLine(line.start, line.finish, r, g, b, 2, 0)
	end
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

function main()
	followPlussCamera = getCameraById("dennssen.followpluss")
	overlayCamera = getCameraById("dennssen.overlayInfo")
	if overlayCamera ~= nil then
		usingOverlay = true
	end
end

function onGui()
	if Gui.button(Icon.Question) then
		controlsScreen = not controlsScreen
	end

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
			Gui.text([[
Controller is HIGHLY RECOMMENDED

Keyboard:
	Modes:
		Z - Freecam Mode
		C - FirstPerson Mode
		V - ThirdPerson Mode

	In Freecam mode:
		WASD - Horizontal Movement
		QE - Vertical Movement
		Right Mouse + Mouse Move - Rotating
		LeftShift - Gear Increase
		LeftControl - Gear Decrease
		Left Alt + E - "Get Player Method" = Player Closest To Ball
		Left Alt + Q - "Get Player Method" = Player Closest To Lign of Sight
		Scroll Wheel Up - Zoom In
		Scroll Wheel Down - Zoom Out

	In FirstPerson & ThirdPerson mode:
		A - Left Player Cycle
		D - Right Player Cycle
		
	In All modes:
		5/NumPadOne - Left Overview
		6/NumPadeltaTimewo - Mid Overview
		7/NumPadeltaTimehree - Right Overview

		^^The Overviews Side is based on which side the ball is on^^
	]])
		end

		if controllerControls then
			Gui.text([[
Controller:
	Modes:
		Left Face Button - Freecam Mode
		Right Face Button - FirstPerson Mode
		Top Face Button - ThirdPerson Mode
					
	In Freecam mode:
		Left Joystick - Horizontal Movement
		Left & Right Trigger - Vertical Movement
		Right Joystick - Rotating
		Right Bumper - Gear Increase
		Left Bumper - Gear Decrease
		Right Joystick Down - "Get Player Method" = Player Closest To Ball
		Left Joystick Down - "Get Player Method" = Player Closest To Lign of Sight
		Dpad Up - Zoom In
		Dpad Down - Zoom Out
					
	In FirstPerson & ThirdPerson mode:
		Left Bumper - Left Player Cycle
		Right Bumper - Right Player Cycle
	
	In All modes:
		Dpad Up + Left Face Button - Left Overview
		Dpad Up + Top Face Button - Mid Overview
		Dpad Up + Right Face Button - Right Overview

		^^The Overviews Side is based on which side the ball is on^^
	]])
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

	Gui.newLine()
	Gui.separatorText("Camera")
	Gui.indent()

	if Gui.button("Get Closest Arena") then
		selectedArena = getClosestArena(camera.position)
		selectedArena.home.players = {}
		selectedArena.away.players = {}
	end

	if Gui.collapsingHeader(`Selected Arena: {selectedArena.name}###ArenaHeader`) then
		local isHovered = false
		Gui.text(hoveredArena)

		Gui.indent()

		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()

		if Gui.button(" 2 ") then
			selectedArena = arenas.plazaWest
			selectedArena.home.players = {}
			selectedArena.away.players = {}
		end
		if Gui.isItemHovered() then
			hoveredArena = "Plaza West"
			isHovered = true
		end

		Gui.sameLine()

		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()

		if Gui.button(" 5 ") then
			selectedArena = arenas.fieldhouseWest
			selectedArena.home.players = {}
			selectedArena.away.players = {}
		end
		if Gui.isItemHovered() then
			hoveredArena = "Fieldhouse West"
			isHovered = true
		end

		if Gui.button("1") then
			selectedArena = arenas.gatewayArena
			selectedArena.home.players = {}
			selectedArena.away.players = {}
		end
		if Gui.isItemHovered() then
			hoveredArena = "Gateway Arena"
			isHovered = true
		end

		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()

		if Gui.button("4") then
			selectedArena = arenas.stadiumPrime
			selectedArena.home.players = {}
			selectedArena.away.players = {}
		end
		if Gui.isItemHovered() then
			hoveredArena = "Stadium Prime"
			isHovered = true
		end

		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()

		if Gui.button("7") then
			selectedArena = arenas.theBunker
			selectedArena.home.players = {}
			selectedArena.away.players = {}
		end
		if Gui.isItemHovered() then
			hoveredArena = "The Bunker"
			isHovered = true
		end

		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()

		if Gui.button(" 3 ") then
			selectedArena = arenas.plazaEast
			selectedArena.home.players = {}
			selectedArena.away.players = {}
		end
		if Gui.isItemHovered() then
			hoveredArena = "Plaza East"
			isHovered = true
		end

		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()
		Gui.spacing()
		Gui.sameLine()

		if Gui.button(" 6 ") then
			selectedArena = arenas.fieldhouseEast
			selectedArena.home.players = {}
			selectedArena.away.players = {}
		end
		if Gui.isItemHovered() then
			hoveredArena = "Fieldhouse East"
			isHovered = true
		end

		if not isHovered then
			hoveredArena = ""
		end

		Gui.unindent()
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
		controllerSensitivity = Gui.sliderFloat("Controller Sensitivity", controllerSensitivity, 0.001, 2)
		controllerSensitivity = math.clamp(controllerSensitivity, 0.001, 2)
		deadzone = Gui.sliderFloat("Controller Deadzone", deadzone, 0, 0.999)
		deadzone = math.clamp(deadzone, 0, 0.999)
		Gui.newLine()
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
		local awayDefault: Vec3 = Vec3.new(awayTeamDefaultColor.r, awayTeamDefaultColor.g, awayTeamDefaultColor.b)
		awayDefault = Gui.sliderFloat3("Away Default Color", awayDefault, 0, 1)
		awayTeamDefaultColor = {
			r = math.clamp(awayDefault.x, 0, 1),
			g = math.clamp(awayDefault.y, 0, 1),
			b = math.clamp(awayDefault.z, 0, 1),
		}
		Gui.unindent()
	end
	Gui.unindent()

	Gui.newLine()

	if Gui.button("Save Config " .. Icon.Save) then
		config.cameraFOV = cameraFOV
		config.deadzone = deadzone
		config.mouseSensitivity = mouseSensitivity
		config.controllerSensitivity = controllerSensitivity
		config.positionSmoothing = positionSmoothing
		config.lookSmoothness = lookSmoothness
		config.particleSimSpeed = particleSimSpeed
		config.vibrance = vibrance
		config.getBallVariant = getBallVariant
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

		saveConfig()
	end

	Gui.newLine()

	if Gui.treeNode("Debug") then
		boundingBoxDebug = Gui.checkbox("show boxes", boundingBoxDebug)
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
	transitionInfo.length = 0
	toggleSmoothing(false, false)
	if transitionInfo.startPosition:length() <= 0.01 then
		camera.position = defaultPosition
		camera.rotation = defaultRotation
		rotEuler = defaultRotation:euler()
	else
		camera.position = transitionInfo.startPosition
		camera.rotation = transitionInfo.startRotation
		rotEuler = transitionInfo.startRotation:euler()
	end
	rotEuler.x = 0
	camera.rotationSmoothing = 0.02
	camera.hideNearestHead = false
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
		if not isBetween(targetPosition.z, arena.position.z + arenaFloorOffset, arena.position.z + arenaRoofOffset) then
			continue
		end
		if distance < closestArenaDistance then
			closestArenaDistance = distance
			closestArena = arena
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
		-- because some arenas are directly above others
		-- we limit the balls to those where the ball is between the arenas floor and roof position
		if
			not isBetween(
				ball.transform.position.z,
				selectedArena.position.z + arenaFloorOffset,
				selectedArena.position.z + arenaRoofOffset
			)
		then
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
		local leftHandPosition = calculateRotatedOffset(player.leftHand.position, root.rotation:euler().z)
			+ root.position
		local rightHandPosition = calculateRotatedOffset(player.rightHand.position, root.rotation:euler().z)
			+ root.position

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
	playerFollow = true

	if followPlussCamera == nil then
		warn("Failed to switch to POV: 'Follow Pluss Camera' is missing.")
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
		playerFollow = false
		return
	end
	local playerIndex = findPlayerInTable(selectedArena.players, tryGetPlayer)
	if playerIndex == nil then
		playerFollow = false
		return
	else
		currentPlayerIndex = playerIndex
	end
end

function stopFollow()
	cameraMode = CameraMode.HeadRotation
	followPlayer()
	playerFollow = false
	camera:followCamera(nil)
	rotEuler = camera.rotation:euler()
	rotEuler.x = 0
	currentPlayerName = nil
	camera.fieldOfView = 100
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
	cameraFOV -= Input.getAnalog(mouseWheelAxis) * 10

	if Input.getKey(dPadUp) and Input.getKey(dPadDown) then
		cameraFOV += 0
	elseif Input.getKey(dPadUp) then
		cameraFOV -= 50 * deltaTime
	elseif Input.getKey(dPadDown) then
		cameraFOV += 50 * deltaTime
	end

	if Input.getKeyDown(middleMouseButton) or Input.getKeyDown(dPadRight) then
		cameraFOV = config.cameraFOV
	end

	if Input.getKeyDown(leftShiftInput) or Input.getKeyDown(rightShoulder) then
		if speedIndex == #speedGears - 1 then
			speedMultiplierHoldBuffer = true
		end
		speedIndex += 1
	end
	if Input.getKeyDown(leftControlInput) or Input.getKeyDown(leftShoulder) then
		speedIndex -= 1
	end
	speedIndex = math.clamp(speedIndex, 1, #speedGears)

	if speedMultiplierHoldBuffer and (Input.getKeyUp(leftShiftInput) or Input.getKeyUp(rightShoulder)) then
		speedMultiplierHoldBuffer = false
	end

	if
		(Input.getKey(leftShiftInput) or Input.getKey(rightShoulder))
		and speedIndex == #speedGears
		and not speedMultiplierHoldBuffer
	then
		speedGearMultiplier = 2
	else
		speedGearMultiplier = 1
	end

	if
		(Input.getKeyDown(numPadOne) or Input.getKeyDown(five))
		or (Input.getKey(dPadLeft) and Input.getKeyDown(leftFaceButton))
	then
		if playerFollow then
			stopFollow()
		end
		toggleSmoothing(false, false)
		if ballIsOnHomeSide() then
			camera.position = selectedArena.home.overview.left.position
			rotEuler = selectedArena.home.overview.left.rotation
		else
			camera.position = selectedArena.away.overview.left.position
			rotEuler = selectedArena.away.overview.left.rotation
		end
	end
	if
		(Input.getKeyDown(numPadTwo) or Input.getKeyDown(six))
		or (Input.getKey(dPadLeft) and Input.getKeyDown(topFaceButton))
	then
		if playerFollow then
			stopFollow()
		end
		toggleSmoothing(false, false)
		if ballIsOnHomeSide() then
			camera.position = selectedArena.home.overview.middle.position
			rotEuler = selectedArena.home.overview.middle.rotation
		else
			camera.position = selectedArena.away.overview.middle.position
			rotEuler = selectedArena.away.overview.middle.rotation
		end
	end
	if
		(Input.getKeyDown(numPadThree) or Input.getKeyDown(seven))
		or (Input.getKey(dPadLeft) and Input.getKeyDown(rightFaceButton))
	then
		if playerFollow then
			stopFollow()
		end
		toggleSmoothing(false, false)
		if ballIsOnHomeSide() then
			camera.position = selectedArena.home.overview.right.position
			rotEuler = selectedArena.home.overview.right.rotation
		else
			camera.position = selectedArena.away.overview.right.position
			rotEuler = selectedArena.away.overview.right.rotation
		end
	end

	if (Input.getKey(leftAlt) and Input.getKeyDown(qInput)) or Input.getKeyDown(leftJoystick) then
		getBallVariant = GetBallVariant.LineOfSight
	end

	if (Input.getKey(leftAlt) and Input.getKeyDown(eInput)) or Input.getKeyDown(rightJoystick) then
		getBallVariant = GetBallVariant.PlayerBallDistance
	end

	if not Input.getKey(dPadLeft) then
		if Input.getKeyDown(vInput) or Input.getKeyDown(topFaceButton) then
			if not currentPlayerName or cameraMode == CameraMode.HeadRotation then
				cameraMode = CameraMode.HeadRotation
				getPlayer()
			else
				cameraMode = CameraMode.HeadRotation
			end
		end

		if Input.getKeyDown(cInput) or Input.getKeyDown(rightFaceButton) then
			if not currentPlayerName or cameraMode == CameraMode.FirstPerson then
				cameraMode = CameraMode.FirstPerson
				getPlayer()
			else
				cameraMode = CameraMode.FirstPerson
			end
		end

		if Input.getKeyDown(leftFaceButton) or Input.getKeyDown(zInput) then
			stopFollow()
		end
	end

	if playerFollow and (Input.getKeyDown(leftShoulder) or Input.getKeyDown(aInput)) then
		currentPlayerIndex -= 1
		if currentPlayerIndex < 1 then
			currentPlayerIndex = #selectedArena.players
		end
		currentPlayerName = selectedArena.players[currentPlayerIndex].playerName
		currentPlayerId = selectedArena.players[currentPlayerIndex].playerId
	end
	if playerFollow and (Input.getKeyDown(rightShoulder) or Input.getKeyDown(dInput)) then
		currentPlayerIndex += 1
		if currentPlayerIndex > #selectedArena.players then
			currentPlayerIndex = 1
		end
		currentPlayerName = selectedArena.players[currentPlayerIndex].playerName
		currentPlayerId = selectedArena.players[currentPlayerIndex].playerId
	end
end

function readMoveInput()
	local input = math.abs(Input.getAnalog(leftAnalogVertical)) + math.abs(Input.getAnalog(leftAnalogHorizontal))
	if input > deadzone then
		Vertical = Input.getAnalog(leftAnalogVertical)
		Horizontal = Input.getAnalog(leftAnalogHorizontal)
		return
	else
		if Input.getKey(wInput) and Input.getKey(sInput) then
			Vertical = 0
		elseif Input.getKey(wInput) then
			Vertical = 1
		elseif Input.getKey(sInput) then
			Vertical = -1
		else
			Vertical = 0
		end

		if Input.getKey(dInput) and Input.getKey(aInput) then
			Horizontal = 0
		elseif Input.getKey(dInput) then
			Horizontal = 1
		elseif Input.getKey(aInput) then
			Horizontal = -1
		else
			Horizontal = 0
		end
	end
end

function readVerticalInput()
	if Input.getAnalog(leftAnalogVertical) then
		Vertical = Input.getAnalog(leftAnalogVertical)
	end

	if Input.getKey(wInput) and Input.getKey(sInput) then
		Vertical = 0
	elseif Input.getKey(wInput) then
		Vertical = 1
	elseif Input.getKey(sInput) then
		Vertical = -1
	else
		Vertical = 0
	end
end

function readHorizontalInput()
	if Input.getAnalog(leftAnalogHorizontal) then
		Horizontal = Input.getAnalog(leftAnalogHorizontal)
	end

	if Input.getKey(dInput) and Input.getKey(aInput) then
		Horizontal = 0
	elseif Input.getKey(dInput) then
		Horizontal = 1
	elseif Input.getKey(aInput) then
		Horizontal = -1
	else
		Horizontal = 0
	end
end

function readUpInput()
	if Input.getKey(leftTrigger) or Input.getKey(rightTrigger) then
		if Input.getKey(leftTrigger) and Input.getKey(rightTrigger) then
			Up = 0
		elseif Input.getKey(rightTrigger) then
			Up = 1
		elseif Input.getKey(leftTrigger) then
			Up = -1
		else
			Up = 0
		end
		return
	end

	if Input.getKey(leftAlt) then
		return
	end

	if Input.getKey(qInput) and Input.getKey(eInput) then
		Up = 0
	elseif Input.getKey(eInput) then
		Up = 1
	elseif Input.getKey(qInput) then
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

local rotDelta: Vec3 = Vec3.zeroVector
function rotateCamera()
	local mouse = Input.getMouseDelta()
	local adjustedLookSmoothness = 1 - (1 - dynamicLookSmoothness) ^ 3
	-- Keyboard
	if Input.getKey(rightMouseButton) then
		turnVelocity = Vec2.new(mouse.x, mouse.y) * 10
		rotDelta += Vec3.new(0, turnVelocity.y, turnVelocity.x) * mouseSensitivity
	end

	-- Gamepad
	turnVelocity = Vec2.new(Input.getAnalog(Input.Gamepad.RightX), Input.getAnalog(Input.Gamepad.RightY))
		* controllerSensitivity
		* 2
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
		local closestArena = getClosestArena(player.root.position)

		if closestArena ~= selectedArena then
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
	camera:followCamera(followPlussCamera)
	local message: MessageValues = {
		readLocation = readLocation,
		targetPlayerId = currentPlayerId,
		cameraMode = cameraMode,
		autoBall = false,
		autoGoalCam = false,
		cameraEulerOffset = tostring(Vec3.zeroVector),
	}
	sendMessage(followPlussCamera, message)
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

function sendOverlayInfo()
	local arenaInfo = {}
	local homePlayerNames = {}
	local awayPlayerNames = {}
	for _, player in selectedArena.home.players do
		table.insert(homePlayerNames, player.playerName)
	end
	for _, player in selectedArena.away.players do
		table.insert(awayPlayerNames, player.playerName)
	end
	arenaInfo["homePlayerNames"] = homePlayerNames
	arenaInfo["awayPlayerNames"] = awayPlayerNames
	arenaInfo["homeColor"] = homeTeamPrimaryColor
	arenaInfo["awayColor"] = awayTeamPrimaryColor
	arenaInfo["isFollowing"] = playerFollow
	arenaInfo["followedPlayerName"] = currentPlayerName
	arenaInfo["homeGoalEnter"] = homeGoalEnter
	arenaInfo["awayGoalEnter"] = awayGoalEnter
	arenaInfo["isSafeTime"] = isSafeTime
	if lastGoalPlayerName ~= nil and lastGoalPlayerName ~= "" then
		arenaInfo["lastGoalInfo"] = {
			shooter = lastGoalPlayerName,
			assister = lastAssistPlayerName,
		}
	end
	if startTimestamp ~= nil then
		arenaInfo["startTimestamp"] = startTimestamp
	end

	if not usingOverlay then
		return
	end

	sendMessage(overlayCamera, { alwaysTick = true, arenaInfo = arenaInfo, ballCenterTime = ballCenterTime })
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

				if consideringSteal then
					consideringSteal = false
					stealTime = 0
				end

				resetPlayersWithBall()

				sendMessage(overlayCamera, {
					statsInfo = {
						playerName = goalie.playerName,
						goal = false,
						save = true,
						steal = false,
						assist = false,
					},
				})
			end
		end
	end

	if not awayGoalPotentialEnter and previousAwayGoalPotentialEnter then
		if awayDist <= 600 then
			if goalie and findPlayerInTable(selectedArena.away.players, goalie) then
				successfulSave = true

				if consideringSteal then
					consideringSteal = false
					stealTime = 0
				end

				resetPlayersWithBall()

				sendMessage(overlayCamera, {
					statsInfo = {
						playerName = goalie.playerName,
						goal = false,
						save = true,
						steal = false,
						assist = false,
					},
				})
			end
		end
	end

	return successfulSave
end

function checkForSteal(): boolean
	if lastPlayerWithBall == nil then
		return false
	end

	if previousLastPlayerWithBall ~= nil then
		if lastPlayerWithBall.playerId == previousLastPlayerWithBall.playerId and not consideringSteal then
			return false -- no change in possession
		end

		if not consideringSteal then
			local teamChange = false

			if not playersAreOnSameTeam(previousLastPlayerWithBall, lastPlayerWithBall) then -- change in team possession
				teamChange = true
				stealPlayer = lastPlayerWithBall
				consideringSteal = true
			end

			return teamChange
		else
			local teamKeep = false

			if playersAreOnSameTeam(stealPlayer, lastPlayerWithBall) then
				stealTime += deltaTime
			else
				stealTime = 0
				consideringSteal = false
			end

			if stealTime >= requiredStealTime then
				stealTime = 0
				consideringSteal = false
				teamKeep = true
				sendMessage(overlayCamera, {
					statsInfo = {
						playerName = stealPlayer.playerName,
						save = false,
						goal = false,
						steal = true,
						assist = false,
					},
				})
			end

			return teamKeep
		end
	else
		return false
	end
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

	if checkForSteal() then
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
		Vec3.new(selectedArena.rotation:euler().z, 0, 0)
	)
	if boundingBoxDebug then
		homeGoalBox:render(0, 1, 0)
	end
	local awayGoalBox: BoxType = Box.new(
		selectedArena.away.goal.position - (selectedArena.rotation:getForwardVector() * 135),
		Vec3.new(100, 500, 225),
		Vec3.new(selectedArena.rotation:euler().z, 0, 0)
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
		if goalPlayer then
			if consideringSteal and findPlayerInTable(selectedArena.away.players, stealPlayer) then
				sendMessage(overlayCamera, {
					statsInfo = {
						playerName = stealPlayer.playerName,
						goal = false,
						save = false,
						steal = true,
						assist = false,
					},
				})
				stealTime = 0
				consideringSteal = false
			end
			resetPlayersWithBall()

			sendMessage(overlayCamera, {
				statsInfo = {
					playerName = goalPlayer.playerName,
					goal = true,
					save = false,
					steal = false,
					assist = false,
				},
			})
			lastGoalPlayerName = goalPlayer.playerName
			if assistPlayer then
				sendMessage(overlayCamera, {
					statsInfo = {
						playerName = assistPlayer.playerName,
						goal = false,
						save = false,
						steal = false,
						assist = true,
					},
				})
				lastAssistPlayerName = assistPlayer.playerName
				assistPlayer = nil
			else
				lastAssistPlayerName = ""
			end
		end
	end

	if awayGoalEnter and not previousAwayGoalEnter then
		isSafeTime = true
		GoalExplosionEffect(selectedArena.away.goal.position + Vec3.new(0, 0, -60), homeTeamPrimaryColor)
		midfieldTimePassed = 0
		if goalPlayer then
			if consideringSteal and findPlayerInTable(selectedArena.home.players, stealPlayer) then
				sendMessage(overlayCamera, {
					statsInfo = {
						playerName = stealPlayer.playerName,
						goal = false,
						save = false,
						steal = true,
						assist = false,
					},
				})
				stealTime = 0
				consideringSteal = false
			end
			resetPlayersWithBall()

			sendMessage(overlayCamera, {
				statsInfo = {
					playerName = goalPlayer.playerName,
					goal = true,
					save = false,
					steal = false,
					assist = false,
				},
			})
			if assistPlayer then
				sendMessage(overlayCamera, {
					statsInfo = {
						playerName = assistPlayer.playerName,
						goal = false,
						save = false,
						steal = false,
						assist = true,
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
	local centerBox: BoxType =
		Box.new(selectedArena.position + Vec3.new(0, 0, 40), Vec3.new(50, 50, 75), Vec3.zeroVector)
	if boundingBoxDebug then
		centerBox:render(0, 0, 1)
	end

	if centerBox:checkPointIntersect(ball.transform.position) then
		ballCenterTime += deltaTime
	else
		if ballCenterTime > requiredBallCenterTime then
			resetPlayersWithBall()
			GameStartEffect()
			startTimestamp = gameData.time.ticks
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

function tick(dt)
	if not camera.isActive and not camera.isFollowed then
		return
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

	if Input.getKeyDown(three) or Input.getKeyDown(bottomFaceButton) then
		GameStartEffect()
	end

	if #gameData.players < 1 and playerFollow then
		stopFollow()
	end

	if playerFollow then
		World.clear()
		followPlayer()
		readOtherInputs()
		particleAffect()
		if ball ~= nil then
			goalScoreCheck()
			ballInCenterCheck()
		else
			warn("can't find ball")
		end
		sendOverlayInfo()
		return
	end

	toggleSmoothing(true, true)
	readInput()

	moveCamera()
	rotateCamera()

	particleAffect()
	if ball ~= nil then
		goalScoreCheck()
		ballInCenterCheck()
	else
		warn("can't find ball")
	end
	sendOverlayInfo()
end
