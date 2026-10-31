#!/usr/bin/env python3
"""Edit the existing synthetic native capture into a short, guided landscape demo.

No generated app UI, fake pointer, clipboard result or upload is added.
Requires ffmpeg and fontTools (used only to prepare Geist's local render faces).
"""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'website/public/assets/native-demo.mp4'
OUTPUT = ROOT / 'website/public/assets/native-demo-guided-v2.mp4'
POSTER = ROOT / 'website/public/assets/native-demo-guided-v2.jpg'
FONT = ROOT / 'website/node_modules/@fontsource-variable/geist/files/geist-latin-wght-normal.woff2'
SOURCE_SHA256 = '8bc0c2100c3e1948c046cef246c4dfd939b2a7a6befbcd49266611b032b97348'
SCENES = [
    dict(id='prompts', label='Prompts', start=2.1, end=4.7, speed=1,
         title='Find a prompt.', body='Writing rules and reusable requests,\nkept in a project pocket.', crop=None, x=810),
    dict(id='blanks', label='Fill-in blanks', start=4.8, end=12.8, speed=1.25,
         title='Fill the blanks.', body='Add the topic and audience.\nReview the text as it updates.', crop='720:880:120:160', x=760),
    dict(id='references', label='References', start=13.95, end=16.65, speed=1,
         title='Keep references.', body='Original files,\nwith labels and notes.', crop=None, x=810),
    dict(id='scratchpad', label='Scratchpad', start=17, end=20, speed=1,
         title='Leave a note.', body='Questions and checklists\nfor the next session.', crop='720:1000:120:0', x=794),
]


def run(args):
    subprocess.run([str(arg) for arg in args], check=True)


def main():
    if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise ValueError('The source capture changed; review the edit points before rendering.')
    from fontTools.ttLib import TTFont
    from fontTools.varLib.instancer import instantiateVariableFont
    with tempfile.TemporaryDirectory(prefix='nivlet-guided-demo-') as temporary:
        temporary = Path(temporary)
        for weight in (400, 600):
            font = instantiateVariableFont(TTFont(FONT), {'wght': weight}, inplace=False)
            font.flavor = None
            font.save(temporary / f'geist-{weight}.ttf')
        chapters = []
        elapsed = 0
        for scene in SCENES:
            chapters.append(dict(id=scene['id'], label=scene['label'], start=round(elapsed, 3)))
            elapsed += (scene['end'] - scene['start']) / scene['speed']
        for mobile in (False, True):
            canvas = '720x1152' if mobile else '1440x900'
            output = OUTPUT.with_name('native-demo-guided-mobile-v2.mp4') if mobile else OUTPUT
            poster = POSTER.with_name('native-demo-guided-mobile-v2.jpg') if mobile else POSTER
            for index, scene in enumerate(SCENES):
                title = temporary / f'title-{index}.txt'
                body = temporary / f'body-{index}.txt'
                title.write_text(scene['label'] if mobile else scene['title'])
                body.write_text(scene['body'])
                duration = (scene['end'] - scene['start']) / scene['speed']
                crop = f"crop={scene['crop']}," if scene['crop'] else ''
                if mobile:
                    view = f"[0:v]{crop}setpts=(PTS-STARTPTS)/{scene['speed']},scale=652:1040:force_original_aspect_ratio=decrease,pad=652:1040:(ow-iw)/2:(oh-ih)/2:black,fps=30[app];[1:v][app]overlay=34:88:shortest=1[framed];"
                    text = f"[framed]drawtext=fontfile='{temporary}/geist-600.ttf':textfile='{title}':fontcolor=0xf2f2f3:fontsize=27:x=(w-tw)/2:y=35[out]"
                else:
                    view = f"[0:v]{crop}setpts=(PTS-STARTPTS)/{scene['speed']},scale=-2:772,fps=30[app];[1:v][app]overlay={scene['x']}:64:shortest=1[framed];"
                    text = f"[framed]drawtext=fontfile='{temporary}/geist-600.ttf':textfile='{title}':fontcolor=0xf2f2f3:fontsize=47:x=100:y=342,drawtext=fontfile='{temporary}/geist-400.ttf':textfile='{body}':fontcolor=0xa9a9b3:fontsize=23:line_spacing=12:x=102:y=422[out]"
                run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-ss', scene['start'],
                     '-t', scene['end'] - scene['start'], '-i', SOURCE,
                     '-f', 'lavfi', '-i', f'color=c=black:s={canvas}:r=30',
                     '-filter_complex', view + text, '-map', '[out]', '-t', duration,
                     '-an', '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
                     '-pix_fmt', 'yuv420p', '-movflags', '+faststart', temporary / f'{index}.mp4'])
            listing = temporary / 'concat.txt'
            listing.write_text(''.join(f"file '{temporary / str(i)}.mp4'\n" for i in range(len(SCENES))))
            run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 'concat', '-safe', '0',
                 '-i', listing, '-c', 'copy', '-movflags', '+faststart', output])
            run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', output,
                 '-ss', '0.5', '-frames:v', '1', '-q:v', '2', poster])
        report = dict(source='native-demo.mp4', source_sha256=SOURCE_SHA256,
                      output=OUTPUT.name, poster=POSTER.name, frame=[1440, 900], mobile_frame=[720, 1152], mobile_output='native-demo-guided-mobile-v2.mp4', fps=30,
                      planned_duration=round(elapsed, 3), audio=False, chapters=chapters, edits=SCENES,
                      note='Actual captured pixels. Trimmed pauses, one 1.25x typing section, explicit focus crops and editorial captions. Not a performance measurement.')
        (OUTPUT.parent / 'native-demo-guided-v2.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(dict(output=str(OUTPUT), poster=str(POSTER), chapters=chapters)))


if __name__ == '__main__':
    main()
