--!strict

local Utils = require("util")

local Overlay = {}

type Stats = {
	goals: number,
	saves: number,
	assists: number,
}

function newStats(): Stats
	return {
		goals = 0,
		saves = 0,
		assists = 0,
	}
end

type ShotInfo = {
	shooter: string,
	assister: string,
	team: number,
	shotSpeed: number,
	shotDistanceMeters: number,
}

type Round = {
	home: {
		score: number,
	},
	away: {
		score: number,
	},
}

type APIStructure = {
	gamemodeId: string,

	home: {
		players: { [string]: Stats },
	},
	away: {
		players: { [string]: Stats },
	},
	rounds: { Round },
	followedPlayer: string,
	lastShotInfo: ShotInfo,
	isGracePeriod: boolean,
	isOvertime: boolean,
	bestOf: number,
	matchLengthSeconds: number,
}

local api: APIStructure = {
	gamemodeId = "",

	home = {
		players = {},
	},
	away = {
		players = {},
	},
	rounds = {},
	followedPlayer = "",
	lastShotInfo = {
		shooter = "",
		assister = "",
		team = -1,
		shotSpeed = 0,
		shotDistanceMeters = 0,
	},
	isGracePeriod = false,
	isOvertime = false,
	bestOf = 0,
	matchLengthSeconds = 0,
}

function Overlay.setGamemodeId(gamemodeId: string)
	api.gamemodeId = gamemodeId
end

function Overlay.setPlayers(teamIndex: number, playerNames: { string })
	local team: string = ""

	if teamIndex == Utils.TeamIndex.HomeTeam then
		team = "home"
	elseif teamIndex == Utils.TeamIndex.AwayTeam then
		team = "away"
	end

	if team == "" then
		-- Check for teamIndex NoTeam but also check for any number not in TeamIndex
		return
	end

	-- Save current players
	local currentPlayers: { [string]: boolean } = {}
	for playerName: string, _ in api[team].players do
		currentPlayers[playerName] = true
	end

	-- Add new players
	for _, playerName: string in playerNames do
		if api[team].players[playerName] == nil then
			print(`Created new player stats data for {playerName}`)
			api[team].players[playerName] = newStats()
		else
			currentPlayers[playerName] = false
		end
	end

	-- Remove old players
	for playerName: string, remove: boolean in currentPlayers do
		if remove then
			api[team].players[playerName] = nil
		end
	end
end

function Overlay.clearStats()
	for _, stats: Stats in api.home.players do
		stats = newStats()
	end

	for _, stats: Stats in api.away.players do
		stats = newStats()
	end
end

function Overlay.increaseStat(teamIndex: number, playerName: string, stat: string)
	local team: string = ""

	if teamIndex == Utils.TeamIndex.HomeTeam then
		team = "home"
	elseif teamIndex == Utils.TeamIndex.AwayTeam then
		team = "away"
	end

	if team == "" then
		-- Check for teamIndex NoTeam but also check for any number not in TeamIndex
		return
	end

	if api[team].players[playerName] == nil then
		return
	end

	if api[team].players[playerName][stat] == nil then
		return
	end

	print(`Increased stat {stat} for {playerName}`)

	api[team].players[playerName][stat] += 1
end

function Overlay.setFollowedPlayer(followedPlayer: string)
	api.followedPlayer = followedPlayer
end

function Overlay.setShotInfo(shotInfo: ShotInfo)
	api.lastShotInfo = shotInfo
end

function Overlay.setIsGracePeriod(isGracePeriod: boolean)
	api.isGracePeriod = isGracePeriod
end

function Overlay.setIsOvertime(isOvertime: boolean)
	api.isOvertime = isOvertime
end

function Overlay.setBestOf(bestOf: number)
	api.bestOf = bestOf
end

function Overlay.setMatchLengthSeconds(matchLengthSeconds: number)
	api.matchLengthSeconds = matchLengthSeconds
end

function Overlay.tick()
	config.api = api
	saveConfig()
end

return Overlay
