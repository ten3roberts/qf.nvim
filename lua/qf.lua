local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local bo = vim.bo
local wo = vim.wo

--- Documentation
--- Quickfix and Location list management for Neovim.
---
--- This plugin allows easier use of the builtin lists for wrapping navigation,
--following, toggling, and much more.
--
---@tag qf.nvim

---@class List
---@field auto_close boolean Close the list if empty
---@field auto_follow string|boolean Follow current entries. Possible strategies: prev,next,nearest or false to disable
---@field auto_follow_limit number limit the distance for the auto follow
---@field follow_slow boolean debounce following to `updatetime`
---@field auto_open boolean Open list on QuickFixCmdPost, e.g; grep
---@field auto_resize boolean Grow or shrink list according to items
---@field max_height number Auto resize max height
---@field min_height number Auto resize min height
---@field wide boolean Open list at the very bottom of the screen
---@field number boolean Show line numbers in window
---@field relativenumber boolean Show relative line number in window
---@field unfocus_close boolean Close list when parent window loses focus
---@field focus_open boolean Pair with `unfocus_close`, open list when parent window focuses
local list_defaults = {
  auto_close = true,
  auto_follow = "prev",
  auto_follow_limit = 8,
  follow_slow = true,
  auto_open = true,
  auto_resize = true,
  max_height = 8,
  min_height = 5,
  wide = false,
  number = false,
  relativenumber = false,
  unfocus_close = false,
  focus_open = false,
}

---@tag qf.config
---@class Config
---@field c List
---@field l List
---@field close_other boolean Close other list kind on open. If location list opens, qf closes, and vice-versa..
---@field pretty boolean Use a pretty printed format function for the quickfix lists.
local defaults = {
  c = list_defaults,
  l = list_defaults,
  close_other = true,
  pretty = true,
  -- signs = {
  --   E = { hl = "DiagnosticSignError", sign = "" },
  --   W = { hl = "DiagnosticSignWarn", sign = "" },
  --   I = { hl = "DiagnosticSignInfo", sign = "" },
  --   N = { hl = "DiagnosticSignHint", sign = "" },
  --   T = { hl = "DiagnosticSignHint", sign = "" },
  -- },
}

local qf = { config = defaults }

local util = require("qf.util")

local fix_list = util.fix_list
local list_items = util.list_items
local get_height = util.get_height

local post_commands = {
  "make",
  "grep",
  "grepadd",
  "vimgrep",
  "vimgrepadd",
  "cfile",
  "cgetfile",
  "caddfile",
  "cexpr",
  "cgetexpr",
  "caddexpr",
  "cbuffer",
  "cgetbuffer",
  "caddbuffer",
}

local function list_post_commands(l)
  if l == "l" then
    return vim.tbl_map(
      -- Remove prefix c and prepend l
      function(val)
        if val:sub(1, 1) == "c" then
          return "l" .. val:sub(2)
        else
          return "l" .. val
        end
      end,
      post_commands
    )
  else
    return post_commands
  end
end

local function istrue(val)
  return val == true or val == "1"
end

--- Initialize and configure qf.nvim using the provided config.
---@param config Config
function qf.setup(config)
  qf.config = vim.tbl_deep_extend("force", defaults, config or {})
  qf.saved = {}

  if qf.config.pretty then
    local fmt = require("qf.format")
    vim.opt.quickfixtextfunc = "QfFormat"
    qf.setup_syntax = function()
      vim.cmd(fmt.setup_syntax())
    end
  else
    qf.setup_syntax = function() end
  end

  qf.setup_autocmds(qf.config)
end

local function message_verbose(verbose, msg, level)
  if istrue(verbose) ~= false then
    vim.notify(msg, level)
  end
end

local function check_empty(list, num_items, verbose)
  if num_items == 0 then
    if list == "c" then
      message_verbose(verbose, "Quickfix list empty", vim.log.levels.ERROR)
    else
      message_verbose(verbose, "Location list empty", vim.log.levels.ERROR)
    end

    return false
  end
  return true
end

