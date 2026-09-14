# Video asset audit

Audited all five tracked video assets from commit `858a6f7c10ccf31b559ae8da543a1e3e082c5433` in the isolated branch `codex/optimize-video-assets`.

The app uses AVPlayer/AVPlayerLayer and targets iOS 18. H.264 is a suitable playback codec, but codec choice alone does not establish optimal size or quality. The selected settings prioritize visual fidelity, existing resolution, timing, audio, and resource compatibility. They are a measured conservative tradeoff, not a claim of a universal optimum.

| Asset | Original bytes | Final bytes | Action |
| --- | ---: | ---: | --- |
| `iss.mp4` | 15,529,612 | 15,529,704 | Lossless fast-start remux |
| `iss_pass_compilation.mov` | 4,134,570 | 4,134,570 | Preserved byte-for-byte |
| `pass_demo.mov` | 5,021,986 | 1,001,684 | H.264 CRF 18, slow; audio copied |
| `sky_chart_tutorial.mov` | 19,498,655 | 12,132,377 | H.264 CRF 18, slow; audio copied |
| `tiangong.mp4` | 8,316,218 | 8,316,270 | Lossless fast-start remux |

Total: **52,501,041 → 41,114,605 bytes**, saving **11,386,436 bytes (21.7%)**.

## Encoding decisions

- `pass_demo.mov`: HEVC → H.264 High, 8-bit yuv420p, CRF 18, slow preset. Maintains 1080 × 2346 and all 393 frames.
- `sky_chart_tutorial.mov`: high-bitrate H.264 → H.264 High, CRF 18, slow preset. Original 1920 × 1080 plus rotation is baked into upright 1080 × 1920 pixels. All 241 frames retained. Captured device/location metadata and unused timed metadata tracks removed; audio is copied intact.
- `iss.mp4` and `tiangong.mp4`: existing H.264 is already efficiently compressed (about 1.83 and 1.21 Mb/s). Full-resolution CRF 18 trials grew to 32,655,279 and 14,466,973 bytes, so those trials were rejected. Move the MP4 index before media data with stream copy instead. This adds only 144 bytes combined and does not re-encode video. Fast-start is mainly useful for progressive transfer; no measured local playback speedup is claimed.
- `iss_pass_compilation.mov`: retained exactly. Its HEVC stream has pre-existing duplicate picture-order counts and irregular timestamps: 487 declared frames but 466 decodable frames in FFmpeg. A trial transcode shifted some frame timestamps by up to 66.8 ms and shortened duration by about 40 ms; remuxing also produced timing warnings. Neither was accepted. Re-exporting this clip from its original editing source is preferable to automatically rewriting its irregular timing.

Existing filenames and MOV/MP4 containers remain compatible with all resource lookups; no application code changes are needed. MOV is a container and can contain H.264.

## Verification

FFmpeg/ffprobe 7.1.1:

- Fully decoded accepted transcodes; checked original and output frame counts, display dimensions, color properties, and durations.
- Frame timestamp differences: zero for `pass_demo.mov`; at most 1.667 ms for `sky_chart_tutorial.mov` due to time-base quantization. Both video durations are unchanged.
- Full-clip SSIM against decoded sources: **0.999649** for pass demo and **0.988215** for tutorial. SSIM is a similarity indicator, not proof of perceptual equivalence.
- Visually compared before/after frames at five seconds for orientation, UI text, color and detail.
- SHA-256 compressed stream hashes match for copied AAC audio and for both losslessly remuxed H.264 videos.
- Verified `moov` precedes `mdat` in all four changed assets.
- The compilation is byte-identical to the source commit; its original decoding warnings remain.
- No app build or on-device playback test was performed; this is an asset-only change with unchanged resource paths.

## Reproduction

Run from the worktree root using originals from the source commit, writing to a separate output directory. Do not repeatedly re-encode already optimized assets.

```sh
ffmpeg -i ORIGINAL.mov -map 0:v:0 -map '0:a?' -map_metadata -1 \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
  -fps_mode passthrough -c:a copy -movflags +faststart OUTPUT.mov

ffmpeg -i ORIGINAL.mp4 -map 0 -c copy -movflags +faststart OUTPUT.mp4
```

The first command applies to pass demo and tutorial; FFmpeg automatically applies the tutorial's display rotation. The second applies to ISS and Tiangong only.

References: [Apple AVFoundation](https://developer.apple.com/av-foundation/), [FFmpeg libx264 options](https://www.ffmpeg.org/ffmpeg-codecs.html#libx264_002c-libx264rgb), [FFmpeg MOV/MP4 fast-start](https://ffmpeg.org/ffmpeg-formats.html#mov_002c-mp4_002c-ismv).
