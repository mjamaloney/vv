vim9script
# Syntax for the vv log buffer. Fields on node lines (ids, author, time,
# bookmarks) are highlighted with text properties in autoload/vv/log.vim;
# this file only covers the graph and description lines.

if exists('b:current_syntax')
  finish
endif

syntax match VVGraph /^[│├─╮╯╰╭┤┬┴┼|\\/ ]\+/
syntax match VVNodeWorkingCopy /^[│├─╮╯╰╭┤┬┴┼|\\/ ]*\zs@/
syntax match VVNodeImmutable /^[│├─╮╯╰╭┤┬┴┼|\\/ ]*\zs◆/
syntax match VVNodeConflict /^[│├─╮╯╰╭┤┬┴┼|\\/ ]*\zs×/
syntax match VVNode /^[│├─╮╯╰╭┤┬┴┼|\\/ ]*\zs[○◉●o]/
syntax match VVElided /(elided revisions)/
syntax match VVNoDescription /(no description set)$/

b:current_syntax = 'vvlog'
