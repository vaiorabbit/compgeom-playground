# Usage:
# $ gem install rmath3d_plain
# $ ruby test_triangulation.rb
require 'opengl'
require 'glfw'
require 'rmath3d/rmath3d_plain'
require_relative 'nanovg'
require_relative 'compgeom/delaunay'
require_relative 'compgeom/intersection'

OpenGL.load_lib()
GLFW.load_lib()
NanoVG.load_dll('libnanovg_gl3.dylib', render_backend: :gl3)

include OpenGL
include GLFW
include NanoVG
include RMath3D

$plot_spiral = false
$plot_random = false

class Graph
  attr_accessor :nodes, :triangle_indices

  def initialize
    @nodes = []
    @polygon = []

#    @undo_insert_index = -1
    @node_radius = 10.0

    @triangle_indices = []
  end

  def add_node(x, y)
    @nodes << RVec2.new(x, y)
    @polygon << (@nodes.length - 1)
  end

  def insert_node0(point_x, point_y)
    if @nodes.length < 3
      add_node(point_x, point_y)
      if @nodes.length == 3 && Triangle.ccw(@nodes[0], @nodes[1], @nodes[2]) > 0
        @nodes[1], @nodes[2] = @nodes[2], @nodes[1]
        @polygon[1], @polygon[2] = @polygon[2], @polygon[1]
      end
      return
    end
    point = RVec2.new(point_x, point_y)

    # Calculate distance from point to all edges.
    # Ref. : http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment
    distances = Array.new(@nodes.length) { -Float::MAX }
    @nodes.each_with_index do |node_current, index|
      node_next = @nodes[(index + 1) % @nodes.length]
      edge_dir = node_next - node_current
      edge_squared_length = edge_dir.getLengthSq
      if edge_squared_length < Float::EPSILON
        distances[index] = (node_current - point).getLength
        next
      end
      edge_start_to_point = point - node_current
      t = RVec2.dot(edge_start_to_point, edge_dir) / edge_squared_length
      if t < 0
        distances[index] = (node_current - point).getLength
      elsif t > 1
        distances[index] = (node_next - point).getLength
      else
        projection = node_current + t * edge_dir
        distances[index] = (projection - point).getLength
      end
    end

    # Find nearest edge and insert new Node as a dividing point.
    segment_indices = []
    @nodes.length.times do |i|
      segment_indices << [i, (i + 1) % @nodes.length]
    end

    nearest_edge_index = -1

    minimum_distances = distances.min_by(2) {|d| d}
    if minimum_distances[0] != minimum_distances[1]
      i = distances.find_index( minimum_distances[0] )
      edge_node_indices = segment_indices.select { |segment_index| segment_index.include?(i) }
      e0_self_intersect = SegmentIntersection.check(@nodes + [point], segment_indices - [edge_node_indices[0]] + [[edge_node_indices[0][0], @nodes.length], [@nodes.length, edge_node_indices[0][1]]])
      e1_self_intersect = SegmentIntersection.check(@nodes + [point], segment_indices - [edge_node_indices[1]] + [[edge_node_indices[1][0], @nodes.length], [@nodes.length, edge_node_indices[1][1]]])
      if e0_self_intersect && e1_self_intersect
        nearest_edge_index = -1
      elsif e0_self_intersect
        nearest_edge_index = edge_node_indices[1][0]
      elsif e1_self_intersect
        nearest_edge_index = edge_node_indices[0][0]
      else
        nearest_edge_index = i
      end

    end

    if nearest_edge_index == -1

      distances = Array.new(@nodes.length) { -Float::MAX }
      @nodes.each_with_index do |node_current, index|
        distances[index] = (node_current - point).getLength
      end
      distances.sort.each do |d|
        i = distances.find_index(d)
        edge_node_indices = segment_indices.select { |segment_index| segment_index.include?(i) }
        e0_self_intersect = SegmentIntersection.check(@nodes + [point], segment_indices - [edge_node_indices[0]] + [[edge_node_indices[0][0], @nodes.length], [@nodes.length, edge_node_indices[0][1]]])
        e1_self_intersect = SegmentIntersection.check(@nodes + [point], segment_indices - [edge_node_indices[1]] + [[edge_node_indices[1][0], @nodes.length], [@nodes.length, edge_node_indices[1][1]]])
        if e0_self_intersect && e1_self_intersect
          next
        elsif e0_self_intersect
          nearest_edge_index = edge_node_indices[1][0]
          break
        elsif e1_self_intersect
          nearest_edge_index = edge_node_indices[0][0]
          break
        else
          nearest_edge_index = i
          break
        end
      end
    end

    if nearest_edge_index == -1
      puts "fail"
      return
    end

    @nodes.insert( nearest_edge_index + 1, RVec2.new(point_x, point_y) )
