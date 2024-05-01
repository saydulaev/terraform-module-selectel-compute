variable "name" {
  description = "A unique name for the resource."
  type        = string
}

variable "description" {
  description = "Description for compute resources."
  type        = string
  default     = null
}

variable "image_id" {
  description = <<EOT
    The image ID of the desired image for the server. 
    Required if `image_name` is empty and not booting from a volume. 
    Do not specify if booting from a volume.
    EOT
  type        = string
  default     = null
}

variable "image_name" {
  description = <<EOT
    The name of the desired image for the server.
    Required if `image_id` is empty and not booting from a volume.
    Do not specify if booting from a volume.
    EOT
  type        = string
  default     = null
}

variable "source_volume_image_id" {
  description = "Source image id from which to create the new volume."
  type        = string
  default     = null
}

variable "user_data" {
  description = <<EOT
    The user data to provide when launching the instance.
    Changing this creates a new server.
    EOT
  type        = string
  default     = null
}

variable "security_groups" {
  description = "An array of one or more security group names to associate with the server."
  type        = list(string)
  default     = null
}

variable "availability_zone_hints" {
  description = "The availability zone in which to create the server."
  type        = string
  default     = null
}

variable "network" {
  description = "An array of one or more networks to attach to the instance."
  type = list(object({
    uuid           = optional(string) // (unless port or name is provided) The network UUID to attach to the server. Changing this creates a new server.
    name           = optional(string) // (unless uuid or port is provided) The human-readable name of the network. Changing this creates a new server.
    port           = optional(string) // (unless uuid or name is provided) The port UUID of a network to attach to the server. Changing this creates a new server.
    fixed_ip_v4    = optional(string) // Specifies a fixed IPv4 address to be used on this network. Changing this creates a new server.
    access_network = optional(string) // Specifies if this network should be used for provisioning access. Accepts true or false. Defaults to false.
  }))
  default = null
}

variable "network_id" {
  description = "Network ID."
  type        = string
  default     = null
}

variable "network_mode" {
  description = "Special string for network option to create the server."
  type        = string
  default     = null

  validation {
    condition     = var.network_mode == null || anytrue([var.network_mode == "auto", var.network_mode == "none"]) // contains(["auto", "none"], )
    error_message = "Network mode can be `auto` or `none`"
  }
}

variable "metadata" {
  description = "Metadata key/value pairs to make available from within the instance."
  type        = map(string)
  default     = null
}

variable "config_drive" {
  description = "Whether to use the config_drive feature to configure the instance."
  type        = bool
  default     = null
}

variable "admin_pass" {
  description = "The administrative password to assign to the server."
  type        = string
  default     = null
}

variable "key_pair" {
  description = "The name of a key pair to put on the server."
  type        = string
  default     = null
}

variable "block_device" {
  description = "Configuration of block devices."
  type = list(object({
    uuid                  = optional(string)      // [Fill in local vars] (Required unless source_type is set to "blank" ) The UUID of the image, volume, or snapshot. Changing this creates a new server.
    source_type           = string                // The source type of the device. Must be one of "blank", "image", "volume", or "snapshot". Changing this creates a new server.
    volume_size           = optional(number)      // The size of the volume to create (in gigabytes). Required in the following combinations: source=image and destination=volume, source=blank and destination=local, and source=blank and destination=volume. Changing this creates a new server.
    guest_format          = optional(string)      // Specifies the guest server disk file system format, such as ext2, ext3, ext4, xfs or swap. Swap block device mappings have the following restrictions: source_type must be blank and destination_type must be local and only one swap disk per server and the size of the swap disk must be less than or equal to the swap size of the flavor. Changing this creates a new server.
    boot_index            = number                // The boot index of the volume. It defaults to 0. Changing this creates a new server.
    destination_type      = optional(string)      // The type that gets created. Possible values are "volume" and "local". Changing this creates a new server.
    delete_on_termination = optional(bool)        // Delete the volume / block device upon termination of the instance. Defaults to false. Changing this creates a new server.
    volume_type           = optional(string)      // The volume type that will be used, for example SSD or HDD storage. The available options depend on how your specific OpenStack cloud is configured and what classes of storage are provided. Changing this creates a new server.
    device_type           = optional(string)      // The low-level device type that will be used. Most common thing is to leave this empty. Changing this creates a new server.
    disk_bus              = optional(string)      // The low-level disk bus that will be used. Most common thing is to leave this empty. Changing this creates a new server.
    attachable            = optional(bool, false) // Allow block device to be attachable
  }))
  default = []
}

