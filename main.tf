resource "openstack_compute_flavor_v2" "this" {
  count = var.flavor_id == null ? 1 : 0

  flavor_id    = var.flavor_id
  name         = var.flavor_name
  ram          = var.flavor_ram
  vcpus        = var.flavor_vcpus
  disk         = var.flavor_disk
  is_public    = var.flavor_is_public
  ephemeral    = var.flavor_ephemeral
  swap         = var.flavor_swap
  rx_tx_factor = var.flavor_rx_tx_factor
  extra_specs  = var.flavor_extra_specs
}


locals {
  volume_devices = [for device in var.block_device :
    merge({
      name                 = "${var.name}-volume-${try(device.boot_index, index(var.block_device, device))}"
      region               = try(device.region, null)
      size                 = try(device.volume_size, 10)
      image_id             = !try(device.attachable, false) ? try(device.image_id, var.source_volume_image_id) : null
      enable_online_resize = try(device.enable_online_resize, true)
      consistency_group_id = try(device.consistency_group_id, null)
      description          = try(device.description, null)
      metadata             = try(device.metadata, null)
      snapshot_id          = try(device.snapshot_id, null)
      source_replica       = try(device.source_replica, null)
      source_vol_id        = try(device.source_vol_id, null)
      volume_type          = try(device.volume_type, null)
      multiattach          = try(device.multiattach, null)
      scheduler_hints      = try(device.scheduler_hints, null)
  }) if device.source_type == "volume" && device.destination_type == "volume"]
}

resource "openstack_blockstorage_volume_v3" "this" {
  for_each = { for device in local.volume_devices : device.name => device }

  name                 = each.value.name
  size                 = each.value.size
  volume_type          = each.value.volume_type
  image_id             = each.value.image_id
  enable_online_resize = each.value.enable_online_resize
  consistency_group_id = each.value.consistency_group_id
  description          = each.value.description
  metadata             = each.value.metadata
  snapshot_id          = each.value.snapshot_id
  source_replica       = each.value.source_replica
  source_vol_id        = each.value.source_vol_id
  multiattach          = each.value.multiattach
  dynamic "scheduler_hints" {
    for_each = each.value.scheduler_hints != null ? [1] : []
    content {
      different_host        = try(scheduler_hints.value.different_host, null)
      same_host             = try(scheduler_hints.value.same_host, null)
      local_to_instance     = try(scheduler_hints.value.local_to_instance, null)
      query                 = try(scheduler_hints.value.query, null)
      additional_properties = try(scheduler_hints.value.additional_properties, null)
    }
  }
  lifecycle {
    ignore_changes = [image_id]
  }
}


locals {
  boot_block_device = [for device in var.block_device :
    merge({
      name                  = "${var.name}-volume-${try(device.boot_index, index(var.block_device, device))}"
      uuid                  = coalesce(try(device.uuid, null), openstack_blockstorage_volume_v3.this["${var.name}-volume-${try(device.boot_index, index(var.block_device, device))}"].id)
      source_type           = try(device.source_type, "volume")
      volume_size           = (try(device.source_type, "") == "blank" && try(device.destination_type, "") == "volume") || (try(device.source_type, "") == "image" && try(device.destination_type, "") == "volume") || (try(device.source_type, "") == "blank" && try(device.destination_type, "") == "local") ? device.volume_size : null
      guest_format          = try(device.guest_format, "") == "ext2" || try(device.guest_format, "") == "ext3" || try(device.guest_format, "") == "ext4" || try(device.guest_format, "") == "xfs" || try(device.guest_format, "") == "swap" ? device.guest_format : null
      boot_index            = try(device.boot_index, index(var.block_device, device))
      destination_type      = try(device.destination_type, null)
      delete_on_termination = try(device.delete_on_termination, null)
      volume_type           = try(device.volume_type, null)
      device_type           = try(device.device_type, null)
      disk_bus              = try(device.disk_bus, null)
    }) if !try(device.attachable, false)
  ] // : []

  attachable_block_device = [for device in var.block_device :
    merge({
      name = "${var.name}-volume-${try(device.boot_index, index(var.block_device, device))}"
      id   = openstack_blockstorage_volume_v3.this["${var.name}-volume-${try(device.boot_index, index(var.block_device, device))}"].id
    })
  if try(device.attachable, false)]
}


