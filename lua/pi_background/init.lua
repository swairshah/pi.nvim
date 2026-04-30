local M = {}

local config = require('pi_background.config')
local commands = require('pi_background.commands')
local process = require('pi_background.process')
local prompt = require('pi_background.prompt')
local models = require('pi_background.models')
local terminal = require('pi_background.terminal')

function M.setup(opts)
  config.setup(opts)
  commands.register_commands()
  commands.register_keymaps()
end

M.start = process.start
M.stop = process.stop
M.restart = process.restart
M.status = process.status
M.abort = process.abort
M.send = process.send
M.prompt_with_buffer = prompt.with_buffer
M.prompt_with_selection = prompt.with_selection
M.choose_model = models.choose
M.use_model = models.use
M.current_model = models.current
M.session_mode = models.session_mode
M.terminal = terminal.toggle
M.terminal_new = terminal.new_session
M.get_config = config.get

return M
