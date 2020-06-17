patreon_perk_agi_for_kill_t0 = class({})
--------------------------------------------------------------------------------

function patreon_perk_agi_for_kill_t0:IsHidden()
	return false
end

--------------------------------------------------------------------------------
function patreon_perk_agi_for_kill_t0:GetTexture()
	return "perkIcons/patreon_perk_agi_for_kill_t0"
end

--------------------------------------------------------------------------------

function patreon_perk_agi_for_kill_t0:IsPurgable()
	return false
end
--------------------------------------------------------------------------------
function patreon_perk_agi_for_kill_t0:RemoveOnDeath()
	return false
end
--------------------------------------------------------------------------------

function patreon_perk_agi_for_kill_t0:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
	}
	return funcs
end
--------------------------------------------------------------------------------

function patreon_perk_agi_for_kill_t0:GetModifierBonusStats_Agility()
	return GetPerkValue(1, self, 1, 0)*self:GetParent():GetKills()
end


--------------------------------------------------------------------------------
function GetPerkValue(const, modifier, levelCounter, bonusPerLevel)
	local heroLvl = modifier:GetParent():GetLevel()
	return math.floor(heroLvl/levelCounter)*bonusPerLevel+const
end
--------------------------------------------------------------------------------
