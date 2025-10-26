local VORPcore = {}
local isOnCooldown = false
local isUsingMedkit = false

-- Initialize VORP Core
TriggerEvent("getCore", function(core)
    VORPcore = core
end)

-- Register usable item
RegisterNetEvent('vorp_medkit:client:useMedkit')
AddEventHandler('vorp_medkit:client:useMedkit', function()
    if isUsingMedkit then
        return
    end

    if Config.UseCooldown and isOnCooldown then
        VORPcore.NotifyTip(Config.Lang["on_cooldown"], 3000)
        return
    end

    local playerPed = PlayerPedId()
    local isDead = Citizen.InvokeNative(0x3317DEDB88C95038, playerPed) -- IsPedDeadOrDying

    if isDead then
        -- Player is dead, try to revive nearby player
        if Config.ReviveEnabled then
            ReviveNearbyPlayer()
        else
            VORPcore.NotifyTip(Config.Lang["no_players"], 3000)
        end
    else
        -- Player is alive, heal yourself
        HealSelf()
    end
end)

-- Heal self function
function HealSelf()
    local playerPed = PlayerPedId()
    local currentHealth = GetEntityHealth(playerPed)
    local maxHealth = GetEntityMaxHealth(playerPed)

    if currentHealth >= maxHealth then
        VORPcore.NotifyTip(Config.Lang["already_healthy"], 3000)
        return
    end

    isUsingMedkit = true

    -- Start progress bar
    VORPcore.NotifyTip(Config.ProgressBar["healing"], Config.HealTime)

    -- Play animation
    local dict = "amb_rest_drunk@world_human_drinking@coffee@male@idle_a"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(100)
    end
    TaskPlayAnim(playerPed, dict, "idle_a", 1.0, 8.0, -1, 1, 0, false, false, false)

    -- Wait for healing time
    Citizen.Wait(Config.HealTime)

    -- Check if player moved or got interrupted
    if isUsingMedkit then
        -- Apply healing
        local newHealth = math.min(currentHealth + Config.HealAmount, maxHealth)
        SetEntityHealth(playerPed, newHealth)

        -- Clear animation
        ClearPedTasks(playerPed)

        -- Notify player
        VORPcore.NotifyTip(Config.Lang["medkit_used"], 3000)

        -- Remove item and start cooldown
        TriggerServerEvent('vorp_medkit:server:removeItem')

        if Config.UseCooldown then
            StartCooldown()
        end
    else
        VORPcore.NotifyTip(Config.Lang["canceled"], 3000)
    end

    isUsingMedkit = false
end

-- Revive nearby player function
function ReviveNearbyPlayer()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPlayer = nil
    local closestDistance = Config.ReviveDistance

    -- Find closest dead player
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local targetPed = GetPlayerPed(player)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)

            local isDead = Citizen.InvokeNative(0x3317DEDB88C95038, targetPed) -- IsPedDeadOrDying

            if isDead and distance < closestDistance then
                closestPlayer = player
                closestDistance = distance
            end
        end
    end

    if closestPlayer == nil then
        VORPcore.NotifyTip(Config.Lang["no_players"], 3000)
        return
    end

    isUsingMedkit = true

    -- Start progress bar
    VORPcore.NotifyTip(Config.ProgressBar["reviving"], Config.ReviveTime)

    -- Play animation
    local dict = "amb_work@world_human_box_pickup@1@male_a@stand_exit_withprop"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(100)
    end
    TaskPlayAnim(playerPed, dict, "exit_front", 1.0, 8.0, -1, 1, 0, false, false, false)

    -- Wait for revive time
    Citizen.Wait(Config.ReviveTime)

    -- Check if still in range
    local targetPed = GetPlayerPed(closestPlayer)
    local newDistance = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))

    if isUsingMedkit and newDistance <= Config.ReviveDistance then
        -- Clear animation
        ClearPedTasks(playerPed)

        -- Trigger revive
        local targetServerId = GetPlayerServerId(closestPlayer)
        TriggerServerEvent('vorp_medkit:server:revivePlayer', targetServerId)

        -- Notify
        VORPcore.NotifyTip(Config.Lang["revived"], 3000)

        -- Remove item and start cooldown
        TriggerServerEvent('vorp_medkit:server:removeItem')

        if Config.UseCooldown then
            StartCooldown()
        end
    else
        VORPcore.NotifyTip(Config.Lang["canceled"], 3000)
        ClearPedTasks(playerPed)
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

    -- Set health
    SetEntityHealth(playerPed, Config.ReviveHealth)

    -- Clear any death effects
    ClearPedBloodDamage(playerPed)

    -- Notify
    VORPcore.NotifyTip(Config.Lang["got_revived"], 5000)
end)

-- Cancel action if player moves too much or takes damage
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)

        if isUsingMedkit then
            local playerPed = PlayerPedId()

            -- Check if player is in combat or taking damage
            if IsPedInMeleeCombat(playerPed) or HasEntityBeenDamagedByAnyPed(playerPed) then
                isUsingMedkit = false
                ClearPedTasks(playerPed)
            end
        end
    end
end)
