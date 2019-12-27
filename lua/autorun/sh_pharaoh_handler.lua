if SERVER then
	util.AddNetworkString('ttt2_net_pharaoh_spawn_effects')
	util.AddNetworkString('ttt2_net_pharaoh_wallack')
	util.AddNetworkString('ttt2_net_pharaoh_play_sound')
	util.AddNetworkString('ttt2_net_pharaoh_show_popup')
end

PHARAOH_HANDLER = {}

function PHARAOH_HANDLER:PlacedAnkh(ent, placer)
	if CLIENT then return end

	-- first placement
	if not placer.ankh_data then
		-- selecting a graverobber, the adversary of the pharaoh
		local p_graverobber = self:SelectGraverobber()

		-- if a valid player is found, he should be converted
		if p_graverobber then
			p_graverobber:SetRole(ROLE_GRAVEROBBER)
			SendFullStateUpdate()
		end

		-- set up data element
		placer.ankh_data = {
			pharaoh = placer,
			graverobber = p_graverobber,
			owner = placer,
			adversary = p_graverobber,
			health = GetGlobalInt('ttt_ankh_health')
		}
	end

	-- set the hp of the ankh
	ent:SetHealth(placer.ankh_data.health)

	-- drawing the decal on the ground
	if placer:GetSubRole() == ROLE_PHARAOH then
		self:AddDecal(ent, 'rune_pharaoh')
	else
		self:AddDecal(ent, 'rune_graverobber')
	end

	-- store ankh information to the players as well
	placer.ankh_data.pharaoh.ankh = ent
	if placer.ankh_data.graverobber then
		placer.ankh_data.graverobber.ankh = ent
	end

	-- setting the graverobber and pharao to this specific ankh
	ent:SetNWEntity('pharaoh', placer.ankh_data.pharaoh)
	ent:SetNWEntity('graverobber', placer.ankh_data.graverobber)

	-- set new owner of ankh
	ent:SetOwner(placer.ankh_data.owner)
	ent:SetAdversary(placer.ankh_data.adversary)

	-- add wallhack
	self:AddWallhack(ent, placer)

	-- add status icon to owner
	STATUS:AddStatus(ent:GetOwner(), 'ttt_ankh_status', 1)
end

function PHARAOH_HANDLER:StartConversion(ent, ply)
	-- start converting sound for old owner
	self:PlaySound('ankh_converting', ent, {ent:GetOwner(), ent:GetAdversary()})

	-- update status icon
	STATUS:SetActiveIcon(ent:GetOwner(), 'ttt_ankh_status', 2)
end

function PHARAOH_HANDLER:CancelConversion(ent, ply)
	-- stop converting sound for old owner
	self:StopSound('ankh_converting', ent, {ent:GetOwner(), ent:GetAdversary()})

	-- update status icon
	STATUS:SetActiveIcon(ent:GetOwner(), 'ttt_ankh_status', 1)
end

