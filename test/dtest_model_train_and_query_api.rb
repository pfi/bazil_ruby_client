require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'

TestCase 'Bazil-server train and query' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'model_train_and_query_api'

  beforeCase { setup_environment }
  before {
    create_default_application
    create_random_model
  }

  after {
    delete_random_model
    delete_default_application
  }
  afterCase { cleanup_environment }

  test 'random_distribution' do
    train_data, classify_data = gen_data('random')

    train_data.each { |random_data|
      model.train(random_data['label'], random_data['data'])
    }

    collect_result = classify(classify_data)
    expect_true(collect_result > 95)

    result = model.labels
    assert_equal(["NG", "OK"], result.sort)

    status = model.status
    expect_equal(1000, status['num_training_data'])
    expect_equal(1000, status['num_train_queries'])
    expect_equal(100, status['num_queries'])
    expect_equal(10, status['num_features'])  # maybe
    expect_equal(2, status['num_labels'])  # maybe
  end

  test 'random3_distribution' do
    train_data, classify_data = gen_data('random3')

    train_data.each { |random_data|
      model.train(random_data['label'], random_data['data'])
    }

    collect_result = classify(classify_data)
    expect_true(collect_result > 95)

    result = model.labels
    assert_equal(["1", "2", "3"], result.sort)

    status = model.status
    expect_equal(1000, status['num_training_data'])
    expect_equal(1000, status['num_train_queries'])
    expect_equal(100, status['num_queries'])
    expect_equal(10, status['num_features'])  # maybe
    expect_equal(3, status['num_labels'])  # maybe
  end

  test 'train_with_invalid_data', :params => [nil, true, [1, 2], {'key' => 'value'}] do
    assert_error(Bazil::APIError) {
      result = model.train('invalid', {'k' => param})
    }
  end
end

TestCase 'Bazil-server retrain' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'model_train_and_query_api'

  beforeCase { setup_environment }
  before {
    create_default_application
    create_random_model
  }

  after {
    delete_random_model
    delete_default_application
  }
  afterCase { cleanup_environment }

  test 'random_distribution', :params => ['random', 'random3'] do
    train_data, classify_data = gen_data(param)

    train_data.each { |random_data|
      result = model.train(random_data['label'], random_data['data'])
    }

    collect_result = classify(classify_data)
    expect_true(collect_result > 95)

    result = model.retrain()
    expect_true(result.has_key?('elapsed_time'))
    expect_true(train_data.size, result['total'])
    retrain_result = classify(classify_data)
    expect_equal(retrain_result, collect_result)

    # once more
    result = model.retrain()
    assert_true(result.has_key?('elapsed_time'))
    assert_true(train_data.size, result['total'])
    retrain_result = classify(classify_data)
    expect_equal(retrain_result, collect_result)
  end

  test 'random_distribution_with_times', :params => ['random', 'random3'] do
    train_data, classify_data = gen_data(param)

    train_data.each { |random_data|
      result = model.train(random_data['label'], random_data['data'])
    }

    collect_result = classify(classify_data)
    expect_true(collect_result > 95)

    result = model.retrain()
    expect_true(result.has_key?('elapsed_time'))
    expect_true(train_data.size, result['total'])
    retrain_result = classify(classify_data)
    expect_equal(retrain_result, collect_result)

    result = model.retrain({:times => 5})
    assert_true(result.has_key?('elapsed_time'))
    assert_true(train_data.size * 5, result['total'])
    retrain_result = classify(classify_data)
    expect_equal(retrain_result, collect_result)
  end

  test 'random_distribution with range' do
    train_data, classify_data = gen_data('random')

    train_data.each { |random_data|
      result = model.train(random_data['label'], random_data['data'])
    }

    collect_result = classify(classify_data)
    expect_true(collect_result > 95)

    result = model.retrain({:from => 100, :to =>  400})
    assert_true(result.has_key?('elapsed_time'))
    expect_equal(300, result['total'])
    retrain_result = classify(classify_data)
    expect_true((collect_result - 5 < retrain_result and retrain_result < collect_result + 5))

    result = model.retrain({:from => 700, :to =>  800, :times => 2})
    assert_true(result.has_key?('elapsed_time'))
    expect_equal(100 * 2, result['total'])
    retrain_result = classify(classify_data)
    expect_true((collect_result - 5 < retrain_result and retrain_result < collect_result + 5))
  end
end
