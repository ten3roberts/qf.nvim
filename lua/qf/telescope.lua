local qf = require("qf")
local util = require("qf.util")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values

local make_entry = require("telescope.make_entry")

local M = {}

---@class Opts
---@field list string
---@field id number|nil
---@field bufnr number|nil
---@field filter (fun(Item): boolean)|nil

---@param opts Opts
function M.list(opts)
  opts = opts or {}
  -- local qf_identifier = opts.id or vim.F.if_nil(opts.bufnr, "$")
  -- local items = util.get_list(opts.list or "c", { [opts.id and "id" or "nr"] = qf_identifier, items = true }).items
  local items = util.get_list(opts.list or "c", { items = true }).items

  local filter = opts.filter or function()
    return true
  end

  items = vim.tbl_filter(function(v)
    return util.is_valid(v) and filter(v)
  end, items)

  if vim.tbl_isempty(items) then
    return
  end

  pickers
    .new(opts, {
      prompt_title = "Quickfix",
      finder = finders.new_table({
        results = items,
        entry_maker = opts.entry_maker or make_entry.gen_from_quickfix(opts),
      }),
      previewer = conf.qflist_previewer(opts),
      sorter = conf.generic_sorter(opts),
    })
    :find()
end

M.test = function()
  M.list({
    list = "l",
    filter = function(v)
      return v.type == "W"
    end,
  })
end

return M
