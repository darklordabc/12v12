require("common/game_perks/base_game_perk")

int_for_kill = class(base_game_perk)

function int_for_kill:DeclareFunctions() return { MODIFIER_PROPERTY_STATS_INTELLECT_BONUS, MODIFIER_EVENT_ON_HERO_KILLED } end

function int_for_kill:OnHeroKilled(keys)
	if not IsServer() then return end
	local killerID = keys.attacker:GetPlayerOwnerID()

	if killerID and killerID == self:GetParent():GetPlayerOwnerID() and keys.target:GetTeam() ~= self:GetParent():GetTeam() then
		self:IncrementStackCount()
		self:GetParent():CalculateStatBonus(false)
	end
end
function int_for_kill:GetTexture() return "perkIcons/int_for_kill" end

function int_for_kill:GetModifierBonusStats_Intellect()
	if self:GetParent():HasModifier("modifier_meepo_divided_we_stand") then return end
	return self.v * self:GetStackCount()
end

int_for_kill_t0 = class(int_for_kill)
int_for_kill_t1 = class(int_for_kill)
int_for_kill_t2 = class(int_for_kill)
int_for_kill_t3 = class(int_for_kill)

function int_for_kill_t0:OnCreated() self.v = 1.2 end
function int_for_kill_t1:OnCreated() self.v = 2.4 end
function int_for_kill_t2:OnCreated() self.v = 3.6 end
function int_for_kill_t3:OnCreated() self.v = 4.8 end
