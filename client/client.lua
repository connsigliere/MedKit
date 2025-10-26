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
    print("[VORP Medkit] HealSelf function called")

    local playerPed = PlayerPedId()
    print("[VORP Medkit] PlayerPed: " .. tostring(playerPed))

    local currentHealth = GetEntityHealth(playerPed)
    local maxHealth = GetEntityMaxHealth(playerPed)

    print("[VORP Medkit] Current Health: " .. currentHealth .. " / Max Health: " .. maxHealth)

    if currentHealth >= maxHealth then
        Notify(Config.Lang["already_healthy"], "left")
        print("[VORP Medkit] Already at full health")
        return
    end

    print("[VORP Medkit] Starting instant heal (no animation for testing)...")

    -- Calculate heal amount
    local healthToAdd = (maxHealth / 100) * Config.HealAmount
    local newHealth = math.min(currentHealth + healthToAdd, maxHealth)

    print("[VORP Medkit] Will heal from " .. currentHealth .. " to " .. newHealth)

    -- INSTANT HEAL - Try all methods
    -- Method 1: Basic SetEntityHealth
    print("[VORP Medkit] Trying SetEntityHealth...")
    SetEntityHealth(playerPed, math.floor(newHealth))
    Citizen.Wait(50)
    print("[VORP Medkit] Health after method 1: " .. GetEntityHealth(playerPed))

    -- Method 2: RedM specific native
    print("[VORP Medkit] Trying RedM native...")
    Citizen.InvokeNative(0xC6258F41D86676E0, playerPed, 0, math.floor(newHealth))
    Citizen.Wait(50)
    print("[VORP Medkit] Health after method 2: " .. GetEntityHealth(playerPed))

    -- Method 3: Health core regeneration
    print("[VORP Medkit] Trying health core regen...")
    Citizen.InvokeNative(0xC6258F41D86676E0, playerPed, 0, 600) -- Set to max
    Citizen.InvokeNative(0xF6A7C08DF2E28B28, playerPed, 0, 1000) -- Add to health core
    Citizen.InvokeNative(0x4AF5A4C7B9157D14, playerPed, 0, 5000.0) -- _FORTIFY_PED_ATTRIBUTE
    Citizen.Wait(50)
    print("[VORP Medkit] Health after method 3: " .. GetEntityHealth(playerPed))

    -- Method 4: Using VORP if available
    if VORPcore then
        print("[VORP Medkit] Trying VORP method...")
        local User = VORPcore.getUser(PlayerId())
        if User then
            local Character = User.getUsedCharacter
            if Character then
                print("[VORP Medkit] Have VORP character, setting HP...")
                -- Try VORP's method if it exists
            end
        end
    end

    local finalHealth = GetEntityHealth(playerPed)
    print("[VORP Medkit] FINAL HEALTH: " .. finalHealth)

    -- Notify player
    if finalHealth > currentHealth then
        Notify("Health increased to " .. finalHealth, "right")
    else
        Notify("WARNING: Health did NOT increase! Still at " .. finalHealth, "left")
    end

    -- Remove item
    TriggerServerEvent('vorp_medkit:server:removeItem')

    print("[VORP Medkit] HealSelf complete")
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
