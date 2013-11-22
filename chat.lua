module("chat", package.seeall)

local upload     = require "resty.upload"
local uploads_dir = "/opt/openresty/nginx/uploads/"
local chunk_size  = 4096

local sockets = {}     -- holds a socket for each channel.
local count_times = {} -- limit the frequency of count announces (for load testing).
local shit_list = {}   -- todo: figure out what's different about firefox connections

local http_header = "HTTP/1.1 200 OK\r\n"..
					"Content-Type: text/event-stream\r\n"..
					"Server: dropth.at\r\n"..
					"Connection: keep-alive\r\n"..
 				    "Transfer-Encoding: chunked\r\n\r\n"

function is_channel_active(channel)
	local count = table.getn(sockets[channel] or {})
	return count > 0
end

function format_http_chunk(message) -- for chunked transfer-encoding
	local len = string.format("%x\r\n", string.len(message))
	return len..message.."\r\n"
end

function publish_event(channel, event, message)
	local chunk
	if event then
	 	chunk = format_http_chunk("event:"..event.."\r\ndata:"..message.."\r\n\r\n")
	 else
	 	chunk = format_http_chunk("data:"..message.."\r\n\r\n")
	end
	if sockets[channel] then
		for i,sock in ipairs(sockets[channel]) do
			if not shit_list[sock] then
				local bytes, err = sock:send(chunk)
			    if not bytes then
			        ngx.log(ngx.ERR, "server: failed to publish event? ", err)
			        shit_list[sock] = true
			    end
			end
		end
	end
end

function publish_count(channel) -- now, with rate limiting.
	local start_time = ngx.now()
	if count_times[channel] + 0.373 > start_time then
		ngx.sleep(0.431)
	end
	if count_times[channel] >= start_time then
		return
	end
	local count = table.getn(sockets[channel])
	count_times[channel] = ngx.now()
	publish_event(channel,'count',"count="..count)
end

function unsubscribe(channel, sock)
	local channel_sockets = sockets[channel]
	for i,c in ipairs(channel_sockets) do    -- todo: keep an index to avoid the loop
		if c == sock then
			table.remove(channel_sockets,i)
			break
		end
	end
	publish_count(channel)
	shit_list[sock] = nil
	if table.getn(channel_sockets) == 0 then
		sockets[channel] = nil
		count_times[channel] = nil
	end
end

function subscribe(channel, sock)
	local channel_sockets = sockets[channel]
	if not channel_sockets then
		channel_sockets = {}
		sockets[channel] = channel_sockets
		count_times[channel] = 0
	end
	table.insert(channel_sockets, sock)
	publish_count(channel)
end

local blank_chunk = format_http_chunk(":\r\n")
function send_blank(sock)
	local bytes, err = sock:send(blank_chunk)
	if not bytes then
		shit_list[sock] = true
    end
end

function event_source_location()
	local channel = ngx.var.channel
    -- ngx.req.read_body()

    local sock, err = ngx.req.socket(true)
    if not sock then
        ngx.log(ngx.ERR, "server: failed to get raw req socket: ", err)
        return
    end

    local ok, err = sock:send(http_header)
    if not ok then
        ngx.log(ngx.ERR, "failed to send header?: ", err)
        ngx.exit(499)
    end

	local function cleanup()
		unsubscribe(channel, sock)
		ngx.exit(499)
	end
    local ok, err = ngx.on_abort(cleanup)
    if not ok then
        ngx.log(ngx.ERR, "failed to register the on_abort callback: ", err)
        ngx.exit(500)
    end
    subscribe(channel, sock)

    local loops = 0
    while 1 do
    	ngx.sleep(3.617)
    	loops = loops + 1
    	if loops == 5 then
    		send_blank(sock)
    		loops = 0
    	end
    	if shit_list[sock] then
    		ngx.log(ngx.ERR, "found shit list socket.")
    		cleanup()
    	end
    end
end

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
