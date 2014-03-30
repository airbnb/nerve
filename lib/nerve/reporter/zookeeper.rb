require 'nerve/reporter/base'
require 'zk'

class Nerve::Reporter
  class Zookeeper < Base
    def initialize(service)
      %w{zk_hosts zk_path instance_id host port}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless service[required]
      end
      @path = service['zk_hosts'].shuffle.join(',') + service['zk_path']
      @data = parse_data({'host' => service['host'], 'port' => service['port'], 'name' => service['instance_id']})

      @key = "/#{service['instance_id']}_"
      @full_key = nil
    end

    def start
      log.info "nerve: waiting to connect to zookeeper at #{@path}"
      @zk = ZK.new(@path)

      @zk.on_expired_session do
        log.info "nerve: zookeeper session expired at #{@path}"
        start

        if @full_key
          zk_create
        end
      end

      log.info "nerve: successfully created zk connection to #{@path}"
    end

    def stop
      log.info "nerve: closing zk connection at #{@path}"
      @zk.close
    end

    def report_up
      zk_create
    end

    def report_down
      zk_delete
    end

    def ping?
      return @zk.ping?
    end

    def close!
      @zk.close!
    end

    private

    def zk_delete
      if @node_subscription
        @node_subscription.unsubscribe
      end

      if @full_key
        @zk.delete(@full_key, :ignore => :no_node)
        @full_key = nil
      end
    end

    def zk_create
      @full_key = @zk.create(@key, :data => @data, :mode => :ephemeral_sequential)

      @node_subscription = @zk.register(@full_key, :only => [:changed, :deleted]) do |event|
        puts "ZK node subscription event received for key #{@full_key}: type=#{event.type}, state=#{event.state}"
        log.info "ZK node subscription event received for key #{@full_key}: type=#{event.type}, state=#{event.state}"
        zk_create
      end

      unless @zk.exists?(@full_key, :watch => true)
        @node_subscription.unsubscribe
        puts "ZK node subscription lost for #{@full_key}"
        log.info "ZK node subscription lost for #{@full_key}"
        zk_create
      end

      @full_key
    end

    def parse_data(data)
      return data if data.class == String
      return data.to_json
    end
  end
end

