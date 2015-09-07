# Ref.: http://geomalgorithms.com/a09-_intersect-3.html
#       http://stackoverflow.com/questions/4876065/check-if-polygon-is-self-intersecting
require 'rmath3d/rmath3d_plain'
include RMath3D

require_relative 'triangle'

module SegmentIntersection

  # Ref. : http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment
  def self.distance_from_point(point, edge_from, edge_to)
    edge_dir = edge_to - edge_from
    edge_squared_length = edge_dir.getLengthSq
    if edge_squared_length < Float::EPSILON
      return (edge_from - point).getLength
    end

    distance = 0.0
    edge_start_to_point = point - edge_from
    t = RVec2.dot(edge_start_to_point, edge_dir) / edge_squared_length
    if t < 0
      distance = (edge_from - point).getLength
    elsif t > 1
      distance = (edge_to - point).getLength
    else
      projection = edge_from + t * edge_dir
      distance = (projection - point).getLength
    end
    return distance
  end

  # Ref.: Real-Time Collision Detection, Ch. 5.1.9.1
  def self.intersect?(a, b, c, d)
    a1 = Triangle.signed_area(a, b, d)
    a2 = Triangle.signed_area(a, b, c)
    if a1 * a2 < 0
      a3 = Triangle.signed_area(c, d, a)
      a4 = a3 + a2 - a1 # == Triangle.signed_area(c, d, b)
      # t = a3 / (a3 - a4)
      # p = a + t * (b - a)
      return a3 / (a3 - a4) if a3 * a4 < 0
    end
    return nil
  end

  def self.find(points, indices)
    return find_Bruteforce(points, indices)
  end

  def self.find_Bruteforce(points, indices)
    # TODO
  end

  def self.find_BentleyOttmann(points, indices)
    # TODO
  end

  def self.check(points, indices)
    return check_Bruteforce(points, indices)
  end

  def self.check_Bruteforce(points, indices)
    for i in 0...(indices.length - 1) do
      for j in i...indices.length do
        return true if intersect?(points[indices[i][0]], points[indices[i][1]], points[indices[j][0]], points[indices[j][1]])
      end
    end
    return false
  end

  def self.check_ShamosHoey(points, indices)
    # TODO
  end

end

if __FILE__ == $0
  points = []

  points << RVec2.new(1.0, 0.0)
  points << RVec2.new(0.0, -1.0)
  points << RVec2.new(-1.0, 0.0)
  points << RVec2.new(0.0, 1.0)
  points << RVec2.new(0.0, 0.0)
  points << RVec2.new(1.0, 1.0)

  indices = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5]]

  p SegmentIntersection.check(points, indices)
end
