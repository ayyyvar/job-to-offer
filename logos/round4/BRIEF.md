# Round 4 brief: the road writes a word
job-to-offer iOS app icon. The user picked concept 11 (logos/concepts/concept-11.svg, render logos/renders/concept-11.svg.png):
green #2F6F5E square, a paper #F3F5F4 road with round caps, a green dashed centerline on the road, violet #5B3FA8 start dot, amber #E0A23B end dot.
The user wants the road to WRITE A WORD as ONE continuous line: "job" and "work".
Earlier attempts failed on legibility (renders logos/renders/iteration-1.svg.png = "work" read as "wok"; iteration-2 = "job" read as "jeb"):
- the road was too thick for the letter size, so counters (inside of o, b) closed up;
- letters overlapped and crossings hid letter shapes;
- the word was small inside the square.
Hard requirements:
- A stranger must read the word instantly at 512 px AND at 64 px.
- One continuous road line (the dot of j may be a separate dot = violet start dot).
- Counters of o/b at least 2x the road width. No letter crosses another letter.
- Fill ~84% of the width; vertical centering by optical mass.
- Dashed centerline may be dropped if it hurts legibility (say so).
SVG: viewBox 0 0 512 512, no width/height, full-square background rect, no <text>, no <use>, flat fills, mark in <g id="icon">. Draw the dashed centerline as a duplicate path.
Verification: render with `qlmanage -t -s 512 -o /tmp <file>` and also `qlmanage -t -s 64 -o /tmp/small <file>` (mkdir first); Read both PNGs and honestly ask "would a stranger read the word?". Iterate up to 4 times.
