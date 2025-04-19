" My vimrc
set hidden

" Gui Font
set guifont=Consolas:h11:cANSI

" Cursor settings:
" Change the cursor from a blinking block in insert mode to a blinking
" vertical bar when entering insert mode

"  1 -> blinking block
"  2 -> solid block 
"  3 -> blinking underscore
"  4 -> solid underscore
"  5 -> blinking vertical bar
"  6 -> solid vertical bar

"Mode Settings
let &t_SI.="\e[5 q" "SI = INSERT mode
"let &t_SR.="\e[4 q" "SR = REPLACE mode
let &t_EI.="\e[1 q" "EI = NORMAL mode (ELSE)

" Make vim use bash login profile
set shell=/usr/bash " use bash
set shellcmdflag="-ic" "flag passed to shell to execute "!" and ":!" commands

" Case insensitive search
set ignorecase
set hlsearch

" General Mappings
" Quick buffer switching 
nnoremap <Leader>b :ls<CR>:b<space>
nnoremap <Leader>vb :ls<CR>:vert sb<space>

" Functions related Yank Ring Implementation
let g:yank_ring_registers = split('asdfghjklzxcvbnm', '\zs')


function! YankRingRotate()
  " Check the type of operation
  let l:event = v:event
  if has_key(l:event, 'operator')
    if l:event.operator ==# 'y'
      let l:text = @0
    elseif l:event.operator ==# 'd'
      let l:text = @1
    else
      return
    endif
  else
    return
  endif

  " Skip if the text is only blank lines or whitespace
  if empty(l:text) || l:text =~? '^\_s*$'
    return
  endif

  " Get yank ring from global variable, fallback to ['a','b','c','d','e']
  let l:ring = get(g:, 'yank_ring_registers', ['a', 'b', 'c', 'd', 'e'])

  " Rotate: shift down from end to start
  for i in range(len(l:ring) - 1, 0, -1)
    call setreg(l:ring[i], getreg(l:ring[i - 1]))
  endfor

  " Set the latest yank/delete into the first register
  call setreg(l:ring[0], l:text)
endfunction

augroup YankRing
	  autocmd!
	    autocmd TextYankPost * call YankRingRotate()
augroup END

function! RegisterRingPicker()
  let s:origin_win = win_getid()
  let s:origin_buf = bufnr('%')

  if exists('g:from_visual') && g:from_visual
    let s:visual_start = getpos("'<")
    let s:visual_end = getpos("'>")
    let s:visual_mode = visualmode()
  endif

  " Open scratch buffer
  new
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
  setlocal nonumber norelativenumber nowrap
  file [Register Picker]

  " Prepare register list
  let l:lines = ['" Select a register and press <Enter>', '']

  " Use yank ring from global var or default
  let l:ring = get(g:, 'yank_ring_registers', ['a', 'b', 'c', 'd', 'e'])

  " Show yank ring registers in order
  for r in l:ring
    let content = getreg(r)
    if !empty(content)
      call add(l:lines, r . ': ' . content)
    endif
  endfor

  " Add system-related registers
"  for r in split('%#*+', '\zs')
"    let content = getreg(r)
"    if !empty(content)
"      call add(l:lines, r . ': ' . content)
"    endif
"  endfor

  " Display the content
  call setline(1, l:lines)
  normal! gg

  " Handle selection
  nnoremap <buffer> <CR> :call PasteFromSelectedRegister()<CR>
endfunction


function! PasteFromSelectedRegister()
  let line = getline('.')
  if line =~ '^.'
    let reg = matchstr(line, '^\zs.')
    if reg != ''
      call win_gotoid(s:origin_win)

      if exists('g:from_visual') && g:from_visual
            \ && exists('s:visual_start') && exists('s:visual_end') && exists('s:visual_mode')

        call setpos("'<", s:visual_start)
        call setpos("'>", s:visual_end)

        if s:visual_mode ==# 'V'
          " Linewise visual mode
          execute "'<,'>delete _"
          execute 'put!' . reg
        elseif s:visual_mode ==# 'v'
          " Characterwise visual mode
          execute "normal! gv\"_d"
          execute "normal! \"" . reg . "P"
        else
          echo "Blockwise visual mode not yet supported."
        endif
      else
        " Normal mode paste
        execute 'normal! "' . reg . 'p'
      endif

      " Close the picker window
      for w in range(1, winnr('$'))
        if bufname(winbufnr(w)) ==# '[Register Picker]'
          execute w . 'wincmd c'
          break
        endif
      endfor
    endif
  endif
endfunction

xnoremap <silent> <leader>rp :<C-u>let g:from_visual = 1 \| call RegisterRingPicker()<CR>
nnoremap <silent> <leader>rp :let g:from_visual = 0 \| call RegisterRingPicker()<CR>

" The following will always been at the bottom of the this main file
" Source local machine-specific overrides
if filereadable(expand('~/.vimrc.local'))
  source ~/.vimrc.local
endif
