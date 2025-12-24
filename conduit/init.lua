--- conduit/init.lua
--- Main entry point for Conduit debug console

local Conduit = {}

-- Private state (not accessible outside this module)
local consoles = {}           -- Stores all console instances {name -> console_object}
local config = {              -- Default configuration
  port = 8080,
  timestamps = true,
  max_logs = 1000
}
local server = nil            -- Will hold the HTTP server instance
local is_initialized = false  -- Have we called init() yet?

-- Global command templates (we'll copy these into each console)
local global_command_templates = {}

-----------------------------------------------------------
-- INITIALIZATION
-----------------------------------------------------------

--- Initialize Conduit
--- Call this once at the start of your game
--- @param options table Optional:   {port = 8080, timestamps = true, max_logs = 1000}
function Conduit:init(options)
  if is_initialized then
    print("[Conduit] Already initialized")
    return
  end

  -- Merge user options into config
  if options then
    for key, value in pairs(options) do
      config[key] = value
    end
  end

  -- Define built-in global commands
  Conduit:_define_global_commands()

  -- Start the HTTP server
  local Server = require("conduit.server")
  server = Server:new(config, consoles)
  server:start()

  is_initialized = true
  print(string.format("[Conduit] Initialized on http://localhost:%d", config.port))
end

--- Update - call this every frame in love.update()
function Conduit:update()
  if server then
    server:update()
  end
end

--- Shutdown Conduit
function Conduit:shutdown()
  if server then
    server:stop()
  end
  is_initialized = false
  print("[Conduit] Shutdown complete")
end

-----------------------------------------------------------
-- CONSOLE CREATION
-----------------------------------------------------------

--- Create or get a console
--- @param name string Name of the console (e.g., "gameplay", "network")
--- @return Console The console instance
function Conduit:console(name)
  -- Auto-initialize if not done
  if not is_initialized then
    self:init()
  end

  -- Validate name
  if not name or type(name) ~= "string" or name == "" then
    error("[Conduit] Console name must be a non-empty string")
  end

  -- Sanitize name (remove spaces, special chars)
  name = name:lower():gsub("[^%w_%-]", "")

  -- Return existing console if already created
  if consoles[name] then
    return consoles[name]
  end

  -- Create new console
  local Console = require("conduit.console")
  local console = Console:new(name, config)

  -- Copy all global commands into this console
  for cmd_name, cmd_template in pairs(global_command_templates) do
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

-----------------------------------------------------------
-- GLOBAL COMMANDS
-----------------------------------------------------------

--- Define built-in global commands
--- These will be copied into every console when it's created
function Conduit:_define_global_commands()

  -- HELP:   Show all available commands
  global_command_templates["help"] = {
    callback = function(console, args)
      local lines = {"=== Available Commands ===\n"}

      -- Get all commands from this console and sort them
      local cmd_list = {}
      for name, cmd in pairs(console.commands) do
        table.insert(cmd_list, {name = name, desc = cmd.description})
      end
      table.sort(cmd_list, function(a, b) return a.name < b.name end)

      -- Format each command
      for _, cmd in ipairs(cmd_list) do
        table.insert(lines, string.format("  %s - %s", cmd.name, cmd.desc))
      end

      -- Log to console as one message
      console:log(table.concat(lines, "\n"))
    end,
    description = "Show all available commands"
  }

  -- CLEAR:  Clear logs from this console
  global_command_templates["clear"] = {
    callback = function(console, args)
      console:clear()
      console:log("Console cleared")
    end,
    description = "Clear all logs from this console"
  }

  -- STATS:  Show console statistics
  global_command_templates["stats"] = {
    callback = function(console, args)
      local stats = console:get_stats()
      local lines = {
        "=== Console Statistics ===\n",
        string.format("Name: %s", stats.name),
        string.format("Current logs: %d", stats.log_count),
        string.format("Total logs written: %d", stats.total_logs),
        string.format("Max logs: %d", stats.max_logs),
        string.format("Commands available: %d", stats.command_count)
      }
      console:log(table.concat(lines, "\n"))
    end,
    description = "Show statistics for this console"
  }
end

--- Register a custom global command
--- This will be added to ALL existing consoles and future consoles
--- @param name string Command name
--- @param callback function Command function(console, args)
--- @param description string Command description
function Conduit:register_global_command(name, callback, description)
  if not is_initialized then
    self:init()
  end

  -- Add to templates
  global_command_templates[name] = {
    callback = callback,
    description = description or "No description"
  }

  -- Add to all existing consoles
  for _, console in pairs(consoles) do
    console:register_command(name, callback, description)
  end

  print(string.format("[Conduit] Registered global command '%s'", name))
end

return Conduit
