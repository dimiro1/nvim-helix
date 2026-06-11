# Tests and local runs use an isolated XDG_CONFIG_HOME whose nvim/ entry is a
# symlink to this repo: nvim then treats the repo as its config dir, and the
# committed vim.pack lockfile (nvim-pack-lock.json) is written in-repo.
XDG := $(CURDIR)/.testenv
export XDG_CONFIG_HOME := $(XDG)/config
# hermetic zoxide db: tests cd around and must not pollute the real one
export _ZO_DATA_DIR := $(XDG)/zoxide
# isolated state dir: workspace sessions from tests stay out of ~/.local/state
export XDG_STATE_HOME := $(XDG)/state

.PHONY: bootstrap test run check clean

$(XDG)/config/nvim:
	mkdir -p $(XDG)/config $(XDG)/zoxide
	ln -sfn $(CURDIR) $(XDG)/config/nvim

# First boot installs plugins via vim.pack, then blocks until tree-sitter
# parsers are compiled (install() is async; idempotent when already done).
bootstrap: $(XDG)/config/nvim
	nvim --headless "+lua require('nvim-treesitter').install(require('config.plugins').parsers):wait(600000)" "+lua print('boot ok')" +qa

test: bootstrap
	nvim --headless -c "lua require('mini.test').setup()" -c "lua MiniTest.run()"

# Interactive session against this repo without touching ~/.config
run: $(XDG)/config/nvim
	nvim

# lua_ls type-check over the whole repo, with the same settings the editor
# uses (lua/config/lsp.lua) — keep the two in sync when editing either.
check: $(XDG)/config/nvim
	nvim --clean --headless "+lua io.write(vim.json.encode({ runtime = { version = 'LuaJIT' }, workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME, '\$${3rd}/luv/library' } }, diagnostics = { globals = { 'MiniTest' } } }))" +q > $(XDG)/luarc-check.json 2>/dev/null
	lua-language-server --check $(CURDIR) --configpath $(XDG)/luarc-check.json --checklevel=Warning

clean:
	rm -rf $(XDG)
