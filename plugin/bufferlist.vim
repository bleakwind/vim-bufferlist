" vim: set expandtab tabstop=4 softtabstop=4 shiftwidth=4: */
"
" +--------------------------------------------------------------------------+
" | $Id: bufferlist.vim 2025-07-10 02:30:17 Bleakwind Exp $                  |
" +--------------------------------------------------------------------------+
" | Copyright (c) 2008-2025 Bleakwind(Rick Wu).                              |
" +--------------------------------------------------------------------------+
" | This source file is bufferlist.vim.                                      |
" | This source file is release under BSD license.                           |
" +--------------------------------------------------------------------------+
" | Author: Bleakwind(Rick Wu) <bleakwind@qq.com>                            |
" +--------------------------------------------------------------------------+
"

if exists('g:bufferlist_plugin') || &compatible
    finish
endif
let g:bufferlist_plugin = 1

scriptencoding utf-8

let s:save_cpo = &cpoptions
set cpoptions&vim

" ============================================================================
" bufferlist setting
" ============================================================================
" public setting
let g:bufferlist_enabled        = get(g:, 'bufferlist_enabled',     0)
let g:bufferlist_position       = get(g:, 'bufferlist_position',    'top')
let g:bufferlist_winwidth       = get(g:, 'bufferlist_winwidth',    20)
let g:bufferlist_winheight      = get(g:, 'bufferlist_winheight',   1)
let g:bufferlist_horzsepar      = get(g:, 'bufferlist_horzsepar',   '|')
let g:bufferlist_modifmark      = get(g:, 'bufferlist_modifmark',   '[+]')

" tab color format - [dark cterm, dark gui, light cterm, light gui]
let g:bufferlist_defnor         = get(g:, 'bufferlist_defnor',      ['White',      '#FFFFFF', 'Black',      '#000000'])
let g:bufferlist_defmod         = get(g:, 'bufferlist_defmod',      ['LightRed',   '#F56C6C', 'LightRed',   '#D5393E'])
let g:bufferlist_curnor         = get(g:, 'bufferlist_curnor',      ['LightGreen', '#67C23A', 'LightGreen', '#18794E'])
let g:bufferlist_curmod         = get(g:, 'bufferlist_curmod',      ['LightRed',   '#E0575B', 'LightRed',   '#B8272C'])
let g:bufferlist_visnor         = get(g:, 'bufferlist_visnor',      ['LightGreen', '#67C23A', 'LightGreen', '#18794E'])
let g:bufferlist_vismod         = get(g:, 'bufferlist_vismod',      ['LightRed',   '#E0575B', 'LightRed',   '#B8272C'])
let g:bufferlist_sepnor         = get(g:, 'bufferlist_sepnor',      ['White',      '#AAAAAA', 'Black',      '#555555'])

" reopen file
let g:bufferlist_reopen         = get(g:, 'bufferlist_reopen',      0)
let g:bufferlist_filepath       = get(g:, 'bufferlist_filepath',    $HOME.'/.vim/bufferlist')

" plugin variable
let s:bufferlist_bufnbr         = -1
let s:bufferlist_winidn         = -1
let s:bufferlist_tabidx         = 0
let s:bufferlist_ifhorz         = 0
let s:bufferlist_untnum         = 0
let s:bufferlist_bufinf         = []
let s:bufferlist_hltdef         = []
let s:bufferlist_hltcur         = []
let s:bufferlist_hltvis         = []
let s:bufferlist_timertab       = -1
let s:bufferlist_timerbuf       = -1
let s:bufferlist_restover       = 0
let s:bufferlist_filelist       = g:bufferlist_filepath.'/filelist'
let s:bufferlist_filedata       = {}

