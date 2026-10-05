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

    # On neovim's PATH only: the JSON/YAML commands (nvim/json.lua).
    extraPackages = with pkgs; [
      jq
      yq-go
      prettier
    ];

    initLua = ''
      vim.g.mapleader = " "
      local o = vim.opt
      o.number = true
      o.relativenumber = true
      o.cursorline = true
      o.termguicolors = true
      o.signcolumn = "yes"
      -- Indents follow the system EditorConfig (modules/nixos/editorconfig.nix);
      -- these are the same defaults for buffers without a file.
      o.expandtab = true
      o.shiftwidth = 4
      o.tabstop = 4
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
      require("harmonia.json").setup()
      require("which-key").add({ { "<leader>j", group = "JSON/YAML" } })
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

  xdg.configFile."nvim/lua/harmonia/json.lua".source = ./nvim/json.lua;

  # lualine theme
  xdg.configFile."nvim/lua/miami-wind/lualine.lua".text = ''
    local c = {
      bg = "${p.bgDark}", alt = "${p.surface}", fg = "${p.fg}", dim = "${p.muted}",
      primary = "${p.primary}", secondary = "${p.secondary}", yellow = "${p.yellow}",
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
      normal = mode(c.primary),
      insert = mode(c.secondary),
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
      primary = "${p.primary}", secondary = "${p.secondary}", yellow = "${p.yellow}", purple = "${p.purple}",
      blue = "${p.blue}", green = "${p.green}", red = "${p.red}", orange = "${p.orange}",
      primary_b = "${p.primaryBright}", secondary_b = "${p.secondaryBright}", yellow_b = "${p.yellowBright}",
      blue_b = "${p.blueBright}", green_b = "${p.greenBright}", red_b = "${p.redBright}",
      selection = "${p.selectionSolid}", -- primary @ 25% over bg (VS Code: #f472b640)
      line = "#282838",      -- fg @ 7% over bg (VS Code: #cdd6f412)
    }

    local groups = {
      -- UI
      Normal = { fg = c.fg, bg = c.bg },
      NormalNC = { fg = c.fg, bg = c.bg },
      NormalFloat = { fg = c.fg, bg = c.bg_alt },
      FloatBorder = { fg = c.primary, bg = c.bg_alt },
      FloatTitle = { fg = c.secondary, bg = c.bg_alt, bold = true },
      Cursor = { fg = c.bg, bg = c.primary },
      CursorLine = { bg = c.line },
      CursorColumn = { bg = c.line },
      ColorColumn = { bg = c.bg_alt },
      CursorLineNr = { fg = c.primary, bold = true },
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
      TabLineSel = { fg = c.primary, bg = c.bg, bold = true },
      WinBar = { fg = c.fg_dim, bg = c.bg },
      Visual = { bg = c.selection },
      VisualNOS = { bg = c.selection },
      Search = { fg = c.bg, bg = c.yellow },
      IncSearch = { fg = c.bg, bg = c.primary },
      CurSearch = { fg = c.bg, bg = c.primary },
      Substitute = { fg = c.bg, bg = c.orange },
      MatchParen = { fg = c.primary, bold = true, underline = true },
      Pmenu = { fg = c.fg, bg = c.bg_alt },
      PmenuSel = { fg = c.bg, bg = c.primary },
      PmenuSbar = { bg = c.surface },
      PmenuThumb = { bg = c.surface_hi },
      WildMenu = { fg = c.bg, bg = c.primary },
      NonText = { fg = c.surface_hi },
      Whitespace = { fg = c.surface },
      SpecialKey = { fg = c.surface_hi },
      EndOfBuffer = { fg = c.bg },
      Directory = { fg = c.secondary },
      Title = { fg = c.purple, bold = true },
      Question = { fg = c.secondary },
      MoreMsg = { fg = c.secondary },
      ModeMsg = { fg = c.fg, bold = true },
      ErrorMsg = { fg = c.red_b },
      WarningMsg = { fg = c.yellow_b },
      Conceal = { fg = c.muted },
      SpellBad = { sp = c.red, undercurl = true },
      SpellCap = { sp = c.yellow, undercurl = true },
      SpellRare = { sp = c.purple, undercurl = true },
      SpellLocal = { sp = c.secondary, undercurl = true },
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
      Statement = { fg = c.primary },
      Conditional = { fg = c.primary },
      Repeat = { fg = c.primary },
      Label = { fg = c.primary },
      Operator = { fg = c.primary },
      Keyword = { fg = c.primary },
      Exception = { fg = c.primary },
      PreProc = { fg = c.primary },
      Include = { fg = c.primary },
      Define = { fg = c.primary },
      Macro = { fg = c.secondary },
      PreCondit = { fg = c.primary },
      Type = { fg = c.secondary, italic = true },
      StorageClass = { fg = c.primary },
      Structure = { fg = c.secondary },
      Typedef = { fg = c.secondary },
      Special = { fg = c.primary },
      SpecialChar = { fg = c.primary },
      Tag = { fg = c.primary },
      Delimiter = { fg = c.white },
      SpecialComment = { fg = c.primary },
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
      ["@module"] = { fg = c.secondary },
      ["@string"] = { fg = c.yellow },
      ["@string.escape"] = { fg = c.primary },
      ["@string.regexp"] = { fg = c.yellow },
      ["@string.special.url"] = { fg = c.secondary_b, underline = true },
      ["@character"] = { fg = c.yellow },
      ["@number"] = { fg = c.purple },
      ["@boolean"] = { fg = c.purple },
      ["@function"] = { fg = c.green },
      ["@function.call"] = { fg = c.green },
      ["@function.builtin"] = { fg = c.secondary, italic = true },
      ["@function.method"] = { fg = c.green },
      ["@constructor"] = { fg = c.secondary },
      ["@keyword"] = { fg = c.primary },
      ["@keyword.function"] = { fg = c.primary },
      ["@keyword.return"] = { fg = c.primary },
      ["@keyword.operator"] = { fg = c.primary },
      ["@operator"] = { fg = c.primary },
      ["@type"] = { fg = c.secondary, italic = true },
      ["@type.builtin"] = { fg = c.secondary, italic = true },
      ["@attribute"] = { fg = c.green, italic = true },
      ["@tag"] = { fg = c.primary },
      ["@tag.attribute"] = { fg = c.green, italic = true },
      ["@tag.delimiter"] = { fg = c.white },
      ["@punctuation.delimiter"] = { fg = c.white },
      ["@punctuation.bracket"] = { fg = c.white },
      ["@punctuation.special"] = { fg = c.primary },
      ["@comment"] = { link = "Comment" },
      ["@markup.heading"] = { fg = c.purple, bold = true },
      ["@markup.strong"] = { fg = c.orange, bold = true },
      ["@markup.italic"] = { fg = c.yellow, italic = true },
      ["@markup.quote"] = { fg = c.yellow, italic = true },
      ["@markup.link"] = { fg = c.primary },
      ["@markup.link.url"] = { fg = c.secondary_b, underline = true },
      ["@markup.raw"] = { fg = c.green },
      ["@markup.list"] = { fg = c.secondary_b },

      -- Diagnostics
      DiagnosticError = { fg = c.red_b },
      DiagnosticWarn = { fg = c.yellow_b },
      DiagnosticInfo = { fg = c.secondary_b },
      DiagnosticHint = { fg = c.purple },
      DiagnosticOk = { fg = c.green_b },
      DiagnosticUnderlineError = { sp = c.red_b, undercurl = true },
      DiagnosticUnderlineWarn = { sp = c.yellow_b, undercurl = true },
      DiagnosticUnderlineInfo = { sp = c.secondary_b, undercurl = true },
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
      TelescopeBorder = { fg = c.primary, bg = c.bg_alt },
      TelescopeNormal = { fg = c.fg, bg = c.bg_alt },
      TelescopeTitle = { fg = c.bg, bg = c.primary, bold = true },
      TelescopeSelection = { bg = c.surface },
      TelescopeMatching = { fg = c.secondary, bold = true },
      TelescopePromptPrefix = { fg = c.primary },
      IblIndent = { fg = c.surface },
      IblScope = { fg = c.surface_hi },
      WhichKey = { fg = c.primary },
      WhichKeyGroup = { fg = c.secondary },
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
