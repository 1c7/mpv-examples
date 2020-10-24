# Client API examples

All these examples use the mpv client API through libmpv.
所有这些例子都是用 libmpv 来使用 mpv 的客户端 API

## Where are the docs?

The libmpv C API is documented directly in the header files. (On normal Unix
systems, this is in `/usr/include/mpv/client.h`.)

libmpv merely gives you access to mpv's command interface, which is documented
here:
* Commands (`mpv_command()` and friends): http://mpv.io/manual/master/#list-of-input-commands
* Properties (`mpv_set_property()` and friends): http://mpv.io/manual/master/#properties
* Options (`mpv_set_property()` and friends, `mpv_set_option()` in obscure cases): http://mpv.io/manual/master/#options

Essentially everything is done with them, including loading a file, retrieving
playback progress, and so on.

## Methods of embedding the video window

All of these examples concentrate on how to integrate mpv's video renderers
with your own GUI. This is generally the hardest part. libmpv enforces a
somewhat efficient video output method, rather than e.g. returning a RGBA
surface in memory for each frame. The latter would be prohibitively inefficient,
because it would require conversion on the CPU. The goal is also not requiring
the API users to reinvent their own video rendering/scaling/presentation
mechanisms.

所有这些例子的重点，都是怎么整合 mpv 的视频渲染到你的 GUI 里头，
一般来说这是最难的部分。
（省略后面一部分）

There are currently 2 methods of embedding video.

### Native window embedding 窗口嵌套
简而言之，这个方法不好。macOS 上有问题

This uses the platform's native method of nesting multiple windows. For example,
Linux/X11 can nest a window from a completely different process. The nested
window can redraw contents on its own, and receive user input if the user
interacts with this window.

libmpv lets you specify a parent window for its own video window via the `wid`
option. Then libmpv will create its window with your window as parent, and
render its video inside of it.

This method is highly OS-dependent. Some behavior is OS-specific. There are
problems with focusing on X11 (the ancient X11 focus policy mismatches with
that of modern UI toolkits - it's normally worked around, but this is not
easily possible with raw window embedding). It seems to have stability problems
on OSX when using the Qt toolkit.

Both on X11 and win32, the player will fill the window referenced by the "wid"
option fully and letterbox the video (i.e. add black bars if the aspect ratio of
the window and the video mismatch).

Setting the `input-vo-keyboard` option may be required to get keyboard input
through the embedded window, if this is desired.

### Render API

This method lets you use libmpv's OpenGL renderer directly. You create an
OpenGL context, and then use `mpv_render_context_render()` to render the video
on each frame. (This can be OpenGL emulation as well, such as with ANGLE.)

这个方法是直接用 libmpv 的 OpenGL  渲染器。
创建一个 OpenGL context, 然后调用 `mpv_render_context_render()` 来渲染视频

This is more complicated, because libmpv will work directly on your own OpenGL
state. It's also not possible to have mpv automatically receive user input.
You will have to simulate this with the `mouse`/`keypress`/`keydown`/`keyup`
commands.

这个复杂一些，因为 libmpv 会直接在你的  OpenGL 状态上工作。
也不可能直接接收用户输入，你需要自己模拟。

You also get much more flexibility. For example, you can actually render your
own OSD on top of the video, something that is not possible with raw window
embedding.

这样灵活度更高，比如你可以自己在视频上方渲染 OSD

### Deprecated opengl-cb API

An older variant of the render API is called opengl-cb (in `libmpv/opengl_cb.h`).
It is almost equivalent, but is hardcoded to OpenGL and has some other
disadvantages. It is deprecated, and you should use `libmpv/render.h` instead.

The old API does not work anymore (as of mpv 0.33.0), and was deactivated.

### Which one to use?

Due to the various platform-specific behavior and problems (in particular on
OSX), using the render API is currently recommended over window embedding. In
some cases, window embedding can be preferable, because it is simpler and has
no disadvantages for the specific use case.

建议用 render API，而不是 window embedding   

If you're not comfortable with the higher complexity and requirements on the
GPU, or window embedding happens to work fine for your use case, or you want
to support "direct" video output such as vdpau (which might win when it comes
to performance and energy-saving), you should probably support both methods
if possible.

## List of examples

### simple

Very primitive terminal-only example. Shows some most basic API usage.
非常基础的命令行例子，演示最基本的 API 使用

### cocoa

Shows how to embed the mpv video window in Objective-C/Cocoa.
演示 Objective-C/Cocoa 里面怎么嵌入 mpv 视频窗口

### cocoa-openglcb

Similar to the cocoa sample, but shows how to integrate mpv's OpenGL renderer
using libmpv's opengl-cb API. Since it does not require complicated interaction
with Cocoa elements from different libraries, it's more robust.

### csharp

Shows how to use libmpv from C# on Windows. Uses Platform Invoke to call into
mpv-1.dll directly and uses native window embedding to show the video in a
Windows Forms control.

### qt

Shows how to embed the mpv video window in Qt (using normal desktop widgets).

### qt_opengl

Shows how to use mpv's OpenGL video renderer in Qt. This uses the opengl-cb API
for video. Since it does not rely on embedding "foreign" native Windows, it's
usually more robust, potentially faster, and it's easier to control how your
GUI interacts with the video. You can do your own OpenGL rendering on top of
the video as well.

### qml

Shows how to use mpv's OpenGL video renderer in QtQuick2 with QML. Uses the
opengl-cb API for video. Since the video is a normal QML element, it's trivial
to create OSD overlays with QML-native graphical elements as well.

### qml_direct

Alternative example, which typically avoids a FBO indirection. Might be
slightly faster, but is less flexible and harder to use. In particular, the
video is not a normal QML element. Uses the opengl-cb API for video.

### sdl

Show how to embed the mpv OpenGL renderer in SDL. Uses the render API for video.
In addition, main_sw demonstrates the render API software renderer.

演示怎么把 mpv 的 OpenGL 渲染器弄到 SDL 里面

### streamcb

Demonstrates use of the custom stream API.

### wxwidgets

Shows how to embed the mpv video window in wxWidgets frame.

### wxwidgets_opengl

Similar to wxwidgets sample, but shows how to use mpv's OpenGL video renderer
using libmpv's opengl-cb API in wxWidgets frame via wxGLCanvas.
