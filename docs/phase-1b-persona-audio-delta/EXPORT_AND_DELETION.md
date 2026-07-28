# Export and deletion

Structured export now has an optional `persona.json` only for the complete aggregate, containing enum answers, derived persona, routing rule, and calculation instant. It never includes a questionnaire draft, queue/receipt state, credentials, audio bytes, filenames, paths, transcripts, waveforms, or derived voice data.

Local profile deletion cascades drafts, aggregate, clip metadata, and default selection. Account deletion cascades the remote aggregate and receipts/tombstones through account ownership. Personal audio produces no server deletion request.
