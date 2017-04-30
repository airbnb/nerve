require 'nerve/service_watcher/tcp'
require 'nerve/service_watcher/http'
require 'nerve/service_watcher/rabbitmq'

module Nerve
  class ServiceWatcher
    include Utils
    include Logging

    attr_reader :was_up

    def initialize(service={})
      log.debug "nerve: creating service watcher object"

      # check that we have all of the required arguments
      %w{name instance_id host port}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless service[required]
      end

      @name = service['name']

      # configure the reporter, which we use for reporting status to the registry
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

      # when this watcher is started it will store the
      # thread here
      @run_thread = nil
      @should_finish = false

      log.debug "nerve: created service watcher for #{@name} with #{@service_checks.size} checks"
    end

    def start()
      unless @run_thread
        @run_thread = Thread.new { self.run() }
      else
        log.error "nerve: tried to double start a watcher"
      end
    end

    def stop()
      log.info "nerve: stopping service watch #{@name}"
      @should_finish = true
      return true if @run_thread.nil?

      unclean_shutdown = @run_thread.join(10).nil?
      if unclean_shutdown
        log.error "nerve: unclean shutdown of #{@name}, killing thread"
        Thread.kill(@run_thread)
      end
      @run_thread = nil
      !unclean_shutdown
    end

    def alive?()
      !@run_thread.nil? && @run_thread.alive?
    end

    def run()
      log.info "nerve: starting service watch #{@name}"
      @reporter.start()

      until watcher_should_exit?
        check_and_report

        # wait to run more checks but make sure to exit if $EXIT
        # we avoid sleeping for the entire check interval at once
        # so that nerve can exit promptly if required
        responsive_sleep (@check_interval) { watcher_should_exit? }
      end
    rescue StandardError => e
      log.error "nerve: error in service watcher #{@name}: #{e.inspect}"
      raise e
    ensure
      log.info "nerve: stopping reporter for #{@name}"
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

    private
    def watcher_should_exit?
      $EXIT || @should_finish
    end

  end
end
