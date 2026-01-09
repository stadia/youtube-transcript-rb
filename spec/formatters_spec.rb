# frozen_string_literal: true

require "spec_helper"

RSpec.describe YoutubeRb::Formatters do
  # Helper to create a FetchedTranscript with snippets
  def create_transcript(video_id: "test123", language: "English", language_code: "en", is_generated: false,
                        snippets: nil)
    snippets ||= [
      YoutubeRb::Transcript::TranscriptSnippet.new(text: "Hello world", start: 0.0, duration: 2.5),
      YoutubeRb::Transcript::TranscriptSnippet.new(text: "This is a test", start: 2.5, duration: 3.0),
      YoutubeRb::Transcript::TranscriptSnippet.new(text: "Thank you", start: 5.5, duration: 2.0)
    ]

    YoutubeRb::Transcript::FetchedTranscript.new(
      video_id: video_id,
      language: language,
      language_code: language_code,
      is_generated: is_generated,
      snippets: snippets
    )
  end

  let(:transcript) { create_transcript }
  let(:transcript2) { create_transcript(video_id: "video2", language_code: "es", language: "Spanish") }
  let(:transcripts) { [transcript, transcript2] }

  describe YoutubeRb::Formatters::Formatter do
    let(:formatter) { described_class.new }

    describe "#format_transcript" do
      it "raises NotImplementedError" do
        expect { formatter.format_transcript(transcript) }.to raise_error(NotImplementedError)
      end
    end

    describe "#format_transcripts" do
      it "raises NotImplementedError" do
        expect { formatter.format_transcripts(transcripts) }.to raise_error(NotImplementedError)
      end
    end
  end

  describe YoutubeRb::Formatters::JSONFormatter do
    let(:formatter) { described_class.new }

    describe "#format_transcript" do
      it "returns valid JSON" do
        result = formatter.format_transcript(transcript)
        expect { JSON.parse(result) }.not_to raise_error
      end

      it "contains all snippets" do
        result = formatter.format_transcript(transcript)
        parsed = JSON.parse(result)
        expect(parsed.length).to eq(3)
      end

      it "includes text, start, and duration for each snippet" do
        result = formatter.format_transcript(transcript)
        parsed = JSON.parse(result)

        expect(parsed[0]["text"]).to eq("Hello world")
        expect(parsed[0]["start"]).to eq(0.0)
        expect(parsed[0]["duration"]).to eq(2.5)
      end

      it "supports JSON options" do
        # JSON.generate with indent requires array_nl and object_nl for newlines
        result = formatter.format_transcript(transcript, indent: "  ", array_nl: "\n", object_nl: "\n")
        expect(result).to include("\n")
      end
    end

    describe "#format_transcripts" do
      it "returns valid JSON array" do
        result = formatter.format_transcripts(transcripts)
        parsed = JSON.parse(result)
        expect(parsed).to be_an(Array)
        expect(parsed.length).to eq(2)
      end

      it "contains all transcripts" do
        result = formatter.format_transcripts(transcripts)
        parsed = JSON.parse(result)
        expect(parsed[0].length).to eq(3)
        expect(parsed[1].length).to eq(3)
      end
    end
  end

  describe YoutubeRb::Formatters::TextFormatter do
    let(:formatter) { described_class.new }

    describe "#format_transcript" do
      it "returns plain text with newlines" do
        result = formatter.format_transcript(transcript)
        expect(result).to eq("Hello world\nThis is a test\nThank you")
      end

      it "contains only text, no timestamps" do
        result = formatter.format_transcript(transcript)
        expect(result).not_to include("0.0")
        expect(result).not_to include("-->")
      end
    end

    describe "#format_transcripts" do
      it "separates transcripts with triple newlines" do
        result = formatter.format_transcripts(transcripts)
        expect(result).to include("\n\n\n")
      end

      it "contains all transcript texts" do
        result = formatter.format_transcripts(transcripts)
        expect(result).to include("Hello world")
        expect(result).to include("Thank you")
      end
    end
  end

  describe YoutubeRb::Formatters::PrettyPrintFormatter do
    let(:formatter) { described_class.new }

    describe "#format_transcript" do
      it "returns a string" do
        result = formatter.format_transcript(transcript)
        expect(result).to be_a(String)
      end

      it "contains transcript data" do
        result = formatter.format_transcript(transcript)
        expect(result).to include("Hello world")
        expect(result).to include("text")
        expect(result).to include("start")
        expect(result).to include("duration")
      end

      it "is formatted with indentation" do
        result = formatter.format_transcript(transcript)
        # PP output typically has newlines for arrays
        expect(result).to include("\n") if transcript.length > 1
      end

      it "accepts width option" do
        result = formatter.format_transcript(transcript, width: 40)
        expect(result).to be_a(String)
      end
    end

    describe "#format_transcripts" do
      it "returns a string containing all transcripts" do
        result = formatter.format_transcripts(transcripts)
        expect(result).to be_a(String)
        expect(result).to include("Hello world")
      end
    end
  end

  describe YoutubeRb::Formatters::SRTFormatter do
    let(:formatter) { described_class.new }

    describe "#format_transcript" do
      let(:result) { formatter.format_transcript(transcript) }

      it "includes sequence numbers starting from 1" do
        expect(result).to include("1\n")
        expect(result).to include("2\n")
        expect(result).to include("3\n")
      end

      it "uses comma as millisecond separator" do
        expect(result).to include(",")
        expect(result).not_to match(/\d{2}:\d{2}:\d{2}\.\d{3}/)
      end

      it "formats timestamps correctly" do
        expect(result).to include("00:00:00,000 --> 00:00:02,500")
        expect(result).to include("00:00:02,500 --> 00:00:05,500")
      end

      it "includes the text content" do
        expect(result).to include("Hello world")
        expect(result).to include("This is a test")
        expect(result).to include("Thank you")
      end

      it "separates entries with blank lines" do
        expect(result).to include("\n\n")
      end

      it "ends with a newline" do
        expect(result).to end_with("\n")
      end

      it "follows SRT format structure" do
        lines = result.split("\n\n")
        first_entry = lines[0].split("\n")

        expect(first_entry[0]).to eq("1")
        expect(first_entry[1]).to match(/\d{2}:\d{2}:\d{2},\d{3} --> \d{2}:\d{2}:\d{2},\d{3}/)
        expect(first_entry[2]).to eq("Hello world")
      end
    end

    describe "timestamp edge cases" do
      it "handles hours correctly" do
        snippets = [
          YoutubeRb::Transcript::TranscriptSnippet.new(text: "Long video", start: 3661.5, duration: 2.0)
        ]
        transcript = create_transcript(snippets: snippets)
        result = formatter.format_transcript(transcript)

        expect(result).to include("01:01:01,500")
      end

      it "handles overlapping timestamps" do
        snippets = [
          YoutubeRb::Transcript::TranscriptSnippet.new(text: "First", start: 0.0, duration: 5.0),
          YoutubeRb::Transcript::TranscriptSnippet.new(text: "Second", start: 2.0, duration: 3.0)
        ]
        transcript = create_transcript(snippets: snippets)
        result = formatter.format_transcript(transcript)

        # First snippet should end at second snippet's start
        expect(result).to include("00:00:00,000 --> 00:00:02,000")
      end
    end
  end

  describe YoutubeRb::Formatters::WebVTTFormatter do
    let(:formatter) { described_class.new }

    describe "#format_transcript" do
      let(:result) { formatter.format_transcript(transcript) }

      it "starts with WEBVTT header" do
        expect(result).to start_with("WEBVTT\n\n")
      end

      it "uses period as millisecond separator" do
        expect(result).to match(/\d{2}:\d{2}:\d{2}\.\d{3}/)
        expect(result).not_to match(/\d{2}:\d{2}:\d{2},\d{3}/)
      end

      it "formats timestamps correctly" do
        expect(result).to include("00:00:00.000 --> 00:00:02.500")
        expect(result).to include("00:00:02.500 --> 00:00:05.500")
      end

      it "does not include sequence numbers" do
        lines = result.split("\n")
        # Skip WEBVTT header
        timestamp_lines = lines.select { |l| l.include?("-->") }
        timestamp_lines.each_with_index do |line, _i|
          prev_line = lines[lines.index(line) - 1]
          # Previous line should be empty or WEBVTT, not a number
          expect(prev_line).not_to match(/^\d+$/)
        end
      end

      it "includes the text content" do
        expect(result).to include("Hello world")
        expect(result).to include("This is a test")
        expect(result).to include("Thank you")
      end

      it "ends with a newline" do
        expect(result).to end_with("\n")
      end
    end

    describe "timestamp edge cases" do
      it "handles hours correctly" do
        snippets = [
          YoutubeRb::Transcript::TranscriptSnippet.new(text: "Long video", start: 3661.5, duration: 2.0)
        ]
        transcript = create_transcript(snippets: snippets)
        result = formatter.format_transcript(transcript)

        expect(result).to include("01:01:01.500")
      end
    end
  end

  describe YoutubeRb::Formatters::FormatterLoader do
    let(:loader) { described_class.new }

    describe "#load" do
      it "loads JSONFormatter for 'json'" do
        formatter = loader.load("json")
        expect(formatter).to be_a(YoutubeRb::Formatters::JSONFormatter)
      end

      it "loads TextFormatter for 'text'" do
        formatter = loader.load("text")
        expect(formatter).to be_a(YoutubeRb::Formatters::TextFormatter)
      end

      it "loads PrettyPrintFormatter for 'pretty'" do
        formatter = loader.load("pretty")
        expect(formatter).to be_a(YoutubeRb::Formatters::PrettyPrintFormatter)
      end

      it "loads SRTFormatter for 'srt'" do
        formatter = loader.load("srt")
        expect(formatter).to be_a(YoutubeRb::Formatters::SRTFormatter)
      end

      it "loads WebVTTFormatter for 'webvtt'" do
        formatter = loader.load("webvtt")
        expect(formatter).to be_a(YoutubeRb::Formatters::WebVTTFormatter)
      end

      it "defaults to PrettyPrintFormatter" do
        formatter = loader.load
        expect(formatter).to be_a(YoutubeRb::Formatters::PrettyPrintFormatter)
      end

      it "accepts symbol as formatter type" do
        formatter = loader.load(:json)
        expect(formatter).to be_a(YoutubeRb::Formatters::JSONFormatter)
      end

      it "raises UnknownFormatterType for invalid type" do
        expect { loader.load("invalid") }.to raise_error(
          YoutubeRb::Formatters::FormatterLoader::UnknownFormatterType
        )
      end

      it "includes available formats in error message" do
        loader.load("invalid")
      rescue YoutubeRb::Formatters::FormatterLoader::UnknownFormatterType => e
        expect(e.message).to include("json")
        expect(e.message).to include("text")
        expect(e.message).to include("srt")
        expect(e.message).to include("webvtt")
        expect(e.message).to include("pretty")
      end
    end

    describe "TYPES constant" do
      it "contains all expected formatter types" do
        expect(described_class::TYPES.keys).to contain_exactly("json", "pretty", "text", "webvtt", "srt")
      end

      it "is frozen" do
        expect(described_class::TYPES).to be_frozen
      end
    end
  end

  describe "integration tests" do
    let(:loader) { YoutubeRb::Formatters::FormatterLoader.new }

    it "can format transcript with each formatter type" do
      %w[json text pretty srt webvtt].each do |type|
        formatter = loader.load(type)
        result = formatter.format_transcript(transcript)
        expect(result).to be_a(String)
        expect(result.length).to be > 0
      end
    end

    it "can format multiple transcripts with each formatter type" do
      %w[json text pretty].each do |type|
        formatter = loader.load(type)
        result = formatter.format_transcripts(transcripts)
        expect(result).to be_a(String)
        expect(result.length).to be > 0
      end
    end
  end

  describe "empty transcript handling" do
    let(:empty_snippets) { [] }
    let(:empty_transcript) { create_transcript(snippets: empty_snippets) }

    it "JSONFormatter handles empty transcript" do
      formatter = YoutubeRb::Formatters::JSONFormatter.new
      result = formatter.format_transcript(empty_transcript)
      expect(JSON.parse(result)).to eq([])
    end

    it "TextFormatter handles empty transcript" do
      formatter = YoutubeRb::Formatters::TextFormatter.new
      result = formatter.format_transcript(empty_transcript)
      expect(result).to eq("")
    end

    it "SRTFormatter handles empty transcript" do
      formatter = YoutubeRb::Formatters::SRTFormatter.new
      result = formatter.format_transcript(empty_transcript)
      expect(result).to eq("\n")
    end

    it "WebVTTFormatter handles empty transcript" do
      formatter = YoutubeRb::Formatters::WebVTTFormatter.new
      result = formatter.format_transcript(empty_transcript)
      expect(result).to eq("WEBVTT\n\n\n")
    end
  end

  describe "special character handling" do
    let(:special_snippets) do
      [
        YoutubeRb::Transcript::TranscriptSnippet.new(text: "Hello <b>world</b>", start: 0.0, duration: 2.0),
        YoutubeRb::Transcript::TranscriptSnippet.new(text: 'Quote: "test"', start: 2.0, duration: 2.0),
        YoutubeRb::Transcript::TranscriptSnippet.new(text: "Line1\nLine2", start: 4.0, duration: 2.0)
      ]
    end
    let(:special_transcript) { create_transcript(snippets: special_snippets) }

    it "JSONFormatter escapes special characters" do
      formatter = YoutubeRb::Formatters::JSONFormatter.new
      result = formatter.format_transcript(special_transcript)
      parsed = JSON.parse(result)
      expect(parsed[0]["text"]).to eq("Hello <b>world</b>")
      expect(parsed[1]["text"]).to eq('Quote: "test"')
    end

    it "TextFormatter preserves special characters" do
      formatter = YoutubeRb::Formatters::TextFormatter.new
      result = formatter.format_transcript(special_transcript)
      expect(result).to include("<b>world</b>")
      expect(result).to include('"test"')
    end

    it "SRTFormatter preserves HTML tags in text" do
      formatter = YoutubeRb::Formatters::SRTFormatter.new
      result = formatter.format_transcript(special_transcript)
      expect(result).to include("<b>world</b>")
    end
  end
end
