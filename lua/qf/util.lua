local M = {}
local api = vim.api
local fn = vim.fn

function M.fix_list(list)
    list = list or "c"

    if list == "qf" or list == "quickfix" or list == "c" then
        return "c"
    elseif list == "loc" or list == "location" or list == "l" then
        return "l"
    end

    if list == "visible" then
        local win = M.get_list_win("l")
        if win ~= 0 then
            return "l"
        else
            return "c"
        end
    end
    api.nvim_err_writeln("Invalid list type: " .. list)
    return "c"
end

-- Returns true if the current item is valid by having valid == 1 and a valid bufnr and line number
local function is_valid(item)
    return (item.bufnr > 0 and item.lnum > 0)
end

M.is_valid = is_valid

function M.set_list(list, items, mode, opts)
    if list == "c" then
        return fn.setqflist(items, mode, opts)
    else
        return fn.setloclist(".", items, mode, opts)
    end
end

---@class QfList
---@field items Item[]
---@field changedtick number
---@field size number
---@field idx number
---@field title string
---@field qfbufnr number

---@class Item: Position
---@field text string
---@field idx number
---@field type string

---@return QfList
function M.get_list(list, what, winid)
    local res
    what = what or { items = 1 }
    if list == "c" then
        res = fn.getqflist(what)
    else
        res = fn.getloclist(winid or ".", what)
    end

    if res.items then
        for i, v in ipairs(res.items) do
            v.idx = i
        end
    end

    return res
end

--- Returns the window id of the location list if it exists for a window
function M.location_list(winid)
    local t = fn.getloclist(winid, { winid = 1 })

    if t.winid ~= 0 then
        return t.winid
    else
        return nil
    end
end

function M.get_list_win(list)
    list = M.fix_list(list)
    local tabnr = fn.tabpagenr()
    if list == "c" then
        local w = vim.tbl_filter(function(t)
            return t.tabnr == tabnr and t.quickfix == 1 and t.loclist == 0
        end, fn.getwininfo())[1]
        if w then
            return w.winid
        else
            return 0
        end
    else
        return vim.fn.getloclist(0, { winid = 1 }).winid or 0
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

---@type QfList
local cache = {}

---@return Item[]
function M.sorted_list_items(list)
    local res = M.get_list(list, { items = 1, changedtick = 1 })
    local cached = cache[list]
    if cached and cached.changedtick == res.changedtick then
        return cached.items
    end

    local t = {}

    for i, v in ipairs(res.items) do
        if is_valid(v) then
            v.idx = i
            t[#t + 1] = v
        end
    end

    table.sort(t, function(a, b)
        if a.bufnr ~= b.bufnr then
            return a.bufnr < b.bufnr
        end

        if a.lnum ~= b.lnum then
            return a.lnum < b.lnum
        end

        return (a.col or 0) < (b.col or 0)
    end)

    cache[list] = { items = t, changedtick = res.changedtick }

    return t
end

function M.valid_list_items(list)
    local items = M.get_list(list).items
    local t = {}

    for i, v in ipairs(items) do
        if is_valid(v) then
            v.idx = i
            t[#t + 1] = v
        end
    end

    return t
end

---@return number
function M.get_height(list, config)
    local opts = config[list]

    if opts.auto_resize == false then
        return opts.max_height
    end

    local size = M.get_list(list, { size = 1 }).size

    return math.max(math.min(size, opts.max_height), opts.min_height)
end

---@class Tally
---@field error integer
---@field warn integer
---@field info integer
---@field hint integer
---@field text integer

---comment
---@param items Item[]
---@return Tally
function M.tally(items)
    local error = 0
    local warn = 0
    local information = 0
    local hint = 0
    local text = 0

    local sevs = {}

    for _, v in ipairs(items) do
        sevs[v.type] = (sevs[v.type] or 0) + 1
        if v.type == "E" then
            error = error + 1
        elseif v.type == "W" then
            warn = warn + 1
        elseif v.type == "I" then
            information = information + 1
        elseif v.type == "N" then
            hint = hint + 1
        else
            text = text + 1
        end
    end

    return { error = error, warn = warn, info = information, hint = hint, text = text }
end

---@param tally Tally
function M.tally_str(tally, highlight)
    local d = require("qf").config.signs
    d = {
        error = d.E,
        warn = d.W,
        info = d.I,
        hint = d.N,
        text = d.T,
    }

    local t = {}
    for i, v in pairs(tally) do
        if v > 0 then
            local severity = d[i]
            if highlight then
                t[#t + 1] = "%#" .. severity.hl .. "#" .. severity.sign .. " " .. v
            else
                t[#t + 1] = severity.sign .. " " .. v
            end
        end
    end

    return table.concat(t, " ") .. "%#Normal#"
end

---@class Position
---@field bufnr number
---@field lnum number
---@field col number

---@param a Position
---@param b Position
---@return number
function M.compare_pos(a, b)
    if a.bufnr < b.bufnr then
        return -1
    end
    if a.bufnr > b.bufnr then
        return 1
    end

    if a.lnum < b.lnum then
        return -1
    end
    if a.lnum > b.lnum then
        return 1
    end

    if a.col < b.col then
        return -1
    end
    if a.col > b.col then
        return 1
    end

    return 0
end

--- Returns the cursor position
---@return Position
function M.get_pos()
    local bufnr = fn.bufnr("%")
    local pos = fn.getpos(".")

    return {
        bufnr = bufnr,
        lnum = pos[2],
        col = pos[3],
    }
end

function M.log_error(msg)
    vim.notify("Quickfix: " .. msg, vim.log.levels.ERROR)
end

return M
