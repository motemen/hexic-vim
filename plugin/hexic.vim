" hexic.vim
" Version: 20070529
" Author:  motemen <motemen@gmail.com>

" Settings
" ========
let g:hexic_colors = [ 'red', 'yellow', 'purple', 'lightblue', 'springgreen', 'skyblue', 'seagreen' ]
let g:hexic_board_width  = 10
let g:hexic_board_height = 17

" Commands
" ========
command! HexicInit call s:Initialize()

" Terms {{{
" =========
" Hexagon - blocks (of any colors) arranged as:
" .   0   .
"   5   1  
" .   .   .
"   4   2  
" .   3   .

" List of points
let s:hexagon_template = [ [0, 0], [1, 2], [3, 2], [4, 0], [3, -2], [1, -2] ]

" Flower - a hexagon of same color

" Triangle - blocks (of any colors) arranged as:
" .   0   .
"   .   1
" .   2   .
" or
" .   0   .
"   2   .
" .   1   .

" List of list of points
let s:triangle_templates = [ [[0, 0], [1, 2], [2, 0]], [[0, 0], [2, 0], [1, -2]] ]

" Cluster - a triangle of same color
" }}}

" Main {{{
" ========
function! s:Initialize()
    " Setup board
    enew!
    set buftype=nofile
    for l in range(g:hexic_board_height)
        if l % 2 == 0
            normal! a   
        endif
        for c in range((g:hexic_board_width + l % 2) / 2)
            execute 'normal! ' . (c ? 'a' : 'i') . nr2char(char2nr('a') + Random(len(g:hexic_colors))) . '   '
        endfor
        normal o
    endfor

    syntax clear
    syntax case match

    " Blocks/bombs
    let symbol = char2nr('a')
    for i in range(len(g:hexic_colors))
        let char = nr2char(symbol + i)
        let uchar = toupper(char)
        execute printf('syntax match hexBlock%s +\c%s+', uchar, char)
        execute printf('highlight hexBlock%s   guifg=%s', uchar, g:hexic_colors[i])
        execute printf('highlight hexBlock%sHL guifg=%s gui=bold,underline', uchar, g:hexic_colors[i])

        execute printf('syntax match hexBomb%s  +%s+', uchar, i)
        execute printf('highlight hexBomb%s    guibg=%s', uchar, g:hexic_colors[i])
        execute printf('highlight hexBomb%sHL  guibg=%s gui=bold,underline', uchar, g:hexic_colors[i])
    endfor

    " Stars
    syntax match hexStar +\*+
    highlight hexStar    guifg=white
    highlight hexStarHL  guifg=white gui=bold,underline

    " Black pearls
    syntax match hexPearl +[v^]+
    highlight hexPearl   guifg=black
    highlight hexPearlHL guifg=black gui=bold,underline

    highlight hexBlink guifg=red guibg=white

    " Behavior
    autocmd CursorMoved <buffer> call HighlightSelection()
    nnoremap <buffer> <silent> r :call Rotate(-1)<CR>
    nnoremap <buffer> <silent> R :call Rotate(+1)<CR>

    let b:hexic_rotate_count = 0
endfunction    

" Return the selected blocks' position in clockwise order.
function! GetSelection()
    let [_, cursor_line, cursor_col, cursor_off] = getpos('.')
    let cursor_col += cursor_off

    let ch = GetChar([cursor_line, cursor_col])

    if ch == '^'
        " Pearl
        " .   X   .   
        "   .   .     
        " .   ^   .
        "   X   X     
        " .   .   .   
        return [[cursor_line - 2, cursor_col], [cursor_line + 1, cursor_col - 2], [cursor_line + 1, cursor_col + 2]]
    elseif ch == 'v'
        " Pearl
        " .   .   .
        "   X   X  
        " .   v   .
        "   .   .  
        " .   X   .
        return [[cursor_line + 2, cursor_col], [cursor_line - 1, cursor_col + 2], [cursor_line - 1, cursor_col - 2]]
    elseif ch == '*'
        " Star
        " .   X   .
        "   X   X  
        " .   *   .
        "   X   X  
        " .   X   .
        return [[cursor_line - 2, cursor_col], [cursor_line - 1, cursor_col - 2], [cursor_line + 1, cursor_col - 2], [cursor_line + 2, cursor_col], [cursor_line + 1, cursor_col + 2], [cursor_line - 1, cursor_col + 2]]
    else
        " Block
        if cursor_line % 2 == 0
            let col = cursor_col / 4 * 4 + 1
        else
            let col = (cursor_col - 2) / 4 * 4 + 3
        endif
        if cursor_col > col
            return [[cursor_line, col], [cursor_line + 1, col + 2], [cursor_line - 1, col + 2]]
        else
            return [[cursor_line, col], [cursor_line - 1, col - 2], [cursor_line + 1, col - 2]]
        endif
    end
