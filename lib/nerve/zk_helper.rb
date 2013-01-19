module Nerve
  class ZKHelper
    include Base
    include Logging

    def initialize(opts)
      %w{path key}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
        instance_variable_set("@#{required}",opts[required])
        log.debug "set @#{required} to #{opts[required]}"
      end
      save_data(opts['data'] ? opts['data'] : '')
      @key.insert(0,'/') unless @key[0] == '/'

      log.info "waiting to connect to zookeeper"
      @zk = ZK.new(@path)
      log.debug "created zk connection to #{@path}"
    end

    def report_up()
      zk_save
    end

    def report_down
      zk_delete
    end

    def update_data(new_data='')
      save_data(new_data)
      zk_save
    end

    def ping?
      return @zk.ping?
    end

    private

    def zk_delete
      @zk.delete(@key, :ignore => :no_node)
    end

    def zk_save
      begin
        @zk.set(@key,format_data(data))
      rescue ZK::Exceptions::NoNode => e
        @zk.create(node,:data => @data, :mode => :ephemeral)
      end
    end

    def save_data(data)
      case data.class
      when Hash
        @data = data.to_json
      else
        @data = data
      end
    end

  end
end
