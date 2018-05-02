"=============================================================================
" FILE: autoload.vim
" AUTHOR:  Yanfei Guo <yanf.guo at gmail.com>
" License: MIT license
"=============================================================================

let s:rtp_list = []
let s:insert_index = 0
let s:insert_after_index = 0

function! dein#rtp#init() abort
    if !has('vim_starting')
        execute 'set rtp-='.fnameescape(g:dein#_runtime_path)
        execute 'set rtp-='.fnameescape(g:dein#_runtime_path.'/after')
    endif

    let s:rtp_list = s:split_rtp(&runtimepath)
    let index = index(s:rtp_list, $VIMRUNTIME)
    if index < 0
        " call dein#util#print_data(s:rtp_list)
        echom g:dein#_runtime_path
        echom s:insert_index
        throw 'dein#rtp_list#init cannot find $VIMRUNTIME in rtp'
    endif

    if fnamemodify(g:dein#_base_path, ':t') ==# 'plugin'
                \ && index(s:rtp_list, fnamemodify(a:path, ':h')) >= 0
        call dein#util#_error('You must not set the installation directory'
                    \ .' under "&runtimepath/plugin"')
        return 1
    endif

    call insert(s:rtp_list, g:dein#_runtime_path, index)
    let &runtimepath = s:join_rtp(s:rtp_list, &runtimepath, g:dein#_runtime_path)

    " call dein#util#print_data(s:rtp_list)
    let s:insert_index = index(s:rtp_list, g:dein#_runtime_path)
    let s:insert_after_index = index(s:rtp_list, $VIMRUNTIME)
endfunction

function! dein#rtp#insert(rtp) abort
    if empty(s:rtp_list)
        throw 'dein#rtp_list#insert rtp_list uninitialized'
    endif
    call insert(s:rtp_list, a:rtp, s:insert_index)

    if isdirectory(a:rtp.'/after')
        call insert(s:rtp_list, a:rtp, (s:insert_after_index ? -1 : s:insert_after_index + 2))
    endif
endfunction

function! dein#rtp#commit() abort
    if empty(s:rtp_list)
        throw 'dein#rtp_list#insert rtp_list uninitialized'
    endif
    let &runtimepath = s:join_rtp(s:rtp_list, &runtimepath, '')
endfunction

function! dein#rtp#dedup() abort
    let &runtimepath = s:join_rtp(dein#util#_uniq(
                \ s:split_rtp(&runtimepath)), &runtimepath, '')
endfunction

function! s:split_rtp(runtimepath) abort
    if stridx(a:runtimepath, '\,') < 0
        return split(a:runtimepath, ',')
    endif

    let split = split(a:runtimepath, '\\\@<!\%(\\\\\)*\zs,')
    return map(split,'substitute(v:val, ''\\\([\\,]\)'', ''\1'', ''g'')')
endfunction

function! s:join_rtp(list, runtimepath, rtp) abort
    return (stridx(a:runtimepath, '\,') < 0 && stridx(a:rtp, ',') < 0) ?
                \ join(a:list, ',') : join(map(copy(a:list), {val -> s:escape(val)}), ',')
endfunction

function! s:escape(path) abort
    " Escape a path for runtimepath.
    return substitute(a:path, ',\|\\,\@=', '\\\0', 'g')
endfunction

