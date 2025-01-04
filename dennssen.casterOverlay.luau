metadata = {
	name = "Spectator",
	description = "TBD",
	author = "Dennssen",
	defaultKeybind = "",
}

local saveInterval = 0.5
local saveTime = 0
local newTeamInfo = nil
local newStatsQueue = {}
local ballCenterTime = 0
local requiredBallCenterTimer = 10
local statReset = false

function checkForTeamInfoChanges(): boolean
	local saveToConfig = false

	if newTeamInfo == nil then
		return saveToConfig
	end

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

function addStatsInfoToQueue(newStatsInfo)
	local queueIndex = nil
	for i, statsInfo in newStatsQueue do
		if newStatsInfo.playerName == statsInfo.playerName then -- player is already in queue
			queueIndex = i
		end
	end

	if queueIndex ~= nil then
		if newStatsInfo.goal then
			newStatsQueue[queueIndex].goal = true
		end

		if newStatsInfo.save then
			newStatsQueue[queueIndex].save = true
		end

		if newStatsInfo.steal then
			newStatsQueue[queueIndex].steal = true
		end

		if newStatsInfo.assist then
			newStatsQueue[queueIndex].assist = true
		end
	else
		table.insert(newStatsQueue, newStatsInfo)
	end
end

function checkForGameStarted(): boolean
	local save = false
	if (ballCenterTime >= requiredBallCenterTimer) and (config.homeScore ~= 0 or config.awayScore ~= 0) then
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

function checkForPlayerStats(): boolean
	local save = false
	if config.homeTeam == nil then
		config.homeTeam = {}
		save = true
	end
	if config.awayTeam == nil then
		config.awayTeam = {}
		save = true
	end

	local newHomePlayer = false
	local newAwayPlayer = false

	for _, playerName in config.teamInfo.homePlayerNames do
		if config.homeTeam[playerName] == nil then
			newHomePlayer = true
			break
		end
	end

	for _, playerName in config.teamInfo.awayPlayerNames do
		if config.awayTeam[playerName] == nil then
			newAwayPlayer = true
			break
		end
	end

	for playerName, playerStats in config.homeTeam do
		if table.find(config.teamInfo.homePlayerNames, tostring(playerName)) == nil then
			local combinedStats = playerStats.goals + playerStats.saves + playerStats.steals
			if combinedStats == 0 then
				config.homeTeam[playerName] = nil
				save = true
			end
		end
	end

	for playerName, playerStats in config.awayTeam do
		if table.find(config.teamInfo.awayPlayerNames, tostring(playerName)) == nil then
			local combinedStats = playerStats.goals + playerStats.saves + playerStats.steals
			if combinedStats == 0 then
				config.awayTeam[playerName] = nil
				save = true
			end
		end
	end

	if newHomePlayer then
		for _, playerName in config.teamInfo.homePlayerNames do
			if config.homeTeam[playerName] ~= nil then
				continue
			end

			config.homeTeam[playerName] = {
				saves = 0,
				goals = 0,
				steals = 0,
				assists = 0,
			}
		end
		save = true
	end
	if newAwayPlayer then
		for _, playerName in config.teamInfo.awayPlayerNames do
			if config.awayTeam[playerName] ~= nil then
				continue
			end

			config.awayTeam[playerName] = {
				saves = 0,
				goals = 0,
				steals = 0,
				assists = 0,
			}
		end
		save = true
	end

	if #newStatsQueue == 0 then
		return save
	end

	for _, newStatsInfo in newStatsQueue do
		local isOnHome = nil

		if config.homeTeam[newStatsInfo.playerName] ~= nil then
			isOnHome = true
		elseif config.awayTeam[newStatsInfo.playerName] ~= nil then
			isOnHome = false
		end

		if isOnHome == nil then
			return save
		end

		if newStatsInfo.save then
			if isOnHome then
				config.homeTeam[newStatsInfo.playerName].saves += 1
			else
				config.awayTeam[newStatsInfo.playerName].saves += 1
			end
			save = true
		end

		if newStatsInfo.goal then
			if isOnHome then
				config.homeTeam[newStatsInfo.playerName].goals += 1
			else
				config.awayTeam[newStatsInfo.playerName].goals += 1
			end
			save = true
		end

		if newStatsInfo.steal then
			if isOnHome then
				config.homeTeam[newStatsInfo.playerName].steals += 1
			else
				config.awayTeam[newStatsInfo.playerName].steals += 1
			end
			save = true
		end

		if newStatsInfo.assist then
			if isOnHome then
				config.homeTeam[newStatsInfo.playerName].assists += 1
			else
				config.awayTeam[newStatsInfo.playerName].assists += 1
			end
			save = true
		end
	end

	newStatsQueue = {}

	return save
end

function resetPlayerStats()
	config.homeTeam = {}
	config.awayTeam = {}
end

function resetInactivePlayerStats()
	for playerName, playerStats in config.homeTeam do
		if table.find(config.teamInfo.homePlayerNames, tostring(playerName)) == nil then
			config.homeTeam[playerName] = nil
		end
	end

	for playerName, playerStats in config.awayTeam do
		if table.find(config.teamInfo.awayPlayerNames, tostring(playerName)) == nil then
			config.awayTeam[playerName] = nil
		end
	end
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
		saveToConfig = checkForPlayerStats()
	else
		checkForPlayerStats()
	end

	if statReset then
		statReset = false
		saveToConfig = true
	end

	if not saveToConfig then
		-- nothing has changed
		return
	end
	saveConfig()
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

	if messageTable.resetAllStats then
		resetPlayerStats()
		statReset = true
	end

	if messageTable.resetInactiveStats then
		resetInactivePlayerStats()
		statReset = true
	end

	if messageTable.statsInfo then
		addStatsInfoToQueue(messageTable.statsInfo)
	end
end
