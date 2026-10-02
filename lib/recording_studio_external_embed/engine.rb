# frozen_string_literal: true

module RecordingStudio
  module ExternalEmbed
    module ConfigLoader
      MISSING_CONFIG = "Could not load configuration. No such file"

      def merge_recorded_config(app)
        merge_yaml(app)
        merge_rails_config(app)
      end

      private

      def merge_yaml(app)
        yaml = yaml_config(app)
        configuration.merge!(yaml) if yaml.respond_to?(:each)
      end

      def yaml_config(app)
        return nil unless app.respond_to?(:config_for)

        app.config_for(:recording_studio_external_embed)
      rescue RuntimeError => e
        raise unless e.message.start_with?(MISSING_CONFIG)

        nil
      end

      def merge_rails_config(app)
        return unless rails_config?(app)

        value = app.config.x.recording_studio_external_embed
        hash = value.respond_to?(:to_h) ? value.to_h : pair_hash(value)
        configuration.merge!(hash) if hash.respond_to?(:each)
      end

      def rails_config?(app)
        app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_external_embed)
      end

      def pair_hash(value)
        return nil unless value.respond_to?(:each_pair)

        hash = {}
        value.each_pair { |key, entry| hash[key] = entry }
        hash
      end

      def configuration
        RecordingStudio::ExternalEmbed.configuration
      end
    end

    class Engine < ::Rails::Engine
      include ConfigLoader

      isolate_namespace RecordingStudio::ExternalEmbed

      initializer "recording_studio_external_embed.before_initialize",
                  before: "recording_studio_external_embed.load_config" do |_app|
        RecordingStudio::ExternalEmbed.configuration.hooks.run(:before_initialize, self)
      end

      initializer "recording_studio_external_embed.load_config" do |app|
        merge_recorded_config(app)
        RecordingStudio::ExternalEmbed.configuration.hooks.run(:on_configuration, RecordingStudio::ExternalEmbed.configuration)
      end

      initializer "recording_studio_external_embed.helper" do
        ActiveSupport.on_load(:action_controller_base) do
          helper RecordingStudio::ExternalEmbed::Helper
        end
      end

      initializer "recording_studio_external_embed.after_initialize",
                  after: "recording_studio_external_embed.load_config" do |_app|
        RecordingStudio::ExternalEmbed.configuration.hooks.run(:after_initialize, self)
        RecordingStudio::ExternalEmbed.freeze_catalog!
      end
    end
  end
end
