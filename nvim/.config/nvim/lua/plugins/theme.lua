-- Mac only: stowed by install-mac.sh, not by install-omarchy.sh
-- Omarchy manages colorscheme via its own theme system
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
