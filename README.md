# Conduit

A real-time debug console for LÖVE2D games that runs in your web browser.

[![Version](https://img.shields.io/github/v/release/NathanTBeene/conduit-module?label=version)](https://github.com/NathanTBeene/conduit-module/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/NathanTBeene/conduit-module?tab=MIT-1-ov-file)
[![LÖVE](https://img.shields.io/badge/LÖVE-11.0+-pink.svg)](https://love2d.org/)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg)](https://www.lua.org/source/5.1/)

---

## Features

- **Multiple Consoles** - Create separate consoles for different systems (gameplay, network, audio, etc.)
- **Real-time Logging** - See logs appear instantly in your browser
- **Search & Filter** - Search logs and filter by level (info, success, warning, error, debug)
- **Custom Commands** - Register commands that can be executed from the browser
- **Watchable Variables** - Monitor values in real-time without logging every frame
- **Lightweight** - Pure Lua implementation with no external dependencies

---

## 📦 Installation

### Option 1: Copy Files

1. Download the latest [release](https://github.com/NathanTBeene/conduit-module/releases).
2. Copy the `conduit/` folder into your LÖVE project
3. Require it in your `main.lua`:

```lua
local Conduit = require("conduit")
```

> [!IMPORTANT]
> **If you place conduit in a subfolder** (like `modules/conduit/`), you need to tell Lua where to find it.
>
> Add this line at the top of your `main.lua` before requiring conduit:
>
> ```lua
> -- If conduit is in modules/conduit/
> package.path = package.path .. ";modules/?.lua;modules/?/init.lua"
>
> local Conduit = require("conduit")
> ```
>
> **Why?** Lua doesn't automatically search subfolders. This adds your `modules/` folder to Lua's search path so it can find conduit and all its internal files.

---

## Quick Start

### Basic Setup

```lua
local Conduit = require("conduit")

  -- Initialize Conduit outside your love.load
  -- Or in a separate file like 'network' or 'consoles'
  Conduit:init({
      port = 8080,
      timestamps = true,
      max_logs = 1000,
      max_watchables = 100,
      refresh_interval = 200  -- ms between updates
  })

  -- Create a console
  console = Conduit:console("gameplay")

  -- Log messages
  console:log("Game started!")
  console:success("Player loaded")

  -- Or use the alias for cleaner code
  Conduit.gameplay:log("This works too!")
  Conduit.gameplay:warn("Low Memory")

  print("Open http://localhost:8080 in your browser")


function love.load()
end

function love.update(dt)
    -- Update Conduit every frame
    Conduit:update()
end

function love.quit()
    -- Clean shutdown
    Conduit:shutdown()
end
```

### Open Your Browser

Navigate to `http://localhost:8080` to see the index page with a list of all your consoles.

---

## Documentation

### Configuration

```lua
Conduit:init({
    port = 8080,              -- HTTP server port
    timestamps = true,        -- Show timestamps on logs
    max_logs = 1000,          -- Maximum logs per console
    max_watchables = 100,     -- Maximum watchables per console
    refresh_interval = 200    -- Milliseconds between browser updates
})
```

---

### Logging

#### Basic Logging

```lua
console:log("Normal message")       -- ▸ White
console:success("Success message")  -- ✓ Green
console:warn("Warning message")     -- ⚠ Yellow
console:error("Error message")      -- ✖ Red
console:debug("Debug message")      -- ○ Gray
```

#### Logging Objects

```lua
local player = { x = 100, y = 200, health = 75 }
console:log(tostring(player))  -- Convert to string first
```

#### Multi-line Logs

```lua
console:log("Line 1\nLine 2\nLine 3")
```

#### Clear Logs

```lua
console:clear()  -- Clear all logs from this console
```

---

### Multiple Consoles

Create separate consoles for different systems:

```lua
local game_console = Conduit:console("gameplay")
local network_console = Conduit:console("network")
local audio_console = Conduit:console("audio")

game_console:log("Player spawned")
network_console:log("Connected to server")
audio_console:log("Music volume: 80%")
```

Each console is independent with its own logs, commands, and watchables.

#### Console Aliases

When you create a console, Conduit automatically creates an alias for easy access:

```lua
-- Create console
Conduit:console("gameplay")

-- Access via alias (no variable needed!)
Conduit.gameplay:log("Using alias")
Conduit.gameplay:success("Much cleaner!")

-- Still works with variables if you prefer
gameplay = Conduit:console("gameplay")
gameplay:log("Using variable")
```

This is especially useful for global access across multiple files:

```lua
-- main.lua
Conduit = require("conduit")
Conduit:init()
Conduit:console("gameplay")

-- player.lua
function Player:takeDamage()
    Conduit.gameplay:warn("Player took damage!")  -- No need to pass console around
end

-- enemy.lua
function Enemy:spawn()
    Conduit.gameplay:log("Enemy spawned")  -- Same here!
end
```

Each console is independent with its own logs, commands, and watchables.

---

### Custom Commands

Register commands that can be executed from the browser console:

```lua
-- Register a command
console:register_command("spawn", function(console, args)
    console:success("Enemy spawned at (100, 200)")
    -- Your spawn logic here
end, "Spawn an enemy")

console:register_command("reset", function(console, args)
    console:warn("Resetting game state...")
    -- Your reset logic here
    console:success("Game reset complete!")
end, "Reset the game")
```

#### Built-in Commands

Every console has these commands by default:

- `help` - Show all available commands
- `clear` - Clear the console
- `stats` - Show console statistics

#### Global Commands

Register a command that appears on ALL consoles:

```lua
Conduit:register_global_command("fps", function(console, args)
    console:log("FPS: " .. love.timer.getFPS())
end, "Show current FPS")
```

---

### Watchable Variables

Monitor values in real-time without spamming logs:

```lua
local player = { health = 100, x = 50, y = 30 }
local enemies = {}

-- Watch simple values
console:watch("FPS", function()
    return love.timer.getFPS()
end)

console:watch("Player Health", function()
    return player.health
end)

console:watch("Enemy Count", function()
    return #enemies
end)

-- Watch formatted values
console:watch("Position", function()
    return string. format("(%.1f, %.1f)", player.x, player.y)
end)

console:watch("Memory", function()
    local kb = collectgarbage("count")
    return string.format("%. 2f MB", kb / 1024)
end)
```

#### Grouped Watchables

Organize watchables into groups with custom ordering:

```lua
-- Define groups with display order
console:group("System", 1)    -- Shows first
console:group("Player", 2)    -- Shows second
console: group("Gameplay", 3)  -- Shows third

-- Add watchables to groups with item order
console:watch("FPS", function() return love.timer.getFPS() end, "System", 1)
console:watch("Memory", function() return "12 MB" end, "System", 2)

console:watch("Health", function() return player.health end, "Player", 1)
console:watch("Position", function() return "(50, 30)" end, "Player", 2)

console:watch("Wave", function() return current_wave end, "Gameplay", 1)
console:watch("Enemies", function() return #enemies end, "Gameplay", 2)
```

#### Remove Watchables

```lua
console:unwatch("FPS")           -- Remove a single watchable
console:unwatch_group("System")  -- Remove all watchables in a group
```

---

### Search & Filter

In the browser console:

- **Search box** - Filter logs by text content
- **Dropdown** - Filter by log level (all, info, success, warning, error, debug)
- **Clear button** - Clear all logs

---

## Advanced Usage

### Multiple Consoles Example

```lua
Conduit = require("conduit") -- Make it Global

local game_console
local network_console
local audio_console

function love.load()
    Conduit:init()

    -- Create consoles
    game_console = Conduit:console("gameplay")
    network_console = Conduit:console("network")
    audio_console = Conduit:console("audio")

    -- Setup gameplay console
    game_console:group("System", 1)
    game_console:group("Player", 2)

    game_console:watch("FPS", function() return love.timer.getFPS() end, "System", 1)
    game_console:watch("Health", function() return player.health end, "Player", 1)

    game_console:register_command("spawn", function(console, args)
        spawnEnemy()
        console:success("Enemy spawned!")
    end, "Spawn an enemy")

    -- Setup network console using the alias
    Conduit.network:register_command("ping", function(console, args)
        console:log("Pinging server...")
        console:success("Pong!  42ms")
    end, "Ping the server")

    Conduit.network:watch("Ping", function() return network. ping ..  "ms" end)
    Conduit.network:watch("Connected", function() return network.connected and "Yes" or "No" end)
end

function love.update(dt)
    Conduit:update()

    -- Log events
    if player_damaged then
        game_console:warn("Player took damage!")
    end

    -- Or log with alias
    if network_error then
        Conduit.network:error("Connection lost!")
    end
end
```

---

## API Reference

### Conduit Module

| Method | Description |
|--------|-------------|
| `Conduit:init(options)` | Initialize Conduit with config options |
| `Conduit:update()` | Update server (call every frame) |
| `Conduit:shutdown()` | Clean shutdown |
| `Conduit:console(name)` | Create or get a console |
| `Conduit:register_global_command(name, callback, desc)` | Register command on all consoles |

### Console Access

After creating a console with `Conduit:console("name")`, you can access it two ways:

```lua
-- Method 1: Store in variable
local console = Conduit:console("gameplay")
console:log("Hello")

-- Method 2: Use alias (recommended for global access)
Conduit:console("gameplay")
Conduit.gameplay:log("Hello")
```


### Console Object

#### Logging Methods

| Method | Description |
|--------|-------------|
| `console:log(message)` | Log info message (white) |
| `console:success(message)` | Log success message (green) |
| `console:warn(message)` | Log warning message (yellow) |
| `console:error(message)` | Log error message (red) |
| `console:debug(message)` | Log debug message (gray) |
| `console:clear()` | Clear all logs |
| `console:get_logs()` | Get array of log objects |

#### Command Methods

| Method | Description |
|--------|-------------|
| `console:register_command(name, callback, desc)` | Register a command |
| `console:execute_command(name, args)` | Execute a command (internal) |

#### Watchable Methods

| Method | Description |
|--------|-------------|
| `console:watch(name, getter, group, order)` | Add a watchable variable |
| `console:unwatch(name)` | Remove a watchable |
| `console:group(name, order)` | Define a watchable group order |
| `console:unwatch_group(name)` | Remove all watchables in group |
| `console:get_watchables()` | Get watchables data (internal) |

#### Statistics Methods

| Method | Description |
|--------|-------------|
| `console:get_stats()` | Get console statistics |

---

## Troubleshooting

### Port Already In Use

If port 8080 is occupied, change it:

```lua
Conduit:init({ port = 8081 })
```

### Browser Shows "Connection Refused"

- Make sure your LÖVE game is running
- Check the console output for the correct URL
- Try accessing from `http://127.0.0.1:8080` instead of `localhost`

### Watchables Not Updating

- Ensure you're calling `Conduit:update()` every frame
- Check that your getter functions don't error (errors show as "Error:  ..." in the value)
- Try lowering `refresh_interval` for faster updates

### High CPU Usage

- Increase `refresh_interval` (e.g., 500ms instead of 200ms)
- Reduce `max_logs` to limit memory usage
- Limit the number of watchables

---

## Performance Tips

1. **Adjust refresh interval** - Higher = less CPU, lower = more responsive
   ```lua
   Conduit:init({ refresh_interval = 500 })  -- Update every 500ms
   ```

2. **Limit logs** - Keep only recent logs
   ```lua
   Conduit:init({ max_logs = 500 })
   ```

3. **Optimize watchable getters** - Keep getter functions fast
   ```lua
   -- Good
   console:watch("FPS", function() return love.timer.getFPS() end)

   -- Bad - too slow
   console:watch("Total Enemies", function()
       local count = 0
       for _, entity in ipairs(all_entities) do
           if entity.type == "enemy" then count = count + 1 end
       end
       return count
   end)
   ```

4. **Use multiple consoles** - Separate concerns for easier filtering

5. **Use aliases for cleaner code** - `Conduit.gameplay:log()` is more readable than passing console objects around

---

## License

MIT License - See [LICENSE](LICENSE) file for details

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
