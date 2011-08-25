let s:save_cpo = &cpo
set cpo&vim

let s:unite_source = {'name': 'twitter'}

function! s:unite_source.gather_candidates(args, context)
  let result = rubytter#request('list_statuses' , 'basyura' , 'all')
  return map(result , 
        \ '{
        \ "word": v:val.user.screen_name . " : " . v:val.text,
        \ "source": "twitter",
        \ }')
endfunction

function! unite#sources#twitter#define()
  return s:unite_source
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