#    @undo_insert_index = nearest_edge_index + 1
  end

  def insert_node(point_x, point_y)
    if @polygon.length < 3
      add_node(point_x, point_y)
      if @polygon.length == 3 && Triangle.ccw(@nodes[@polygon[0]], @nodes[@polygon[1]], @nodes[@polygon[2]]) > 0
        @nodes[1], @nodes[2] = @nodes[2], @nodes[1]
        @polygon[1], @polygon[2] = @polygon[2], @polygon[1]
      end
      return
    end
    point = RVec2.new(point_x, point_y)

    # Calculate distance from point to all edges.
    # Ref. : http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment
    distances = Array.new(@polygon.length) { -Float::MAX }
    @polygon.each_with_index do |polygon_current, index|
      node_current = @nodes[polygon_current]
      node_next = @nodes[@polygon[(index + 1) % @polygon.length]]
      edge_dir = node_next - node_current
      edge_squared_length = edge_dir.getLengthSq
      if edge_squared_length < Float::EPSILON
        distances[index] = (node_current - point).getLength
        next
      end
      edge_start_to_point = point - node_current
      t = RVec2.dot(edge_start_to_point, edge_dir) / edge_squared_length
      if t < 0
        distances[index] = (node_current - point).getLength
      elsif t > 1
        distances[index] = (node_next - point).getLength
      else
        projection = node_current + t * edge_dir
        distances[index] = (projection - point).getLength
      end
    end

    # Find nearest edge and insert new Node as a dividing point.
    segment_indices = []
    @polygon.length.times do |i|
      # TODO : Remove duplicate edge
      segment_indices << [@polygon[i], @polygon[(i + 1) % @polygon.length]]
    end

    nearest_edge_index = -1

    minimum_distances = distances.min_by(2) {|d| d}
    if minimum_distances[0] != minimum_distances[1]
      i = distances.find_index( minimum_distances[0] )
      edge_node_indices = segment_indices.select { |segment_index| segment_index.include?(i) }
      # exit if edge_node_indices.length != 2
      e0_self_intersect = SegmentIntersection.check(@nodes + [point], segment_indices - [edge_node_indices[0]] + [[edge_node_indices[0][0], @nodes.length], [@nodes.length, edge_node_indices[0][1]]])
      e1_self_intersect = SegmentIntersection.check(@nodes + [point], segment_indices - [edge_node_indices[1]] + [[edge_node_indices[1][0], @nodes.length], [@nodes.length, edge_node_indices[1][1]]])
      if e0_self_intersect && e1_self_intersect
        nearest_edge_index = -1
      elsif e0_self_intersect
        nearest_edge_index = edge_node_indices[1][0]
      elsif e1_self_intersect
        nearest_edge_index = edge_node_indices[0][0]
      else
        nearest_edge_index = i
      end

    end

    if nearest_edge_index == -1

      distances = Array.new(@nodes.length) { -Float::MAX }
      @nodes.each_with_index do |node_current, index|
        distances[index] = (node_current - point).getLength
      end
      distances.sort.each do |d|
        i = distances.find_index(d)
        edge_node_indices = segment_indices.select { |segment_index| segment_index.include?(i) }
        e0_self_intersect = SegmentIntersection.check(@nodes + [point], segment_indices - [edge_node_indices[0]] + [[edge_node_indices[0][0], @nodes.length], [@nodes.length, edge_node_indices[0][1]]])
        e1_self_intersect = SegmentIntersection.check(@nodes + [point], segment_indices - [edge_node_indices[1]] + [[edge_node_indices[1][0], @nodes.length], [@nodes.length, edge_node_indices[1][1]]])
        if e0_self_intersect && e1_self_intersect
          next
        elsif e0_self_intersect
          nearest_edge_index = edge_node_indices[1][0]
          break
        elsif e1_self_intersect
          nearest_edge_index = edge_node_indices[0][0]
          break
        else
          nearest_edge_index = i
          break
        end
      end
    end

    if nearest_edge_index == -1
      puts "fail"
      return
    end

    @nodes << RVec2.new(point_x, point_y)
    @polygon.insert( nearest_edge_index + 1, @nodes.length - 1 )
