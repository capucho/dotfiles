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
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "oxocarbon",
    },
  },
}
