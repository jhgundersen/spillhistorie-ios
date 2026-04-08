#!/usr/bin/swift
import CoreGraphics
import Foundation
import ImageIO

// 7-column × 7-row pixelated S
let pixels: [[Int]] = [
    [0,1,1,1,1,1,0],
    [1,0,0,0,0,0,0],
    [1,0,0,0,0,0,0],
    [0,1,1,1,1,1,0],
    [0,0,0,0,0,0,1],
    [0,0,0,0,0,0,1],
    [0,1,1,1,1,1,0],
]

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// Background — dark navy, matching the TUI's dark terminal feel
ctx.setFillColor(CGColor(red: 0.06, green: 0.03, blue: 0.16, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let rows = pixels.count
let cols = pixels[0].count
let margin = 190
let gap = 14
let pixW = (size - 2 * margin) / cols
let pixH = (size - 2 * margin) / rows

// Bright magenta — the TUI's signature color (lipgloss Color("13"))
ctx.setFillColor(CGColor(red: 0.87, green: 0.32, blue: 1.0, alpha: 1))

for (row, line) in pixels.enumerated() {
    for (col, val) in line.enumerated() where val == 1 {
        let x = CGFloat(margin + col * pixW + gap / 2)
        // CoreGraphics is bottom-up; flip the row
        let y = CGFloat(margin + (rows - 1 - row) * pixH + gap / 2)
        let w = CGFloat(pixW - gap)
        let h = CGFloat(pixH - gap)
        // Slightly rounded pixel blocks
        let path = CGPath(
            roundedRect: CGRect(x: x, y: y, width: w, height: h),
            cornerWidth: 6, cornerHeight: 6, transform: nil
        )
        ctx.addPath(path)
        ctx.fillPath()
    }
}

let image = ctx.makeImage()!
let outputPath = "Sources/SpillhistorieApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let outputURL = URL(fileURLWithPath: outputPath)
let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("Icon written: \(outputPath)")
