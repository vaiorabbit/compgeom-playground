# coding: utf-8
# Usage:
# $ gem install rmath3d_plain
# $ ruby test_convex_decomposition.rb
require 'pp'
require 'opengl'
require 'glfw'
require 'rmath3d/rmath3d_plain'
require_relative 'nanovg'
require_relative 'compgeom/convex_partitioning'
require_relative 'compgeom/intersection'


OpenGL.load_lib()
GLFW.load_lib()
NanoVG.load_dll('libnanovg_gl3.dylib', render_backend: :gl3)

include OpenGL
include GLFW
include NanoVG
include RMath3D

class FontPlane
  def initialize
    @fonts = []
  end

  def load(vg, name="sans", ttf="data/GenShinGothic-Bold.ttf")
    font_handle = nvgCreateFont(vg, name, ttf)
    if font_handle == -1
      puts "Could not add font."
      return -1
    end
    @fonts << font_handle
  end

  def render(vg, x, y, width, height, text, name: "sans", color: nvgRGBA(255,255,255,255))
    rows_buf = FFI::MemoryPointer.new(NVGtextRow, 3)
    glyphs_buf = FFI::MemoryPointer.new(NVGglyphPosition, 100)
    lineh_buf = '        '
    lineh = 0.0

    nvgSave(vg)

    nvgFontSize(vg, 44.0)
    nvgFontFace(vg, name)
    nvgTextAlign(vg, NVG_ALIGN_LEFT|NVG_ALIGN_TOP)
    nvgTextMetrics(vg, nil, nil, lineh_buf)
    lineh = lineh_buf.unpack('F')[0]

    text_start = text
    text_end = nil
    while ((nrows = nvgTextBreakLines(vg, text_start, text_end, width, rows_buf, 3)))
      rows = nrows.times.collect do |i|
        NVGtextRow.new(rows_buf + i * NVGtextRow.size)
      end
      nrows.times do |i|
        row = rows[i]

        nvgBeginPath(vg)
#        nvgFillColor(vg, nvgRGBA(255,255,255, 0))
#        nvgRect(vg, x, y, row[:width], lineh)
#        nvgFill(vg)

        nvgFillColor(vg, color)
        nvgText(vg, x, y, row[:start], row[:end])

        y += lineh
      end
      if rows.length > 0
        text_start = rows[nrows-1][:next]
      else
        break
      end
    end

    nvgRestore(vg)
  end
end

