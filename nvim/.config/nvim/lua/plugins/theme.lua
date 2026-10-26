-- Colorscheme is set on macOS only.
-- On Omarchy the system theme drives Neovim's colorscheme, so this file
-- returns nothing there and leaves the base config untouched.
if vim.fn.has("mac") ~= 1 then
  return {}
end

return {
  {
    "nyoom-engineering/oxocarbon.nvim",
    build = false,
    priority = 1000,
    config = function()
      -- oxocarbon renders types/signatures in dim greys; brighten them
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "oxocarbon",
        callback = function()
          local set = vim.api.nvim_set_hl
          set(0, "BlinkCmpLabel", { fg = "#dde1e6" })
          set(0, "BlinkCmpLabelDetail", { fg = "#82cfff" })
          set(0, "BlinkCmpLabelDescription", { fg = "#82cfff" })
          set(0, "LspInlayHint", { fg = "#78a9ff", italic = true })
        end,
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "oxocarbon",
    },
  },
}
