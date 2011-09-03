let s:save_cpo = &cpo
set cpo&vim

let s:buf_name = 'unite_twitter_buffer'

let s:cache_directory = g:unite_data_directory . '/twitter'
let s:screen_name_cache_path = s:cache_directory . '/screen_name'

let s:screen_name_cache = {}
if filereadable(s:screen_name_cache_path)
  for v in readfile(s:screen_name_cache_path)
    let s:screen_name_cache[v] = 1
  endfor
else
  if !isdirectory(s:cache_directory)
    call mkdir(s:cache_directory , "p")
  endif
endif

let s:friends = []

let s:source = {
      \ 'name'  : 'twitter' ,
      \ 'hooks' : {} ,
      \ 'action_table'   : {'*': {}} ,
      \ 'default_action' : 'preview' ,
      \ }

let s:source.action_table['*'].preview = {
      \ 'description' : 'preview this tweet',
      \ 'is_quit'     : 0,
      \ }

function! s:source.action_table['*'].preview.func(candidate)

    "if a:candidate.source__load_next
      "execute ":Unite " . a:candidate.method
      "echo 'now loading ....'
      "return
    "endif

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
      \ 'is_quit'     : 0,
      \ }

function! s:source.action_table['*'].reply.func(candidate)
    
    let bufnr = bufwinnr(s:buf_name)
    if bufnr > 0
      exec bufnr.'wincmd w'
    else
      execute 'below split ' . s:buf_name
    end
    execute '3 wincmd _'
    let &filetype = 'unite_twitter'
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

let s:source.action_table['*'].user_timeline = {
      \ 'description' : 'user timeline',
      \ 'is_quit'     : 0,
      \ }

function! s:source.action_table['*'].user_timeline.func(candidate)
  execute unite#start([['twitter/user_timeline' , a:candidate.source__screen_name]])
endfunction
"
" action - in reply to 
"
let s:source.action_table['*'].inReplyTo = {
      \ 'description' : 'inReplyTo tweet',
      \ }

function! s:source.action_table['*'].inReplyTo.func(candidate)
  let id = a:candidate.source__in_reply_to_status_id
  if id == ""
    call unite#util#print_error("no reply")
    return
  endif
  execute unite#start([['twitter/show' , a:candidate.source__status_id]])
endfunction

function! s:source.hooks.on_close(args, context)
  let no = bufnr(s:buf_name)
  try | execute "bd! " . no | catch | endtry
  call writefile(keys(s:screen_name_cache) , s:screen_name_cache_path)
endfunction

function! s:source.gather_candidates(args, context)

  if !exists("s:user_info")
    let s:user_info = rubytter#request("verify_credentials")
  endif

  let method = substitute(self.name , "twitter/" , "" , "")
  if method == 'twitter'
    let method = 'home_timeline'
  endif

  try
    if method == 'show'
      let result = s:gather_candidates_show(a:args, a:context)
    elseif method == 'friends'
      return s:gather_candidates_friends(a:args, a:context)
    else
      let args = a:args
      call add(args , {"count" : 50 , "per_page" : 50})
      let result = rubytter#request(method , args)
    endif
  catch 
    return map(split(v:exception , "\n") , '{
          \ "word"   : v:val ,
          \ "source" : "common" ,
          \ }')
  endtry

  if type(result) == 4
    let tmp = [result] | unlet result
    let result = tmp
  endif

  let tweets = []
  for t in result
    call add(tweets , {
        \ "word"   : s:ljust(t.user.screen_name , 15) . " : " . t.text,
        \ "source" : "twitter",
        \ "source__screen_name" : t.user.screen_name ,
        \ "source__status_id"   : t.id   ,
        \ "source__in_reply_to_status_id" : t.in_reply_to_status_id  ,
          \ })
    let s:screen_name_cache[t.user.screen_name] = 1
  endfor

  return tweets
endfunction

function! s:gather_candidates_show(args, context)
  let id = a:args[0]
  let list = []
  while 1
    if id == ""
      return list
    endif
    let tweet = rubytter#request("show" , id)
    call add(list , tweet)
    let id = tweet.in_reply_to_status_id
  endwhile
endfunction

function! s:gather_candidates_friends(args, context)

  if !unite#util#input_yesno("it takes long time")
    return []
  endif

  if len(s:friends) != 0
    return s:friends
  endif

  let friends = []
  let next_cursor = "-1"
  while 1
    " how to get my screen name ?
    let tmp = rubytter#request("friends" , s:user_info.screen_name , {"cursor" : next_cursor})
    call extend(friends , tmp.users)
    let next_cursor = tmp.next_cursor
    if next_cursor == "0"
      break
    endif
  endwhile

  let candidates = []
  for v in friends
    let tweets =  {
          \ "word"   : s:ljust(v.screen_name , 15) . " : " . v.description ,
          \ "source" : "twitter",
          \ "source__screen_name" : v.screen_name ,
          \ "source__status_id"   : "" ,
          \ "source__in_reply_to_status_id" : ""  ,
          \ }
      call add(candidates , tweets)
  endfor
  let s:friends = candidates
  return candidates
endfunction

function! unite#sources#twitter#define()
  let sources = map([
        \ {'name': 'list_statuses'},
        \ {'name': 'mentions'     },
        \ {'name': 'user_timeline'},
        \ {'name': 'show'},
        \ {'name': 'friends'},
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
  echo 'sent ... ' . text 
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

