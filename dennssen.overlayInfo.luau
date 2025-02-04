metadata = {
	name = "Overlay Info",
	description = "TBD",
	author = "Dennssen",
	defaultKeybind = "",
}

local saveInterval = 0.5
local saveTime = 0
local newArenaInfo = nil
local newStatsQueue = {}
local ballCenterTime = 0
local requiredBallCenterTimer = 10
local statReset = false

function checkForArenaInfoChanges(): boolean
	local saveToConfig = false

	if newArenaInfo == nil then
		return saveToConfig
	end

	if config.arenaInfo == nil then
		newArenaInfo["lastGoalInfo"] = {
			shooter = "",
			assister = "",
		}
		saveToConfig = true
	else
		for key, value in config.arenaInfo do -- info that hasn't been sendt should keep it's old info
			if newArenaInfo[key] == nil then
				newArenaInfo[key] = value
			end
		end

		for key, value in newArenaInfo do
			local oldOverlayValue = config.arenaInfo[key]
			if type(value) == "table" then
				for tableKey, tableValue in value do
					if oldOverlayValue[tableKey] ~= tableValue then
						saveToConfig = true
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
		config.arenaInfo = newArenaInfo
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

	if newArenaInfo.homeGoalEnter and not config.arenaInfo.homeGoalEnter then
		config.homeScore += 1
		save = true
	end

	if newArenaInfo.awayGoalEnter and not config.arenaInfo.awayGoalEnter then
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

	for _, playerName in config.arenaInfo.homePlayerNames do
		if config.homeTeam[playerName] == nil then
			newHomePlayer = true
			break
		end
	end

	for _, playerName in config.arenaInfo.awayPlayerNames do
		if config.awayTeam[playerName] == nil then
			newAwayPlayer = true
			break
		end
	end

	for playerName, playerStats in config.homeTeam do
		if table.find(config.arenaInfo.homePlayerNames, tostring(playerName)) == nil then
			local combinedStats = playerStats.goals + playerStats.saves + playerStats.steals
			if combinedStats == 0 then
				config.homeTeam[playerName] = nil
				save = true
			end
		end
	end

	for playerName, playerStats in config.awayTeam do
		if table.find(config.arenaInfo.awayPlayerNames, tostring(playerName)) == nil then
			local combinedStats = playerStats.goals + playerStats.saves + playerStats.steals
			if combinedStats == 0 then
				config.awayTeam[playerName] = nil
				save = true
			end
		end
	end

	if newHomePlayer then
		for _, playerName in config.arenaInfo.homePlayerNames do
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
		for _, playerName in config.arenaInfo.awayPlayerNames do
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
		if table.find(config.arenaInfo.homePlayerNames, tostring(playerName)) == nil then
			config.homeTeam[playerName] = nil
		end
	end

	for playerName, playerStats in config.awayTeam do
		if table.find(config.arenaInfo.awayPlayerNames, tostring(playerName)) == nil then
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
		saveToConfig = checkForArenaInfoChanges()
	else
		checkForArenaInfoChanges()
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

	if messageTable.arenaInfo then
		newArenaInfo = messageTable.arenaInfo
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
