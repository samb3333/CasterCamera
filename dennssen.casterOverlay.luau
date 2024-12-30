metadata = {
	name = "Spectator",
	description = "TBD",
	author = "Dennssen",
	defaultKeybind = "",
}

local saveInterval = 0.5
local saveTime = 0
local newTeamInfo = nil
local ballCenterTime = 0
local requiredBallCenterTimer = 10

function checkForTeamInfoChanges(): boolean
	local saveToConfig = false
	if config.teamInfo == nil then
		saveToConfig = true
	else
		for key, value in newTeamInfo do
			local oldOverlayValue = config.teamInfo[key]
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
	end

	if saveToConfig then
		config.teamInfo = newTeamInfo
	end

	return saveToConfig
end

function checkForGameStarted(): boolean
	local save = false
	if ballCenterTime >= requiredBallCenterTimer then
		config.homeScore = 0
		config.awayScore = 0
		ballCenterTime = 0
		save = true
	end

	return save
end

function checkForScoreChange(): boolean
	local save = false

	if config.homeScore == nil then
		config.homeScore = 0
		save = true
	end

	if config.awayScore == nil then
		config.awayScore = 0
		save = true
	end

	if newTeamInfo.homeGoalEnter and not config.teamInfo.homeGoalEnter then
		config.homeScore += 1
		save = true
	end

	if newTeamInfo.awayGoalEnter and not config.teamInfo.awayGoalEnter then
		config.awayScore += 1
		save = true
	end

	return save
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

	if newTeamInfo then
		local saveToConfig

		saveToConfig = checkForGameStarted()

		if not saveToConfig then
			saveToConfig = checkForScoreChange()
		else
			checkForScoreChange()
		end

		if not saveToConfig then
			saveToConfig = checkForTeamInfoChanges()
		else
			checkForTeamInfoChanges()
		end

		if not saveToConfig then
			-- nothing has changed
			return
		end
		saveConfig()
	end
end

function onMessageReceived(messageTable)
	if messageTable.alwaysTick ~= nil then
		alwaysTick = messageTable.alwaysTick
	end

	if messageTable.teamInfo then
		newTeamInfo = messageTable.teamInfo
	end

	if messageTable.ballCenterTime then
		ballCenterTime = messageTable.ballCenterTime
	end
end
