require 'fileutils'

module Nerve
  class ZooKeeperProcess < Process
    attr_reader :myid
    attr_reader :cluster_size

    attr_reader :bindir
    attr_reader :prefix

    attr_reader :zoocfg

    attr_reader :zk

    # options - Hash of client options
    #
    #    :myid         - Integer id of server in cluster, standalone mode if not specified
    #    :cluster_size - Integer number of servers in the cluster
    #
    #    :bindir       - String path to bin directory in ZooKeeper installation
    #    :prefix       - String path to this ZooKeeper instance's config, data, and log files
    #
    #    :zoocfg       - Hash misc ZooKeeper options, written to zoo.cfg
    def initialize(options={})
      @myid         = options[:myid] || 1
      @cluster_size = options[:cluster_size] || 1

      default_prefix = '/tmp/nerve-spec-zk'
      default_prefix += "-#{myid}" if myid

      @bindir = options[:bindir] || ENV['ZOOKEEPER_BINDIR'] || '/opt/zookeeper/bin'
      @prefix = options[:prefix] || default_prefix

      @zoocfg = options[:zoocfg] || {}

      command = File.join(@bindir, 'zkServer')
      options = {
        :arguments => [
          'start-foreground'
        ],
        :environment => {
          'ZOOCFGDIR' => File.join(@prefix, 'conf'),
          'ZOO_LOG_DIR' => File.join(@prefix, 'log')
        }
      }
      super(command, options)
    end

    def start
      create_directories
      write_configs
      super
      start_client
    end

    def stop(options={})
      stop_client rescue nil
      super(options)
    ensure
      destroy_directories unless options[:preserve]
    end

    def up?(timeout=0.1)
      !!zk.get('/')
    end

    def client_port
      calculate_client_port(myid)
    end

    def quorum_port
      calculate_quorum_port(myid)
    end

    def leader_election_port
      calculate_leader_election_port(myid)
    end

    def client_socket
      "localhost:#{client_port}"
    end

    private

    def create_directories
      Dir.mkdir(prefix) unless Dir.exists?(prefix)
      %w{conf data log}.each do |dir|
        path = File.join(prefix, dir)
        Dir.mkdir(path) unless Dir.exists?(path)
      end
    end

    def generate_zoocfg
      overrides = {
        :dataDir    => File.join(prefix, 'data'),
        :clientPort => calculate_client_port(myid || 1)
      }

      if cluster_size
        1.upto(cluster_size) do |id|
          q_port  = calculate_quorum_port(id)
          le_port = calculate_leader_election_port(id)
          overrides["server.#{id}"] = "localhost:#{q_port}:#{le_port}"
        end
      end

      zoocfg.merge(overrides)
    end

    def write_configs
      path = File.join(prefix, 'conf', 'zoo.cfg')
      File.open(path, 'w') do |file|
        generate_zoocfg.each_pair do |key,value|
          file.write("#{key}=#{value}\n")
        end
      end

      if myid
        path = File.join(prefix, 'data', 'myid')
        File.open(path, 'w') { |file| file.write(myid) }
      end
    end

    def destroy_directories
      FileUtils.rm_rf(prefix)
    end

    def calculate_client_port(id)
      2180 + id
    end

    def calculate_quorum_port(id)
      2280 + id
    end

    def calculate_leader_election_port(id)
      2380 + id
    end

    def start_client
      @zk = ZK.new("localhost:#{client_port}",
        :timeout => 1,
        :connect => true)
    end

    def stop_client
      shave_yak
      @zk.close!
      @zk = nil
    end

    def shave_yak
      # The zookeeper gem unnecessarily waits on continuations after the
      # connection has closed. This incantation forcibly removes any pending
      # continuations from the registry so that we shutdown quickly.
      @zk.cnx.czk.instance_variable_get(:@reg).in_flight.clear
    end

  end
end
