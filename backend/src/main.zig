const std = @import("std");
const zap = @import("zap");

fn factorial(n: u64) u64 {
    if (n == 0) return 1;
    var result: u64 = 1;
    var i: u64 = 1;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

fn on_request(r: zap.Request) void {
    if (r.path) |the_path| {
        std.debug.print("PATH: {s}\n", .{the_path});
        if (std.mem.eql(u8, the_path, "/factorial")) {
            if (r.query) |the_query| {
                var query = std.mem.split(u8, the_query, "&");
                while (query.next()) |pair| {
                    var parts = std.mem.split(u8, pair, "=");
                    if (parts.next()) |key| {
                        if (std.mem.eql(u8, key, "n")) {
                            if (parts.next()) |value| {
                                if (std.fmt.parseInt(u64, value, 10)) |n| {
                                    const result = factorial(n);
                                    const json = try std.fmt.allocPrint(r.allocator, "{{\"n\": {d}, \"factorial\": {d}}}", .{ n, result });
                                    r.sendJson(json) catch return;
                                    return;
                                }
                            }
                        }
                    }
                }
            }
            r.sendJson("{\"error\": \"Missing or invalid 'n' parameter\"}") catch return;
            return;
        }
    }

    r.sendBody("<html><body><h1>Hello from ZAP!!!</h1></body></html>") catch return;
}

pub fn main() !void {
    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = on_request,
        .log = true,
        .max_clients = 100000,
    });
    try listener.listen();

    std.debug.print("Listening on 0.0.0.0:3000\n", .{});

    zap.start(.{
        .threads = 2,
        .workers = 1,
    });
}
