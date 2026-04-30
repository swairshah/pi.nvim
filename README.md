# pi-background.nvim

A standalone Neovim plugin that keeps one `pi --mode rpc` process running in the background and reuses it for `,pi` prompts.

## Features

- `,pi` asks Pi about the current buffer using a persistent background RPC process.
- Visual `,pi` asks about the selection.
- Floating progress window while Pi thinks/runs tools.
- Model picker backed by `pi --list-models`.
- Defaults to `openai-codex/gpt-5.3-codex-spark`.
- Defaults to `--continue` sessions.
- No dependency on `pablopunk/pi.nvim`; this plugin talks to Pi RPC directly.

## Requirements

- Neovim 0.10+
- `pi` CLI installed and authenticated

## Lazy.nvim

```lua
{
  "pi-background.nvim",
  url = "git@github.com:swairshah/pi-background.nvim.git",
  opts = {},
}
```

For a local checkout:

```lua
{
  dir = "~/work/code/pi-background.nvim",
  opts = {},
}
```

## Configuration

```lua
{
  "pi-background.nvim",
  url = "git@github.com:swairshah/pi-background.nvim.git",
  opts = {
    provider = "openai-codex",
    model = "gpt-5.3-codex-spark",
    session_mode = "continue", -- continue | new | ephemeral
    keymap_prefix = "<leader>p",
  },
}
```

Environment overrides:

```bash
PI_NVIM_PROVIDER=anthropic PI_NVIM_MODEL=claude-haiku-4-5 nvim
PI_NVIM_SESSION_MODE=ephemeral nvim
```

## Keymaps

With the default `<leader>p` prefix:

- `,pi` ask background Pi about current buffer
- visual `,pi` ask about selection
- `,pc` cancel current Pi operation
- `,ps` show background Pi status
- `,pS` stop the background Pi process
- `,pm` choose model
- `,pM` show current model/session
- `,pl` open plugin log
- `,pt` optional persistent Pi terminal

## Commands

- `:PiBgAsk`
- `:PiBgAskSelection`
- `:PiBgCancel`
- `:PiBgStop`
- `:PiBgRestart`
- `:PiBgStatus`
- `:PiChooseModel`
- `:PiUseModel <provider> <model>`
- `:PiUseModel` reset to Pi CLI default
- `:PiCurrentModel`
- `:PiSessionMode continue|new|ephemeral`
- `:PiLog`
- `:PiTerminal`
- `:PiTerminalNew`
