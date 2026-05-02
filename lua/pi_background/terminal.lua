local config = require('pi_background.config')

local M = {}

local state = { bufnr = nil, winid = nil, job_id = nil }

local function terminal_job_running()
  return state.job_id and vim.fn.jobwait({ state.job_id }, 0)[1] == -1
end

local function find_window_for_buffer(bufnr)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
  return nil
end

local function args(opts)
  opts = opts or {}
  local cfg = config.get_pi_config()
  local cmd = { 'pi' }
  local session_mode = opts.session_mode or cfg.session_mode or 'continue'

  if cfg.provider then
    vim.list_extend(cmd, { '--provider', cfg.provider })
  end
  if cfg.model then
    vim.list_extend(cmd, { '--model', cfg.model })
  end
  if session_mode == 'continue' then
    table.insert(cmd, '--continue')
  elseif session_mode == 'ephemeral' then
    table.insert(cmd, '--no-session')
  end
  for _, path in ipairs(config.extension_paths()) do
    vim.list_extend(cmd, { '--extension', path })
  end
  return cmd
end

function M.toggle(opts)
  opts = opts or {}
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) and terminal_job_running() then
    local existing_win = find_window_for_buffer(state.bufnr)
    if existing_win then
      vim.api.nvim_win_close(existing_win, true)
    else
      vim.cmd('botright 15split')
      state.winid = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(state.winid, state.bufnr)
      vim.cmd('startinsert')
    end
    return
  end

  vim.cmd('botright 15split')
  state.winid = vim.api.nvim_get_current_win()
  state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(state.winid, state.bufnr)
  vim.bo[state.bufnr].bufhidden = 'hide'
  vim.bo[state.bufnr].swapfile = false
  vim.api.nvim_buf_set_name(state.bufnr, 'pi://terminal')
  state.job_id = vim.fn.termopen(args(opts), { cwd = vim.loop.cwd() })
  vim.cmd('startinsert')
end

function M.new_session()
  M.toggle({ session_mode = 'new' })
end

return M
