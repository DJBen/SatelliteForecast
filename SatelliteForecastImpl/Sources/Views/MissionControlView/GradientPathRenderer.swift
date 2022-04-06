//
//  GradientPathRenderer.swift
//  SatelliteForecastImpl
//
//  Created by Ben Lu on 4/3/22.
//

import MapKit

/// Draws a given polyline with a gradient fill, use in place of a MKOverlayPathRenderer
public class GradientPathRenderer: MKOverlayPathRenderer {
    public struct ColorAndStop {
        public let color: CGColor
        /// The stop / location of the color. This value is normalized from 0 to 1, where as 0 indicates the start of the gradient and
        /// 1 idicates the end.
        public let stop: CGFloat

        public init(
            color: CGColor,
            stop: CGFloat
        ) {
            self.color = color
            self.stop = stop
        }
    }

    enum ColorMode {
        /// Evenly distributed array of colors
        case evenlyDistributed([CGColor])

        /// Colors with custom locations allowing uneven distributions
        case custom([ColorAndStop])
    }

    /// The polyline to render
    var polyline: MKPolyline
    /// The colors used to draw the gradient
    var colors: ColorMode
    /// If a border should be rendered to make the line more visible
    var showsBorder: Bool
    /// The color of the border, if showsBorder is true
    var borderColor: CGColor

    static var defaultBorderColor: CGColor {
        let space = CGColorSpace(name: CGColorSpace.genericRGBLinear)!
        let comps: [CGFloat] = [1, 1, 1, 1]
        let color = CGColor(colorSpace: space, components: comps)!
        return color
    }

    // MARK: Initializers
    /// Initializes a new Gradient Path Renderer from a given polyline and an array of colors
    ///
    /// Use this initializer if you want an even distribution of colors.
    /// - Parameters:
    ///   - polyline: The polyline to render
    ///   - colors: The colours the gardient should contain
    ///   - showsBorder: If the polyline should have a border
    ///   - borderColor: The colour of the border
    init(polyline: MKPolyline, colors: [CGColor], showsBorder: Bool = false, borderColor: CGColor = GradientPathRenderer.defaultBorderColor) {
        self.polyline = polyline
        self.colors = .evenlyDistributed(colors)
        self.showsBorder = showsBorder
        self.borderColor = borderColor

        super.init(overlay: polyline)
    }

    /// Initializes a new Gradient Path Renderer from a given polyline and an array of colors and stop locations.
    ///
    /// Use this initializer if you want to customize the location of each color, allowing uneven distribution.
    /// - Parameters:
    ///   - polyline: The polyline to render
    ///   - colorsAndStops: The colors and stops the gardient should contain
    ///   - showsBorder: If the polyline should have a border
    ///   - borderColor: The colour of the border
    init(polyline: MKPolyline, colorsAndStops: [ColorAndStop], showsBorder: Bool = false, borderColor: CGColor = GradientPathRenderer.defaultBorderColor) {
        self.polyline = polyline
        self.colors = .custom(colorsAndStops)
        self.showsBorder = showsBorder
        self.borderColor = borderColor

        super.init(overlay: polyline)
    }

