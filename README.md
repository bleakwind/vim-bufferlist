# vim-bufferlist

## A lightweight plugin that displays all buffers as tabs for vim...
vim-bufferlist is a minimalist yet powerful buffer navigation plugin for Vim that provides an intuitive way to manage and switch between open buffers. It displays your buffers in a customizable bar (either horizontal or vertical) with visual indicators for modified files and the current active buffer.

## Features
- **Lightweight**: Pure Vimscript implementation with no external dependencies
- **Customizable**: Customizable colors for different buffer states
- **Intuitive Navigation**: Keyboard shortcuts for easy buffer switching
- **Mouse Navigation**: Mouse support for clicking on buffers
- **Session Restoration**: Saves and restores open files between sessions

## Screenshot
![Bufferlist Screenshot](https://github.com/bleakwind/vim-bufferlist/blob/main/vim-bufferlist.png)

## Requirements
Recommended Vim 8.1+

## Installation
```vim
" Using Vundle
Plugin 'bleakwind/vim-bufferlist'
```

And Run:
```vim
:PluginInstall
```

## Configuration
Add these to your `.vimrc`:
```vim
" Set 1 enable bufferlist (default: 0)
let g:bufferlist_enabled = 1
" Set 1 autostart bufferlist (default: 0)
let g:bufferlist_autostart = 1
" Position of bufferlist: 'top', 'bottom', 'left', 'right' (default: 'top')
let g:bufferlist_position = 'top'
" Window width for vertical position (default: 20)
let g:bufferlist_winwidth = 20
" Window height for horizontal position (default: 1)
let g:bufferlist_winheight = 1
" Enable bufferlist restoration (default: 0)
let g:bufferlist_reopen = 1
" Path for storing bufferlist data (default: $HOME/.vim/bufferlist)
let g:bufferlist_filepath = g:config_dir_data.'bufferlist'
```

Color Customization
```vim
" Tab color format - [dark cterm, dark gui, light cterm, light gui]
" Normal buffers
let g:bufferlist_hldefnor = '#FFFFFF'
" Modified buffers
let g:bufferlist_hldefmod = '#F56C6C'
" Current normal buffer
let g:bufferlist_hlcurnor = '#67C23A'
" Current modified buffer
let g:bufferlist_hlcurmod = '#E0575B'
" Visible normal buffer
let g:bufferlist_hlvisnor = '#67C23A'
" Visible modified buffer
let g:bufferlist_hlvismod = '#E0575B'
" Separator
let g:bufferlist_hlsepnor = '#AAAAAA'
```

## Usage
| Command               | Description              |
| --------------------- | ------------------------ |
| `:BufferlistToggle`   | Toggle the bufferlist    |
| `:BufferlistOpen`     | Open the bufferlist      |
| `:BufferlistClose`    | Close the bufferlist     |
| `:BufferlistTabnew`   | Create a new buffer      |
| `:BufferlistTabClose` | Close the current buffer |

## Key Mappings

### When the bufferlist is focused:
| Key            | Action                |
| -------------- | --------------------- |
| l,[right]      | Next buffer           |
| h,[left]       | Previous buffer       |
| Tab            | Next buffer           |
| Shift-Tab      | Previous buffer       |
| Enter          | Select current buffer |

### Global key mappings:
| Key            | Action
| -------------- | ----------------------|
| Ctrl-[right]   | Next buffer           |
| Ctrl-[left]    | Previous buffer       |
| Ctrl-Tab       | Next buffer           |
| Ctrl-Shift-Tab | Previous buffer       |
| Mouse Click    | Select clicked buffer |

## License
BSD 2-Clause - See LICENSE file
