metadata = {
	name = "Spectator",
	description = "TBD",
	author = "Dennssen",
	defaultKeybind = "",
}

local saveInterval = 0.5
local saveTime = 0
local newOverlayInfo = nil
local previousHomeGoalEnter = false
local previousAwayGoalEnter = false
local ballCenterTime = 0
local requiredBallCenterTimer = 10

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
		local saveToConfig
		if config.overlayInfo == nil then
			saveToConfig = true
		else
			saveToConfig = checkForChanges()
		end

		if ballCenterTime >= requiredBallCenterTimer then
			config.homeScore = 0
			config.awayScore = 0
			ballCenterTime = 0
			saveToConfig = true
		end

		if not saveToConfig then
			-- nothing has changed
			return
		end

		if config.homeScore == nil then
			config.homeScore = 0
		end
		if config.awayScore == nil then
			config.awayScore = 0
		end

		if newOverlayInfo.homeGoalEnter and not previousHomeGoalEnter then
			config.homeScore += 1
		end

		if newOverlayInfo.awayGoalEnter and not previousAwayGoalEnter then
			config.awayScore += 1
		end

		config.overlayInfo = newOverlayInfo
		previousHomeGoalEnter = newOverlayInfo.homeGoalEnter
		previousAwayGoalEnter = newOverlayInfo.awayGoalEnter
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

	if messageTable.ballCenterTime then
		ballCenterTime = messageTable.ballCenterTime
	end
end
