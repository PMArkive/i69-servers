{ config, lib, self, inputs, ... }:
let
  modules = config.flake.nixosModules;
in
{
  flake.nixosModules = {
    common = { config, ... }: {
      # from modules/profiles/headless.nix
      boot.loader.grub.splashImage = null;

      documentation = {
        enable = lib.mkForce false;
        dev.enable = lib.mkForce false;
        doc.enable = lib.mkForce false;
        man.enable = lib.mkForce false;
        nixos.enable = lib.mkForce false;
      };

      i18n.supportedLocales = lib.mkForce [ "en_US.UTF-8/UTF-8" ];

      networking.firewall = {
        allowedTCPPorts = config.services.openssh.ports;
      };

      programs.command-not-found.enable = false;

      services.openssh = {
        enable = true;
        passwordAuthentication = false;
        ports = [ 50022 ];
      };

      system.stateVersion = "22.11";

      time.timeZone = "Europe/London";

      users.users.root = {
        initialPassword = "toor";

        openssh.authorizedKeys.keyFiles = [
          "${self}/ssh/ldesgoui.pub"
          "${self}/ssh/proto.pub"
        ];
      };
    };

    game-server = { config, modulesPath, ... }: {
      imports = [
        "${modulesPath}/virtualisation/proxmox-image.nix"
      ];

      networking = {
        useDHCP = false;
        # cloud-init provides configuration using the "default" interface names
        usePredictableInterfaceNames = false;
      };

      # Use cloud-init to set up network interfaces on boot
      services.cloud-init = {
        enable = true;
        network.enable = true;
      };
    };

    ovh-vps = { modulesPath, ... }: {
      imports = [
        "${modulesPath}/profiles/qemu-guest.nix"
      ];

      boot.loader.grub.device = "/dev/sda";

      boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" ];
      boot.kernelModules = [ "kvm-intel" "nvme" ];

      fileSystems."/" = {
        fsType = "ext4";
        device = "/dev/sda1";
      };

      # networking = {
      #   nat = {
      #     enable = true;
      #     externalInterface = "enp0s3";
      #     internalInterfaces = [ "wg6" ];
      #   };
      # };
    };

    mumble = { config, ... }: {
      networking.firewall = {
        allowedTCPPorts = [ config.services.murmur.port ];
        allowedUDPPorts = [ config.services.murmur.port ];
      };

      services.murmur = {
        enable = true;
        bandwidth = 320000;
        users = 420;
        registerName = "mumble.i69.lan.tf";
      };
    };
  };

  flake.colmena = {
    meta.nixpkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;

    defaults = { name, ... }: {
      imports = [
        modules.common
      ]
      ++ lib.optional (lib.hasPrefix "game-" name)
        modules.game-server;

      networking.hostName = name;
    };

    game-1 = {
      deployment.targetHost = "";

      imports = [
        modules.mumble
      ];
    };

    game-2 = { deployment.targetHost = ""; };
    game-3 = { deployment.targetHost = ""; };
    game-4 = { deployment.targetHost = ""; };
    game-5 = { deployment.targetHost = ""; };
    game-6 = { deployment.targetHost = ""; };

    spec-1 = {
      deployment.targetHost = "54.36.190.233";

      imports = [
        modules.ovh-vps
      ];
    };
  };
}
