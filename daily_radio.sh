#!/bin/bash

# A comprehensive script to create a daily playlist based on a genre of the day.

set -e # Exit immediately if a command exits with a non-zero status.

echo "🎶 Starting the daily playlist creation process..."

# --- Step 1: Determine Today's Genre ---
genres=(
  "(Ambient|Chill)"  # Sunday
  "Electro"          # Monday
  "(Rock|Metal)"     # Tuesday
  "(Jazz|Blues)"     # Wednesday
  "(Folk|Indie)"     # Thursday
  "Classical"        # Friday
  "(Hip-Hop|Funk)"   # Saturday
)

# Get the day's index (0-6) and select the genre.
day_index=$(date +%w)
todays_genre="${genres[$day_index]}"

echo "Today is $(date +%A). Selected genre: '$todays_genre'"

# --- Step 2: Select a Random Track for the Genre ---
echo "🔎 Selecting a random track..."
track_path=$(docker exec beets beet random -pe genre::"$todays_genre")

# --- Step 3: Validate the Track Path ---
# Check if the select_track script failed to return a path.
if [[ -z "$track_path" ]]; then
  echo "❌ Error: Could not find a track for the genre '$todays_genre'." >&2
  exit 1
fi

echo "👍 Found track: $track_path"

# --- Step 4: Create the Playlist ---
echo "⏯️ Creating playlist..."
docker exec deej-ai bash rand-playlist.sh -r /music -d /music/_playlists -s  100 -n 0 -l 5 -t "$track_path"

echo "✅ Playlist created successfully!"

docker restart liquidsoap
