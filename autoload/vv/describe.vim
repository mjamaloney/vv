vim9script
# Describe: edit a revision's description in a buffer; :w applies it.

import autoload 'vv.vim'

export def Open(root: string, rev: dict<any>, OnSaved: func = null_function)
  var lines: list<string>
  try
    lines = vv.Sync(root, ['log', '--no-graph', '-r', rev.rev, '-T', 'description'])
  catch /^vv:/
    vv.Error(substitute(v:exception, '^vv: ', '', ''))
    return
  endtry
  execute get(g:, 'vv_describe_split', 'botright new')
  silent! execute 'file ' .. fnameescape('vv://describe/' .. rev.change)
  setlocal buftype=acwrite bufhidden=wipe noswapfile nobuflisted
  setline(1, lines + ['', 'JJ: Change ID: ' .. rev.change, 'JJ: Lines starting with "JJ:" are removed.', 'JJ: :w to save, :q! to cancel.'])
  setlocal nomodified
  setlocal filetype=jjdescription
  cursor(1, 1)
  b:vv_root = root
  b:vv_rev = rev
  b:vv_on_saved = OnSaved
  autocmd BufWriteCmd <buffer> Save()
enddef

def Save()
  var lines = filter(getline(1, '$'), (_, l) => l !~ '^JJ:')
  while !empty(lines) && lines[-1] =~ '^\s*$'
    remove(lines, -1)
  endwhile
  var buf = bufnr()
  var OnSaved: func = b:vv_on_saved
  # Clear 'modified' now so :wq can close the window before jj finishes.
  setlocal nomodified
  # The change id (not the commit id) is the target, so repeated :w keeps
  # rewriting the same change instead of a stale, hidden commit.
  vv.Run(b:vv_root, ['describe', '-r', b:vv_rev.rev, '--stdin'], (_) => {
    if OnSaved != null_function
      OnSaved()
    endif
  }, empty(lines) ? [''] : lines)
enddef
