# Contributing to Peekr.nvim

Thanks for your interest in contributing!

## Development setup

1. Clone the repo and make sure you have **Neovim >= 0.12** installed.
2. Install [StyLua](https://github.com/JohnnyMorganz/StyLua) and [Luacheck](https://github.com/mpeterv/luacheck).

## Code style

- Format with StyLua: `stylua lua/ tests/`
- Lint with Luacheck: `luacheck lua/ tests/`
- Config files: `.stylua.toml` and `.luacheckrc`

## Running tests

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (busted-style):

```sh
make test
```

This clones plenary.nvim to `/tmp` if needed and runs all `tests/*_spec.lua` files in headless Neovim.

## Full check

```sh
make check   # runs format check + lint + tests
```

## Pull requests

- Run `make check` before submitting.
- Keep commits focused and descriptive.
- Add tests for new functionality when possible.
- Follow the existing code style (2-space indent, single quotes).
