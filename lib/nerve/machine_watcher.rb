require_relative './machine_watcher/cpuidle'

module Nerve
  class MachineWatcher
    include Utils
    include Logging

    def initialize(opts={})
      log.debug 'creating machine watcher'

      # required inputs
      %w{metric zk_path instance_id}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
        instance_variable_set("@#{required}",opts[required])
        log.debug "set @#{required} to #{opts[required]}"
      end

      begin
        machine_check_class = MachineCheck::CHECKS[@metric]
      rescue
        raise ArgumentError,
          "invalid machine check metric #{@metric}; valid checks: #{MachineCheck::CHECKS.keys.join(',')}"
      end

      @machine_check = machine_check_class.new(opts)
    end

    def run
      log.info 'watching machine'
      @reporter = Reporter.new({
          'path' => @zk_path,
          'key' => @instance_id,
          'data' => {'vote'=>0},
        })
      @reporter.report_up
      previous_vote = 0
      log.info "starting machine watch. vote is 0"

      until $EXIT
        begin
          @reporter.ping?
          @machine_check.poll
          vote = @machine_check.vote
          log.debug "current vote is #{vote}"
          if vote != previous_vote
            @reporter.update_data({'vote'=>vote})
            previous_vote = vote
            log.info "vote changed to #{vote}"
          end
          sleep 1
        rescue Object => o
          log.error "hit an error, setting exit: "
          log.error o.inspect
          log.error o.backtrace
          $EXIT = true
        end
      end
      log.info "ending machine watch"
    end
  end
end
