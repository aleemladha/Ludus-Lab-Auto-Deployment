#!/bin/bash

# This script is like summoning a cyber-genie! It'll weave your lab environment with magic spells. ✨💻
#Made by AleemLadha @LadhaAleem
# Prepare the lab configuration
cat <<EOF > config.yml
ludus:
  - vm_name: "{{ range_id }}-NHA-DC01"
    hostname: "{{ range_id }}-DC01"
    template: win2019-server-x64-template
    vlan: 10
    ip_last_octet: 30
    ram_gb: 4
    cpus: 2
    windows:
      sysprep: true
  - vm_name: "{{ range_id }}-NHA-DC02"
    hostname: "{{ range_id }}-DC02"
    template: win2019-server-x64-template
    vlan: 10
    ip_last_octet: 31
    ram_gb: 4
    cpus: 2
    windows:
      sysprep: true
  - vm_name: "{{ range_id }}-NHA-SRV01"
    hostname: "{{ range_id }}-SRV01"
    template: win2019-server-x64-template
    vlan: 10
    ip_last_octet: 32
    ram_gb: 4
    cpus: 2
    windows:
      sysprep: true
  - vm_name: "{{ range_id }}-NHA-SRV02"
    hostname: "{{ range_id }}-SRV02"
    template: win2019-server-x64-template
    vlan: 10
    ip_last_octet: 33
    ram_gb: 4
    cpus: 2
    windows:
      sysprep: true
  - vm_name: "{{ range_id }}-NHA-SRV03"
    hostname: "{{ range_id }}-SRV03"
    template: win2019-server-x64-template
    vlan: 10
    ip_last_octet: 34
    ram_gb: 4
    cpus: 2
    windows:
      sysprep: true
  - vm_name: "{{ range_id }}-kali"
    hostname: "{{ range_id }}-kali"
    template: kali-x64-desktop-template
    vlan: 10
    ip_last_octet: 99
    ram_gb: 4
    cpus: 4
    linux: true
    testing:
      snapshot: false
      block_internet: false       
EOF

# Set up Ludus range with the configured VMs
ludus range config set -f config.yml
ludus range deploy

# Function to ensure deployment success
check_status() {
    status=$(ludus range status | grep "SUCCESS")
    [ -z "$status" ] && return 1 || return 0
}

# Wait until deployment is successful
while ! check_status; do
    echo "The magic circle is forming... Lab deployment is in progress. Hold tight!"
    sleep 60
done

echo "The spells have been cast, and the lab is ready for enchantment!"

# Prepare the lab environment further
python3 -m pip install ansible-core pywinrm
git clone https://github.com/Orange-Cyberdefense/GOAD
cd GOAD/ansible || exit

# Configure inventory for Ansible
cat <<EOF > inventory.yml
# Cyber Nexus - A gathering place for digital warriors
[default]
dc01 ansible_host=10.RANGENUMBER.10.30 dns_domain=dc01 dns_domain=dc02 dict_key=dc01
dc02 ansible_host=10.RANGENUMBER.10.31 dns_domain=dc02 dict_key=dc02
srv01 ansible_host=10.RANGENUMBER.10.32 dns_domain=dc02 dict_key=srv01
srv02 ansible_host=10.RANGENUMBER.10.33 dns_domain=dc02 dict_key=srv02
srv03 ansible_host=10.RANGENUMBER.10.34 dns_domain=dc02 dict_key=srv03

[all:vars]
domain_name=NHA
force_dns_server=yes
dns_server=10.RANGENUMBER.10.254
two_adapters=no
nat_adapter=Ethernet
domain_adapter=Ethernet
ansible_user=localuser
ansible_password=password
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore
ansible_winrm_operation_timeout_sec=400
ansible_winrm_read_timeout_sec=500
enable_http_proxy=no
ad_http_proxy=http://x.x.x.x:xxxx
ad_https_proxy=http://x.x.x.x:xxxx
EOF

# Install required Ansible roles
ansible-galaxy install -r requirements.yml

# Update inventory file with Ludus range information
export RANGENUMBER=$(ludus range list --json | jq '.rangeNumber')
sed -i "s/RANGENUMBER/$RANGENUMBER/g" inventory.yml

# Set up environment variables for Ansible
export ANSIBLE_INVENTORY=inventory.yml
export ANSIBLE_COMMAND="ansible-playbook -i ../ad/NHA/data/inventory -i $ANSIBLE_INVENTORY"
export LAB="NHA"

# Begin the magical provisioning process
../scripts/provisionning.sh

echo "The lab has been summoned into existence. Let the digital adventures begin!"
