# treesitter #
-- Built-in treesitter (Neovim 0.10+). Parsers come from pacman:
--   tree-sitter-{bash,c,javascript,lua,markdown,python,query,rust,vim,vimdoc}

vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
    if lang and pcall(vim.treesitter.start, args.buf, lang) then
      vim.bo[args.buf].indentexpr = "v:lua.require'vim.treesitter'.indentexpr()"
    end
  end,
})
