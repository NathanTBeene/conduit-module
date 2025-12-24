--- @class Console
--- conduit/console.lua
--- Individual console instance

local Console = {}
Console.__index = Console

-- Log level definitions
local LOG_LEVELS = {
  INFO = { name = "info", icon = "▸", color = "#c9d1d9" },
  SUCCESS = { name = "success", icon = "✓", color = "#3fb950" },
  WARNING = { name = "warning", icon = "⚠", color = "#d29922" },
  ERROR = { name = "error", icon = "✖", color = "#f85149" },
  DEBUG = { name = "debug", icon = "○", color = "#8b949e" },
  CUSTOM = { name = "custom", icon = "▸", color = "#c9d1d9" }
}


-----------------------------------------------------------
-- CONSTRUCTOR
-----------------------------------------------------------


function Console:new(name, config)
  local self = setmetatable({}, Console)

  self.name = name
  self.max_logs = config.max_logs or 1000
  self.timestamps = config.timestamps or false

  self.logs = {}      -- Array of logs
  self.total_logs = 0 -- Total logs ever added
  self.commands = {}  -- Console-specific commands

  return self
end


-----------------------------------------------------------
-- LOGGING
-----------------------------------------------------------


function Console:_add_log(level, message)
  -- Convert message to string if needed
  if type(message) ~= "string" then
    message = tostring(message)
  end

  -- Create log entry
  local log_entry = {
    level = level.name,
    icon = level.icon,
    color = level.color,
    message = message,
    timestamp = self.timestamps and os.date("%H:%M:%S") or nil,
    id = self.total_logs + 1
  }

  -- Add logs to array
  table.insert(self.logs, log_entry)

  -- Increment total counter
  self.total_logs = self.total_logs + 1

  -- Trim if we exceed max logs
  if #self.logs > self.max_logs then
    table.remove(self.logs, 1)
  end
end


function Console:log(message)
  self:_add_log(LOG_LEVELS.INFO, message)
end


function Console:success(message)
  self:_add_log(LOG_LEVELS.SUCCESS, message)
end


function Console:warn(message)
  self:_add_log(LOG_LEVELS.WARNING, message)
end


function Console:error(message)
  self:_add_log(LOG_LEVELS.ERROR, message)
end


function Console:debug(message)
  self:_add_log(LOG_LEVELS.DEBUG, message)
end


function Console:clear()
  self.logs = {}
end


function Console:get_logs()
  return self.logs
end

-----------------------------------------------------------
-- COMMANDS
-----------------------------------------------------------


function Console:register_command(name, callback, description)
  if not name or type(name) ~= "string" then
    error("[Conduit] Command name must be a string")
  end

  if not callback or type(callback) ~= "function" then
    error("[Conduit] Command callback must be a function")
  end

  self.commands[name] = {
    callback = callback,
    description = description or "No description"
  }
end


function Console:execute_command(name, args)
  -- Check if command exists
  if not self.commands[name] then
    local error_msg = string.format("Command '%s' not found. Type 'help' for a list of commands.", name)
    self:error(error_msg)
    return {
      success = false,
      message = error_msg
    }
  end

  -- Execute command
  local success, result = pcall(self.commands[name].callback, self, args or {})

  -- Handle execution errors
  if not success then
    local error_msg = string.format("Error executing command '%s': %s", name, tostring(result))
    self:error(error_msg)
    return {
      success = false,
      message = tostring(result)
    }
  end

  -- Command executed successfully
  return {
    success = true,
    message = "Command executed successfully."
  }
end


function Console:count_commands()
  local count = 0
  for _ in pairs(self.commands) do
    count = count + 1
  end
  return count
end

-----------------------------------------------------------
-- STATISTICS
-----------------------------------------------------------

function Console:get_stats()
  return {
    name = self.name,
    log_count = #self.logs,
    total_logs = self.total_logs,
    max_logs = self.max_logs,
    command_count = self:count_commands()
  }
end

return Console
