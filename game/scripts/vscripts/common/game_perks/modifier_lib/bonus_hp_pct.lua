require("common/game_perks/base_game_perk")

bonus_hp_pct = class(base_game_perk)

function bonus_hp_pct:DeclareFunctions() return { MODIFIER_PROPERTY_EXTRA_HEALTH_PERCENTAGE } end
function bonus_hp_pct:GetTexture() return "perkIcons/bonus_hp_pct" end
function bonus_hp_pct:GetModifierExtraHealthPercentage() return self.v end

bonus_hp_pct_t0 = class(bonus_hp_pct)
bonus_hp_pct_t1 = class(bonus_hp_pct)
bonus_hp_pct_t2 = class(bonus_hp_pct)

function bonus_hp_pct_t0:OnCreated() self.v = 5 end
function bonus_hp_pct_t1:OnCreated() self.v = 10 end
function bonus_hp_pct_t2:OnCreated() self.v = 20 end
