" vista-lite.vim: Command definitions for vista-lite

if exists('g:loaded_vista_lite')
  finish
endif
let g:loaded_vista_lite = 1

" Commands
command! Vista lua require('vista-lite').toggle()
command! VistaOpen lua require('vista-lite').open()
command! VistaClose lua require('vista-lite').close()
command! VistaFocus lua require('vista-lite').focus()
command! VistaRefresh lua require('vista-lite').refresh()

" Highlight groups
highlight default link VistaClass Type
highlight default link VistaFunction Function
highlight default link VistaMethod Function
highlight default link VistaVariable Identifier
highlight default link VistaConstant Constant
highlight default link VistaInterface Type
highlight default link VistaEnum Type
highlight default link VistaStruct Type