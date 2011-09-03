
command! UniteTwitterPost :call s:open_buffer()

function! s:open_buffer()
  let bufnr = bufwinnr('unite_twitter')
  if bufnr > 0
    exec bufnr.'wincmd w'
  else
    execute 'below split unite_twitter' 
    execute '2 wincmd _'
    let &filetype = 'unite_twitter'
  endif
  nnoremap <buffer> <silent> <CR> :call <SID>post()<CR>
  startinsert!
endfunction

function! s:post()
  redraw | echo 'sending ... ' | sleep 1
  let text  = join(getline(1, "$"))
  try
    call rubytter#request('update' , text)
  catch
    echoerr v:exception
    return
  endtry
  bd!
  redraw | echo 'sending ... ok'
endfunction

augroup UniteTwitter
  autocmd! UniteTwitter
  autocmd FileType    unite_twitter call s:unite_twitter_settings()
  autocmd BufWinLeave unite_twitter call s:save_history_at_leave()
augroup END

function! s:unite_twitter_settings()
  setlocal bufhidden=delete 
  setlocal nobuflisted
  setlocal noswapfile
  nnoremap <buffer> <silent> q :bd!<CR>
  nnoremap <buffer> <silent> <C-s> :call <SID>show_history()<CR>0
  inoremap <buffer> <silent> <C-s> <ESC>:call <SID>show_history()<CR>0
  
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