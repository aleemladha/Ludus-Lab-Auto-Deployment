#!/bin/bash
# Made by Aleem Ladha @LadhaAleem
# Create config.yml file with provided content
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

# Set the config using ludus range command
ludus range config set -f config.yml

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
echo "Deployment is successful. Continuing with additional steps..."

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
; ninja.local
; ------------------------------------------------
dc01 ansible_host=10.RANGENUMBER.10.30 dns_domain=dc01 dns_domain=dc02 dict_key=dc01
dc02 ansible_host=10.RANGENUMBER.10.31 dns_domain=dc02 dict_key=dc02
srv01 ansible_host=10.RANGENUMBER.10.32 dns_domain=dc02 dict_key=srv01
srv02 ansible_host=10.RANGENUMBER.10.33 dns_domain=dc02 dict_key=srv02
srv03 ansible_host=10.RANGENUMBER.10.34 dns_domain=dc02 dict_key=srv03


[all:vars]
; domain_name : folder inside ad/
domain_name=NHA

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
export ANSIBLE_COMMAND="ansible-playbook -i ../ad/NHA/data/inventory -i $ANSIBLE_INVENTORY"
export LAB="NHA"

# Run provisioning script
../scripts/provisionning.sh
