
let s:save_cpo = &cpo
set cpo&vim

let s:buf_name = 'unite_twitter'

let s:cache_directory = g:unite_data_directory . '/twitter'
let s:screen_name_cache_path = s:cache_directory . '/screen_name'

let s:api_alias = {
      \ 'twitter' : 'home_timeline' ,
      \ 'list'    : 'list_statuses' ,
      \ 'user'    : 'user_timeline' ,
      \}

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

let s:TweetManager = {}

function! s:TweetManager.request(...)
  let tweet = call('rubytter#request' , a:000)
  for t in tweet
    let self[t.id] = t
  endfor

  let cache = get(self, a:1, [])
  call extend(cache, tweet, 0)
  let self[a:1] = cache[0:100]

  return copy(cache)
endfunction

function! s:TweetManager.get(id)
  if has_key(self , a:id)
    return self[a:id]
  endif
  let tweet = rubytter#request("show" , a:id)
  let self[tweet.id] = tweet
  let s:screen_name_cache[tweet.user.screen_name] = 1
  return tweet
endfunction

let s:friends = []

let s:source = {
      \ 'name'  : 'twitter' ,
      \ 'hooks' : {} ,
      \ 'action_table'   : {'*': {}} ,
      \ 'default_action' : 'preview' ,
      \ }