    // MARK: Override methods
    public override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {

        /*
         Set path width relative to map zoom scale
         */
        let baseWidth: CGFloat = self.lineWidth / zoomScale

        if self.showsBorder {
            context.setLineWidth(baseWidth * 2)
            context.setLineJoin(CGLineJoin.round)
            context.setLineCap(CGLineCap.round)
            context.addPath(self.path)
            context.setStrokeColor(self.borderColor)
            context.strokePath()
        }

        /*
         Create a gradient from the colors provided with evenly spaced stops
         */
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let gradient: CGGradient?
        switch colors {
        case .evenlyDistributed(let colorArray):
            // Passing `nil` to location evenly distributes the colors
            gradient = CGGradient(colorsSpace: colorspace, colors: colorArray as CFArray, locations: nil)
        case .custom(let colorsAndStops):
            gradient = CGGradient(colorsSpace: colorspace, colors: colorsAndStops.map(\.color) as CFArray, locations: colorsAndStops.map(\.stop))
        }

        /*
         Define path properties and add it to context
         */
        context.setLineWidth(baseWidth)
        context.setLineJoin(CGLineJoin.round)
        context.setLineCap(CGLineCap.round)

        context.addPath(self.path)

        /*
         Replace path with stroked version so we can clip
         */
        context.saveGState();

        context.replacePathWithStrokedPath()
        context.clip();

        /*
         Create bounding box around path and get top and bottom points
         */
        let boundingBox = self.path.boundingBoxOfPath
        let gradientStart = boundingBox.origin
        let gradientEnd   = CGPoint(x:boundingBox.maxX, y:boundingBox.maxY)

        /*
         Draw the gradient in the clipped context of the path
         */
        if let gradient = gradient {
            context.drawLinearGradient(gradient, start: gradientStart, end: gradientEnd, options: CGGradientDrawingOptions.drawsBeforeStartLocation);
        }


        context.restoreGState()

        super.draw(mapRect, zoomScale: zoomScale, in: context)
    }

    /*
     Create path from polyline
     Thanks to Adrian Schoenig
     (http://adrian.schoenig.me/blog/2013/02/21/drawing-multi-coloured-lines-on-an-mkmapview/ )
     */
    public override func createPath() {
        let path: CGMutablePath  = CGMutablePath()
        var pathIsEmpty: Bool = true

        for i in 0...self.polyline.pointCount-1 {

            let point: CGPoint = self.point(for: self.polyline.points()[i])
            if pathIsEmpty {
                path.move(to: point)
                pathIsEmpty = false
            } else {
                path.addLine(to: point)
            }
        }
        self.path = path
    }
}

#if canImport(UIKIt)
import UIKit

public extension GradientPathRenderer {
    // MARK: Initializers
    /// Initializes a new Gradient Path Renderer from a given polyline and an array of colors
    ///
    /// - Parameters:
    ///   - polyline: The polyline to render
    ///   - colors: The colours the gardient should contain
    convenience init(polyline: MKPolyline, colors: [UIColor]) {
        self.init(polyline: polyline, colors: colors.map(\.cgColor))
    }

    /// Initializes a new Gradient Path Renderer from a given polyline and an array of colors, with a border with a defined colour
    ///
    /// - Parameters:
    ///   - polyline: The polyline to render
    ///   - colors: The colours the gardient should contain
    ///   - showsBorder: If the polyline should have a border
    ///   - borderColor: The colour of the border
    convenience init(polyline: MKPolyline, colors: [UIColor], showsBorder: Bool, borderColor: UIColor) {
        self.init(polyline: polyline, colors: colors.map(\.cgColor), showsBorder: showsBorder, borderColor: borderColor.cgColor)
    }
}
#endif

#if canImport(AppKit)
import AppKit

public extension GradientPathRenderer {
    //MARK: Initializers
    /// Initializes a new Gradient Path Renderer from a given polyline and an array of colors
    ///
    /// - Parameters:
    ///   - polyline: The polyline to render
    ///   - colors: The colours the gardient should contain
    convenience init(polyline: MKPolyline, colors: [NSColor]) {
        self.init(polyline: polyline, colors: colors.map(\.cgColor))
    }

    /// Initializes a new Gradient Path Renderer from a given polyline and an array of colors, with a border with a defined colour
    ///
    /// - Parameters:
    ///   - polyline: The polyline to render
    ///   - colors: The colours the gardient should contain
    ///   - showsBorder: If the polyline should have a border
    ///   - borderColor: The colour of the border
    convenience init(polyline: MKPolyline, colors: [NSColor], showsBorder: Bool, borderColor: NSColor) {
        self.init(polyline: polyline, colors: colors.map(\.cgColor), showsBorder: showsBorder, borderColor: borderColor.cgColor)
    }
}
#endif
