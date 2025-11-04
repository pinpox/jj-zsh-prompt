# jj-zsh-prompt

An async [Jujutsu](https://github.com/martinvonz/jj) and Git prompt for Zsh, inspired by [Pure](https://github.com/sindresorhus/pure).


<img width="2312" height="150" alt="image" src="https://github.com/user-attachments/assets/d7623a34-e92a-423e-b587-0da67d199348" />


## Features

- **Async Jujutsu support**: Shows change ID, commit ID, description, bookmarks, and file stats
- **Git fallback**: Displays branch, dirty status, and push/pull indicators when not in a jj repo
- **Non-blocking**: Uses `zsh-async` to keep your prompt fast
- **Customizable**: Colors and prompt character can be configured
- **Status indicators**:
  - Background jobs counter
  - Exit code coloring (green = success, red = error)
  - Git ahead/behind arrows (⇡⇣)

### Jujutsu Prompt Format

When in a jujutsu repository:
```
~/project lsuk 0efd home-manager/jj: create custom prompt main ⇡1 ±7 +296 -3
➜
```

- **Change ID** (`lsuk`): Unique prefix in bold magenta, rest in grey
- **Commit ID** (`0efd`): Unique prefix in bold cyan, rest in grey
- **Description** (`home-manager/jj: create custom prompt`): Italic
- **Bookmark** (`main`): Bold magenta
- **Ahead count** (`⇡1`): Blue
- **File stats** (`±7 +296 -3`): Changed (yellow), added (green), removed (red)

### Git Prompt Format

When in a git repository (but not jj):
```
~/project main*⇡⇣
➜
```

- **Branch** (`main`): Grey
- **Dirty marker** (`*`): Grey (appears when there are uncommitted changes)
- **Arrows** (`⇡⇣`): Cyan (ahead/behind remote)

## Requirements

- Zsh 5.0+
- [zsh-async](https://github.com/mafredri/zsh-async)
- [Jujutsu](https://github.com/martinvonz/jj) (optional, will fall back to git)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/pinpox/jj-zsh-prompt.git ~/.zsh/jj-zsh-prompt
   ```

2. Install [zsh-async](https://github.com/mafredri/zsh-async):
   ```bash
   git clone https://github.com/mafredri/zsh-async.git ~/.zsh/zsh-async
   ```

3. Add to your `~/.zshrc`:
   ```bash
   # Load zsh-async
   source ~/.zsh/zsh-async/async.zsh

   # Load jj-zsh-prompt
   source ~/.zsh/jj-zsh-prompt/jj-zsh-prompt.plugin.zsh
   ```

Or use your favorite zsh plugin manager

### Nix / NixOS / Home Manager

#### Flake Input

Add to your `flake.nix`:
```nix
{
  inputs = {
    jj-zsh-prompt.url = "github:pinpox/jj-zsh-prompt";
    jj-zsh-prompt.flake = false;
  };
}
```

#### Home Manager Configuration

```nix
{ pkgs, inputs, ... }:
{
  programs.zsh = {
    plugins = [
      {
        name = "zsh-async";
        src = pkgs.zsh-async;
        file = "share/zsh-async/async.zsh";
      }
      {
        name = "jj-zsh-prompt";
        src = inputs.jj-zsh-prompt;
        file = "jj-zsh-prompt.plugin.zsh";
      }
    ];
  };
}
```

## Configuration

### Customizing Colors

Set these variables before loading the plugin:

```bash
# Jujutsu colors
export JJ_COLOR_CHANGE_ID="%F{magenta}"      # Change ID unique prefix
export JJ_COLOR_CHANGE_REST="%F{240}"        # Change ID rest (grey)
export JJ_COLOR_COMMIT_ID="%F{cyan}"         # Commit ID unique prefix
export JJ_COLOR_COMMIT_REST="%F{240}"        # Commit ID rest (grey)
export JJ_COLOR_STATUS="%F{red}"             # Status indicators
export JJ_COLOR_BOOKMARK="%F{magenta}"       # Bookmark name
export JJ_COLOR_STATS="%F{blue}"             # File stats

# Git colors
export JJ_COLOR_GIT_BRANCH="%F{240}"         # Branch name (grey)
export JJ_COLOR_GIT_ARROWS="%F{cyan}"        # Ahead/behind arrows

# Prompt character
export JJ_PROMPT_CHAR="❯"                    # Default is ➜

# Debugging
export JJ_DEBUG=1                            # Adds debug output
```

## Thanks to

- **[Pure](https://github.com/sindresorhus/pure)**: Inspiration for this prompt; focused on git
- **[Powerlevel10k](https://github.com/romkatv/powerlevel10k)**: More features but heavier; no native jj support
- **[Starship](https://starship.rs/)**: Rust-based, fast, but different approach
- **[zsh-async](https://github.com/mafredri/zsh-async)**: by Mathias Fredriksson
