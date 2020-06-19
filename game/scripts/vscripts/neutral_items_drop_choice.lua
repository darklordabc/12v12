function DropItem(data)
	local item = EntIndexToHScript( data.item )
	local player = PlayerResource:GetPlayer(data.PlayerID)

	local team = player:GetTeam()
	local fountain
	local multiplier

	if team == DOTA_TEAM_GOODGUYS then
		multiplier = -350
		fountain = Entities:FindByName( nil, "ent_dota_fountain_good" )
	elseif team == DOTA_TEAM_BADGUYS then
		multiplier = -650
		fountain = Entities:FindByName( nil, "ent_dota_fountain_bad" )
	end

	local fountain_pos = fountain:GetAbsOrigin()
	local pos_item = fountain_pos:Normalized() * multiplier + RandomVector( RandomFloat( 0, 200 ) ) + fountain_pos
	pos_item.z = fountain_pos.z

	CreateItemOnPositionSync(pos_item, item)
	item.neutralDropInBase = true
	for i = 0, 24 do
		if data.PlayerID ~= i and PlayerResource:GetTeam(i) == team then -- remove check "data.PlayerID ~= i" ig you want test system
			CustomGameEventManager:Send_ServerToPlayer( PlayerResource:GetPlayer( i ), "neutral_item_dropped", { item = data.item } )
		end
	end
	Timers:CreateTimer(15,function() -- !!! You need put here time from function NeutralItemDropped from neutral_items.js - Shelude
		local container = item:GetContainer()
		if container then
			local hero =  player:GetAssignedHero()
			local shop = SearchCorrectNeutralShopByTeam(hero:GetTeamNumber())
			if shop then
				local dummyInventory = player.dummyInventory
				if not dummyInventory then return end
				UTIL_Remove(container)
				dummyInventory:AddItem(item)
				ExecuteOrderFromTable({
					UnitIndex = dummyInventory:entindex(),
					OrderType = 37,
					AbilityIndex = item:entindex(),
				})
			end
		end
		return nil
	end)
end
function CheckNeutralItemForUnit(unit)
	local count = 0
	if unit and unit:HasInventory() then
		for i = 0, 20 do
			local item = unit:GetItemInSlot(i)
			if item then
				if _G.neutralItems[item:GetAbilityName()] then count = count + 1 end
			end
		end
	end
	return count
end

function CheckCountOfNeutralItemsForPlayer(playerId)
	local hero = PlayerResource:GetSelectedHeroEntity(playerId)
	local neutralItemsForPlayer = CheckNeutralItemForUnit(hero)
	if neutralItemsForPlayer >= MAX_NEUTRAL_ITEMS_FOR_PLAYER then return neutralItemsForPlayer end
	local playersCourier
	local couriers = Entities:FindAllByName("npc_dota_courier")
	for _, courier in pairs(couriers) do
		if courier:GetPlayerOwnerID() == playerId then
			playersCourier = courier
		end
	end
	if playersCourier then
		neutralItemsForPlayer = neutralItemsForPlayer + CheckNeutralItemForUnit(playersCourier)
	end
	return neutralItemsForPlayer
end

function NotificationToAllPlayerOnTeam(data)
	for id = 0, 24 do
		if PlayerResource:GetTeam( data.PlayerID ) == PlayerResource:GetTeam( id ) then
			CustomGameEventManager:Send_ServerToPlayer( PlayerResource:GetPlayer( id ), "neutral_item_taked", { item = data.item, player = data.PlayerID } )
		end
	end
end

RegisterCustomEventListener( "neutral_item_keep", function( data )
	if CheckCountOfNeutralItemsForPlayer(data.PlayerID) >= _G.MAX_NEUTRAL_ITEMS_FOR_PLAYER then
		DropItem(data)
		DisplayError(data.PlayerID, "#player_still_have_a_lot_of_neutral_items")
		return
	end
	local item = EntIndexToHScript( data.item )
	local hero = PlayerResource:GetSelectedHeroEntity( data.PlayerID )
	local freeSlot = DoesHeroHasFreeSlot(hero)
	if freeSlot then
		hero:AddItem(item)
		NotificationToAllPlayerOnTeam(data)
	else
		DropItem(data)
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(data.PlayerID), "display_custom_error", { message = "#inventory_full_custom_message" })
	end
end )

RegisterCustomEventListener( "neutral_item_take", function( data )
	if CheckCountOfNeutralItemsForPlayer(data.PlayerID) >= MAX_NEUTRAL_ITEMS_FOR_PLAYER then
		DisplayError(data.PlayerID, "#player_still_have_a_lot_of_neutral_items")
		return
	end
	local item = EntIndexToHScript( data.item )
	local hero = PlayerResource:GetSelectedHeroEntity( data.PlayerID )
	local freeSlot = DoesHeroHasFreeSlot(hero)

	if freeSlot then
		if item.neutralDropInBase then
			item.neutralDropInBase = false
			local container = item:GetContainer()
			UTIL_Remove( container )
			hero:AddItem( item )
			NotificationToAllPlayerOnTeam(data)
		end
	else
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(data.PlayerID), "display_custom_error", { message = "#inventory_full_custom_message" })
	end
end )

RegisterCustomEventListener( "neutral_item_drop", function( data )
	DropItem(data)
end )

function SearchCorrectNeutralShopByTeam(team)
	local neutralShops = Entities:FindAllByClassname('ent_dota_neutral_item_stash')
	for _, focusShop in pairs(neutralShops) do
		if focusShop:GetTeamNumber() == team then
			return focusShop
		end
	end
	return false
end
