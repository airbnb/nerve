require 'fileutils'
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
      @heartbeat_path = opts['heartbeat_path']
      @watchers = {}

      log.debug 'nerve: completed init'
    end

    def run
      log.info 'nerve: starting run'

      @services.each do |name, config|
        launch_watcher(name, config)
      end

      begin
        loop do
          # Check that watcher threads are still alive, auto-remediate if they
          # are not. Sometimes zookeeper flakes out or connections are lost to
          # remote datacenter zookeeper clusters, failing is not an option
          relaunch = []
          @watchers.each do |name, watcher_thread|
            unless watcher_thread.alive?
              relaunch << name
            end
          end

          relaunch.each do |name|
            begin
              log.warn "nerve: watcher #{name} not alive; reaping and relaunching"
              reap_watcher(name)
            rescue => e
              log.warn "nerve: could not reap #{name}, got #{e.inspect}"
            end
            launch_watcher(name, @services[name])
          end

          unless @heartbeat_path.nil?
            FileUtils.touch(@heartbeat_path)
          end

          sleep 10
        end
      rescue SignalException => e
        log.info "nerve: received signal #{e} #{e.signo}"
        raise e
      rescue Exception => e
        log.error "nerve: encountered unexpected exception #{e.inspect} in main thread"
        raise e
      ensure
        $EXIT = true
        log.warn 'nerve: reaping all watchers'
        @watchers.each do |name, watcher_thread|
          reap_watcher(name) rescue "nerve: watcher #{name} could not be immediately reaped; skippping"
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
