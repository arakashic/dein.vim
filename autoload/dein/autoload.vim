"=============================================================================
" FILE: autoload.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

function! dein#autoload#_source(...) abort
  let plugins = empty(a:000) ? values(g:dein#_plugins) :
        \ dein#util#_convert2list(a:1)
  if empty(plugins)
    return
  endif

  if type(plugins[0]) != v:t_dict
    let plugins = map(dein#util#_convert2list(a:1),
          \       'get(g:dein#_plugins, v:val, {})')
  endif

  let sourced = []
  for plugin in filter(plugins,
        \ {k, v -> !empty(v) && !v.sourced && v.rtp !=# ''})
    call dein#plugin#source(plugin, sourced)
  endfor
  if empty(sourced)
    return sourced
  endif

  let filetype_before = dein#util#_redir('autocmd FileType')
  call dein#rtp#commit()

  " Reload script files.
  for plugin in sourced
    for directory in filter(['plugin', 'after/plugin'],
          \ "isdirectory(plugin.rtp.'/'.v:val)")
      for file in dein#util#_globlist(plugin.rtp.'/'.directory.'/**/*.vim')
        execute 'source' fnameescape(file)
      endfor
    endfor

    if !has('vim_starting')
      let augroup = get(plugin, 'augroup', plugin.normalized_name)
      if exists('#'.augroup.'#VimEnter')
        execute 'doautocmd' augroup 'VimEnter'
      endif
      if has('gui_running') && &term ==# 'builtin_gui'
            \ && exists('#'.augroup.'#GUIEnter')
        execute 'doautocmd' augroup 'GUIEnter'
      endif
      if exists('#'.augroup.'#BufRead')
        execute 'doautocmd' augroup 'BufRead'
      endif
    endif
  endfor

  let filetype_after = dein#util#_redir('autocmd FileType')

  let is_reset = s:is_reset_ftplugin(sourced)
  if is_reset
    call s:reset_ftplugin()
  endif

  if is_reset || filetype_before !=# filetype_after
    " Recall FileType autocmd
    let &filetype = &filetype
  endif

  call dein#plugin#post_source(sourced)
  return sourced
endfunction

function! dein#autoload#_on_default_event(event) abort
  let lazy_plugins = dein#util#_get_lazy_plugins()
  let plugins = []

  let path = expand('<afile>')
  " For ":edit ~".
  if fnamemodify(path, ':t') ==# '~'
    let path = '~'
  endif
  let path = dein#util#_expand(path)

  for filetype in split(&l:filetype, '\.')
    let plugins += filter(copy(lazy_plugins),
          \ "index(get(v:val, 'on_ft', []), filetype) >= 0")
  endfor

  let plugins += filter(copy(lazy_plugins),
        \ "!empty(filter(copy(get(v:val, 'on_path', [])),
        \                'path =~? v:val'))")
  let plugins += filter(copy(lazy_plugins),
        \ "!has_key(v:val, 'on_event')
        \  && has_key(v:val, 'on_if') && eval(v:val.on_if)")
  call s:source_events(a:event, plugins)
endfunction

function! dein#autoload#_on_event(event, plugins) abort
  let lazy_plugins = filter(dein#util#_get_plugins(a:plugins),
        \ '!v:val.sourced')
  if empty(lazy_plugins)
    execute 'autocmd! dein-events' a:event
    return
  endif

  let plugins = filter(copy(lazy_plugins),
        \ "!has_key(v:val, 'on_if') || eval(v:val.on_if)")
  call s:source_events(a:event, plugins)
endfunction

function! s:source_events(event, plugins) abort
  if empty(a:plugins)
    return
  endif

  let l:sourced = dein#autoload#_source(a:plugins)

  if a:event ==# 'InsertCharPre'
    " Queue this key again
    call feedkeys(v:char)
    let v:char = ''
  else
    if a:event ==# 'BufNew'
      " For BufReadCmd plugins
      doautocmd <nomodeline> BufReadCmd
    endif
    execute 'doautocmd <nomodeline>' a:event
  endif
endfunction

function! dein#autoload#_on_func(name) abort
  let function_prefix = substitute(a:name, '[^#]*$', '', '')
  if function_prefix =~# '^dein#'
        \ || function_prefix =~# '^vital#'
        \ || has('vim_starting')
    return
  endif

  call dein#autoload#_source(filter(dein#util#_get_lazy_plugins(),
        \  "stridx(function_prefix, v:val.normalized_name.'#') == 0
        \   || (index(get(v:val, 'on_func', []), a:name) >= 0)"))
endfunction

function! dein#autoload#_on_pre_cmd(name) abort
  call dein#autoload#_source(
        \ filter(dein#util#_get_lazy_plugins(),
        \ "index(map(copy(get(v:val, 'on_cmd', [])),
        \            'tolower(v:val)'), a:name) >= 0
        \  || stridx(tolower(a:name),
        \            substitute(tolower(v:val.normalized_name),
        \                       '[_-]', '', 'g')) == 0"))
endfunction

function! dein#autoload#_on_cmd(command, name, args, bang, line1, line2) abort
  let l:sourced = dein#autoload#_source(a:name)

  if empty(l:sourced)
    echo a:name.' is disabled'
    return
  endif

  if exists(':' . a:command) != 2
    call dein#util#_error(printf('command %s is not found.', a:command))
    return
  endif

  let range = (a:line1 == a:line2) ? '' :
        \ (a:line1 == line("'<") && a:line2 == line("'>")) ?
        \ "'<,'>" : a:line1.','.a:line2

  try
    execute range.a:command.a:bang a:args
  catch /^Vim\%((\a\+)\)\=:E481/
    " E481: No range allowed
    execute a:command.a:bang a:args
  endtry
endfunction

function! dein#autoload#_on_map(mapping, name, mode) abort
  let cnt = v:count > 0 ? v:count : ''

  let input = s:get_input()

  call dein#autoload#_source(a:name)

  if a:mode ==# 'v' || a:mode ==# 'x'
    call feedkeys('gv', 'n')
  elseif a:mode ==# 'o' && v:operator !=# 'c'
    " TODO: omap
    " v:prevcount?
    " Cancel waiting operator mode.
    call feedkeys(v:operator, 'm')
  endif

  call feedkeys(cnt, 'n')

  if a:mode ==# 'o' && v:operator ==# 'c'
    " Note: This is the dirty hack.
    execute matchstr(s:mapargrec(a:mapping . input, a:mode),
          \ ':<C-U>\zs.*\ze<CR>')
  else
    let mapping = a:mapping
    while mapping =~# '<[[:alnum:]_-]\+>'
      let mapping = substitute(mapping, '\c<Leader>',
            \ get(g:, 'mapleader', '\'), 'g')
      let mapping = substitute(mapping, '\c<LocalLeader>',
            \ get(g:, 'maplocalleader', '\'), 'g')
      let ctrl = matchstr(mapping, '<\zs[[:alnum:]_-]\+\ze>')
      execute 'let mapping = substitute(
            \ mapping, "<' . ctrl . '>", "\<' . ctrl . '>", "")'
    endwhile
    call feedkeys(mapping . input, 'm')
  endif

  return ''
endfunction

function! dein#autoload#_dummy_complete(arglead, cmdline, cursorpos) abort
  let command = matchstr(a:cmdline, '\h\w*')
  if exists(':'.command) == 2
    " Remove the dummy command.
    silent! execute 'delcommand' command
  endif

  " Load plugins
  call dein#autoload#_on_pre_cmd(tolower(command))

  if exists(':'.command) == 2
    " Print the candidates
    call feedkeys("\<C-d>", 'n')
  endif

  return [a:arglead]
endfunction

function! s:reset_ftplugin() abort
  let filetype_state = dein#util#_redir('filetype')

  if exists('b:did_indent') || exists('b:did_ftplugin')
    filetype plugin indent off
  endif

  if filetype_state =~# 'plugin:ON'
    silent! filetype plugin on
  endif

  if filetype_state =~# 'indent:ON'
    silent! filetype indent on
  endif
endfunction

function! s:get_input() abort
  let input = ''
  let termstr = '<M-_>'

  call feedkeys(termstr, 'n')

  while 1
    let char = getchar()
    let input .= (type(char) == v:t_number) ? nr2char(char) : char

    let idx = stridx(input, termstr)
    if idx >= 1
      let input = input[: idx - 1]
      break
    elseif idx == 0
      let input = ''
      break
    endif
  endwhile

  return input
endfunction

function! s:is_reset_ftplugin(plugins) abort
  if &filetype ==# ''
    return 0
  endif

  for plugin in a:plugins
    let ftplugin = plugin.rtp . '/ftplugin/' . &filetype
    let after = plugin.rtp . '/after/ftplugin/' . &filetype
    if !empty(filter(['ftplugin', 'indent',
          \ 'after/ftplugin', 'after/indent',],
          \ "filereadable(printf('%s/%s/%s.vim',
          \    plugin.rtp, v:val, &filetype))"))
          \ || isdirectory(ftplugin) || isdirectory(after)
          \ || glob(ftplugin. '_*.vim') !=# '' || glob(after . '_*.vim') !=# ''
      return 1
    endif
  endfor
  return 0
endfunction

function! s:mapargrec(map, mode) abort
  let arg = maparg(a:map, a:mode)
  while maparg(arg, a:mode) !=# ''
    let arg = maparg(arg, a:mode)
  endwhile
  return arg
endfunction

" vim: sw=2:ts=2:sts=2:
