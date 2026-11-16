from pathlib import Path
import json
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent.parent
brand = root / 'assets/branding'
brand.mkdir(parents=True, exist_ok=True)
paths = [
 ('M512 740 C522 650 518 598 506 532', '#f7f6ed', False, 50),
 ('M506 532 C350 539 279 435 292 318 C440 311 539 408 506 532 Z', '#f0f1e4', True, 0),
 ('M518 605 C514 451 630 371 756 377 C775 512 661 625 518 605 Z', '#cad4b7', True, 0),
 ('M375 755 C460 780 565 780 650 755', '#a8b99c', False, 25),
]
svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="#354b3d"/>'
for path, color, filled, stroke in paths:
    svg += f'<path d="{path}" fill="{color if filled else "none"}" stroke="{color if not filled else "none"}" stroke-width="{stroke}" stroke-linecap="round"/>'
svg += '</svg>'
(brand / 'growza-mark.svg').write_text(svg, encoding='utf-8')

def points(path):
    values = path.replace('M',' M ').replace('C',' C ').replace('Z',' Z ').split()
    i = 0
    result = []
    while i < len(values):
        command = values[i]; i += 1
        if command == 'M':
            current = tuple(float(x) for x in values[i:i+2]); i += 2; result.append(current)
        elif command == 'C':
            control = [tuple(float(x) for x in values[j:j+2]) for j in range(i,i+6,2)]; i += 6
            a = current; b,c,d = control
            for step in range(1,61):
                t=step/60; u=1-t
                result.append(tuple(u**3*a[k]+3*u*u*t*b[k]+3*u*t*t*c[k]+t**3*d[k] for k in (0,1)))
            current=d
    return result

master=Image.new('RGB',(2048,2048),'#354b3d')
draw=ImageDraw.Draw(master)
for path,color,filled,stroke in paths:
    pts=[(round(x*2),round(y*2)) for x,y in points(path)]
    if filled: draw.polygon(pts,fill=color)
    else:
        draw.line(pts,fill=color,width=stroke*2,joint='curve')
        for x,y in (pts[0],pts[-1]): draw.ellipse((x-stroke,y-stroke,x+stroke,y+stroke),fill=color)

def save(path,size):
    path.parent.mkdir(parents=True,exist_ok=True)
    master.resize((size,size),Image.Resampling.LANCZOS).save(path)

save(brand/'growza-icon.png',256)
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    save(root/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png',size)
icons=root/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for icon in json.loads((icons/'Contents.json').read_text())['images']:
    save(icons/icon['filename'],round(float(icon['size'].split('x')[0])*float(icon['scale'][:-1])))
for name,size in [('Icon-192.png',192),('Icon-512.png',512),('Icon-maskable-192.png',192),('Icon-maskable-512.png',512)]:
    save(root/'web/icons'/name,size)
save(root/'web/favicon.png',32)
res=root/'android/app/src/main/res'
(res/'mipmap-anydpi-v26').mkdir(exist_ok=True)
(res/'mipmap-anydpi-v26/ic_launcher.xml').write_text('<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@drawable/growza_launcher_background"/><foreground android:drawable="@drawable/growza_launcher_foreground"/></adaptive-icon>',encoding='utf-8')
(res/'drawable/growza_launcher_background.xml').write_text('<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="#354b3d"/></shape>',encoding='utf-8')
vector='<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="1024" android:viewportHeight="1024">'
for path,color,filled,stroke in paths:
    vector += f'<path android:pathData="{path}" android:fillColor="{color if filled else "#00000000"}" android:strokeColor="{color if not filled else "#00000000"}" android:strokeWidth="{stroke}" android:strokeLineCap="round"/>'
vector += '</vector>'
(res/'drawable/growza_launcher_foreground.xml').write_text(vector,encoding='utf-8')
manifest=root/'web/manifest.json'
data=json.loads(manifest.read_text(encoding='utf-8-sig'));data['background_color']='#f7f6f2';data['theme_color']='#354b3d'
manifest.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
for scale in [1,2,3]:
    name='LaunchImage'+('' if scale == 1 else f'@{scale}x')+'.png'
    save(root/'ios/Runner/Assets.xcassets/LaunchImage.imageset'/name,128*scale)
print('Generated Growza launcher icons for Android, iOS and web from the vector mark.')
