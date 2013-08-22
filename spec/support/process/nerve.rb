require 'socket'
require 'securerandom'
require 'json'

module Nerve
  module Test

    class NerveProcess < Process

      class MachineCheck
        attr_reader :metric
        attr_reader :hold
        attr_reader :up
        attr_reader :down

        def initialize(options={})
          @metric = options[:metric] || 'cpuidle'
          @hold   = options[:hold]   || 60
          @up     = options[:up]     || {:threshold => 30, :condition => '<'}
          @down   = options[:down]   || {:threshold => 70, :condition => '>'}
        end

        def to_h
          [:metric, :hold, :up, :down].
            each_with_object({}) do |attrib, hash|
              hash[attrib] = send(attrib)
            end
        end
      end

      class ServiceCheck
        attr_reader :name
        attr_reader :port
        attr_reader :check_interval
        attr_reader :checks
        attr_reader :host

        def initialize(options={})
          @name           = options[:name]           || 'my_service'
          @port           = options[:port]           || 9000
          @check_interval = options[:check_interval] || 1
          @checks         = options[:checks]         || [default_check]
          @host           = options[:host]           || "127.0.0.1"
        end

        def to_h
          [:port, :check_interval, :checks, :host].
            each_with_object({}) do |attrib, hash|
              hash[attrib] = send(attrib)
            end
        end

        private

        def default_check
          return {
            :type    => 'http',
            :uri     => '/health',
            :timeout => 1
          }
        end
      end

      attr_reader :config_path

      attr_reader :zk_servers
      attr_reader :zk_path

      attr_reader :instance_id
      attr_reader :machine_check
      attr_reader :service_checks

      def initialize(options={})
        @config_path    = options[:config_path]    || default_config_path

        @zk_servers     = options[:zk_servers]     || ['127.0.0.1:2181']
        @zk_path        = options[:zk_path]        || "/services/my_service"

        @instance_id    = options[:instance_id]    || 'test_host'
        @machine_check  = options[:machine_check]  || MachineCheck.new
        @service_checks = options[:service_checks] || [ServiceCheck.new]

        super('bin/nerve', :arguments => ['--config', @config_path])
      end

      def start
        write_config
        super
      end

      def stop
        super
      ensure
        remove_config
      end

      private

      def write_config
        config = {
          :instance_id => instance_id,
          :machine_check => machine_check.to_h.merge(:zk_path => full_zk_path),
          :service_checks => service_checks.each_with_object({}) { |s, map|
            map[s.name] = s.to_h.merge(:zk_path => full_zk_path('services'))
          }
        }
        File.write(config_path, JSON.dump(config))
      rescue
        puts "ERROR: Can't create config file"
        raise
      end

      def remove_config
        File.delete(@config_path)
      rescue
        puts "ERROR: Can't delete non-existent config file"
        raise
      end

      def default_config_path
        tag = SecureRandom.hex
        "/tmp/nerve.config-#{tag}"
      end

      def full_zk_path(final_component=nil)
        path = "#{zk_servers.join(',')}#{zk_path}"
        path << "/#{final_component}" if final_component
        path
      end

    end

  end
end