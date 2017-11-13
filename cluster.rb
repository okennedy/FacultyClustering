$:.push "lib"
require 'yaml'
require 'kmeans-clusterer'
require 'util.rb'

####################
### Usage
####################
# - First install kmeans-clusterer
#   > sudo gem install kmeans-clusterer
# - Then run
#   > ruby ./cluster.rb
####################

d = File.read("Projects")

people_with_keywords = 
  YAML.load(d).map do |person, projects|
    keywords = 
      projects.map do |keyword|
        case keyword
        when /\((.*)\)/ then $1.split(/, */)
        else keyword
        end
      end.flatten.uniq
    [person, keywords.map { |a| a.gsub(/^ +/, "").gsub(/ +$/, "").downcase }]
  end

puts "#{people_with_keywords.size} People"

if File.exists? "Faculty"
  faculty = YAML.load(File.read("Faculty"))
  names = faculty.keys
  people_with_keywords.each do |person, keywords|
    names.delete(person)
  end
  unless names.empty?
    puts "----- Missing ------"
    puts names.join("\n")  
  end
end


keywords = 
  File.readlines("Keywords")
    .map { |keyword| keyword.downcase.chomp }

keyword_indices = 
  keywords
    .map.with_index { |keyword, idx| [keyword, idx] }
    .to_h

keywords_by_people = 
  people_with_keywords
    .map { |person, keywords| keywords.map { |keyword| [keyword, person] } }
    .flatten(1)
    .reduce

keyword_frequency = 
  keywords_by_people.map { |keyword, people| [keyword, people.size] }.to_h

labels, data = people_with_keywords
  .map do |person, person_keywords|
    features = [0] * keywords.size
    person_keywords.each do |keyword| 
      keyword_idx = keyword_indices[keyword]
      raise "#{person} used an invalid keyword: #{keyword}" if keyword_idx.nil?
      features[keyword_idx] = 1 #keyword_frequency[keyword]
    end
    [ person, features ]
  end
  .unzip

File.open("Features", "w+") do |f|
  f.puts(keywords.join(","))
  data.each do |vector|
    f.puts(vector.join(","))
  end
end

puts "=========== Keyword Frequency ==========="
puts keyword_frequency.to_a.sort_by { |k, f| -f }.to_table(["Keyword", "Faculty"])

# p data
k = 7
kmeans = KMeansClusterer.run k, data, labels: labels, runs: 1000

kmeans.clusters.each do |cluster|
  puts ""
  puts "=========== Cluster #{cluster.id} ==========="

  puts "Example Members: " + cluster.points.map{ |c| c.label }.join(",")
  fields = 
    cluster
      .centroid
      .to_a
      .map.with_index { |strength, idx| [strength, "#{keywords[idx]} (#{strength*100}%)"] }  #/ (keyword_frequency[keywords[idx]] or 1
      .select { |a| a[0] > 0.0 }
      .sort_by { |a| -a[0] }
      .map { |a| a[1] }
  puts "Keywords: \n#{fields.join("\n")}"
end