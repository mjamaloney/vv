vim9script
# The log view: the hub every other feature is driven from.

import autoload 'vv.vim'
import autoload 'vv/diff.vim'
import autoload 'vv/describe.vim'
import autoload 'vv/rebase.vim'

const SEP = "\x1f"

# Each node line is emitted as SEP-separated fields that Parse() turns back
# into display text + text properties. The full ids never reach the buffer.
const FIELDS = [
  'change_id',
  'commit_id',
  'if(current_working_copy, "@")',
  'if(divergent, "divergent")',
  'change_id.shortest(8).prefix()',
  'change_id.shortest(8).rest()',
  'author.email().local()',
  'committer.timestamp().ago()',
  'separate(" ", bookmarks, tags, working_copies)',
  'separate(" ", if(conflict, "conflict"), if(empty, "(empty)"), if(divergent, "divergent"), if(hidden, "hidden"))',
  'commit_id.shortest(8).prefix()',
  'commit_id.shortest(8).rest()',
]
const TEMPLATE = '"\x1f" ++ ' .. join(FIELDS, ' ++ "\x1f" ++ ')
  .. ' ++ "\n" ++ if(description, description.first_line(), "(no description set)") ++ "\n"'

const PROP_TYPES = ['VVChangePrefix', 'VVChangeRest', 'VVAuthor', 'VVTime',
  'VVRefs', 'VVFlags', 'VVCommitPrefix', 'VVCommitRest']
for name in PROP_TYPES
  if empty(prop_type_get(name))
    prop_type_add(name, {highlight: name})
  endif
endfor
if empty(prop_type_get('VVMark'))
  prop_type_add('VVMark', {highlight: 'VVMark', priority: -10})
endif

var log_bufs: dict<number> = {}

# ---------------------------------------------------------------------------
# Opening and rendering

export def Open(revset: string = '')
  var root = vv.Root()
  if root == ''
    vv.Error('not inside a jj repository')
    return
  endif
  var buf = get(log_bufs, root, -1)
  if buf != -1 && bufexists(buf)
    var win = bufwinid(buf)
    if win != -1
      win_gotoid(win)
    else
      execute get(g:, 'vv_log_split', 'topleft split') .. ' | buffer ' .. buf
    endif
  else
    execute get(g:, 'vv_log_split', 'topleft split') .. ' | enew'
    buf = bufnr()
    log_bufs[root] = buf
    silent! execute 'file ' .. fnameescape('vv://log' .. root)
    setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted nomodifiable
    b:vv_root = root
    b:vv_revset = ''
    b:vv_ids = []
    b:vv_mark = {}
    setlocal filetype=vvlog
  endif
  if revset != ''
    b:vv_revset = revset
  endif
  Refresh(buf)
enddef

export def Refresh(buf: number = bufnr())
  if !bufexists(buf)
    return
  endif
  var root: string = getbufvar(buf, 'vv_root')
  var revset: string = getbufvar(buf, 'vv_revset')
  var args = ['log', '-T', TEMPLATE] + (revset == '' ? [] : ['-r', revset])
  vv.Run(root, args, (out) => Draw(buf, out))
enddef

# Turn raw `jj log` output into display lines, per-line revision info and
# text properties.
def Parse(raw: list<string>): dict<any>
  var text: list<string> = []
  var ids: list<dict<any>> = []
  var props: list<list<any>> = []
  var current: dict<any> = {}
  for line in raw
    var i = stridx(line, SEP)
    if i < 0
      # Description, edge or elision line: belongs to the node above it.
      add(text, line)
      add(ids, current)
      continue
    endif
    var f = split(strpart(line, i + 1), SEP, true)
    current = {
      change: f[0],
      commit: f[1],
      wc: f[2] == '@',
      # Divergent change ids are ambiguous; fall back to the commit id.
      rev: f[3] == '' ? f[0] : f[1],
      node: true,
    }
    var segs: list<list<string>> = [[f[4], 'VVChangePrefix'], [f[5], 'VVChangeRest']]
    for [txt, hl] in [[f[6], 'VVAuthor'], [f[7], 'VVTime'], [f[8], 'VVRefs'], [f[9], 'VVFlags']]
      if txt != ''
        segs += [[' ', ''], [txt, hl]]
      endif
    endfor
    segs += [[' ', ''], [f[10], 'VVCommitPrefix'], [f[11], 'VVCommitRest']]
    var out = strpart(line, 0, i)
    var lnum = len(text) + 1
    for [txt, hl] in segs
      if hl != '' && txt != ''
        add(props, [lnum, len(out) + 1, len(txt), hl])
      endif
      out ..= txt
    endfor
    add(text, out)
    add(ids, current)
  endfor
  # Lines after the first node line of an entry are not nodes themselves.
  ids = mapnew(ids, (idx, d) => idx > 0 && ids[idx - 1] is d ? extendnew(d, {node: false}) : d)
  return {text: text, ids: ids, props: props}
enddef

