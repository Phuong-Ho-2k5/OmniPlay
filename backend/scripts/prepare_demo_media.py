"""Generate and fully decode local synthetic demo fixtures (Python 3.10+, FFmpeg).

No network access or Python packages are required. Paths and durations are the
same as Flyway's opt-in V3 demo seed. Existing files are verified, not overwritten.
"""
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

BACKEND = Path(__file__).resolve().parents[1]


def safe_path(root, relative):
    if not isinstance(relative, str) or not relative or "\\" in relative or ":" in relative:
        raise ValueError(f"Invalid relative media path: {relative!r}")
    path = PurePosixPath(relative)
    if path.is_absolute() or any(part in ("", ".", "..") for part in relative.split("/")):
        raise ValueError(f"Unsafe relative media path: {relative!r}")
    target = root.joinpath(*path.parts).resolve()
    if not target.is_relative_to(root):
        raise ValueError(f"Media path escapes root: {relative!r}")
    return target


def load_manifest(path, root):
    entries = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(entries, list) or not entries:
        raise ValueError("Manifest must contain a nonempty media list")
    ids, paths = set(), set()
    for entry in entries:
        media_id = str(uuid.UUID(entry["media_id"]))
        if media_id in ids:
            raise ValueError(f"Duplicate media ID: {media_id}")
        ids.add(media_id)
        kind = entry["media_type"]
        if kind not in ("VIDEO", "MUSIC", "PODCAST"):
            raise ValueError(f"Invalid media_type: {kind}")
        duration = entry["duration_seconds"]
        if type(duration) is not int or not 0 < duration <= 3600:
            raise ValueError("duration_seconds must be a positive integer up to 3600")
        frequency = entry["frequency"]
        if type(frequency) is not int or not 20 <= frequency <= 20000:
            raise ValueError("frequency must be between 20 and 20000 Hz")
        if not re.fullmatch(r"0x[0-9a-fA-F]{6}", entry["color"]):
            raise ValueError("color must be a six-digit hexadecimal RGB color")
        for key in ("file_path", "thumbnail_path"):
            target = safe_path(root, entry[key])
            if target in paths:
                raise ValueError(f"Duplicate media path: {entry[key]}")
            paths.add(target)
        extension = ".mp4" if kind == "VIDEO" else ".mp3"
        if not entry["file_path"].endswith(extension) or not entry["thumbnail_path"].endswith(".jpg"):
            raise ValueError("Media path extension does not match its type")
    return entries


def executable(value):
    resolved = shutil.which(value)
    if not resolved and value in ("ffmpeg", "ffprobe"):
        suffix = ".exe" if os.name == "nt" else ""
        local = BACKEND / ".tools" / "ffmpeg" / "bin" / (value + suffix)
        if local.is_file():
            resolved = str(local)
    if not resolved:
        raise ValueError(f"Executable missing: {value}. Install FFmpeg or set FFMPEG/FFPROBE.")
    return resolved


def run(arguments):
    completed = subprocess.run(arguments, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if completed.returncode:
        raise ValueError(f"{Path(arguments[0]).name} failed: {completed.stderr.strip()}")
    return completed.stdout


def create_file(target, arguments, ffmpeg):
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".generating-", suffix=target.suffix, delete=False) as handle:
        temporary = Path(handle.name)
    try:
        run([ffmpeg, "-hide_banner", "-loglevel", "error", "-nostdin", "-y", *arguments, str(temporary)])
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)


def generate(entries, root, ffmpeg, force):
    for entry in entries:
        target = safe_path(root, entry["file_path"])
        duration, frequency = entry["duration_seconds"], entry["frequency"]
        if force or not target.exists():
            audio = f"sine=frequency={frequency}:sample_rate=44100:duration={duration}"
            fade = f"afade=t=in:d=0.1,afade=t=out:st={duration - 0.1}:d=0.1"
            if entry["media_type"] == "VIDEO":
                arguments = ["-f", "lavfi", "-i", "testsrc2=size=320x180:rate=15",
                             "-f", "lavfi", "-i", audio, "-t", str(duration),
                             "-c:v", "libx264", "-preset", "veryfast", "-crf", "28",
                             "-profile:v", "baseline", "-pix_fmt", "yuv420p", "-g", "30",
                             "-c:a", "aac", "-b:a", "64k", "-af", fade, "-movflags", "+faststart"]
            else:
                arguments = ["-f", "lavfi", "-i", audio, "-t", str(duration),
                             "-af", f"tremolo=f=2:d=0.5,{fade}", "-c:a", "libmp3lame", "-b:a", "96k"]
            create_file(target, arguments, ffmpeg)
        thumbnail = safe_path(root, entry["thumbnail_path"])
        if force or not thumbnail.exists():
            create_file(thumbnail, ["-f", "lavfi", "-i", f"color=c={entry['color']}:s=320x180",
                                    "-frames:v", "1", "-q:v", "3"], ffmpeg)


def verify(entries, root, ffmpeg, ffprobe):
    results = []
    for entry in entries:
        target = safe_path(root, entry["file_path"])
        if not target.is_file():
            raise ValueError(f"Media file missing: {entry['file_path']}")
        metadata = json.loads(run([ffprobe, "-v", "error", "-show_format", "-show_streams", "-of", "json", str(target)]))
        duration = float(metadata["format"]["duration"])
        if abs(duration - entry["duration_seconds"]) > 0.12:
            raise ValueError(f"Media duration mismatch: {entry['file_path']} expected {entry['duration_seconds']}s, got {duration}s")
        streams = {stream["codec_type"]: stream["codec_name"] for stream in metadata["streams"]}
        expected = {"video": "h264", "audio": "aac"} if entry["media_type"] == "VIDEO" else {"audio": "mp3"}
        if streams != expected:
            raise ValueError(f"Unexpected streams/codecs for {entry['file_path']}: {streams}")
        run([ffmpeg, "-v", "error", "-xerror", "-nostdin", "-i", str(target), "-f", "null", "-"])
        thumbnail = safe_path(root, entry["thumbnail_path"])
        if not thumbnail.is_file():
            raise ValueError(f"Thumbnail missing: {entry['thumbnail_path']}")
        run([ffmpeg, "-v", "error", "-xerror", "-nostdin", "-i", str(thumbnail), "-f", "null", "-"])
        results.append({"media_id": entry["media_id"], "file_path": entry["file_path"],
                        "duration_seconds": duration, "streams": streams, "decoded": True})
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=BACKEND / "demo" / "media-manifest.json")
    parser.add_argument("--media-root", type=Path, default=BACKEND / "media")
    parser.add_argument("--ffmpeg", default=os.environ.get("FFMPEG", "ffmpeg"))
    parser.add_argument("--ffprobe", default=os.environ.get("FFPROBE", "ffprobe"))
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--force", action="store_true", help="Regenerate existing fixture files")
    parser.add_argument("--report", type=Path, help="Optional JSON verification report")
    args = parser.parse_args()
    try:
        root = args.media_root.resolve()
        entries = load_manifest(args.manifest, root)
        ffmpeg, ffprobe = executable(args.ffmpeg), executable(args.ffprobe)
        if not args.verify_only:
            generate(entries, root, ffmpeg, args.force)
        results = verify(entries, root, ffmpeg, ffprobe)
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        print(f"Verified {len(results)} media files and thumbnails: paths, durations, codecs and full decode.")
        return 0
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f"Demo media error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
