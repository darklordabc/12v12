-- credits: yahnich
function CDOTA_BaseNPC:IsFakeHero()
	if self:IsIllusion() or (self:HasModifier("modifier_monkey_king_fur_army_soldier") or self:HasModifier("modifier_monkey_king_fur_army_soldier_hidden")) or self:IsTempestDouble() or self:IsClone() then
		return true
	else return false end
end

-- credits: yahnich
function CDOTA_BaseNPC:IsRealHero()
	if not self:IsNull() then
		return self:IsHero() and not (self:IsIllusion() or self:IsClone()) and not self:IsFakeHero()
	end
end

function math.sign(x)
	if x > 0 then
		return 1
	elseif x < 0 then
		return -1
	else
		return 0
	end
end

function ExpandVector(vec, by)
	return Vector(
		(math.abs(vec.x) + by) * math.sign(vec.x),
		(math.abs(vec.y) + by) * math.sign(vec.y),
		(math.abs(vec.z) + by) * math.sign(vec.z)
	)
end

function IsInBox(point, point1, point2)
	return point.x > point1.x and point.y > point1.y and point.x < point2.x and point.y < point2.y
end

function IsInTriggerBox(trigger, extension, vector)
	local origin = trigger:GetAbsOrigin()
	return IsInBox(
		vector,
		origin + ExpandVector(trigger:GetBoundingMins(), extension),
		origin + ExpandVector(trigger:GetBoundingMaxs(), extension)
	)
end


function table.find(tbl, f)
  	for _, v in ipairs(tbl) do
	    if f == v then
	      	return v
	    end
  	end
  	return false
end

function table.length(tbl)
	local amount = 0
	for __,___ in pairs(tbl) do
		amount = amount + 1
	end
  	return amount
end


function table.concat(tbl1,tbl2)
	local tbl = {}
	for k,v in ipairs(tbl1) do
		table.insert(tbl,v)
	end
	for k,v in ipairs(tbl2) do
		table.insert(tbl,v)
	end

	return tbl
end

function CalculateDirection(ent1, ent2)
	local pos1 = ent1
	local pos2 = ent2
	if ent1.GetAbsOrigin then pos1 = ent1:GetAbsOrigin() end
	if ent2.GetAbsOrigin then pos2 = ent2:GetAbsOrigin() end
	local direction = (pos1 - pos2):Normalized()
	return direction
end

function FindUnitsInCone(teamNumber, vDirection, vPosition, startRadius, endRadius, flLength, hCacheUnit, targetTeam, targetUnit, targetFlags, findOrder, bCache, bIsFullCircle)
	local unitTable = {}
	local radiusSearch = endRadius + flLength
	if bIsFullCircle then radiusSearch = flLength end

	local enemies = FindUnitsInRadius(teamNumber, vPosition, hCacheUnit, radiusSearch, targetTeam, targetUnit, targetFlags, findOrder, bCache )

	if #enemies > 0 then
		if bIsFullCircle then
			unitTable = enemies
		else
			local vDirectionCone = Vector( vDirection.y, -vDirection.x, 0.0 )
			for _,enemy in pairs(enemies) do
				if enemy ~= nil then
					local vToPotentialTarget = enemy:GetOrigin() - vPosition
					local flSideAmount = math.abs( vToPotentialTarget.x * vDirectionCone.x + vToPotentialTarget.y * vDirectionCone.y + vToPotentialTarget.z * vDirectionCone.z )
					local enemy_distance_from_caster = ( vToPotentialTarget.x * vDirection.x + vToPotentialTarget.y * vDirection.y + vToPotentialTarget.z * vDirection.z )

					local max_increased_radius_from_distance = endRadius - startRadius

					local pct_distance = enemy_distance_from_caster / flLength

					local radius_increase_from_distance = max_increased_radius_from_distance * pct_distance

					if (( flSideAmount < startRadius + radius_increase_from_distance ) and ( enemy_distance_from_caster > 0.0 ) and ( enemy_distance_from_caster < flLength )) or (vToPotentialTarget:Length2D() < startRadius) then
						table.insert(unitTable, enemy)
					end
				end
			end
		end
	end
	return unitTable
end
