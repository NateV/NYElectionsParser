require 'rubygems'
require 'json'
require 'debugger'
require 'nokogiri'


class ElectionsParser

  attr_accessor :xml, :full_list, :districts_list, :record_date, :election_date

  def initialize (*args)
    #debugger
    if args[0].empty? || args[0].length != 2
  	  raise "Incorrect arguments. Needs to be [in-file] [out-file]."
	else 
	  @FILE_IN=args[0][0]
	  @FILE_OUT=args[0][1]
	end
  end# of #new
  
  def file_to_xml
    file = File.open(@FILE_IN)
    @xml= Nokogiri::HTML(file, nil, 'UTF-8') do |config|
      config.nonet
    end
    file.close
    @xml
  end# of #file_to_xml
  
  def xml_to_list
    @full_list = []
    
    @xml.xpath("//text").each do |element|
      @full_list << element.text
    end
    @full_list
  end# of xml_to_list
  
  def clean_list (list)
  #If there are any numbers formatted with commas,
  # the method removes those commas, and finds, stores, and removes the date.
    list.each do |item| 
      if /([0-9]+)+,[0-9]+/.match item 
        item.gsub!(",","")
      elsif /dated/i.match item
        @record_date= /^dated:\ ([a-z]*\ [0-9]*,\ [0-9]*)\ \(/i.match(item)[1]
      elsif /election\ returns/i.match item
        @election_date= /election\ returns\ (.*)$/i.match(item)[1]
      end
    end
    
    #And removes page numbers
    list.reject {|item| ((/page/i.match item) || (/dated/i.match item) || (/election\ returns/i.match item))}
      
  end# of clean_commas_from_list
  
  def break_list_into_districts 
    @districts_list = []
    current_district = []
    @full_list.each do |string|
      if /^([0-9]*)(st|nd|rd|th)\ SENATE\ DISTRICT$/.match(string) then
		@districts_list << current_district
		current_district = []
		current_district << string
	  else 
	    current_district << string
	  end
    end# of each block
    if current_district!=nil then
      @districts_list << current_district
    end
    
    if @districts_list[0]==[] then
      @districts_list.shift
    end
    @districts_list
  end# of #break_list_into_districts
  
  def break_districts_into_rows
    @districts_list.map! do |district|
      ##i've got an array of strings, and need to break them up into separate arrays for each row.
      rows = [] #rows will be an array of arrays. row[row_number][column]
      
      #The first 3 rows I will identify based on values I know they will have.
      county_index = district.find_index("County")
      subtotal_index = district.find_index("Subtotal")
     
      last_party_index = district.rindex {|x| /^[A-Z]{3}$/i.match x}
      rows[0] = district[0..county_index-1]
      rows[1] = district[county_index..subtotal_index+1]
      rows[2] = district[subtotal_index+2..last_party_index]
      
      #Now I'll remove the values I've taken so far because I am done with them:
      district = district.drop(rows[0].length + rows[1].length + rows[2].length)
      
      #Then I will pop off the recap values, because I don't need them. 
      recap_index = district.find_index {|x| /recap/i.match x}
      district.slice!(recap_index..district.length-1)
      
      #the rest of the rows will have the same length - the same length as row 1.
      target_length= rows[1].length
      target_number_elements = district.length/target_length# this should be an even number.
      while district.length>0
        rows << district.slice!(0, target_length)
      end
      rows
    end# of districts_list.each block
    
    @districts_list
  end# of break_districts_into_rows
  
  def align_rows_of_each_district
    @districts_list.map! do |district|
		 
	  columns=district[3].length #all the rows need to be as long as this.
	  
	  #pad the first row
	  while district[0].find_index("BVS") < district[1].find_index("Subtotal") 
        district[0].insert(district[0].find_index("BVS"),"")
      end
      while district[0].length < district[1].length
        district[0].push("")
      end
      
      #pad the row with parties. 
      district[2].unshift("")
      while district[2].length<district[1].length
        district[2].push("")
      end

      district
    end# of each block.
      
  end# of align_rows_of_each_district
  
  def transform_district_tables_to_hash
    @districts_list.map! do |district|
      result = {event: "election",
    			record_date: @record_date,
    			election_date: @election_date}
 
      result[:district] = /^([0-9]*)(st|nd|rd|th)\ (senate|assembly)/i.match(district[0][0])[1]
      result[:chamber]= /^([0-9]*)(st|nd|rd|th)\ (senate|assembly)/i.match(district[0][0])[3]
      
      ##NOT RIGHT FOR MORE COMPLICATED DISTRICTS!!
      # go through each column
      number_of_columns = district[1].length
      number_of_rows = district.length
      
      vote_hashes =[]
      for column_index in 1..number_of_columns-1
        vote_hash= {candidate: district[0][column_index] + " " + district[1][column_index],
        				party: district[2][column_index]}
        county_votes = []
        for row_index in 3..number_of_rows-1
          if /^part\ of/i.match(district[row_index][0])
            county_votes << {county: district[row_index][0],
            				 vote_count: district[row_index][column_index]}
          elsif /total/i.match(district[row_index][0])
            vote_hash[:total_votes]=district[row_index][column_index]
          end
        end# of loop through rows 3 to end
        vote_hash[:county_votes]=county_votes
        vote_hashes << vote_hash
      end# of loop through columns

      result[:votes] = vote_hashes
      result
    end# of map each block
  end# of transform_district_tables_to_hash
 
  def print_hashes_to_json 
    File.write @FILE_OUT, JSON.pretty_generate(@districts_list)
  end# of #print_hashes_to_json
  
  
  #deprecated
  def districts(xml)
	districtList=[]
	currentDistrict=[]
    xml.xpath("//text").each do |text_node|
	  if /^([0-9]*)(st|nd|th)\ SENATE\ DISTRICT$/.match(text_node.text) then
		districtList << currentDistrict
		currentDistrict = []
		currentDistrict << text_node.text
	  else 
	    currentDistrict << text_node.text
	  end
	end# of each block
	
	#if there's something in current district, it didn't get added
	# to the list of districts.
	if currentDistrict then
	    districtList << currentDistrict
	end
	districtList.shift
	districtList
  end# of #districts
  
  #deprecated
  def district_list_to_json(district)
    #get a list of the values for a sigle district's election, and return a 
    # formatted json object with the correct vote totals. 
    
    #To put the values together, I have to align them in columns.
    # the column that starts County and goes to Total is the longest, and
    # has values that i can use to align the rest of the rows, filling in
    # blank cells where necessary.
    rows = [5]
    
    #break up the rows
    county_index = district.find_index("County")
    total_index = district.find_index("Total")
    part_of_index = district.find_index {|element| element.match(/Part of/)}
    rows[0] = district[0..(county_index-1)]
    rows[1] = district[county_index..total_index]# this is the key row. 
    rows[2] = district[(total_index+1)..(part_of_index-1)]
    rows[3] = district[(part_of_index), rows[1].length] #this is a range. array(start, length)
    rows[4] = district[-3..district.length-1]
    
    #add padding where necessary:
    columns = rows[1].length
    ##Padding row 0, getting 'BVS' to line up with 'Subtotal'. 
    while rows[0].find_index("BVS") < rows[1].find_index("Subtotal") 
      rows[0].insert(rows[0].find_index("BVS"),"")
    end
    while rows[0].length < rows[1].length
      rows[0].push("")
    end
    ##Padding row 2, lining up parties 
    rows[2].unshift("")
    while rows[2].length<rows[1].length
      rows[2].push("")
    end
    ##Row 3 should be fine.
    ## Padding row 4, just to add empty cells at the end.
    while rows[4].length < rows[1].length
      rows[4].push("")
    end
    
    ##INCIDENTALLY, this district is now formatted for CSV...
        

    #now get the values out of the table I've made:
    
    chamber = rows[0][0].match(/^([1-9]*)(st|nd|rd|th)\ (senate|assembly)/i)[3]
    district = rows[0][0].match(/^([1-9]*)(st||nd|rd|th)\ (senate|assembly)/i)[1]
    
    result = {event: "election", 
    	date: "Nov-6-2012",
    	chamber: chamber,
    	district: district,
    	county: rows[3][0]}
    
    votes = []
    for i in 1..rows[1].length-1
      votes << {candidate: rows[0][i] + " " + rows[1][i],
      			party: rows[2][i],
      			vote_count: rows[3][i]}
    end
    result[:votes] = votes
    
    recap = []
    for i in 1..2
      recap << {candidate: rows[0][i] + " " + rows[1][i],
      			vote_count: rows[4][i]}
    end
    result[:recap] = recap
    #debugger 
    result.to_json
  end# of #district_list_to_json
  

  def run!
	@f = File.new("logs/log_" + Time.now.to_s + ".txt", "w+")
	@f.write "Running app \n"
	file_to_xml
	@f.write "-file_to_xml \n"
	xml_to_list
	@f.write "-xml_to_list \n"
	@full_list = clean_list(@full_list)
	@f.write "-clean_list \n"
	break_list_into_districts
	@f.write "-break_list_into_districts \n"
	break_districts_into_rows
	@f.write "-break_districts_into_rows \n"
	align_rows_of_each_district
	@f.write "-align_rows_of_each_district \n"
	transform_district_tables_to_hash
	@f.write "-transform_rows_of_each_district\n "
	print_hashes_to_json
	@f.write "Completed. Successfully?"
	@f.close
  end# of #run!

end

