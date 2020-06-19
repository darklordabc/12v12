modifier_super_tower = class({})

function modifier_super_tower:IsHidden() return false end
function modifier_super_tower:IsPurgable() return false end
function modifier_super_tower:RemoveOnDeath() return false end

function modifier_super_tower:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS,
		MODIFIER_PROPERTY_BASE_ATTACK_TIME_CONSTANT
	}
end

function modifier_super_tower:GetTexture()
	return "super_tower"
end

function modifier_super_tower:GetModifierExtraHealthBonus()
	return 2000
end

function modifier_super_tower:GetModifierBaseAttackTimeConstant()
	return 0.65
end
