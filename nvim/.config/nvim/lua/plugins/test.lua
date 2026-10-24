return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "marilari88/neotest-vitest",
    },
    keys = {
      {
        "<leader>tl",
        function()
          require("neotest").run.run_last()
        end,
        desc = "Run Last Test",
      },
      {
        "<leader>tL",
        function()
          require("neotest").run.run_last({ strategy = "dap" })
        end,
        desc = "Debug Last Test",
      },
      {
        "<leader>tw",
        function()
          require("neotest").run.run({ strategy = "watch" })
        end,
        desc = "Run Watch (Vitest)",
      },
      {
        "<leader>to",
        function()
          require("neotest").output.open({ enter = true })
        end,
        desc = "Open Test Output",
      },
      {
        "<leader>tp",
        function()
          require("neotest").output_panel.toggle()
        end,
        desc = "Toggle Output Panel",
      },
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}

      -- Vitest automatically detects ESM modules via package.json "type": "module"
      -- or when using .mjs/.mts extensions
      table.insert(opts.adapters, require("neotest-vitest")({
        filter_dir = function(name, rel_path, root)
          return name ~= "node_modules"
        end,
      }))
    end,
  },
}
