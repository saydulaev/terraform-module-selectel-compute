output "instance" {
  description = "All compute exported attributes"
  value       = openstack_compute_instance_v2.this
}

output "keypair" {
  description = "Compute keypair exported attributes"
  value       = one(openstack_compute_keypair_v2.this[*])
}

output "flavor" {
  description = "Compute flavor exported attributes."
  value       = one(openstack_compute_flavor_v2.this[*])
}

output "volumes" {
  description = "Compute volumes exported attributes."
  value       = [for device in var.block_device : lookup(openstack_blockstorage_volume_v3.this, "${var.name}-volume-${device.boot_index}", null) if device.source_type == "volume" && device.destination_type == "volume"]
}

output "local_block_devices" {
  description = "For debug locals block_device."
  value       = concat(local.boot_block_device, local.attachable_block_device)
}

output "local_volume_devices" {
  description = "For debug locals volume_devices"
  value       = local.volume_devices
}
output "secgroup" {
  description = "Compute security group exported attributes."
  value       = one(openstack_networking_secgroup_v2.this[*])
}

output "secgroup_rules" {
  description = "Compute security group rules exported attributes."
  value       = var.create_secgroup ? { for idx, rule in local.secgroup_rules : "${rule.direction}_${rule.protocol}_${idx}" => openstack_networking_secgroup_rule_v2.this["${rule.direction}_${rule.protocol}_${idx}"] } : {}
}

output "floatingip" {
  description = "Compute floating IP exported attributes."
  value       = one(openstack_compute_floatingip_associate_v2.this[*])
}


output "networking_ports" {
  description = "Network port exported attributes."
  value       = var.ports != null && length(local.ports) > 0 ? [for port in local.ports : openstack_networking_port_v2.this[port.name]] : []
}

output "floating_ip" {
  description = "Floating IP."
  value       = one(openstack_networking_floatingip_v2.this[*].id)
}