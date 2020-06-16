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

## Configuration

### Email
E-mail use the local smtp server (postfix). The only issue is that, by default
postfix is using all protocols and fails to start on IPv4-only machine like ours.

### LDAP
Configuration for the LDAP plugin is in 
`/etc/tuleap/plugins/ldap/etc/ldap.inc`. Relevant parameters for EPFL: 

```
server: ldap.epfl.ch
basedn: ou=idev-fsd,ou=si-idev,ou=si,o=epfl,c=ch
```
and the fact that the _unique idendifier_ is not `employeeNumber` but `uniqueidentifier`.

Since the same `uid` can be found in several branches of the LDAP tree, a tiny patch was introduced in `/usr/share/tuleap/plugins/ldap/include/LDAP.class.php`. **NEEDS TESTING!**

After installing the ldap plugin, `tuleap-php-fpm` service needs to be restarted.
The annoying thing is that I cannot find a way to activate the plugins
programmaticaly. Therefore, after the first ansible run, the admin must activate
the plugin manually. At that point LDAP login will not work because ldap config
will have been overwritten. Therefore, in order for it to work, a second 
ansible run is necessary.

### GIT
In principle, once installed and enabled the git plugin, repositories can be 
created in projects. It is not straightforward to install though and I doubt
it will work (see below).

There is no mechanism for cloning nor periodically 
polling remote repositories. Therefore, Tuleap repos will have to be used as 
extra remote where to push manually unless we add a cron job ourselves.

#### Git pluging installation

The official rpm package for RHEL have several issues:
 - a broken dependency on `sclo-git212-git` which needs an extra 
   _CentOS community_ repository. It can be added to RHEL system;
 - the plugin depends on gitolite3 and it is not clear if further configuration
   is needed for it to work.
 - there are various references to _codendi_ of which I found no traces except
   for a very old (2009) [system][codendi] for application lifecycle 
   management. 
   * file `/etc/codendi/plugins/git/etc/config.inc` mentioned in the plugin
     configuration page is absent;
   * the plugin is supposed to create a `/var/lib/gitolite/.ssh/authorized_keys` 
     file by mean of the 
     `/usr/share/tuleap/plugins/git/bin/recreate_authorized_keys.sh` script 
     which makes reference to the phantom _codendi_ project and is written for 
     CentOS v. 6 and not suited for RHEL/CentOS 7 series. 

Filed an [issue]:[issue1]. Let's see what happens.

In the mean time, I have created a CentOS vagrant image VM to test with the 
officially supported OS with an easy way to revert back. 
There the keys are created and copied. Therefore, for the moment I have done the 
same on the RHEL machine just to see if things start to work. Next issue is 
the fact that git repos is queued for creation and never actually created
 > The repository is in queue for creation. Please check back here in a few minutes

After resetting the machine to base config (via snapshot and `yum undo`s), I have
done the installation once more by hand. This time git works. I suspect that 
the configuration script failed for some other reason and could not complete
the installation. Now the idea is to get a brand new machine and retry with 
ansible from scratch (this time I will create a snapshot as **first thing**).


[install]: https://docs.tuleap.org/installation-guide/full-installation.html 
[codendi]: http://codendi.org/
[tracker]: https://tuleap.net/plugins/tracker
[issue1]: https://tuleap.net/plugins/tracker/?aid=14963&group_id=101
