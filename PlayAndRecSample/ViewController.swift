//
//  ViewController.swift
//  PlayAndRecSample
//
//  Created by Tadashi on 2017/03/02.
//  Copyright © 2017 T@d. All rights reserved.
//

import UIKit

import UIKit
import AVFoundation
import AudioToolbox

class ViewController: UIViewController {

	@IBOutlet weak var indicatorView: UIActivityIndicatorView!
	var audioEngine : AVAudioEngine!
	var audioFile : AVAudioFile!
	var audioPlayer : AVAudioPlayerNode!
	var outref: ExtAudioFileRef?
	var audioFilePlayer: AVAudioPlayerNode!
	var mixer : AVAudioMixerNode!
	var filePath : String? = nil
	var isPlay = false
	var isRec = false

	@IBOutlet var play: UIButton!
	@IBAction func play(_ sender: Any) {

		if self.isPlay {
			self.play.setTitle("PLAY", for: .normal)
			self.indicator(value: false)
			self.stopPlay()
		} else {
			self.play.setTitle("STOP", for: .normal)
			self.indicator(value: true)
			self.startPlay()
		}
	}

	@IBOutlet var rec: UIButton!
	@IBAction func rec(_ sender: Any) {
	
		if self.isRec {
			self.rec.setTitle("RECORDING", for: .normal)
			self.indicator(value: false)
			self.stopRecord()
		} else {
			self.rec.setTitle("STOP", for: .normal)
			self.indicator(value: true)
			self.startRecord()
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		self.audioEngine = AVAudioEngine()
		self.audioFilePlayer = AVAudioPlayerNode()
		self.mixer = AVAudioMixerNode()
		self.audioEngine.attach(audioFilePlayer)
		self.audioEngine.attach(mixer)

		self.indicator(value: false)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio) != .authorized {
			AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeAudio,
				completionHandler: { (granted: Bool) in
			})
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}

	func startRecord() {

		self.filePath = nil

		self.isRec = true

		try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
		try! AVAudioSession.sharedInstance().setActive(true)

		self.audioFile = try! AVAudioFile(forReading: Bundle.main.url(forResource: "1K", withExtension: "mp3")!)

		let format = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatInt16,
			sampleRate: 44100.0,
			channels: 1,
			interleaved: true)

		self.audioEngine.connect(self.audioEngine.inputNode!, to: self.mixer, format: format)
		self.audioEngine.connect(self.audioFilePlayer, to: self.mixer, format: self.audioFile.processingFormat)
		self.audioEngine.connect(self.mixer, to: self.audioEngine.mainMixerNode, format: format)

		self.audioFilePlayer.scheduleSegment(audioFile,
			startingFrame: AVAudioFramePosition(0),
			frameCount: AVAudioFrameCount(self.audioFile.length),
			at: nil,
			completionHandler: self.completion)

		let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as String
		self.filePath =  dir.appending("/temp.wav")

		_ = ExtAudioFileCreateWithURL(URL(fileURLWithPath: self.filePath!) as CFURL,
			kAudioFileWAVEType,
			format.streamDescription,
			nil,
			AudioFileFlags.eraseFile.rawValue,
			&outref)

		self.mixer.installTap(onBus: 0, bufferSize: AVAudioFrameCount(format.sampleRate * 0.4), format: format, block: { (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in

			let audioBuffer : AVAudioBuffer = buffer
			_ = ExtAudioFileWrite(self.outref!, buffer.frameLength, audioBuffer.audioBufferList)
		})

		try! self.audioEngine.start()
		self.audioFilePlayer.play()
	}

	func stopRecord() {
		self.isRec = false
		self.audioFilePlayer.stop()
		self.audioEngine.stop()
		self.mixer.removeTap(onBus: 0)
		ExtAudioFileDispose(self.outref!)
		try! AVAudioSession.sharedInstance().setActive(false)
	}

	func startPlay() {
	
		if self.filePath == nil {
			return
		}

		self.isPlay = true

		try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
		try! AVAudioSession.sharedInstance().setActive(true)

		self.audioFile = try! AVAudioFile(forReading: URL(fileURLWithPath: self.filePath!))

		self.audioEngine.connect(self.audioFilePlayer, to: self.audioEngine.mainMixerNode, format: audioFile.processingFormat)

		self.audioFilePlayer.scheduleSegment(audioFile,
			startingFrame: AVAudioFramePosition(0),
			frameCount: AVAudioFrameCount(self.audioFile.length),
			at: nil,
			completionHandler: self.completion)

		try! self.audioEngine.start()
		self.audioFilePlayer.play()
	}
	
	func stopPlay() {
		self.isPlay = false
		if self.audioFilePlayer != nil && self.audioFilePlayer.isPlaying {
			self.audioFilePlayer.stop()
		}
		self.audioEngine.stop()
		try! AVAudioSession.sharedInstance().setActive(false)
	}

	func completion() {

		if self.isRec {
			DispatchQueue.main.async {
				self.rec(UIButton())
			}
		} else if self.isPlay {
			DispatchQueue.main.async {
				self.play(UIButton())
			}
		}
	}
	
	func indicator(value: Bool) {
	
		if value {
			self.indicatorView.startAnimating()
			self.indicatorView.isHidden = false
		} else {
			self.indicatorView.stopAnimating()
			self.indicatorView.isHidden = true
		}
	}
}
