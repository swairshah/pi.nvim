local M = {}

local defaults = {
  provider = 'openai-codex',
  model = 'gpt-5.3-codex-spark',
  session_mode = 'continue', -- continue | new | ephemeral
  log_path = vim.fn.stdpath('state') .. '/pi-nvim.log',
  max_context_lines = 300,
  max_context_bytes = 24000,
  selection_context_lines = 40,
  skills = true,
  extensions = true,
  tools = true,
  keymaps = true,
  keymap_prefix = '<leader>p',
  window = {
    enabled = true,
    close_after_done_ms = 1200,
    close_after_stop_ms = 900,
    width = 0.45,
    min_width = 40,
    max_width = 60,
  },
}

local config = vim.deepcopy(defaults)

local state = {
  process = nil,
  stdout_tail = '',
  stderr_tail = '',
  running = false,
  streaming = false,
  request_id = 0,
  file_snapshots = {},
  ui_bufnr = nil,
  ui_winid = nil,
  ui_timer = nil,
  ui_close_timer = nil,
  ui_status = 'idle',
  ui_history = {},
  spinner_idx = 0,
}

local spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = 'pi.nvim' })
end

local function empty_to_nil(value)
  if value == nil or value == '' then
    return nil
  end
  return value
end

local function plugin_config_from_env(opts)
  opts = opts or {}
  local merged = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts)
  merged.provider = empty_to_nil(vim.g.pi_nvim_provider or vim.env.PI_NVIM_PROVIDER) or merged.provider
  merged.model = empty_to_nil(vim.g.pi_nvim_model or vim.env.PI_NVIM_MODEL) or merged.model
  merged.session_mode = vim.env.PI_NVIM_SESSION_MODE or merged.session_mode
  return merged
end

local function context_module()
  return require('pi.context')
end

local function pi_config()
  return require('pi.config').get()
end

local function model_label(provider, model)
  if provider and model then
    return provider .. '/' .. model
  end
  return 'pi CLI default'
end

local function apply_pi_setup()
  require('pi').setup({
    provider = config.provider,
    model = config.model,
    max_context_lines = config.max_context_lines,
    max_context_bytes = config.max_context_bytes,
    selection_context_lines = config.selection_context_lines,
    log_path = config.log_path,
    skills = config.skills,
    extensions = config.extensions,
    tools = config.tools,
    session_mode = config.session_mode,
  })
end

local function is_process_running()
  return state.running and state.process and not state.process:is_closing()
end

local function next_request_id()
  state.request_id = state.request_id + 1
  return 'pi-bg-' .. state.request_id
end

local function get_pi_cmd()
  local cfg = pi_config()
  local cmd = { 'pi', '--mode', 'rpc' }

  if cfg.session then
    table.insert(cmd, '--session')
    table.insert(cmd, cfg.session)
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
    table.insert(cmd, '--provider')
    table.insert(cmd, cfg.provider)
  end
  if cfg.model then
    table.insert(cmd, '--model')
    table.insert(cmd, cfg.model)
  end

  return cmd
end

local function is_ui_buffer_valid()
  return state.ui_bufnr and vim.api.nvim_buf_is_valid(state.ui_bufnr)
end

local function is_ui_window_valid()
  return state.ui_winid and vim.api.nvim_win_is_valid(state.ui_winid)
end

local function cancel_ui_close_timer()
  if state.ui_close_timer then
    state.ui_close_timer:stop()
    state.ui_close_timer:close()
    state.ui_close_timer = nil
  end
end

local function close_ui()
  cancel_ui_close_timer()

  if state.ui_timer then
    state.ui_timer:stop()
    state.ui_timer:close()
    state.ui_timer = nil
  end

  if is_ui_window_valid() then
    pcall(vim.api.nvim_win_close, state.ui_winid, true)
  end

  if is_ui_buffer_valid() then
    pcall(vim.api.nvim_buf_delete, state.ui_bufnr, { force = true })
  end

  state.ui_winid = nil
  state.ui_bufnr = nil
end

local function schedule_ui_close(delay_ms)
  cancel_ui_close_timer()
  state.ui_close_timer = vim.loop.new_timer()
  state.ui_close_timer:start(delay_ms or config.window.close_after_done_ms, 0, vim.schedule_wrap(close_ui))
