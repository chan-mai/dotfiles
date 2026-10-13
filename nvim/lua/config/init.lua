local map = vim.keymap.set

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local ok, catppuccin = pcall(require, "catppuccin")
if ok then
  catppuccin.setup({ flavour = "mocha", auto_integrations = true })
  vim.cmd.colorscheme("catppuccin")
end

vim.opt.number = true
vim.opt.signcolumn = "yes"
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.updatetime = 250
-- エージェント編集の即時反映
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  command = "silent! checktime",
})

-- treesitter
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})

-- LSP, 実行ファイルのあるサーバのみ
local servers = { "gopls", "rust_analyzer", "ts_ls", "pyright", "lua_ls", "nil_ls", "terraformls", "yamlls" }
for _, name in ipairs(servers) do
  local cmd = (vim.lsp.config[name] or {}).cmd
  if type(cmd) == "table" and vim.fn.executable(cmd[1]) == 1 then
    vim.lsp.enable(name)
  end
end
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
    end
  end,
})
vim.diagnostic.config({ virtual_text = true })
map("n", "gd", vim.lsp.buf.definition, { desc = "Definition" })

-- telescope
local builtin = require("telescope.builtin")
require("telescope").setup({})
pcall(require("telescope").load_extension, "fzf")
map("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
map("n", "<leader>fg", builtin.live_grep, { desc = "Grep" })
map("n", "<leader>fw", builtin.grep_string, { desc = "Grep word" })
map("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
map("n", "<leader>fr", builtin.lsp_references, { desc = "References" })
map("n", "<leader>fs", builtin.lsp_dynamic_workspace_symbols, { desc = "Workspace symbols" })
map("n", "<leader>fd", builtin.diagnostics, { desc = "Diagnostics" })

-- gitsigns, stage=レビュー済み
local gs = require("gitsigns")
gs.setup({ attach_to_untracked = true })
map("n", "]h", function() gs.nav_hunk("next") end, { desc = "Next hunk" })
map("n", "[h", function() gs.nav_hunk("prev") end, { desc = "Prev hunk" })
map("n", "<leader>hs", gs.stage_hunk, { desc = "Toggle stage hunk" })
map("x", "<leader>hs", function()
  gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
end, { desc = "Toggle stage lines" })
map("n", "<leader>hS", gs.stage_buffer, { desc = "Stage buffer" })
map("n", "<leader>hr", gs.reset_hunk, { desc = "Reset hunk" })
map("n", "<leader>hp", gs.preview_hunk_inline, { desc = "Preview hunk" })
map("n", "<leader>hb", gs.blame_line, { desc = "Blame line" })

-- diffview
require("diffview").setup({
  enhanced_diff_hl = true,
  view = { default = { layout = "diff1_inline" } },
  file_panel = { listing_style = "tree" },
})

local function review_refs()
  local out = vim.fn.systemlist({
    "git", "for-each-ref", "--sort=-refname", "--format=%(refname:short)", "refs/review/2*",
  })
  return vim.v.shell_error == 0 and out or {}
end

local function pick_snapshot(cb)
  local refs = review_refs()
  if #refs == 0 then
    vim.notify("no review snapshot", vim.log.levels.WARN)
    return
  end
  vim.ui.select(refs, { prompt = "Snapshot" }, function(ref)
    if ref then cb(ref) end
  end)
end

map("n", "<leader>rr", "<cmd>DiffviewOpen<cr>", { desc = "Review: unreviewed/staged" })
map("n", "<leader>ra", "<cmd>DiffviewOpen refs/review/latest<cr>", { desc = "Review: since last prompt" })
map("n", "<leader>rA", function()
  pick_snapshot(function(ref) vim.cmd("DiffviewOpen " .. ref) end)
end, { desc = "Review: since snapshot" })
map("n", "<leader>rR", function()
  pick_snapshot(function(from)
    pick_snapshot(function(to) vim.cmd(("DiffviewOpen %s..%s"):format(from, to)) end)
  end)
end, { desc = "Review: snapshot A..B" })
map("n", "<leader>rs", "<cmd>DiffviewOpen --staged<cr>", { desc = "Review: staged only" })
map("n", "<leader>rh", "<cmd>DiffviewFileHistory %<cr>", { desc = "Review: file history" })
map("n", "<leader>rq", "<cmd>DiffviewClose<cr>", { desc = "Review: close" })
map("n", "<leader>rg", function()
  gs.change_base("refs/review/latest", true)
end, { desc = "Signs: base=last prompt" })
map("n", "<leader>rG", function() gs.reset_base(true) end, { desc = "Signs: base=index" })

-- shepherd, エージェントへ@path#L参照送信後にペイン移動
local shepherd = require("shepherd")
local function focus_agent(result)
  if result and result.ok then shepherd.open() end
end
map({ "n", "x" }, "<leader>aa", function()
  return shepherd.send_range(nil, nil, {}, focus_agent)
end, { expr = true, desc = "Agent: send range" })
map("n", "<leader>al", function()
  local l = vim.fn.line(".")
  shepherd.send_range(l, l, {}, focus_agent)
end, { desc = "Agent: send line" })
map("n", "<leader>af", function() shepherd.send_file({}, focus_agent) end, { desc = "Agent: send file" })
map("n", "<leader>ap", function() shepherd.pick() end, { desc = "Agent: pick target" })
map("n", "<leader>ao", function() shepherd.open() end, { desc = "Agent: focus" })
