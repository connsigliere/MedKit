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

    -- Register medkit as usable item
    local VORPInv = exports.vorp_inventory:vorp_inventoryApi()

    VORPInv.RegisterUsableItem(Config.MedkitItem, function(data)
        local source = data.source

        if VORPcore then
            local User = VORPcore.getUser(source)
            if User then
                -- Trigger client event to use medkit
                TriggerClientEvent('vorp_medkit:client:useMedkit', source)
            end
        end
    end)

    print("[VORP Medkit] Resource loaded successfully")
end)

-- Remove item from inventory
RegisterNetEvent('vorp_medkit:server:removeItem')
AddEventHandler('vorp_medkit:server:removeItem', function()
    local _source = source

    if Config.RemoveOnUse then
        local VORPInv = exports.vorp_inventory:vorp_inventoryApi()
        local itemCount = VORPInv.getItemCount(_source, Config.MedkitItem)

        if itemCount > 0 then
            VORPInv.subItem(_source, Config.MedkitItem, 1)
        end
    end
end)

-- Check if player has medkit before revive
RegisterNetEvent('vorp_medkit:server:checkMedkitForRevive')
AddEventHandler('vorp_medkit:server:checkMedkitForRevive', function(targetId)
    local _source = source

    -- Check if player has medkit
    local VORPInv = exports.vorp_inventory:vorp_inventoryApi()
    local itemCount = VORPInv.getItemCount(_source, Config.MedkitItem)

    if itemCount > 0 then
        -- Player has medkit, proceed with revive
        TriggerClientEvent('vorp_medkit:client:reviveWithMedkit', _source, targetId)
    else
        -- Player doesn't have medkit
        TriggerClientEvent('vorp:TipLeft', _source, 'You need a medkit to revive players', 3000)
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

        -- Log for admin purposes
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
