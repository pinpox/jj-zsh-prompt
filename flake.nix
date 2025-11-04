{
  description = "An async Jujutsu (jj) and Git prompt for Zsh";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation rec {
            pname = "jj-zsh-prompt";
            version = "latest";

            src = self;

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              plugindir="$out/share/jj-zsh-prompt"
              mkdir -p "$plugindir"
              cp -r * "$plugindir"/
            '';

            meta = with pkgs.lib; {
              description = "ZSH prompt plugin for Jujutsu (jj) version control";
              homepage = "https://github.com/pinpox/jj-zsh-prompt";
              license = licenses.mit;
              platforms = platforms.unix;
            };
          };
        }
      );
    };
}
