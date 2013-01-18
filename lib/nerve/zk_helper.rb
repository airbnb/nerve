module Nerve
  class ZKHelper
    include Logging
    def initialize(path)
      log.debug "creating new zk at #{path}"
      log.debug "path.class is #{path.class}"
      log.debug "path.inspect is #{path.inspect}"
      @zk = ZK.new(path)
      log.debug "created zk connect to @{path}"
    end

    def create_service_node  
      # create ephemeral node in zookeeper under <root>/services/<service name>/<instance_id>
      # write json hash {ip:ip, host:host, port:port} into ephemeral node
    end

    def delete(path)
      log.debug "trying to delete #{path}"
      @zk.delete(path, :ignore => :no_node)
      log.debug "path #{path} deleted"
    end

    def create_ephemeral_node(node, data="")
      node = prepend_slash(node)
      data = format_data(data)
      log.debug "creating ephemeral node at '#{node}' with #{data}"
      @zk.delete(node, :ignore => :no_node)
      # TODO(mkr): not sure if we should do this, as we are chrooting
      # to the base dir
      # create_path(File.dirname(node))
      @zk.create(node, :data => data.to_json, :mode => :ephemeral)
    end

    def ensure_ephemeral_node(node,data='')
      log.debug "ensuring ephemeral node #{node} exists"
      node = prepend_slash(node)
      data = format_data(data)
      @zk.create(node, :data => data.to_json, :mode => :ephemeral, :ignore => :node_exists)
    end

    def ping?
      #log.debug "pinging zk"
      return @zk.ping?
    end

    def update(node,data='')
      node = prepend_slash(node)
      log.debug "updating node #{node}"
      @zk.set(node,data.to_json)
    end

    def format_data(data)
      return data.to_json if data.class == Hash
      return data
    end

    # prepend slash if there is not one already
    def prepend_slash(path='')
      path.insert(0,'/') unless path[0] == '/'
      return path
    end

    # recursively creates a zk path
    def create_path(path)
      return if @zk.exists?(path)
      create_path File.dirname(path)
      @zk.create(path)
    end

  end
end
