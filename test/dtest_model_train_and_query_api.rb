require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'

SharedContext 'model_train_and_query_api' do
  def gen_data(algorithm)
    sample = gen_random_distribution(algorithm)
    train_data = sample[0...1000]
    classify_data = sample[1000..-1]
    [train_data, classify_data]
  end

  def rand_normal(mu, sigma)
    alpha = rand
    beta = rand
    mu + Math.sqrt(-2 * Math.log(alpha)) * Math.sin(2 * Math::PI * beta) * sigma
  end

  def make_random(mus, sigma, dim)
    [].tap { |a|
      dim.times { |i|
        a << rand_normal(mus[i % mus.size], sigma)
      }
    }
  end

  def gen_random_data
    if rand(2) == 0
      label = "OK"
      mu = 1.0
    else
      label = "NG"
      mu = -1.0
    end
    [label, make_random([mu], 1.0, 10)]
  end

  def naive_array_rotate(a, c)
    c %= a.size
    a[c..-1].to_a + a[0...c].to_a
  end

  def gen_random_data3
    i = rand(3)
    [["1", "2", "3"][i], make_random(naive_array_rotate([3, 0, -3], i), 1.0, 10)]
  end

  def gen_random_distribution(algorithm)
    if algorithm == "random"
      [].tap { |a|
        1100.times {
          label, data = gen_random_data
          a << {'label' => label, 'data' => {}.tap { |m| data.each_with_index { |d, i| m["f#{i}"] = d }}}
        }
      }
    else
      [].tap { |a|
        1100.times {
          label, data = gen_random_data3
          a << {'label' => label, 'data' => {}.tap { |m| data.each_with_index { |d, i| m["f#{i}"] = d }}}
        }
      }
    end
  end
end

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

    collect_result = 0
    classify_data.each { |random_data|
      max_label, = model.query(random_data['data'])
      collect_result +=1 if random_data['label'] == max_label
    }
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

    collect_result = 0
    classify_data.each { |random_data|
      max_label, = model.query(random_data['data'])
      collect_result +=1 if random_data['label'] == max_label
    }
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
    assert_error(RuntimeError) {
      result = model.train('invalid', {'k' => param})
    }
  end
end
