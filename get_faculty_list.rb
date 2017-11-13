require 'net/http'
require 'nokogiri'
require 'yaml'


faculty_url = URI("https://engineering.buffalo.edu/computer-science-engineering/people/faculty-directory.html")

data = Net::HTTP.get(faculty_url)
data = Nokogiri::HTML(data)

faculty = 
  data.css(".staff_member")
    .map do |member|
      staff_name = member.at_css(".staff_name_bolded").text
      staff_roles = member.at_css(".staff_title_italic").text.split(/; */)

      [staff_name, staff_roles]
    end.to_h



File.open("Faculty", "w+") do |f|
  f.puts(YAML.dump(faculty))
end