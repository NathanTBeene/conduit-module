-- test/main.lua
-- To run, use `love .\test` from the conduit module root folder
-- or `love .` from the test folder

-- incluce package path to conduit folder at ../conduit/init.lua
package.path = package.path .. ";../conduit/?.lua"
Conduit = require "conduit.init"

Conduit:init() -- Initialize the Conduit framework

-- Setup System Console
Conduit:console("system")
Conduit.system:success("[Conduit] System console initialized.")
Conduit.system:group("Stats", 1) -- Setup group with order 1 to make it appear at the top
Conduit.system:watch("FPS", function() return love.timer.getFPS() end, "Stats", 1) -- Watch FPS under Stats group
Conduit.system:watch("Memory Usage", function()
  local rep = ""
  local mem = collectgarbage("count")

  if mem < 1024 then
    rep = string.format("%.0f KB", mem)
  else
    rep = string.format("%.0f MB", mem / 1024)
  end

  return rep
end, "Stats", 2) -- Watch Memory under Stats grou

-- Setup Gameplay Console
Conduit:console("gameplay")
Conduit.gameplay:success("[Conduit] Gameplay console initialized.")
Conduit.gameplay:group("Player", 1) -- Setup group with order 1 to make it appear at the top
Conduit.gameplay:watch("Health", function() return player.health end, "Player", 1) -- Watch Player Health under Player group
Conduit.gameplay:watch("Player Position", function() return string.format("X: %.2f, Y: %.2f", player.x, player.y) end, "Player", 2) -- Watch Player Position under Player group

function love.load()
  -- Create player
  player = {
    x = love.graphics.getWidth() / 2,
    y = love.graphics.getHeight() / 2,
    speed = 200,
    health = 100,
    is_alive = function(self) return self.health > 0 end,
    take_damage = function(self, amount)
      if self.health <= 0 then
        Conduit.gameplay:warn("Player is already dead.")
        return
      end
      self.health = math.max(0, self.health - amount)
      Conduit.gameplay:warn(string.format("Player took %.2f damage.", amount, self.health))
      if self.health == 0 then
        Conduit.gameplay:error("Player has died.")
      end
    end
  }
end

-- INPUT METHODS --

local function getDirection()
  local dirX, dirY = 0, 0
  if love.keyboard.isDown("w") then
    dirY = dirY - 1
  end
  if love.keyboard.isDown("s") then
    dirY = dirY + 1
  end
  if love.keyboard.isDown("a") then
    dirX = dirX - 1
  end
  if love.keyboard.isDown("d") then
    dirX = dirX + 1
  end

  -- Normalize direction
  local length = math.sqrt(dirX * dirX + dirY * dirY)
  if length > 0 then
    dirX = dirX / length
    dirY = dirY / length
  end
  return dirX, dirY
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  end

  if key == "space" then
    player:take_damage(10) -- Simulate taking damage when space is pressed
  end
end

-- UPDATE METHODS --

function love.update(dt)
  Conduit:update() -- Update the Conduit framework
  local dirX, dirY = getDirection()
  player.x = player.x + dirX * player.speed * dt
  player.y = player.y + dirY * player.speed * dt
end

-- DRAW METHODS --

local function draw_controls()
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Use W/A/S/D to move the player (green circle).", 10, 10)
  love.graphics.print("Press SPACE to simulate taking damage.", 10, 30)
  love.graphics.print("Press ESC to quit.", 10, 50)
end

local function draw_player()
  if player:is_alive() then
    love.graphics.setColor(0, 1, 0) -- Green color
  else
    love.graphics.setColor(1, 0, 0) -- Red color
  end
  love.graphics.circle("fill", player.x, player.y, 20)

  -- Print player health above the player
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Health: " .. player.health, player.x - 30, player.y - 40)
end

function love.draw()
  draw_controls()
  draw_player()
end

-- EXTRA LÖVE CALLBACKS --

function love.shutdown()
  Conduit:shutdown() -- Shutdown the Conduit framework
  -- Your game shutdown code here
end
