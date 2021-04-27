provider "vsphere" {
  version              = ">= 1.3.0, <= 1.18.3"
  allow_unverified_ssl = "true"
}

provider "tls" {
  version = "~> 2.0"
}

provider "random" {
  version = "~> 2.1"
}

module "camtags" {
  source = "../Modules/camtags"
}

locals {
  private_ssh_key = length(var.vm_os_private_ssh_key) == 0 ? tls_private_key.generate.private_key_pem : base64decode(var.vm_os_private_ssh_key)
  public_ssh_key  = length(var.vm_os_private_ssh_key) == 0 ? tls_private_key.generate.public_key_openssh : var.vm_os_public_ssh_key
  #private_ssh_key="${tls_private_key.generate.private_key_pem}"
  #public_ssh_key="${tls_private_key.generate.public_key_openssh}"
}

resource "vsphere_tag_category" "ibm_terraform_automation_category" {
  count = length(module.camtags.tagslist) > 0 ? 1 : 0
  name        = format("%s %s", "IBM Terraform Automation Tags for", var.vm_name)
  description = "Category for IBM Terraform Automation"
  cardinality = "MULTIPLE"

  associable_types = [
    "VirtualMachine",
    "Datastore",
    "Network",
  ]
}

resource "vsphere_tag" "ibm_terraform_automation_tags" {
  count = length(module.camtags.tagslist)
  name        = element(module.camtags.tagslist, count.index)
  category_id = element(vsphere_tag_category.ibm_terraform_automation_category.*.id, 0)
  description = "Managed by IBM Terraform Automation"
}


resource "random_string" "random-dir" {
  length  = 8
  special = false
}

resource "tls_private_key" "generate" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "vsphere_virtual_machine" "vm" {
  name             = var.vm_name
  folder           = var.vm_folder
  num_cpus         = var.vm_vcpu
  memory           = var.vm_memory
  resource_pool_id = data.vsphere_resource_pool.resource_pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  guest_id         = data.vsphere_virtual_machine.vm_image_template.guest_id
  scsi_type        = data.vsphere_virtual_machine.vm_image_template.scsi_type
  tags = vsphere_tag.ibm_terraform_automation_tags[*].id
  clone {
    template_uuid = data.vsphere_virtual_machine.vm_image_template.id
    timeout       = var.vm_clone_timeout
    customize {
      linux_options {
        domain    = var.vm_domain_name
        host_name = var.vm_name
      }

      network_interface {
      }

      network_interface {
      }
      
      ipv4_gateway    = var.vm_ipv4_gateway
      dns_suffix_list = var.dns_suffixes
      dns_server_list = var.dns_servers
    }
  }

  network_interface {
    network_id   = data.vsphere_network.vm_network.id
    adapter_type = var.adapter_type
  }
  
  network_interface {
    network_id   = data.vsphere_network.vm_network.id
    adapter_type = var.adapter_type
  }  

  disk {
    label          = "${var.vm_name}.vmdk"
    size           = var.vm_disk_size
    keep_on_remove = var.vm_disk_keep_on_remove
    datastore_id   = data.vsphere_datastore.datastore.id
  }

  lifecycle {
    ignore_changes = [
      datastore_id,
      disk.0.datastore_id,
    ]
    create_before_destroy = true
  }

  # Specify the connection
  # Specify the connection
  connection {
    host        = self.default_ip_address
    type        = "ssh"
    user        = var.vm_os_user
    password    = var.vm_os_password
    private_key = length(var.vm_os_private_ssh_key) == 0 ? "" : base64decode(var.vm_os_private_ssh_key)
    timeout     = "5m"
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key = length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key
    bastion_port        = var.bastion_port
    bastion_host_key    = var.bastion_host_key
    bastion_password    = var.bastion_password    
  }
}

