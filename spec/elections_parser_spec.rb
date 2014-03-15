require 'spec_helper.rb'
require 'elections_parser.rb'

describe ElectionsParser do
  before(:each) do 
    @parser = ElectionsParser.new ["../NYLegislatureEvents/spec/fixtures/sample.xml", "output_test.txt"]
  	@parser.run!
  end
  
  it "evaluates simple tests." do
    5.should==5
  end# of simple tests

  it 'reads in a file and parses it into a nokogiri document.' do
    @parser.read_file_to_xml.class.should==Nokogiri::HTML::Document
  end
  
  it 'separates districts' do
    xml = @parser.read_file_to_xml
    @parser.districts(xml).length.should==2
  end

  it 'parses a single districts values into a json object.' do
	correctJSON = {event: "election",
				 	date: "Nov-6-2012",
				 	chamber: "senate",
				 	district: "1",
				 	county: "Part of Suffolk",
				 	votes: [ {candidate: "Bridget M. Fleming",
				 				party: "DEM",
				 				vote_count: "47041"},
				 			 {candidate: "Kenneth P. LaValle",
				 			  	party: "REP",
				 			  	vote_count: "61309"}],
				 	recap: [ {candidate: "Bridget M. Fleming",
				 				vote_count: "51301"},
				 			 {candidate: "Kenneth P. LaValle",
				 			 	vote_count: "76006"}]}
	xml = @parser.read_file_to_xml
    districtList = @parser.districts(xml)
    results= @parser.district_list_to_json(districtList[0])
    results = JSON.parse(results)
    results.class.should==Hash
    results["district"].should=="1"
	results["chamber"].should=="SENATE"
	results["votes"].class.should==Array
  end

end# of spec