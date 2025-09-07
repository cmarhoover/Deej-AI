#!/bin/bash

# A comprehensive script to create a daily playlist based on a genre of the day.

# Exit on error, treat unset variables as an error, and fail pipelines on first error.
set -euo pipefail

# --- Configuration ---
readonly MAX_RETRIES=5          # The maximum number of times to try and create the playlist.
readonly PLAYLIST_LENGTH=100    # The number of tracks in the final playlist (sets the -s arg).
readonly BEETS_CONTAINER="beets"
readonly DEEJAI_CONTAINER="deej-ai"

# --- Functions ---

# A simple logging function for consistent output.
log() {
  # Redirect echo to stderr so log messages don't interfere with command substitution.
  echo "[$1] $2" >&2
}

# Determines the genre for the current day of the week.
get_todays_genre() {
  log "INFO" "Determining today's genre..."
  local genres=(
    "(Ambient|Chill)"  # Sunday
    "Electro"          # Monday
    "(Rock|Metal)"     # Tuesday
    "(Jazz|Blues)"     # Wednesday
    "(Folk|Indie)"     # Thursday
    "Classical"        # Friday
    "(Hip Hop|Funk)"   # Saturday
  )

  local day_index
  day_index=$(date +%w)
  local todays_genre="${genres[$day_index]}"

  log "INFO" "Today is $(date +%A). Selected genre: '$todays_genre'"
  echo "$todays_genre"
}

# Finds a random track matching the given genre.
# This function will now only try ONCE.
# Arg 1: The genre to search for.
find_track() {
  local genre="$1"
  local track_path=""

  log "INFO" "Searching for a random seed track..."
  
  # Use an 'if' statement to gracefully handle a command failure without exiting the script.
  if track_path=$(docker exec "$BEETS_CONTAINER" beet random -pe genre::"$genre" 2>/dev/null); then
      if [[ -n "$track_path" ]]; then
        log "SUCCESS" "Found potential seed track: $track_path"
        echo "$track_path"
        return 0
      fi
  fi
  
  log "WARN" "Beets did not return a track for genre '$genre'."
  return 1
}

# Creates the playlist using the deej-ai script.
# This function will now pass its exit code up to the caller.
# Arg 1: The path to the seed track.
create_playlist() {
  local seed_track="$1"
  log "INFO" "Attempting to create playlist with seed: ${seed_track}"

  docker exec "$DEEJAI_CONTAINER" bash rand-playlist.sh \
    -r /music \
    -d /music/_playlists \
    -s "$PLAYLIST_LENGTH" \
    -n 0 \
    -l "5" \
    -t "$seed_track"
  
  # The exit code of the docker command will be returned automatically.
}

# --- Main Execution ---
main() {
  log "PROCESS" "Starting the daily playlist creation process..."

  local genre
  genre=$(get_todays_genre)
  local attempt=0

  while [[ $attempt -lt $MAX_RETRIES ]]; do
    attempt=$((attempt + 1))
    log "PROCESS" "Overall attempt ${attempt}/${MAX_RETRIES}..."

    local seed_track
    # First, try to get a seed track. If this fails, continue to the next attempt.
    if ! seed_track=$(find_track "$genre"); then
        log "WARN" "Could not find a seed track on this attempt. Retrying..."
        sleep 2
        continue
    fi

    # Next, try to create the playlist with the found track.
    if create_playlist "$seed_track"; then
      log "SUCCESS" "Playlist created successfully!"
      log "PROCESS" "Restarting Liquidsoap..."
      docker restart liquidsoap
      log "PROCESS" "All done! 🎉"
      exit 0 # Success! Exit the script.
    else
      log "WARN" "Failed to create playlist with that seed track. The track may not be in the deej-ai database. Trying a new track..."
      sleep 2
    fi
  done

  log "ERROR" "Could not create a playlist after $MAX_RETRIES attempts. Aborting." >&2
  exit 1
}

# Run the main function
main

