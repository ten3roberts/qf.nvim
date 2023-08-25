return require("telescope").register_extension({
  setup = function()
    -- access extension config and user config
  end,
  exports = {
    list = require("qf.telescope").list,
  },
})