endfunction

function! ClearHighlightSelection()
    let symbol = char2nr('A')
    for i in range(len(g:hexic_colors))
        execute 'syntax clear hexBlock' . nr2char(symbol + i) . 'HL'
        execute 'syntax clear hexBomb' . nr2char(symbol + i) . 'HL'
        execute 'syntax clear hexPearlHL'
        execute 'syntax clear hexStarHL'
    endfor
endfunction

function! HighlightSelection()
    call ClearHighlightSelection()

    let pos = GetSelection()
    for p in pos
        let [line, col] = p
        if line >= 0 && col >= 0
            let ch = GetChar(p)
            if ch == ' ' || ch == ''
                continue
            elseif ch == 'v' || ch == '^'
                let group = 'Pearl'
            elseif ch == '*'
                let group = 'Star'
            elseif ch =~ '\a'
                let group = 'Block' . toupper(ch)
            elseif ch =~ '\d'
                let group = 'Bomb' . toupper(nr2char(char2nr('a') + ch))
            endif
            if exists('group')
                execute printf('syntax match hex%sHL +\%%%dl\%%%dc.+', group, line, col)
            endif
        endif
    endfor
endfunction

" Get char at given position
function! GetChar(pos)
    let line = getline(a:pos[0])
    return line[a:pos[1] - 1]
endfunction

" Set char at given position
function! SetChar(pos, ch)
    let ch = a:ch[0]
    let pos_save = getpos('.')
    call cursor(a:pos)
    execute 'normal! r' . ch
    call setpos('.', pos_save)
endfunction

function! Rotate(dir)
    let poss = GetSelection()
    let symbols = map(copy(poss), 'GetChar(v:val)')
    for s in symbols
        if !len(s)
            return
        endif
    endfor

    let len = len(poss)
    for i in range(len)
        call SetChar(poss[(i+a:dir+len) % len], symbols[i])
    endfor

    let clusters = FindClusters(poss)
    let flowers = FindFlowers(poss)
    let blocks = Uniq(sort(Flatten(clusters) + Flatten(flowers)))

    if GetChar(getpos('.')[1:2]) !~ '[*^v]'
        let b:hexic_rotate_count += 1
        if !len(blocks)
            if b:hexic_rotate_count == 3
                let b:hexic_rotate_count = 0
            else
                call ClearHighlightSelection()
                redraw
                sleep 200ms
                return Rotate(a:dir)
            endif
        endif
    endif
    while len(blocks)
        call ClearHighlightSelection()

        " Make stars
        for f in flowers
            if GetChar(f[0]) != '*'
                call SetChar(PtAdd(f[0], [2, 0]), '*')
            else
                call SetChar(PtAdd(f[0], [2, 0]), '^v'[Random(2)])
            endif
        endfor

        call BlinkBlocks(blocks)

        " Erase blocks
        for i in range(len(blocks))
            call DropBlocks(blocks[i])
            for j in range(i + 1, len(blocks) - 1)
                " Same column, above
                if blocks[j][1] == blocks[i][1] && blocks[j][0] < blocks[i][0]
                    let blocks[j][0] += 2
                endif
            endfor
        endfor

        let columns = { }
        for block in blocks
            let columns[block[1]] = max([get(columns, block[1], -1), block[0]])
        endfor
        let poss = []
        for col in keys(columns)
            let line = columns[col]
            while line > 0
                call add(poss, [line, col])
                let line -= 2
            endwhile
        endfor

        let clusters = FindClusters(poss)
        let flowers = FindFlowers(poss)
        let blocks = Uniq(sort(Flatten(clusters) + Flatten(flowers)))
    endwhile
    let b:hexic_rotate_count = 0
endfunction

function! TrianglesIncluding(p)
    let triangles = []
    for t in s:triangle_templates
        call extend(triangles, ExpandTemplate(t, a:p))
    endfor
    return sort(triangles)
endfunction

function! HexagonsIncluding(p)
    return sort(ExpandTemplate(s:hexagon_template, a:p))
endfunction

