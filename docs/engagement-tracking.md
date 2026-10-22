# Engagement tracking

Tweaks Forever does not currently collect or transmit progression statistics. Its features are point-of-use helpers,
and many actions it triggers (quest acceptance, loot, repair, and selling) do not have a reliable event that proves
the player's broader progress or attributes an outcome to this addon. A counter of calls would measure automation,
not an adventure milestone.

Keep local tracking off the roadmap until a metric has a game-authored success event and a clear player benefit.
Do not derive counters from localized chat text or infer successful questing from the automation's button/API calls.

There is no leaderboard or addon-message protocol in Tweaks Forever. Any future sharing must use an explicitly
designed suite protocol, with documented scope, opt-out behavior, and a way to keep local records when sharing is
disabled. WoW addons cannot upload records to a global board on their own.
