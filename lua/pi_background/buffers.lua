local M = {}

local function context_module()
  return require('pi.context')
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

function M.is_file_backed(bufnr)
  return context_module().buffer_is_file_backed(bufnr)
end

function M.snapshot_loaded_file_buffers()
  local snapshots = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and M.is_file_backed(bufnr) then
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

function M.reload_changed_file_buffers(before_snapshots)
  before_snapshots = before_snapshots or {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and M.is_file_backed(bufnr) then
      local path = normalize_path(vim.api.nvim_buf_get_name(bufnr))
      if not signatures_equal(before_snapshots[path], file_signature(path)) then
        reload_buffer_from_disk(bufnr, path)
      end
    end
  end
end

return M
