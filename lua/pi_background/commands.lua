local config = require('pi_background.config')
local process = require('pi_background.process')
local prompt = require('pi_background.prompt')
local models = require('pi_background.models')
local terminal = require('pi_background.terminal')
local log = require('pi_background.log')

local M = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = 'pi-background.nvim' })
end

function M.register_commands()
  vim.api.nvim_create_user_command('PiBgAsk', prompt.with_buffer, { desc = 'Ask background Pi with current buffer as context' })
  vim.api.nvim_create_user_command('PiBgAskSelection', prompt.with_selection, { range = true, desc = 'Ask background Pi with visual selection as context' })
  vim.api.nvim_create_user_command('PiBgCancel', process.abort, { desc = 'Abort the current background Pi operation' })
  vim.api.nvim_create_user_command('PiBgStop', process.stop, { desc = 'Stop the background Pi process' })
  vim.api.nvim_create_user_command('PiBgRestart', process.restart, { desc = 'Restart the background Pi process' })
  vim.api.nvim_create_user_command('PiBgStatus', process.status, { desc = 'Show background Pi status' })
  vim.api.nvim_create_user_command('PiChooseModel', models.choose, { desc = 'Choose Pi provider/model from `pi --list-models`' })
  vim.api.nvim_create_user_command('PiCurrentModel', models.current, { desc = 'Show current Pi provider/model and session mode' })
  vim.api.nvim_create_user_command('PiLog', log.open, { desc = 'Open pi-background.nvim log' })
  vim.api.nvim_create_user_command('PiTerminal', terminal.toggle, { desc = 'Toggle a persistent Pi terminal' })
  vim.api.nvim_create_user_command('PiTerminalNew', terminal.new_session, { desc = 'Open a persistent Pi terminal in a fresh saved session' })
  vim.api.nvim_create_user_command('PiUseModel', function(opts)
    if #opts.fargs == 0 then
      models.use(nil, nil)
    elseif #opts.fargs == 2 then
      models.use(opts.fargs[1], opts.fargs[2])
    else
      notify('Usage: :PiUseModel <provider> <model> or :PiUseModel to use CLI default', vim.log.levels.ERROR)
    end
  end, { nargs = '*', desc = 'Set Pi provider/model; no args resets to Pi CLI default' })
  vim.api.nvim_create_user_command('PiSessionMode', function(opts)
    models.session_mode(opts.args)
  end, {
    nargs = '?',
    complete = function()
      return { 'continue', 'new', 'ephemeral' }
    end,
    desc = 'Set Pi session mode: continue, new, or ephemeral',
  })
end

function M.register_keymaps()
  local cfg = config.get()
  if not cfg.keymaps then
    return
  end

  local p = cfg.keymap_prefix
  vim.keymap.set('n', p .. 'i', prompt.with_buffer, { desc = 'Ask background Pi' })
  vim.keymap.set('v', p .. 'i', prompt.with_selection, { desc = 'Ask background Pi about selection' })
  vim.keymap.set('n', p .. 'c', process.abort, { desc = 'Cancel background Pi' })
  vim.keymap.set('n', p .. 'l', '<cmd>PiLog<cr>', { desc = 'Open Pi log' })
  vim.keymap.set('n', p .. 'm', models.choose, { desc = 'Choose Pi model' })
  vim.keymap.set('n', p .. 'M', models.current, { desc = 'Show Pi model/session' })
  vim.keymap.set('n', p .. 's', process.status, { desc = 'Show background Pi status' })
  vim.keymap.set('n', p .. 'S', process.stop, { desc = 'Stop background Pi process' })
  vim.keymap.set('n', p .. 't', terminal.toggle, { desc = 'Toggle persistent Pi terminal' })
end

return M
