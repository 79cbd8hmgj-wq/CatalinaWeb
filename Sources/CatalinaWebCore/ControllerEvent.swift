import Foundation

public enum ControllerEvent: Equatable {
    case workspaceSwitched(from: Workspace, to: Workspace)
    case orionWindowConnected(pid: Int32)
    case orionWindowDisconnected
    case externalNavigationRerouted(host: String, workspace: Workspace)
    case automationFailed(operation: String, description: String)
    case setupStageChanged(OrionSetupStage)
}

public protocol ControllerEventRecording: AnyObject {
    func record(_ event: ControllerEvent)
}

public final class NullControllerEventRecorder: ControllerEventRecording {
    public init() {}

    public func record(_ event: ControllerEvent) {}
}
