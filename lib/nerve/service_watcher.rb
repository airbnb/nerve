require_relative './service_watcher/tcp'
require_relative './service_watcher/http'

module Nerve
  class ServiceWatcher
    include Utils
    include Logging

    def initialize(opts={})
      log.debug "creating service watcher object"
      %w{port host zk_path instance_id name}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless opts[required]
        instance_variable_set("@#{required}", opts[required])
      end

      @zk_key = "#{@instance_id}_#{@name}"
      @check_interval = opts['check_interval'] || 0.5

      # instantiate the checks for this watcher
      @service_checks = []
      opts['checks'] ||= []
      opts['checks'].each do |check|
        check['type'] ||= "undefined"
        begin
          service_check_class = ServiceCheck::CHECKS[check['type']]
        rescue
          raise ArgumentError, "invalid service check type #{check['type']}; valid types: #{ServiceCheck::CHECKS.keys.join(',')}"
        end

        check['host'] ||= @host
        check['port'] ||= @port
        check['name'] ||= "#{@name}_#{check['type']}_#{check['port']}"
        @service_checks << service_check_class.new(check)
      end

      log.debug "created service watcher for #{@name} with #{@service_checks.size} checks"
    end

    def run()
      log.info "Starting to watch service #{@name}"

      # create zookeeper connection
      @reporter = Reporter.new({
                           'path' => @zk_path,
                           'key' => @zk_key,
                           'data' => {'host' => @host, 'port' => @port},
                         })
      log.debug "created zk handle for service #{@name}"

      # the main loop
      was_up = false
      log.debug "about to start main loop"
      until $EXIT
        begin
          log.debug "loop service watcher #{@name}"

          @reporter.ping?

          # what is the status of the service?
          is_up = check?
          log.debug "current service status for #{@name} is #{is_up.inspect}"
          if is_up != was_up
            if is_up
              @reporter.report_up
              log.info "service #{@name} is now up"
            else
              @reporter.report_down
              log.warn "service #{@name} is now down"
            end
            was_up = is_up
          end

          # wait to run more checks
          sleep @check_interval
        rescue Object => o
          log.error "hit an error, setting exit: "
          log.error o.inspect
          log.error o.backtrace
          $EXIT = true
        end
      end
      log.debug "exited loop"
    end

    def check?
      @service_checks.each do |check|
        return false unless check.up?
      end
      return true
    end

  end
end
