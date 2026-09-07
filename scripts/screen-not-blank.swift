#!/usr/bin/env swift
//
// Fails when a screenshot rendered nothing.
//
// The first version of this check shelled out to ImageMagick, which is not installed on
// the GitHub macOS runner. Every image reported `sigma=-1`, the check skipped them all,
// and the build went green — a guard that silently guards nothing, which is worse than no
// guard, because it also removes the suspicion.
//
// CoreGraphics is on the runner by definition: the job builds an iOS app with Xcode. No
// install step, no version drift.
//
// Usage:  swift scripts/screen-not-blank.swift <threshold> <file.png> ...
// Exit 0 when every image has luminance standard deviation above the threshold.

import CoreGraphics
import Foundation
import ImageIO

/// Luminance standard deviation, 0...255. A single-colour screen sits at 0; any real
/// interface is far above it.
func luminanceSigma(of url: URL) -> Double? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }

    // Downsample hard. A blank screen is blank at any resolution, and decoding three
    // megapixels per shot to compute one number is waste.
    let width = 96
    let height = max(1, Int(Double(width) * Double(image.height) / Double(image.width)))
    var pixels = [UInt8](repeating: 0, count: width * height * 4)

    guard let context = CGContext(
        data: &pixels,
        width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var sum = 0.0
    var sumSquares = 0.0
    let count = width * height

    for index in 0..<count {
        let r = Double(pixels[index * 4])
        let g = Double(pixels[index * 4 + 1])
        let b = Double(pixels[index * 4 + 2])
        // Rec. 601 luma. The exact weights barely matter here; consistency does.
        let luma = 0.299 * r + 0.587 * g + 0.114 * b
        sum += luma
        sumSquares += luma * luma
    }

    let mean = sum / Double(count)
    return (sumSquares / Double(count) - mean * mean).squareRoot()
}

let arguments = CommandLine.arguments
guard arguments.count >= 3, let threshold = Double(arguments[1]) else {
    FileHandle.standardError.write(
        Data("usage: screen-not-blank.swift <threshold> <file.png> ...\n".utf8)
    )
    exit(2)
}

var failed = false
for path in arguments.dropFirst(2) {
    let name = (path as NSString).lastPathComponent
    guard let sigma = luminanceSigma(of: URL(fileURLWithPath: path)) else {
        print("\(name)  could not decode")
        failed = true
        continue
    }
    let verdict = sigma < threshold ? "BLANK" : "ok"
    print(String(format: "%@  sigma=%.2f  %@", name, sigma, verdict))
    if sigma < threshold { failed = true }
}

exit(failed ? 1 : 0)
