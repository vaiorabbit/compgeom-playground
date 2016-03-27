# coding: utf-8
# Usage:
# $ gem install rmath3d_plain
# $ ruby test_hole_polygon.rb
require 'pp'
require 'opengl'
require 'glfw'
require 'rmath3d/rmath3d_plain'
require_relative 'nanovg'
require_relative 'compgeom/linear_program'


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


$font_plane = FontPlane.new


key = GLFW::create_callback(:GLFWkeyfun) do |window, key, scancode, action, mods|
  if key == GLFW_KEY_ESCAPE && action == GLFW_PRESS # Press ESC to exit.
    glfwSetWindowShouldClose(window, GL_TRUE)
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
    else
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
  # glfwWindowHint(GLFW_DECORATED, 0)

  window = glfwCreateWindow( 1280, 720, "2D Bounded Linear Programming", nil, nil )
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

  lines = [
    # A
    LinearProgram::Line2D.new(RVec2.new(4, 3), RVec2.new(1, 0)),
    LinearProgram::Line2D.new(RVec2.new(1, 0), RVec2.new(5,-1)),
    LinearProgram::Line2D.new(RVec2.new(5,-1), RVec2.new(4, 3)),
    # B
    LinearProgram::Line2D.new(RVec2.new(0, 0), RVec2.new(4, 1)),
    LinearProgram::Line2D.new(RVec2.new(4, 1), RVec2.new(1, 4)),
    LinearProgram::Line2D.new(RVec2.new(1, 4), RVec2.new(0, 0)),
  ]

  glfwSwapInterval(0)
  glfwSetTime(0)

  total_time = 0.0

  prevt = glfwGetTime()

  while glfwWindowShouldClose( window ) == 0

    t = glfwGetTime()
    dt = t - prevt # 1.0 / 60.0
    prevt = t
    total_time += dt

    objective = RVec2.new(Math.cos(total_time), Math.sin(total_time))
    optimal = LinearProgram.solve2DBoundedLP(lines, objective)

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

    offset_x = 300.0
    offset_y = 300.0
    scale = 100.0
    line_half_length = 100.0
    lines.each do |line|
      p0 = line.position + line_half_length * line.direction
      p1 = line.position - line_half_length * line.direction

      dir_left = RVec2.new(line.direction.y, -line.direction.x)

      p0_render_x = scale * p0.x + offset_x
      p0_render_y = 200 - scale * p0.y + offset_y
      p1_render_x = scale * p1.x + offset_x
      p1_render_y = 200 - scale * p1.y + offset_y

      nvgLineCap(vg, NVG_ROUND)
      nvgLineJoin(vg, NVG_ROUND)
      nvgBeginPath(vg)
      nvgMoveTo(vg, p0_render_x, p0_render_y)
      nvgLineTo(vg, p1_render_x, p1_render_y)
      nvgClosePath(vg)
      color = nvgRGBA(255,128,0, 255)
      nvgStrokeColor(vg, color)
#      nvgStrokeWidth(vg, lw)
      nvgStroke(vg)
    end

    nvgSave(vg)
    nvgTranslate(vg, scale * optimal.x + offset_x, 200 - scale * optimal.y + offset_y)
    nvgBeginPath(vg)
    nvgFillColor(vg, nvgRGBA(255,255,255, 255))
    nvgRect(vg, -5, -5, 10, 10)
    nvgFill(vg)
    nvgClosePath(vg)
    nvgRestore(vg)

    $font_plane.render(vg, winWidth - 1200, 10, 1150, 700, "[Objective] (#{objective.x}, #{objective.y})", color: nvgRGBA(32,128,64,255))
    $font_plane.render(vg, winWidth - 1200, 60, 1150, 700, "[Optimal] (#{optimal.x}, #{optimal.y})", color: nvgRGBA(32,128,64,255))

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
