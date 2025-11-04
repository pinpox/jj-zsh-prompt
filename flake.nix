{
  description = "An async Jujutsu (jj) and Git prompt for Zsh";

  outputs = { self }: {
    # This is primarily meant to be used as a flake input with flake = false
    # Users should add it to their flake inputs like:
    #   jj-zsh-prompt.url = "github:pinpox/jj-zsh-prompt";
    #   jj-zsh-prompt.flake = false;

    # The main plugin file is at: jj-zsh-prompt.plugin.zsh
  };
}
