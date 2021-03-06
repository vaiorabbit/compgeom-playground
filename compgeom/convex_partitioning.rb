require 'rmath3d/rmath3d_plain'
include RMath3D

require_relative 'triangle'
require_relative 'intersection'

module ConvexPartitioning

  # Ear-cutting algorithm
  # Ref.: Christer Ericson, Real-Time Collision Detection
  def self.triangulate(polygon_points)
    triangles = []
    indices = []
    n = polygon_points.length
    v = polygon_points

    indices_prev = []
    indices_next = []
    n.times do |i|
      indices_prev << i - 1
      indices_next << i + 1
    end
    indices_prev[0] = n - 1
    indices_next[n - 1] = 0

    iter = 0
    i = 0
    while n > 3
      is_ear = true
      if Triangle.ccw(v[indices_prev[i]], v[i], v[indices_next[i]]) < 0
        k = indices_next[indices_next[i]]
        begin
          if Triangle.contains(v[k],  v[indices_prev[i]], v[i], v[indices_next[i]])
            is_ear = false
            break
          end
          k = indices_next[k]
        end while k != indices_prev[i]
      else
        is_ear = false
      end

      if is_ear
        iter = 0
        indices << [indices_prev[i], i, indices_next[i]]
        indices_next[indices_prev[i]] = indices_next[i]
        indices_prev[indices_next[i]] = indices_prev[i]
        n -= 1
        i = indices_prev[i]
      else
        iter += 1
        i = indices_next[i]
      end
      break if iter == n
    end # while n > 3
    if iter == n
      # p "Failed."
      return nil
    else
      # puts "ear found : #{v[indices_prev[i]]}, #{v[i]}, #{v[indices_next[i]]}"
      # p "Done."
    end

    indices << [indices_prev[i], i, indices_next[i]]

    return indices
  end

  def self.convex?(polygon_points)
    polygon_points.length.times do |i|
      if Triangle.ccw(polygon_points[(i - 1) % polygon_points.length], polygon_points[i], polygon_points[(i + 1) % polygon_points.length]) > 0
        return false
      end
    end
    return true
  end

  class PolygonForMerge

    attr_accessor :convex_index, :adjacents

    def initialize(tri_index)
      @convex_index = tri_index.clone
      @adjacents = []
    end

    def build_edge
      edges = []
      @convex_index.length.times do |i|
        edges << [@convex_index[i], @convex_index[(i + 1) % @convex_index.length]]
      end
      return edges
    end

    def has_edge?(edge) # edge = [i, j]
      edges = build_edge()
      edges.each do |e|
        return true if e.sort == edge.sort
      end
      return false
    end

    def shared_edge(other)
      edges_self = build_edge()
      edges_other = other.build_edge()

      edges_self.each do |e_self|
        edges_other.each do |e_other|
          if e_self.sort == e_other.sort
            return e_self
          end
        end
      end

      return nil
    end

    def merge(other)
      # merge other's polygon
      edge_shared = self.shared_edge(other)
      return false if edge_shared == nil # puts "NOT FOUND"

      insert_at   =  self.convex_index.find_index(edge_shared[0]) + 1
      merge_start = other.convex_index.find_index(edge_shared[0]) + 1
      # p edge_shared, merge_start, other.convex_index[merge_start]
      spliced = []
      (other.convex_index.length - 2).times do |i|
        spliced << other.convex_index[(merge_start + i) % other.convex_index.length]
      end
      spliced.reverse!

      spliced.each do |i|
        self.convex_index.insert(insert_at, i)
      end

      # take over other's adjacency information
      other.adjacents.each do |cp|
        self.adjacents << cp if cp != self
      end

      return true
    end

    def convex?(polygon_points)
      convex_points = []
      convex_index.each do |i|
        convex_points << polygon_points[i]
      end
      return ConvexPartitioning.convex?(convex_points)
    end

  end


  # Hertel-Mehlhorn Algorithm
  # Ref.: Christer Ericson, Real-Time Collision Detection
  def self.decompose(polygon_points)
    # This algorithm is based on triangulation by ear-cutting
    triangles = []
    tri_indices = []
    n = polygon_points.length
    v = polygon_points

    indices_prev = []
    indices_next = []
    n.times do |i|
      indices_prev << i - 1
      indices_next << i + 1
    end
    indices_prev[0] = n - 1
    indices_next[n - 1] = 0

    temp_polygon = nil
    temp_polygon_new = nil
    convex_indices = []
    iter = 0
    i = 0
    while n >= 3
      is_ear = true
      if Triangle.ccw(v[indices_prev[i]], v[i], v[indices_next[i]]) < 0
        k = indices_next[indices_next[i]]
        begin
          if Triangle.contains(v[k],  v[indices_prev[i]], v[i], v[indices_next[i]])
            is_ear = false
            break
          end
          k = indices_next[k]
        end while k != indices_prev[i]
      else
        is_ear = false
      end

      if is_ear
        iter = 0
        tri_indices << [indices_prev[i], i, indices_next[i]]

        temp_polygon_new = PolygonForMerge.new([indices_prev[i], i, indices_next[i]])
        merge_success = true
        if temp_polygon != nil
          merge_success = temp_polygon_new.merge(temp_polygon)
          if not merge_success
            convex_indices << temp_polygon.convex_index
            temp_polygon = temp_polygon_new
          end
        end

        if merge_success
          if temp_polygon_new.convex?(v) # If the ear triangle has a removable diagonal
            temp_polygon = temp_polygon_new
          else # Merging the ear makes temp_polygon concave, then output current polygon and restart merger
            convex_indices << temp_polygon.convex_index
            temp_polygon = PolygonForMerge.new([indices_prev[i], i, indices_next[i]])
          end
        end

        indices_next[indices_prev[i]] = indices_next[i]
        indices_prev[indices_next[i]] = indices_prev[i]
        n -= 1
        i = indices_prev[i]
      else
        iter += 1
        i = indices_next[i]
      end
      break if iter == n
    end # while n >= 3

    return nil if iter == n # p "Failed."

    tri_indices << [indices_prev[i], i, indices_next[i]]

    convex_last = []
    if temp_polygon != nil
      temp_polygon.convex_index.each do |i|
        convex_last << i
      end
      convex_indices << convex_last
    end

    return convex_indices
  end

  # Ref.: David Eberly, "Triangulation by Ear Clipping"
  # http://www.geometrictools.com/Documentation/TriangulationByEarClipping.pdf
  def self.find_mutually_visible_vertices(outer_polygon, inner_polygon, axis = RVec2.new(1.0, 0.0))
    # Search the inner polygon for vertex M of maximum x-value.
  # vertex_M = inner_polygon.max_by {|v| v.x} # usable if axis == (1, 0)
    vertex_M = inner_polygon.max_by {|v| RVec2.dot(v, axis)}

    # Let I be the closest visible point to M on the ray M + t(1, 0).
    vertex_I = RVec2.new(Float::MAX, vertex_M.y)
    vertex_I_dot = Float::MAX
    vertex_P = nil
    outer_polygon.each_with_index do |vertex_current, index|
      # next if vertex_current.x < vertex_M.x
      vertex_next = outer_polygon[(index + 1) % outer_polygon.length]
      # next if vertex_next.x < vertex_M.x
    # vertex_I_new = Intersection.get_ray_segment_intersection(vertex_M, RVec2.new(1.0, 0.0), vertex_current, vertex_next) # usable if axis == (1, 0)
      vertex_I_new = Intersection.get_ray_segment_intersection(vertex_M, axis, vertex_current, vertex_next)
    # if vertex_I_new != nil && vertex_I_new.x < vertex_I.x # usable if axis == (1, 0)
      if vertex_I_new != nil
        vertex_I_new_dot = RVec2.dot(vertex_I_new, axis)
        if vertex_I_new_dot < vertex_I_dot
          vertex_I = vertex_I_new
          vertex_I_dot = vertex_I_new_dot
          # I is an interior point of the edge. Select P to be the endpoint of maximum x-value for this edge.
          vertex_current_dot = RVec2.dot(vertex_current, axis)
          vertex_next_dot = RVec2.dot(vertex_next, axis)
        # vertex_P = vertex_current.x >= vertex_next.x ? vertex_current : vertex_next # usable if axis == (1, 0)
          vertex_P = vertex_current_dot >= vertex_next_dot ? vertex_current : vertex_next
        end
      end
    end

    # Search the reflex vertices of the outer polygon.
    vertex_R = nil
    angle_MR = Math::PI
    outer_polygon.each_with_index do |vertex_current, index|
      vertex_prev = outer_polygon[(index - 1 + outer_polygon.length) % outer_polygon.length]
      vertex_next = outer_polygon[(index + 1) % outer_polygon.length]
      vertex_is_reflex = Triangle.ccw(vertex_prev, vertex_current, vertex_next) > 0
      if vertex_is_reflex
        is_inside = Triangle.contains(vertex_current, vertex_M, vertex_I, vertex_P)
        if is_inside
          # At least one reflex vertex lies in <M, I, P>. Search for the reflex R that minimizes
          # the angle between (1, 0) and the line segment <M, R>. The M and R are mutually visible.
        # angle_MR_new = Math.acos(RVec2.dot((vertex_current - vertex_M).getNormalized, RVec2.new(1,0)).abs) # usable if axis == (1, 0)
          angle_MR_new = Math.acos(RVec2.dot((vertex_current - vertex_M).getNormalized, axis).abs)
          if angle_MR_new < angle_MR
            angle_MR = angle_MR_new
            vertex_R = vertex_current
          end
        end
      end
    end
    # If all of these vertices are strictly outside triangle <M, I, P> then M and P are mutually visible.
    vertex_R = vertex_P if vertex_R == nil
    index_outer = outer_polygon.find_index(vertex_R)
    index_inner = inner_polygon.find_index(vertex_M)
    return index_outer, index_inner
  end

  def self.merge_inner_polygon(outer_polygon, inner_polygon)
    index_outer, index_inner = ConvexPartitioning.find_mutually_visible_vertices(outer_polygon, inner_polygon)
    mutually_visible_edge = [index_outer, index_inner]

    merged_polygon = outer_polygon.rotate( (mutually_visible_edge[0] + 1) % outer_polygon.length )
    append_polygon = inner_polygon.rotate( (mutually_visible_edge[1] + 1) % inner_polygon.length ).reverse!

    merged_polygon.concat(append_polygon)
    merged_polygon << merged_polygon[outer_polygon.length]
    merged_polygon << merged_polygon[outer_polygon.length-1]

    return merged_polygon, append_polygon
  end

end

if __FILE__ == $0
  points = []

#  points << RVec2.new(0.0, 0.0)
  points << RVec2.new(1.0, 0.0)
  points << RVec2.new(0.0, -1.0)
  points << RVec2.new(-1.0, 0.0)
  points << RVec2.new(0.0, 1.0)

  p indices = ConvexPartitioning.triangulate(points)
end
