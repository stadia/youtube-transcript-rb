# frozen_string_literal: true

require "spec_helper"
require "youtube_rb/transcript"

RSpec.describe YoutubeRb::Transcript do
  describe YoutubeRb::Transcript::TranslationLanguage do
    let(:language) { described_class.new(language: "Spanish", language_code: "es") }

    describe "#initialize" do
      it "sets the language" do
        expect(language.language).to eq("Spanish")
      end

      it "sets the language_code" do
        expect(language.language_code).to eq("es")
      end
    end
  end

  describe YoutubeRb::Transcript::TranscriptSnippet do
    let(:snippet) { described_class.new(text: "Hello world", start: 1.5, duration: 2.0) }

    describe "#initialize" do
      it "sets the text" do
        expect(snippet.text).to eq("Hello world")
      end

      it "sets the start time" do
        expect(snippet.start).to eq(1.5)
      end

      it "sets the duration" do
        expect(snippet.duration).to eq(2.0)
      end

      it "converts start to float" do
        snippet = described_class.new(text: "test", start: "1.5", duration: 2)
        expect(snippet.start).to eq(1.5)
        expect(snippet.start).to be_a(Float)
      end

      it "converts duration to float" do
        snippet = described_class.new(text: "test", start: 1, duration: "2.5")
        expect(snippet.duration).to eq(2.5)
        expect(snippet.duration).to be_a(Float)
      end
    end

    describe "#to_h" do
      it "returns a hash representation" do
        hash = snippet.to_h
        expect(hash).to be_a(Hash)
        expect(hash["text"]).to eq("Hello world")
        expect(hash["start"]).to eq(1.5)
        expect(hash["duration"]).to eq(2.0)
      end
    end
  end

  describe YoutubeRb::Transcript::FetchedTranscript do
    let(:transcript) do
      described_class.new(
        video_id: "test_video",
        language: "English",
        language_code: "en",
        is_generated: false
      )
    end

    let(:snippet1) { YoutubeRb::Transcript::TranscriptSnippet.new(text: "Hello", start: 0.0, duration: 1.5) }
    let(:snippet2) { YoutubeRb::Transcript::TranscriptSnippet.new(text: "World", start: 1.5, duration: 2.0) }

    describe "#initialize" do
      it "sets the video_id" do
        expect(transcript.video_id).to eq("test_video")
      end

      it "sets the language" do
        expect(transcript.language).to eq("English")
      end

      it "sets the language_code" do
        expect(transcript.language_code).to eq("en")
      end

      it "sets is_generated" do
        expect(transcript.is_generated).to be(false)
      end

      it "initializes with empty snippets by default" do
        expect(transcript.snippets).to eq([])
      end

      it "can initialize with snippets" do
        t = described_class.new(
          video_id: "test",
          language: "English",
          language_code: "en",
          is_generated: false,
          snippets: [snippet1, snippet2]
        )
        expect(t.snippets.length).to eq(2)
      end
    end

    describe "#add_snippet" do
      it "adds a snippet" do
        transcript.add_snippet(snippet1)
        expect(transcript.snippets.length).to eq(1)
        expect(transcript.snippets.first).to eq(snippet1)
      end

      it "returns self for chaining" do
        result = transcript.add_snippet(snippet1)
        expect(result).to eq(transcript)
      end
    end

    describe "Enumerable" do
      before do
        transcript.add_snippet(snippet1)
        transcript.add_snippet(snippet2)
      end

      it "is enumerable" do
        expect(transcript).to respond_to(:each)
        expect(transcript).to respond_to(:map)
        expect(transcript).to respond_to(:select)
      end

      it "iterates over snippets" do
        texts = transcript.map(&:text)
        expect(texts).to eq(%w[Hello World])
      end

      describe "#each" do
        it "yields each snippet" do
          yielded = transcript.map { |s| s }
          expect(yielded).to eq([snippet1, snippet2])
        end
      end
    end

    describe "#[]" do
      before do
        transcript.add_snippet(snippet1)
        transcript.add_snippet(snippet2)
      end

      it "returns snippet by index" do
        expect(transcript[0]).to eq(snippet1)
        expect(transcript[1]).to eq(snippet2)
      end

      it "supports negative indices" do
        expect(transcript[-1]).to eq(snippet2)
      end
    end

    describe "#length" do
      it "returns 0 for empty transcript" do
        expect(transcript.length).to eq(0)
      end

      it "returns the number of snippets" do
        transcript.add_snippet(snippet1)
        transcript.add_snippet(snippet2)
        expect(transcript.length).to eq(2)
      end
    end

    describe "#size" do
      it "is an alias for length" do
        transcript.add_snippet(snippet1)
        expect(transcript.size).to eq(transcript.length)
      end
    end

    describe "#to_raw_data" do
      before do
        transcript.add_snippet(snippet1)
        transcript.add_snippet(snippet2)
      end

      it "returns an array of hashes" do
        data = transcript.to_raw_data
        expect(data).to be_an(Array)
        expect(data.length).to eq(2)
      end

      it "contains snippet data as hashes" do
        data = transcript.to_raw_data
        expect(data[0]).to eq({ "text" => "Hello", "start" => 0.0, "duration" => 1.5 })
        expect(data[1]).to eq({ "text" => "World", "start" => 1.5, "duration" => 2.0 })
      end
    end

    describe "#generated?" do
      it "returns true when is_generated is true" do
        t = described_class.new(
          video_id: "test",
          language: "English",
          language_code: "en",
          is_generated: true
        )
        expect(t.generated?).to be true
      end

      it "returns false when is_generated is false" do
        expect(transcript.generated?).to be false
      end
    end
  end

  describe YoutubeRb::Transcript::TranscriptMetadata do
    let(:http_client) { double("Faraday::Connection") }
    let(:translation_languages) do
      [
        YoutubeRb::Transcript::TranslationLanguage.new(language: "Spanish", language_code: "es"),
        YoutubeRb::Transcript::TranslationLanguage.new(language: "French", language_code: "fr")
      ]
    end

    let(:transcript) do
      described_class.new(
        http_client: http_client,
        video_id: "test_video",
        url: "https://www.youtube.com/api/timedtext?v=test_video",
        language: "English",
        language_code: "en",
        is_generated: false,
        translation_languages: translation_languages
      )
    end

    let(:transcript_without_translations) do
      described_class.new(
        http_client: http_client,
        video_id: "test_video",
        url: "https://www.youtube.com/api/timedtext?v=test_video",
        language: "English",
        language_code: "en",
        is_generated: false,
        translation_languages: []
      )
    end

    describe "#initialize" do
      it "sets the video_id" do
        expect(transcript.video_id).to eq("test_video")
      end

      it "sets the language" do
        expect(transcript.language).to eq("English")
      end

      it "sets the language_code" do
        expect(transcript.language_code).to eq("en")
      end

      it "sets is_generated" do
        expect(transcript.is_generated).to be(false)
      end

      it "sets translation_languages" do
        expect(transcript.translation_languages.length).to eq(2)
      end
    end

    describe "#translatable?" do
      it "returns true when translation_languages is not empty" do
        expect(transcript.translatable?).to be true
      end

      it "returns false when translation_languages is empty" do
        expect(transcript_without_translations.translatable?).to be false
      end
    end

    describe "#is_translatable" do
      it "is an alias for translatable?" do
        expect(transcript.is_translatable).to eq(transcript.translatable?)
      end
    end

    describe "#generated?" do
      it "returns the value of is_generated" do
        expect(transcript.generated?).to be false
      end
    end

    describe "#translate" do
      it "raises NotTranslatable when not translatable" do
        expect do
          transcript_without_translations.translate("es")
        end.to raise_error(YoutubeRb::Transcript::NotTranslatable)
      end

      it "raises TranslationLanguageNotAvailable for unavailable language" do
        expect do
          transcript.translate("de")
        end.to raise_error(YoutubeRb::Transcript::TranslationLanguageNotAvailable)
      end

      it "returns a new Transcript for available language" do
        translated = transcript.translate("es")
        expect(translated).to be_a(described_class)
        expect(translated.language_code).to eq("es")
        expect(translated.language).to eq("Spanish")
      end

      it "appends tlang to URL" do
        translated = transcript.translate("fr")
        # The URL should contain &tlang=fr
        expect(translated.instance_variable_get(:@url)).to include("&tlang=fr")
      end

      it "marks translated transcript as generated" do
        translated = transcript.translate("es")
        expect(translated.is_generated).to be true
      end

      it "translated transcript has no translation languages" do
        translated = transcript.translate("es")
        expect(translated.translation_languages).to eq([])
      end
    end

    describe "#fetch" do
      let(:xml_response) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0" dur="2.5">Hello world</text>
            <text start="2.5" dur="3.0">This is a test</text>
          </transcript>
        XML
      end

      let(:response) { double("Response", status: 200, body: xml_response) }

      before do
        allow(http_client).to receive(:get).and_return(response)
      end

      it "returns a FetchedTranscript" do
        result = transcript.fetch
        expect(result).to be_a(YoutubeRb::Transcript::FetchedTranscript)
      end

      it "parses the transcript snippets" do
        result = transcript.fetch
        expect(result.length).to eq(2)
        expect(result[0].text).to eq("Hello world")
        expect(result[1].text).to eq("This is a test")
      end

      it "sets metadata on FetchedTranscript" do
        result = transcript.fetch
        expect(result.video_id).to eq("test_video")
        expect(result.language).to eq("English")
        expect(result.language_code).to eq("en")
        expect(result.is_generated).to be(false)
      end

      it "raises PoTokenRequired when URL contains &exp=xpe" do
        po_transcript = described_class.new(
          http_client: http_client,
          video_id: "test_video",
          url: "https://www.youtube.com/api/timedtext?v=test_video&exp=xpe",
          language: "English",
          language_code: "en",
          is_generated: false,
          translation_languages: []
        )

        expect { po_transcript.fetch }.to raise_error(YoutubeRb::Transcript::PoTokenRequired)
      end

      context "when HTTP error occurs" do
        it "raises IpBlocked for 429 status" do
          allow(http_client).to receive(:get).and_return(double("Response", status: 429, body: ""))
          expect { transcript.fetch }.to raise_error(YoutubeRb::Transcript::IpBlocked)
        end

        it "raises YouTubeRequestFailed for 4xx/5xx status" do
          allow(http_client).to receive(:get).and_return(double("Response", status: 500, body: ""))
          expect { transcript.fetch }.to raise_error(YoutubeRb::Transcript::YouTubeRequestFailed)
        end
      end

      context "with preserve_formatting option" do
        let(:xml_with_formatting) do
          <<~XML
            <?xml version="1.0" encoding="utf-8" ?>
            <transcript>
              <text start="0.0" dur="2.5">Hello &lt;b&gt;world&lt;/b&gt;</text>
            </transcript>
          XML
        end

        it "preserves formatting tags when preserve_formatting is true" do
          allow(http_client).to receive(:get).and_return(double("Response", status: 200, body: xml_with_formatting))
          result = transcript.fetch(preserve_formatting: true)
          expect(result[0].text).to include("<b>")
        end

        it "strips formatting tags when preserve_formatting is false" do
          allow(http_client).to receive(:get).and_return(double("Response", status: 200, body: xml_with_formatting))
          result = transcript.fetch(preserve_formatting: false)
          expect(result[0].text).not_to include("<b>")
          expect(result[0].text).to include("world")
        end
      end
    end

    describe "#to_s" do
      it "includes language_code and language" do
        str = transcript.to_s
        expect(str).to include("en")
        expect(str).to include("English")
      end

      it "includes [TRANSLATABLE] when translatable" do
        expect(transcript.to_s).to include("[TRANSLATABLE]")
      end

      it "does not include [TRANSLATABLE] when not translatable" do
        expect(transcript_without_translations.to_s).not_to include("[TRANSLATABLE]")
      end
    end
  end
end