resource "openstack_compute_instance_v2" "this" {

  name                    = var.name
  image_name              = var.source_volume_image_id != null && (var.image_id == null && var.image_name == null) ? null : var.image_name
  flavor_id               = coalesce(var.flavor_id, one(openstack_compute_flavor_v2.this[*].id))
  flavor_name             = var.flavor_id == null ? var.flavor_name : null
  user_data               = var.user_data
  key_pair                = var.create_key_pair ? one(openstack_compute_keypair_v2.this[*].name) : var.key_pair
  security_groups         = var.create_secgroup && var.ports == null ? [one(openstack_networking_secgroup_v2.this[*].name)] : var.security_groups
  availability_zone_hints = var.availability_zone_hints
  metadata                = var.metadata
  // If var.network is defined.
  dynamic "network" {
    for_each = alltrue([var.network != null, var.network_mode == null]) ? toset(var.network) : []
    iterator = net
    content {
      uuid           = try(net.value.name, false) != false || try(net.value.port, false) != false ? net.value.uuid : null
      name           = try(net.value.uuid, false) != false || try(net.value.port, false) != false ? net.value.name : null
      port           = try(net.value.uuid, false) != false || try(net.value.name, false) != false ? net.value.port : null
      fixed_ip_v4    = try(net.value.fixed_ip_v4, null)
      access_network = try(net.value.access_network, null)
    }
  }
  // If var.ports is defined.
  dynamic "network" {
    for_each = alltrue([var.network == null, var.ports != null, var.network_mode == null]) ? toset(local.ports) : []
    iterator = port
    content {
      port = openstack_networking_port_v2.this[port.value.name].id
    }
  }

  network_mode = var.network == null ? var.network_mode : null
  config_drive = var.config_drive
  #checkov:skip=CKV_OPENSTACK_4:Ensure that instance does not use basic credentials. Default value is null.
  admin_pass   = var.admin_pass
  dynamic "block_device" {
    for_each = local.boot_block_device
    iterator = device
    content {
      uuid                  = device.value.uuid
      source_type           = device.value.source_type
      volume_size           = device.value.volume_size
      guest_format          = device.value.guest_format
      boot_index            = device.value.boot_index
      destination_type      = device.value.destination_type
      delete_on_termination = device.value.delete_on_termination
      device_type           = device.value.device_type
      disk_bus              = device.value.disk_bus
    }
  }
  dynamic "scheduler_hints" {
    for_each = var.scheduler_hints != null ? [1] : []

    content {
      group                 = try(var.scheduler_hints.group, null)
      different_host        = try(var.scheduler_hints.different_host, null)
      same_host             = try(var.scheduler_hints.same_host, null)
      query                 = try(var.scheduler_hints.query, null)
      target_cell           = try(var.scheduler_hints.target_cell, null)
      different_cell        = try(var.scheduler_hints.different_cell, null)
      build_near_host_ip    = try(var.scheduler_hints.build_near_host_ip, null)
      additional_properties = try(var.scheduler_hints.additional_properties, null)
    }
  }
  dynamic "personality" {
    for_each = var.personality != null ? [1] : []
    content {
      file    = try(var.personality.file, null)
      content = try(var.personality.content, null)
    }
  }
  stop_before_destroy = var.stop_before_destroy
  force_delete        = var.force_delete
  power_state         = var.power_state
  dynamic "vendor_options" {
    for_each = var.vendor_options != null ? [1] : []
    content {
      ignore_resize_confirmation  = try(var.vendor_options.ignore_resize_confirmation, null)
      detach_ports_before_destroy = try(var.vendor_options.detach_ports_before_destroy, null)
    }
  }

  tags = setunion(var.tags)

  lifecycle {
    ignore_changes = [image_id]
  }

  depends_on = [
    openstack_blockstorage_volume_v3.this,
  ]
}


resource "openstack_compute_volume_attach_v2" "this" {
  for_each = { for device in local.attachable_block_device : device.name => device }

  instance_id = openstack_compute_instance_v2.this.id
  volume_id   = each.value.id

  depends_on = [
    openstack_compute_instance_v2.this,
    openstack_blockstorage_volume_v3.this
  ]
}

resource "openstack_compute_keypair_v2" "this" {
  count = var.create_key_pair ? 1 : 0

  name = var.name
}


locals {
  ports = length(var.ports) > 0 ? [for port in var.ports : merge({
    region                = try(port.port, null)
    name                  = "${port.name}-port-${index(var.ports, port)}"
    description           = coalesce(try(port.description, null), var.description)
    network_id            = var.network_id
    admin_state_up        = try(port.admin_state_up, null)
    mac_address           = try(port.mac_address, null)
    tenant_id             = try(port.tenant_id, null)
    device_owner          = try(port.device_owner, null)
    no_security_groups    = try(port.no_security_groups, null) != null ? port.no_security_groups : null
    device_id             = try(port.device_id, null)
    fixed_ip              = try(port.fixed_ip, null) != null ? try(port.fixed_ip, null) : null
    no_fixed_ip           = try(port.fixed_ip, null) != null ? try(port.no_fixed_ip, null) : null
    allowed_address_pairs = try(port.allowed_address_pairs, null)
    extra_dhcp_option     = try(port.extra_dhcp_option, null)
    port_security_enabled = try(port.port_security_enabled, null)
    value_specs           = try(port.value_specs, null)
    binding               = try(port.binding, null)
    dns_name              = try(port.dns_name, null)
    qos_policy_id         = try(port.qos_policy_id, null)
    security_group_ids    = coalescelist(try(port.security_group_ids, []), [one(openstack_networking_secgroup_v2.this[*].id)])
    tags                  = coalesce(try(port.tags, null), var.tags)
  })] : []
}


