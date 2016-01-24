require 'nerve/service_watcher/tcp'
require 'nerve/service_watcher/http'
require 'nerve/service_watcher/rabbitmq'

module Nerve
  class ServiceWatcher
    include Utils
    include Logging

    def initialize(service={})
      log.debug "nerve: creating service watcher object"

      # So this thread can be interrupted
      Thread.current[:finish] = false

      # check that we have all of the required arguments
      %w{name instance_id host port}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless service[required]
      end

      @name = service['name']

      # configure the reporter, which we use for talking to zookeeper
      @reporter = Reporter.new_from_service(service)

      # instantiate the checks for this service
      @service_checks = []
      service['checks'] ||= []
      service['checks'].each do |check|
        # checks inherit attributes from the service overall
        check['host'] ||= service['host']
        check['port'] ||= service['port']

        # generate a nice readable name for each check
        check['name'] ||= "#{@name} #{check['type']}-#{check['host']}:#{check['port']}"

        # make sure a type is set
        check['type'] ||= "undefined"

        # require a 3rd-party module if necessary for external checkers
        unless ServiceCheck::CHECKS[check['type']]
          m = check['module'] ? check['module'] : "nerve-watcher-#{check['type']}"
          require m
        end

        # instantiate the check object
        service_check_class = ServiceCheck::CHECKS[check['type']]
        if service_check_class.nil?
          raise ArgumentError,
            "invalid service check type #{check['type']}; valid types: #{ServiceCheck::CHECKS.keys.join(',')}"
        end

        # save the check object
        @service_checks << service_check_class.new(check)
      end

      # how often do we initiate service checks?
      @check_interval = service['check_interval'] || 0.5

      # force an initial report on startup
      @was_up = nil

      log.debug "nerve: created service watcher for #{@name} with #{@service_checks.size} checks"
    end

    def run()
      log.info "nerve: starting service watch #{@name}"

      @reporter.start()

      until $EXIT or Thread.current[:finish]
        check_and_report

        # wait to run more checks but make sure to exit if $EXIT
        # we avoid sleeping for the entire check interval at once
        # so that nerve can exit promptly if required
        nap_time = @check_interval
        while nap_time > 0
          break if $EXIT
          sleep [nap_time, 1].min
          nap_time -= 1
        end
      end
    rescue StandardError => e
      log.error "nerve: error in service watcher #{@name}: #{e.inspect}"
      raise e
    ensure
      log.info "nerve: ending service watch #{@name}"
      @reporter.stop
    end

    def check_and_report
      if !@reporter.ping?
        # If the reporter can't ping, then we do not know the status
        # and must force a new report.
        @was_up = nil
      end

      # what is the status of the service?
      is_up = check?
      log.debug "nerve: current service status for #{@name} is #{is_up.inspect}"

      if is_up != @was_up
        if is_up
          @reporter.report_up
          log.info "nerve: service #{@name} is now up"
        else
          @reporter.report_down
          log.warn "nerve: service #{@name} is now down"
        end
        @was_up = is_up
      end
    end

    def check?
      @service_checks.each do |check|
        return false unless check.up?
      end
      return true
    end
  end
end
