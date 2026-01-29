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
	home: number,
	away: number,
}

type OverlayTeam = {
	players: { [string]: Stats },
}

type APIStructure = {
	gamemodeId: string,

	home: OverlayTeam,
	away: OverlayTeam,
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
	local team: OverlayTeam = nil

	if teamIndex == Utils.TeamIndex.HomeTeam then
		team = api.home
	elseif teamIndex == Utils.TeamIndex.AwayTeam then
		team = api.away
	end

	if team == nil then
		-- Check for teamIndex NoTeam but also check for any number not in TeamIndex
		return
	end

	-- Save current players
	local currentPlayers: { [string]: boolean } = {}
	for playerName: string, _ in team.players do
		currentPlayers[playerName] = true
	end

	-- Add new players
	for _, playerName: string in playerNames do
		if team.players[playerName] == nil then
			team.players[playerName] = newStats()
		else
			currentPlayers[playerName] = false
		end
	end

	-- Remove old players
	for playerName: string, remove: boolean in currentPlayers do
		if remove then
			team.players[playerName] = nil
		end
	end
end

function Overlay.clearRounds()
	api.rounds = {}
end

function Overlay.addRound(homeScore: number, awayScore: number)
	table.insert(api.rounds, {
		home = homeScore,
		away = awayScore,
	})
end

function Overlay.clearStats()
	for playerName: string, _ in api.home.players do
		api.home.players[playerName] = newStats()
	end

	for playerName: string, _ in api.away.players do
		api.away.players[playerName] = newStats()
	end
end

function Overlay.increaseStat(teamIndex: number, playerName: string, stat: string)
	local team: OverlayTeam = nil

	if teamIndex == Utils.TeamIndex.HomeTeam then
		team = api.home
	elseif teamIndex == Utils.TeamIndex.AwayTeam then
		team = api.away
	end

	if team == nil then
		-- Check for teamIndex NoTeam but also check for any number not in TeamIndex
		return
	end

	if team.players[playerName] == nil then
		return
	end

	if team.players[playerName][stat] == nil then
		return
	end

	team.players[playerName][stat] += 1
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