" Blocks from template
" Example:
"   ExpandTemplate([[0, 0], [1, 2]], [100, 100])
"       == [[[101, 100], [101, 102]], [[99, 98], [100, 100]]]
" Last argument if offset
function! ExpandTemplate(template, p, ...)
    let sets = []
    for axis in a:template
        call add(sets, map(copy(a:template), a:0 ? 'PtAdd(PtAdd(v:val, PtSub(a:p, axis)), a:1)' : 'PtAdd(v:val, PtSub(a:p, axis))'))
    endfor
    return sets
endfunction

function! PtAdd(p1, p2)
    return [ a:p1[0] + a:p2[0], a:p1[1] + a:p2[1] ]
endfunction

function! PtSub(p1, p2)
    return [ a:p1[0] - a:p2[0], a:p1[1] - a:p2[1] ]
endfunction

" Find clusters containing points
function! FindClusters(ps)
    let clusters = Uniq(filter(Flatten(map(copy(a:ps), 'TrianglesIncluding(v:val)')), 'MakesCluster(v:val)'))
    return clusters
endfunction

" Find flowers containing points
function! FindFlowers(ps)
    let flowers = Uniq(filter(Flatten(map(copy(a:ps), 'HexagonsIncluding(v:val)')), 'MakesFlower(v:val)'))
    return flowers
endfunction

" Return 1 if given points make cluster
function! MakesCluster(ps)
    let s = map(map(copy(a:ps), 'GetChar(v:val)'), 'v:val =~ "\\d" ? nr2char(char2nr("a")+v:val) : v:val')
    if s[0] == '' || s[1] == '' || s[2] == ''
        return 0
    endif
    return tolower(s[0]) == tolower(s[1]) && tolower(s[1]) == tolower(s[2])
endfunction

function! MakesFlower(ps)
    let ss = map(map(copy(a:ps), 'GetChar(v:val)'), 'v:val =~ "\\d" ? nr2char(char2nr("a")+v:val) : v:val')
    for s in ss
        if s == ''
            return 0
        endif
    endfor
    for i in range(len(ss) - 1)
        if tolower(ss[i]) != tolower(ss[i+1])
            return 0
        endif
    endfor
    return 1
endfunction

function! DropBlocks(pos)
    let pos_save = getpos('.')

    " Drop blocks
    call cursor(a:pos)

    " Drop new blocks
    if line('.') > 2
        if line('.') == 3
            normal! kdkdjjP
        else
            normal! kdk100kdjjP
        endif
        if GetChar(getpos('.')[1:2]) == ' '
            let counter = 1
        else
            let counter = 0
        endif
        while line('.') != 1
            if counter % 2 == 0
                normal! ki 
            else
                execute 'normal! ki' . nr2char(char2nr('a') + Random(len(g:hexic_colors)))
            endif
            let counter += 1
        endwhile
    else
        execute 'normal! r' . nr2char(char2nr('a') + Random(len(g:hexic_colors)))
    endif

    call setpos('.', pos_save)
endfunction

function! BlinkBlocks(poss)
    for c in range(6)
        if c % 2 == 0
            for pos in a:poss
                "execute 'syntax match hexBlink +\%' . pos[0] . 'l\%' . pos[1] . 'c.+'
                execute printf('syntax match hexBlink +\%%%dl\%%%dc.+', pos[0], pos[1])
            endfor
        else
            execute 'syntax clear hexBlink'
        endif
        redraw
        sleep 100ms
    endfor
endfunction
" }}}

" Common Functions {{{
" ====================

" Make elements unique in a sorted list
function! Uniq(list)
    let list = []
    for a in a:list
        if !len(list) || list[-1] != a
            call add(list, a)
        endif
    endfor
    return list
endfunction

" Flatten list
function! Flatten(list)
    let list = []
    for a in a:list
        call extend(list, a)
    endfor
    return list
endfunction

" Generate random number
let random_num = strftime('%S') * strftime('%m') * strftime('%d')
function! Random(ub)
    let n = printf('%010d', g:random_num * 673 + 944)[3:8]
    let g:random_num = n
    return n % a:ub
endfunction

function! ByDepth(p1, p2)
    if a:p1[0] == a:p2[0]
        return a:p1[1] == a:p2[1] ? 0 : a:p1[1] > a:p2[1] ? 1 : -1;
    elseif a:p1[0] > a:p2[0]
        return -1
    else
        return 1
    endif
endfunction
" }}}
