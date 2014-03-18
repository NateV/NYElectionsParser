## ElectionsParser

This utility will parse New York State election results published as PDF by
the NYS Board of Elections.
  
To use:
1. Download the pdf you would like to parse from 
2. Transform the pdf to xml using pdftohtml [file_name] -xml
3. Run the parser using ruby executable.rb [xml-file] [output-file]
4. You could import the json output into a nosql database such as Mongodb.


Issues: 
-the pdfs are not in fantastic shape. I had to make on change to the
 file SenateResults.xml to remove a typo that caused errors in the utility. The 
 utility ought to be able to either (a) handle typos, (b) do better at reporting back
 about what is causing errors, or (c) accept something like a config file that tells
 the utility how to fix errors specific to a pdf. i.e. the config file would include
 blocks of code that would be run during the clean_list method.
 