# coding: utf-8
require 'rmath3d/rmath3d_plain'
include RMath3D

require_relative 'common'
require_relative 'intersection'

module LinearProgram

  # A directed line through two points @p1 and @p2.
  class Line2D
    attr_accessor :p0, :p1

    def initialize(*args)
      if args.length == 2 # given two points p0 and p1.
        p0, p1 = args[0], args[1]
        raise ArgumentError "Line2D : Creating degenerate line." if (p1 - p0).getLengthSq <= RMath3D::TOLERANCE

        # Ensure all members are the instances of Float.
        p0.x = p0.x.to_f
        p0.y = p0.y.to_f
        p1.x = p1.x.to_f
        p1.y = p1.y.to_f

        @p0, @p1 = p0, p1
      elsif args.length == 3 # given 3 coefficients (a, b, c) of constraint : ax + by <= c
        a, b, c = args[0], args[1], args[2]
        x0, y0, x1, y1 = 0.0, 0.0, 0.0, 0.0
        if a.abs <= RMath3D::TOLERANCE
          # by <= c (b >= 0) or by > c (b < 0)
          if b >= 0.0
            x0, y0 =  0.0, c / b
            x1, y1 = -1.0, c / b
          else
            x0, y0 =  0.0, c / b
            x1, y1 =  1.0, c / b
          end
        elsif b.abs <= RMath3D::TOLERANCE
          # ax <= c (a >= 0) or ax > c (a < 0)
          if a >= 0.0
            x0, y0 =  c / a, 0.0
            x1, y1 =  c / a, 1.0
          else
            x0, y0 =  c / a, 0.0
            x1, y1 =  c / a,-1.0
          end
        else
          # ax + by <= c (b >= 0) or ax + by > c (b < 0)
          if b >= 0.0
            x0, y0 =  1.0, (c - a) / b
            x1, y1 =  0.0, c / b
          else
            x0, y0 =  0.0, c / b
            x1, y1 =  1.0, (c - a) / b
          end
        end
        @p0 = RVec2.new(x0, y0)
        @p1 = RVec2.new(x1, y1)
      else
        raise ArgumentError
      end
    end

    def position; @p0; end
    def direction; (@p1 - @p0).normalize!; end

    # p : Point (RVec2)
    def in_left(p)
      return CompGeom.ccw(@p0, @p1, p) > 0
    end
    alias :inside :in_left

    # d : Direction (unit length RVec2)
    # returns true if +d+ indicates inside of this line.
    def toward_left(d)
      return RVec2.cross(direction, d) > 0
    end

    def self.intersection(line1, line2)
      return Intersection.get_lines_intersection(line1.p0, line1.p1, line2.p0, line2.p1)
    end

    def self.parallel?(line1, line2)
      return Intersection.test_lines_parallel(line1.p0, line1.p1, line2.p0, line2.p1)
    end

    # Returns true if two line constraints make no common feasible region.
    def self.infeasible?(line1, line2)
      return self.parallel?(line1, line2) && (RVec2.dot(line1.direction, line2.direction) < 0)
    # return RVec2.dot(line1.direction, line2.direction) <= (-1 + RMath3D::TOLERANCE)
    end

    # Returns boundary candidate as a signed distance between 'self.p0' and the intersection point.
    # - If the intersection point is in front of 'self.p0', result will have positive('+') sign.
    # - Otherwise the result will be negative('-').
    def calc_boundary(h_j)
      x_world = Line2D.intersection(self, h_j) # intersection point in world coordinate system
      if x_world == nil || x_world.x.nan? || x_world.y.nan? || x_world.x.infinite? || x_world.y.infinite?
        return nil
      end
      x_local = x_world - self.position # intersection point in local coordinate system
      sgn = CompGeom.sgn(RVec2.dot(x_local, self.direction)) # '+1' if x_local is in front of p0. otherwise '-1'.
      boundary_new = sgn * x_local.getLength # sgn((X-P0) . d) . |X-P0|
      return boundary_new
    end
  end


  # constraints : Half-plane constraints described as an Array of Line2D
  # objective : Vec2(cx, cy)
  # mx, my : Float
  def self.solve2DBoundedLP(constraints, objective, mx = 1_000_000.0, my = 1_000_000.0)
    cx, cy = objective.x, objective.y
    m1 = if cx > 0
           Line2D.new(RVec2.new(mx, 0), RVec2.new(mx, 1))
         else
           Line2D.new(RVec2.new(-mx, 1), RVec2.new(-mx, 0))
         end
    m2 = if cy > 0
           Line2D.new(RVec2.new(1, my), RVec2.new(0, my))
         else
           Line2D.new(RVec2.new(0, -my), RVec2.new(1, -my))
         end

    vtx_current = Line2D.intersection(m1, m2) # v0

    constraints.each_with_index do |h_i, i|
      next if h_i.inside(vtx_current) # puts "line=(#{h_i.p0}, #{h_i.p1}), vtx_current=#{vtx_current} : #{h_i.inside(vtx_current) ? 'inside' : 'outside'}"

      # [Needs ORCA-specific process here] test line-sphere intersection
      # -> return false if no intersections found. This means that the max-speed
      # circle is fully outside of the newly-added half-space.

      #
      # 1D LP
      #

      # - Build 1D feasible region [boundary_l, boundary_r] incrementally.
      # - Return false if this problem is proved infeasible.
      boundary_l = -Float::MAX # Left  (Lower bound in 1D LP)
      boundary_r =  Float::MAX # Right (Upper bound in 1D LP)
      [m1, m2].concat(constraints[0...i]).each do |h_j|
        boundary_new = h_i.calc_boundary(h_j)
        if boundary_new == nil || boundary_new.nan?
          vtx_current = nil
          break
        end
        if h_i.toward_left(h_j.direction)
          boundary_r = [boundary_r, boundary_new].min
        else
          boundary_l = [boundary_l, boundary_new].max
        end
        if boundary_l > boundary_r
          vtx_current = nil
          break
        end
      end
      break if vtx_current == nil

      # [Needs ORCA-specific process here]
      # The optimization function is the distance to the preferred velocity.

      vtx_current = if RVec2.dot(objective, h_i.direction) > 0
                      h_i.position + boundary_r * h_i.direction
                    else
                      h_i.position + boundary_l * h_i.direction
                    end
    end

    return vtx_current
  end

