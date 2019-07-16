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
The information it reports can be used to take action from a centralized automation center: action like scaling distributed systems up or down or alerting ops or engineering about downtime.

## Installation ##

To download and run the nerve binary, first install a version of ruby. Then,
install nerve with:

```bash
$ mkdir -p /opt/smartstack/nerve

# If you want to install specific versions of dependencies such as an older
# version of the aws-sdk, the docker-api, etc, gem install that here *before*
# gem installing nerve. This is also where you would gem install
# custom reporters.

# If you are on Ruby 2.X use --no-document instead of --no-ri --no-rdoc
$ gem install nerve --install-dir /opt/smartstack/nerve --no-ri --no-rdoc
```

This will download nerve and its dependencies into /opt/smartstack/nerve. You
might wish to omit the `--install-dir` flag to use your system's default gem
path, however this will require you to run `gem install nerve` with root
permissions. You can also install via bundler, but keep in mind you'll pick up
Nerve's version of library dependencies and possibly not the ones you need
for your infra/apps.

## Configuration ##

Nerve depends on a single configuration file, in json format.
It is usually called `nerve.conf.json`.
An example config file is available in `example/nerve.conf.json`.
The config file is composed of two main sections:

* `instance_id`: the name nerve will submit when registering services; makes debugging easier
* `heartbeat_path`: a path to a file on disk to touch as nerve makes progress. This allows you to work around https://github.com/zk-ruby/zk/issues/50 by restarting a stuck nerve.
* `services`: the hash (from service name to config) of the services nerve will be monitoring
* `service_conf_dir`: path to a directory in which each json file will be interpreted as a service with the basename of the file minus the .json extension

### Services Config ###

Each service that nerve will be monitoring is specified in the `services` hash.
The key is the name of the service, and the value is a configuration hash telling nerve how to monitor the service.
The configuration contains the following options:

* `host`: the default host on which to make service checks; you should make this your *public* ip to ensure your service is publicly accessible
* `port`: the default port for service checks; nerve will report the `host`:`port` combo via your chosen reporter
* `reporter_type`: the mechanism used to report up/down information; depending on the reporter you choose, additional parameters may be required. Defaults to `zookeeper`
* `check_interval`: the frequency with which service checks will be initiated; defaults to `500ms`
* `check_mocked`: whether or not health check is mocked, the host check always returns healthy and report up when the value is true
* `checks`: a list of checks that nerve will perform; if all of the pass, the service will be registered; otherwise, it will be un-registered
* `weight` (optional): a positive integer weight value which can be used to affect the haproxy backend weighting in synapse.
* `haproxy_server_options` (optional): a string containing any special haproxy server options for this service instance. For example if you wanted to set a service instance as a backup.
* `labels` (optional): an object containing user-defined key-value pairs that describe this service instance. For example, you could label service instances with datacenter information.

#### Zookeeper Reporter ####

If you set your `reporter_type` to `"zookeeper"` you should also set these parameters:

* `zk_hosts`: a list of the zookeeper hosts comprising the [ensemble](https://zookeeper.apache.org/doc/r3.1.2/zookeeperAdmin.html#sc_zkMulitServerSetup) that nerve will submit registration to
* `zk_path`: the path (or [znode](https://zookeeper.apache.org/doc/r3.1.2/zookeeperProgrammers.html#sc_zkDataModel_znodes)) where the registration will be created; nerve will create the [ephemeral node](https://zookeeper.apache.org/doc/r3.1.2/zookeeperProgrammers.html#Ephemeral+Nodes) that is the registration as a child of this path
* `use_path_encoding`: flag to turn on path encoding optimization, the canonical config data at host level (e.g. ip, port, az) is encoded using json base64 and written as zk child name, the zk child data will still be written for backward compatibility

#### Etcd Reporter ####

Note: Etcd support is currently experimental! 

If you set your `reporter_type` to `"etcd"` you should also set these parameters:

* `etcd_host`: etcd host that nerve will submit registration to
* `etcd_port`: port to connect to etcd.
* `etcd_path`: the path where the registration will be created; nerve will create a node with a 30s ttl that is the registration as a child of this path, and then update it every few seconds

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

#### Custom External Checks ####

If you would like to run a custom check but don't feel like trying to get it merged into this project, there is a mechanism for including external checks thanks to @bakins (airbnb/nerve#36).
Build your custom check as a separate gem and make sure to `bundle install` it on your system.

Ideally, you should name your gem `"nerve-watcher-#{type}"`, as that is what nerve will `require` on boot.
However, if you have a custom name for your gem, you can specify that in the `module` argument to the check.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
