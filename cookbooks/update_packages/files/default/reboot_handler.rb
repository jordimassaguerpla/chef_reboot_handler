require 'chef/log'

module AAAA
  class RebootHandler < Chef::Handler
    def initialize(process="ping")
      @process = process
    end

    def installed_kernel
      rpm_cmd = Mixlib::ShellOut.new("rpm --query kernel-default")
      rpm_cmd.run_command
      rpm_cmd.error!
      k = rpm_cmd.stdout.chomp
      matching = k.match(/\Akernel-default-([\d]+\.[\d]+\.[\d]+-[\d]+\.[\d]+).*\z/)
      if matching.nil? || matching.length != 2
        Chef::Log.error "can't parse installed kernel: #{k}"
        return nil
      end
      matching[1]
    end

    def running_kernel
      k = run_status.node[:kernel][:release]
      matching = k.match(/\A([\d]+\.[\d]+\.[\d]+-[\d]+\.[\d]+).*\z/)
      if matching.nil? || matching.length != 2
        Chef::Log.error "can't parse running kernel: #{k}"
        return nil
      end
      matching[1]
    end

    def is_process_running? name
      system("ps -C #{name}")
      $?.exitstatus == 0
    end

    def need_reboot?
      k1 = installed_kernel
      k2 = running_kernel
      Chef::Log.info "Recently installed kernel: #{k1}"
      Chef::Log.info "Running kernel: #{k2}"
      k1 && k2 && k1 != k2
    end

    def acquire_mutex name
      mutex = Chef::DataBagItem.load("mutex","need_reboot")
      # TODO: if it does not exist, create it
      # see https://github.com/websterclay/chef-dominodes/blob/master/libraries/dominodes.rb
      return nil if (mutex["node_name"] && mutex["node_name"] != name)
      return mutex if (mutex["node_name"] && mutex["node_name"] == name)
      mutex["node_name"] = name 
      mutex.save
      # now reload the data to confirm no one else has clobbered it
      mutex = Chef::DataBagItem.load("mutex","need_reboot")
      return nil if (mutex["node_name"] && mutex["node_name"] != name)
      return nil if !mutex["node_name"]
      mutex
    end

   def release_mutex mutex, name
     mutex = Chef::DataBagItem.load("mutex","need_reboot")
     if mutex["node_name"] != name
       Chef::Log.error("chef_reboot_handler: Hey, this recipe is trying to release a mutex that is not owned by this client. This client is named #{name} and the mutex is owned by #{mutex["node_name"]}")
       Chef::Log.error("chef_reboot_handler: It may be that has been stolen.")
       return
     end
     mutex.delete("node_name")
     mutex.save
   end

   def disable_worker name
     Chef::Log.info("chef_reboot_handler: call API to disable worker #{name} (faked)")
   end

   def enable_worker name
     Chef::Log.info("chef_reboot_handler: call API to enable worker #{name} (faked)")
   end

   def is_worker_enabled? name
     Chef::Log.info("chef_reboot_handler: The worker is enabled (fake)")
     return true
   end

   def needs_enabling? name
      needs_enabling = Chef::DataBagItem.load("node_status","needs_enabling")
      # TODO: create it if it does not exist
      needs_enabling[name]
   end

   def set_needs_enabling name
      needs_enabling = Chef::DataBagItem.load("node_status","needs_enabling")
      # TODO: create it if it does not exist
      needs_enabling[name] = true
      needs_enabling.save
   end

   def remove_needs_enabling name
      needs_enabling = Chef::DataBagItem.load("node_status","needs_enabling")
      # TODO: create it if it does not exist
      needs_enabling.delete name
      needs_enabling.save
   end

   def report
      if need_reboot?
        Chef::Log.info("chef_reboot_handler: Hey I need to reboot")
        mutex = acquire_mutex run_status.node.name
        if !mutex.nil?
          Chef::Log.info("chef_reboot_handler: Mutex acquired")
          disable_worker run_status.node.name
          if !is_process_running? @process
            Chef::Log.info("chef_reboot_handler: #{@process} not running")
            Chef::Log.info("chef_reboot_handler: set this worker should be enabled in the future")
            set_needs_enabling run_status.node.name
            release_mutex mutex, run_status.node.name
            Chef::Log.info("chef_reboot_handler: Mutex released")
            Chef::Log.info("chef_reboot_handler: Machine will reboot in one minute...")
            Mixlib::ShellOut.new("/sbin/shutdown -r +1 &").run_command
          else
           Chef::Log.info("chef_reboot_handler: #{@process} is running, thus no reboot for now")
          end #if !is_process_running?
        end #if !mutex
      else
        if needs_enabling? run_status.node.name
          Chef::Log.info("chef_reboot_handler: enabling worker")
          enable_worker run_status.node.name
          remove_needs_enabling run_status.node.name
        end
      end # if need_reboot
    end # def report

  end # class

end # module
