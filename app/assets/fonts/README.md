# Atkinson Hyperlegible Next (static TTFs)

Family `Atkinson Hyperlegible Next`, weights 400 Regular, 500 Medium, 600 SemiBold,
700 Bold, 800 ExtraBold (the weights used by `tokens.json`). Bundled locally: the
app works offline and never loads fonts from Google Fonts.

## How these files were made

The design system ships variable woff2 subsets (`bezpiecznik/08-design-system/fonts/`,
wght 200-800, latin + latin-ext). Flutter cannot load woff2 and ignores variable
axes on some platforms, so `tools/build_fonts.py` (fontTools + brotli) does, per weight:

1. decompress each woff2 subset to TTF,
2. `instancer.instantiateVariableFont(font, {"wght": weight})` (static instance),
3. merge latin + latin-ext (`fontTools.merge.Merger`) so Polish letters
   (ąćęłńóśźż, ĄĆĘŁŃÓŚŹŻ) are covered; GSUB `tnum`/`pnum` features survive,
4. rename family/style/PostScript names and set `usWeightClass`.

Regenerate:

    uv run --script tools/build_fonts.py

## pubspec.yaml

    flutter:
      fonts:
        - family: Atkinson Hyperlegible Next
          fonts:
            - asset: assets/fonts/AtkinsonHyperlegibleNext-Regular.ttf
              weight: 400
            - asset: assets/fonts/AtkinsonHyperlegibleNext-Medium.ttf
              weight: 500
            - asset: assets/fonts/AtkinsonHyperlegibleNext-SemiBold.ttf
              weight: 600
            - asset: assets/fonts/AtkinsonHyperlegibleNext-Bold.ttf
              weight: 700
            - asset: assets/fonts/AtkinsonHyperlegibleNext-ExtraBold.ttf
              weight: 800

## Licence

SIL Open Font License 1.1. Copyright 2020-2024 The Atkinson Hyperlegible Next
Project Authors (https://github.com/googlefonts/atkinson-hyperlegible-next).
Licence text: https://openfontlicense.org (the design-system folder does not
include a copy of the licence file; add `OFL.txt` from the upstream repository
before store release).
