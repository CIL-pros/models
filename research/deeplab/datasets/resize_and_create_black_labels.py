import sys
import warnings
import numpy as np
from skimage.transform import resize
from skimage.io import imread, imsave


with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    image = imread(sys.argv[1])
    image_resized = image # resize(image, (400, 400))
    imsave(sys.argv[2], image_resized)
    imsave(sys.argv[3], np.zeros_like(image_resized))
