local config = require('pi_background.config')
local process = require('pi_background.process')
local buffers = require('pi_background.buffers')

local M = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = 'pi.nvim' })
end

local function context_module()
  return require('pi.context')
end

local function ensure_file_backed_buffer(command_name)
  local bufnr = vim.api.nvim_get_current_buf()
  if not buffers.is_file_backed(bufnr) then
    notify(command_name .. ' requires a file', vim.log.levels.ERROR)
    return nil
  end
  return bufnr
end

function M.with_buffer()
  local bufnr = ensure_file_backed_buffer('PiBgAsk')
  if not bufnr then
    return
  end

  vim.ui.input({ prompt = context_module().format_prompt_label(bufnr, nil) }, function(input)
    if input then
      process.send(input .. '\n\nContext:\n' .. context_module().get_buffer_context(bufnr, config.get_pi_config()))
    end
  end)
end

function M.with_selection()
  local bufnr = ensure_file_backed_buffer('PiBgAskSelection')
  if not bufnr then
    return
  end

  local range = context_module().get_visual_selection_range()
  vim.ui.input({ prompt = context_module().format_prompt_label(bufnr, range) }, function(input)
    if input then
      process.send(input .. '\n\nContext:\n' .. context_module().get_visual_context(bufnr, config.get_pi_config()))
    end
  end)
end

return M
