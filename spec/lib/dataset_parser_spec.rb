require 'spec_helper'

describe DatasetParser do

  let(:parser) { Class.new { extend DatasetParser } }

  before(:each) do
    WebMock.stub_request(:get, "http://www.example.com").to_return(body: load_fixture("multiple-items.json"))
    WebMock.stub_request(:get, "http://www.example.com?afterTimestamp=1506335000").to_return(body: load_fixture("multiple-items.json"))
    WebMock.stub_request(:get, "http://www.example.com?afterChangeNumber=1000").to_return(body: load_fixture("multiple-items.json"))
  end

  describe "#parse_modified" do
    it "parses various date formats" do
      expect(parser.parse_modified("1496565686")).to eql(1496565686)
      expect(parser.parse_modified(1512457484704)).to eql(1512457484)
      expect(parser.parse_modified("2017-09-22T12:35:02.511Z")).to eql(1506083702)
    end
  end

  describe "#extract_activities" do

    it "extracts activity name in a string" do
      item = { "data" =>{ "activity"=>"Body Attack" } }
      expect(parser.extract_activities(item)).to eql(["Body Attack"])
    end

    it "extracts activity name in a hash" do
      item = { "data" =>{ "activity"=>{ "prefLabel" => "Body Attack" } } }
      expect(parser.extract_activities(item)).to eql(["Body Attack"])
    end

    it "extracts activity names in an array of strings" do
      item = { "data" =>{ "activity"=>["Body Attack", "Boxing Fitness"] } }
      expect(parser.extract_activities(item)).to eql(["Body Attack", "Boxing Fitness"])
    end

    it "extracts activity names in an array of hashes" do
      item = { "data" =>{ "activity"=>[{ "prefLabel" => "Body Attack" },
        { "prefLabel" => "Boxing Fitness" } ]}
      }
      expect(parser.extract_activities(item)).to eql(["Body Attack", "Boxing Fitness"])
    end

    it "returns empty if there's no activity key" do
      item = { "data" =>{ "activity_names"=>["Body Attack", "Boxing Fitness"]} }
      expect(parser.extract_activities(item)).to eql([])
    end

  end

  describe "#extract_coordinates" do
    it "extracts latitude and longitude" do
      item = {
        "data" =>{ "location"=> { "geo" => { "latitude" => "51.0", "longitude" => "0.23" } } }
      }

      item2 = {
        "data" =>{ "location"=> { "containedInPlace" => {
          "geo" => { "latitude" => "52.0", "longitude" => "0.24" } } }
        }
      }

      expect(parser.extract_coordinates(item)).to eql([0.23, 51.0])
      expect(parser.extract_coordinates(item2)).to eql([0.24, 52.0])
    end

    it "returns false when no location available" do
      item = {
        "data" =>{ "location" => { "address" => "a street" } }
      }
      item2 = {
        "data" =>{ "other" => "stuff" }
      }
      expect(parser.extract_coordinates(item)).to eql(false)
      expect(parser.extract_coordinates(item2)).to eql(false)
    end

    it "returns false when coordinates are null" do
      item = {
        "data" =>{ "location"=> { "geo" => { "latitude" => nil, "longitude" => nil } } }
      }
      item2 = {
        "data" =>{ "location"=> { "geo" => nil } }
      }
      expect(parser.extract_coordinates(item)).to eql(false)
      expect(parser.extract_coordinates(item2)).to eql(false)
    end

    it "returns false when coordinates are all 0" do
      item = {
        "data" =>{ "location"=> { "geo" => { "latitude" => "0.0000", "longitude" => "0.0000" } } }
      }
      expect(parser.extract_coordinates(item)).to eql(false)
    end
  end

  describe "#extract_timestamp" do
    it "returns date timestamp for various formats" do

      item1 = {
        "data" =>{ "startDate"=> "2017-09-22T12:35:02.511Z" }
      }

      item2 = {
        "data" =>{ "subEvent" => { "startDate"=> "2017-09-22T12:35:02.511Z" } }
      }

      item3 = {
        "data" =>{ "subEvent" => [{ "startDate"=> "2017-09-22T12:35:02.511Z" }] }
      }

      item4 = {
        "data" =>{ "eventSchedule" => { "startDate"=> "2017-10-22T12:35:02.511Z" } }
      }

      expect(parser.extract_timestamp(item1, "startDate")).to eql("2017-09-22T12:35:02.511Z")
      expect(parser.extract_timestamp(item2, "startDate")).to eql("2017-09-22T12:35:02.511Z")
      expect(parser.extract_timestamp(item3, "startDate")).to eql("2017-09-22T12:35:02.511Z")
      expect(parser.extract_timestamp(item4, "startDate")).to eql("2017-10-22T12:35:02.511Z")
    end
  end

  describe "#is_page_recent?" do
    it "returns true if content is relevant within a year" do
      allow(Time).to receive_message_chain(:now).and_return(Time.at(1506335263))
      page = OpenActive::Feed.new("http://www.example.com?afterTimestamp=1506335000").fetch
      expect(parser.is_page_recent?(page)).to eql(true)
    end

    it "returns true if content is relevant within a year (from extracted date)" do
      allow(Time).to receive_message_chain(:now).and_return(Time.at(1506335263))
      page = OpenActive::Feed.new("http://www.example.com?afterChangeNumber=1000").fetch
      expect(parser.is_page_recent?(page)).to eql(true)
    end

    it "returns true if content is relevant within a year (ongoing without endDate)" do
      allow(Time).to receive_message_chain(:now).and_return(Time.at(1506335263))
      body=JSON.parse(load_fixture("multiple-items.json"))
      body["items"][1]["data"]["subEvent"][0].delete("endDate")
      WebMock.stub_request(:get, "http://www.example.com?afterChangeNumber=1000").to_return(body: body.to_json)
      page = OpenActive::Feed.new("http://www.example.com?afterChangeNumber=1000").fetch
      expect(parser.is_page_recent?(page)).to eql(true)
    end

    it "returns false if content is not relevant within a year" do
      allow(Time).to receive_message_chain(:now).and_return(Time.at(1577836800))
      page = OpenActive::Feed.new("http://www.example.com?afterTimestamp=1506335000").fetch
      expect(parser.is_page_recent?(page)).to eql(false)
    end

    it "returns false if content is not relevant within a year (from extracted date)" do
      allow(Time).to receive_message_chain(:now).and_return(Time.at(1577836800))
      page = OpenActive::Feed.new("http://www.example.com?afterChangeNumber=1000").fetch
      expect(parser.is_page_recent?(page)).to eql(false)
    end
  end

  describe "#uses_modified_timestamps?" do
    it "returns false when no params given" do
      page = OpenActive::Feed.new("http://www.example.com").fetch
      expect(parser.uses_modified_timestamps?(page)).to eql(false)
    end

    it "returns false when no afterTimestamp param is given" do
      page = OpenActive::Feed.new("http://www.example.com?afterChangeNumber=1000").fetch
      expect(parser.uses_modified_timestamps?(page)).to eql(false)
    end

    it "returns true when afterTimestamp is given" do
      page = OpenActive::Feed.new("http://www.example.com?afterTimestamp=1506335000").fetch
      expect(parser.uses_modified_timestamps?(page)).to eql(true)
    end
  end

end