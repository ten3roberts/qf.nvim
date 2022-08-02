local M = {}
local api = vim.api
local fn = vim.fn

function M.fix_list(list)
  list = list or "c"

  if list == "qf" or list == "quickfix" or list == "c" then
    return "c"
  elseif list == "loc" or list == "location" or list == "l" then
    return "l"
  end

  if list == "visible" then
    if M.get_list_win("l") ~= 0 then
      return "l"
    else
      return "c"
    end
  end
  api.nvim_err_writeln("Invalid list type: " .. list)
  return "c"
end

-- Returns true if the current item is valid by having valid == 1 and a valid bufnr and line number
local function is_valid(item)
  return (item.bufnr > 0 and item.lnum > 0)
end

M.is_valid = is_valid

function M.set_list(list, items, mode, opts)
  if list == "c" then
    return fn.setqflist(items, mode, opts)
  else
    return fn.setloclist(".", items, mode, opts)
  end
end

function M.get_list(list, what, winid)
  what = what or { items = 1 }
  if list == "c" then
    return fn.getqflist(what)
  else
    return fn.getloclist(winid or ".", what)
  end
end

function M.get_list_win(list)
  list = M.fix_list(list)
  local tabnr = fn.tabpagenr()
  if list == "c" then
    local w = vim.tbl_filter(function(t)
      return t.tabnr == tabnr and t.quickfix == 1 and t.loclist == 0
    end, fn.getwininfo())[1]
    if w then
      return w.winid
    else
      return 0
    end
  else
    return vim.fn.getloclist(0, { winid = 0 })["winid"] or 0
  end
end

function M.list_items(list, all)
  local items = M.get_list(list).items
  if all then
    return items
  else
    return vim.tbl_filter(is_valid, items)
  end
end

function M.valid_list_items(list)
  local items = M.get_list(list).items
  local t = {}

  for i, v in ipairs(items) do
    if is_valid(v) then
      v.idx = i
      t[#t + 1] = v
    end
  end

  return t
end

function M.get_height(list, config)
  local opts = config[list]

  if opts.auto_resize == false then
    return opts.max_height
  end

  local size = M.get_list(list, { size = 1 }).size

  return math.max(math.min(size, opts.max_height), opts.min_height)
end

---comment
---@param list any
---@return integer[]
function M.tally(list)
  -- Tally
  local error = 0
  local warn = 0
  local information = 0
  local hint = 0
  local text = 0

  local sevs = {}

  for _, v in ipairs(M.list_items(list, false)) do
    sevs[v.type] = (sevs[v.type] or 0) + 1
    if v.type == "E" then
      error = error + 1
    elseif v.type == "W" then
      warn = warn + 1
    elseif v.type == "I" then
      information = information + 1
    elseif v.type == "N" then
      hint = hint + 1
    else
      text = text + 1
    end
  end

  return { error, warn, information, hint, text }
end

return M
