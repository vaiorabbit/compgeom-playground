require 'pp'
require 'rmath3d/rmath3d_plain'
include RMath3D

require_relative 'triangle'
require_relative 'intersection'
require_relative 'polygon'

module Clipping

  NODE_STATUS_UNKNOWN = -1
  NODE_STATUS_ENTRY = 0
  NODE_STATUS_EXIT = 1
  NODE_STATUS_COUNT = 2

  class Node
    attr_accessor :pos, :intersection, :alpha, :next, :prev, :neighbor, :entry_exit, :visited
    def initialize(pos, intersection = false, alpha = 0.0)
      @pos = pos != nil ? pos : RVec2.new(0, 0)
      @intersection = intersection
      @alpha = alpha
      @next = nil # Node
      @prev = nil # Node
      @neighbor = nil # Node
      @entry_exit = NODE_STATUS_UNKNOWN
      @visited = false
    end
  end

  def self.build_node_list(polygon_points)
    top = nil
    current = nil
    polygon_points.each do |pos|
      if top == nil
        current = Node.new(pos)
        top = current
      else
        current.next = Node.new(pos)
        current.next.prev = current
        current = current.next
      end
    end
    return top
  end
  private_class_method :build_node_list

  def self.get_last_node(node)
    n = node
    while n.next != nil && n.next != node
      n = n.next
    end
    return n
  end
  private_class_method :get_last_node

  def self.get_contour_candidate_node(node)
    return nil if node == nil
    found = false

    n = node
    until found do
      n = n.next
      break if n == node || n == nil
      next unless n.intersection
      found = !n.visited
    end

    return n
  end

  def self.next_original_node(node)
    n = node
    while n != nil && n.intersection
      n = n.next
    end
    return n
  end
  private_class_method :next_original_node

  def self.insert_intersection_node(int_node, n0, n1)
    return if (n0.intersection || n1.intersection)
    n = n0
    while n != n1 && n.alpha < int_node.alpha
      n = n.next
    end

    int_node.next = n
    int_node.prev = n.prev
    int_node.prev.next = int_node if int_node.prev != nil
    int_node.next.prev = int_node
  end
  private_class_method :insert_intersection_node

  def self.clip(subject_polygon_points, clip_polygon_points)
    return [] if subject_polygon_points.empty? || clip_polygon_points.empty?
    subject_polygon_list = build_node_list(subject_polygon_points)
    clip_polygon_list = build_node_list(clip_polygon_points)
    subj_last_node = get_last_node(subject_polygon_list)
    clip_last_node = get_last_node(clip_polygon_list)
    subj_last_node.next = Node.new(subject_polygon_list.pos, false, 0)
    clip_last_node.next = Node.new(clip_polygon_list.pos, false, 0)
    subj_last_node.next.prev = subj_last_node
    clip_last_node.next.prev = clip_last_node

    # Phase 1

    found_intersection = false
    subject_node = subject_polygon_list
    while subject_node.next != nil
      unless subject_node.intersection
        clip_node = clip_polygon_list
        while clip_node.next != nil
          unless clip_node.intersection

            s0 = subject_node
            s1 = next_original_node(subject_node.next)
            c0 = clip_node
            c1 = next_original_node(clip_node.next)

            int_pos = Intersection.get_segments_intersection(s0.pos, s1.pos, c0.pos, c1.pos)
            if int_pos != nil
              found_intersection = true
              int_node_subj = Node.new(int_pos, true, (int_pos - s0.pos).getLength / (s1.pos - s0.pos).getLength)
              int_node_clip = Node.new(int_pos, true, (int_pos - c0.pos).getLength / (c1.pos - c0.pos).getLength)
              int_node_subj.neighbor = int_node_clip
              int_node_clip.neighbor = int_node_subj
              insert_intersection_node(int_node_subj, s0, s1)
              insert_intersection_node(int_node_clip, c0, c1)
            end
          end
          clip_node = clip_node.next
        end

      end
      subject_node = subject_node.next
    end

    # Phase 2
    if found_intersection
      subject_node = subject_polygon_list
      subj_entry_exit = Polygon.point_inside?(subject_node.pos, clip_polygon_points) ? NODE_STATUS_EXIT : NODE_STATUS_ENTRY
    # subj_entry_exit = !subj_entry_exit # do this if mode == AND
      while subject_node.next != nil
        if subject_node.intersection
          subject_node.entry_exit = subj_entry_exit
          subj_entry_exit = (subj_entry_exit + 1) % NODE_STATUS_COUNT
        end
        subject_node = subject_node.next
      end

      clip_node = clip_polygon_list
      clip_entry_exit = Polygon.point_inside?(clip_node.pos, subject_polygon_points) ? NODE_STATUS_EXIT : NODE_STATUS_ENTRY
    # clip_entry_exit = !clip_entry_exit # do this if mode == OR
      while clip_node.next != nil
        if clip_node.intersection
          clip_node.entry_exit = clip_entry_exit
          clip_entry_exit = (clip_entry_exit + 1) % NODE_STATUS_COUNT
        end
        clip_node = clip_node.next
      end
    end

    # puts "clip"
    # c = clip_polygon_list
    # count = 0
    # while c.next != nil
    #   count += 1
    #   puts "#{c.pos}, #{c.entry_exit}, #{c.intersection}, #{c.visited}"
    #   c = c.next
    # end

    # puts "subj"
    # c = subject_polygon_list
    # count = 0
    # while c.next != nil
    #   count += 1
    #   puts "#{c.pos}, #{c.entry_exit}, #{c.intersection}, #{c.visited}"
    #   c = c.next
    # end

    # Phase 3

    # subj_last_node.next.prev = subj_last_node
    # clip_last_node.next.prev = clip_last_node

    # subj_last_node.next = nil
    # clip_last_node.next = nil
    # OR
    subj_last_node = get_last_node(subject_polygon_list)
    clip_last_node = get_last_node(clip_polygon_list)

    subj_last_node.next = subject_polygon_list
    subject_polygon_list.prev = subj_last_node

    clip_last_node.next = clip_polygon_list
    clip_polygon_list.prev = clip_last_node

    polygons = []

    if found_intersection

      current = get_contour_candidate_node(subject_polygon_list)

      while current != nil && current != subject_polygon_list
        polygon_position = []
        while current != nil && !current.visited
          polygon_position << current.pos
          move_forward = current.entry_exit == NODE_STATUS_ENTRY
          while current != nil
            current.visited = true
            current = move_forward ? current.next : current.prev
            if current != nil
              if current.intersection
                current.visited = true
                break
              else
                polygon_position << current.pos
              end
            end
          end
          current = current.neighbor if current != nil
        end
        polygons << polygon_position
        current = get_contour_candidate_node(subject_polygon_list)
      end

    end

    return polygons

  end

end

if __FILE__ == $0
=begin
  points = []

  points << RVec2.new(0.0, 0.0)
  points << RVec2.new(1.0, 0.0)
  points << RVec2.new(-1.0, 0.0)
  points << RVec2.new(0.0, 1.0)
  points << RVec2.new(0.0, -1.0)

  tri_indices = DelaunayTriangulation.calculate(points)
  tri_indices.each_with_index do |indices, i|
    puts "Triangle(#{i}) : (#{points[indices[0]]}, #{points[indices[1]]}, #{points[indices[2]]})\t"
  end
=end
end