" ============================================================================
" bufferlist detail
" g:bufferlist_enabled = 1
" ============================================================================
if exists('g:bufferlist_enabled') && g:bufferlist_enabled == 1

    " --------------------------------------------------
    " bufferlist#MixWhite
    " --------------------------------------------------
    function! bufferlist#MixWhite(color, alpha) abort
        let l:res_color = a:color
        if a:color =~? '^#[0-9a-fA-F]\{6}$' && a:alpha >= 0.0 && a:alpha <= 1.0
            let l:r = str2nr(a:color[1:2], 16)
            let l:g = str2nr(a:color[3:4], 16)
            let l:b = str2nr(a:color[5:6], 16)

            let l:mixed_r = float2nr(l:r * (1.0 - a:alpha) + 255 * a:alpha)
            let l:mixed_g = float2nr(l:g * (1.0 - a:alpha) + 255 * a:alpha)
            let l:mixed_b = float2nr(l:b * (1.0 - a:alpha) + 255 * a:alpha)

            let l:mixed_r = max([0, min([255, l:mixed_r])])
            let l:mixed_g = max([0, min([255, l:mixed_g])])
            let l:mixed_b = max([0, min([255, l:mixed_b])])

            let l:res_color = printf('#%02X%02X%02X', l:mixed_r, l:mixed_g, l:mixed_b)
        endif
        return l:res_color
    endfunction

    " --------------------------------------------------
    " bufferlist#CalcFg
    " --------------------------------------------------
    function! bufferlist#CalcFg(hex) abort
        let l:r = str2nr(a:hex[1:2], 16)
        let l:g = str2nr(a:hex[3:4], 16)
        let l:b = str2nr(a:hex[5:6], 16)
        let l:brightness = (0.299 * l:r + 0.587 * l:g + 0.114 * l:b) / 255
        return l:brightness > 0.5 ? 'Black' : 'White'
    endfunction

    " --------------------------------------------------
    " bufferlist#IsSpecial
    " --------------------------------------------------
    function! bufferlist#IsSpecial(...) abort
        let l:ret = 0
        if a:0 > 0
            let l:buftype = getbufvar(a:1, '&buftype')
            let l:ret = l:buftype != '' && l:buftype != 'help' ? 1 : 0
        endif
        return l:ret
    endfunction

    " --------------------------------------------------
    " bufferlist#TabCollect
    " --------------------------------------------------
    function! bufferlist#TabCollect(...) abort
        " set variable
        let s:bufferlist_ifhorz = g:bufferlist_position == 'top' || g:bufferlist_position == 'bottom' ? 1 : 0

        " check winidn
        if (s:bufferlist_bufnbr != -1 && bufexists(s:bufferlist_bufnbr) == 0) || (s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) == 0)
            let s:bufferlist_bufnbr = -1
            let s:bufferlist_winidn = -1
        endif

        " check bufferlist
        if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0

            " get message
            let l:orig_bufnbr = bufnr('%')
            let l:orig_bufinf = s:bufferlist_bufinf
            let s:bufferlist_bufinf = []

            " get buflist
            let l:buflst = filter(getbufinfo({'buflisted': 1}), '!bufferlist#IsSpecial(v:val.bufnr) && v:val.loaded')
            if !empty(l:buflst)
                for il in l:buflst
                    " ready value
                    let l:otabnm = get(filter(map(copy(l:orig_bufinf), 'v:val.bufnbr == il.bufnr ? v:val.tabnme : ""'), 'v:val != ""'), 0, '')
                    " set value
                    let l:bufnbr = il.bufnr
                    let l:bufnme = bufname(il.bufnr)
                    if empty(l:otabnm)
                        let s:bufferlist_untnum = s:bufferlist_untnum + 1
                        let l:tabnme = 'Untitled-'.s:bufferlist_untnum.''
                    elseif !filereadable(bufname(il.bufnr))
                        let l:tabnme = l:otabnm
                    else
                        let l:tabnme = fnamemodify(l:bufnme, ':t')
                    endif
                    let l:modify = getbufvar(il.bufnr, '&modified') ? g:bufferlist_modifmark : ''
                    let l:tabdat = ' '.l:tabnme.l:modify.' '
                    let l:active = il.bufnr == l:orig_bufnbr ? 1 : 0
                    let l:length = strlen(l:tabnme) + strlen(l:modify) + 2
                    let l:filepath = empty(l:bufnme) ? '' : fnamemodify(l:bufnme, ':p')
                    " set list
                    call add(s:bufferlist_bufinf, {
                                \     'bufnbr'   : l:bufnbr,
                                \     'bufnme'   : l:bufnme,
                                \     'tabnme'   : l:tabnme,
                                \     'modify'   : l:modify,
                                \     'tabdat'   : l:tabdat,
                                \     'active'   : l:active,
                                \     'length'   : l:length,
                                \     'filepath' : l:filepath
                                \ })
                endfor
            endif

            " back buffer
            if bufnr('%') != l:orig_bufnbr
                execute 'buffer '.l:orig_bufnbr
            endif
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#TabRender
    " --------------------------------------------------
    function! bufferlist#TabRender(...) abort
        " render highlight
        if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0

            " build tablist
            let l:lines = []
            if s:bufferlist_ifhorz
                call add(l:lines, join(map(copy(s:bufferlist_bufinf), {_, v -> v.tabdat}), g:bufferlist_horzsepar))
            else
                call extend(l:lines, map(copy(s:bufferlist_bufinf), {_, v -> v.tabdat}))
            endif

            " setbufvar bufferlist
            call setbufvar(s:bufferlist_bufnbr, '&modifiable', 1)
            silent! call deletebufline(s:bufferlist_bufnbr, 1, '$')
            silent! call setbufline(s:bufferlist_bufnbr, 1, l:lines)
            call setbufvar(s:bufferlist_bufnbr, '&modifiable', 0)
            call setbufvar(s:bufferlist_bufnbr, '&modified', 0)

            " clean match
            let l:orig_winidn = win_getid()
            call bufferlist#TabClean()

            " render tablist
            call win_gotoid(s:bufferlist_winidn)
            if !empty(s:bufferlist_bufinf) && s:bufferlist_ifhorz
                let l:pos = 1
                for il in range(len(s:bufferlist_bufinf))
                    let l:bufinf = s:bufferlist_bufinf[il]
                    let l:modify = !empty(l:bufinf.modify)
                    " hl leftsepar
                    if il > 0
                        let l:sep_pos = l:pos - strlen(g:bufferlist_horzsepar)
                        if il == s:bufferlist_tabidx || il - 1 == s:bufferlist_tabidx || l:bufinf.active || s:bufferlist_bufinf[il-1].active
                            let l:sep_match = matchaddpos('BufferlistSepmod', [[1, l:sep_pos, strlen(g:bufferlist_horzsepar)]], 0)
                        else
                            let l:sep_match = matchaddpos('BufferlistSepnor', [[1, l:sep_pos, strlen(g:bufferlist_horzsepar)]], 0)
                        endif
                        call add(s:bufferlist_hltdef, l:sep_match)
                    endif
                    " hl tabdat
                    if il == s:bufferlist_tabidx
                        " cur
                        let l:hl_group = l:modify ? 'BufferlistCurmod' : 'BufferlistCurnor'
                        let l:match_id = matchaddpos(l:hl_group, [[1, l:pos, l:bufinf.length]], 10)
                        call add(s:bufferlist_hltcur, l:match_id)
                        call cursor(1, l:pos)
                    elseif l:bufinf.active
                        " vis
                        let l:hl_group = l:modify ? 'BufferlistVismod' : 'BufferlistVisnor'
                        let l:match_id = matchaddpos(l:hl_group, [[1, l:pos, l:bufinf.length]], 5)
                        call add(s:bufferlist_hltvis, l:match_id)
                    else
                        " def
                        let l:hl_group = l:modify ? 'BufferlistDefmod' : 'BufferlistDefnor'
                        let l:match_id = matchaddpos(l:hl_group, [[1, l:pos, l:bufinf.length]], 1)
                        call add(s:bufferlist_hltdef, l:match_id)
                    endif
                    " hl rightsepar
                    if il < len(s:bufferlist_bufinf) - 1
                        let l:sep_pos = l:pos + l:bufinf.length
                        if il == s:bufferlist_tabidx || l:bufinf.active
                            let l:sep_match = matchaddpos('BufferlistSepmod', [[1, l:sep_pos, strlen(g:bufferlist_horzsepar)]], 0)
                        else
                            let l:sep_match = matchaddpos('BufferlistSepnor', [[1, l:sep_pos, strlen(g:bufferlist_horzsepar)]], 0)
                        endif
                        call add(s:bufferlist_hltdef, l:sep_match)
                    endif
                    " pos count
                    let l:pos += l:bufinf.length + strlen(g:bufferlist_horzsepar)
                endfor
            elseif !empty(s:bufferlist_bufinf)
                for il in range(len(s:bufferlist_bufinf))
                    let l:bufinf = s:bufferlist_bufinf[il]
                    let l:modify = !empty(l:bufinf.modify)
                    " hl tabdat
                    if il == s:bufferlist_tabidx
                        " cur
                        let l:hl_group = l:modify ? 'BufferlistCurmod' : 'BufferlistCurnor'
                        let l:match_id = matchadd(l:hl_group, '\%'.(il + 1).'l.*', 10)
                        call add(s:bufferlist_hltcur, l:match_id)
                        call cursor(il + 1, 1)
                    elseif l:bufinf.active
                        " vis
                        let l:hl_group = l:modify ? 'BufferlistVismod' : 'BufferlistVisnor'
                        let l:match_id = matchadd(l:hl_group, '\%'.(il + 1).'l.*', 5)
                        call add(s:bufferlist_hltvis, l:match_id)
                    else
                        " def
                        let l:hl_group = l:modify ? 'BufferlistDefmod' : 'BufferlistDefnor'
                        let l:match_id = matchadd(l:hl_group, '\%'.(il + 1).'l.*', 1)
                        call add(s:bufferlist_hltdef, l:match_id)
                    endif
                endfor
            endif

            " back win
            if l:orig_winidn != 0 && win_id2win(l:orig_winidn) != 0
                call win_gotoid(l:orig_winidn)
            endif
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#TabClean
    " --------------------------------------------------
    function! bufferlist#TabClean(...) abort
        if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0
            let l:orig_winidn = win_getid()
            " clean match
            call win_gotoid(s:bufferlist_winidn)
            call clearmatches(s:bufferlist_winidn)
            let s:bufferlist_hltdef = []
            let s:bufferlist_hltcur = []
            let s:bufferlist_hltvis = []
            " back win
            if l:orig_winidn != 0 && win_id2win(l:orig_winidn) != 0
                call win_gotoid(l:orig_winidn)
            endif
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#TabTupdtab
    " --------------------------------------------------
    function! bufferlist#TabTupdtab(...) abort
        if &modified == 1
            if s:bufferlist_timertab != -1
                call timer_stop(s:bufferlist_timertab)
                let s:bufferlist_timertab = -1
            endif
            let s:bufferlist_timertab = timer_start(100, {-> execute('call bufferlist#TabUpdtab()', '')})
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#TabUpdtab
    " --------------------------------------------------
    function! bufferlist#TabUpdtab(...) abort
        if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0
            call bufferlist#TabCollect()
            call bufferlist#TabRender()
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#TabTupdbuf
    " --------------------------------------------------
    function! bufferlist#TabTupdbuf(...) abort
        if &modified == 1
            if s:bufferlist_timerbuf != -1
                call timer_stop(s:bufferlist_timerbuf)
                let s:bufferlist_timerbuf = -1
            endif
            let s:bufferlist_timerbuf = timer_start(100, {-> execute('call bufferlist#TabUpdbuf()', '')})
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#TabUpdbuf
    " --------------------------------------------------
    function! bufferlist#TabUpdbuf(...) abort
        if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0
            call bufferlist#TabCollect()
            for il in range(len(s:bufferlist_bufinf))
                if s:bufferlist_bufinf[il].active
                    let s:bufferlist_tabidx = il
                    break
                endif
            endfor
            call bufferlist#TabRender()
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#BufActive
    " --------------------------------------------------
    function! bufferlist#BufActive(...) abort
        " check bufinf
        if !empty(s:bufferlist_bufinf) && a:0 > 0

            " tab index
            let s:bufferlist_tabidx += a:1
            if s:bufferlist_tabidx < 0
                let s:bufferlist_tabidx = len(s:bufferlist_bufinf) - 1
            elseif s:bufferlist_tabidx >= len(s:bufferlist_bufinf)
                let s:bufferlist_tabidx = 0
            endif

            " tab into
            let l:orig_winidn = win_getid()
            let l:bufnbr = s:bufferlist_bufinf[s:bufferlist_tabidx].bufnbr
            if bufexists(l:bufnbr)
                let l:basic_winidn = get(filter(map(range(1, winnr('$')), 'win_getid(v:val)'), '!bufferlist#IsSpecial(winbufnr(win_id2win(v:val)))'), 0, -1)
                if l:basic_winidn != -1 && win_id2win(l:basic_winidn) != 0
                    call win_gotoid(l:basic_winidn)
                else
                    if g:bufferlist_position == 'top'
                        execute 'silent! botright split'
                    elseif g:bufferlist_position == 'bottom'
                        execute 'silent! topleft split'
                    elseif g:bufferlist_position == 'left'
                        execute 'silent! botright vsplit'
                    elseif g:bufferlist_position == 'right'
                        execute 'silent! topleft vsplit'
                    endif
                endif
                execute 'buffer '.l:bufnbr
                if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0
                    if g:bufferlist_position == 'top'
                        execute win_id2win(s:bufferlist_winidn).'resize '.g:bufferlist_winheight
                    elseif g:bufferlist_position == 'bottom'
                        execute win_id2win(s:bufferlist_winidn).'resize '.g:bufferlist_winheight
                    elseif g:bufferlist_position == 'left'
                        execute 'vertical '.win_id2win(s:bufferlist_winidn).'resize '.g:bufferlist_winwidth
                    elseif g:bufferlist_position == 'right'
                        execute 'vertical '.win_id2win(s:bufferlist_winidn).'resize '.g:bufferlist_winwidth
                    endif
                endif
            endif

            " back win
            if a:1 != 0 && l:orig_winidn != 0 && win_id2win(l:orig_winidn) != 0
                call win_gotoid(l:orig_winidn)
            endif

            " tab update
            call bufferlist#TabUpdtab()
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#BufSwitch
    " --------------------------------------------------
    function! bufferlist#BufSwitch(...) abort
        if !empty(s:bufferlist_bufinf) && a:0 > 0
            if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0
                " have bufferlist
                call bufferlist#BufActive(a:1)
            else
                " no bufferlist
                let l:buflst = filter(getbufinfo({'buflisted': 1}), '!bufferlist#IsSpecial(v:val.bufnr) && v:val.loaded')
                if !empty(l:buflst)
                    let l:curr_bufnbr = bufnr('%')
                    let l:curr_bufidx = -1
                    for il in range(len(l:buflst))
                        if l:buflst[il].bufnr == l:curr_bufnbr
                            let l:curr_bufidx = il
                            break
                        endif
                    endfor
                    if l:curr_bufidx != -1
                        let l:targ_bufidx = l:curr_bufidx + a:1
                        if l:targ_bufidx < 0
                            let l:targ_bufidx = len(l:buflst) - 1
                        elseif l:targ_bufidx >= len(l:buflst)
                            let l:targ_bufidx = 0
                        endif
                        execute 'buffer '.l:buflst[l:targ_bufidx].bufnr
                    endif
                endif
            endif
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#BufMouse
    " --------------------------------------------------
    function! bufferlist#BufMouse(...) abort
        if !empty(s:bufferlist_bufinf) && s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0
            let l:click_lin = line('.')
            let l:click_col = col('.')
            if s:bufferlist_ifhorz
                " horizontal
                let l:pos = 1
                for il in range(len(s:bufferlist_bufinf))
                    let l:bufinf = s:bufferlist_bufinf[il]
                    if l:click_col >= l:pos && l:click_col < l:pos + l:bufinf.length
                        let s:bufferlist_tabidx = il
                        call bufferlist#BufActive(0)
                        break
                    endif
                    let l:pos += l:bufinf.length + strlen(g:bufferlist_horzsepar)
                endfor
            else
                " vertical
                if l:click_lin <= len(s:bufferlist_bufinf)
                    let s:bufferlist_tabidx = l:click_lin - 1
                    call bufferlist#BufActive(0)
                endif
            endif
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#TabNew
    " --------------------------------------------------
    function! bufferlist#TabNew(...) abort
        " check win
        let l:orig_winidn = win_getid()
        let l:basic_winidn = get(filter(map(range(1, winnr('$')), 'win_getid(v:val)'), '!bufferlist#IsSpecial(winbufnr(win_id2win(v:val)))'), 0, -1)
        if l:basic_winidn != -1 && win_id2win(l:basic_winidn) != 0
            call win_gotoid(l:basic_winidn)
            " tab new
            if a:0 > 0
                execute 'edit '.fnameescape(a:1)
            else
                enew
            endif
        endif
        " back win
        if l:orig_winidn != 0 && win_id2win(l:orig_winidn) != 0
            call win_gotoid(l:orig_winidn)
        endif
        " tab update
        call bufferlist#TabUpdtab()
    endfunction

    " --------------------------------------------------
    " bufferlist#TabOpen
    " --------------------------------------------------
    function! bufferlist#TabOpen(...) abort
        " tab check
        let l:buflst = filter(getbufinfo({'buflisted': 1}), '!bufferlist#IsSpecial(v:val.bufnr) && v:val.loaded')
        if len(l:buflst) == 2
            for il in range(len(l:buflst))
                if l:buflst[il].bufnr != bufnr('%')
                    let l:file_empty = getbufvar(l:buflst[il].bufnr, '&modified') == 0 && trim(join(getbufline(l:buflst[il].bufnr, 1, '$'), '')) == '' && filereadable(expand('#'.l:buflst[il].bufnr.':p')) == 0
                    if l:file_empty == 1
                        execute 'bwipeout' l:buflst[il].bufnr
                        let s:bufferlist_untnum = 0
                    endif
                endif
            endfor
        endif
        " tab update
        if !bufferlist#IsSpecial(bufnr('%'))
            call bufferlist#TabUpdtab()
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#TabClose
    " --------------------------------------------------
    function! bufferlist#TabClose(...) abort
        " check win
        let l:orig_winidn = win_getid()
        let l:basic_winidn = get(filter(map(range(1, winnr('$')), 'win_getid(v:val)'), '!bufferlist#IsSpecial(winbufnr(win_id2win(v:val)))'), 0, -1)
        if l:basic_winidn != -1 && win_id2win(l:basic_winidn) != 0
            call win_gotoid(l:basic_winidn)
            " tab close
            let l:curr_bufnbr = bufnr('%')
            let l:buflst = filter(getbufinfo({'buflisted': 1}), '!bufferlist#IsSpecial(v:val.bufnr) && v:val.loaded')
            if len(l:buflst) > 1
                " current index
                let l:curr_bufidx = -1
                for il in range(len(l:buflst))
                    if l:buflst[il].bufnr == l:curr_bufnbr
                        let l:curr_bufidx = il
                        break
                    endif
                endfor
                " next index
                let l:next_bufidx = -1
                if l:curr_bufidx + 1 < len(l:buflst)
                    let l:next_bufidx = l:buflst[l:curr_bufidx + 1].bufnr
                elseif l:curr_bufidx - 1 >= 0
                    let l:next_bufidx = l:buflst[l:curr_bufidx - 1].bufnr
                endif
                if l:next_bufidx != -1
                    execute 'buffer' l:next_bufidx
                else
                    enew
                endif
                " delete current
                execute 'bwipeout' l:curr_bufnbr
            else
                " last tab
                if getbufvar(l:curr_bufnbr, '&modified') == 1
                    echohl ErrorMsg | echo "Warning: Please save this file first..." | echohl None
                elseif !filereadable(expand('#'.l:curr_bufnbr.':p'))
                    echohl WarningMsg | echo "Warning: You already closed all buffer..." | echohl None
                else
                    enew
                    execute 'bwipeout' l:curr_bufnbr
                endif
            endif
        endif
        " back win
        if l:orig_winidn != 0 && win_id2win(l:orig_winidn) != 0
            call win_gotoid(l:orig_winidn)
        endif
        " tab update
        call bufferlist#TabUpdtab()
    endfunction

    " --------------------------------------------------
    " bufferlist#WinOpen
    " --------------------------------------------------
    function! bufferlist#WinOpen(...) abort
        if s:bufferlist_winidn == -1 || win_id2win(s:bufferlist_winidn) == 0
            " get message
            let l:orig_winidn = win_getid()
            " open new
            if g:bufferlist_position == 'top'
                execute 'silent! topleft split vim-bufferlist | resize '.g:bufferlist_winheight
            elseif g:bufferlist_position == 'bottom'
                execute 'silent! botright split vim-bufferlist | resize '.g:bufferlist_winheight
            elseif g:bufferlist_position == 'left'
                execute 'silent! topleft vsplit vim-bufferlist | vertical resize '.g:bufferlist_winwidth
            elseif g:bufferlist_position == 'right'
                execute 'silent! botright vsplit vim-bufferlist | vertical resize '.g:bufferlist_winwidth
            endif
            let s:bufferlist_bufnbr = bufnr('%')
            let s:bufferlist_winidn = win_getid()
            " set option
            setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted nomodifiable
            setlocal nonumber norelativenumber nocursorline nocursorcolumn nowrap nospell
            setlocal nofoldenable foldcolumn=0 signcolumn=no
            " set keymap
            nnoremap <buffer> <silent> l             :call bufferlist#BufActive(1)<CR>
            nnoremap <buffer> <silent> h             :call bufferlist#BufActive(-1)<CR>
            nnoremap <buffer> <silent> <Right>       :call bufferlist#BufActive(1)<CR>
            nnoremap <buffer> <silent> <Left>        :call bufferlist#BufActive(-1)<CR>
            nnoremap <buffer> <silent> <Tab>         :call bufferlist#BufActive(1)<CR>
            nnoremap <buffer> <silent> <S-Tab>       :call bufferlist#BufActive(-1)<CR>
            nnoremap <buffer> <silent> <Enter>       :call bufferlist#BufActive(0)<CR>
            nnoremap <buffer> <silent> <LeftRelease> :call bufferlist#BufMouse()<CR>
            " back win
            if l:orig_winidn != 0 && win_id2win(l:orig_winidn) != 0
                call win_gotoid(l:orig_winidn)
            endif
        endif
        call bufferlist#TabUpdbuf()
    endfunction

    " --------------------------------------------------
    " bufferlist#WinClose
    " --------------------------------------------------
    function! bufferlist#WinClose(...) abort
        if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0
            " clean match
            call bufferlist#TabClean()
            let l:orig_winidn = win_getid()
            call win_gotoid(s:bufferlist_winidn)
            " del keymap
            silent! nunmap <buffer> l
            silent! nunmap <buffer> h
            silent! nunmap <buffer> <Right>
            silent! nunmap <buffer> <Left>
            silent! nunmap <buffer> <Tab>
            silent! nunmap <buffer> <S-Tab>
            silent! nunmap <buffer> <Enter>
            silent! nunmap <buffer> <LeftRelease>
            " operate
            close
            let s:bufferlist_bufnbr = -1
            let s:bufferlist_winidn = -1
            " back win
            if l:orig_winidn != 0 && win_id2win(l:orig_winidn) != 0
                call win_gotoid(l:orig_winidn)
            endif
        else
            let s:bufferlist_bufnbr = -1
            let s:bufferlist_winidn = -1
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#Toggle
    " --------------------------------------------------
    function! bufferlist#Toggle(...) abort
        if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0
            call bufferlist#WinClose()
        else
            call bufferlist#WinOpen()
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#Open
    " --------------------------------------------------
    function! bufferlist#Open(...) abort
        if s:bufferlist_winidn == -1 || win_id2win(s:bufferlist_winidn) == 0
            call bufferlist#WinOpen()
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#Close
    " --------------------------------------------------
    function! bufferlist#Close(...) abort
        if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0
            call bufferlist#WinClose()
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#SetHlcolor
    " --------------------------------------------------
    function! bufferlist#SetHlcolor(...) abort
        let l:cbg = !empty(synIDattr(hlID('StatusLine'), 'bg', 'cterm')) ? synIDattr(hlID('StatusLine'), 'bg', 'cterm') : 'Black'
        let l:gbg = !empty(synIDattr(hlID('StatusLine'), 'bg', 'gui'))   ? synIDattr(hlID('StatusLine'), 'bg', 'gui')   : '#171C22'
        let l:tpe = bufferlist#CalcFg(l:gbg) == "White" ? [0, 1] : [2, 3]
        " tab default
        execute 'hi! BufferlistDefnor ctermfg='.g:bufferlist_defnor[l:tpe[0]].' ctermbg='.l:cbg.' cterm=NONE guifg='.g:bufferlist_defnor[l:tpe[1]].' guibg='.bufferlist#MixWhite(l:gbg, 0.3).' gui=NONE'
        execute 'hi! BufferlistDefmod ctermfg='.g:bufferlist_defmod[l:tpe[0]].' ctermbg='.l:cbg.' cterm=NONE guifg='.g:bufferlist_defmod[l:tpe[1]].' guibg='.bufferlist#MixWhite(l:gbg, 0.3).' gui=NONE'
        " tab current
        execute 'hi! BufferlistCurnor ctermfg='.g:bufferlist_curnor[l:tpe[0]].' ctermbg='.l:cbg.' cterm=NONE guifg='.g:bufferlist_curnor[l:tpe[1]].' guibg='.l:gbg.' gui=NONE'
        execute 'hi! BufferlistCurmod ctermfg='.g:bufferlist_curmod[l:tpe[0]].' ctermbg='.l:cbg.' cterm=NONE guifg='.g:bufferlist_curmod[l:tpe[1]].' guibg='.l:gbg.' gui=NONE'
        " tab visible
        execute 'hi! BufferlistVisnor ctermfg='.g:bufferlist_visnor[l:tpe[0]].' ctermbg='.l:cbg.' cterm=NONE guifg='.g:bufferlist_visnor[l:tpe[1]].' guibg='.l:gbg.' gui=NONE'
        execute 'hi! BufferlistVismod ctermfg='.g:bufferlist_vismod[l:tpe[0]].' ctermbg='.l:cbg.' cterm=NONE guifg='.g:bufferlist_vismod[l:tpe[1]].' guibg='.l:gbg.' gui=NONE'
        " tab separator
        execute 'hi! BufferlistSepnor ctermfg='.g:bufferlist_sepnor[l:tpe[0]].' ctermbg='.l:cbg.' cterm=NONE guifg='.g:bufferlist_sepnor[l:tpe[1]].' guibg='.bufferlist#MixWhite(l:gbg, 0.3).' gui=NONE'
        execute 'hi! BufferlistSepmod ctermfg='.l:cbg.' ctermbg='.l:cbg.' cterm=NONE guifg='.bufferlist#MixWhite(l:gbg, 0.3).' guibg='.bufferlist#MixWhite(l:gbg, 0.3).' gui=NONE'
        " update bufferlist
        call bufferlist#TabUpdbuf()
    endfunction

    " --------------------------------------------------
    " bufferlist#ReopenBuild
    " --------------------------------------------------
    function! bufferlist#ReopenBuild(buf)
        if !isdirectory(g:bufferlist_filepath)
            call mkdir(g:bufferlist_filepath, 'p', 0777)
        endif
        if filereadable(s:bufferlist_filelist) && s:bufferlist_restover == 1
            let l:savelist = []
            let l:bufname = fnamemodify(bufname(a:buf), ':p')
            let l:buflist = filter(range(1, bufnr('$')), 'buflisted(v:val) && getbufvar(v:val, "&buftype") == ""')
            if index(l:buflist, a:buf) != -1
                for il in l:buflist
                    let l:name = fnamemodify(bufname(il), ':p')
                    if !empty(l:name)
                        if l:name == l:bufname
                            call add(l:savelist, l:name."|C|1|1|1")
                        else
                            call add(l:savelist, l:name."|X|1|1|1")
                        endif
                    endif
                endfor
                let s:bufferlist_filedata = l:savelist
                call writefile(s:bufferlist_filedata, s:bufferlist_filelist, 'b')
            endif
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#ReopenClose
    " --------------------------------------------------
    function! bufferlist#ReopenClose(buf)
        if !isdirectory(g:bufferlist_filepath)
            call mkdir(g:bufferlist_filepath, 'p', 0777)
        endif
        if filereadable(s:bufferlist_filelist) && s:bufferlist_restover == 1
            let l:savelist = []
            let s:bufferlist_filedata = readfile(s:bufferlist_filelist)
            for il in s:bufferlist_filedata
                let l:rec = split(il, '|')
                if (l:rec[0] != a:buf)
                    call add(l:savelist, l:rec[0]."|X|".l:rec[2]."|".l:rec[3]."|".l:rec[4]."")
                endif
            endfor
            let s:bufferlist_filedata = l:savelist
            call writefile(s:bufferlist_filedata, s:bufferlist_filelist, 'b')
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#ReopenRestore
    " --------------------------------------------------
    function! bufferlist#ReopenRestore()
        if filereadable(s:bufferlist_filelist)
            let l:savelist = []
            let l:currfile = ''
            let s:bufferlist_filedata = readfile(s:bufferlist_filelist)
            for il in s:bufferlist_filedata
                let l:rec = split(il, '|')
                if exists('l:rec[0]') && l:rec[0] != "" && filereadable(l:rec[0])
                    if l:rec[1] == 'C'
                        let l:currfile = l:rec[0]
                    endif
                    silent execute "edit ".l:rec[0]
                endif
            endfor
            if !empty(l:currfile)
                silent execute "edit ".l:currfile
            endif
        endif
        let s:bufferlist_restover = 1
    endfunction

    " --------------------------------------------------
    " bufferlaaaist#BuildCmd
    " --------------------------------------------------
    function! bufferlist#BuildCmd(...) abort
        augroup bufferlist_cmd_sub
            autocmd!
            " BufNew
            autocmd BufEnter,WinEnter,BufWipeout,BufWritePost * noautocmd call bufferlist#TabUpdbuf()
            autocmd TextChanged * call bufferlist#TabTupdbuf()
            autocmd ModeChanged [iI]:[n] call bufferlist#TabTupdbuf()
            autocmd BufRead * call bufferlist#TabOpen()
            autocmd WinResized * call bufferlist#BufActive(0)
            if exists('g:bufferlist_reopen') && g:bufferlist_reopen == 1
                autocmd BufAdd,BufEnter * call bufferlist#ReopenBuild(str2nr(expand('<abuf>')))
                autocmd BufDelete * call bufferlist#ReopenClose(expand('<afile>:p'))
            endif
        augroup END
    endfunction

    " --------------------------------------------------
    " bufferlist_cmd_bas
    " --------------------------------------------------
    augroup bufferlist_cmd_bas
        autocmd!
        autocmd ColorScheme * call bufferlist#SetHlcolor()
        autocmd VimEnter * call bufferlist#SetHlcolor()
        autocmd VimEnter * nested call bufferlist#BuildCmd()
        if exists('g:bufferlist_reopen') && g:bufferlist_reopen == 1
            autocmd VimEnter * call timer_start(0, {-> execute('call bufferlist#ReopenRestore()', '')})
        endif
    augroup END

    " --------------------------------------------------
    " keymap
    " --------------------------------------------------
    if has('gui_running')
        nnoremap <silent> <C-Tab>   :call bufferlist#BufSwitch(1)<CR>
        nnoremap <silent> <C-S-Tab> :call bufferlist#BufSwitch(-1)<CR>
        nnoremap <silent> <C-Right> :call bufferlist#BufSwitch(1)<CR>
        nnoremap <silent> <C-Left>  :call bufferlist#BufSwitch(-1)<CR>
    else
        nnoremap <silent> <C-Right> :call bufferlist#BufSwitch(1)<CR>
        nnoremap <silent> <C-Left>  :call bufferlist#BufSwitch(-1)<CR>
    endif

    " --------------------------------------------------
    " command
    " --------------------------------------------------
    command!                         BufferlistToggle   call bufferlist#Toggle()
    command!                         BufferlistOpen     call bufferlist#Open()
    command!                         BufferlistClose    call bufferlist#Close()
    command! -nargs=? -complete=file BufferlistTabnew   call bufferlist#TabNew(<f-args>)
    command!                         BufferlistTabClose call bufferlist#TabClose()

endif

" ============================================================================
" Other
" ============================================================================
let &cpoptions = s:save_cpo
unlet s:save_cpo
