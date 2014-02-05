require 'logger'
require 'json'
require 'timeout'

require 'nerve/version'
require 'nerve/utils'
require 'nerve/log'
require 'nerve/ring_buffer'
require 'nerve/reporter'
require 'nerve/service_watcher'

module Nerve
  class Nerve

    include Logging

    def initialize(opts={})
      log.info 'nerve: starting up!'

      # set global variable for exit signal
      $EXIT = false

      # required options
      log.debug 'nerve: checking for required inputs'
      %w{instance_id services}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
      end

      @instance_id = opts['instance_id']
      @services = opts['services']
      @watchers = {}

      log.debug 'nerve: completed init'
    end

    def run
      log.info 'nerve: starting run'

      @services.each do |name, config|
        launch_watcher(name, config)
      end

      begin
        sleep
      rescue StandardError => e
        log.error 'nerve: encountered unexpected exception #{e.inspect} in main thread'
        raise e
      ensure
        $EXIT = true
        log.warn 'nerve: reaping all watchers'
        @watchers.each do |name, watcher_thread|
          reap_watcher(name)
        end
      end

      log.info 'nerve: exiting'
    ensure
      $EXIT = true
    end

    def launch_watcher(name, config)
      log.debug "nerve: launching service watcher #{name}"
      watcher = ServiceWatcher.new(config.merge({'instance_id' => @instance_id, 'name' => name}))
      @watchers[name] = Thread.new{watcher.run}
    end

    def reap_watcher(name)
      watcher_thread = @watchers.delete(name)
      watcher_thread.join()
    end
  end
end
