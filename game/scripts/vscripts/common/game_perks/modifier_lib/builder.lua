require("common/game_perks/base_game_perk")
LinkLuaModifier("modifier_builder_tower", 'common/game_perks/modifier_lib/builder', LUA_MODIFIER_MOTION_NONE)

builder = class(base_game_perk)

function builder:GetTexture() return "perkIcons/builder" end
function builder:OnIntervalThink()
	if not IsServer() then return end
	
	local towers = Entities:FindAllByClassname('npc_dota_tower')
	local weakiest_tower
	local parent = self:GetParent()
	
	for _, tower in pairs(towers) do
		if parent:GetTeam() == tower:GetTeam() and ((not weakiest_tower) or weakiest_tower:GetHealth() > tower:GetHealth()) then
			weakiest_tower = tower
		end
	end
	
	if weakiest_tower then
		weakiest_tower:AddNewModifier(parent, nil, "modifier_builder_tower", { duration = 2, heal_per_sec = self.v })
	end
end

modifier_builder_tower = class(base_game_perk)
function modifier_builder_tower:OnCreated(params)
	self.heal_per_sec = params.heal_per_sec
	self:StartIntervalThink(1)

	local parent = self:GetParent()
	self.particle = ParticleManager:CreateParticle("particles/items5_fx/repair_kit.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControl(self.particle, 0, parent:GetAbsOrigin())
	ParticleManager:SetParticleControl(self.particle, 1, parent:GetAbsOrigin())
end
function modifier_builder_tower:OnIntervalThink()
	if not IsServer() then return end
	local parent = self:GetParent()
	parent:Heal(self.heal_per_sec, nil)
end
function modifier_builder_tower:OnDestroy()
	ParticleManager:DestroyParticle(self.particle, false)
	ParticleManager:ReleaseParticleIndex( self.particle )
end
function modifier_builder_tower:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_builder_tower:GetTexture() return "perkIcons/builder" end

builder_t0 = class(builder)
builder_t1 = class(builder)
builder_t2 = class(builder)
builder_t3 = class(builder)

function builder_t0:OnCreated() self.v = 15 self:StartIntervalThink(15) end
function builder_t1:OnCreated() self.v = 30 self:StartIntervalThink(15) end
function builder_t2:OnCreated() self.v = 60 self:StartIntervalThink(15) end
function builder_t3:OnCreated() self.v = 120 self:StartIntervalThink(15) end
