--!strict

-- Possession Tracker
-- Tracks who last touched the ball for the caster's selected arena and reports possession % per round.

local Util = require("util")

local Arena = require("arena")
type Arena = Arena.Arena

export type PlayerPossessionStats = {
	name: string,
	seconds: number,
}

type Possession = {
	__index: Possession,

	arena: Arena?,

	contactDistance: number,
	possessionTimeout: number,

	currentToucher: ReplayPlayer?,
	lastToucher: ReplayPlayer?,
	lastTouchTime: number,
	possessionHolder: ReplayPlayer?,

	possessionSeconds: { home: number, away: number, loose: number },
	possessionSecondsByPlayer: { [number]: PlayerPossessionStats },

	reset: (self: Possession) -> (),
	getContactPlayer: (self: Possession) -> ReplayPlayer?,
	printResults: (self: Possession) -> (),
	tick: (self: Possession, dt: number) -> (),
	gui: (self: Possession) -> (),
}

local Possession: Possession = {} :: Possession
Possession.__index = Possession

Possession.arena = nil

Possession.contactDistance = 30 -- cm, how close a hand/head needs to be to count as a touch
Possession.possessionTimeout = 3 -- seconds without contact before possession goes loose (covers passes/dribbles)

Possession.currentToucher = nil
Possession.lastToucher = nil
Possession.lastTouchTime = -math.huge
Possession.possessionHolder = nil

Possession.possessionSeconds = { home = 0, away = 0, loose = 0 }
Possession.possessionSecondsByPlayer = {}

function Possession:reset()
	self.currentToucher = nil
	self.lastToucher = nil
	self.lastTouchTime = -math.huge
	self.possessionHolder = nil
	self.possessionSeconds = { home = 0, away = 0, loose = 0 }
	self.possessionSecondsByPlayer = {}
end

function Possession:getContactPlayer(): ReplayPlayer?
	local arena = self.arena
	if not arena or not arena.ball then
		return nil
	end

	local ballPosition = arena.ball.transform.position
	local closestPlayer: ReplayPlayer? = nil
	local closestDist = self.contactDistance

	for _, player: ReplayPlayer in arena.players do
		local root = player.root
		local headPosition = player.head.position
		local leftHandPosition = root.rotation:rotateVector(player.leftHand.position) + root.position
		local rightHandPosition = root.rotation:rotateVector(player.rightHand.position) + root.position

		local dist = math.min(
			ballPosition:distance(headPosition),
			ballPosition:distance(leftHandPosition),
			ballPosition:distance(rightHandPosition)
		)

		if dist < closestDist then
			closestDist = dist
			closestPlayer = player
		end
	end

	return closestPlayer
end

function Possession:printResults()
	local total = self.possessionSeconds.home + self.possessionSeconds.away + self.possessionSeconds.loose
	if total <= 0 then
		return
	end

	local homePct = math.floor((self.possessionSeconds.home / total) * 100 + 0.5)
	local awayPct = math.floor((self.possessionSeconds.away / total) * 100 + 0.5)
	local loosePct = math.floor((self.possessionSeconds.loose / total) * 100 + 0.5)

	print(`[Possession] Home: {homePct}% Loose: {loosePct}% Away: {awayPct}%`)

	local players = {}
	for _, playerStats in self.possessionSecondsByPlayer do
		table.insert(players, playerStats)
	end

	table.sort(players, function(a, b)
		return a.seconds > b.seconds
	end)

	for _, playerStats in players do
		local playerPct = math.floor((playerStats.seconds / total) * 100 + 0.5)
		print(`[Possession] {playerStats.name}: {playerPct}%`)
	end
end

function Possession:tick(dt: number)
	local arena = self.arena
	if not arena then
		return
	end

	if arena.isGameActive and not arena.lastIsGameActive then
		self:reset()
	end

	local previousPossessionId = self.possessionHolder and self.possessionHolder.playerId or nil

	if arena.ball then
		self.currentToucher = self:getContactPlayer()
		if self.currentToucher then
			self.lastToucher = self.currentToucher
			self.lastTouchTime = os.clock()
			self.possessionHolder = self.currentToucher
		end
	else
		self.currentToucher = nil
	end

	-- keep possession with the last toucher through passes/dribbles until the timeout elapses
	if self.possessionHolder and os.clock() - self.lastTouchTime > self.possessionTimeout then
		self.possessionHolder = nil
	end

	local newPossessionId = self.possessionHolder and self.possessionHolder.playerId or nil
	if newPossessionId ~= previousPossessionId then
		if self.possessionHolder then
			print(`[Possession] {self.possessionHolder.playerName} has possession`)
		elseif self.lastToucher then
			print(`[Possession] Ball is loose - last touched by {self.lastToucher.playerName}`)
		else
			print(`[Possession] Ball is loose - no one has touched it yet`)
		end
	end

	if arena.isGameActive then
		if self.possessionHolder then
			local playerStats = self.possessionSecondsByPlayer[self.possessionHolder.playerId]
			if not playerStats then
				playerStats = { name = self.possessionHolder.playerName, seconds = 0 }
				self.possessionSecondsByPlayer[self.possessionHolder.playerId] = playerStats
			end
			playerStats.seconds += dt

			if self.possessionHolder.teamIndex == Util.TeamIndex.HomeTeam then
				self.possessionSeconds.home += dt
			elseif self.possessionHolder.teamIndex == Util.TeamIndex.AwayTeam then
				self.possessionSeconds.away += dt
			else
				self.possessionSeconds.loose += dt
			end
		else
			self.possessionSeconds.loose += dt
		end
	end

	if not arena.isGameActive and arena.lastIsGameActive then
		self:printResults()
	end
end

function Possession:gui()
	Gui.separatorText("Possession Tracker")

	Gui.text(`Selected Arena: {self.arena and self.arena.name or "None"}`)

	self.possessionTimeout = Gui.sliderFloat("Possession Timeout (sec)", self.possessionTimeout, 0.5, 15)

	Gui.newLine()
	Gui.text(`Currently On Ball: {self.currentToucher and self.currentToucher.playerName or "No one"}`)
	Gui.text(`Possession: {self.possessionHolder and self.possessionHolder.playerName or "Loose"}`)
	Gui.text(`Last Touched By: {self.lastToucher and self.lastToucher.playerName or "No one yet"}`)
end

return Possession
