# frozen_string_literal: true

module YoutubeRb
  module Transcript
    # YouTube watch URL template
    # @example
    #   format(WATCH_URL, video_id: "abc123")
    #   # => "https://www.youtube.com/watch?v=abc123"
    WATCH_URL = "https://www.youtube.com/watch?v=%<video_id>s"

    # YouTube Innertube API URL template
    # @example
    #   format(INNERTUBE_API_URL, api_key: "key123")
    #   # => "https://www.youtube.com/youtubei/v1/player?key=key123"
    INNERTUBE_API_URL = "https://www.youtube.com/youtubei/v1/player?key=%<api_key>s"

    # Innertube API context for Android client
    # Used in POST requests to the Innertube API
    INNERTUBE_CONTEXT = {
      "client" => {
        "clientName" => "ANDROID",
        "clientVersion" => "20.10.38"
      }
    }.freeze
  end
end