--- Close and opens list if already open.
--- This is to fix the list stretching bottom of a new vertical split.
---@param list string
function qf.reopen(list)
  -- local prev = fn.win_getid(fn.winnr('#'))
  if api.nvim_buf_get_option(0, "filetype") == "qf" or api.nvim_buf_get_option(0, "buftype") ~= "" then
    return
  end

  list = fix_list(list)

  if util.get_list_win(list) == 0 then
    return
  end

  print("Reopening window: " .. list)

  -- api.nvim_exec(
  --   string.format(
  --     [[
  -- noau %sclose
  -- ]],
  --     list,
  --     list,
  --     get_height(list, qf.config)
  --   ),
  --   false
  -- )

  -- api.nvim_set_current_win(new)

  -- qf.on_ft()
end

function qf.reopen_all()
  local reopen = qf.reopen
  reopen("c")
  reopen("l")
end

local set_list = util.set_list
local get_list = util.get_list
qf.get_list_win = util.get_list_win

local function set_entry(list, idx)
  set_list(list, {}, "r", { idx = idx })
end

-- Setup qf filetype specific options
function qf.on_ft(winid)
  winid = winid or fn.win_getid()
  local wininfo = fn.getwininfo(winid) or {}
  local list = nil

  if not wininfo or not wininfo[1] then
    return
  end

  if wininfo[1].quickfix == 1 then
    list = "c"
  end

  if wininfo[1].loclist == 1 then
    list = "l"
  end

  if list == nil then
    return
  end

  local opts = qf.config[list]

  bo.buflisted = false
  wo.winfixheight = true
  wo.number = opts.number
  wo.relativenumber = opts.relativenumber

  if opts.auto_resize then
    api.nvim_win_set_height(winid, get_height(list, qf.config))
  end

  if opts.wide then
    cmd("wincmd J")
  end
end

--- Resize list to the number of items between max and min height
--- If stay, the list will not be focused.
---@param list string
---@param size number|nil If nil, the size will be deduced from the item count and config
function qf.resize(list, size)
  list = fix_list(list)

  local opts = qf.config[list]

  local win = util.get_list_win(list)

  -- Don't do anything if list isn't open
  if win == 0 then
    return
  end

  local height = size or get_height(list, qf.config)
  if height ~= 0 then
    api.nvim_win_set_height(win, height)
  elseif opts.auto_close then
    cmd(list .. "close")
  end
end

--- Open the `quickfix` or `location` list
--- If stay == true, the list will not be focused
--- If auto_close is true, the list will be closed if empty, similar to cwindow
---@param list string
---@param stay boolean|nil
---@tag qf.open() Qopen Lopen
function qf.open(list, stay, silent)
  list = fix_list(list)

  local opts = qf.config[list]
  local num_items = get_list(list, { size = 1 }).size

  -- Auto close
  if not check_empty(list, num_items, not silent) then
    if opts and opts.auto_close then
      cmd(list .. "close")
      return
    end
    return
  end

  if qf.config.close_other then
    if list == "c" then
      local wininfo = fn.getwininfo()
      for _, win in ipairs(wininfo) do
        if win.loclist == 1 then
          api.nvim_win_close(win.winid, false)
        end
      end
    elseif list == "l" then
      cmd("cclose")
    end
  end

  local win = util.get_list_win(list)
  if win ~= 0 then
    if not istrue(stay) then
      api.nvim_set_current_win(win)
    end
    return
  end
  cmd(list .. "open " .. get_height(list, qf.config))

  if istrue(stay) then
    cmd("wincmd p")
  end
end

--- Close `list`
--- @param list string
---@tag qf.close() Qclose LClose VClose
function qf.close(list)
  list = fix_list(list)

  cmd(list .. "close")
end

--- Toggle `list`
--- If stay == true, the list will not be focused
---@param list string
---@param stay boolean|nil Do not focus the opened list
---@tag qf.toggle() QToggle LToggle
function qf.toggle(list, stay)
  list = fix_list(list)

  if util.get_list_win(list) ~= 0 then
    qf.close(list)
  else
    qf.open(list, stay)
  end
end

--- Clears the quickfix or current location list
---@param list string
---@param name string|nil save the list before clearing under name
---@tag qf.clear() Qclear Lclear
function qf.clear(list, name)
  list = fix_list(list)

  if name then
    qf.save(list, name)
  end

  if list == "c" then
    fn.setqflist({})
  else
    fn.setloclist(".", {})
  end

  qf.open(list, true)
end

local function clear_prompt()
  vim.api.nvim_command("normal :esc<CR>")
end

local function linelen(bufnr, lnum)
  if not api.nvim_buf_is_valid(bufnr) then
    return 0
  end
  return #(api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or "")
end

local is_valid = util.is_valid

