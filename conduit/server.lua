--- conduit/server. lua
--- HTTP server for serving console pages and handling API requests

local socket = require("socket")

local Server = {}
Server.__index = Server

-----------------------------------------------------------
-- CONSTRUCTOR
-----------------------------------------------------------


function Server:new(config, consoles)
  local self = setmetatable({}, Server)

  self.config = config        -- Server configuration
  self.consoles = consoles    -- Reference to all consoles
  self.tcp = nil              -- TCP server socket
  self.clients = {}           -- Connected clients

  return self
end


-----------------------------------------------------------
-- SERVER LIFECYCLE
-----------------------------------------------------------

-- Start the HTTP SErver
function Server:start()
  -- Create TCP socket
  self.tcp = socket.tcp()

  -- Bind to port (use "*" to bind all interfaces)
  local success, err = self.tcp:bind("*", self.config.port)
  if not success then
    error(string.format("[Conduit] Failed to bind server to port %d: %s", self.config.port, err))
  end

  -- Start listening for incoming connections
  self.tcp:listen(5)
  self.tcp:settimeout(0)  -- Non-blocking

  print(string.format("[Conduit] Server started on port %d", self.config.port))
end


-- Stop the HTTP Server
function Server:stop()
  if self.tcp then
    self.tcp:close()
    self.tcp = nil
  end

  -- Close all client connections
  for _, client_data in pairs(self.clients) do
    if client_data.socket then
      client_data.socket:close()
    end
  end

  self.clients = {}
  print("[Conduit] Server stopped.")
end


-- Update server - call this periodically to handle connections
function Server:update()
  if not self.tcp then
    return
  end

  -- Accept new client connections
  self:_accept_connections()

  -- Process existing clients
  self:_process_connections()
end


-----------------------------------------------------------
-- CONNECTION HANDLING (Private)
-----------------------------------------------------------


function Server:_accept_connections()
  local client, err = self.tcp:accept()

  if client then
    client:settimeout(0)

    -- Add client to list
    table.insert(self.clients, {
      socket = client,
      buffer = "",
      start_time = socket.gettime(),
      headers_complete = false,
      content_length = 0,
      body_start = nil
    })
  end
end


function Server:_process_connections()
  -- Iterate backwards so we can remove closed clients
  for i = #self.clients, 1, -1 do
    local client_data = self.clients[i]
    local remove_client = false

    -- Try to read data
    local continue_reading = true
    local reads_this_frame = 0

    while continue_reading and reads_this_frame < 5 do
      reads_this_frame = reads_this_frame + 1
      local data, err, partial = client_data.socket:receive(1024)

      if data then
        client_data.buffer = client_data.buffer .. data
      elseif partial and #partial > 0 then
        client_data.buffer = client_data.buffer .. partial
      end

      if err == "timeout" then
        -- No more data available right now
        continue_reading = false
      elseif err == "closed" then
        -- Client disconnected
        remove_client = true
        continue_reading = false
      elseif err then
        -- Some other error
        remove_client = true
        continue_reading = false
      end
    end

    -- Parse headers if not done yet
    if not client_data.headers_complete then
      local header_end = string.find(client_data.buffer, "\r\n\r\n")
      if header_end then
        client_data.headers_complete = true
        client_data.body_start = header_end + 4

        -- Extract Content Length if present
        local content_length = string.match(client_data.buffer, "Content%-Length:%s*(%d+)")
        if content_length then
          client_data.content_length = tonumber(content_length)
        end
      end
    end

    -- Check if we have the full request
    if client_data.headers_complete then
      local total_expected = client_data.body_start + client_data.content_length - 1

      if #client_data.buffer >= total_expected then
        -- We have the complete request, process it
        local success, err = pcall(function()
          self:_handle_request(client_data.socket, client_data.buffer)
        end)

        if not success then
          print(string.format("[Conduit] Error handling request: %s", tostring(err)))
        end

        remove_client = true
      end
    end

    -- Timeout check (5 seconds)
    if socket.gettime() - client_data.start_time > 5 then
      remove_client = true
    end

    -- Remove client if needed
    if remove_client then
      client_data.socket:close()
      table.remove(self.clients, i)
    end
  end
end


-----------------------------------------------------------
-- REQUEST HANDLING (Private)
-----------------------------------------------------------


