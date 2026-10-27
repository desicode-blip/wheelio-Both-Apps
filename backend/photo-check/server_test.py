import os
import unittest
from pathlib import Path
import cv2
import numpy as np
from server import compare, decode, quality

class PhotoChecks(unittest.TestCase):
    def test_bad_image_and_dark_frame_cannot_pass(self):
        with self.assertRaises(ValueError):
            decode("not-an-image")
        dark = np.zeros((480, 640, 3), np.uint8)
        self.assertEqual(quality(dark), "tooDark")
        self.assertEqual(compare(dark, dark)["status"], "retake")

    def test_small_or_obscured_capture_is_rejected(self):
        self.assertEqual(quality(np.ones((64, 64, 3), np.uint8)*120), "tooSmall")
        self.assertEqual(quality(np.ones((480, 640, 3), np.uint8)*120), "obscured")

    @unittest.skipUnless(os.environ.get("PHOTO_FIXTURE_DIR"), "Optional public scientific face fixtures")
    def test_one_to_one_reference_match_and_different_person_review(self):
        folder = Path(os.environ["PHOTO_FIXTURE_DIR"])
        reference = cv2.imread(str(folder / "nasa-astronaut.jpg"))
        other = cv2.imread(str(folder / "navy-grace-hopper.jpg"))
        self.assertIsNotNone(reference)
        self.assertIsNotNone(other)
        self.assertEqual(compare(reference, reference.copy())["status"], "candidateMatch")
        self.assertEqual(compare(reference, other)["status"], "review")

if __name__ == "__main__":
    unittest.main()