function PHARAOH_HANDLER:TransferAnkhOwnership(ent, ply)
	if CLIENT then return end

	if not IsValid(ply) then return end

	-- stop converting sound for old owner
	self:StopSound('ankh_converting', ent, {ent:GetOwner(), ent:GetAdversary()})

	-- play conversion sound for all players
	self:PlaySound('ankh_conversion', ent, player.GetAll())

	-- show conversion popup to old owner
	self:ShowPopup(ent:GetOwner(), 'conversion_success')

	-- update status icons for both players
	STATUS:RemoveStatus(ent:GetOwner(), 'ttt_ankh_status')
	STATUS:AddStatus(ent:GetAdversary(), 'ttt_ankh_status', 1)

	-- add fingerprints to the ent
	if not table.HasValue(ent.fingerprints, ent:GetAdversary()) then
		ent.fingerprints[#ent.fingerprints + 1] = ent:GetAdversary()
	end

	-- flip adversary and owner
	ent:SetAdversary(ent:GetOwner())
	ent:SetOwner(ply)

	-- removing the decal on the ground since it will be replaced
	self:RemoveDecal(ent)

	if ply == ent:GetNWEntity('pharaoh') then
		self:AddDecal(ent, 'rune_pharaoh')
	end

	if ply == ent:GetNWEntity('graverobber') then
		self:AddDecal(ent, 'rune_graverobber')
	end

	-- update wallhacks
	self:RemoveWallhack(ent, ent:GetAdversary())
	self:AddWallhack(ent, ent:GetOwner())
end

function PHARAOH_HANDLER:AddWallhack(ent, ply)
	net.Start('ttt2_net_pharaoh_wallack')
	net.WriteBool(true)
	net.WriteEntity(ent)
	net.Send(ply)
end

function PHARAOH_HANDLER:RemoveWallhack(ent, ply)
	net.Start('ttt2_net_pharaoh_wallack')
	net.WriteBool(false)
	net.WriteEntity(ent)
	net.Send(ply)
end

function PHARAOH_HANDLER:DestroyAnkh(ent, ply)
	if CLIENT then return end

	self:RemovedAnkh(ent)
	self:AddDecal(ent, 'rune_neutral')

	ent:Remove()
end

function PHARAOH_HANDLER:RemovedAnkh(ent)
	if CLIENT then return end

	-- replace decal with inactive decal
	self:RemoveDecal(ent)

	-- remove status icon
	STATUS:RemoveStatus(ent:GetOwner(), 'ttt_ankh_status')

	-- stop all possible sounds
	self:StopSound('ankh_converting', ent, player.GetAll())
	self:StopSound('ankh_conversion', ent, player.GetAll())
	self:StopSound('ankh_respawn', ent, player.GetAll())

	-- remove wallhack
	self:RemoveWallhack(ent, ent:GetOwner())
end

function PHARAOH_HANDLER:AddDecal(ent, type)
	-- ignore the ankh at all players
	local filter = {ent}
	table.Add(filter, player.GetAll())

	-- store the decal id on this ent for easier removal
	ent.decal_id = 'ankh_decal_' .. tostring(ent:EntIndex())

	util.PaintDownRemovable(ent.decal_id, ent:GetPos() + Vector(0, 0, 20), type, filter)
end

function PHARAOH_HANDLER:RemoveDecal(ent)
	if not ent.decal_id then return end

	util.RemoveDecal(ent.decal_id)

	ent.decal_id = nil
end

function PHARAOH_HANDLER:SpawnEffects(pos)
	if CLIENT then return end

	net.Start('ttt2_net_pharaoh_spawn_effects')
	net.WriteVector(pos)
	net.Broadcast()
end

function PHARAOH_HANDLER:ShowPopup(ply, id)
	net.Start('ttt2_net_pharaoh_show_popup')
	net.WriteString(id)
	net.Send(ply)
end

function PHARAOH_HANDLER:PlaySound(soundname, target, listeners)
	if CLIENT then return end

	if not IsValid(target) then return end

	net.Start('ttt2_net_pharaoh_play_sound')
	net.WriteEntity(target)
	net.WriteString(soundname)
	net.WriteBool(true)
	net.Send(listeners)
end

function PHARAOH_HANDLER:StopSound(soundname, target, listeners)
	if CLIENT then return end

	if not IsValid(target) then return end

	net.Start('ttt2_net_pharaoh_play_sound')
	net.WriteEntity(target)
	net.WriteString(soundname)
	net.WriteBool(false)
	net.Send(listeners)
end

if CLIENT then
	local zapsound = Sound('npc/assassin/ball_zap1.wav')

	local smokeparticles = {
		Model('particle/particle_smokegrenade'),
		Model('particle/particle_noisesphere')
	}

	net.Receive('ttt2_net_pharaoh_spawn_effects', function()
		local pos = net.ReadVector()

		-- spawn sound effect and destroy particless
		local effect = EffectData()
		effect:SetOrigin(pos)
		util.Effect('cball_explode', effect)

		sound.Play(zapsound, pos)

		-- smoke spawn code by Alf21
		local em = ParticleEmitter(pos)
		local r = 1.5 * 64

		for i = 1, 75 do
			local prpos = VectorRand() * r
			prpos.z = prpos.z + 332
			prpos.z = math.min(prpos.z, 52)

			local p = em:Add(table.Random(smokeparticles), pos + prpos)
			if p then
				local gray = math.random(125, 255)
				p:SetColor(gray, gray, gray)
				p:SetStartAlpha(200)
				p:SetEndAlpha(0)
				p:SetVelocity(VectorRand() * math.Rand(900, 1300))
				p:SetLifeTime(0)

				p:SetDieTime(10)

				p:SetStartSize(math.random(140, 150))
				p:SetEndSize(math.random(1, 40))
				p:SetRoll(math.random(-180, 180))
				p:SetRollDelta(math.Rand(-0.1, 0.1))
				p:SetAirResistance(600)

				p:SetCollide(true)
				p:SetBounce(0.4)

				p:SetLighting(false)
			end
		end

		em:Finish()
	end)

	net.Receive('ttt2_net_pharaoh_wallack', function()
		if net.ReadBool() then
			marks.Add({net.ReadEntity()}, LocalPlayer():GetRoleColor())
		else
			marks.Remove({net.ReadEntity()})
		end
	end)

	net.Receive('ttt2_net_pharaoh_play_sound', function()
		local target = net.ReadEntity()
		local soundname = net.ReadString()

		if not IsValid(target) then return end

		if net.ReadBool() then
			target:EmitSound(soundname, 130)
		else
			target:StopSound(soundname)
		end
	end)

	net.Receive('ttt2_net_pharaoh_show_popup', function()
		local id = net.ReadString()

		if id == 'conversion_success' then
			EPOP:AddMessage(LANG.GetTranslation('ankh_popup_converted_title'), LANG.GetTranslation('ankh_popup_converted_text'), 6)
		end
	end)
end

---
-- Returns a player that can be converted to a graverobber
-- Vanilla T players are preferred, other team traitor players are used as
-- a fallback
function PHARAOH_HANDLER:SelectGraverobber()
	local p_vanilla_traitor = {}
	local p_team_traitor = {}

	local plys = player.GetAll()

	for i = 1, #plys do
		local ply = plys[i]

		if ply:GetSubRole() == ROLE_TRAITOR then
			p_vanilla_traitor[#p_vanilla_traitor + 1] = ply
		end

		if ply:GetTeam() == TEAM_TRAITOR then
			p_team_traitor[#p_team_traitor + 1] = ply
		end
	end

	if #p_vanilla_traitor > 0 then
		return p_vanilla_traitor[math.random(1, #p_vanilla_traitor)]
	end

	if #p_team_traitor > 0 then
		return p_team_traitor[math.random(1, #p_team_traitor)]
	end
end

---
-- using TTT2PostPlayerDeath hook here, since it is called at the very last, addons like
-- a second change are triggered prior to this hook (SERVER ONLY)
hook.Add('TTT2PostPlayerDeath', 'ttt2_role_pharaoh_death', function(victim, inflictor, attacker)
	if GetRoundState() ~= ROUND_ACTIVE then return end

	-- victim must be either a pharaoh or graverobber with an ankh
	if not IsValid(victim) or not IsValid(victim.ankh) then return end

	-- the victim must be the current owner of the ankh
	if victim ~= victim.ankh:GetOwner() then return end

	victim:Revive(10, function(ply)
		local ankh_pos = ply.ankh:GetPos() + Vector(0, 0, 2.5)

		-- destroying the ankh on revival
		PHARAOH_HANDLER:DestroyAnkh(ply.ankh, ply)

		-- porting the player to the ankh
		ply:SetPos(ankh_pos)

		-- et player HP to 50
		ply:SetHealth(50)

		-- spawn smoke
		PHARAOH_HANDLER:SpawnEffects(ankh_pos)

		-- play sound
		PHARAOH_HANDLER:PlaySound('ankh_respawn', ply, player.GetAll())
	end,
	function(ply)
		-- make sure the revival is still valid
		return GetRoundState() == ROUND_ACTIVE and IsValid(ply) and ply.ankh and ply == ply.ankh:GetOwner()
	end,
	false, -- no corpse needed for respawn
	true, -- force revival
	function(ply)
		-- on fail todo
	end)
end)

hook.Add('TTTBeginRound', 'ttt2_role_pharaoh_reset', function()
	for _, p in pairs(player.GetAll()) do
		p.ankh_data = nil
	end
end)
