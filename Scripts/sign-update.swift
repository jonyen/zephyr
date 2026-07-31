#!/usr/bin/env swift
//
// Signs update payloads with Ed25519, and generates the keypair that does it.
//
// The app replaces its own bundle with whatever it downloads, so the download has to be
// provably ours. CryptoKit is used on both sides — here and in UpdateService — so there is
// no key-encoding or signature-format mismatch to debug between signer and verifier.
//
//   swift Scripts/sign-update.swift keygen
//   UPDATE_SIGNING_KEY=<base64> swift Scripts/sign-update.swift sign path/to/Zephyr.app.zip
//
// keygen prints the private key (store as the UPDATE_SIGNING_KEY secret, never commit) and
// the public key (safe to commit — it goes in UpdateService). sign prints a base64 signature.

import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("sign-update: \(message)\n".utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())

switch args.first {
case "keygen":
    let key = Curve25519.Signing.PrivateKey()
    print("private (UPDATE_SIGNING_KEY secret): \(key.rawRepresentation.base64EncodedString())")
    print("public  (embed in UpdateService):    \(key.publicKey.rawRepresentation.base64EncodedString())")

case "sign":
    guard args.count == 2 else { fail("usage: sign-update.swift sign <file>") }
    let path = args[1]

    guard let secret = ProcessInfo.processInfo.environment["UPDATE_SIGNING_KEY"], !secret.isEmpty else {
        fail("UPDATE_SIGNING_KEY is not set")
    }
    guard let seed = Data(base64Encoded: secret) else {
        fail("UPDATE_SIGNING_KEY is not valid base64")
    }
    guard let payload = FileManager.default.contents(atPath: path) else {
        fail("cannot read \(path)")
    }

    do {
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        let signature = try key.signature(for: payload)
        // Bare signature on stdout so callers can capture it directly.
        print(signature.base64EncodedString())
    } catch {
        fail("signing failed: \(error)")
    }

case "verify":
    // Lets CI prove a payload verifies before publishing it, using the same path the app takes.
    guard args.count == 4 else { fail("usage: sign-update.swift verify <file> <base64-sig> <base64-pubkey>") }
    guard let payload = FileManager.default.contents(atPath: args[1]),
          let signature = Data(base64Encoded: args[2]),
          let publicKeyData = Data(base64Encoded: args[3]) else {
        fail("could not read payload, signature, or public key")
    }
    do {
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        guard publicKey.isValidSignature(signature, for: payload) else { fail("signature does NOT verify") }
        print("signature verifies")
    } catch {
        fail("verification failed: \(error)")
    }

default:
    fail("usage: sign-update.swift <keygen|sign|verify> [...]")
}
