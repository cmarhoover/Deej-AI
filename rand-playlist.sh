#!/usr/bin/env bash
#
#  _____           _              ____     __    _____ _         _ _     _
# | __  |___ ___ _| |___ _____   |    \ __|  |  |  _  | |___ _ _| |_|___| |_
# |    -| .'|   | . | . |     |  |  |  |  |  |  |   __| | .'| | | | |_ -|  _|
# |__|__|__,|_|_|___|___|_|_|_|  |____/|_____|  |__|  |_|__,|_  |_|_|___|_|
#                                                           |___|
#
# Create one or more Deej-AI playlists by randomly selecting a track from a root
# directory and its subdirectories.
#
# Usage:
#   ./rand-playlist.sh [--options] [<arguments>]
#   ./rand-playlist.sh -h | --help
#
# Depends on:
#   Deej-AI     https://github.com/teticio/Deej-AI
#
# Copyleft (c) 2024 alfred_j_kwack
# version: 1.0.1

###############################################################################
# Strict Mode
###############################################################################

set -o nounset
set -o errexit
set -o errtrace
set -o pipefail

# Set $IFS to only newline and tab.
IFS=$'\n\t'

###############################################################################
# Environment
###############################################################################

# This program's basename.
_ME="$(basename "${0}")"

###############################################################################
# Debug
###############################################################################

# _debug()
#
# Usage:
#   _debug <command> <options>...
#
# Description:
#   Execute a command and print to standard error. The command is expected to
#   print a message and should typically be either `echo`, `printf`, or `cat`.
#
# Example:
#   _debug printf "Debug info. Variable: %s\\n" "$0"
__DEBUG_COUNTER=0
_debug() {
  if ((${_USE_DEBUG:-0}))
  then
    __DEBUG_COUNTER=$((__DEBUG_COUNTER+1))
    {
      # Prefix debug message with "bug (U+1F41B)"
      printf "🐛  %s " "${__DEBUG_COUNTER}"
      "${@}"
      printf "―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――\\n"
    } 1>&2
  fi
}

###############################################################################
# Error Messages
###############################################################################

# _exit_1()
#
# Usage:
#   _exit_1 <command>
#
# Description:
#   Exit with status 1 after executing the specified command with output
#   redirected to standard error. The command is expected to print a message
#   and should typically be either `echo`, `printf`, or `cat`.
_exit_1() {
  {
    printf "%s " "$(tput setaf 1)!$(tput sgr0)"
    "${@}"
  } 1>&2
  exit 1
}

# _warn()
#
# Usage:
#   _warn <command>
#
# Description:
#   Print the specified command with output redirected to standard error.
#   The command is expected to print a message and should typically be either
#   `echo`, `printf`, or `cat`.
_warn() {
  {
    printf "%s " "$(tput setaf 1)!$(tput sgr0)"
    "${@}"
  } 1>&2
}

###############################################################################
# Help
###############################################################################

# _print_help()
#
# Usage:
#   _print_help
#
# Description:
#   Print the program help information.
_print_help() {
  cat <<HEREDOC

 _____           _              ____     __    _____ _         _ _     _
| __  |___ ___ _| |___ _____   |    \ __|  |  |  _  | |___ _ _| |_|___| |_
|    -| .'|   | . | . |     |  |  |  |  |  |  |   __| | .'| | | | |_ -|  _|
|__|__|__,|_|_|___|___|_|_|_|  |____/|_____|  |__|  |_|__,|_  |_|_|___|_|
                                                          |___|

Create one or more Deej-AI playlists by randomly selecting a track from a root
directory and its subdirectories.

Usage:
  ${_ME} [--options] [<arguments>]
  ${_ME} -h | --help

Options:
  -h --help             Display this help information.
  -r --root-directory   Directory to search for tracks. [ Required ]
  -p --playlist-count   Number of playlists to create.  [ Default = 1 ]
  -e --file-extension   File extenstion to match for.   [ Default = ".mp3" ]
  -s --playlist-length  Number of tracks in playlist.   [ Default = 40 ]
  -l --lookback         Deej-A.I lookback option.       [ Default = 3 ]
  -n --noise            Deej-A.I noise option.          [ Default = 0 ]
  -p --pickles          Deej-A.I pickles option.        [ Default = "Pickles" ]
  -m --mp3tovec         Deej-A.I mp3tovec option.       [ Default = "mp3tovec" ]

Example:
  ${_ME} -r "./some path/to music" -p 10 --file-extension ".flac"

Output: 
  The script will create one or more .m3u files at the <root_directory> 
  The names of the playlists will follow this format: 
    for a root directory "./some path/to music"
    a random track found at "./some path/to music/my band/my album/track1.mp3"
    will generate a playlist named "my_band-${_ME%.*}.3mu"

HEREDOC
}

