# frozen_string_literal: true

require "test_helper"
require "action_controller"

layout_helper = File.join(
  Gem.loaded_specs.fetch("recording_studio").full_gem_path,
  "app/helpers/recording_studio/layout_helper.rb"
)
require layout_helper

class LayoutConfigurationTest < Minitest::Test
  class ProbeController < ActionController::Base
    include RecordingStudio::ControllerLayout

    recording_studio_layout { RecordingStudio::ExternalEmbed.configuration.layout }
  end

  def setup
    @core_layout = RecordingStudio.configuration.layout
    RecordingStudio::ExternalEmbed.instance_variable_set(:@configuration, nil)
    RecordingStudio.configuration.layout = nil
  end

  def teardown
    RecordingStudio::ExternalEmbed.instance_variable_set(:@configuration, nil)
    RecordingStudio.configuration.layout = @core_layout
  end

  def test_nil_falls_through_to_core_layout_then_the_default
    assert_nil RecordingStudio::ExternalEmbed.configuration.layout

    RecordingStudio.configuration.layout = "host_shell"
    assert_equal "host_shell", probe.recording_studio_resolved_layout

    RecordingStudio.configuration.layout = nil
    assert_equal "recording_studio/default_layout", probe.recording_studio_resolved_layout
  end

  def test_string_layout_name_is_used_as_given
    RecordingStudio::ExternalEmbed.configuration.layout = "admin"
    assert_equal "admin", probe.recording_studio_resolved_layout
  end

  def test_false_layout_does_not_fall_through
    RecordingStudio::ExternalEmbed.configuration.layout = false
    RecordingStudio.configuration.layout = "host_shell"

    assert_equal false, probe.recording_studio_resolved_layout
  end

  def test_keyword_callable_receives_the_controller
    seen = nil
    RecordingStudio::ExternalEmbed.configuration.layout = lambda { |controller:|
      seen = controller
      "from_callable"
    }

    assert_equal "from_callable", probe.recording_studio_resolved_layout
    assert_instance_of ProbeController, seen
  end

  def test_invalid_layout_values_raise_argument_error
    assert_raises(ArgumentError) { RecordingStudio::ExternalEmbed.configuration.layout = 1 }
    assert_raises(ArgumentError) { RecordingStudio::ExternalEmbed.configuration.layout = ->(controller) { controller } }
    assert_raises(ArgumentError) { RecordingStudio::ExternalEmbed.configuration.layout = "" }
  end

  def test_controllers_do_not_hardcode_a_recording_studio_layout
    root = File.expand_path("..", __dir__)

    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(root)
    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(File.join(root, "test/dummy"))
  end

  def test_widen_helper_lets_recording_studio_6_satisfy_a_4x_requirement
    require_relative "support/widen_recording_studio_requirement"

    dependency = Gem::Dependency.new("recording_studio", "~> 4.2")
    refute dependency.requirement.satisfied_by?(Gem::Version.new("6.1.0"))

    WidenRecordingStudioRequirement.widen_all([dependency])

    assert dependency.requirement.satisfied_by?(Gem::Version.new("6.1.0"))
    assert dependency.requirement.satisfied_by?(Gem::Version.new("4.2.0"))
  end

  private

  def probe
    @probe ||= ProbeController.new
  end
end
