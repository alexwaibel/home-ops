machine:
  install:
    disk: /dev/sda
    image: factory.talos.dev/installer-secureboot/{{ .SchematicID }}:{{ .Node.TalosVersion }}
    wipe: false