class Graph
  attr_accessor :nodes, :polygon_indices, :polygon

  def initialize
    @nodes = []
    @polygon = []

    @undo_insert_index = -1
    @node_radius = 10.0

    @polygon_indices = []
    @hull_indices = []
  end

  def add_node(x, y)
    @nodes << RVec2.new(x, y)
    @polygon << @nodes.last
  end

  def connecter_edge?(edge, same_edge_pair)
    is_connecter_edge = false
    edge_sorted = edge.sort
    same_edge_pair.each do |edge_pair|
      if edge_pair[0].sort == edge_sorted || edge_pair[1].sort == edge_sorted
        is_connecter_edge = true
        break
      end
    end
    return is_connecter_edge
  end
  private :connecter_edge?

  def insert_node(point_x, point_y)
    if @polygon.length < 3
      add_node(point_x, point_y)
      if @polygon.length == 3 && Triangle.ccw(@polygon[0], @polygon[1], @polygon[2]) > 0
        @polygon[1], @polygon[2] = @polygon[2], @polygon[1]
      end
      return
    end
    point = RVec2.new(point_x, point_y)

    edges = []
    @polygon.length.times do |i|
      edges << [i, (i + 1) % @polygon.length] # TODO : Remove duplicate edge
    end

    # Calculate distance from point to all edges.
    distances = Array.new(@polygon.length) { -Float::MAX }
    edges.each_with_index do |edge, i|
      distances[i] = SegmentIntersection.distance_from_point(point, @polygon[edge[0]], @polygon[edge[1]])
    end

    # Find nearest edge and insert new Node as a dividing point.
    insertion_index = -1

    same_edge_pair = [] # store connecter edges
    edges.each_with_index do |edge_a, idx_a|
      edges.each_with_index do |edge_b, idx_b|
        next if idx_a >= idx_b
        if (@polygon[edge_a[0]] == @polygon[edge_b[0]] && @polygon[edge_a[1]] == @polygon[edge_b[1]]) ||
           (@polygon[edge_a[0]] == @polygon[edge_b[1]] && @polygon[edge_a[1]] == @polygon[edge_b[0]])
          same_edge_pair << [edge_a, edge_b]
        end
      end
    end

    minimum_distances = distances.min_by(2) {|d| d}
    if (minimum_distances[0] - minimum_distances[1]).abs > 1.0e-6
      # Found one nearest edge.
      i = distances.find_index( minimum_distances[0] )
      nearest_edge = edges[i]

      is_connecter_edge = connecter_edge?(nearest_edge, same_edge_pair)

      if not is_connecter_edge
        # Normal edge
        self_intersect = SegmentIntersection.check(@polygon + [point], edges - [nearest_edge] + [[nearest_edge[0], @polygon.length], [@polygon.length, nearest_edge[1]]])
        if not self_intersect
          insertion_index = i
        end
      else
        # Connecter edge
        indices = []
        distances.each_with_index do |d, i|
          if d == minimum_distances[0]
            indices << i
          end
        end
        p "indices.length == #{indices.length}, != 2" if indices.length != 2
        nearest_edges = [edges[indices[0]], edges[indices[1]]]

        e0_ccw = Triangle.ccw(@polygon[nearest_edges[0][0]], point, @polygon[nearest_edges[0][1]]) > 0
        e1_ccw = Triangle.ccw(@polygon[nearest_edges[1][0]], point, @polygon[nearest_edges[1][1]]) > 0
        if e0_ccw
          insertion_index = indices[0]
        else # e1_ccw
          insertion_index = indices[1]
        end
      end
    else

      # If two or more nearest edges found...
      # TODO : implement
      #          for vertex voronoi case
      #          [DONE] for connecter edge case

      # Inside polygon connecter edge
      indices = []
      distances.each_with_index do |d, i|
        if (d - minimum_distances[0]).abs <= 1.0e-6
          indices << i
        end
      end
      p "indices.length != 2" if indices.length != 2
      nearest_edges = [edges[indices[0]], edges[indices[1]]]

      is_connecter_edge = false
      if (@polygon[nearest_edges[0][0]] == @polygon[nearest_edges[1][0]] && @polygon[nearest_edges[0][1]] == @polygon[nearest_edges[1][1]]) || (@polygon[nearest_edges[0][1]] == @polygon[nearest_edges[1][0]] && @polygon[nearest_edges[0][0]] == @polygon[nearest_edges[1][1]])
        is_connecter_edge = true
      end

      if not is_connecter_edge
        # the input point is placed in the vertex Voronoi region
        # p nearest_edges
      else
        # Divide one of the edges that never break the graph ordering (the one should make a counter-clockwise triangle with the input point)
        e0_ccw = Triangle.ccw(@polygon[nearest_edges[0][0]], point, @polygon[nearest_edges[0][1]]) > 0
        e1_ccw = Triangle.ccw(@polygon[nearest_edges[1][0]], point, @polygon[nearest_edges[1][1]]) > 0
        if e0_ccw
          insertion_index = indices[0]
        else # e1_ccw
          insertion_index = indices[1]
        end
      end
    end

    if insertion_index == -1
      # puts "fail"
      return
    end

    @nodes << RVec2.new(point_x, point_y)
    @polygon.insert( insertion_index + 1, @nodes.last )
