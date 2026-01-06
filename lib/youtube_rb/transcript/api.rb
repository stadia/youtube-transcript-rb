# frozen_string_literal: true

require "faraday"
require "faraday/follow_redirects"

module YoutubeRb
  module Transcript
    # Main entry point for fetching YouTube transcripts.
    # This class provides a simple API for retrieving transcripts from YouTube videos.
    #
    # @example Basic usage
    #   api = YoutubeRb::Transcript::YouTubeTranscriptApi.new
    #   transcript = api.fetch("dQw4w9WgXcQ")
    #   transcript.each { |snippet| puts snippet.text }
    #
    # @example With language preference
    #   api = YoutubeRb::Transcript::YouTubeTranscriptApi.new
    #   transcript = api.fetch("dQw4w9WgXcQ", languages: ["es", "en"])
    #
    # @example Listing available transcripts
    #   api = YoutubeRb::Transcript::YouTubeTranscriptApi.new
    #   transcript_list = api.list("dQw4w9WgXcQ")
    #   transcript_list.each { |t| puts t }
    #
    class YouTubeTranscriptApi
      # Default timeout for HTTP requests in seconds
      DEFAULT_TIMEOUT = 30

      # @param http_client [Faraday::Connection, nil] Custom HTTP client (optional)
      # @param proxy_config [Object, nil] Proxy configuration (optional)
      def initialize(http_client: nil, proxy_config: nil)
        @http_client = http_client || build_default_http_client
        @proxy_config = proxy_config
        @fetcher = TranscriptListFetcher.new(
          http_client: @http_client,
          proxy_config: @proxy_config
        )
      end

      # Fetch a transcript for a video.
      # This is a convenience method that combines `list` and `find_transcript`.
      #
      # @param video_id [String] The YouTube video ID
      # @param languages [Array<String>] Language codes in order of preference (default: ["en"])
      # @param preserve_formatting [Boolean] Whether to preserve HTML formatting (default: false)
      # @return [FetchedTranscript] The fetched transcript
      # @raise [NoTranscriptFound] If no transcript matches the requested languages
      # @raise [TranscriptsDisabled] If transcripts are disabled for the video
      # @raise [VideoUnavailable] If the video is not available
      #
      # @example
      #   api = YouTubeTranscriptApi.new
      #   transcript = api.fetch("dQw4w9WgXcQ", languages: ["en", "es"])
      #   puts transcript.first.text
      #
      def fetch(video_id, languages: ["en"], preserve_formatting: false)
        list(video_id)
          .find_transcript(languages)
          .fetch(preserve_formatting: preserve_formatting)
      end

      # List all available transcripts for a video.
      #
      # @param video_id [String] The YouTube video ID
      # @return [TranscriptList] A list of available transcripts
      # @raise [TranscriptsDisabled] If transcripts are disabled for the video
      # @raise [VideoUnavailable] If the video is not available
      #
      # @example
      #   api = YouTubeTranscriptApi.new
      #   transcript_list = api.list("dQw4w9WgXcQ")
      #
      #   # Find a specific transcript
      #   transcript = transcript_list.find_transcript(["en"])
      #
      #   # Or iterate over all available transcripts
      #   transcript_list.each do |transcript|
      #     puts "#{transcript.language_code}: #{transcript.language}"
      #   end
      #
      def list(video_id)
        @fetcher.fetch(video_id)
      end

      # Fetch transcripts for multiple videos.
      #
      # @param video_ids [Array<String>] Array of YouTube video IDs
      # @param languages [Array<String>] Language codes in order of preference (default: ["en"])
      # @param preserve_formatting [Boolean] Whether to preserve HTML formatting (default: false)
      # @param continue_on_error [Boolean] Whether to continue if a video fails (default: false)
      # @yield [video_id, result] Block called for each video with either transcript or error
      # @yieldparam video_id [String] The video ID being processed
      # @yieldparam result [FetchedTranscript, StandardError] The transcript or error
      # @return [Hash<String, FetchedTranscript>] Hash mapping video IDs to transcripts
      # @raise [CouldNotRetrieveTranscript] If any video fails and continue_on_error is false
      #
      # @example Fetch multiple videos
      #   api = YouTubeTranscriptApi.new
      #   transcripts = api.fetch_all(["video1", "video2", "video3"])
      #   transcripts.each { |id, t| puts "#{id}: #{t.length} snippets" }
      #
      # @example With error handling
      #   api = YouTubeTranscriptApi.new
      #   api.fetch_all(["video1", "video2"], continue_on_error: true) do |video_id, result|
      #     if result.is_a?(StandardError)
      #       puts "Error for #{video_id}: #{result.message}"
      #     else
      #       puts "Got #{result.length} snippets for #{video_id}"
      #     end
      #   end
      #
      def fetch_all(video_ids, languages: ["en"], preserve_formatting: false, continue_on_error: false)
        results = {}

        video_ids.each do |video_id|
          begin
            transcript = fetch(video_id, languages: languages, preserve_formatting: preserve_formatting)
            results[video_id] = transcript
            yield(video_id, transcript) if block_given?
          rescue CouldNotRetrieveTranscript => e
            if continue_on_error
              yield(video_id, e) if block_given?
            else
              raise
            end
          end
        end

        results
      end

      private

      # Build the default Faraday HTTP client
      #
      # @return [Faraday::Connection] The configured HTTP client
      def build_default_http_client
        Faraday.new do |conn|
          conn.options.timeout = DEFAULT_TIMEOUT
          conn.options.open_timeout = DEFAULT_TIMEOUT
          conn.request :url_encoded
          conn.response :follow_redirects
          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
