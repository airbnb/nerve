[![Build Status](https://travis-ci.org/airbnb/nerve.png?branch=master)](https://travis-ci.org/airbnb/nerve)

# Nerve

Nerve is a utility for tracking the status of machines and services.
It runs locally on the boxes which make up a distributed system, and reports state information to a distributed key-value store.
At Airbnb, we use Zookeeper as our key-value store.
The combination of Nerve and [Synapse](https://github.com/airbnb/synapse) make service discovery in the cloud easy!

## Motivation ##

We already use [Synapse](https://github.com/airbnb/synapse) to discover remote services.
However, those services needed boilerplate code to register themselves in [Zookeeper](http://zookeeper.apache.org/).
Nerve simplifies underlying services, enables code reuse, and allows us to create a more composable system.
It does so by factoring out the boilerplate into it's own application, which independenly handles monitoring and reporting.

Beyond those benefits, nerve also acts as a general watchdog on systems.
The information it reports can be used to take action from a certralized automation center: action like scaling distributed systems up or down or alerting ops or engineering about downtime.

## Installation ##

Add this line to your application's Gemfile:

    gem 'nerve'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nerve

## Configuration ##

Nerve depends on a single configuration file, in json format.
It is usually called `nerve.conf.json`.
An example config file is available in `example/nerve.conf.json`.
The config file is composed of two main sections:

* `instance_id`: the name nerve will submit when registering services; makes debugging easier
* `services`: the hash (from service name to config) of the services nerve will be monitoring
* `service_conf_dir`: path to a directory in which each json file will be interpreted as a service with the basename of the file minus the .json extension
* `listen_port`: TCP port on which Nerve will listen for ephemeral services
* `ephemeral_service_expiry`: number of seconds after which ephemeral services expire if they have not sent a heartbeat

### Services Config ###

Each service that nerve will be monitoring is specified in the `services` hash.
The key is the name of the service, and the value is a configuration hash telling nerve how to monitor the service.
The configuration contains the following options:

* `host`: the default host on which to make service checks; you should make this your *public* ip to ensure your service is publically accessible
* `port`: the default port for service checks; nerve will report the `host`:`port` combo via your chosen reporter
* `reporter_type`: the mechanism used to report up/down information; depending on the reporter you choose, additional parameters may be required. Defaults to `zookeeper`
* `check_interval`: the frequency with which service checks will be initiated; defaults to `500ms`
* `checks`: a list of checks that nerve will perform; if all of the pass, the service will be registered; otherwise, it will be un-registered

#### Zookeeper Reporter ####

If you set your `reporter_type` to `"zookeeper"` you should also set these parameters:

* `zk_hosts`: a list of the zookeeper hosts comprising the [ensemble](https://zookeeper.apache.org/doc/r3.1.2/zookeeperAdmin.html#sc_zkMulitServerSetup) that nerve will submit registration to
* `zk_path`: the path (or [znode](https://zookeeper.apache.org/doc/r3.1.2/zookeeperProgrammers.html#sc_zkDataModel_znodes)) where the registration will be created; nerve will create the [ephemeral node](https://zookeeper.apache.org/doc/r3.1.2/zookeeperProgrammers.html#Ephemeral+Nodes) that is the registration as a child of this path

### Checks ###

The core of nerve is a set of service checks.
Each service can define a number of checks, and all of them must pass for the service to be registered.
Although the exact parameters passed to each check are different, all take a number of common arguments:

* `type`: (required) the kind of check; you can see available check types in the `lib/nerve/service_watcher` dir of this repo
* `name`: (optional) a descriptive, human-readable name for the check; it will be auto-generated based on the other parameters if not specified
* `host`: (optional) the host on which the check will be performed; defaults to the `host` of the service to which the check belongs
* `port`: (optional) the port on which the check will be performed; like `host`, it defaults to the `port` of the service
* `timeout`: (optional) maximum time the check can take; defaults to `100ms`
* `rise`: (optional) how many consecutive checks must pass before the check is considered passing; defaults to 1
* `fall`: (optional) how many consecutive checks must fail before the check is considered failing; defaults to 1

### Runtime configuration (ephemeral services) ###

It's possible to announce services to Nerve at runtime.  Nerve, by default, binds to 127.0.0.1 and listens for TCP connections on port 1025 (you can change the port with the `listen_port` configuration option).  You can write a TCP client which connects to this port and sends JSON within the minimum heartbeat interval (60s, configured with `ephemeral_service_expiry`).  For example, you may run a service which sends the JSON service definition every 45 seconds.  Here's a sample Ruby announcer:


```ruby
module Nerve
  class Announcer
    attr_accessor :port
    attr_accessor :name
    attr_accessor :check_interval
    attr_accessor :timeout
    attr_accessor :rise
    attr_accessor :fall
    attr_accessor :type
    attr_accessor :uri

    def initialize
      @check_interval = 30
      @timeout = 300
      @rise = 1
      @fall = 3
      @type = "tcp"
      @uri = "/healthy" # only if @type is 'http'
    end

    def run
      if @name.nil?
        raise "Name must be defined"
      end
      if @port.nil?
        raise "Port must be defined"
      end
      log = Logger.new(STDERR)
      log.level = Logger::INFO

      @nerve_host = 'localhost'
      @nerve_port = 1025

      @zk_prod_servers = ['zk.host.name:2181']

      # Announce this service to nerve
      json = {
        "services" => {
          @name => {
            "port"            => @port.to_i,
            "check_interval"  => @check_interval,
            "checks" => [{
              "type"          => @type,
              "uri"           => @uri,
              "timeout"       => @timeout,
              "rise"          => @rise,
              "fall"          => @fall,
            }],
            "zk_hosts"        => @zk_prod_servers,
            "zk_path"         => "/production/services/#{name}/services",
            "host"            => Resolv.getaddress(Socket.gethostbyname(Socket.gethostname).first),
          },
        },
      }
      json = JSON.generate(json) + "\n"

      Thread.new(json) do |json|
        log.info "Announcing to Nerve: service '#{@name}' on local port #{@port}"
        # loopy loop
        loop do
          begin
            TCPSocket.open(@nerve_host, @nerve_port) do |s|
              s.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
              loop do
                s.write json
                s.flush
                sleep 45
              end
            end
          rescue => e
            log.error $!.inspect
            log.error $@
          end
          sleep 45
        end
      end
    end
  end
end
```



## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
