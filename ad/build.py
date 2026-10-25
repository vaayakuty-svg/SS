import subprocess, os, math

U = "/root/.claude/uploads/eb0cc57c-09fc-5979-b9d7-526cb142a6f6/"
IMG = {n: U + f for n, f in enumerate([
    "e38b794e-image.jpg", "7a86c105-image.jpg", "48bf9f71-image.jpg", "894bbc1f-image.jpg",
    "735db66d-image.jpg", "29ebc457-image.jpg", "65ae6077-image.jpg", "b81b4d9a-image.jpg",
    "bb384993-image.jpg", "e593012f-image.jpg", "598dd98b-image.jpg", "065b2b1b-image.jpg",
    "fe21fbaa-image.jpg"], start=1)}
D = os.path.dirname(os.path.abspath(__file__))
W, H, FPS, XF = 1920, 1080, 30, 0.5
BLACK = "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf"
SEMI = "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"
RED = "0xE3141B"

def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

def esc(s):
    return s.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’")

def slide(t0, dx=-120, dur=0.55):
    # ease-out cubic offset from dx to 0 starting at t0
    return f"({dx})*pow(1-min(1\\,max(0\\,(t-{t0})/{dur}))\\,3)"

def fade(t0, dur=0.4):
    return f"min(1\\,max(0\\,(t-{t0})/{dur}))"

def text(s, font, size, x, y, t0, color="white", dx=-120, shadow=True):
    sh = ":shadowcolor=black@0.6:shadowx=3:shadowy=3" if shadow else ""
    return (f"drawtext=fontfile={font}:text='{esc(s)}':fontsize={size}:fontcolor={color}"
            f":x={x}+{slide(t0, dx)}:y={y}:alpha='{fade(t0)}'{sh}")

def bar(x, y, w, h, t0):
    # red accent bar that wipes in from the left
    return (f"drawbox=x={x}:y={y}:w='{w}*min(1\\,max(0\\,(t-{t0})/0.45))':h={h}"
            f":color={RED}:t=fill:enable='gte(t,{t0})'")