-- Returns the list entry currently previous to the cursor
---@param list string
---@param include_current boolean
---@return Item|nil
local function follow_prev(list, include_current)
  local pos = util.get_pos()
  local items = util.sorted_list_items(list)
  if #items == 0 then
    return nil
  end

  local compare_pos = util.compare_pos
  local found_buf = false

  for i = 1, #items do
    local j = #items - i + 1
    local item = items[j]
    local ord = compare_pos(item, pos)

    -- We overshot the current buffer
    if item.bufnr == pos.bufnr then
      found_buf = true
    end
    -- If the current entry is past cursor, of the entry of the cursor has been
    -- passed
    item.col = math.min(item.col, linelen(item.bufnr, item.lnum))
    if found_buf and (ord == -1 or (include_current and ord == 0)) then
      return item
    end
  end

  return nil
end

-- Returns the first entry after the cursor in buf or the first entry in the
-- buffer
---@param list string
---@param include_current boolean
---@return Item|nil
local function follow_next(list, include_current)
  local pos = util.get_pos()
  local items = util.sorted_list_items(list)
  if #items == 0 then
    return nil
  end

  local compare_pos = util.compare_pos
  for _, item in ipairs(items) do
    local ord = compare_pos(item, pos)
    -- We overshot the current buffer
    -- If the current entry is past cursor, of the entry of the cursor has been
    -- passed
    item.col = math.min(item.col, linelen(item.bufnr, item.lnum))
    if ord == 1 or (include_current and ord == 0) then
      return item
    end
  end

  return nil
end

-- Returns the list entry closest to the cursor vertically
--- Follows the closest entry
---@return Item|nil
local function follow_nearest(list)
  local items = util.sorted_list_items(list)
  if #items == 0 then
    return nil
  end
  local pos = util.get_pos()
  local i = 1
  local min = nil
  local min_item = nil

  for _, item in ipairs(items) do
    local dist = math.abs((item.lnum == pos.lnum and pos.col and item.col - pos.col) or item.lnum - pos.lnum)

    if min == nil or dist < min and item.bufnr == pos.bufnr then
      min_item = item
      min = dist
    end

    i = i + 1
  end

  return min_item
end

local strategy_lookup = {
  prev = follow_prev,
  next = follow_next,
  nearest = follow_nearest,
}

--- strategy is one of the following:
--- - 'prev'
--- - 'next'
--- - 'nearest'
---@param limit number|nil Don't select entry further away than limit.
function qf.follow(list, strategy, limit)
  if api.nvim_get_mode().mode ~= "n" or vim.o.buftype == "quickfix" then
    return
  end

  list = fix_list(list)
  local opts = qf.config[list]

  local pos = fn.getpos(".")
  local line = pos[2]

  -- Cursor hasn't moved to a new line since last call
  if opts and opts.last_line and opts.last_line == line then
    return
  end

  opts.last_line = line

  local strategy_func = strategy_lookup[strategy or "prev"]
  if strategy_func == nil then
    vim.notify("Invalid follow strategy " .. strategy, vim.log.levels.ERROR)
    return
  end

  local item = strategy_func(list, true)

  if not item then
    return
  end

  if type(limit == "boolean") and limit == true then
    limit = opts.auto_follow_limit
  end

  -- if limit and math.abs(items[i].lnum - line) > limit then
  --   return
  -- end

  -- Clear echo area
  -- clear_prompt()
  -- Select found entry
  set_entry(list, item.idx)
end

local function goto_entry(list, index)
  local silent = qf.config.silent and "silent" or ""
  local command = list == "c" and "cc" or "ll"

  cmd(string.format("%s %s %d", silent, command, index))
end

