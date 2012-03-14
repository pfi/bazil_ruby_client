require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'

SharedContext 'training_data_sort_query_test_util' do
  def prepare_training_data
    # data with label
    [['D', ['god', 10]], ['C++', ['owkn', -1]], ['C#', ['normal', 1000]]].each { |label, value|
      training_data = {'f1' => value[0], 'f2' => value[1]}
      model.train(label, training_data)
    }

    set :training_data_size, get_training_data_size
  end

  def before_case_set
    setup_environment

    create_default_application
    create_random_model
    prepare_training_data
  end

  def after_case_set
    delete_random_model
    delete_default_application
    cleanup_environment
  end
end

TestCase 'Bazil-server training-data-query-id-sort' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'training_data_sort_query_test_util'

  beforeCase do
    before_case_set
  end

  afterCase do
    after_case_set
  end

  test 'asc' do
    sort_conditions = [{:target => 'id', :asc => true}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query})['training_data'].map { |e| e['id'] }
    result.each_cons(2) { |a, b|
      expect_true(a < b)
    }
  end

  test 'asc_with_page_size' do
    sort_conditions = [{:target => 'id', :asc => true}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query, :page => 3, :page_size => 1})['training_data'].map { |e| e['id'] }
    assert_equal(1, result.size)
    expect_equal(3, result[0])
  end

  test 'desc' do
    sort_conditions = [{:target => 'id', :asc => false}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query})['training_data'].map { |e| e['id'] }
    result.each_cons(2) { |a, b|
      expect_true(a > b)
    }
  end

  test 'desc_with_page_size' do
    sort_conditions = [{:target => 'id', :asc => false}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query, :page => 3, :page_size => 1})['training_data'].map { |e| e['id'] }
    assert_equal(1, result.size)
    expect_equal(1, result[0])
  end
end

# TODO: add test to check combination of sorting operations and page/pagesize.
