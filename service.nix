{ config, lib, ... }:
let
  packages = config.flake.packages.x86_64-linux;

  # TODO: dry
  toArgs = args @ { commands ? [ ], ... }:
    lib.escapeShellArgs
      (lib.cli.toGNUCommandLine
        { mkOptionName = k: "-${k}"; }
        (builtins.removeAttrs args [ "commands" ])
      ++ (map (c: "+${c}") commands));
in
{
  flake.nixosModules = {
    tf2ds = { config, lib, pkgs, ... }:
      let
        inherit (lib)
          mkOption
          types
          ;

        cfg = config.services.tf2ds;

        mkService = name: opts:
          let
            args = {
              game = "tf";
              ip = "0.0.0.0";
              scriptportbind = true;
              inherit (opts) port;
            }
            // opts.args
            // {
              commands = [
                "tv_port ${toString opts.stvPort}"
                "clientport ${toString (50000 + opts.port)}"
              ]
              ++ opts.args.commands;
            };
          in
          {
            "tf2ds-${name}" = {
              description = "Team Fortress 2 Dedicated Server - ${name}";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              inherit (opts) restartIfChanged;

              preStart = ''
                mkdir -p {tf/addons,.steam/sdk32}
                ${pkgs.findutils}/bin/find . -type l -delete

                ln -fns ${packages.gameinfo} tf/gameinfo.txt
                ln -fns ${packages.tf2ds}/bin/steamclient.so .steam/sdk32/

                ${lib.getExe pkgs.xorg.lndir} -silent ${packages.all-plugins} ./
              '';

              script = ''
                HOME=$STATE_DIRECTORY \
                LD_LIBRARY_PATH=${packages.tf2ds}/bin:${pkgs.pkgsi686Linux.ncurses5}/lib \
                exec -a "$STATE_DIRECTORY"/srcds_linux \
                  ${packages.tf2ds}/srcds_linux \
                    ${toArgs args}
              '';

              serviceConfig = {
                Restart = "always";

                DynamicUser = "true";
                StateDirectory = "tf2ds/${name}";
                WorkingDirectory = "%S/tf2ds/${name}";
              };
            };
          };
      in
      {
        options.services.tf2ds = {
          instances = mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                port = mkOption { type = types.port; };
                stvPort = mkOption { type = types.port; };

                restartIfChanged = mkOption {
                  type = types.bool;
                  default = false;
                };

                args = mkOption {
                  type = types.raw;
                  default = {
                    commands = [
                      "sv_pure 1"
                      "map itemtest"
                    ];
                  };
                };
              };
            });

            default = { };
          };
        };

        config.systemd.services = lib.mkMerge (
          lib.mapAttrsToList mkService cfg.instances
        );

        config.networking.firewall = lib.mkMerge (
          lib.mapAttrsToList
            (_: opts: {
              allowedTCPPorts = [ opts.port ];
              allowedUDPPorts = [ opts.port opts.stvPort ];
            })
            cfg.instances
        );
      };
  };
}
