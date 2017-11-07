require 'net/http'
require 'nokogiri'

faculty_url = URI("https://engineering.buffalo.edu/computer-science-engineering/people/faculty-directory.html")

data = Net::HTTP.get(faculty_url)

p data