-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true

local Plug = vim.fn['plug#']

vim.call('plug#begin', '~/.local/share/nvim/site/plugged')
Plug('nvim-tree/nvim-tree.lua')
Plug('nvim-lua/plenary.nvim')
Plug('nvim-telescope/telescope.nvim', { tag = '0.1.2' })
Plug('nvim-treesitter/nvim-treesitter', { ['do'] = ':TSUpdate'})

Plug('autozimu/LanguageClient-neovim', { branch = 'next', ['do'] = 'bash install.sh' })
Plug('catppuccin/nvim', { as = 'catppuccin' })
-- Plug('tanvirtin/monokai.nvim')
vim.call('plug#end')

-- empty setup using defaults
require("nvim-tree").setup()

-- OR setup with some options
require("nvim-tree").setup({
  sort_by = "case_sensitive",
  view = {
    width = 30,
  },
  renderer = {
    group_empty = true
  },
  filters = {
    dotfiles = true,
  },
})

function map(mode, lhs, rhs, opts)
  local options = { noremap = true }
  if opts then
      options = vim.tbl_extend("force", options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

-- initialise LSP
vim.cmd('source ~/.config/nvim/lsp.vim')

-- set up my keybinds
map("n", "<F5>", ":NvimTreeToggle<cr>")
map("n", "<C-p>", ":Telescope find_files<cr>")
map("n", "<F6>", "<Plug>(lcn-menu)")

vim.wo.number = true

require("catppuccin").setup({
  flavour = "frappe"
});
vim.cmd.colorscheme "catppuccin"
