require("common/game_perks/base_game_perk")

hp_regen = class(base_game_perk)

function hp_regen:DeclareFunctions() return { MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT } end
function hp_regen:GetTexture() return "perkIcons/hp_regen" end
function hp_regen:GetModifierConstantHealthRegen()
	return self:GetPerkValue(self.v[1], self.v[2], self.v[3])
end

hp_regen_t0 = class(hp_regen)
hp_regen_t1 = class(hp_regen)
hp_regen_t2 = class(hp_regen)
hp_regen_t3 = class(hp_regen)

function hp_regen_t0:OnCreated() self.v = {1.5, 1, 0.25} end
function hp_regen_t1:OnCreated() self.v = {3, 1, 0.5} end
function hp_regen_t2:OnCreated() self.v = {6, 1, 1} end
function hp_regen_t3:OnCreated() self.v = {12, 1, 2} end
