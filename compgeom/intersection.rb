# coding: utf-8
# Ref.: http://geomalgorithms.com/a09-_intersect-3.html
#       http://stackoverflow.com/questions/4876065/check-if-polygon-is-self-intersecting
require 'rmath3d/rmath3d_plain'
include RMath3D

require_relative 'triangle'

module Intersection

  # Ref.: Real-Time Collision Detection, Ch. 5.1.9.1
  def self.test_segments(a, b, c, d)
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

  # Ref.: Real-Time Collision Detection, Ch. 5.1.9.1g
  def self.get_segments_intersection(a, b, c, d)
    a1 = Triangle.signed_area(a, b, d)
    a2 = Triangle.signed_area(a, b, c)
    if a1 * a2 < 0
      a3 = Triangle.signed_area(c, d, a)
      a4 = a3 + a2 - a1 # == Triangle.signed_area(c, d, b)
      if a3 * a4 < 0
        t = a3 / (a3 - a4)
        p = a + t * (b - a)
        return p
      end
    end
    return nil
  end

  # Ref.: https://rootllama.wordpress.com/2014/06/20/ray-line-segment-intersection-test-in-2d/
  #       https://stackoverflow.com/questions/14307158/how-do-you-check-for-intersection-between-a-line-segment-and-a-line-ray-emanatin
  def self.test_ray_segment(o, d, a, b)
    v1 = o - a
    v2 = b - a
    v3 = RVec2.new(-d.y, d.x)
    dot = RVec2.dot(v2, v3)
    return false if dot.abs <= Float::EPSILON

    t1 = RVec2.cross(v2, v1) / dot
    t2 = RVec2.dot(v1, v3) / dot
    return (t1 >= 0 && (0 <= t2 && t2 <= 1))
  end

  def self.get_ray_segment_intersection(o, d, a, b)
    v1 = o - a
    v2 = b - a
    v3 = RVec2.new(-d.y, d.x)
    dot = RVec2.dot(v2, v3)
    return nil if dot.abs <= Float::EPSILON

    t1 = RVec2.cross(v2, v1) / dot
    t2 = RVec2.dot(v1, v3) / dot

    intersect = (t1 >= 0 && (0 <= t2 && t2 <= 1))
    return intersect ? o + t1 * d : nil
  end

  # Returns true if two lines are parallel.
  def self.test_lines_parallel(a, b, c, d)
    x1, y1 = a.x, a.y
    x2, y2 = b.x, b.y
    x3, y3 = c.x, c.y
    x4, y4 = d.x, d.y

    det = CompGeom.determinant(x1-x2, y1-y2, x3-x4, y3-y4)
    return det.abs <= RMath3D::TOLERANCE
  end

  # https://en.wikipedia.org/wiki/Line–line_intersection
  # http://mathworld.wolfram.com/Line-LineIntersection.html
  def self.get_lines_intersection(a, b, c, d)
    x1, y1 = a.x, a.y
    x2, y2 = b.x, b.y
    x3, y3 = c.x, c.y
    x4, y4 = d.x, d.y

    det = CompGeom.determinant(x1-x2, y1-y2, x3-x4, y3-y4)
    return nil if det.abs <= RMath3D::TOLERANCE # Two lines are parallel

    det12 = CompGeom.determinant(x1, y1, x2, y2)
    det34 = CompGeom.determinant(x3, y3, x4, y4)

    int_x = CompGeom.determinant(det12, x1-x2, det34, x3-x4) / det
    int_y = CompGeom.determinant(det12, y1-y2, det34, y3-y4) / det

    return RVec2.new(int_x, int_y);
  end

  
end

module Distance

  # Ref. : http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment
  def self.point_segment(point, edge_from, edge_to)
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

end

module SegmentIntersection

  # Ref. : http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment
  def self.distance_from_point(point, edge_from, edge_to)
    return Distance.point_segment(point, edge_from, edge_to)
  end

  def self.intersect?(a, b, c, d)
    return Intersection.test_segments(a, b, c, d)
  end

  def self.get_intersection(a, b, c, d)
    return Intersection.get_segments_intersection(a, b, c, d)
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

  p Intersection.test_ray_segment(RVec2.new(0, 0.5), RVec2.new(1, 0), RVec2.new(0, 0), RVec2.new(0, 1))
  p Intersection.test_ray_segment(RVec2.new(1.5, 0.5), RVec2.new(1, 0), RVec2.new(0, 0), RVec2.new(0, 1))
end
