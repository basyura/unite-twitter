
if exists('g:loaded_unite_twitter')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

command! UniteTwitterPost :call s:open_buffer()

augroup UniteTwitter
  autocmd! UniteTwitter
  autocmd FileType    unite_twitter call s:unite_twitter_settings()
  autocmd BufWinLeave unite_twitter call s:save_history_at_leave()
augroup END

function! s:open_buffer()
  let bufnr = bufwinnr('unite_twitter')
  if bufnr > 0
    exec bufnr.'wincmd w'
  else
    execute 'below split unite_twitter' 
    execute '2 wincmd _'
  endif
  setlocal modifiable
  silent %delete _
  let &filetype = 'unite_twitter'
  startinsert!
endfunction

function! s:post()
  let text  = join(getline(1, "$"))
  if strchars(text) > 140
    call unite#util#print_error("over 140 chars")
    return
  endif
  redraw | echo 'sending ... ' | sleep 1
  try
    let param = exists("b:post_param") ? b:post_param : {}
    call rubytter#request('update' , text , param)
  catch
    echoerr v:exception
    return
  endtry
  bd!
  redraw | echo 'sending ... ok'
endfunction

function! s:unite_twitter_settings()
  setlocal bufhidden=delete 
  setlocal nobuflisted
  setlocal noswapfile
  setlocal modifiable
  setlocal nomodified
  nnoremap <buffer> <silent> q :bd!<CR>
  nnoremap <buffer> <silent> <C-s> :call <SID>show_history()<CR>0
  inoremap <buffer> <silent> <C-s> <ESC>:call <SID>show_history()<CR>0
  nnoremap <buffer> <silent> <CR>  :call <SID>post()<CR>
  
  :0
  startinsert!
  " i want to judge by buffer variable
  if !exists('s:unite_twitter_bufwrite_cmd')
    autocmd BufWriteCmd <buffer> echo 'please enter to tweet'
    let s:unite_twitter_bufwrite_cmd = 1
  endif
endfunction

" for recovery tweet
let s:history = []

function! s:show_history()
  let no = len(s:history)
  if(no == 0)
    return
  endif
  let no = (exists('b:history_no') ? b:history_no : no) - 1
  if no == -1
    let no = len(s:history) - 1
  endif
  silent %delete _
  silent execute 'normal i' . s:history[no]
  let b:history_no = no
endfunction

function! s:save_history_at_leave()
  let msg = join(getline(1, "$"))
  if msg !~ '^\s\?$'
    call add(s:history , msg)
  endif
endfunction

let g:loaded_unite_twitter = 1

let &cpo = s:save_cpo
unlet s:save_cpo
