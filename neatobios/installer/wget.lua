-- Copyright © 2026 UsUsStudios
--
-- Permission is hereby granted, free of charge, to any person
-- obtaining a copy of this software and associated documentation
-- files (the “Software”), to deal in the Software without
-- restriction, including without limitation the rights to use, copy,
-- modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
-- BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
-- ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local queueEvent = event.queueEvent

local function waitForHttpResponse(id)
	local queue = event.getQueue("network", "HttpResponse")
	for _, event in ipairs(queue) do
		local _, eventId = table.unpack(event)
		if eventId == id then
			return true, event
		end
		queueEvent("network", "HttpResponse", table.unpack(event))
	end
	return false
end

local function retrieveHTTPResponse(id)
	local found, response = false, nil
	event.clear()
	while not found do
		found, response = waitForHttpResponse(id)
		coroutine.yield()
	end
	if response == nil then
		return
	end
	local _, _, code, msg, headers, body = table.unpack(response)
	if code == 200 then
		return headers, body
	end
	print(code .. ": " .. msg)
	return code, msg
end

local function wget(url, filename)
	local formattedUrl = url
	if string.sub(url, 1, 8) ~= "https://" then
		formattedUrl = "https://" .. url
	end

	local id = internet.GET(formattedUrl)

	local headers, body = retrieveHTTPResponse(id)
	-- check if headers is actually a status code
	if type(headers) == "number" then
		return false
	end

	local header = files.open(filename, "w", 0)
	header.write(body)
	header.close()
	return true
end

return wget
