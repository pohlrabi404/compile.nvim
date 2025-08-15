# compile.nvim

Meet **compile.nvim**, the Neovim plugin that brings integrated compilation right into your workflow!
It’s inspired by the famous Emacs Compilation Mode, but utilizing Neovim terminal buffer.

Instead of just piping output to a new buffer (which can be tricky to interact with), this plugin uses Neovim's built-in terminal buffers. 
This means you get a powerful, interactive terminal for your build processes while also enjoying real-time error highlighting and seamless navigation. 
No more juggling windows or trying to figure out where your compiler's output went!

## ✨ Features


[Demo](https://github.com/user-attachments/assets/370993be-c461-4f8c-9714-7c59d8836784)


  - **Effortless Error Navigation**: Zip between compiler errors with simple keybinds.
  - **Instant Error Jumps**: Place your cursor on or after an error, and it will jump directly to the spot in your code!
  - **Fresh Start, Every Time**: The error list is automatically cleared for each new compilation, so you always see the latest issues.
  - **Smart Terminal**: By default, `  <C-j> ` in the terminal will send a `<CR>` without clearing your error list.
  - **Ready to Go**: The default compile command is `"make -k"`, so you can start compiling out of the box.

## 🚀 Installation

Using **lazy.nvim** is recommended.

### Minimal Installation

Just drop this into your `lazy.nvim` configuration!

```lua
return {
  'pohlrabi404/compile.nvim',
  -- This event makes sure the plugin loads lazily. You can
  -- use any event you like, such as `ft` for file types or `autocmds`.
  event = "VeryLazy",
  -- don't forget the options table!
  opts = {},
}
```

## ⚙️ Configuration

Here's a default settings. You don't have to put all of them in the opts table and can just change which one you want!

```lua
opts = {
  -- Give your terminal a custom name.
  term_win_name = "CompileTerm",
  ---@type vim.api.keyset.win_config
  term_win_opts = {
    -- The split direction for the terminal window. "below" places it at the bottom.
    split = "below",
    -- The height of the terminal window as a percentage (0.4 = 40%).
    -- Any number >= 1 will use that amount of lines as height
    height = 0.4,
    -- width = 0.8, -- the same applied for width
    -- Or you can make it float, adding borders, etc. check :h win_config
  },

  ---@type vim.api.keyset.win_config
  normal_win_opts = {
    -- The split direction for the normal window. "above" places it at the top.
    split = "above",
    -- similar to term_win_opts
    height = 0.6,
  },

  ---@type boolean
  -- Set this to `true` if you want to jump into the terminal when you run compile command
  enter = false,

  highlight_under_cursor = {
    -- Enable or disable highlighting the error under your cursor. It’s a great visual cue!
    enabled = true,
    -- The timeout in milliseconds for the highlight to appear in the terminal.
    timeout_term = 500,
    -- The timeout in milliseconds for the highlight in a normal buffer.
    timeout_normal = 200,
  },

  cmds = {
    -- The default command to run when you compile. Change this if you use a different build tool!
    -- I will make it possible to have dynamic default for each project types soon~
    default = "make -k",
  },

  patterns = {
    -- A table of patterns to match compiler output. This is how the plugin finds
    -- files, lines, and columns for errors. The "123" and "12" refer to the
    -- capture groups in the regex.
    -- 1 stands for filename
    -- 2 stands for row number
    -- 3 stands for col number (can be omitted if the language doesn't support)
    -- For example: col:filename:row will be "312" instead
    rust = { "(%S+):(%d+):(%d+)", "123" },
    Makefile = { "%[(%S+):(%d+):.+%]", "12" },
    -- I will also add more regex for different error types soon
  },

  colors = {
    -- Customize the highlight colors for different parts of the error message.
    -- These correspond to Neovim highlight groups.
    file = "WarningMsg",
    row = "CursorLineNr",
    col = "CursorLineNr",
  },

  keys = {
    -- Here's where you define all the handy keybindings!
    global = {
      -- Normal mode keybindings, you can group modes by writing them next to each other
      -- eg: ["nvi"] for normal, select and insert mode keybinding
      ["n"] = {
        -- start compile/recompile, will also open the terminal
        ["<localleader>cc"] = "require('compile').compile()",
        ["<localleader>cn"] = "require('compile').next_error()",
        ["<localleader>cp"] = "require('compile').prev_error()",
        ["<localleader>cl"] = "require('compile').last_error()",
        ["<localleader>cf"] = "require('compile').first_error()",
      },
    },
    term = {
      -- Keybindings specific to the terminal buffer.
      -- Global keybinding for terminal will work everywhere but will be removed
      -- when you close the terminal buffer
      global = {
        ["n"] = {
          -- clears the terminal
          ["<localleader>cr"] = "require('compile').clear()",
          -- quits the terminal buffer.
          ["<localleader>cq"] = "require('compile').destroy()",
        },
      },
      -- This one will only work INSIDE the terminal buffer
      buffer = {
        ["n"] = {
          ["r"] = "require('compile').clear()",
          ["c"] = "require('compile').compile()",
          -- quit the terminal.
          ["q"] = "require('compile').destroy()",
          ["n"] = "require('compile').next_error()",
          ["p"] = "require('compile').prev_error()",
          ["0"] = "require('compile').first_error()",
          ["$"] = "require('compile').last_error()",
          -- Jump to the nearest error under or before your cursor
          ["<Cr>"] = "require('compile').nearest_error()",
        },
        -- Tricks to clear warning/error list
        ["t"] = {
          -- Press `<CR>` in terminal mode to send a command and clear highlights.
          ["<CR>"] = "require('compile').clear_hl()",
          -- This sends the command to the terminal without clearing the error list!
          ["<C-j>"] = "require('compile.term').send_cmd('')",
        },
      },
    },
  },
}
```
## 📜 Documentation (TODO)
Sorry a bit lazy, pinky promise that I won't forget about it

## 🛠️ PRs
PRs and Issues are always welcome~
