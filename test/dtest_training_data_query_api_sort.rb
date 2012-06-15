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

TestCase 'Bazil-server training-data-query-label-sort' do
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
    sort_conditions = [{:target => 'label', :asc => true}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query})['training_data'].map { |e| e['label'] }
    result.each_cons(2) { |a, b|
      expect_true(a < b)
    }
  end

  test 'asc_with_page_size' do
    sort_conditions = [{:target => 'label', :asc => true}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query, :page => 3, :page_size => 1})['training_data'].map { |e| e['label'] }
    assert_equal(1, result.size)
    expect_equal('D', result[0])
  end

  test 'desc' do
    sort_conditions = [{:target => 'label', :asc => false}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query})['training_data'].map { |e| e['label'] }
    result.each_cons(2) { |a, b|
      expect_true(a > b)
    }
  end

  test 'asc_with_page_size' do
    sort_conditions = [{:target => 'label', :asc => false}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query, :page => 3, :page_size => 1})['training_data'].map { |e| e['label'] }
    assert_equal(1, result.size)
    expect_equal('C#', result[0])
  end
end

TestCase 'Bazil-server training-data-query-field-sort' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'training_data_sort_query_test_util'

  beforeCase do
    before_case_set
  end

  afterCase do
    after_case_set
  end

  test 'asc', :params => ['f1', 'f2'] do
    sort_conditions = [{:target => 'field', :key => param, :asc => true}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query})['training_data'].map { |e| e['data'] }
    result.each_cons(2) { |a, b|
      expect_true(a[param] < b[param])
    }
  end

  test 'asc_with_page_size', :params => [['f1', 'owkn'], ['f2', 1000]] do
    sort_conditions = [{:target => 'field', :key => param[0], :asc => true}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query, :page => 3, :page_size => 1})['training_data'].map { |e| e['data'] }
    assert_equal(1, result.size)
    expect_equal(param[1], result[0][param[0]])
  end

  test 'desc', :params => ['f1', 'f2'] do
    sort_conditions = [{:target => 'field', :key => param, :asc => false}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query})['training_data'].map { |e| e['data'] }
    result.each_cons(2) { |a, b|
      expect_true(a[param] > b[param])
    }
  end

  test 'desc_with_page_size', :params => [['f1', 'god'], ['f2', -1]] do
    sort_conditions = [{:target => 'field', :key => param[0], :asc => false}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query, :page => 3, :page_size => 1})['training_data'].map { |e| e['data'] }
    assert_equal(1, result.size)
    expect_equal(param[1], result[0][param[0]])
  end

  test 'missing_key_field' do
    sort_conditions = [{:target => 'field', :asc => false}]
    query = {:version => 1, :sort => sort_conditions}
    assert_error(Bazil::APIError) {
      model.list_training_data({:query => query})
    }
  end

  test 'unknown_field' do
    sort_conditions = [{:target => 'field', :key => 'unknown', :asc => false}]
    query = {:version => 1, :sort => sort_conditions}
    model.list_training_data({:query => query})
    # order is not defined.
  end

  test 'unknown_field_with_page_size', :params => [[1, 1, 1], [4, 1, 0], [1, 2, 2], [2, 2, 1]] do
    sort_conditions = [{:target => 'field', :key => 'unknown', :asc => false}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query, :page => param[0], :page_size => param[1]})['training_data']
    assert_equal(param[2], result.size)
    # order is not defined.
  end
end

SharedContext 'training_data_complex_sort_query_test_util' do
  def prepare_training_data
    set :float_key, 'float'
    set :int_key, 'int'
    set :str_key, 'str'

    [-0.5, 1.0, 0.0, -10.5, 1.0, 1.5].zip([100, 0, -1000, 100, 50, 100], ['a', 'led', 'z', 'z', 'red', 'b']) { |f, n, s|
      training_data = {float_key => f, 'int' => n, 'str' => s}
      result = model.train('sort', training_data)
    }

    set :training_data_size, get_training_data_size
  end

  def sort_checker(sort_conditions)
    query = {:version => 1, :field => {'str' => {:any => [{:pattern => '.*'}]}}, :sort => sort_conditions}
    result = model.list_training_data({:query => query})['training_data'].map { |e| e['data'] }
    result.each_cons(2) { |a, b|
      num = 1
      check = sort_conditions.any? { |sort_condition|
        key = sort_condition['key']
        cond = sort_condition['asc'] ? :< : :>
        if a[key].__send__(cond, b[key])
          true
        elsif a[key] == b[key]
          if num == sort_conditions.size
            true
          else
            num += 1
            false # goto next comparison
          end
        else
          break false
        end
      }
      expect_true(check)
    }
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

TestCase 'Bazil-server training-data-query-complex-sort' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'training_data_complex_sort_query_test_util'

  beforeCase do
    before_case_set
  end

  afterCase do
    after_case_set
  end

  test 'query_with_one_key_sort' do
    [float_key, int_key, str_key].each { |key|
      [true, false].each { |asc|
        sort_checker([{'target' => 'field', 'key' => key, 'asc' => asc}])
      }
    }
  end

  test 'query_with_two_keys_sort' do
    conds = [true, false].repeated_permutation(2).to_a
    [float_key, int_key, str_key].permutation(2).each { |key1, key2|
      conds.each { |asc1, asc2|
        sort_checker([{'target' => 'field', 'key' => key1, 'asc' => asc1}, {'target' => 'field', 'key' => key2, 'asc' => asc2}])
      }
    }
  end

  test 'query_with_three_keys_sort' do
    conds = [true, false].repeated_permutation(3).to_a
    [float_key, int_key, str_key].permutation(3).each { |key1, key2, key3|
      conds.each { |asc1, asc2, asc3|
        sort_checker([{'target' => 'field', 'key' => key1, 'asc' => asc1}, {'target' => 'field', 'key' => key2, 'asc' => asc2}, {'target' => 'field', 'key' => key3, 'asc' => asc3}])
      }
    }
  end

  test 'label_and_id_asc_sort' do
    sort_conditions = [{:target => 'label', 'asc' => true}, {:target => 'id', :asc => true}]
    query = {:version => 1, :sort => sort_conditions}
    result = model.list_training_data({:query => query})['training_data'].map { |e| e['id'] }
    result.each_cons(2) { |a, b|
      expect_true(a < b)
    }
  end

  test 'label_and_id_desc_sort' do
    sort_conditions = [{:target => 'label', :asc => true}, {:target => 'id', :asc => false}]
    query = {'version' => 1, 'sort' => sort_conditions}
    result = model.list_training_data({:query => query})['training_data'].map { |e| e['id'] }
    result.each_cons(2) { |a, b|
      expect_true(a > b)
    }
  end

  # TODO: add test to check combination of sorting operations and page/pagesize.
  # TODO: add test for label and field
  # TODO: add test for id and field
  # TODO: add test for label and id and field
end

