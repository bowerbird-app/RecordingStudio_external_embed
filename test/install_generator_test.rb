# frozen_string_literal: true

require "test_helper"
require "generators/recording_studio_external_embed/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  def test_mount_engine_uses_the_external_embed_engine
    generator = RecordingStudio::ExternalEmbed::Generators::InstallGenerator.new(
      [],
      { mount_path: "/embeds" },
      destination_root: "/tmp"
    )
    routes = []

    generator.stub(:route, ->(value) { routes << value }) do
      generator.mount_engine
    end

    assert_equal [%(mount RecordingStudio::ExternalEmbed::Engine, at: "/embeds")], routes
  end

  def test_initializer_template_configures_the_nested_module
    template = File.read(
      File.expand_path("../lib/generators/recording_studio_external_embed/install/templates/initializer.rb", __dir__)
    )

    assert_includes template, "RecordingStudio::ExternalEmbed.configure"
  end
end
