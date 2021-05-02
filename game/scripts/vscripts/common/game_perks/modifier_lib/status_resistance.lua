require("common/game_perks/base_game_perk")

status_resistance = class(base_game_perk)

function status_resistance:DeclareFunctions() return { MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING } end
function status_resistance:GetTexture() return "perkIcons/status_resistance" end
function status_resistance:GetModifierStatusResistanceStacking() return self.v end

status_resistance_t0 = class(status_resistance)
status_resistance_t1 = class(status_resistance)
status_resistance_t2 = class(status_resistance)

function status_resistance_t0:OnCreated() self.v = 9 end
function status_resistance_t1:OnCreated() self.v = 18 end
function status_resistance_t2:OnCreated() self.v = 36 end
