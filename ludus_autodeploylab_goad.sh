#!/bin/bash

# Create goadconfig.yml file with provided content
cat <<EOF > goadconfig.yml
ludus:
  - vm_name: "{{ range_id }}-GOAD-DC01"
    hostname: "{{ range_id }}-DC01"
    template: win2019-server-x64-template
    vlan: 10
    ip_last_octet: 10
    ram_gb: 4
    cpus: 2
    windows:
      sysprep: true
  - vm_name: "{{ range_id }}-GOAD-DC02"
    hostname: "{{ range_id }}-DC02"
    template: win2019-server-x64-template
    vlan: 10
    ip_last_octet: 11
    ram_gb: 4
    cpus: 2
    windows:
      sysprep: true
  - vm_name: "{{ range_id }}-GOAD-DC03"
    hostname: "{{ range_id }}-DC03"
    template: win2019-server-x64-template
    vlan: 10
    ip_last_octet: 12
    ram_gb: 8
    cpus: 2
    windows:
      sysprep: true
  - vm_name: "{{ range_id }}-GOAD-SRV02"
    hostname: "{{ range_id }}-SRV02"
    template: win2019-server-x64-template
    vlan: 10
    ip_last_octet: 22
    ram_gb: 4
    cpus: 2
    windows:
      sysprep: true
  - vm_name: "{{ range_id }}-GOAD-SRV03"
    hostname: "{{ range_id }}-SRV03"
    template: win2019-server-x64-template
    vlan: 10
    ip_last_octet: 23
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
    cpus: 2
    linux: true
    testing:
      snapshot: false
      block_internet: false
EOF

# Set the config using ludus range command
ludus range config set -f goadconfig.yml

# Deploy the range
ludus range deploy

# Function to check deployment status
check_status() {
    status=$(ludus range status | grep "SUCCESS")
    if [ -z "$status" ]; then
        return 1
    else
        return 0
    fi
}

# Wait until deployment is successful
while ! check_status; do
    echo "Deployment is not yet successful. Waiting..."
    sleep 60  # Adjust sleep time as needed
done

# Once deployment is successful, proceed with additional steps
echo "Deployment is successful. Updating the servers..."

# Get the userID
userID=$(ludus range list --json | jq -r '.userID')

# Update the command with the extracted userID
updatesrv02="ludus testing update -n ${userID}-GOAD-SRV02"

# Execute the updated command
$updatesrv02

# Check logs continuously until the desired output is obtained
echo "Waiting for updates to be installed..."
while true; do
    logs=$(ludus range logs)
    echo "$logs" | grep -i "PLAY RECAP" && break
    sleep 10  # Adjust sleep time as needed
done

# Continue with other commands after updates are complete
echo "Updates are complete. Continuing with other commands..."

# Install required Python packages
python3 -m pip install ansible-core
python3 -m pip install pywinrm

# Clone GOAD repository
git clone https://github.com/Orange-Cyberdefense/GOAD

# Change directory to GOAD/ansible
cd GOAD/ansible || exit

# Create inventory.yml file with provided content
cat <<EOF > inventory.yml
[default]
; Note: ansible_host *MUST* be an IPv4 address or setting things like DNS
; servers will break.
; ------------------------------------------------
; sevenkingdoms.local
; ------------------------------------------------
dc01 ansible_host=10.RANGENUMBER.10.10 dns_domain=dc01 dict_key=dc01
;ws01 ansible_host=10.RANGENUMBER.10.30 dns_domain=dc01 dict_key=ws01
; ------------------------------------------------
; north.sevenkingdoms.local
; ------------------------------------------------
dc02 ansible_host=10.RANGENUMBER.10.11 dns_domain=dc01 dict_key=dc02
srv02 ansible_host=10.RANGENUMBER.10.22 dns_domain=dc02 dict_key=srv02
; ------------------------------------------------
; essos.local
; ------------------------------------------------
dc03 ansible_host=10.RANGENUMBER.10.12 dns_domain=dc03 dict_key=dc03
srv03 ansible_host=10.RANGENUMBER.10.23 dns_domain=dc03 dict_key=srv03

[all:vars]
; domain_name : folder inside ad/
domain_name=GOAD

force_dns_server=yes
dns_server=10.RANGENUMBER.10.254

two_adapters=no
; adapter created by vagrant and virtualbox (comment if you use vmware)
nat_adapter=Ethernet
domain_adapter=Ethernet

; adapter created by vagrant and vmware (uncomment if you use vmware)
; nat_adapter=Ethernet0
; domain_adapter=Ethernet1

; winrm connection (windows)
ansible_user=localuser
ansible_password=password
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore
ansible_winrm_operation_timeout_sec=400
ansible_winrm_read_timeout_sec=500

; proxy settings (the lab need internet for some install, if you are behind a proxy you should set the proxy here)
enable_http_proxy=no
ad_http_proxy=http://x.x.x.x:xxxx
ad_https_proxy=http://x.x.x.x:xxxx
EOF

# Clone GOAD repository and install Ansible roles
ansible-galaxy install -r requirements.yml

# Update inventory file with ludus range information
export RANGENUMBER=$(ludus range list --json | jq '.rangeNumber')
sed -i "s/RANGENUMBER/$RANGENUMBER/g" inventory.yml

# Set up environment variables for Ansible
export ANSIBLE_INVENTORY=inventory.yml
export ANSIBLE_COMMAND="ansible-playbook -i ../ad/GOAD/data/inventory -i $ANSIBLE_INVENTORY"
export LAB="GOAD"

# Run provisioning script
../scripts/provisionning.sh