#    @undo_insert_index = insertion_index + 1
  end

  def undo_insert
    if @undo_insert_index >= 0
      @nodes.delete_at(@undo_insert_index)
      @undo_insert_index = -1
      if $outer_graph.nodes.length <= 2
        $outer_graph.clear
      else
        $outer_graph.decompose($convex_decomposition_mode)
      end
    end
  end

  def node_removable?(node_index)
    #
    # TODO : Original implementation is for @node, not for @polygon. Fix it.
    #
    segment_indices = []
    new_edge_index = []

    node = @nodes[node_index]

    @polygon.length.times do |i|
      # TODO : Remove duplicate edge
      if @polygon[i] == node
        new_edge_index << (i + 1) % @polygon.length
        next
      end
      if @polygon[(i + 1) % @polygon.length] == node
        new_edge_index << i
        next
      end
      # p new_edge_index.length
      segment_indices << [i, (i + 1) % @polygon.length]
    end

    return SegmentIntersection.check(@polygon, segment_indices + [new_edge_index]) == false
  end

  def remove_nearest_node(point_x, point_y)
    return if @nodes.empty?
    distances = Array.new(@nodes.length) { -Float::MAX }
    @nodes.each_with_index do |node_current, index|
      distances[index] = (node_current.x - point_x)**2 + (node_current.y - point_y)**2
    end
    minimum_distance = distances.min_by {|d| d}
    if minimum_distance <= @node_radius ** 2
      nearest_node_index = distances.find_index( minimum_distance )
      @undo_insert_index = -1
      if node_removable?(nearest_node_index)
        @polygon.delete_if {|p| p == @nodes[nearest_node_index]}
        @nodes.delete_at(nearest_node_index)
      else
        puts "[WARN] remove_nearest_node : Failed. Removing the node #{nearest_node_index} will make self-intersecting polygon."
      end
    end
  end

  def decompose(convex_mode = true)
    return false if @nodes.length < 3
    indices = convex_mode ? ConvexPartitioning.decompose(@polygon) : ConvexPartitioning.triangulate(@polygon)
    @polygon_indices = indices == nil ? [] : indices
  end

  def clear
    @nodes.clear
    @polygon.clear
    @polygon_indices.clear if @polygon_indices != nil
  end

  def render(vg, render_edge: true, render_node: true, color_scheme: :outer)
    # Polygons
    if @polygon_indices.length > 0
      color = nvgRGBA(0,255,0, 255)
      lw = @node_radius * 0.5
      @polygon_indices.each do |indices|
        nvgLineCap(vg, NVG_ROUND)
        nvgLineJoin(vg, NVG_ROUND)
        nvgBeginPath(vg)
        indices.each_with_index do |index, i|
          if i == 0
            nvgMoveTo(vg, @polygon[index].x, @polygon[index].y)
          else
            nvgLineTo(vg, @polygon[index].x, @polygon[index].y)
          end
        end
        nvgClosePath(vg)
        color = nvgRGBA(0,255,0, 64)
        nvgFillColor(vg, color)
        nvgFill(vg)
        color = $convex_decomposition_mode ? nvgRGBA(255,255,0, 255) : nvgRGBA(255,128,0, 255)
        nvgStrokeColor(vg, color)
        nvgStrokeWidth(vg, lw)
        nvgStroke(vg)
      end
    end

    # Edges
    if render_edge and @nodes.length >= 2
      color = color_scheme == :outer ? nvgRGBA(0,0,255, 255) : nvgRGBA(255,0,0, 255)
      lw = @node_radius * 0.5
      nvgLineCap(vg, NVG_ROUND)
      nvgLineJoin(vg, NVG_ROUND)
      nvgBeginPath(vg)
      @polygon.length.times do |i|
        if i == 0
          nvgMoveTo(vg, @polygon[0].x, @polygon[0].y)
        else
          nvgLineTo(vg, @polygon[i].x, @polygon[i].y)
        end
      end
      nvgClosePath(vg)
      nvgStrokeColor(vg, color)
      nvgStrokeWidth(vg, lw)
      nvgStroke(vg)
    end

    # Nodes
    if render_node and @nodes.length > 0
      color = color_scheme == :outer ? nvgRGBA(0,192,255, 255) : nvgRGBA(255,192,0, 255)
      nvgBeginPath(vg)
      @nodes.each do |node|
        nvgCircle(vg, node.x, node.y, @node_radius)
        nvgFillColor(vg, color)
      end
      nvgFill(vg)
    end

  end
