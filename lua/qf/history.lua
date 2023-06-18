---@class HistoryItem
---@field key string
---@field title string
---@field items Item
---@field tally Tally

---@type table<string, integer>
local indices = {}

---@type HistoryItem[]
local history = {}

local M = {}

function M.remove(key)
  local index = indices[key]
  if index then
    M.remove_index(index)
  end
end

function M.remove_index(index)
  table.remove(history, index)
  for k, i in pairs(indices) do
    if i > index then
      print(string.format("Updating index for %s:%d", k, i))
      indices[k] = i - 1
    end
  end
end

---@param key string
---@param item HistoryItem
function M.insert(key, item)
  M.remove(key)

  table.insert(history, item)
  local index = #history
  indices[key] = index
end

local max_history = 8
local util = require("qf.util")

--- Saves the list using the provided `key`
---@param list string
---@param key string|nil
function M.save(list, key)
  if #history > max_history then
    M.remove_index(0)
  end

  list = util.fix_list(list)
  local info = util.get_list(list, { items = 1, title = 1, qfbufnr = 1 })
  if info.qfbufnr == 0 then
    return
  end

  key = key or info.title:sub(1, 32)

  M.insert(key, {
    tally = util.tally(info.items),
    key = key,
    title = info.title,
    items = info.items,
  })
end

---@param key string
---@return HistoryItem|nil
function M.get(key)
  local index = indices[key]
  if index then
    local item = history[index]
    return item
  else
    return nil
  end
end

---@param list string
---@param key string
---@param opts SetOpts|nil
function M.restore(list, key, opts)
  local item = M.get(key)
  list = util.fix_list(list)
  if item then
    require("qf").set(
      list,
      vim.tbl_extend("keep", {
        items = item.items,
        title = item.title,
        open = true,
      }, opts or {})
    )
  end
end

---@param opts SetOpts|nil
function M.pick(list, opts)
  list = util.fix_list(list)
  local list_name
  if list == "c" then
    list_name = "Quickfix"
  else
    list_name = "Loclist"
  end

  vim.ui.select(history, {
    prompt = "Restore " .. list_name,
    format_item = function(item)
      return table.concat({ item.key, util.tally_str(item.tally, false) }, " ")
    end,
  }, function(item)
    if not item then
      return
    end
    require("qf").set(
      list,
      vim.tbl_extend("keep", {
        items = item.items,
        title = item.title,
        open = true,
      }, opts or {})
    )
  end)
end

return M
