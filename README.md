chef_reboot_handler
===================

This is a chef handler that can be used for rebooting worker nodes in an
ordered way when there is a kernel update.

The code includes also a recipe for updating a node with zypper which
installs the handler.

The basic idea is that if you have multiple workers running jobs, you need
to reboot only one node at a time and only when that node has finished all
his jobs.

It assumes that you have API calls for disabling and enabling the worker so
that no more jobs get into its queue and also an API call to check if the
worker is enabled.

In the reboot_handler all these calls are faked, but you can overwrite them
with yours.

It assumes you use a zypper based system for updating your system, thus a
SUSE linux.

You should have the chef_handler installed
(https://github.com/opscode-cookbooks/chef_handler).

It is based on the dominodes implementation of a mutex
(see: https://github.com/websterclay/chef-dominodes/blob/master/libraries/dominodes.rb)

The mutex is a databag item in the chef server.

If you look at the implementation, you will realize that this is not a real
mutex. I mean there is the possibility that 2 workers acquire the mutex.
Thus, if you use this handler, you have to know that some times more than one
worker will reboot at the same time.

However, if you can live with that, you have a very simple implementation.

Otherwise, you can try to implement the mutex with Apache Zookeeper.

