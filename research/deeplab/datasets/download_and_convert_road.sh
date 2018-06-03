#!/bin/bash
# Copyright 2018 The TensorFlow Authors All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================
#
# Script to download and preprocess the road dataset.
#
# Usage:
#   bash ./download_and_convert_voc2012.sh
#
# The folder structure is assumed to be:
#  + datasets
#     - build_data.py
#     - build_voc2012_data.py
#     - download_and_convert_voc2012.sh
#     - remove_gt_colormap.py
#     + pascal_voc_seg
#       + VOCdevkit
#         + VOC2012
#           + JPEGImages
#           + SegmentationClass
#

# Exit immediately if a command exits with a non-zero status.
set -e

CURRENT_DIR=$(pwd)
WORK_DIR="./road_seg"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# Helper function to download and unpack VOC 2012 dataset.
download_and_uncompress() {
  local BASE_URL=${1}
  local FILENAME=${2}

  if [ ! -f "${FILENAME}" ]; then
    echo "Downloading ${FILENAME} to ${WORK_DIR}"
    wget -nd -c "${BASE_URL}" -O ${FILENAME}
  fi
  echo "Uncompressing ${FILENAME}"
  unzip "${FILENAME}"
}

# Download the images.
BASE_URL="https://drive.google.com/uc?export=download&id=1XU0YQkH5jEmg7OBXsH6uX1shCd7a2gRD"
FILENAME="training.zip"

download_and_uncompress "${BASE_URL}" "${FILENAME}"

cd "${CURRENT_DIR}"

# Root path for road dataset.
ROAD_ROOT="${WORK_DIR}/RoadsDevKit"

# Remove the colormap in the ground truth annotations.
SEG_FOLDER="${ROAD_ROOT}/SegmentationClass"
SEMANTIC_SEG_FOLDER="${ROAD_ROOT}/SegmentationClassRaw"

mkdir -p ${SEG_FOLDER} ${SEMANTIC_SEG_FOLDER}

echo $PWD
cp -r "${WORK_DIR}/training/groundtruth/." "${SEG_FOLDER}"

echo "Removing the color map in ground truth annotations..."
python ./remove_gt_colormap.py \
  --original_gt_folder="${SEG_FOLDER}" \
  --output_dir="${SEMANTIC_SEG_FOLDER}"

# Build TFRecords of the dataset.
# First, create output directory for storing TFRecords.
OUTPUT_DIR="${WORK_DIR}/tfrecord"
mkdir -p "${OUTPUT_DIR}"

IMAGE_FOLDER="${ROAD_ROOT}/JPEGImages"
LIST_FOLDER="${ROAD_ROOT}/ImageSets/Segmentation"

mkdir -p ${IMAGE_FOLDER} ${LIST_FOLDER}

cp -r "${WORK_DIR}/training/images/." "${IMAGE_FOLDER}"
touch "${LIST_FOLDER}/train.txt" ${LIST_FOLDER}/trainval.txt
ls "${WORK_DIR}/training/images/" | head -80 | sed -e 's/\.png$//'  > "${LIST_FOLDER}/train.txt"
ls "${WORK_DIR}/training/images/" | tail -20 | sed -e 's/\.png$//'  > "${LIST_FOLDER}/trainval.txt"

echo "Converting ROAD dataset..."
python ./build_road_data.py \
  --image_folder="${IMAGE_FOLDER}" \
  --semantic_segmentation_folder="${SEMANTIC_SEG_FOLDER}" \
  --list_folder="${LIST_FOLDER}" \
  --image_format="png" \
  --output_dir="${OUTPUT_DIR}"
