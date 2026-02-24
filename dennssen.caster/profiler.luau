--!strict

-- Profiler Begin
type ProfiledData = {
	exclusiveTime: number,
	inclusiveTime: number,
	exclusiveMemory: number,
}

type ProfiledFunction = {
	data: ProfiledData?,
	calls: { [string]: ProfiledFunction },
}

type Profiler = {
	deltaTime: number,

	enabled: boolean,
	paused: boolean,
	frame: { [string]: ProfiledFunction },
	wrappers: { [(...any) -> any]: boolean },

	freshFrame: boolean,

	setDeltaTime: (self: Profiler, dt: number) -> (),

	getFunctionId: (level: number, f: (...any) -> any) -> string,
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
	clearFrame: (self: Profiler) -> (),

	viewFrameData: (self: Profiler) -> (),
	viewCallsData: (calls: { [string]: ProfiledFunction }) -> (),
	graph: (self: Profiler) -> (),
}

local Profiler: Profiler = {} :: Profiler
Profiler.enabled = false
Profiler.paused = false
Profiler.frame = {}
Profiler.wrappers = {}

Profiler.freshFrame = true

function Profiler:setDeltaTime(dt: number)
	self.deltaTime = dt
end

function Profiler.getFunctionId(level: number, f: (...any) -> any?): string
	local callsiteSource, line = _G.debug.info(level, "sl")
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

	local targetFuncProfile: ProfiledFunction = self:buildProfiledFunction(self.frame, tracebackIds, #tracebackIds)
	for _, func: ProfiledFunction in targetFuncProfile.calls do
		if func.data then
			targetProfileData.exclusiveTime -= func.data.inclusiveTime
			targetProfileData.exclusiveMemory -= func.data.exclusiveMemory
		end
	end

	targetFuncProfile.data = targetProfileData
end

function Profiler:wrap(f: (...any) -> any?): (...any) -> any?
	local wrapper: (...any) -> any?

	wrapper = function(...)
		if not self.enabled or self.paused then
			return f(...)
		end

		local startTime = os.clock()
		local startMem = gcinfo()

		local result = { f(...) }

		local inclusiveTime: number = (os.clock() - startTime) * 1000 -- convert to milliseconds

		local profileData: ProfiledData = {
			inclusiveTime = inclusiveTime,
			exclusiveTime = inclusiveTime,
			exclusiveMemory = gcinfo() - startMem,
		}

		self:buildProfiledTree(wrapper, self.getFunctionId(3, f), profileData)

		return table.unpack(result)
	end

	self.wrappers[wrapper] = true

	return wrapper
end

function Profiler:clearFrame()
	if self.paused then
		self.freshFrame = false
		return
	end

	self.freshFrame = true
	self.frame = {}
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
	padding: number,
	render: string,
}

local graphObjects: { [string]: GraphObject } = {}

local graphPosition: number = 0
local lastGraphPosition: number = graphPosition
local buttonJumpShift: number = 5

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

function padToSize(line: string, totalSize: number): string
	local gap = totalSize - line:len()
	local left = math.floor(gap / 2)
	local right = gap - left
	return `{(" "):rep(left)}{line}{(" "):rep(right)}`
end

