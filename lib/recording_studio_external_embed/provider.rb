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
        clause, captured = capture(ingress)
        return Unresolved.malformed(ingress.original) unless clause

        Embed.materialize(**attributes_for(ingress, clause, captured))
      rescue ArgumentError
        Unresolved.malformed(ingress.original)
      end

      def attributes_for(ingress, clause, captured)
        presentation = decorate(clause, captured)
        identity_attributes(ingress, clause, captured).merge(presentation_attributes(presentation, clause))
      end

      def identity_attributes(ingress, clause, captured)
        {
          source_url: ingress.original,
          canonical_url: expand(canonical_template_for(clause), captured.id, captured.unlisted_hash),
          embed_url: expand(clause.embed_template || embed_template, captured.id, captured.unlisted_hash),
          provider: key,
          provider_label: label,
          content_type: clause.content_type,
          external_id: captured.id
        }
      end

      def canonical_template_for(clause)
        clause.canonical_template || canonical_template
      end

      def presentation_attributes(presentation, clause)
        aspect = aspect_for(presentation, clause)
        width, height = dimensions(aspect)
        text_attributes(presentation).merge(frame_attributes(width, height, aspect))
      end

      def aspect_for(presentation, clause)
        pair = [presentation.width, presentation.height]
        pair.all? { |number| number.is_a?(Integer) && number.positive? } ? Rational(*pair) : clause.aspect
      end

      def text_attributes(presentation)
        {
          title: presentation.title,
          description: nil,
          author_name: presentation.author_name,
          author_url: presentation.author_url,
          thumbnail_url: presentation.thumbnail_url, metadata_status: presentation.metadata_status
        }
      end

      def frame_attributes(width, height, aspect)
        { width: width, height: height, aspect_ratio: aspect }
      end

      def capture(ingress)
        plain = nil
        clauses.each do |clause|
          next unless clause.hosts.include?(ingress.host)

          captured = clause.capture(ingress)
          next unless captured
          return [clause, captured] if captured.unlisted_hash

          plain ||= [clause, captured]
        end
        plain
      end

      def decorate(clause, captured)
        return Oembed::Presentation.none unless oembed

        canonical_url = expand(canonical_template_for(clause), captured.id, captured.unlisted_hash)
        Oembed::Gateway.lookup(oembed, canonical_url, provider: key)
      end

      def expand(template, external_id, unlisted_hash = nil)
        raise ArgumentError, "external id is invalid" unless external_id.match?(ID_CHARSET)

        invalid_hash = template.include?("{hash}") && !(unlisted_hash.is_a?(String) && unlisted_hash.match?(ID_CHARSET))
        raise ArgumentError, "hash is invalid" if invalid_hash

        template.sub("{id}", external_id).sub("{hash}", unlisted_hash.to_s)
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

          Templates.review(
            embed_template: @embed_template,
            canonical_template: @canonical_template,
            clauses: @clauses,
            allowed_hosts: (@hosts + @embed_hosts).uniq
          )
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
      end

      class Templates
        def self.review(embed_template:, canonical_template:, clauses:, allowed_hosts:)
          new(embed_template, canonical_template, allowed_hosts).review(clauses)
        end

        def initialize(embed_template, canonical_template, allowed_hosts)
          @embed_template = embed_template
          @canonical_template = canonical_template
          @allowed_hosts = allowed_hosts
        end

        def review(clauses)
          check(@embed_template)
          check(@canonical_template)
          clauses.each { |clause| review_clause(clause) }
        end

        private

        def review_clause(clause)
          check(clause.embed_template) if clause.embed_template
          check(clause.canonical_template) if clause.canonical_template
          agree(clause)
        end

        def agree(clause)
          expected = clause.captures_hash?
          [picked(clause, :embed), picked(clause, :canonical)].each do |template|
            found = template.scan("{hash}").size == 1
            raise DefinitionError, "template hash does not match the clause" unless found == expected
          end
        end

        def picked(clause, kind)
          override = kind == :embed ? clause.embed_template : clause.canonical_template
          override || (kind == :embed ? @embed_template : @canonical_template)
        end

        def check(template)
          raise DefinitionError, "template must contain one id" unless one?(template, "{id}")
          raise DefinitionError, "template must contain one hash" unless one_hash?(template)
          return if trusted?(template)

          raise DefinitionError, "template is not a trusted https url"
        end

        def one_hash?(template)
          template.is_a?(String) && template.scan("{hash}").size <= 1
        end

        def one?(template, token)
          template.is_a?(String) && template.scan(token).size == 1
        end

        def trusted?(template)
          sample = template.sub("{id}", "placeholder").sub("{hash}", "placeholder")
          uri = URI.parse(sample)
          https?(uri)
        rescue URI::InvalidURIError
          false
        end

        def https?(uri)
          return false unless uri.is_a?(URI::HTTPS)
          return false if uri.userinfo
          return false unless @allowed_hosts.include?(uri.host)

          uri.port.nil? || uri.port == 443
        end
      end

      class Matcher
        def initialize(builder, content_type, aspect)
          @builder = builder
          @content_type = content_type
          @aspect = aspect
        end

        def path(regexp, **options)
          raise DefinitionError, "path pattern must capture id" unless anchored?(regexp) && regexp.names.include?("id")

          check_hash_names(regexp, options[:hash_param])
          check_hash_param(options[:hash_param], options[:hash_pattern])
          add_match(path_attrs(regexp, options))
        end

        def query(param, pattern:, path:, hosts: nil, embeds_as: nil)
          raise DefinitionError, "query path must be anchored" unless anchored?(path)
          raise DefinitionError, "query pattern must be anchored" unless anchored?(pattern)
          raise DefinitionError, "query path must not capture id" if path.names.include?("id")
          raise DefinitionError, "query path must not capture hash" if path.names.include?("hash")

          add_match(hosts:, path:, param: param.to_s, value_pattern: pattern, embed_template: embeds_as)
        end

        def path_attrs(regexp, options)
          {
            hosts: options[:hosts], path: regexp, param: nil, value_pattern: nil,
            embed_template: options[:embeds_as], canonical_template: options[:canonical],
            hash_param: options[:hash_param]&.to_s, hash_pattern: options[:hash_pattern]
          }
        end

        def add_match(attrs)
          attrs[:hosts] = selected_hosts(attrs[:hosts])
          attrs[:content_type] = @content_type
          attrs[:aspect] = @aspect
          @builder.add_clause(Clause.new(attrs))
        end

        def check_hash_names(regexp, hash_param)
          unknown = regexp.names - %w[id hash]
          raise DefinitionError, "path pattern captures an unknown name" unless unknown.empty?
          raise DefinitionError, "hash is captured twice" if hash_param && regexp.names.include?("hash")
        end

        def check_hash_param(hash_param, hash_pattern)
          return if hash_param.nil? && hash_pattern.nil?

          raise DefinitionError, "hash pattern needs a param" if hash_param.nil?
          raise DefinitionError, "hash param is invalid" unless hash_param.to_s.match?(/\A[a-z][a-z0-9_]*\z/)
          raise DefinitionError, "hash pattern must be anchored" unless anchored?(hash_pattern)
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
        attr_reader :hosts, :content_type, :aspect, :path, :param, :value_pattern, :embed_template,
                    :canonical_template, :hash_param, :hash_pattern

        def initialize(attrs)
          @hosts = attrs.fetch(:hosts)
          @content_type = attrs.fetch(:content_type)
          @aspect = attrs.fetch(:aspect)
          @path = attrs.fetch(:path)
          @param = attrs.fetch(:param)
          @value_pattern = attrs.fetch(:value_pattern)
          @embed_template = attrs[:embed_template]
          @canonical_template = attrs[:canonical_template]
          @hash_param, @hash_pattern = attrs.values_at(:hash_param, :hash_pattern)
          freeze
        end

        def captures_hash?
          return true if hash_param
          return false if param

          path.names.include?("hash")
        end

        def capture(ingress)
          return capture_query_hash(ingress) if hash_param
          return capture_query_id(ingress) if param

          capture_path(ingress)
        end

        def capture_query_id(ingress)
          return nil unless path.match?(ingress.path)

          id = certify(ingress.query[param], value_pattern)
          id && Capture.new(id: id, unlisted_hash: nil)
        end

        def capture_query_hash(ingress)
          match = path.match(ingress.path)
          return nil unless match
          return nil if ingress.query[hash_param].nil?

          id = certify(match[:id], ID_CHARSET)
          unlisted_hash = certify(ingress.query[hash_param], hash_pattern)
          raise ArgumentError, "hash is invalid" unless id && unlisted_hash

          Capture.new(id: id, unlisted_hash: unlisted_hash)
        end

        def capture_path(ingress)
          match = path.match(ingress.path)
          return nil unless match

          id = certify(match[:id], ID_CHARSET)
          return nil unless id
          return Capture.new(id: id, unlisted_hash: nil) unless path.names.include?("hash")

          unlisted_hash = certify(match[:hash], ID_CHARSET)
          return nil unless unlisted_hash

          Capture.new(id: id, unlisted_hash: unlisted_hash)
        end

        def certify(raw, pattern)
          return nil unless raw.is_a?(String)
          return nil unless raw.match?(pattern) && raw.match?(ID_CHARSET)
          return nil if [".", ".."].include?(raw)

          raw
        end
      end

      Capture = Data.define(:id, :unlisted_hash)
      private_constant :Builder, :Templates, :Matcher, :Clause, :Capture
    end
  end
end
