TESTS_DIR := tests
PLENARY_DIR := /tmp/plenary.nvim

.PHONY: test lint format fmt check

test: $(PLENARY_DIR)
	nvim --headless \
		-u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory $(TESTS_DIR) { minimal_init = 'tests/minimal_init.lua', sequential = true }"

$(PLENARY_DIR):
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(PLENARY_DIR)

lint:
	luacheck lua/ tests/

format:
	stylua --check lua/ tests/

fmt:
	stylua lua/ tests/

check: format lint test
