require 'nerve/reporter/base'
require 'thread'
require 'zk'


class Nerve::Reporter
  class Zookeeper < Base
    @@zk_pool = {}
    @@zk_pool_lock = Mutex.new

    def initialize(service)
      %w{zk_hosts zk_path instance_id host port}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless service[required]
      end
      @path = service['zk_hosts'].shuffle.join(',')
      @data = parse_data({'host' => service['host'], 'port' => service['port'], 'name' => service['instance_id']})

      @key = service['zk_path'] + "/#{service['instance_id']}_"
      @full_key = nil
    end

    def start()
      log.info "nerve: waiting to connect to zookeeper at #{@path}"
      # Ensure that all Zookeeper reporters re-use a single zookeeper
      # connection to any given connection string. Note that you will
      # end up with a number of connections equal to the number of hosts in
      # the connection string because the randomization in initialize
      @@zk_pool_lock.synchronize {
        unless @@zk_pool.has_key?(@path)
          log.info "nerve: creating pooled connection at #{@path}"
          @@zk_pool[@path] = ZK.new(@path)
          log.info "nerve: successfully created zk connection to #{@path}"
        else
          log.info "nerve: re-using existing zookeeper connection at #{@path}"
        end
        @zk = @@zk_pool[@path]
        log.info "nerve: retrieved zk connection to #{@path}"
      }
    end

    def stop()
      log.info "nerve: closing zk connection at #{@path}"
      report_down
      @zk.close!
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
  end
end

