vim9script
# Keymaps and options for the vv log buffer.

if exists('b:did_ftplugin')
  finish
endif
b:did_ftplugin = 1

import autoload 'vv/log.vim'

setlocal nowrap nonumber norelativenumber nolist nospell cursorline signcolumn=no

if get(g:, 'vv_no_mappings', false)
  finish
endif

nnoremap <buffer> <nowait> <silent> <CR>  <ScriptCmd>log.ShowDiff(true)<CR>
nnoremap <buffer> <nowait> <silent> p     <ScriptCmd>log.ShowDiff(false)<CR>
nnoremap <buffer> <nowait> <silent> e     <ScriptCmd>log.Describe()<CR>
nnoremap <buffer> <nowait> <silent> m     <ScriptCmd>log.Mark(false)<CR>
nnoremap <buffer> <nowait> <silent> M     <ScriptCmd>log.Mark(true)<CR>
nnoremap <buffer> <nowait> <silent> a     <ScriptCmd>log.Move('after')<CR>
nnoremap <buffer> <nowait> <silent> b     <ScriptCmd>log.Move('before')<CR>
nnoremap <buffer> <nowait> <silent> o     <ScriptCmd>log.Move('onto')<CR>
nnoremap <buffer> <nowait> <silent> s     <ScriptCmd>log.Squash()<CR>
nnoremap <buffer> <nowait> <silent> n     <ScriptCmd>log.New()<CR>
nnoremap <buffer> <nowait> <silent> E     <ScriptCmd>log.Edit()<CR>
nnoremap <buffer> <nowait> <silent> X     <ScriptCmd>log.Abandon()<CR>
nnoremap <buffer> <nowait> <silent> u     <ScriptCmd>log.Undo()<CR>
nnoremap <buffer> <nowait> <silent> R     <ScriptCmd>log.Refresh()<CR>
nnoremap <buffer> <nowait> <silent> <C-n> <ScriptCmd>log.Jump(1)<CR>
nnoremap <buffer> <nowait> <silent> <C-p> <ScriptCmd>log.Jump(-1)<CR>
nnoremap <buffer> <nowait> <silent> g?    <ScriptCmd>log.Help()<CR>
nnoremap <buffer> <nowait> <silent> q     <Cmd>if winnr('$') > 1 <Bar> close <Bar> else <Bar> bdelete <Bar> endif<CR>
