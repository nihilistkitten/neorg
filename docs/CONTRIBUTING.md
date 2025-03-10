# Contributions welcome!
Whilst any help is very special, please be considerate of certain rules in order to make the codebase uniform/coherent.

---
### Table of Contents

- When you need help:
  - [What to do when you encounter a bug](#reporting-a-bug-or-issue)

- When contributing:
  - [Formatting rules](#formatting-rules)
  - [Coding style](#coding-style)
  - [Adding extra functionality](#adding-functionality)
---

### Reporting a bug or issue
Whenever something happens the way it's not supposed to, [file an issue!](https://github.com/nvim-neorg/neorg/issues/new/choose), but before you do, try the following:
- If you haven't already, always try updating the plugin first. Issues may be fixed before you can even file one, so always make sure you are up to date beforehand.
- Make sure you are running the latest neovim version. Whenever I test neorg, I test it on the latest compiled neovim from source which I recompile everyday. While you don't have to be *that* extreme with your updates, make sure you're at least running the latest neovim nightly.

If you're certain it's a fault of the plugin, not your configuration, in the issue please provide the following:
- The neovim version you're running (`nvim --version`)
- The neorg log file (you'll find it at `stdpath('data') .. '/neorg.log'`). This file will contain the necessary info for me to effectively debug.
  You can run `:echo stdpath('data')` if you're unsure where that path resides.
- The branch of Neorg you are using (unstable/main/some other experimental branch)
- The list of modules you have loaded (you can run `:Neorg module list` to see a comprehensive list)
- Other plugins you are using which you think could potentially be conflicting with neorg.
- Steps to reproduce the bug, if any - sometimes bugs get triggered only on certain configurations, which can be a pain. If you're aware that the bug requires a specific config, be sure to include that information as well!

---

### Formatting rules
Formatting is done in the project via `stylua`. You should install it with lua 5.2 support, as that
version allows for the formatting of `goto` blocks. You can install it via cargo: `cargo install stylua --features lua52`.
You can then run `make format` in the project root to automatically format all your lua code. Good stuff.

### Coding style
- I use snake_case for everything, and you should too :P
- **Please** comment all your code! Documentation for functions is generated by [neogen](https://github.com/danymat/neogen).

<!--### Modules
- When creating a module, add a comment up top as seen [here](/lua/neorg/modules/core/autocommands/module.lua) and [here](/lua/neorg/modules/core/keybinds/module.lua)
- Add a general description of what the module does at the top and provide a `USAGE:` block describing how to use the module
- Try to only access neorg data through functions, not through tables (e.g. don't access parts of `neorg.modules.loaded_modules` you're not supposed to - if anything only access the public fields exposed by other modules). Use the API as much as possible.
TODO: Make this reference our new "top comment" style.
-->

## Adding functionality
Whenever you are planning on extending neorg, try your best to add *all* extra functionality through modules and modules only. Make changes to the Neorg core only if absolutely necessary.
When adding stuff, use lua only. `vim.cmd` in extreme cases :)
