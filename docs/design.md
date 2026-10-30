# Color roles and verification

The syntax mapping follows [VSCode Dark+](https://github.com/microsoft/vscode/blob/main/extensions/theme-defaults/themes/dark_plus.json)
and its [base theme](https://github.com/microsoft/vscode/blob/main/extensions/theme-defaults/themes/dark_vs.json),
translated to the existing Solarized accents. The normal background remains
Solarized base03 (`#002b36`); the eight accent colors retain their hue balance.
A pale blue `variable` foreground adds a distinct identifier level at L* 76,
C* 24 with the existing Solarized blue hue. It is lighter and less saturated
than the blue used for declaration keywords, booleans, and constants.

The following before/after table records the earlier UI readability revision
from baseline commit `05fb6e3`. Its syntax rows are historical; the current
syntax roles are described below.

## Changes and measured pairs

Ratios use WCAG relative luminance after conversion to rounded sRGB hex values.
A ratio is about a particular pair of colors, not a color in isolation.

| Pair / role | Before | After | Contrast before → after |
| --- | --- | --- | --- |
| Normal text / Normal background | `#9daeb0` / `#002b36` | unchanged | 6.52 → 6.52 |
| Comment / Normal background | `#8d9aa7` / `#002b36` | unchanged | 5.23 → 5.23 |
| Visual surface / Normal surface | `#163a45` / `#002b36` | `#304148` / `#002b36` | 1.23 → 1.41 |
| Visual surface / CursorLine surface | `#163a45` / `#073642` | `#304148` / `#073642` | 1.07 → 1.22 |
| Normal foreground / Visual surface | `#9daeb0` / `#163a45` | `#9daeb0` / `#304148` | 5.28 → 4.61 |
| Selected comment (effective) | `#8d9aa7` / `#163a45` | `#e0dac7` / `#304148` | 4.24 → 7.61 |
| Selected string (effective) | `#56afa7` / `#163a45` | `#e0dac7` / `#304148` | 4.69 → 7.61 |
| LineNr / Normal background | `#8d9aa7` / `#002b36` | `#84919e` / `#002b36` | 5.23 → 4.66 |
| Variable, property / Normal background | `#6aa5e0` / `#002b36` | `#9daeb0` / `#002b36` | 5.77 → 6.52 |
| Delimiter / Normal background | `#f87b6b` / `#002b36` | `#8d9aa7` / `#002b36` | 5.75 → 5.23 |
| Pmenu / float background | `#9daeb0` / `#01242e` | unchanged | 7.05 → 7.05 |
| PmenuSel | `#e0dac7` / `#163a45` | `#e0dac7` / `#304148` | 8.71 → 7.61 |

The text regression target is at least 4.5:1 for the listed effective text
pairs. Surface ratios are not text accessibility scores: their regression
guards are 1.4 for Visual/Normal, 1.2 for Visual/CursorLine, and a lightness
increase of at least 10 L* from Normal to Visual. Selection chroma falls from
approximately 14 to 8. These thresholds record an intentional increase in
separation.

Simply raising the selection background would leave raw `comment` at 3.70:1
on the new surface. `Visual` and `VisualNOS` therefore explicitly supply
`fg_bright`, overriding selected syntax foregrounds. The tests distinguish
this effective pairing from raw palette combinations. This sacrifices syntax
hues inside selections; it preserves text content and italic/bold cues. Users
who override Visual to remove its foreground must retune the background or
check every syntax foreground themselves. Definition-level contrast checks are
complemented by the actual screen-cell checks described below.

## Syntax and UI hierarchy

| Role | Palette key |
| --- | --- |
| Variables, parameters, properties, tag attributes | `variable` |
| Functions, methods, macros, decorators | `yellow` |
| Types, classes, namespaces, constructors | `cyan` |
| Strings, characters | `orange` |
| Numbers, floats | `green` |
| Declaration keywords, booleans, constants, builtin variables | `blue` |
| Conditionals, loops, return, exceptions, imports | `magenta` |
| String escapes / regular expressions | `yellow` / `red` |

Tree-sitter, traditional syntax, and specific LSP roles agree. Generic semantic
variable and keyword tokens are explicitly empty so they cannot erase more
specific syntax captures. Without an underlying syntax capture they inherit
Normal; a theme alone cannot infer a generic token's more specific role.
Readonly variable modifiers are also empty: ordinary const locals may contain
functions. Readonly properties retain the property color. Built-in types and
variables retain italic cues; deprecated modifiers retain strikethrough.

The seven primary families (variable, function, type, string, number, keyword,
control flow) each have a different color, with a minimum CIE76 distance of 15
in regression tests. This guards against near-duplicate role colors, not all
forms of color-vision deficiency. Delimiters retain secondary text, and comments
retain their muted foreground. Related roles deliberately share a family;
each token does not get an unrelated accent.

`fg_subtle` adds one auxiliary UI level (L* 59.5), below comments/secondary text
(L* 63) and body text (L* 70). It is used on the normal surface, not the lighter
inactive statusline surface, where `fg_dim` keeps at least 4.5:1. Existing palette
keys and setup/callback signatures are retained; `comment` remains independently
overridable. CursorLineNr still uses bold yellow to mark the active line.

LSP references and MiniCursorword now use CursorLine's quieter surface plus an
underline. Write references also use bold. Selection uses a stronger surface
and explicit light text. Search remains blue-backed, with the current match
using dark text on orange. Their text ratios remain 5.80 and 6.96 respectively.
Diagnostic virtual text already passes the text target, so its colors remain:
error 4.71, warning 4.98, info 4.58, and hint 4.59. Extra diagnostic saturation
or plugin integrations were unnecessary.

## ANSI decision

The existing terminal palette defines 16 slots but 10 distinct colors. Normal
and bright red/green/yellow/blue/magenta/cyan intentionally coincide. Separating
these could preserve intensity-only distinctions in terminal tools; it would
also introduce six brighter colors or weaken the existing normal accents.
No terminal application requirement here justifies that change. Black/bright
black and white/bright white remain separate. Tests preserve these mappings.
ANSI black is a surface color, so the text target does not apply to black text
on the normal background.

## Compatibility evidence

The runtime's newest required API is `nvim_set_hl` (since Neovim 0.5.0).
Other runtime calls are longstanding Lua/Vim helpers. Merely defining newer
group names does not require the Neovim version that first uses those groups.
The test suite uses `nvim_get_hl` and `nvim -l`, introduced in 0.9.0. Thus API
availability alone does not justify the former 0.12.5 minimum.

The supported floor is conservatively 0.9.5, the oldest version actually tested,
rather than an untested theoretical 0.5.0. The complete suite was run locally
with official macOS release binaries 0.9.5, 0.10.4, 0.11.5, and the installed
0.12.6. All passed. CI now includes pinned 0.9.5, 0.10.4, 0.11.5, 0.12.5,
plus stable and nightly on Linux. Nightly is a compatibility probe.

API references: [nvim_set_hl / nvim_get_hl](https://neovim.io/doc/user/api/#nvim_set_hl()),
[0.9 Lua runner](https://github.com/neovim/neovim/blob/v0.9.5/runtime/doc/starting.txt),
[terminal palette](https://neovim.io/doc/user/terminal/#terminal-config).

## Rendered Tree-sitter and LSP overlap

`nvim -l tests/render.lua` launches a clean embedded Neovim, attaches an RGB
line-grid UI, and reads its actual `grid_line` / `hl_attr_define` output.
It uses the real bundled Lua parser and runtime highlight query, plus a small
deterministic JSON-RPC LSP server implemented with Python 3's standard library.
Semantic tokens travel through Neovim's normal LSP transport and highlighter;
the test does not substitute hand-placed semantic extmarks. Child state and
logs are temporary, and no user Neovim configuration is loaded.

Six scenes each check 16 screen positions: Tree-sitter alone, concurrent LSP
semantic tokens, linewise selection, deselection, characterwise selection, and
blockwise selection. Positions cover comments, strings, variables, properties,
parameters, function declarations/calls, keywords, numbers, and delimiters.
The deterministic server also tests readonly/defaultLibrary/deprecated
modifiers, a readonly generic semantic variable on a Tree-sitter function call, a
generic keyword over a return capture, and a
semantic class overriding a less-specific Tree-sitter variable capture.
Foreground/background RGB values are checked, along with italic and deprecated
strikethrough cues. All three Visual modes render selected text as `#e0dac7`
on `#304148`; original syntax colors return after deselection.

`nvim -l tests/render.lua --real-lsp` repeats the scenes with the installed
Lua Language Server, allowing its actual analysis to supply the semantic
tokens. It waits for tokens on function/parameter/property positions before
testing combined rendering. Synthetic class/deprecated expectations are only
used in deterministic mode; real-server expectations follow the Lua fixture.
Client error notifications fail the test; status messages do not open prompts
in the test UI. Diagnostics/inlay hints are disabled to isolate syntax layering.

Both modes passed locally on Neovim 0.9.5, 0.10.4, 0.11.5, and 0.12.6. The
installed LuaLS reported `3.18.2-dev`. This verifies rendered colors for the
Lua cases above, including real Tree-sitter/LSP overlap.
The deterministic mode is included in CI; the optional installed-server mode
is a local integration check.

## Manual visual review

`tests/samples` contains TypeScript, Lua, Markdown, and unified diff examples.
They are editing fixtures; the automated overlap test above specifically uses
Lua, not the TypeScript/Markdown/diff parsers or their language servers.
From the repository root:

```sh
nvim --clean --cmd 'set rtp^=.' \
  '+set termguicolors number cursorline' '+colorscheme dim-solarized' \
  tests/samples/editing.lua
```

Repeat for the other samples. Use the user's usual Tree-sitter/LSP setup as
well as traditional syntax. Select across a comment, string, and identifier;
compare with CursorLine, `/name` search and the current match. Trigger document
references and completion; inspect selected/unselected menu items, inactive
statuslines, and a separate diagnostic example. Compare side-by-side diff and
unified diff, including text inside changed areas. Check a real terminal tool
that emits SGR 30–37 and 90–97 if intensity distinction matters.

The previous README screenshot was inspected: it gives substantial space to
a warning and completion popup and predates this revision. The file is retained
as a historical asset, but the README uses the regenerated palette chart until
a real replacement capture is reviewed. Prefer a routine editing screenshot
with a small selection/search match and a separate diagnostic example.
