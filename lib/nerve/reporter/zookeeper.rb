require 'nerve/reporter/base'
require 'thread'
require 'zk'


class Nerve::Reporter
  class Zookeeper < Base
    @@zk_pool = {}
    @@zk_pool_count = {}
    @@zk_pool_lock = Mutex.new

    def initialize(service)
      %w{zk_hosts zk_path}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless service[required]
      end
      # Since we pool we get one connection per zookeeper cluster
      @path = service['zk_hosts'].sort.join(',')
      @data = parse_data(get_service_data(service))

      @zk_path = service['zk_path']
      @key = @zk_path + "/#{service['instance_id']}_"
      @full_key = nil
    end

    def start()
      log.info "nerve: waiting to connect to zookeeper to #{@path}"
      # Ensure that all Zookeeper reporters re-use a single zookeeper
      # connection to any given set of zk hosts.
      @@zk_pool_lock.synchronize {
        unless @@zk_pool.has_key?(@path)
          log.info "nerve: creating pooled connection to #{@path}"
          @@zk_pool[@path] = ZK.new(@path, :timeout => 5)
          @@zk_pool_count[@path] = 1
          log.info "nerve: successfully created zk connection to #{@path}"
        else
          @@zk_pool_count[@path] += 1
          log.info "nerve: re-using existing zookeeper connection to #{@path}"
        end
        @zk = @@zk_pool[@path]
        log.info "nerve: retrieved zk connection to #{@path}"
      }
    end

    def stop()
      log.info "nerve: removing zk node at #{@full_key}" if @full_key
      begin
        report_down
      ensure
        @@zk_pool_lock.synchronize {
          @@zk_pool_count[@path] -= 1
          # Last thread to use the connection closes it
          if @@zk_pool_count[@path] == 0
            log.info "nerve: closing zk connection to #{@path}"
            begin
              @zk.close!
            ensure
              @@zk_pool.delete(@path)
            end
          end
        }
      end
    end

    def report_up()
      zk_save
    end

    def report_down
      zk_delete
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
      @zk.mkdir_p(@zk_path)
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

