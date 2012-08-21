require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'

TestCase 'Bazil-server trace feature_weights' do
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

  test 'trace_with_invalid_method', :params => ['saitama', '', true] do
    data = {'f1' => 1.0}
    begin
      result = model.trace(param, data)
      abort
    rescue => e
      expect_true(true)
    end
  end

  test 'feature_weights' do
    data = {'f1' => 1.0}
    result = model.trace('feature_weights', data)
    expect_true(result.has_key?('data'))
    expect_true(result.has_key?('result'))
    result_field = result['result']
    expect_true(result_field.has_key?('min_weight'))
    expect_true(result_field.has_key?('max_weight'))
    expect_true(result_field.has_key?('feature_weights'))
  end
end
