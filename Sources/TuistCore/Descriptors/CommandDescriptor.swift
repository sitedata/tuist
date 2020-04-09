import Foundation

/// Command Descriptor
///
/// Describes a command that needs to be executed as part of
/// generating a project or workspace.
///
/// - seealso: `SideEffectsDescriptor`
public struct CommandDescriptor: Equatable, Hashable, CustomStringConvertible {
    public var command: [String]

    /// Creates a command descriptor
    /// - Parameter command: The command and its arguments to perform
    public init(command: [String]) {
        self.command = command
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(command)
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        "execute \(command.joined(separator: " "))"
    }
}
