vim9script
# Rearranging revisions: build the `jj rebase` invocation for a move.

const WHERE = {after: '-A', before: '-B', onto: '-o'}

# mark: the marked revision (with .descendants), target: revision under cursor.
export def Args(mark: dict<any>, target: dict<any>, where: string): list<string>
  return ['rebase', mark.descendants ? '-s' : '-r', mark.rev, WHERE[where], target.rev]
enddef
