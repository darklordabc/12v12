modifier_super_tower = class({})

function modifier_super_tower:IsHidden() return false end
function modifier_super_tower:IsPurgable() return false end
function modifier_super_tower:RemoveOnDeath() return false end

function modifier_super_tower:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS
	}
end
function modifier_super_tower:GetTexture()
	return "super_tower"
end
function modifier_super_tower:GetModifierPreAttack_BonusDamage()
	return 110
end

function modifier_super_tower:GetModifierPhysicalArmorBonus()
	return 12
end
