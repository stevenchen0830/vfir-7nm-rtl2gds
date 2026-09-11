import importlib.util
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]


def load(path):
    spec=importlib.util.spec_from_file_location('tested',ROOT/path)
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


class PublicReproductionTests(unittest.TestCase):
    def test_binary_versions_cannot_be_inferred_from_checkout(self):
        preflight=load('tools/preflight.py')
        self.assertTrue(preflight.version_matches('openroad','26Q3-1499-g46ab99414e'))
        self.assertFalse(preflight.version_matches('openroad','different-build'))
        self.assertFalse(preflight.version_matches('sta','3.2.0'))
        self.assertTrue(preflight.version_matches('yosys','Yosys 0.68+ (git sha1 a5af9d690)'))

    def test_windows_and_posix_manifest_paths(self):
        paths=load('tools/evidence_paths.py')
        self.assertEqual(paths.evidence_path(ROOT,r'experiments\cnn\rtl\int8_dw3x1.sv'),
                         paths.evidence_path(ROOT,'experiments/cnn/rtl/int8_dw3x1.sv'))
        self.assertTrue(paths.evidence_path(ROOT,r'experiments\cnn\rtl\int8_dw3x1.sv').is_file())
        for bad in ['../outside',r'..\outside','/tmp/outside',r'C:\outside']:
            with self.assertRaises(ValueError): paths.evidence_path(ROOT,bad)

    def test_asset_paths_reject_traversal(self):
        fetch=load('tools/fetch_v4_release.py')
        fetch.check_name('6_final.v.gz')
        for bad in ['../x','..','/tmp/x','a\\b','a/b']:
            with self.assertRaises(ValueError): fetch.check_name(bad)

    def test_variant_is_deterministic_and_has_one_mac(self):
        build=load('experiments/fir_pipeline/build_variant.py')
        first=build.generate()
        self.assertEqual(first,build.generate())
        self.assertEqual(first.count(b'fir_mac_pipeline u_mac'),1)
        self.assertNotIn(b'pair_q',first)
        self.assertIn(b'wire opush = pipe_en & mac_valid;',first)
        self.assertIn(b'if (out_d1) rdata_q <= mem_rdata;',first)


if __name__=='__main__': unittest.main()
