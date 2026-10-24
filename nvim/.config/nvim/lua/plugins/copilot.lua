return {
  {
    "zbirenbaum/copilot.lua",
    build = ":Copilot auth",
    event = "InsertEnter",
    opts = function(_, opts)
      opts.suggestion = vim.tbl_deep_extend("force", opts.suggestion or {}, {
        auto_trigger = true,
        hide_during_completion = vim.g.ai_cmp or false,
        keymap = {
          accept = false,
          next = "<M-]>",
          prev = "<M-[>",
        },
      })
      opts.panel = { enabled = false }
      opts.filetypes = {
        markdown = true,
        help = true,
      }

      LazyVim.cmp.actions.ai_accept = function()
        if require("copilot.suggestion").is_visible() then
          LazyVim.create_undo()
          require("copilot.suggestion").accept()
          return true
        end
      end
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      opts.keymap = opts.keymap or {}
      opts.keymap["<Tab>"] = {
        LazyVim.cmp.map({ "snippet_forward", "ai_accept" }),
        "fallback",
      }
      opts.keymap["<C-Space>"] = { "show" }
    end,
  },
}
