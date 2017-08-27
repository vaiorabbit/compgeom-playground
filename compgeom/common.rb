# coding: utf-8
require 'rmath3d/rmath3d_plain'
include RMath3D

module CompGeom

  # +1 : counterclockwise / collinear (p0 is in between p1 and p2).
  # -1 : clockwise / collinear (p2 is in between p0 and p1).
  #  0 : collinear (p1 is in between p0 and p2)
  def self.ccw(p0, p1, p2)
    dx1 = p1.x - p0.x
    dy1 = p1.y - p0.y
    dx2 = p2.x - p0.x
    dy2 = p2.y - p0.y
    return +1 if dx1*dy2 > dy1*dx2
    return -1 if dx1*dy2 < dy1*dx2
    return -1 if (dx1*dx2 < 0) || (dy1*dy2 < 0)
    return +1 if dx1**2 + dy1**2 < dx2**2 + dy2**2
    return 0
  end

  # src and dst : A directed line through two points
  # p : Point (RVec2)
  def self.in_left(src, dst, p)
    return CompGeom.ccw(src, dst, p) > 0
  end

  # |a b|
  # |c d|
  def self.determinant(a, b, c, d)
    return a * d - b * c
  end

  # sign of +x+ : x > 0 -> +1, x < 0 -> -1
  def self.sgn(x)
    sgn = if x.abs > RMath3D::TOLERANCE
            sgn = x / x.abs
          else
            0
          end
  end

end
