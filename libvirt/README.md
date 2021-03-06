# Terraform cluster deployment with Libvirt

# Table of content:

- [Requirements](#requirements)
- [Howto](#quickstart)
- [Monitoring](../doc/monitoring.md)
- [Design](#design)
- [Specifications](#specifications)
- [Troubleshooting](#troubleshooting)

# Requirements

1. You need to have Terraform and the the Libvirt provider for Terraform. You may download packages from the
   [openSUSE Build Service](http://download.opensuse.org/repositories/systemsmanagement:/terraform/) or
   [build from source](https://github.com/dmacvicar/terraform-provider-libvirt)

   You will need to have a working libvirt/kvm setup for using the libvirt-provider. (refer to upstream doc of [libvirt provider](https://github.com/dmacvicar/terraform-provider-libvirt))

2. You need to fulfill the system requirements provided by SAP for each Application. At least 15 GB of free disk space and 512 MiB of free memory per node.

# Quickstart

1) Make sure you use terraform workspaces, create new one with: ```terraform workspace new $USER``` 

  For more doc, see: [workspace](../doc/workspaces-workflow.md). 
  If you don't create a new one, the string `default` will be used as workspace name. This is however highly discouraged since the workspace name is used as prefix for resources names, which can led to conflicts to unique names in a shared server ( when using a default name).

2) Edit the `terraform.tfvars.example` file, following the Readme.md in the provider directory.

3) Adapt pillars:

  Choose one profile, among the list. (in this example we choose `cost_optimized`)

  * from root top-level dir:
   `cp pillar_examples/libvirt/cost_optimized/*  salt/hana_node/files/pillar`

For more informations have a look at [pillar-doc](../pillar_examples/README.md)

4) Deploy with:

```bash
terraform workspace new myworkspace # The workspace name will be used to create the name of the created resources as prefix (`default` by default)
terraform init
terraform apply
terraform destroy
```




# Design

This project is mainly based in [sumaform](https://github.com/uyuni-project/sumaform/)

Components:

- **modules**: Terraform modules to deploy a basic two nodes SAP HANA environment.
- **salt**: Salt provisioning states to configure the deployed machines with the
all required components.


### Terraform modules
- [base](modules/base): Base configuration of the cluster. The used SLES images, private
network and generic data are managed here.
- [host](modules/host): The generic SAP HANA node definition. This modules defines the most
important features of the each node (attach used partitions, networks, OS parameters, etc).
Besides that, the different kind of provisioners are available in this module. By now, only
`salt` is supported but more could be added just adding other `provisioner` files like
[salt_provisioner](modules/host/salt_provisioner.tf).
- [hana_node](modules/hana_node): Specific SAP HANA node defintion. Basically it calls the
host module with some particular updates. 
 The hana node contains also:
 * sbd device definition. Currently a shared disk.
- [iscsi_server](modules/iscsi_server): Machine to host a iscsi target.
- [monitoring](modules/monitoring): Machine to host the monitoring stack.

### Salt modules
- [default](../salt/default): Default configuration for each node. Install the most
basic packages and apply basic configuration.
- [hana_node](../salt/hana_node): Apply SAP HANA nodes specific updates to install
SAP HANA and enable system replication according [pillar](../../pillar_examples/libvirt/hana.sls)
data.

# Specifications

* main.tf

**main.tf** stores the configuration of the terraform deployment, the infrastructure configuration basically. Here some important tips to update the file properly (all variables are described in each module variables file):

- **qemu_uri**: Uri of the libvirt provider.
- **base_image**: The cluster nodes image is selected updating the *image* parameter in the *base* module.
- **network_name** and **bridge**: If the cluster is deployed locally, the *network_name* should match with a currently available virtual network. If the cluster is deployed remotely, leave the *network_name* empty and set the *bridge* value with remote machine bridge network interface.
- **sap_inst_media**: Public media where SAP installation files are stored.
- **iprange**: IP range addresses for the isolated network.
- **host_ips**: Each host IP address (sequential order).
- **shared_storage_type**: Shared storage type between iscsi and KVM raw file shared disk. Available options: `iscsi` and `shared-disk`.
- **iscsi_srv_ip**: IP address of the machine that will host the iscsi target (only used if `iscsi` is used as a shared storage for fencing)
- **iscsi_image**: Source image of the machine hosting the iscsi target (sles15 or above) (only used if `iscsi` is used as a shared storage for fencing)
- **monitoring_srv_ip**: IP address of the machine that will host the monitoring stack
- **ha_sap_deployment_repo**: Repository with HA and Salt formula packages. The latest RPM packages can be found at [https://download.opensuse.org/repositories/network:/ha-clustering:/Factory/{YOUR OS VERSION}](https://download.opensuse.org/repositories/network:/ha-clustering:/Factory/)
- **devel_mode**: Whether or not to install HA/SAP packages from ha_sap_deployment_repo
- **scenario_type**: SAP HANA scenario type. Available options: `performance-optimized` and `cost-optimized`.
- **provisioner**: Select the desired provisioner to configure the nodes. Salt is used by default: [salt](../salt). Let it empty to disable the provisioning part.
- **background**: Run the provisioning process in background finishing terraform execution.
- **reg_code**: Registration code for the installed base product (Ex.: SLES for SAP). This parameter is optional. If informed, the system will be registered against the SUSE Customer Center.
- **reg_email**: Email to be associated with the system registration. This parameter is optional.
- **reg_additional_modules**: Additional optional modules and extensions to be registered (Ex.: Containers Module, HA module, Live Patching, etc). The variable is a key-value map, where the key is the _module name_ and the value is the _registration code_. If the _registration code_ is not needed, set an empty string as value. The module format must follow SUSEConnect convention:
    - `<module_name>/<product_version>/<architecture>`
    - *Example:* Suggested modules for SLES for SAP 15


          sle-module-basesystem/15/x86_64
          sle-module-desktop-applications/15/x86_64
          sle-module-server-applications/15/x86_64
          sle-ha/15/x86_64 (use the same regcode as SLES for SAP)
          sle-module-sap-applications/15/x86_64

For more information about registration, check the ["Registering SUSE Linux Enterprise and Managing Modules/Extensions"](https://www.suse.com/documentation/sles-15/book_sle_deployment/data/cha_register_sle.html) guide.

Specific QA variables
* **qa_mode**: If set to true, it disables extra packages not already present in the image. For example, set this value to true if performing the validation of a new image.
* **hwcct**: If set to true, it executes HANA Hardware Configuration Check Tool to bench filesystems. It's a very long test (about 2 hours), results will be both in /root/hwcct_out and in the global log file /tmp/provisioning.log.

If the current *main.tf* is used, only *uri* (usually SAP HANA cluster deployment needs a powerful machine, not recommended to deploy locally) and *sap_inst_media* parameters must be updated.

* hana.sls

**hana.sls** is used to configure the SAP HANA cluster. Check the options in: [saphanabootstrap-formula](https://github.com/SUSE/saphanabootstrap-formula)

* cluster.sls

**cluster.sls** is used to configure the HA cluster. Check the options in: [habootstrap-formula](https://github.com/SUSE/habootstrap-formula)


# Troubleshooting

### Resources have not been destroyed

Sometimes it happens that created resources are left after running
`terraform destroy`. It happens especially when the `terraform apply` command
was not successful and you tried to destroy the setup in order of resetting the
state of your terraform deployment to zero.
It is often helpful to simply run `terraform destroy` again. However, even when
it succeeds in this case you might still want to check manually for remaining
resources.

For the following commands you need to use the command line tool Virsh. You can
retrieve the QEMU URI Virsh is currently connected to by running the command
`virsh uri`.

#### Checking networks

You can run `virsh net-list --all` to list all defined Libvirt networks. You can
delete undesired ones by executing `virsh net-undefine <network_name>`, where
`<network_name>` is the name of the network you like to delete.

#### Checking domains

For each node a domain is defined by Libvirt in order to address the specific
machine. You can list all domains by running the command `virsh list`. When you
like to delete a domain you can run `virsh undefine <domain_name>` where
`<domain_name>` is the name of the domain you like to delete.

#### Checking images

In case you experience issues with your images such as install ISOs for
operating systems or virtual disks of your machine check the following folder
with elevated privileges: `sudo ls -Faihl /var/lib/libvirt/images/`

#### Packages failures

If some package installation fails during the salt provisioning, the
most possible thing is that some repository is missing.
Add the new repository with the needed package and try again.