###############################################################################
# Options
###############################################################################

# Parse Options ###############################################################

# Initialize program option variables.
_PRINT_HELP=0
_USE_DEBUG=0

# Initialize additional expected option variables.
_ROOT_DIR=
_PLAYLISTS_COUNT=1
_FILE_EXT=".mp3"
_LOOKBACK=3
_SONGS=40
_NOISE=0
_PICKLES="Pickles"
_MP3TOVEC="mp3tovec"
_PLAYLIST_SUB=${_ME%.*}


# __get_option_value()
#
# Usage:
#   __get_option_value <option> <value>
#
# Description:
#  Given a flag (e.g., -e | --example) return the value or exit 1 if value
#  is blank or appears to be another option.
__get_option_value() {
  local __arg="${1:-}"
  local __val="${2:-}"

  if [[ -n "${__val:-}" ]] && [[ ! "${__val:-}" =~ ^- ]]
  then
    printf "%s\\n" "${__val}"
  else
    _exit_1 printf "%s requires a valid argument.\\n" "${__arg}"
  fi
}

while ((${#}))
do
  __arg="${1:-}"
  __val="${2:-}"

  case "${__arg}" in
    -h|--help)
      _PRINT_HELP=1
      ;;
    --debug)
      _USE_DEBUG=1
      ;;
    -r|--root-directory)
      _ROOT_DIR="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;;
    -p|--playlist-count)
      _PLAYLISTS_COUNT="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;;
    -e|--file-extension)
      _FILE_EXT="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;;
    -l|--lookback)
      _LOOKBACK="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;; 
    -s|--playlist-length)
      _SONGS="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;;
    --n|--noise)
      _NOISE="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;;
    -p|--pickles)
      _PICKLES="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;;            
    -m|--mp3tovec)
      _MP3TOVEC="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;;    
    --endopts)
      # Terminate option parsing.
      break
      ;;
    -*)
      _exit_1 printf "Unexpected option: %s\\n" "${__arg}"
      ;;
  esac

  shift
done

###############################################################################
# Program Functions
###############################################################################

# _print_variables()
#
# Usage:
#   _print_variables
#
# Description:
#  Prints out the global variables
# 
_print_variables(){
  cat <<HEREDOC
>> Variables set:
         _ROOT_DIR=${_ROOT_DIR}
         _FILE_EXT=${_FILE_EXT}
         _PLAYLISTS_COUNT=${_PLAYLISTS_COUNT}
         _SONGS=${_SONGS}
         _NOISE=${_NOISE}
         _PICKLES=${_PICKLES}
         _MP3TOVEC=${_MP3TOVEC}
         _PLAYLIST_SUB=${_PLAYLIST_SUB}
HEREDOC
}

# _err_missing_param_r()
#
# Usage:
#   _err_missing_param_r
#
# Description:
#  Error message used when --root-directory parameter is missing.
#  
_err_missing_param_r(){
  printf "[ ERROR ] Mandatory option not provided: -r|--root-directory.\\n"
  _warn  printf "[ WARN  ] Try \"${_ME} --help\" for instructions on how to use this script.\\n"
}

# _err_no_matches()
#
# Usage:
#   _err_no_matches
#
# Description:
#  Error message used when we failed to find a file that matches the criteria.
#  
_err_no_matches(){
  cat <<HEREDOC 
[ ERROR ] No files with the provided extension found the root directory
            --file-extension="${_FILE_EXT}" 
            --root-directory="${_ROOT_DIR}"
HEREDOC
}

