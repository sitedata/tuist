import Foundation
import TSCBasic
import TuistCore
import TuistGraph
import TuistSupport

/// Tree-shakes testable targets which hashes have not changed from those in the tests cache directory
/// Creates tests hash files into a `testsCacheDirectory`
public final class TestsCacheGraphMapper: GraphMapping {
    private let testsCacheDirectory: AbsolutePath
    private let testsGraphContentHasher: TestsGraphContentHashing

    /// - Parameters:
    ///     - testsCacheDirectory: Location where to save current hashes.
    /// This should be a temporary location if you don't want to save the hashes permanently.
    /// This is useful when you want to save the hashes of tests only after the tests have run successfully.
    public convenience init(
        testsCacheDirectory: AbsolutePath
    ) {
        self.init(
            testsCacheDirectory: testsCacheDirectory,
            testsGraphContentHasher: TestsGraphContentHasher()
        )
    }

    init(
        testsCacheDirectory: AbsolutePath,
        testsGraphContentHasher: TestsGraphContentHashing
    ) {
        self.testsCacheDirectory = testsCacheDirectory
        self.testsGraphContentHasher = testsGraphContentHasher
    }

    public func map(graph: Graph) throws -> (Graph, [SideEffectDescriptor]) {
        let hashes = try testsGraphContentHasher.contentHashes(graph: graph)

        var visitedNodes: [TargetNode: Bool] = [:]
        var workspace = graph.workspace
        let mappedSchemes = try workspace.schemes
            .map { scheme -> (Scheme, [TargetNode]) in
                try map(
                    scheme: scheme,
                    graph: graph,
                    hashes: hashes,
                    visited: &visitedNodes
                )
            }
        let schemes = mappedSchemes.map(\.0)
        let cachedTestableTargets = mappedSchemes.flatMap(\.1)
        Set(cachedTestableTargets).forEach {
            logger.notice("\($0.target.name) has not changed from last successful run, skipping...")
        }
        workspace.schemes = schemes
        return (
            graph.with(
                workspace: workspace
            ),
            hashes.values.map {
                .file(
                    FileDescriptor(
                        path: testsCacheDirectory.appending(component: $0)
                    )
                )
            }
        )
    }

    // MARK: - Helpers

    private func testableTargets(scheme: Scheme, graph: Graph) -> [TargetNode] {
        scheme.testAction
            .map(\.targets)
            .map { testTargets in
                testTargets.compactMap { testTarget in
                    graph.target(
                        path: testTarget.target.projectPath,
                        name: testTarget.target.name
                    )
                }
            } ?? []
    }

    /// - Returns: Mapped scheme and cached testable targets
    private func map(
        scheme: Scheme,
        graph: Graph,
        hashes: [TargetNode: String],
        visited: inout [TargetNode: Bool]
    ) throws -> (Scheme, [TargetNode]) {
        var scheme = scheme
        guard let testAction = scheme.testAction else { return (scheme, []) }
        let cachedTestableTargets = testableTargets(
            scheme: scheme,
            graph: graph
        )
        .filter { testableTarget in
            isCached(
                testableTarget,
                hashes: hashes,
                visited: &visited
            )
        }

        scheme.testAction?.targets = testAction.targets.filter { testTarget in
            !cachedTestableTargets.contains(where: { $0.target.name == testTarget.target.name })
        }

        return (scheme, cachedTestableTargets)
    }

    private func isCached(
        _ target: TargetNode,
        hashes: [TargetNode: String],
        visited: inout [TargetNode: Bool]
    ) -> Bool {
        if let visitedValue = visited[target] { return visitedValue }
        let allTargetDependenciesAreHashed = target.targetDependencies
            .allSatisfy {
                self.isCached(
                    $0,
                    hashes: hashes,
                    visited: &visited
                )
            }
        guard let hash = hashes[target] else {
            visited[target] = false
            return false
        }
        /// Target is considered as cached if all its dependencies are cached and its hash is present in `testsCacheDirectory`
        /// Hash of the target is saved to that directory only after a successful test run
        let isCached = FileHandler.shared.exists(
            Environment.shared.testsCacheDirectory.appending(component: hash)
        ) && allTargetDependenciesAreHashed
        visited[target] = isCached
        return isCached
    }
}
