local child = MiniTest.new_child_neovim()
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'init.lua' })
      child.o.columns = 160
      child.o.lines = 40
      child.lua([[
        local base = vim.fn.tempname()
        vim.fn.mkdir(base .. '/project/deep/nested', 'p')
        vim.fn.mkdir(base .. '/project/clean-dir', 'p')
        vim.fn.mkdir(base .. '/elsewhere', 'p')
        local root = vim.uv.fs_realpath(base .. '/project')
        _G.tree_fixture = { root = root, other = base .. '/elsewhere', base = base }
        function tree_fixture.git(...)
          local cmd = { 'git', '-C', root, '-c', 'user.email=t@t', '-c', 'user.name=t' }
          vim.list_extend(cmd, { ... })
          local out = vim.fn.system(cmd)
          assert(vim.v.shell_error == 0, out)
        end
        function tree_fixture.text()
          local win = require('nvim-tree.api').tree.winid()
          if not win then return '' end
          return table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), '\n')
        end
        tree_fixture.git('init', '-q', '-b', 'main')
        for _, name in ipairs({ 'clean.txt', 'dirty.txt', 'staged.txt', 'deep/nested/review.txt', 'clean-dir/keep.txt' }) do
          vim.fn.writefile({ 'original' }, root .. '/' .. name)
        end
        vim.fn.writefile({ 'ignored.log' }, root .. '/.gitignore')
        tree_fixture.git('add', '.')
        tree_fixture.git('commit', '-q', '-m', 'init')
        for _, name in ipairs({ 'dirty.txt', 'staged.txt', 'deep/nested/review.txt' }) do
          vim.fn.writefile({ 'changed' }, root .. '/' .. name)
        end
        tree_fixture.git('add', 'staged.txt')
        vim.fn.writefile({ 'new' }, root .. '/untracked.txt')
        vim.fn.writefile({ 'ignored' }, root .. '/ignored.log')
        vim.cmd.cd(tree_fixture.other)
        vim.cmd.edit(root .. '/clean.txt')
      ]])
    end,
    post_once = child.stop,
  },
})

local function wait_for(expression)
  local ok = child.lua_get('vim.wait(3000, function() return ' .. expression .. ' end, 10)')
  if not ok then MiniTest.add_note(child.lua_get([[tree_fixture.text()]])) end
  eq(ok, true)
end

local function open_tree()
  child.type_keys(100, '<Space>E')
  wait_for([[require('nvim-tree.api').tree.is_visible()]])
end

local function filter(query)
  child.type_keys(50, '/')
  wait_for([[vim.bo.filetype == 'NvimTreeFilter']])
  child.type_keys(50, query, '<CR>')
  wait_for([[vim.bo.filetype == 'NvimTree']])
end

