# frozen_string_literal: true

require "spec_helper"
require "youtube_rb/transcript"

RSpec.describe "YoutubeRb::Transcript Settings" do
  describe "WATCH_URL" do
    it "is defined" do
      expect(YoutubeRb::Transcript::WATCH_URL).not_to be_nil
    end

    it "is a YouTube watch URL template" do
      expect(YoutubeRb::Transcript::WATCH_URL).to include("youtube.com/watch")
    end

    it "contains video_id placeholder" do
      expect(YoutubeRb::Transcript::WATCH_URL).to include("%<video_id>s")
    end

    it "can be formatted with a video_id" do
      url = format(YoutubeRb::Transcript::WATCH_URL, video_id: "abc123")
      expect(url).to eq("https://www.youtube.com/watch?v=abc123")
    end
  end

  describe "INNERTUBE_API_URL" do
    it "is defined" do
      expect(YoutubeRb::Transcript::INNERTUBE_API_URL).not_to be_nil
    end

    it "is a YouTube API URL" do
      expect(YoutubeRb::Transcript::INNERTUBE_API_URL).to include("youtube.com/youtubei")
    end

    it "contains api_key placeholder" do
      expect(YoutubeRb::Transcript::INNERTUBE_API_URL).to include("%<api_key>s")
    end

    it "can be formatted with an api_key" do
      url = format(YoutubeRb::Transcript::INNERTUBE_API_URL, api_key: "my_api_key")
      expect(url).to eq("https://www.youtube.com/youtubei/v1/player?key=my_api_key")
    end
  end

  describe "INNERTUBE_CONTEXT" do
    it "is defined" do
      expect(YoutubeRb::Transcript::INNERTUBE_CONTEXT).not_to be_nil
    end

    it "is a frozen hash" do
      expect(YoutubeRb::Transcript::INNERTUBE_CONTEXT).to be_frozen
    end

    it "contains client configuration" do
      expect(YoutubeRb::Transcript::INNERTUBE_CONTEXT).to have_key("client")
    end

    it "specifies clientName as ANDROID" do
      expect(YoutubeRb::Transcript::INNERTUBE_CONTEXT["client"]["clientName"]).to eq("ANDROID")
    end

    it "specifies a clientVersion" do
      expect(YoutubeRb::Transcript::INNERTUBE_CONTEXT["client"]["clientVersion"]).not_to be_nil
      expect(YoutubeRb::Transcript::INNERTUBE_CONTEXT["client"]["clientVersion"]).to be_a(String)
    end
  end
end
