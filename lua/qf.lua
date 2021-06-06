local M = {}

local list_defaults = {
  auto_close = true,
  auto_follow = 'prev',
  auto_open = true,
  auto_resize = true,
  max_height = 8,
}

local defaults = {
  quickfix = list_defaults,
  location = list_defaults,
}

local post_commands = {
  'make', 'grep', 'grepadd', 'vimgrep', 'vimgrepadd',
  'cfile', 'cgetfile', 'caddfile', 'cexpr', 'cgetexpr',
  'caddexpr', 'cbuffer', 'cgetbuffer', 'caddbuffer'
}

local function qf_post_commands()
  return table.concat(post_commands, ',')
end

local function loc_post_commands()
  return table.concat( vim.tbl_map(
    -- Remove prefix c and prepend l
    function(val) if val:sub(1,1) == 'c' then
      return 'l'..val:sub(2)
    else
      return 'l' .. val end
    end
    , post_commands), ',')
end


local function setup_autocmds(options)
  vim.cmd 'augroup qf.nvim'
  vim.cmd 'autocmd!'

  local quickfix = options.quickfix
  local location = options.location

  if location.auto_follow then
    vim.cmd('autocmd CursorMoved * :lua require"qf".follow("location", "' .. location.auto_follow .. '")')
  end

  if quickfix.auto_follow then
    vim.cmd('autocmd CursorMoved * :lua require"qf".follow("quickfix", "' .. quickfix.auto_follow .. '")')
  end

  if location.auto_open then
    vim.cmd('autocmd QuickFixCmdPost ' .. loc_post_commands() .. ' :lua require"qf".open("location")')
  end

  if quickfix.auto_open then
    vim.cmd('autocmd QuickFixCmdPost ' .. qf_post_commands() .. ' :lua require"qf".open("quickfix")')
  end

  vim.cmd 'augroup END'
end

function M.setup(options)
  options = options or {}
  M.options = vim.tbl_deep_extend('force', defaults, options)

  setup_autocmds(M.options)
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

-- Returns the list entry currently previous to the cursor
local function follow_prev(items, bufnr, line)
  local i = 1
  local last_valid = nil
  while i <= #items do
    if items[i].bufnr == bufnr then
      last_valid = i
      if items[i].lnum > line then
        return math.max(i - 1, 1)
      end
    end

    i = i + 1
  end

  return last_valid
end

-- Returns the list entry currently after to the cursor
local function follow_next(items, bufnr, line)
  local i = 1
  local last_valid = nil
  while i <= #items do
    if items[i].bufnr == bufnr then
      last_valid = i
      if items[i].lnum > line then
        return i
      end
    end

    i = i + 1
  end

  return last_valid
end

-- Returns the list entry closest to the cursor vertically
local function follow_nearest(items, bufnr, line)
  local i = 1
  local min = nil
  local min_i = nil

  while i <= #items do
    if items[i].bufnr == bufnr then
      local dist = math.abs(items[i].lnum - line)

      if min == nil or dist < min then
        min = dist
        min_i = i
      end
    end

    i = i + 1
  end

  return min_i
end


local strategy_lookup = {
  prev = follow_prev,
  next = follow_next,
  nearest = follow_nearest,
}

-- strategy is one of the following:
-- - prev
-- - next
-- - nearest
function M.follow(list, strategy)
  list = fix_list(list)
  local opts = M.options[list]

  local pos = vim.fn.getpos('.')

  local bufnr = vim.fn.bufnr('%')
  local line = pos[2]

  -- Cursor hasn't moved to a new line since last call
  if opts.last_line and opts.last_line == line then
    return
  end

  opts.last_line = line

  local strategy_func = strategy_lookup[strategy or 'prev']
  if strategy_func == nil then
    error("Invalid follow strategy " .. strategy)
    return
  end

  local items = list_items(list)

  if #items == 0 then
    return
  end

  local i = strategy_func(items, bufnr, line)

  if i == nil then
    return
  end

  -- Select found entry
  if list == 'quickfix' then
    vim.cmd('cc ' .. i)
  else
    vim.cmd('ll ' .. i)
  end

  vim.fn.setpos('.', pos)
end

return M
