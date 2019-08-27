// Names are calculated as follows:
// ${terraform.workspace}${var.name}${var.host_count > 1 ? "-${host_count.index  + 1}" : ""}
// This means:
//   workspace + name (if count = 1)
//   workspace + name + "-" + index (if count > 1)
terraform {
  required_version = ">= 0.12"
}

resource "libvirt_volume" "main_disk" {
  name             = "${terraform.workspace}-${var.name}${var.host_count > 1 ? "-${count.index + 1}" : ""}-main-disk"
  base_volume_name = var.base_configuration["use_shared_resources"] ? "" : "${terraform.workspace}-baseimage"
  pool             = var.base_configuration["pool"]
  count            = var.host_count
}

resource "libvirt_volume" "hana_disk" {
  name  = "${terraform.workspace}-${var.name}${var.host_count > 1 ? "-${count.index + 1}" : ""}-hana-disk"
  pool  = var.base_configuration["pool"]
  count = var.host_count
  size  = var.hana_disk_size
}

resource "libvirt_domain" "domain" {
  name       = "${terraform.workspace}-${var.name}${var.host_count > 1 ? "-${count.index + 1}" : ""}"
  memory     = var.memory
  vcpu       = var.vcpu
  count      = var.host_count
  qemu_agent = true
   dynamic "disk" {
    for_each = [
        {
          "vol_id" = element(libvirt_volume.main_disk.*.id, count.index)
        },
        {
          "vol_id" = element(libvirt_volume.hana_disk.*.id, count.index)
        },
      ]
    content {
      volume_id = disk.value.vol_id
    }
  }
  // handle additional disks
  dynamic "disk" {
   for_each = var.additional_disk
   content {
     volume_id = disk.value.volume_id
   }
  }

  network_interface {
    wait_for_lease = true
    network_name   = var.base_configuration["network_name"]
    bridge         = var.base_configuration["bridge"]
    mac            = var.mac
  }

  network_interface {
    wait_for_lease = false
    network_id     = var.base_configuration["isolated_network_id"]
    hostname       = "${var.name}${var.host_count > 1 ? "0${count.index + 1}" : ""}"
    addresses      = [element(var.host_ips, count.index)]
  }

  xml {
    xslt = file("modules/host/shareable.xsl")
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  cpu = {
    mode = "host-passthrough"
  }
}

output "configuration" {
  value = {
    id       = libvirt_domain.domain.*.id
    hostname = libvirt_domain.domain.*.name
  }
}

output "addresses" {
  value = flatten(libvirt_domain.domain.*.network_interface.0.addresses)
}