function Server:_handle_request(client, request)
  local method, path, protocol = string.match(request, "^(%w+)%s+(.-)%s+HTTP/%d%.%d")

  if not method or not path then
    self:_send_response(client, 400, "text/plain", "Bad Request")
  end

  -- Parse query string if present
  local base_path, query_string = string.match(path, "([^?]+)%??(.*)")
  if not base_path then
    base_path = path
    query_string = ""
  end

  -- Route the request
  if base_path == "/" or base_path == "/index" or base_path == "/index.html" then
        self:_serve_index(client)

    elseif string.match(base_path, "^/console/([a-z0-9_%-]+)$") then
        local console_name = string.match(base_path, "^/console/([a-z0-9_%-]+)$")
        self:_serve_console(client, console_name)

    elseif string.match(base_path, "^/api/console/([a-z0-9_%-]+)/buffer$") then
        local console_name = string.match(base_path, "^/api/console/([a-z0-9_%-]+)/buffer$")
        self:_api_console_buffer(client, console_name)

    elseif string.match(base_path, "^/api/console/([a-z0-9_%-]+)/logs$") then
        local console_name = string.match(base_path, "^/api/console/([a-z0-9_%-]+)/logs$")
        self:_api_console_logs(client, console_name)

    elseif string.match(base_path, "^/api/console/([a-z0-9_%-]+)/command$") then
        local console_name = string.match(base_path, "^/api/console/([a-z0-9_%-]+)/command$")
        self:_api_console_command(client, console_name, request)

    elseif base_path == "/api/consoles" then
        self:_api_consoles_list(client)

    elseif base_path == "/api/stats" then
        self:_api_stats(client)

    else
        self:_send_response(client, 404, "text/plain", "Not Found:  " .. base_path)
    end
end


function Server:_send_response(client, status, content_type, body)
  local status_text = {
    [200] = "OK",
    [400] = "Bad Request",
    [404] = "Not Found",
    [500] = "Internal Server Error"
  }

  local response = string.format(
    "HTTP/1.1 %d %s\r\n" ..
    "Content-Type: %s\r\n" ..
    "Content-Length: %d\r\n" ..
    "Connection: close\r\n" ..
    "\r\n" ..
    "%s",
    status,
    status_text[status] or "Unknown",
    content_type,
    #body,
    body
  )

  client:send(response)
end


-----------------------------------------------------------
-- REQUEST HANDLING (Private)
-----------------------------------------------------------


function Server:_server_index(client)
  local Templates = require("conduit.templates")
  local html = Templates.render_index(self.consoles, self.config)
  self:_send_response(client, 200, "text/html", html)
end


function Server:_serve_console(client, console_name)
  local console = self.consoles[console_name]
  if not console then
    self:_send_response(client, 404, "text/plain", "Console not found: " .. console_name)
    return
  end

  local Templates = require("conduit.templates")
  local html = Templates.render_console(console, self.config)
  self:_send_response(client, 200, "text/html", html)
end


-----------------------------------------------------------
-- API Routes (Private)
-----------------------------------------------------------


-- API: Get log bugger (HTML fragment for AJAX updates)
function Server:_api_console_buffer(client, console_name)
  local console = self.consoles[console_name]

  if not console then
    self:_send_response(client, 404, "text/plain", 'Console not found: ' .. console_name)
    return
  end

  local Templates = require("conduit.templates")
  local html = Templates.render_logs_buffer(console)
  self:_send_response(client, 200, "text/html", html)
end


-- API: Get logs as JSON
function Server:_api_console_logs(client, console_name)
  local console = self.consoles[console_name]

  if not console then
    self:_send_response(client, 404, "application/json", '{"error":"Console not found"}')
    return
  end

  local logs = console:get_logs()
  local json = self:_encode_json({
    success = true,
    total = console.total_logs,
    count = #logs,
    logs = logs
  })

  self:_send_response(client, 200, "application/json", json)
end


-- API: Execute command
function Server:_api_console_command(client, console_name, request)
  local console = self.consoles[console_name]

  if not console then
    self:_send_response(client, 404, "application/json", '{"error":"Console not found"}')
    return
  end

  -- Extract body from request
  local body_start = string.find(request, "\r\n\r\n")
  if not body_start then
    self:_send_response(client, 400, "application/json", '{"error":"No request body"}')
    return
  end

  local body = string.sub(request, body_start + 4)
  if not body or body == "" then
    self:_send_response(client, 400, "application/json", '{"error": "Empty request body"}')
    return
  end

  -- Parse JSON body
  local data = self:_decode_json(body)
  if not data or not data.command then
    self:_send_response(client, 400, "application/json", '{"error":"Invalid JSON or missing command"}')
    return
  end

  -- Execute command
  local result = console:execute_command(data.command, data.args or {})
  local json = self:_encode_json(result)

  self:_send_response(client, 200, "application/json", json)
