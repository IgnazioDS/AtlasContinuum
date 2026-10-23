# WorldPane independence model

WorldPane has no runtime dependency on another map addon. Its folder, globals,
saved variables, commands, public API, addon-message prefix, settings category,
validation, package, documentation, and support destination are owned and
versioned here.

The release includes a small load-on-demand compatibility folder solely to let
WoW hydrate saved variables written under the previous package identity. It has
no map engine and can be retired after a documented migration window.

## License boundary

The codebase is not accurately described as wholly proprietary. The historical
foundation, including the original OpenMap-derived line and additions published
through commit `5e248565f8b75993ecdd15d81a941518f06cc657`, remains MIT-licensed.
Original WorldPane work published after that boundary is All Rights Reserved
unless a file says otherwise. Existing MIT grants cannot be withdrawn.

Operational independence and copyright exclusivity are different goals.
WorldPane has the former. Achieving a wholly proprietary implementation would
require a separately managed clean-room rewrite that does not copy protected
expression from this repository.

## Publication rules

- Keep the full legacy MIT notice in every source and binary-style package.
- Keep source visible and unobfuscated for World of Warcraft addon policy.
- Distribute the addon free of charge.
- Keep third-party and Blizzard-asset notices intact.
- Never describe inherited MIT material as newly exclusive WorldPane code.
