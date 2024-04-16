#!/bin/bash

# Summoning the Seven Kingdoms with GOAD (Game of Active Directory)

# Creating goadconfig.yml file with noble house assignments
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

# Setting up the battalions with ludus range command
ludus range config set -f goadconfig.yml

# Deploying the legions
ludus range deploy

# Function to consult the Red Priests for deployment status
check_status() {
    status=$(ludus range status | grep "SUCCESS")
    if [ -z "$status" ]; then
        return 1
    else
        return 0
    fi
}

# Waiting for ravens to return with news of successful deployment
while ! check_status; do
    echo "Deployment is not yet successful. Waiting..."
    sleep 60  # Adjust sleep time as needed
done

# Rejoice! The deployment has succeeded, let's update the lords of the servers

# Consulting the Maesters for the userID
userID=$(ludus range list --json | jq -r '.userID')

# Sending raven to update the noble server of House GOAD-SRV02
updatesrv02="ludus testing update -n ${userID}-GOAD-SRV02"
$updatesrv02

# Gazing into the flames, awaiting visions of successful updates
echo "Waiting for updates to be installed..."
while true; do
    logs=$(ludus range logs)
    echo "$logs" | grep -i "PLAY RECAP" && break
    sleep 120  # Adjust sleep time as needed
done

# The updates are complete! Continuing with other commands...

# Channeling the wisdom of the Maesters to install required spells (Python packages)
echo "Installing required spells (Python packages)..."
python3 -m pip install ansible-core
python3 -m pip install pywinrm

# Embarking on a journey to the lands of GOAD, accompanied by loyal bannermen
echo "Gathering the banners of GOAD..."
git clone https://github.com/Orange-Cyberdefense/GOAD

# Venturing into the halls of GOAD/ansible
cd GOAD/ansible || exit

# Crafting the sigils and banners of the noble houses in inventory.yml
cat <<EOF > inventory.yml
[default]
; Note: ansible_host *MUST* be an IPv4 address or setting things like DNS
; servers will break.
; ------------------------------------------------
; Winterfell
; ------------------------------------------------
dc01 ansible_host=10.RANGENUMBER.10.10 dns_domain=dc01 dict_key=dc01
; The Eyrie
; ------------------------------------------------
dc02 ansible_host=10.RANGENUMBER.10.11 dns_domain=dc01 dict_key=dc02
srv02 ansible_host=10.RANGENUMBER.10.22 dns_domain=dc02 dict_key=srv02
; Castle Black
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

# Unleashing the fury of Ansible, rallying the troops for provisioning
echo "Unleashing the fury of Ansible, rallying the troops for provisioning..."
ansible-galaxy install -r requirements.yml

# Updating the map with ludus range information
export RANGENUMBER=$(ludus range list --json | jq '.rangeNumber')
sed -i "s/RANGENUMBER/$RANGENUMBER/g" inventory.yml

# Preparing the battle plans with environment variables for Ansible
export ANSIBLE_INVENTORY=inventory.yml
export ANSIBLE_COMMAND="ansible-playbook -i ../ad/GOAD/data/inventory -i $ANSIBLE_INVENTORY"
export LAB="GOAD"

# Commencing the great journey with the provisioning script
echo "Commencing the great journey with the provisioning script..."
../scripts/provisionning.sh

# The saga continues... Valar Morghulis!
