if !has('nvim-0.5') || exists('g:loaded_vista_nvim') | finish | endif

let s:save_cpo = &cpo
set cpo&vim

augroup VistaNvim
au!
" au VimEnter * lua require'vista-nvim'._vim_enter()
au VimLeavePre * lua require'vista-nvim'.on_vim_leave()
au WinClosed * lua require'vista-nvim'.on_win_leave()
augroup end


command! VistaNvimOpen lua require'vista-nvim'.open()
command! VistaNvimClose lua require'vista-nvim'.close()
command! VistaNvimToggle lua require'vista-nvim'.toggle()
command! VistaNvimFocus lua require'vista-nvim'.focus()
command! -nargs=1 VistaNvimResize lua require'vista-nvim'.resize(<args>)

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_vista_nvim = 1
