//
//  HelperError.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-10-02
//

import Foundation

public let HelperErrorDomain = "com.shariq.sapphireHelper.ErrorDomain"

public enum HelperErrorCode: Int {
    case smcOpenFailed = 1
    case smcWriteFailed = 2
    case generalError = 3
}

func makeError(code: HelperErrorCode, description: String, arguments: [String] = []) -> NSError {
    // Preserve the diagnostic identity; the UI host resolves the native localization.
    let diagnostic = arguments.isEmpty ? description : String(format: description, arguments: arguments)
    let userInfo: [String: Any] = [
        NSLocalizedDescriptionKey: diagnostic,
        "SapphireLocalizationKey": description,
        "SapphireLocalizationArguments": arguments
    ]
    return NSError(domain: HelperErrorDomain, code: code.rawValue, userInfo: userInfo)
}