require 'rubygems'
require 'json'
require 'set'

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

    annotations = SortedSet.new
    train_data, classify_data = gen_data('random3')
    train_data.each { |random_data|
      annotations.add(random_data['annotation'])
      model.train(random_data['annotation'], random_data['data'])
    }

    set :annotations, annotations
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
    expect_equal(annotations, SortedSet.new(result_field['feature_weights'].keys))
  end

  # We want to write like 'test 'feature_weights_with_return_annotations', :params => 0..annotations.size do'
  test 'feature_weights_with_return_annotations' do
    returns = annotations.to_a.sort
    data = {'f1' => 1.0}
    returns.size.times { |i|
      expected = returns[0..i]
      result = model.trace_with_config('feature_weights', data, {'return_annotations' => expected})
      assert_true(result.has_key?('result'))
      expect_equal(expected, result['result']['feature_weights'].keys.sort, "{'return_annotations': #{expected}} failed: actual = #{result['result']['feature_weights'].keys.sort}")
    }
  end
end
