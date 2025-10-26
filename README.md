# VORP Medkit Script

A fully functional medkit script for RedM VORP Core servers that allows players to heal themselves and revive teammates.

## Features

- **Self-Healing**: Use medkit to restore health when injured
- **Team Revival**: Revive nearby dead/downed players
- **Configurable**: Extensive config options for healing amounts, cooldowns, distances, etc.
- **Animations**: Includes immersive animations during use
- **Cooldown System**: Prevents spam with configurable cooldown
- **Progress Interruption**: Actions can be canceled if player takes damage or moves too far
- **Admin Commands**: Give medkits to players with admin commands
- **Fully Integrated**: Works seamlessly with VORP Core and VORP Inventory

## Requirements

- [VORP Core](https://github.com/VORPCORE/vorp-core-lua)
- [VORP Inventory](https://github.com/VORPCORE/vorp_inventory-lua)
- RedM Server

## Installation

### 1. Download and Extract
Extract the `vorp_medkit` folder to your server's resources directory.

### 2. Database Setup
Execute the SQL file in your database:
```sql
-- Run the medkit.sql file in your database
-- This adds the medkit item to your items table
```

### 3. Server Configuration
Add the following line to your `server.cfg`:
```
ensure vorp_medkit
```

### 4. Restart Server
Restart your server or use the command:
```
refresh
start vorp_medkit
```

## Configuration

Edit the `config.lua` file to customize the script:

### Basic Settings
```lua
Config.MedkitItem = "medkit"  -- Item name in database
Config.HealAmount = 100       -- Health restored when self-healing
Config.HealTime = 5000        -- Time to use medkit (milliseconds)
```

### Revival Settings
```lua
Config.ReviveEnabled = true   -- Enable/disable revival feature
Config.ReviveTime = 8000      -- Time to revive a player
Config.ReviveDistance = 2.0   -- Maximum distance to revive
Config.ReviveHealth = 50      -- Health after revival
```

### Cooldown Settings
```lua
Config.UseCooldown = true     -- Enable/disable cooldown
Config.CooldownTime = 30000   -- Cooldown time (30 seconds)
```

### Other Options
```lua
Config.RemoveOnUse = true     -- Remove medkit after use
```

## Usage

### For Players

**Self-Healing:**
1. Open your inventory
2. Use the medkit item
3. Wait for the healing animation to complete
4. Your health will be restored

**Reviving Teammates:**
1. Stand near a downed/dead player (within 2 meters by default)
2. Use the medkit item
3. Wait for the revival animation to complete
4. Your teammate will be revived

### For Admins

**Give Medkit Command:**
```
/givemedkit [player_id] [amount]
```

Examples:
- `/givemedkit 1 1` - Give 1 medkit to player ID 1
- `/givemedkit 5 10` - Give 10 medkits to player ID 5

## How It Works

1. **Self-Healing**: When used by a living player, the medkit restores health based on config settings
2. **Revival**: When used near a dead/downed player, it initiates a revival sequence
3. **Cooldown**: After use, a cooldown prevents immediate reuse
4. **Interruption**: If the player takes damage or moves during use, the action is canceled
5. **Item Removal**: The medkit is removed from inventory after successful use (configurable)

## Customization

### Adding to Shops
To make medkits available in shops, add the following to your shop configuration:
```sql
INSERT INTO `store_items` (`store`, `item`, `price`, `amount`) VALUES
('doctor', 'medkit', 25.00, 10);
```

### Changing Language
Edit the `Config.Lang` table in `config.lua`:
```lua
Config.Lang = {
    ["medkit_used"] = "Your custom message here",
    -- ... more translations
}
```

### Adjusting Animations
Modify animation dictionaries in `client/client.lua`:
- Line 42-49: Self-healing animation
- Line 104-111: Revival animation

## Troubleshooting

**Medkit not working:**
- Ensure VORP Core and VORP Inventory are started before this resource
- Check that the SQL was executed successfully
- Verify the resource is started in server console

**Item not appearing:**
- Run the SQL file in your database
- Restart VORP Inventory after adding the item
- Check item name matches in config and database

**Revival not working:**
- Ensure `Config.ReviveEnabled = true`
- Check that players are within `Config.ReviveDistance`
- Verify the target player is actually dead/downed

## Support

For issues and suggestions, please create an issue on the GitHub repository.

## Credits

Created for RedM VORP Core framework

## License

Free to use and modify for your server. Credit appreciated but not required.
