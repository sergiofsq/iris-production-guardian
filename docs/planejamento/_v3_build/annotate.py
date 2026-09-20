from PIL import Image, ImageDraw, ImageFont
U="/mnt/user-data/uploads/IRIS Production Guardian/"
M=U+"entregaveis/manual_assets/"
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
def annotate(src,out,targets,crop=None,width=None):
    im=Image.open(src).convert("RGB")
    dy=0
    if crop:
        im=im.crop(crop); dy=crop[1]
    d=ImageDraw.Draw(im)
    sc=max(1,im.width/1314)
    f=ImageFont.truetype(FONT,int(17*sc))
    for n,cx,cy,w,h in targets:
        cy-=dy
        if crop: cx-=crop[0]
        d.ellipse([cx-w/2,cy-h/2,cx+w/2,cy+h/2],outline=(214,32,32),width=max(3,int(3*sc)))
        r=int(14*sc); bx=cx-w/2; by=cy-h/2
        d.ellipse([bx-r,by-r,bx+r,by+r],fill=(214,32,32),outline=(255,255,255),width=2)
        tw=d.textlength(str(n),font=f)
        d.text((bx-tw/2,by-int(10*sc)),str(n),fill="white",font=f)
    if width and im.width>width:
        im=im.resize((width,int(im.height*width/im.width)),Image.LANCZOS)
    im.save(out)
O="ann_"
annotate(M+"01-monitor.png",O+"P05.png",[(1,113,117,190,30),(2,700,83,800,24),(3,373,215,96,24)])
annotate(M+"02-investigator.png",O+"P15.png",[(1,113,153,190,30),(2,670,131,390,36),(3,1053,131,170,36),(4,443,171,92,32)])
annotate(M+"05-investigacao-resultado.png",O+"P17.png",[(1,443,171,92,32),(2,432,391,80,20),(3,472,629,140,22)])
annotate(M+"07-rag-resposta.png",O+"P18.png",[(1,113,189,190,30),(2,722,336,560,36),(3,1052,336,92,36)])
annotate(M+"04-rag-alternativo.png",O+"P20.png",[(1,113,233,200,50),(2,722,303,560,36),(3,1052,303,92,36)])
annotate(U+"Imagens/Config/Production3.jpg",O+"R3.png",[(1,164,261,290,42),(2,1326,261,270,42)],crop=(0,165,2982,1676),width=1600)
print("ok")
