patreon_perk_cd_after_deadth_t2 = class({})
--------------------------------------------------------------------------------

function patreon_perk_cd_after_deadth_t2:IsHidden()
	return false
end

--------------------------------------------------------------------------------
function patreon_perk_cd_after_deadth_t2:GetTexture()
	return "perkIcons/patreon_perk_cd_after_deadth_t0"
end

--------------------------------------------------------------------------------

function patreon_perk_cd_after_deadth_t2:IsPurgable()
	return false
end
--------------------------------------------------------------------------------
function patreon_perk_cd_after_deadth_t2:OnCreated()
	self:GetParent().reduceCooldownAfterRespawn = GetPerkValue(50, self, 1, 0)
end
----------------------------------------------------------------------------------
function patreon_perk_cd_after_deadth_t2:RemoveOnDeath()
	return false
end
--------------------------------------------------------------------------------
function GetPerkValue(const, modifier, levelCounter, bonusPerLevel)
	local heroLvl = modifier:GetParent():GetLevel()
	return math.floor(heroLvl/levelCounter)*bonusPerLevel+const
end
--------------------------------------------------------------------------------
