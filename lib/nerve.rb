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
      %w{instance_id services}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
      end

      @instance_id = opts['instance_id']

      # create service watcher objects
      log.debug 'nerve: creating service watchers'
      @service_watchers=[]
      opts['services'].each do |name, config|
        @service_watchers << ServiceWatcher.new(config.merge({'instance_id' => @instance_id, 'name' => name}))
      end

      log.debug 'nerve: completed init'
    end

    def run
      log.info 'nerve: starting run'
      begin
        children = []

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