#    @undo_insert_index = nearest_edge_index + 1
  end

  def undo_insert
#    if @undo_insert_index >= 0
#      @nodes.delete_at(@undo_insert_index)
#      @undo_insert_index = -1
#    end
  end

  def node_removable?(node_index)
    segment_indices = []
    new_edge_index = []
    @nodes.length.times do |i|
      if i == node_index 
        new_edge_index << (i + 1) % @nodes.length
        next
      end
      if (i + 1) % @nodes.length == node_index
        new_edge_index << i
        next
      end
      segment_indices << [i, (i + 1) % @nodes.length]
    end
    return SegmentIntersection.check(@nodes, segment_indices + [new_edge_index]) == false
  end

  def remove_nearest_node(point_x, point_y, ignore_self_intersection: true)
    distances = Array.new(@nodes.length) { -Float::MAX }
    @nodes.each_with_index do |node_current, index|
      distances[index] = (node_current.x - point_x)**2 + (node_current.y - point_y)**2
    end
    minimum_distance = distances.min_by {|d| d}
    if minimum_distance <= @node_radius ** 2
      nearest_node_index = distances.find_index( minimum_distance )
#      @undo_insert_index = -1
      if ignore_self_intersection || node_removable?(nearest_node_index)
        @nodes.delete_at(nearest_node_index)
      else
        puts "[WARN] remove_nearest_node : Failed. Removing the node #{nearest_node_index} will make self-intersecting polygon."
      end
    end
  end

  def triangulate
    return if @nodes.length < 3
    @triangle_indices, @triangles = DelaunayTriangulation.calculate(@nodes)
  end

  def clear
    @nodes.clear
    @polygon.clear
    @triangle_indices.clear
    @triangles.clear
  end

  def render(vg, render_edge: false, render_node: true)
    # Triangles
    if @triangle_indices.length > 0
      color = nvgRGBA(0,255,0, 255)
      lw = @node_radius * 0.5
      @triangle_indices.each do |indices|
        nvgLineCap(vg, NVG_ROUND)
        nvgLineJoin(vg, NVG_ROUND)
        nvgBeginPath(vg)
        nvgMoveTo(vg, @nodes[indices[0]].x, @nodes[indices[0]].y)
        nvgLineTo(vg, @nodes[indices[1]].x, @nodes[indices[1]].y)
        nvgLineTo(vg, @nodes[indices[2]].x, @nodes[indices[2]].y)
        nvgClosePath(vg)
        color = nvgRGBA(0,255,0, 64)
        nvgFillColor(vg, color)
        nvgFill(vg)
        color = nvgRGBA(255,128,0, 255)
        nvgStrokeColor(vg, color)
        nvgStrokeWidth(vg, lw)
        nvgStroke(vg)
      end
    end

    # Edges
    if render_edge and @nodes.length >= 2
      color = nvgRGBA(255,128,0, 255)
      lw = @node_radius * 0.5
      nvgLineCap(vg, NVG_ROUND)
      nvgLineJoin(vg, NVG_ROUND)
      nvgBeginPath(vg)
      @nodes.length.times do |i|
        if i == 0
          nvgMoveTo(vg, @nodes[0].x, @nodes[0].y)
        else
          nvgLineTo(vg, @nodes[i].x, @nodes[i].y)
        end
      end
      nvgClosePath(vg)
      nvgStrokeColor(vg, color)
      nvgStrokeWidth(vg, lw)
      nvgStroke(vg)
    end

    # Nodes
    if render_node and @nodes.length > 0
      color = nvgRGBA(0,192,255, 255)
      nvgBeginPath(vg)
      @nodes.each do |node|
        nvgCircle(vg, node.x, node.y, @node_radius)
        nvgFillColor(vg, color)
      end
      nvgFill(vg)
    end

  end
end

$graph = Graph.new


