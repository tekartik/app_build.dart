/// The iOS simulators (`xcrun simctl`): list, choose, boot (shown in
/// DeviceHub on Xcode 27+), shut down, run an action on one.
///
/// io only, macOS hosts.
library;

export 'src/ios_simulator.dart'
    show
        iosSimulatorRuntimePrefix,
        iosSimulatorStateBooted,
        IosSimulator,
        iosSimulatorRuntimeVersion,
        iosSimulatorsParseJson,
        listIosSimulators,
        iosSimulatorChooseTarget,
        bootIosSimulator,
        showIosSimulatorApp,
        shutdownIosSimulator,
        IosRunSimulator,
        withIosSimulator;
