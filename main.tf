
locals {
  vcn_id = var.existing_vcn_ocid == "" ? oci_core_virtual_network.mysqlvcn[0].id : var.existing_vcn_ocid
  nat_gatway_id = var.existing_nat_gateway_ocid == "" ? oci_core_nat_gateway.nat_gateway[0].id : var.existing_nat_gateway_ocid
  private_route_table_id = var.existing_private_route_table_ocid == "" ? oci_core_route_table.private_route_table[0].id : var.existing_private_route_table_ocid
  private_subnet_id = var.existing_private_subnet_ocid == "" ? oci_core_subnet.private[0].id : var.existing_private_subnet_ocid
  private_security_list_id = var.existing_private_security_list_ocid == "" ? oci_core_security_list.private_security_list[0].id : var.existing_private_security_list_ocid
}

data "oci_identity_availability_domains" "ad" {
  compartment_id = var.tenancy_ocid
}

data "template_file" "ad_names" {
  count    = length(data.oci_identity_availability_domains.ad.availability_domains)
  template = lookup(data.oci_identity_availability_domains.ad.availability_domains[count.index], "name")
}


data "oci_mysql_mysql_configurations" "shape" {
    compartment_id = var.compartment_ocid
    type = ["DEFAULT"]
    shape_name = var.mysql_shape
}

resource "oci_core_virtual_network" "mysqlvcn" {
  cidr_block = var.vcn_cidr
  compartment_id = var.compartment_ocid
  display_name = var.vcn
  dns_label = "mysqlvcn"

  count = var.existing_vcn_ocid == "" ? 1 : 0
}


resource "oci_core_nat_gateway" "nat_gateway" {
  compartment_id = var.compartment_ocid
  vcn_id = local.vcn_id
  display_name   = "nat_gateway"

  count = var.existing_nat_gateway_ocid == "" ? 1 : 0
}


resource "oci_core_route_table" "private_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id = local.vcn_id
  display_name   = "RouteTableForMySQLPrivate"
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = local.nat_gatway_id
  }

  count = var.existing_private_route_table_ocid == "" ? 1 : 0
}

resource "oci_core_security_list" "private_security_list" {
  compartment_id = var.compartment_ocid
  display_name   = "Private"
  vcn_id = local.vcn_id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
  ingress_security_rules  {
    protocol = "1"
    source   = var.vcn_cidr
  }
  ingress_security_rules  {
    tcp_options  {
      max = 3306
      min = 3306
    }
    protocol = "6"
    source   = var.vcn_cidr
  }
  ingress_security_rules  {
    tcp_options  {
      max = 33061
      min = 33060
    }
    protocol = "6"
    source   = var.vcn_cidr
  }

  count = var.existing_private_security_list_ocid == "" ? 1 : 0
}

resource "oci_core_subnet" "private" {
  cidr_block                 = cidrsubnet(var.vcn_cidr, 8, 1)
  display_name               = "mysql_private_subnet"
  compartment_id             = var.compartment_ocid
  vcn_id                     = local.vcn_id
  route_table_id             = local.private_route_table_id
  security_list_ids          = [local.private_security_list_id]
  #dhcp_options_id = var.use_existing_vcn_ocid ? var.existing_vcn_ocid.default_dhcp_options_id : oci_core_virtual_network.mysqlvcn[0].default_dhcp_options_id
  prohibit_public_ip_on_vnic = "true"
  dns_label                  = "mysqlpriv"

  count = var.existing_private_subnet_ocid == "" ? 1 : 0

}

module "mds-instance" {
  source         = "./modules/mds-instance"
  admin_password = var.admin_password
  admin_username = var.admin_username
  availability_domain = data.template_file.ad_names.*.rendered[0]
  configuration_id = data.oci_mysql_mysql_configurations.shape.configurations[0].id
  compartment_ocid = var.compartment_ocid
  subnet_id = local.private_subnet_id
  display_name = var.mds_instance_name
  existing_mds_instance_id  = var.existing_mds_instance_ocid
  deploy_ha = var.deploy_mds_ha
  deploy_heatwave = var.deploy_mds_heatwave
  heatwave_cluster_size = var.heatwave_cluster_size
  mysql_shape = var.mysql_shape
}