end

local function ui_title()
  if state.ui_status == 'error' then
    return ' pi error '
  end
  return ' pi '
end

local function ui_status_line()
  local active = state.ui_status == 'starting' or state.ui_status == 'thinking' or state.ui_status == 'running_tool' or state.ui_status == 'queued'
  local prefix = ''
  if active then
    state.spinner_idx = (state.spinner_idx % #spinner) + 1
    prefix = spinner[state.spinner_idx] .. ' '
  end

  local labels = {
    idle = 'Idle',
    starting = 'Starting background Pi...',
    thinking = 'Pi thinking...',
    running_tool = 'Running tool...',
    queued = 'Pi is busy; queued follow-up...',
    done = 'Done',
    cancelled = 'Cancelled',
    stopped = 'Stopped',
    error = 'Pi failed',
  }

  return prefix .. (labels[state.ui_status] or state.ui_status)
end

local function render_ui()
  if not is_ui_buffer_valid() then
    return
  end

  local lines = { ui_status_line() }
  local start_idx = math.max(1, #state.ui_history - 3)
  for i = start_idx, #state.ui_history do
    lines[#lines + 1] = state.ui_history[i]
  end

  vim.bo[state.ui_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(state.ui_bufnr, 0, -1, false, lines)
  vim.bo[state.ui_bufnr].modifiable = false

  if is_ui_window_valid() then
    pcall(vim.api.nvim_win_set_config, state.ui_winid, vim.tbl_extend('force', vim.api.nvim_win_get_config(state.ui_winid), {
      title = ui_title(),
      height = math.min(math.max(#lines, 1), math.max(3, math.floor(vim.o.lines * 0.25))),
    }))
  end
end

local function ensure_ui()
  if not config.window.enabled then
    return
  end

  cancel_ui_close_timer()

  if not is_ui_buffer_valid() then
    state.ui_bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[state.ui_bufnr].buftype = 'nofile'
    vim.bo[state.ui_bufnr].bufhidden = 'wipe'
    vim.bo[state.ui_bufnr].swapfile = false
    vim.bo[state.ui_bufnr].modifiable = false
    vim.api.nvim_buf_set_name(state.ui_bufnr, 'pi-background://status')
  end

  if not is_ui_window_valid() then
    local width = math.min(config.window.max_width, math.max(config.window.min_width, math.floor(vim.o.columns * config.window.width)))
    local height = 4
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    state.ui_winid = vim.api.nvim_open_win(state.ui_bufnr, false, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
      title = ui_title(),
      title_pos = 'center',
      noautocmd = true,
    })

    vim.wo[state.ui_winid].wrap = true
    vim.wo[state.ui_winid].linebreak = true
    vim.wo[state.ui_winid].winfixbuf = true
  end

  if not state.ui_timer then
    state.ui_timer = vim.loop.new_timer()
    state.ui_timer:start(100, 100, vim.schedule_wrap(function()
      if is_ui_buffer_valid() and state.streaming then
        render_ui()
      end
    end))
  end

  render_ui()
end

local function push_ui(message)
  if message and message ~= '' then
    state.ui_history[#state.ui_history + 1] = message
  end
end

local function set_ui_status(status, message, opts)
  opts = opts or {}
  state.ui_status = status
  push_ui(message)
  ensure_ui()

  if opts.close_after then
    schedule_ui_close(opts.close_after)
  end
end

local function normalize_path(path)
  return vim.fn.fnamemodify(path, ':p')
end

local function file_signature(path)
  local stat = vim.loop.fs_stat(path)
  if not stat or stat.type ~= 'file' then
    return nil
  end
  return {
    size = stat.size,
    mtime_sec = stat.mtime and stat.mtime.sec or 0,
    mtime_nsec = stat.mtime and stat.mtime.nsec or 0,
  }
end

local function signatures_equal(a, b)
  if not a or not b then
    return a == b
  end
  return a.size == b.size and a.mtime_sec == b.mtime_sec and a.mtime_nsec == b.mtime_nsec
end

local function buffer_is_file_backed(bufnr)
  return context_module().buffer_is_file_backed(bufnr)
end

local function snapshot_loaded_file_buffers()
  local snapshots = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and buffer_is_file_backed(bufnr) then
      local path = normalize_path(vim.api.nvim_buf_get_name(bufnr))
      snapshots[path] = file_signature(path)
    end
  end
  return snapshots
end

local function reload_buffer_from_disk(bufnr, path)
  if vim.fn.filereadable(path) ~= 1 or vim.bo[bufnr].modified then
    return false
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return false
  end

  local was_modifiable = vim.bo[bufnr].modifiable
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modified = false
  vim.bo[bufnr].modifiable = was_modifiable
  return true
end

local function reload_changed_file_buffers()
  local before_snapshots = state.file_snapshots or {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and buffer_is_file_backed(bufnr) then
      local path = normalize_path(vim.api.nvim_buf_get_name(bufnr))
      local before = before_snapshots[path]
      local after = file_signature(path)
      if not signatures_equal(before, after) then
        reload_buffer_from_disk(bufnr, path)
      end
    end
  end
end

local function handle_response(event)
  if event.success == false then
    local message = event.error or 'Pi request failed'
    set_ui_status('error', message)
    notify(message, vim.log.levels.ERROR)
  end
end

local function handle_event(event)
  if event.type == 'response' then
    handle_response(event)
  elseif event.type == 'agent_start' then
    state.streaming = true
    set_ui_status('thinking', 'Prompt accepted')
  elseif event.type == 'tool_execution_start' then
    local tool = event.toolName or 'unknown'
    set_ui_status('running_tool', 'Running tool: ' .. tool)
  elseif event.type == 'message_update' then
    local delta = event.assistantMessageEvent
    if delta and delta.type == 'error' then
      local message = delta.reason or 'Pi error'
      set_ui_status('error', message)
      notify(message, vim.log.levels.ERROR)
    end
  elseif event.type == 'agent_end' then
    state.streaming = false
    reload_changed_file_buffers()
    set_ui_status('done', 'Pi done', { close_after = config.window.close_after_done_ms })
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
        -- Suppress noisy Tailscale CLI/daemon mismatch warning from extensions.
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
  set_ui_status('starting', 'Starting background Pi')

  local cmd = get_pi_cmd()
  local ok, process = pcall(vim.system, cmd, {
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
    if result.code ~= 0 and result.code ~= 143 then
      local message = 'Background Pi exited with code ' .. result.code
      set_ui_status('error', message)
      notify(message, vim.log.levels.ERROR)
    end
  end))

  if not ok then
    local message = 'Failed to start background Pi: ' .. tostring(process)
    set_ui_status('error', message)
    notify(message, vim.log.levels.ERROR)
    return false
  end

  state.process = process
  state.running = true
  set_ui_status('starting', 'Background Pi started')
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
    set_ui_status('cancelled', 'Sent abort to background Pi', { close_after = config.window.close_after_done_ms })
  else
    local message = 'Failed to abort background Pi: ' .. tostring(write_err)
    set_ui_status('error', message)
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
  set_ui_status('stopped', 'Stopped background Pi', { close_after = config.window.close_after_stop_ms })
end

function M.restart()
  M.stop()
  vim.defer_fn(function()
    M.start()
  end, 100)
end

function M.status()
  local cfg = pi_config()
  notify(string.format('Background Pi: %s | streaming: %s | model: %s', is_process_running() and 'running' or 'stopped', state.streaming and 'yes' or 'no', model_label(cfg.provider, cfg.model)))
end

function M.send(message)
  if not message or message == '' then
    notify('No message provided', vim.log.levels.ERROR)
    return
  end

  state.ui_history = {}
  set_ui_status('starting', 'Sending prompt')

  if not M.start() then
    return
  end

  state.file_snapshots = snapshot_loaded_file_buffers()

  local payload = {
    id = next_request_id(),
    type = 'prompt',
    message = message,
  }

  if state.streaming then
    payload.streamingBehavior = 'followUp'
    set_ui_status('queued', 'Pi is busy; queued follow-up')
  end

  local encoded = vim.json.encode(payload) .. '\n'
  local wrote, write_err = pcall(state.process.write, state.process, encoded)
  if not wrote then
    local message = 'Failed to write to background Pi: ' .. tostring(write_err)
    set_ui_status('error', message)
    notify(message, vim.log.levels.ERROR)
    state.running = false
    state.process = nil
  else
    set_ui_status(state.streaming and 'queued' or 'thinking', 'Prompt sent')
  end
end

local function ensure_file_backed_buffer(command_name)
  local bufnr = vim.api.nvim_get_current_buf()
  if not buffer_is_file_backed(bufnr) then
    notify(command_name .. ' requires a file', vim.log.levels.ERROR)
    return nil
  end
  return bufnr
end

function M.prompt_with_buffer()
  local bufnr = ensure_file_backed_buffer('PiBgAsk')
  if not bufnr then
    return
  end

  vim.ui.input({ prompt = context_module().format_prompt_label(bufnr, nil) }, function(input)
    if input then
      M.send(input .. '\n\nContext:\n' .. context_module().get_buffer_context(bufnr, pi_config()))
    end
  end)
end

function M.prompt_with_selection()
  local bufnr = ensure_file_backed_buffer('PiBgAskSelection')
  if not bufnr then
    return
  end

  local range = context_module().get_visual_selection_range()
  vim.ui.input({ prompt = context_module().format_prompt_label(bufnr, range) }, function(input)
    if input then
      M.send(input .. '\n\nContext:\n' .. context_module().get_visual_context(bufnr, pi_config()))
    end
  end)
end

function M.current_model()
  local cfg = pi_config()
  notify('pi.nvim model: ' .. model_label(cfg.provider, cfg.model) .. ' | session: ' .. (cfg.session_mode or 'new'))
end

function M.use_model(provider, model)
  provider = empty_to_nil(provider)
  model = empty_to_nil(model)

  config.provider = provider
  config.model = model
  apply_pi_setup()
  notify('pi.nvim model set to: ' .. model_label(provider, model))
  M.restart()
end

local function available_models()
  local output = vim.fn.systemlist({ 'pi', '--list-models' })
  if vim.v.shell_error ~= 0 then
    notify('Unable to run `pi --list-models`', vim.log.levels.ERROR)
    return {}
  end

  local models = {}
  for _, line in ipairs(output) do
    local provider, model = line:match('^(%S+)%s+(%S+)')
    if provider and model and provider ~= 'provider' then
      table.insert(models, { provider = provider, model = model, label = provider .. '  ' .. model })
    end
  end
  return models
end

function M.choose_model()
  local models = available_models()
  if #models == 0 then
    return
  end

  vim.ui.select(models, {
    prompt = 'Pi model',
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice then
      M.use_model(choice.provider, choice.model)
    end
  end)
end

function M.session_mode(mode)
  mode = empty_to_nil(mode)
  local valid = { continue = true, new = true, ephemeral = true }

  if not mode then
    local cfg = pi_config()
    notify('pi.nvim session mode: ' .. (cfg.session_mode or 'new'))
    return
  end

  if not valid[mode] then
    notify('Usage: :PiSessionMode continue|new|ephemeral', vim.log.levels.ERROR)
    return
  end

  config.session_mode = mode
  apply_pi_setup()
  notify('pi.nvim session mode set to: ' .. mode)
  M.restart()
end

local term = { bufnr = nil, winid = nil, job_id = nil }

local function terminal_job_running()
  return term.job_id and vim.fn.jobwait({ term.job_id }, 0)[1] == -1
end

local function find_window_for_buffer(bufnr)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
  return nil
end

local function terminal_args(opts)
  opts = opts or {}
  local cfg = pi_config()
  local args = { 'pi' }
  local session_mode = opts.session_mode or cfg.session_mode or 'continue'

  if cfg.provider then
    vim.list_extend(args, { '--provider', cfg.provider })
  end
  if cfg.model then
    vim.list_extend(args, { '--model', cfg.model })
  end
  if session_mode == 'continue' then
    table.insert(args, '--continue')
  elseif session_mode == 'ephemeral' then
    table.insert(args, '--no-session')
  end
  return args
end

function M.terminal(opts)
  opts = opts or {}
  if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) and terminal_job_running() then
    local existing_win = find_window_for_buffer(term.bufnr)
    if existing_win then
      vim.api.nvim_win_close(existing_win, true)
    else
      vim.cmd('botright 15split')
      term.winid = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(term.winid, term.bufnr)
      vim.cmd('startinsert')
    end
    return
  end

  vim.cmd('botright 15split')
  term.winid = vim.api.nvim_get_current_win()
  term.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(term.winid, term.bufnr)
  vim.bo[term.bufnr].bufhidden = 'hide'
  vim.bo[term.bufnr].swapfile = false
  vim.api.nvim_buf_set_name(term.bufnr, 'pi://terminal')
  term.job_id = vim.fn.termopen(terminal_args(opts), { cwd = vim.loop.cwd() })
  vim.cmd('startinsert')
end

function M.terminal_new()
  M.terminal({ session_mode = 'new' })
end

local function register_commands()
  vim.api.nvim_create_user_command('PiBgAsk', M.prompt_with_buffer, { desc = 'Ask background Pi with current buffer as context' })
  vim.api.nvim_create_user_command('PiBgAskSelection', M.prompt_with_selection, { range = true, desc = 'Ask background Pi with visual selection as context' })
  vim.api.nvim_create_user_command('PiBgCancel', M.abort, { desc = 'Abort the current background Pi operation' })
  vim.api.nvim_create_user_command('PiBgStop', M.stop, { desc = 'Stop the background Pi process' })
  vim.api.nvim_create_user_command('PiBgRestart', M.restart, { desc = 'Restart the background Pi process' })
  vim.api.nvim_create_user_command('PiBgStatus', M.status, { desc = 'Show background Pi status' })
  vim.api.nvim_create_user_command('PiChooseModel', M.choose_model, { desc = 'Choose pi.nvim provider/model from `pi --list-models`' })
  vim.api.nvim_create_user_command('PiCurrentModel', M.current_model, { desc = 'Show current pi.nvim provider/model and session mode' })
  vim.api.nvim_create_user_command('PiTerminal', M.terminal, { desc = 'Toggle a persistent Pi terminal' })
  vim.api.nvim_create_user_command('PiTerminalNew', M.terminal_new, { desc = 'Open a persistent Pi terminal in a fresh saved session' })
  vim.api.nvim_create_user_command('PiUseModel', function(opts)
    if #opts.fargs == 0 then
      M.use_model(nil, nil)
    elseif #opts.fargs == 2 then
      M.use_model(opts.fargs[1], opts.fargs[2])
    else
      notify('Usage: :PiUseModel <provider> <model> or :PiUseModel to use CLI default', vim.log.levels.ERROR)
    end
  end, { nargs = '*', desc = 'Set pi.nvim provider/model; no args resets to pi CLI default' })
  vim.api.nvim_create_user_command('PiSessionMode', function(opts)
    M.session_mode(opts.args)
  end, {
    nargs = '?',
    complete = function()
      return { 'continue', 'new', 'ephemeral' }
    end,
    desc = 'Set pi.nvim session mode: continue, new, or ephemeral',
  })
end

local function register_keymaps()
  if not config.keymaps then
    return
  end

  local p = config.keymap_prefix
  vim.keymap.set('n', p .. 'i', M.prompt_with_buffer, { desc = 'Ask background Pi' })
  vim.keymap.set('v', p .. 'i', M.prompt_with_selection, { desc = 'Ask background Pi about selection' })
  vim.keymap.set('n', p .. 'c', M.abort, { desc = 'Cancel background Pi' })
  vim.keymap.set('n', p .. 'l', '<cmd>PiLog<cr>', { desc = 'Open Pi log' })
  vim.keymap.set('n', p .. 'm', M.choose_model, { desc = 'Choose Pi model' })
  vim.keymap.set('n', p .. 'M', M.current_model, { desc = 'Show Pi model/session' })
  vim.keymap.set('n', p .. 's', M.status, { desc = 'Show background Pi status' })
  vim.keymap.set('n', p .. 'S', M.stop, { desc = 'Stop background Pi process' })
  vim.keymap.set('n', p .. 't', M.terminal, { desc = 'Toggle persistent Pi terminal' })
end

function M.setup(opts)
  config = plugin_config_from_env(opts)
  apply_pi_setup()
  register_commands()
  register_keymaps()
end

function M.get_config()
  return vim.deepcopy(config)
end

return M
