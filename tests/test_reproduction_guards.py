import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def module(name, relative):
    spec = importlib.util.spec_from_file_location(name, REPO/relative)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


checkpoint = module('checkpoint', 'tools/checkpoint_guard.py')
search = module('search', 'experiments/eda_search/search.py')
closure = module('closure', 'tools/run_closure_matrix.py')
sys.path.insert(0,str(REPO/'tools'))
promotion = module('promotion', 'tools/check_closure.py')


class CheckpointTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.stamp = self.root/'new.inputs'; self.stamp.write_text('input hashes')
        self.roots = [self.root/x for x in ['results','logs','reports']]

    def test_fresh_and_matching_resume(self):
        checkpoint.guard(self.roots, self.stamp)
        (self.roots[0]/'4_cts.odb').write_bytes(b'checkpoint')
        checkpoint.guard(self.roots, self.stamp)

    def test_changed_inputs_rejected(self):
        checkpoint.guard(self.roots, self.stamp)
        self.stamp.write_text('different hashes')
        with self.assertRaises(ValueError): checkpoint.guard(self.roots, self.stamp)

    def test_unstamped_results_logs_reports_rejected(self):
        for root in self.roots:
            with self.subTest(root=root.name):
                root.mkdir(); stale=root/'old'; stale.write_text('stale')
                with self.assertRaises(ValueError): checkpoint.guard(self.roots, self.stamp)
                self.assertFalse((self.roots[0]/'reproduction.inputs').exists())
                stale.unlink(); root.rmdir()


class CacheTests(unittest.TestCase):
    def test_raw_and_summary_both_checked(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); metric=root/'a.metrics.json'; cache=root/'a.json'
            metric.write_text(json.dumps({'xdesign__instance__area__stdcell': 1,
                 'xtiming__setup__ws': 2, 'xtiming__hold__ws': 3, 'xpower__total': 4}))
            row={'metrics_sha256': search.sha(metric), 'area_um2': 1,
                 'setup_ws_ps': 2, 'hold_ws_ps': 3, 'power_w': 4}
            cache.write_text(json.dumps(row))
            self.assertEqual(search.load_cached(cache,metric),row)
            row['area_um2']=5; cache.write_text(json.dumps(row))
            with self.assertRaises(ValueError): search.load_cached(cache,metric)
            row['area_um2']=1; cache.write_text(json.dumps(row))
            metric.write_text(metric.read_text()+'\n')
            with self.assertRaises(ValueError): search.load_cached(cache,metric)


class ClosureTests(unittest.TestCase):
    def report(self, overrides=None):
        values = {key: 0 for key in closure.REQUIRED}
        values.update(setup_ws_ps=1.0,hold_ws_ps=0.1)
        values.update(overrides or {})
        return ''.join(f'METRIC {k} {v}\n' for k,v in values.items())+'CLOSURE_AUDIT_DONE\n'

    def test_complete_pass(self):
        self.assertTrue(closure.parse_report(self.report())[1])

    def test_missing_corner_cannot_pass_promotion(self):
        with tempfile.TemporaryDirectory() as tmp:
            matrix=Path(tmp)/'matrix.json'
            for rows in [[],[{'corner':'FF'}],[{'corner':'FF'}]*3]:
                matrix.write_text(json.dumps({'views':rows}))
                with self.assertRaises(ValueError): promotion.check(matrix)

    def test_one_violation_is_failure(self):
        for key,value in [('setup_ws_ps',-0.0001), ('hold_tns_ps',-1), ('slew_violations',1),
                          ('cap_violations',1), ('setup_endpoints',1)]:
            with self.subTest(key=key): self.assertFalse(closure.parse_report(self.report({key:value}))[1])

    def test_missing_duplicate_error_nonfinite_rejected(self):
        texts=[self.report().replace('CLOSURE_AUDIT_DONE',''),
               self.report()+'METRIC slew_violations 0\n',
               self.report()+'Error: failed\n', self.report({'hold_ws_ps':'nan'}),
               self.report({'cap_violations':-1}), self.report({'cap_violations':0.5}),
               'CLOSURE_AUDIT_DONE\n']
        for text in texts:
            with self.subTest(text=text):
                with self.assertRaises(ValueError): closure.parse_report(text)


if __name__ == '__main__': unittest.main()
