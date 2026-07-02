--!strict

-- REMEMBER: Gui.rangeSlider doesn't work because its width spans the entire gui width (clips outside the window)

-- Profiler Begin
type ProfiledData = {
	exclusiveTime: number,
	inclusiveTime: number,
	exclusiveMemory: number,
	timesCalled: number,
}

type ProfiledFunction = {
	data: ProfiledData?,
	calls: { [string]: ProfiledFunction },
}

type Profiler = {
	deltaTime: number,

	enabled: boolean,
	paused: boolean,
	frames: { { [string]: ProfiledFunction } },
	wrappers: { [(...any) -> any]: boolean },
	overhead: number,

	freshFrame: boolean,
	maxFrameAmount: number,

	setDeltaTime: (self: Profiler, dt: number) -> (),

	getFunctionId: (levelIndicator: ((...any) -> any) | number, f: (...any) -> any) -> string,
	isCFunction: (f: (...any) -> any) -> boolean,
	buildProfiledFunction: (
		self: Profiler,
		parentCalls: { [string]: ProfiledFunction },
		tracebackIds: { string },
		currentTracebackIndex: number
	) -> ProfiledFunction,
	buildProfiledTree: (
		self: Profiler,
		wrappedFunc: (...any) -> any,
		targetFuncId: string,
		targetProfileData: ProfiledData
	) -> (),

	wrap: (self: Profiler, f: (...any) -> any) -> (...any) -> any,
	wrapScriptTick: (self: Profiler, f: (...any) -> any) -> (...any) -> any,
	wrapModule: (self: Profiler, module: any) -> any,
	wrapClass: (self: Profiler, class: any) -> any,
	clearOverhead: (self: Profiler) -> (),
	clearFrame: (self: Profiler) -> (),

	controls: (self: Profiler) -> (),
	graph: (self: Profiler) -> (),

	tick: (self: Profiler, dt: number) -> (),
}

local FONT_CHAR_WIDTH: number = 8
local FUNC_TIME_WIDTH_MULT: number = 200
local MAX_FRAME_AMOUNT: number = 5

local Profiler: Profiler = {} :: Profiler
Profiler.enabled = false
Profiler.paused = false
Profiler.frames = {
	{},
}
Profiler.wrappers = {}
Profiler.overhead = 0

Profiler.freshFrame = true
Profiler.maxFrameAmount = 1

function Profiler:setDeltaTime(dt: number)
	self.deltaTime = dt
end

function Profiler.getFunctionId(levelIndicator: ((...any) -> any?) | number, f: (...any) -> any?): string
	local callsiteLevel: number = typeof(levelIndicator) == "number" and levelIndicator or 1
	if typeof(levelIndicator) ~= "number" then
		while true do
			local stackFunc = _G.debug.info(callsiteLevel, "f")
			if stackFunc == nil then
				break
			end
			if stackFunc == levelIndicator then
				-- The frame above the wrapper is the callsite
				callsiteLevel += 1
				break
			end
			callsiteLevel += 1
		end
	end

	local callsiteSource, line = _G.debug.info(callsiteLevel, "sl")
	local definitionSource = _G.debug.info(f, "s")

	if line == -1 or line == nil then
		callsiteSource, line = _G.debug.info(f, "sl") -- get definition line for root functions
	end

	local callsiteStripped = callsiteSource:match('^%[string "(.-)"%]$')
	callsiteSource = (callsiteStripped and callsiteStripped:match("[^/]+$")) or callsiteSource

	local definitionStripped = definitionSource:match('^%[string "(.-)"%]$')
	definitionSource = (definitionStripped and definitionStripped:match("[^/]+$"):match("^[^.]+")) or definitionSource

	local name = _G.debug.info(f, "n")

	return `{definitionSource}:{name}():{line} [{callsiteSource}]`
end

function Profiler.isCFunction(f: (...any) -> any?): boolean
	local source = _G.debug.info(f, "s")
	return source == "[C]"
end