end

if __FILE__ == $0
  # Making constraints through points
  gap = 0.00001
  lines = [
    # A
    LinearProgram::Line2D.new(RVec2.new(4, 3), RVec2.new(1, 0)),
    LinearProgram::Line2D.new(RVec2.new(1, 0), RVec2.new(5,-1)),
    LinearProgram::Line2D.new(RVec2.new(5,-1), RVec2.new(4, 3)),
    # B
    LinearProgram::Line2D.new(RVec2.new(0, 0), RVec2.new(4, 1)),
    LinearProgram::Line2D.new(RVec2.new(4, 1), RVec2.new(1, 4)),
    LinearProgram::Line2D.new(RVec2.new(1, 4), RVec2.new(0, 0)),
    # Inconsistent constraints (for test purpose only)
  # LinearProgram::Line2D.new(RVec2.new(3+gap, 5), RVec2.new(2+gap,-5)),
  # LinearProgram::Line2D.new(RVec2.new(2-gap,-5), RVec2.new(3-gap, 5)),
  ].shuffle!
=begin
  # Making constraints through coefficients
  lines = [
    # A
    LinearProgram::Line2D.new(-1.0, 1.0, -1.0),
    LinearProgram::Line2D.new(-1.0,-4.0, -1.0),
    LinearProgram::Line2D.new( 4.0, 1.0, 19.0),
    # B
    LinearProgram::Line2D.new(-4.0, 1.0,  0.0),
    LinearProgram::Line2D.new( 1.0,-4.0,  0.0),
    LinearProgram::Line2D.new( 1.0, 1.0,  5.0),
  ].shuffle!
=end
  objective = RVec2.new(-1.0, -1.0)
  p LinearProgram.solve2DBoundedLP(lines, objective) # -> RVec2(1.333333, 0.33333)

  lines = [
    # OptMath p.168
    LinearProgram::Line2D.new(2.0, 8.0, 60.0),
    LinearProgram::Line2D.new(4.0, 4.0, 60.0),
  ].shuffle!
  objective = RVec2.new(29.0, 45.0)
  p LinearProgram.solve2DBoundedLP(lines, objective) # -> RVec2(10.0, 5.0)
end
