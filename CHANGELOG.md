# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.1] - 2026-10-30

### Added

- `fg_subtle` palette color for line numbers, sign and fold columns, and inactive
  window bars.
- Color-role design notes, editing samples, and regression checks for text
  contrast, surface separation, and syntax roles.
- Rendered-color tests for overlapping Lua Tree-sitter and LSP semantic tokens,
  characterwise, linewise, and blockwise Visual selections, and deselection.
  CI uses a deterministic LSP fixture; `--real-lsp` enables an optional LuaLS check.

### Changed

- Use neutral text for routine variables, parameters, and properties, reserving
  blue for callable names. Built-in variables use italics; delimiters and Markdown
  list markers use secondary text instead of red.
- Give Visual selections a lighter, low-chroma background and an explicit
  `fg_bright` foreground so selected comments and syntax remain readable.
  `VisualNOS` and `QuickFixLine` use the same foreground and background.
- Use the CursorLine background and underlines for LSP document references;
  write references also use bold.
- Lower the supported Neovim version from 0.12.5 to 0.9.5 and expand CI to cover
  0.9.5, 0.10.4, and 0.11.5 alongside 0.12.5, stable, and nightly.
- Clarify that text and accents are lighter than original Solarized, document
  selection and ANSI color tradeoffs, and regenerate the palette chart.

### Fixed

- Generic LSP variable tokens no longer override more specific Tree-sitter
  captures, preserving function colors when semantic tokens overlap them.
- LSP `readonly` variables and properties retain their neutral role instead of
  being colored as constants.

## [0.1.0] - 2026-10-28

### Added

- Dark Solarized-based colorscheme with a dim navy background and lower lightness and chroma
- Palette computed from CIE LCh (`lua/dim-solarized/palette.lua`)
- Highlight groups for Tree-sitter, LSP, diagnostics, diff, and the 16 `:terminal` colors
- More Tree-sitter variety: italic parameters, distinct colors for built-in variables, built-in types, attributes, and modules, orange string escapes and regexps, and a different color for each Markdown heading level
- LSP semantic token types, plus the `defaultLibrary`, `readonly`, and `deprecated` modifiers, mapped to the matching Tree-sitter groups
- Options `transparent`, `italic_comments`, `on_colors`, and `on_highlights` (which also receives the built-in groups)
- `scripts/gen_palette.lua` to regenerate `docs/palette.svg`
- Selection and diff backgrounds tuned so body text and accents keep at least 4.5:1 contrast on them; comments and secondary text reach about 5.2:1 against the background
- Tests (`nvim -l tests/run.lua`) covering palette contrast, every generated highlight group, options, and loading behavior, run on GitHub Actions with Neovim v0.12.5, stable, and nightly
- Help file `doc/dim-solarized.txt`, available with `:help dim-solarized`
- MIT `LICENSE` that includes the Solarized license notice (Copyright (c) 2011 Ethan Schoonover)
- Requires Neovim 0.12.5 or later

### Fixed

- Modifying the palette inside a callback no longer affects later loads
- Bright `:terminal` colors now reuse the accents instead of mapping to foreground shades
- `DiagnosticDeprecated`, `DiagnosticUnderlineOk`, `OkMsg`, and the float and popup shadow groups no longer fall back to Neovim's default colors
- A non-function `on_highlights` value no longer raises an error while loading

[Unreleased]: https://github.com/pitahashi/dim-solarized.nvim/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/pitahashi/dim-solarized.nvim/releases/tag/v0.1.1
[0.1.0]: https://github.com/pitahashi/dim-solarized.nvim/releases/tag/v0.1.0
