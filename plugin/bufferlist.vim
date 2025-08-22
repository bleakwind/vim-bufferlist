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
" public setting - [g:bufferlist_position:top|bottom|left|right]
let g:bufferlist_enabled    = get(g:, 'bufferlist_enabled',     0)
let g:bufferlist_autostart  = get(g:, 'bufferlist_autostart',   0)
let g:bufferlist_position   = get(g:, 'bufferlist_position',    'top')
let g:bufferlist_winwidth   = get(g:, 'bufferlist_winwidth',    20)
let g:bufferlist_winheight  = get(g:, 'bufferlist_winheight',   1)
let g:bufferlist_horzsepar  = get(g:, 'bufferlist_horzsepar',   '|')
let g:bufferlist_modifmark  = get(g:, 'bufferlist_modifmark',   '[+]')

" tab color
let g:bufferlist_hldefnor   = get(g:, 'bufferlist_hldefnor',    '#FFFFFF')
let g:bufferlist_hldefmod   = get(g:, 'bufferlist_hldefmod',    '#F56C6C')
let g:bufferlist_hlcurnor   = get(g:, 'bufferlist_hlcurnor',    '#67C23A')
let g:bufferlist_hlcurmod   = get(g:, 'bufferlist_hlcurmod',    '#E0575B')
let g:bufferlist_hlvisnor   = get(g:, 'bufferlist_hlvisnor',    '#67C23A')
let g:bufferlist_hlvismod   = get(g:, 'bufferlist_hlvismod',    '#E0575B')
let g:bufferlist_hlsepnor   = get(g:, 'bufferlist_hlsepnor',    '#AAAAAA')

" reopen file
let g:bufferlist_reopen     = get(g:, 'bufferlist_reopen',      0)
let g:bufferlist_datapath   = get(g:, 'bufferlist_datapath',    $HOME.'/.vim/bufferlist')

" plugin variable
let s:bufferlist_bufnbr     = -1
let s:bufferlist_winidn     = -1
let s:bufferlist_tabidx     = 0
let s:bufferlist_ifhorz     = 0
let s:bufferlist_untnum     = 0
let s:bufferlist_bufinf     = []
let s:bufferlist_hltdef     = []
let s:bufferlist_hltcur     = []
let s:bufferlist_hltvis     = []
let s:bufferlist_timertab   = -1
let s:bufferlist_timerbuf   = -1
let s:bufferlist_restover   = 0
let s:bufferlist_reopenlist = g:bufferlist_datapath.'/reopenlist'
let s:bufferlist_reopendata = {}

