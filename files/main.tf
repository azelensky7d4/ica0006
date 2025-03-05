provider "vsphere" {
  # If you use a domain, set your login like this "Domain\\User"
  # Change the username to your uni-id and password as hardcoded or environment variable
  user           = "UNI-ID@intra.ttu.ee"
  password       = "PASSWORD"
  vsphere_server = "192.168.184.253"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "Datacenter_407"
}

# If you don't have any resource pools, put "/Resources" after cluster name
data "vsphere_resource_pool" "pool" {
  name          = "HPE BladeSystem Gen8 - Rack 3/Resources"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Retrieve datastore information on vsphere
data "vsphere_datastore" "datastore" {
  name          = "Hitachi_LUN1"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Retrieve network information on vsphere
data "vsphere_network" "network" {
  name          = "VM Network"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Retrieve template information on vsphere
data "vsphere_virtual_machine" "template" {
  name          = "Ubuntu 22.04 vanilla template"
  datacenter_id = data.vsphere_datacenter.dc.id
}

############# VM CONFIG ##################
# Set vm parameters
# VM name should be defined as GRUPP_X number you have been assigned
resource "vsphere_virtual_machine" "demo" {
  name             = "grupp_11"
  num_cpus         = 2
  memory           = 4096
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  scsi_type        = data.vsphere_virtual_machine.template.scsi_type
  folder           = "ICA0006"

  # Set network parameters
  network_interface {
    network_id = data.vsphere_network.network.id
  }

  # Use a predefined vmware template as main disk
  disk {
    label = "vm-one.vmdk"
    size = "50"
    eagerly_scrub    = false
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }
}
