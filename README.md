# Tuleap-ops

Install Tuleap onto Kubernetes or VM with Ansible.

## Setup
Everything is done using the `tulsible` wrapper. It will install all dependencies and wrap the ansible-playbook command.
This includes the `eyaml` filter plugin for eventually decryting encrypted secrets. Usage: 
`"{{ encrypted_variable | eyaml(eyaml_keys) }}"`. Variables are encrypted by editing the file with `eyaml edit filename.yml`

## Ansible Roles
We are working on three main roles

### tuleap-namespace
This is the (attempt) to install Tuleap on OpenShift. It does not work yet because we have issues in figuring out how to make Tuleap work on a Docker container. See `localcompose/Readme.md` directory for more details.

### chrooted_centos
The idea is to install a Centos7 as a chrooted environment on a RHEL 8 VM to serve as a base for Tuleap installation. This is on hold for the moment because we decided to start with the simpler solution of going directly to a Centos 7 VM.
The main difficulty is being able to run ansible on a remote chroot. This can be done by configuring ssh to chroot under given conditions. The easiest is to let ssh listen on a second port and chroot any connection on that port. In order to avoid firewall issues, I have started by applying the same trick but on an user (`ansible`) but introduces the extra issue of configuring sudo on the chroot environment which is not trivial. 

### Tuleap-vm
This instals Tuleap on a Centos7 base. We cannot use the role provided by Tuleap as it is tuned for RHEL/Centos 6.
It closely follow the [official installation guide][install]





[install]: https://docs.tuleap.org/installation-guide/full-installation.html 