patreon_perk_manaburn_t2 = class({})
--------------------------------------------------------------------------------

function patreon_perk_manaburn_t2:IsHidden()
	return false
end

--------------------------------------------------------------------------------
function patreon_perk_manaburn_t2:GetTexture()
	return "perkIcons/patreon_perk_manaburn_t0"
end

--------------------------------------------------------------------------------


function patreon_perk_manaburn_t2:IsPurgable()
	return false
end
--------------------------------------------------------------------------------
---
function patreon_perk_manaburn_t2:RemoveOnDeath()
	return false
end
--------------------------------------------------------------------------------

function patreon_perk_manaburn_t2:DeclareFunctions()
	local funcs = {
		MODIFIER_EVENT_ON_ATTACK_LANDED,
	}
	return funcs
end
--------------------------------------------------------------------------------

function patreon_perk_manaburn_t2:OnAttackLanded(params)
	if IsServer() then
		params.target:SpendMana(GetPerkValue(35, self, 1, 0), nil)
	end
end

--------------------------------------------------------------------------------
function GetPerkValue(const, modifier, levelCounter, bonusPerLevel)
	local heroLvl = modifier:GetParent():GetLevel()
	return math.floor(heroLvl/levelCounter)*bonusPerLevel+const
end
--------------------------------------------------------------------------------