function Profiler:buildProfiledFunction(
	parentCalls: { [string]: ProfiledFunction },
	tracebackIds: { string },
	currentTracebackIndex: number
): ProfiledFunction
	local tracebackId: string = tracebackIds[currentTracebackIndex]
	if not parentCalls[tracebackId] then
		parentCalls[tracebackId] = {
			data = nil,
			calls = {},
		}
	end

	if currentTracebackIndex == 1 then
		return parentCalls[tracebackId]
	else
		return self:buildProfiledFunction(parentCalls[tracebackId].calls, tracebackIds, currentTracebackIndex - 1)
	end
end

function Profiler:buildProfiledTree(
	wrappedFunc: (...any) -> any?,
	targetFuncId: string,
	targetProfileData: ProfiledData
)
	local level: number = 1
	local passedTarget: boolean = false
	local tracebackIds: { string } = {}
	while true do
		local func = _G.debug.info(level, "f")

		if func == nil then
			break
		end

		if not passedTarget and func == wrappedFunc then
			passedTarget = true
			table.insert(tracebackIds, targetFuncId)
		elseif passedTarget then
			if not self.wrappers[func] and not self.isCFunction(func) then
				local callsiteLine = level + 3
				-- callsiteFunc is apparently the child of the function with the callsite line, so we -1
				local callsiteFunc = _G.debug.info(callsiteLine - 1, "f")

				if not self.wrappers[callsiteFunc] then
					table.insert(tracebackIds, self.getFunctionId(callsiteLine, func))
				else
					-- If the callsite function is a wrapper then that is the callsite line
					table.insert(tracebackIds, self.getFunctionId(callsiteLine - 1, func))
				end
			end
		end

		level += 1
	end

	local targetFuncProfile: ProfiledFunction =
		self:buildProfiledFunction(self.frames[#self.frames], tracebackIds, #tracebackIds)
	for _, func: ProfiledFunction in targetFuncProfile.calls do
		if func.data then
			targetProfileData.exclusiveTime -= func.data.inclusiveTime
			targetProfileData.exclusiveMemory -= func.data.exclusiveMemory
		end
	end

	if targetFuncProfile.data then
		-- previously called in the same frame, so we combine data
		targetFuncProfile.data.timesCalled += 1
		targetFuncProfile.data.inclusiveTime += targetProfileData.inclusiveTime
		if targetProfileData.exclusiveTime > targetFuncProfile.data.exclusiveTime then
			targetFuncProfile.data.exclusiveTime = targetProfileData.exclusiveTime
		end
	else
		targetFuncProfile.data = targetProfileData
	end
end

function Profiler:wrap(f: (...any) -> any?): (...any) -> any?
	local wrapper: (...any) -> any?

	wrapper = function(...)
		if not self.enabled or self.paused then
			local result = { f(...) }

			return table.unpack(result)
		end

		local startMem = gcinfo()
		local overheadBefore = self.overhead
		local startTime = os.clock()
		local result = { f(...) }
		local endTime = os.clock()

		local overheadStart = os.clock()
		local functionId = self.getFunctionId(wrapper, f)
		local overheadGain = self.overhead - overheadBefore
		local inclusiveTime: number = ((endTime - startTime) * 1000) -- convert to milliseconds
		inclusiveTime -= overheadGain

		local profileData: ProfiledData = {
			inclusiveTime = inclusiveTime,
			exclusiveTime = inclusiveTime,
			exclusiveMemory = gcinfo() - startMem,
			timesCalled = 1,
		}

		self:buildProfiledTree(wrapper, functionId, profileData)
		local overheadEnd = os.clock()

		self.overhead += (overheadEnd - overheadStart) * 1000

		return table.unpack(result)
	end

	self.wrappers[wrapper] = true

	return wrapper
end

-- is completely identical to wrap except it calls clearOverhead before the wrapped function.
function Profiler:wrapScriptTick(f: (...any) -> any?): (...any) -> any?
	local wrapper: (...any) -> any?

	wrapper = function(...)
		if not self.enabled or self.paused then
			local result = { f(...) }

			return table.unpack(result)
		end

		self:clearOverhead()

		local startMem = gcinfo()
		local overheadBefore = self.overhead
		local startTime = os.clock()
		local result = { f(...) }
		local endTime = os.clock()

		local overheadStart = os.clock()
		local functionId = self.getFunctionId(3, f)
		local overheadGain = self.overhead - overheadBefore
		local inclusiveTime: number = ((endTime - startTime) * 1000) -- convert to milliseconds
		inclusiveTime -= overheadGain

		local profileData: ProfiledData = {
			inclusiveTime = inclusiveTime,
			exclusiveTime = inclusiveTime,
			exclusiveMemory = gcinfo() - startMem,
			timesCalled = 1,
		}

		self:buildProfiledTree(wrapper, functionId, profileData)
		local overheadEnd = os.clock()

		self.overhead += (overheadEnd - overheadStart) * 1000

		return table.unpack(result)
	end

	self.wrappers[wrapper] = true

	return wrapper
end

function Profiler:wrapModule(module: any): any
	for k, v in pairs(module) do
		if type(v) == "function" then
			module[k] = self:wrap(v)
		end
	end

	return module
end

function Profiler:wrapClass(class: any): any
	local current = class
	while current do
		for k, v in pairs(current) do
			if type(v) == "function" and k ~= "new" then
				current[k] = self:wrap(v)
			end
		end
		local mt = getmetatable(current)
		current = mt and rawget(mt, "__index")
		if type(current) ~= "table" then
			break
		end
	end

	return class
end

function Profiler:clearOverhead()
	self.overhead = 0
end

function Profiler:clearFrame()
	if self.paused then
		return
	end

	self:clearOverhead()
	while #self.frames >= math.max(self.maxFrameAmount, 1) do
		table.remove(self.frames, 1)
	end

	table.insert(self.frames, {})
	self.freshFrame = true
end

function Profiler:controls()
	if not self.enabled then
		if Gui.button(Icon.Play) then
			self.enabled = true
		end
	elseif self.enabled and not self.paused then
		if Gui.button(Icon.Pause) then
			self.paused = true
		end
		Gui.sameLine()
		if Gui.button(Icon.Stop) then
			self.enabled = false
		end
	elseif self.enabled and self.paused then
		if Gui.button(Icon.Play) then
			self.paused = false
		end
		Gui.sameLine()
		if Gui.button(Icon.Stop) then
			self.enabled = false
			self.paused = false
		end
	end
	self.maxFrameAmount = Gui.sliderInt("# Profiled Frames", self.maxFrameAmount, 1, MAX_FRAME_AMOUNT)
	self.maxFrameAmount = math.clamp(self.maxFrameAmount, 1, MAX_FRAME_AMOUNT)
end

-- Profiler End

-- Graph Begin

type GraphObject = {
	data: ProfiledData?,
	calls: { [string]: GraphObject },
	name: string,
	line: string,
	file: string,
	width: number,
}

local graphFrames: { { [string]: GraphObject } } = {}

local graphPosition: Vec2 = Vec2.new(0, 20)
local lastGraphPosition: number = graphPosition.x
local graphLength: number = 0
local GRAPH_UI_WIDTH: number = 600
local RANGE_SLIDER_WIDTH: number = 385

local frameAverage: number = 0

local hoverTime: { [string]: number } = {}
local maxHoverTime: number = 0.15

function getFunctionRenderName(funcName: string, data: ProfiledData?): string
	local inclusiveTimeText = data and ` ({string.format("%.4f", data.inclusiveTime)}ms)` or ""
	return `{funcName}{inclusiveTimeText}`
end

function parseFunction(id: string): { name: string, line: string, file: string }
	local name: string = id:match("(.-:.-%(%))") or "Bad Name Parse"
	local line: string = id:match(":(%d+)") or "Bad Line Parse"
	local file: string = id:match("%[(.-)%]") or "Bad File Parse"
	return {
		name = name,
		line = line,
		file = file,
	}
end

function convertToGraphObject(funcID: string, profiledFunc: ProfiledFunction): GraphObject
	local calls: { [string]: GraphObject } = {}
	for childID, child in profiledFunc.calls do
		calls[childID] = convertToGraphObject(childID, child)
	end

	local funcInfo = parseFunction(funcID)
	local funcName = getFunctionRenderName(funcInfo.name, profiledFunc.data)

	local width: number = math.floor(profiledFunc.data and profiledFunc.data.exclusiveTime * FUNC_TIME_WIDTH_MULT or 10)
	local textWidth: number = math.floor(funcName:len() * FONT_CHAR_WIDTH)
	width = math.max(width, textWidth)
	for _, child in calls do
		-- the added width is to account for the spacing added by the horizontal and vertical gui widgets
		width += child.width + 4
	end

	return {
		data = profiledFunc.data,
		calls = calls,
		name = funcName,
		line = funcInfo.line,
		file = funcInfo.file,
		width = width,
	}
end

function createTooltip(id: string, tooltip: () -> ())
	if not hoverTime[id] then
		hoverTime[id] = 0
	end

	if Gui.isItemHovered() then
		hoverTime[id] += Profiler.deltaTime
		if hoverTime[id] >= maxHoverTime then
			Gui.beginTooltip()
			tooltip()
			Gui.endTooltip()
		end
	else
		hoverTime[id] = 0
	end
end

function setTooltip(id: string, graphObject: GraphObject, parentInclusiveTime: number?)
	createTooltip(id, function()
		Gui.separatorText(graphObject.name)
		Gui.text(`Location: {graphObject.file}:{graphObject.line}`)
		if graphObject.data then
			local isLooped: boolean = graphObject.data.timesCalled > 1
			local selfTimeFormated: string = string.format("%.4f", graphObject.data.exclusiveTime)

			if isLooped then
				Gui.text(`Biggest Self Time: {selfTimeFormated}ms`)
			else
				Gui.text(`Self Time: {selfTimeFormated}ms`)
			end

			if parentInclusiveTime then
				Gui.text(
					`Percentage of parent: {string.format(
						"%.2f",
						graphObject.data.inclusiveTime / parentInclusiveTime * 100
					)}%`
				)
			end
			Gui.text(`Memory: {graphObject.data.exclusiveMemory}MB`)
			if isLooped then
				Gui.text(`Called Amount: {graphObject.data.timesCalled}`)
			end
			if Input.getKey(Input.Key.LeftAlt) then
				Gui.text(`Width: {graphObject.width}`)
			end
		end
	end)
end

function getGraphSize(graphObjects: { [string]: GraphObject }): Vec2
	local graphSize = Vec2.zeroVector
	for _, graphObject in graphObjects do
		graphSize.x += graphObject.width

		local childDepth = getGraphSize(graphObject.calls).y
		if childDepth + 1 > graphSize.y then
			graphSize.y = childDepth + 1
		end
	end
	return graphSize
end

function isGraphObjectVisible(position: number, cursor: number, profiledFuncs: { [string]: GraphObject }): boolean
	for funcID, profiledFunc in profiledFuncs do
		local length: number = profiledFunc.width
		if cursor + length >= position then
			return true
		end
		cursor += length
	end
	return false
end

function renderGraphObjects(
	frameId: string,
	position: number,
	cursor: number,
	scale: number, -- pixels-per-graph-unit, NOT a raw percentage
	parentInclusiveTime: number?,
	graphObjects: { [string]: GraphObject }
): Vec2
	local graphSize: Vec2 = Vec2.unitX
	if next(graphObjects) == nil then
		return graphSize
	end

	if not isGraphObjectVisible(position, cursor, graphObjects) then
		graphSize = getGraphSize(graphObjects)
		return graphSize
	end

	Gui.beginHorizontal("horizontal" .. frameId)
	for funcID: string, graphObject: GraphObject in graphObjects do
		local cursorStart: number = cursor
		local renderText: string = graphObject.name
		local renderWidth: number = graphObject.width

		graphSize.x += renderWidth

		if cursor < position then
			renderWidth -= position - cursor
		end

		renderWidth *= scale

		-- If the function is visable
		local isVisable: boolean = renderWidth > 0
		if isVisable then
			Gui.beginVertical("vertical" .. frameId .. funcID)
			Gui.setNextItemWidth(renderWidth)
			Gui.inputText(`##{renderText}`, renderText)
			setTooltip(frameId .. funcID, graphObject, parentInclusiveTime)
		end

		local currentNest = renderGraphObjects(
			frameId,
			position,
			cursorStart,
			scale,
			graphObject.data and graphObject.data.inclusiveTime or nil,
			graphObject.calls
		).y + 1
		graphSize.y = currentNest > graphSize.y and currentNest or graphSize.y
		cursor += graphObject.width

		if isVisable then
			Gui.endVertical()
		end
	end
	Gui.endHorizontal()

	return graphSize
end

function getGraphObjects(profiledFuncs: { [string]: ProfiledFunction }): { [string]: GraphObject }
	local graphObjects: { [string]: GraphObject } = {}
	for funcID: string, profiledFunc: ProfiledFunction in profiledFuncs do
		graphObjects[funcID] = convertToGraphObject(funcID, profiledFunc)
	end

	return graphObjects
end

function Profiler:graph()
	if not self.enabled or not self.paused then
		return
	end

	local doUpdate: boolean = self.freshFrame
	if doUpdate then
		self.freshFrame = false
	end

	if doUpdate then
		local framesAmount: number = 0
		local framesTotal: number = 0
		for _, frame in self.frames do
			framesAmount += 1
			for _, func in frame do
				if func.data then
					framesTotal += func.data.inclusiveTime
				end
			end
		end
		frameAverage = framesAmount ~= 0 and framesTotal / framesAmount or 0
	end

	Gui.beginChild("ProfilerBox", GRAPH_UI_WIDTH, 300, true)
	Gui.text(`Frame Average: {string.format("%.4f", frameAverage)}ms`)

	lastGraphPosition = graphPosition.x

	Gui.setNextItemWidth(RANGE_SLIDER_WIDTH)
	graphPosition = Gui.rangeSlider("##graphSlider", graphPosition, 0, 100, true)
	graphPosition.x = math.max(0, graphPosition.x)
	graphPosition.x = math.min(graphPosition.x, 100 - (graphPosition.y - graphPosition.x))

	if graphPosition.x ~= lastGraphPosition or doUpdate then
		-- cache graph objects
		graphFrames = {}
		for i, frame in self.frames do
			graphFrames[i] = getGraphObjects(frame)
		end
	end

	Gui.separator()

	Gui.beginHorizontal("hor")

	local visiblePercent: number = graphPosition.y - graphPosition.x
	local visibleGraphUnits: number = graphLength * (visiblePercent / 100)
	local graphScale: number = visibleGraphUnits > 0 and ((GRAPH_UI_WIDTH - 25) / visibleGraphUnits) or 1

	local totalGraphSize: Vec2 = Vec2.zeroVector
	for i, graphFrame in graphFrames do
		local graphSize = renderGraphObjects(
			`root{i}`,
			graphLength * (graphPosition.x / 100),
			totalGraphSize.x,
			graphScale,
			nil,
			graphFrame
		)
		totalGraphSize.x += graphSize.x
		totalGraphSize.y = graphSize.y > totalGraphSize.y and graphSize.y or totalGraphSize.y
	end

	graphLength = totalGraphSize.x

	Gui.endHorizontal()

	Gui.endChild()
end

-- Graph End

function Profiler:tick(dt: number)
	self:setDeltaTime(dt)
	self:clearFrame()
end

return Profiler
