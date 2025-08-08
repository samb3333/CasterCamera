--!strict

export type Local = {
	position: Vec3,
	normal: Vec3,
	length: number,
}

export type BoxType = {
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

return Box