" ============================================================================
" bufferlist detail
" g:bufferlist_enabled = 1
" ============================================================================
if exists('g:bufferlist_enabled') && g:bufferlist_enabled ==# 1

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
        let s:bufferlist_ifhorz = g:bufferlist_position ==# 'top' || g:bufferlist_position ==# 'bottom' ? 1 : 0

        " check winidn
        if (s:bufferlist_bufnbr != -1 && bufexists(s:bufferlist_bufnbr) ==# 0) || (s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) ==# 0)
            let s:bufferlist_bufnbr = -1
            let s:bufferlist_winidn = -1
        endif

        " check bufferlist
        if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0

            " get message
            let l:orig_bufnbr = bufnr('%')
            let l:orig_bufinf = copy(s:bufferlist_bufinf)
            let s:bufferlist_bufinf = []

            " get buflist
            let l:buflst = filter(getbufinfo({'buflisted': 1}), '!bufferlist#IsSpecial(v:val.bufnr) && v:val.loaded')
            if !empty(l:buflst)
                for il in l:buflst
                    " ready value
                    let l:otabnm = get(filter(map(copy(l:orig_bufinf), 'v:val.bufnbr ==# il.bufnr ? v:val.tabnme : ""'), 'v:val != ""'), 0, '')
                    " set value
                    let l:bufnbr = il.bufnr
                    let l:bufnme = bufname(il.bufnr)
                    if !empty(l:bufnme)
                        let l:tabnme = fnamemodify(l:bufnme, ':t')
                    elseif !empty(l:otabnm)
                        let l:tabnme = l:otabnm
                    else
                        let s:bufferlist_untnum = s:bufferlist_untnum + 1
                        let l:tabnme = 'Untitled-'.s:bufferlist_untnum.''
                    endif
                    let l:modify = getbufvar(il.bufnr, '&modified') ? g:bufferlist_modifmark : ''
                    let l:tabdat = ' '.l:tabnme.l:modify.' '
                    let l:active = il.bufnr ==# l:orig_bufnbr ? 1 : 0
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
                        if il ==# s:bufferlist_tabidx || il - 1 ==# s:bufferlist_tabidx || l:bufinf.active || s:bufferlist_bufinf[il-1].active
                            let l:sep_match = matchaddpos('BufferlistHlSepmod', [[1, l:sep_pos, strlen(g:bufferlist_horzsepar)]], 0)
                        else
                            let l:sep_match = matchaddpos('BufferlistHlSepnor', [[1, l:sep_pos, strlen(g:bufferlist_horzsepar)]], 0)
                        endif
                        call add(s:bufferlist_hltdef, l:sep_match)
                    endif
                    " hl tabdat
                    if il ==# s:bufferlist_tabidx
                        " cur
                        let l:hl_group = l:modify ? 'BufferlistHlCurmod' : 'BufferlistHlCurnor'
                        let l:match_id = matchaddpos(l:hl_group, [[1, l:pos, l:bufinf.length]], 10)
                        call add(s:bufferlist_hltcur, l:match_id)
                        keepjumps call setpos('.', [0, 1, l:pos, 0])
                    elseif l:bufinf.active
                        " vis
                        let l:hl_group = l:modify ? 'BufferlistHlVismod' : 'BufferlistHlVisnor'
                        let l:match_id = matchaddpos(l:hl_group, [[1, l:pos, l:bufinf.length]], 5)
                        call add(s:bufferlist_hltvis, l:match_id)
                    else
                        " def
                        let l:hl_group = l:modify ? 'BufferlistHlDefmod' : 'BufferlistHlDefnor'
                        let l:match_id = matchaddpos(l:hl_group, [[1, l:pos, l:bufinf.length]], 1)
                        call add(s:bufferlist_hltdef, l:match_id)
                    endif
                    " hl rightsepar
                    if il < len(s:bufferlist_bufinf) - 1
                        let l:sep_pos = l:pos + l:bufinf.length
                        if il ==# s:bufferlist_tabidx || l:bufinf.active
                            let l:sep_match = matchaddpos('BufferlistHlSepmod', [[1, l:sep_pos, strlen(g:bufferlist_horzsepar)]], 0)
                        else
                            let l:sep_match = matchaddpos('BufferlistHlSepnor', [[1, l:sep_pos, strlen(g:bufferlist_horzsepar)]], 0)
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
                    if il ==# s:bufferlist_tabidx
                        " cur
                        let l:hl_group = l:modify ? 'BufferlistHlCurmod' : 'BufferlistHlCurnor'
                        let l:match_id = matchadd(l:hl_group, '\%'.(il + 1).'l.*', 10)
                        call add(s:bufferlist_hltcur, l:match_id)
                        keepjumps call setpos('.', [0, il + 1, 1, 0])
                    elseif l:bufinf.active
                        " vis
                        let l:hl_group = l:modify ? 'BufferlistHlVismod' : 'BufferlistHlVisnor'
                        let l:match_id = matchadd(l:hl_group, '\%'.(il + 1).'l.*', 5)
                        call add(s:bufferlist_hltvis, l:match_id)
                    else
                        " def
                        let l:hl_group = l:modify ? 'BufferlistHlDefmod' : 'BufferlistHlDefnor'
                        let l:match_id = matchadd(l:hl_group, '\%'.(il + 1).'l.*', 1)
                        call add(s:bufferlist_hltdef, l:match_id)
                    endif
                endfor
            endif

            " tab visible
            call bufferlist#TabVisible()

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
        if &modified ==# 1
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
        if &modified ==# 1
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
    " bufferlist#TabVisible
    " --------------------------------------------------
    function! bufferlist#TabVisible(...) abort
        if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0 && !empty(s:bufferlist_bufinf)
            let l:orig_winidn = win_getid()
            " check tab index
            if s:bufferlist_tabidx < 0
                let s:bufferlist_tabidx = 0
            elseif s:bufferlist_tabidx >= len(s:bufferlist_bufinf)
                let s:bufferlist_tabidx = len(s:bufferlist_bufinf) - 1
            endif
            " goto bufferlist win
            call win_gotoid(s:bufferlist_winidn)
            let l:curr_tab = s:bufferlist_bufinf[s:bufferlist_tabidx]
            if s:bufferlist_ifhorz
                " horizontal
                let l:win_width = winwidth(s:bufferlist_winidn)
                let l:curr_begtab = 1
                for il in range(len(s:bufferlist_bufinf))
                    let l:bufinf = s:bufferlist_bufinf[il]
                    if il == s:bufferlist_tabidx
                        break
                    endif
                    let l:curr_begtab += l:bufinf.length + strlen(g:bufferlist_horzsepar)
                endfor
                let l:curr_endtab = l:curr_begtab + l:curr_tab.length - 1
                let l:curr_curtab = winsaveview().leftcol
                " check tab outside
                if l:curr_begtab < (l:curr_curtab + 1) || l:curr_endtab > (l:curr_curtab + l:win_width)
                    let l:target_scroll = l:curr_begtab - (l:win_width / 2) + (l:curr_tab.length / 2)
                    if l:target_scroll < 0
                        let l:target_scroll = 0
                    endif
                    call winrestview({'leftcol': l:target_scroll})
                endif
            else
                " vertical
                let l:win_height = winheight(s:bufferlist_winidn)
                let l:curr_begtab = winsaveview().topline
                let l:curr_endtab = l:curr_begtab + l:win_height - 1
                let l:curr_curtab = s:bufferlist_tabidx + 1
                " check tab outside
                if l:curr_curtab < l:curr_begtab || l:curr_curtab > l:curr_endtab
                    let l:target_topline = l:curr_curtab - (l:win_height / 2)
                    if l:target_topline < 1
                        let l:target_topline = 1
                    endif
                    call winrestview({'topline': l:target_topline})
                endif
            endif
            " back win
            if l:orig_winidn != 0 && win_id2win(l:orig_winidn) != 0
                call win_gotoid(l:orig_winidn)
            endif
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
                    if g:bufferlist_position ==# 'top'
                        execute 'silent! botright split'
                    elseif g:bufferlist_position ==# 'bottom'
                        execute 'silent! topleft split'
                    elseif g:bufferlist_position ==# 'left'
                        execute 'silent! botright vsplit'
                    elseif g:bufferlist_position ==# 'right'
                        execute 'silent! topleft vsplit'
                    endif
                endif
                execute 'buffer '.l:bufnbr
                if s:bufferlist_winidn != -1 && win_id2win(s:bufferlist_winidn) != 0
                    if g:bufferlist_position ==# 'top'
                        execute win_id2win(s:bufferlist_winidn).'resize '.g:bufferlist_winheight
                    elseif g:bufferlist_position ==# 'bottom'
                        execute win_id2win(s:bufferlist_winidn).'resize '.g:bufferlist_winheight
                    elseif g:bufferlist_position ==# 'left'
                        execute 'vertical '.win_id2win(s:bufferlist_winidn).'resize '.g:bufferlist_winwidth
                    elseif g:bufferlist_position ==# 'right'
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
                        if l:buflst[il].bufnr ==# l:curr_bufnbr
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
        " tab load
        let l:bufall = filter(getbufinfo({'buflisted': 1}), '!bufferlist#IsSpecial(v:val.bufnr)')
        for buf in l:bufall
            if !buf.loaded
                call bufload(buf.bufnr)
            endif
            " close untitled tab
            let l:buflst = filter(getbufinfo({'buflisted': 1}), '!bufferlist#IsSpecial(v:val.bufnr) && v:val.loaded')
            if len(l:buflst) ==# 2
                for il in l:buflst
                    if getbufvar(il.bufnr, '&modified') ==# 0 && trim(join(getbufline(il.bufnr, 1, '$'), '')) ==# '' && filereadable(expand('#'.il.bufnr.':p')) ==# 0
                        execute 'silent! bwipeout' il.bufnr
                        break
                    endif
                endfor
            endif
        endfor
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
                    if l:buflst[il].bufnr ==# l:curr_bufnbr
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
                if getbufvar(l:curr_bufnbr, '&modified') ==# 1
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
        if s:bufferlist_winidn ==# -1 || win_id2win(s:bufferlist_winidn) ==# 0
            " get message
            let l:orig_winidn = win_getid()

            " open win
            if g:bufferlist_position ==# 'bottom'
                execute 'silent! botright split vim-bufferlist | resize '.g:bufferlist_winheight
            elseif g:bufferlist_position ==# 'left'
                execute 'silent! topleft vsplit vim-bufferlist | vertical resize '.g:bufferlist_winwidth
            elseif g:bufferlist_position ==# 'right'
                execute 'silent! botright vsplit vim-bufferlist | vertical resize '.g:bufferlist_winwidth
            else
                execute 'silent! topleft split vim-bufferlist | resize '.g:bufferlist_winheight
            endif

            let s:bufferlist_bufnbr = bufnr('%')
            let s:bufferlist_winidn = win_getid()

            " set option
            call win_execute(s:bufferlist_winidn, 'setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted nomodifiable')
            call win_execute(s:bufferlist_winidn, 'setlocal nonumber norelativenumber nolist nocursorline nocursorcolumn nospell')
            call win_execute(s:bufferlist_winidn, 'setlocal nowrap nofoldenable foldcolumn=0 signcolumn=no colorcolumn=')
            call win_execute(s:bufferlist_winidn, 'setlocal filetype=bufferlist')
            call win_execute(s:bufferlist_winidn, 'file vim-bufferlist')

            " set win
            if g:bufferlist_position ==# 'bottom'
                call win_execute(s:bufferlist_winidn, 'setlocal winfixheight')
            elseif g:bufferlist_position ==# 'left'
                call win_execute(s:bufferlist_winidn, 'setlocal winfixwidth')
            elseif g:bufferlist_position ==# 'right'
                call win_execute(s:bufferlist_winidn, 'setlocal winfixwidth')
            else
                call win_execute(s:bufferlist_winidn, 'setlocal winfixheight')
            endif

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
    " bufferlist#Open
    " --------------------------------------------------
    function! bufferlist#Open(...) abort
        if s:bufferlist_winidn ==# -1 || win_id2win(s:bufferlist_winidn) ==# 0
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
    " bufferlist#ColorBgtype
    " --------------------------------------------------
    function! bufferlist#ColorBgtype(hex) abort
        let l:r = str2nr(a:hex[1:2], 16)
        let l:g = str2nr(a:hex[3:4], 16)
        let l:b = str2nr(a:hex[5:6], 16)
        let l:brightness = (0.299 * l:r + 0.587 * l:g + 0.114 * l:b) / 255
        return l:brightness > 0.5 ? 'White' : 'Black'
    endfunction

    " --------------------------------------------------
    " bufferlist#ColorMask
    " --------------------------------------------------
    function! bufferlist#ColorMask(color, alpha) abort
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
    " bufferlist#ColorInvert
    " --------------------------------------------------
    function! bufferlist#ColorInvert(hex)
        let sat = 1.5
        let lit = 0.4

        " HexToHSL
        let r = str2nr(a:hex[1:2], 16) / 255.0
        let g = str2nr(a:hex[3:4], 16) / 255.0
        let b = str2nr(a:hex[5:6], 16) / 255.0

        let max = r > g ? (r > b ? r : b) : (g > b ? g : b)
        let min = r < g ? (r < b ? r : b) : (g < b ? g : b)
        let delta = max - min

        let l = (max + min) / 2.0

        if delta ==# 0.0
            let h = 0.0
            let s = 0.0
        else
            let s = l < 0.5 ? delta / (max + min) : delta / (2.0 - max - min)
            if max ==# r
                let h = (g - b) / delta
            elseif max ==# g
                let h = 2.0 + (b - r) / delta
            else
                let h = 4.0 + (r - g) / delta
            endif
            let h = h * 60.0
            if h < 0.0
                let h = h + 360.0
            endif
        endif

        " change saturation and light
        let s = s * sat > 1.0 ? 1.0 : s * sat
        let l = l * lit

        " HSLToHex
        let h = h >= 360.0 ? 0.0 : h / 360.0
        let s = s < 0.0 ? 0.0 : s > 1.0 ? 1.0 : s
        let l = l < 0.0 ? 0.0 : l > 1.0 ? 1.0 : l

        if s ==# 0.0
            let r = l
            let g = l
            let b = l
        else
            let q = l < 0.5 ? l * (1.0 + s) : l + s - l * s
            let p = 2.0 * l - q

            let rt = h + 1.0/3.0
            let rt = rt < 0.0 ? rt + 1.0 : rt > 1.0 ? rt - 1.0 : rt
            let r = rt < 1.0/6.0 ? p + (q - p) * 6.0 * rt : rt < 1.0/2.0 ? q : rt < 2.0/3.0 ? p + (q - p) * (2.0/3.0 - rt) * 6.0 : p

            let gt = h
            let gt = gt < 0.0 ? gt + 1.0 : gt > 1.0 ? gt - 1.0 : gt
            let g = gt < 1.0/6.0 ? p + (q - p) * 6.0 * gt : gt < 1.0/2.0 ? q : gt < 2.0/3.0 ? p + (q - p) * (2.0/3.0 - gt) * 6.0 : p

            let bt = h - 1.0/3.0
            let bt = bt < 0.0 ? bt + 1.0 : bt > 1.0 ? bt - 1.0 : bt
            let b = bt < 1.0/6.0 ? p + (q - p) * 6.0 * bt : bt < 1.0/2.0 ? q : bt < 2.0/3.0 ? p + (q - p) * (2.0/3.0 - bt) * 6.0 : p
        endif

        let r = float2nr(round(r * 255.0))
        let g = float2nr(round(g * 255.0))
        let b = float2nr(round(b * 255.0))
        let r = r < 0 ? 0 : r > 255 ? 255 : r
        let g = g < 0 ? 0 : g > 255 ? 255 : g
        let b = b < 0 ? 0 : b > 255 ? 255 : b

        return printf("#%02X%02X%02X", r, g, b)
    endfunction

    " --------------------------------------------------
    " bufferlist#ColorName
    " --------------------------------------------------
    function! bufferlist#ColorName(color)
        let l:color_hex = {
                    \ 'Red':            '#FF0000',
                    \ 'LightRed':       '#FF6666',
                    \ 'DarkRed':        '#8B0000',
                    \ 'Green':          '#00FF00',
                    \ 'LightGreen':     '#66FF66',
                    \ 'DarkGreen':      '#006400',
                    \ 'Blue':           '#0000FF',
                    \ 'LightBlue':      '#6666FF',
                    \ 'DarkBlue':       '#00008B',
                    \ 'Cyan':           '#00FFFF',
                    \ 'LightCyan':      '#66FFFF',
                    \ 'DarkCyan':       '#008B8B',
                    \ 'Magenta':        '#FF00FF',
                    \ 'LightMagenta':   '#FF66FF',
                    \ 'DarkMagenta':    '#8B008B',
                    \ 'Yellow':         '#FFFF00',
                    \ 'LightYellow':    '#FFFF66',
                    \ 'Brown':          '#A52A2A',
                    \ 'DarkYellow':     '#CCCC00',
                    \ 'Gray':           '#808080',
                    \ 'LightGray':      '#C0C0C0',
                    \ 'DarkGray':       '#404040',
                    \ 'Black':          '#000000',
                    \ 'White':          '#FFFFFF',
                    \ }

        " parse color
        let l:input_rgb = [0, 0, 0]
        if a:color =~? '^#[0-9a-f]\{3}$'
            let l:hex = a:color[1:]
            let l:input_rgb = [str2nr(l:hex[0].l:hex[0], 16), str2nr(l:hex[1].l:hex[1], 16), str2nr(l:hex[2].l:hex[2], 16)]
        elseif a:color =~? '^#[0-9a-f]\{6}$'
            let l:hex = a:color[1:]
            let l:input_rgb = [str2nr(l:hex[0:1], 16), str2nr(l:hex[2:3], 16), str2nr(l:hex[4:5], 16)]
        elseif a:color =~? '^rgb(\s*\d\+\s*,\s*\d\+\s*,\s*\d\+\s*)$'
            let l:parts = split(matchstr(a:color, '\d\+\s*,\s*\d\+\s*,\s*\d\+'), '\s*,\s*')
            let l:input_rgb = [str2nr(l:parts[0]), str2nr(l:parts[1]), str2nr(l:parts[2])]
        elseif has_key(l:color_hex, a:color)
            let l:hex = l:color_hex[a:color][1:]
            if len(l:hex) ==# 3
                let l:input_rgb = [str2nr(l:hex[0].l:hex[0], 16), str2nr(l:hex[1].l:hex[1], 16), str2nr(l:hex[2].l:hex[2], 16)]
            else
                let l:input_rgb = [str2nr(l:hex[0:1], 16), str2nr(l:hex[2:3], 16), str2nr(l:hex[4:5], 16)]
            endif
        else
            return 'Black'
        endif

        " check brightness
        let l:brightness = l:input_rgb[0] * 0.299 + l:input_rgb[1] * 0.587 + l:input_rgb[2] * 0.114
        if l:input_rgb[2] > max([l:input_rgb[0], l:input_rgb[1]]) + 20
            return l:brightness > 150 ? 'LightBlue' : 'DarkBlue'
        endif
        if abs(l:input_rgb[0] - l:input_rgb[1]) < 30 && abs(l:input_rgb[1] - l:input_rgb[2]) < 30
            if l:brightness > 180
                return 'White'
            elseif l:brightness > 120
                return 'LightGray'
            elseif l:brightness > 60
                return 'Gray'
            else
                return l:brightness > 30 ? 'DarkGray' : 'Black'
            endif
        endif

        " find name
        let l:min_distance = 999999
        let l:nearest_color = 'Black'
        for [l:color_name, l:hex] in items(l:color_hex)
            let l:palette_hex = l:hex[1:]
            if len(l:palette_hex) ==# 3
                let l:palette_rgb = [ str2nr(l:palette_hex[0].l:palette_hex[0], 16), str2nr(l:palette_hex[1].l:palette_hex[1], 16), str2nr(l:palette_hex[2].l:palette_hex[2], 16)]
            else
                let l:palette_rgb = [ str2nr(l:palette_hex[0:1], 16), str2nr(l:palette_hex[2:3], 16), str2nr(l:palette_hex[4:5], 16)]
            endif

            let l:dr = l:input_rgb[0] - l:palette_rgb[0]
            let l:dg = l:input_rgb[1] - l:palette_rgb[1]
            let l:db = l:input_rgb[2] - l:palette_rgb[2]
            let l:distance = l:dr*l:dr*0.3 + l:dg*l:dg*0.59 + l:db*l:db*0.11

            if l:distance < l:min_distance
                let l:min_distance = l:distance
                let l:nearest_color = l:color_name
            endif
        endfor

        " adjust result
        if l:brightness > 180 && l:nearest_color =~? '^Dark'
            let l:nearest_color = substitute(l:nearest_color, 'Dark', 'Light', '')
        elseif l:brightness < 80 && l:nearest_color =~? '^Light'
            let l:nearest_color = substitute(l:nearest_color, 'Light', 'Dark', '')
        endif

        return l:nearest_color
    endfunction

    " --------------------------------------------------
    " bufferlist#SetHlcolor
    " --------------------------------------------------
    function! bufferlist#SetHlcolor(...) abort
        " check bgcolor
        let l:gbg = !empty(synIDattr(hlID('StatusLine'), 'bg', 'gui'))   ? synIDattr(hlID('StatusLine'), 'bg', 'gui')   : '#171C22'
        let l:hldefnor = bufferlist#ColorBgtype(l:gbg) ==# "White" ? bufferlist#ColorInvert(g:bufferlist_hldefnor) : g:bufferlist_hldefnor
        let l:hldefmod = bufferlist#ColorBgtype(l:gbg) ==# "White" ? bufferlist#ColorInvert(g:bufferlist_hldefmod) : g:bufferlist_hldefmod
        let l:hlcurnor = bufferlist#ColorBgtype(l:gbg) ==# "White" ? bufferlist#ColorInvert(g:bufferlist_hlcurnor) : g:bufferlist_hlcurnor
        let l:hlcurmod = bufferlist#ColorBgtype(l:gbg) ==# "White" ? bufferlist#ColorInvert(g:bufferlist_hlcurmod) : g:bufferlist_hlcurmod
        let l:hlvisnor = bufferlist#ColorBgtype(l:gbg) ==# "White" ? bufferlist#ColorInvert(g:bufferlist_hlvisnor) : g:bufferlist_hlvisnor
        let l:hlvismod = bufferlist#ColorBgtype(l:gbg) ==# "White" ? bufferlist#ColorInvert(g:bufferlist_hlvismod) : g:bufferlist_hlvismod
        let l:hlsepnor = bufferlist#ColorBgtype(l:gbg) ==# "White" ? bufferlist#ColorInvert(g:bufferlist_hlsepnor) : g:bufferlist_hlsepnor

        " tab default
        execute 'hi! BufferlistHlDefnor ctermfg='.bufferlist#ColorName(l:hldefnor).' ctermbg='.bufferlist#ColorName(l:gbg).' cterm=NONE guifg='.l:hldefnor.' guibg='.bufferlist#ColorMask(l:gbg, 0.3).' gui=NONE'
        execute 'hi! BufferlistHlDefmod ctermfg='.bufferlist#ColorName(l:hldefmod).' ctermbg='.bufferlist#ColorName(l:gbg).' cterm=NONE guifg='.l:hldefmod.' guibg='.bufferlist#ColorMask(l:gbg, 0.3).' gui=NONE'
        " tab current
        execute 'hi! BufferlistHlCurnor ctermfg='.bufferlist#ColorName(l:hlcurnor).' ctermbg='.bufferlist#ColorName(l:gbg).' cterm=NONE guifg='.l:hlcurnor.' guibg='.l:gbg.' gui=NONE'
        execute 'hi! BufferlistHlCurmod ctermfg='.bufferlist#ColorName(l:hlcurmod).' ctermbg='.bufferlist#ColorName(l:gbg).' cterm=NONE guifg='.l:hlcurmod.' guibg='.l:gbg.' gui=NONE'
        " tab visible
        execute 'hi! BufferlistHlVisnor ctermfg='.bufferlist#ColorName(l:hlvisnor).' ctermbg='.bufferlist#ColorName(l:gbg).' cterm=NONE guifg='.l:hlvisnor.' guibg='.l:gbg.' gui=NONE'
        execute 'hi! BufferlistHlVismod ctermfg='.bufferlist#ColorName(l:hlvismod).' ctermbg='.bufferlist#ColorName(l:gbg).' cterm=NONE guifg='.l:hlvismod.' guibg='.l:gbg.' gui=NONE'
        " tab separator
        execute 'hi! BufferlistHlSepnor ctermfg='.bufferlist#ColorName(l:hlsepnor).' ctermbg='.bufferlist#ColorName(l:gbg).' cterm=NONE guifg='.l:hlsepnor.' guibg='.bufferlist#ColorMask(l:gbg, 0.3).' gui=NONE'
        execute 'hi! BufferlistHlSepmod ctermfg='.bufferlist#ColorName(l:gbg).'      ctermbg='.bufferlist#ColorName(l:gbg).' cterm=NONE guifg='.bufferlist#ColorMask(l:gbg, 0.3).' guibg='.bufferlist#ColorMask(l:gbg, 0.3).' gui=NONE'

        " prompt message
        hi! BufferlistPmtDefault ctermfg=Gray   ctermbg=NONE cterm=Bold guifg=#B1B3B8 guibg=NONE gui=Bold
        hi! BufferlistPmtNormal  ctermfg=Blue   ctermbg=NONE cterm=Bold guifg=#79BBFF guibg=NONE gui=Bold
        hi! BufferlistPmtSuccess ctermfg=Green  ctermbg=NONE cterm=Bold guifg=#95D475 guibg=NONE gui=Bold
        hi! BufferlistPmtWarning ctermfg=Yellow ctermbg=NONE cterm=Bold guifg=#EEBE77 guibg=NONE gui=Bold
        hi! BufferlistPmtError   ctermfg=Red    ctermbg=NONE cterm=Bold guifg=#F56C6C guibg=NONE gui=Bold

        " update bufferlist
        call bufferlist#TabUpdbuf()
    endfunction

    " --------------------------------------------------
    " bufferlist#ReopenBuild
    " --------------------------------------------------
    function! bufferlist#ReopenBuild(buf)
        if !isdirectory(g:bufferlist_datapath)
            call mkdir(g:bufferlist_datapath, 'p', 0777)
        endif
        if filereadable(s:bufferlist_reopenlist) && s:bufferlist_restover ==# 1
            let l:savelist = []
            let l:bufname = fnamemodify(bufname(a:buf), ':p')
            let l:buflist = filter(range(1, bufnr('$')), 'buflisted(v:val) && getbufvar(v:val, "&buftype") ==# ""')
            if index(l:buflist, a:buf) != -1
                for il in l:buflist
                    let l:enitem = fnamemodify(bufname(il), ':p')
                    if !empty(l:enitem)
                        if l:enitem ==# l:bufname
                            let l:enitem = substitute(l:enitem, ' ', '\\ ', 'g')
                            call add(l:savelist, l:enitem." C")
                        else
                            let l:enitem = substitute(l:enitem, ' ', '\\ ', 'g')
                            call add(l:savelist, l:enitem." X")
                        endif
                    endif
                endfor
                let s:bufferlist_reopendata = l:savelist
                call writefile(s:bufferlist_reopendata, s:bufferlist_reopenlist)
            endif
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#ReopenClose
    " --------------------------------------------------
    function! bufferlist#ReopenClose(buf)
        if !isdirectory(g:bufferlist_datapath)
            call mkdir(g:bufferlist_datapath, 'p', 0777)
        endif
        if filereadable(s:bufferlist_reopenlist) && s:bufferlist_restover ==# 1
            let l:savelist = []
            let s:bufferlist_reopendata = readfile(s:bufferlist_reopenlist)
            for il in s:bufferlist_reopendata
                let il = substitute(il, '\\ ', "\u0001", 'g')
                let l:rec = split(il, ' ', 1)
                if len(l:rec) >= 2
                    let l:deitem = substitute(l:rec[0], "\u0001", ' ', 'g')
                    if (l:deitem != a:buf)
                        let l:enitem = substitute(l:deitem, ' ', '\\ ', 'g')
                        call add(l:savelist, l:enitem." X")
                    endif
                endif
            endfor
            let s:bufferlist_reopendata = l:savelist
            call writefile(s:bufferlist_reopendata, s:bufferlist_reopenlist)
        endif
    endfunction

    " --------------------------------------------------
    " bufferlist#ReopenRestore
    " --------------------------------------------------
    function! bufferlist#ReopenRestore()
        if filereadable(s:bufferlist_reopenlist)
            let l:savelist = []
            let l:currfile = ''
            let s:bufferlist_reopendata = readfile(s:bufferlist_reopenlist)
            for il in s:bufferlist_reopendata
                let il = substitute(il, '\\ ', "\u0001", 'g')
                let l:rec = split(il, ' ', 1)
                if len(l:rec) >= 2
                    let l:deitem = substitute(l:rec[0], "\u0001", ' ', 'g')
                    if l:deitem != "" && filereadable(l:deitem)
                        if l:rec[1] ==# 'C'
                            let l:currfile = l:deitem
                        endif
                        silent execute "edit ".fnameescape(l:deitem)
                    endif
                endif
            endfor
            if !empty(l:currfile)
                silent execute "edit ".fnameescape(l:currfile)
            endif
        endif
        let s:bufferlist_restover = 1
    endfunction

    " --------------------------------------------------
    " bufferlist#BuildCmd
    " --------------------------------------------------
    function! bufferlist#BuildCmd(...) abort
        augroup bufferlist_cmd_sub
            autocmd!
            autocmd BufRead * call bufferlist#TabOpen()
            autocmd BufEnter,WinEnter,BufWipeout,BufWritePost * noautocmd call bufferlist#TabUpdbuf()
            autocmd TextChanged * call bufferlist#TabTupdbuf()
            autocmd ModeChanged [iI]:[n] call bufferlist#TabTupdbuf()
            if exists('g:bufferlist_reopen') && g:bufferlist_reopen ==# 1
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
        if g:bufferlist_autostart ==# 1
            autocmd VimEnter * call timer_start(0, {-> execute('BufferlistOpen', '')})
        endif
        if exists('g:bufferlist_reopen') && g:bufferlist_reopen ==# 1
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
    command!                         BufferlistOpen     call bufferlist#Open()
    command!                         BufferlistClose    call bufferlist#Close()
    command!                         BufferlistToggle   call bufferlist#Toggle()
    command! -nargs=? -complete=file BufferlistTabnew   call bufferlist#TabNew(<f-args>)
    command!                         BufferlistTabClose call bufferlist#TabClose()

endif

" ============================================================================
" Other
" ============================================================================
let &cpoptions = s:save_cpo
unlet s:save_cpo
