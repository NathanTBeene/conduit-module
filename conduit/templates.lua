--- conduit/templates. lua
--- HTML templates for rendering console pages

local Templates = {}

-----------------------------------------------------------
-- SHARED CSS
-----------------------------------------------------------

local SHARED_CSS = [[
<style>
    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    html, body {
        height: 100%;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
        background-color: #0d1117;
        color: #c9d1d9;
    }

    /* Header */
    . header {
        background-color:  #161b22;
        border-bottom: 1px solid #30363d;
        padding: 16px 20px;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .header-left {
        display: flex;
        align-items: center;
        gap: 16px;
        padding: 8px;
    }

    .logo {
        font-size: 20px;
        font-weight: 600;
        color: #58a6ff;
        letter-spacing: 0.5px;
        text-decoration: none;
        transition: color 0.2s;
    }

    .logo:hover {
        color:  #79c0ff;
    }

    .console-name {
        font-size: 16px;
        color: #8b949e;
        padding-left: 16px;
        border-left: 1px solid #30363d;
        text-transform: capitalize;
    }

    /* Toolbar */
    .toolbar {
        background-color: #161b22;
        border-bottom: 1px solid #30363d;
        padding:  12px 20px;
        display: flex;
        gap: 12px;
        align-items:  center;
    }

    .btn {
        background-color: #21262d;
        color: #c9d1d9;
        border: 1px solid #30363d;
        padding: 6px 16px;
        border-radius:  6px;
        font-size: 14px;
        cursor: pointer;
        transition: background-color 0.2s, border-color 0.2s;
    }

    .btn:hover {
        background-color: #30363d;
        border-color: #58a6ff;
    }

    /* Log Container */
    .log-container {
        flex: 1;
        overflow-y: auto;
        overflow-x: hidden;
        padding: 20px;
        font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
        font-size: 14px;
        line-height: 1.6;
    }

    .log-entry {
        padding: 4px 8px;
        margin-bottom: 2px;
        border-radius:  3px;
        display: flex;
        align-items: flex-start;
        gap: 8px;
    }

    .log-entry:hover {
        background-color:  #161b22;
    }

    .log-icon {
        flex-shrink: 0;
        width: 16px;
        text-align: center;
    }

    .log-message {
        flex: 1;
        word-break: break-word;
        white-space: pre-wrap;
    }

    .log-timestamp {
        color: #8b949e;
        margin-right: 8px;
    }

    /* Command Input */
    .command-input-container {
        background-color: #161b22;
        border-top: 1px solid #30363d;
        padding: 12px 20px;
    }

    .command-input-wrapper {
        display: flex;
        gap: 8px;
        align-items: center;
    }

    .command-prompt {
        color: #58a6ff;
        font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
        font-size: 14px;
        font-weight: bold;
    }

    .command-input {
        flex: 1;
        background-color: #0d1117;
        color:  #c9d1d9;
        border: 1px solid #30363d;
        padding: 8px 12px;
        border-radius: 6px;
        font-family:  'Consolas', 'Monaco', 'Courier New', monospace;
        font-size: 14px;
        transition: border-color 0.2s;
    }

    .command-input:focus {
        outline: none;
        border-color: #58a6ff;
    }

    .command-help {
        font-size: 11px;
        color: #8b949e;
        margin-top: 6px;
        font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
    }

    /* Status Bar */
    .status-bar {
        background-color: #161b22;
        border-top: 1px solid #30363d;
        padding: 8px 20px;
        font-size: 12px;
        color: #8b949e;
        display:  flex;
        justify-content:  space-between;
    }

    /* Index Page Specific */
    .index-container {
        max-width: 900px;
        margin: 40px auto;
        padding: 0 20px;
    }

    .section-title {
        font-size:  20px;
        font-weight: 600;
        margin-bottom: 16px;
        color: #c9d1d9;
    }

    .console-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
        gap: 16px;
        margin-bottom: 40px;
    }

    .console-card {
        background-color: #161b22;
        border: 1px solid #30363d;
        border-radius: 8px;
        padding: 20px;
        transition: border-color 0.2s, transform 0.2s;
        cursor: pointer;
        text-decoration: none;
        color: inherit;
        display: block;
    }

    .console-card:hover {
        border-color: #58a6ff;
        transform: translateY(-2px);
    }

    .console-card-title {
        font-size:  18px;
        font-weight:  600;
        color: #58a6ff;
        text-transform: capitalize;
        margin-bottom: 8px;
    }

    .console-card-info {
        font-size: 13px;
        color: #8b949e;
    }

    .stats-container {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 16px;
    }

    .stat-card {
        background-color:  #161b22;
        border: 1px solid #30363d;
        border-radius:  8px;
        padding:  20px;
    }

    .stat-value {
        font-size:  32px;
        font-weight:  600;
        color: #58a6ff;
        margin-bottom: 4px;
    }

    .stat-label {
        font-size: 14px;
        color: #8b949e;
    }

    /* Console Page Layout */
    .console-page {
        display: flex;
        flex-direction: column;
        height: 100vh;
        overflow: hidden;
    }
</style>
]]