---comment
---@param items Item[]
---@param start number
---@param direction number
---@param func fun(item: Item): boolean
---@param wrap boolean
---@return Item|nil
local function seek_entry(items, start, direction, func, wrap)
  --- Find next valid
  if direction == 1 then
    for i = start, #items do
      local item = items[i]
      if func(item) then
        return item
      end
    end

    local items = vim.tbl_filter(func, items)
    local first = items[1]

    return first
  else
    for i = #items - start + 1, #items do
      local j = #items - i + 1

      local item = items[j]
      if func(item) then
        return item
      end
    end

    if wrap then
      local items = vim.tbl_filter(func, items)
      local last = items[#items]

      return last
    end
  end
end

--- Wrapping version of [lc]next. Also takes into account valid entries.
--- If wrap is nil or true, it will wrap around the list
---@tag qf.next() Qnext Lnext
function qf.next(list, wrap, verbose)
  if wrap == nil then
    wrap = true
  end
  list = fix_list(list)

  local info = get_list(list, { items = 1, idx = 0 })

  local item = seek_entry(info.items, info.idx + 1, 1, is_valid, wrap)
  if item then
    goto_entry(list, item.idx)
  end
end

-- Wrapping version of [lc]prev. Also takes into account valid entries.
-- If wrap is nil or true, it will wrap around the list
---@tag qf.prev() Qprev Lprev
function qf.prev(list, wrap, verbose)
  if wrap == nil then
    wrap = true
  end
  list = fix_list(list)

  local info = get_list(list, { items = 1, idx = 0 })

  local item = seek_entry(info.items, info.idx - 1, -1, is_valid, wrap)

  if item then
    goto_entry(list, item.idx)
  end
end

--- Wrapping version of [lc]above
--- Will switch buffer
---@tag qf.above() Qabove Labove Vabove
function qf.above(list, wrap, verbose)
  if wrap == nil then
    wrap = true
  end

  list = fix_list(list)

  local item = follow_prev(list, false)

  if not item then
    check_empty(list, 0, verbose)
    return
  end

  goto_entry(list, item.idx)
end

--- Wrapping version of [lc]below
--- Will switch buffer
---@tag qf.below() Qbelow Lbelow Vbelow
function qf.below(list, wrap, verbose)
  if wrap == nil then
    wrap = true
  end
  list = fix_list(list)

  local item = follow_next(list, false)

  print("Item: " .. vim.inspect(item))
  if not item then
    check_empty(list, 0, verbose)
    return
  end

  goto_entry(list, item.idx)
end

---@param list string
---@param key string|nil
function qf.save(list, key)
  require("qf.history").save(list, key)
end

--- Restores a saved list into the location or quickfix list
--- If name is not given, user will be prompted with all saved lists.
---@param list string
---@param key string|nil
---@param opts SetOpts|nil
function qf.load(list, key, opts)
  if key then
    require("qf.history").restore(list, key, opts)
  else
    require("qf.history").pick(list, opts)
  end
end

---@class SetOpts
---@field items table
---@field lines table
---@field cwd string
---@field compiler string|nil
---@field winid number|nil
---@field title string|nil
---@field tally boolean|nil
---@field open boolean|string|nil if "auto", open if there are errors
---@field save boolean|nil saves the previous list

--- Set location or quickfix list items
--- If a compiler is given, the items will be parsed from it
--- Invalidates follow cache
---@param list string
---@param opts SetOpts
function qf.set(list, opts)
  list = fix_list(list)

  if opts.save then
    qf.save(list, nil)
  end

  local old_c = vim.b.current_compiler

  local old_efm = vim.opt.efm

  local old_makeprg = vim.o.makeprg
  local old_cwd = fn.getcwd()

  if opts.cwd then
    api.nvim_set_current_dir(opts.cwd)
  end

  if opts.compiler ~= nil then
    vim.cmd("compiler! " .. opts.compiler)
  else
  end
  if opts.lines == nil and opts.items == nil then
    vim.notify("Missing either opts.lines or opts.items in qf.set()", vim.log.levels.ERROR)
  end

  if list == "c" then
    vim.fn.setqflist({}, "r", {
      title = opts.title,
      items = opts.items,
      lines = opts.lines,
    })
  else
    vim.fn.setloclist(opts.winid or 0, {}, "r", {
      title = opts.title,
      items = opts.items,
      lines = opts.lines,
    })
  end

  vim.b.current_compiler = old_c
  vim.opt.efm = old_efm
  vim.o.makeprg = old_makeprg
  if old_c ~= nil then
    vim.cmd("compiler " .. old_c)
  end

  qf.config[list].last_line = nil

  if opts.cwd then
    api.nvim_set_current_dir(old_cwd)
  end

  if
    opts.open == true
    or (opts.open == "auto" and util.tally(util.get_list(list, { items = 1 }, opts.winid).items).error > 0)
  then
    qf.open(list, true, true)
  end
end

---@class QfInfo
---@field title string
---@field tally_str string
---@field tally Tally
---@field list_kind string
---@field size integer
---@field idx integer

---@param list string
---@return QfInfo
function qf.get_info(list, winid)
  list = fix_list(list)

  local info = get_list(list, { items = 1, title = 1, id = 0 }, winid)

  local title = info.title

  local tally = util.tally(info.items)

  local tally_str = util.tally_str(tally, true)
  return {
    title = title,
    tally = tally,
    tally_str = tally_str,
  }
end

---@return QfInfo|nil
function qf.inspect_win(winid)
  local info = fn.getwininfo(winid)[1]

  local title = info.variables.quickfix_title
  local list
  local what = { all = 1 }
  if info.loclist == 1 then
    list = util.get_list("l", what, winid)
  elseif info.quickfix == 1 then
    list = util.get_list("c", what, winid)
  else
    return nil
  end

  local tally = util.tally(list.items)

  local tally_str = util.tally_str(tally, true)
  return {
    title = title,
    tally = tally,
    tally_str = tally_str,
    size = list.size,
    idx = list.idx,
  }
end

function qf.filter_text(list, pat)
  list = fix_list(list)
  local items = vim.tbl_filter(function(item)
    return item.text:find(pat, 1, true) or vim.fn.bufname(item.bufnr):find(pat, 1, true)
  end, list_items(list))

  qf.set(list, { items = items, open = true, tally = true })
end

---Filter and keep items in a list based on `filter`
---@param list string
---@param filter fun(Entry): boolean
---@param multiline_msg boolean keep multiline messages spanning many items
---@tag qf.keep() VkeepText QkeepText LkeepText VkeepType QkeepType LkeepType
function qf.filter(list, filter, multiline_msg)
  list = fix_list(list)

  local items = {}

  local extend = false
  for _, item in ipairs(list_items(list, true)) do
    if multiline_msg ~= false and item.type == "" and extend then
      table.insert(items, item)
    elseif filter(item) then
      extend = true
      table.insert(items, item)
    else
      extend = false
    end
  end

  qf.set(list, { items = items, open = true, tally = true })
end

--- Sort the items according to file -> line -> column
---@tag qf.sort() Qsort Lsort Vsort
function qf.sort(list)
  list = fix_list(list)
  local items = list_items(list, true)
  table.sort(items, function(a, b)
    a.fname = a.fname or fn.bufname(a.bufnr)
    b.fname = b.fname or fn.bufname(b.bufnr)

    if not is_valid(a) then
      a.text = "invalid"
    end
    if not is_valid(b) then
      b.text = "invalid"
    end

    if a.fname == b.fname then
      if a.lnum == b.lnum then
        return a.col < b.col
      else
        return a.lnum < b.lnum
      end
    else
      return a.fname < b.fname
    end
  end)

  qf.set(list, {
    items = items,
  })
end

--- Called in |qf.setup|
---@param config Config
function qf.setup_autocmds(config)
  local g = api.nvim_create_augroup("qf", { clear = true })
  local au = function(events, callback, opts)
    opts = opts or {}
    opts.group = g
    opts.callback = callback
    api.nvim_create_autocmd(events, opts)
  end

  local follow = qf.follow
  local open = qf.open
  local close = qf.close

  au("WinClosed", function(o)
    local winid = tonumber(o.file)
    local wininfo = fn.getwininfo(winid)[1]
    if wininfo == nil then
      return
    end
    if wininfo.loclist == 1 or wininfo.quickfix == 1 then
      return
    end

    local loc_win = util.location_list(winid)
    if loc_win ~= nil then
      api.nvim_win_close(loc_win, true)
    end
  end)

  for k, list in pairs({ c = config.c, l = config.l }) do
    if list.auto_follow then
      au(list.follow_slow and "CursorHold" or "CursorMoved", function()
        follow(k, list.auto_follow, 16)
      end)
    end

    if list.unfocus_close then
      au("WinLeave", function(o)
        vim.schedule(function()
          local winid = tonumber(o.file)
          local wininfo = fn.getwininfo(winid)[1]

          if wininfo.loclist == 1 or wininfo.quickfix == 1 then
            return
          end

          local loc_win = util.location_list(winid)
          if loc_win ~= nil then
            api.nvim_win_close(loc_win, true)
          end
        end)
      end)
    end

    if list.focus_open then
      au("WinEnter", function()
        open(k, true, true)
      end)
    end

    if list.auto_open then
      au("QuickFixCmdPost", function()
        open(k, true, true)
      end, { pattern = list_post_commands(k) })
    end
  end
end

return qf
