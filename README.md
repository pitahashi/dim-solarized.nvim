# dim-solarized.nvim

A softer, more muted take on Solarized Dark.

## Palette
![dim-solarized color palette](docs/palette.svg)

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
