local M = {}

local list_defaults = {
  auto_close = true, -- Automatically close location/quickfix list if empty
  auto_follow = 'prev', -- Follow current entry, possible values: prev,next,nearest
  follow_slow = true, -- Only follow on CursorHold
  auto_open = true, -- Automatically open location list on QuickFixCmdPost
  auto_resize = true, -- Auto resize and shrink location list if less than `max_height`
  max_height = 8, -- Maximum height of location/quickfix list
}

local defaults = {
  c = list_defaults,
  l = list_defaults,
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
local function setup_autocmds(options)
  vim.cmd 'augroup qf.nvim'
  vim.cmd 'autocmd!'

  local c = options.c
  local l = options.l

  if l.auto_follow then
    if l.follow_slow then
      vim.cmd('autocmd CursorHold * :lua require"qf".follow("l", "' .. c.auto_follow .. '")')
    else
      vim.cmd('autocmd CursorMoved * :lua require"qf".follow("c", "' .. c.auto_follow .. '")')
    end
  end

  if c.auto_follow then
    if c.follow_slow then
      vim.cmd('autocmd CursorHold * :lua require"qf".follow("c", "' .. c.auto_follow .. '", 8)')
    else
      vim.cmd('autocmd CursorMoved * :lua require"qf".follow("c", "' .. c.auto_follow .. '", 8)')
    end
  end


  if l.auto_open then
    vim.cmd('autocmd QuickFixCmdPost ' .. loc_post_commands() .. ' :lua require"qf".open("l", true)')
  end

  if c.auto_open then
    vim.cmd('autocmd QuickFixCmdPost ' .. qf_post_commands() .. ' :lua require"qf".open("c", true)')
  end

  vim.cmd('autocmd QuitPre * :lua require"qf".close("loc")')

  vim.cmd 'augroup END'
end

function M.setup(options)
  options = options or {}
  M.options = vim.tbl_deep_extend('force', defaults, options)
  M.saved = {}

  setup_autocmds(M.options)
end

local function list_visible(list)
  if list == 'c' then
    return #vim.tbl_filter(function(t) return t.quickfix == 1 end, vim.fn.getwininfo()) > 0
  else
    return #vim.tbl_filter(function(t) return t.loclist == 1 end, vim.fn.getwininfo()) > 0
  end
end

local function list_items(list)
  if list == 'c' then
    return vim.fn.getqflist()
  else
    return vim.fn.getloclist('.')
  end
end

local function fix_list(list)
  list = list or 'c'

  if list == 'qf' or list == 'quickfix' or list == 'c' then
    return 'c'
  elseif list == 'loc' or list == 'location' or list == 'l' then
    return 'l'
  end
  error("Invalid list type: " .. list)
end

-- Automatically resize list to the number of items or max_height
function M.resize(list, num_items)
  local opts = M.options[fix_list(list)]

  if not opts.auto_resize then
    return
  end

  num_items = num_items or #list_items(list)

  local height = math.min(num_items, opts.max_height)
  if height == 0 then
    height = opts.max_height
  end

  if list == 'c' then
    vim.cmd("cclose | copen " .. height )
  else
    vim.cmd("lclose | lopen " .. height )
  end
end

-- Hide quickfix and location lists from the buffers list
-- Hide linenumbers and relative line numbers
local function hide_lists()
  vim.tbl_map(
    function(win)
      if win.quickfix or win.loclist then
        vim.fn.setbufvar(win.bufnr, "&buflisted", 0)
        vim.fn.setbufvar(win.bufnr, "&number", 0)
        vim.fn.setbufvar(win.bufnr, "&relativenumber", 0)
      end
    end,
    vim.fn.getwininfo())
end

-- Open the `quickfix` or `location` list
-- If stay == true, the list will not be focused
function M.open(list, stay)
  list = fix_list(list)

  local opts = M.options[list]
  local num_items = #list_items(list)

  -- Auto close
  if num_items == 0 and opts.auto_close then
    if list == 'c' then
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
    if list == 'c' then
      vim.cmd "copen"
    else
      vim.cmd "lopen"
    end
  end

  hide_lists()

  if stay then
    vim.cmd "wincmd p"
  end
end

-- Close list
function M.close(list)
  list = fix_list(list)

  if list == 'c' then
    vim.cmd "cclose"
  else
    vim.cmd "lclose"
  end
end

-- Toggle list
-- If stay == true, the list will not be focused
function M.toggle(list, stay)
  list = fix_list(list)

  if list_visible(list) then
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
    vim.fn.setqflist({})
  else
    vim.fn.setloclist('.', {})
  end

  M.open(list, 0)
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

-- Returns the list entry currently after the cursor
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
-- - 'prev'
-- - 'next'
-- - 'nearest'
-- (optional) limit, don't select entry further away than limit.
-- If entry is further away than limit, the entry will not be selected. This is to prevent recentering of cursor caused by setpos. There is no way to select an entry without jumping, so the cursor position is saved and restored instead.
function M.follow(list, strategy, limit)
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

  if i == nil or items[i].bufnr ~= bufnr then
    return
  end

  if limit and math.abs(items[i].lnum - line > limit) then
    return
  end

  -- Clear echo area
  print('')
  -- Select found entry
  if list == 'c' then
    vim.cmd('cc ' .. i)
  else
    vim.cmd('ll ' .. i)
  end

  vim.fn.setpos('.', pos)
end

-- Wrapping version of [lc]next
function M.next(list)
  list = fix_list(list)

  if list == 'c' then
    vim.cmd "try | :cnext | catch | cfirst | endtry"
  else
    vim.cmd "try | :lnext | catch | lfirst | endtry"
  end
end

-- Wrapping version of [lc]prev
function M.prev(list)
  list = fix_list(list)

  if list == 'c' then
    vim.cmd "try | :cprev | catch | clast | endtry"
  else
    vim.cmd "try | :lprev | catch | llast | endtry"
  end
end

-- Wrapping version of [lc]above
-- Will switch buffer
function M.above(list)
  list = fix_list(list)

  local items = list_items(list)
  local bufnr = vim.fn.bufnr('%')
  local line = vim.fn.line('.')

  local idx = follow_next(items, bufnr, line - 1) - 1

  if idx == 0 then
    vim.cmd(list .. 'last')
  elseif list == 'c' then
    vim.cmd('cc ' .. idx)
  else
    vim.cmd('ll ' .. idx)
  end
end

-- Wrapping version of [lc]below
-- Will switch buffer
function M.below(list)
  list = fix_list(list)

  local items = list_items(list)
  local bufnr = vim.fn.bufnr('%')
  local line = vim.fn.line('.')

  local idx = follow_prev(items, bufnr, line) + 1

  if idx > #items then
    vim.cmd (list .. 'first')
  elseif list == 'c' then
    vim.cmd('cc ' .. idx)
  else
    vim.cmd('ll ' .. idx)
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
    error("No saved lists")
  end

  local choice = vim.fn.confirm('Choose saved list', table.concat(t, '\n'))
  if choice == nil then
    return nil
  end

  return t[choice]
end

-- Loads a saved list into the location or quickfix list
-- If name is not given, user will be prompted with all saved lists.
function M.load(list, name)
  list = fix_list(list)

  print("Name: ", name)
  if name == nil then
    name = prompt_name()
  end

  if name == nil then
    return
  end

  local items = M.saved[name]

  if items == nil then
    error("No list saved with name: " .. name)
    return
  end

  if list == 'c' then
    vim.fn.setqflist(items)
  else
    vim.fn.setloclist('.', items)
  end

  if M.options[list].auto_open then
    M.open(list, true)
  end
end

return M