def scene(i, src, dur, zoom=(1.0, 1.12), pan=(0.5, 0.5), crop_top=0, lines=(), grad=True):
    out = f"{D}/s{i:02}.mp4"
    n = int(dur * FPS)
    z0, z1 = zoom
    px, py = pan
    pre = (f"crop=iw-{crop_top*16//9}:ih-{crop_top}:{crop_top*8//9}:{crop_top},"
           f"scale=3840:2160,setsar=1")
    zp = (f"zoompan=z='{z0}+({z1}-{z0})*on/{n}':x='(iw-iw/zoom)*{px}':y='(ih-ih/zoom)*{py}'"
          f":d={n}:s={W}x{H}:fps={FPS}")
    vf = [pre, zp, "format=yuv420p"]
    fc = f"[0:v]{','.join(vf)}[b];"
    if grad:
        fc += "[b][1:v]overlay=0:0[b2];"
        last = "b2"
    else:
        last = "b"
    fc += f"[{last}]" + ",".join(lines or ["null"]) + "[v]"
    cmd = ["ffmpeg", "-y", "-loop", "1", "-i", src]
    if grad:
        cmd += ["-loop", "1", "-i", f"{D}/grad.png"]
    cmd += ["-filter_complex", fc, "-map", "[v]", "-t", str(dur), "-r", str(FPS),
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-pix_fmt", "yuv420p", out]
    run(cmd)
    return out, dur

def caption(head, sub, y=700, t0=0.35, size=96):
    # left-aligned headline block: red bar, headline, subline
    L = [bar(120, y - 34, 140, 10, t0),
         text(head, BLACK, size, 120, y, t0 + 0.12)]
    if sub:
        L.append(text(sub, SEMI, 44, 124, y + size + 22, t0 + 0.32, color="0xEDEDED"))
    return L

# left-to-right dark gradient for text legibility
run(["ffmpeg", "-y", "-f", "lavfi", "-i", f"color=black:s={W}x{H}", "-vf",
     "format=rgba,geq=r=0:g=0:b=0:a='min(255\\,255*0.78*pow(max(0\\,1-X/(W*0.62))\\,1.4)+255*0.45*pow(Y/H\\,3))'",
     "-frames:v", "1", f"{D}/grad.png"])

scenes = []
# 0: animated logo title on black
title = [
    text("GRIPCO", BLACK, 210, "(w-text_w)/2", 360, 0.2, dx=0, shadow=False),
    f"drawbox=x='960-430*min(1\\,max(0\\,(t-0.55)/0.5))':y=600:w='860*min(1\\,max(0\\,(t-0.55)/0.5))':h=8:color={RED}:t=fill:enable='gte(t,0.55)'",
    text("AUTO HUB", BLACK, 84, "(w-text_w)/2", 640, 0.85, color=RED, dx=0, shadow=False),
    "fade=t=in:st=0:d=0.3",
]
run(["ffmpeg", "-y", "-f", "lavfi", "-i", f"color=0x0B0B0D:s={W}x{H}:r={FPS}", "-vf",
     ",".join(title), "-t", "2.6", "-c:v", "libx264", "-preset", "veryfast", "-crf", "18",
     "-pix_fmt", "yuv420p", f"{D}/s00.mp4"])
scenes.append((f"{D}/s00.mp4", 2.6))

S = 3.6
scenes.append(scene(1, IMG[2], S, (1.0, 1.10), (0.5, 0.6), 0,
                    [bar(120, 566, 140, 10, 0.35),
                     text("YOUR ONE-STOP", BLACK, 96, 120, 600, 0.47),
                     text("CAR CARE HUB", BLACK, 96, 120, 710, 0.7, color=RED),
                     text("Premium care for every car", SEMI, 44, 124, 834, 0.95, color="0xEDEDED")]))
scenes.append(scene(2, IMG[1], S, (1.12, 1.0), (0.5, 0.4), 0,
                    caption("ALL UNDER ONE ROOF", "Car Wash  |  Wheel Alignment  |  Tyres")))
scenes.append(scene(3, IMG[3], S, (1.0, 1.14), (0.5, 0.0), 48,
                    caption("SPOTLESS CAR WASH", "High-pressure foam & rinse")))
scenes.append(scene(4, IMG[4], S, (1.04, 1.16), (0.5, 0.0), 48,
                    caption("2 WASH BAYS", "Less waiting. More shine.")))
scenes.append(scene(5, IMG[5], S, (1.0, 1.12), (0.5, 0.0), 48,
                    caption("WHEEL ALIGNMENT", "Smoother rides. Longer tyre life.")))
scenes.append(scene(6, IMG[6], S, (1.14, 1.0), (0.5, 0.0), 48,
                    caption("TYRE STOCK", "A wide range, ready to fit")))
scenes.append(scene(7, IMG[7], S, (1.0, 1.1), (0.6, 0.5), 48,
                    caption("CUSTOMER LOUNGE", "Relax while we work")))
scenes.append(scene(8, IMG[9], S, (1.0, 1.12), (0.3, 0.6), 48,
                    caption("EASY PARKING", "Spacious, well-lit premises")))
scenes.append(scene(9, IMG[11], S, (1.0, 1.1), (0.6, 0.4), 60,
                    [text("CLEANER CARS.", BLACK, 104, 120, 600, 0.3),
                     text("SAFER DRIVES.", BLACK, 104, 120, 720, 0.75, color=RED)]))
# end card: dark aerial with logo lockup
end = [
    "boxblur=16:2", "eq=brightness=-0.42:saturation=0.7",
    text("GRIPCO", BLACK, 190, "(w-text_w)/2", 300, 0.2, dx=0),
    f"drawbox=x='960-400*min(1\\,max(0\\,(t-0.5)/0.5))':y=520:w='800*min(1\\,max(0\\,(t-0.5)/0.5))':h=8:color={RED}:t=fill:enable='gte(t,0.5)'",
    text("AUTO HUB", BLACK, 78, "(w-text_w)/2", 556, 0.7, color=RED, dx=0),
    text("CAR WASH  |  WHEEL ALIGNMENT  |  TYRE STOCK", SEMI, 42, "(w-text_w)/2", 720, 1.1, dx=0),
    text("VISIT US TODAY", BLACK, 56, "(w-text_w)/2", 820, 1.5, dx=0),
    "fade=t=out:st=4.0:d=0.7",
]
scenes.append(scene(10, IMG[1], 4.7, (1.0, 1.06), (0.5, 0.5), 0, end, grad=False))

# crossfade chain
trans = ["fade", "slideleft", "fade", "wipeleft", "smoothleft", "fade", "slideleft",
         "wiperight", "fade", "fadeblack"]
cmd = ["ffmpeg", "-y"]
for f, _ in scenes:
    cmd += ["-i", f]
fc, prev, t = [], "0:v", scenes[0][1]
offsets = []
for k in range(1, len(scenes)):
    off = t - XF
    offsets.append(off)
    lab = f"x{k}"
    fc.append(f"[{prev}][{k}:v]xfade=transition={trans[k-1]}:duration={XF}:offset={off:.3f}[{lab}]")
    prev, t = lab, off + scenes[k][1]
total = t
cmd += ["-filter_complex", ";".join(fc), "-map", f"[{prev}]", "-c:v", "libx264",
        "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p", f"{D}/video.mp4"]
run(cmd)

# generated soundtrack: 120bpm kick + offbeat hats + bass pulse, plus whooshes on transitions
bpm = 2.0  # beats/sec
music = (
    "aevalsrc=exprs='"
    f"0.9*sin(2*PI*(45*mod(t,0.5)+3*(1-exp(-mod(t,0.5)*40))))*exp(-mod(t,0.5)*9)"
    f"+0.10*(random(0)*2-1)*exp(-mod(t+0.25,0.5)*60)"
    f"+0.22*sin(2*PI*55*pow(2,if(lt(mod(t,8),4),0,3/12))*t)*(0.6+0.4*sin(2*PI*4*t))"
    f"+0.06*sin(2*PI*220*pow(2,if(lt(mod(t,8),4),0,3/12))*t)*(0.5+0.5*sin(2*PI*0.25*t))"
    f"':s=44100:d={total:.2f}"
)
whoosh = "aevalsrc=exprs='(random(0)*2-1)*sin(PI*t/0.7)*0.5':s=44100:d=0.7,highpass=f=800,lowpass=f=5000"
afc = [f"{music},lowpass=f=9000,afade=t=in:d=0.5,afade=t=out:st={total-1.5:.2f}:d=1.5[m]"]
mix = ["[m]"]
for k, off in enumerate(offsets):
    afc.append(f"{whoosh},adelay={int((off - 0.1) * 1000)}|{int((off - 0.1) * 1000)}[w{k}]")
    mix.append(f"[w{k}]")
afc.append("".join(mix) + f"amix=inputs={len(mix)}:normalize=0,alimiter=limit=0.9,loudnorm=I=-14:TP=-1.5[a]")
run(["ffmpeg", "-y", "-i", f"{D}/video.mp4", "-filter_complex", ";".join(afc),
     "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
     "-ar", "48000", "-shortest", "-movflags", "+faststart", f"{D}/gripco_ad.mp4"])
print("total", total)
