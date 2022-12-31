if !has('nvim-0.5') || exists('g:loaded_vista_nvim') | finish | endif

let s:save_cpo = &cpo
set cpo&vim

augroup SidebarNvim
au!
" au VimEnter * lua require'vista-nvim'._vim_enter()
" au VimLeavePre * lua require'vista-nvim.lib'.on_vim_leave()
" au WinClosed * lua require'vista-nvim.lib'.on_win_leave()

" au BufWritePost * lua require'vista-nvim.lib'.update()
" au BufEnter * lua require'vista-nvim.lib'.update()
" au TabEnter * lua require'vista-nvim.lib'.update()
" au VimResume * lua require'vista-nvim.lib'.update()
" au FocusGained * lua require'vista-nvim.lib'.update()
augroup end


command! VistaNvimOpen lua require'vista-nvim'.open()
command! VistaNvimClose lua require'vista-nvim'.close()
command! VistaNvimToggle lua require'vista-nvim'.toggle()
command! VistaNvimFocus lua require'vista-nvim'.focus()
command! -nargs=1 VistaNvimResize lua require'vista-nvim'.resize(<args>)

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_vista_nvim = 1
