local ParticleVariant = {
	Embers = "embers",
	Rings = "rings",
	GoalRing = "goalring",
	Rocket = "rocket",
}

type Particle = {
	position: Vec3,
	rotation: Quat,
	scale: number,
	velocity: Vec3,
	color: LinearColor,
	variant: string,
	lifespan: number,
	aliveTime: number,
}

type ParticelSystem = {
	vibrance: number,
	particles: { Particle },
	replay: Replay?,
	speed: number,

	createParticle: (
		self: ParticelSystem,
		position: Vec3,
		rotation: Quat,
		scale: number,
		velocity: Vec3,
		color: LinearColor,
		variant: string,
		lifespan: number
	) -> (),

	particleAffect: (self: ParticelSystem) -> (),
}

local ParticleSystem: ParticelSystem = {} :: ParticelSystem

ParticleSystem.vibrance = 1
ParticleSystem.particles = {}
ParticleSystem.replay = nil
ParticleSystem.speed = 1

function ParticleSystem:createParticle(
	position: Vec3,
	rotation: Quat,
	scale: number,
	velocity: Vec3,
	color: LinearColor,
	variant: string,
	lifespan: number
)
	local variantExists = false
	for _, value in pairs(ParticleVariant) do
		if value == variant then
			variantExists = true
		end
	end

	if not variantExists then
		warn(`Bad Variant: {variant}`)
		return
	end

	-- change vibrancy of the color
	color = LinearColor.new(color.R * self.vibrance, color.G * self.vibrance, color.B * self.vibrance, 1)

	local newParticle: Particle = {
		position = position,
		rotation = rotation,
		scale = scale,
		velocity = velocity,
		color = color,
		variant = variant,
		lifespan = lifespan,
		aliveTime = lifespan,
	}
	table.insert(ParticleSystem.particles, newParticle)
end

function ParticleSystem:particleAffect()
	if #self.particles < 1 then
		return
	end

	for i, particle: Particle in ipairs(self.particles) do
		--LIFE DURATION
		if not self.replay or self.replay.isPlaying then
			particle.aliveTime -= 1 * self.speed
		end

		if particle.aliveTime < 0 then
			table.remove(self.particles, i)
		end

		if not self.replay or self.replay.isPlaying then
			--affect position
			local emberDrag = 0.95
			local gravityMultiplier = 0.8
			if particle.variant == ParticleVariant.Embers or particle.variant == ParticleVariant.Rocket then
				particle.velocity -= (gravity.upDirection * gravityMultiplier * self.speed)

				--ember drag
				if particle.variant ~= ParticleVariant.Rocket then
					particle.velocity = particle.velocity * (emberDrag ^ self.speed)
				end
			end

			--collision
			if particle.variant == ParticleVariant.Embers then
				local hit = camera:castRay(particle.position, particle.velocity + particle.position)
				if hit.successful then
					local dotProduct = particle.velocity:dot(hit.normal)
					local reflection = particle.velocity - (hit.normal * (2 * dotProduct))

					particle.velocity = reflection --bounce embers
				end
			end

			--update position
			particle.position += (particle.velocity * self.speed)

			--affect scale
			if
				particle.variant == ParticleVariant.Embers
				or particle.variant == ParticleVariant.Rings
				or particle.variant == ParticleVariant.GoalRing
			then
				particle.scale *= ((particle.aliveTime / particle.lifespan) ^ self.speed)
			end
		end

		--remove tiny particles
		if particle.scale < 0.01 then
			table.remove(self.particles, i)
		end

		--draw parts
		if particle.variant == ParticleVariant.Embers or particle.variant == ParticleVariant.Rocket then
			WorldDraw.drawLine(
				particle.position,
				particle.position - particle.velocity,
				particle.color.R,
				particle.color.G,
				particle.color.B,
				particle.scale * 20,
				0
			)
		end

		--generate rings
		if particle.variant == ParticleVariant.Rings then
			local r = (1 - particle.aliveTime / particle.lifespan) * 6000
			local resolution = 90
			local theta = 2 * math.pi / resolution

			local previousRingOffset = Vec3.new(r * math.cos(0), r * math.sin(0), -40)

			for i = 1, resolution do
				local currentRingOffset = Vec3.new(r * math.cos(i * theta), r * math.sin(i * theta), -40)

				WorldDraw.drawLine(
					particle.rotation:rotateVector(previousRingOffset) + particle.position,
					particle.rotation:rotateVector(currentRingOffset) + particle.position,
					particle.color.R,
					particle.color.G,
					particle.color.B,
					particle.scale * 90,
					0
				)

				previousRingOffset = currentRingOffset
			end

			--generate goal ring
		end
		if particle.variant == ParticleVariant.GoalRing then
			local goalOutline = {
				Vec3.new(0, -248.905, -52.404),
				Vec3.new(0, -248.905, 109.223),
				Vec3.new(0, -188.979, 172.762),
				Vec3.new(0, 188.979, 172.762),
				Vec3.new(0, 248.905, 109.223),
				Vec3.new(0, 248.905, -52.404),
			}
			for i = 1, 5 do
				WorldDraw.drawLine(
					particle.rotation:rotateVector(goalOutline[i]) + particle.position,
					particle.rotation:rotateVector(goalOutline[i + 1]) + particle.position,
					particle.color.R,
					particle.color.G,
					particle.color.B,
					particle.scale * 15,
					0
				)
			end
		end
	end
end

return ParticleSystem
