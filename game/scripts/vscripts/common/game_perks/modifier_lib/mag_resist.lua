require("common/game_perks/base_game_perk")

mag_resist = class(base_game_perk)

function mag_resist:DeclareFunctions() return { MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS } end
function mag_resist:GetTexture() return "perkIcons/mag_resist" end
function mag_resist:GetModifierMagicalResistanceBonus() return self.v end

mag_resist_t0 = class(mag_resist)
mag_resist_t1 = class(mag_resist)
mag_resist_t2 = class(mag_resist)
mag_resist_t3 = class(mag_resist)

function mag_resist_t0:OnCreated() self.v = 10 end
function mag_resist_t1:OnCreated() self.v = 20 end
function mag_resist_t2:OnCreated() self.v = 35 end
function mag_resist_t3:OnCreated() self.v = 50 end
