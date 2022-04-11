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
  return (item.bufnr > 0 and item.lnum > 0)
end

M.is_valid = is_valid


function M.set_list(list, items, mode, opts)
  if list == 'c' then
    return fn.setqflist(items, mode, opts)
  else
    return fn.setloclist(".", items, mode, opts)
  end
end

function M.get_list(list, what, winid)
  what = what or { items = 1 }
  if list == 'c' then
    return fn.getqflist(what)
  else
    return fn.getloclist(winid or ".", what)
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

local syntax_cache

function M.setup_syntax()
  if syntax_cache then return syntax_cache end

  local template = [[
    syn match QfError "^%s" nextgroup=QfPath
    syn match QfWarn  "^%s" nextgroup=QfPath
    syn match QfInfo  "^%s" nextgroup=QfPath
    syn match QfHint  "^%s" nextgroup=QfPath
    syn match QfText  "^%s" nextgroup=QfPath

    syn match QfPath     "\(^[%s]\s\)\@<=[^ :]\+" nextgroup=QfLocation
    syn match QfLocation "[0-9:]\+" contained

    hi link QfError DiagnosticSignError
    hi link QfWarn  DiagnosticSignWarn
    hi link QfInfo  DiagnosticSignInfo
    hi link QfHint  Search
    hi link QfText  Error

    hi link QfLocation Number
    hi link QfPath     Directory
  ]]

  local d = diagnostic_severities
  syntax_cache = string.format(template, d[1].sign, d[2].sign, d[3].sign, d[4].sign, d[5].sign,
    d[1].sign .. d[2].sign .. d[3].sign .. d[4].sign .. d[5].sign .. " ")
  return syntax_cache
end

local function rpad(s, len)
  local p = len - #s
  if p > 0 then
    return s .. string.rep(" ", p)
  else
    return s
  end
end

function M.format_items(info)
  local items = M.get_list(info.quickfix == 1 and "c" or "l", { i=info.id, items = 1}, info.winid).items;

  local l = {}

  local maxl = 0

  for _, item in ipairs(items) do
    local icon

    if     item.type == "E" then icon = diagnostic_severities[1].sign
    elseif item.type == "W" then icon = diagnostic_severities[2].sign
    elseif item.type == "I" then icon = diagnostic_severities[3].sign
    elseif item.type == "N" then icon = diagnostic_severities[4].sign
    else                         icon = " "
    end

    local t = {}

    if icon then
      t[#t + 1] = icon
    end

    local header = (item.bufnr ~= 0 and fn.bufname(item.bufnr) or " ") .. (item.lnum ~= 0 and ":" .. item.lnum or " ") .. (item.col ~= 0 and ":" .. item.col or "")
    -- if item.bufnr ~= 0 then
    --   header = fn.bufname(item.bufnr)
    --   if item.lnum ~= 0 then
    --     header = header .. ":" .. item.lnum
    --     if item.col  ~= 0 then
    --       header = header .. ":" .. item.col
    --     end
    --   end

    maxl = math.max(maxl, #header)
    -- end
    t[#t + 1] = rpad(header, maxl)

    -- Remove newlines
    -- t[#t + 1] = string.gsub(item.text, "[\n\r]", "")
    t[#t + 1] = item.text

    l[#l + 1] = table.concat(t, " ")
  end


  return l
end

_G.__qf_format = M.format_items

vim.cmd([[
    function! QfFormat(info)
    return v:lua.__qf_format(a:info)
    endfunction
]])

return M
