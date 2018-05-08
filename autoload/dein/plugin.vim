"=============================================================================
" FILE: plugin.vim
" AUTHOR:  Yanfei Guo <yanf.guo at gmail.com>
" License: MIT license
"=============================================================================

function! s:default_post_add_hook() abort
  return
endfunction

function! s:default_pre_source_hook() abort
  " echom expand('<sfile>').' pre_source_hook'
  return
endfunction

function! s:default_post_source_hook() abort
  " echom expand('<sfile>').' post_source_hook'
  return
endfunction

function! s:default_post_update_hook() abort
  return
endfunction

let s:hooks_template = {
      \ 'post_add' : function('s:default_post_add_hook'),
      \ 'pre_source' : function('s:default_pre_source_hook'),
      \ 'post_source' : function('s:default_post_source_hook'),
      \ 'post_update' : function('s:default_post_update_hook'),
      \ }

let s:plugin_options_template = {
      \ 'normalized_name' : '',
      \ }

let s:plugin_template = {
      \ 'name' : '',
      \ 'new' : 1,
      \ 'normalized_name' : '',
      \ 'path' : '',
      \ 'local' : 0,
      \ 'script_type' : '',
      \ 'type' : 'none',
      \ 'vcs' : {'rev' : '', 'frozen' : 0, 'timeout' : 60},
      \ 'rtp' : '',
      \ 'if' : 1,
      \ 'trusted' : 0,
      \ 'merged' : 0,
      \ 'sourced' : 0,
      \ 'depends' : [],
      \ 'orig_opts' : {},
      \ 'hooks' : deepcopy(s:hooks_template),
      \ }

let s:git = dein#types#git#define()

let g:dein#plugin#lazy_options = [
      \ 'on_ft', 'on_path', 'on_cmd', 'on_func', 'on_map',
      \ 'on_source', 'on_event',
      \ ]

function! s:is_lazy(options) abort
  for l:opt in g:dein#plugin#lazy_options
    if has_key(a:options, l:opt)
      return 1
    endif
  endfor
  return 0
endfunction

