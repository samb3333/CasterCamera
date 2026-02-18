--!strict

type ProfiledData = {
	deltaTime: number,
	deltaMemory: number,
}

type ProfiledFunction = {
	data: ProfiledData?,
	calls: { [string]: ProfiledFunction },
}

type Profiler = {
	enabled: boolean,
	freezed: boolean,
	frame: { [string]: ProfiledFunction },
	wrappers: { [(...any) -> any]: boolean },

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

	viewFrame: (self: Profiler) -> (),
	viewCalls: (calls: { [string]: ProfiledFunction }) -> (),
}

local Profiler: Profiler = {} :: Profiler
Profiler.enabled = false
Profiler.freezed = false
Profiler.frame = {}
Profiler.wrappers = {}

function Profiler.getFunctionId(level: number, f: (...any) -> any?): string
	local source, line = _G.debug.info(level, "sl")

	if line == -1 or line == nil then
		source, line = _G.debug.info(f, "sl") -- get definition line for root functions
	end

	local name = _G.debug.info(f, "n")

	return `{source}:{line}_{name}()`
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
				-- this is supposed to skip the wrapper and the definition
				local callsiteLevel = level + 2
				local callsiteFunc = _G.debug.info(callsiteLevel, "f")

				if not self.wrappers[callsiteFunc] then
					-- i don't know why this +1 works, but it does.
					table.insert(tracebackIds, self.getFunctionId(callsiteLevel + 1, func))
				else
					-- If the called function is a
					table.insert(tracebackIds, self.getFunctionId(level, func))
				end
			end
		end

		level += 1
	end

	local targetFuncProfile: ProfiledFunction = self:buildProfiledFunction(self.frame, tracebackIds, #tracebackIds)
	targetFuncProfile.data = targetProfileData
end

function Profiler:wrap(f: (...any) -> any?): (...any) -> any?
	local wrapper: (...any) -> any?

	wrapper = function(...)
		if not self.enabled or self.freezed then
			return f(...)
		end

		local startTime = os.clock()
		local startMem = gcinfo()

		local result = { f(...) }

		local profileData: ProfiledData = {
			deltaTime = os.clock() - startTime,
			deltaMemory = gcinfo() - startMem,
		}

		self:buildProfiledTree(wrapper, self.getFunctionId(3, f), profileData)

		return table.unpack(result)
	end

	self.wrappers[wrapper] = true

	return wrapper
end

function Profiler:clearFrame()
	if self.freezed then
		return
	end

	self.frame = {}
end

function Profiler:viewFrame()
	if not self.enabled then
		return
	end

	if Gui.treeNode("frame") then
		self.viewCalls(self.frame)
		Gui.treePop()
	end
end

function Profiler.viewCalls(calls: { [string]: ProfiledFunction })
	for id: string, func: ProfiledFunction in calls do
		if Gui.treeNode(id) then
			local data: ProfiledData? = func.data
			if data then
				Gui.text(`{data.deltaTime * 1000}ms`)
				Gui.text(`{data.deltaMemory > 0 and "+" or ""}{data.deltaMemory}MB`)
			end

			Profiler.viewCalls(func.calls)

			Gui.treePop()
		end
	end
end

return Profiler
