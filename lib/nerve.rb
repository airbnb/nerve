require 'nerve/version'
require 'nerve/base'
require 'logger'
require 'json'

require 'zk'

require_relative './nerve/log'
require_relative './nerve/ring_buffer'
require_relative './nerve/zk_helper'
require_relative './nerve/service_watcher'
require_relative './nerve/service_watcher/tcp'
require_relative './nerve/service_watcher/http'
require_relative './nerve/machine_watcher'
require_relative './nerve/machine_watcher/cpuidle'



## a config might look like this:
config = {
  'instance_id' => '$instance_id',
  'voter_status' => {
    'metric' => 'cpuidle',
    'hold' => '60',
    'up' => {
      'threshold' => '30',
      'condition' => '<',
    },
    'down' => {
      'threshold' => '70',
      'condition' => '>'
    },
  },
  'service_checks' => {
    'monorails' =>{
      'port' => '80',
      'host' => '0.0.0.0',
      'zk_path' => '',
      'checks' => {
        'tcp' => {},
        'http' => {
          'uri' => '/health',
        },
      },
    },
  },
}


module Nerve
  # Your code goes here...
  class Nerve < Base

    include Logging

    def initialize(opts={})

      # set global variable for exit signal
      $EXIT = false

      # trap int signal and set exit to true
      trap('INT') do
        $EXIT = true
      end

      log.info "starting nerve"

      # required options
      log.debug "checking for required inputs"
      %w{instance_id service_checks machine_check}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
        instance_variable_set("@#{required}",opts[required])
      end


      # create service watcher objects
      log.debug "creating service watchers"
      opts['service_checks'] ||= {}
      @service_watchers=[]
      opts['service_checks'].each do |name,params|
        @service_watchers << ServiceWatcher.new(params.merge({'instance_id' => @instance_id, 'name' => name}))
      end

      # create machine watcher object
      log.debug "creating machine watcher"
      @machine_check = MachineWatcher.new(opts['machine_check'].merge({'instance_id' => @instance_id}))

      log.debug 'completed init for nerve'
    end

    def run
      log.info "starting run"
      begin
        children = []
        log.debug "launching machine check thread"
#        children << Thread.new{@machine_check.run}

        log.debug "launching service check threads"
        @service_watchers.each do |watcher|
          children << Thread.new{watcher.run}
        end

        log.info "waiting for children"
        children.each do |child|
          child.join
        end
      ensure
        $EXIT = true
      end
      log.info "ending run"
    end

  end
end
