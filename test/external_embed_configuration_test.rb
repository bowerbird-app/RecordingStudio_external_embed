# frozen_string_literal: true

require "test_helper"

class ExternalEmbedConfigurationTest < Minitest::Test
  def test_merge_updates_timeouts_and_ignores_transport_keys
    configuration = RecordingStudio::ExternalEmbed::Configuration.new

    configuration.merge!(open_timeout: 3, read_timeout: 4, max_bytes: 100, http: "nope", unknown: "ignored")

    assert_equal 3, configuration.open_timeout
    assert_equal 4, configuration.read_timeout
    assert_equal 100, configuration.max_bytes
    assert_nil configuration.http
    refute_respond_to configuration, :unknown
  end

  def test_engine_runs_configuration_hooks
    called = []
    RecordingStudio::ExternalEmbed.configuration.hooks.before_initialize { called << :before }
    RecordingStudio::ExternalEmbed.configuration.hooks.on_configuration { called << :configured }
    RecordingStudio::ExternalEmbed.configuration.hooks.after_initialize { called << :after }

    initializer("recording_studio_external_embed.before_initialize").block.call(Object.new)
    initializer("recording_studio_external_embed.load_config").block.call(app_with(open_timeout: 9))
    initializer("recording_studio_external_embed.after_initialize").block.call(Object.new)

    assert_equal %i[before configured after], called
    assert_equal 9, RecordingStudio::ExternalEmbed.configuration.open_timeout
  ensure
    RecordingStudio::ExternalEmbed.configuration.hooks.clear!
    RecordingStudio::ExternalEmbed.instance_variable_set(:@configuration, nil)
    RecordingStudio::ExternalEmbed.instance_variable_set(:@catalog_frozen, false)
    RecordingStudio::ExternalEmbed.instance_variable_set(:@catalog, nil)
  end

  def test_helper_initializer_includes_the_view_helper
    host = Class.new do
      class << self
        attr_reader :included_helper

        def helper(mod)
          @included_helper = mod
        end
      end
    end

    initializer("recording_studio_external_embed.helper").block.call(Object.new)
    ActiveSupport.run_load_hooks(:action_controller_base, host)

    assert_equal RecordingStudio::ExternalEmbed::Helper, host.included_helper
  end

  def initializer(name)
    RecordingStudio::ExternalEmbed::Engine.initializers.find { |entry| entry.name == name }
  end

  def app_with(values)
    xcfg = Struct.new(:recording_studio_external_embed).new(values)
    app_config = Struct.new(:x).new(xcfg)
    Struct.new(:config).new(app_config)
  end
end
