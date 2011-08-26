let s:save_cpo = &cpo
set cpo&vim

let s:preview_buf_name = 'unite_twitter_preview'

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
    let bufnr = bufwinnr(s:preview_buf_name)
    if bufnr > 0
      exec bufnr.'wincmd w'
    else
      execute 'below split ' . s:preview_buf_name
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

function! s:source.hooks.on_close(args, context)
  let no = bufnr(s:preview_buf_name)
  try | execute "bd! " . no | catch | endtry
endfunction

function! s:source.gather_candidates(args, context)
  let method = substitute(self.name , "twitter/" , "" , "")
  if method == 'twitter'
    let method = 'home_timeline'
  endif
  " I want to change from a:args to a:000
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
