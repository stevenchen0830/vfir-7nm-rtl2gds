import importlib.util
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]


def load(path):
    spec=importlib.util.spec_from_file_location('tested',ROOT/path)
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


class PublicReproductionTests(unittest.TestCase):
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