function! dein#plugin#add(repo, options) abort
  let plugin = dein#plugin#new(a:repo, a:options)

  call s:set_options(plugin, a:options)
  if (has_key(g:dein#_plugins, plugin.name)
        \ && g:dein#_plugins[plugin.name].sourced)
        " \ || !get(plugin, 'if', 1)
    " Skip already loaded or not enabled plugin.
    " call dein#util#_error('Plugin '.plugin.name.' skipped because it is already loaded or disabled')
    return {}
  endif

  if plugin.lazy && plugin.rtp !=# ''
    call s:set_lazy_handler(plugin, a:options)
  endif

  let g:dein#_plugins[plugin.name] = plugin
  call dein#plugin#call_hook(plugin, 'post_add')

  return plugin
endfunction

function! dein#plugin#new(repo, options) abort
  let repo = dein#util#expand_path(a:repo)
  let new_plugin = deepcopy(s:plugin_template)

  let l:git_type = s:git.init(a:repo, {})
  if !empty(git_type)
    let new_plugin.repo = a:repo
    let new_plugin.name = s:repo_to_name(a:repo)
    let new_plugin.type = l:git_type.type
    let new_plugin.path = dein#util#_chomp(l:git_type.path)
    let new_plugin.local = l:git_type.local
  else
    call dein#util#_error('Unsupported plugin repo type')
    return {}
  endif

  if has_key(a:options, 'build')
    let new_plugin['build'] = deepcopy(a:options.build)
  endif

  if has_key(a:options, 'rev')
    let new_plugin.vcs.rev = a:options.rev
  endif

  if has_key(a:options, 'frozen')
    let new_plugin.vcs.frozen = a:options.frozen
  endif

  return new_plugin
endfunction

function! dein#plugin#set_hook(name, hook_name, hook_func)
  if !has_key(g:dein#_plugins, a:name)
    " echo printf('Plugin %s not registered.', a:name)
    return
  endif
  if type(a:hook_func) != v:t_func " if not funcref
    call dein#util#_error(printf('hook_func must be FuncRef.', string(a:hook_func)))
    return
  endif
  if has_key(s:hooks_template, a:hook_name)
    let g:dein#_plugins[a:name].hooks[a:hook_name] = a:hook_func
  else
    call dein#util#_error(printf('Invalid hook name %s.', a:hook_name))
  endif
endfunction

function! s:set_options(plugin, options) abort
  if !has_key(a:plugin, 'path')
    call dein#util#_error('Plugin '.a:plugin.name.' does not have a path.')
    " let plugin.path = (plugin.repo =~# '^/\|^\a:[/\\]') ?
    "             \ plugin.repo : dein#util#_get_base_path().'/repos/'.plugin.name
    " let plugin.path = dein#util#_chomp(plugin.path)
  endif

  let a:plugin.normalized_name = get(a:options, 'normalized_name',
        \ s:normalize(a:plugin.name))

  let a:plugin.trusted = get(a:options, 'trusted', 0)

  if (!g:dein#_is_sudo || get(a:plugin, 'trusted', 0))
        \ && a:plugin.rtp !~# '^\%([~/]\|\a\+:\)'
    let a:plugin.rtp = dein#util#_chomp(
          \ dein#util#expand_path(a:plugin.path.'/'.a:plugin.rtp)
          \ )
  endif

  if has_key(a:options, 'script_type')
    let a:plugin.script_type = a:options.script_type
  endif

  if has_key(a:options, 'depends')
    call extend(a:plugin.depends, a:options.depends)
  endif

  if has_key(a:options, 'if')
    let a:plugin.if = a:options.if
  endif

  if !has_key(a:options, 'lazy')
    let a:plugin.lazy = s:is_lazy(a:options)
  else
    let a:plugin.lazy = a:options.lazy
  endif

  if has_key(a:options, 'merged')
    if a:plugins.lazy && a:options.merged
      call dein#util#_error('Cannot merge a lazy-load plugin.')
    else 
      let a:plugin.merged = a:options.merged
    endif
  endif
endfunction

function! s:set_lazy_handler(plugin, options) abort
  for key in g:dein#plugin#lazy_options
    if has_key(a:options, key)
      let a:plugin[key] = deepcopy(a:options[key])
    endif
  endfor

  if has_key(a:options, 'on_event')
    for event in a:options.on_event
      if !has_key(g:dein#_event_plugins, event)
        let g:dein#_event_plugins[event] = [a:plugin.name]
      else
        call add(g:dein#_event_plugins[event], a:plugin.name)
        let g:dein#_event_plugins[event] = dein#util#_uniq(
              \ g:dein#_event_plugins[event])
      endif
    endfor
  endif

  if has_key(a:options, 'on_cmd')
    call s:generate_dummy_commands(a:plugin, a:options)
  endif

  if has_key(a:options, 'on_map')
    call s:generate_dummy_mappings(a:plugin, a:options)
  endif
endfunction

function! s:generate_dummy_commands(plugin, options) abort
  let a:plugin.dummy_commands = []
  for name in a:options.on_cmd
    " Define dummy commands.
    let raw_cmd = 'command '
          \ . '-complete=customlist,dein#autoload#_dummy_complete'
          \ . ' -bang -bar -range -nargs=* '. name
          \ . printf(" call dein#autoload#_on_cmd(%s, %s, <q-args>,
          \  expand('<bang>'), expand('<line1>'), expand('<line2>'))",
          \   string(name), string(a:plugin.name))

    call add(a:plugin.dummy_commands, [name, raw_cmd])
    silent! execute raw_cmd
  endfor
endfunction

function! s:generate_dummy_mappings(plugin, options) abort
  let a:plugin.dummy_mappings = []
  let items = type(a:options.on_map) == v:t_dict ?
        \ map(items(a:options.on_map),
        \   "[split(v:val[0], '\\zs'), dein#util#_convert2list(v:val[1])]") :
        \ map(copy(a:options.on_map),
        \  "type(v:val) == v:t_list ?
        \     [split(v:val[0], '\\zs'), v:val[1:]] :
        \     [['n', 'x'], [v:val]]")
  for [modes, mappings] in items
    if mappings ==# ['<Plug>']
      " Use plugin name.
      let mappings = ['<Plug>(' . a:plugin.normalized_name]
      if stridx(a:plugin.normalized_name, '-') >= 0
        " The plugin mappings may use "_" instead of "-".
        call add(mappings, '<Plug>(' .
              \ substitute(a:plugin.normalized_name, '-', '_', 'g'))
      endif
    endif

    for mapping in mappings
      " Define dummy mappings.
      let prefix = printf('dein#autoload#_on_map(%s, %s,',
            \ string(substitute(mapping, '<', '<lt>', 'g')),
            \ string(a:plugin.name))
      for mode in modes
        let raw_map = mode.'noremap <unique><silent> '.mapping
              \ . (mode ==# 'c' ? " \<C-r>=" :
              \    mode ==# 'i' ? " \<C-o>:call " : " :\<C-u>call ") . prefix
              \ . string(mode) . ')<CR>'
        call add(a:plugin.dummy_mappings, [mode, mapping, raw_map])
        silent! execute raw_map
      endfor
    endfor
  endfor
endfunction

function! dein#plugin#call_hook(plugins, hook) abort
  if type(a:plugins) == v:t_dict
    let l:p = a:plugins
  elseif type(a:plugins) == v:t_list
    call dein#util#_error('call hook a:plugins is list')
  else
    call dein#util#_error('Wrong type of a:plugins')
  endif

  try
    " let g:dein#plugin = a:plugins

    " if type(a:hook) == v:t_string
    "     call s:execute(a:hook)
    " else
    call call(l:p.hooks[a:hook], [])
    " endif
  catch
    call dein#util#_error(
          \ 'Error occurred while executing hook: ' .
          \ get(l:p, 'name', ''))
    call dein#util#_error(v:exception)
  endtry
endfunction

" function! s:execute(expr) abort
"     if has('nvim') && s:neovim_version() >= 0.2.0
"         return execute(split(a:expr, '\n'))
"     endif

"     let dummy = '_dein_dummy_' .
"                 \ substitute(reltimestr(reltime()), '\W', '_', 'g')
"     execute 'function! '.dummy."() abort\n"
"                 \ . a:expr . "\nendfunction"
"     call {dummy}()
"     execute 'delfunction' dummy
" endfunction

function! dein#plugin#load_all() abort
  if !has('vim_starting')
    call dein#source(filter(values(g:dein#_plugins),
          \ {k, v -> v.lazy && !v.sourced && v.rtp !=# ''}))
  endif

  let sourced = []
  for plugin in filter(values(g:dein#_plugins),
        \ {k, v -> !v.lazy && v.rtp !=# ''})
    call dein#plugin#source(plugin, sourced)
  endfor
  call dein#rtp#commit()

  call dein#util#_check_vimrcs()

  for [event, plugins] in filter(items(g:dein#_event_plugins),
        \ {k, v -> exists('##' . v[0])})
    execute printf('autocmd dein-events %s * call '
          \. 'dein#autoload#_on_event("%s", %s)',
          \ event, event, string(plugins))
  endfor

  call dein#plugin#post_source(sourced)
endfunction

function! dein#plugin#post_source(plugins)
  for plugin in a:plugins
    call dein#plugin#call_hook(plugin, 'post_source')
  endfor
endfunction

function! dein#plugin#source(plugin, sourced) abort
  if a:plugin.sourced || index(a:sourced, a:plugin) >= 0
    return
  endif
  " echom 'load '.a:plugin.name

  if !eval(a:plugin.if)
    return
  endif

  " Load dependencies
  for name in get(a:plugin, 'depends', [])
    if !has_key(g:dein#_plugins, name)
      call dein#util#_error(printf(
            \ 'Plugin name "%s" is not found.', name))
      continue
    endif

    if !a:plugin.lazy && g:dein#_plugins[name].lazy
      call dein#util#_error(printf(
            \ 'Not lazy plugin "%s" depends lazy "%s" plugin.',
            \ a:plugin.name, name))
      " continue
    endif

    " echom 'load dependency '.name
    call dein#plugin#source(g:dein#_plugins[name], a:sourced)
  endfor

  call dein#plugin#call_hook(a:plugin, 'pre_source')

  if !a:plugin.merged || a:plugin.local
    call dein#rtp#insert(a:plugin.rtp)
  endif

  let a:plugin.sourced = 1
  call add(a:sourced, a:plugin)

  for on_source in filter(dein#util#_get_lazy_plugins(),
        \ "index(get(v:val, 'on_source', []), a:plugin.name) >= 0")
    call dein#plugin#source(on_source, a:sourced)
  endfor

  if has_key(a:plugin, 'dummy_commands')
    for command in a:plugin.dummy_commands
      silent! execute 'delcommand' command[0]
    endfor
    let a:plugin.dummy_commands = []
  endif

  if has_key(a:plugin, 'dummy_mappings')
    for map in a:plugin.dummy_mappings
      silent! execute map[0].'unmap' map[1]
    endfor
    let a:plugin.dummy_mappings = []
  endif
endfunction

function! s:repo_to_name(path) abort
  return fnamemodify(get(split(a:path, ':'), -1, ''),
        \ ':s?/$??:t:s?\c\.git\s*$??')
endfunction

function! s:normalize(name) abort
  return substitute(
        \ fnamemodify(a:name, ':r'),
        \ '\c^n\?vim[_-]\|[_-]n\?vim$', '', 'g')
endfunction

" vim: sw=2:ts=2:sts=2:
