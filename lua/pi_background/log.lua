local config = require('pi_background.config')

local M = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = 'pi-background.nvim' })
end

function M.append(event, data)
  local path = config.get().log_path
  if not path or path == '' then
    return
  end

  local entry = vim.json.encode({
    timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    event = event,
    data = data,
  })

  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  vim.fn.writefile({ entry }, path, 'a')
end

function M.open()
  local path = config.get().log_path
  if not path or path == '' then
    notify('pi-background.nvim: log_path not configured', vim.log.levels.ERROR)
    return
  end

  if vim.fn.filereadable(path) == 0 then
    notify('pi-background.nvim: log file not found at ' .. path)
    return
  end

  vim.cmd('new')
  vim.cmd('read ' .. vim.fn.fnameescape(path))
  vim.cmd('1d')
  vim.bo.modifiable = false
  vim.bo.buftype = 'nofile'
  vim.bo.filetype = 'json'
  vim.cmd('normal! G')
end

return M