-----------------------------------------------------------
-- CONSOLE PAGE JAVASCRIPT
-----------------------------------------------------------

local CONSOLE_JS = [[
<script>
    const logContainer = document.getElementById('logContainer');
    const commandInput = document.getElementById('commandInput');
    const commandHelp = document.getElementById('commandHelp');
    const clearBtn = document.getElementById('clearBtn');
    const statusIndicator = document.getElementById('statusIndicator');

    let contentCache = '';
    let isAtBottom = true;
    let commandHistory = [];
    let historyIndex = -1;

    // Check if user is scrolled to bottom
    function checkIfAtBottom() {
        const threshold = 50;
        isAtBottom = logContainer.scrollHeight - logContainer.scrollTop - logContainer.clientHeight < threshold;
    }

    logContainer.addEventListener('scroll', checkIfAtBottom);

    // Fetch and update logs via AJAX
    function refreshLogs() {
        fetch('/api/console/{{CONSOLE_NAME}}/buffer')
            .then(response => response.text())
            .then(html => {
                // Only update if content changed
                if (html !== contentCache) {
                    const wasAtBottom = isAtBottom;
                    logContainer.innerHTML = html;
                    contentCache = html;

                    // Auto-scroll only if was at bottom
                    if (wasAtBottom) {
                        logContainer.scrollTop = logContainer.scrollHeight;
                    }
                }
                statusIndicator.innerHTML = 'Connected • Live';
            })
            .catch(err => {
                statusIndicator.innerHTML = 'Disconnected &#9675;';
            });
    }

    // Execute command
    function executeCommand(commandText) {
        if (!commandText.trim()) return;

        // Add to history
        if (commandHistory[0] !== commandText) {
            commandHistory.unshift(commandText);
            if (commandHistory.length > 50) commandHistory.pop();
        }
        historyIndex = -1;

        // Send command to server
        fetch('/api/console/{{CONSOLE_NAME}}/command', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ command: commandText })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                commandHelp.textContent = '✓ ' + (data.message || 'Command executed');
                commandHelp.style. color = '#3fb950';
            } else {
                commandHelp.textContent = '✗ ' + (data.error || 'Command failed');
                commandHelp. style.color = '#f85149';
            }
            setTimeout(() => {
                commandHelp.textContent = 'Press Enter to execute • Type "help" for commands';
                commandHelp.style.color = '#8b949e';
            }, 3000);
            refreshLogs();
        })
        .catch(err => {
            commandHelp.textContent = '✗ Failed to execute command';
            commandHelp.style.color = '#f85149';
        });

        // Clear input
        commandInput.value = '';
    }

    // Command input event handlers
    commandInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            executeCommand(commandInput.value);
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            if (historyIndex < commandHistory.length - 1) {
                historyIndex++;
                commandInput.value = commandHistory[historyIndex];
            }
        } else if (e.key === 'ArrowDown') {
            e.preventDefault();
            if (historyIndex > 0) {
                historyIndex--;
                commandInput.value = commandHistory[historyIndex];
            } else if (historyIndex === 0) {
                historyIndex = -1;
                commandInput.value = '';
            }
        }
    });

    // Clear button
    clearBtn.addEventListener('click', () => {
        executeCommand('clear');
    });

    // Initial scroll to bottom
    logContainer.scrollTop = logContainer.scrollHeight;
    isAtBottom = true;

    // Poll every 200ms for low latency
    setInterval(refreshLogs, 200);
</script>
]]

-----------------------------------------------------------
-- INDEX PAGE JAVASCRIPT
-----------------------------------------------------------

local INDEX_JS = [[
<script>
    let consoleCache = '';

    function updateIndex() {
        // Update console list
        fetch('/api/consoles')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    let html = '';
                    data.consoles.forEach(console => {
                        html += `
                            <a href="/console/${console.name}" class="console-card">
                                <div class="console-card-title">${console.name}</div>
                                <div class="console-card-info">${console.log_count} logs</div>
                            </a>
                        `;
                    });

                    if (html !== consoleCache) {
                        const grid = document.getElementById('consoleGrid');
                        grid.innerHTML = html || '<p style="color: #8b949e;">No consoles created yet. </p>';
                        consoleCache = html;
                    }
                }
            })
            .catch(err => {});

        // Update stats
        fetch('/api/stats')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    document.getElementById('statConsoles').textContent = data.stats.console_count;
                    document. getElementById('statLogs').textContent = data.stats.total_logs;
                    document.getElementById('statErrors').textContent = data.stats. total_errors;
                    document.getElementById('statWarnings').textContent = data.stats.total_warnings;
                }
            })
            .catch(err => {});
    }

    // Update every 500ms
    setInterval(updateIndex, 500);
