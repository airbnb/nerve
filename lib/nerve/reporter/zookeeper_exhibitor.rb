require 'nerve/reporter/base'
require 'net/http'
require 'thread'
require 'json'
require 'zk'


class Nerve::Reporter
  class ZookeeperExhibitor < Base
    DEFAULT_EXHIBITOR_POLL_INTERVAL = 10
    def initialize(service)
      %w{exhibitor_url zk_path instance_id host port}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless service[required]
      end
      @exhibitor_url = service['exhibitor_url']
      @exhibitor_user = service['exhibitor_user']
      @exhibitor_password = service['exhibitor_password']
      @exhibitor_poll_interval = service['exhibitor_poll_interval'] || DEFAULT_EXHIBITOR_POLL_INTERVAL
      @zk_hosts = fetch_hosts_from_exhibitor
      @zk_path = service['zk_path']
      @path = @zk_hosts.shuffle.join(',') + @zk_path
      @data = parse_data({'host' => service['host'], 'port' => service['port'], 'name' => service['instance_id']})

      @key = "/#{service['instance_id']}_"
      @full_key = nil
    end

    def start
      log.info "nerve: waiting to connect to zookeeper at #{@path}"
      @zk = ZK.new(@path)
      poll
      log.info "nerve: successfully created zk connection to #{@path}"
    end

    def stop
      log.info "nerve: closing zk connection at #{@path}"
      report_down
      @zk.close!
    end

    def report_up
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
      @watcher.alive? && @zk && @zk.connected?
    end

    private

    def poll
      @watcher = Thread.new do
        while true do
          new_zk_hosts = fetch_hosts_from_exhibitor
          if new_zk_hosts && @zk_hosts != new_zk_hosts
            log.info "nerve: ZooKeeper ensamble changed, going to reconnect"
            @zk_hosts = new_zk_hosts
            @path = @zk_hosts.shuffle.join(',') + @zk_path
            stop
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
      req = Net::HTTP::Get.new(uri)
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
      hosts['servers'].map { |s| s.concat(':' + hosts['port'].to_s) }
    end

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