T['Space-E toggles a tree rooted at the buffer workspace without changing cwd'] = function()
  open_tree()
  eq(child.lua_get([[require('nvim-tree.api').tree.get_nodes().absolute_path == tree_fixture.root]]), true)
  eq(child.lua_get([[vim.uv.fs_realpath(vim.uv.cwd()) == vim.uv.fs_realpath(tree_fixture.other)]]), true)
  child.type_keys(100, '<Space>E')
  wait_for([[not require('nvim-tree.api').tree.is_visible()]])
  eq(child.lua_get([[vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')]]), 'clean.txt')
end

T['pickers use the tree root while the sidebar is focused'] = function()
  open_tree()
  eq(child.lua_get([[require('config.pickers').workspace_root() == tree_fixture.root]]), true)
end

T['the tree shows dotfiles and hides git metadata and ignored files'] = function()
  open_tree()
  local text = child.lua_get([[tree_fixture.text()]])
  eq(text:find('.gitignore', 1, true) ~= nil, true)
  eq(text:find('ignored.log', 1, true), nil)
  local names = child.lua_get([[vim.tbl_map(function(n) return n.name end, require('nvim-tree.api').tree.get_nodes().nodes)]])
  eq(vim.tbl_contains(names, '.git'), false)
end

T['C keeps staged, unstaged and untracked files and hides clean directories'] = function()
  open_tree()
  child.type_keys(50, 'C')
  wait_for([[not tree_fixture.text():find('clean.txt', 1, true) and tree_fixture.text():find('dirty.txt', 1, true)]])
  local text = child.lua_get([[tree_fixture.text()]])
  for _, name in ipairs({ 'dirty.txt', 'staged.txt', 'untracked.txt' }) do
    eq(text:find(name, 1, true) ~= nil, true, name)
  end
  eq(text:find('clean-dir', 1, true), nil)
  eq(text:find('ignored.log', 1, true), nil)
  child.type_keys(50, 'C')
  wait_for([[tree_fixture.text():find('clean.txt', 1, true) ~= nil]])
end

T['slash discovers a matching file inside collapsed nested directories'] = function()
  open_tree()
  eq(child.lua_get([[tree_fixture.text():find('review.txt', 1, true)]]), vim.NIL)
  filter('review')
  wait_for([[tree_fixture.text():find('review.txt', 1, true) ~= nil]])
  local text = child.lua_get([[tree_fixture.text()]])
  eq(text:find('dirty.txt', 1, true), nil)
  eq(text:find('clean-dir', 1, true), nil)
  child.type_keys('F')
  wait_for([[tree_fixture.text():find('dirty.txt', 1, true) ~= nil]])
end

T['name filtering and clearing preserve the changed-only filter'] = function()
  open_tree()
  child.type_keys(50, 'C')
  wait_for([[tree_fixture.text():find('clean.txt', 1, true) == nil]])
  filter('review')
  wait_for([[tree_fixture.text():find('review.txt', 1, true) ~= nil]])
  eq(child.lua_get([[tree_fixture.text():find('dirty.txt', 1, true) == nil]]), true)
  child.type_keys('F')
  wait_for([[tree_fixture.text():find('dirty.txt', 1, true) ~= nil]])
  eq(child.lua_get([[tree_fixture.text():find('clean.txt', 1, true) == nil]]), true)
end

T['width keys honor counts and persist across toggles'] = function()
  open_tree()
  eq(child.api.nvim_win_get_width(0), 40)
  child.type_keys(50, '>')
  eq(child.api.nvim_win_get_width(0), 45)
  child.type_keys(50, '2', '<')
  eq(child.api.nvim_win_get_width(0), 35)
  child.type_keys(100, '<Space>E', '<Space>E')
  wait_for([[require('nvim-tree.api').tree.is_visible()]])
  eq(child.api.nvim_win_get_width(0), 35)
end

T['tree mappings stay buffer local and have help descriptions'] = function()
  open_tree()
  for _, key in ipairs({ '/', 'C', 'F', '<', '>' }) do
    local info = child.lua_get(('(function() local m = vim.fn.maparg(%q, "n", false, true); return { buffer = m.buffer, desc = m.desc } end)()'):format(key))
    eq(info.buffer, 1, key)
    eq(type(info.desc) == 'string' and info.desc ~= '', true, key)
  end
  child.type_keys(100, '<Space>E')
  wait_for([[not require('nvim-tree.api').tree.is_visible()]])
  for _, key in ipairs({ '/', 'C', 'F', '<', '>' }) do
    eq(child.lua_get(('vim.fn.maparg(%q, "n")'):format(key)), '', key)
  end
end

T['switching worktrees keeps an open tree usable at the correct root'] = function()
  child.lua([[
    tree_fixture.git('worktree', 'add', '-q', tree_fixture.base .. '/feature', '-b', 'feature')
    vim.cmd.cd(tree_fixture.root)
    require('config.worktrees').on_first_visit = function() vim.cmd.edit('clean.txt') end
  ]])
  open_tree()
  eq(child.lua_get([[require('config.worktrees').switch(tree_fixture.base .. '/feature')]]), true)
  wait_for([[require('nvim-tree.api').tree.is_visible()]])
  eq(child.lua_get([[require('nvim-tree.api').tree.get_nodes().absolute_path == vim.uv.fs_realpath(tree_fixture.base .. '/feature')]]), true)
  eq(child.lua_get([[vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':t')]]), 'clean.txt')
  eq(child.lua_get([[require('config.worktrees').switch(tree_fixture.root)]]), true)
  wait_for([[require('nvim-tree.api').tree.is_visible()]])
  eq(child.lua_get([[require('nvim-tree.api').tree.get_nodes().absolute_path == tree_fixture.root]]), true)
  eq(child.lua_get([[(function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_get_name(buf):match('NvimTree_%d+$') and vim.bo[buf].filetype ~= 'NvimTree' then return false end
    end
    return true
  end)()]]), true)
end

return T
