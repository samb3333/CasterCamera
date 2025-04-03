metadata = {
	name = "Overlay Info",
	description = "TBD",
	author = "Dennssen",
	defaultKeybind = "",
}

local saveInterval = 1 -- 1 is good middle ground between safe and efficiency
local saveTime = 0
local currentConfig
local lastConfig

local configStructure = {
	statsInfo = {
		away = {},
		home = {},
	},
	arenaInfo = {
		home = {
			score = 0,
			players = {},
			color = {
				r = "",
				g = "",
				b = "",
			},
		},
		away = {
			score = 0,
			players = {},
			color = {
				r = "",
				g = "",
				b = "",
			},
		},
		followedPlayer = "",
		startTime = "",
	},
}

function configInIt(default)
	if config.statsInfo == nil then
		warn("config stucture has changed")
		config = default
		saveConfig()
	end
end

function compareTwoTables(table1, table2, structureOnly: boolean): boolean
	for key1, value1 in table1 do
		local value2 = table2[key1]
		if value2 == nil then
			return false
		end

		if typeof(value1) == "table" and typeof(value2) == "table" then
			if not compareTwoTables(value1, value2, structureOnly) then
				return false
			end
		elseif value1 ~= value2 and not structureOnly then
			return false
		end
	end

	for key, _ in table2 do
		if table1[key] == nil then
			return false
		end
	end

	return true
end

function deepCopyTable(table)
	local copiedTable = {}
	for key, value in table do
		if typeof(value) == "table" then
			copiedTable[key] = deepCopyTable(value)
		else
			copiedTable[key] = value
		end
	end

	return copiedTable
end

function main()
	configInIt(configStructure)
	lastConfig = deepCopyTable(config)
	currentConfig = deepCopyTable(lastConfig)

	alwaysTick = true
end

function tick(dt)
	if Input.getKeyDown(Input.Key.N) then
		print(currentConfig)
		print(lastConfig)
	end

	if saveTime < saveInterval then
		saveTime += dt
		return
	end

	if not compareTwoTables(currentConfig, lastConfig, false) then
		config = currentConfig
		saveConfig()
	end
end

function onMessageReceived(messageTable: { info: string, value: any })
	local info = messageTable.info
	local value = messageTable.value

	if info == "startTime" then
		currentConfig.arenaInfo.startTime = value
	elseif info == "players" then
		currentConfig.arenaInfo[value.team].players = value.players
	elseif info == "score" then
		currentConfig.arenaInfo[value.team].score += 1
	elseif info == "color" then
		currentConfig.arenaInfo[value.team].color = value.color
	elseif info == "followedPlayer" then
		currentConfig.arenaInfo.followedPlayer = value
	elseif info == "stats" then
		local statsPlayer = currentConfig.statsInfo[value.team][value.player]
		if statsPlayer == nil then
			currentConfig.statsInfo[value.team][value.player] = {
				goals = 0,
				saves = 0,
				assists = 0,
			}
		end
		currentConfig.statsInfo[value.team][value.player][value.stat] += 1
	elseif info == "clearStats" then
		currentConfig.statsInfo.home = {}
		currentConfig.statsInfo.away = {}
	end
end
