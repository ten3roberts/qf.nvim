local M = {}

local list_defaults = {
  auto_close = true,
  auto_open = true,
  auto_resize = true,
  max_height = 8,
}

local defaults = {
  quickfix = list_defaults,
  location = list_defaults,
}

function M.setup(options)
  options = options or {}
  M.options = vim.tbl_deep_extend('force', defaults, options)
end

local function list_visible(list)
  if list == 'quickfix' then
    return #vim.tbl_filter(function(t) return t.quickfix == 1 end, vim.fn.getwininfo()) > 0
  else
    return #vim.tbl_filter(function(t) return t.loclist == 1 end, vim.fn.getwininfo()) > 0
  end
end

local function list_items(list)
  if list == 'quickfix' then
    return vim.fn.getqflist()
  else
    return vim.fn.getloclist('.')
  end
end

local function fix_list(list)
  list = list or 'quickfix'

  if list == 'qf' or list == 'quickfix' then
    return 'quickfix'
  else if list == 'loc' or list == 'location' then
      return 'location'
    end
    error("Invalid list type: " .. list)
  end
end

-- Automatically resize list to the number of items or max_height
function M.resize(list, num_items)
  local opts = M.options[fix_list(list)]

  num_items = num_items or #list_items(list)

  local height = math.min(num_items, opts.max_height)
  if height == 0 then
    height = opts.max_height
  end

  if list == 'quickfix' then
    vim.cmd("cclose | copen " .. height )
  else
    vim.cmd("lclose | lopen " .. height )
  end
end

-- Open the `quickfix` or `location` list
function M.open(list)
  list = fix_list(list)

  local opts = M.options[list]
  local num_items = #list_items(list)

  if num_items == 0 then
    print ('No items in ' .. list .. ' list')
  end

  -- Auto close
  if num_items == 0 and opts.auto_close then
    if list == 'quickfix' then
      vim.cmd "cclose"
    else
      vim.cmd "lclose"
    end
    return
  end

  -- Auto resize
  if opts.auto_resize then
    M.resize(list, num_items)
  else
    if list == 'quickfix' then
      vim.cmd "copen"
    else
      vim.cmd "lopen"
    end
  end
end

-- Close list
function M.close(list)
  list = fix_list(list)

  if list == 'quickfix' then
    vim.cmd "cclose"
  else
    vim.cmd "lclose"
  end
end

-- Toggle list
function M.toggle(list)
  list = fix_list(list)

  if list_visible(list) then
    M.close(list)
  else
    M.open(list)
  end
end

return M
