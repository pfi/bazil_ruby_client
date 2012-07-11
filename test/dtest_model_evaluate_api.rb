require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'


TestCase 'Bazil-server evaluate cross_validation' do
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

  test 'cross_validation_with_invalid_method', :params => ['saitama', '', true] do
    config = {'num_folds' => 3}
    begin
      result = model.evaluate(param, config)
      abort
    rescue => e
      expect_true(true)
    end
  end

  test 'cross_validation', :params => [2, 3, 4, 5] do
    config = {'num_folds' => param}
    result = model.evaluate('cross_validation', config)
    expect_true(param, result['folds'].size)
  end
end
