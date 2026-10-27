"""Native review mockups from generated studies. Never edits production art."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[4];sys.path.insert(0,str(ROOT/'tools'))
import micro_asset
PAL={n:tuple(bytes.fromhex(v))+(255,) for n,v in micro_asset.palette().items()}
steel=['ol0','gray1','gray2','gray3','gray4','gray5','orange1','orange2']
parts={
'decal_vehicle_pillar_joint':{'tier':'van','source_box':[38,153,7,7],'size':[6,6],'palette':steel,'label':'PILLAR JOINT'},
'decal_vehicle_roof_seam':{'tier':'van','source_box':[215,148,14,6],'size':[12,6],'palette':steel,'label':'ROOF SEAM'},
'decal_vehicle_fuel_cap':{'tier':'van','source_box':[74,274,9,9],'size':[8,8],'palette':steel,'label':'FUEL CAP'},
'decal_van_door_hardware':{'tier':'van','source_box':[16,185,14,10],'size':[14,10],'palette':['ol0','blue1','blue2','blue3','blue4','gray3','gray5','orange1'],'label':'VAN HANDLE'},
'decal_bus_service_vent':{'tier':'bus','source_box':[10,153,20,13],'size':[12,8],'palette':['ol0','yellow1','yellow2','gray1','gray3','gray5','orange1'],'label':'BUS VENT'},
'decal_rig_door_latch':{'tier':'rig','source_box':[21,213,13,7],'size':[8,6],'palette':['ol0','red1','red2','gray1','gray3','gray5','orange1'],'label':'RIG LATCH'},
'decal_train_access_hinges':{'tier':'train','source_box':[9,116,15,17],'size':[10,8],'palette':['ol0','gray2','gray3','gray4','gray5','orange1'],'label':'TRAIN HINGES'}}
def snap(im,palette):
 out=Image.new('RGBA',im.size);colors={n:PAL[n] for n in palette}
 for y in range(im.height):
  for x in range(im.width):
   q=im.getpixel((x,y));n=min(colors,key=lambda n:sum((q[k]-colors[n][k])**2 for k in range(3)))
   out.putpixel((x,y),colors[n])
 return out
def cleanup(sid,im):
 # Native-grid simplification: keep fasteners, slots and latches readable at1x.
 d=ImageDraw.Draw(im)
 def r(box,c):d.rectangle(box,fill=PAL[c])
 if sid=='decal_vehicle_pillar_joint':
  r((0,0,5,5),'ol0');r((1,1,4,4),'gray3');r((1,1,4,1),'gray4')
  r((1,1,1,1),'gray5');r((1,2,1,2),'gray1');r((4,3,4,3),'gray5');r((4,4,4,4),'gray1');r((2,4,2,4),'orange1')
 elif sid=='decal_vehicle_roof_seam':
  r((0,0,11,5),'ol0');r((1,1,10,4),'gray3');r((1,1,10,1),'gray4')
  for x in (2,9):r((x,2,x,2),'gray5');r((x,3,x,3),'gray1')
  r((4,4,5,4),'orange1')
 elif sid=='decal_van_door_hardware':
  r((0,0,13,9),'blue2');r((1,1,3,8),'ol0');r((2,2,2,7),'gray3')
  for y in (2,7):r((2,y,2,y),'gray5')
  r((4,3,11,6),'ol0');r((5,4,10,5),'gray3');r((5,4,9,4),'gray5');r((3,8,3,8),'orange1')
 elif sid=='decal_bus_service_vent':
  r((0,0,11,7),'yellow2');r((1,0,10,7),'ol0');r((2,1,9,6),'gray3');r((2,1,2,6),'gray5')
  for y in (2,4,6):r((3,y,8,y),'gray1')
  r((1,1,1,1),'gray5');r((10,6,10,6),'orange1')
 elif sid=='decal_rig_door_latch':
  r((0,0,7,5),'red2');r((1,1,6,4),'ol0');r((2,2,5,3),'gray3');r((2,2,4,2),'gray5');r((6,4,6,4),'orange1')
 elif sid=='decal_train_access_hinges':
  r((0,0,9,7),'gray3');r((0,0,2,7),'ol0');r((1,1,1,6),'gray4')
  for y in (1,5):r((2,y,8,y+1),'ol0');r((2,y,7,y),'gray4');r((2,y,2,y),'gray5')
  r((7,6,7,6),'orange1')
 return im
studies={t:Image.open(HERE/(t+'-detail-study.png')).convert('RGBA').resize((280,300),Image.Resampling.BOX) for t in ['van','bus','rig','train']}
font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',17);small=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',13)
partboard=Image.new('RGB',(960,384),'#18181c');pd=ImageDraw.Draw(partboard)
for i,(sid,p) in enumerate(parts.items()):
 x,y,w,h=p['source_box'];raw=studies[p['tier']].crop((x,y,x+w,y+h))
 out=cleanup(sid,snap(raw.resize(tuple(p['size']),Image.Resampling.BOX),p['palette']));out.save(HERE/(sid+'-draft.png'))
 p['native_rgba_sha256']=hashlib.sha256(out.tobytes()).hexdigest()
 cx=(i%4)*240;cy=(i//4)*192;pd.text((cx+10,cy+8),p['label'],font=font,fill='#b2a88a')
 big=out.resize((out.width*10,out.height*10),Image.Resampling.NEAREST);partboard.paste(big,(cx+(240-big.width)//2,cy+48),big)
 pd.text((cx+10,cy+167),str(out.width)+'x'+str(out.height),font=small,fill='#908670')
placements={};floors={'van':2,'bus':3,'rig':4,'train':4,'trailer':2,'wagon':2}
for tier,count in floors.items():
 xs=[16,218] if tier in ('trailer','wagon') else [38,248]
 placements[tier]=[{'id':'decal_vehicle_pillar_joint','anchor':[x,204-56*f]} for f in range(count) for x in xs]
 placements[tier].append({'id':'decal_vehicle_roof_seam','anchor':[206 if tier in ('trailer','wagon') else 216,204-56*(count-1)]})
 if tier in ('van','bus','rig'):placements[tier].append({'id':'decal_vehicle_fuel_cap','anchor':[74,274]})
 specific={'van':('decal_van_door_hardware',[16,185]),'bus':('decal_bus_service_vent',[20,182]),'rig':('decal_rig_door_latch',[26,214]),'train':('decal_train_access_hinges',[10,118])}.get(tier)
 if specific:placements[tier].append({'id':specific[0],'anchor':specific[1]})
manifest={'status':'visual proposal; not yet approved production artwork','reference':'first vehicle tier: actual blue van','native_cleanup':'integer-grid simplification of generated hardware; readable bolt/slot/hinge clusters; draft only','scope':'4 main vehicles plus shared trailer/wagon fittings','parts':parts,'placements':placements,'vehicles':{}}
board=Image.new('RGB',(1200,1320),'#18181c');d=ImageDraw.Draw(board)
for i,tier in enumerate(floors):
 before=Image.open(HERE/('reference-'+tier+'-native.png')).convert('RGBA');after=before.copy();mask=Image.new('1',before.size);md=ImageDraw.Draw(mask)
 for placement in placements[tier]:
  x,y=placement['anchor'];part=Image.open(HERE/(placement['id']+'-draft.png')).convert('RGBA')
  assert before.crop((x,y,x+part.width,y+part.height)).getchannel('A').getextrema()==(255,255),(tier,placement)
  after.paste(part,(x,y));md.rectangle((x,y,x+part.width-1,y+part.height-1),fill=1)
 for y in range(before.height):
  for x in range(before.width):
   if not mask.getpixel((x,y)):assert before.getpixel((x,y))==after.getpixel((x,y))
 assert before.getchannel('A').tobytes()==after.getchannel('A').tobytes()
 after.save(HERE/(tier+'-native-proposal.png'));after.resize((after.width*4,1200),Image.Resampling.NEAREST).save(HERE/(tier+'-proposal-4x.png'))
 manifest['vehicles'][tier]={'size':list(after.size),'sha256':hashlib.sha256(after.tobytes()).hexdigest(),'outside_fittings_unchanged':True,'silhouette_alpha_unchanged':True}
 if i<4:
  cx=(i%2)*600;cy=(i//2)*650
  d.text((cx+16,cy+12),str(i+1)+'. '+tier.upper()+(' - FIRST CAR REFERENCE' if tier=='van' else ' - VAN HARDWARE STYLE'),font=font,fill='#b2a88a')
  big=after.resize((560,600),Image.Resampling.NEAREST);board.paste(big,(cx+20,cy+40),big)
partboard.save(HERE/'micro-details-closeup.png');board.save(HERE/'all-vehicles-detail-proposal.png')
(HERE/'proposal-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('Native proposal: 7 detail assets;4 main vehicles+trailer/wagon. Master palettes; exact existing silhouette; only declared fitting boxes changed.')

