require("common/game_perks/base_game_perk")

cooldown_reduction = class(base_game_perk)

function cooldown_reduction:DeclareFunctions() return { MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE } end
function cooldown_reduction:GetTexture() return "perkIcons/cooldown_reduction" end
function cooldown_reduction:GetModifierPercentageCooldown() return self.v end

cooldown_reduction_t0 = class(cooldown_reduction)
cooldown_reduction_t1 = class(cooldown_reduction)
cooldown_reduction_t2 = class(cooldown_reduction)
cooldown_reduction_t3 = class(cooldown_reduction)

function cooldown_reduction_t0:OnCreated() self.v = 4 end
function cooldown_reduction_t1:OnCreated() self.v = 8 end
function cooldown_reduction_t2:OnCreated() self.v = 15 end
function cooldown_reduction_t3:OnCreated() self.v = 25 end
