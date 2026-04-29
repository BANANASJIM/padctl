// Public surface of the install package. Implementation lives under
// `src/cli/install/`. Architecture-review Finding #2: split the prior
// 5005-LoC monolith into plan/services/udev/migration/mappings/phase.

const plan = @import("install/plan.zig");
const phase = @import("install/phase.zig");
const udev = @import("install/udev.zig");

pub const InstallOptions = plan.InstallOptions;
pub const ImmutableKind = plan.ImmutableKind;
pub const InstallPlan = plan.InstallPlan;
pub const SystemctlUserMode = plan.SystemctlUserMode;
pub const SystemctlUserPlan = plan.SystemctlUserPlan;
pub const EnvSnapshot = plan.EnvSnapshot;

pub const run = phase.run;
pub const uninstall = phase.uninstall;
pub const setupTestUdev = udev.setupTestUdev;

test {
    _ = @import("install/tests.zig");
}
