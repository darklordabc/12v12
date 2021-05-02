require("common/game_perks/base_game_perk")

bonus_movespeed = class(base_game_perk)

function bonus_movespeed:DeclareFunctions()	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT } end
function bonus_movespeed:GetTexture() return "perkIcons/bonus_movespeed" end
function bonus_movespeed:GetModifierMoveSpeedBonus_Constant() return self.v end

bonus_movespeed_t0 = class(bonus_movespeed)
bonus_movespeed_t1 = class(bonus_movespeed)
bonus_movespeed_t2 = class(bonus_movespeed)

function bonus_movespeed_t0:OnCreated() self.v = 10 end
function bonus_movespeed_t1:OnCreated() self.v = 20 end
function bonus_movespeed_t2:OnCreated() self.v = 40 end
