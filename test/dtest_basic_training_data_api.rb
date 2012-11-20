require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'

TestCase 'Bazil-server training-data' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'

  beforeCase { setup_environment }
  before { create_default_application }
  before { create_random_model }

  after { delete_random_model }
  after { delete_default_application }
  afterCase { cleanup_environment }

  test 'put_get' do
    assert_equal(0, get_training_data_size)

    training_data = {'red' => 'bull'}
    result = model.put_training_data(training_data)
    expect_equal(1, result['id'])

    assert_equal(1, get_training_data_size)

    got_training_data = model.training_data(1)
    expect_equal(1, got_training_data['id'])
    expect_equal(nil, got_training_data['annotation'])
    expect_equal(training_data, got_training_data['data'])
  end

  test 'put_invalid_training_data' do
    assert_error(Bazil::APIError) { # TODO: check message
      model.put_training_data({'nested' => {'key' => 'value'}})
    }
    expect_equal(0, get_training_data_size)
  end

  # TODO: add tests for directly POSTing invalid data which cannot be sent via Bazil::Model (e,g, missing 'config')

  test 'put_invalid_data', :params => [0, 'saitama', true, nil, [1]] do
    assert_error(Bazil::APIError) { # TODO: check message
      model.put_training_data(param)
    }
    expect_equal(0, get_training_data_size)
  end

  # TODO: activate this test after providing post to the SharedContext
=begin
  test 'put_broken_data' do
    result = JSON.parse(post.call("G{}", "/apps/#{app_name}/models/#{model_name}/training_data", {}).body)
    expect_true(result.has_key?('errors'))
    expect_true(result['errors'].size > 0)
  end
=end

  test 'delete_invalid_id', :params => [0, 'saitama'] do
    assert_error(Bazil::APIError) {
      model.delete_training_data(param)
    }
  end

  test 'put_delete' do
    result = model.put_training_data({'red' => 'bull'})
    training_data_id = result['id']
    assert_equal(1, get_training_data_size)

    model.delete_training_data(training_data_id)
    assert_equal(0, get_training_data_size)
  end

  test 'only_put' do
    10.times { |i|
      result = model.put_training_data({'red' => 'bull'}, nil)
      training_data_id = result['id']
      assert_equal(i + 1, get_training_data_size)
    }
    assert_equal(10, get_training_data_size)
  end

  test 'update_invalid_id', :params => [0, 'gunma'] do
    assert_error(Bazil::APIError) { # TODO: check message
      model.update_training_data(param, nil, {'k' => 'v'})
    }
  end

  test 'put_update' do
    result = model.put_training_data({'red' => 'bull', 'this' => 'will be removed'})
    training_data_id = result['id']

    model.update_training_data(training_data_id, nil, {'red' => 'blue'})

    got_training_data = model.training_data(training_data_id)
    expect_equal(training_data_id, got_training_data['id'])
    expect_equal(nil, got_training_data['annotation'])
    expect_equal({'red' => 'blue'}, got_training_data['data'])
  end

  test 'put_update_with_annotation' do
    training_data = {'red' => 'bull'}
    result = model.put_training_data(training_data)
    training_data_id = result['id']

    model.update_training_data(training_data_id, 'wing', nil)

    got_training_data = model.training_data(training_data_id)
    assert_equal(training_data_id, got_training_data['id'])
    assert_equal(training_data, got_training_data['data'])
    expect_equal('wing', got_training_data['annotation'])
  end

  test 'delete_all_training_data' do
    10.times do |i|
      training_data = {'f' => i}
      result = model.put_training_data(training_data)
      assert_equal(i + 1, result['id'])
    end

    assert_equal(10, get_training_data_size)
    model.clear_training_data
    assert_equal(0, get_training_data_size)

    # ids of training_data will be reset.
    10.times do |i|
      training_data = {'f' => i}
      result = model.put_training_data(training_data)
      assert_equal(i + 1, result['id'])
    end
  end
end
