# Wingman: Your AI-Powered Coding Companion for Neovim 🚀

Welcome to **Wingman**, the ultimate plugin that supercharges your Neovim experience by integrating a powerful LLM (Large Language Model) directly into your coding workflow! Imagine having an intelligent assistant that understands your project context and helps you write better code, all while you focus on what you do best—creating amazing software!

## Why Wingman?

In today's fast-paced development environment, efficiency is key. Wingman takes your coding to the next level by automatically injecting relevant project context into requests sent to the LLM. This means you get smarter, more contextual responses tailored to your specific needs, making your coding sessions more productive and enjoyable.

### Key Features

- **Context-Aware Requests**: Wingman automatically gathers and includes project context in your requests, ensuring that the LLM understands exactly what you're working on.
- **Seamless Integration**: Designed specifically for Neovim, Wingman fits effortlessly into your existing workflow, enhancing your coding experience without any hassle.
- **User-Friendly Interface**: With a clean and intuitive interface, interacting with the LLM is as easy as pressing a few keys. You'll be amazed at how quickly you can get the help you need!
- **Code Replacement (WIP)**: Wingman aims to automatically replace affected lines of code based on the LLM's suggestions, allowing you to implement improvements with just a few keystrokes.
- **Extend models / providers support (WIP)**: Currently, Wingman only supports OpenAI's models but new models and providers will be added very soon. Feel free to contribute.

## Getting Started

To get started with Wingman, simply install the plugin using your favorite package manager. Once installed, you can begin leveraging the power of LLMs in your coding routine.

To get started with Wingman, simply install the plugin using your favorite package manager. Once installed, you can begin leveraging the power of LLMs in your coding routine.

### Installation with LazyVim

1. Add the following to your `lazyvim` configuration:

```lua
return {
 "webpolis/wingman.nvim",
 dependencies = {'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim', 'junegunn/fzf.vim', 'kkharji/sqlite.lua', 'leafo/lua-openai'},
 opts = {
  openai_api_key = 'your_openai_api_key',
  openai_model = 'gpt-4o-mini'
 }
}
```

### Installation with Packer

1. Add the following to your `packer` configuration:

```lua
return require('packer').startup(function(use)
  -- Dependencies
  use 'nvim-lua/plenary.nvim'
  use 'MunifTanjim/nui.nvim'
  use 'junegunn/fzf.vim'
  use 'kkharji/sqlite.lua'
  use 'leafo/lua-openai'

  use {
    'webpolis/wingman.nvim',
    config = function()
      require('wingman').setup {
        openai_api_key = 'your_openai_api_key',
        openai_model = 'gpt-4o-mini'
      }
    end
  }
end)
```

### Issues with Luarocks / lua-openai

To stream the model's response, certain Lua packages are necessary. If the installation of _leafo/lua-openai_ fails, install it separately using Luarocks and then restart the editor:

```sh
luarocks install lua-openai
```

### Configuration Options

| Option           | Description                                |
| ---------------- | ------------------------------------------ |
| `openai_api_key` | Your OpenAI API key for authentication.    |
| `openai_model`   | The model to use for generating responses. |

### Usage

1. Open a file in Neovim.
2. Run the `Wingman` command.
3. Ask questions or request code suggestions, and watch as Wingman enhances your coding experience!

When the initial prompt dialog opens, Wingman automatically gathers all symbols present in the current buffer. As you type, suggestions will appear as markdown links (e.g. _\[MySymbol\]\(src/symbols.ts\)_). Once a suggestion is selected, it will be included in the current prompt's context.

To ensure symbols are extracted, your editor's LSP must be correctly configured. Use `LspInfo` to verify that the current language is supported by an LSP server. Otherwise, the entire contents of the buffer will be included.

| Option           | Description                                                 |
| ---------------- | ----------------------------------------------------------- |
| `Wingman`        | Opens the prompt dialog                                     |
| `WingmanCollect` | Appends the current buffer's content to the Wingman context |
| `WingmanClear`   | Resets the cache and database                               |

### Contribute

As Wingman is still a work in progress, your feedback and contributions are invaluable! Join our community, report issues, and help us shape the future of this plugin.

```

```
