require("common/game_perks/base_game_perk")

spell_lifesteal = class(base_game_perk)

function spell_lifesteal:DeclareFunctions() return { MODIFIER_EVENT_ON_TAKEDAMAGE } end
function spell_lifesteal:GetTexture() return "perkIcons/spell_lifesteal" end

function spell_lifesteal:OnTakeDamage(params)
	if self:GetParent() ~= params.attacker then return end
	if params.damage <= 0 then return end
	if bit.band(params.damage_flags, DOTA_DAMAGE_FLAG_REFLECTION) == DOTA_DAMAGE_FLAG_REFLECTION then return end
	if params.infilctor or DOTA_DAMAGE_CATEGORY_ATTACK == params.damage_category then return end

	local attacker = params.attacker
	local steal = math.max(1, params.damage * ( self.v / 100))

	if params.target and (not params.target:IsHero()) then
		steal = 0.2 * steal
	end

	attacker:Heal(steal, self)
	local particle = ParticleManager:CreateParticle("particles/generic_gameplay/generic_lifesteal.vpcf", PATTACH_OVERHEAD_FOLLOW, params.attacker)
	ParticleManager:SetParticleControl(particle, 0, params.attacker:GetAbsOrigin())
	SendOverheadEventMessage(params.unit, OVERHEAD_ALERT_HEAL, params.attacker, steal, nil)
end

spell_lifesteal_t0 = class(spell_lifesteal)
spell_lifesteal_t1 = class(spell_lifesteal)
spell_lifesteal_t2 = class(spell_lifesteal)
spell_lifesteal_t3 = class(spell_lifesteal)

function spell_lifesteal_t0:OnCreated() self.v = 5 end
function spell_lifesteal_t1:OnCreated() self.v = 10 end
function spell_lifesteal_t2:OnCreated() self.v = 20 end
function spell_lifesteal_t3:OnCreated() self.v = 40 end
