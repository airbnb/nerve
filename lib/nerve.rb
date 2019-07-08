require 'fileutils'
require 'logger'
require 'json'
require 'timeout'

require 'nerve/version'
require 'nerve/utils'
require 'nerve/log'
require 'nerve/statsd'
require 'nerve/ring_buffer'
require 'nerve/reporter'
require 'nerve/service_watcher'

module Nerve
  class Nerve
    include Logging
    include Utils
    include StatsD

    MAIN_LOOP_SLEEP_S = 10.freeze
    LAUNCH_WAIT_FOR_REPORT_S = 30.freeze

    def initialize(config_manager)
      log.info 'nerve: setting up!'
      @config_manager = config_manager
      @config_manager.reload!

      StatsD.configure_statsd(@config_manager.config["statsd"] || {})

      # set global variable for exit signal
      $EXIT = false

      # State of currently running watchers according to Nerve
      @watchers = {}
      @watcher_versions = {}

      # instance_id, heartbeat_path, and watchers_desired are populated by
      # load_config! in the main loop from the configuration source
      @instance_id = nil
      @heartbeat_path = nil
      @watchers_desired = {}

      # Flag to indicate a config reload is required by the main loop
      # This decoupling is required for gracefully reloading config on SIGHUP
      # as one should do as little as possible in a signal handler
      @config_to_load = true

      Signal.trap("HUP") do
        @config_to_load = true
      end

      log.debug 'nerve: completed init'
    rescue Exception => e
      statsd && statsd.increment('nerve.stop', tags: ['stop_avenue:abort', 'stop_location:init', "exception_name:#{e.class.name}", "exception_message:#{e.message}"])
      raise e
    end

    def load_config!
      log.info 'nerve: loading config'
      @config_to_load = false
      @config_manager.reload!
      config = @config_manager.config

      # required options
      log.debug 'nerve: checking for required inputs'
      %w{instance_id services}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless config[required]
      end
      @instance_id = config['instance_id']
      @watchers_desired = {}
      config['services'].each do |key, value|
        if value.key?('load_test_concurrency')
          concurrenty = value['load_test_concurrency']
          concurrenty.times do |i|
            @watchers_desired["#{key}_#{i}"] = value
          end
        else
          @watchers_desired[key] = value
        end
      end
      @max_repeated_report_failures = config['max_repeated_report_failures']
      @heartbeat_path = config['heartbeat_path']
      StatsD.configure_statsd(config["statsd"] || {})
      statsd.increment('nerve.config.update')
    end

    def run
      log.info 'nerve: starting main run loop'
      statsd.increment('nerve.start')

      statsd.time('nerve.main_loop.elapsed_time') do
        begin
          until $EXIT
            # Check if configuration needs to be reloaded and reconcile any new
            # configuration of watchers with old configuration
            if @config_to_load
              load_config!

              # Reap undesired service watchers
              services_to_reap = @watchers.select{ |name, _|
                !@watchers_desired.has_key?(name)
              }.keys()

              unless services_to_reap.empty?
                log.info "nerve: reaping old watchers: #{services_to_reap}"
                services_to_reap.each do |name|
                  statsd.increment('nerve.watcher.reap', tags: ['reap_reason:old', "watcher_name:#{name}"])
                  reap_watcher(name)
                end
              end

              # Start new desired service watchers
              services_to_launch = @watchers_desired.select{ |name, _|
                !@watchers.has_key?(name)
              }.keys()

              unless services_to_launch.empty?
                log.info "nerve: launching new watchers: #{services_to_launch}"
                services_to_launch.each do |name|
                  statsd.increment('nerve.watcher.launch', tags: ['launch_reason:new', "watcher_name:#{name}"])
                  launch_watcher(name, @watchers_desired[name])
                end
              end

              # Detect and update existing service watchers which are in both
              # the currently running state and the desired (config) watcher
              # state but have different configurations
              services_to_update = @watchers.select { |name, _|
                @watchers_desired.has_key?(name) &&
                merged_config(@watchers_desired[name], name).hash != @watcher_versions[name]
              }.keys()

              services_to_update.each do |name|
                log.info "nerve: detected new config for #{name}"
                # Keep the old watcher running until the replacement is launched
                # This keeps the service registered while we change it over
                # This also keeps connection pools active across diffs
                temp_name = "#{name}_#{@watcher_versions[name]}"
                @watchers[temp_name] = @watchers.delete(name)
                @watcher_versions[temp_name] = @watcher_versions.delete(name)
                log.info "nerve: launching new watcher for #{name}"
                statsd.increment('nerve.watcher.launch', tags: ['launch_reason:update', "watcher_name:#{name}"])
                launch_watcher(name, @watchers_desired[name], :wait => true)
                log.info "nerve: reaping old watcher #{temp_name}"
                statsd.increment('nerve.watcher.reap', tags: ['reap_reason:update', "watcher_name:#{temp_name}"])
                reap_watcher(temp_name)
              end
            end

            # If this was a configuration check, bail out now
            if @config_manager.options[:check_config]
              log.info 'nerve: configuration check succeeded, exiting immediately'
              break
            end

            # Check that watchers are still alive, auto-remediate if they
            # are not. Sometimes zookeeper flakes out or connections are lost to
            # remote datacenter zookeeper clusters, failing is not an option
            relaunch = []
            @watchers.each do |name, watcher|
              unless watcher.alive?
                relaunch << name
              end
            end

            relaunch.each do |name|
              begin
                log.warn "nerve: watcher #{name} not alive; reaping and relaunching"
                statsd.increment('nerve.watcher.reap', tags: ['reap_reason:relaunch', 'reap_result:success', "watcher_name:#{name}"])
                reap_watcher(name)
              rescue => e
                log.warn "nerve: could not reap #{name}, got #{e.inspect}"
                statsd.increment('nerve.watcher.reap', tags: ['reap_reason:relaunch', 'reap_result:fail', "watcher_name:#{name}", "exception_name:#{e.class.name}", "exception_message:#{e.message}"])
              end
              statsd.increment('nerve.watcher.launch', tags: ['launch_reason:relaunch', "watcher_name:#{name}"])
              launch_watcher(name, @watchers_desired[name])
            end

            # Indicate we've made progress
            heartbeat()

            responsive_sleep(MAIN_LOOP_SLEEP_S) { @config_to_load || $EXIT }
          end
        rescue => e
          log.error "nerve: encountered unexpected exception #{e.inspect} in main thread"
          statsd.increment('nerve.stop', tags: ['stop_avenue:abort', 'stop_location:main_loop', "exception_name:#{e.class.name}", "exception_message:#{e.message}"])
          raise e
        ensure
          $EXIT = true
          log.warn 'nerve: reaping all watchers'
          @watchers.each do |name, _|
            reap_watcher(name)
          end
        end
      end

      log.info 'nerve: exiting'
      statsd.increment('nerve.stop', tags: ['stop_avenue:clean', 'stop_location:main_loop'])
    ensure
      $EXIT = true
    end

    def heartbeat
      unless @heartbeat_path.nil?
        FileUtils.touch(@heartbeat_path)
      end
      log.debug 'nerve: heartbeat'
    end

    def merged_config(config, name)
      # Get a deep copy so sub-hashes are properly handled
      deep_copy = Marshal.load(Marshal.dump(config))
      return deep_copy.merge(
        {
          'instance_id' => @instance_id,
          'name' => name,
          'max_repeated_report_failures' => @max_repeated_report_failures,
        }
      )
    end

    def launch_watcher(name, config, opts = {})
      wait = opts[:wait] || false

      watcher_config = merged_config(config, name)
      # The ServiceWatcher may mutate the configs, so record the version before
      # passing the config to the ServiceWatcher
      @watcher_versions[name] = watcher_config.hash

      watcher = ServiceWatcher.new(watcher_config)
      unless @config_manager.options[:check_config]
        log.debug "nerve: launching service watcher #{name}"
        watcher.start()
        @watchers[name] = watcher
        if wait
          log.info "nerve: waiting for watcher thread #{name} to report"
          responsive_sleep(LAUNCH_WAIT_FOR_REPORT_S) { !watcher.was_up.nil? || $EXIT }
          log.info "nerve: watcher thread #{name} has reported!"
        end
      else
        log.info "nerve: not launching #{name} due to --check-config option"
      end
    end

    def reap_watcher(name)
      watcher = @watchers.delete(name)
      @watcher_versions.delete(name)
      shutdown_status = watcher.stop()
      log.info "nerve: stopped #{name}, clean shutdown? #{shutdown_status}"
      shutdown_status
    end
  end
end
