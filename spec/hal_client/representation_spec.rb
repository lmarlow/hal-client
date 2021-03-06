require_relative "../spec_helper"

require "hal_client/representation"

describe HalClient::Representation do
  let(:raw_repr) { <<-HAL }
{ "prop1": 1
  ,"_links": {
    "self": { "href": "http://example.com/foo" }
    ,"link1": { "href": "http://example.com/bar" }
    ,"link2": { "href": "http://example.com/people{?name}"
                ,"templated": true }
    ,"link3": [{ "href": "http://example.com/link3-a" }
               ,{ "href": "http://example.com/link3-b" }]
  }
  ,"_embedded": {
    "embed1": {
      "_links": { "self": { "href": "http://example.com/baz" }}
    }
  }
}
HAL
  subject(:repr) { described_class.new(hal_client: a_client,
                                       parsed_json: MultiJson.load(raw_repr)) }

  describe "#post" do
    let!(:post_request) {
      stub_request(:post, "example.com/bar")
    }

    before(:each) do
      repr.related("link1").post("abc")
    end

    specify {
      expect(
        post_request.
        with(:body => "abc", :headers => {'Content-Type' => 'application/hal+json'})
      ).to have_been_made
    }
  end

  describe "#to_s" do
    subject(:return_val) { repr.to_s }

    it { should eq "#<HalClient::Representation: http://example.com/foo>" }
  end

  describe "#property" do
    context "existent" do
      subject { repr.property "prop1" }
      it { should eq 1 }
    end

    context "non-existent" do
      it "raises exception" do
        expect{repr.property 'wat'}.to raise_exception KeyError
      end
    end
  end

  its(:href) { should eq "http://example.com/foo" }

  describe "#fetch" do
    context "for existent property" do
      subject { repr.fetch "prop1" }
      it { should eq 1 }
    end

    context "for existent link" do
      subject { repr.fetch "link1" }
      it { should have(1).item }
      it "includes related resource representation" do
        expect(subject.first.href).to eq "http://example.com/bar"
      end
    end

    context "for existent embedded" do
      subject { repr.fetch "embed1" }
      it { should have(1).item }
      it "includes related resource representation" do
        expect(subject.first.href).to eq "http://example.com/baz"
      end
    end

    context "non-existent item w/o default" do
      it "raises exception" do
        expect{repr.fetch 'wat'}.to raise_exception KeyError
      end
    end

    context "non-existent item w/ default value" do
      subject { repr.fetch "wat", "whatevs" }
      it { should eq "whatevs" }
    end

    context "non-existent item w/ default value generator" do
      subject { repr.fetch("wat"){|key| key+"gen" } }
      it { should eq "watgen" }
    end
  end

  describe "#[]" do
    context "for existent property" do
      subject { repr["prop1"] }
      it { should eq 1 }
    end

    context "for existent link" do
      subject { repr["link1"] }
      it { should have(1).item }
      it { should include_representation_of "http://example.com/bar" }
    end

    context "for existent embedded" do
      subject { repr["embed1"] }
      it { should have(1).item }
      it { should include_representation_of "http://example.com/baz" }
    end

    context "non-existent item w/o default" do
      subject { repr["wat"] }
      it { should be_nil }
    end
  end

  describe "#related" do
    context "for existent link" do
      subject { repr.related "link1" }
      it { should have(1).item }
      it { should include_representation_of "http://example.com/bar" }
    end

    context "for existent compound link" do
      subject { repr.related "link3" }
      it { should have(2).item }
      it { should include_representation_of "http://example.com/link3-a" }
      it { should include_representation_of "http://example.com/link3-b" }
    end

    context "for existent templated link" do
      subject { repr.related "link2", name: "bob" }
      it { should have(1).item }
      it { should include_representation_of "http://example.com/people?name=bob"  }
    end

    context "for existent embedded" do
      subject { repr.related "embed1" }
      it { should have(1).item }
      it { should include_representation_of "http://example.com/baz" }
    end

    context "non-existent item w/o default" do
      it "raises exception" do
        expect{repr.related 'wat'}.to raise_exception KeyError
      end
    end
  end

  describe "#related_hrefs" do
    context "for existent link" do
      subject { repr.related_hrefs "link1" }
      it { should have(1).item }
      it { should include "http://example.com/bar" }
    end

    context "for existent embedded" do
      subject { repr.related_hrefs "embed1" }
      it { should have(1).item }
      it { should include "http://example.com/baz" }
    end

    context "non-existent item w/o default" do
      it "raises exception" do
        expect{repr.related_hrefs 'wat'}.to raise_exception KeyError
      end
    end
  end

  specify { expect(subject.has_related? "link1").to be true }
  specify { expect(subject.has_related? "link3").to be true }
  specify { expect(subject.has_related? "embed1").to be true }

  specify { expect(subject.has_related? "no-such-link").to be false }
  specify { expect(subject.has_related? "no-such-embed").to be false }

  context "curie links" do
    let(:raw_repr) { <<-HAL }
{ "_links": {
    "self": { "href": "http://example.com/foo" }
    ,"ex:bar": { "href": "http://example.com/bar" }
    ,"curies": [{"name": "ex", "href": "http://example.com/rels/{rel}", "templated": true}]
  }
}
HAL

    describe "#related return value " do
      subject(:return_val) { repr.related("http://example.com/rels/bar") }
      it { should include_representation_of "http://example.com/bar" }
    end

    describe "#[] return value " do
      subject(:return_val) { repr["http://example.com/rels/bar"] }
      it { should include_representation_of "http://example.com/bar" }
    end

    describe "#related_hrefs return value " do
      subject(:return_val) { repr.related_hrefs("http://example.com/rels/bar") }
      it { should include "http://example.com/bar" }
    end
  end

  context "curie embedded" do
    let(:raw_repr) { <<-HAL }
{ "_links": {
    "self": { "href": "http://example.com/foo" }
    ,"curies": {"name": "ex", "href": "http://example.com/rels/{rel}", "templated": true}
  }
  ,"_embedded": {
    "ex:embed1": { "_links": { "self": { "href": "http://example.com/embed1" } } }
  }
}
HAL

    describe "#related return value " do
      subject(:return_val) { repr.related("http://example.com/rels/embed1") }
      it { should include_representation_of "http://example.com/embed1" }
    end

    describe "#[] return value " do
      subject(:return_val) { repr["http://example.com/rels/embed1"] }
      it { should include_representation_of "http://example.com/embed1" }
    end

    describe "#related_hrefs return value " do
      subject(:return_val) { repr.related_hrefs("http://example.com/rels/embed1") }
      it { should include "http://example.com/embed1" }
    end
  end

  context "invalid link/embedded" do
    let(:raw_repr) { <<-HAL }
{ "_links": {
    "self": { "href": "http://example.com/foo" }
    ,"bare_url": "http://example.com/bar"
  }
  ,"_embedded": {
    "atom": "hello"
    ,"array-of-atoms": [1,2,3]
  }
}
HAL

    specify { expect{repr.related("bare_url")}
        .to raise_error HalClient::InvalidRepresentationError, %r(/_links/bare_url) }
    specify { expect{repr.related("atom")}
        .to raise_error HalClient::InvalidRepresentationError, %r(/_embedded/atom) }
    specify { expect{repr.related("array-of-atoms")}
        .to raise_error HalClient::InvalidRepresentationError, %r(/_embedded/array-of-atoms) }

  end
  # Background

  let(:a_client) { HalClient.new }
  let!(:bar_request) { stub_identity_request("http://example.com/bar") }
  let!(:baz_request) { stub_identity_request "http://example.com/baz" }
  let!(:people_request) { stub_identity_request "http://example.com/people?name=bob" }
  let!(:link3_a_request) { stub_identity_request "http://example.com/link3-a" }
  let!(:link3_b_request) { stub_identity_request "http://example.com/link3-b" }

  def stub_identity_request(url)
    stub_request(:get, url).
      to_return body: %Q|{"_links":{"self":{"href":#{url.to_json}}}}|
  end

  matcher :include_representation_of do |url|
    match { |repr_set|
      repr_set.any?{|it| it.href == url}
    }
    failure_message_for_should { |repr_set|
      "Expected representation of <#{url}> but found only #{repr_set.map(&:href)}"
    }
  end
end

describe HalClient::Representation, "w/o hal_client" do
  subject(:repr) { described_class.new(parsed_json: MultiJson.load(raw_repr)) }

  specify { expect(subject.href).to eq "http://example.com/foo" }
  specify { expect(subject.related_hrefs "link1").to include "http://example.com/bar" }
  specify { expect(subject.related("link1").first.href).to eq "http://example.com/bar" }
  specify { expect(subject.related("embed1").first.href).to eq "http://example.com/baz" }


  let(:raw_repr) { <<-HAL }
{ "prop1": 1
  ,"_links": {
    "self": { "href": "http://example.com/foo" }
    ,"link1": { "href": "http://example.com/bar" }
  }
  ,"_embedded": {
    "embed1": {
      "_links": { "self": { "href": "http://example.com/baz" }}
    }
  }
}
  HAL
end
