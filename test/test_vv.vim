vim9script
# Tests for vv. Run via test/run.sh, which sets up a repo with commits
# "first" <- "second" <- "third" (@).

import autoload 'vv/log.vim'

var failures: list<string> = []

def WaitFor(Cond: func(): bool, what: string)
  for _ in range(300)
    if Cond()
      return
    endif
    sleep 10m
  endfor
  add(failures, 'timed out waiting for: ' .. what)
enddef

def Jj(args: string): list<string>
  return systemlist('jj --no-pager --color=never ' .. args)
enddef

def Descriptions(): list<string>
  return Jj('log --no-graph -r "all() ~ root()" -T "description.first_line() ++ \"\n\""')
enddef

# Go to the log window and wait for a fresh render (b:vv_generation bumps on
# every draw), so assertions never see stale state.
def Log()
  VVLog
  # Job callbacks only run while sleeping, so the draw hasn't happened yet.
  var gen = get(b:, 'vv_generation', 0)
  WaitFor(() => get(b:, 'vv_generation', 0) > gen, 'log render')
enddef

def FindLine(pat: string): number
  return search(pat, 'w')
enddef

def Check(name: string, F: func())
  v:errors = []
  try
    F()
  catch
    add(v:errors, v:exception .. ' @ ' .. v:throwpoint)
  endtry
  for e in v:errors
    add(failures, name .. ': ' .. e)
  endfor
enddef

# --- log view -------------------------------------------------------------

Check('log renders', () => {
  edit c.txt
  Log()
  assert_equal('vvlog', &filetype)
  assert_true(log.Current().wc, 'cursor should start on @')
  assert_true(FindLine('third') > 0)
  assert_true(FindLine('second') > 0)
  assert_true(FindLine('first') > 0)
  assert_equal(-1, stridx(join(getline(1, '$')), "\x1f"), 'separator leaked into buffer')
})

Check('lines map to revisions', () => {
  FindLine('third')
  normal! k
  var c = log.Current()
  assert_true(c.wc)
  assert_true(c.node)
  # The description line below the node maps to the same revision.
  normal! j
  assert_equal(c.change, log.Current().change)
  assert_false(log.Current().node)
})

# --- describe -------------------------------------------------------------

Check('describe via :w', () => {
  FindLine('second')
  var change = log.Current().change
  log.Describe()
  assert_equal('jjdescription', &filetype)
  assert_equal('second', getline(1))
  setline(1, 'second, reworded')
  write
  WaitFor(() => index(Descriptions(), 'second, reworded') >= 0, 'describe')
  close
  Log()
  assert_true(FindLine('reworded') > 0)
})

# --- rebase ---------------------------------------------------------------

Check('move revision before another', () => {
  FindLine('third')
  log.Mark(false)
  FindLine('first')
  log.Move('before')
  WaitFor(() => Descriptions() == ['second, reworded', 'first', 'third'], 'rebase')
  WaitFor(() => empty(b:vv_mark), 'mark cleared')
})

Check('undo restores order', () => {
  log.Undo()
  WaitFor(() => Descriptions() == ['third', 'second, reworded', 'first'], 'undo')
  Log()
})

# --- diff -----------------------------------------------------------------

Check('diff opens in detail window', () => {
  FindLine('first')
  var logwin = win_getid()
  log.ShowDiff(false)
  assert_equal(logwin, win_getid(), 'preview should keep focus on log')
  log.ShowDiff(true)
  assert_equal('diff', &filetype)
  WaitFor(() => search('^diff --git a/a.txt', 'w') > 0, 'diff content')
  # Showing another revision reuses the same window.
  var detail = win_getid()
  wincmd p
  FindLine('second')
  log.ShowDiff(true)
  assert_equal(detail, win_getid())
  WaitFor(() => search('^diff --git a/b.txt', 'w') > 0, 'second diff content')
})

# :echo is swallowed in silent Ex mode, so write results to stdout.
if empty(failures)
  writefile(['all tests passed'], '/dev/stdout')
  qall!
else
  writefile(failures, '/dev/stdout')
  cquit!
endif
