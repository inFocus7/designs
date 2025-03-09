#!/bin/bash

set -e

RELATIVE_PATH=$(dirname $0)
FILTER_CONFIGS_PATH="$RELATIVE_PATH/filter_configs"
CURVES_PATH="$FILTER_CONFIGS_PATH/curves"
LUTS_PATH="$FILTER_CONFIGS_PATH/luts"
# the time limit of a processed video
LIMIT_SECONDS=2
# width and height set to portrait mode
WIDTH=1080
HEIGHT=1920

# modifiable variables
START_TIME=0 # default start time
END_TIME=""
LOOP=false

#####################
# Media Processor
# usage ex: sh blueprint/assets/media-processor/processor.sh --input ./blueprint/assets/media-processor/test/in/1.mp4 --output ./blueprint/assets/media-processor/test/out/1.mp4 --playback-effect boomerang --start 0 --filter test_filter
#####################

# define colors for logging
ERR_COLOR="\033[0;31m"
INFO_COLOR="\033[0;34m"
WARN_COLOR="\033[0;33m"
RESET_COLOR="\033[0m"

log_info() {
    echo "${INFO_COLOR}[INFO] $1${RESET_COLOR}"
}

log_warn() {
    echo "${WARN_COLOR}[WARN] $1${RESET_COLOR}"
}

log_err() {
    echo "${ERR_COLOR}[ERR] $1${RESET_COLOR}"
}

# Required commands
# ffmpeg for video processing
# yq for yaml processing (each filter is it's own configuration file in yaml)
required_commands=("ffmpeg" "yq")

# Check for required commands
missing_commands=()
for command in "${required_commands[@]}"; do
  if ! command -v "${command}" &> /dev/null; then
    missing_commands+=("${command}")
  fi
done

if [ ${#missing_commands[@]} -ne 0 ]; then
  log_err "Missing commands: ${missing_commands[@]}"
  exit 1
else
  log_info "All required commands found."
fi

INPUT_PATH=""
OUTPUT_PATH=""
FILTER=""
PLAYBACK_EFFECT=""

# Read in arguments
# For now we accept `--input` and `--output` flags, as well as `--filter` to specify a filter to apply
# Also, just added a --start and --end time to process a segment of the video, where the biggest gap between both it longest length of video (2s)
# Also --playback-effect to apply a playback effect to the video (only boomerang for now)
# We also accept `--help` to print out usage information
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -i|--input) INPUT_PATH="$2"; shift ;;
    -o|--output) OUTPUT_PATH="$2"; shift ;;
    -f|--filter) FILTER="$2"; shift ;;
    -s|--start) START_TIME="$2"; shift ;;
    -e|--end) END_TIME="$2"; shift ;;
    -p|--playback-effect) PLAYBACK_EFFECT="$2"; shift ;;
    -h|--help) echo "Usage: processor.sh -i|--input <input_path> -o|--output <output_path> -f|--filter <filter_name> [-s|--start <start_time> -e|--end <end_time>] [-p|--playback-effect <playback_effect>]"; exit 0 ;;
    *) echo "[ERR] Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

# Validate input and output paths
if [ -z "$INPUT_PATH" ]; then
  log_err "No input path provided."
  exit 1
fi

if [ -z "$OUTPUT_PATH" ]; then
  log_err "No output path provided."
  exit 1
fi

if [ ! -f "$INPUT_PATH" ]; then
  log_err "Input file not found."
  exit 1
fi

# if end time is < start time, exit
if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
  if [ $(awk "BEGIN {print ($END_TIME < $START_TIME) ? 1 : 0}") -eq 1 ]; then
    log_err "End time is less than start time."
    exit 1
  fi
fi

# if end time - start time is greater than the limit (2s), exit
if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
  if [ $(($END_TIME - $START_TIME)) -gt $LIMIT_SECONDS ]; then
    log_warn "Time limit is over $LIMIT_SECONDS seconds, will only process up to 2 seconds after the start time."
    END_TIME="" # reset end time
  fi
fi