variable "scheduler_hints" {
  description = "Provide the Nova scheduler with hints on how the instance should be launched."
  type = object({
    group                 = optional(string)       // A UUID of a Server Group. The instance will be placed into that group.
    different_host        = optional(list(string)) // A list of instance UUIDs. The instance will be scheduled on a different host than all other instances.
    same_host             = optional(list(string)) // A list of instance UUIDs. The instance will be scheduled on the same host of those specified.
    query                 = optional(list(string)) // A conditional query that a compute node must pass in order to host an instance. The query must use the JsonFilter syntax which is described here. At this time, only simple queries are supported. Compound queries using and, or, or not are not supported. An example of a simple query is: [">=", "$free_ram_mb", "1024"]
    target_cell           = optional(string)       // The name of a cell to host the instance.
    different_cell        = optional(list(string)) // The names of cells where not to build the instance.
    build_near_host_ip    = optional(string)       // An IP Address in CIDR form. The instance will be placed on a compute node that is in the same subnet.
    additional_properties = optional(map(string))  // Arbitrary key/value pairs of additional properties to pass to the scheduler.
  })
  default = null
}

variable "personality" {
  description = <<EOT
    Customize the personality of an instance by defining 
    one or more files and their contents. 
    EOT
  type = object({
    file    = string // The absolute path of the destination file.
    content = string // The contents of the file. Limited to 255 bytes.
  })
  default = null
}

variable "stop_before_destroy" {
  description = <<EOT
    Whether to try stop instance gracefully before destroying it, 
    thus giving chance for guest OS daemons to stop correctly.
    EOT
  type        = bool
  default     = null
}

variable "force_delete" {
  description = "Whether to force the OpenStack instance to be forcefully deleted."
  type        = bool
  default     = null
}

variable "power_state" {
  description = "Provide the VM state."
  type        = string
  default     = null

  validation {
    condition     = var.power_state == null || anytrue([var.power_state == "active", var.power_state == "shutoff"]) // contains(["active", "shutoff"], var.power_state)
    error_message = "Only `active` and `shutoff` are supported values."
  }
}

variable "tags" {
  description = "A set of string tags for the instance."
  type        = list(string)
  default     = null
}

variable "vendor_options" {
  description = "Map of additional vendor-specific options."
  type = object({
    ignore_resize_confirmation  = optional(bool) // Boolean to control whether to ignore manual confirmation of the instance resizing. This can be helpful to work with some OpenStack clouds which automatically confirm resizing of instances after some timeout.
    detach_ports_before_destroy = optional(bool) // Whether to try to detach all attached ports to the vm before destroying it to make sure the port state is correct after the vm destruction. This is helpful when the port is not deleted.
  })
  default = null
}

// Key pair
variable "create_key_pair" {
  description = "Create a new openssh key pair."
  type        = bool
  default     = false
}

#~~~ secgroup ~~~#
variable "secgroup_rules" {
  description = "Security group rules."
  type        = list(any)
  default     = null
}

variable "create_secgroup" {
  description = "Create sg or not."
  type        = bool
  default     = false
}

variable "security_group_ids" {
  description = "Array of if external created Security group"
  type        = list(string)
  default     = null
}

variable "tenant_id" {
  type    = string
  default = null
}

variable "flavor_name" {
  description = <<EOT
    The name of the desired flavor for the server.
    Required if `flavor_id` is empty.
    EOT
  type        = string
  default     = null
}
variable "flavor_ram" {
  description = "The exact amount of RAM (in megabytes)"
  type        = number
  default     = 1024
}

variable "flavor_ephemeral" {
  description = <<EOT
      The amount of ephemeral in GiB.
      If unspecified, the default is 0. 
      Changing this creates a new flavor.
    EOT
  type        = number
  default     = null
}

variable "flavor_vcpus" {
  description = "The amount of VCPUs."
  type        = number
  default     = 1
}

variable "flavor_extra_specs" {
  description = "Key/Value pairs of metadata for the flavor."
  type        = map(string)
  default     = null
}

variable "flavor_disk" {
  description = "The exact amount of disk (in gigabytes)."
  type        = number
  default     = 0
}

variable "flavor_id" {
  description = <<EOT
    The ID of the flavor. Conflicts with the `flavor_name`, 
    `flavor_min_ram` and `flavor_min_disk`.
    EOT
  type        = string
  default     = null
}

