-- TypeScript/JavaScript configuration
-- LazyVim's lang.typescript extra uses vtsls (not tsserver).
-- This overrides vtsls settings for inlay hints and import preferences.

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- Configure vtsls (LazyVim's TypeScript LSP) for ESM support and inlay hints
      opts.servers.vtsls = vim.tbl_deep_extend("force", opts.servers.vtsls or {}, {
        settings = {
          typescript = {
            inlayHints = {
              parameterNames = { enabled = "all" },
              parameterTypes = { enabled = true },
              variableTypes = { enabled = true },
              propertyDeclarationTypes = { enabled = true },
              functionLikeReturnTypes = { enabled = true },
              enumMemberValues = { enabled = true },
            },
            preferences = {
              importModuleSpecifier = "non-relative",
              importModuleSpecifierEnding = "minimal",
            },
          },
          javascript = {
            inlayHints = {
              parameterNames = { enabled = "all" },
              parameterTypes = { enabled = true },
              variableTypes = { enabled = true },
              propertyDeclarationTypes = { enabled = true },
              functionLikeReturnTypes = { enabled = true },
              enumMemberValues = { enabled = true },
            },
            preferences = {
              importModuleSpecifier = "non-relative",
              importModuleSpecifierEnding = "minimal",
            },
          },
        },
        on_attach = function(client, bufnr)
          -- Disable vtsls formatting (use Prettier instead)
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end,
      })

      return opts
    end,
  },
}
