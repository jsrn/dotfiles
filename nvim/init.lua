-- leader must be set before any <leader> mappings or plugins that read it
vim.g.mapleader = " "

-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- set termguicolors to enable highlight groups
vim.opt.termguicolors = true

local Plug = vim.fn['plug#']

vim.call('plug#begin', '~/.local/share/nvim/site/plugged')
Plug('nvim-tree/nvim-tree.lua')
Plug('nvim-lua/plenary.nvim')
Plug('nvim-telescope/telescope.nvim')
-- Plug('nvim-treesitter/nvim-treesitter', { ['do'] = ':TSUpdate'})
Plug('folke/which-key.nvim')
Plug('catppuccin/nvim', { as = 'catppuccin' })
Plug('nvim-lualine/lualine.nvim')

-- LSP
Plug('williamboman/mason.nvim')
Plug('williamboman/mason-lspconfig.nvim')
Plug('neovim/nvim-lspconfig')

-- completion
Plug('hrsh7th/nvim-cmp')
Plug('hrsh7th/cmp-nvim-lsp')

-- git
Plug('tpope/vim-fugitive')
Plug('shumphrey/fugitive-gitlab.vim')
vim.call('plug#end')

require("telescope").setup({
  defaults = {
    sorting_strategy = "ascending",
    layout_config = {
      prompt_position = "top",
    },
  },
})

require("nvim-tree").setup({
  sort_by = "case_sensitive",
  view = {
    width = 30,
  },
  renderer = {
    group_empty = true,
    icons = {
      show = {
        file = true,
        folder = true,
        folder_arrow = false,
        git = false,
      },
      glyphs = {
        default = "•",
        symlink = "→",
        folder = {
          arrow_closed = "▸",
          arrow_open = "▾",
          default = "▸",
          open = "▾",
          empty = "▸",
          empty_open = "▾",
          symlink = "→",
          symlink_open = "→",
        },
      },
    },
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
  vim.keymap.set(mode, lhs, rhs, options)
end

-- set up my keybinds
map("n", "<F5>", ":NvimTreeToggle<cr>", { desc = "Toggle file tree" })
map("n", "<C-p>", ":Telescope find_files<cr>", { desc = "Find files" })
map("n", "<leader>gf", ":Telescope find_files<cr>", { desc = "find files" })
map("n", "<leader>gs", ":Telescope lsp_document_symbols<cr>", { desc = "go to symbol" })
map("n", "<leader>gr", function() require("telescope.builtin").oldfiles({ cwd_only = true }) end, { desc = "recent files" })
map("n", "<leader>gb", ":Git blame<cr>", { desc = "git blame" })
map("n", "<leader>go", ":GBrowse<cr>", { desc = "open in browser" })
map("n", "<leader>gl", ":Telescope current_buffer_fuzzy_find<cr>", { desc = "fuzzy find" })
map("n", "<leader>yf", function()
  local path = vim.fn.expand("%")
  vim.fn.setreg("+", path)
  vim.notify("Yanked: " .. path)
end, { desc = "Yank file path" })
map("n", ",", ":WhichKey<cr>")

vim.wo.number = true

-- pretty
require("catppuccin").setup({
  flavour = "frappe"
});
vim.cmd.colorscheme "catppuccin"

-- which-key
require("which-key").setup({})
require("which-key").register({
  g = { name = "go to / git" },
  y = { name = "yank" },
}, { prefix = "<leader>" })

-- statusline
require("lualine").setup({
  options = {
    theme = "catppuccin",
  },
  sections = {
    lualine_b = {
      {
        "diagnostics",
        symbols = { error = "✖ ", warn = "▲ ", info = "● ", hint = "○ " },
      },
    },
    lualine_x = {},
    lualine_y = {
      function()
        local names = vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({ bufnr = 0 }))
        return #names > 0 and table.concat(names, ", ") or ""
      end,
    },
  },
})

-- other options
vim.wo.colorcolumn = '80'
vim.opt.cursorline = true

-- LSP
vim.lsp.config('*', {
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
})

-- Neovim's LSP client unconditionally echoes every client-level error to the
-- message area (forcing a "Press ENTER" prompt), with no config hook to
-- suppress it. NO_RESULT_CALLBACK_FOUND specifically is a benign race: cmp
-- cancels a completion request when you keep typing, but a slow server
-- (ruby_lsp while indexing) replies anyway after the callback's been
-- dropped. Silence just that one; still log it to the LSP log file.
do
  local lsp_client = require("vim.lsp.client")
  local orig_write_error = lsp_client.write_error
  lsp_client.write_error = function(self, code, err)
    if code == require("vim.lsp.rpc").client_errors.NO_RESULT_CALLBACK_FOUND then
      require("vim.lsp.log").error(self._log_prefix, 'on_error', { code = code, err = err })
      return
    end
    orig_write_error(self, code, err)
  end
end

require("mason").setup()
require("mason-lspconfig").setup({})

-- ruby_lsp is intentionally not installed via Mason: it's resolved via PATH
-- (mise), which correctly picks up the project's own Ruby version and gems.
-- See https://shopify.github.io/ruby-lsp/editors.html#neovim
vim.lsp.enable('ruby_lsp')

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local buf = args.buf
    map("n", "K", vim.lsp.buf.hover, { buffer = buf, desc = "Hover docs" })
    map("n", "gd", vim.lsp.buf.definition, { buffer = buf, desc = "Go to definition" })
    map("n", "gr", vim.lsp.buf.references, { buffer = buf, desc = "Go to references" })
    map("n", "<F2>", vim.lsp.buf.rename, { buffer = buf, desc = "Rename symbol" })
    map("n", "<leader>ca", vim.lsp.buf.code_action, { buffer = buf, desc = "Code action" })
    require("which-key").register({
      c = { name = "code actions" },
    }, { prefix = "<leader>", buffer = buf })
    map("n", "[d", vim.diagnostic.goto_prev, { buffer = buf, desc = "Previous diagnostic" })
    map("n", "]d", vim.diagnostic.goto_next, { buffer = buf, desc = "Next diagnostic" })
  end,
})

-- automatically pop up the full diagnostic message when the cursor rests
-- on a line that has one
vim.o.updatetime = 300
vim.api.nvim_create_autocmd("CursorHold", {
  group = vim.api.nvim_create_augroup("diagnostic-float-on-hold", { clear = true }),
  callback = function()
    if vim.fn.pumvisible() == 0 then
      vim.diagnostic.open_float(nil, { focus = false })
    end
  end,
})

-- completion
local cmp = require("cmp")
cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping.select_next_item(),
    ["<S-Tab>"] = cmp.mapping.select_prev_item(),
  }),
  sources = {
    { name = "nvim_lsp" },
  },
})
