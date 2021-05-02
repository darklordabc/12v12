require("common/game_perks/base_game_perk")

manaburn = class(base_game_perk)

function manaburn:DeclareFunctions() return { MODIFIER_EVENT_ON_ATTACK_LANDED } end
function manaburn:GetTexture() return "perkIcons/manaburn" end

function manaburn:OnAttackLanded(params)
	if not IsServer() then return end
	if params.attacker ~= self:GetParent() then return end

	local target_mana = params.target:GetMana()
	local mana_burn = self.v
	if mana_burn > target_mana then
		mana_burn = target_mana
	end
	params.target:SpendMana(mana_burn, nil)
	if mana_burn > 1 then
		EmitSoundOnLocationWithCaster( params.target:GetAbsOrigin(), "Hero_Antimage.ManaBreak", params.attacker )
		local particle = ParticleManager:CreateParticle("particles/generic_gameplay/generic_manaburn.vpcf", PATTACH_ROOTBONE_FOLLOW, params.target)
		ParticleManager:ReleaseParticleIndex(particle)
		local damage = {
			victim = params.target,
			attacker = params.attacker,
			damage = mana_burn,
			damage_type = DAMAGE_TYPE_PHYSICAL,
			ability = nil
		}
		ApplyDamage(damage)
	end
end

manaburn_t0 = class(manaburn)
manaburn_t1 = class(manaburn)
manaburn_t2 = class(manaburn)

function manaburn_t0:OnCreated() self.v = 8 end
function manaburn_t1:OnCreated() self.v = 16 end
function manaburn_t2:OnCreated() self.v = 32 end
