require 'rubygems'
require 'json'
require 'debugger'
require 'nokogiri'


class ElectionsParser

  def initialize (*args)
    #debugger
    if args[0].empty? || args[0].length != 2
  	  raise "Incorrect arguments. Needs to be [in-file] [out-file]."
	else 
	  @FILE_IN=args[0][0]
	  @FILE_OUT=args[0][1]
	end
  end# of #new
  
  def read_file_to_xml
    file = File.open(@FILE_IN)
    xml = Nokogiri::HTML(file, nil, 'UTF-8') do |config|
      config.nonet
    end
    file.close
    xml
  end# of #read_file
  
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
	xml = read_file_to_xml
	districtList = districts(xml)
	districtList_JSON = districtList.map do |district|
	  district_list_to_json(district)
	end 
	#debugger
	File.write @FILE_OUT, districtList_JSON 
  end# of #run!

end

