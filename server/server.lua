local VORPcore = nil

-- Initialize VORP Core
Citizen.CreateThread(function()
    while VORPcore == nil do
        TriggerEvent("getCore", function(core)
            VORPcore = core
        end)
        Citizen.Wait(200)
    end
    print("[VORP Medkit] Server - Core initialized successfully")
end)

-- Wait for VORP Inventory to be ready
Citizen.CreateThread(function()
    Citizen.Wait(2000)

    print("[VORP Medkit] Registering usable item: " .. Config.MedkitItem)

    -- Register medkit as usable item
    local VORPInv = exports.vorp_inventory:vorp_inventoryApi()

    VORPInv.RegisterUsableItem(Config.MedkitItem, function(data)
        local source = data.source
        print("[VORP Medkit] Player " .. source .. " used medkit")

        if VORPcore then
            local User = VORPcore.getUser(source)

            if User then
                print("[VORP Medkit] User found, triggering client event")
                -- Trigger client event to use medkit
                TriggerClientEvent('vorp_medkit:client:useMedkit', source)
            else
                print("[VORP Medkit] ERROR: User not found for source " .. source)
            end
        else
            print("[VORP Medkit] ERROR: VORPcore not initialized")
        end
    end)

    print("[VORP Medkit] Item registered successfully")
end)

-- Remove item from inventory
RegisterNetEvent('vorp_medkit:server:removeItem')
AddEventHandler('vorp_medkit:server:removeItem', function()
    local _source = source

    print("[VORP Medkit] Attempting to remove item from player " .. _source)

    if Config.RemoveOnUse then
        local VORPInv = exports.vorp_inventory:vorp_inventoryApi()
        local itemCount = VORPInv.getItemCount(_source, Config.MedkitItem)

        print("[VORP Medkit] Player has " .. itemCount .. " medkits")

        if itemCount > 0 then
            VORPInv.subItem(_source, Config.MedkitItem, 1)
            print("[VORP Medkit] Removed 1 medkit from player " .. _source)
        else
            print("[VORP Medkit] No medkit to remove from player " .. _source)
        end
    else
        print("[VORP Medkit] RemoveOnUse is disabled")
    end
end)

-- Revive player
RegisterNetEvent('vorp_medkit:server:revivePlayer')
AddEventHandler('vorp_medkit:server:revivePlayer', function(targetId)
    local _source = source

    -- Validate that the target player exists
    if targetId and GetPlayerPing(targetId) > 0 then
        -- Trigger revive on target client
        TriggerClientEvent('vorp_medkit:client:revive', targetId)

        -- Log for admin purposes (optional)
        print(string.format("[VORP Medkit] Player %s revived player %s", GetPlayerName(_source), GetPlayerName(targetId)))
    end
end)

-- Command to give medkit (admin only)
RegisterCommand('givemedkit', function(source, args, rawCommand)
    local _source = source
    local User = VORPcore.getUser(_source)

    if User then
        local group = User.getGroup()

        if group == 'admin' or group == 'superadmin' then
            local targetId = tonumber(args[1])
            local amount = tonumber(args[2]) or 1

            if targetId then
                local VORPInv = exports.vorp_inventory:vorp_inventoryApi()
                local canCarry = VORPInv.canCarryItem(targetId, Config.MedkitItem, amount)

                if canCarry then
                    VORPInv.addItem(targetId, Config.MedkitItem, amount)
                    TriggerClientEvent('vorp:TipRight', _source, string.format('Gave %dx medkit to player %s', amount, GetPlayerName(targetId)), 3000)
                    TriggerClientEvent('vorp:TipRight', targetId, string.format('You received %dx medkit', amount), 3000)
                else
                    TriggerClientEvent('vorp:TipRight', _source, 'Player cannot carry more items', 3000)
                end
            else
                TriggerClientEvent('vorp:TipRight', _source, 'Usage: /givemedkit [player_id] [amount]', 3000)
            end
        else
            TriggerClientEvent('vorp:TipRight', _source, 'You do not have permission to use this command', 3000)
        end
    end
end, false)
