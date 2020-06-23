patreon_perk_cleave_t2 = class({})
--------------------------------------------------------------------------------

function patreon_perk_cleave_t2:IsHidden()
	return false
end

--------------------------------------------------------------------------------
function patreon_perk_cleave_t2:GetTexture()
	return "perkIcons/patreon_perk_cleave_t0"
end

--------------------------------------------------------------------------------


function patreon_perk_cleave_t2:IsPurgable()
	return false
end
--------------------------------------------------------------------------------
---
function patreon_perk_cleave_t2:RemoveOnDeath()
	return false
end
--------------------------------------------------------------------------------

function patreon_perk_cleave_t2:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
	return funcs
end
--------------------------------------------------------------------------------
local vectors = {
	[0]  = Vector(1.0, 						0.0, 					0.0),
	[1]  = Vector(-0.8733046400935156, 		-0.4871745124605095, 	0.0),
	[2]  = Vector(0.5253219888177297, 		0.8509035245341184, 	0.0),
	[3]  = Vector(-0.04422762066183892, 	-0.999021480034635, 	0.0),
	[4]  = Vector(-0.4480736161291701, 		0.8939966636005579, 	0.0),
	[5]  = Vector(0.8268371568000089, 		-0.562441389066343, 	0.0),
	[6]  = Vector(-0.9960878351411849,		 0.08836868610400143, 	0.0),
	[7]  = Vector(0.9129390999389944, 		0.4080958218391593, 	0.0),
	[8]  = Vector(-0.5984600690578581, 		-0.8011526357338304, 	0.0),
	[9]  = Vector(0.13233681049883225, 		0.9912048065798491, 	0.0),
	[10] = Vector(0.36731936773024515, 		-0.9300948780045254, 	0.0),
	[11] = Vector(-0.7739002269689113, 		0.6333075387972795, 	0.0),
	[12] = Vector(0.9843819506325049, 		-0.1760459464712114, 	0.0),
	[13] = Vector(-0.9454304232544339, 		-0.32582405495135236, 	0.0),
	[14] = Vector(0.6669156003948422, 		0.7451332645574127, 	0.0),
	[15] = Vector(-0.21941055349670321, 	-0.9756326199006828, 	0.0),
}
--------------------------------------------------------------------------------
function CreateParticleForCleave(particle_name, radius, target, attacker)
	local multiplayer = 1
	if not attacker:IsRangedAttacker() then
		multiplayer = -500
	end
	local particle = ParticleManager:CreateParticle(particle_name, PATTACH_ABSORIGIN_FOLLOW, target)
	for i = 0, 15 do
		local total_point = multiplayer * (target:GetAbsOrigin() - attacker:GetAbsOrigin()):Normalized()
		ParticleManager:SetParticleControl(particle, i, target:GetAbsOrigin() + vectors[i]*radius/2-total_point)
	end
	ParticleManager:ReleaseParticleIndex( particle )
end
--------------------------------------------------------------------------------
function patreon_perk_cleave_t2:OnAttackLanded(params)
	if IsServer() then
		if self:GetParent() == params.attacker then
			if params.attacker:IsRealHero() and params.attacker:GetTeam() ~= params.target:GetTeam() and (not params.target:IsBuilding()) then
				local target_loc = params.target:GetAbsOrigin()
				local cleavePercent = params.attacker:IsRangedAttacker() and 0.3 or 0.6
				local flagsForSearch = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
				local damage = params.original_damage * cleavePercent
				local enemies = FindUnitsInCone(
					self:GetParent():GetTeamNumber(),
					CalculateDirection(params.target, self:GetParent()),
					target_loc,
					150,
					360,
					300,
					nil,
					DOTA_UNIT_TARGET_TEAM_ENEMY,
					flagsForSearch,
					DOTA_UNIT_TARGET_FLAG_NOT_ATTACK_IMMUNE,
					FIND_ANY_ORDER,
					false,
					params.attacker:IsRangedAttacker()
				)

				CreateParticleForCleave("particles/custom_cleave.vpcf", 100, params.target, params.attacker)

				for _, enemy in pairs(enemies) do
					if enemy ~= params.target then
						ApplyDamage({victim = enemy, attacker = params.attacker, damage = damage, damage_type = DAMAGE_TYPE_PURE, damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION})
					end
				end
			end
		end
	end
end
--------------------------------------------------------------------------------
