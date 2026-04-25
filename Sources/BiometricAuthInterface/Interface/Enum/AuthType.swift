//
//  AuthType.swift
//  BiometricAuthKit
//
//  Created by kavi gevariya on 24/04/26.
//

import Foundation


/// Represents the type of biometric authentication available on the current device.
///
/// Use this enumeration to determine which biometric authentication mechanism
/// is supported and whether the user has granted permission to use it.
///
/// ```swift
/// let authType: BiometricAuthenticationType = .faceIdentification(permitted: true)
///
/// switch authType {
/// case .faceIdentification(let permitted):
///     print("Face ID available, permitted: \(permitted)")
/// case .touchIdentification(let permitted):
///     print("Touch ID available, permitted: \(permitted)")
/// case .none:
///     print("No biometric authentication available")
/// }
/// ```
public enum BiometricAuthenticationType: Hashable, Sendable {

    /// Face ID authentication.
    ///
    /// - Parameter permitted: A Boolean value indicating whether the user has granted permission to use Face ID.
    case faceIdentification(permitted: Bool)

    /// Touch ID authentication.
    ///
    /// - Parameter permitted: A Boolean value indicating whether the user has granted permission to use Touch ID.
    case touchIdentification(permitted: Bool)

    /// No biometric authentication is available on the device.
    case none
}
