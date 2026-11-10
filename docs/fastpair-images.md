# Photos of your earbuds on the island

When a Google Fast Pair case is opened, the island drops for a few
seconds with the battery of the left bud, the case and the right bud
(see `fastPairPeek` in [settings.md](settings.md)). By default each one
is a word and a bar. You can replace the words with real photos of your
own earbuds.

## Where the photos go

A folder named after the device, exactly as its name appears on the
island, under your config:

```
~/.config/shima/fastpair/<device name>/
```

For example, for *OPPO Enco Air4 Pro*:

```
~/.config/shima/fastpair/OPPO Enco Air4 Pro/
```

The name is the one Bluetooth shows for the device — the same one the
peek prints at the top. A space in it is fine; the folder has a space
too.

## Two ways to do it

**One photo per piece.** Put any of these in the folder:

| File | Shows as |
|---|---|
| `left.png` | the left bud, battery beneath |
| `case.png` | the case, in the middle, battery beneath |
| `right.png` | the right bud, battery beneath |

Each is independent: whatever you leave out keeps its word, so a folder
with only `case.png` shows a photo for the case and the words for the
buds.

**One photo of the set.** Put a single `all.png` in the folder and the
peek shows that one picture with the three batteries in a row beneath
it. `all.png` wins over the per-piece files if both are there.

## Making the photos

- **PNG with a transparent background.** The island is dark; a photo on
  a white rectangle looks like a white rectangle. Most product shots
  online already come cut out, and a tool like GIMP, `rembg` or
  remove.bg does it in one step.
- **Square-ish** for the buds and the case, **wide** for an `all.png`
  of the set.
- Around **240 px** on the long side is plenty — they are drawn small.
- Centre the subject and trim the empty margin, so it is not lost in
  its own padding.

### Cutting out a white-on-white photo

White earbuds on a white background are the hard case: a plain "make
white transparent" eats the earbud along with the background. Flood
filling from the corners with a low tolerance stops at the edge
instead. With ImageMagick:

```sh
magick in.png -alpha set -bordercolor white -border 2 -fuzz 2% \
  -fill none -draw 'alpha 0,0 floodfill' -draw 'alpha 0,0 floodfill' \
  -shave 2x2 -trim +repage -resize 240x240 left.png
```

Raise the `-fuzz` a little if a white halo is left, lower it if the
earbud starts to disappear.

## Turning it on

The peek itself is off by default, under **Notifications · Bluetooth**
in the settings, or `fastPairPeek` in the config. It needs BlueZ with
`Experimental = true` and the `python-dbus` package. The photos need
nothing switched on: drop them in the folder and the next opening uses
them.
