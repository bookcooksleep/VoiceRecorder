//
//  RKSettings.swift
//  RecordKit
//
//  Created by guoyiyuan on 2019/3/6.
//  Copyright © 2019 guoyiyuan. All rights reserved.
//

import Foundation
import AVFoundation

public class RKSettings: RKObject {
	@objc public enum BufferLength: Int {
		case shortest = 5
		case veryShort = 6
		case short = 7
		case medium = 8
		case long = 9
		case veryLong = 10
		case huge = 11
		case longest = 12
	}
	
	/// Constants for ramps used in AKParameterRamp.hpp, AKBooster, and others
	@objc public enum RampType: Int {
		case linear = 0
		case exponential = 1
		case logarithmic = 2
		case sCurve = 3
	}
	
	public struct IOFormat {
		public let channelCount: UInt32
		public let formatID: AudioFormatID
		public let bitDepth: CommonFormat
		public let sampleRate: Double
		public let interleaved: Bool
		public var asbd: AudioStreamBasicDescription {
			var value = AudioStreamBasicDescription()
			ioFormat(desc: &value, iof: {
				RKSettings.IOFormat(formatID: formatID, bitDepth: bitDepth,
									channelCount: channelCount, sampleRate: sampleRate)
			}(), inIsInterleaved: interleaved)
			return value
		}
		
		public init(formatID: AudioFormatID, bitDepth: CommonFormat,
					channelCount: UInt32 = 2, sampleRate: Double = RKSettings.sampleRate, isInterleaved: Bool = false) {
			self.formatID = formatID
			self.bitDepth = bitDepth
			self.channelCount = channelCount
			self.sampleRate = sampleRate
			self.interleaved = isInterleaved
		}
	}
	
	@objc public static var resources: Bundle {
		if let bundlePath = Bundle.main.path(forResource: "Frameworks/RecordKit.framework/Resources", ofType: "bundle"),
			let bundle = Bundle(path: bundlePath) {
			return bundle
		} else {
			return Bundle.main
		}
	}
	@objc public static var channelCount: UInt32 = 2
	@objc public static var audioFormat: AVAudioFormat {
		return AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!
	}
	/// If set to true, Recording will stop after some delay to compensate
	/// latency between time recording is stopped and time it is written to file
	/// If set to false (the default value) , stopping record will be immediate,
	/// even if the last audio frames haven't been recorded to file yet.
	@objc public static var fixTruncatedRecordings = false
	/// Global default rampDuration value
	@objc public static var rampDuration: Double = 0.000_2
	@objc public static var sampleRate: Double = 44100
	@objc public static var bufferLength: BufferLength = .veryLong
	@objc public static var interleaved: Bool = false
	@objc public static var enableLogging: Bool = true
	@objc public static var maxDuration: TimeInterval = TimeInterval(2 * 60)
	@objc public static var timeStamp: TimeInterval = 0
	@objc public static var ASRLimitDuration: TimeInterval = TimeInterval(60)
	@objc public static var ASRAppID: String = /** "15731062" **/ "15807927"
	@objc public static var ASRApiKey: String = /** "rbKB6zVhL0fAc7fn0lKGYiPn" **/ "DavSgp7gxiBbbqxdWFQpvGO0"
	@objc public static var ASRSecretKey: String = /** "Un2QyGl2HS942MOa2GjCKFN4HOQrHUaX" **/ "GAXG2t82pT7UWzIXiB4kIkbbD6fwWlK8"
}

private func ioFormat(desc: UnsafeMutablePointer<AudioStreamBasicDescription>,
					  iof: RKSettings.IOFormat,
					  inIsInterleaved: Bool) {
	let descBlock: (inout AudioStreamBasicDescription) -> () = {
		var wordsize: UInt32
		$0.mSampleRate = iof.sampleRate
		$0.mFormatID = iof.formatID
		$0.mFormatFlags = AudioFormatFlags(kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked)
		$0.mFramesPerPacket = 1
		$0.mBytesPerFrame = 0
		$0.mBytesPerPacket = 0
		$0.mReserved = 0
		
		switch iof.bitDepth {
		case .float32:
			wordsize = 4
			$0.mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsFloat)
		case .float64:
			wordsize = 8
			$0.mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsFloat)
			break;
		case .int16:
			wordsize = 2
			$0.mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsSignedInteger)
		case .int32:
			wordsize = 4
			$0.mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsSignedInteger)
			break;
		case .fixed824:
			wordsize = 4
			$0.mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsSignedInteger | (24 << kLinearPCMFormatFlagsSampleFractionShift))
		}
		$0.mBitsPerChannel = wordsize * 8
		if inIsInterleaved {
			$0.mBytesPerFrame = wordsize * iof.channelCount
			$0.mBytesPerPacket = $0.mBytesPerFrame
		} else {
			$0.mFormatFlags |= AudioFormatFlags(kAudioFormatFlagIsNonInterleaved)
			$0.mBytesPerFrame = wordsize
			$0.mBytesPerPacket = $0.mBytesPerFrame
		}
		if case kAudioFormatiLBC = iof.formatID {
			$0.mChannelsPerFrame = 1
		} else {
			$0.mChannelsPerFrame = iof.channelCount
		}
	};descBlock(&desc.pointee)
}

extension RKSettings.IOFormat {
	public static var lpcm16: AudioStreamBasicDescription {
		var asbd = AudioStreamBasicDescription()
		ioFormat(desc: &asbd, iof: {
			RKSettings.IOFormat(formatID: kAudioFormatLinearPCM, bitDepth: .int16)
		}(), inIsInterleaved: true)
		return asbd
	}
	
	public static var lpcm32: AudioStreamBasicDescription {
		var asbd = AudioStreamBasicDescription()
		ioFormat(desc: &asbd, iof: {
			RKSettings.IOFormat(formatID: kAudioFormatLinearPCM, bitDepth: .float32)
		}(), inIsInterleaved: true)
		return asbd
	}
	
	public enum CommonFormat: UInt32 {
		case float32, fixed824, int32 = 4
		case int16 = 2
		case float64 = 8
	}
}

extension RKSettings.BufferLength {
	public var samplesCount: AVAudioFrameCount {
		return AVAudioFrameCount(pow(2.0, Double(rawValue)))
	}
	
	public var duration: Double {
		return Double(samplesCount) / RKSettings.sampleRate
	}
}