variable "flavor_swap" {
  description = "The amount of swap (in gigabytes)."
  type        = number
  default     = null
}

variable "flavor_is_public" {
  description = "The flavor visibility."
  type        = bool
  default     = false
}

variable "flavor_rx_tx_factor" {
  description = "The `rx_tx_factor` of the flavor."
  type        = string
  default     = null
}

variable "ports" {
  description = "Neutron ports."
  type = list(object({
    name               = optional(string)       // A unique name for the port. Changing this updates the name of an existing port.
    region             = optional(string)       // The region in which to obtain the V2 Networking client. A Networking client is needed to create a port. If omitted, the region argument of the provider is used. Changing this creates a new port.
    description        = optional(string)       // Human-readable description of the port. Changing this updates the description of an existing port.
    network_id         = string                 // The ID of the network to attach the port to. Changing this creates a new port.
    admin_state_up     = optional(bool)         // Administrative up/down status for the port (must be true or false if provided). Changing this updates the admin_state_up of an existing port.
    mac_address        = optional(string)       // Specify a specific MAC address for the port. Changing this creates a new port.
    tenant_id          = optional(string)       // The owner of the port. Required if admin wants to create a port for another tenant. Changing this creates a new port.
    device_owner       = optional(string)       // The device owner of the port. Changing this creates a new port.
    security_group_ids = optional(list(string)) // Conflicts with no_security_groups) A list of security group IDs to apply to the port. The security groups must be specified by ID and not name (as opposed to how they are configured with the Compute Instance).
    no_security_groups = optional(string)       // Conflicts with security_group_ids) If set to true, then no security groups are applied to the port. If set to false and no security_group_ids are specified, then the port will yield to the default behavior of the Networking service, which is to usually apply the "default" security group.
    device_id          = optional(string)       // The ID of the device attached to the port. Changing this creates a new port.
    fixed_ip = optional(list(object({
      subnet_id  = string           // Subnet in which to allocate IP address for this port.
      ip_address = optional(string) // IP address desired in the subnet for this port. If you don't specify ip_address, an available IP address from the specified subnet will be allocated to this port. This field will not be populated if it is left blank or omitted. To retrieve the assigned IP address, use the all_fixed_ips attribute.
    })))                            // Conflicts with no_fixed_ip. An array of desired IPs for this port. The structure is described below.
    no_fixed_ip = optional(bool)    // Conflicts with fixed_ip. Create a port with no fixed IP address. This will also remove any fixed IPs previously set on a port. true is the only valid value for this argument.
    allowed_address_pairs = optional(list(object({
      ip_address  = string           // The additional IP address.
      mac_address = optional(string) // The additional MAC address.
    })))                             // An IP/MAC Address pair of additional IP addresses that can be active on this port.
    extra_dhcp_option = optional(list(object({
      name       = string                          // Name of the DHCP option.
      value      = string                          // Value of the DHCP option.
      ip_version = optional(number)                // IP protocol version. Defaults to 4.
    })))                                           // An extra DHCP option that needs to be configured on the port. The structure is described below. Can be specified multiple times.
    port_security_enabled = optional(bool)         // Whether to explicitly enable or disable port security on the port. Port Security is usually enabled by default, so omitting argument will usually result in a value of true. Setting this explicitly to false will disable port security. In order to disable port security, the port must not have any security groups. Valid values are true and false.
    value_specs           = optional(map(string))  // Map of additional options.
    tags                  = optional(list(string)) // A set of string tags for the port.
    binding = optional(list(object({
      host_id   = optional(string)   // The ID of the host to allocate port on.
      profile   = optional(any)      // Custom data to be passed as binding:profile. Data must be passed as JSON.
      vnic_type = optional(string)   // VNIC type for the port. Can either be direct, direct-physical, macvtap, normal, baremetal or virtio-forwarder. Default value is normal.
    })))                             // The port binding allows to specify binding information for the port. The structure is described below.
    dns_name      = optional(string) // The port DNS name. Available, when Neutron DNS extension is enabled.
    qos_policy_id = optional(string) // Reference to the associated QoS policy.
  }))
  default = []
}

variable "floating_ip_pool" {
  description = <<EOT
    The pool of external network which will be used 
    to assign floating IP to instance.
    EOT
  type        = string
  default     = null
}

variable "floating_ip_subnet_ids" {
  description = "External subnet ids for floating IP."
  type        = list(string)
  default     = []
}

variable "assign_floating_ip" {
  description = "Assign floating ip to instance."
  type        = bool
  default     = false
}