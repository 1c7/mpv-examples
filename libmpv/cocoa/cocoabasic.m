// Plays a video from the command line in a view provided by the client
// application.

// Build with: clang -o cocoabasic cocoabasic.m `pkg-config --libs --cflags mpv` -framework cocoa
// 2020年10月25号在 macOS 上编译成功，得到一个同名无后缀文件
// 这条编译命令还有一部分不懂，需要学一下

// 运行: ./cocoabasic test.mkv 
// 可以正常播放，完全没有问题
// 缺点是 OC 挺烦的

// 这个看起来就是 window embedding，没啥值得学习的

#include <mpv/client.h>
// 这个引入咋整的?

#include <stdio.h>
#include <stdlib.h>

static inline void check_error(int status)
{
    if (status < 0) {
        printf("mpv API error: %s\n", mpv_error_string(status));
        exit(1);
    }
}

#import <Cocoa/Cocoa.h>

@interface CocoaWindow : NSWindow
@end

@implementation CocoaWindow
- (BOOL)canBecomeMainWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return YES; }
@end
// 这里好像就是马上定义了一个 interface + 实现

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    mpv_handle *mpv; // 这个简单，就是 mpv 指针
    dispatch_queue_t queue; // 不清楚为什么要用 queue
    NSWindow *w; // 窗口 
    NSView *wrapper; // view wrapper
}
@end

static void wakeup(void *);

// 实现 AppDelegate
@implementation AppDelegate

// 这个好像就是纯粹的创建窗口，没有别的
- (void)createWindow {

    int mask = NSTitledWindowMask|NSClosableWindowMask|
               NSMiniaturizableWindowMask|NSResizableWindowMask;

    self->w = [[CocoaWindow alloc]
        initWithContentRect:NSMakeRect(0,0, 1280, 720)
                  styleMask:mask
                    backing:NSBackingStoreBuffered
                      defer:NO];
                    // 窗口大小

    [self->w setTitle:@"cocoabasic example"]; // 标题
    [self->w makeMainWindow]; // 主窗口
    [self->w makeKeyAndOrderFront:nil]; // 放到前面

    NSRect frame = [[self->w contentView] bounds];
    self->wrapper = [[NSView alloc] initWithFrame:frame];
    [self->wrapper setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [[self->w contentView] addSubview:self->wrapper];
    [self->wrapper release];

    // 菜单
    NSMenu *m = [[NSMenu alloc] initWithTitle:@"AMainMenu"];
    NSMenuItem *item = [m addItemWithTitle:@"Apple" action:nil keyEquivalent:@""];
    NSMenu *sm = [[NSMenu alloc] initWithTitle:@"Apple"];
    [m setSubmenu:sm forItem:item];
    [sm addItemWithTitle: @"mpv_command('stop')" action:@selector(mpv_stop) keyEquivalent:@""];
    [sm addItemWithTitle: @"mpv_command('quit')" action:@selector(mpv_quit) keyEquivalent:@""];
    [sm addItemWithTitle: @"quit" action:@selector(terminate:) keyEquivalent:@"q"];
    [NSApp setMenu:m];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    atexit_b(^{
        // Because activation policy has just been set to behave like a real
        // application, that policy must be reset on exit to prevent, among
        // other things, the menubar created here from remaining on screen.
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    });

    // Read filename
    // 读取命令行文件名
    NSArray *args = [NSProcessInfo processInfo].arguments;
    if (args.count < 2) {
        NSLog(@"Expected filename on command line");
        exit(1);
    }
    NSString *filename = args[1];

    [self createWindow];
    // 创建窗口

    // Deal with MPV in the background.
    queue = dispatch_queue_create("mpv", DISPATCH_QUEUE_SERIAL);
    // 这是创建队列？为啥说在后台和 mpv 交互
    dispatch_async(queue, ^{

        mpv = mpv_create();
        if (!mpv) {
            printf("failed creating context\n");
            exit(1);
        }
        // 直接创建 mpv 并且保存 handle

        int64_t wid = (intptr_t) self->wrapper;
        // 这是拿到 window id？
        check_error(mpv_set_option(mpv, "wid", MPV_FORMAT_INT64, &wid));
        // 似乎这就是一个 window embedding 的操作

        // Maybe set some options here, like default key bindings.
        // NOTE: Interaction with the window seems to be broken for now.
        check_error(mpv_set_option_string(mpv, "input-default-bindings", "yes"));

        // for testing!
        check_error(mpv_set_option_string(mpv, "input-media-keys", "yes"));
        check_error(mpv_set_option_string(mpv, "input-cursor", "no"));
        check_error(mpv_set_option_string(mpv, "input-vo-keyboard", "yes"));

        // request important errors
        check_error(mpv_request_log_messages(mpv, "warn"));

        // 上面设置了一些选项，这里初始化
        check_error(mpv_initialize(mpv));

        // Register to be woken up whenever mpv generates new events.
        mpv_set_wakeup_callback(mpv, wakeup, (__bridge void *) self);

        // Load the indicated file
        // 载入文件
        const char *cmd[] = {"loadfile", filename.UTF8String, NULL};
        check_error(mpv_command(mpv, cmd));
    });
}

// 处理事件
- (void) handleEvent:(mpv_event *)event
{
    // 如果是关闭事件，直接退出
    switch (event->event_id) {
    case MPV_EVENT_SHUTDOWN: {
        mpv_detach_destroy(mpv);
        mpv = NULL;
        printf("event: shutdown\n");
        break;
    }

    // 其他几个事件的处理
    case MPV_EVENT_LOG_MESSAGE: {
        struct mpv_event_log_message *msg = (struct mpv_event_log_message *)event->data;
        printf("[%s] %s: %s", msg->prefix, msg->level, msg->text);
    }

    case MPV_EVENT_VIDEO_RECONFIG: {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray *subviews = [self->wrapper subviews];
            if ([subviews count] > 0) {
                // mpv's events view
                NSView *eview = [self->wrapper subviews][0];
                [self->w makeFirstResponder:eview];
            }
        });
    }

    default:
        printf("event: %s\n", mpv_event_name(event->event_id));
    }
}

// 这是干嘛？event loop？
- (void) readEvents
{
    dispatch_async(queue, ^{
        while (mpv) {
            mpv_event *event = mpv_wait_event(mpv, 0);
            if (event->event_id == MPV_EVENT_NONE)
                break;
            [self handleEvent:event];
        }
    });
}

static void wakeup(void *context) {
    AppDelegate *a = (__bridge AppDelegate *) context;
    [a readEvents];
}

// Ostensibly, mpv's window would be hooked up to this.
- (BOOL) windowShouldClose:(id)sender
{
    return NO;
}

// 这2个和菜单项相关
- (void) mpv_stop
{
    if (mpv) {
        const char *args[] = {"stop", NULL};
        mpv_command(mpv, args);
    }
}

- (void) mpv_quit
{
    if (mpv) {
        const char *args[] = {"quit", NULL};
        mpv_command(mpv, args);
    }
}
@end

// Delete this if you already have a main.m.
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [AppDelegate new];
        app.delegate = delegate;
        [app run];
        // 看起来是，弄了个 application, 弄了个 delegate
        // 让 application.delegate 设置一下
        // run
    }
    return 0;
}
