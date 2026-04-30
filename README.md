# pi-background.nvim

A small Neovim wrapper around [pablopunk/pi.nvim](https://github.com/pablopunk/pi.nvim) that keeps a single `pi --mode rpc` process running in the background and reuses it for `,pi` prompts.

## Features

- `,pi` asks Pi about the current buffer using a persistent background RPC process.
- Visual `,pi` asks about the selection.
- Floating progress window while Pi thinks/runs tools.
- Model picker backed by `pi --list-models`.
- Defaults to `openai-codex/gpt-5.3-codex-spark`.
- Defaults to `--continue` sessions.

## Requirements

- Neovim 0.10+
- `pi` CLI installed and authenticated
- `pablopunk/pi.nvim`

## Lazy.nvim

```lua
{
  "YOUR_GITHUB_USER/pi-background.nvim",
  dependencies = { "pablopunk/pi.nvim" },
  opts = {},
}
```

For a local checkout:

```lua
{
  dir = "~/work/code/pi-background.nvim",
  dependencies = { "pablopunk/pi.nvim" },
  opts = {},
}
```

## Configuration

```lua
{
  "YOUR_GITHUB_USER/pi-background.nvim",
  dependencies = { "pablopunk/pi.nvim" },
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
- `,pl` open Pi log
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
- `:PiTerminal`
- `:PiTerminalNew`
