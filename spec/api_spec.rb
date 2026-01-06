# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe YoutubeRb::Transcript::YouTubeTranscriptApi do
  let(:api) { described_class.new }
  let(:video_id) { "dQw4w9WgXcQ" }
  let(:api_key) { "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8" }

  let(:watch_url) { "https://www.youtube.com/watch?v=#{video_id}" }
  let(:innertube_url) { "https://www.youtube.com/youtubei/v1/player?key=#{api_key}" }
  let(:transcript_url) { "https://www.youtube.com/api/timedtext?v=#{video_id}&lang=en" }

  let(:sample_html) do
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Test Video</title></head>
      <body>
        <script>
          var ytcfg = {"INNERTUBE_API_KEY": "#{api_key}"};
        </script>
      </body>
      </html>
    HTML
  end

  let(:sample_innertube_response) do
    {
      "playabilityStatus" => { "status" => "OK" },
      "captions" => {
        "playerCaptionsTracklistRenderer" => {
          "captionTracks" => [
            {
              "baseUrl" => transcript_url,
              "name" => { "runs" => [{ "text" => "English" }] },
              "languageCode" => "en",
              "isTranslatable" => true
            },
            {
              "baseUrl" => "https://www.youtube.com/api/timedtext?v=#{video_id}&lang=es",
              "name" => { "runs" => [{ "text" => "Spanish" }] },
              "languageCode" => "es",
              "isTranslatable" => false
            }
          ],
          "translationLanguages" => [
            { "languageCode" => "fr", "languageName" => { "runs" => [{ "text" => "French" }] } }
          ]
        }
      }
    }
  end

  let(:sample_transcript_xml) do
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <transcript>
        <text start="0.0" dur="2.5">Hello world</text>
        <text start="2.5" dur="3.0">This is a test</text>
        <text start="5.5" dur="2.0">Thank you</text>
      </transcript>
    XML
  end

  describe "#initialize" do
    it "creates a default HTTP client when none provided" do
      api = described_class.new
      expect(api.instance_variable_get(:@http_client)).to be_a(Faraday::Connection)
    end

    it "accepts a custom HTTP client" do
      custom_client = Faraday.new
      api = described_class.new(http_client: custom_client)
      expect(api.instance_variable_get(:@http_client)).to eq(custom_client)
    end

    it "accepts a proxy configuration" do
      proxy_config = double("proxy_config")
      api = described_class.new(proxy_config: proxy_config)
      expect(api.instance_variable_get(:@proxy_config)).to eq(proxy_config)
    end

    it "creates a TranscriptListFetcher" do
      api = described_class.new
      expect(api.instance_variable_get(:@fetcher)).to be_a(YoutubeRb::Transcript::TranscriptListFetcher)
    end
  end

  describe "#fetch" do
    before do
      stub_request(:get, watch_url)
        .to_return(status: 200, body: sample_html)

      stub_request(:post, innertube_url)
        .to_return(status: 200, body: sample_innertube_response.to_json)

      stub_request(:get, transcript_url)
        .to_return(status: 200, body: sample_transcript_xml)
    end

    it "returns a FetchedTranscript" do
      result = api.fetch(video_id)
      expect(result).to be_a(YoutubeRb::Transcript::FetchedTranscript)
    end

    it "fetches the transcript with correct video_id" do
      result = api.fetch(video_id)
      expect(result.video_id).to eq(video_id)
    end

    it "fetches the transcript with correct language" do
      result = api.fetch(video_id, languages: ["en"])
      expect(result.language_code).to eq("en")
      expect(result.language).to eq("English")
    end

    it "contains transcript snippets" do
      result = api.fetch(video_id)
      expect(result.length).to eq(3)
      expect(result.first.text).to eq("Hello world")
    end

    it "respects language preference order" do
      stub_request(:get, "https://www.youtube.com/api/timedtext?v=#{video_id}&lang=es")
        .to_return(status: 200, body: sample_transcript_xml)

      result = api.fetch(video_id, languages: ["es", "en"])
      expect(result.language_code).to eq("es")
    end

    it "falls back to next language if first not available" do
      result = api.fetch(video_id, languages: ["ja", "en"])
      expect(result.language_code).to eq("en")
    end

    it "raises NoTranscriptFound when no language matches" do
      expect {
        api.fetch(video_id, languages: ["ja", "ko", "zh"])
      }.to raise_error(YoutubeRb::Transcript::NoTranscriptFound)
    end

    context "with preserve_formatting option" do
      let(:formatted_transcript_xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <transcript>
            <text start="0.0" dur="2.5">Hello &lt;b&gt;world&lt;/b&gt;</text>
            <text start="2.5" dur="3.0">This is &lt;i&gt;important&lt;/i&gt;</text>
          </transcript>
        XML
      end

      before do
        stub_request(:get, transcript_url)
          .to_return(status: 200, body: formatted_transcript_xml)
      end

      it "preserves formatting when requested" do
        result = api.fetch(video_id, preserve_formatting: true)
        expect(result.first.text).to include("<b>")
        expect(result.first.text).to eq("Hello <b>world</b>")
      end

      it "removes formatting by default" do
        result = api.fetch(video_id, preserve_formatting: false)
        expect(result.first.text).not_to include("<b>")
        expect(result.first.text).to eq("Hello world")
      end
    end
  end

  describe "#list" do
    before do
      stub_request(:get, watch_url)
        .to_return(status: 200, body: sample_html)

      stub_request(:post, innertube_url)
        .to_return(status: 200, body: sample_innertube_response.to_json)
    end

    it "returns a TranscriptList" do
      result = api.list(video_id)
      expect(result).to be_a(YoutubeRb::Transcript::TranscriptList)
    end

    it "returns a list with the correct video_id" do
      result = api.list(video_id)
      expect(result.video_id).to eq(video_id)
    end

    it "includes all available transcripts" do
      result = api.list(video_id)
      expect(result.count).to eq(2)
    end

    it "allows finding specific transcripts" do
      result = api.list(video_id)
      transcript = result.find_transcript(["en"])
      expect(transcript.language_code).to eq("en")
    end

    context "when video is unavailable" do
      before do
        stub_request(:post, innertube_url)
          .to_return(status: 200, body: {
            "playabilityStatus" => {
              "status" => "ERROR",
              "reason" => "This video is unavailable"
            }
          }.to_json)
      end

      it "raises VideoUnavailable error" do
        expect { api.list(video_id) }.to raise_error(YoutubeRb::Transcript::VideoUnavailable)
      end
    end

    context "when transcripts are disabled" do
      before do
        stub_request(:post, innertube_url)
          .to_return(status: 200, body: {
            "playabilityStatus" => { "status" => "OK" },
            "captions" => {}
          }.to_json)
      end

      it "raises TranscriptsDisabled error" do
        expect { api.list(video_id) }.to raise_error(YoutubeRb::Transcript::TranscriptsDisabled)
      end
    end
  end

  describe "#fetch_all" do
    let(:video_ids) { ["video1", "video2", "video3"] }

    before do
      video_ids.each do |vid|
        stub_request(:get, "https://www.youtube.com/watch?v=#{vid}")
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(status: 200, body: {
            "playabilityStatus" => { "status" => "OK" },
            "captions" => {
              "playerCaptionsTracklistRenderer" => {
                "captionTracks" => [
                  {
                    "baseUrl" => "https://www.youtube.com/api/timedtext?v=#{vid}&lang=en",
                    "name" => { "runs" => [{ "text" => "English" }] },
                    "languageCode" => "en",
                    "isTranslatable" => false
                  }
                ],
                "translationLanguages" => []
              }
            }
          }.to_json)

        stub_request(:get, "https://www.youtube.com/api/timedtext?v=#{vid}&lang=en")
          .to_return(status: 200, body: sample_transcript_xml)
      end
    end

    it "returns a hash of transcripts" do
      results = api.fetch_all(video_ids)
      expect(results).to be_a(Hash)
      expect(results.keys).to contain_exactly(*video_ids)
    end

    it "fetches all video transcripts" do
      results = api.fetch_all(video_ids)
      results.each do |vid, transcript|
        expect(transcript).to be_a(YoutubeRb::Transcript::FetchedTranscript)
        expect(transcript.video_id).to eq(vid)
      end
    end

    it "respects language preference" do
      results = api.fetch_all(video_ids, languages: ["en"])
      results.each do |_, transcript|
        expect(transcript.language_code).to eq("en")
      end
    end

    it "yields each result when block given" do
      yielded = []
      api.fetch_all(video_ids) do |video_id, result|
        yielded << [video_id, result.class]
      end
      expect(yielded.length).to eq(3)
      yielded.each do |vid, klass|
        expect(video_ids).to include(vid)
        expect(klass).to eq(YoutubeRb::Transcript::FetchedTranscript)
      end
    end

    context "when a video fails" do
      let(:failing_video_ids) { ["fail_video"] }

      before do
        WebMock.reset!

        # Setup a failing video
        stub_request(:get, "https://www.youtube.com/watch?v=fail_video")
          .to_return(status: 200, body: sample_html)

        stub_request(:post, innertube_url)
          .to_return(status: 200, body: {
            "playabilityStatus" => {
              "status" => "ERROR",
              "reason" => "This video is unavailable"
            }
          }.to_json)
      end

      it "raises error by default" do
        expect { api.fetch_all(failing_video_ids) }.to raise_error(YoutubeRb::Transcript::VideoUnavailable)
      end

      it "continues on error when configured" do
        results = api.fetch_all(failing_video_ids, continue_on_error: true)
        # No successful ones
        expect(results).to be_empty
      end

      it "yields errors when continue_on_error is true" do
        errors = []
        api.fetch_all(failing_video_ids, continue_on_error: true) do |video_id, result|
          errors << [video_id, result] if result.is_a?(StandardError)
        end
        expect(errors.length).to eq(1)
        expect(errors.first[0]).to eq("fail_video")
        expect(errors.first[1]).to be_a(YoutubeRb::Transcript::VideoUnavailable)
      end
    end

    context "with empty video list" do
      it "returns empty hash" do
        results = api.fetch_all([])
        expect(results).to eq({})
      end
    end
  end

  describe "convenience module methods" do
    before do
      stub_request(:get, watch_url)
        .to_return(status: 200, body: sample_html)

      stub_request(:post, innertube_url)
        .to_return(status: 200, body: sample_innertube_response.to_json)

      stub_request(:get, transcript_url)
        .to_return(status: 200, body: sample_transcript_xml)
    end

    describe "YoutubeRb::Transcript.fetch" do
      it "fetches a transcript" do
        result = YoutubeRb::Transcript.fetch(video_id)
        expect(result).to be_a(YoutubeRb::Transcript::FetchedTranscript)
      end

      it "accepts language option" do
        result = YoutubeRb::Transcript.fetch(video_id, languages: ["en"])
        expect(result.language_code).to eq("en")
      end

      it "accepts preserve_formatting option" do
        result = YoutubeRb::Transcript.fetch(video_id, preserve_formatting: false)
        expect(result).to be_a(YoutubeRb::Transcript::FetchedTranscript)
      end
    end

    describe "YoutubeRb::Transcript.list" do
      it "lists available transcripts" do
        result = YoutubeRb::Transcript.list(video_id)
        expect(result).to be_a(YoutubeRb::Transcript::TranscriptList)
      end
    end
  end

  describe "default HTTP client configuration" do
    it "sets timeout" do
      api = described_class.new
      client = api.instance_variable_get(:@http_client)
      expect(client.options.timeout).to eq(30)
    end

    it "sets open_timeout" do
      api = described_class.new
      client = api.instance_variable_get(:@http_client)
      expect(client.options.open_timeout).to eq(30)
    end
  end
end