def Draw(buf: number, raw: list<string>)
  if !bufexists(buf)
    return
  endif
  var win = bufwinid(buf)
  var old_ids: list<dict<any>> = getbufvar(buf, 'vv_ids', [])
  var keep = ''
  if win != -1
    keep = get(get(old_ids, line('.', win) - 1, {}), 'change', '')
  endif

  var p = Parse(raw)
  setbufvar(buf, '&modifiable', 1)
  silent deletebufline(buf, 1, '$')
  setbufline(buf, 1, p.text)
  for [lnum, col, length, type] in p.props
    prop_add(lnum, col, {bufnr: buf, length: length, type: type})
  endfor
  var mark: dict<any> = getbufvar(buf, 'vv_mark', {})
  if !empty(mark)
    var lnum = FindNode(p.ids, (d: dict<any>): bool => d.change == mark.change)
    if lnum > 0
      prop_add(lnum, 1, {bufnr: buf, length: len(p.text[lnum - 1]), type: 'VVMark'})
    endif
  endif
  setbufvar(buf, '&modifiable', 0)
  setbufvar(buf, 'vv_ids', p.ids)
  setbufvar(buf, 'vv_generation', getbufvar(buf, 'vv_generation', 0) + 1)

  if win != -1
    # Stay on the same change (ids survive rewrites); otherwise go to @.
    var lnum = keep == '' ? 0 : FindNode(p.ids, (d: dict<any>): bool => d.change == keep)
    if lnum == 0
      lnum = FindNode(p.ids, (d: dict<any>): bool => d.wc)
    endif
    if lnum > 0
      win_execute(win, 'cursor(' .. lnum .. ', 1)')
    endif
  endif
enddef

def FindNode(ids: list<dict<any>>, Pred: func(dict<any>): bool): number
  for i in range(len(ids))
    if get(ids[i], 'node', false) && Pred(ids[i])
      return i + 1
    endif
  endfor
  return 0
enddef

# ---------------------------------------------------------------------------
# Cursor helpers

# The revision under the cursor: {change, commit, rev, wc, node}, or {}.
export def Current(): dict<any>
  var d: dict<any> = get(b:vv_ids, line('.') - 1, {})
  if empty(d)
    vv.Error('no revision on this line')
  endif
  return d
enddef

# Jump to the next (dir=1) or previous (dir=-1) revision node.
export def Jump(dir: number)
  var lnum = line('.') + dir
  while lnum >= 1 && lnum <= line('$')
    if get(get(b:vv_ids, lnum - 1, {}), 'node', false)
      cursor(lnum, 1)
      return
    endif
    lnum += dir
  endwhile
enddef

# Run a mutating jj command, then refresh the log and reload changed files.
def Mutate(args: list<string>)
  var buf = bufnr()
  vv.Run(b:vv_root, args, (_) => AfterMutate(buf))
enddef

def AfterMutate(buf: number)
  Refresh(buf)
  silent! checktime
enddef

# ---------------------------------------------------------------------------
# Actions bound in ftplugin/vvlog.vim

export def ShowDiff(focus: bool)
  var c = Current()
  if !empty(c)
    diff.Show(b:vv_root, c, focus)
  endif
enddef

export def Describe()
  var c = Current()
  if !empty(c)
    var buf = bufnr()
    describe.Open(b:vv_root, c, () => Refresh(buf))
  endif
enddef

# Mark the revision under the cursor as the thing to move. `with_descendants`
# moves its descendants too (jj rebase -s instead of -r).
export def Mark(with_descendants: bool)
  var c = Current()
  if empty(c)
    return
  endif
  if !empty(b:vv_mark) && b:vv_mark.change == c.change && b:vv_mark.descendants == with_descendants
    b:vv_mark = {}
  else
    b:vv_mark = extendnew(c, {descendants: with_descendants})
  endif
  Refresh()
enddef

# Move the marked revision relative to the one under the cursor.
# where: 'after' | 'before' | 'onto'
export def Move(where: string)
  if empty(b:vv_mark)
    vv.Error('nothing marked (use m or M first)')
    return
  endif
  var c = Current()
  if empty(c)
    return
  endif
  var mark = b:vv_mark
  b:vv_mark = {}
  Mutate(rebase.Args(mark, c, where))
enddef

export def Squash()
  var c = Current()
  if !empty(c)
    Mutate(['squash', '-r', c.rev])
  endif
enddef

export def New()
  var c = Current()
  if !empty(c)
    Mutate(['new', c.rev])
  endif
enddef

export def Edit()
  var c = Current()
  if !empty(c)
    Mutate(['edit', c.rev])
  endif
enddef

export def Abandon()
  var c = Current()
  if !empty(c) && confirm('Abandon ' .. c.change[: 7] .. '?', "&Yes\n&No", 2) == 1
    Mutate(['abandon', c.rev])
  endif
enddef

export def Undo()
  Mutate(['undo'])
enddef

export def Help()
  popup_create([
    '<CR>    show diff (focus it)',
    'p       preview diff (stay here)',
    'e       edit description',
    'm / M   mark revision / revision + descendants',
    'a b o   move marked: after / before / onto this',
    's       squash into parent',
    'n       new change on top of this',
    'E       edit (check out) this revision',
    'X       abandon',
    'u       jj undo',
    'R       refresh',
    'C-n C-p next / previous revision',
    'q       close',
  ], {
    title: ' vv ',
    border: [],
    padding: [0, 1, 0, 1],
    pos: 'center',
    filter: (id, _) => {
      popup_close(id)
      return true
    },
  })
enddef
