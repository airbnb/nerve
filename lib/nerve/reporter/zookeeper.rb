require 'nerve/reporter/base'
require 'nerve/atomic'
require 'thread'
require 'zk'
require 'zookeeper'
require "base64"

class Nerve::Reporter
  class Zookeeper < Base
    ZK_CONNECTION_ERRORS = [ZK::Exceptions::OperationTimeOut, ZK::Exceptions::ConnectionLoss, ::Zookeeper::Exceptions::NotConnected]

    # zookeeper children call will fail if the array of children names exceeds 4,194,304 bytes:
    # https://issues.apache.org/jira/browse/ZOOKEEPER-272?attachmentOrder=desc
    # here we limit max length of single child name to 64K, to allow reasonable number of children
    PATH_ENCODING_MAX_LENGTH = 65536

    DEFAULT_NODE_TYPE = 'ephemeral_sequential'
    TTL_RENEW_EXCLUSIONS = [ :ephemeral, :ephemeral_sequential ].freeze

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
      @mode = (service['node_type'] || DEFAULT_NODE_TYPE).to_sym
      @zk_path = service['zk_path']
      @key_prefix = @zk_path + encode_child_name(service)
      @node_ttl = service['ttl_seconds']
      @full_key = Nerve::AtomicValue.new(nil)
    end

    def start()
      log.info "nerve: waiting to connect to zookeeper cluster #{@zk_cluster} hosts #{@zk_connection_string}"
      # Ensure that all Zookeeper reporters re-use a single zookeeper
      # connection to any given set of zk hosts.
      @@zk_pool_lock.synchronize {
        unless @@zk_pool.has_key?(@zk_connection_string)
          log.info "nerve: creating pooled connection to #{@zk_connection_string}"
          # zk session timeout is 2 * receive_timeout_msec (as of zookeeper-1.4.x)
          # i.e. 16000 means 32 sec session timeout
          @@zk_pool[@zk_connection_string] = ZK.new(@zk_connection_string, :timeout => 5, :receive_timeout_msec => 16000)
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

      start_ttl_renew_thread
    end

    def stop()
      stop_ttl_renew_thread

      node_path = @full_key.get
      log.info "nerve: removing zk node at #{node_path}" if node_path

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
      node_path = @full_key.get

      if not @zk.connected?
        log.error "nerve: error in reporting up on zk node #{node_path}: loss connection"
        return false
      else
        begin
          zk_save(node_path)
        rescue *ZK_CONNECTION_ERRORS => e
          log.error "nerve: error in reporting up on zk node #{node_path}: #{e.message}"
          return false
        end

        return true
      end
    end

    def report_down
      node_path = @full_key.get

      if not @zk.connected?
        log.error "nerve: error in reporting down on zk node #{node_path}: loss connection"
        return false
      else
        begin
          zk_delete
        rescue *ZK_CONNECTION_ERRORS => e
          log.error "nerve: error in reporting down on zk node #{node_path}: #{e.message}"
          return false
        end

        return true
      end
    end

    def ping?
      node_path = @full_key.get

      if not @zk.connected?
        log.error "nerve: error in ping reporter at zk node #{node_path}: loss connection"
        return false
      else
        begin
          return @zk.exists?(node_path || '/')
        rescue *ZK_CONNECTION_ERRORS => e
          log.error "nerve: error in ping reporter at zk node #{node_path}: #{e.message}"
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

    def encode_child_name(service)
      if service['use_path_encoding'] == true
        encoded = Base64.urlsafe_encode64(@data)
        length = encoded.length
        statsd.gauge('nerve.reporter.zk.child.bytes', length, tags: ["zk_cluster:#{@zk_cluster}", "zk_path:#{@zk_path}"])
        if length <= PATH_ENCODING_MAX_LENGTH
          return "/base64_#{length}_#{encoded}_"
        end
      end
      "/#{service['instance_id']}_"
    end

    def zk_delete
      node_path = @full_key.get

      if node_path
        statsd.time('nerve.reporter.zk.delete.elapsed_time', tags: ["zk_cluster:#{@zk_cluster}"]) do
          @zk.delete(node_path, :ignore => :no_node)
        end

        @full_key.set(nil)
      end
    end

    def zk_create
      # only mkdir_p if the path does not exist
      statsd.time('nerve.reporter.zk.create.elapsed_time', tags: ["zk_cluster:#{@zk_cluster}", "zk_path:#{@zk_path}"]) do
        @zk.mkdir_p(@zk_path) unless @zk.exists?(@zk_path)

        node_path = zk_try_create
        @full_key.set(node_path)
        log.info "nerve: wrote new ZK node of type #{@mode} at #{node_path}"
      end
    end

    def zk_try_create
      begin
        return @zk.create(@key_prefix, :data => @data, :mode => @mode)
      rescue ::Zookeeper::Exceptions::NodeExists, ZK::Exceptions::NodeExists
        # This exception will only occur when not using sequential
        # nodes (because sequential nodes are always unique), in which
        # case the name is the same as @key_prefix as Zookeeper
        # will not append any suffix.
        @zk.set(@key_prefix, @data)
        log.info "nerve: tried to write node but exists, setting data instead"

        return @key_prefix
      end
    end

    def zk_save(node_path)
      return zk_create unless node_path

      begin
        statsd.time('nerve.reporter.zk.save.elapsed_time', tags: ["zk_cluster:#{@zk_cluster}"]) do
          @zk.set(node_path, @data)
          log.info "nerve: set data on #{node_path}"
        end
      rescue ZK::Exceptions::NoNode
        zk_create
      end
    end

    def start_ttl_renew_thread
      @ttl_should_exit = Nerve::AtomicValue.new(false)
      @ttl_thread = nil

      unless @node_ttl.nil? || TTL_RENEW_EXCLUSIONS.include?(@mode)
        @ttl_thread = Thread.new {
          log.info "nerve: ttl renew: background thread starting"
          last_run = Time.now - rand(@node_ttl)

          until @ttl_should_exit.get
            last_run = renew_ttl(last_run)
            sleep 0.5
          end

          log.info "synapse: ttl renew: background thread exiting normally"
        }
      end
    end

    # Renew the TTL of @full_key if more than @node_ttl seconds has passed
    # between `Time.now` and `last_refresh`.
    # Returns the last refresh time *after performing the renewal.*
    # If the TTL *is* renewed, it will return `Time.now`.
    # Otherwise, it will return `last_refresh`.
    def renew_ttl(last_refresh)
      elapsed = Time.now - last_refresh

      if elapsed >= @node_ttl
        node_path = @full_key.get

        if node_path.nil?
          log.info "nerve: ttl renew: not touching ZK node because path not set"
        else
          begin
            @zk.set(node_path, @data)
            log.info "nerve: ttl renew: touched ZK node at #{node_path}"
            statsd.increment('nerve.reporter.zk.ttl.renew', tags: ["zk_cluster:#{@zk_cluster}", "result:success"])
          rescue ::Zookeeper::Exceptions::NoNode, ZK::Exceptions::NoNode
            log.info "nerve: ttl renew: failed to touch ZK node because node not found: #{node_path}"
            statsd.increment('nerve.reporter.zk.ttl.renew', tags: ["zk_cluster:#{@zk_cluster}", "result:fail", "reason:no_node"])
          rescue *ZK_CONNECTION_ERRORS => e
            log.info "nerve: ttl renew: Zookeeper connection issue: #{e}"
            statsd.increment('nerve.reporter.zk.ttl.renew', tags: ["zk_cluster:#{@zk_cluster}", "result:fail", "reason:connection_error"])
          end
        end

        # last_refresh can be set regardless of whether or not @zk.set is called.
        # If @zk.set is called, then it's obvious that it should be set.
        # If @zk.set is *not* called, it can only be called after @full_key
        # is set, which happens when the node was just written.
        return Time.now
      end

      return last_refresh
    end

    def stop_ttl_renew_thread
      @ttl_should_exit.set(true)
      @ttl_thread.join unless @ttl_thread.nil?
    end
  end
end

