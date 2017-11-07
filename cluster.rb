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

keywords = 
  File.readlines("Keywords")
    .map { |keyword| keyword.downcase.chomp }

keyword_indices = 
  keywords
    .map.with_index { |keyword, idx| [keyword, idx] }
    .to_h

labels, data = people_with_keywords
  .map do |person, person_keywords|
    features = [0] * keywords.size
    person_keywords.each do |keyword| 
      keyword_idx = keyword_indices[keyword]
      raise "#{person} used an invalid keyword: #{keyword}" if keyword_idx.nil?
      features[keyword_idx] = 1 
    end
    [ person, features ]
  end
  .unzip

# p data
k = 5
kmeans = KMeansClusterer.run k, data, labels: labels, runs: 1000

kmeans.clusters.each do |cluster|
  puts ""
  puts "=========== Cluster #{cluster.id} ==========="

  puts "People in Cluster: " + cluster.points.map{ |c| c.label }.join(",")
  fields = 
    cluster
      .centroid
      .to_a
      .map.with_index { |str, idx| [str, "#{keywords[idx]} (#{str*100}%)"] }
      .select { |a| a[0] > 0.0 }
      .sort_by { |a| -a[0] }
      .map { |a| a[1] }
  puts "Keywords: \n#{fields.join("\n")}"
end