function convertToGraphObject(funcID: string, profiledFunc: ProfiledFunction): GraphObject
	local calls: { [string]: GraphObject } = {}
	for childID, child in profiledFunc.calls do
		calls[childID] = convertToGraphObject(childID, child)
	end

	local funcInfo = parseFunction(funcID)
	local funcName = getFunctionRenderName(funcInfo.name, profiledFunc.data)

	local padding: number = math.floor(profiledFunc.data and profiledFunc.data.exclusiveTime or 0)
	for _, child in calls do
		-- the added padding is to account for the spacing added by the horizontal and vertical gui widgets
		padding += child.width + 4
	end
	local render = padToSize(funcName, padding)

	return {
		data = profiledFunc.data,
		calls = calls,
		name = funcName,
		line = funcInfo.line,
		file = funcInfo.file,
		padding = padding,
		width = render:len(),
		render = render,
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

function setTooltip(id: string, funcFile: string, funcLine: string, exclusiveTime: number?, memory: number?)
	createTooltip(id, function()
		Gui.separatorText("data")
		Gui.text(`Location: {funcFile}:{funcLine}`)
		if exclusiveTime then
			Gui.text(`Self Time: {string.format("%.4f", exclusiveTime)}ms`)
		end
		if memory then
			Gui.text(`Memory: {string.format("%.4f", memory)}MB`)
		end
	end)
end

function getMaxDepth(profiledFuncs: { [string]: GraphObject }): number
	local maxDepth = 0
	for _, profiledFunc in profiledFuncs do
		local childDepth = getMaxDepth(profiledFunc.calls)
		if childDepth + 1 > maxDepth then
			maxDepth = childDepth + 1
		end
	end
	return maxDepth
end

function isGraphObjectVisible(position: number, cursor: number, profiledFuncs: { [string]: GraphObject }): boolean
	for funcID, profiledFunc in profiledFuncs do
		local length: number = profiledFunc.render:len()
		if cursor + length >= position then
			return true
		end
		cursor += length
	end
	return false
end

function renderGraphObjects(
	position: number,
	cursor: number,
	parent: string,
	graphObjects: { [string]: GraphObject }
): number
	if next(graphObjects) == nil then
		return 0
	end

	if not isGraphObjectVisible(position, cursor, graphObjects) then
		return getMaxDepth(graphObjects)
	end

	Gui.beginHorizontal("horizontal" .. parent)
	local deepestNest: number = 0
	for funcID: string, graphObject: GraphObject in graphObjects do
		local cursorStart: number = cursor
		local renderText: string = graphObject.render

		if cursor < position then
			renderText = renderText:sub(position - cursor)
		end

		-- If the function is visable
		local isVisable: boolean = renderText:len() > 0
		if isVisable then
			Gui.beginVertical("vertical" .. funcID)
			Gui.smallButton(renderText)
			if graphObject.data then
				setTooltip(
					funcID,
					graphObject.file,
					graphObject.line,
					graphObject.data.exclusiveTime,
					graphObject.data.exclusiveMemory
				)
			end
		end

		local currentNest = renderGraphObjects(position, cursorStart, funcID, graphObject.calls) + 1
		deepestNest = currentNest > deepestNest and currentNest or deepestNest
		cursor += graphObject.render:len()

		if isVisable then
			Gui.endVertical()
		end
	end
	Gui.endHorizontal()

	return deepestNest
end

function getGraphObjects(profiledFuncs: { [string]: ProfiledFunction }): { [string]: GraphObject }
	local graphObjects: { [string]: GraphObject } = {}
	for funcID: string, profiledFunc: ProfiledFunction in profiledFuncs do
		graphObjects[funcID] = convertToGraphObject(funcID, profiledFunc)
	end

	return graphObjects
end

function Profiler:graph()
	if not self.enabled and not self.paused then
		return
	end

	lastGraphPosition = graphPosition

	if Gui.button("<-") then
		graphPosition = graphPosition - buttonJumpShift
	end
	Gui.sameLine()
	graphPosition = Gui.dragInt("##Slider", graphPosition, 1, 0, 9999999)
	Gui.sameLine()
	if Gui.button("->") then
		graphPosition += buttonJumpShift
	end
	graphPosition = math.max(0, graphPosition)

	Gui.separator()

	if graphPosition ~= lastGraphPosition or self.freshFrame then
		graphObjects = getGraphObjects(self.frame) -- cache graph objects
	end

	Gui.beginHorizontal("hor")

	local height = renderGraphObjects(graphPosition, 0, "root", graphObjects)
	Gui.beginVertical("KeepHeight")
	for i = 1, height + 1, 1 do
		Gui.text(" ")
	end
	Gui.endVertical()
	Gui.endHorizontal()

	Gui.separator()
end

-- Graph End

return Profiler