if [ -z "$START_TIME" ] && [ -z "$END_TIME" ]; then
  START_TIME=0
  END_TIME=$(ffmpeg -i "$INPUT_PATH" 2>&1 | awk -F: '/Duration/{print ($2*3600) + ($3*60) + $4}' | awk '{if ($1 < $LIMIT_SECONDS) print $1; else print $LIMIT_SECONDS}')
elif [ -n "$START_TIME" ] && [ -z "$END_TIME" ]; then
  END_TIME=$(awk "BEGIN {print $START_TIME + $LIMIT_SECONDS}")
elif [ -z "$START_TIME" ] && [ -n "$END_TIME" ]; then
  START_TIME=$(awk "BEGIN {print ($END_TIME - $LIMIT_SECONDS < 0) ? 0 : $END_TIME - $LIMIT_SECONDS}")
fi

existing_playback_effects=("boomerang")
if [ -n "$PLAYBACK_EFFECT" ]; then
  if ! [[ " ${existing_playback_effects[@]} " =~ " ${PLAYBACK_EFFECT} " ]]; then
    log_err "Playback effect not found."
    exit 1
  fi
fi

# validate the filter is in the list of existing filters
existing_filters=("test_filter")
filter_to_config_map=("test_filter:$FILTER_CONFIGS_PATH/test.yaml")

if [ -z "$FILTER" ]; then
  log_err "No filter provided."
  exit 1
fi

if ! [[ " ${existing_filters[@]} " =~ " ${FILTER} " ]]; then
  log_err "Filter not found."
  exit 1
fi

# get the configuration path for the filter
# is there a way to map, or should i eventually move to a programming language? i'm hoping to keep this as
# light and fast as possible to run ffmpeg commands
filter_config_path=""
for filter_config in "${filter_to_config_map[@]}"; do
  filter_name=$(echo $filter_config | cut -d':' -f1)
  filter_config_path=$(echo $filter_config | cut -d':' -f2)
  if [ "$filter_name" == "$FILTER" ]; then
    break
  fi
done

# configuration files are in the format of yaml
# metadata.name, metadata.description
# define.curve_path, define.lut_path

# read in the configuration file
curve_path=""
lut_path=""
fps=""
crf=""

# use yq to read in the configuration file into variables
curve_path=$(yq '.parameters.curve' < $filter_config_path)
lut_path=$(yq '.parameters.lut' < $filter_config_path)
fps=$(yq '.parameters.fps' < $filter_config_path)
crf=$(yq '.parameters.crf' < $filter_config_path)

# create the filter chain
# do a force scale for vertical
filterchain=("scale='if(gt($WIDTH/$HEIGHT,iw/ih),$WIDTH,iw*$HEIGHT/ih)':'if(gt($WIDTH/$HEIGHT,iw/ih),ih*$WIDTH/iw,$HEIGHT)':flags=fast_bilinear" "crop=$WIDTH:$HEIGHT:(in_w-$WIDTH)/2:(in_h-$HEIGHT)/2")
# auto-contrast/balance before applying the lut
filterchain+=("colorbalance=rs=.05:gs=.05:bs=.05" "lutyuv=y=gammaval(0.95)")

# Make sure it's set and not "null"
if [ -n "$lut_path" ] && [ "$lut_path" != "null" ]; then
  filterchain+=("lut3d=file=$LUTS_PATH/$lut_path")
fi

if [ -n "$curve_path" ] && [ "$curve_path" != "null" ]; then
  filterchain+=("curves=psfile=$CURVES_PATH/$curve_path")
fi

if [ -n "$fps" ] && [ "$fps" != "null" ]; then
  filterchain+=("fps=$fps")
fi

if [ -z "$crf" ] || [ "$crf" == "null" ]; then
  crf=18
fi

filterchain_string=$(IFS=,; echo "${filterchain[*]}")

# run ffmpeg command
ffmpeg -i $INPUT_PATH -ss $START_TIME -to $END_TIME -vf $filterchain_string -preset veryfast -threads 0 -an -crf $crf $OUTPUT_PATH -y

