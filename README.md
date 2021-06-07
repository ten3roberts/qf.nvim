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

```lua
-- Setup and configure qf.nvim
require('qf').setup(options)

-- Automatically resize list to the number of items or max_height
require('qf').resize(list, num_items)

-- Hide quickfix and location lists from the buffers list
-- Hide linenumbers and relative line numbers
-- Open the `quickfix` or `location` list
-- If stay == true, the list will not be focused
require('qf').open(list, stay)

-- Close list
require('qf').close(list)

-- Toggle list
-- If stay == true, the list will not be focused
require('qf').toggle(list, stay)

-- Clears the quickfix or current location list
-- If name is not nil, the current list will be saved before being cleared
require('qf').clear(list, name)

-- Returns the list entry currently previous to the cursor
-- Returns the list entry currently after the cursor
-- Returns the list entry closest to the cursor vertically
-- strategy is one of the following:
-- - 'prev'
-- - 'next'
-- - 'nearest'
require('qf').follow(list, strategy)

-- Wrapping version of [lc]next
require('qf').next(list)

-- Wrapping version of [lc]prev
require('qf').prev(list)

-- Wrapping version of [lc]above
-- Will switch buffer
require('qf').above(list)

-- Wrapping version of [lc]below
-- Will switch buffer
require('qf').below(list)

-- Save quickfix or location list with name
require('qf').save(list, name)

-- Loads a saved list into the location or quickfix list
require('qf').load(list, name)
```

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
```

## Configuration

Configuration is done by passing a table to setup.

Quickfix list and locations lists are configured separetely with keys 'c' and 'l'

Default setup:

```lua
require 'qf'.setup {
  -- Location list configuration
  'l' = { 
    auto_close = true, -- Automatically close location/quickfix list if empty
    auto_follow = 'prev', -- Follow current entry, possible values: prev,next,nearest
    follow_slow = true, -- Only follow on CursorHold
    auto_open = true, -- Automatically open location list on QuickFixCmdPost
    auto_resize = true, -- Auto resize and shrink location list if less than `max_height`
    max_height = 8, -- Maximum height of location/quickfix list
  },
  -- Quickfix list configuration
  'c' = { 
    auto_close = true, -- Automatically close location/quickfix list if empty
    auto_follow = 'prev', -- Follow current entry, possible values: prev,next,nearest
    follow_slow = true, -- Only follow on CursorHold
    auto_open = true, -- Automatically open location list on QuickFixCmdPost
    auto_resize = true, -- Auto resize and shrink location list if less than `max_height`
    max_height = 8, -- Maximum height of location/quickfix list
  }
}
```
