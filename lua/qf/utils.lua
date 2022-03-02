local M = {}
local api = vim.api
local fn = vim.fn

function M.fix_list(list)
  list = list or 'c'

  if list == 'qf' or list == 'quickfix' or list == 'c' then
    return 'c'
  elseif list == 'loc' or list == 'location' or list == 'l' then
    return 'l'
  end

  if list == 'visible' then
    if M.get_list_win('l') ~= 0 then
      return 'l'
    else
      return 'c'
    end
  end
  api.nvim_err_writeln("Invalid list type: " .. list)
  return nil
end

function M.get_list_win(list)
  list = M.fix_list(list)
  local tabnr = fn.tabpagenr()
  if list == 'c' then
    local w = vim.tbl_filter(function(t) return t.tabnr == tabnr and t.quickfix == 1 and t.loclist == 0 end, fn.getwininfo())[1]
    if w then return w.winid else return 0 end
  else
    return vim.fn.getloclist(0, { winid = 0 })['winid'] or 0
  end
end

function M.list_items(list, all)
  if list == 'c' then
    return vim.tbl_filter(function(v) return v.valid == 1 or all end, fn.getqflist())
  else
    return vim.tbl_filter(function(v) return v.valid == 1 or all end, fn.getloclist('.'))
  end
end

function M.get_height(list, config)
  local opts = config[list]

  if opts.auto_resize == false then
    return opts.max_height
  end

  local size = 0
  if list == 'c' then
    size = fn.getqflist({ size = 1 }).size
  else
    size = fn.getloclist('.', { size = 1 }).size
  end

  return math.max(math.min(size, opts.max_height), opts.min_height)
end

return M
