# audio.yazi

Preview audio cover and fallback to metadata on [Yazi](https://github.com/sxyazi/yazi).

![audio-cover](https://github.com/gaesa/audio.yazi/assets/71256557/c0eb01f8-c61f-4966-a34a-4d63639db800)
![audio-metadata](https://github.com/gaesa/audio.yazi/assets/71256557/8850814c-1faf-43b2-8d9b-e586adc7178c)

> [!NOTE]
> The latest main branch of Yazi is required at the moment.

## Requirements

Make sure you have [exiftool](https://exiftool.org/), [mediainfo](https://mediaarea.net/en/MediaInfo/Download), [ripgrep](https://github.com/BurntSushi/ripgrep/releases) installed and in your `PATH`.

## Installation

```sh
# Linux/macOS
git clone https://github.com/gaesa/audio.yazi.git ~/.config/yazi/plugins/audio.yazi

# Windows
git clone https://github.com/gaesa/audio.yazi.git %AppData%\yazi\config\plugins\audio.yazi
```

## Usage

Add this to your `yazi.toml`:

```toml
[plugin]
prepend_previewers = [
    { mime = "audio/*", run = "audio" },
]
```

## Thanks

Thanks to [sxyazi](https://github.com/sxyazi) for the PDF previewer code, on which this previewer is based on.
