module Nerve
  class MachineWatcher
    include Logging
    def initialize(opts={})
      log.debug 'creating machine watcher'
      # required inputs
      %w{metric zk_path instance_id}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
        instance_variable_set("@#{required}",opts[required])
        log.debug "set @#{required} to #{opts[required]}"
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
      log.info 'watching machine'
      @zk = ZKHelper.new(@zk_path)
      @zk.create_ephemeral_node(@instance_id,{'vote'=>0})

      until defined?(EXIT)
        begin
          @zk.ping?
          vote = @machine_check.vote
          if vote != @previous_vote
            @zk.update(@instance_id,{vote: vote})
          end

          @previous_vote = vote
          sleep 1
        rescue Object => o
          log.error "hit an error, setting exit: "
          log.error o.inspect
          log.error o.backtrace
          self.class.const_set(:EXIT,true)
        end
      end
      log.info "ending machine watch"
    end
  end
end
