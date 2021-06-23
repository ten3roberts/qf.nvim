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

Qf.nvim offers many customization options to suit your workflow.

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

-- Same as resize, but does nothing if auto_resize is off
require('qf').checked_auto_resize(list, stay)

-- Automatically resize list to the number of items between max and min height
-- If stay, the list will not be focused.
-- num_items can be provided if number of items are already none, if nil, they will be queried
require('qf').resize(list, stay, num_items)

-- Hide quickfix and location lists from the buffers list
-- Hide linenumbers and relative line numbers
-- Open the `quickfix` or `location` list
-- If stay == true, the list will not be focused
-- If auto_close is true, the list will be closed if empty, similar to cwindow
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
-- (optional) limit, don't select entry further away than limit. Use true to use config value
-- If entry is further away than limit, the entry will not be selected. This is to prevent recentering of cursor caused by setpos. There is no way to select an entry without jumping, so the cursor position is saved and restored instead.
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
    l = {
        auto_close = true, -- Automatically close location/quickfix list if empty
        auto_follow = 'prev', -- Follow current entry, possible values: prev,next,nearest, or false to disable
        auto_follow_limit = 8, -- Do not follow if entry is further away than x lines
        follow_slow = true, -- Only follow on CursorHold
        auto_open = true, -- Automatically open list on QuickFixCmdPost
        auto_resize = true, -- Auto resize and shrink location list if less than `max_height`
        max_height = 8, -- Maximum height of location/quickfix list
        min_height = 5, -- Minumum height of location/quickfix list
        wide = false, -- Open list at the very bottom of the screen, stretching the whole width.
        number = false, -- Show line numbers in list
        relativenumber = false, -- Show relative line numbers in list
        unfocus_close = false, -- Close list when window loses focus
        focus_open = false, -- Auto open list on window focus if it contains items
        close_other = false, -- Close quickfix list when location list opens
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
        min_height = 5, -- Minumum height of location/quickfix list
        wide = false, -- Open list at the very bottom of the screen, stretching the whole width.
        number = false, -- Show line numbers in list
        relativenumber = false, -- Show relative line numbers in list
        unfocus_close = false, -- Close list when window loses focus
        focus_open = false, -- Auto open list on window focus if it contains items
        close_other = false, -- Close location list when quickfix list opens
      }
}
```

## Inspiration
- [vim-qf](https://github.com/romainl/vim-qf)
- [vim-loclist-follow](https://github.com/elbeardmorez/vim-loclist-follow)
