# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe YoutubeRb::Transcript::TranscriptListFetcher do
  let(:http_client) { Faraday.new }
  let(:fetcher) { described_class.new(http_client: http_client) }
  let(:video_id) { "dQw4w9WgXcQ" }
  let(:api_key) { "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8" }

  let(:watch_url) { "https://www.youtube.com/watch?v=#{video_id}" }
  let(:innertube_url) { "https://www.youtube.com/youtubei/v1/player?key=#{api_key}" }

  # Sample HTML with embedded API key
  let(:sample_html) do
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Test Video</title></head>
      <body>
        <script>
          var ytcfg = {"INNERTUBE_API_KEY": "#{api_key}", "OTHER_KEY": "value"};
        </script>
      </body>
      </html>
    HTML
  end

  # Sample innertube API response with captions
  let(:sample_innertube_response) do
    {
      "playabilityStatus" => { "status" => "OK" },
      "captions" => {
        "playerCaptionsTracklistRenderer" => {
          "captionTracks" => [
            {
              "baseUrl" => "https://www.youtube.com/api/timedtext?v=#{video_id}&lang=en",
              "name" => { "runs" => [{ "text" => "English" }] },
              "languageCode" => "en",
              "isTranslatable" => true
            }
          ],
          "translationLanguages" => [
            { "languageCode" => "es", "languageName" => { "runs" => [{ "text" => "Spanish" }] } }
          ]
        }
      }
    }
  end

  describe "#initialize" do
    it "stores the http_client" do
      fetcher = described_class.new(http_client: http_client)
      expect(fetcher.instance_variable_get(:@http_client)).to eq(http_client)
    end

    it "stores the proxy_config when provided" do
      proxy_config = double("proxy_config")
      fetcher = described_class.new(http_client: http_client, proxy_config: proxy_config)
      expect(fetcher.instance_variable_get(:@proxy_config)).to eq(proxy_config)
    end

    it "defaults proxy_config to nil" do
      fetcher = described_class.new(http_client: http_client)
      expect(fetcher.instance_variable_get(:@proxy_config)).to be_nil
    end
  end

  describe "#fetch" do
    before do
      stub_request(:get, watch_url)
        .to_return(status: 200, body: sample_html)

      stub_request(:post, innertube_url)
        .to_return(status: 200, body: sample_innertube_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns a TranscriptList" do
      result = fetcher.fetch(video_id)
      expect(result).to be_a(YoutubeRb::Transcript::TranscriptList)
    end

    it "returns a TranscriptList with the correct video_id" do
      result = fetcher.fetch(video_id)
      expect(result.video_id).to eq(video_id)
    end

    it "makes a GET request to the watch URL" do
      fetcher.fetch(video_id)
      expect(WebMock).to have_requested(:get, watch_url)
    end

    it "makes a POST request to the innertube API" do
      fetcher.fetch(video_id)
      expect(WebMock).to have_requested(:post, innertube_url)
    end

    it "includes Accept-Language header in watch request" do
      fetcher.fetch(video_id)
      expect(WebMock).to have_requested(:get, watch_url)
        .with(headers: { "Accept-Language" => "en-US" })
    end

    it "includes proper body in innertube request" do
      fetcher.fetch(video_id)
      expect(WebMock).to(have_requested(:post, innertube_url)
        .with do |req|
          body = JSON.parse(req.body)
          body["videoId"] == video_id && body["context"]["client"]["clientName"] == "ANDROID"
        end)
    end
  end

  describe "error handling" do
    describe "when IP is blocked (429 response)" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 429, body: "Too Many Requests")
      end

      it "raises IpBlocked error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::IpBlocked)
      end
    end

    describe "when CAPTCHA is detected" do
      let(:captcha_html) do
        '<html><body><div class="g-recaptcha" data-sitekey="abc"></div></body></html>'
      end

      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: captcha_html)
      end

      it "raises IpBlocked error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::IpBlocked)
      end
    end

    describe "when API key cannot be found" do
      let(:no_api_key_html) do
        "<html><body>No API key here</body></html>"
      end

      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: no_api_key_html)
      end

      it "raises YouTubeDataUnparsable error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::YouTubeDataUnparsable)
      end
    end

    describe "when video is unavailable" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(status: 200, body: {
            "playabilityStatus" => {
              "status" => "ERROR",
              "reason" => "This video is unavailable"
            }
          }.to_json)
      end

      it "raises VideoUnavailable error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::VideoUnavailable)
      end
    end

    describe "when video ID looks like a URL" do
      let(:url_video_id) { "https://www.youtube.com/watch?v=abc123" }

      before do
        stub_request(:get, "https://www.youtube.com/watch?v=#{url_video_id}")
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(status: 200, body: {
            "playabilityStatus" => {
              "status" => "ERROR",
              "reason" => "This video is unavailable"
            }
          }.to_json)
      end

      it "raises InvalidVideoId error" do
        expect { fetcher.fetch(url_video_id) }.to raise_error(YoutubeRb::Transcript::InvalidVideoId)
      end
    end

    describe "when video is age restricted" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(status: 200, body: {
            "playabilityStatus" => {
              "status" => "LOGIN_REQUIRED",
              "reason" => "This video may be inappropriate for some users."
            }
          }.to_json)
      end

      it "raises AgeRestricted error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::AgeRestricted)
      end
    end

    describe "when bot is detected" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(status: 200, body: {
            "playabilityStatus" => {
              "status" => "LOGIN_REQUIRED",
              "reason" => "Sign in to confirm you're not a bot"
            }
          }.to_json)
      end

      it "raises RequestBlocked error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::RequestBlocked)
      end
    end

    describe "when video is unplayable with subreasons" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(status: 200, body: {
            "playabilityStatus" => {
              "status" => "ERROR",
              "reason" => "Video unavailable",
              "errorScreen" => {
                "playerErrorMessageRenderer" => {
                  "subreason" => {
                    "runs" => [
                      { "text" => "This video is private" },
                      { "text" => "Please contact the owner" }
                    ]
                  }
                }
              }
            }
          }.to_json)
      end

      it "raises VideoUnplayable error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::VideoUnplayable)
      end
    end

    describe "when transcripts are disabled" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(status: 200, body: {
            "playabilityStatus" => { "status" => "OK" },
            "captions" => {}
          }.to_json)
      end

      it "raises TranscriptsDisabled error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::TranscriptsDisabled)
      end
    end

    describe "when captions is nil" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(status: 200, body: {
            "playabilityStatus" => { "status" => "OK" }
          }.to_json)
      end

      it "raises TranscriptsDisabled error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::TranscriptsDisabled)
      end
    end

    describe "when captionTracks is missing" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(status: 200, body: {
            "playabilityStatus" => { "status" => "OK" },
            "captions" => {
              "playerCaptionsTracklistRenderer" => {
                "translationLanguages" => []
              }
            }
          }.to_json)
      end

      it "raises TranscriptsDisabled error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::TranscriptsDisabled)
      end
    end

    describe "when HTTP request fails" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises YouTubeRequestFailed error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::YouTubeRequestFailed)
      end
    end

    describe "when innertube API returns error" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(status: 403, body: "Forbidden")
      end

      it "raises YouTubeRequestFailed error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::YouTubeRequestFailed)
      end
    end
  end

  describe "consent cookie handling" do
    let(:consent_html) do
      <<~HTML
        <!DOCTYPE html>
        <html>
        <body>
          <form action="https://consent.youtube.com/s">
            <input name="v" value="cb.20231201-01-p1.en+FX+999">
          </form>
        </body>
        </html>
      HTML
    end

    context "when consent is required and resolved" do
      before do
        stub_request(:get, watch_url)
          .to_return(
            { status: 200, body: consent_html },
            { status: 200, body: sample_html }
          )

        stub_request(:post, innertube_url)
          .to_return(status: 200, body: sample_innertube_response.to_json)
      end

      it "retries after setting consent cookie" do
        result = fetcher.fetch(video_id)
        expect(result).to be_a(YoutubeRb::Transcript::TranscriptList)
        expect(WebMock).to have_requested(:get, watch_url).times(2)
      end

      it "includes consent cookie in second request" do
        fetcher.fetch(video_id)
        expect(WebMock).to have_requested(:get, watch_url)
          .with(headers: { "Cookie" => /CONSENT=YES\+/ })
      end
    end

    context "when consent cannot be resolved" do
      let(:no_value_consent_html) do
        <<~HTML
          <!DOCTYPE html>
          <html>
          <body>
            <form action="https://consent.youtube.com/s">
              <input name="other" value="something">
            </form>
          </body>
          </html>
        HTML
      end

      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: no_value_consent_html)
      end

      it "raises FailedToCreateConsentCookie error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::FailedToCreateConsentCookie)
      end
    end

    context "when consent page persists after cookie" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: consent_html)
      end

      it "raises FailedToCreateConsentCookie error" do
        expect { fetcher.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::FailedToCreateConsentCookie)
      end
    end
  end

  describe "HTML unescaping" do
    let(:escaped_html) do
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>Test &amp; Video</title></head>
        <body>
          <script>
            var ytcfg = {&quot;INNERTUBE_API_KEY&quot;: &quot;#{api_key}&quot;};
          </script>
        </body>
        </html>
      HTML
    end

    before do
      stub_request(:get, watch_url)
        .to_return(status: 200, body: escaped_html)

      stub_request(:post, innertube_url)
        .to_return(status: 200, body: sample_innertube_response.to_json)
    end

    it "properly unescapes HTML entities" do
      result = fetcher.fetch(video_id)
      expect(result).to be_a(YoutubeRb::Transcript::TranscriptList)
    end
  end

  describe "with proxy config" do
    let(:proxy_config) do
      double("proxy_config", retries_when_blocked: 3)
    end

    let(:fetcher_with_proxy) do
      described_class.new(http_client: http_client, proxy_config: proxy_config)
    end

    context "when request is blocked and retries configured" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(
            { status: 200,
              body: { "playabilityStatus" => { "status" => "LOGIN_REQUIRED",
                                               "reason" => "Sign in to confirm you're not a bot" } }.to_json },
            { status: 200,
              body: { "playabilityStatus" => { "status" => "LOGIN_REQUIRED",
                                               "reason" => "Sign in to confirm you're not a bot" } }.to_json },
            { status: 200, body: sample_innertube_response.to_json }
          )
      end

      it "retries the request" do
        result = fetcher_with_proxy.fetch(video_id)
        expect(result).to be_a(YoutubeRb::Transcript::TranscriptList)
        expect(WebMock).to have_requested(:post, innertube_url).times(3)
      end
    end

    context "when all retries fail" do
      before do
        stub_request(:get, watch_url)
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(status: 200, body: { "playabilityStatus" => { "status" => "LOGIN_REQUIRED",
                                                                   "reason" => "Sign in to confirm you're not a bot" } }.to_json)
      end

      it "raises RequestBlocked after exhausting retries" do
        expect { fetcher_with_proxy.fetch(video_id) }.to raise_error(YoutubeRb::Transcript::RequestBlocked)
        expect(WebMock).to have_requested(:post, innertube_url).times(3)
      end
    end
  end

  describe "PlayabilityStatus module" do
    it "defines OK status" do
      expect(YoutubeRb::Transcript::PlayabilityStatus::OK).to eq("OK")
    end

    it "defines ERROR status" do
      expect(YoutubeRb::Transcript::PlayabilityStatus::ERROR).to eq("ERROR")
    end

    it "defines LOGIN_REQUIRED status" do
      expect(YoutubeRb::Transcript::PlayabilityStatus::LOGIN_REQUIRED).to eq("LOGIN_REQUIRED")
    end
  end

  describe "PlayabilityFailedReason module" do
    it "defines BOT_DETECTED reason" do
      expect(YoutubeRb::Transcript::PlayabilityFailedReason::BOT_DETECTED).to eq("Sign in to confirm you're not a bot")
    end

    it "defines AGE_RESTRICTED reason" do
      expect(YoutubeRb::Transcript::PlayabilityFailedReason::AGE_RESTRICTED).to eq("This video may be inappropriate for some users.")
    end

    it "defines VIDEO_UNAVAILABLE reason" do
      expect(YoutubeRb::Transcript::PlayabilityFailedReason::VIDEO_UNAVAILABLE).to eq("This video is unavailable")
    end
  end
end
