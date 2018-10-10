# CompGeom-Playground #

*   Created : 2015-09-08
*   Last modified : 2016-03-27

<img src="https://raw.githubusercontent.com/vaiorabbit/compgeom-playground/master/doc/test_clipping_rb.png" width="150"> <img src="https://raw.githubusercontent.com/vaiorabbit/compgeom-playground/master/doc/test_convex_decomposition_rb_0.png" width="150"> <img src="https://raw.githubusercontent.com/vaiorabbit/compgeom-playground/master/doc/test_convex_decomposition_rb_1.png" width="150"> <img src="https://raw.githubusercontent.com/vaiorabbit/compgeom-playground/master/doc/test_hole_polygon_rb_0.png" width="150">

<img src="https://raw.githubusercontent.com/vaiorabbit/compgeom-playground/master/doc/test_hole_polygon_rb_1.png" width="150"> <img src="https://raw.githubusercontent.com/vaiorabbit/compgeom-playground/master/doc/test_linear_program_rb.png" width="150"> <img src="https://raw.githubusercontent.com/vaiorabbit/compgeom-playground/master/doc/test_triangulation_rb.png" width="150"> <img src="https://raw.githubusercontent.com/vaiorabbit/compgeom-playground/master/doc/test_voronoi_rb.png" width="150">


## Prerequisites ##

*   GLFW DLL
    *   https://www.glfw.org (Windows)
    *   $ brew install glfw3 (macOS)

*   Ruby-FFI https://github.com/ffi/ffi
	*   nanovg.rb depends on it.
	*   run 'gem install ffi'

*   opengl-bindings https://github.com/vaiorabbit/ruby-opengl
	*   Provides glfw.rb, a ruby bindings of GLFW.
	*   run 'gem install opengl-bindings'

*   nanovg-bindings https://github.com/vaiorabbit/nanovg-bindings
	*   Provides nanovg.rb, a ruby bindings of NanoVG.

*   rmath3d https://github.com/vaiorabbit/rmath3d
	*   run 'gem install rmath3d_plain'

## How to run ##

1.  Put glfw3.dll (Windows) / libglfw.dylib (macOS) here
    *   or specify path to the GLFW DLL as the argument of 'GLFW.load_lib()'. See perfume_dance.rb
        *   ex.) GLFW.load_lib('libglfw3.dylib', '/usr/local/lib')  (macOS)
2.  $ ruby test_voronoi.rb, etc.

## Operation ##

*   Common
    *   Esc     : Quit
    *   R       : Reset
    *   Mouse L : Put new polygon vertex

*   test_clipping.rb
    *   Space   : Switch editing polygon between outer(blue) and inner(red)
    *   C       : Execute clipping
    *   Ctrl+Z  : Undo polygon vertex addition

*   test_convex_decomposition.rb
    *   Space   : Switch editing polygon between outer(blue) and inner(red)
    *   D       : Execute decomposition
    *   M       : Merge inner polygon
    *   Ctrl+Z  : Undo polygon vertex addition

*   test_hole_polygon.rb
    *   Space   : Switch editing polygon between outer(blue) and inner(red)
    *   M       : Merge inner polygon
    *   Ctrl+Z  : Undo polygon vertex addition

*   test_triangulation.rb
    *   Space   : Switch editing polygon between outer(blue) and inner(red)
    *   T       : Execute triangulation
    *   Ctrl+Z  : Undo polygon vertex addition

### Copyright Notice ###

	CompGeom-Playground
	Copyright (c) 2015-2018 vaiorabbit
	
	This software is provided 'as-is', without any express or implied
	warranty. In no event will the authors be held liable for any damages
	arising from the use of this software.
	
	Permission is granted to anyone to use this software for any purpose,
	including commercial applications, and to alter it and redistribute it
	freely, subject to the following restrictions:
	
	    1. The origin of this software must not be misrepresented; you must not
	    claim that you wrote the original software. If you use this software
	    in a product, an acknowledgment in the product documentation would be
	    appreciated but is not required.
	
	    2. Altered source versions must be plainly marked as such, and must not be
	    misrepresented as being the original software.
	
	    3. This notice may not be removed or altered from any source
	    distribution.


#### 3rd Party Modules ####

*   See data/README_GenShin.txt for the license of 'data/GenShinGothic-Normal.ttf'.
