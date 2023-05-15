# qf.nvim
Quickfix and location list management for Neovim.

## Features

- [X] Automatically open quickfix and location list
- [X] Automatically close list when empty
- [X] Close location list when parent window is destroyed
- [X] Automatically shrink lists to the number of items
- [X] Toggle list
- [X] Open and Toggle without losing focus
- [X] Follow cursor and select nearest entry
- [X] Navigate location list relative to cursor
- [X] Wrapping navigation
- [X] Save and load lists
- [X] Clear lists
- [X] Automatically close the location list when quickfix list opens, saving
  space
- [X] Open list at the very bottom of the screen rather than at the bottom of
  current split
- [X] Automatically open or close list on window leave and enter
- [X] Make list regroup to window on split
- [X] Close other location list when quickfix opens and vice verse
- [X] Pretty print list entries

qf.nvim offers many customization options to suit your workflow.

The plugin uses the default builtin quickfix list and location list and only
extends it, which means all builtin behaviour and plugins are compatible, such
as `:cclose`, `:cnext`, `:copen`, `:grep`, `:make`, `vim.diagnostic.set_qflist`,
etc. For `:make`, there exists an asynchronous name based build system called
( recipe.nvim )[https://github.com/ten3roberts/recipe.nvim], which integrates
directly with qf.nvim for added functionality such as error tallying.

## Installation
### [packer](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'ten3roberts/qf.nvim',
    config = function()
      require'qf'.setup{}
  end
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'ten3roberts/qf.nvim'

lua require'qf'.setup{}
```

## Usage

qf.nvim exposes a lua api.

Most functions require a first parameter list to specify which list to act on.
Either 'c','qf', or 'quickfix' for affecting the quickfix list, or
'l','loc','location' for affecting the location list.

If a value of 'visible' is given, it will use the currently visible list type,
or the quickfix window as a fallback.

See `(qf.nvim)[./doc/qf.txt` for more details.

## Example keymaps
```vim
nnoremap <leader>lo <cmd>lua require'qf'.open('l')<CR> " Open location list
nnoremap <leader>lc <cmd>lua require'qf'.close('l')<CR> " Close location list
nnoremap <leader>ll <cmd>lua require'qf'.toggle('l', true)<CR> " Toggle location list and stay in current window

nnoremap <leader>co <cmd>lua require'qf'.open('c')<CR> " Open quickfix list
nnoremap <leader>cc <cmd>lua require'qf'.close('c')<CR> " Close quickfix list
nnoremap <leader>cl <cmd>lua require'qf'.toggle('c', true)<CR> "Toggle quickfix list and stay in current window

nnoremap <leader>j <cmd>lua require'qf'.below('l')<CR> " Go to next location list entry from cursor
nnoremap <leader>k <cmd>lua require'qf'.above('l')<CR> " Go to previous location list entry from cursor

nnoremap <leader>J <cmd>lua require'qf'.below('c')<CR> " Go to next quickfix entry from cursor
nnoremap <leader>K <cmd>lua require'qf'.above('c')<CR> " Go to previous quickfix entry from cursor

nnoremap ]q <cmd>lua require'qf'.below('visible')<CR> " Go to next entry from cursor in visible list
nnoremap [q <cmd>lua require'qf'.above('visible')<CR> " Go to previous entry from cursor in visible list
```

## Configuration

Configuration is done by passing a table to setup.

Quickfix list and locations lists are configured separetely with keys 'c' and 'l'

Default setup:

```lua
require 'qf'.setup {
  -- Location list configuration
    l = {
        auto_close = true, -- Automatically close location/quickfix list if empty
        auto_follow = 'prev', -- Follow current entry, possible values: prev,next,nearest, or false to disable
        auto_follow_limit = 8, -- Do not follow if entry is further away than x lines
        follow_slow = true, -- Only follow on CursorHold
        auto_open = true, -- Automatically open list on QuickFixCmdPost
        auto_resize = true, -- Auto resize and shrink location list if less than `max_height`
        max_height = 8, -- Maximum height of location/quickfix list
        min_height = 5, -- Minimum height of location/quickfix list
        wide = false, -- Open list at the very bottom of the screen, stretching the whole width.
        number = false, -- Show line numbers in list
        relativenumber = false, -- Show relative line numbers in list
        unfocus_close = false, -- Close list when window loses focus
        focus_open = false, -- Auto open list on window focus if it contains items
    },
    -- Quickfix list configuration
    c = {
        auto_close = true, -- Automatically close location/quickfix list if empty
        auto_follow = 'prev', -- Follow current entry, possible values: prev,next,nearest, or false to disable
        auto_follow_limit = 8, -- Do not follow if entry is further away than x lines
        follow_slow = true, -- Only follow on CursorHold
        auto_open = true, -- Automatically open list on QuickFixCmdPost
        auto_resize = true, -- Auto resize and shrink location list if less than `max_height`
        max_height = 8, -- Maximum height of location/quickfix list
        min_height = 5, -- Minimum height of location/quickfix list
        wide = false, -- Open list at the very bottom of the screen, stretching the whole width.
        number = false, -- Show line numbers in list
        relativenumber = false, -- Show relative line numbers in list
        unfocus_close = false, -- Close list when window loses focus
        focus_open = false, -- Auto open list on window focus if it contains items
      }
      close_other = false, -- Close location list when quickfix list opens
      pretty = true, -- Pretty print quickfix lists
      silent = false, -- Suppress messages like "(1 of 3): *line content*" on jump
}
```

## Inspiration
- [vim-qf](https://github.com/romainl/vim-qf)
- [vim-loclist-follow](https://github.com/elbeardmorez/vim-loclist-follow)
