local M = {}

function M:peek()
    local cache = ya.file_cache(self)
    if not cache then
        return
    end

    local function prettify(metadata)
        local key, value = metadata:match("(.-):%s*(.*)")
        if key == nil or value == nil then
            return ui.Span("")
        else
            return ui.Line({ ui.Span(key):bold(), ui.Span(": "), ui.Span(value) })
        end
    end

    local function show_metadata()
        local child = Command("mediainfo")
            :arg("--")
            :arg(tostring(self.file.url))
            :stdout(Command.PIPED)
            :stderr(Command.NULL)
            :spawn()
        local function get_metadata()
            local limit = self.area.h + self.skip
            local i, metadata = 0, {}
            if child ~= nil then
                while i < limit do
                    local next, event = child:read_line()
                    if event == 0 then
                        i = i + 1
                        if i > self.skip then
                            table.insert(metadata, prettify(next))
                        end
                    else
                        return metadata
                    end
                end
                return metadata
            else
                return metadata
            end
        end

        ya.preview_widgets(self, { ui.Text(get_metadata()):area(self.area):wrap(ui.Text.WRAP) })
    end

    local function has_cover()
        local child1 = Command("mediainfo")
            :arg("--")
            :arg(tostring(self.file.url))
            :stdout(Command.PIPED)
            :stderr(Command.NULL)
            :spawn()
        if child1 ~= nil then
            local child2 = Command("rg")
                :args({ "Cover", "-m=1" })
                :stdin(child1:take_stdout())
                :stdout(Command.NULL)
                :stderr(Command.NULL)
                :spawn()
            if child2 ~= nil then
                local status = child2:wait()
                if status ~= nil then
                    return status.success
                else
                    return false
                end
            else
                return false
            end
        else
            return false
        end
    end

    local function show_cover()
        local cover_width = self.area.w
        local cover_height = self.area.h

        local top_left = ui.Rect({
            x = self.area.left,
            y = self.area.top,
            w = cover_width,
            h = cover_height,
        })

        if self:preload() == 1 then
            ya.image_show(cache, top_left)
        end
    end

    if has_cover() then
        show_cover()
    else
        show_metadata()
    end
end

function M:seek(units)
    local h = cx.active.current.hovered
    if h and h.url == self.file.url then
        ya.manager_emit("peek", {
            tostring(math.max(0, cx.active.preview.skip + units)),
            only_if = tostring(self.file.url),
        })
    end
end

function M:preload()
    local cache = ya.file_cache(self)
    if cache == nil then -- not allowd to be cached
        return tonumber("01", 2) -- don't continue, success
    end
    local cha = select(1, fs.cha(cache))
    if cha ~= nil and cha.len > 1 then -- cache already exits
        return tonumber("01", 2)
    end

    local status, code = Command("ffmpeg"):args({
        "-v",
        "error",
        "-i",
        tostring(self.file.url),
        "-an",
        "-vcodec",
        "copy",
        "-frames:v",
        "1",
        "-f",
        "image2",
        "-y",
        tostring(cache),
    }):status()

    if status == nil then -- `ffmpeg` executable not found
        ya.err("`ffmpeg` command returns " .. tostring(code))
        return tonumber("00", 2)
    else
        if status.success then
            return tonumber("01", 2)
        else -- decoding error or save error
            return tonumber("10", 2)
        end
    end
end

return M
