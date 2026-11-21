## Editing

A multi-edit call matches against the file as it was before the call, so keep every `oldText` unique and disjoint. If a call reports PARTIAL APPLY, re-read the file and resend only the hunks that did not land. Resending the whole call double-applies the ones that did.
