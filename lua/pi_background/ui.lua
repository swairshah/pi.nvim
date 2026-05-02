local config = require('pi_background.config')

local M = {}

local spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

local state = {
  bufnr = nil,
  winid = nil,
  timer = nil,
  close_timer = nil,
  status = 'idle',
  history = {},
  show_lines = {},
  spinner_idx = 0,
  streaming = false,
}

local function is_buffer_valid()
  return state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr)
end

local function is_window_valid()
  return state.winid and vim.api.nvim_win_is_valid(state.winid)
end

local function cancel_close_timer()
  if state.close_timer then
    state.close_timer:stop()
    state.close_timer:close()
    state.close_timer = nil
  end
end

local function title()
  return state.status == 'error' and ' pi error ' or ' pi '
end

local function status_line()
  local active = state.status == 'starting' or state.status == 'thinking' or state.status == 'running_tool' or state.status == 'queued'
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

  return prefix .. (labels[state.status] or state.status)
end

local function split_lines(text)
  local lines = {}
  text = text:gsub('\r\n', '\n'):gsub('\r', '\n')
  if text == '' then
    return lines
  end
  for line in (text .. '\n'):gmatch('(.-)\n') do
    lines[#lines + 1] = line
  end
  return lines
end

local function compact_blank_edges(lines)
  while #lines > 0 and lines[1] == '' do
    table.remove(lines, 1)
  end
  while #lines > 0 and lines[#lines] == '' do
    table.remove(lines)
  end
  return lines
end

function M.render()
  if not is_buffer_valid() then
    return
  end

  local lines = { status_line() }

  local start_idx = math.max(1, #state.history - 2)
  for i = start_idx, #state.history do
    lines[#lines + 1] = state.history[i]
  end

  if #state.show_lines > 0 then
    if #lines > 1 then
      lines[#lines + 1] = ''
    end
    vim.list_extend(lines, compact_blank_edges(vim.deepcopy(state.show_lines)))
  end

  vim.bo[state.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  vim.bo[state.bufnr].modifiable = false

  if is_window_valid() then
    local cfg = config.get()
    local max_height = math.max(3, math.floor(vim.o.lines * (cfg.window.max_height_fraction or 0.35)))
    pcall(vim.api.nvim_win_set_config, state.winid, vim.tbl_extend('force', vim.api.nvim_win_get_config(state.winid), {
      title = title(),
      height = math.min(math.max(#lines, 1), max_height),
    }))
  end
end

function M.ensure()
  local cfg = config.get()
  if not cfg.window.enabled then
    return
  end

  cancel_close_timer()

  if not is_buffer_valid() then
    state.bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[state.bufnr].buftype = 'nofile'
    vim.bo[state.bufnr].bufhidden = 'wipe'
    vim.bo[state.bufnr].swapfile = false
    vim.bo[state.bufnr].modifiable = false
    vim.api.nvim_buf_set_name(state.bufnr, 'pi-background://status')
    vim.keymap.set('n', 'q', M.close, { buffer = state.bufnr, silent = true, desc = 'Close Pi popup' })
    vim.keymap.set('n', '<Esc>', M.close, { buffer = state.bufnr, silent = true, desc = 'Close Pi popup' })
  end

  if not is_window_valid() then
    local width = math.min(cfg.window.max_width, math.max(cfg.window.min_width, math.floor(vim.o.columns * cfg.window.width)))
    local height = 4
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    if cfg.window.position == 'top-right' then
      row = cfg.window.row or 1
      col = math.max(0, vim.o.columns - width - (cfg.window.col_offset or 2))
    end

    state.winid = vim.api.nvim_open_win(state.bufnr, false, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
      title = title(),
      title_pos = 'center',
      noautocmd = true,
    })
    vim.wo[state.winid].wrap = true
    vim.wo[state.winid].linebreak = true
    vim.wo[state.winid].winfixbuf = true
  end

  if not state.timer then
    state.timer = vim.loop.new_timer()
    state.timer:start(100, 100, vim.schedule_wrap(function()
      if is_buffer_valid() and state.streaming then
        M.render()
      end
    end))
  end

  M.render()
end

function M.close()
  cancel_close_timer()

  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end

  if is_window_valid() then
    pcall(vim.api.nvim_win_close, state.winid, true)
  end

  if is_buffer_valid() then
    pcall(vim.api.nvim_buf_delete, state.bufnr, { force = true })
  end

  state.winid = nil
  state.bufnr = nil
end

function M.schedule_close(delay_ms)
  cancel_close_timer()
  state.close_timer = vim.loop.new_timer()
  state.close_timer:start(delay_ms or config.get().window.close_after_done_ms, 0, vim.schedule_wrap(M.close))
end

function M.set_streaming(streaming)
  state.streaming = streaming
end

function M.clear_history()
  state.history = {}
end

function M.clear_show()
  state.show_lines = {}
end

function M.push(message)
  if message and message ~= '' then
    state.history[#state.history + 1] = message
  end
end

function M.append_show(text)
  if not text or text == '' then
    return
  end
  local new_lines = split_lines(text)
  if #new_lines == 0 then
    return
  end

  if #state.show_lines == 0 then
    state.show_lines = new_lines
  elseif text:sub(1, 1) == '\n' then
    vim.list_extend(state.show_lines, new_lines)
  else
    state.show_lines[#state.show_lines] = state.show_lines[#state.show_lines] .. new_lines[1]
    for i = 2, #new_lines do
      state.show_lines[#state.show_lines + 1] = new_lines[i]
    end
  end

  M.ensure()
end

function M.set_status(status, message, opts)
  opts = opts or {}
  state.status = status
  M.push(message)
  M.ensure()
  if opts.close_after then
    M.schedule_close(opts.close_after)
  end
end

return M
