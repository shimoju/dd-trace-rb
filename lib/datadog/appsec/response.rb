# frozen_string_literal: true

require_relative 'assets'
require_relative 'utils/http/media_range'

module Datadog
  module AppSec
    # AppSec response
    class Response
      attr_reader :status, :headers, :body

      def initialize(status:, headers: {}, body: [])
        @status = status
        @headers = headers
        @body = body
      end

      def to_rack
        [status, headers, body]
      end

      def to_sinatra_response
        ::Sinatra::Response.new(body, status, headers)
      end

      def to_action_dispatch_response
        ::ActionDispatch::Response.new(status, headers, body)
      end

      class << self
        def negotiate(env)
          content_type = content_type(env)

          Datadog.logger.debug { "negotiated response content type: #{content_type}" }

          Response.new(
            status: 403,
            headers: { 'Content-Type' => content_type },
            body: [Datadog::AppSec::Assets.blocked(format: FORMAT_MAP[content_type])]
          )
        end

        private

        FORMAT_MAP = {
          'application/json' => :json,
          'text/html' => :html,
          'text/plain' => :text,
        }.freeze

        DEFAULT_CONTENT_TYPE = 'application/json'

        def content_type(env)
          return DEFAULT_CONTENT_TYPE unless env.key?('HTTP_ACCEPT')

          accept_types = env['HTTP_ACCEPT'].split(',').map(&:strip)

          accepted = accept_types.map { |m| Utils::HTTP::MediaRange.new(m) }.sort!.reverse!

          accepted.each do |range|
            match = FORMAT_MAP.keys.find { |key| range === key }

            return match if match
          end
        rescue Datadog::AppSec::Utils::HTTP::MediaRange::ParseError
          DEFAULT_CONTENT_TYPE
        end
      end
    end
  end
end
