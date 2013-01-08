require "nerve/version"
require "nerve/base"

require "zk"

module Nerve
  # Your code goes here...
  class Nerve < Base
    attr_reader :instance_id, :service_name, :service_port, :zk_path, :health_check
    def initialize(opts={})
      %w{instance_id service_name zk_path}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" \
          unless opts[required]
      end

      @zk_path = opts['zk_path']
      @instance_id = opts['instance_id']
      @service_name = opts['service_name']

      # optional -- if present, will create service node
      @service_port = opts['service_port']
      @health_check = opts['health_check']

      # internal settings
      @zk = nil
      @failure_threshold = 2 
      @exiting = False
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

        sleep(5)
      end
    end

    def register_service
      return unless (@service_port && @health_check)

      failures = @failure_threshold
      while not @exiting
        passed = run_health_check(check_type)
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
