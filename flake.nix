{
  description = "MedSimAI Patient Builder – Elixir/Phoenix/LiveView with ex_webrtc";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Erlang/OTP 26 + Elixir 1.16 (well-tested combo for Phoenix 1.7)
        erlang = pkgs.beam.packages.erlang_26;
        elixir = erlang.elixir_1_16;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            elixir
            erlang.erlang

            # Build tooling
            pkgs.git
            pkgs.gnumake
            pkgs.gcc

            # For esbuild (asset bundling)
            pkgs.nodejs_20

            # Native deps for ex_webrtc / DTLS / SRTP
            pkgs.openssl
            pkgs.libsrtp

            # For full audio codec conversion (Opus <-> PCM via xav)
            pkgs.ffmpeg
            pkgs.libopus
            pkgs.pkg-config

            # inotify for Phoenix live reload on Linux
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.inotify-tools
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.darwin.apple_sdk.frameworks.CoreFoundation
            pkgs.darwin.apple_sdk.frameworks.CoreServices
          ];

          shellHook = ''
            # Keep Mix/Hex state inside the project so different projects
            # don't collide and the store stays read-only.
            export MIX_HOME="$PWD/.nix-mix"
            export HEX_HOME="$PWD/.nix-hex"
            export ERL_AFLAGS="-kernel shell_history enabled"
            export PATH="$MIX_HOME/bin:$MIX_HOME/escripts:$HEX_HOME/bin:$PATH"

            # Ensure Hex and rebar are available
            mix local.hex --if-missing --force > /dev/null 2>&1
            mix local.rebar --if-missing --force > /dev/null 2>&1

            # pkg-config paths for native compilation
            export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.libopus}/lib/pkgconfig:''${PKG_CONFIG_PATH:-}"
          '';
        };
      }
    );
}
