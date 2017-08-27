# coding: utf-8
# Usage:
# $ gem install rmath3d_plain
# $ ruby test_hole_polygon.rb
require 'pp'
require 'opengl'
require 'glfw'
require 'rmath3d/rmath3d_plain'
require_relative 'nanovg'
require_relative 'compgeom/convex_partitioning'
require_relative 'compgeom/intersection'
require_relative 'compgeom/clipping'


OpenGL.load_lib()
GLFW.load_lib()
NanoVG.load_dll('libnanovg_gl3.dylib', render_backend: :gl3)

include OpenGL
include GLFW
include NanoVG
include RMath3D

# Saves as .tga
$ss_name = "ss0000.tga"
$ss_id = 0
def save_screenshot(w, h, name)
  image = FFI::MemoryPointer.new(:uint8, w*h*4)
  return if image == nil

  glReadPixels(0, 0, w, h, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, image)

  File.open( name, 'wb' ) do |fout|
    fout.write [0].pack('c')      # identsize
    fout.write [0].pack('c')      # colourmaptype
    fout.write [2].pack('c')      # imagetype
    fout.write [0].pack('s')      # colourmapstart
    fout.write [0].pack('s')      # colourmaplength
    fout.write [0].pack('c')      # colourmapbits
    fout.write [0].pack('s')      # xstart
    fout.write [0].pack('s')      # ystart
    fout.write [w].pack('s')      # image_width
    fout.write [h].pack('s')      # image_height
    fout.write [8 * 4].pack('c')  # image_bits_per_pixel
    fout.write [8].pack('c')      # descriptor

    fout.write image.get_bytes(0, w*h*4)
  end
end

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
  attr_accessor :nodes, :triangle_indices, :polygon

  def initialize(edge_color = nil, node_color = nil)
    @nodes = []
    @polygon = []

    @undo_insert_index = -1
    @node_radius = 10.0

    @triangle_indices = []
    @hull_indices = []

    @edge_color = edge_color != nil ? edge_color : nvgRGBA(255, 255, 255, 255)
    @node_color = node_color != nil ? node_color : nvgRGBA(255, 255, 255, 255)
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
      distances[i] = Distance.point_segment(point, @polygon[edge[0]], @polygon[edge[1]])
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
  end

  def undo_insert
    if @undo_insert_index >= 0
      @nodes.delete_at(@undo_insert_index)
      @undo_insert_index = -1
      if $subj_graph.nodes.length <= 2
        $subj_graph.clear
      else
        $subj_graph.triangulate
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

  def triangulate
    return false if @nodes.length < 3
    indices = ConvexPartitioning.triangulate(@polygon)
    @triangle_indices = indices == nil ? [] : indices
  end

  def clear
    @nodes.clear
    @polygon.clear
    @triangle_indices.clear if @triangle_indices != nil
  end

  def render(vg, render_edge: true, render_node: true)
    # Triangles
    if @triangle_indices.length > 0
      lw = @node_radius * 0.5
      @triangle_indices.each do |indices|
        nvgLineCap(vg, NVG_ROUND)
        nvgLineJoin(vg, NVG_ROUND)
        nvgBeginPath(vg)
        nvgMoveTo(vg, @polygon[indices[0]].x, @polygon[indices[0]].y)
        nvgLineTo(vg, @polygon[indices[1]].x, @polygon[indices[1]].y)
        nvgLineTo(vg, @polygon[indices[2]].x, @polygon[indices[2]].y)
        nvgClosePath(vg)
        color = nvgRGBA(0,255,0, 64)
        nvgFillColor(vg, color)
        nvgFill(vg)
        # Edge of each triangles.
        # color = nvgRGBA(255,128,0, 255)
        # nvgStrokeColor(vg, color)
        # nvgStrokeWidth(vg, lw)
        # nvgStroke(vg)
      end
    end

    # Edges
    if render_edge and @nodes.length >= 2
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
      nvgStrokeColor(vg, @edge_color)
      nvgStrokeWidth(vg, lw)
      nvgStroke(vg)
    end

    # Nodes
    if render_node and @nodes.length > 0
      nvgBeginPath(vg)
      @nodes.each do |node|
        nvgCircle(vg, node.x, node.y, @node_radius)
        nvgFillColor(vg, @node_color)
      end
      nvgFill(vg)
    end

  end
end

$font_plane = FontPlane.new

$subj_graph = Graph.new(nvgRGBA(0,0,255, 255), nvgRGBA(0,192,255, 255))
$clip_graph = Graph.new(nvgRGBA(255,0,0, 255), nvgRGBA(255,0,192, 255))
$current_graph = $subj_graph

$new_graphs = []

