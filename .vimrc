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
"set shell=/usr/bash " use bash
"set shellcmdflag="-ic" "flag passed to shell to execute "!" and ":!" commands

" Case insensitive search
set ignorecase
set hlsearch

" Some basic tab settings for now. Just testing with vim files currently
au FileType vim setlocal tabstop=2 shiftwidth=2

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


" ============================================================================
" MARK MANAGER - CONFIGURATION & STATE
" ============================================================================

let g:mark_ring = []

" ============================================================================
" MARK MANAGER - PUSH & JUMP
" ============================================================================

function! MarkRingPush()
	let l:pos = getpos(".")
	let l:file = expand('%:p')
	let l:context = getline('.')

	" Prompt for optional label
	let l:label = input('Enter label for mark (optional): ')

	" If user hits Enter, fall back to a default label
	if empty(l:label)
		let l:label = 'line ' . l:pos[1]
	endif

	" Store mark with label
	call insert(g:mark_ring, {
				\ 'file': l:file,
				\ 'pos': l:pos,
				\ 'context': l:context,
				\ 'label': l:label
				\ }, 0)

	" Keep ring size to 10
	let g:mark_ring = g:mark_ring[:29]

	echo "Mark saved at " . l:pos[1] . ":" . l:pos[2]
endfunction

function! MarkRingJump()
	let line = getline('.')
	let index = str2nr(matchstr(line, '^\s*\zs\d\+'))

	if index < len(g:mark_ring)
		let mark = g:mark_ring[index]
		silent execute 'edit ' . fnameescape(mark['file'])
		call setpos('.', mark['pos'])
		redraw  " remove lingering messages
	endif

	" Close the picker window
	for w in range(1, winnr('$'))
		if bufname(winbufnr(w)) ==# '[Mark Picker]'
			execute w . 'wincmd c'
			break
		endif
	endfor
endfunction

function! MarkRingJumpSolo()
	let line = getline('.')
	let index = str2nr(matchstr(line, '^\s*\zs\d\+'))

	if index < len(g:mark_ring)
		let mark = g:mark_ring[index]
		silent execute 'edit ' . fnameescape(mark['file'])
		call setpos('.', mark['pos'])

		" Close all other windows
		only

		redraw
	endif
endfunction

" ============================================================================
" MARK MANAGER - EDIT, DELETE, CLOSE
" ============================================================================

function! MarkRingDelete()
	let line = getline('.')
	let index = str2nr(matchstr(line, '^\s*\zs\d\+'))

	if index >= 0 && index < len(g:mark_ring)
		call remove(g:mark_ring, index)
		call MarkRingPicker()  " Refresh the picker
	endif
endfunction


function! MarkRingEditLabel()
	let line = getline('.')
	let index = str2nr(matchstr(line, '^\s*\zs\d\+'))

	if index >= 0 && index < len(g:mark_ring)
		let old_label = get(g:mark_ring[index], 'label', '')
		let new_label = input('Edit label: ', old_label)
		if new_label !=# ''
			let g:mark_ring[index]['label'] = new_label
		endif
		call MarkRingPicker()
	endif
endfunction

" ============================================================================
" MARK MANAGER - PICKER WINDOW
" ============================================================================

function! MarkRingPicker()
	" Look for existing [Mark Picker] buffer
	for w in range(1, winnr('$'))
		if bufname(winbufnr(w)) ==# '[Mark Picker]'
			execute w . 'wincmd w'
			%delete _
			goto 1
			let l:picker_open = 1
			break
		endif
	endfor

	" Only create new buffer if one wasn't already open
	if !exists('l:picker_open')
		new
		setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
		setlocal nonumber norelativenumber nowrap
		file [Mark Picker]
	endif	

	let l:lines = [
      \ '" Shortcuts: <Enter>=Open Solo o=Split and Open  d=Delete  e=Edit',
      \ '"',
      \ '" Select a mark and press <Enter>',
      \ ''
      \ ]
	let l:file_groups = {}

	" Group marks by file
	for i in range(len(g:mark_ring))
		let mark = g:mark_ring[i]
		let file = mark['file']
		if !has_key(l:file_groups, file)
			let l:file_groups[file] = []
		endif
		call add(l:file_groups[file], {
					\ 'index': i,
					\ 'pos': mark['pos'],
					\ 'context': mark['context'],
					\ 'label': mark['label']
					\ })
	endfor

	" Determine max label width for alignment
	let l:max_label_width = 0
	for file in keys(l:file_groups)
		for entry in l:file_groups[file]
			let l:max_label_width = max([l:max_label_width, strlen(entry['label'])])
		endfor
	endfor

	" Format grouped and sorted lines
	for file in sort(keys(l:file_groups))
		call add(l:lines, '--- ' . file . ' ---')

		" Sort entries in this file group by line number
		let sorted_entries = sort(l:file_groups[file], {a, b -> a['pos'][1] - b['pos'][1]})

		for entry in sorted_entries
			let idx  = entry['index']
			let lnum = entry['pos'][1]
			let col  = entry['pos'][2]
			let label = printf('%-' . l:max_label_width . 's', entry['label'])
			let ctx = substitute(entry['context'], '\t', '⇥', 'g')
			let ctx = substitute(ctx, '\n', '', 'g')

			let lnum_str = printf('%5d', lnum)
			let col_str  = printf('%-2d', col)

			call add(l:lines, printf('  %d: %s:%s → %s → %s', idx, lnum_str, col_str, label, ctx))
		endfor
	endfor

	call setline(1, l:lines)
	normal! gg

	" Highlight file header lines
	syntax match MarkRingFileHeader /^--- .* ---$/
	highlight default link MarkRingFileHeader Title

	nnoremap <buffer> o :call MarkRingJump()<CR>
	nnoremap <buffer> d :call MarkRingDelete()<CR>
	nnoremap <buffer> e :call MarkRingEditLabel()<CR>
	nnoremap <buffer> <CR> :call MarkRingJumpSolo()<CR>
