# pi.nvim

Use [Pi](https://pi.dev) from Neovim without leaving your editor.

This plugin keeps a single `pi --mode rpc` process running in the background, so repeated asks are fast and continue the same Pi session. It shows a small floating progress window while Pi thinks, runs tools, and edits files.

- Ask Pi about the current file with `,pi`.
- Ask Pi about a visual selection with visual `,pi`.
- Reuses one background Pi process instead of starting Pi from scratch every time.
- Continues your normal Pi session by default.
- Uses your system Pi default model by default.
- Lets you configure provider/model directly in your Lazy spec.
- Reloads changed buffers after Pi edits files.
- Includes a lightweight floating status window in the top-right corner.
- Loads a bundled Neovim-only Pi extension placeholder.
- Lets you pass extra Pi extensions from your Lazy config while keeping your normally installed Pi extensions enabled.

## Requirements

Install and authenticate the Pi CLI first:

```bash
npm install -g @mariozechner/pi-coding-agent
pi
/login
```

If `pi` works in your terminal, this plugin can use it.

## Installation with lazy.nvim

```lua
{
  "swairshah/pi.nvim",
  opts = {},
}
```

Then run:

```vim
:Lazy sync
```

## Configuration

By default, the plugin does **not** choose a model. It lets your installed Pi CLI use whatever model/provider it would normally use.

If you want to set a model from your Neovim config, put it in the same Lazy spec:

```lua
{
  "swairshah/pi.nvim",
  opts = {
    provider = "openai-codex",
    model = "gpt-5.3-codex-spark",
  },
}
```

Another example:

```lua
{
  "swairshah/pi.nvim",
  opts = {
    provider = "anthropic",
    model = "claude-haiku-4-5",
  },
}
```

Full example with session behavior and key prefix:

```lua
{
  "swairshah/pi.nvim",
  opts = {
    -- nil provider/model means use Pi CLI defaults
    provider = nil,
    model = nil,

    -- continue: use `pi --continue`
    -- new: start a fresh saved Pi session
    -- ephemeral: use `pi --no-session`
    session_mode = "continue",

    -- defaults to <leader>p; if your leader is comma, this means ,pi, ,pm, etc.
    keymap_prefix = "<leader>p",

    -- Floating status window placement. Default is top-right.
    window = {
      position = "top-right", -- or "center"
      row = 1,
      col_offset = 2,
    },

    -- Load the bundled Neovim-only Pi extension placeholder. Default: true.
    builtin_extension = true,

    -- Extra Pi extensions to load with this plugin. These are added with
    -- `pi --extension ...` and do not disable your normal installed extensions.
    extension_paths = {
      -- "~/.pi/agent/extensions/my-extra-extension.ts",
      -- "~/work/my-pi-extension",
    },
  },
}
```

You can also override from the shell:

```bash
PI_NVIM_PROVIDER=anthropic PI_NVIM_MODEL=claude-haiku-4-5 nvim
PI_NVIM_SESSION_MODE=ephemeral nvim
```

## Usage

With the default key prefix `<leader>p`:

| Key | What it does |
| --- | --- |
| `,pi` | Ask Pi about the current file |
| visual `,pi` | Ask Pi about the selected text |
| `,pc` | Cancel the current Pi task |
| `,ps` | Show background Pi status |
| `,pS` | Stop the background Pi process |
| `,pm` | Pick a model from `pi --list-models` |
| `,pM` | Show current model and session mode |
| `,pl` | Open plugin log |
| `,pt` | Optional interactive Pi terminal split |

If your leader is not comma, replace `,` with your leader key.

## Commands

```vim
:PiBgAsk
:PiBgAskSelection
:PiBgCancel
:PiBgStop
:PiBgRestart
:PiBgStatus
:PiChooseModel
:PiUseModel <provider> <model>
:PiUseModel              " reset to Pi CLI default
:PiCurrentModel
:PiSessionMode continue
:PiSessionMode new
:PiSessionMode ephemeral
:PiLog
:PiTerminal
:PiTerminalNew
```

## Pi extensions

pi.nvim loads one bundled Neovim-only Pi extension by default. Right now it is an intentional no-op placeholder. It exists so you can add Neovim-specific Pi behavior later without affecting normal terminal `pi` sessions.

Your normal Pi extensions still load too. The plugin does not pass `--no-extensions` unless you configure `extensions = false`.

To add more extensions only for Neovim-launched Pi sessions:

```lua
{
  "swairshah/pi.nvim",
  opts = {
    extension_paths = {
      "~/.pi/agent/extensions/my-extra-extension.ts",
      "~/work/my-pi-extension",
    },
  },
}
```

To turn off the bundled Neovim extension:

```lua
{
  "swairshah/pi.nvim",
  opts = {
    builtin_extension = false,
  },
}
```

## Notes

- The plugin talks to Pi directly through RPC; it does not depend on another Neovim Pi plugin.
- The first ask starts the background process. Later asks reuse it.
- If Pi edits files on disk, loaded unmodified buffers are refreshed automatically.
