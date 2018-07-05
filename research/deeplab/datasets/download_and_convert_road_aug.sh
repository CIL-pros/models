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
WORK_DIR="./road_seg_aug"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

SIGMA="1e-3"

# Helper function to download and unpack VOC 2012 dataset.
download_and_uncompress() {
  local BASE_URL=${1}
  local FILENAME=${2}

  if [ ! -f "${FILENAME}" ]; then
    echo "Downloading ${FILENAME} to ${WORK_DIR}"
    if [ ${FILENAME} = "training.zip" ]; then
      cp "../../../../../AugmentedDataSet.zip" "training.zip"
    elif [ ${FILENAME} = "test_images.tar.gz" ]; then
      wget -nd -c "${BASE_URL}" -O ${FILENAME}
    fi
  fi
  echo "Uncompressing ${FILENAME}"
  if [ ${FILENAME} = "training.zip" ]; then
    unzip "${FILENAME}"
    mkdir -p training
    cp -r "Untitled Folder/${SIGMA}/AugmentedImage" "./training/images"
    cp -r "Untitled Folder/${SIGMA}/AugmentedLabel" "./training/groundtruth"
  elif [ ${FILENAME} = "test_images.tar.gz" ]; then
    tar -xzf "${FILENAME}"
  fi
}

build_data() {
    local TRAIN_OR_TEST=${1}
    local ROAD_ROOT=${2}
    local RAW_ROOT=${3}
    local TFRECORD_DIR=${4}

    # Remove the colormap in the ground truth annotations.
    SEG_FOLDER="${ROAD_ROOT}/SegmentationClass"
    SEMANTIC_SEG_FOLDER="${ROAD_ROOT}/SegmentationClassRaw"

    mkdir -p ${SEG_FOLDER} ${SEMANTIC_SEG_FOLDER}

    echo $PWD
    cp -r "${RAW_ROOT}/groundtruth/." "${SEG_FOLDER}"

    echo "Removing the color map in ground truth annotations..."
    python ./remove_gt_colormap.py \
      --original_gt_folder="${SEG_FOLDER}" \
      --output_dir="${SEMANTIC_SEG_FOLDER}"

    # Build TFRecords of the dataset.
    # First, create output directory for storing TFRecords.
    mkdir -p "${TFRECORD_DIR}"

    IMAGE_FOLDER="${ROAD_ROOT}/JPEGImages"
    LIST_FOLDER="${ROAD_ROOT}/ImageSets/Segmentation"

    mkdir -p ${IMAGE_FOLDER} ${LIST_FOLDER}

    cp -r "${RAW_ROOT}/images/." "${IMAGE_FOLDER}"

    if [ "$TRAIN_OR_TEST" = "train" ]; then
        touch "${LIST_FOLDER}/train.txt" ${LIST_FOLDER}/trainval.txt
        ls "${RAW_ROOT}/images/" | head -4664 | sed -e 's/\.png$//'  > "${LIST_FOLDER}/train.txt"
        ls "${RAW_ROOT}/images/" | tail -1166 | sed -e 's/\.png$//'  > "${LIST_FOLDER}/trainval.txt"
    elif [ "$TRAIN_OR_TEST" = "test" ]; then
        touch "${LIST_FOLDER}/test.txt"
        ls "${RAW_ROOT}/images/" | sed -e 's/\.png$//'  > "${LIST_FOLDER}/test.txt"
    fi

    echo "Converting ROAD dataset..."
    python ./build_road_data.py \
      --image_folder="${IMAGE_FOLDER}" \
      --semantic_segmentation_folder="${SEMANTIC_SEG_FOLDER}" \
      --list_folder="${LIST_FOLDER}" \
      --image_format="png" \
      --output_dir="${TFRECORD_DIR}"
}

# Download the images.
BASE_TRAIN_URL="https://drive.google.com/uc?export=download&id=1XU0YQkH5jEmg7OBXsH6uX1shCd7a2gRD"
TRAIN_FILENAME="training.zip"

download_and_uncompress "${BASE_TRAIN_URL}" "${TRAIN_FILENAME}"

echo "Downloaded and uncompressed train images"

BASE_TEST_URL="https://drive.google.com/uc?export=download&id=195--p90lFpiqcdtNGpUq2RsGsKM-dZ5j"
TEST_FILENAME="test_images.tar.gz"

download_and_uncompress "${BASE_TEST_URL}" "${TEST_FILENAME}"

echo "Downloaded and uncompressed test images"

cd "${CURRENT_DIR}"

# Root path for road dataset.
ROAD_TRAIN_ROOT="${WORK_DIR}/RoadsTrainKit"
TRAIN_RAW_ROOT="${WORK_DIR}/training"
TF_TRAIN_RECORD_DIR="${WORK_DIR}/tfrecord/train"

build_data "train" "${ROAD_TRAIN_ROOT}" "${TRAIN_RAW_ROOT}" "${TF_TRAIN_RECORD_DIR}"

echo "Built training data"

TEST_RAW_ROOT="${WORK_DIR}/testing"
TEST_IMAGES_RAW="${TEST_RAW_ROOT}/images"
TEST_LABELS_RAW="${TEST_RAW_ROOT}/groundtruth"

mkdir -p ${TEST_IMAGES_RAW} ${TEST_LABELS_RAW}
cp -r "${WORK_DIR}/test_images/." "${TEST_IMAGES_RAW}"

for image_name in ${TEST_IMAGES_RAW}/*.png; do
    python resize_and_create_black_labels.py "${image_name}" "${image_name}" "${TEST_LABELS_RAW}/$(basename ${image_name})" 
    # convert "${image_name}" -resize 400x400! "${image_name}"
    # convert -size 400x400 xc:black "${TEST_LABELS_RAW}/$(basename ${image_name})"
done

ROAD_TEST_ROOT="${WORK_DIR}/RoadsTestKit"
TF_TEST_RECORD_DIR="${WORK_DIR}/tfrecord/test"

build_data "test" "${ROAD_TEST_ROOT}" "${TEST_RAW_ROOT}" "${TF_TEST_RECORD_DIR}"

echo "Built testing data"
