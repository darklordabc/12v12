require("common/game_perks/base_game_perk")

cd_after_death = class(base_game_perk)

function cd_after_death:DeclareFunctions() return { MODIFIER_EVENT_ON_DEATH } end
function cd_after_death:GetTexture() return "perkIcons/cd_after_death" end

function cd_after_death:OnDeath(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	if params.unit ~= parent then return end

	if not parent:IsReincarnating() then
		parent.reduceCooldownAfterRespawn = self.v
	else
		parent.reduceCooldownAfterRespawn = false
	end
end

cd_after_death_t0 = class(cd_after_death)
cd_after_death_t1 = class(cd_after_death)
cd_after_death_t2 = class(cd_after_death)
cd_after_death_t3 = class(cd_after_death)

function cd_after_death_t0:OnCreated() self.v = 40 end
function cd_after_death_t1:OnCreated() self.v = 60 end
function cd_after_death_t2:OnCreated() self.v = 80 end
function cd_after_death_t3:OnCreated() self.v = 100 end
