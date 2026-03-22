[nginx]
%{ for instance in nginx_instances ~}
${instance.name} ansible_host=${instance.network_interface[0].nat_ip_address} ansible_user=${ssh_user} internal_ip=${instance.network_interface[0].ip_address}
%{ endfor ~}

[backend]
%{ for instance in backend_instances ~}
${instance.name} ansible_host=${instance.network_interface[0].nat_ip_address} ansible_user=${ssh_user} internal_ip=${instance.network_interface[0].ip_address}
%{ endfor ~}

[database]
${database_instance.name} ansible_host=${database_instance.network_interface[0].nat_ip_address} ansible_user=${ssh_user} internal_ip=${database_instance.network_interface[0].ip_address}

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
