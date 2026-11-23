" Vim syntax file
" Language:    powwow / powxel definition files (*.pow)
" The filetype comes from lua/config/options.lua (vim.filetype.add).
" Colours come from links to the standard groups, so any colour scheme works.

if exists('b:current_syntax')
  finish
endif

syn case match

" Commands
syn match powCommand    /#[a-z][a-z-]*/ nextgroup=powBindName,powActionLabel skipwhite
syn match powCommand    /#savefile-version/

" Section headers (after the commands, so they win): #("=====> DIRS ") and #print > Loading ...
syn match powHeader     /^\s*#(\s*".*")\s*$/
syn match powHeader     /^\s*#print\s\+>.*$/

" #bind NAME ^[Ox=...  and  #bi f1=...
syn match powBindName   /\%(#bi\%(nd\)\?\s\+\)\@<=[A-Za-z0-9_+-]\+/ contained nextgroup=powSequence skipwhite
syn match powSequence   /[^ =]\+\ze=/ contained contains=powControl
" Control characters anywhere: ^[ ^M ^? ...
syn match powControl    /\^[A-Z\[\\\]^_?@]/

" #action >+label pattern=...  (> on, < off, + and - flags)
syn match powActionLabel /[<>=%][+-]\?[A-Za-z0-9_]\+/ contained

" Variables and placeholders: $tt @n $0 $(1) @(2) %(...) &1
syn match powVariable   /[$@][A-Za-z_][A-Za-z0-9_]*/
syn match powParam      /[$@]\d\+/
syn match powParam      /[$@%](/me=e-1
syn match powParam      /&\d/

" Line editing functions in bindings: &del-char-left, &enter-line
syn match powEditFn     /&[a-z][a-z-]\+/

" Strings, numbers, structure
syn region powString    start=/"/ skip=/\\./ end=/"/ contains=powControl
syn match powNumber     /\<\d\+\>/
syn match powDelimiter  /[{};]/
syn match powOperator   /==\|!=\|<=\|>=\|&&\|||\|[=+*\/]/

" Colours in #mark and #hilite: =bold red
syn keyword powAttribute bold underline blink inverse reverse normal
syn keyword powColor     black red green yellow blue magenta cyan white

hi def link powHeader      Title
hi def link powCommand     Statement
hi def link powBindName    Type
hi def link powSequence    Special
hi def link powControl     SpecialChar
hi def link powActionLabel Label
hi def link powVariable    Identifier
hi def link powParam       PreProc
hi def link powEditFn      Function
hi def link powString      String
hi def link powNumber      Number
hi def link powDelimiter   Delimiter
hi def link powOperator    Operator
hi def link powAttribute   Constant
hi def link powColor       Constant

let b:current_syntax = 'pow'
