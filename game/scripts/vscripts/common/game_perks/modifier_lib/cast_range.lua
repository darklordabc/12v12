require("common/game_perks/base_game_perk")

cast_range = class(base_game_perk)

function cast_range:DeclareFunctions() return { MODIFIER_PROPERTY_CAST_RANGE_BONUS_STACKING } end
function cast_range:GetTexture() return "perkIcons/cast_range" end
function cast_range:GetModifierCastRangeBonusStacking() return self.v end

cast_range_t0 = class(cast_range)
cast_range_t1 = class(cast_range)
cast_range_t2 = class(cast_range)
cast_range_t3 = class(cast_range)

function cast_range_t0:OnCreated() self.v = 45 end
function cast_range_t1:OnCreated() self.v = 90 end
function cast_range_t2:OnCreated() self.v = 180 end
function cast_range_t3:OnCreated() self.v = 360 end
