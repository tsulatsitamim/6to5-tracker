import Darwin
import Foundation
import TrackerCore

// Hand-rolled test runner: XCTest and Swift Testing are unavailable without
// a full Xcode installation, so assertions and the entry point live here.
// Each task adds its suite function to TestMain.main() below.

private(set) var testCount = 0
private(set) var testFailures = 0

func fail(_ message: String, file: String = #file, line: Int = #line) {
    testFailures += 1
    print("FAIL \(file):\(line) - \(message)")
}

func expectTrue(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String,
    file: String = #file, line: Int = #line
) {
    testCount += 1
    if !condition() { fail(message(), file: file, line: line) }
}

func expectEqual<T: Equatable>(
    _ actual: @autoclosure () -> T,
    _ expected: @autoclosure () -> T,
    _ message: @autoclosure () -> String,
    file: String = #file, line: Int = #line
) {
    testCount += 1
    let a = actual()
    let e = expected()
    if a != e { fail("\(message()) - expected \(e), got \(a)", file: file, line: line) }
}

func expectNil(
    _ actual: @autoclosure () -> Any?,
    _ message: @autoclosure () -> String,
    file: String = #file, line: Int = #line
) {
    testCount += 1
    if actual() != nil { fail("\(message()) - expected nil", file: file, line: line) }
}

func expectNotNil(
    _ actual: @autoclosure () -> Any?,
    _ message: @autoclosure () -> String,
    file: String = #file, line: Int = #line
) {
    testCount += 1
    if actual() == nil { fail("\(message()) - expected non-nil", file: file, line: line) }
}

private func runVersionTests() {
    expectEqual(TrackerCore.version, "0.1.1", "TrackerCore.version should be 0.1.1")
}

@main
struct TestMain {
    static func main() {
        runVersionTests()
        runCoreTypesTests()
        runEngineTests()
        runStoreTests()
        runDayGroupingTests()

        print("== \(testCount) assertions, \(testFailures) failures ==")
        if testFailures > 0 {
            exit(1)
        }
        print("ALL TESTS PASSED")
    }
}
