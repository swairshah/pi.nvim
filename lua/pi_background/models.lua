local config = require('pi_background.config')
local process = require('pi_background.process')

local M = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = 'pi-background.nvim' })
end

function M.current()
  local cfg = config.get_pi_config()
  notify('Pi model: ' .. config.model_label(cfg.provider, cfg.model) .. ' | session: ' .. (cfg.session_mode or 'new'))
end

function M.use(provider, model)
  config.set_model(provider, model)
  notify('Pi model set to: ' .. config.model_label(provider, model))
  process.restart()
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

function M.choose()
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
      M.use(choice.provider, choice.model)
    end
  end)
end

function M.session_mode(mode)
  mode = config.empty_to_nil(mode)
  local valid = { continue = true, new = true, ephemeral = true }

  if not mode then
    notify('Pi session mode: ' .. (config.get_pi_config().session_mode or 'new'))
    return
  end

  if not valid[mode] then
    notify('Usage: :PiSessionMode continue|new|ephemeral', vim.log.levels.ERROR)
    return
  end

  config.set_session_mode(mode)
  notify('Pi session mode set to: ' .. mode)
  process.restart()
end

return M
