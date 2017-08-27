# Ref.: http://geomalgorithms.com/a09-_intersect-3.html
#       http://stackoverflow.com/questions/4876065/check-if-polygon-is-self-intersecting
require 'rmath3d/rmath3d_plain'
include RMath3D

require_relative 'common'
require_relative 'intersection'

module Polygon

  def self.point_inside?(p, polygon_points)
    crossing = 0
    d = RVec2.new(1, 0)
    n = polygon_points.length
    n.times do |i|
      p0 = polygon_points[i]
      p1 = polygon_points[(i + 1) % n]
      crossing += 1 if Intersection.test_ray_segment(p, d, p0, p1)
    end

    return (crossing % 2 == 1)
  end

  # sort polygon_points clockwise/counterclockwise order.
  # Ref.: http://stackoverflow.com/questions/6989100/sort-points-in-clockwise-order
  def self.reorder(polygon_points)
    # TODO
    # See VoronoiDiagram.calculate_VDBDT
  end

end

if __FILE__ == $0
  points = []

  points << RVec2.new(0.0, 0.0)
  points << RVec2.new(0.0, 100.0)
  points << RVec2.new(100.0, 100.0)
  points << RVec2.new(100.0, 0.0)

  p Polygon.point_inside?(RVec2.new(50.0, 50.0), points)
  p Polygon.point_inside?(RVec2.new(150.0, 150.0), points)
end
