local Profiler = {}
Profiler.enabled = false
Profiler.freeze = false
Profiler.frame = {}

function Profiler:clearFrame()
	if self.freeze then
		return
	end

	self.frame = {}
end

function Profiler:wrap(f: (...any) -> any?): (...any) -> any?
	return function(...)
		if not self.enabled or self.freeze then
			return f(...)
		end

		local startTime = os.clock()
		local startMem = gcinfo()

		local result = { f(...) }

		local name, source, line = _G.debug.info(f, "nsl")
		table.insert(self.frame, {
			name = name,
			source = source,
			line = line,
			deltaTime = os.clock() - startTime,
			deltaMem = gcinfo() - startMem,
		})

		return table.unpack(result)
	end
end

function Profiler:viewFrame()
	if not self.enabled then
		return
	end

	if Gui.treeNode("frame") then
		for _, func in self.frame do
			if Gui.treeNode(`{func.source}:{func.line} {func.name}()`) then
				Gui.text(`{func.deltaTime * 1000}ms`)
				Gui.text(`{func.deltaMem > 0 and "+" or ""}{func.deltaMem}MB`)
				Gui.treePop()
			end
		end
		Gui.treePop()
	end
end

return Profiler
