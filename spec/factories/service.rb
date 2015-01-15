FactoryGirl.define do
  factory :service, :class => Hash do
    sequence(:name)    {|n| "service_check_#{n}"}
    instance_id        'public_hostname.example.com'
    host               'localhost'
    port               3000
    checks             { create_list(:check, checks_count) }

    trait :zookeeper do
      reporter_type    'zookeeper'
      zk_hosts         ['localhost:2181']
      zk_path          { "/nerve/services/#{name}/services" }
    end

    # set up some service checks
    transient do
      checks_count 1
    end

    # thanks to https://stackoverflow.com/questions/10032760
    initialize_with { Hash[attributes.map{|k,v| [k.to_s,v]}] }
    to_create {}
  end
end
