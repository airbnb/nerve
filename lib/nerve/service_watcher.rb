require 'nerve/service_watcher/tcp'
require 'nerve/service_watcher/http'
require 'nerve/service_watcher/rabbitmq'
require_relative './reporter/zookeeper'

module Nerve
  class ServiceWatcher
    include Utils
    include Logging

    @reporters = {
      'zookeeper' => ZookeeperReporter
    }

    def self.add_reporter(key, klass)
      @reporters[key] = klass
    end

    def initialize(service={})
      log.debug "nerve: creating service watcher object"

      # check that we have all of the required arguments
      %w{name instance_id host port}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless service[required]
      end

      @name = service['name']

      # default to zk
      meth = service['method'] || 'zookeeper'

      unless @reporters[meth]
        if m = service['module']
          require m
        end
      end

      @reporter = @reporters[meth].new(
                                       service.merge(
                                                     'key' => "#{service['instance_id']}_#{@name}"
                                                     )
                                       )
      # instantiate the checks for this service
      @service_checks = []
      service['checks'] ||= []
      service['checks'].each do |check|
        check['type'] ||= "undefined"
        begin
          service_check_class = ServiceCheck::CHECKS[check['type']]
        rescue
          raise ArgumentError,
            "invalid service check type #{check['type']}; valid types: #{ServiceCheck::CHECKS.keys.join(',')}"
        end

        check['host'] ||= service['host']
        check['port'] ||= service['port']
        check['name'] ||= "#{@name} #{check['type']}-#{check['host']}:#{check['port']}"
        @service_checks << service_check_class.new(check)
      end

      # how often do we initiate service checks?
      @check_interval = service['check_interval'] || 0.5

      log.debug "nerve: created service watcher for #{@name} with #{@service_checks.size} checks"
    end

    def run()
      log.info "nerve: starting service watch #{@name}"

      # begin by reporting down
      @reporter.start()
      @reporter.report_down
      was_up = false

      until $EXIT
        @reporter.ping?

        # what is the status of the service?
        is_up = check?
        log.debug "nerve: current service status for #{@name} is #{is_up.inspect}"

        if is_up != was_up
          if is_up
            @reporter.report_up
            log.info "nerve: service #{@name} is now up"
          else
            @reporter.report_down
            log.warn "nerve: service #{@name} is now down"
          end
          was_up = is_up
        end

        # wait to run more checks
        sleep @check_interval
      end
    rescue StandardError => e
      log.error "nerve: error in service watcher #{@name}: #{e}"
      raise e
    ensure
      log.info "nerve: ending service watch #{@name}"
      $EXIT = true
    end

    def check?
      @service_checks.each do |check|
        return false unless check.up?
      end
      return true
    end
  end
end
