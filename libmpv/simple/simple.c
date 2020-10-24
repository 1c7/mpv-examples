// Build with: gcc -o simple simple.c `pkg-config --libs --cflags mpv`
// 2020年10月25号，实测 macOS 下可以编译，在当前目录下运行这个命令即可
// 只是没理解 `pkg-config --libs --cflags mpv` 是什么

// 运行：./simple test.mkv
// 什么也没发生，我去开了 Github issue 问问题去了

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

#include <mpv/client.h>

// 检查错误
static inline void check_error(int status)
{
    if (status < 0) {
        printf("mpv API error: %s\n", mpv_error_string(status));
        exit(1);
    }
}

int main(int argc, char *argv[])
{
    // 如果参数不足就提示并退出
    if (argc != 2) {
        printf("pass a single media file as argument\n");
        return 1;
    }

    // 创建 context
    mpv_handle *ctx = mpv_create();
    if (!ctx) {
        printf("failed creating context\n");
        return 1;
    }

    // Enable default key bindings, so the user can actually interact with
    // the player (and e.g. close the window).
    check_error(mpv_set_option_string(ctx, "input-default-bindings", "yes"));
    mpv_set_option_string(ctx, "input-vo-keyboard", "yes");
    // 调用 set_option，看来是定义了一些 option

    // int val = 1;
    // check_error(mpv_set_option(ctx, "osc", MPV_FORMAT_FLAG, &val));
    // 这个 osc 是在设置什么？

    // Done setting up options.
    check_error(mpv_initialize(ctx));
    // 设置 option 完了所以旧初始化？

    // Play this file.
    const char *cmd[] = {"loadfile", argv[1], NULL};
    // 这个定义第一次见，这是什么写法？

    check_error(mpv_command(ctx, cmd));
    printf("运行到这里了\n");

    // Let it play, and wait until the user quits.
    while (1) {
        mpv_event *event = mpv_wait_event(ctx, 10000);
        printf("event: %s\n", mpv_event_name(event->event_id));
        if (event->event_id == MPV_EVENT_SHUTDOWN)
            break;
    }
    // 这个 while(1) 应该是让程序不要退出，然后持续等待 event 并处理

    mpv_terminate_destroy(ctx);
    return 0;
}
