require("common/game_perks/base_game_perk")

mp_regen = class(base_game_perk)

function mp_regen:DeclareFunctions() return { MODIFIER_PROPERTY_MANA_REGEN_CONSTANT } end
function mp_regen:GetTexture() return "perkIcons/mp_regen" end
function mp_regen:GetModifierConstantManaRegen()
	return self:GetPerkValue(self.v[1], self.v[2], self.v[3])
end

mp_regen_t0 = class(mp_regen)
mp_regen_t1 = class(mp_regen)
mp_regen_t2 = class(mp_regen)
mp_regen_t3 = class(mp_regen)

function mp_regen_t0:OnCreated() self.v = {0.75, 1, 0.1} end
function mp_regen_t1:OnCreated() self.v = {1.5, 1, 0.2} end
function mp_regen_t2:OnCreated() self.v = {3, 1, 0.4} end
function mp_regen_t3:OnCreated() self.v = {6, 1, 0.8} end
