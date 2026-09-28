# Auction House compatibility

This child addon ships with Tweaks Forever. Auctionator already lists `LibAHTab` as an optional dependency, so it loads this library before its embedded copy. Auctionator updates therefore do not overwrite the fix.

Based on TheMouseNest/LibAHTab commit `24090a7bb096208dceaa4e6d95e539a7f3a5c4fe` (MIT; see LICENSE), library revision 4. The only behavioural changes are observing native panel OnShow scripts instead of hooking SetDisplayMode, and removing the direct displayMode field write. Native panel changes hide and deselect custom tabs without replacing Blizzard methods.

Keep upstream's revision number: an equal embedded revision leaves this copy in place, while a newer upstream revision can upgrade normally. Remove this compatibility copy once Auctionator ships a library revision that fixes both operations on Forever. Do not increase the revision to block upstream upgrades.
