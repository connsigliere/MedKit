Config = {}

-- Item name in the database
Config.MedkitItem = "medkit"

-- Healing settings
Config.HealAmount = 100 -- Amount of health to restore (0-100)
Config.HealTime = 5000 -- Time in milliseconds to use medkit on yourself (5 seconds)

-- Revival settings
Config.ReviveEnabled = true -- Enable/disable revival feature
Config.ReviveTime = 8000 -- Time in milliseconds to revive a player (8 seconds)
Config.ReviveDistance = 2.0 -- Maximum distance to revive someone (in meters)
Config.ReviveHealth = 50 -- Health amount after revival (0-100)

-- Cooldown settings
Config.UseCooldown = true -- Enable/disable cooldown
Config.CooldownTime = 30000 -- Cooldown time in milliseconds (30 seconds)

-- Remove item after use
Config.RemoveOnUse = true -- Remove medkit from inventory after use

-- Notifications
Config.Lang = {
    ["medkit_used"] = "You used a medkit and restored your health",
    ["reviving"] = "Reviving player...",
    ["revived"] = "You revived a player",
    ["got_revived"] = "You have been revived",
    ["no_players"] = "No injured players nearby",
    ["already_healthy"] = "You are already healthy",
    ["player_not_dead"] = "This player is not injured",
    ["too_far"] = "Player is too far away",
    ["on_cooldown"] = "You must wait before using another medkit",
    ["canceled"] = "Action canceled"
}

-- Progress bar text
Config.ProgressBar = {
    ["healing"] = "Using Medkit",
    ["reviving"] = "Reviving Player"
}
