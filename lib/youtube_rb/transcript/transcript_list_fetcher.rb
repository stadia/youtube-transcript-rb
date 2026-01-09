# frozen_string_literal: true

require "cgi"
require "json"

module YoutubeRb
  module Transcript
    # Playability status values returned by YouTube
    module PlayabilityStatus
      OK = "OK"
      ERROR = "ERROR"
      LOGIN_REQUIRED = "LOGIN_REQUIRED"
    end

    # Reason messages for playability failures
    module PlayabilityFailedReason
      BOT_DETECTED = "Sign in to confirm you're not a bot"
      AGE_RESTRICTED = "This video may be inappropriate for some users."
      VIDEO_UNAVAILABLE = "This video is unavailable"
    end

    # Fetches transcript lists from YouTube videos.
    # This class handles all the HTTP communication with YouTube,
    # including consent cookie handling and error detection.
    class TranscriptListFetcher
      # @param http_client [Faraday::Connection] the HTTP client to use
      # @param proxy_config [Object, nil] optional proxy configuration
      def initialize(http_client:, proxy_config: nil)
        @http_client = http_client
        @proxy_config = proxy_config
      end

      # Fetch the transcript list for a video
      #
      # @param video_id [String] the YouTube video ID
      # @return [TranscriptList] the list of available transcripts
      # @raise [CouldNotRetrieveTranscript] if transcripts cannot be retrieved
      def fetch(video_id)
        TranscriptList.build(
          http_client: @http_client,
          video_id: video_id,
          captions_json: fetch_captions_json(video_id)
        )
      end

      private

      # Fetch captions JSON with retry support
      #
      # @param video_id [String] the YouTube video ID
      # @param try_number [Integer] current retry attempt
      # @return [Hash] the captions JSON
      def fetch_captions_json(video_id, try_number: 0)
        html = fetch_video_html(video_id)
        api_key = extract_innertube_api_key(html, video_id)
        innertube_data = fetch_innertube_data(video_id, api_key)
        extract_captions_json(innertube_data, video_id)
      rescue RequestBlocked => e
        retries = if @proxy_config.nil?
                    0
                  else
                    (@proxy_config.respond_to?(:retries_when_blocked) ? @proxy_config.retries_when_blocked : 0)
                  end
        return fetch_captions_json(video_id, try_number: try_number + 1) if try_number + 1 < retries

        raise e
      end

      # Extract the INNERTUBE_API_KEY from the video page HTML
      #
      # @param html [String] the HTML content
      # @param video_id [String] the video ID (for error messages)
      # @return [String] the API key
      # @raise [IpBlocked] if a CAPTCHA is detected
      # @raise [YouTubeDataUnparsable] if the key cannot be found
      def extract_innertube_api_key(html, video_id)
        match = html.match(/"INNERTUBE_API_KEY":\s*"([a-zA-Z0-9_-]+)"/)
        return match[1] if match && match[1]

        raise IpBlocked, video_id if html.include?('class="g-recaptcha"')

        raise YouTubeDataUnparsable, video_id
      end

      # Extract captions JSON from innertube data
      #
      # @param innertube_data [Hash] the innertube API response
      # @param video_id [String] the video ID
      # @return [Hash] the captions JSON
      # @raise [TranscriptsDisabled] if no captions are available
      def extract_captions_json(innertube_data, video_id)
        assert_playability(innertube_data["playabilityStatus"], video_id)

        captions_json = innertube_data.dig("captions", "playerCaptionsTracklistRenderer")
        raise TranscriptsDisabled, video_id if captions_json.nil? || !captions_json.key?("captionTracks")

        captions_json
      end

      # Assert that the video is playable
      #
      # @param playability_status_data [Hash, nil] the playability status from API
      # @param video_id [String] the video ID
      # @raise [Various] depending on the playability status
      def assert_playability(playability_status_data, video_id)
        return if playability_status_data.nil?

        status = playability_status_data["status"]
        return if status == PlayabilityStatus::OK || status.nil?

        reason = playability_status_data["reason"]

        if status == PlayabilityStatus::LOGIN_REQUIRED
          if reason == PlayabilityFailedReason::BOT_DETECTED
            raise RequestBlocked, video_id
          elsif reason == PlayabilityFailedReason::AGE_RESTRICTED
            raise AgeRestricted, video_id
          end
        end

        if status == PlayabilityStatus::ERROR && reason == PlayabilityFailedReason::VIDEO_UNAVAILABLE
          raise InvalidVideoId, video_id if video_id.start_with?("http://") || video_id.start_with?("https://")

          raise VideoUnavailable, video_id
        end

        # Extract subreasons for more detailed error messages
        subreasons = playability_status_data.dig("errorScreen", "playerErrorMessageRenderer", "subreason", "runs") || []
        subreason_texts = subreasons.map { |run| run["text"] || "" }

        raise VideoUnplayable.new(video_id, reason, subreason_texts)
      end

      # Create a consent cookie from the HTML
      #
      # @param html [String] the HTML content
      # @param video_id [String] the video ID
      # @raise [FailedToCreateConsentCookie] if the cookie cannot be created
      def create_consent_cookie(html, video_id)
        match = html.match(/name="v" value="(.*?)"/)
        raise FailedToCreateConsentCookie, video_id if match.nil?

        # Set the consent cookie
        # Note: Faraday doesn't have built-in cookie management like requests.Session
        # We'll need to handle this via headers or middleware
        @consent_value = "YES+#{match[1]}"
      end

      # Fetch the video HTML page
      #
      # @param video_id [String] the video ID
      # @return [String] the HTML content
      def fetch_video_html(video_id)
        html = fetch_html(video_id)

        if html.include?('action="https://consent.youtube.com/s"')
          create_consent_cookie(html, video_id)
          html = fetch_html(video_id)
          raise FailedToCreateConsentCookie, video_id if html.include?('action="https://consent.youtube.com/s"')
        end

        html
      end

      # Fetch raw HTML from YouTube
      #
      # @param video_id [String] the video ID
      # @return [String] the HTML content (unescaped)
      def fetch_html(video_id)
        url = format(WATCH_URL, video_id: video_id)
        headers = { "Accept-Language" => "en-US" }

        # Add consent cookie if we have one
        headers["Cookie"] = "CONSENT=#{@consent_value}" if @consent_value

        response = @http_client.get(url) do |req|
          headers.each { |k, v| req.headers[k] = v }
        end

        raise_http_errors(response, video_id)
        CGI.unescapeHTML(response.body)
      end

      # Fetch data from the Innertube API
      #
      # @param video_id [String] the video ID
      # @param api_key [String] the API key
      # @return [Hash] the API response
      def fetch_innertube_data(video_id, api_key)
        url = format(INNERTUBE_API_URL, api_key: api_key)

        response = @http_client.post(url) do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = JSON.generate({
                                     "context" => INNERTUBE_CONTEXT,
                                     "videoId" => video_id
                                   })
        end

        raise_http_errors(response, video_id)
        JSON.parse(response.body)
      end

      # Raise appropriate errors for HTTP responses
      #
      # @param response [Faraday::Response] the HTTP response
      # @param video_id [String] the video ID
      # @raise [IpBlocked] for 429 responses
      # @raise [YouTubeRequestFailed] for other error responses
      def raise_http_errors(response, video_id)
        case response.status
        when 429
          raise IpBlocked, video_id
        when 400..599
          raise YouTubeRequestFailed.new(video_id, StandardError.new("HTTP #{response.status}"))
        end
      end
    end
  end
end
