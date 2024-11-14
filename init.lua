local M = {}

function M:peek()
    local cache = ya.file_cache(self)
    if cache == nil then
        return
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
                            table.insert(metadata, next)
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
        local output, _ = Command("ffprobe")
            :args({
                "-v",
                "error",
                "-select_streams",
                "v:0",
                "-show_entries",
                "stream=codec_type",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
            })
            :arg(tostring(self.file.url))
            :stdout(Command.PIPED)
            :stderr(Command.NULL)
            :output()
        return output ~= nil and output.status.success and output.stdout ~= ""
    end

    local function show_cover()
        if self:preload() == tonumber("01", 2) then
            ya.image_show(cache, self.area)
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
            -- return tonumber("10", 2)
            return tonumber("11", 2) -- suppress errors
        end
    end
end

return M
