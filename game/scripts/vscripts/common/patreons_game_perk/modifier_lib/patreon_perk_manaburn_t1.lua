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
			params.target:SpendMana(GetPerkValue(25, self, 1, 0), nil)
		end
	end
end

--------------------------------------------------------------------------------
function GetPerkValue(const, modifier, levelCounter, bonusPerLevel)
	local heroLvl = modifier:GetParent():GetLevel()
	return math.floor(heroLvl/levelCounter)*bonusPerLevel+const
end
--------------------------------------------------------------------------------
