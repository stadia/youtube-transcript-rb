# frozen_string_literal: true

require "spec_helper"
require "youtube/transcript/rb"

RSpec.describe Youtube::Transcript::Rb::TranscriptParser do
  describe "#initialize" do
    it "creates a parser with preserve_formatting false by default" do
      parser = described_class.new
      expect(parser.instance_variable_get(:@preserve_formatting)).to be false
    end

    it "creates a parser with preserve_formatting true when specified" do
      parser = described_class.new(preserve_formatting: true)
      expect(parser.instance_variable_get(:@preserve_formatting)).to be true
    end
  end

  describe "#parse" do
    let(:parser) { described_class.new }

    context "with basic XML" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0" dur="2.5">Hello world</text>
            <text start="2.5" dur="3.0">This is a test</text>
          </transcript>
        XML
      end

      it "returns an array of TranscriptSnippet objects" do
        result = parser.parse(xml)
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first).to be_a(Youtube::Transcript::Rb::TranscriptSnippet)
      end

      it "parses text content correctly" do
        result = parser.parse(xml)
        expect(result[0].text).to eq("Hello world")
        expect(result[1].text).to eq("This is a test")
      end

      it "parses start time correctly" do
        result = parser.parse(xml)
        expect(result[0].start).to eq(0.0)
        expect(result[1].start).to eq(2.5)
      end

      it "parses duration correctly" do
        result = parser.parse(xml)
        expect(result[0].duration).to eq(2.5)
        expect(result[1].duration).to eq(3.0)
      end
    end

    context "with missing duration attribute" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0">Hello world</text>
          </transcript>
        XML
      end

      it "defaults duration to 0.0" do
        result = parser.parse(xml)
        expect(result[0].duration).to eq(0.0)
      end
    end

    context "with empty text elements" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0" dur="2.5">Hello</text>
            <text start="2.5" dur="1.0"></text>
            <text start="3.5" dur="2.0">World</text>
          </transcript>
        XML
      end

      it "skips empty text elements" do
        result = parser.parse(xml)
        expect(result.length).to eq(2)
        expect(result[0].text).to eq("Hello")
        expect(result[1].text).to eq("World")
      end
    end

    context "with HTML entities" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0" dur="2.5">Hello &amp; goodbye</text>
            <text start="2.5" dur="3.0">Quote: &quot;hello&quot;</text>
          </transcript>
        XML
      end

      it "unescapes HTML entities" do
        result = parser.parse(xml)
        expect(result[0].text).to eq("Hello & goodbye")
        expect(result[1].text).to eq('Quote: "hello"')
      end
    end

    context "with escaped HTML that looks like tags" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0" dur="2.5">Test &lt;value&gt;</text>
          </transcript>
        XML
      end

      it "unescapes and then strips the tag (expected behavior)" do
        # When HTML entities are unescaped, <value> becomes a tag and gets stripped
        result = parser.parse(xml)
        expect(result[0].text).to eq("Test ")
      end
    end

    context "with HTML tags and preserve_formatting: false" do
      let(:parser) { described_class.new(preserve_formatting: false) }
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0" dur="2.5">Hello &lt;b&gt;world&lt;/b&gt;</text>
            <text start="2.5" dur="3.0">&lt;i&gt;Italic&lt;/i&gt; text</text>
            <text start="5.5" dur="2.0">&lt;span class="highlight"&gt;Span&lt;/span&gt;</text>
          </transcript>
        XML
      end

      it "strips all HTML tags" do
        result = parser.parse(xml)
        expect(result[0].text).to eq("Hello world")
        expect(result[1].text).to eq("Italic text")
        expect(result[2].text).to eq("Span")
      end
    end

    context "with HTML tags and preserve_formatting: true" do
      let(:parser) { described_class.new(preserve_formatting: true) }
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0" dur="2.5">Hello &lt;b&gt;world&lt;/b&gt;</text>
            <text start="2.5" dur="3.0">&lt;i&gt;Italic&lt;/i&gt; text</text>
            <text start="5.5" dur="2.0">&lt;em&gt;Emphasis&lt;/em&gt;</text>
            <text start="8.5" dur="2.0">&lt;strong&gt;Strong&lt;/strong&gt;</text>
          </transcript>
        XML
      end

      it "preserves formatting tags like <b>" do
        result = parser.parse(xml)
        expect(result[0].text).to eq("Hello <b>world</b>")
      end

      it "preserves formatting tags like <i>" do
        result = parser.parse(xml)
        expect(result[1].text).to eq("<i>Italic</i> text")
      end

      it "preserves formatting tags like <em>" do
        result = parser.parse(xml)
        expect(result[2].text).to eq("<em>Emphasis</em>")
      end

      it "preserves formatting tags like <strong>" do
        result = parser.parse(xml)
        expect(result[3].text).to eq("<strong>Strong</strong>")
      end
    end

    context "with non-formatting HTML tags and preserve_formatting: true" do
      let(:parser) { described_class.new(preserve_formatting: true) }
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0" dur="2.5">&lt;span class="x"&gt;Span&lt;/span&gt;</text>
            <text start="2.5" dur="3.0">&lt;div&gt;Div&lt;/div&gt;</text>
            <text start="5.5" dur="2.0">&lt;a href="url"&gt;Link&lt;/a&gt;</text>
          </transcript>
        XML
      end

      it "strips non-formatting tags like <span>" do
        result = parser.parse(xml)
        expect(result[0].text).to eq("Span")
      end

      it "strips non-formatting tags like <div>" do
        result = parser.parse(xml)
        expect(result[1].text).to eq("Div")
      end

      it "strips non-formatting tags like <a>" do
        result = parser.parse(xml)
        expect(result[2].text).to eq("Link")
      end
    end

    context "with all supported formatting tags" do
      let(:parser) { described_class.new(preserve_formatting: true) }

      described_class::FORMATTING_TAGS.each do |tag|
        it "preserves <#{tag}> tags" do
          xml = <<~XML
            <?xml version="1.0" encoding="utf-8" ?>
            <transcript>
              <text start="0.0" dur="2.5">&lt;#{tag}&gt;content&lt;/#{tag}&gt;</text>
            </transcript>
          XML
          result = parser.parse(xml)
          expect(result[0].text).to eq("<#{tag}>content</#{tag}>")
        end
      end
    end

    context "with mixed content" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0" dur="2.5">Line 1</text>
            <text start="2.5" dur="3.0">Line 2 with &amp; ampersand</text>
            <text start="5.5" dur="2.0">Line 3</text>
          </transcript>
        XML
      end

      it "parses multiple elements correctly" do
        result = parser.parse(xml)
        expect(result.length).to eq(3)
        expect(result.map(&:text)).to eq(["Line 1", "Line 2 with & ampersand", "Line 3"])
      end
    end

    context "with integer times" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="5" dur="10">Content</text>
          </transcript>
        XML
      end

      it "converts to float" do
        result = parser.parse(xml)
        expect(result[0].start).to eq(5.0)
        expect(result[0].duration).to eq(10.0)
        expect(result[0].start).to be_a(Float)
        expect(result[0].duration).to be_a(Float)
      end
    end

    context "with empty transcript" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
          </transcript>
        XML
      end

      it "returns an empty array" do
        result = parser.parse(xml)
        expect(result).to eq([])
      end
    end

    context "with whitespace-only text" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0" dur="2.5">   </text>
            <text start="2.5" dur="3.0">Valid text</text>
          </transcript>
        XML
      end

      it "includes whitespace-only text since it's not empty" do
        result = parser.parse(xml)
        # Whitespace is still valid content
        expect(result.length).to eq(2)
      end
    end

    context "with Unicode content" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0" dur="2.5">こんにちは世界</text>
            <text start="2.5" dur="3.0">Привет мир</text>
            <text start="5.5" dur="2.0">🎉 Emoji test 🚀</text>
          </transcript>
        XML
      end

      it "handles Japanese characters" do
        result = parser.parse(xml)
        expect(result[0].text).to eq("こんにちは世界")
      end

      it "handles Cyrillic characters" do
        result = parser.parse(xml)
        expect(result[1].text).to eq("Привет мир")
      end

      it "handles emoji" do
        result = parser.parse(xml)
        expect(result[2].text).to eq("🎉 Emoji test 🚀")
      end
    end

    context "with newlines in text" do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="utf-8" ?>
          <transcript>
            <text start="0.0" dur="2.5">Line one
          Line two</text>
          </transcript>
        XML
      end

      it "preserves newlines" do
        result = parser.parse(xml)
        expect(result[0].text).to include("\n")
      end
    end
  end

  describe "FORMATTING_TAGS" do
    it "includes all expected formatting tags" do
      expected_tags = %w[strong em b i mark small del ins sub sup]
      expect(described_class::FORMATTING_TAGS).to match_array(expected_tags)
    end
  end
end
