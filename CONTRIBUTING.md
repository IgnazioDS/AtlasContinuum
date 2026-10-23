# Contributing

Keep changes small enough to verify visually in game. Do not hand-edit files
marked as generated unless repairing the generator in the same change.

Before submitting a change:

1. Run `make check`.
2. Test on the exact Retail build declared in the TOC.
3. Include the output of `/acaudit` for data or map coverage changes.
4. Include before/after screenshots for rendering, masks, alignment, fades, or
   UI changes.
5. State which map addons were enabled during the test.
6. Preserve upstream attribution and asset provenance.

Never include account data, SavedVariables, screenshots containing private
chat, or extracted game assets that are unrelated to the addon runtime.