key = GLFW::create_callback(:GLFWkeyfun) do |window, key, scancode, action, mods|
  if key == GLFW_KEY_ESCAPE && action == GLFW_PRESS # Press ESC to exit.
    glfwSetWindowShouldClose(window, GL_TRUE)
  elsif key == GLFW_KEY_R && action == GLFW_PRESS # Press 'R' to clear graph.
    $graph.clear
  elsif key == GLFW_KEY_T && action == GLFW_PRESS # Press 'T' to triangulate graph.
    $graph.triangulate
  elsif key == GLFW_KEY_Z && action == GLFW_PRESS && (mods & GLFW_MOD_CONTROL != 0) # Remove the last node your added by Ctrl-Z.
    $graph.undo_insert
  end
end

$spiral_theta = 0.0
$spiral_radius = Float::EPSILON

mouse = GLFW::create_callback(:GLFWmousebuttonfun) do |window_handle, button, action, mods|
  if $plot_spiral
    sx = $spiral_radius * Math.cos($spiral_theta)
    sy = $spiral_radius * Math.sin($spiral_theta)
    sx += 1280 * 0.5
    sy += 720 * 0.5
    $graph.add_node(sx, sy) # insert_node(sx, sy)
    $graph.triangulate
    $spiral_theta += 22.0 * Math::PI/180 # Math::PI * (3 - Math.sqrt(5)) # golden angle in radian
    $spiral_radius += 4.0
    return
  end

  if $plot_random
    sx = rand(1280.0)
    sy = rand(720.0)
    $graph.add_node(sx, sy) # insert_node(sx, sy)
    $graph.triangulate
    return
  end

  if button == GLFW_MOUSE_BUTTON_LEFT && action == 0
    mx_buf = ' ' * 8
    my_buf = ' ' * 8
    glfwGetCursorPos(window_handle, mx_buf, my_buf)
    mx = mx_buf.unpack('D')[0]
    my = my_buf.unpack('D')[0]
    if (mods & GLFW_MOD_SHIFT) != 0
      $graph.remove_nearest_node(mx, my)
      $graph.triangulate
    else
      $graph.add_node(mx, my) # insert_node(mx, my)
      $graph.triangulate
    end
  end
end


if __FILE__ == $0

  $plot_spiral = ARGV[0] == "-plot_spiral"
  $plot_random = ARGV[0] == "-plot_random"

  if glfwInit() == GL_FALSE
    puts("Failed to init GLFW.")
    exit
  end

  # glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2)
  # glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0)
  glfwDefaultWindowHints()
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE)
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4)
  glfwWindowHint(GLFW_DECORATED, 0)

  window = glfwCreateWindow( 1280, 720, "Triangulation", nil, nil )
  if window == 0
    glfwTerminate()
    exit
  end

  glfwSetKeyCallback( window, key )
  glfwSetMouseButtonCallback( window, mouse )

  glfwMakeContextCurrent( window )

  nvgSetupGL3()
  vg = nvgCreateGL3(NVG_ANTIALIAS | NVG_STENCIL_STROKES)
  if vg == nil
    puts("Could not init nanovg.")
    exit
  end

  winWidth_buf  = '        '
  winHeight_buf = '        '
  fbWidth_buf  = '        '
  fbHeight_buf = '        '

  glfwSwapInterval(0)
  glfwSetTime(0)

  total_time = 0.0

  prevt = glfwGetTime()

  while glfwWindowShouldClose( window ) == 0
    t = glfwGetTime()
    dt = t - prevt # 1.0 / 60.0
    prevt = t
    total_time += dt

    glfwGetWindowSize(window, winWidth_buf, winHeight_buf)
    glfwGetFramebufferSize(window, fbWidth_buf, fbHeight_buf)
    winWidth = winWidth_buf.unpack('L')[0]
    winHeight = winHeight_buf.unpack('L')[0]
    fbWidth = fbWidth_buf.unpack('L')[0]
    fbHeight = fbHeight_buf.unpack('L')[0]

    pxRatio = fbWidth.to_f / winWidth.to_f

    glViewport(0, 0, fbWidth, fbHeight)
    glClearColor(0.8, 0.8, 0.8, 1.0)
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT|GL_STENCIL_BUFFER_BIT)

    nvgBeginFrame(vg, winWidth, winHeight, pxRatio)
    nvgSave(vg)

    $graph.render(vg)

    nvgRestore(vg)
    nvgEndFrame(vg)

    glfwSwapBuffers( window )
    glfwPollEvents()

    if ($plot_spiral || $plot_random) && total_time > 0.01
      mouse.call(window, 0, 0, 0)
      total_time = 0
    end
  end

  nvgDeleteGL3(vg)

  glfwTerminate()
end
