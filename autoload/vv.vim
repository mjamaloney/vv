vim9script
# Core helpers shared by every vv module: locating the repo and running jj.

const BASE = ['jj', '--no-pager', '--color=never']

# Return the root of the jj repo containing the current buffer (or cwd), or ''.
export def Root(): string
  if exists('b:vv_root')
    return b:vv_root
  endif
  var dir = expand('%:p:h')
  if dir == '' || !isdirectory(dir)
    dir = getcwd()
  endif
  var found = finddir('.jj', dir .. ';')
  if found == ''
    return ''
  endif
  # :p gives ".../.jj/", :h strips the slash, :h again strips ".jj".
  return fnamemodify(found, ':p:h:h')
enddef

export def Error(msg: any)
  var lines = type(msg) == v:t_list ? msg : split(msg, "\n")
  echohl ErrorMsg
  for line in lines
    echomsg 'vv: ' .. line
  endfor
  echohl None
enddef

# Run jj synchronously. Throws "vv: <stderr>" on failure.
export def Sync(root: string, args: list<string>): list<string>
  var cmd = join(mapnew(BASE + ['-R', root] + args, (_, a) => shellescape(a)), ' ')
  var out = systemlist(cmd)
  if v:shell_error != 0
    throw 'vv: ' .. join(out, "\n")
  endif
  return out
enddef

# Run jj asynchronously. OnDone(stdout_lines) is called only on success; on
# failure stderr is reported. `input` is written to stdin if non-empty.
export def Run(root: string, args: list<string>, OnDone: func = null_function, input: list<string> = [])
  var state = {out: [], err: [], status: -1, closed: false}
  var job = job_start(BASE + args, {
    cwd: root,
    in_io: empty(input) ? 'null' : 'pipe',
    out_cb: (_, msg) => add(state.out, msg),
    err_cb: (_, msg) => add(state.err, msg),
    exit_cb: (_, status) => {
      state.status = status
      Finish(state, OnDone)
    },
    close_cb: (_) => {
      state.closed = true
      Finish(state, OnDone)
    },
  })
  if job_status(job) == 'fail'
    Error('could not start jj')
    return
  endif
  if !empty(input)
    var ch = job_getchannel(job)
    ch_sendraw(ch, join(input, "\n") .. "\n")
    ch_close_in(ch)
  endif
enddef

# exit_cb and close_cb can arrive in either order; act once both have.
def Finish(state: dict<any>, OnDone: func)
  if state.status < 0 || !state.closed
    return
  endif
  if state.status != 0
    Error(state.err)
    return
  endif
  # jj reports what it did on stderr ("Rebased 1 commits ..."); surface it.
  if !empty(state.err)
    echo state.err[-1]
  endif
  if OnDone != null_function
    OnDone(state.out)
  endif
enddef
