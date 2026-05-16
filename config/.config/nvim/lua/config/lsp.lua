# lsp #
vim.lsp.config('lua_ls', {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
  settings = {
    Lua = {
      workspace = {
        library = { '/usr/share/hypr/stubs/' },
        checkThirdParty = false,
      },
      diagnostics = { globals = { 'vim' } },
    },
  },
})

vim.lsp.enable('lua_ls')
