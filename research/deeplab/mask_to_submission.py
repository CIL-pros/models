#!/usr/bin/env python3

import os
import numpy as np
import matplotlib.image as mpimg
import re
from optparse import OptionParser

foreground_threshold = 0.25  # percentage of pixels > 1 required to assign a foreground label to a patch

test_set_order = ['test_10', 'test_105', 'test_106', 'test_107', 'test_108', 'test_11', 'test_115', 'test_116', 'test_12', 'test_121', 'test_122', 'test_123', 'test_124', 'test_128', 'test_129', 'test_130', 'test_131', 'test_136', 'test_137', 'test_138', 'test_139', 'test_14', 'test_140', 'test_142', 'test_143', 'test_144', 'test_145', 'test_15', 'test_151', 'test_152', 'test_153', 'test_154', 'test_155', 'test_157', 'test_159', 'test_161', 'test_162', 'test_168', 'test_169', 'test_170', 'test_174', 'test_175', 'test_176', 'test_177', 'test_186', 'test_187', 'test_189', 'test_190', 'test_191', 'test_192', 'test_196', 'test_200', 'test_201', 'test_202', 'test_204', 'test_205', 'test_206', 'test_207', 'test_208', 'test_21', 'test_211', 'test_215', 'test_216', 'test_218', 'test_219', 'test_220', 'test_221', 'test_222', 'test_223', 'test_23', 'test_25', 'test_26', 'test_27', 'test_29', 'test_36', 'test_40', 'test_41', 'test_49', 'test_50', 'test_51', 'test_54', 'test_61', 'test_64', 'test_65', 'test_69', 'test_7', 'test_76', 'test_79', 'test_8', 'test_80', 'test_9', 'test_90', 'test_92', 'test_93'] 


# assign a label to a patch
def patch_to_label(patch):
    df = np.mean(patch)
    if df > foreground_threshold:
        return 1
    else:
        return 0


def mask_to_submission_strings(image_filename):
    """Reads a single image and outputs the strings that should go into the submission file"""
    img_number = int(re.search(r"\d+", image_filename).group(0))
    test_img_number = int(re.search(r"\d+", test_set_order[img_number]).group(0))
    im = mpimg.imread(image_filename)
    im[im > 0] = 1  # make sure labels are set to 1
    patch_size = 16
    for j in range(0, im.shape[1], patch_size):
        for i in range(0, im.shape[0], patch_size):
            patch = im[i:i + patch_size, j:j + patch_size]
            label = patch_to_label(patch)
            yield ("{:03d}_{}_{},{}".format(test_img_number, j, i, label))


def masks_to_submission(submission_filename, *image_filenames):
    """Converts images into a submission file"""
    with open(submission_filename, 'w') as f:
        f.write('id,prediction\n')
        for fn in image_filenames[0:]:
            f.writelines('{}\n'.format(s) for s in mask_to_submission_strings(fn))


def create_parser():
    parser = OptionParser()
    parser.add_option('-d', '--image-directory',
                      dest='directory_in_str',
                      default='datasets/road_seg/exp/train_seg_with_test/vis/segmentation_results',
                      help='Path to folder with segmentation results. It is assumed that'
                           'prediction files will contain word \"prediction\".')
    parser.add_option('-o', '--output-file',
                      dest='output_file',
                      default='submission.csv',
                      help='Path to output submission file.')
    return parser


if __name__ == '__main__':
    # Load command input options
    options, remainder = create_parser().parse_args()
    directory = os.fsencode(options.directory_in_str)
    image_filenames = []
    for file in sorted(os.listdir(directory)):
        filename = os.fsdecode(file)
        print(filename)
        if 'prediction' in filename:
            image_filenames.append('{}/{}'.format(options.directory_in_str, filename))
    masks_to_submission(options.output_file, *image_filenames)
