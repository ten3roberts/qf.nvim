if exists('b:current_syntax')
  finish
end

let b:current_syntax = 'qf'

lua require"qf".setup_syntax()