endfunction

" ============================================================================
" MARK MANAGER - SAVE / LOAD
" ============================================================================

function! MarkRingSave(...) abort
	let l:file = a:0 ? a:1 : expand('~/.vim_mark_ring.json')
	try
		call writefile([json_encode(g:mark_ring)], l:file)
		echo 'Mark ring saved to ' . l:file
	catch
		echoerr 'Error saving mark ring.'
	endtry
endfunction

function! MarkRingLoad(...) abort
	let l:file = a:0 ? a:1 : expand('~/.vim_mark_ring.json')

	if !filereadable(l:file)
		echoerr 'Mark ring file not found: ' . l:file
		return
	endif

	" Confirm if g:mark_ring is not empty
	if exists('g:mark_ring') && len(g:mark_ring) > 0
		let l:confirm = input('Load will overwrite existing marks. Continue? [y/N]: ')
		if l:confirm !~? '^y$'
			echo 'Load cancelled.'
			return
		endif
	endif

	try
		let l:json = join(readfile(l:file), "\n")
		let g:mark_ring = json_decode(l:json)
		echo 'Mark ring loaded from ' . l:file
	catch
		echoerr 'Error loading mark ring.'
	endtry
endfunction

command! -nargs=? MarkRingSave call MarkRingSave(<f-args>)
command! -nargs=? MarkRingLoad call MarkRingLoad(<f-args>)

" ============================================================================
" MARK MANAGER - USER MAPPINGS
" ============================================================================

nnoremap <leader>m :call MarkRingPush()<CR>
nnoremap <leader>mp :call MarkRingPicker()<CR>



" Template Task Folder Creation

create_jira_workspace() {
    if [ -z "$1" ]; then
        echo "Usage: create_jira_workspace JIRA-12345"
        return 1
    fi

    if [ -z "$workspace" ]; then
        echo "Error: Environment variable \$workspace is not set."
        echo "Please set it with: export workspace=/path/to/your/base/folder"
        return 1
    fi

    JIRA_ID="$1"
    BASE_DIR="$workspace/$JIRA_ID"
    TEMPLATE_PATH="$workspace/Templates/checklist.xls"
    DEST_CHECKLIST="$BASE_DIR/Checklist-$JIRA_ID.xls"

    # Create directory structure
    mkdir -p "$BASE_DIR/Testing"
    mkdir -p "$BASE_DIR/Documentation"
    touch "$BASE_DIR/Analysis.sql"

    # Copy and rename checklist if the template exists
    if [ -f "$TEMPLATE_PATH" ]; then
        cp "$TEMPLATE_PATH" "$DEST_CHECKLIST"
    else
        echo "Warning: Template checklist file not found at $TEMPLATE_PATH"
    fi

    echo "Workspace created for $JIRA_ID:"
    echo " - $BASE_DIR/"
    echo " - $BASE_DIR/Analysis.sql"
    echo " - $BASE_DIR/Testing/"
    echo " - $BASE_DIR/Documentation/"
    if [ -f "$DEST_CHECKLIST" ]; then
        echo " - $DEST_CHECKLIST"
    fi
}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" The following will always been at the bottom of the this main file
" Source local machine-specific overrides
if filereadable(expand('~/.vim/vimrc.local'))
	source ~/.vim/vimrc.local
endif
