# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0] - 2026-10-28

### Added

- Dark colorscheme that keeps Solarized's hue angles with lower lightness and chroma
- Palette computed from CIE LCh (`lua/dim-solarized/palette.lua`)
- Highlight groups for Tree-sitter, LSP, diagnostics, diff, and the 16 `:terminal` colors
- Options `transparent`, `italic_comments`, and `on_highlights`
- `scripts/gen_palette.lua` to regenerate `docs/palette.svg`
- MIT `LICENSE`

[Unreleased]: https://github.com/pitahashi/dim-solarized.nvim/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/pitahashi/dim-solarized.nvim/releases/tag/v0.1.0
