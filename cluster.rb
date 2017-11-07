$:.push "~/ownCloud/CodeSnippets"
require 'yaml'
require 'kmeans-clusterer'
require 'util.rb'

d = File.read("Areas")


people_with_areas = 
  YAML.load(d).map do |person, projects|
    areas = 
      projects.map do |area|
        case area
        when /\((.*)\)/ then $1.split(/, */)
        else area
        end
      end.flatten.uniq
    [person, areas.map { |a| a.gsub(/^ +/, "").gsub(/ +$/, "").downcase }]
  end

puts "#{people_with_areas.size} People"

areas = 
  people_with_areas
    .unzip[1]
    .flatten
    .uniq

area_indices = 
  areas
    .map.with_index { |area, idx| [area, idx] }
    .to_h

labels, data = people_with_areas
  .map do |person, person_areas|
    features = [0] * areas.size
    # p features
    person_areas.each { |a| features[area_indices[a]] = 1 }
    # p features
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
      .map.with_index { |str, idx| [str, "#{areas[idx]} (#{str*100}%)"] }
      .select { |a| a[0] > 0.0 }
      .sort_by { |a| -a[0] }
      .map { |a| a[1] }
  puts "Disciplines: \n#{fields.join("\n")}"
end