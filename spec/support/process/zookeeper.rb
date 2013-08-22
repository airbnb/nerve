require 'fileutils'

module Nerve
  module Test

    class ZooKeeperProcess < Process
      attr_reader :myid
      attr_reader :cluster_size

      attr_reader :bindir
      attr_reader :prefix

      attr_reader :zoocfg

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
        @myid         = options[:myid]
        @cluster_size = options[:cluster_size]

        default_prefix = '/tmp/nerve-spec-zk'
        default_prefix += "-#{myid}" if myid

        @bindir = options[:bindir] || ENV['ZOOKEEPER_BINDIR'] || '/opt/zookeeper/bin'
        @prefix = options[:prefix] || default_prefix

        @zoocfg = options[:zoocfg] || {}

        command = File.join(@bindir, 'zkServer.sh')
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
      end

      def stop(options={})
        retval = super
        destroy_directories unless options[:preserve]
        retval
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

    end
  end
end
