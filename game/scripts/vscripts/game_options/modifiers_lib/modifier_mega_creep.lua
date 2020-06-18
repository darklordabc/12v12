modifier_mega_creep = class({})

function modifier_mega_creep:IsHidden() return false end
function modifier_mega_creep:IsPurgable() return false end
function modifier_mega_creep:RemoveOnDeath() return false end

function modifier_mega_creep:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_EXTRA_HEALTH_BONUS
	}
end
function modifier_mega_creep:GetTexture()
	return "mega_creep"
end
function modifier_mega_creep:GetModifierPreAttack_BonusDamage()
	return 30
end

function modifier_mega_creep:GetModifierPhysicalArmorBonus()
	return 2
end

function modifier_mega_creep:GetModifierExtraHealthBonus()
	return 200
end
