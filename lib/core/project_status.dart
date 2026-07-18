/// Canonical project lifecycle statuses. New vaults seed these; existing vaults
/// keep whatever they already have, and the status dropdown always offers the
/// full set — so no on-disk migration is needed.
const kProjectStatuses = ['planning', 'pending', 'in progress', 'paused', 'done', 'cancelled'];

/// Status a brand-new project starts in.
const kDefaultProjectStatus = 'planning';

/// Statuses counted as active work in dashboard stats. Legacy 'active' (from
/// vaults created before the status set expanded) is included so those projects
/// still tally.
const kActiveStatuses = {'active', 'planning', 'pending', 'in progress'};
