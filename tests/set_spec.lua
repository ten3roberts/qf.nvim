describe("set qf list", function()
  it("echo", function()
    local async = require("plenary.async")
    async.util.block_on(function()
      local recipe = require("recipe")
      local logger = require("recipe.logger")

      local task = recipe.insert("test", {
        cmd = "cat tests/file.txt",
      })

      logger.info("Spawning task")
      task:spawn()

      logger.info("Joining")
      local _, result = task:join()
      assert.equals(result, 0)
      local output = trim(task:get_output())

      assert.are.same(output, {
        "Lorem ipsum dolor sit amet,",
        "qui minim labore adipisicing minim sint cillum sint consectetur cupidatat.",
      })
    end)
  end)
end)
