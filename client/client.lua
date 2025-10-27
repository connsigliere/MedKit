local VORPcore = nil
local isOnCooldown = false
local isUsingMedkit = false

-- Initialize VORP Core
Citizen.CreateThread(function()
    while VORPcore == nil do
        TriggerEvent("getCore", function(core)
            VORPcore = core
        end)
        Citizen.Wait(200)
    end
end)

-- Notification helper
function Notify(message, type, duration)
    if type == "left" then
        TriggerEvent("vorp:NotifyLeft", message, duration or 3000)
    else
        TriggerEvent("vorp:NotifyRight", message, duration or 3000)
    end
end

-- Register usable item (double-click in inventory = heal self)
RegisterNetEvent('vorp_medkit:client:useMedkit')
AddEventHandler('vorp_medkit:client:useMedkit', function()
    if isUsingMedkit then
        return
    end

    if Config.UseCooldown and isOnCooldown then
        Notify(Config.Lang["on_cooldown"], "left")
        return
    end

    local playerPed = PlayerPedId()
    local isDead = Citizen.InvokeNative(0x3317DEDB88C95038, playerPed) -- IsPedDeadOrDying

    if isDead then
        Notify(Config.Lang["cannot_use_dead"], "left")
        return
    end

    -- Always heal yourself when using from inventory
    HealSelf()
end)

-- Heal self function with animation
function HealSelf()
    local playerPed = PlayerPedId()
    local currentHealth = GetEntityHealth(playerPed)
    local maxHealth = GetEntityMaxHealth(playerPed)

    if currentHealth >= maxHealth then
        Notify(Config.Lang["already_healthy"], "left")
        return
    end

    isUsingMedkit = true

    -- Notify player
    Notify(Config.ProgressBar["healing"], "left", Config.HealTime)

    -- Play healing scenario animation (crouch and inspect wounds)
    TaskStartScenarioInPlace(playerPed, GetHashKey("WORLD_HUMAN_CROUCH_INSPECT"), 0, true, false, false, false)
    Citizen.Wait(500)

    -- Wait for heal time
    Citizen.Wait(Config.HealTime)

    -- Check if action was interrupted
    if not isUsingMedkit then
        ClearPedTasks(playerPed)
        Notify(Config.Lang["canceled"], "left")
        return
    end

    -- Clear animation
    ClearPedTasks(playerPed)

    -- Calculate heal amount
    local healthToAdd = (maxHealth / 100) * Config.HealAmount
    local newHealth = math.min(currentHealth + healthToAdd, maxHealth)

    -- Apply healing (using multiple methods for reliability)
    SetEntityHealth(playerPed, math.floor(newHealth))
    Citizen.InvokeNative(0xC6258F41D86676E0, playerPed, 0, math.floor(newHealth))
    Citizen.InvokeNative(0xF6A7C08DF2E28B28, playerPed, 0, 1000) -- Add to health core
    Citizen.InvokeNative(0x4AF5A4C7B9157D14, playerPed, 0, 5000.0) -- Fortify health

    -- Notify success
    Notify(Config.Lang["medkit_used"], "right")

    -- Remove item
    TriggerServerEvent('vorp_medkit:server:removeItem')

    -- Start cooldown
    if Config.UseCooldown then
        StartCooldown()
    end

    isUsingMedkit = false
end

-- Cooldown function
function StartCooldown()
    isOnCooldown = true
    Citizen.SetTimeout(Config.CooldownTime, function()
        isOnCooldown = false
    end)
end

-- Handle getting revived
RegisterNetEvent('vorp_medkit:client:revive')
AddEventHandler('vorp_medkit:client:revive', function()
    local playerPed = PlayerPedId()

    -- Revive the player
    local coords = GetEntityCoords(playerPed)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(playerPed), true, false)

    -- Set health (calculate based on max health percentage)
    local maxHealth = GetEntityMaxHealth(playerPed)
    local reviveHealth = (maxHealth / 100) * Config.ReviveHealth
    SetEntityHealth(playerPed, math.floor(reviveHealth))

    -- Clear any death effects
    ClearPedBloodDamage(playerPed)

    -- Notify
    Notify(Config.Lang["got_revived"], "right", 5000)
end)

