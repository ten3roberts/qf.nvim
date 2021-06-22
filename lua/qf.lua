local M = {}

local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local bo = vim.bo
local wo = vim.wo

local list_defaults = {
  auto_close = true, -- Automatically close location/quickfix list if empty
  auto_follow = 'prev', -- Follow current entry, possible values: prev,next,nearest, or false to disable
  auto_follow_limit = 8, -- Do not follow if entry is further away than x lines
  follow_slow = true, -- Only follow on CursorHold
  auto_open = true, -- Automatically open list on QuickFixCmdPost
  auto_resize = true, -- Auto resize and shrink location list if less than `max_height`
  max_height = 8, -- Maximum height of location/quickfix list
  min_height = 5, -- Minumum height of location/quickfix list
  wide = false, -- Open list at the very bottom of the screen, stretching the whole width.
  number = false, -- Show line numbers in list
  relativenumber = false, -- Show relative line numbers in list
}

local defaults = {
  c = list_defaults,
  l = list_defaults,
  -- Close location list when quickfix list is opened.
  qf_close_loc = false,
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


-- Setup and configure qf.nvim
local function setup_autocmds(config)
  cmd 'augroup qf.nvim'
  cmd 'autocmd!'

  local c = config.c
  local l = config.l

  if l.auto_follow then
    if l.follow_slow then
      cmd('autocmd CursorHold * :lua require"qf".follow("l", "' .. l.auto_follow .. '", true)')
    else
      cmd('autocmd CursorMoved * :lua require"qf".follow("l", "' .. l.auto_follow .. '", true)')
    end
  end

  if c.auto_follow then
    if c.follow_slow then
      cmd('autocmd CursorHold * :lua require"qf".follow("c", "' .. c.auto_follow .. '", true)')
    else
      cmd('autocmd CursorMoved * :lua require"qf".follow("c", "' .. c.auto_follow .. '", true)')
    end
  end


  if l.auto_open then
    cmd('autocmd QuickFixCmdPost ' .. loc_post_commands() .. ' :lua require"qf".open("l", true)')
  end

  if c.auto_open then
    cmd('autocmd QuickFixCmdPost ' .. qf_post_commands() .. ' :lua require"qf".open("c", true)')
  end

  cmd('autocmd QuitPre * :lua require"qf".close("loc")')

  cmd 'augroup END'
end

function M.setup(config)
  config = config or {}
  M.config = vim.tbl_deep_extend('force', defaults, config)
  M.saved = {}

  setup_autocmds(M.config)
end

local function printv(msg, verbose)
  if verbose ~= false then print(msg) end
end

local function check_empty(list, num_items, verbose)
  if num_items == 0 then
    if list == 'c' then
      printv("Quickfix list empty", verbose)
      return false
    else
      printv("Location list empty", verbose)
      return false
    end
  end
  return true
end

function M.list_visible(list)
  if list == 'c' then
    return #vim.tbl_filter(function(t) return t.quickfix == 1 end, fn.getwininfo()) > 0
  else
    return #vim.tbl_filter(function(t) return t.loclist == 1 end, fn.getwininfo()) > 0
  end
end

local function list_items(list)
  if list == 'c' then
    return fn.getqflist()
  else
    return fn.getloclist('.')
  end
end

local function fix_list(list)
  list = list or 'c'

  if list == 'qf' or list == 'quickfix' or list == 'c' then
    return 'c'
  elseif list == 'loc' or list == 'location' or list == 'l' then
    return 'l'
  end
  api.nvim_err_writeln("Invalid list type: " .. list)
  return nil
end

local function get_height(list, num_items)
  local opts = M.config[list]
  num_items = num_items or #list_items(list)

  return math.max(math.min(num_items, opts.max_height), opts.min_height)
end

-- Same as resize, but does nothing if auto_resize is off
function M.checked_auto_resize(list, stay)
  if M.config[list].auto_resize then
    M.resize(list, stay)
  end
end

-- Setup qf filetype specific options
function M.on_ft()
  local wininfo = fn.getwininfo(fn.win_getid()) or {}
  local list = nil

  if not wininfo or not wininfo[1] then
    return
  end

  if wininfo[1].quickfix == 1 then
    list = 'c'
  end

  if wininfo[1].loclist == 1 then
    list = 'l'
  end

  if list == nil then
    return
  end

  local opts = M.config[list]

  bo.buflisted = false
  wo.number = opts.number
  wo.relativenumber = opts.relativenumber


  if opts.auto_resize then
    cmd('resize ' .. get_height(list))
  end

  if opts.wide then
    cmd "wincmd J"
  end
end

-- Resize list to the number of items between max and min height
-- If stay, the list will not be focused.
-- num_items can be provided if number of items are already none, if nil, they will be queried
function M.resize(list, stay, num_items)
  list = fix_list(list)

  local opts = M.config[list]

  -- Don't do anything if list isn't open
  if not M.list_visible(list) then
    return
  end

  local height = get_height(list, num_items)

  if height == 0 and opts.auto_close() then
    cmd (list .. 'close')
  end

  cmd(list .. "open " .. height )

  if stay then
    cmd "wincmd p"
  end
end

-- Open the `quickfix` or `location` list
-- If stay == true, the list will not be focused
function M.open(list, stay, verbose)
  list = fix_list(list)

  local opts = M.config[list]
  local num_items = #list_items(list)

  check_empty(list, num_items, verbose)

  -- Auto close
  if num_items == 0 then
    if opts.auto_close then
      cmd(list .. 'close')
    else
      -- List is empty, but ensure it is properly sized
      M.resize(list, true, num_items)
    end
    return
  end

  if list == 'c'  and M.config.qf_close_loc then
    cmd 'lclose'
  end

  -- Only open if not already open
  if not M.list_visible(list) then
    cmd(list .. 'open ' .. opts.max_height)
  end

  if stay then
    cmd "wincmd p"
  end
end

-- Close list
function M.close(list)
  list = fix_list(list)

  cmd(list .. 'close')
end

-- Toggle list
-- If stay == true, the list will not be focused
function M.toggle(list, stay)
  list = fix_list(list)

  if M.list_visible(list) then
    M.close(list)
  else
    M.open(list, stay)
  end

end

-- Clears the quickfix or current location list
-- If name is not nil, the current list will be saved before being cleared
function M.clear(list, name)
  list = fix_list(list)

  if name then
    M.save(list, name)
  end

  if list == 'c' then
    fn.setqflist({})
  else
    fn.setloclist('.', {})
  end

  M.open(list, 0)
end

-- Returns the list entry currently previous to the cursor
local function follow_prev(items, bufnr, line)
  local i = 1
  local last_valid = 1
  for _,item in ipairs(items) do
    if item.valid == 1 and item.bufnr == bufnr then
      last_valid = i
      if item.lnum > line then
        return math.max(i - 1, 1)
      end
    end

    i = i + 1
  end

  return last_valid
end

-- Returns the list entry currently after the cursor
local function follow_next(items, bufnr, line)
  local i = 1
  local last_valid = 1
  for _,item in ipairs(items) do
    if item.valid == 1 and item.bufnr == bufnr then
      last_valid = i
      if item.lnum > line then
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

  for _,item in ipairs(items) do
    if items.valid == 1 and item.bufnr == bufnr then
      local dist = math.abs(item.lnum - line)

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
-- - 'prev'
-- - 'next'
-- - 'nearest'
-- (optional) limit, don't select entry further away than limit.
-- If entry is further away than limit, the entry will not be selected. This is to prevent recentering of cursor caused by setpos. There is no way to select an entry without jumping, so the cursor position is saved and restored instead.
function M.follow(list, strategy, limit)
  list = fix_list(list)
  local opts = M.config[list]

  local pos = fn.getpos('.')

  local bufnr = fn.bufnr('%')
  local line = pos[2]

  -- Cursor hasn't moved to a new line since last call
  if opts.last_line and opts.last_line == line then
    return
  end

  opts.last_line = line

  local strategy_func = strategy_lookup[strategy or 'prev']
  if strategy_func == nil then
    api.nvim_err_writeln("Invalid follow strategy " .. strategy)
    return
  end

  local items = list_items(list)

  if #items == 0 then
    return
  end

  local i = strategy_func(items, bufnr, line)

  if i == nil or items[i].bufnr ~= bufnr then
    return
  end

  if type(limit == 'boolean') and limit == true then
    limit = opts.auto_follow_limit
  end

  if limit and math.abs(items[i].lnum - line) > limit then
    return
  end

  -- Clear echo area
  print('')
  -- Select found entry
  if list == 'c' then
    cmd('cc ' .. i)
  else
    cmd('ll ' .. i)
  end

  fn.setpos('.', pos)
end

-- Wrapping version of [lc]next
function M.next(list, verbose)
  list = fix_list(list)

  if not check_empty(list, #list_items(list), verbose) then
    return
  end

  if list == 'c' then
    cmd "try | :cnext | catch | cfirst | endtry"
  else
    cmd "try | :lnext | catch | lfirst | endtry"
  end
end

-- Wrapping version of [lc]prev
function M.prev(list, verbose)
  list = fix_list(list)

  if not check_empty(list, #list_items(list), verbose) then
    return
  end

  if list == 'c' then
    cmd "try | :cprev | catch | clast | endtry"
  else
    cmd "try | :lprev | catch | llast | endtry"
  end
end

-- Returns true if the current item is valid by having valid == 1 and a valid bufnr and line number
local function is_valid(item)
  return item.valid == 1 and item.bufnr ~= 0
end

local function prev_valid(items, idx)
  while idx and idx > 0 do
    if is_valid(items[idx]) then
      break
    end
    idx = idx - 1
  end

  return idx
end

local function next_valid(items, idx)
  while idx and idx <= #items do
    if is_valid(items[idx]) then
      break
    end
    idx = idx + 1
  end

  return idx
end

-- Wrapping version of [lc]above
-- Will switch buffer
function M.above(list, verbose)
  list = fix_list(list)

  local items = list_items(list)

  if not check_empty(list, #items, verbose) then
    return
  end

  local bufnr = fn.bufnr('%')
  local line = fn.line('.')

  local idx = prev_valid(items, follow_next(items, bufnr, line - 1) - 1)

  if idx == 0 then
    cmd(list .. 'last')
  elseif list == 'c' then
    cmd('cc ' .. idx)
  else
    cmd('ll ' .. idx)
  end
end

-- Wrapping version of [lc]below
-- Will switch buffer
function M.below(list, verbose)
  list = fix_list(list)

  local items = list_items(list)

  if not check_empty(list, #items, verbose) then
    return
  end

  local bufnr = fn.bufnr('%')
  local line = fn.line('.')

  local idx = next_valid(items, follow_prev(items, bufnr, line) + 1)

  if not idx or idx > #items then
    cmd (list .. 'first')
  elseif list == 'c' then
    cmd('cc ' .. idx)
  else
    cmd('ll ' .. idx)
  end
end


-- Save quickfix or location list with name
function M.save(list, name)
  list = fix_list(list)

  M.saved[name] = list_items(list)
end

local function prompt_name()
  local t = {}
  for k,_ in pairs(M.saved) do
    t[#t+1] = k
  end

  if #t == 0 then
    api.nvim_err_writeln("No saved lists")
  end

  local choice = fn.confirm('Choose saved list', table.concat(t, '\n'))
  if choice == nil then
    return nil
  end

  return t[choice]
end

-- Loads a saved list into the location or quickfix list
-- If name is not given, user will be prompted with all saved lists.
function M.load(list, name)
  list = fix_list(list)

  if name == nil then
    name = prompt_name()
  end

  if name == nil then
    return
  end

  local items = M.saved[name]

  if items == nil then
    api.nvim_err_writeln("No list saved with name: " .. name)
    return
  end

  if list == 'c' then
    fn.setqflist(items)
  else
    fn.setloclist('.', items)
  end

  if M.config[list].auto_open then
    M.open(list, true)
  end
end

-- Set location or quickfix list items
-- Invalidates follow cache
function M.set(list, items)
  list = fix_list(list)

  if list == 'c' then
    fn.setqflist(items)
  else
    fn.setloclist('.', items)
  end

  local opts = M.config[list]
  opts.last_line = nil

  if #items == 0 and opts.auto_close then
    M.close(list)
  elseif opts.auto_open then
    M.open(list, true)
  end
end

return M
