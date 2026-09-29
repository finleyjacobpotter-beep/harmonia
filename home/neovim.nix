{ pkgs, palette, ... }:
let
  p = palette;
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;

    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      nvim-web-devicons
      lualine-nvim
      gitsigns-nvim
      telescope-nvim
      plenary-nvim
      which-key-nvim
      indent-blankline-nvim
    ];

    initLua = ''
      vim.g.mapleader = " "
      local o = vim.opt
      o.number = true
      o.relativenumber = true
      o.cursorline = true
      o.termguicolors = true
      o.signcolumn = "yes"
      o.expandtab = true
      o.shiftwidth = 2
      o.tabstop = 2
      o.smartindent = true
      o.ignorecase = true
      o.smartcase = true
      o.undofile = true
      o.scrolloff = 6
      o.splitright = true
      o.splitbelow = true
      o.clipboard = "unnamedplus"
      o.fillchars = { eob = " " }

      vim.cmd.colorscheme("miami-wind")

      -- nvim-treesitter's main branch has no `configs` module: highlighting
      -- and indent are turned on per buffer. pcall skips filetypes without
      -- a parser.
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
      require("nvim-web-devicons").setup({ default = true })
      require("gitsigns").setup()
      require("which-key").setup()
      require("ibl").setup({ indent = { char = "│" }, scope = { enabled = true } })

      local mw = require("miami-wind.lualine")
      require("lualine").setup({
        options = {
          theme = mw,
          section_separators = "",
          component_separators = "│",
          globalstatus = true,
        },
      })

      local tb = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", tb.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", tb.live_grep, { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", tb.buffers, { desc = "Buffers" })
      vim.keymap.set("n", "<leader>e", "<cmd>Explore<cr>", { desc = "File explorer" })
      vim.keymap.set("n", "<leader>fh", tb.help_tags, { desc = "Help" })
      vim.keymap.set("n", "<leader>fk", tb.keymaps, { desc = "Keymaps" })

      -- Windows: Ctrl+w h/j/k/l is vim's own and doesn't clash with tmux
      -- (Ctrl+Space prefix) or sway (Super). Leader shortcuts on top:
      vim.keymap.set("n", "<leader>s", "<cmd>split<cr>", { desc = "Split below" })
      vim.keymap.set("n", "<leader>v", "<cmd>vsplit<cr>", { desc = "Split right" })
      vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window" })
      vim.keymap.set("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })
      vim.keymap.set("n", "[b", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
      -- Leave :terminal insert mode with a double Escape
      vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Terminal normal mode" })
    '';
  };

  home.packages = with pkgs; [
    ripgrep
    fd
  ];

  # lualine theme
  xdg.configFile."nvim/lua/miami-wind/lualine.lua".text = ''
    local c = {
      bg = "${p.bgDark}", alt = "${p.surface}", fg = "${p.fg}", dim = "${p.muted}",
      pink = "${p.pink}", cyan = "${p.cyan}", yellow = "${p.yellow}",
      green = "${p.green}", purple = "${p.purple}", red = "${p.redBright}",
    }
    local function mode(color)
      return {
        a = { bg = color, fg = c.bg, gui = "bold" },
        b = { bg = c.alt, fg = color },
        c = { bg = c.bg, fg = c.fg },
      }
    end
    return {
      normal = mode(c.pink),
      insert = mode(c.cyan),
      visual = mode(c.purple),
      replace = mode(c.red),
      command = mode(c.yellow),
      terminal = mode(c.green),
      inactive = {
        a = { bg = c.bg, fg = c.dim },
        b = { bg = c.bg, fg = c.dim },
        c = { bg = c.bg, fg = c.dim },
      },
    }
  '';

  # Colour scheme — a port of the VS Code theme's token colours.
  xdg.configFile."nvim/colors/miami-wind.lua".text = ''
    vim.cmd("highlight clear")
    if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
    vim.o.background = "dark"
    vim.g.colors_name = "miami-wind"

    local c = {
      bg = "${p.bg}", bg_alt = "${p.bgAlt}", bg_dark = "${p.bgDark}",
      surface = "${p.surface}", surface_hi = "${p.surfaceHi}",
      fg = "${p.fg}", fg_dim = "${p.fgDim}", muted = "${p.muted}", overlay = "${p.grey500}",
      white = "${p.white}",
      pink = "${p.pink}", cyan = "${p.cyan}", yellow = "${p.yellow}", purple = "${p.purple}",
      blue = "${p.blue}", green = "${p.green}", red = "${p.red}", orange = "${p.orange}",
      pink_b = "${p.pinkBright}", cyan_b = "${p.cyanBright}", yellow_b = "${p.yellowBright}",
      blue_b = "${p.blueBright}", green_b = "${p.greenBright}", red_b = "${p.redBright}",
      selection = "#4a2d45", -- pink @ 25% over bg (VS Code: #f472b640)
      line = "#282838",      -- fg @ 7% over bg (VS Code: #cdd6f412)
    }

    local groups = {
      -- UI
      Normal = { fg = c.fg, bg = c.bg },
      NormalNC = { fg = c.fg, bg = c.bg },
      NormalFloat = { fg = c.fg, bg = c.bg_alt },
      FloatBorder = { fg = c.pink, bg = c.bg_alt },
      FloatTitle = { fg = c.cyan, bg = c.bg_alt, bold = true },
      Cursor = { fg = c.bg, bg = c.pink },
      CursorLine = { bg = c.line },
      CursorColumn = { bg = c.line },
      ColorColumn = { bg = c.bg_alt },
      CursorLineNr = { fg = c.pink, bold = true },
      LineNr = { fg = c.muted },
      SignColumn = { bg = c.bg },
      FoldColumn = { fg = c.muted, bg = c.bg },
      Folded = { fg = c.fg_dim, bg = c.surface },
      VertSplit = { fg = c.surface },
      WinSeparator = { fg = c.surface },
      StatusLine = { fg = c.fg, bg = c.bg_dark },
      StatusLineNC = { fg = c.muted, bg = c.bg_dark },
      TabLine = { fg = c.muted, bg = c.bg_dark },
      TabLineFill = { bg = c.bg_dark },
      TabLineSel = { fg = c.pink, bg = c.bg, bold = true },
      WinBar = { fg = c.fg_dim, bg = c.bg },
      Visual = { bg = c.selection },
      VisualNOS = { bg = c.selection },
      Search = { fg = c.bg, bg = c.yellow },
      IncSearch = { fg = c.bg, bg = c.pink },
      CurSearch = { fg = c.bg, bg = c.pink },
      Substitute = { fg = c.bg, bg = c.orange },
      MatchParen = { fg = c.pink, bold = true, underline = true },
      Pmenu = { fg = c.fg, bg = c.bg_alt },
      PmenuSel = { fg = c.bg, bg = c.pink },
      PmenuSbar = { bg = c.surface },
      PmenuThumb = { bg = c.surface_hi },
      WildMenu = { fg = c.bg, bg = c.pink },
      NonText = { fg = c.surface_hi },
      Whitespace = { fg = c.surface },
      SpecialKey = { fg = c.surface_hi },
      EndOfBuffer = { fg = c.bg },
      Directory = { fg = c.cyan },
      Title = { fg = c.purple, bold = true },
      Question = { fg = c.cyan },
      MoreMsg = { fg = c.cyan },
      ModeMsg = { fg = c.fg, bold = true },
      ErrorMsg = { fg = c.red_b },
      WarningMsg = { fg = c.yellow_b },
      Conceal = { fg = c.muted },
      SpellBad = { sp = c.red, undercurl = true },
      SpellCap = { sp = c.yellow, undercurl = true },
      SpellRare = { sp = c.purple, undercurl = true },
      SpellLocal = { sp = c.cyan, undercurl = true },
      QuickFixLine = { bg = c.surface },

      -- Syntax (VS Code tokenColors)
      Comment = { fg = c.blue, italic = true },
      Constant = { fg = c.purple },
      String = { fg = c.yellow },
      Character = { fg = c.yellow },
      Number = { fg = c.purple },
      Boolean = { fg = c.purple },
      Float = { fg = c.purple },
      Identifier = { fg = c.fg },
      Function = { fg = c.green },
      Statement = { fg = c.pink },
      Conditional = { fg = c.pink },
      Repeat = { fg = c.pink },
      Label = { fg = c.pink },
      Operator = { fg = c.pink },
      Keyword = { fg = c.pink },
      Exception = { fg = c.pink },
      PreProc = { fg = c.pink },
      Include = { fg = c.pink },
      Define = { fg = c.pink },
      Macro = { fg = c.cyan },
      PreCondit = { fg = c.pink },
      Type = { fg = c.cyan, italic = true },
      StorageClass = { fg = c.pink },
      Structure = { fg = c.cyan },
      Typedef = { fg = c.cyan },
      Special = { fg = c.pink },
      SpecialChar = { fg = c.pink },
      Tag = { fg = c.pink },
      Delimiter = { fg = c.white },
      SpecialComment = { fg = c.pink },
      Debug = { fg = c.orange },
      Underlined = { underline = true },
      Error = { fg = c.red, underline = true },
      Todo = { fg = c.bg, bg = c.yellow, bold = true },

      -- Tree-sitter
      ["@variable"] = { fg = c.fg },
      ["@variable.builtin"] = { fg = c.purple, italic = true },
      ["@variable.parameter"] = { fg = c.orange, italic = true },
      ["@variable.member"] = { fg = c.fg },
      ["@property"] = { fg = c.fg },
      ["@constant"] = { fg = c.purple },
      ["@constant.builtin"] = { fg = c.purple },
      ["@module"] = { fg = c.cyan },
      ["@string"] = { fg = c.yellow },
      ["@string.escape"] = { fg = c.pink },
      ["@string.regexp"] = { fg = c.yellow },
      ["@string.special.url"] = { fg = c.cyan_b, underline = true },
      ["@character"] = { fg = c.yellow },
      ["@number"] = { fg = c.purple },
      ["@boolean"] = { fg = c.purple },
      ["@function"] = { fg = c.green },
      ["@function.call"] = { fg = c.green },
      ["@function.builtin"] = { fg = c.cyan, italic = true },
      ["@function.method"] = { fg = c.green },
      ["@constructor"] = { fg = c.cyan },
      ["@keyword"] = { fg = c.pink },
      ["@keyword.function"] = { fg = c.pink },
      ["@keyword.return"] = { fg = c.pink },
      ["@keyword.operator"] = { fg = c.pink },
      ["@operator"] = { fg = c.pink },
      ["@type"] = { fg = c.cyan, italic = true },
      ["@type.builtin"] = { fg = c.cyan, italic = true },
      ["@attribute"] = { fg = c.green, italic = true },
      ["@tag"] = { fg = c.pink },
      ["@tag.attribute"] = { fg = c.green, italic = true },
      ["@tag.delimiter"] = { fg = c.white },
      ["@punctuation.delimiter"] = { fg = c.white },
      ["@punctuation.bracket"] = { fg = c.white },
      ["@punctuation.special"] = { fg = c.pink },
      ["@comment"] = { link = "Comment" },
      ["@markup.heading"] = { fg = c.purple, bold = true },
      ["@markup.strong"] = { fg = c.orange, bold = true },
      ["@markup.italic"] = { fg = c.yellow, italic = true },
      ["@markup.quote"] = { fg = c.yellow, italic = true },
      ["@markup.link"] = { fg = c.pink },
      ["@markup.link.url"] = { fg = c.cyan_b, underline = true },
      ["@markup.raw"] = { fg = c.green },
      ["@markup.list"] = { fg = c.cyan_b },

      -- Diagnostics
      DiagnosticError = { fg = c.red_b },
      DiagnosticWarn = { fg = c.yellow_b },
      DiagnosticInfo = { fg = c.cyan_b },
      DiagnosticHint = { fg = c.purple },
      DiagnosticOk = { fg = c.green_b },
      DiagnosticUnderlineError = { sp = c.red_b, undercurl = true },
      DiagnosticUnderlineWarn = { sp = c.yellow_b, undercurl = true },
      DiagnosticUnderlineInfo = { sp = c.cyan_b, undercurl = true },
      DiagnosticUnderlineHint = { sp = c.purple, undercurl = true },

      -- Diff / git
      DiffAdd = { bg = "#1f3a36" },
      DiffChange = { bg = "#3a3230" },
      DiffDelete = { bg = "#3d2530" },
      DiffText = { bg = "#5a4636" },
      Added = { fg = c.green },
      Changed = { fg = c.orange },
      Removed = { fg = c.red },
      GitSignsAdd = { fg = c.green },
      GitSignsChange = { fg = c.orange },
      GitSignsDelete = { fg = c.red },

      -- Plugins
      TelescopeBorder = { fg = c.pink, bg = c.bg_alt },
      TelescopeNormal = { fg = c.fg, bg = c.bg_alt },
      TelescopeTitle = { fg = c.bg, bg = c.pink, bold = true },
      TelescopeSelection = { bg = c.surface },
      TelescopeMatching = { fg = c.cyan, bold = true },
      TelescopePromptPrefix = { fg = c.pink },
      IblIndent = { fg = c.surface },
      IblScope = { fg = c.surface_hi },
      WhichKey = { fg = c.pink },
      WhichKeyGroup = { fg = c.cyan },
      WhichKeyDesc = { fg = c.fg },
      WhichKeySeparator = { fg = c.muted },
    }

    for name, spec in pairs(groups) do
      vim.api.nvim_set_hl(0, name, spec)
    end

    local term = {
      ${builtins.concatStringsSep ", " (map (x: ''"${x}"'') p.ansi)}
    }
    for i, col in ipairs(term) do
      vim.g["terminal_color_" .. (i - 1)] = col
    end
  '';
}