key = GLFW::create_callback(:GLFWkeyfun) do |window, key, scancode, action, mods|
  if key == GLFW_KEY_ESCAPE && action == GLFW_PRESS # Press ESC to exit.
    glfwSetWindowShouldClose(window, GL_TRUE)
  elsif key == GLFW_KEY_SPACE && action == GLFW_PRESS
    $current_graph = $current_graph == $clip_graph ? $subj_graph : $clip_graph
  elsif key == GLFW_KEY_R && action == GLFW_PRESS # Press 'R' to clear graph.
    $current_graph.clear
  elsif key == GLFW_KEY_M && action == GLFW_PRESS # Press 'M' to change clipping mode.
    # if $subj_graph.polygon.length >= 3 && $clip_graph.polygon.length >= 3
    #   $subj_graph.polygon, appended_nodes = ConvexPartitioning.merge_inner_polygon($subj_graph.polygon, $clip_graph.polygon)
    #   $subj_graph.nodes.concat(appended_nodes)
    #   $subj_graph.triangulate
    # end
  elsif key == GLFW_KEY_C && action == GLFW_PRESS # Press 'C' to execute clipping.
    polygons = Clipping.clip($subj_graph.polygon, $clip_graph.polygon)
    unless polygons.empty?
      $new_graphs.clear
      polygons.each do |polygon|
        g = Graph.new(nvgRGBA(255,255,0, 255), nvgRGBA(0,255,0, 255))
        polygon.each do |pos|
          g.add_node(pos.x, pos.y)
        end
        g.triangulate
        $new_graphs << g
      end
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
        $current_graph.triangulate
      end
    else
      $current_graph.insert_node(mx, my)
      $current_graph.triangulate
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

  window = glfwCreateWindow( 1280, 720, "Merge inner polygon", nil, nil )
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

  winWidth_buf  = ' ' * 8
  winHeight_buf = ' ' * 8
  fbWidth_buf  = ' ' * 8
  fbHeight_buf = ' ' * 8

  $font_plane.load(vg, "sans", "data/GenShinGothic-Normal.ttf")

  glfwSwapInterval(0)
  glfwSetTime(0)

  total_time = 0.0

  prevt = glfwGetTime()

  # Ref.: http://www.explore-hokkaido.com/assets/svg/hokkaido-map.svg
  hokkaido = [
    RVec2.new(31.66,226.29),
    RVec2.new(31.56,215.25),
    RVec2.new(28.15,207.94),
    RVec2.new(23.25,206.53),
    RVec2.new(21.67,201.39),
    RVec2.new(17.76,200.06),
    RVec2.new(16.18,194.91),
    RVec2.new(20.83,187.27),
    RVec2.new(19.74,176.14),
    RVec2.new(21.98,173.32),
    RVec2.new(31.11,172.06),
    RVec2.new(37.83,163.59),
    RVec2.new(40.49,167.82),
    RVec2.new(42.57,166.99),
    RVec2.new(47.29,158.35),
    RVec2.new(53.69,153.86),
    RVec2.new(44.87,139.08),
    RVec2.new(46.44,132.19),
    RVec2.new(53.58,130.77),
    RVec2.new(65.72,141.81),
    RVec2.new(76.93,139.72),
    RVec2.new(76.68,142.71),
    RVec2.new(83.41,146.28),
    RVec2.new(88.64,143.7),
    RVec2.new(95.36,135.22),
    RVec2.new(91.43,109.81),
    RVec2.new(94.83,105.08),
    RVec2.new(102.06,102.66),
    RVec2.new(106.54,97.01),
    RVec2.new(107.43,74.01),
    RVec2.new(112.08,66.36),
    RVec2.new(113.89,56.48),
    RVec2.new(112.38,38.29),
    RVec2.new(105.97,18.7),
    RVec2.new(109.7,9.98),
    RVec2.new(109.2,3.91),
    RVec2.new(110.95,7.07),
    RVec2.new(116.01,6.48),
    RVec2.new(122.57,0),
    RVec2.new(146.26,29.05),
    RVec2.new(153.16,42.66),
    RVec2.new(167.71,60.92),
    RVec2.new(195.05,82.24),
    RVec2.new(223.54,89.61),
    RVec2.new(224.21,93.67),
    RVec2.new(228.78,99.07),
    RVec2.new(247.72,100.63),
    RVec2.new(271.86,75.53),
    RVec2.new(273.44,80.68),
    RVec2.new(261.59,102.78),
    RVec2.new(260.77,112.74),
    RVec2.new(263.26,118.97),
    RVec2.new(272.98,122.78),
    RVec2.new(270.82,124.61),
    RVec2.new(272.07,121.7),
    RVec2.new(266.09,121.21),
    RVec2.new(270.08,133.58),
    RVec2.new(275.49,141.05),
    RVec2.new(279.39,142.38),
    RVec2.new(287.03,134.98),
    RVec2.new(294.09,134.56),
    RVec2.new(283.46,141.71),
    RVec2.new(280.89,148.52),
    RVec2.new(263.7,150.11),
    RVec2.new(261.22,155.93),
    RVec2.new(256.82,160.58),
    RVec2.new(251.84,160.17),
    RVec2.new(250.01,158.01),
    RVec2.new(251.17,156.1),
    RVec2.new(248.26,154.86),
    RVec2.new(244.78,160.59),
    RVec2.new(247.6,162.83),
    RVec2.new(232.57,162.59),
    RVec2.new(224.85,158.95),
    RVec2.new(209.24,165.69),
    RVec2.new(193.97,180.48),
    RVec2.new(183.85,193.69),
    RVec2.new(180.12,202.42),
    RVec2.new(179.88,217.45),
    RVec2.new(177.23,225.26),
    RVec2.new(164.19,213.14),
    RVec2.new(142,202.28),
    RVec2.new(115.5,183.04),
    RVec2.new(102.7,179.98),
    RVec2.new(105.94,177.23),
    RVec2.new(90.33,183.97),
    RVec2.new(73.07,198.6),
    RVec2.new(70.33,195.37),
    RVec2.new(74.31,195.69),
    RVec2.new(69.41,194.29),
    RVec2.new(67.91,188.14),
    RVec2.new(60.6,179.51),
    RVec2.new(49.55,179.6),
    RVec2.new(43.99,186.17),
    RVec2.new(40.18,195.89),
    RVec2.new(40.85,199.96),
    RVec2.new(52.15,208.92),
    RVec2.new(62.12,209.74),
    RVec2.new(70.1,222.44),
    RVec2.new(78.83,226.17),
    RVec2.new(80.57,229.32),
    RVec2.new(74.18,233.81),
    RVec2.new(70.03,235.48),
    RVec2.new(61.39,230.75),
    RVec2.new(58.23,232.5),
    RVec2.new(58.56,228.51),
    RVec2.new(55.66,227.27),
    RVec2.new(53.25,232.09),
    RVec2.new(45.95,235.5),
    RVec2.new(45.21,244.47),
    RVec2.new(36.91,247.79),
    RVec2.new(33.5,252.53),
    RVec2.new(26.77,248.97),
    RVec2.new(24.28,242.74),
    RVec2.new(26.02,233.85),
    RVec2.new(31.66,226.29),
  ]
  ofs_x = 1280 / 2 - 360
  ofs_y = 720 / 2 - 340
  scl = 2.7
  hokkaido.each do |pos|
    $subj_graph.add_node(scl * pos.x + ofs_x, scl * pos.y + ofs_y)
  end
  $subj_graph.triangulate

  # Ref.: https://www.bang-guru.com/assets/img_v5/base/ico_score_on.svg
  star = [
    RVec2.new(0,15),
    RVec2.new(4.1,3.5),
    RVec2.new(15,3.5),
    RVec2.new(6.1,-3.2),
    RVec2.new(9.3,-15),
    RVec2.new(0,-7.9),
    RVec2.new(-9.3,-15),
    RVec2.new(-6.1,-3.2),
    RVec2.new(-15,3.5),
    RVec2.new(-4.1,3.5),
  ]
  ofs_x = 1280 / 2 - 100
  ofs_y = 720 / 2 + 60
  scl = 14
  star.reverse.each do |pos|
    $clip_graph.add_node(scl * pos.x + ofs_x, -scl * pos.y + ofs_y)
  end
  $clip_graph.triangulate
  

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

    $subj_graph.render(vg)
    $clip_graph.render(vg)

    $new_graphs.each do |graph|
      graph.render(vg)
    end

    $font_plane.render(vg, winWidth - 1200, 10, 1150, 700, "[MODE] #{$current_graph==$subj_graph ? 'Making Subject Polygon' : 'Making Clip Polygon'}", color: nvgRGBA(32,128,64,255))
    $font_plane.render(vg, winWidth - 1200, 60, 1150, 700, "[CLIP] #{$new_graphs.length > 0 ? 'Done' : 'Not Yet'}", color: nvgRGBA(32,128,64,255))

    nvgRestore(vg)
    nvgEndFrame(vg)

    glfwSwapBuffers( window )
    glfwPollEvents()

=begin
    if total_time > 0.01
      $ss_name = sprintf("ss%05d.tga", $ss_id)
      save_screenshot(fbWidth, fbHeight, $ss_name)
      $ss_id += 1
    end
=end
  end

  nvgDeleteGL3(vg)

  glfwTerminate()
end
