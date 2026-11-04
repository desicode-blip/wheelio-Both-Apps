"""Meaningful regression tests for the ELF checker; no SDK or credentials needed."""
import importlib.util
from pathlib import Path
import struct
import unittest

spec = importlib.util.spec_from_file_location('validator', Path(__file__).with_name('verify-android-store.py'))
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class ElfCheckTest(unittest.TestCase):
    def fixture(self, align):
        data = bytearray(120)
        data[:6] = b'\x7fELF\x02\x01'
        struct.pack_into('<Q', data, 32, 64)
        struct.pack_into('<HH', data, 54, 56, 1)
        struct.pack_into('<I', data, 64, 1)
        struct.pack_into('<Q', data, 112, align)
        return data

    def test_reads_load_alignment_not_other_header_bytes(self):
        self.assertEqual(validator.elf_alignment(self.fixture(16384)), [16384])
        self.assertEqual(validator.elf_alignment(self.fixture(4096)), [4096])

    def test_rejects_32_bit_or_truncated_table(self):
        with self.assertRaises(ValueError):
            validator.elf_alignment(b'not ELF')
        with self.assertRaises(ValueError):
            validator.elf_alignment(self.fixture(16384)[:90])


if __name__ == '__main__':
    unittest.main()
