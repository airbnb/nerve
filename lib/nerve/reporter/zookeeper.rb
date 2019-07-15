require 'nerve/reporter/base'
require 'thread'
require 'zk'
require 'zookeeper'
require "base64"

class Nerve::Reporter
  class Zookeeper < Base
    ZK_CONNECTION_ERRORS = [ZK::Exceptions::OperationTimeOut, ZK::Exceptions::ConnectionLoss, ::Zookeeper::Exceptions::NotConnected]

    @@zk_pool = {}
    @@zk_pool_count = {}
    @@zk_pool_lock = Mutex.new

    def initialize(service)
      %w{zk_hosts zk_path}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless service[required]
      end
      # Since we pool we get one connection per zookeeper cluster
      zk_host_list = service['zk_hosts'].sort
      @zk_cluster = host_list_to_cluster(zk_host_list)
      @zk_connection_string = zk_host_list.join(',')
      @data = parse_data(get_service_data(service))

      @zk_path = service['zk_path']
      @key_prefix = @zk_path + get_key(service)
      @full_key = nil
    end

    def start()
      log.info "nerve: waiting to connect to zookeeper cluster #{@zk_cluster} hosts #{@zk_connection_string}"
      # Ensure that all Zookeeper reporters re-use a single zookeeper
      # connection to any given set of zk hosts.
      @@zk_pool_lock.synchronize {
        unless @@zk_pool.has_key?(@zk_connection_string)
          log.info "nerve: creating pooled connection to #{@zk_connection_string}"
          @@zk_pool[@zk_connection_string] = ZK.new(@zk_connection_string, :timeout => 5)
          @@zk_pool_count[@zk_connection_string] = 1
          log.info "nerve: successfully created zk connection to #{@zk_connection_string}"
          statsd.increment('nerve.reporter.zk.client.created', tags: ["zk_cluster:#{@zk_cluster}"])
        else
          @@zk_pool_count[@zk_connection_string] += 1
          log.info "nerve: re-using existing zookeeper connection to #{@zk_connection_string}"
          statsd.increment('nerve.reporter.zk.client.reused', tags: ["zk_cluster:#{@zk_cluster}"])
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
      if not @zk.connected?
        log.error "nerve: error in reporting up on zk node #{@full_key}: loss connection"
        return false
      else
        begin
          zk_save
        rescue *ZK_CONNECTION_ERRORS => e
          log.error "nerve: error in reporting up on zk node #{@full_key}: #{e.message}"
          return false
        end

        return true
      end
    end

    def report_down
      if not @zk.connected?
        log.error "nerve: error in reporting down on zk node #{@full_key}: loss connection"
        return false
      else
        begin
          zk_delete
        rescue *ZK_CONNECTION_ERRORS => e
          log.error "nerve: error in reporting down on zk node #{@full_key}: #{e.message}"
          return false
        end

        return true
      end
    end

    def ping?
      if not @zk.connected?
        log.error "nerve: error in ping reporter at zk node #{@full_key}: loss connection"
        return false
      else
        begin
          return @zk.exists?(@full_key || '/')
        rescue *ZK_CONNECTION_ERRORS => e
          log.error "nerve: error in ping reporter at zk node #{@full_key}: #{e.message}"
          return false
        end
      end
    end

    private

    def host_list_to_cluster(list)
      first_host = list.sort.first
      first_token = first_host.split('.').first
      # extract cluster name by filtering name of first host
      # remove domain extents and trailing numbers
      last_non_number = first_token.rindex(/[^0-9]/)
      last_non_number ? first_token[0..last_non_number] : first_host
    end

    def get_key(service)
      if service.has_key?('use_path_encoding') && service['use_path_encoding'] == true
        obj = {
          'host' => service['host'],
          'port' => service['port']
        }
        if service.has_key?('labels')
          obj['labels'] = service['labels']
        end
        '/base64_' + Base64.urlsafe_encode64(JSON(obj)) + '_'
      else
        "/#{service['instance_id']}_"
      end
    end

    def zk_delete
      if @full_key
        statsd.time('nerve.reporter.zk.delete.elapsed_time', tags: ["zk_cluster:#{@zk_cluster}"]) do
          @zk.delete(@full_key, :ignore => :no_node)
        end
        @full_key = nil
      end
    end

    def zk_create
      # only mkdir_p if the path does not exist
      statsd.time('nerve.reporter.zk.create.elapsed_time', tags: ["zk_cluster:#{@zk_cluster}", "zk_path:#{@zk_path}"]) do
        @zk.mkdir_p(@zk_path) unless @zk.exists?(@zk_path)
        @full_key = @zk.create(@key_prefix, :data => @data, :mode => :ephemeral_sequential)
      end
    end

    def zk_save
      return zk_create unless @full_key

      begin
        statsd.time('nerve.reporter.zk.save.elapsed_time', tags: ["zk_cluster:#{@zk_cluster}"]) do
          @zk.set(@full_key, @data)
        end
      rescue ZK::Exceptions::NoNode
        zk_create
      end
    end
  end
end

