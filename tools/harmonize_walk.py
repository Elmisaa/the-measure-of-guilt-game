#!/usr/bin/env python3
"""s01 walk scene: chunky-pixel the panorama (3x/4x) and grade Alexei's sprite into the room light
(darker, softer contrast, 30% toward the room tint, same pixel size). Run from the repo root."""
import sys; sys.path.insert(0,'tools')
from PIL import Image
import numpy as np
from pixelize import remove_background, harden_alpha
from slice_sheet import find_frames
D='art/drafts/walk_final/'
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
bg=Image.open(D+'pano_v1.png').convert('RGB')
res={}
for f in (3,4):
    w,h=round(bg.width/f),round(360/f)
    px=bg.resize((w,h),Image.BOX); big=px.resize((w*f,h*f),Image.NEAREST).crop((0,0,bg.width,360)) if h*f>=360 else px.resize((w*f,360),Image.NEAREST)
    big.save(D+f'px_pano_{f}x.png'); res[f]=(px,big)
# palette of the scene (k-means in Lab on the 4x small image)
small=np.asarray(res[4][0],dtype=np.float64).reshape(-1,3); lab=to_lab(small)
rng=np.random.default_rng(0); K=40; C=lab[rng.choice(len(lab),K,replace=False)]
for _ in range(25):
    d=((lab[:,None,:]-C[None])**2).sum(-1); idx=d.argmin(1)
    for k in range(K):
        if (idx==k).any(): C[k]=lab[idx==k].mean(0)
cent_rgb=np.array([small[idx==k].mean(0) if (idx==k).any() else [0,0,0] for k in range(K)])
# sprite frames (Alexei v3_a), common scale
img=remove_background(Image.open(D+'alexei_v3_a.png'),110)
crops=[]
for x0,x1 in find_frames(img,6,8):
    c=img.crop((x0,0,x1,img.height)); bb=c.getbbox(); crops.append(c.crop((0,bb[1],c.width,bb[3])))
tall=max(c.height for c in crops)
# walk-zone stats of the scene (wall + floor where he walks)
zone=to_lab(np.asarray(bg.crop((0,150,bg.width,360)),dtype=np.float64)).reshape(-1,3)
for f in (3,4):
    hh=round(200/f); k=hh/tall
    frames=[harden_alpha(c.convert('RGBa').resize((max(1,round(c.width*k)),hh if c.height==tall else max(1,round(c.height*k))),Image.BOX).convert('RGBA')) for c in crops]
    cw=max(fr.width for fr in frames)+2
    sheet=Image.new('RGBA',(cw*len(frames),hh),(0,0,0,0))
    for i,fr in enumerate(frames):
        arr=np.asarray(fr,dtype=np.float64); rgb=arr[...,:3]; al=arr[...,3]>0
        L=to_lab(rgb)
        # pull toward the scene: darker, cooler, less saturated; keep his own contrast
        sl=L[al]; m=sl.mean(0); s=sl.std(0)+1e-6; zm=zone.mean(0); zs=zone.std(0)
        # keep his own colours (navy uniform, skin) but sit him in the scene light:
        # a bit darker and lower contrast, less saturated, tinted toward the room's teal
        adj=sl.copy()
        adj[:,0]=(sl[:,0]-m[0])*0.85+m[0]*0.8
        adj[:,1:]=sl[:,1:]*0.7+zm[1:]*0.3
        out=rgb.copy(); out[al]=from_lab(adj)
        # drop magenta-tinted edge pixels left from the generator background
        mag=(rgb[...,0]-rgb[...,1]>40)&(rgb[...,2]-rgb[...,1]>30)
        arr[...,3]=np.where(mag,0,arr[...,3])
        o=np.dstack([out,arr[...,3]]).astype(np.uint8)
        sheet.paste(Image.fromarray(o,'RGBA'),(i*cw+(cw-fr.width)//2,hh-fr.height))
    sheet=sheet.resize((sheet.width*f,sheet.height*f),Image.NEAREST); sheet.save(D+f'alexei_{f}x_sheet.png')
    one=sheet.crop((4*cw*f,0,5*cw*f,sheet.height))
    scr=res[f][1].convert('RGBA').crop((560,0,1200,360)); scr.alpha_composite(one,(240,360-8-one.height)); scr.convert('RGB').save(D+f'screen_{f}x.png')
    # gif
    frs=[]
    for i in range(2,10):
        fr=Image.new('RGBA',(cw*f+40,hh*f+20),(24,28,34,255)); fr.alpha_composite(sheet.crop((i*cw*f,0,(i+1)*cw*f,sheet.height)),(20,10)); frs.append(fr.convert('RGB').resize(((cw*f+40)*2,(hh*f+20)*2),Image.NEAREST))
    frs[0].save(D+f'alexei_{f}x_walk.gif',save_all=True,append_images=frs[1:],duration=100,loop=0)
print('ok')
