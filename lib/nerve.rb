require 'nerve/version'
require 'nerve/base'

require 'zk'

require_relative './nerve/service_checks/tcp'
require_relative './nerve/service_checks/http'

## a config might look like this:
config = {
  'instance_name' => '$instance_id',
  'voter_status' => {
    'metric' => 'cpuidle',
    'hold' => '60',
    'up' => {
      'threshold' => '30',
      'condition' => '<',
    }
    'down' => {
      'threshold' => '70',
      'condition' => '>'
    },
  },
  'services' => {
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

## sample service check could look something like:
service_checks = {
  'monorails_tcp' => {
    'type' => 'tcp',
    'port' => '80',
  },
  'monorails_/health' => {
    'type' => 'http',
    'port' => 80,
    'uri'=> '/health',
  },
}


module Nerve
  # Your code goes here...
  class Nerve < Base
    #TODO(mkr): we should add an option for the interface and default
    #to 0.0.0.0
    attr_reader :instance_id, :service_name, :service_port, :zk_path, :service_checks
    def initialize(opts={})
      # Stringify keys :/
      options = options.inject({}) { |h,(k,v)| h[k.to_s] = v; h }
      
      %w{instance_id service_name zk_path}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
      end
        
      @zk_path = opts['zk_path']
      @instance_id = opts['instance_id']
      @service_name = opts['service_name']
      
      # optional -- if present, will create service node
      @service_port = opts['service_port']

      # internal settings
      @zk = nil
      @failure_threshold = 2 
      @exiting = False

      # create service check objects
      opts['service_checks'] ||= {}
      @service_checks=[]
      opts['service_checks'].each do |name,params|
        raise ArgumentError, "missing service check type for #{name}" unless params['type']
        service_check_class_name = params['type'].split("_").map(&:capitalize).join
        service_check_class_name << "ServiceCheck"
        begin
          service_check_class = Nerve::ServiceCheck.const_get service_check_class_name
        rescue NameError
          raise ArgumentError, "invalid service check type: #{params['type']}"
        end
        @service_checks << service_check_class.new(params)
      end
    end

    def run
      @zk = ZK.new(@zk_path)
      begin
        register_thread = Thread.new(register_machine)
        Thread.new(register_service)

        register_thread.join()
      ensure
        @exiting = True
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
              machine_node_path
              {'service' => @service_name, 'cpu_ide' => cpu_idle })
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

    def create_service_node  
      # create ephemeral node in zookeeper under <root>/services/<service name>/<instance_id>
      # write json hash {ip:ip, host:host, port:port} into ephemeral node
    end

    def delete_service_node
      # delete node in zookeeper under <root>/services/<service_name>/<instance_id>
    end

    def create_ephemeral_node(path, data="")
      @zk.delete(path, :ignore => :no_node)
      @zk.create(path, :data => data.to_json)
    end
  end
end
