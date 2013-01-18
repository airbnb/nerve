module Nerve
  class ServiceWatcher

    include Logging

    def initialize(opts={})
      log.debug "creating service watcher object"
      %w{port host zk_path instance_id name}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
        instance_variable_set("@#{required}",opts[required])
      end
      @host = opts['host'] ? opts['host'] : '0.0.0.0'
      # TODO(mkr): maybe take these as inputs
      @threshold = 2
      @sleep = 1
      @service_checks = []
      opts['checks'] ||= {}
      opts['checks'].each do |type,params|
        service_check_class_name = type.split("_").map(&:capitalize).join
        service_check_class_name << "ServiceCheck"
        begin
          service_check_class = ServiceCheck.const_get(service_check_class_name)
        rescue
          raise ArgumentError, "invalid service check: #{type}"
        end
        @service_checks << service_check_class.new(params.merge({
                                                                  'port' => @port,
                                                                  'host' => @host,
                                                                }))
      end
    end

    def run()
      log.info "watching service #{@name}"
      @zk = ZKHelper.new(@zk_path)
      log.debug "created Zk handle"
      @zk.delete(@instance_id)
      log.debug "creating ring buffer"
      ring_buffer = RingBuffer.new(@threshold)
      @threshold.times { ring_buffer.push false }

      log.debug "about to start loop"
      until $EXIT
        begin
          log.debug "starting loop"
          @zk.ping?
          check = check?
          log.debug "check returned #{check.inspect} for #{@name}"
          ring_buffer.push check?
          if ring_buffer.include?(false)
            @zk.delete(@instance_id)
          else
            @zk.ensure_ephemeral_node(@instance_id)
          end
          sleep @sleep
        rescue Object => o
          log.error "hit an error, setting exit: "
          log.error o.inspect
          log.error o.backtrace
          $EXIT = true
        end
      end
      log.debug "exited loop"
    end

    def check?
      @service_checks.each do |check|
        check_status = check.check?

        return false unless check_status
      end
      return true
    end

  end
end
