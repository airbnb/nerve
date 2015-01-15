FactoryGirl.define do
  factory :check, :class => Hash do
    type       'tcp'
    timeout    0.2
    rise       3
    fall       2

    trait :http do
      type   'http'
      uri    '/health'
    end

    initialize_with { Hash[attributes.map{|k,v| [k.to_s,v]}] }
    to_create {}
  end
end