</script>
]]

-----------------------------------------------------------
-- RENDER FUNCTIONS
-----------------------------------------------------------

function Templates.render_index(consoles, config)
  -- Build console cards
  local console_cards = {}
  for name, console in pairs(consoles) do
    local stats = console: get_stats()
    table.insert(console_cards, string.format([[
      <a href="/console/%s" class="console-card">
        <div class="console-card-title">%s</div>
        <div class="console-card-info">%d logs</div>
      </a>
    ]], name, name, stats.log_count))
  end

  local console_cards_html = table.concat(console_cards, "\n")
  if console_cards_html == "" then
    console_cards_html = '<p style="color: #8b949e; padding: 40px; text-align: center;">No consoles created yet.</p>'
  end

  -- Calculate Stats
  local total_logs = 0
  local total_errors = 0
  local total_warnings = 0
  local console_count = 0

  for name, console in pairs(consoles) do
    console_count = console_count + 1
    total_logs = total_logs + console.total_logs

    for _, log in ipairs(console:get_logs()) do
      if log.level == "error" then
        total_errors = total_errors + 1
      elseif log.level == "warning" then
        total_warnings = total_warnings + 1
      end
    end
  end

  -- Build Page
  return string.format([[
    <! DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Conduit - Console Index</title>
      %s
    </head>
    <body>
        <div class="header">
            <div class="header-left">
                <a href="/" class="logo">CONDUIT</a>
            </div>
        </div>

        <div class="index-container">
            <h2 class="section-title">Active Consoles</h2>
            <div class="console-grid" id="consoleGrid">
                %s
            </div>

            <h2 class="section-title">Statistics</h2>
            <div class="stats-container">
                <div class="stat-card">
                    <div class="stat-value" id="statConsoles">%d</div>
                    <div class="stat-label">Consoles</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="statLogs">%d</div>
                    <div class="stat-label">Total Logs</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="statErrors">%d</div>
                    <div class="stat-label">Errors</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="statWarnings">%d</div>
                    <div class="stat-label">Warnings</div>
                </div>
            </div>
        </div>

        %s
    </body>
    </html>
    ]],
    SHARED_CSS, console_cards_html, console_count, total_logs, total_errors, total_warnings, INDEX_JS)
end

function Templates.render_console(console, config)
  local logs_html = Templates.render_logs_buffer(console)

  -- Replace template variables in JavaScript
  local js = CONSOLE_JS:gsub("{{CONSOLE_NAME}}", console.name)

  return string.format([[
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Conduit - %s</title>
        %s
    </head>
    <body class="console-page">
        <div class="header">
            <div class="header-left">
                <a href="/" class="logo">CONDUIT</a>
                <div class="console-name">%s</div>
            </div>
        </div>

        <div class="toolbar">
            <button class="btn" id="clearBtn">Clear</button>
        </div>

        <div class="log-container" id="logContainer">
            %s
        </div>

        <div class="command-input-container">
            <div class="command-input-wrapper">
                <span class="command-prompt">&gt;</span>
                <input type="text" class="command-input" id="commandInput"
                      placeholder="Type a command...  (try 'help')" autocomplete="off">
            </div>
            <div class="command-help" id="commandHelp">
                Press Enter to execute • Type "help" for commands
            </div>
        </div>

        <div class="status-bar">
            <span>Total Logs: <strong>%d</strong></span>
            <span id="statusIndicator">Connected • Live</span>
        </div>

        %s
    </body>
    </html>
  ]], console.name, SHARED_CSS, console.name, logs_html, console.total_logs, js)
end

function Templates.render_logs_buffer(console)
  local logs = console:get_logs()

  if #logs == 0 then
    return [[
      <div style="text-align: center; padding: 40px; color: #8b949e;">
      <p>No logs yet.</p>
      <p style="font-size: 12px; margin-top: 8px;">
        Start logging with <code>console: log("message")</code>
      </p>
      </div>
    ]]
  end

  local log_entries = {}
  for _, log in ipairs(logs) do
    local timestamp_html = ""
    if log.timestamp then
      timestamp_html = string.format('<span class="log-timestamp">[%s]</span> ', log.timestamp)
    end

    -- Convert newlines into <br> for HTML display
    local message = log.message:gsub("\n", "<br>")

    local entry = string.format([[
      <div class="log-entry" style="color: %s;">
        <span class="log-icon">%s</span>
        <span class="log-message">%s%s</span>
      </div>
    ]], log.color, log.icon, timestamp_html, message)

    table.insert(log_entries, entry)
  end

  return table.concat(log_entries, "\n")
end

return Templates