# _validate_root_directory()
#
# Usage:
#   _validate_root_directory
#
# Description:
#  Ensures the --root-directory exists and is canonical
#  
_validate_root_directory(){
  # Convert the root directory to an absolute path if there's a ~ in it.
  if [ "${_ROOT_DIR:0:1}" == \~ ]; then
      eval _ROOT_DIR="$(printf '~%q' "${_ROOT_DIR#\~}")"
      _debug printf ">> Expanded ~ \\n         _ROOT_DIR=${_ROOT_DIR}\\n"
  fi
  # Check if the provided root directory exists
  if [ ! -d ${_ROOT_DIR} ]; then
      _exit_1 printf "[ ERROR ] The --root-directory does not appear to exist. Try --debug if you must\\n"
  fi    
  # Solve for symlinks
  _ROOT_DIR=$(readlink -f "${_ROOT_DIR}")
  _debug printf ">> readlink exited with %d\n         _ROOT_DIR=${_ROOT_DIR}\\n" $?
}

# _generate_playlists()
#
# Usage:
#   _generate_playlists
#
# Description:
#  Generates the playlists
#  
_generate_playlists() {
  # Declare the variables you will use
  local __random_file
  local __relative_file
  local __playlist

  # Populate the files array
  while IFS= read -r -d '' file; do
      __files+=("$file")
  done < <(find ${_ROOT_DIR} -type f -name "*${_FILE_EXT}" -print0)

  # Check if any files with the given extension were found
  set +u
  if [ "${#__files[@]}" -eq 0 ]; then
      _exit_1 _err_no_matches
  fi
  _debug printf ">> #files=${#__files[@]:-} \\n"
  set -u

  # Start loop for n playlists
  for ((__i = 0 ; __i < ${_PLAYLISTS_COUNT} ; __i++)); do

    # Randomly choose one file from the array
    __random_file="${__files[RANDOM % ${#__files[@]}]}"

    # Set the playlist filename
    __relative_file=$(printf "${__random_file}" | sed "s|^${_ROOT_DIR}/||")
    __playlist=$(printf "${__relative_file}" | cut -d'/' -f1 | sed 's/ /_/g')
    __playlist=$(printf "${__playlist}"-"${_PLAYLIST_SUB}"".m3u")

    # Prepare your variables for Deej-AI
    if [[ "${_ROOT_DIR}" != */ ]]; then
        __dj_playlist="${_ROOT_DIR}/${__playlist}"
    else
        __dj_playlist="${_ROOT_DIR}${__playlist}"
    fi
    _debug cat <<HEREDOC
>> At playlists loop 
         __i="${__i}"
         __random_file="${__random_file}"
         __playlist="${__playlist}"
         __dj_playlist="${__dj_playlist}"
HEREDOC
    
    # Now wrangle that Python thing!
    python Deej-A.I.py ${_PICKLES} ${_MP3TOVEC} --lookback ${_LOOKBACK} --nsongs ${_SONGS} --noise ${_NOISE} --playlist "${__dj_playlist}" --inputsong "${__random_file}"

  # End loop for n playlists
  done

}

###############################################################################
# Main
###############################################################################

# _main()
#
# Usage:
#   _main [<options>] [<arguments>]
#
# Description:
#   Entry point for the program, handling basic option parsing and dispatching.
_main() {
  if ((_PRINT_HELP))
  then
    _print_help
  else
    _debug _print_variables

    #check _SONGS is a number
    local __re='^[0-9]+$'
    if ! [[ "${_SONGS}" =~ ${__re} ]] ; then
      _exit_1 printf "[ ERROR ] <playlist-length> must be an integer. Try --debug if you must\\n"
    fi

    #check _PLAYLISTS_COUNT is a number
    if ! [[ "${_PLAYLISTS_COUNT}" =~ ${__re} ]] ; then
      _exit_1 printf "[ ERROR ] <playlist-count> must be an integer. Try --debug if you must\\n"
    fi

    #check _NOISE is a number
    if ! [[ "${_NOISE}" =~ ${__re} ]] ; then
      _exit_1 printf "[ ERROR ] <noise> must be an integer. Try --debug if you must\\n"
    fi

    #check _LOOKBACK is a number
    if ! [[ "${_LOOKBACK}" =~ ${__re} ]] ; then
      _exit_1 printf "[ ERROR ] <lookback> must be an integer. Try --debug if you must\\n"
    fi    

    # Verify the --root-directory parameter is present and valid
    if ! [[ -n "${_ROOT_DIR}" ]] ; then
      _exit_1 _err_missing_param_r
    else 
      _validate_root_directory
    fi

    # Now we can proceed.
    _generate_playlists "$@"

  fi
}

# Call `_main` after everything has been defined.
_main "$@"
