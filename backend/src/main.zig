const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;

const zap = @import("zap");

// 정적 파일을 제공할 디렉토리 (main.zig 기준 상대 경로)
const STATIC_DIR = "../../frontend";

pub fn main() !void {
    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = serveStatic,
        .log = true,
        .max_clients = 100_000,
    });

    try listener.listen();
    std.debug.print("Listening on 0.0.0.0:3000\n", .{});

    zap.start(.{
        .threads = 2,
        .workers = 1,
    });
}

/// 정적 파일 서빙용 미들웨어
fn serveStatic(r: zap.Request) !void {
    const path = r.path orelse "/";
    if (mem.eql(u8, path, "/")) {
        // 루트 경로 -> index.html 리다이렉트
        r.sendBody(
            \\HTTP/1.1 302 Found
            \\Location: /index.html
            \\
        ) catch {
            r.sendError(error.InternalServerError, null, 500);
            return;
        };
        return;
    }

    // 보안상 위험한 경로 차단
    if (mem.startsWith(u8, path, "../") or mem.indexOf(u8, path, "..") != null) {
        r.sendError(error.Forbidden, null, 403);
        return;
    }

    // 직접 arena 생성
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // 실제 파일 경로 조합
    const file_path = fmt.allocPrint(arena.allocator(), "{s}/{s}", .{ STATIC_DIR, path }) catch {
        r.sendError(error.InternalServerError, null, 500);
        return;
    };

    // 파일 열기 시도
    const file = fs.openFileAbsolute(file_path, .{}) catch {
        r.sendError(error.NotFound, null, 404);
        return;
    };
    defer file.close();

    // 파일 내용 읽기
    const contents = file.readToEndAlloc(arena.allocator(), 1024 * 1024) catch {
        r.sendError(error.InternalServerError, null, 500);
        return;
    };

    // 클라이언트에 전송
    r.sendBody(contents) catch {
        r.sendError(error.InternalServerError, null, 500);
    };
}
