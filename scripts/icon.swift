import AppKit

let side = 1024
let rep = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
  hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.91, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: 924, height: 924), xRadius: 208, yRadius: 208)
  .fill()
let ink = NSColor(calibratedRed: 0.86, green: 0.34, blue: 0.12, alpha: 1)
ink.setStroke()
let ring = NSBezierPath(ovalIn: NSRect(x: 258, y: 224, width: 508, height: 508))
ring.lineWidth = 48
ring.stroke()
let hand = NSBezierPath()
hand.move(to: NSPoint(x: 512, y: 654))
hand.line(to: NSPoint(x: 512, y: 478))
hand.line(to: NSPoint(x: 612, y: 408))
hand.lineWidth = 46
hand.lineCapStyle = .round
hand.lineJoinStyle = .round
hand.stroke()
let cap = NSBezierPath()
cap.move(to: NSPoint(x: 445, y: 809))
cap.line(to: NSPoint(x: 579, y: 809))
cap.lineWidth = 44
cap.lineCapStyle = .round
cap.stroke()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(
  to: URL(fileURLWithPath: CommandLine.arguments[1]))