end


-- API: List all consoles
function Server:_api_consoles_list(client)
  local console_list = {}

  for name, console in pairs(self.consoles) do
    table.insert(console_list, console:get_stats())
  end

  local json = self:_encode_json({
    success = true,
    consoles = console_list
  })

  self:_send_response(client, 200, "application/json", json)
end


-- API: Get server statistics
function Server:_api_stats(client)
  local total_logs = 0
  local total_errors = 0
  local total_warnings = 0
  local console_count = 0

  for name, console in pairs(self.consoles) do
    console_count = console_count + 1
    total_logs = total_logs + console.total_logs

    -- Count errors and warnings
    for _, log in ipairs(console.logs) do
      if log.level == "error" then
        total_errors = total_errors + 1
      elseif log.level == "warning" then
        total_warnings = total_warnings + 1
      end
    end
  end

  local json = self:_encode_json({
    success = true,
    total_consoles = console_count,
    total_logs = total_logs,
    total_errors = total_errors,
    total_warnings = total_warnings
  })

  self:_send_response(client, 200, "application/json", json)
end


-----------------------------------------------------------
-- API Routes (Private)
-----------------------------------------------------------


function Server:_encode_json(obj)
  local function encode_value(val)
    local val_type = type(val)

    if val_type == "string" then
      -- Escape special characters
      val = string.gsub(val, '\\', '\\\\')
      val = string.gsub(val, '"', '\\"')
      val = string.gsub(val, '\n', '\\n')
      val = string.gsub(val, '\r', '\\r')
      val = string.gsub(val, '\t', '\\t')
      return '"' .. val .. '"'

    elseif val_type == "number" then
      return tostring(val)

    elseif val_type == "boolean" then
      return val and "true" or "false"

    elseif val_type == "nil" then
      return "null"

    elseif val_type == "table" then
      -- Check if it's an array or object
      local is_array = true
      local count = 0
      for k, v in pairs(val) do
        count = count + 1
        if type(k) ~= "number" or k ~= count then
          is_array = false
          break
        end
      end

      if is_array and count > 0 then
        -- Array
        local parts = {}
        for i, v in ipairs(val) do
          table.insert(parts, encode_value(v))
        end
        return "[" .. table.concat(parts, ",") .. "]"
      else
        -- Object
        local parts = {}
        for k, v in pairs(val) do
          table.insert(parts, encode_value(tostring(k)) .. ":" .. encode_value(v))
        end
        return "{" .. table.concat(parts, ",") .. "}"
      end
    else
      return "null"
    end
  end

  return encode_value(obj)
end


function Server:_decode_json(str)
  -- Remove whitespace
  str = string.gsub(str, "^%s+", "")
  str = string.gsub(str, "%s+$", "")

  if str == "" then
    return nil
  end

  -- Parse JSON object
  if string.sub(str, 1, 1) == "{" and string.sub(str, -1) == "}" then
    local obj = {}
    local content = string.sub(str, 2, -2)

    local i = 1
    while i <= #content do
      -- Skip whitespace
      while i <= #content and string.match(string.sub(content, i, i), "%s") do
        i = i + 1
      end

      if i > #content then break end

      -- Read key (quoted string)
      if string.sub(content, i, i) == '"' then
        i = i + 1
        local key_start = i
        while i <= #content and string.sub(content, i, i) ~= '"' do
          i = i + 1
        end
        local key = string.sub(content, key_start, i - 1)
        i = i + 1

        -- Skip whitespace and colon
        while i <= #content and string.match(string.sub(content, i, i), "[%s:]") do
          i = i + 1
        end

        -- Read value
        local value
        if string.sub(content, i, i) == '"' then
          -- String value
          i = i + 1
          local val_start = i
          while i <= #content and string.sub(content, i, i) ~= '"' do
            i = i + 1
          end
          value = string.sub(content, val_start, i - 1)
          i = i + 1
        else
          -- Number, boolean, or null
          local val_start = i
          while i <= #content and not string.match(string.sub(content, i, i), "[,%s}]") do
            i = i + 1
          end
          local val_str = string.sub(content, val_start, i - 1)

          if val_str == "true" then
            value = true
          elseif val_str == "false" then
            value = false
          elseif val_str == "null" then
            value = nil
          elseif tonumber(val_str) then
            value = tonumber(val_str)
          else
            value = val_str
          end
        end

        obj[key] = value

        -- Skip comma
        while i <= #content and string.match(string.sub(content, i, i), "[,%s]") do
          i = i + 1
        end
      else
        break
      end
    end

    return obj
  end

  return nil
end

return Server
