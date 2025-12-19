-- conduit/init.lua
-- Main entry point for the Conduit debug console module

local Conduit = {}
Conduit.__index = Conduit
Conduit._VERSION = "1.0.0"

-- Internal State
local consoles = {}
local config = {
  port = 8080,
  timestamps = true,
  max_logs = 1000,
}
local server = nil
local is_initialized = false

local global_commands = {} -- holds global commands available to all consoles


-------------------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------------------


--- Initialize Conduit
--- Only need to call this once.
function Conduit:init(options)
  if is_initialized then
    print("[Conduit] Already initialized. Ignoring subsequent init call.")
    return
  end

  -- Merge user options with default config
  if options then
    for k, v in pairs(options) do
      if config[k] ~= nil then
        config[k] = v
      end
    end
  end

  -- Define built in global commands
  Conduit:define_global_commands()

  -- Load server module and start it
  local Server = require("conduit.server")
  server = Server:new(config, consoles)
  server:start()

  is_initialized = true
  print(string.format("[Conduit] Initialized on http://%s:%d", config.host, config.port))
end


--- Update function - called periodically to handle internal tasks
function Conduit:update()
  if server then
    server:update()
  end
end


--- Shutdown Conduit and clean up resources
function Conduit:shutdown()
  if server then
    server:stop()
  end

  is_initialized = false
  print("[Conduit] Shutdown complete.")
end


-------------------------------------------------------------------------------
-- CONSOLE CREATION
-------------------------------------------------------------------------------


function Conduit:console(name)
  -- Auto initialize if not already done
  if not is_initialized then
    self:init()
  end

  -- Validate name
  if not name or type(name) ~= "string" then
    error("[Conduit] Console name must be a string.")
  end

  -- Sanitize name
  name = name:lower():gsub("%s+", "_")

  -- Return existing console if already created
  if consoles[name] then
    return consoles[name]
  end

  -- Create new console
  local Console = require("conduit.console")
  local console = Console:new(name, config)

  -- Copy global commands to the new console
  for cmd_name, cmd_template in pairs(global_commands) do
    console:register_command(
      cmd_name,
      cmd_template.callback,
      cmd_template.description
    )
  end

  consoles[name] = console
  print(string.format("[Conduit] Created new console '%s'.", name))
  return console
end


-------------------------------------------------------------------------------
-- CONSOLE CREATION
-------------------------------------------------------------------------------


function Conduit:define_global_commands()

  -- HELP: List all available commands
  global_commands["help"] = {
    callback = function(console, args)
      local lines = {}
      table.insert(lines, "") -- Blank line for spacing
      table.insert(lines, "Available Commands:")

      local cmd_list = {}
      for name, cmd in pairs(console.commands) do
        table.insert(cmd_list, {name = name, description = cmd.description})
      end
      table.sort(cmd_list, function(a, b) return a.name < b.name end)

      -- Format each command
      for _, cmd in ipairs(cmd_list) do
        table.insert(lines, string.format(" - %s: %s", cmd.name, cmd.description))
      end

      -- Log to console as one message
      console:log(table.concat(lines, "\n"))

    end,
    description = "List all available commands."
  }

  -- CLEAR: Clear all logs from the console
  global_commands["clear"] = {
    callback = function(console, args)
      console:clear()
    end,
    description = "Clear all logs from the console."
  }

  -- STATS: Show console statistics
  global_commands["stats"] = {
    callback = function(console, args)
      local lines = {
        "",
        "Console Statistics:",
        string.format("Name: %s", console.name),
        string.format("Current Logs: %d", console:get_log_count()),
        string.format("Total Logs Written: %d", console:get_total_logs()),
        string.format("Max Logs: %d", console.max_logs),
        string.format("Commands Available: %d", #console:get_commands())
      }
      console:log(table.concat(lines, "\n"))
    end,
    description = "Show console statistics."
  }
end


function Conduit:register_global_command(name, callback, description)
  if not is_initialized then
    self:init()
  end

  -- Add to templates
  global_commands[name] = {
    callback = callback,
    description = description or "No description provided."
  }

  -- Add to all existing consoles
  for _, console in pairs(consoles) do
    console:register_command(name, callback, description)
  end

  print(string.format("[Conduit] Registered global command '%s'.", name))
end

return Conduit
