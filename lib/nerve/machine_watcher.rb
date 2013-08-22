require_relative './machine_watcher/cpuidle'
require_relative './machine_watcher/trivial'

module Nerve
  class MachineWatcher
    include Utils
    include Logging

    def initialize(opts={})
      log.debug 'nerve: creating machine watcher'

      # required inputs
      %w{metric zk_path instance_id}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
        instance_variable_set("@#{required}",opts[required])
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
      log.info 'nerve: starting machine watch'

      @reporter = Reporter.new({
          'path' => @zk_path,
          'key' => @instance_id,
          'data' => {'vote'=>0},
        })
      @reporter.report_up

      previous_vote = 0

      until $EXIT
        @reporter.ping?

        @machine_check.poll
        vote = @machine_check.vote
        log.debug "nerve: current vote is #{vote}"

        if vote != previous_vote
          @reporter.update_data({'vote'=>vote})
          previous_vote = vote
          log.info "nerve: vote changed to #{vote}"
        end

        sleep 1
      end
    rescue StandardError => e
      log.error "nerve: error in machine watcher: #{e}"
      raise e
    ensure
      log.info 'nerve: ending machine watch'
      $EXIT = true
    end
  end
end
