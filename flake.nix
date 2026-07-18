{
  description = "padctl — HID gamepad remapper";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    zig2nix.url = "github:Cloudef/zig2nix";
    zig2nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, zig2nix }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      env = system: zig2nix.outputs.zig-env.${system} {
        zig = zig2nix.outputs.packages.${system}.zig-0_15_2;
      };
    in
    {
      packages = forAllSystems (system:
        let
          e = env system;
          zigTarget = builtins.replaceStrings [ "-linux" ] [ "-linux-musl" ] system;
        in
        {
          default = e.package {
            src = ./.;
            inherit zigTarget;
            zigBuildFlags = [ "-Doptimize=ReleaseSafe" ];
            postInstall = ''
              install -Dm644 completions/padctl.bash \
                $out/share/bash-completion/completions/padctl.bash
              install -Dm644 completions/_padctl \
                $out/share/zsh/site-functions/_padctl
            '';
            meta = {
              description = "HID gamepad remapper — declarative TOML config, uinput output";
              homepage = "https://github.com/BANANASJIM/padctl";
              license = nixpkgs.lib.licenses.lgpl21Plus;
              maintainers = [ ];
              platforms = [ "x86_64-linux" "aarch64-linux" ];
            };
          };
        }
      );

      devShells = forAllSystems (system:
        let
          e = env system;
        in
        {
          default = e.mkShell {
            packages = [ ];
          };
        }
      );
    };
}
