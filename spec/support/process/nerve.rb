require 'socket'
require 'securerandom'
require 'json'

module Nerve
  class NerveProcess < Process
    attr_reader :config_path

    attr_reader :zk_servers
    attr_reader :zk_path

    attr_reader :role
    attr_reader :instance_id
    attr_reader :machine_check
    attr_reader :service_checks

    attr_reader :config

    def initialize(options={})
      @config_path    = options[:config_path]    || default_config_path

      @zk_servers     = options[:zk_servers]     || ['localhost:2181']
      @zk_path        = options[:zk_path]        || "/"

      @role           = options[:role]           || 'my_role'
      @instance_id    = options[:instance_id]    || 'test_host'
      @machine_check  = options[:machine_check]  || default_machine_check
      @service_checks = options[:service_checks] || default_service_checks

      @config = {
        :instance_id => instance_id,
        :machine_check =>
          machine_check.merge(:zk_path => full_path(machine_check_path)),
        :service_checks =>
          service_checks.each_pair.each_with_object({}) { |(n, c), map|
            map[n] = c.merge(:zk_path => full_path(service_check_path(n)))
          }
      }

      super('bin/nerve', :arguments => ['--config', @config_path])
    end

    def start
      write_config
      super
    end

    def stop(options={})
      super(options)
    ensure
      remove_config
    end

    def up?
      stderr =~ /nerve: starting run/
    end

    def machine_check_path
      "#{zk_path}machines/#{role}"
    end

    def service_check_path(service_name)
      "#{zk_path}services/#{service_name}"
    end

    def default_machine_check
      return {
        :metric => 'trivial'
      }
    end

    def default_service_checks
      return {
        "my_service" => {
          "host" => "localhost",
          "port" => 3238,
          "check_interval" => 2,
          "checks" => [
            {
              "type" => "http",
              "uri" => "/health",
              "timeout" => 0.5
            }
          ]
        }
      }
    end

    private

    def write_config
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

    def full_path(absolute_path)
      "#{zk_servers.join(',')}#{absolute_path}"
    end

  end
end
