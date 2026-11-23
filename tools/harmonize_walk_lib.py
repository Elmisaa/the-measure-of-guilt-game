import numpy as np
def to_lab(a):
    a=a/255.0; a=np.where(a>0.04045,((a+0.055)/1.055)**2.4,a/12.92)
    M=np.array([[0.4124,0.3576,0.1805],[0.2126,0.7152,0.0722],[0.0193,0.1192,0.9505]])
    xyz=a@M.T/np.array([0.9505,1,1.089]); f=np.where(xyz>0.008856,np.cbrt(xyz),7.787*xyz+16/116)
    return np.stack([116*f[...,1]-16,500*(f[...,0]-f[...,1]),200*(f[...,1]-f[...,2])],-1)
def from_lab(L):
    fy=(L[...,0]+16)/116; fx=fy+L[...,1]/500; fz=fy-L[...,2]/200
    def inv(t): return np.where(t**3>0.008856,t**3,(t-16/116)/7.787)
    xyz=np.stack([inv(fx)*0.9505,inv(fy),inv(fz)*1.089],-1)
    Mi=np.linalg.inv(np.array([[0.4124,0.3576,0.1805],[0.2126,0.7152,0.0722],[0.0193,0.1192,0.9505]]))
    rgb=xyz@Mi.T; rgb=np.where(rgb>0.0031308,1.055*np.power(np.clip(rgb,0,None),1/2.4)-0.055,12.92*rgb)
    return np.clip(rgb*255,0,255)
