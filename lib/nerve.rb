require 'nerve/version'
require 'nerve/base'

require 'zk'

require_relative './nerve/ring_buffer'
require_relative './nerve/zk_helper'
require_relative './nerve/service_watcher'
require_relative './nerve/service_watcher/tcp'
require_relative './nerve/service_watcher/http'
require_relative './nerve/machine_watcher/cpuidle'

## a config might look like this:
config = {
  'instance_name' => '$instance_id',
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
    attr_reader :instance_id, :service_port, :zk_path, :service_watchers, :machine_watcher
    def initialize(opts={})
      # required options
      %w{instance_id zk_path}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
        instance_variable_set("@#{required}",opts[required])
      end

      # internal settings
      @zk = nil
      @failedure_threshold = 2 
      @exiting = false

      # create service watcher objects
      puts "creating service watcher objects"
      opts['service_checks'] ||= {}
      @service_watchers=[]
      opts['service_checks'].each do |name,params|
        @service_watchers << ServiceWatcher.new(params.merge({'name' => name}))
      end

      # create machine watcher object
      puts "creating machine watcher"
      if opts['machine_check']
        machine_check_class_name = opts['machine_check']['metric'].split('_').map(&:capitalize).join
        machine_check_class_name << 'MachineCheck'
        begin
          machine_check_class = MachineCheck.const_get(machine_check_class_name)
        rescue
          raise ArgumentError, "machine check #{opts['machine_check']['metric']} is not valid"
        end
        @machine_check = machine_check_class.new(opts['machine_check'])
      else
        @machine_check = nil
      end
      puts "end of init function"
    end

    def run
      puts "starting run..."
      @zk = ZKHelper()
      begin
        puts "registering machine..."
        register_thread = Thread.new{register_machine}
        
        puts "registering service"
        Thread.new{register_service}
        
        puts "waiting for children"
        register_thread.join()
      ensure
        @exiting = true
      end
    end

    

    def register_machine
      failed = true
      machine_node_path = "/machines/#{@instance_id}"
      
      while not @exiting
        begin
          @zk.ping?
        rescue Zookeeeper::Exceptions::NotConnected => e
          failed = true
        else
          # write json hash {service:service_name, host:host, cpu_idle:cpu_idle} into ephemeral node
          if failed or not @zk.exists?(machine_node_path)
            create_ephemeral_node(
              machine_node_path,
              {'vote' => @machine_check.vote })
            failed = false
          end
        end
        
        sleep(5)
      end
    end
    
    def run_service_checks
      # TODO(mkr): could consider doing this in parallel
      @service_checks.each do |service_check|
        return false unless service_check.check
      end
      retrun true
    end

    def register_service
      return unless (@service_port && run_service_checks)

      failures = @failure_threshold
      while not @exiting
        puts "looping inside register service"
        passed = run_service_checks
        if passed
          failures -= 1 unless failures == 0
        else
          failures += 1 unless failures == @failure_threshold
        end

        create_service_node unless failures > 0
        delete_service_node if failures == @failure_threshold

        sleep(5)
      end
    end


  end
end
