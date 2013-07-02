require 'logger'
require 'json'
require 'timeout'

require_relative './nerve/version'
require_relative './nerve/utils'
require_relative './nerve/log'
require_relative './nerve/ring_buffer'
require_relative './nerve/reporter'
require_relative './nerve/service_watcher'
require_relative './nerve/machine_watcher'

module Nerve
  # Your code goes here...
  class Nerve

    include Logging

    def initialize(opts={})
      # set global variable for exit signal
      $EXIT = false

      # trap int signal and set exit to true
      %w{INT TERM}.each do |signal|
        trap(signal) do
          $EXIT = true
        end
      end

      log.info 'nerve: starting up!'

      # required options
      log.debug 'nerve: checking for required inputs'
      %w{instance_id service_checks machine_check}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
        instance_variable_set("@#{required}",opts[required])
      end


      # create service watcher objects
      log.debug 'nerve: creating service watchers'
      opts['service_checks'] ||= {}
      @service_watchers=[]
      opts['service_checks'].each do |name,params|
        @service_watchers << ServiceWatcher.new(params.merge({'instance_id' => @instance_id, 'name' => name}))
      end

      # create machine watcher object
      log.debug 'nerve: creating machine watcher'
      @machine_check = MachineWatcher.new(opts['machine_check'].merge({'instance_id' => @instance_id}))

      log.debug 'nerve: completed init'
    end

    def run
      log.info 'nerve: starting run'
      begin
        children = []
        log.debug 'nerve: launching machine check thread'
        children << Thread.new{@machine_check.run}

        log.debug 'nerve: launching service check threads'
        @service_watchers.each do |watcher|
          children << Thread.new{watcher.run}
        end

        log.debug 'nerve: main thread done, waiting for children'
        children.each do |child|
          child.join
        end
      ensure
        $EXIT = true
      end
      log.info 'nerve: exiting'
    end

  end
end
