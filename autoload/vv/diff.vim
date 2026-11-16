vim9script
# Diff view: `jj show --git` in a reusable detail window beside the log.

import autoload 'vv.vim'

export def Show(root: string, rev: dict<any>, focus: bool)
  var from = win_getid()
  var win = DetailWindow()
  if win == -1
    execute get(g:, 'vv_detail_split', 'botright vnew')
    w:vv_detail = true
  else
    win_gotoid(win)
    enew
  endif
  var buf = bufnr()
  silent! execute 'file ' .. fnameescape('vv://show/' .. rev.change)
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted nomodifiable
  setlocal filetype=diff
  b:vv_root = root
  b:vv_rev = rev
  nnoremap <buffer> <silent> ]f <Cmd>call search('^diff --git', 'W')<CR>
  nnoremap <buffer> <silent> [f <Cmd>call search('^diff --git', 'bW')<CR>
  nnoremap <buffer> <silent> q <Cmd>close<CR>
  Fill(buf, ['loading...'])
  vv.Run(root, ['show', '--git', rev.rev], (out) => Fill(buf, empty(out) ? ['(no changes)'] : out))
  if !focus
    win_gotoid(from)
  endif
enddef

def DetailWindow(): number
  for w in gettabinfo(tabpagenr())[0].windows
    if getwinvar(w, 'vv_detail', false)
      return w
    endif
  endfor
  return -1
enddef

def Fill(buf: number, lines: list<string>)
  if !bufexists(buf)
    return
  endif
  setbufvar(buf, '&modifiable', 1)
  silent deletebufline(buf, 1, '$')
  setbufline(buf, 1, lines)
  setbufvar(buf, '&modifiable', 0)
enddef