-- Keybind system for reviving nearby dead players
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if not isUsingMedkit and Config.ReviveEnabled then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local isDead = Citizen.InvokeNative(0x3317DEDB88C95038, playerPed)

            -- Only show prompt if player is alive
            if not isDead then
                -- Find closest dead player
                local closestPlayer = nil
                local closestDistance = Config.ReviveDistance

                for _, player in ipairs(GetActivePlayers()) do
                    if player ~= PlayerId() then
                        local targetPed = GetPlayerPed(player)
                        local targetCoords = GetEntityCoords(targetPed)
                        local distance = #(playerCoords - targetCoords)
                        local isTargetDead = Citizen.InvokeNative(0x3317DEDB88C95038, targetPed)

                        if isTargetDead and distance < closestDistance then
                            closestPlayer = player
                            closestDistance = distance
                        end
                    end
                end

                -- If dead player nearby, show prompt
                if closestPlayer ~= nil then
                    -- Draw text on screen
                    local str = "Press ~COLOR_PURE_WHITE~[E]~q~ to revive player"
                    local _str = Citizen.InvokeNative(0xFA925AC00EB830B9, 10, "LITERAL_STRING", str, Citizen.ResultAsLong())
                    Citizen.InvokeNative(0xFA233F8FE190514C, _str)
                    Citizen.InvokeNative(0xE9990552DEC71600)

                    -- Check for E key press
                    if Citizen.InvokeNative(0x580417101DDB492F, 0, 0xCEFD9220) then -- INPUT_CONTEXT (E key)
                        -- Check if player has medkit
                        TriggerServerEvent('vorp_medkit:server:checkMedkitForRevive', GetPlayerServerId(closestPlayer))
                    end
                end
            end
        else
            Citizen.Wait(500)
        end
    end
end)

-- Handle revive with medkit check
RegisterNetEvent('vorp_medkit:client:reviveWithMedkit')
AddEventHandler('vorp_medkit:client:reviveWithMedkit', function(targetServerId)
    if isUsingMedkit then
        return
    end

    if Config.UseCooldown and isOnCooldown then
        Notify(Config.Lang["on_cooldown"], "left")
        return
    end

    -- Find the target player
    local targetPlayer = nil
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == targetServerId then
            targetPlayer = player
            break
        end
    end

    if targetPlayer == nil then
        Notify(Config.Lang["no_players"], "left")
        return
    end

    local playerPed = PlayerPedId()
    local targetPed = GetPlayerPed(targetPlayer)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(playerCoords - targetCoords)

    if distance > Config.ReviveDistance then
        Notify(Config.Lang["too_far"], "left")
        return
    end

    isUsingMedkit = true

    -- Start progress bar
    Notify(Config.ProgressBar["reviving"], "left", Config.ReviveTime)

    -- Play animation
    local dict = "amb_work@world_human_box_pickup@1@male_a@stand_exit_withprop"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(100)
    end
    TaskPlayAnim(playerPed, dict, "exit_front", 1.0, 8.0, -1, 1, 0, false, false, false)

    -- Wait for revive time
    Citizen.Wait(Config.ReviveTime)

    -- Check if still in range and action not interrupted
    local newDistance = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))

    if isUsingMedkit and newDistance <= Config.ReviveDistance then
        -- Clear animation
        ClearPedTasks(playerPed)

        -- Trigger revive
        TriggerServerEvent('vorp_medkit:server:revivePlayer', targetServerId)

        -- Notify
        Notify(Config.Lang["revived"], "right")

        -- Remove item and start cooldown
        TriggerServerEvent('vorp_medkit:server:removeItem')

        if Config.UseCooldown then
            StartCooldown()
        end
    else
        Notify(Config.Lang["canceled"], "left")
        ClearPedTasks(playerPed)
    end

    isUsingMedkit = false
end)

-- Cancel action if player moves too much or takes damage
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)

        if isUsingMedkit then
            local playerPed = PlayerPedId()

            -- Check if player is in combat or taking damage
            local inCombat = IsPedInMeleeCombat(playerPed)
            local takenDamage = HasEntityBeenDamagedByAnyPed(playerPed)

            if inCombat or takenDamage then
                isUsingMedkit = false
                ClearPedTasks(playerPed)
                Notify(Config.Lang["canceled"], "left")
            end
        end
    end
end)
