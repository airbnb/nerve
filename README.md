# Nerve

Nerve is a utility for tracking the status of machines and services.
It runs locally on the boxes which make up a distributed system, and reports state information to a distributed key-value store.
At Airbnb, we use Zookeeper as our key-value store.
The combination of Nerve and [Synapse](https://github.com/airbnb/synapse) make service discovery in the cloud easy!

## Motivation ##

We already use [Synapse](https://github.com/airbnb/synapse) to discover remote services.
However, those services needed boilerplate code to register themselves in [Zookeeper](zookeeper.apache.org/).
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
The config file is composed of three main sections: 

* `instance_id`: the name under which your services will be registered in zookeeper
* `machine_check`: configuration of the machine registration
* `service_checks`: configuration of the monitoring of services on this machine

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
