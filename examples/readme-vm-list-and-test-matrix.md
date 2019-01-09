[VM List]
1. Support multiple labs in different sections. Each section starts with keyword "LAB"
    for example: "LAB 1"

2. In each lab, you can define multiple VMs. The accepted formats for vm line are:
    a. "username:vm_role:vm_ip"
    b. "vm_role:vm_ip" (then in this case, scripts will try to use default username, for exmaple, "betty", as defined in the scripts)

3. If the VM line is defined with other format, for example, only one element, or more then 3 elements, scripts will throw error and exit.

[VM Test Matrix]
1. Only support one format:
    a. "source_vm_role - destination_vm_role"
