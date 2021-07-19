require("common/game_perks/base_game_perk")

evasion = class(base_game_perk)

function evasion:DeclareFunctions() return { MODIFIER_PROPERTY_EVASION_CONSTANT } end
function evasion:GetTexture() return "perkIcons/evasion" end
function evasion:GetModifierEvasion_Constant() return self.v end

evasion_t0 = class(evasion)
evasion_t1 = class(evasion)
evasion_t2 = class(evasion)
evasion_t3 = class(evasion)

function evasion_t0:OnCreated() self.v = 15 end
function evasion_t1:OnCreated() self.v = 25 end
function evasion_t2:OnCreated() self.v = 40 end
function evasion_t3:OnCreated() self.v = 60 end
