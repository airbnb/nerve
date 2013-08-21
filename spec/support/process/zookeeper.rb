require 'fileutils'

module Nerve
  module Test

    class ZooKeeperProcess < Process
      attr_reader :zoocfg
      attr_reader :prefix
      attr_reader :bindir

      # zoocfg - Hash ZooKeeper options, written to zoo.cfg
      # prefix - String path to this ZooKeeper instance's config, data, and log files
      # bindir - String path to unpacked ZooKeeper installation
      def initialize(zoocfg = nil, prefix = nil, bindir = nil)
        @zoocfg = zoocfg || { :tickTime => 2000, :clientPort => 2181 }
        @prefix = prefix || ENV['ZOOKEEPER_PREFIX'] || '/tmp/zk'
        @bindir = bindir || ENV['ZOOKEEPER_BINDIR'] || '/opt/zookeeper/bin'

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

      private

      def create_directories
        Dir.mkdir(prefix) unless Dir.exists?(prefix)
        %w{conf data log}.each do |dir|
          path = File.join(prefix, dir)
          Dir.mkdir(path) unless Dir.exists?(path)
        end
      end

      def write_configs
        # TODO(jtai): handle ports too?
        config = zoocfg.merge(:dataDir => File.join(prefix, 'data'))

        path = File.join(prefix, 'conf', 'zoo.cfg')
        File.open(path, 'w') do |file|
          config.each_pair do |key,value|
            file.write("#{key}=#{value}\n")
          end
        end

        # TODO(jtai): write myid?
      end

      def destroy_directories
        FileUtils.rm_rf(prefix)
      end

    end
  end
end
