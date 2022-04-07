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

-- Returns true if the current item is valid by having valid == 1 and a valid bufnr and line number
local function is_valid(item)
  return item.bufnr ~= 0 or ( item.filename ~= nil and item.filename ~= "")
end

M.is_valid = is_valid


function M.set_list(list, items, mode, opts)
  if list == 'c' then
    return fn.setqflist(items, mode, opts)
  else
    return fn.setloclist(".", items, mode, opts)
  end
end

function M.get_list(list, what)
  what = what or { items = 1 }
  if list == 'c' then
    return fn.getqflist(what)
  else
    return fn.getloclist(".", what)
  end
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
  local items = M.get_list(list).items
  if all then
    return items
  else
    return vim.tbl_filter(is_valid, items)
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

local diagnostic_severities = {
  { hl = '%#DiagnosticSignError#', type = 'E', kind = 'error',   sign = ''};
  { hl = '%#DiagnosticSignWarn#',  type = 'W', kind = 'warning', sign = ''};
  { hl = '%#DiagnosticSignInfo#',  type = 'I', kind = 'info',    sign = ''};
  { hl = '%#DiagnosticSignHint#',  type = 'H', kind = 'hint',    sign = ''};
  { hl = '%#DiagnosticSignHint#',  type = 'T', kind = 'text',    sign = ''};
}

function M.tally(list)
  -- Tally
  local E = 0
  local W = 0
  local I = 0
  local N = 0
  local T = 0

  for _,v in ipairs(M.list_items(list)) do
    if v.type == "E" then
      E = E + 1
    elseif v.type == "W" then
      W = W + 1
    elseif v.type == "I" then
      I = I + 1
    elseif v.type == "N" then
      N = N + 1
    else
      T = T + 1
    end
  end

  local tally = { E, W, I, N, T }
  local t = {}
  for i,v in ipairs(tally) do
    if v > 0 then
      local severity = diagnostic_severities[i]
      t[#t + 1] = severity.hl .. severity.sign .. ' ' .. v
    end
  end

  -- return table.concat(t, " | ")
  return " - " .. table.concat(t, " ") .. "%#Normal#"
end

return M
