-- Port of Protesilaos Stavrou's Modus and Standard themes for Emacs. Both
-- families share Modus's semantic palette (keyword, fnname, bg-region, …),
-- so one builder maps it onto Neovim groups the way Modus maps it onto
-- Emacs faces, with upstream's defaults: no bold or italic constructs.
-- Copyright (C) 2019-2026 Free Software Foundation, Inc.; GPL-3.0-or-later,
-- see docs/modus-LICENSE.
local M = {}

M.palettes = require('config.modus_palettes')

-- Colorscheme names, in the order upstream lists them.
M.themes = {
  'modus-operandi', 'modus-operandi-tinted', 'modus-operandi-deuteranopia',
  'modus-operandi-tritanopia', 'modus-vivendi', 'modus-vivendi-tinted',
  'modus-vivendi-deuteranopia', 'modus-vivendi-tritanopia',
  'standard-light', 'standard-light-tinted', 'standard-dark',
  'standard-dark-tinted', 'standard-adwaita', 'standard-wombat',
}

-- Palette -> highlight groups. Pure, so tests can sweep every theme.
function M.highlights(p)
  local groups = {
    Normal = { fg = p.fg_main, bg = p.bg_main },
    NormalNC = { link = 'Normal' },
    NormalFloat = { fg = p.fg_main, bg = p.bg_popup },
    FloatBorder = { fg = p.border, bg = p.bg_popup },
    FloatTitle = { fg = p.fg_prompt, bg = p.bg_popup, bold = true },
    FloatFooter = { fg = p.fg_dim, bg = p.bg_popup },
    WinSeparator = { fg = p.border, bg = p.bg_main },
    -- Emacs draws nothing past the end of a buffer.
    EndOfBuffer = { fg = p.bg_main },
    NonText = { fg = p.fg_dim },
    Whitespace = { fg = p.fg_space },
    SpecialKey = { link = 'NonText' },
    Conceal = { fg = p.fg_dim },
    Cursor = { fg = p.bg_main, bg = p.cursor },
    lCursor = { link = 'Cursor' },
    CursorIM = { link = 'Cursor' },
    TermCursor = { link = 'Cursor' },
    CursorLine = { bg = p.bg_hl_line },
    CursorColumn = { link = 'CursorLine' },
    ColorColumn = { bg = p.bg_dim },
    -- The gutter sits on the canvas; Emacs's fringe and number strips
    -- would read as a separate panel.
    LineNr = { fg = p.fg_line_number_inactive },
    CursorLineNr = { fg = p.fg_line_number_active, bold = true },
    SignColumn = {},
    CursorLineSign = { link = 'SignColumn' },
    FoldColumn = { fg = p.fg_dim },
    Folded = { fg = p.fg_dim, bg = p.bg_dim },
    StatusLine = { fg = p.fg_mode_line_active, bg = p.bg_mode_line_active },
    StatusLineNC = { fg = p.fg_mode_line_inactive, bg = p.bg_mode_line_inactive },
    TabLine = { fg = p.fg_dim, bg = p.bg_tab_other },
    TabLineSel = { fg = p.fg_main, bg = p.bg_tab_current, bold = true },
    TabLineFill = { bg = p.bg_tab_bar },
    WinBar = { fg = p.fg_main, bg = p.bg_dim },
    WinBarNC = { fg = p.fg_dim, bg = p.bg_dim },
    Visual = { fg = p.fg_region, bg = p.bg_region },
    VisualNOS = { bg = p.bg_hover_secondary },
    Search = { fg = p.fg_search_lazy, bg = p.bg_search_lazy },
    IncSearch = { fg = p.fg_search_current, bg = p.bg_search_current },
    CurSearch = { link = 'IncSearch' },
    Substitute = { fg = p.fg_search_replace, bg = p.bg_search_replace },
    MatchParen = {
      fg = p.fg_paren_match, bg = p.bg_paren_match,
      sp = p.underline_paren_match, underline = p.underline_paren_match ~= 'NONE',
    },
    QuickFixLine = { bg = p.bg_completion },
    Pmenu = { link = 'NormalFloat' },
    PmenuSel = { fg = p.fg_main, bg = p.bg_completion },
    PmenuKind = { fg = p.docstring, bg = p.bg_popup },
    PmenuKindSel = { fg = p.docstring, bg = p.bg_completion },
    PmenuExtra = { fg = p.docstring, bg = p.bg_popup },
    PmenuExtraSel = { fg = p.docstring, bg = p.bg_completion },
    PmenuMatch = { fg = p.fg_completion_match_0, bg = p.bg_popup },
    PmenuMatchSel = { fg = p.fg_completion_match_0, bg = p.bg_completion },
    PmenuSbar = { bg = p.bg_popup },
    PmenuThumb = { bg = p.fg_dim },
    PmenuBorder = { link = 'FloatBorder' },
    WildMenu = { link = 'PmenuSel' },
    Directory = { fg = p.accent_0 },
    Title = { fg = p.fg_heading_1, bold = true },
    Question = { fg = p.fg_prompt },
    MoreMsg = { fg = p.info },
    ModeMsg = { fg = p.fg_main },
    ErrorMsg = { fg = p.err },
    WarningMsg = { fg = p.warning },

    -- Legacy syntax also supplies the statusline's mode badge accents.
    Comment = { fg = p.comment },
    Constant = { fg = p.constant },
    String = { fg = p.string },
    Character = { link = 'String' },
    Number = { fg = p.number },
    Boolean = { link = 'Constant' },
    Float = { link = 'Number' },
    Identifier = { fg = p.variable },
    Function = { fg = p.fnname },
    Statement = { fg = p.keyword },
    Operator = { fg = p.operator },
    Keyword = { link = 'Statement' },
    PreProc = { fg = p.preprocessor },
    Type = { fg = p.type },
    Special = { fg = p.builtin },
    SpecialChar = { fg = p.rx_backslash },
    Delimiter = { fg = p.delimiter },
    Underlined = { fg = p.fg_link, sp = p.underline_link, underline = true },
    Ignore = { fg = p.fg_dim },
    Error = { fg = p.err },
    Todo = { fg = p.prose_todo, bold = true },

    -- Emacs's tree-sitter modes face declarations but leave most uses
    -- plain: variables and calls each get their own, quieter mapping.
    ['@variable'] = { fg = p.fg_main },
    ['@variable.builtin'] = { link = 'Special' },
    ['@variable.parameter'] = { link = '@variable' },
    ['@variable.member'] = { fg = p.property },
    ['@property'] = { link = '@variable.member' },
    ['@constant'] = { link = 'Constant' },
    ['@constant.builtin'] = { link = 'Constant' },
    ['@constant.macro'] = { link = 'PreProc' },
    ['@module'] = { link = 'Constant' },
    ['@label'] = { link = 'Constant' },
    ['@string'] = { link = 'String' },
    ['@string.documentation'] = { fg = p.docstring },
    ['@string.regexp'] = { link = 'String' },
    ['@string.escape'] = { link = 'SpecialChar' },
    ['@string.special.url'] = { link = 'Underlined' },
    ['@character'] = { link = 'Character' },
    ['@boolean'] = { link = 'Boolean' },
    ['@number'] = { link = 'Number' },
    ['@type'] = { link = 'Type' },
    ['@type.builtin'] = { link = 'Type' },
    ['@attribute'] = { link = 'PreProc' },
    ['@function'] = { link = 'Function' },
    ['@function.call'] = { fg = p.fnname_call },
    ['@function.method'] = { link = 'Function' },
    ['@function.method.call'] = { link = '@function.call' },
    ['@function.builtin'] = { link = 'Special' },
    ['@function.macro'] = { link = 'PreProc' },
    ['@constructor'] = { link = 'Type' },
    -- Lua captures table braces as constructors.
    ['@constructor.lua'] = { link = '@punctuation.bracket' },
    ['@operator'] = { link = 'Operator' },
    ['@keyword'] = { link = 'Keyword' },
    ['@keyword.directive'] = { link = 'PreProc' },
    ['@punctuation'] = { link = 'Delimiter' },
    ['@punctuation.bracket'] = { fg = p.bracket },
    ['@punctuation.delimiter'] = { link = 'Delimiter' },
    ['@punctuation.special'] = { fg = p.punctuation },
    ['@comment'] = { link = 'Comment' },
    ['@comment.documentation'] = { link = '@string.documentation' },
    ['@comment.error'] = { fg = p.err },
    ['@comment.warning'] = { fg = p.warning },
    ['@comment.todo'] = { link = 'Todo' },
    ['@comment.note'] = { fg = p.info },
    ['@markup.strong'] = { bold = true },
    ['@markup.italic'] = { italic = true },
    ['@markup.strikethrough'] = { strikethrough = true },
    ['@markup.underline'] = { underline = true },
    ['@markup.heading'] = { link = 'Title' },
    ['@markup.quote'] = { fg = p.docstring },
    ['@markup.math'] = { link = 'Type' },
    ['@markup.link'] = { link = 'Underlined' },
    ['@markup.link.label'] = { fg = p.fg_link },
    ['@markup.link.url'] = { link = 'Underlined' },
    ['@markup.raw'] = { fg = p.fg_prose_code, bg = p.bg_prose_code },
    ['@markup.list'] = { fg = p.fg_dim },
    ['@markup.list.checked'] = { fg = p.prose_done },
    ['@markup.list.unchecked'] = { fg = p.prose_todo },
    ['@tag'] = { link = 'Function' },
    ['@tag.attribute'] = { link = 'Identifier' },
    ['@tag.delimiter'] = { link = 'Delimiter' },

    -- LSP semantic tokens take precedence over Tree-sitter; declaration
    -- modifiers restore the declaration faces (added below).
    ['@lsp.type.function'] = { link = '@function.call' },
    ['@lsp.type.method'] = { link = '@function.method.call' },
    ['@lsp.type.variable'] = { link = '@variable' },
    ['@lsp.type.parameter'] = { link = '@variable.parameter' },
    ['@lsp.type.property'] = { link = '@property' },
    ['@lsp.type.enumMember'] = { link = 'Constant' },
    ['@lsp.type.namespace'] = { link = '@module' },
    ['@lsp.type.decorator'] = { link = 'PreProc' },
    ['@lsp.type.macro'] = { link = 'PreProc' },
    ['@lsp.type.modifier'] = { link = 'Keyword' },
    ['@lsp.type.regexp'] = { link = '@string.regexp' },
    ['@lsp.typemod.variable.declaration'] = { link = 'Identifier' },
    ['@lsp.typemod.variable.definition'] = { link = 'Identifier' },
    ['@lsp.typemod.parameter.declaration'] = { link = 'Identifier' },

    -- Diff buffers color whole lines, like Emacs's diff-mode; diff mode
    -- keeps syntax colors and paints only the backgrounds.
    DiffAdd = { bg = p.bg_added },
    DiffChange = { bg = p.bg_changed },
    DiffText = { bg = p.bg_changed_refine },
    DiffTextAdd = { bg = p.bg_added_refine },
    DiffDelete = { fg = p.fg_removed, bg = p.bg_removed },
    Added = { fg = p.fg_added },
    Changed = { fg = p.fg_changed },
    Removed = { fg = p.fg_removed },
    diffAdded = { fg = p.fg_added, bg = p.bg_added },
    diffChanged = { fg = p.fg_changed, bg = p.bg_changed },
    diffRemoved = { fg = p.fg_removed, bg = p.bg_removed },
    ['@diff.plus'] = { link = 'diffAdded' },
    ['@diff.delta'] = { link = 'diffChanged' },
    ['@diff.minus'] = { link = 'diffRemoved' },
    diffLine = { bg = p.bg_inactive },
    diffSubname = { link = 'diffLine' },
    diffFile = { bold = true },
    diffIndexLine = { link = 'diffFile' },
    diffNewFile = { link = 'diffFile' },
    diffOldFile = { link = 'diffFile' },

    -- eglot underlines highlighted symbols rather than filling them.
    LspReferenceText = { sp = p.border, underline = true },
    LspReferenceRead = { link = 'LspReferenceText' },
    LspReferenceWrite = { link = 'LspReferenceText' },
    LspReferenceTarget = { link = 'LspReferenceText' },
    LspSignatureActiveParameter = { fg = p.fnname, bold = true },
    LspInlayHint = { fg = p.fg_dim },
    SnippetTabstop = { fg = p.fg_main, bg = p.bg_hover },
    SpellBad = { sp = p.underline_err, undercurl = true },
    SpellCap = { sp = p.underline_warning, undercurl = true },
    SpellLocal = { sp = p.underline_note, undercurl = true },
    SpellRare = { sp = p.underline_note, undercurl = true },
    DiagnosticDeprecated = { sp = p.fg_dim, strikethrough = true },
    DiagnosticUnnecessary = { sp = p.underline_note, undercurl = true },

    -- Plugins share the same surfaces and semantic accents.
    FzfLuaNormal = { link = 'NormalFloat' },
    FzfLuaBorder = { link = 'FloatBorder' },
    FzfLuaTitle = { link = 'FloatTitle' },
    FzfLuaCursorLine = { link = 'PmenuSel' },
    FzfLuaPreviewCursorLine = { link = 'CursorLine' },
    FzfLuaDirPart = { fg = p.fg_dim },
    FzfLuaHeaderBind = { fg = p.keybind },
    FzfLuaHeaderText = { fg = p.fg_dim },
    FzfLuaPathColNr = { fg = p.fg_dim },
    FzfLuaPathLineNr = { fg = p.fg_dim },
    FzfLuaLivePrompt = { fg = p.fg_prompt },
    FzfLuaLiveSym = { fg = p.fg_completion_match_0 },
    FzfLuaBufNr = { fg = p.fg_dim },
    FzfLuaBufFlagCur = { fg = p.accent_0 },
    FzfLuaBufFlagAlt = { fg = p.accent_1 },
    FzfLuaTabTitle = { fg = p.accent_0, bold = true },
    FzfLuaTabMarker = { fg = p.accent_1, bold = true },
    FzfLuaFzfMatch = { fg = p.fg_completion_match_0 },
    FzfLuaFzfPrompt = { fg = p.fg_prompt },
    FzfLuaFzfPointer = { fg = p.fg_prompt },
    MiniClueDescGroup = { fg = p.type },
    MiniClueNextKey = { fg = p.keybind, bold = true },
    MiniClueNextKeyWithPostkeys = { fg = p.err, bold = true },
    MiniIndentscopeSymbol = { fg = p.border },
    -- diff-hl's solid fringe bars become the sign glyph's color.
    MiniDiffSignAdd = { fg = p.bg_added_fringe },
    MiniDiffSignChange = { fg = p.bg_changed_fringe },
    MiniDiffSignDelete = { fg = p.bg_removed_fringe },
    MiniDiffOverAdd = { bg = p.bg_added },
    MiniDiffOverChange = { bg = p.bg_removed_refine },
    MiniDiffOverChangeBuf = { bg = p.bg_added_refine },
    MiniDiffOverContext = { bg = p.bg_removed },
    MiniDiffOverContextBuf = { bg = p.bg_added },
    MiniDiffOverDelete = { fg = p.fg_removed, bg = p.bg_removed },
    TreesitterContext = { bg = p.bg_dim },
    TreesitterContextLineNumber = { fg = p.fg_dim, bg = p.bg_dim },
    TreesitterContextBottom = { sp = p.border, underline = true },
    FlashBackdrop = { fg = p.fg_dim },
    FlashMatch = { link = 'Search' },
    FlashCurrent = { link = 'IncSearch' },
    FlashLabel = { fg = p.fg_search_replace, bg = p.bg_search_replace, bold = true },
    NvimTreeNormal = { link = 'Normal' },
    NvimTreeNormalNC = { link = 'Normal' },
    NvimTreeCursorLine = { link = 'CursorLine' },
    NvimTreeRootFolder = { fg = p.accent_0, bold = true },
    NvimTreeFolderIcon = { link = 'Directory' },
    NvimTreeIndentMarker = { fg = p.border },
    NvimTreeGitNewIcon = { fg = p.fg_added },
    NvimTreeGitDirtyIcon = { fg = p.fg_changed },
    NvimTreeGitDeletedIcon = { fg = p.fg_removed },
    NvimTreeGitStagedIcon = { fg = p.info },
    NvimTreeGitRenamedIcon = { fg = p.accent_1 },
    NvimTreeGitMergeIcon = { fg = p.warning },
    NvimTreeModifiedIcon = { fg = p.fg_changed },
    NvimTreeWindowPicker = { fg = p.bg_main, bg = p.keybind, bold = true },
  }

  for i = 1, 6 do
    groups['@markup.heading.' .. i] = { fg = p['fg_heading_' .. i], bold = true }
  end

  for _, kind in ipairs({ 'function', 'method' }) do
    for _, modifier in ipairs({ 'declaration', 'definition' }) do
      groups['@lsp.typemod.' .. kind .. '.' .. modifier] = { link = 'Function' }
    end
    groups['@lsp.typemod.' .. kind .. '.defaultLibrary'] = { link = '@function.builtin' }
  end

  -- Emacs has three severities; hints and successes take the note color.
  for severity, colors in pairs({
    Error = { p.err, p.underline_err },
    Warn = { p.warning, p.underline_warning },
    Info = { p.info, p.underline_note },
    Hint = { p.info, p.underline_note },
    Ok = { p.info, p.underline_note },
  }) do
    groups['Diagnostic' .. severity] = { fg = colors[1] }
    groups['DiagnosticUnderline' .. severity] = { sp = colors[2], undercurl = true }
  end

  return groups
end

-- Terminal buffers take the palette's ANSI mappings, zero-based as
-- Neovim indexes them.
function M.terminal(p)
  local colors = {}
  for _, bright in ipairs({ '', '_bright' }) do
    for _, name in ipairs({
      'black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white',
    }) do
      colors[#colors + 1] = p['fg_term_' .. name .. bright]
    end
  end
  return colors
end

function M.apply(name)
  local p = assert(M.palettes[name], 'unknown theme ' .. name)
  vim.o.termguicolors = true
  -- With colors_name still set, changing 'background' would reload the
  -- previous scheme over this one.
  vim.g.colors_name = nil
  vim.o.background = p.background
  vim.cmd('highlight clear')
  vim.g.colors_name = name

  for group, attributes in pairs(M.highlights(p)) do
    vim.api.nvim_set_hl(0, group, attributes)
  end
  for i, color in ipairs(M.terminal(p)) do
    vim.g['terminal_color_' .. (i - 1)] = color
  end
end

return M
