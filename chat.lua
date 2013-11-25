module("chat", package.seeall)

local upload     = require "resty.upload"
local uploads_dir = "/opt/openresty/nginx/uploads/"
local chunk_size  = 4096

local stats  = { sub_open=0, sub_close=0, chan_open=0, chan_close=0, msg_send=0, broken_count=0 }    -- holds global stats
local channels = {}  -- holds info for each channel
local shit_list = {} -- holds broken sockets.

local notify_queue_tail = {nil,nil}
local notify_queue_head = notify_queue_tail

local http_header = "HTTP/1.1 200 OK\r\n"..
                    "Content-Type: text/event-stream\r\n"..
                    "Server: dropth.at\r\n"..
                    "Connection: keep-alive\r\n"..
                    "Transfer-Encoding: chunked\r\n\r\n"

local function format_http_chunk(message) -- for chunked transfer-encoding
    local len = string.format("%x\r\n", string.len(message))
    return len..message.."\r\n"
end

local function format_event(id, event, message)
    local buff = "data:"..message.."\r\n\r\n"
    if event then
        buff = "event:"..event.."\r\n"..buff
    end
    if id then
        buff = "id:"..id.."\r\n"..buff
    end
    return format_http_chunk(buff)
end

local function get_or_create_channel(channel_id)
    if not channels[channel_id] then        
        stats.chan_open = stats.chan_open + 1
        local data = {
                        msg_count=0,
                        count_open=0,
                        count_close=0,
                        last_announce=0,
                        announce_queued=false,
                        sockets={},
                    }
        channels[channel_id] = data
        stats.chan_open = stats.chan_open + 1
    end
    return channels[channel_id]
end

local function pop_update_queue() -- todo: generalized linked list?
    if notify_queue_head ~= notify_queue_tail then
        local item = notify_queue_head[0]
        notify_queue_head = notify_queue_head[1]
        return item
    end
    return nil
end

local function push_update_queue(item)
    notify_queue_tail[0] = item
    notify_queue_tail[1] = {nil,nil}
    notify_queue_tail = notify_queue_tail[1]
end

local function update_channel(channel_id)
    local channel = channels[channel_id]
    if not channel.announce_queued then
        push_update_queue(channel_id)
        channel.announce_queued = true
    end
end

local function add_socket(channel_id, socket)
    local channel = get_or_create_channel(channel_id)
    channel.sockets[socket] = ngx.now() -- TODO: keep more state here?
    channel.count_open = channel.count_open + 1
    stats.sub_open = stats.sub_open + 1
    update_channel(channel_id)
end

local function remove_socket(channel_id, socket)
    local channel = channels[channel_id]
    if channel then
        local start_time = channel.sockets[socket]
        if start_time then
            stats.sub_close = stats.sub_close + 1
            channel.count_close = channel.count_close + 1
            channel.sockets[socket] = nil
            if shit_list[socket] then
                stats.broken_count = stats.broken_count + 1
                shit_list[socket] = nil
            end
            update_channel(channel_id)
        end
        if channel_count(channel_id) == 0 then
            channels[channel_id] = nil
            stats.chan_close = stats.chan_close + 1
        end
    end
end

function channel_count(channel_id)
    local channel = channels[channel_id]
    if channel then
        return channel.count_open - channel.count_close
    end
    return 0
end

function publish_event(channel_id, event_id, event, message)
    local chunk = format_event(event_id, event, message)
    local channel = channels[channel_id]
    if channel then
        for sock,start_time in pairs(channel.sockets) do
            if not shit_list[sock] then
                local bytes, err = sock:send(chunk)
                if bytes ~= string.len(chunk) then
                    ngx.log(ngx.INFO, "failed to write event? adding to shit list", err)
                    shit_list[sock] = true
                end
            end
        end
    end
end

local function publish_channel_count(channel_id)
    local channel = channels[channel_id]
    if channel then
        publish_event(channel_id, nil, 'count', 'count='..channel_count(channel_id))
        channel.last_announce = ngx.now()
    end
end

-- FIXME TODO: investigate reload behaivor with timers + their view of state.
-- (until then kill server when reloading)
-- in server directive: set_by_lua $something 'chat.check_init()';
local function notify_thread(premature)
    ngx.log(ngx.ERR, "Notify thread running.")
    local loops = 0
    while true do
        loops = loops + 1
        if loops == 20 then
            local cons = stats.sub_open - stats.sub_close
            ngx.log(ngx.CRIT, "Hper;Derp. Connections: "..cons)        
            loops = 0
        end
        local channel_id = pop_update_queue()
        if channel_id then
            local now = ngx.now();
            local channel = channels[channel_id]
            if channel and now < 0.373 + channel.last_announce then  -- not horrible; could be better.
                ngx.sleep(0.373) -- meh.
            end
            channel = channels[channel_id]
            if channel then
                channel.announce_queued = false
                publish_channel_count(channel_id)
            end
        else
            ngx.sleep(.327)
        end
    end
end

function check_init()
    ngx.log(ngx.ERR, "Started notify thread.")
    ngx.timer.at(0, notify_thread)
    check_init = function()
        --ngx.log(ngx.ERR, "NOP. (was check_init)")
    end
end

local blank_chunk = format_http_chunk(":\r\n")
function send_blank(sock)
    bytes, err = sock:send(blank_chunk)
    if not bytes then
        shit_list[sock] = true
    end
end

function event_source_location()
    local channel_id = ngx.var.channel
    local sock, err = ngx.req.socket(true)
    if not sock then
        ngx.log(ngx.ERR, "server: failed to get raw req socket: ", err)
        return
    end
    local bytes, err = sock:send(http_header)
    if not bytes then
        ngx.log(ngx.ERR, "failed to send header?: ", err)
        ngx.exit(499)
    end

    local function cleanup()
        remove_socket(channel_id, sock)
        ngx.exit(499)
    end
    local ok, err = ngx.on_abort(cleanup)
    if not ok then
        ngx.log(ngx.ERR, "failed to register the on_abort callback: ", err)
        ngx.exit(500)
    end
    add_socket(channel_id, sock)

    local loops = 0
    local shit_list = channels[channel_id]
    while 1 do
        ngx.sleep(3.617)
        loops = loops + 1
        if loops == 6 then
            send_blank(sock)
            loops = 0
        end
        local channel = channels[channel_id]
        if shit_list[sock] then
            ngx.log(ngx.ERR, "found shit list socket that didn't abort itself")
            cleanup()
        end
    end
end

-----------------------------------------------------------------------

function file_upload_location()
    local filename = uploads_dir..ngx.var.dir..'/'..ngx.var.filename
    local form = upload:new(chunk_size)
    local file
    local first = true

    if not form then
        return ngx.exit(400)
    end

    while true do
        local typ, res, err = form:read()
        if not typ then
            ngx.say("failed to read: ", err)
            ngx.exit(400)
        end
        if typ == "header" then
            -- Content-Disposition: form-data; name="encrypted-file"
            if string.lower(res[1]) == 'content-disposition' and string.match(string.lower(res[2]),'name="?encrypted%-file"?') then
                file = io.open(filename, "w+")
                if not file then
                    ngx.say("failed to open file ", filename)
                    return
                end
            end
        elseif typ == "body" then
            if file then
                if first then
                    first = false
                    if string.sub(res,1,2) ~= '{"' then
                        ngx.exit(400)
                    end
                end
                file:write(res)
            end
        elseif typ == "part_end" then
            if file then
                file:close()
                file = nil
                break
            end
        elseif typ == "eof" then
            break
        end
    end
end
