config = {
  'instance_name' => '$instance_id',
  'voter_status' => {
    'metric' => 'cpuidle',
    'hold' => '60',
    'up' => {
      'threshold' => '30',
      'condition' => '<',
    }
    'down' => {
      'threshold' => '70',
      'condition' => '>'
    },
  },
  'services' => {
    'monorails' =>{
      'port' => '80',
      'host' => '0.0.0.0',
      'zk_path' => '',
      'checks' => {
        'tcp' => {},
        'http' => {
          'uri' => '/health',
        },
      },
    },
  },  
}