function! s:source.gather_candidates(args, context)

  if !exists("s:user_info")
    let s:user_info = rubytter#request("verify_credentials")
  endif

  let method = substitute(self.name , "twitter/" , "" , "")
  let method = get(s:api_alias , method , method)

  try
    let Fn = function('s:gather_candidates_' . method)
  catch
    let Fn = function('s:gather_candidates')
  endtry

  try
    let result = Fn(method, a:args, a:context)
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
    let word = s:ljust(t.user.screen_name , 15) . " : "
    if get(t , "favorited" , "") == 'true' | let word .= '★ ' | endif
    let word .= t.text
    let abbr = substitute(unite#util#truncate(word , winwidth(0) - 9) , '\s*$' , '' , '') 
    if word != abbr
      let abbr .= '..'
    endif

    call add(tweets , {
        \ "word"   : word ,
        \ "abbr"   : abbr ,
        \ "source" : "twitter",
        \ "source__screen_name" : t.user.screen_name ,
        \ "source__status_id"   : t.id   ,
        \ "source__in_reply_to_status_id" : t.in_reply_to_status_id  ,
        \})
  endfor

  return tweets
endfunction

let s:last_ids = {}

function! s:gather_candidates(method, args, context)
  let param = {"count" : 100 , "per_page" : 100 , "rpp" : 100 }

  let last_id = get(s:last_ids, a:method, "")
  if last_id != ""
    let param.since_id = last_id
  endif

  let args = a:args
  call add(args , param)

  let tweets = s:TweetManager.request(a:method , args)
  if len(tweets) != 0
    let s:last_ids[a:method] = tweets[0].id
  end

  return tweets
endfunction

function! s:gather_candidates_user_timeline(method, args, context)
  let args = a:args
  if len(args) == 0
    call add(args , s:user_info.screen_name)
  endif
  return s:gather_candidates(a:method, args, a:context)
endfunction

function! s:gather_candidates_show(method, args, context)
  let id = a:args[0]
  let list = []
  while 1
    if id == ""
      return list
    endif
    let tweet = s:TweetManager.get(id)
    call add(list , tweet)
    let id = tweet.in_reply_to_status_id
  endwhile
endfunction

function! s:gather_candidates_friends(method, args, context)

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
    let tmp = s:TweetManager.request("friends" , s:user_info.screen_name , {"cursor" : next_cursor})
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

function! s:gather_candidates_search(method, args, context)
  let word = len(a:args) == 0 ? input("search word : ") : join(a:args , " ")
  return s:gather_candidates(a:method, [word], a:context)
endfunction

function! s:gather_candidates_favorites(method, args, context)
  let args = a:args
  if len(args) == 0
    call add(args , s:user_info.screen_name)
  endif
  return s:gather_candidates(a:method, args, a:context)
endfunction

function! s:gather_candidates_list_statuses(method, args, context)
  let args = a:args
  if len(args) == 1
    let args = [s:user_info.screen_name , args[0]]
  endif
  return s:gather_candidates(a:method, args, a:context)
endfunction

let s:source.action_table['*'].preview = {
      \ 'description' : 'preview this tweet',
      \ 'is_quit'     : 0,
      \ }

function! s:source.action_table['*'].preview.func(candidate)

    let bufnr = bufwinnr(s:buf_name)
    if bufnr > 0
      execute bufnr.'wincmd w'
    else
      execute 'below split ' . s:buf_name
    end
    let &filetype = 'unite_twitter_preview'
    setlocal modifiable
    silent %delete _
    call append(0 , a:candidate.word)

    for reply in s:reply_list(a:candidate.source__in_reply_to_status_id)
      call append(line('$') - 1 , s:ljust(reply.user.screen_name , 15) . ' : ' . reply.text)
    endfor

    execute (line('$') + 1) . ' wincmd _'

    setlocal nomodified
    setlocal nomodifiable
    call cursor(1,1)
    redraw
    execute 'wincmd p'
endfunction

augroup UniteTwitterPreview
  autocmd! UniteTwitterPreview
  autocmd FileType unite_twitter_preview call s:unite_twitter_preview_settings()
augroup END

function! s:unite_twitter_preview_settings()
  setlocal bufhidden=wipe
  setlocal nobuflisted
  setlocal noswapfile
endfunction

function! s:reply_list(in_reply_to_status_id)
  let id = a:in_reply_to_status_id
  let list = []
  while 1
    if id == ""
      return list
    endif
    try
      let tweet = s:TweetManager.get(id)
    catch
      echo v:exception
      echo 'id = ' . id
      break
    endtry
    call add(list , tweet)
    let id = tweet.in_reply_to_status_id
  endwhile
  return list
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
    call append(0 , '@' . a:candidate.source__screen_name . ' ')
    let &filetype = 'unite_twitter'

    let b:post_param = {"in_reply_to_status_id" : a:candidate.source__status_id}
endfunction

let s:source.action_table['*'].user = {
      \ 'description' : 'user timeline',
      \ 'is_quit'     : 0,
      \ }

function! s:source.action_table['*'].user.func(candidate)
  execute unite#start([['twitter/user' , a:candidate.source__screen_name]])
endfunction
"
" action - in reply to 
"
let s:source.action_table['*'].inReplyTo = {
      \ 'description' : 'inReplyTo tweet',
      \ 'is_quit'     : 0,
      \ }

function! s:source.action_table['*'].inReplyTo.func(candidate)
  let id = a:candidate.source__in_reply_to_status_id
  if id == ""
    call unite#util#print_error("no reply")
    return
  endif
  execute unite#start([['twitter/show' , a:candidate.source__status_id]])
endfunction
"
" action - open browser
"
let s:source.action_table['*'].browser = {
      \ 'description' : 'open a tweet with browser',
      \ 'is_quit'     : 0,
      \ }

function! s:source.action_table['*'].browser.func(candidate)
  let url = 'https://twitter.com/' . 
              \ a:candidate.source__screen_name . '/status/' .
              \ a:candidate.source__status_id
  execute "OpenBrowser " . url
endfunction
"
" action - open links
"
let s:source.action_table['*'].link = {
      \ 'description' : 'open links with browser',
      \ 'is_quit'     : 0,
      \ }

function! s:source.action_table['*'].link.func(candidate)
  let text = a:candidate.word
  while 1
    let matched = matchlist(text, '\<https\?://\S\+')
    if len(matched) == 0
      break
    endif
    execute "OpenBrowser " . matched[0]
    let text = substitute(text , matched[0] , "" , "g")
  endwhile
endfunction

function! s:source.hooks.on_close(args, context)
  let no = bufnr(s:buf_name)
  try | execute "bd! " . no | catch | endtry
  call writefile(keys(s:screen_name_cache) , s:screen_name_cache_path)
endfunction

function! unite#sources#twitter#define()
  let sources = map([
        \ {'name': 'list'     },
        \ {'name': 'mentions' },
        \ {'name': 'user'     },
        \ {'name': 'show'     },
        \ {'name': 'friends'  },
        \ {'name': 'search'   },
        \ {'name': 'favorites'},
        \ ],
        \ 'extend(copy(s:source),
        \  extend(v:val, {"name": "twitter/" . v:val.name,
        \  "description": "candidates from twitter of " . v:val.name}))')
  call add(sources , s:source)
  return sources
endfunction

function! s:post()
  let text  = join(getline(1, "$"))
  if strchars(text) > 140
    unite#util#print_error("over 140 chars")
    return
  endif

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

