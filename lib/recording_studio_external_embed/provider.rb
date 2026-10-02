# frozen_string_literal: true

require "uri"

module RecordingStudio
  module ExternalEmbed
    class Provider
      ID_CHARSET = /\A[A-Za-z0-9_-]{1,64}\z/
      LONG_EDGE = 560

      attr_reader :key, :label, :hosts, :embed_template, :canonical_template, :embed_hosts, :clauses, :oembed

      def self.define(key, &)
        builder = Builder.new(key)
        builder.instance_eval(&)
        builder.build
      end

      def initialize(attributes)
        @key = attributes.fetch(:key)
        @label = attributes.fetch(:label)
        @hosts = attributes.fetch(:hosts)
        @embed_template = attributes.fetch(:embed_template)
        @canonical_template = attributes.fetch(:canonical_template)
        @embed_hosts = attributes.fetch(:embed_hosts)
        @clauses = attributes.fetch(:clauses)
        @oembed = attributes[:oembed]
        freeze
      end

      def resolve(ingress)
        clause, external_id = capture(ingress)
        return Unresolved.malformed(ingress.original) unless clause

        Embed.materialize(**attributes_for(ingress, clause, external_id))
      rescue ArgumentError
        Unresolved.malformed(ingress.original)
      end

      def attributes_for(ingress, clause, external_id)
        presentation = decorate(external_id)
        identity_attributes(ingress, clause, external_id).merge(presentation_attributes(presentation, clause))
      end

      def identity_attributes(ingress, clause, external_id)
        {
          source_url: ingress.original,
          canonical_url: expand(canonical_template, external_id),
          embed_url: expand(embed_template_for(clause), external_id),
          provider: key,
          provider_label: label,
          content_type: clause.content_type,
          external_id: external_id
        }
      end

      def embed_template_for(clause)
        clause.embed_template || embed_template
      end

      def presentation_attributes(presentation, clause)
        width, height = dimensions(clause.aspect)
        text_attributes(presentation).merge(frame_attributes(width, height, clause.aspect))
      end

      def text_attributes(presentation)
        {
          title: presentation.title,
          description: nil,
          author_name: presentation.author_name,
          author_url: presentation.author_url,
          thumbnail_url: presentation.thumbnail_url
        }
      end

      def frame_attributes(width, height, aspect)
        { width: width, height: height, aspect_ratio: aspect }
      end

      def capture(ingress)
        clauses.each do |clause|
          next unless clause.hosts.include?(ingress.host)

          external_id = clause.capture(ingress)
          return [clause, external_id] if external_id
        end
        nil
      end

      def decorate(external_id)
        return Oembed::Presentation.empty unless oembed

        Oembed::Gateway.lookup(oembed, expand(canonical_template, external_id))
      end

      def expand(template, external_id)
        raise ArgumentError, "external id is invalid" unless external_id.match?(ID_CHARSET)

        template.sub("{id}", external_id)
      end

      def dimensions(aspect)
        if aspect >= 1
          [LONG_EDGE, (LONG_EDGE / aspect).round]
        else
          [(LONG_EDGE * aspect).round, LONG_EDGE]
        end
      end

      class Builder
        def initialize(key)
          @key = key
          @hosts = []
          @embed_hosts = []
          @clauses = []
          @label = key.to_s
          @embed_template = nil
          @canonical_template = nil
          @oembed = nil
        end

        def host(*names)
          @hosts.concat(names.map { |name| normalize_name(name) })
        end

        def embed_host(*names)
          @embed_hosts.concat(names.map { |name| normalize_name(name) })
        end

        def label(text)
          @label = text.to_s
        end

        def embeds_as(template)
          @embed_template = template
        end

        def canonical(template)
          @canonical_template = template
        end

        def oembed(endpoint:, thumbnail_hosts:)
          @oembed = Oembed::Endpoint.build(endpoint: endpoint, thumbnail_hosts: thumbnail_hosts)
        end

        def match(content_type:, aspect:, &)
          raise DefinitionError, "content type is invalid" unless content_type.is_a?(Symbol)
          raise DefinitionError, "aspect ratio is invalid" unless aspect.is_a?(Rational) && aspect.positive?

          matcher = Matcher.new(self, content_type, aspect)
          matcher.instance_eval(&)
        end

        def add_clause(clause)
          @clauses << clause
        end

        def paste_hosts
          @hosts.dup
        end

        def build
          validate_definition
          Provider.new(definition_attributes)
        end

        private

        def validate_definition
          raise DefinitionError, "provider key is invalid" unless valid_key?
          raise DefinitionError, "provider needs a host" if @hosts.empty?
          raise DefinitionError, "provider needs a match" if @clauses.empty?

          allowed = (@hosts + @embed_hosts).uniq
          check_template(@embed_template, allowed)
          check_template(@canonical_template, allowed)
          @clauses.each { |clause| check_template(clause.embed_template, allowed) if clause.embed_template }
        end

        def valid_key?
          @key.is_a?(Symbol) && @key.match?(/\A[a-z][a-z0-9_]*\z/)
        end

        def definition_attributes
          {
            key: @key,
            label: @label,
            hosts: @hosts.uniq.freeze,
            embed_template: @embed_template,
            canonical_template: @canonical_template,
            embed_hosts: @embed_hosts.uniq.freeze,
            clauses: @clauses.freeze,
            oembed: @oembed
          }
        end

        def normalize_name(name)
          value = name.to_s.downcase
          return value if acceptable_host?(value)

          raise DefinitionError, "host is invalid"
        end

        def acceptable_host?(value)
          value.match?(/\A[a-z0-9.-]+\z/) && !value.include?("..") && !value.start_with?(".") && !value.end_with?(".")
        end

        def check_template(template, allowed_hosts)
          raise DefinitionError, "template must contain one id" unless one_id?(template)
          return if trusted_template?(template, allowed_hosts)

          raise DefinitionError, "template is not a trusted https url"
        end

        def one_id?(template)
          template.is_a?(String) && template.scan("{id}").size == 1
        end

        def trusted_template?(template, allowed_hosts)
          uri = URI.parse(template.sub("{id}", "placeholder"))
          https_template?(uri, allowed_hosts)
        rescue URI::InvalidURIError
          false
        end

        def https_template?(uri, allowed_hosts)
          return false unless uri.is_a?(URI::HTTPS)
          return false if uri.userinfo
          return false unless allowed_hosts.include?(uri.host)

          uri.port.nil? || uri.port == 443
        end
      end

      class Matcher
        def initialize(builder, content_type, aspect)
          @builder = builder
          @content_type = content_type
          @aspect = aspect
        end

        def path(regexp, hosts: nil, embeds_as: nil)
          raise DefinitionError, "path pattern must capture id" unless anchored?(regexp) && regexp.names.include?("id")

          @builder.add_clause(
            clause_for(hosts: hosts, path: regexp, param: nil, value_pattern: nil, embed_template: embeds_as)
          )
        end

        def query(param, pattern:, path:, hosts: nil, embeds_as: nil)
          raise DefinitionError, "query path must be anchored" unless anchored?(path)
          raise DefinitionError, "query pattern must be anchored" unless anchored?(pattern)
          raise DefinitionError, "query path must not capture id" if path.names.include?("id")

          @builder.add_clause(
            clause_for(hosts: hosts, path: path, param: param.to_s, value_pattern: pattern, embed_template: embeds_as)
          )
        end

        def clause_for(hosts:, path:, param:, value_pattern:, embed_template:)
          Clause.new(
            hosts: selected_hosts(hosts),
            content_type: @content_type,
            aspect: @aspect,
            path: path,
            param: param,
            value_pattern: value_pattern,
            embed_template: embed_template
          )
        end

        private

        def anchored?(regexp)
          regexp.is_a?(Regexp) && regexp.source.start_with?("\\A") && regexp.source.end_with?("\\z")
        end

        def selected_hosts(hosts)
          list = hosts.nil? ? @builder.paste_hosts : Array(hosts).map(&:to_s)
          unknown = list - @builder.paste_hosts
          raise DefinitionError, "clause host is not on the provider" unless unknown.empty?
          raise DefinitionError, "clause needs a host" if list.empty?

          list.freeze
        end
      end

      class Clause
        attr_reader :hosts, :content_type, :aspect, :path, :param, :value_pattern, :embed_template

        def initialize(attrs)
          @hosts = attrs.fetch(:hosts)
          @content_type = attrs.fetch(:content_type)
          @aspect = attrs.fetch(:aspect)
          @path = attrs.fetch(:path)
          @param = attrs.fetch(:param)
          @value_pattern = attrs.fetch(:value_pattern)
          @embed_template = attrs[:embed_template]
          freeze
        end

        def capture(ingress)
          if param
            return nil unless path.match?(ingress.path)

            certify(ingress.query[param], value_pattern)
          else
            match = path.match(ingress.path)
            certify(match && match[:id], ID_CHARSET)
          end
        end

        def certify(raw, pattern)
          return nil unless raw.is_a?(String)
          return nil unless raw.match?(pattern) && raw.match?(ID_CHARSET)
          return nil if [".", ".."].include?(raw)

          raw
        end
      end

      private_constant :Builder, :Matcher, :Clause
    end
  end
end
