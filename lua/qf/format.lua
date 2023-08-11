local syntax_cache
local fn = vim.fn

local util = require("qf.util")
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

    hi default link QfError DiagnosticSignError
    hi default link QfWarn  DiagnosticSignWarn
    hi default link QfInfo  DiagnosticSignInfo
    hi default link QfHint  DiagnosticSignHint
    hi default link QfText  DiagnosticSignHint

    hi link QfLocation Number
    hi link QfPath     Directory
  ]]

  local d = util.get_signs()
  local sum = d.E.text .. d.W.text .. d.I.text .. d.N.text .. d.T.text .. " "
  syntax_cache = string.format(template, d.E.text, d.W.text, d.I.text, d.N.text, d.T.text, sum)
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
  local items = util.get_list(info.quickfix == 1 and "c" or "l", { i = info.id, items = 1 }, info.winid).items

  local signs = util.get_signs()
  local l = {}

  local maxl = 0

  for _, item in ipairs(items) do
    local icon = signs[item.type]
    icon = icon and icon.text or ""

    local t = {}

    if icon then
      t[#t + 1] = icon
    end

    local header = table.concat(
      vim.tbl_filter(function(v)
        return #v > 0
      end, {
        item.bufnr ~= 0 and fn.bufname(item.bufnr) or "",
        item.lnum ~= 0 and tostring(item.lnum) or "",
        item.col ~= 0 and tostring(item.col) or "",
      }),
      ":"
    )

    maxl = math.max(maxl, #header)

    t[#t + 1] = rpad(header, maxl + 4)

    -- Remove newlines
    t[#t + 1] = item.text:gsub("[\n\r]", " ↩ "):gsub("^%s+", "")

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
