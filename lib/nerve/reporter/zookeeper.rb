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
      @zk_connection_string = service['zk_hosts'].sort.join(',')
      @data = parse_data(get_service_data(service))

      @zk_path = service['zk_path']
      @key_prefix = @zk_path + "/#{service['instance_id']}_"
      @full_key = nil
    end

    def start()
      log.info "nerve: waiting to connect to zookeeper to #{@zk_connection_string}"
      # Ensure that all Zookeeper reporters re-use a single zookeeper
      # connection to any given set of zk hosts.
      @@zk_pool_lock.synchronize {
        unless @@zk_pool.has_key?(@zk_connection_string)
          log.info "nerve: creating pooled connection to #{@zk_connection_string}"
          new_connection = ZK.new(@zk_connection_string, :timeout => 5)
          # If we couldn't connect, then raise an exception so that we can
          # reap the service watcher that holds this reporter
          raise "unable to establish connection to #{@zk_connection_string}" unless new_connection.connected?

          @@zk_pool[@zk_connection_string] = new_connection
          @@zk_pool_count[@zk_connection_string] = 1
          log.info "nerve: successfully created zk connection to #{@zk_connection_string}"
        else
          unless  @@zk_pool[@zk_connection_string].connected?
            log.warn "nerve: refusing to re-use a dead connection"
            raise "disconnected shared connection to #{@zk_connection_string}"
          end

          @@zk_pool_count[@zk_connection_string] += 1
          log.info "nerve: re-using existing zookeeper connection to #{@zk_connection_string}"
        end
        @zk = @@zk_pool[@zk_connection_string]
        log.info "nerve: retrieved zk connection to #{@zk_connection_string}"
      }
    end

    def stop()
      log.info "nerve: removing zk node at #{@full_key}" if @full_key
      begin
        report_down
      ensure
        @@zk_pool_lock.synchronize {
          @@zk_pool_count[@zk_connection_string] -= 1
          # Last thread to use the connection closes it
          if @@zk_pool_count[@zk_connection_string] == 0
            log.info "nerve: closing zk connection to #{@zk_connection_string}"
            begin
              @zk.close!
            ensure
              @@zk_pool.delete(@zk_connection_string)
            end
          end
        }
      end
    end

    def report_up()
      zk_save
    end

    def report_down
      # We need to touch zookeeper in the report_down method in case
      # we have a bad connection to zookeeper. We have to throw exceptions
      # to get cleaned up. This exists line serves no other purpose
      @zk.exists?('/')
      zk_delete
    end

    def ping?
      return @zk.connected? && @zk.exists?(@full_key || '/')
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
      @full_key = @zk.create(@key_prefix, :data => @data, :mode => :ephemeral_sequential)
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

