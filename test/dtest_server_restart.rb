require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'


TestCase 'Bazil-server restart' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'model_train_and_query_api'

  beforeCase { 
    setup_environment
    create_default_application
    create_random_model

    train_data, classify_data = gen_data('random3')
    train_data.each { |random_data|
      model.train(random_data['annotation'], random_data['data'])
    }
  }

  afterCase {
    delete_random_model
    delete_default_application
    cleanup_environment
  }

  test 'retrain_at_restart' do
    data = gen_random_data3.last
    data = {}.tap { |m| data.each_with_index { |d, i| m["f#{i}"] = d }}
    max_label, result = model.query(data)

    restart_bazil

    restarted_max_label, restarted_result = model.query(data)
    expect_equal(max_label, restarted_max_label)
    expect_equal(result, restarted_result)
  end
end
