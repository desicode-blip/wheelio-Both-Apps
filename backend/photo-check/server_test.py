import os
import unittest
from unittest.mock import patch
from pathlib import Path
import cv2
import numpy as np
from server import compare, decode, quality, feature

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

    def test_camera_resolution_detection_maps_landmarks_to_original(self):
        photo = np.tile(np.arange(900, dtype=np.uint8)[None, :, None], (1600, 1, 3))
        face = np.array([[40, 60, 120, 160, 60, 90, 140, 90, 100, 130, 70, 170, 130, 170, .95]], np.float32)
        with patch('server.detector') as detector, patch('server.recognizer') as recognizer:
            detector.detect.return_value = (None, face)
            feature(photo)
            detector.setInputSize.assert_called_once_with((360, 640))
            original, mapped = recognizer.alignCrop.call_args.args
            self.assertIs(original, photo)
            np.testing.assert_allclose(mapped[:14], face[0, :14] / .4)
            self.assertAlmostEqual(float(mapped[14]), .95, places=5)

    def test_scaling_keeps_small_and_multiple_face_rejection(self):
        photo = np.tile(np.arange(900, dtype=np.uint8)[None, :, None], (1600, 1, 3))
        tiny = np.ones((1, 15), np.float32) * 10
        for faces in [None, np.vstack([tiny, tiny]), tiny]:
            with patch('server.detector') as detector, patch('server.recognizer') as recognizer:
                detector.detect.return_value = (None, faces)
                self.assertIsNone(feature(photo))
                recognizer.feature.assert_not_called()

    @unittest.skipUnless(os.environ.get("PHOTO_FIXTURE_DIR"), "Optional public scientific face fixtures")
    def test_one_to_one_reference_match_and_different_person_review(self):
        folder = Path(os.environ["PHOTO_FIXTURE_DIR"])
        reference = cv2.imread(str(folder / "nasa-astronaut.jpg"))
        other = cv2.imread(str(folder / "navy-grace-hopper.jpg"))
        self.assertIsNotNone(reference)
        self.assertIsNotNone(other)
        self.assertEqual(compare(reference, reference.copy())["status"], "candidateMatch")
        self.assertEqual(compare(reference, other)["status"], "review")
        large = cv2.resize(reference, None, fx=3, fy=3)
        self.assertEqual(compare(reference, large)["status"], "candidateMatch")

if __name__ == "__main__":
    unittest.main()
