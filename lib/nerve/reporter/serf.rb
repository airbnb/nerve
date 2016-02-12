require 'nerve/reporter/base'

class Nerve::Reporter
  class Serf < Base
    def initialize(service)

      # Set default parameters - the defaults are sane so nothing needed.
      @config_dir = service['serf_config_dir'] || '/etc/serf'
      @name       = service['name']
      # please note that because of
      # https://github.com/airbnb/smartstack-cookbook/blob/master/recipes/nerve.rb#L71
      # the name won't just be the name you gave but name_port. this allows a same
      # service to be on multiple ports of a same machine.

      # FIXME: support IPv6?
      @data        = "#{service['host']}:#{service['port']}"
      @config_file = File.join(@config_dir,"zzz_nerve_#{@name}.json")
      File.unlink @config_file if File.exists? @config_file
    end

    def start()
      log.info "nerve: started the maintain the tag #{@name} with Serf"

      # Notes on WHY things are done in a certain way. It's not obvious at all
      # OK so here is the challenge: to persist tags, we write them in the file 
      # /etc/serf/zzz_nerve_servicename.json, and reload. Unlike zookeeper, if
      # we stop nerve there is no clearing up of this. So if we delete a service
      # from a server, then the config file (and the tag in memory if serf isn't 
      # restarted) might persist.
      #
      # First I thought, let's just read the config and delete what is not there
      # but that doesn't work because modules don't have access to the config,
      # and I don't want to patch the general system to make config into $config
      # which might (or might not?) basically break the object model.
      #
      # There is one thing that I know, it's that I can force the module to update
      # the files at startup. Therefore, only the files that have a recent stamp
      # can be kept, and the others deleted. To avoid any kind of race condition
      # here is the process I found:
      # 1/ startup nerve, write necessary files, launch a timer that will update
      #    in two seconds
      # 2/ after the update, wait another two seconds, and any file older than
      #    three seconds will be wiped.
      # 
      # This system assumes that the various threads will have written their
      # files after four seconds - which is kind of reasonnable IMHO

      @cleanup_thread = Thread.new do
        sleep 2
        FileUtils.touch @config_file if File.exists? @config_file
        sleep 2
        must_hup = false
        oldest = Time.new.to_i - 3
        Dir.glob(File.join(@config_dir,'zzz_nerve_*.json')).each do |file|
          if File.stat(file).mtime.to_i < oldest
            log.info "cleaning up old file #{file} from serf config"
            File.unlink(file)
            must_hup = true
          end
        end
        log.info "reload serf since files have changed"
        system("/usr/bin/killall -HUP serf")
      end

    end

    def report_up()
      update_data(false)
    end

    def report_down
      File.unlink(@config_file)
      system("/usr/bin/killall -HUP serf")
    end

    def update_data(new_data='')
      @data = new_data if new_data
      File.write(@config_file, JSON.generate({tags:{"smart:#{@name}"=>@data}}))
      system("/usr/bin/killall -HUP serf")
    end

    def ping?
      # for now return true.
      return true
    end
  end
end