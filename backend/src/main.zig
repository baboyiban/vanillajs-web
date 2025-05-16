const std = @import("std");
const zap = @import("zap");

/// 요청 핸들러: 에러를 던질 수 있는 함수 (!void)
fn on_request(r: zap.Request) !void {
    if (r.path) |the_path| {
        std.debug.print("PATH: {s}\n", .{the_path});
    }

    if (r.query) |the_query| {
        std.debug.print("QUERY: {s}\n", .{the_query});
    }

    // sendBody는 오류가 발생할 수 있으므로 try 사용
    try r.sendBody("<html><body><h1>Hello from ZAP!!!</h1></body></html>");
}

pub fn main() !void {
    // HTTP 리스너 설정
    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = on_request, // 시그니처가 !void 여야 함
        .log = true,
        .max_clients = 100_000,
    });

    // 포트 열기
    try listener.listen();

    std.debug.print("Listening on 0.0.0.0:3000\n", .{});

    // 서버 시작 (워커와 스레드 개수 지정)
    zap.start(.{
        .threads = 2,
        .workers = 1,
    });
}
