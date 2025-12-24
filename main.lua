--- main.lua
--- Example usage of Conduit debug console

local Conduit = require("conduit")

-- Console references
local game_console
local network_console

function love.load()
  -- Initialize Conduit
  Conduit:init({
    port = 8080,
    timestamps = true,
    max_logs = 1000
  })

  -- Create consoles
  game_console = Conduit:console("gameplay")
  network_console = Conduit:console("network")

  -- Register custom commands for gameplay console
  game_console:register_command("spawn", function(console, args)
    console:success("Enemy spawned at (100, 200)")
    console:log("Enemy type:  Zombie")
  end, "Spawn an enemy")

  game_console:register_command("reset", function(console, args)
    console:warn("Resetting game state...")
    console:success("Game reset complete!")
  end, "Reset the game")

  -- Register custom commands for network console
  network_console:register_command("ping", function(console, args)
    console:log("Pinging server...")
    console:success("Pong!  Latency: 42ms")
  end, "Ping the server")

  -- Log some initial messages
  game_console:log("Game initialized")
  game_console:success("Player spawned")
  game_console:debug("Loading assets...")

  network_console:log("Network initialized")
  network_console:success("Connected to server")

  print("Open your browser to http://localhost:8080")
end

function love.update(dt)
  -- Update Conduit every frame (handles HTTP requests)
  Conduit:update()

  -- Example: Log every 2 seconds
  if love.timer.getTime() % 2 < dt then
    game_console:log("Game tick: " .. math.floor(love.timer.getTime()))
  end
end

function love.draw()
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Conduit Debug Console Example", 10, 10)
  love.graphics.print("Open:  http://localhost:8080", 10, 30)
  love.graphics.print("Press ESC to quit", 10, 50)

  love.graphics.print("Try these commands in the web console:", 10, 90)
  love.graphics.print("  help - Show all commands", 10, 110)
  love.graphics.print("  clear - Clear logs", 10, 130)
  love.graphics.print("  stats - Show statistics", 10, 150)
  love.graphics.print("  spawn - Spawn an enemy (gameplay only)", 10, 170)
  love.graphics.print("  ping - Ping server (network only)", 10, 190)
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  end

  -- Example: Log keypresses
  if key == "space" then
    game_console:log("Player jumped!")
  elseif key == "left" or key == "right" or key == "up" or key == "down" then
    game_console:debug("Player moved: " .. key)
  elseif key == "e" then
    game_console:error("Example error message!")
  elseif key == "w" then
    game_console:warn("Example warning message!")
  end
end

function love.quit()
  -- Shutdown Conduit
  Conduit:shutdown()
end
