require("common/game_perks/base_game_perk")

lifesteal = class(base_game_perk)

function lifesteal:DeclareFunctions() return { MODIFIER_EVENT_ON_TAKEDAMAGE } end
function lifesteal:GetTexture() return "perkIcons/lifesteal" end

function lifesteal:OnTakeDamage(params)
	if self:GetParent() ~= params.attacker then return end
	if DOTA_DAMAGE_CATEGORY_ATTACK ~= params.damage_category then return end
	if params.damage <= 0 then return end
	local attacker = params.attacker
	local steal = params.damage * (self.v/100)

	attacker:Heal(steal, self)

	local particle = ParticleManager:CreateParticle("particles/generic_gameplay/generic_lifesteal.vpcf", PATTACH_OVERHEAD_FOLLOW, params.attacker)
	ParticleManager:SetParticleControl(particle, 0, params.attacker:GetAbsOrigin())
	SendOverheadEventMessage(params.unit, OVERHEAD_ALERT_HEAL, params.attacker, steal, nil)
end

lifesteal_t0 = class(lifesteal)
lifesteal_t1 = class(lifesteal)
lifesteal_t2 = class(lifesteal)
lifesteal_t3 = class(lifesteal)

function lifesteal_t0:OnCreated() self.v = 8 end
function lifesteal_t1:OnCreated() self.v = 16 end
function lifesteal_t2:OnCreated() self.v = 32 end
function lifesteal_t3:OnCreated() self.v = 64 end
