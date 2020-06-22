patreon_perk_manaburn_t1 = class({})
--------------------------------------------------------------------------------

function patreon_perk_manaburn_t1:IsHidden()
	return false
end

--------------------------------------------------------------------------------
function patreon_perk_manaburn_t1:GetTexture()
	return "perkIcons/patreon_perk_manaburn_t0"
end

--------------------------------------------------------------------------------


function patreon_perk_manaburn_t1:IsPurgable()
	return false
end
--------------------------------------------------------------------------------
---
function patreon_perk_manaburn_t1:RemoveOnDeath()
	return false
end
--------------------------------------------------------------------------------

function patreon_perk_manaburn_t1:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
	return funcs
end
--------------------------------------------------------------------------------

function patreon_perk_manaburn_t1:OnAttackLanded(params)
	if IsServer() then
		if params.attacker == self:GetParent() then
			local targetMana = params.target:GetMana()
			local manaBurn = GetPerkValue(8, self, 1, 0)
			if manaBurn > targetMana then
				manaBurn = targetMana
			end
			params.target:SpendMana(manaBurn, nil)
			if manaBurn > 1 then
				EmitSoundOnLocationWithCaster( params.target:GetAbsOrigin(), "Hero_Antimage.ManaBreak", params.attacker )
				local particle = ParticleManager:CreateParticle("particles/generic_gameplay/generic_manaburn.vpcf", PATTACH_ROOTBONE_FOLLOW, params.target)
				ParticleManager:ReleaseParticleIndex(particle)
				local damage = {
					victim = params.target,
					attacker = params.attacker,
					damage = manaBurn,
					damage_type = DAMAGE_TYPE_PHYSICAL,
					ability = nil
				}
				ApplyDamage(damage)
			end
		end
	end
end

--------------------------------------------------------------------------------
function GetPerkValue(const, modifier, levelCounter, bonusPerLevel)
	local heroLvl = modifier:GetParent():GetLevel()
	return math.floor(heroLvl/levelCounter)*bonusPerLevel+const
end
--------------------------------------------------------------------------------
