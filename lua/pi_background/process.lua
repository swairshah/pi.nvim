local config = require('pi_background.config')
local ui = require('pi_background.ui')
local buffers = require('pi_background.buffers')
local log = require('pi_background.log')

local M = {}

local state = {
  process = nil,
  stdout_tail = '',
  stderr_tail = '',
  running = false,
  streaming = false,
  request_id = 0,
  file_snapshots = {},
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = 'pi-background.nvim' })
end

local function is_process_running()
  return state.running and state.process and not state.process:is_closing()
end

function M.is_running()
  return is_process_running()
end

function M.is_streaming()
  return state.streaming
end

local function next_request_id()
  state.request_id = state.request_id + 1
  return 'pi-bg-' .. state.request_id
end

local function get_pi_cmd()
  local cfg = config.get_pi_config()
  local cmd = { 'pi', '--mode', 'rpc' }

  if cfg.session then
    vim.list_extend(cmd, { '--session', cfg.session })
  elseif cfg.session_mode == 'continue' or cfg.continue_session then
    table.insert(cmd, '--continue')
  elseif cfg.session_mode == 'ephemeral' then
    table.insert(cmd, '--no-session')
  end

  if not cfg.extensions then
    table.insert(cmd, '--no-extensions')
  end
  if not cfg.skills then
    table.insert(cmd, '--no-skills')
  end
  if not cfg.tools then
    table.insert(cmd, '--no-tools')
  end
  if cfg.provider then
    vim.list_extend(cmd, { '--provider', cfg.provider })
  end
  if cfg.model then
    vim.list_extend(cmd, { '--model', cfg.model })
  end

  return cmd
end

local function handle_response(event)
  if event.success == false then
    local message = event.error or 'Pi request failed'
    ui.set_status('error', message)
    notify(message, vim.log.levels.ERROR)
  end
end

local function handle_event(event)
  log.append('rpc_event', event)

  if event.type == 'response' then
    handle_response(event)
  elseif event.type == 'agent_start' then
    state.streaming = true
    ui.set_streaming(true)
    ui.set_status('thinking', 'Prompt accepted')
  elseif event.type == 'tool_execution_start' then
    ui.set_status('running_tool', 'Running tool: ' .. (event.toolName or 'unknown'))
  elseif event.type == 'message_update' then
    local delta = event.assistantMessageEvent
    if delta and delta.type == 'error' then
      local message = delta.reason or 'Pi error'
      ui.set_status('error', message)
      notify(message, vim.log.levels.ERROR)
    end
  elseif event.type == 'agent_end' then
    state.streaming = false
    ui.set_streaming(false)
    buffers.reload_changed_file_buffers(state.file_snapshots)
    ui.set_status('done', 'Pi done', { close_after = config.get().window.close_after_done_ms })
  elseif event.type == 'extension_ui_request' then
    -- Background bridge intentionally ignores extension UI requests.
  end
end

local function feed_stream(key, chunk)
  if not chunk or chunk == '' then
    return
  end
  state[key] = (state[key] or '') .. chunk

  while true do
    local newline = state[key]:find('\n', 1, true)
    if not newline then
      break
    end

    local line = state[key]:sub(1, newline - 1)
    state[key] = state[key]:sub(newline + 1)

    if line ~= '' then
      local ok, event = pcall(vim.json.decode, line)
      if ok and event and event.type then
        handle_event(event)
      elseif key == 'stderr_tail' then
        if not line:match('client version') or not line:match('tailscaled server version') then
          notify(line, vim.log.levels.WARN)
        end
      end
    end
  end
end

function M.start()
  if is_process_running() then
    return true
  end

  state.stdout_tail = ''
  state.stderr_tail = ''
  state.streaming = false
  log.append('start', { cmd = get_pi_cmd() })
  ui.set_streaming(false)
  ui.set_status('starting', 'Starting background Pi')

  local ok, process = pcall(vim.system, get_pi_cmd(), {
    text = true,
    stdin = true,
    stdout = vim.schedule_wrap(function(err, data)
      if err then
        notify(tostring(err), vim.log.levels.ERROR)
        return
      end
      feed_stream('stdout_tail', data)
    end),
    stderr = vim.schedule_wrap(function(err, data)
      if err then
        notify(tostring(err), vim.log.levels.ERROR)
        return
      end
      feed_stream('stderr_tail', data)
    end),
  }, vim.schedule_wrap(function(result)
    state.running = false
    state.process = nil
    state.streaming = false
    ui.set_streaming(false)
    if result.code ~= 0 and result.code ~= 143 then
      local message = 'Background Pi exited with code ' .. result.code
      ui.set_status('error', message)
      notify(message, vim.log.levels.ERROR)
    end
  end))

  if not ok then
    local message = 'Failed to start background Pi: ' .. tostring(process)
    ui.set_status('error', message)
    notify(message, vim.log.levels.ERROR)
    return false
  end

  state.process = process
  state.running = true
  ui.set_status('starting', 'Background Pi started')
  return true
end

function M.abort()
  if not is_process_running() then
    notify('Background Pi is not running')
    return
  end

  local encoded = vim.json.encode({ id = next_request_id(), type = 'abort' }) .. '\n'
  local wrote, write_err = pcall(state.process.write, state.process, encoded)
  if wrote then
    state.streaming = false
    ui.set_streaming(false)
    ui.set_status('cancelled', 'Sent abort to background Pi', { close_after = config.get().window.close_after_done_ms })
  else
    local message = 'Failed to abort background Pi: ' .. tostring(write_err)
    ui.set_status('error', message)
    notify(message, vim.log.levels.ERROR)
  end
end

function M.stop()
  if state.process and not state.process:is_closing() then
    pcall(state.process.kill, state.process, 15)
  end
  state.running = false
  state.process = nil
  state.streaming = false
  ui.set_streaming(false)
  ui.set_status('stopped', 'Stopped background Pi', { close_after = config.get().window.close_after_stop_ms })
end

function M.restart()
  M.stop()
  vim.defer_fn(M.start, 100)
end

function M.status()
  local cfg = config.get_pi_config()
  notify(string.format(
    'Background Pi: %s | streaming: %s | model: %s',
    is_process_running() and 'running' or 'stopped',
    state.streaming and 'yes' or 'no',
    config.model_label(cfg.provider, cfg.model)
  ))
end

function M.send(message)
  if not message or message == '' then
    notify('No message provided', vim.log.levels.ERROR)
    return
  end

  log.append('prompt', { message = message })
  ui.clear_history()
  ui.set_status('starting', 'Sending prompt')

  if not M.start() then
    return
  end

  state.file_snapshots = buffers.snapshot_loaded_file_buffers()
  local payload = { id = next_request_id(), type = 'prompt', message = message }

  if state.streaming then
    payload.streamingBehavior = 'followUp'
    ui.set_status('queued', 'Pi is busy; queued follow-up')
  end

  local wrote, write_err = pcall(state.process.write, state.process, vim.json.encode(payload) .. '\n')
  if not wrote then
    local error_message = 'Failed to write to background Pi: ' .. tostring(write_err)
    ui.set_status('error', error_message)
    notify(error_message, vim.log.levels.ERROR)
    state.running = false
    state.process = nil
  else
    ui.set_status(state.streaming and 'queued' or 'thinking', 'Prompt sent')
  end
end

return M
