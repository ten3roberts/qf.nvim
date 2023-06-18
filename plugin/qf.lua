local commands = {
  close = function(list, o)
    require"qf".close(list,o.fargs[1])
  end,
  next = function(list, o)
    require"qf".next(list,o.fargs[1])
  end,
  prev = function(list, o)
    require"qf".prev(list,o.fargs[1])
  end,
  above = function(list, o)
    require"qf".above(list,o.fargs[1])
  end,
  below = function(list, o)
    require"qf".below(list,o.fargs[1])
  end,
  save = function(list, o)
    require"qf".save(list,o.fargs[1])
  end,
  load = function(list, o)
    require"qf".load(list,o.fargs[1])
  end,
}

local methods = { Q = "c", L = "l", V = "visible" }

for method, list in pairs(methods) do
  for name, cmd in pairs(commands) do
    vim.api.nvim_create_user_command(method .. name, function(o)
      (cmd)(list, o)
    end, { nargs = "*" })
  end
end
