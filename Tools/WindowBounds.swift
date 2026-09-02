#!/usr/bin/env swift
// Prints "x,y,w,h" for the first on-screen window owned by the named app,
// in the coordinate space `screencapture -R` expects.
import CoreGraphics
import Foundation

let target = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ReadmeLens"
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []

for window in windows {
    guard let owner = window[kCGWindowOwnerName as String] as? String, owner == target,
          let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
          let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
          bounds.width > 200, bounds.height > 200
    else { continue }
    print("\(Int(bounds.origin.x)),\(Int(bounds.origin.y)),\(Int(bounds.width)),\(Int(bounds.height))")
    exit(0)
}
FileHandle.standardError.write("no window found for \(target)\n".data(using: .utf8)!)
exit(1)
