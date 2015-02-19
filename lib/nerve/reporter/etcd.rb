require 'nerve/reporter/base'
require 'etcd'

class Nerve::Reporter
  class Etcd < Base
    def initialize(service)
      %w{etcd_host instance_id host port}.each do |required|
        raise ArgumentError, "missing required argument #{required} for new service watcher" unless service[required]
      end
      @host = service['etcd_host']
      @port = service['etcd_port'] || 4003
      path = service['etcd_path'] || '/'
      @path = path.split('/').push(service['instance_id']).join('/')
      @data = parse_data({'host' => service['host'], 'port' => service['port'], 'name' => service['instance_id']})
      @key = nil
      @ttl = (service['check_interval'] || 0.5) * 5
      @ttl = @ttl.ceil
    end

    def start()
      log.info "nerve: connecting to etcd at #{@host}:#{@port}"
      @etcd = ::Etcd.client(:host => @host, :port => @port)
      log.info "nerve: successfully created etcd connection to #{@host}:#{@port}"
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
      # nothing in nerve calls this, but implement it like the zookeeper
      # reporter just for fun.
      @data = parse_data(new_data)
      etcd_save
    end

    def ping?
      # we get a ping every check_interval.
      if @key
        # we have made a key: save it to prevent the TTL from expiring.
        etcd_save
      else
        # we haven't created a key, so just frob the etcd API to assure that
        # it's alive.
        @etcd.leader
      end
    end

    private

    def etcd_delete
      return unless @etcd and @key
      begin
        @etcd.delete(@key)
      rescue ::Etcd::NotFile
      rescue Errno::ECONNREFUSED
      end
    end

    def etcd_create
      # we use create_in_order to create a unique key under our path,
      # permitting multiple registrations from the same instance_id.
      @key = @etcd.create_in_order(@path, :value => @data, :ttl => @ttl).key
      log.info "registered etcd key #{@key} with value #{@data}, TTL #{@ttl}"
    end

    def etcd_save
      return etcd_create unless @key
      @etcd.set(@key, :value => @data, :ttl => @ttl)
    end
  end
end