// Create a network port.
resource "openstack_networking_port_v2" "this" {
  for_each = length(local.ports) > 0 ? { for p in local.ports : p.name => p } : {}

  region             = each.value.region
  name               = each.key
  description        = each.value.description
  network_id         = each.value.network_id
  admin_state_up     = each.value.admin_state_up
  mac_address        = each.value.mac_address
  tenant_id          = each.value.tenant_id
  device_owner       = each.value.device_owner
  no_security_groups = each.value.no_security_groups
  device_id          = each.value.device_id
  dynamic "fixed_ip" {
    for_each = each.value.fixed_ip != null ? each.value.fixed_ip : []
    content {
      subnet_id  = fixed_ip.value.subnet_id
      ip_address = try(fixed_ip.value.ip_address, null)
    }
  }
  no_fixed_ip = each.value.no_fixed_ip
  dynamic "allowed_address_pairs" {
    for_each = each.value.allowed_address_pairs != null ? each.value.allowed_address_pairs : []
    content {
      ip_address  = allowed_address_pairs.value.ip_address
      mac_address = try(allowed_address_pairs.value.mac_address, null)
    }
  }
  dynamic "extra_dhcp_option" {
    for_each = each.value.extra_dhcp_option != null ? each.value.extra_dhcp_option : []
    content {
      name       = extra_dhcp_option.value.name
      value      = extra_dhcp_option.value.value
      ip_version = extra_dhcp_option.value.ip_version
    }
  }
  port_security_enabled = each.value.port_security_enabled
  value_specs           = each.value.value_specs
  dynamic "binding" {
    for_each = each.value.binding != null ? each.value.binding : []
    content {
      host_id   = try(binding.value.host_id, null)
      profile   = try(binding.value.profile, null)
      vnic_type = try(binding.value.vnic_type, null)
    }
  }
  dns_name           = each.value.dns_name
  qos_policy_id      = each.value.qos_policy_id
  security_group_ids = var.create_secgroup ? [one(openstack_networking_secgroup_v2.this[*].id)] : var.security_group_ids
  tags               = setunion(each.value.tags)
}


resource "openstack_networking_secgroup_v2" "this" {
  count = var.create_secgroup ? 1 : 0

  name        = "${var.name}-secgroup"
  description = "${var.name} security group"
  tenant_id   = var.tenant_id
  tags        = setunion(var.tags)
}

locals {
  _directions = ["ingress", "egress"]
  _ethertypes = ["IPv4", "IPv6"]
  _protocols = [
    "tcp", "udp", "icmp", "ah", "dccp", "egp", "esp", "gre",
    "igmp", "ipv6-encap", "ipv6-frag", "ipv6-icmp", "ipv6-nonxt",
    "ipv6-opts", "ipv6-route", "ospf", "pgm", "rsvp", "sctp", "udplite", "vrrp"
  ]
  secgroup_rules = var.secgroup_rules != null ? [
    for rule in var.secgroup_rules :
    merge({
      description      = try(rule.description, null)
      direction        = contains(local._directions, try(rule.direction, "")) ? rule.direction : "ingress"
      ethertype        = contains(local._ethertypes, try(rule.ethertype, "")) ? rule.direction : "IPv4"
      protocol         = contains(local._protocols, try(rule, "protocol", "")) ? rule.protocol : "tcp"
      port_range_min   = try(rule.port_range_min, 0) >= 1 && try(rule.port_range_min, 0) <= 65535 ? rule.port_range_min : null
      port_range_max   = try(rule.port_range_max, 0) >= 1 && try(rule.port_range_max, 0) <= 65535 ? rule.port_range_max : null
      remote_ip_prefix = try(rule.remote_ip_prefix, "0.0.0.0/0")
      remote_group_id  = try(rule.remote_group_id, null)
      tenant_id        = try(rule.tenant_id, null)
      region           = try(rule.region, null)
    })
  ] : []

  securitygroup_rules = { for idx, rule in local.secgroup_rules : "${rule.direction}_${rule.protocol}_${idx}" => rule }
}


resource "openstack_networking_secgroup_rule_v2" "this" {
  for_each = var.create_secgroup ? local.securitygroup_rules : {}

  region            = each.value.region
  security_group_id = one(openstack_networking_secgroup_v2.this[*]).id
  description       = each.value.description
  direction         = each.value.direction
  ethertype         = each.value.ethertype
  protocol          = each.value.protocol
  port_range_min    = each.value.port_range_min
  port_range_max    = each.value.port_range_max
  remote_ip_prefix  = each.value.remote_ip_prefix
  remote_group_id   = try(each.value.remote_group_id, null)
  tenant_id         = try(each.value.tenant_id, null)
}


resource "openstack_networking_floatingip_v2" "this" {
  count = var.assign_floating_ip ? 1 : 0

  description = var.description
  pool        = coalesce(var.floating_ip_pool, "external-network")
  subnet_ids  = length(var.floating_ip_subnet_ids) > 0 ? var.floating_ip_subnet_ids : null
}


resource "openstack_compute_floatingip_associate_v2" "this" {
  count = var.assign_floating_ip ? 1 : 0

  floating_ip = one(openstack_networking_floatingip_v2.this[*].address)
  instance_id = openstack_compute_instance_v2.this.id
}