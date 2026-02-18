--!strict

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
	local callsiteSource, line = _G.debug.info(level, "sl")
	local definitionSource = _G.debug.info(f, "s")

	if line == -1 or line == nil then
		callsiteSource, line = _G.debug.info(f, "sl") -- get definition line for root functions
	end

	-- dennssen.caster/main.luau:3436 tick()
	-- tick():3436[dennssen.caster/main.luau]
	-- tick():3436 [main.luau]
	-- arena:tick():3436 [main.luau]
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
		if not self.enabled or self.freezed then
			return f(...)
		end

		local startTime = os.clock()
		local startMem = gcinfo()

		local result = { f(...) }

		local inclusiveTime: number = os.clock() - startTime

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
	if not Profiler.enabled then
		warn("this is not meant to be called directly")
		return
	end

	for id: string, func: ProfiledFunction in calls do
		if Gui.treeNode(id) then
			local data: ProfiledData? = func.data
			if data then
				Gui.text(`Inclusive Time: {string.format("%.4f", data.inclusiveTime * 1000)}ms`)
				Gui.text(`Exclusive Time: {string.format("%.4f", data.exclusiveTime * 1000)}ms`)

				local share: number
				if data.exclusiveTime ~= 0 then
					share = data.exclusiveTime / data.inclusiveTime * 100
				else
					share = 0
				end
				Gui.text(`Self %{string.format("%.2f", share)}`)
				Gui.text(`Exclusive Memory: {data.exclusiveMemory > 0 and "+" or ""}{data.exclusiveMemory}MB`)
			end

			Profiler.viewCalls(func.calls)

			Gui.treePop()
		end
	end
end

return Profiler
