require 'nerve/reporter/base'
require 'net/http'
require 'thread'
require 'json'
require 'zk'


class Nerve::Reporter
  class ZookeeperExhibitor < Base
    DEFAULT_EXHIBITOR_POLL_INTERVAL = 10
    @@zk_pool = {}
    @@zk_pool_count = {}
    @@zk_pool_lock = Mutex.new

    def initialize(service)
      %w{exhibitor_url zk_path}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless service[required]
      end
      # Since we pool we get one connection per zookeeper cluster
      @exhibitor_url = service['exhibitor_url']
      @exhibitor_user = service['exhibitor_user']
      @exhibitor_password = service['exhibitor_password']
      @exhibitor_poll_interval = service['exhibitor_poll_interval'] || DEFAULT_EXHIBITOR_POLL_INTERVAL
      @zk_connection_string = fetch_hosts_from_exhibitor
      @data = parse_data(get_service_data(service))

      @zk_path = service['zk_path']
      @key_prefix = @zk_path + "/#{service['instance_id']}_"
      @full_key = nil
    end

    def poll
      @watcher = Thread.new do
        while true do
          new_zk_hosts = fetch_hosts_from_exhibitor
          if new_zk_hosts && @zk_connection_string != new_zk_hosts
            log.info "nerve: ZooKeeper ensamble changed, going to reconnect"
            stop
            @zk_connection_string = new_zk_hosts
            start
            report_up
            break
          end
          sleep @exhibitor_poll_interval
        end
      end
    end

    def fetch_hosts_from_exhibitor
      uri = URI(@exhibitor_url)
      req = Net::HTTP::Get.new(uri.request_uri)
      if @exhibitor_user && @exhibitor_password
        req.basic_auth(@exhibitor_user, @exhibitor_password)
      end
      req.add_field('Accept', 'application/json')
      res = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end

      if res.code.to_i != 200
        log.error "Exhibitor poll failed: #{res.code}: #{res.body}"
        return nil
      end
      hosts = JSON.load(res.body)
      log.debug hosts
      zk_hosts = hosts['servers'].map { |s| s.concat(':' + hosts['port'].to_s) }
      zk_hosts.sort.join(',')
    end


    def start()
      log.info "nerve: waiting to connect to zookeeper to #{@zk_connection_string}"
      # Ensure that all Zookeeper reporters re-use a single zookeeper
      # connection to any given set of zk hosts.
      @@zk_pool_lock.synchronize {
        unless @@zk_pool.has_key?(@zk_connection_string)
          log.info "nerve: creating pooled connection to #{@zk_connection_string}"
          @@zk_pool[@zk_connection_string] = ZK.new(@zk_connection_string, :timeout => 5)
          @@zk_pool_count[@zk_connection_string] = 1
          poll
          log.info "nerve: successfully created zk connection to #{@zk_connection_string}"
        else
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
      zk_delete
    end

    def ping?
      return @watcher.alive? && @zk.connected? && @zk.exists?(@full_key || '/')
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

