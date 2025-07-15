#!/usr/bin/liquidsoap -v

log.stdout.set(true)

# --- Dynamic Playlist Discovery ---

# 1. Get the current date using the system 'date' command.
date_prefix = string.trim(system("date +%F").stdout)
print("Searching for a playlist with date prefix: #{date_prefix}")

# 2. Construct a shell command to find the playlist file for today.
command = "find /playlists/ -maxdepth 1 -name '" ^ date_prefix ^ "-*.m3u' | head -n 1"

# 3. Execute the command and trim the output.
playlist_path_raw = system(command).stdout
playlist_path = string.trim(playlist_path_raw)

# 4. Define the 'music' variable using an if/else expression.
# This structure ensures 'music' is always assigned a value before it's used later.
music =
  if playlist_path != "" then
    print("Success! Found today's playlist: #{playlist_path}")
    # This value is returned and assigned to 'music' if the file is found.
    mksafe(crossfade(duration=2.0, playlist(mode="normal", playlist_path)))
  else
    print("Warning: No playlist found for today. Playing silence.")
    # This value is returned and assigned to 'music' if no file is found.
    blank(duration=3600.)
  end

# --- Stream Output ---

# This section now works because the 'music' variable is guaranteed to be defined.
output.icecast(
  %mp3(bitrate=320, samplerate=44100, stereo=true),
  mount="/halogen",
  host="icecast",
  port=8000,
  password="bBA8PKupa2K0Of",
  description="halogen radio " ^ date_prefix,
  music)
