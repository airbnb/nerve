module Nerve
  class MachineWatcher
    def initialize(opts={})
      %w{metric zk_path instance_id}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
        instance_variable_set("@#{required}",opts[required])
      end

      machine_check_class_name = @metric.split('_').map(&:capitalize).join
      machine_check_class_name << 'MachineCheck'
      begin
        machine_check_class = MachineCheck.const_get(machine_check_class_name)
      rescue
        raise ArgumentError, "machine check #{@metric} is not valid"
      end
      
      @machine_check = machine_check_class.new(opts)
      @exiting = false
      @previous_vote = nil
    end

    def run
      @zk = ZKHelper.new(@zk_path)
      @zk.create_ephemeral_node(@instance_id,{vote: 0})
      
      unless defined?(EXIT)
        begin
          @zk.ping?
          vote = @machine_check.vote
          if vote != @previous_vote
            @zk.update(@instance_id,{vote: vote})
          end
          
          @previous_vote = vote
          sleep 1
        ensure
          EXIT = true
        end
      end
      
    end
  end
end
