#!/usr/bin/env python3
"""Projected-gradient learning of a legal nonnegative symmetric 5-tap FIR.

Synthetic denoising benchmark, disjoint train/validation/test seeds. This is
a learned linear filter, not a claim of a trained CNN or natural-image quality.
"""
import argparse
import hashlib
import json
import time
from pathlib import Path
import numpy as np


def dataset(seed, count):
    rng=np.random.default_rng(seed)
    y,x=np.mgrid[:32,:32]
    clean=[]; noisy=[]
    for _ in range(count):
        a=480+150*np.sin(y/rng.uniform(5,12)+rng.uniform(0,6))+100*np.cos(x/rng.uniform(5,10))
        a+=rng.uniform(30,100)*(x>rng.integers(8,24))
        a=np.clip(a,0,1023)
        clean.append(a); noisy.append(np.clip(a+rng.normal(0,45,a.shape),0,1023))
    return np.array(clean),np.array(noisy)


def features(noisy):
    p=np.pad(noisy,((0,0),(2,2),(0,0)),mode='symmetric')
    return np.stack((noisy,(p[:,1:-3]+p[:,3:-1])/2,(p[:,:-4]+p[:,4:])/2),axis=-1)


def simplex(v):
    u=np.sort(v)[::-1]; css=np.cumsum(u)-1
    rho=np.nonzero(u-css/np.arange(1,len(u)+1)>0)[0][-1]
    return np.maximum(v-css[rho]/(rho+1),0)


def quantize(alpha):
    # 64 units: center uses 2 per unit, each symmetric side uses 1.
    scaled=alpha*64; q=np.floor(scaled).astype(int)
    for i in np.argsort(-(scaled-q))[:64-int(q.sum())]: q[i]+=1
    return np.array([q[2],q[1],2*q[0],q[1],q[2]],dtype=int)


def apply_integer(noisy, coeff):
    data=np.rint(noisy).astype(np.int64)
    p=np.pad(data,((0,0),(2,2),(0,0)),mode='symmetric')
    acc=sum(int(coeff[k])*p[:,k:k+data.shape[1]] for k in range(5))
    return np.clip((acc+64)>>7,0,1023)


def run(output, seed):
    t=time.perf_counter(); output.mkdir(parents=True,exist_ok=True)
    tr,nt=dataset(seed,12); va,nv=dataset(seed+1,4); te,ne=dataset(seed+2,4)
    X=features(nt).reshape(-1,3)/1023; target=tr.ravel()/1023
    V=features(nv)/1023
    gram=X.T@X/len(X); rhs=X.T@target/len(X)
    # The equality constraint removes the common-mode direction. Use the
    # tangent-space curvature to avoid needlessly slow projected steps.
    tangent=np.eye(3)-np.ones((3,3))/3
    lr=1/(2*np.linalg.eigvalsh(tangent@gram@tangent).max())
    alpha=np.array([1.,0,0]); best=alpha.copy(); bestloss=float('inf'); trace=[]
    for step in range(400):
        alpha=simplex(alpha-lr*2*(gram@alpha-rhs))
        loss=float(np.mean((V@alpha-va/1023)**2))
        if loss<bestloss: bestloss=loss; best=alpha.copy()
        if step%20==0: trace.append({'step':step,'validation_mse_normalized':loss})
    coeff=quantize(best)
    assert (coeff>=0).all() and coeff.sum()==128 and np.array_equal(coeff,coeff[::-1])
    rows={}
    for name,pred in [('identity',np.rint(ne)),('fixed_binomial',apply_integer(ne,[8,32,48,32,8])),
                      ('fixed_near_uniform',apply_integer(ne,[26,25,26,25,26])),
                      ('learned_float',features(ne)@best),('learned_integer',apply_integer(ne,coeff))]:
        mse=float(np.mean((pred-te)**2)); rows[name]={'mse':mse,'psnr_db':float(10*np.log10(1023**2/mse))}
    result={'benchmark':'synthetic grayscale denoising; not natural-image validation',
            'seed':seed,'train_frames':12,'validation_frames':4,'test_frames':4,
            'coefficients_full':coeff.tolist(),'coefficient_half':coeff[:3].tolist(),
            'alpha_center_pair1_pair2':best.tolist(),'test_metrics':rows,'training_trace':trace,
            'data_sha256':hashlib.sha256(te.tobytes()+ne.tobytes()).hexdigest(),
            'baseline_note':'near-uniform baseline added to avoid attributing all smoothing benefit to learning; no universal superiority claimed',
            'wall_seconds':time.perf_counter()-t}
    (output/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    (output/'coef_half.hex').write_text(f'{sum(int(v)<<(8*i) for i,v in enumerate(coeff[:3])):050x}\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--output',type=Path,default=Path('experiments/learned_fir/results'))
    p.add_argument('--seed',type=int,default=20260910); a=p.parse_args(); run(a.output,a.seed)
