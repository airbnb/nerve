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

    def start()
      log.info "nerve: waiting to connect to zookeeper at #{@path}"
      @zk = ZK.new(@path)

      log.info "nerve: successfully created zk connection to #{@path}"
    end

    def stop()
      log.info "nerve: closing zk connection at #{@path}"
      @zk.close
    end

    def report_up()
      zk_save
    end

    def report_down
      zk_delete
    end

    def update_data(new_data='')
      @data = parse_data(new_data)
      zk_save
    end

    def ping?
      return @zk.ping?
    end

    def close!
      @zk.close!
    end

    private

    def zk_delete
      if @full_key
        @zk.delete(@full_key, :ignore => :no_node)
        @full_key = nil
      end
    end

    def zk_create
      @full_key = @zk.create(@key, :data => @data, :mode => :ephemeral_sequential)
    end

    def zk_save
      return zk_create unless @full_key

      begin
        @zk.set(@full_key, @data)
      rescue ZK::Exceptions::NoNode
        zk_create
      end
    end

    def parse_data(data)
      return data if data.class == String
      return data.to_json
    end
  end
end

