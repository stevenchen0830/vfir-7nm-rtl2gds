import importlib.util
import random
import unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('cnn_test',Path(__file__).resolve().parents[1]/'experiments/cnn/test_cnn.py')
cnn=importlib.util.module_from_spec(spec); spec.loader.exec_module(cnn)


class QuantizationTests(unittest.TestCase):
    def test_narrow_rounding_matches_independent_abs_reference(self):
        rng=random.Random(20260911)
        lo=-(2**31)-3*16256
        hi=(2**31-1)+3*16384
        for shift in range(32):
            half=2**(shift-1) if shift else 0
            samples=[lo,hi,-1,0,1,-half,half,-half-1,half+1]
            samples += [rng.randint(lo,hi) for _ in range(1000)]
            for acc in samples:
                rounded=acc+half-int(acc<0) if shift else acc
                self.assertTrue(-(2**32)<=rounded<2**32, '33-bit overflow')
                for relu in [False,True]:
                    result=max(0 if relu else -128,min(127,rounded>>shift))
                    self.assertEqual(result,cnn.quant(acc,shift,relu),(acc,shift,relu))


if __name__=='__main__': unittest.main()
