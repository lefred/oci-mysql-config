
locals {
    db_system_id = var.existing_mds_instance_id ==  "" ? oci_mysql_mysql_db_system.MDSinstance[0].id : var.existing_mds_instance_id
}

resource "oci_mysql_mysql_db_system" "MDSinstance" {
    admin_password = var.admin_password
    admin_username = var.admin_username
    availability_domain = var.availability_domain
    compartment_id = var.compartment_ocid
    configuration_id = oci_mysql_mysql_configuration.mds_mysql_configuration.id
    shape_name = var.mysql_shape
    subnet_id = var.subnet_id
    data_storage_size_in_gb = var.mysql_data_storage_in_gb
    display_name = var.display_name

    count = var.existing_mds_instance_id == "" ? 1 : 0

    is_highly_available = var.deploy_ha

    maintenance {
      window_start_time = "sun 01:00"
    }

    backup_policy {
       is_enabled        = "true"
       retention_in_days = "3"
       window_start_time = "01:00-00:00"
    }
    
}


data "oci_mysql_mysql_configurations" "mds_mysql_configurations" {
  compartment_id = var.compartment_ocid

  #Optional
  state        = "ACTIVE"
  shape_name   = var.mysql_shape
}


resource "oci_mysql_mysql_configuration" "mds_mysql_configuration" {
	#Required
	compartment_id = var.compartment_ocid
        shape_name   = var.mysql_shape

	#Optional
	description = "MDS configuration created by terraform"
	display_name = "MDS terraform configuration"
	parent_configuration_id = data.oci_mysql_mysql_configurations.mds_mysql_configurations.configurations[0].id
	variables {

		#Optional
		max_connections = "501"
        binlog_expire_logs_seconds = "7200"
	}
}


data "oci_mysql_mysql_db_system" "MDSinstance_to_use" {
    db_system_id =  local.db_system_id
}

resource "oci_mysql_heat_wave_cluster" "test_heat_wave_cluster" {
    #Required
    db_system_id  = local.db_system_id
    cluster_size  = var.heatwave_cluster_size 
    shape_name    = var.heatwave_cluster_shape

    count = var.deploy_heatwave ? 1 : 0
}

