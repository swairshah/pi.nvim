local M = {}

local defaults = {
  -- nil means: let the installed `pi` CLI choose its normal default.
  provider = nil,
  model = nil,
  session_mode = 'continue', -- continue | new | ephemeral
  log_path = vim.fn.stdpath('state') .. '/pi-background.log',
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

local function apply_env_overrides(cfg)
  cfg.provider = empty_to_nil(vim.g.pi_nvim_provider or vim.env.PI_NVIM_PROVIDER) or cfg.provider
  cfg.model = empty_to_nil(vim.g.pi_nvim_model or vim.env.PI_NVIM_MODEL) or cfg.model
  cfg.session_mode = vim.env.PI_NVIM_SESSION_MODE or cfg.session_mode
  return cfg
end

function M.setup(opts)
  values = apply_env_overrides(vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {}))
  return values
end

function M.get()
  return values
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
end

function M.set_session_mode(mode)
  values.session_mode = mode
end

function M.get_pi_config()
  return values
end

return M
