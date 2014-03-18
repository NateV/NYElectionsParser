require 'spec_helper.rb'
require 'elections_parser.rb'

describe ElectionsParser do
#   before(:each) do 
#     @parser = ElectionsParser.new ["../NYLegislatureEvents/spec/fixtures/sample.xml", "output_test.txt"]
#   	@parser.run!
#   end
#   
#   it "evaluates simple tests." do
#     5.should==5
#   end# of simple tests
# 
#   it 'reads in a file and parses it into a nokogiri document.' do
#     @parser.read_file_to_xml.class.should==Nokogiri::HTML::Document
#   end
#   
#   it 'separates districts' do
#     xml = @parser.read_file_to_xml
#     @parser.districts(xml).length.should==2
#   end
# 
#   it 'parses a single districts values into a json object.' do
# 	correctJSON = {event: "election",
# 				 	date: "Nov-6-2012",
# 				 	chamber: "senate",
# 				 	district: "1",
# 				 	county: "Part of Suffolk",
# 				 	votes: [ {candidate: "Bridget M. Fleming",
# 				 				party: "DEM",
# 				 				vote_count: "47041"},
# 				 			 {candidate: "Kenneth P. LaValle",
# 				 			  	party: "REP",
# 				 			  	vote_count: "61309"}],
# 				 	recap: [ {candidate: "Bridget M. Fleming",
# 				 				vote_count: "51301"},
# 				 			 {candidate: "Kenneth P. LaValle",
# 				 			 	vote_count: "76006"}]}
# 	xml = @parser.read_file_to_xml
#     districtList = @parser.districts(xml)
#     results= @parser.district_list_to_json(districtList[0])
#     results = JSON.parse(results)
#     results.class.should==Hash
#     results["district"].should=="1"
# 	results["chamber"].should=="SENATE"
# 	results["votes"].class.should==Array
#   end
# 
  before(:each) do
    @parser = ElectionsParser.new ["../NYLegislatureEvents/spec/fixtures/sample.xml", "output_test.txt"]
  end

  specify {expect(@parser).to be_a ElectionsParser}

  describe "#file_to_xml" do
    it 'reads an xml file and returns a nokogiri document.' do
      @parser.file_to_xml.class.should==Nokogiri::HTML::Document
    end
    
    it 'stores the result in an instance variable' do
      @parser.file_to_xml
      @parser.xml.class.should==Nokogiri::HTML::Document
    end
  end# of #file_to_xml

  describe "#xml_to_list" do
    before(:each) do
      @parser.file_to_xml
    end
    
    it 'parses xml elements from a collection of <text> nodes into an array of the content of the nodes.' do
      @parser.xml_to_list.class.should==Array
    end
    
    it 'stores the result in an instance variable, full_list' do
      @parser.xml_to_list
      @parser.full_list.class.should==Array
      @parser.full_list[5].class.should==String
    end
  end# of #xml_to_list

  describe "clean_list" do
    it 'cleans commas from only numbers in an array of strings' do
      @parser.clean_list(["Some, text", "23,532", "424", "Page 9", "DATED: March 20, 2013 ( Kings* updated June 9, 2013)", "NYS Board of Elections Senate Election Returns Nov. 6, 2012"]).should==
    								  ["Some, text", "23532", "424"]
    end
    
    it 'finds the record date' do
      @parser.clean_list(["nothing", "DATED: March 20, 2013 ( Kings* updated June 9, 2013)"])
      @parser.record_date.should=="March 20, 2013"
    end
    
    it 'finds the election date' do
      @parser.clean_list(["nothing", "NYS Board of Elections Senate Election Returns Nov. 6, 2012"])
	  @parser.election_date.should=="Nov. 6, 2012"
    end
  end# of #clean_commas_from_list
  
  describe "#break_list_into_districts" do
    before(:each) do
      @parser.file_to_xml
      @parser.xml_to_list
      @parser.full_list= @parser.clean_list(@parser.full_list)
      @parser.break_list_into_districts
    end
    
    it 'breaks the list of elements into a list, each element of which is a list of the strings
    	related to a particular district.' do
    	expect(@parser.districts_list).to be_a Array
    	expect(@parser.districts_list[0]).to be_a Array
    	/[senate|assembly]/i.match(@parser.districts_list[0][0]).should be_true
    end 
  end# of #break_list_into_distrocts
  
  describe "#break_districts_into_rows" do
    before(:each) do
      @parser.file_to_xml
      @parser.xml_to_list
      @parser.full_list= @parser.clean_list(@parser.full_list)
      @parser.break_list_into_districts
      @parser.break_districts_into_rows
    end
    
    it 'breaks the array of elements for each district into arrays for each table row.' do
      district1= @parser.districts_list[0]
      dist_61 = @parser.districts_list[2]
      expect(district1).to be_a Array
      expect(dist_61).to be_a Array
      expect(district1[0]).to be_a Array
      expect(dist_61).to be_a Array
      /senate/i.match(district1[0][0]).should_not be_nil
      /part/i.match(district1[3][0]).should_not be_nil
    end
  end# of #break_districts_into_rows
  
  describe "#align_rows_of_each_district" do
    before(:each) do
      @parser.file_to_xml
      @parser.xml_to_list
      @parser.full_list= @parser.clean_list(@parser.full_list)
      @parser.break_list_into_districts
      @parser.break_districts_into_rows
      @parser.align_rows_of_each_district
    end
    
    it 'correctly aligns the list of strings according to the tables in the election results.' do
      district1= @parser.districts_list[0]
      dist_61 = @parser.districts_list[2]
      (district1[0][1] + " " + district1[1][1]).should=="Bridget M. Fleming"
      dist_61[2][1].should=="DEM"
      
      subtotal_index = dist_61[1].find_index("Subtotal")
      dist_61[0][subtotal_index].should=="BVS"
    end
  end# of align_rows_of_one_district
  
  describe "#transform_district_tables_to_hash" do
    before(:each) do
      @parser.file_to_xml
      @parser.xml_to_list
      @parser.full_list= @parser.clean_list(@parser.full_list)
      @parser.break_list_into_districts
      @parser.break_districts_into_rows
      @parser.align_rows_of_each_district
      @parser.transform_district_tables_to_hash
    end
    
    it "transforms an array of rows of election results into a hash" do
      expect(@parser.districts_list[0]).to be_a Hash
      @parser.districts_list[0][:district].should=="1"
      @parser.districts_list[0][:chamber].should=="SENATE"
      expect(@parser.districts_list[2][:votes]).to be_a Array
    end
  end# of #transform_district_tables_to_hash
  
  describe "#print_hashes_as_json" do
    it 'saves hashes to a file' do
    
    end
  end# of #print_hashes_as_json
end# of spec