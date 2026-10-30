# dim-solarized.nvim

A softer, more muted take on Solarized Dark, with VSCode Dark+ inspired syntax roles.

## Palette
![dim-solarized color palette](docs/palette.svg)

## Syntax colors

| Role | Color |
| --- | --- |
| Variables, parameters, properties | Pale blue |
| Functions, methods | Yellow |
| Types, classes, namespaces | Cyan |
| Strings | Orange |
| Numbers | Green |
| Declaration keywords, booleans, constants | Blue |
| Control flow (`if`, `return`, `for`, etc.) | Magenta |
| Comments, punctuation | Muted foregrounds |

Tree-sitter and LSP share role colors. Generic semantic variable/keyword tokens
preserve more specific syntax captures, including callable names and control flow.
Without a syntax capture, these generic tokens inherit the normal foreground.
The palette keeps Solarized hues; the role mapping follows
[VSCode Dark+](https://github.com/microsoft/vscode/blob/main/extensions/theme-defaults/themes/dark_plus.json).

## Requirements

- Neovim (tested on 0.9.5, 0.10.4, 0.11.5, and 0.12.5)
- True color support (`vim.o.termguicolors = true`)

## Installation

lazy.nvim

```lua
{
  "pitahashi/dim-solarized.nvim",
  lazy = false,
  priority = 1000,
  opts = {},
  config = function(_, opts)
    require("dim-solarized").setup(opts)
    vim.cmd.colorscheme("dim-solarized")
  end,
}
```

## Documentation
`:help dim-solarized`

## Default Configuration
```lua
require("dim-solarized").setup({
	transparent = false,
	italic_comments = true,
	on_colors = function(c) end,
	on_highlights = function(c, groups)
		return {}
	end,
})
```

## Configuration Example
```lua
require("dim-solarized").setup({
	on_colors = function(c)
		c.bg = "#001f27"
	end,
	on_highlights = function(c)
		return {
			CursorLine = { bg = c.bg_sel },
			["@comment.todo"] = { fg = c.orange, bold = true },
		}
	end,
})
```

## AI Assistance
This project was developed with assistance from Claude Code and Codex.

## Acknowledgements
The color design is based on Solarized by Ethan Schoonover (MIT License).
This is an independent project and is not affiliated with the original. Solarized's license notice is included in LICENSE.
