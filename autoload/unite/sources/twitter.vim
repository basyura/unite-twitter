let s:save_cpo = &cpo
set cpo&vim

let s:source = {'name': 'twitter'}

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
        \ {'name': 'mentions'},
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
