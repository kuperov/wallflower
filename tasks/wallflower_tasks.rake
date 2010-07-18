desc 'Print out a dot graph showing all routes.'
task :wallflower => :environment do

  require 'ruby-debug'

  # Container for a single route
  class Route
    attr_accessor :verb, :controller, :action
    def initialize(v,c,a)
      @verb = v
      @controller = c
      @action = a
    end
  end

  # Node along a known path
  class PathSegment < Hash
    attr_accessor :name, :path, :routes, :leaf
    def initialize(n,p)
      @name = n
      @path = p
      @routes = []
      @leaf = false
    end
    # symbol dot uses to identify this node
    def nodename
      if path == ['/']
        'root'
      else
        path.join('_').gsub(/[:"\/]/, '_')
      end
    end
    def readable_path
      "/#{path.join('/')}"
    end
    def to_s
      readable_path
    end
  end

filename = ARGV[1] || 'wallflower.dot'
puts "Writing DOT file to #{filename}"

  File.open(filename, "w") do |file|

file.puts <<EOF 
digraph wallflower {
  rankdir=LR;
EOF

  root = PathSegment.new('root', ['/'])
  ActionController::Routing::Routes.routes.collect do |route|
    name = ActionController::Routing::Routes.named_routes.routes.index(route).to_s
    verb = route.conditions[:method].to_s.upcase
    segs = route.segments.select { |r| !r.optional? && r.class != ActionController::Routing::DividerSegment }

    pointer = root
    segs.each_with_index do |seg, n|
      if pointer[seg.to_s].nil?
        pointer[seg.to_s] = PathSegment.new(nil, segs[0..n])
      end
      pointer = pointer[seg.to_s]
    end
    pointer.name = name
    pointer.leaf = true

    reqs = route.requirements.empty? ? "" : route.requirements.inspect

    pointer.routes << Route.new(verb, reqs[0], reqs[1])
  end

  # define graphviz nodes recursively
  def output_node(node, file)
    label = ((node.name && !node.name.empty?) ? "#{node.name}\\n" : "") +
            "#{node.readable_path}"
    file.puts %Q{  #{node.nodename}[label="#{label}"]; }
    node.each do |key,value|
      output_node(value, file)
    end
  end
  output_node(root, file) # begin recursion

  # link nodes
  def output_links(node, file)
    node.each do |key,value|
      file.puts %Q{  #{node.nodename} -> #{value.nodename}; }
      output_links(value, file)
    end
  end
  output_links(root, file) # begin recursion

  file.puts '}'
end

puts "You can generate a PDF with the following command:"
puts "  dot -Tpdf -O #{filename}"

end

