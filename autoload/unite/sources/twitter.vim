let s:save_cpo = &cpo
set cpo&vim

let s:buf_name = 'unite_twitter_buffer'

let s:source = {
      \ 'name': 'twitter' ,
      \ 'hooks': {},
      \ 'action_table': {'*': {}},
      \ }

let s:source.action_table['*'].preview = {
      \ 'description' : 'preview this tweet',
      \ 'is_quit' : 0,
      \ }

function! s:source.action_table['*'].preview.func(candidate)
    let bufnr = bufwinnr(s:buf_name)
    if bufnr > 0
      exec bufnr.'wincmd w'
    else
      execute 'below split ' . s:buf_name
    end
    execute '3 wincmd _'
    setlocal modifiable
    silent %delete _
    setlocal bufhidden=hide
    setlocal noswapfile
    call append(0 , a:candidate.word)
    setlocal nomodified
    setlocal nomodifiable
    :0
    execute 'wincmd p'
endfunction

function! s:initialize_yesno_actions()
  let list = [
        \ {'action' : 'favorite'        , 'desc' : 'favorite tweet' , 'msg' : 'favorite this tweet ?'} ,
        \ {'action' : 'remove_favorite' , 'desc' : 'remove tweet'   , 'msg' : 'remove this tweet ?'  } ,
        \ {'action' : 'retweet'         , 'desc' : 'retweet'        , 'msg' : 'retweet this tweet ?' } ,
        \ {'action' : 'remove_status'   , 'desc' : 'remove tweet'   , 'msg' : 'remvoe this tweet ?'  } ,
        \ ]
  for v in list
    let s:source.action_table['*'][v.action] = {
          \ 'description' : v.desc ,
          \ 'is_quit'     : 0 ,
          \ 'msg'         : v.msg ,
          \ 'action'      : v.action ,
          \ }
    function s:source.action_table['*'][v.action].func(candidate) dict
      if !unite#util#input_yesno(self.msg)
        return
      endif
      call rubytter#request(self.action , a:candidate.source__status_id)
    endfunction
  endfor
endfunction

call s:initialize_yesno_actions()

let s:source.action_table['*'].reply = {
      \ 'description' : 'reply tweet',
      \ 'is_quit' : 0,
      \ }

function! s:source.action_table['*'].reply.func(candidate)
    let bufnr = bufwinnr(s:buf_name)
    if bufnr > 0
      exec bufnr.'wincmd w'
    else
      execute 'below split ' . s:buf_name
    end
    execute '3 wincmd _'
    setlocal modifiable
    silent %delete _
    setlocal bufhidden=hide
    setlocal noswapfile
    call append(0 , '@' . a:candidate.source__screen_name . ' ')
    setlocal nomodified

    let b:post_param = {"in_reply_to_status_id" : a:candidate.source__status_id}

    nnoremap <buffer> <silent> <CR> :call <SID>post()<CR>
    :0
    startinsert!
endfunction

function! s:source.hooks.on_close(args, context)
  let no = bufnr(s:buf_name)
  try | execute "bd! " . no | catch | endtry
endfunction

function! s:source.gather_candidates(args, context)
  let method = substitute(self.name , "twitter/" , "" , "")
  if method == 'twitter'
    let method = 'home_timeline'
  endif

  try
    let result = rubytter#request(method , a:args)
  catch 
    return map(split(v:exception , "\n") , '{
          \ "word"   : v:val ,
          \ "source" : "common" ,
          \ }')
  endtry
  return map(result , 
        \ '{
        \ "word": s:ljust(v:val.user.screen_name , 15) . " : " . v:val.text,
        \ "source": "twitter",
        \ "source__screen_name" : v:val.user.screen_name ,
        \ "source__text"        : v:val.text ,
        \ "source__status_id"   : v:val.id   ,
        \ }')
endfunction

function! unite#sources#twitter#define()
  let sources = map([
        \ {'name': 'list_statuses'},
        \ {'name': 'mentions'     },
        \ {'name': 'user_timeline'},
        \ ],
        \ 'extend(copy(s:source),
        \  extend(v:val, {"name": "twitter/" . v:val.name,
        \  "description": "candidates from twitter of " . v:val.name}))')
  call add(sources , s:source)
  return sources
endfunction

function! s:post()
  let text  = join(getline(1, "$"))
  let param = exists("b:post_param") ? b:post_param : {}
  call rubytter#request('update' , text , param)
  unlet b:post_param
  bd!
  redraw
  echo 'sended .. ' . text 
endfunction

function! s:ljust(str, size, ...)
  let str = a:str
  let c   = a:0 > 0 ? a:000[0] : ' '
  while 1
    if strwidth(str) >= a:size
      return str
    endif
    let str .= c
  endwhile
  return str
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo

