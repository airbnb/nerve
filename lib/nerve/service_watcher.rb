require_relative './service_watcher/tcp'
require_relative './service_watcher/http'

module Nerve
  class ServiceWatcher
    include Base
    include Logging

    def initialize(opts={})
      log.debug "creating service watcher object"
      %w{port host zk_path instance_id name}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless opts[required]
        instance_variable_set("@#{required}", opts[required])
      end

      # optional parameters control how checks are made
      @threshold = opts['failure_threshold'] || 2
      @check_interval = opts['check_interval'] || 0.5

      # instantiate the checks for this watcher
      @service_checks = []
      opts['checks'] ||= {}
      opts['checks'].each do |type,params|
        begin
          service_check_class = ServiceCheck::CHECKS[type]
        rescue
          raise ArgumentError, "invalid service check type #{type}; valid types: #{ServiceCheck::CHECKS.keys.join(',')}"
        end

        @service_checks << service_check_class.new(params.merge({'port' => @port, 'host' => @host}))
      end

      log.debug "created service watcher for #{@name} with #{@service_checks.size} checks"
    end

    def run()
      log.info "Starting to watch service #{@name}"

      # create zookeeper connection
      @zk = ZKHelper.new({
                           'path' => @zk_path,
                           'key' => @instance_id,
                           'data' => {'host' => @host, 'port' => @port},
                         })
      log.debug "created Zk handle for service #{@name}"

      # run the initial check
      log.info "running initial check for service #{@name}"
      ring_buffer = RingBuffer.new(@threshold)
      if check?
        @threshold.times { ring_buffer.push true }
        log.info "initial check succeeded, bring up service #{@name}"
      else
        @threshold.times { ring_buffer.push false }
        log.info "initial check failed, bringing down service #{@name}"
      end

      # the main loop
      was_up = false
      log.debug "about to start main loop"
      until $EXIT
        begin
          log.debug "loop service watcher #{@name}"

          @zk.ping?

          # what is the status of the service?
          is_up = ring_buffer.include?(false) ? false : true
          log.debug "current service status for #{@name} is #{is_up.inspect}"
          if is_up != was_up
            if is_up
              @zk.report_up
              log.info "service #{@name} is now up"
            else
              @zk.report_down
              log.warn "service #{@name} is now down"
            end
            was_up = is_up
          end

          # wait to run more checks
          sleep @check_interval
          ring_buffer.push check?
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
        check_status = check.check?
        return false unless check_status
      end
      return true
    end

  end
end
