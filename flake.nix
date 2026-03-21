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
        zig = zig2nix.outputs.packages.${system}.zig."0.15.0".bin;
      };
    in
    {
      packages = forAllSystems (system:
        let
          e = env system;
        in
        {
          default = e.packageForTarget "x86_64-linux-musl" {
            src = ./.;
            zigBuildFlags = [ "-Doptimize=ReleaseSafe" ];
            meta = {
              description = "HID gamepad remapper — declarative TOML config, uinput output";
              homepage = "https://github.com/example/padctl";
              license = nixpkgs.lib.licenses.mit;
              maintainers = [ ];
              platforms = [ "x86_64-linux" "aarch64-linux" ];
            };
          };
        }
      );

      devShells = forAllSystems (system:
        let
          e = env system;
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = e.mkShell {
            packages = [ pkgs.namcap ];
          };
        }
      );
    };
}
