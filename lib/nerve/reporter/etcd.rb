require 'nerve/reporter/base'
require 'etcd'

class Nerve::Reporter
  class Etcd < Base
    def initialize(service)
      %w{etcd_hosts instance_id host port}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless service[required]
      end
      @hosts = service['etcd_hosts'].shuffle
      path = service['etcd_path'] || '/'
      @key = path.split('/').push(service['instance_id']).join('/')
      @data = parse_data({'host' => service['host'], 'port' => service['port'], 'name' => service['instance_id']})
    end

    def start()
      log.info "nerve: waiting to connect to etcd at #{@path}"
      @hosts.each do |h|
        host, port = h.split(':')
        port = port || 4003
        @etcd = ::Etcd.client(:host => host, :port => port)

        connected =
          begin
            @etcd.leader
          rescue
            false
          end
        break if connected
      end
      log.info "nerve: successfully created etcd connection to #{@key}"
    end

    def stop()
       report_down
       @etcd = nil
    end

    def report_up()
      etcd_save
    end

    def report_down
      etcd_delete
    end

    def update_data(new_data='')
      @data = parse_data(new_data)
      etcd_save
    end

    def ping?
      if @full_key
        etcd_save
      else
        @etcd.leader
      end
    end

    private

    def etcd_delete
      return unless @etcd and @full_key
      begin
        @etcd.delete(@full_key)
      rescue ::Etcd::KeyNotFound
      rescue Errno::ECONNREFUSED
      end
    end

    def etcd_create
      @full_key = @etcd.create_in_order(@key, :value => @data).key
      log.info "Created etcd node path #{@full_key}"
    end

    def etcd_save
      return etcd_create unless @full_key
      begin
        @etcd.set(@key, :value => @data, ttl => 30)
      rescue ::Etcd::KeyNotFound
        etcd_create
      end
    end
  end
end

