require 'test_helper'

module ActiveMerchant; end
class ActiveMerchant::Base
  def ssl_post(arg)
    if arg
      'OK'
    else
      raise 'Not OK'
    end
  end

  def post_with_block(&block)
    yield if block_given?
  end
end

class ActiveMerchant::Gateway < ActiveMerchant::Base
  def purchase(arg)
    ssl_post(arg)
    true
  rescue
    false
  end

  def self.sync
    true
  end

  def self.singleton_class
    class << self; self; end
  end
end

class ActiveMerchant::UniqueGateway < ActiveMerchant::Base
  def ssl_post(arg)
    {:success => arg}
  end

  def purchase(arg)
    ssl_post(arg)
  end
end

class GatewaySubClass < ActiveMerchant::Gateway
end

ActiveMerchant::Base.extend StatsD::Instrument

class StatsDInstrumentationTest < Minitest::Test
  include StatsD::Instrument::Assertions

  def test_statsd_count_if
    ActiveMerchant::Gateway.statsd_count_if :ssl_post, 'ActiveMerchant.Gateway.if'

    assert_statsd_increment('ActiveMerchant.Gateway.if') do
      ActiveMerchant::Gateway.new.purchase(true)
      ActiveMerchant::Gateway.new.purchase(false)
    end

    ActiveMerchant::Gateway.statsd_remove_count_if :ssl_post, 'ActiveMerchant.Gateway.if'
  end

  def test_statsd_count_if_with_method_receiving_block
    ActiveMerchant::Base.statsd_count_if :post_with_block, 'ActiveMerchant.Base.post_with_block' do |result|
      result == 'true'
    end

    assert_statsd_increment('ActiveMerchant.Base.post_with_block') do
      assert_equal 'true',  ActiveMerchant::Base.new.post_with_block { 'true' }
      assert_equal 'false', ActiveMerchant::Base.new.post_with_block { 'false' }
    end

    ActiveMerchant::Base.statsd_remove_count_if :post_with_block, 'ActiveMerchant.Base.post_with_block'
  end

  def test_statsd_count_if_with_block
    ActiveMerchant::UniqueGateway.statsd_count_if :ssl_post, 'ActiveMerchant.Gateway.block' do |result|
      result[:success]
    end

    assert_statsd_increment('ActiveMerchant.Gateway.block', times: 1) do
      ActiveMerchant::UniqueGateway.new.purchase(true)
      ActiveMerchant::UniqueGateway.new.purchase(false)
    end

    ActiveMerchant::UniqueGateway.statsd_remove_count_if :ssl_post, 'ActiveMerchant.Gateway.block'
  end

  def test_statsd_count_success
    ActiveMerchant::Gateway.statsd_count_success :ssl_post, 'ActiveMerchant.Gateway', 0.5

    assert_statsd_increment('ActiveMerchant.Gateway.success', sample_rate: 0.5, times: 1) do
      ActiveMerchant::Gateway.new.purchase(true)
      ActiveMerchant::Gateway.new.purchase(false)
    end

    assert_statsd_increment('ActiveMerchant.Gateway.failure', sample_rate: 0.5, times: 1) do
      ActiveMerchant::Gateway.new.purchase(false)
      ActiveMerchant::Gateway.new.purchase(true)
    end

    ActiveMerchant::Gateway.statsd_remove_count_success :ssl_post, 'ActiveMerchant.Gateway'
  end

  def test_statsd_count_success_with_method_receiving_block
    ActiveMerchant::Base.statsd_count_success :post_with_block, 'ActiveMerchant.Base.post_with_block' do |result|
      result == 'successful'
    end

    assert_statsd_increment('ActiveMerchant.Base.post_with_block.success', times: 1) do
      assert_equal 'successful', ActiveMerchant::Base.new.post_with_block { 'successful' }
      assert_equal 'not so successful', ActiveMerchant::Base.new.post_with_block { 'not so successful' }
    end

    assert_statsd_increment('ActiveMerchant.Base.post_with_block.failure', times: 1) do
      assert_equal 'successful', ActiveMerchant::Base.new.post_with_block { 'successful' }
      assert_equal 'not so successful', ActiveMerchant::Base.new.post_with_block { 'not so successful' }
    end    

    ActiveMerchant::Base.statsd_remove_count_success :post_with_block, 'ActiveMerchant.Base.post_with_block'
  end

  def test_statsd_count_success_with_block
    ActiveMerchant::UniqueGateway.statsd_count_success :ssl_post, 'ActiveMerchant.Gateway' do |result|
      result[:success]
    end

    assert_statsd_increment('ActiveMerchant.Gateway.success') do
      ActiveMerchant::UniqueGateway.new.purchase(true)
    end

    assert_statsd_increment('ActiveMerchant.Gateway.failure') do
      ActiveMerchant::UniqueGateway.new.purchase(false)
    end

    ActiveMerchant::UniqueGateway.statsd_remove_count_success :ssl_post, 'ActiveMerchant.Gateway'
  end

  def test_statsd_count
    ActiveMerchant::Gateway.statsd_count :ssl_post, 'ActiveMerchant.Gateway.ssl_post'

    assert_statsd_increment('ActiveMerchant.Gateway.ssl_post') do
      ActiveMerchant::Gateway.new.purchase(true)
    end

    ActiveMerchant::Gateway.statsd_remove_count :ssl_post, 'ActiveMerchant.Gateway.ssl_post'
  end

  def test_statsd_count_with_name_as_lambda
    metric_namer = lambda { |object, args| object.class.to_s.downcase + ".insert." + args.first.to_s }
    ActiveMerchant::Gateway.statsd_count(:ssl_post, metric_namer)

    assert_statsd_increment('gatewaysubclass.insert.true') do
      GatewaySubClass.new.purchase(true)
    end

    ActiveMerchant::Gateway.statsd_remove_count(:ssl_post, metric_namer)
  end

  def test_statsd_count_with_method_receiving_block
    ActiveMerchant::Base.statsd_count :post_with_block, 'ActiveMerchant.Base.post_with_block'

    assert_statsd_increment('ActiveMerchant.Base.post_with_block') do
      assert_equal 'block called', ActiveMerchant::Base.new.post_with_block { 'block called' }
    end

    ActiveMerchant::Base.statsd_remove_count :post_with_block, 'ActiveMerchant.Base.post_with_block'
  end

  def test_statsd_measure
    ActiveMerchant::UniqueGateway.statsd_measure :ssl_post, 'ActiveMerchant.Gateway.ssl_post', sample_rate: 0.3

    assert_statsd_measure('ActiveMerchant.Gateway.ssl_post', sample_rate: 0.3) do
      ActiveMerchant::UniqueGateway.new.purchase(true)
    end

    ActiveMerchant::UniqueGateway.statsd_remove_measure :ssl_post, 'ActiveMerchant.Gateway.ssl_post'
  end

  def test_statsd_measure_uses_normalized_metric_name
    ActiveMerchant::UniqueGateway.statsd_measure :ssl_post, 'ActiveMerchant::Gateway.ssl_post'

    assert_statsd_measure('ActiveMerchant.Gateway.ssl_post') do
      ActiveMerchant::UniqueGateway.new.purchase(true)
    end

    ActiveMerchant::UniqueGateway.statsd_remove_measure :ssl_post, 'ActiveMerchant::Gateway.ssl_post'
  end

  def test_statsd_measure_with_method_receiving_block
    ActiveMerchant::Base.statsd_measure :post_with_block, 'ActiveMerchant.Base.post_with_block'

    assert_statsd_measure('ActiveMerchant.Base.post_with_block') do
      assert_equal 'block called', ActiveMerchant::Base.new.post_with_block { 'block called' }
    end

    ActiveMerchant::Base.statsd_remove_measure :post_with_block, 'ActiveMerchant.Base.post_with_block'
  end

  def test_instrumenting_class_method
    ActiveMerchant::Gateway.singleton_class.extend StatsD::Instrument
    ActiveMerchant::Gateway.singleton_class.statsd_count :sync, 'ActiveMerchant.Gateway.sync'

    assert_statsd_increment('ActiveMerchant.Gateway.sync') do
      ActiveMerchant::Gateway.sync
    end

    ActiveMerchant::Gateway.singleton_class.statsd_remove_count :sync, 'ActiveMerchant.Gateway.sync'
  end

  def test_statsd_count_with_tags
    ActiveMerchant::Gateway.singleton_class.extend StatsD::Instrument
    ActiveMerchant::Gateway.singleton_class.statsd_count :sync, 'ActiveMerchant.Gateway.sync', tags: { key: 'value' }

    assert_statsd_increment('ActiveMerchant.Gateway.sync', tags: ['key:value']) do
      ActiveMerchant::Gateway.sync
    end

    ActiveMerchant::Gateway.singleton_class.statsd_remove_count :sync, 'ActiveMerchant.Gateway.sync'
  end
end