# Apply playback effect (boomerang, reverse, etc.)
if [ -n "$PLAYBACK_EFFECT" ]; then
  if [ "$PLAYBACK_EFFECT" == "boomerang" ]; then
    TMP_REVERSED=$(mktemp).mp4
    TMP_LIST=$(mktemp).txt
    TMP_FINAL=$(mktemp).mp4

    # Convert paths to absolute paths
    TMP_REVERSED_ABS=$(realpath "$TMP_REVERSED")
    TMP_LIST_ABS=$(realpath "$TMP_LIST")
    OUTPUT_PATH_ABS=$(realpath "$OUTPUT_PATH")
    TMP_FINAL_ABS=$(realpath "$TMP_FINAL")

    # Create a reversed version of the video (ensuring proper re-encoding)
    ffmpeg -i "$OUTPUT_PATH_ABS" -vf reverse -af areverse -preset veryfast -threads 0 -crf "$crf" -movflags faststart "$TMP_REVERSED_ABS" -y

    if [ ! -f "$TMP_REVERSED_ABS" ]; then
      log_err "Reversed video file was not created successfully."
      exit 1
    fi

    # Create a concat list file (with absolute paths & proper formatting)
    echo "file '$OUTPUT_PATH_ABS'" > "$TMP_LIST_ABS"
    echo "file '$TMP_REVERSED_ABS'" >> "$TMP_LIST_ABS"

    ffmpeg -f concat -safe 0 -i "$TMP_LIST_ABS" -c copy "$TMP_FINAL_ABS" -y

    mv "$TMP_FINAL_ABS" "$OUTPUT_PATH_ABS"

    rm "$TMP_REVERSED_ABS" "$TMP_LIST_ABS"
  fi
fi

# Add film grain to final output
grain_strength=$(yq '.parameters.postfilter.grain' < $filter_config_path)
if [ -z "$grain_strength" ] || [ "$grain_strength" == "null" ]; then
  grain_strength=0
fi

noise_strength=$(yq '.parameters.postfilter.noise' < $filter_config_path)
if [ -z "$noise_strength" ] || [ "$noise_strength" == "null" ]; then
  noise_strength=0
fi

rescale=$(yq '.parameters.postfilter.scale.div' < $filter_config_path)
if [ -z "$rescale" ] || [ "$rescale" == "null" ]; then
  rescale=1
fi

rescale_filter=$(yq '.parameters.postfilter.scale.filter' < $filter_config_path)
if [ -z "$rescale_filter" ] || [ "$rescale_filter" == "null" ]; then
  rescale_filter="neighbor"
fi

reblur_filter=$(yq '.parameters.postfilter.blur.filter' < $filter_config_path)
if [ -z "$reblur_filter" ] || [ "$reblur_filter" == "null" ]; then
  reblur_filter="smartblur"
fi

reblur_radius=$(yq '.parameters.postfilter.blur.radius' < $filter_config_path)
if [ -z "$reblur_radius" ] || [ "$reblur_radius" == "null" ]; then
  reblur_radius=0
fi

post_filterchain=("noise=alls=$noise_strength:allf=t+u" "noise=c0s=$grain_strength:c0f=t+u" "scale=iw/$rescale:ih/$rescale:flags=neighbor" "scale=$WIDTH:$HEIGHT:flags=$rescale_filter" "$reblur_filter=sigma=$reblur_radius")
post_filterchain_string=$(IFS=,; echo "${post_filterchain[*]}")

mv "$OUTPUT_PATH" "$OUTPUT_PATH-bk"

ffmpeg -i "$OUTPUT_PATH-bk" -vf "$post_filterchain_string" -c:a copy "$OUTPUT_PATH" -y

rm "$OUTPUT_PATH-bk"

# TODO: Add support for effect overlays + blending (ex. bokeh, light leaks, super 8, etc.)
# TODO: Setup the prefilters
#   - with the addition of these pre-filters, would it make most sense to _first_ process the video with the loop wanted, then apply the preFilter->lut/curve->postFilter?
#   - this was any grain added before effects does not get looped? or is it getting looped aesthetic?