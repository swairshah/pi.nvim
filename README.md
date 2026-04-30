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
- Includes a lightweight floating status window.

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
