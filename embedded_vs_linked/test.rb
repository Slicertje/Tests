require 'rubygems'
require 'mongo_mapper'

MongoMapper.connection = Mongo::Connection.new
MongoMapper.database = 'tests'

class EmbeddedChild

    include MongoMapper::EmbeddedDocument

    key :dummy

end

class EmbeddedParent

    include MongoMapper::Document

    key :name

    many :embedded_children

end

class LinkedChild

    include MongoMapper::Document

    key :dummy

    belongs_to :linked_parent

end


class LinkedParent

    include MongoMapper::Document

    key :name

    many :linked_children
end

def clear_database
    MongoMapper.database.collections.each do |c|
        if c.name != 'system.indexes'
            c.drop
        end
    end
end

def random_name
    (0...50).map{ ('a'..'z').to_a[rand(26)] }.join
end

clear_database

puts "Generating dummy data"
# 1. Generate dummy data
parents  = []
children = []
1000.times do |i|
    parents[i]  = random_name
    children[i] = []
    (0..rand(20)).each do |d|
        children[i] << random_name
    end
end

puts "Starting creation tests"
# 2. Creation
start_time = Time.now

parents.each_index do |i|
    parent_name = parents[i]
    parent = EmbeddedParent.new({ :name => parent_name })
    children[i].each do |child|
        parent.embedded_children << EmbeddedChild.new({ :dummy => parent_name })
    end
    parent.save
end

creation_embedded = Time.now - start_time

start_time = Time.now

parents.each_index do |i|
    parent_name = parents[i]
    parent = LinkedParent.create({ :name => parent_name })
    children[i].each do |child|
        LinkedChild.create({ :linked_parent => parent, :dummy => parent_name })
    end
end

creation_linked = Time.now - start_time

puts "Embedded: #{creation_embedded}s (AVG: #{creation_embedded / parents.size})"
puts "Linked: #{creation_linked}s (AVG: #{creation_linked / parents.size}"

clear_database

puts "Starting embedded extra saving creation tests"
# 3. Creation embedded reloaded
start_time = Time.now

parents.each_index do |i|
    parent_name = parents[i]
    parent = EmbeddedParent.new({ :name => parent_name })
    parent.save
    children[i].each do |child|
        parent.embedded_children << EmbeddedChild.new({ :dummy => parent_name })
        parent.save
    end
end

creation_embedded = Time.now - start_time

start_time = Time.now

parents.each_index do |i|
    parent_name = parents[i]
    parent = LinkedParent.create({ :name => parent_name })
    children[i].each do |child|
        LinkedChild.create({ :linked_parent => parent, :dummy => parent_name })
    end
end

creation_linked = Time.now - start_time

puts "Embedded: #{creation_embedded}s (AVG: #{creation_embedded / parents.size})"
puts "Linked: #{creation_linked}s (AVG: #{creation_linked / parents.size}"

# 4. Fetching tests
puts "Fetching tests"

fetches = []
(1..40).each do |i|
    fetches << parents[rand(parents.size - 1)]
end

start_time = Time.now

fetches.each do |name|
    parent = EmbeddedParent.first(:name => name)
    parent.embedded_children.each do |child|
        child.dummy[0, 1]
    end
end

read_embedded = Time.now - start_time

start_time = Time.now

fetches.each do |name|
    parent = LinkedParent.first(:name => name)
    parent.linked_children.each do |child|
        child.dummy[0, 1]
    end
end

read_linked = Time.now - start_time

puts "Embedded: #{read_embedded} (AVG: #{read_embedded / fetches.size})"
puts "linked: #{read_linked} (AVG: #{read_linked / fetches.size})"
