local syntax_cache
local fn = vim.fn

local M = {}
function M.setup_syntax()
  if syntax_cache then
    return syntax_cache
  end

  local template = [[
    syn match QfError "^%s" nextgroup=QfPath
    syn match QfWarn  "^%s" nextgroup=QfPath
    syn match QfInfo  "^%s" nextgroup=QfPath
    syn match QfHint  "^%s" nextgroup=QfPath
    syn match QfText  "^%s" nextgroup=QfPath

    syn match QfPath     "\(^[%s]\s\)\@<=[^ :]\+" nextgroup=QfLocation
    syn match QfLocation "[0-9:]\+" contained

    hi link QfError %s
    hi link QfWarn  %s
    hi link QfInfo  %s
    hi link QfHint  %s
    hi link QfText  %s

    hi link QfLocation Number
    hi link QfPath     Directory
  ]]

  local config = require("qf").config
  local d = config.signs
  local sum = d.E.sign .. d.W.sign .. d.I.sign .. d.N.sign .. d.T.sign .. " "
  syntax_cache = string.format(
    template,
    d.E.sign,
    d.W.sign,
    d.I.sign,
    d.N.sign,
    d.T.sign,
    sum,
    d.E.hl,
    d.W.hl,
    d.I.hl,
    d.N.hl,
    d.T.hl
  )
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

local util = require("qf.util")

function M.format_items(info)
  local items = util.get_list(info.quickfix == 1 and "c" or "l", { i = info.id, items = 1 }, info.winid).items

  local signs = require("qf").config.signs
  local l = {}

  local maxl = 0

  for _, item in ipairs(items) do
    local icon

    icon = signs[item.type]
    icon = icon and icon.sign or " "

    local t = {}

    if icon then
      t[#t + 1] = icon
    end

    local header = (item.bufnr ~= 0 and fn.bufname(item.bufnr) or " ")
      .. (item.lnum ~= 0 and ":" .. item.lnum or " ")
      .. (item.col ~= 0 and ":" .. item.col or "")
    maxl = math.max(maxl, #header)
    -- end
    t[#t + 1] = rpad(header, maxl)

    -- Remove newlines
    t[#t + 1] = item.text:gsub("[\n\r]", " ↩ ")

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
