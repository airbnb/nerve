require 'logger'
require 'json'
require 'timeout'
require 'digest/sha1'

require 'em/pure_ruby'
require 'eventmachine'

require 'nerve/version'
require 'nerve/utils'
require 'nerve/log'
require 'nerve/ring_buffer'
require 'nerve/reporter'
require 'nerve/service_watcher'
require 'nerve/machine_watcher'

module Nerve
  class NerveServer < EM::Connection
    def initialize(nerve)
      @nerve = nerve
    end
    def receive_data(data)
      # Attempt to parse as JSON
      begin
        json = JSON.parse(data)
        @nerve.receive(json)
      rescue JSON::ParserError => e
        # nope!
      rescue => e
        $stdout.puts $!.inspect, $@
        $stderr.puts $!.inspect, $@
      end
    end
  end

  class Nerve
    include Logging

    def initialize(opts={})
      # trap int signal and set exit to true
      %w{INT TERM}.each do |signal|
        trap(signal) do
          puts "Caught signal"
          EventMachine.stop
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
      @service_watchers={}
      opts['service_checks'].each do |name,params|
        @service_watchers[name] = ServiceWatcher.new(params.merge({'instance_id' => @instance_id, 'name' => name}))
      end

      @ephemeral_service_watchers={}

      # create machine watcher object
      log.debug 'nerve: creating machine watcher'
      @machine_check = MachineWatcher.new(opts['machine_check'].merge({'instance_id' => @instance_id}))

      @port = opts['listen_port'] || 1025
      @port = @port.to_i

      @expiry = opts['dynamic_service_expiry'] || 60
      @expiry = @expiry.to_i

      log.debug 'nerve: completed init'
    end

    def run
      log.info 'nerve: starting run'
      begin
        log.debug 'nerve: initializing machine check'
        @machine_check.init

        log.debug 'nerve: initializing service checks'
        @service_watchers.each do |name,watcher|
          watcher.init
        end

        log.debug 'nerve: main initialization done'

        EventMachine.run do
          EM.add_periodic_timer(1) {
            @machine_check.run
            @service_watchers.each do |name,watcher|
              if watcher.expires and Time.now.to_i > watcher.expires_at
                log.info "removing service watcher for #{name} because it has expired"
                @service_watchers[name].close!
                @service_watchers.delete name
                next
              end
              watcher.run
            end
          }
          log.info "nerve: listening on port #{@port} for services"
          EventMachine.start_server("127.0.0.1", @port, NerveServer, self)
        end

        @machine_check.close!
        @service_watchers.each do |name,watcher|
          watcher.close!
        end
      rescue => e
        $stdout.puts $!.inspect, $@
        $stderr.puts $!.inspect, $@
      ensure
        EventMachine.stop
      end
      log.info 'nerve: exiting'
    end

    def receive(json)
      json['service_checks'].each do |name,params|
        sha1 = Digest::SHA1.hexdigest params.to_s
        params = params.merge({'instance_id' => @instance_id, 'name' => name, 'sha1' => sha1})
        port = params['port']
        key = "#{@name}_#{params['type']}_#{params['port']}"
        if @service_watchers.has_key? key
          if @service_watchers[key].sha1 != sha1
            log.info "removing ephemeral service watcher for #{key}"
            @service_watchers[key].close!
            @service_watchers.delete key
          else
            @service_watchers[key].expires_at = Time.now.to_i + @expiry
          end
        end

        if not @service_watchers.has_key? key
          begin
            log.info "adding new ephemeral service watcher for #{key}"
            s = ServiceWatcher.new(params)
            s.expires = true
            s.init
            @service_watchers[key] = s
          rescue ArgumentError => e
            log.info e
          end
        end
      end
    end
  end
end
