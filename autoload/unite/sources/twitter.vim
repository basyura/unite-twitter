let s:save_cpo = &cpo
set cpo&vim

let s:buf_name = 'unite_twitter_buffer'

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

let s:source.action_table['*'].inReplyTo = {
      \ 'description' : 'inReplyTo tweet',
      \ 'is_quit'     : 0,
      \ }

function! s:source.action_table['*'].inReplyTo.func(candidate)
  let id = a:candidate.source__in_reply_to_status_id
  let list = []
  while 1
    if id == ""
      break
    endif
    let tweet = rubytter#request("show" , id)
    call add(list , tweet)
    let id = tweet.in_reply_to_status_id
  endwhile
  echo list
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
    let args   = a:args
    call add(args , {"count" : 50 , "per_page" : 50})
    let result = rubytter#request(method , args)
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

  let tweets = map(result , 
        \ '{
        \ "word"   : s:ljust(v:val.user.screen_name , 15) . " : " . v:val.text,
        \ "source" : "twitter",
        \ "source__screen_name" : v:val.user.screen_name ,
        \ "source__text"        : v:val.text ,
        \ "source__status_id"   : v:val.id   ,
        \ "source__in_reply_to_status_id" : v:val.in_reply_to_status_id  ,
        \ "source__load_next"   : 0 ,
        \ }')

  "call add(tweets , {
        "\ "word"    : 'load more ...' ,
        "\ "source"  : "twitter" ,
        "\ "source__load_next" : 1 ,
        "\ "source__status_id" : result[-1].source__status_id ,
        "\ "source__method"    : self.name ,
        "\})

  return tweets
endfunction

function! unite#sources#twitter#define()
  let sources = map([
        \ {'name': 'list_statuses'},
        \ {'name': 'mentions'     },
        \ {'name': 'user_timeline'},
        \ {'name': 'show'},
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