end

$font_plane = FontPlane.new

$convex_docomposition_mode = true
$outer_graph = Graph.new
$inner_graph = Graph.new
$current_graph = $outer_graph

key = GLFW::create_callback(:GLFWkeyfun) do |window, key, scancode, action, mods|
  if key == GLFW_KEY_ESCAPE && action == GLFW_PRESS # Press ESC to exit.
    glfwSetWindowShouldClose(window, GL_TRUE)
  elsif key == GLFW_KEY_SPACE && action == GLFW_PRESS
    $current_graph = $current_graph == $inner_graph ? $outer_graph : $inner_graph
  elsif key == GLFW_KEY_D && action == GLFW_PRESS # Press 'D' to switch convex decomposition mode.
    $convex_decomposition_mode = !$convex_decomposition_mode
    $outer_graph.decompose($convex_decomposition_mode)
  elsif key == GLFW_KEY_R && action == GLFW_PRESS # Press 'R' to clear graph.
    $current_graph.clear
  elsif key == GLFW_KEY_M && action == GLFW_PRESS # Press 'M' to merge inner polygon.
    if $outer_graph.polygon.length >= 3 && $inner_graph.polygon.length >= 3
      $outer_graph.polygon, appended_nodes = ConvexPartitioning.merge_inner_polygon($outer_graph.polygon, $inner_graph.polygon)
      $outer_graph.nodes.concat(appended_nodes)
      $outer_graph.decompose($convex_decomposition_mode)
    end
  elsif key == GLFW_KEY_Z && action == GLFW_PRESS && (mods & GLFW_MOD_CONTROL != 0) # Remove the last node your added by Ctrl-Z.
    $current_graph.undo_insert
  end
end

mouse = GLFW::create_callback(:GLFWmousebuttonfun) do |window_handle, button, action, mods|
  if button == GLFW_MOUSE_BUTTON_LEFT && action == 0
    mx_buf = ' ' * 8
    my_buf = ' ' * 8
    glfwGetCursorPos(window_handle, mx_buf, my_buf)
    mx = mx_buf.unpack('D')[0]
    my = my_buf.unpack('D')[0]
    if (mods & GLFW_MOD_SHIFT) != 0
      $current_graph.remove_nearest_node(mx, my)
      if $current_graph.nodes.length <= 2
        $current_graph.clear
      else
        $current_graph.decompose($convex_decomposition_mode)
      end
    else
      $current_graph.insert_node(mx, my)
      $current_graph.decompose($convex_decomposition_mode)
    end
  end
end


if __FILE__ == $0

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

  window = glfwCreateWindow( 1280, 720, "Hertel-Mehlhorn Algorithm", nil, nil )
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

  $font_plane.load(vg, "sans", "data/GenShinGothic-Normal.ttf")

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

    $outer_graph.render(vg, color_scheme: :outer)
    $inner_graph.render(vg, color_scheme: :inner)

    $font_plane.render(vg, winWidth - 1200, 10, 1150, 700, "[Edit Mode] #{$current_graph==$outer_graph ? 'Outer Polygon' : 'Inner Polygon'}", color: nvgRGBA(32,128,64,255))
    $font_plane.render(vg, winWidth - 1200, 60, 1150, 700, "[Decomposition] #{$convex_decomposition_mode ? 'Convex' : 'Triangle'}", color: nvgRGBA(32,128,64,255))

    nvgRestore(vg)
    nvgEndFrame(vg)

    glfwSwapBuffers( window )
    glfwPollEvents()

  end

  nvgDeleteGL3(vg)

  glfwTerminate()
end
