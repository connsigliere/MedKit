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
    print("[VORP Medkit] Core initialized successfully")
end)

-- Notification helper
function Notify(message, type, duration)
    if type == "left" then
        TriggerEvent("vorp:NotifyLeft", message, duration or 3000)
    else
        TriggerEvent("vorp:NotifyRight", message, duration or 3000)
    end
end

-- Register usable item
RegisterNetEvent('vorp_medkit:client:useMedkit')
AddEventHandler('vorp_medkit:client:useMedkit', function()
    print("[VORP Medkit] Item used!")

    if isUsingMedkit then
        print("[VORP Medkit] Already using medkit")
        return
    end

    if Config.UseCooldown and isOnCooldown then
        Notify(Config.Lang["on_cooldown"], "left")
        print("[VORP Medkit] On cooldown")
        return
    end

    local playerPed = PlayerPedId()
    local isDead = Citizen.InvokeNative(0x3317DEDB88C95038, playerPed) -- IsPedDeadOrDying

    print("[VORP Medkit] Is player dead: " .. tostring(isDead))

    if isDead then
        -- Player is dead, try to revive nearby player
        if Config.ReviveEnabled then
            ReviveNearbyPlayer()
        else
            Notify(Config.Lang["no_players"], "left")
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

    print("[VORP Medkit] Current Health: " .. currentHealth .. " / Max Health: " .. maxHealth)

    if currentHealth >= maxHealth then
        Notify(Config.Lang["already_healthy"], "left")
        print("[VORP Medkit] Already at full health")
        return
    end

    isUsingMedkit = true

    -- Clear any previous damage flags to prevent false interrupts
    ClearEntityLastDamageEntity(playerPed)

    -- Notify start of healing
    Notify(Config.ProgressBar["healing"], "left", Config.HealTime)
    print("[VORP Medkit] Starting heal process...")

    -- Play animation
    local dict = "amb_rest_drunk@world_human_drinking@coffee@male@idle_a"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(100)
    end
    TaskPlayAnim(playerPed, dict, "idle_a", 1.0, 8.0, -1, 1, 0, false, false, false)

    -- Wait for healing time
    Citizen.Wait(Config.HealTime)

    print("[VORP Medkit] Wait completed. isUsingMedkit = " .. tostring(isUsingMedkit))

    -- Check if player moved or got interrupted
    if isUsingMedkit then
        -- Apply healing - RedM uses different health scale (600 is max typically)
        -- Calculate percentage heal
        local healthToAdd = (maxHealth / 100) * Config.HealAmount
        local newHealth = math.min(currentHealth + healthToAdd, maxHealth)

        print("[VORP Medkit] Healing: " .. currentHealth .. " -> " .. newHealth)

        SetEntityHealth(playerPed, math.floor(newHealth))

        -- Also use native for RedM
        Citizen.InvokeNative(0xC6258F41D86676E0, playerPed, 0, math.floor(newHealth))

        -- Clear animation
        ClearPedTasks(playerPed)

        -- Notify player
        Notify(Config.Lang["medkit_used"], "right")
        print("[VORP Medkit] Healed successfully!")

        -- Remove item and start cooldown
        TriggerServerEvent('vorp_medkit:server:removeItem')

        if Config.UseCooldown then
            StartCooldown()
        end
    else
        Notify(Config.Lang["canceled"], "left")
        print("[VORP Medkit] Healing canceled")
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
        Notify(Config.Lang["no_players"], "left")
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
                print("[VORP Medkit] INTERRUPTED! Combat: " .. tostring(inCombat) .. ", Damage: " .. tostring(takenDamage))
                isUsingMedkit = false
                ClearPedTasks(playerPed)
            end
        end
    end
end)
