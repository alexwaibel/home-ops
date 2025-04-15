# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ modulesPath, lib, pkgs, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  boot.initrd = {
    availableKernelModules = [ "virtio-pci" ];
    network = {
      enable = true;
      ssh = {
        enable = true;
        port = 2222;
        hostKeys = [ /etc/secrets/initrd/ssh_host_ed25519_key ];
        authorizedKeys = lib.splitString "\n" (builtins.readFile ../../id_rsa.pub);
      };
      postCommands = ''
        zpool import -a
        echo "zfs load-key -a; killall zfs" >> /root/.profile
      '';
    };
    secrets = {
      "/etc/secrets/initrd/ssh_host_ed25519_key" = /etc/secrets/initrd/ssh_host_ed25519_key;
    };
  };

  networking.hostName = "media-center"; # Define your hostname.
  networking.hostId = "36ce7dcd";
  networking.useDHCP = true;

  time.timeZone = "America/Los_Angeles";

  services.xserver = {
    enable = true;
    desktopManager = {
      xterm.enable = false;
      xfce.enable = true;
    };
  };
  services.displayManager.defaultSession = "xfce";

  programs.virt-manager.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.docker.enable = true;

  # virtualisation.oci-containers.containers = {
  #   docker-osx = {
  #     devices = [
  #       "/dev/kvm"
  #     ];
  #     ports = [
  #       "50922:10022"
  #     ];
  #     volumes = [
  #       "/tmp/.X11-unix:/tmp/.X11-unix"
  #     ];
  #     environment = {
  #       DISPLAY = "${DISPLAY:-:0.0}";
  #       GENERATE_UNIQUE = "true";
  #       CPU = "Haswell-noTSX";
  #       CPUID_FLAGS = "kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on";
  #       MASTER_PLIST_URL = "https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom-sonoma.plist";
  #       SHORTNAME = "sequoia";
  #     };
  #     image = "sickcodes/docker-osx:latest";
  #   };
  # };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    root.openssh.authorizedKeys.keys = lib.splitString "\n" (builtins.readFile ../../id_rsa.pub);
    alex = {
      isNormalUser = true;
      extraGroups = [
        "wheel" # Enable 'sudo' for the user.
        "docker"
        "libvirtd" ];
      packages = with pkgs; [
        firefox
        hyperion-ng
        tree
      ];
      openssh.authorizedKeys.keys = lib.splitString "\n" (builtins.readFile ../../id_rsa.pub);
    };
  };
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
  ];

  environment.variables.EDITOR = "vim";

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  systemd.services.hyperion = {
    description = "Hyperion ambient light systemd service";
    documentation = [ "https://docs.hyperion-project.org" ];
    requisite = [ "network.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "systemd-resolved.service" ];
    serviceConfig = {
      ExecStart = ''${pkgs.hyperion-ng}/bin/hyperiond'';
      WorkingDirectory = ''${pkgs.hyperion-ng}/share/hyperion/bin'';
      # WorkingDirectory = "/run/current-system/sw/share/hyperion/bin";
      User = "alex";
      TimeoutStopSec = 5;
      KillMode = "mixed";
      Restart = "on-failure";
      RestartSec = 2;
    };
    wantedBy = [ "multi-user.target" ];
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    8090 # hyperion-ng
  ];

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?

}
