-- Use oxfmt (resolved from the project's node_modules/.bin) for JS/TS files.
-- Falls back to LSP formatting if oxfmt isn't installed in the project.
local oxfmt_fts = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
}

return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      for _, ft in ipairs(oxfmt_fts) do
        opts.formatters_by_ft[ft] = { "oxfmt", lsp_format = "fallback" }
      end
    end,
  },
}
