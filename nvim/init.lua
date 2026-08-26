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
Plug('stevearc/aerial.nvim')

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

-- symbol outline sidebar. treesitter is disabled above, so the LSP backend
-- (ruby_lsp) is the only source of symbols
require("aerial").setup({
  backends = { "lsp" },
  layout = {
    default_direction = "left",
    placement = "edge",
    width = 30,
  },
  show_guides = true,
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

-- yank a reference to the symbol under the cursor, e.g. "ClassName" for a
-- class, or "ClassName#method_name" for a method inside one
local SYMBOL_KIND = { CLASS = 5, MODULE = 2, METHOD = 6, FUNCTION = 12, CONSTRUCTOR = 9 }
local CLASS_KINDS = { [SYMBOL_KIND.CLASS] = true, [SYMBOL_KIND.MODULE] = true }
local METHOD_KINDS = { [SYMBOL_KIND.METHOD] = true, [SYMBOL_KIND.FUNCTION] = true, [SYMBOL_KIND.CONSTRUCTOR] = true }

local function in_range(range, line, col)
  local s, e = range.start, range["end"]
  if line < s.line or line > e.line then return false end
  if line == s.line and col < s.character then return false end
  if line == e.line and col > e.character then return false end
  return true
end

local function find_symbol_path(symbols, line, col, ancestors)
  for _, sym in ipairs(symbols or {}) do
    if in_range(sym.range, line, col) then
      local path = vim.deepcopy(ancestors)
      table.insert(path, sym)
      return find_symbol_path(sym.children, line, col, path) or path
    end
  end
  return nil
end

function yank_symbol_reference()
  local bufnr = vim.api.nvim_get_current_buf()
  if #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/documentSymbol" }) == 0 then
    vim.notify("No LSP client supports document symbols", vim.log.levels.WARN)
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line, col = cursor[1] - 1, cursor[2]
  local params = vim.lsp.util.make_position_params(0, "utf-16")

  vim.lsp.buf_request(bufnr, "textDocument/documentSymbol", params, function(err, result)
    if err or not result then
      vim.notify("No symbol under cursor", vim.log.levels.WARN)
      return
    end
    local path = find_symbol_path(result, line, col, {})
    if not path then
      vim.notify("No symbol under cursor", vim.log.levels.WARN)
      return
    end

    local last = path[#path]
    local text = last.name
    if METHOD_KINDS[last.kind] then
      for i = #path - 1, 1, -1 do
        if CLASS_KINDS[path[i].kind] then
          text = path[i].name .. "#" .. last.name
          break
        end
      end
    end

    vim.fn.setreg("+", text)
    vim.notify("Yanked: " .. text)
  end)
end

-- jump to the FactoryBot factory definition for the symbol under the
-- cursor, e.g. cursor on :project in create(:project) -> factory :project
function goto_factory_definition()
  local name = vim.fn.expand("<cword>")
  if name == "" then
    vim.notify("No word under cursor", vim.log.levels.WARN)
    return
  end
  require("telescope.builtin").grep_string({
    search = "factory :" .. name .. "\\b",
    use_regex = true,
    search_dirs = { "spec/factories", "ee/spec/factories" },
    prompt_title = "Factory: " .. name,
  })
end

-- toggle between a source file and its spec, following GitLab's
-- conventions: app/X.rb <-> spec/X_spec.rb, lib/X.rb <-> spec/lib/X_spec.rb
-- (each optionally under an ee/ prefix)
function toggle_spec_file()
  local path = vim.fn.expand("%")
  local ee_prefix, rest = path:match("^(ee/)(.*)$")
  if not ee_prefix then
    ee_prefix, rest = "", path
  end

  local target
  local body = rest:match("^spec/lib/(.*)_spec%.rb$")
  if body then
    target = ee_prefix .. "lib/" .. body .. ".rb"
  else
    body = rest:match("^spec/(.*)_spec%.rb$")
    if body then
      target = ee_prefix .. "app/" .. body .. ".rb"
    else
      body = rest:match("^lib/(.*)%.rb$")
      if body then
        target = ee_prefix .. "spec/lib/" .. body .. "_spec.rb"
      else
        body = rest:match("^app/(.*)%.rb$")
        if body then
          target = ee_prefix .. "spec/" .. body .. "_spec.rb"
        end
      end
    end
  end

  if not target then
    vim.notify("Don't know the spec convention for this path", vim.log.levels.WARN)
    return
  end

  if vim.fn.filereadable(target) == 1 then
    vim.cmd.edit(target)
  else
    vim.notify("No matching file found: " .. target, vim.log.levels.WARN)
  end
end

-- set up my keybinds
map("n", "<F5>", ":NvimTreeToggle<cr>", { desc = "Toggle file tree" })
map("n", "<F6>", ":AerialToggle<cr>", { desc = "Toggle symbol outline" })
map("n", "<C-p>", ":Telescope find_files<cr>", { desc = "Find files" })
map("n", "<leader>gf", ":Telescope find_files<cr>", { desc = "find files" })
map("n", "<leader>gs", ":Telescope lsp_document_symbols<cr>", { desc = "go to symbol" })
map("n", "<leader>gr", function() require("telescope.builtin").oldfiles({ cwd_only = true }) end, { desc = "recent files" })
map("n", "<leader>gb", ":Git blame<cr>", { desc = "git blame" })
map("n", "<leader>go", ":GBrowse<cr>", { desc = "open in browser" })
map("n", "<leader>gl", ":Telescope current_buffer_fuzzy_find<cr>", { desc = "fuzzy find" })
map("n", "<leader>gF", goto_factory_definition, { desc = "go to factory definition" })
map("n", "<leader>gS", toggle_spec_file, { desc = "toggle spec/source file" })
map("n", "<leader>yf", function()
  local path = vim.fn.expand("%")
  vim.fn.setreg("+", path)
  vim.notify("Yanked: " .. path)
end, { desc = "Yank file path" })
map("n", "<leader>ys", yank_symbol_reference, { desc = "Yank symbol reference" })
map("n", ",", ":WhichKey<cr>")

map("n", "<leader>wv", ":vsplit<cr>", { desc = "split vertically" })

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
  w = { name = "window" },
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
