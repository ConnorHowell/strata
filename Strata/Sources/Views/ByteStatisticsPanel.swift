// ByteStatisticsPanel.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - ByteStatisticsPanel

/// Displays a byte frequency histogram for the current file data.
public final class ByteStatisticsPanel: NSView {

    // MARK: - Public API

    /// Creates the panel and computes statistics for the given data.
    ///
    /// - Parameter data: The file data to analyze.
    public init(data: Data) {
        self.frequencies = Self.computeFrequencies(data)
        self.totalBytes = data.count
        super.init(frame: .zero)
        setupViews()
    }

    override public init(frame frameRect: NSRect) {
        self.frequencies = Array(repeating: 0, count: 256)
        self.totalBytes = 0
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        drawHistogram(in: ctx)
    }

    // MARK: - Private

    private let frequencies: [Int]
    private let totalBytes: Int
    private let infoLabel = NSTextField(labelWithString: "")

    private static func computeFrequencies(_ data: Data) -> [Int] {
        var freq = Array(repeating: 0, count: 256)
        for byte in data {
            freq[Int(byte)] += 1
        }
        return freq
    }

    private func setupViews() {
        wantsLayer = true

        infoLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        infoLabel.stringValue = "Total: \(totalBytes) bytes | "
            + "Unique: \(frequencies.filter { $0 > 0 }.count)/256"
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(infoLabel)

        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            infoLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
        ])
    }

    private func drawHistogram(in ctx: CGContext) {
        let margin: CGFloat = 40
        let topMargin: CGFloat = 40
        let bottomMargin: CGFloat = 30
        let chartX = margin
        let chartY = topMargin
        let chartW = bounds.width - margin * 2
        let chartH = bounds.height - topMargin - bottomMargin
        guard chartW > 0, chartH > 0 else { return }

        // Background
        NSColor.textBackgroundColor.setFill()
        ctx.fill(bounds)

        let maxFreq = frequencies.max() ?? 1
        guard maxFreq > 0 else { return }

        let barW = chartW / 256.0

        // Draw bars
        for i in 0..<256 {
            let count = frequencies[i]
            guard count > 0 else { continue }
            let ratio = CGFloat(count) / CGFloat(maxFreq)
            let barH = ratio * chartH
            let x = chartX + CGFloat(i) * barW
            let y = chartY + chartH - barH

            let hue = CGFloat(i) / 256.0
            NSColor(
                hue: hue, saturation: 0.6,
                brightness: 0.85, alpha: 0.9
            ).setFill()
            ctx.fill(CGRect(x: x, y: y, width: max(barW - 0.5, 1), height: barH))
        }

        // Draw axis labels
        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        let color = NSColor.secondaryLabelColor
        for tick in stride(from: 0, through: 255, by: 32) {
            let label = String(format: "%02X", tick)
            let x = chartX + CGFloat(tick) * barW
            drawLabel(label, in: ctx, at: CGPoint(x: x, y: chartY + chartH + 4), font: font, color: color)
        }
    }

    private func drawLabel(
        _ text: String, in ctx: CGContext,
        at point: CGPoint, font: NSFont, color: NSColor
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        str.draw(at: point)
    }
}
