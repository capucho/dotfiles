-- every spec file under the "plugins" directory will be loaded automatically by lazy.nvim
--
-- In your plugin files, you can:
-- * add extra plugins
-- * disable/enabled LazyVim plugins
-- * override the configuration of LazyVim plugins
return {
  -- ident blankline
  { "lukas-reineke/indent-blankline.nvim", enabled = false },

  -- disable noice in favour of snacks.nvim
  { "folke/noice.nvim", enabled = false },
}
