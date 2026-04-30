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

local values = vim.deepcopy(defaults)

local function empty_to_nil(value)
  if value == nil or value == '' then
    return nil
  end
  return value
end

local function apply_env_overrides(config)
  config.provider = empty_to_nil(vim.g.pi_nvim_provider or vim.env.PI_NVIM_PROVIDER) or config.provider
  config.model = empty_to_nil(vim.g.pi_nvim_model or vim.env.PI_NVIM_MODEL) or config.model
  config.session_mode = vim.env.PI_NVIM_SESSION_MODE or config.session_mode
  return config
end

function M.setup(opts)
  values = apply_env_overrides(vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {}))
  M.apply_pi_setup()
  return values
end

function M.get()
  return values
end

function M.apply_pi_setup()
  require('pi').setup({
    provider = values.provider,
    model = values.model,
    max_context_lines = values.max_context_lines,
    max_context_bytes = values.max_context_bytes,
    selection_context_lines = values.selection_context_lines,
    log_path = values.log_path,
    skills = values.skills,
    extensions = values.extensions,
    tools = values.tools,
    session_mode = values.session_mode,
  })
end

function M.empty_to_nil(value)
  return empty_to_nil(value)
end

function M.model_label(provider, model)
  if provider and model then
    return provider .. '/' .. model
  end
  return 'pi CLI default'
end

function M.set_model(provider, model)
  values.provider = empty_to_nil(provider)
  values.model = empty_to_nil(model)
  M.apply_pi_setup()
end

function M.set_session_mode(mode)
  values.session_mode = mode
  M.apply_pi_setup()
end

function M.get_pi_config()
  return require('pi.config').get()
end

return M
