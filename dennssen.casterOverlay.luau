metadata = {
	name = "Spectator",
	description = "TBD",
	author = "Dennssen",
	defaultKeybind = "",
}

local saveInterval = 0.5
local saveTime = 0
local newOverlayInfo = nil

function checkForChanges(): boolean
	local saveToConfig = false
	for key, value in newOverlayInfo do
		local oldOverlayValue = config.overlayInfo[key]
		if type(value) == "table" then
			for tableKey, tableValue in value do
				local oldOverlayTableValue = oldOverlayValue[tableKey]
				if oldOverlayTableValue == nil then
					oldOverlayTableValue = 0
				end
				if type(tableValue) == "number" and (tableValue ~= 0 and oldOverlayTableValue ~= 0) then
					-- round to 2 decimals if value is a number
					local roundedOldTableValue = math.round(oldOverlayTableValue * 100) / 100
					local roundedNewTableValue = math.round(tableValue * 100) / 100
					if roundedOldTableValue ~= roundedNewTableValue then
						saveToConfig = true
					end
				else
					if oldOverlayTableValue ~= tableValue then
						saveToConfig = true
					end
				end
			end
		else
			if oldOverlayValue ~= value then
				saveToConfig = true
			end
		end
	end
	return saveToConfig
end

function tick(dt)
	if not alwaysTick then
		return
	end

	saveTime += dt
	if saveTime < saveInterval then
		return
	end

	saveTime = 0

	if newOverlayInfo then
		local saveToConfig = checkForChanges()

		if not saveToConfig then
			-- nothing has changed
			return
		end

		config.overlayInfo = newOverlayInfo
		saveConfig()
	end
end

function onMessageReceived(messageTable)
	if messageTable.alwaysTick ~= nil then
		alwaysTick = messageTable.alwaysTick
	end

	if messageTable.overlayInfo then
		newOverlayInfo = messageTable.overlayInfo
	end
end
