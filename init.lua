local M = {}

local function display_error(job, error)
    ya.preview_widgets(job, { ui.Text(ui.Line({ ui.Span(error) })):area(job.area):wrap(ui.Text.WRAP) })
end

local function has_cover(job)
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
        :arg(tostring(job.file.url))
        :stdout(Command.PIPED)
        :stderr(Command.PIPED)
        :output()

    if output ~= nil then
        if output.status.success and output.stdout ~= "" then
            return true
        else
            display_error(job, output.stderr)
            return false
        end
    else
        display_error(job, "Make sure `ffprobe` (part of the `ffmpeg` suite) is installed and in your PATH.")
        return false
    end
end

local function show_metadata(job)
    local function get_metadata()
        local child, _ = Command("mediainfo")
            :arg("--")
            :arg(tostring(job.file.url))
            :stdout(Command.PIPED)
            :stderr(Command.NULL)
            :spawn()
        local limit = job.area.h + job.skip
        local i, metadata = 0, {}
        if child ~= nil then
            while i < limit do
                local next, event = child:read_line()
                if event == 0 then
                    i = i + 1
                    if i > job.skip then
                        table.insert(metadata, next)
                    end
                else
                    return metadata
                end
            end
        end
        return metadata
    end

    ya.preview_widgets(job, { ui.Text(get_metadata()):area(job.area):wrap(ui.Text.WRAP) })
end

function M:peek(job)
    local start, cache = os.clock(), ya.file_cache(job)
    if cache == nil then
        return
    end

    local function show_cover()
        if self:preload(job) == tonumber("01", 2) then
            ya.sleep(math.max(0, PREVIEW.image_delay / 1000 + start - os.clock()))
            ya.image_show(cache, job.area)
            ya.preview_widgets(job, {})
        end
    end

    if has_cover(job) then
        show_cover(self, job)
    else
        show_metadata(job)
    end
end

function M:seek(job)
    local h = cx.active.current.hovered
    if h and h.url == job.file.url then
        ya.manager_emit("peek", {
            math.max(0, cx.active.preview.skip + job.units),
            only_if = job.file.url,
        })
    end
end

function M:preload(job)
    local cache = ya.file_cache(job)
    if cache == nil then -- not allowd to be cached
        return tonumber("01", 2) -- don't continue, success
    end
    local cha = select(1, fs.cha(cache))
    if cha ~= nil and cha.len > 1 then -- cache already exits
        return tonumber("01", 2)
    end

    -- Assumption: `num` is always non-negative
    local function round(num)
        return math.floor(num + 0.5)
    end

    -- Map `image_quality` from range [1, 100] to FFmpeg's `-q:v` range [2, 31]
    -- Assumption: `image_quality` is in the range [1, 100]
    -- See also:
    -- https://docs.rs/image/latest/image/codecs/jpeg/struct.JpegEncoder.html#method.new_with_quality
    -- https://ffmpeg.org/ffmpeg-codecs.html#toc-Codec-Options
    -- https://stackoverflow.com/questions/32147805/ffmpeg-generate-higher-quality-images-for-mjpeg-encoding
    local function map_quality_to_qv(image_quality)
        local k = -29 / 99
        local b = 31 - k
        return math.min(31, math.max(2, round(k * image_quality + b)))
    end

    local status, code = Command("ffmpeg"):args({
        "-v",
        "error",
        "-i",
        tostring(job.file.url),
        "-an",
        "-frames:v",
        "1",
        "-vf",
        -- See also:
        -- https://trac.ffmpeg.org/wiki/Scaling
        -- https://superuser.com/questions/566998/how-can-i-fit-a-video-to-a-certain-size-but-dont-upscale-it-with-ffmpeg
        "scale='-1:min("
            .. tostring(PREVIEW.max_height)
            .. ",ih)'",
        "-q:v",
        tostring(map_quality_to_qv(PREVIEW.image_quality)),
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
