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

  -- Watchables
  self.watchables = {}
  self.watchable_groups = {}
  self.max_watchables = config.max_watchables or 100

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
-- WATCHABLES
-----------------------------------------------------------

function Console:watch(name, getter, group, order)
  -- Validate
  if not name or type(name) ~= "string" then
    error("[Conduit] Watchable name must be a string")
    self:warn("Invalid name for watchable. Must be a string.")
  end

  if not getter or type(getter) ~= "function" then
    error("[Conduit] Watchable getter must be a function")
    self:warn("Invalid getter for watchable '" .. name .. "'. Must be a function.")
  end

  -- Check max watchables
  if #self.watchables >= self.max_watchables then
    error("[Conduit] Maximum number of watchables reached")
    self:warn("Maximum number of watchables reached. Cannot add '" .. name .. "'.")
  end

  -- Default group and order
  group = group or "Other"
  order = order or 999

  -- Store watchable
  self.watchables[name] = {
    getter = getter,
    group = group,
    order = order
  }
end

function Console:group(name, order)
  if not name or type(name) ~= "string" then
    error("[Conduit] Watchable group name must be a string")
  end

  order = order or 999
  self.watchable_groups[name] = order
end

function Console:unwatch(name)
  self.watchables[name] = nil
  self._recalculate_group_orders()
end

-- Remove all watchables in a group
function Console:unwatch_group(group)
  for name, watchable in pairs(self.watchables) do
    if watchable.group == group then
      self.watchables[name] = nil
    end
  end
end

function Console:get_watchables()
  -- Build Groups
  local groups = {}
  local group_map = {}

  for name, watchable in pairs(self.watchables) do
    local group_name = watchable.group

    -- Create group if doesn't exist
    if not group_map[group_name] then
      local group_data = {
        name = group_name,
        order = self.watchable_groups[group_name] or 999,
        items = {}
      }
      table.insert(groups, group_data)
      group_map[group_name] = group_data
    end

    -- Evaluate getter
    local success, result = pcall(watchable.getter)
    local value = success and tostring(result) or ("Error: " .. tostring(result))

    -- Add to group
    table.insert(group_map[group_name].items, {
      name = name,
      value = value,
      order = watchable.order
    })
  end

  -- Sort groups by order
  table.sort(groups, function(a, b)
    return a.order < b.order
  end)

  -- Sort items within each group by order
  for _, group in ipairs(groups) do
    table.sort(group.items, function(a, b)
      return a.order < b.order
    end)
  end

  return groups
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
