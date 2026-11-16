vim9script
# vv: Jujutsu workflows from within Vim.

if exists('g:loaded_vv')
  finish
endif
g:loaded_vv = 1

import autoload 'vv/log.vim'

command -nargs=? VV log.Open(<q-args>)
command -nargs=? VVLog log.Open(<q-args>)

def Highlights()
  highlight default link VVChangePrefix Identifier
  highlight default link VVChangeRest Comment
  highlight default link VVAuthor String
  highlight default link VVTime Number
  highlight default link VVRefs Function
  highlight default link VVFlags WarningMsg
  highlight default link VVCommitPrefix Type
  highlight default link VVCommitRest Comment
  highlight default link VVMark Visual
  highlight default link VVNodeWorkingCopy Title
  highlight default link VVNodeImmutable Special
  highlight default link VVNodeConflict Error
  highlight default link VVNode Normal
  highlight default link VVGraph Comment
  highlight default link VVNoDescription WarningMsg
  highlight default link VVElided Comment
enddef
Highlights()

augroup vv_highlights
  autocmd!
  autocmd ColorScheme * Highlights()
augroup END
