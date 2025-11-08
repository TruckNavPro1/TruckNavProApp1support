//
//  NavigationInstructionView.swift
//  TruckNavPro
//

import UIKit

class NavigationInstructionView: UIView {

    private let distanceLabel = UILabel()
    private let instructionLabel = UILabel()
    private let roadNameLabel = UILabel()
    private let maneuverIconLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8

        // Maneuver Icon
        maneuverIconLabel.font = .systemFont(ofSize: 40)
        maneuverIconLabel.text = "↑"
        maneuverIconLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(maneuverIconLabel)

        // Distance Label
        distanceLabel.font = .systemFont(ofSize: 24, weight: .bold)
        distanceLabel.textColor = .label
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(distanceLabel)

        // Instruction Label
        instructionLabel.font = .systemFont(ofSize: 18, weight: .medium)
        instructionLabel.textColor = .label
        instructionLabel.numberOfLines = 2
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(instructionLabel)

        // Road Name Label
        roadNameLabel.font = .systemFont(ofSize: 14, weight: .regular)
        roadNameLabel.textColor = .secondaryLabel
        roadNameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(roadNameLabel)

        NSLayoutConstraint.activate([
            maneuverIconLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            maneuverIconLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            distanceLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            distanceLabel.leadingAnchor.constraint(equalTo: maneuverIconLabel.trailingAnchor, constant: 16),
            distanceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            instructionLabel.topAnchor.constraint(equalTo: distanceLabel.bottomAnchor, constant: 8),
            instructionLabel.leadingAnchor.constraint(equalTo: maneuverIconLabel.trailingAnchor, constant: 16),
            instructionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            roadNameLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 4),
            roadNameLabel.leadingAnchor.constraint(equalTo: maneuverIconLabel.trailingAnchor, constant: 16),
            roadNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            roadNameLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        ])
    }

    func configure(distance: String, instruction: String, roadName: String?, maneuverType: String) {
        distanceLabel.text = distance
        instructionLabel.text = instruction
        roadNameLabel.text = roadName ?? ""
        maneuverIconLabel.text = iconForManeuver(maneuverType)
    }

    private func iconForManeuver(_ type: String) -> String {
        switch type.lowercased() {
        case "turn-left", "turn left":
            return "←"
        case "turn-right", "turn right":
            return "→"
        case "sharp-left", "sharp left":
            return "↰"
        case "sharp-right", "sharp right":
            return "↱"
        case "slight-left", "slight left":
            return "↖"
        case "slight-right", "slight right":
            return "↗"
        case "uturn", "u-turn":
            return "↩"
        case "arrive", "destination":
            return "🏁"
        case "depart", "start":
            return "🚗"
        case "roundabout", "rotary":
            return "⭕"
        case "merge":
            return "⤴"
        case "fork":
            return "⑂"
        case "continue", "straight":
            return "↑"
        default:
            return "↑"
        }
    }
}
